-- StoryBeat.luau — orchestrator ของ 1 story beat: ล็อก player → (cutscene) → จอดำ+จัดฉาก → (dialogue) → จอดำ+เก็บฉาก → คืนคุม
-- ยิงตอน player เสียการควบคุมตามธรรมชาติ (ลุกจากเตียง/ลุกจากคอม) — ไม่เล่นกลางที่เดินอยู่
-- reuse engine เดิมทั้งหมด: CutscenePlayer(mode1) + ScreenTransition(จอดำ+hook) + DialogueUI(mode2) + InteractLock
--
-- ล็อกต่อเนื่องทั้ง beat ผ่าน InteractLock (ref-count) — DialogueUI ล็อก/ปลดข้างในเองก็ depth ไม่ตกถึง 0
-- gotcha: CutscenePlayer คุม WalkSpeed เอง + เคลียร์ MoveLocked ตอนจบ → relock() ย้ำหลัง cutscene ก่อนจอดำ
local isStudio = script ~= nil
local CutscenePlayer = if isStudio then require(script.Parent.UI.CutscenePlayer) else require("./UI/CutscenePlayer")
local ScreenTransition = if isStudio then require(script.Parent.ScreenTransition) else require("./ScreenTransition")
local DialogueUI = if isStudio then require(script.Parent.UI.DialogueUI) else require("./UI/DialogueUI")
local InteractLock = if isStudio then require(script.Parent.InteractLock) else require("./InteractLock")
local Players = game:GetService("Players")

local StoryBeat = {}
StoryBeat.running = false

local function hum()
	local char = Players.LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

-- ย้ำล็อกเดินหลัง cutscene (มันเคลียร์ MoveLocked ตอนจบ) — กันเดินหลุดใต้จอดำ
local function relock()
	local h = hum()
	if h then
		h:SetAttribute("MoveLocked", true)
		h.WalkSpeed, h.JumpPower = 0, 0
	end
end

-- เล่น 1 beat แบบ non-blocking (chain ผ่าน callback) — เรียกซ้ำระหว่างเล่นไม่ได้ (กันซ้อน)
-- opts = {
--   cutscene = steps?,   -- CutscenePlayer step list (ไม่ใส่ = ข้ามช่วงหนัง)
--   stage    = fn()?,    -- ทำใต้จอดำ "ก่อน" dialogue: วาป player/จัดตัวละครเข้าฉาก (ยิง server ผ่าน caller)
--   dialogue = lines?,   -- DialogueUI lines (ไม่ใส่ = ข้ามช่วงคุย)
--   settle   = fn()?,    -- ทำใต้จอดำ "หลัง" dialogue: ตั้ง npcLoc/เก็บฉากท่าสุดท้าย
--   stageLines/settleLines = {..}?, -- ข้อความบนจอดำแต่ละช่วง (ว่าง = ดำเฉยๆ)
--   onDone = fn()?,      -- จบ beat คืนคุมแล้ว
-- }
function StoryBeat.play(playerGui, opts)
	if StoryBeat.running then return end
	StoryBeat.running = true
	opts = opts or {}
	InteractLock.lock() -- ถือยาวทั้ง beat · ปลดทีเดียวตอนจบ

	local function finish()
		InteractLock.unlock()
		StoryBeat.running = false
		if opts.onDone then opts.onDone() end
	end

	local function afterDialogue()
		ScreenTransition.play({ lines = opts.settleLines, onBlack = opts.settle, onDone = finish })
	end

	local function afterCutscene()
		relock() -- cutscene เคลียร์ MoveLocked ไป — ย้ำก่อนจอดำ
		ScreenTransition.play({
			lines = opts.stageLines,
			onBlack = opts.stage,
			onDone = function()
				if opts.dialogue then
					DialogueUI.show(playerGui, opts.dialogue, afterDialogue)
				else
					afterDialogue()
				end
			end,
		})
	end

	if opts.cutscene then
		CutscenePlayer.play(playerGui, opts.cutscene, afterCutscene)
	else
		afterCutscene()
	end
end

return StoryBeat
