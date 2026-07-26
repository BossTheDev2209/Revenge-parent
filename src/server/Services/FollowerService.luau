-- FollowerService.luau — ตัดคลิป(รับคะแนน) + อัปคลิป(ได้ follower/เงิน)
-- ไม่เรียก push / ไม่ require service อื่น — Main compose (mentalPct ส่งเข้ามาเป็น arg)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../shared/Formulas")

local FollowerService = {}

-- client จบ QTE ส่งคะแนนมา (คะแนนไว้ใจ client ได้ — singleplayer)
-- ปุ่ม "Edit more" บนจอสรุป = ตัด**คลิปใหม่**ต่อทันที ไม่ต้องออกไปเปิดแอปใหม่
-- → ฝั่ง server เหมือนกันทุกรอบ: 1 รอบ QTE = 1 คลิปใหม่ + ใจ −20 (Main ยิง clipEdit ให้)
function FollowerService.finishEdit(state, action)
	local score = math.clamp(tonumber(action.score) or 0, 0, Config.MaxClipAccuracy)
	table.insert(state.clips, {
		tier = Formulas.vidqTier(score),
		score = score,
		uploaded = false,
	})
end

-- อัปคลิป: follower = base(เฟสปัจจุบัน) × VidQ × mental แล้วอัปเดตเงิน/เฟส
-- คืน (สำเร็จไหม, viral ไหม) — viral แล้ว Main ไปบวก mental ต่อ
function FollowerService.uploadClip(state, action, mentalPct: number, rng)
	local clip = state.clips[tonumber(action.clip) or 0]
	if not clip or clip.uploaded then return false, false end
	local phase = Formulas.phaseFor(state.follower)
	local gained, viral = Formulas.followerGain(phase, clip.tier, mentalPct, rng)
	state.follower += gained
	state.money += Formulas.moneyGain(gained, phase)
	state.phase = Formulas.phaseFor(state.follower)
	clip.uploaded = true
	clip.gained = gained
	clip.viral = viral
	return true, viral
end

return FollowerService
