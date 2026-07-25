-- EndingService.luau — ตัดสิน ending (design doc §5)
-- priority: จบแล้ว → Bad1 (เงิน/ไล่ที่ ×2) → Bad2 (mental 0) → ถึง 1M ค่อยเข้าสูตร % → ยังไม่จบ
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../shared/Formulas")

local EndingService = {}

-- แปลง state → stats หน่วย % ตรงกับ Config.EndingThresholds
function EndingService.computeStats(state)
	local counts = { C = 0, B = 0, A = 0, S = 0 }
	local n = 0
	for _, clip in state.clips do
		counts[clip.tier] += 1
		n += 1
	end
	-- คลิปทีมนับครึ่งเดียว (docs/02 §9.8) — ทีมช่วยดันเกรดได้ แต่ ending ยังสะท้อนฝีมือ player
	local w = Config.Staff.vidqWeight
	for _, clip in state.staffClips or {} do
		counts[clip.tier] += w
		n += w
	end
	local vidq = {}
	for tier, k in counts do
		vidq[tier] = n > 0 and (k / n * 100) or 0
	end
	local ch = state.choices
	local total = ch.pos + ch.neu + ch.neg
	local choice = {
		pos = total > 0 and (ch.pos / total * 100) or 0,
		neu = total > 0 and (ch.neu / total * 100) or 0,
		neg = total > 0 and (ch.neg / total * 100) or 0,
	}
	return { vidq = vidq, choice = choice }
end

-- คืนชื่อ ending ("Bad1".."Good1") หรือ nil ถ้าเกมยังไม่จบ — Main เรียกหลังทุก action/วันใหม่
function EndingService.check(state)
	if state.flags.ending then return nil end -- จบไปแล้ว ไม่ trigger ซ้ำ
	if (state.flags.rentMissed or 0) >= 2 then return "Bad1" end
	if state.flags.mentalZero then return "Bad2" end
	local lastGate = Config.PhaseGates[#Config.PhaseGates].max
	if state.follower >= lastGate then
		return Formulas.resolveEnding(EndingService.computeStats(state))
	end
	return nil
end

return EndingService
