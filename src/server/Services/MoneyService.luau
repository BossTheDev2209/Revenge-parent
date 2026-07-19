-- MoneyService.luau — หักค่าใช้จ่ายราย 7 วันเกม (design doc §4)
-- เงินเข้าจากคลิปอยู่ FollowerService.uploadClip — ไฟล์นี้ดูแลรายจ่ายอย่างเดียว
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")

local MoneyService = {}

function MoneyService.weeklyTotal(phase: number): number
	local w = Config.WeeklyExpenses[phase]
	return w.rent + w.internet + w.food
end

-- เรียกจาก TimeService.onDay (wiring ใน Main) — คืน true ถ้าจ่ายไม่ไหว (Main ไปหัก mental ต่อ)
function MoneyService.onDay(state): boolean
	if state.day <= 1 or (state.day - 1) % 7 ~= 0 then return false end
	local total = MoneyService.weeklyTotal(state.phase)
	if state.money >= total then
		state.money -= total
		return false
	end
	state.money = 0
	state.flags.rentMissed = (state.flags.rentMissed or 0) + 1 -- Bad End 1 = ครบ 2 (EndingService ทีหลัง)
	return true
end

return MoneyService
