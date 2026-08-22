-- FollowerService — ตัดคลิป (รับคะแนน) + อัปคลิป (ได้ follower/เงิน)
-- ไม่ push / ไม่ require service อื่น — Main compose, mentalPct ส่งเข้ามาเป็น arg
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../shared/Formulas")

local FollowerService = {}

-- client จบ QTE ส่งคะแนนมา (เชื่อ client ได้ — singleplayer) → สร้างคลิป 1 ตัว
function FollowerService.finishEdit(state, action)
	local score = math.clamp(tonumber(action.score) or 0, 0, Config.MaxClipAccuracy)
	local footageGB = tonumber(action.footageGB) or Config.Record.footagePerClipGB
	table.insert(state.clips, {
		tier = Formulas.vidqTier(score),
		score = score,
		footageGB = footageGB,
		sizeMult = Formulas.clipSizeMult(footageGB),
		uploaded = false,
	})
end

-- อัปคลิป: follower = base × VidQ × mental × sizeMult · คืน (สำเร็จ, viral)
function FollowerService.uploadClip(state, action, mentalPct: number, rng)
	local clip = state.clips[tonumber(action.clip) or 0]
	if not clip or clip.uploaded then return false, false end
	local phase = Formulas.phaseFor(state.follower)
	local gained, viral = Formulas.followerGain(phase, clip.tier, mentalPct, rng)
	gained = math.floor(gained * (clip.sizeMult or 1))
	state.follower += gained
	-- buff sponsor คูณเฉพาะเงิน ไม่แตะ follower (สูตร follower ล็อก docs/02 §2)
	state.money += math.floor(Formulas.moneyGain(gained, phase) * Formulas.sponsorMult(state))
	state.phase = Formulas.phaseFor(state.follower)
	clip.uploaded = true
	clip.gained = gained
	clip.viral = viral
	clip.day = state.day -- ใช้คิด income/สัปดาห์ ในแอป Bank
	return true, viral
end

return FollowerService
