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

-- คลิปล่าสุดที่ยังไม่อัป (เป้าของ "Edit more")
function FollowerService.latestUnuploaded(state)
	for i = #state.clips, 1, -1 do
		if not state.clips[i].uploaded then return state.clips[i], i end
	end
	return nil, nil
end

-- client จบ QTE ส่งคะแนนมา (คะแนนไว้ใจ client ได้ — singleplayer)
-- action.redo = "Edit more" (PDF จอ 3): ตัดคลิปเดิมซ้ำ **ไม่สร้างคลิปใหม่** เก็บคะแนนสูงสุด
-- ราคาของการตัดซ้ำ = mental clipEdit -20 + นับ EditStreak5 อีกรอบ (Main ยิงให้ทุกครั้ง)
function FollowerService.finishEdit(state, action)
	local score = math.clamp(tonumber(action.score) or 0, 0, Config.MaxClipAccuracy)
	if action.redo then
		local clip = FollowerService.latestUnuploaded(state)
		if clip then
			clip.score = math.max(clip.score, score)
			clip.tier = Formulas.vidqTier(clip.score)
			clip.edits = (clip.edits or 1) + 1
			return
		end
		-- ไม่มีคลิปค้าง = ตัดใหม่ปกติ (กัน redo ลอย)
	end
	table.insert(state.clips, {
		tier = Formulas.vidqTier(score),
		score = score,
		uploaded = false,
		edits = 1,
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
