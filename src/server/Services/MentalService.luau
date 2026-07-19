-- MentalService.luau — หลอดใจ: drain + delta จาก action (design doc §3)
-- option ข: ยังไม่มี drain modifiers — รอ user ตัดสินอายุ (flag ใน docs/08 §4)
-- bar เข้าระบบตอน phase 2 (Config.Mental.introducedInPhase) — ก่อนนั้น no-op ทั้งไฟล์
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")

local MentalService = {}

-- 1%/4.5 วิจริง แปลงเป็นต่อชั่วโมงเกม (7.5 วิจริง)
MentalService.drainPerHour = Config.Mental.drainPercent
	* (Config.Time.secondsPerGameHour / Config.Mental.drainEverySeconds)

-- ค่า mental ที่สูตรควรใช้: ก่อน phase 2 คืน 50 (โซนกลาง ×1.0 — ไม่มีโบนัส/โทษ)
function MentalService.effective(state): number
	if state.phase < Config.Mental.introducedInPhase then return 50 end
	return state.mental
end

function MentalService.applyDelta(state, delta: number)
	if state.phase < Config.Mental.introducedInPhase then return end
	state.mental = math.clamp(state.mental + delta, 0, 100)
	if state.mental <= 0 then
		state.flags.mentalZero = true -- EndingService อ่านทีหลัง (Bad End 2)
	end
end

-- reason = key ใน Config.Mental.deltas (clipEdit / viralClip / rentMissed / ...)
function MentalService.apply(state, reason: string)
	local d = Config.Mental.deltas[reason]
	assert(d, "ไม่รู้จัก mental reason: " .. tostring(reason))
	MentalService.applyDelta(state, d)
end

function MentalService.onHour(state)
	MentalService.applyDelta(state, -MentalService.drainPerHour)
end

return MentalService
