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
		upgrades = { camera = 1, storage = 1 },
		calendar = {}, -- [day] = {type=..., id=...}
		flags = {},    -- canon event ที่ผ่านแล้ว
		activity = { streak = 0, cooldownUntilDay = 0 }, -- ฟื้นใจติดกัน 3 ครั้ง → cooldown
		slot = 1,
		savedAt = 0,
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

-- ข้อมูลย่อไว้โชว์หน้า save select (Main Menu)
function GameState.slotSummary(state)
	return {
		follower = state.follower,
		day = state.day,
		phase = Formulas.phaseFor(state.follower),
		savedAt = state.savedAt,
	}
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

-- ทุกจุดแตะ DataStore ห่อ pcall — fail = warn + เล่นต่อ (Edit mode fail เป็นเรื่องปกติ)
function GameState.saveSlot(userId: number, state)
	state.savedAt = os.time()
	local ok, err = pcall(function()
		store():SetAsync(userId .. "_" .. state.slot, state)
	end)
	if ok then dirty = false else warn("[GameState] save ไม่สำเร็จ:", err) end
	return ok
end

function GameState.loadSlot(userId: number, slot: number)
	local ok, data = pcall(function()
		return store():GetAsync(userId .. "_" .. slot)
	end)
	if not ok or data == nil then return nil end
	data.slot = slot
	return GameState.mergeDefaults(data, GameState.newGame())
end

-- คืน {[slot] = summary} เฉพาะ slot ที่มี save — หน้า Main Menu ใช้ (Continue = savedAt มากสุด)
function GameState.listSlots(userId: number)
	local out = {}
	for slot = 1, MAX_SLOTS do
		local data = GameState.loadSlot(userId, slot)
		if data then out[slot] = GameState.slotSummary(data) end
	end
	return out
end

return GameState
