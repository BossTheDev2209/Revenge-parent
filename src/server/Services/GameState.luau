-- GameState — state ตารางเดียวของทั้งเกม + save/load 4 slot
-- pure: newGame / mergeDefaults / slotSummary (เทส lune) · glue: push / saveSlot / loadSlot / listSlots
-- กติกา: service แก้ state เสร็จต้องเรียก GameState.push(state) ไม่งั้นจอไม่อัปเดต
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../shared/Formulas")

local GameState = {}

function GameState.newGame()
	return {
		follower = 0,
		money = Config.StartMoney,
		mental = Config.Mental.start,
		phase = 1,
		day = 1,
		timeOfDay = Config.Time.dayStartHour,
		clips = {},
		choices = { pos = 0, neu = 0, neg = 0 }, -- ชื่อตรงกับ Formulas.resolveEnding
		upgrades = { camera = 1, storage = 1 }, -- ระดับสูงสุดที่ซื้อ (ขึ้นอย่างเดียว)
		equipped = {}, -- ระดับที่เลือกใช้ · ว่าง = ใช้ตัวสูงสุด (Formulas.activeLevel)
		footageGB = 0,        -- footage ดิบ · เต็ม capacity = อัดต่อไม่ได้
		lastRecordAt = 0,     -- os.clock ครั้งล่าสุด (cooldown)
		filmZone = { spot = nil, expiresAt = 0 },
		notebookPlaced = false, -- โน้ตบุ๊คเฟส 1 วางบนพื้นไหม
		spending = { food = 0, rent = 0 }, -- ⊖⊕ ใน Bank เป็น offset step (Config.Spending)
		sponsorOffer = false, -- มี offer ค้างรอกดรับไหม (หมดอายุเมื่อขึ้นวันใหม่)
		sponsorBuffUntilDay = 0, -- กดรับแล้ว → เงินคลิป ×SponsorBuffMult จนถึงวันนี้
		dmClaimed = {},       -- [payoutId] = true (เงินก้อน sponsor ที่กดรับแล้ว)
		staff = {},           -- พนักงานจ้าง {id, speed, quality, salary}
		companions = {},      -- เพื่อนร่วมทาง (auto ตามเนื้อเรื่อง ไม่มี salary)
		npcLoc = {},          -- [actor] = ที่อยู่ ("room"/"park"/"away")
		staffClips = {},      -- คลิปที่ทีมผลิต {tier, by} — นับ VidQ% ครึ่งเดียว
		staffClipCarry = {},  -- [id] = เศษคลิปสะสมข้ามวัน
		flags = {},           -- canon event ที่ผ่านแล้ว
		seenDialogue = {},    -- [ชื่อบท] = เฟสที่คุยจบล่าสุด (คุยซ้ำเฟสเดิม = บท repeat)
		activity = { streak = 0, cooldownUntilDay = 0 },
		pendingComments = {}, -- comment รอตอบ
		pendingEvents = {},   -- canon event รอเล่นฝั่ง client เช่น "milestone_1000"
		mentalMods = {},      -- modifier ที่ active: {id, expireHour?}
		buffs = {},           -- ของกินที่ออกฤทธิ์: [key] = { expireHour }
		streaks = { edit = 0, commentBad = 0, commentGood = 0 },
		awakeHours = 0,       -- ตื่นต่อเนื่องกี่ชั่วโมง (ครบ 20 → NoSleep)
		lastViralDay = 0,
		slot = 1,
		savedAt = 0,
		settings = { volume = 1, bgmVol = 1, sfxVol = 1, ambientVol = 1, shadow = true, musicMuted = false, hideBillboards = false },
		-- ผู้เล่น commit เข้าเกมแล้วยัง — false ระหว่างอยู่เมนู · autosave/BindToClose เซฟเฉพาะ started=true
		-- (กัน placeholder state ทับเซฟจริงช่อง 1 ตอนนั่งดูเมนู >60 วิ)
		started = false,
	}
end

-- เติม key ที่ขาดจาก defaults (recursive) — save เก่าโหลดกับโค้ดใหม่แล้วไม่พัง
function GameState.mergeDefaults(loaded, defaults)
	for k, v in defaults do
		if loaded[k] == nil then
			loaded[k] = v
		elseif type(v) == "table" and type(loaded[k]) == "table" then
			GameState.mergeDefaults(loaded[k], v)
		end
	end
	return loaded
end

-- เคลียร์ flag ที่ชี้ไปโมเดลใน workspace (ไม่ persist ข้าม session) ตอนโหลด
-- notebookPlaced: โมเดลหายเมื่อออกเกมแต่ flag ถูก save → reset false = โน้ตบุ๊คกลับเข้ากระเป๋า
function GameState.clearWorldFlags(state)
	state.notebookPlaced = false
	state.pendingRecordQTE = nil -- QTE transient — save ที่ค้างมาไม่ควร retrigger ตอนโหลด
	return state
end

function GameState.slotSummary(state)
	return {
		follower = state.follower,
		day = state.day,
		phase = Formulas.phaseFor(state.follower),
		savedAt = state.savedAt,
	}
end

-- Continue = slot ที่เซฟล่าสุด (savedAt มากสุด)
function GameState.latestSlot(summaries)
	local best, bestAt = nil, -1
	for slot, sum in summaries do
		if sum.savedAt > bestAt then
			best, bestAt = slot, sum.savedAt
		end
	end
	return best
end

-- โหลดทับ state เดิมโดยรักษา identity ของตาราง (service/Main ถือ reference เดิมอยู่)
function GameState.replaceWith(state, newState)
	for k in state do state[k] = nil end
	for k, v in newState do state[k] = v end
	return state
end

-- ===== Roblox glue (Studio เท่านั้น — lune ไม่แตะ) =====
local DATASTORE_NAME = "SaveSlots_v1"
local MAX_SLOTS = 4

local function store()
	return game:GetService("DataStoreService"):GetDataStore(DATASTORE_NAME)
end

local dirty = false

-- ยิง state ทั้งก้อนให้ client + ตั้ง dirty รอ autosave
function GameState.push(state)
	dirty = true
	local remote = game:GetService("ReplicatedStorage").Shared.Remotes.StateChanged
	remote:FireAllClients(state)
end

function GameState.isDirty()
	return dirty
end

-- 1 ช่อง = 1 ไฟล์เซฟ เก็บได้หลาย snapshot
--   file = { snapshots = {{state, savedAt, summary}, ...}, auto = {snapshot เดียว} }
--   snapshots[1] = manual ล่าสุด (ใหม่→เก่า, cap MAX_SNAPSHOTS) · auto = autosave (ทับตัวเดียว)
local MAX_SNAPSHOTS = 5

local function entryMeta(snap, which)
	local sum = snap.summary or {}
	return { which = which, follower = sum.follower, day = sum.day, phase = sum.phase, savedAt = snap.savedAt }
end

-- สรุปช่องเซฟจาก file ในมือ (ไม่ re-read DataStore = กัน cache race) · file/ว่าง = nil
local function summarizeFile(file)
	if not file then return nil end
	local entries = {}
	if file.auto then table.insert(entries, entryMeta(file.auto, "auto")) end
	for idx, snap in file.snapshots do table.insert(entries, entryMeta(snap, idx)) end
	local latest
	for _, e in entries do
		if not latest or (e.savedAt or 0) > (latest.savedAt or 0) then latest = e end
	end
	if not latest then return nil end
	return {
		follower = latest.follower, day = latest.day, phase = latest.phase, savedAt = latest.savedAt,
		count = #file.snapshots, hasAuto = file.auto ~= nil, entries = entries,
	}
end

-- GetAsync + retry — throttle/timeout เป็นครั้งคราว = ปกติ (ไม่ใช่ "ไม่มีเซฟ")
-- คืน (ok, data): ok=false = อ่านไม่สำเร็จหลัง retry · ok=true,data=nil = ช่องว่างจริง
local function getAsyncRetry(key: string)
	local lastErr
	for attempt = 1, 3 do
		local ok, data = pcall(function() return store():GetAsync(key) end)
		if ok then return true, data end
		lastErr = data
		if attempt < 3 then task.wait(0.5 * attempt) end -- backoff
	end
	warn("[GameState] GetAsync ล้มเหลวหลัง retry:", key, lastErr)
	return false, nil
end

-- อ่านไฟล์ช่อง + migrate เซฟเก่า (state ดิบไม่มี .snapshots) → wrap เป็น snapshot เดียว
-- คืน (file, readOk): readOk=false = อ่านไม่สำเร็จ ("ไม่รู้" ไม่ใช่ "ว่าง") — caller ต้องแยกให้ออก
--   ไม่งั้น fail ชั่วคราว = เซฟหายหน้าเมนู แล้ว Continue เดา NewGame ทับ
local function readFile(userId: number, slot: number)
	local ok, data = getAsyncRetry(userId .. "_" .. slot)
	if not ok then return nil, false end
	if data == nil then return nil, true end -- ช่องว่างจริง
	if data.snapshots == nil and data.auto == nil then
		return { snapshots = { { state = data, savedAt = data.savedAt or 0, summary = GameState.slotSummary(data) } } }, true
	end
	data.snapshots = data.snapshots or {}
	return data, true
end

-- isAuto = ทับ file.auto ตัวเดียว · ไม่ใช่ = manual (push เข้า history ตัดตัวเก่าสุดถ้าเกิน 5)
function GameState.saveSlot(userId: number, state, isAuto: boolean?)
	state.savedAt = os.time()
	local file = readFile(userId, state.slot) or { snapshots = {} }
	local snap = { state = state, savedAt = state.savedAt, summary = GameState.slotSummary(state) }
	if isAuto then
		file.auto = snap
	else
		table.insert(file.snapshots, 1, snap)
		while #file.snapshots > MAX_SNAPSHOTS do table.remove(file.snapshots) end
	end
	local ok, err = pcall(function() store():SetAsync(userId .. "_" .. state.slot, file) end)
	if ok then dirty = false else warn("[GameState] save ไม่สำเร็จ:", err) end
	return ok, summarizeFile(file) -- summary จาก file ในมือ (cache-proof)
end

-- which: "auto" | index ใน snapshots | nil (= ล่าสุดข้าม manual+auto)
function GameState.loadSlot(userId: number, slot: number, which)
	local file = readFile(userId, slot)
	if not file then return nil end
	local snap
	if which == "auto" then
		snap = file.auto
	elseif type(which) == "number" then
		snap = file.snapshots[which]
	else
		snap = file.snapshots[1]
		if file.auto and (not snap or file.auto.savedAt > snap.savedAt) then snap = file.auto end
	end
	if not snap or not snap.state then return nil end
	local data = snap.state
	data.slot = slot
	GameState.mergeDefaults(data, GameState.newGame())
	return GameState.clearWorldFlags(data)
end

-- ลบ snapshot เดียว (ว่างหมด = ลบทั้งช่อง)
function GameState.deleteSnapshot(userId: number, slot: number, which)
	local file = readFile(userId, slot)
	if not file then return false end
	if which == "auto" then
		file.auto = nil
	elseif type(which) == "number" then
		table.remove(file.snapshots, which)
	end
	if not file.auto and #file.snapshots == 0 then
		local ok = GameState.deleteSlot(userId, slot)
		return ok, nil -- ช่องว่างหมด → summary nil
	end
	local ok = pcall(function() store():SetAsync(userId .. "_" .. slot, file) end)
	return ok, summarizeFile(file)
end

function GameState.deleteSlot(userId: number, slot: number)
	local ok, err = pcall(function()
		store():RemoveAsync(userId .. "_" .. slot)
	end)
	if not ok then warn("[GameState] delete ไม่สำเร็จ:", err) end
	return ok
end

-- คืน (out, failed): out={[slot]=summary} ช่องที่มีเซฟ · failed={[slot]=true} ช่องที่อ่านไม่สำเร็จ
--   client แยก failed ออกจาก "ว่าง" → โชว์ "ลองใหม่" ไม่ให้ Continue เดา NewGame ทับ
function GameState.listSlots(userId: number)
	local out = {}
	-- อ่าน 4 ช่องพร้อมกัน (spawn ให้ GetAsync yield ซ้อนกัน — เดิมไล่ทีละช่อง ~1.5 วิ)
	local files, oks, pending = {}, {}, MAX_SLOTS
	for slot = 1, MAX_SLOTS do
		task.spawn(function()
			files[slot], oks[slot] = readFile(userId, slot)
			pending -= 1
		end)
	end
	local t0 = os.clock()
	while pending > 0 and os.clock() - t0 < 12 do task.wait() end -- ช่องที่ค้างเกิน 12s นับเป็น failed
	local failed = {}
	for slot = 1, MAX_SLOTS do
		local sum = summarizeFile(files[slot])
		if sum then
			out[slot] = sum
		elseif oks[slot] ~= true then
			failed[slot] = true
		end
	end
	return out, failed
end

return GameState
