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

return GameState
