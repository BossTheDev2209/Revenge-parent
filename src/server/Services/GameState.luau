-- GameState.luau — state ตารางเดียวของทั้งเกม + save/load 4 slot
-- pure ส่วน: newGame / mergeDefaults / slotSummary (เทสด้วย lune)
-- Roblox glue: push / saveSlot / loadSlot / listSlots (ใช้ได้เฉพาะใน Studio)
-- กติกา: service แก้ state เสร็จต้องเรียก GameState.push(state) เสมอ ไม่งั้นจอไม่อัปเดต
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
		clips = {},    -- {tier="B", uploaded=true, ...}
		choices = { pos = 0, neu = 0, neg = 0 }, -- ชื่อตรงกับ Formulas.resolveEnding
		upgrades = { camera = 1, storage = 1 }, -- ระดับสูงสุดที่ซื้อ (ขึ้นอย่างเดียว) — pc ถอดออก 11 ส.ค. (user)
		-- ระดับที่เลือกใช้อยู่ — ว่าง = ใช้ตัวสูงสุดที่ซื้อ (Formulas.activeLevel)
		-- ปล่อยว่างไว้จงใจ: save เก่าที่ไม่มี field นี้ merge เข้ามาแล้วไม่โดนลดระดับเงียบๆ
		equipped = {},
		-- ระบบอัดคลิป (docs/02 §9.5)
		footageGB = 0,        -- footage ดิบที่อัดมา เต็ม capacity = FULL อัดต่อไม่ได้
		lastRecordAt = 0,     -- os.clock ครั้งล่าสุด (cooldown 0.6 วิ)
		filmZone = { spot = nil, expiresAt = 0 }, -- โซนถ่ายปัจจุบัน ย้ายทุก 120 วิ
		notebookPlaced = false, -- โน้ตบุ๊ค (เฟส 1) วางอยู่บนพื้นไหม — วางแล้ว Tool หายจากมือ
		spending = { food = 0, rent = 0, staff = 0 }, -- ⊖⊕ ใน Bank เป็น offset step (Config.Spending)
		calendar = {}, -- [day] = {type=..., id=...} — ★ ปฏิทินถูกพับไว้ 9 ส.ค. (ดู SponsorService) เก็บ field ไว้เผื่อรื้อกลับ
		sponsorOffer = false, -- มี offer ค้างรอกดรับไหม (สุ่มรายวัน — SponsorService.rollOffer · หมดอายุเมื่อขึ้นวันใหม่)
		sponsorBuffUntilDay = 0, -- กดรับงานแล้ว → เงินจากคลิป ×Config.SponsorBuffMult จนถึงวันนี้ (Formulas.sponsorMult)
		dmClaimed = {}, -- [payoutId] = true — เงินก้อน sponsor ตาม milestone ที่กดรับไปแล้ว (SponsorService.claimDM)
		-- ระบบพนักงาน (docs/02 §9.8)
		staff = {},          -- พนักงานจ้าง {id=, speed=, quality=, salary=}
		companions = {},     -- เพื่อนร่วมทาง (auto ตามเนื้อเรื่อง ไม่มี salary)
		npcLoc = {},         -- [ชื่อ actor] = ที่อยู่ปัจจุบัน ("room"/"park"/"away") — StoryNPCPlacer วางตาม (client render)
		staffClips = {},     -- คลิปที่ทีมผลิต {tier=, by=} — นับ VidQ% ครึ่งเดียว
		staffClipCarry = {}, -- [id] = เศษคลิปสะสมข้ามวัน
		flags = {},    -- canon event ที่ผ่านแล้ว
		seenDialogue = {}, -- [ชื่อบท] = เฟสที่คุยจบบทเต็มล่าสุด (คุยซ้ำเฟสเดิม = เล่นบท repeat)
		activity = { streak = 0, cooldownUntilDay = 0 }, -- ฟื้นใจติดกัน 3 ครั้ง → cooldown
		pendingComments = {}, -- comment รอตอบ {id=} (CommentService)
		pendingEvents = {},   -- canon event รอเล่นฝั่ง client เช่น "milestone_1000"
		mentalMods = {},      -- modifier ที่ active: {id=, expireHour=?} (docs/02 §3)
		buffs = {},           -- ของกินที่ออกฤทธิ์อยู่: [key] = { expireHour = } (Config.Consumables · หมดฤทธิ์ที่ MoneyService.expireBuffs)
		streaks = { edit = 0, commentBad = 0, commentGood = 0 },
		awakeHours = 0,       -- ตื่นต่อเนื่องกี่ชั่วโมงเกม (ครบ 20 → NoSleep)
		lastViralDay = 0,     -- ไว้เช็ค viral 2 วันติด
		slot = 1,
		savedAt = 0,
		-- preference (เซฟไปกับเกม): เสียงรวม/เพลง/เอฟเฟกต์/บรรยากาศ/เงา/ปิดเพลง/ป้ายลอย (12 ส.ค. 2569, user — mirror จาก Studio ที่ยังไม่เคย commit)
		settings = { volume = 1, bgmVol = 1, sfxVol = 1, ambientVol = 1, shadow = true, musicMuted = false, hideBillboards = false },
		-- ★ ผู้เล่น commit เข้าเกมแล้วหรือยัง (กด New Game / Continue) — false ระหว่างอยู่หน้าเมนู
		--   autosave/BindToClose เซฟเฉพาะเมื่อ started=true · กัน placeholder state (follower 0 slot 1)
		--   ทับเซฟจริงช่อง 1 ระหว่างผู้เล่นยังนั่งดูเมนู >60 วิ (เจอจริง 6 ส.ค.)
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

-- reset flags ที่ชี้ไป "โมเดลใน workspace" ซึ่งไม่ persist ข้าม session → ต้องเคลียร์ตอนโหลด
-- notebookPlaced: โมเดล PlacedNotebook อยู่ workspace หายเมื่อออกเกม แต่ flag ถูก save
--   → โหลดมาแล้ว desiredTools ตัด Notebook ทิ้ง + ไม่มีโมเดลวางอยู่ = โน้ตบุ๊คหายเกลี้ยง
--   reset false = โน้ตบุ๊คกลับเข้ากระเป๋า (ผู้เล่นวางใหม่ได้) · flag world-model ใหม่ในอนาคตเพิ่มที่นี่
function GameState.clearWorldFlags(state)
	state.notebookPlaced = false
	state.pendingRecordQTE = nil -- QTE เป็น transient client-driven — save ที่ติดค้างมาไม่ควร retrigger ตอนโหลด
	return state
end

-- ข้อมูลย่อไว้โชว์หน้า save select (Main Menu)
function GameState.slotSummary(state)
	return {
		follower = state.follower,
		day = state.day,
		phase = Formulas.phaseFor(state.follower),
		savedAt = state.savedAt,
	}
end

-- หน้า Main Menu ใช้ — Continue = slot ที่เซฟล่าสุด (savedAt มากสุด)
function GameState.latestSlot(summaries)
	local best, bestAt = nil, -1
	for slot, sum in summaries do
		if sum.savedAt > bestAt then
			best, bestAt = slot, sum.savedAt
		end
	end
	return best
end

-- โหลด save ทับ state เดิมโดยรักษา identity ของตาราง (service/Main ถือ reference เดิมอยู่)
function GameState.replaceWith(state, newState)
	for k in state do state[k] = nil end
	for k, v in newState do state[k] = v end
	return state
end

-- ===== Roblox glue (Studio เท่านั้น — lune ไม่แตะส่วนนี้) =====
local DATASTORE_NAME = "SaveSlots_v1"
local MAX_SLOTS = 4

local function store()
	return game:GetService("DataStoreService"):GetDataStore(DATASTORE_NAME)
end

local dirty = false

-- ยิง state ทั้งก้อนให้ client + ตั้ง dirty รอ autosave (docs/06 §3)
function GameState.push(state)
	dirty = true
	local remote = game:GetService("ReplicatedStorage").Shared.Remotes.StateChanged
	remote:FireAllClients(state)
end

function GameState.isDirty()
	return dirty
end

-- 1 ช่อง (slot) = 1 "ไฟล์เซฟ" เก็บได้หลาย snapshot (docs)
--   file = { snapshots = { {state=, savedAt=, summary=}, ... }, auto = {snapshot เดียว} }
--   snapshots[1] = manual ล่าสุด (ใหม่→เก่า, cap MAX_SNAPSHOTS) · auto = autosave (ทับตัวเดียว ไม่รก history)
local MAX_SNAPSHOTS = 5

-- metadata ต่อ snapshot (ส่งให้ client เลือก — ไม่รวม state เต็ม) · which = "auto" หรือ index ใน snapshots
local function entryMeta(snap, which)
	local sum = snap.summary or {}
	return { which = which, follower = sum.follower, day = sum.day, phase = sum.phase, savedAt = snap.savedAt }
end

-- สรุปช่องเซฟจาก file (in-memory) → แถวย่อ + entries · file/ว่าง = nil
-- ใช้ทั้ง listSlots และ save/deleteSnapshot (คืน summary จาก file ในมือ = ไม่ต้อง re-read DataStore = กัน cache race)
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

-- GetAsync + retry — DataStore fail แบบ throttle/timeout เป็นครั้งคราว = ปกติ (ไม่ใช่ "ไม่มีเซฟ")
-- คืน (ok, data): ok=false = อ่านไม่สำเร็จหลัง retry ครบ · ok=true,data=nil = ช่องว่างจริง
local function getAsyncRetry(key: string)
	local lastErr
	for attempt = 1, 3 do
		local ok, data = pcall(function() return store():GetAsync(key) end)
		if ok then return true, data end
		lastErr = data
		if attempt < 3 then task.wait(0.5 * attempt) end -- backoff 0.5s, 1.0s
	end
	warn("[GameState] GetAsync ล้มเหลวหลัง retry:", key, lastErr)
	return false, nil
end

-- อ่านไฟล์ช่อง + migrate เซฟเก่า (state ดิบ ไม่มี .snapshots) → wrap เป็น snapshot เดียว (ไม่พังของเก่า)
-- คืน (file, readOk): readOk=false = DataStore อ่านไม่สำเร็จ (ช่องนี้ "ไม่รู้" ไม่ใช่ "ว่าง") — caller ต้องแยกให้ออก
--   ไม่งั้น fail ชั่วคราว = เซฟหายหน้าเมนู แล้ว Continue เดา NewGame ทับ (เจอจริง — replay/รอ ถึงกลับมา)
local function readFile(userId: number, slot: number)
	local ok, data = getAsyncRetry(userId .. "_" .. slot)
	if not ok then return nil, false end -- อ่านล้มเหลว: อย่าแปลว่าช่องว่าง
	if data == nil then return nil, true end -- ช่องว่างจริง
	if data.snapshots == nil and data.auto == nil then
		return { snapshots = { { state = data, savedAt = data.savedAt or 0, summary = GameState.slotSummary(data) } } }, true
	end
	data.snapshots = data.snapshots or {}
	return data, true
end

-- ทุกจุดแตะ DataStore ห่อ pcall — fail = warn + เล่นต่อ (Edit mode fail เป็นเรื่องปกติ)
-- isAuto = autosave (ทับ file.auto ตัวเดียว) · ไม่ใช่ = manual (push เข้า history ตัดตัวเก่าสุดถ้าเกิน 5)
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
	return ok, summarizeFile(file) -- summary จาก file ในมือ (cache-proof) — handler เอาไปอัป slotList เฉพาะช่องนี้
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
	return GameState.clearWorldFlags(data) -- โน้ตบุ๊ค/โมเดลวางในโลก ไม่ persist → กลับเข้ากระเป๋า
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
		return ok, nil -- ช่องว่างหมด = ลบทั้งช่อง → summary nil
	end
	local ok = pcall(function() store():SetAsync(userId .. "_" .. slot, file) end)
	return ok, summarizeFile(file) -- summary จาก file ในมือ (cache-proof)
end

function GameState.deleteSlot(userId: number, slot: number)
	local ok, err = pcall(function()
		store():RemoveAsync(userId .. "_" .. slot)
	end)
	if not ok then warn("[GameState] delete ไม่สำเร็จ:", err) end
	return ok
end

-- คืน {[slot] = summary} เฉพาะ slot ที่มี save — Main Menu/SavePanel ใช้
-- summary = ข้อมูล snapshot ล่าสุด (แถวย่อ) + count + entries (รายการ snapshot ให้กางเลือก restore)
-- คืน (out, failed): out={[slot]=summary} ช่องที่มีเซฟ · failed={[slot]=true} ช่องที่อ่าน DataStore ไม่สำเร็จ
--   client แยก failed ออกจาก "ว่าง" → โชว์ "ลองใหม่" + ไม่ให้ Continue เดา NewGame ทับเซฟ
function GameState.listSlots(userId: number)
	local out = {}
	-- อ่าน 4 ช่องพร้อมกัน (GetAsync แต่ละตัว yield รอ network — spawn ให้ยิงซ้อนกัน)
	-- เดิมไล่ทีละช่อง = 4 round-trip ต่อกัน (~1.5 วิ) หน้าต่างที่ผู้เล่นเผลอกด "เล่นต่อ" ก่อนโหลดเสร็จ
	-- แล้วกลายเป็น NewGame ทับเซฟ · ยิงพร้อมกันเหลือ ~1 round-trip ลดหน้าต่างนั้นลง (readFile ห่อ pcall+retry แล้ว)
	local files, oks, pending = {}, {}, MAX_SLOTS
	for slot = 1, MAX_SLOTS do
		task.spawn(function()
			files[slot], oks[slot] = readFile(userId, slot)
			pending -= 1
		end)
	end
	local t0 = os.clock()
	while pending > 0 and os.clock() - t0 < 12 do task.wait() end -- retry เพิ่มเวลา → เผื่อ 12s · ช่องที่ค้างนับเป็น failed
	local failed = {}
	for slot = 1, MAX_SLOTS do
		local sum = summarizeFile(files[slot])
		if sum then
			out[slot] = sum
		elseif oks[slot] ~= true then
			failed[slot] = true -- อ่านไม่สำเร็จ (error) หรือ timeout (ยัง pending) — ไม่ใช่ "ว่างจริง"
		end
	end
	return out, failed
end

return GameState
