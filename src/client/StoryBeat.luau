-- StoryBeat — orchestrator ของ 1 beat: ล็อก player → (cutscene) → จอดำ+จัดฉาก → (dialogue) → จอดำ+เก็บฉาก → คืนคุม
-- reuse: CutscenePlayer + ScreenTransition + DialogueUI + InteractLock · ล็อกต่อเนื่องทั้ง beat (ref-count)
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

-- เล่น 1 beat non-blocking (chain ผ่าน callback) — เรียกซ้ำระหว่างเล่นไม่ได้
-- opts: preStage/stage/settle = fn() ทำใต้จอดำแต่ละช่วง · cutscene = steps · dialogue = lines
--   runDialogue = fn(lines, onDone) ตัวเล่นบท (ไม่ใส่ = DialogueUI.show เปล่าๆ)
--   preStageLines/stageLines/settleLines = ข้อความบนจอดำ · onDone = จบ beat
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
		relock()
		ScreenTransition.play({
			lines = opts.stageLines,
			onBlack = opts.stage,
			onDone = function()
				if opts.dialogue then
					if opts.runDialogue then
						opts.runDialogue(opts.dialogue, afterDialogue)
					else
						DialogueUI.show(playerGui, opts.dialogue, afterDialogue)
					end
				else
					afterDialogue()
				end
			end,
		})
	end

	local function startCutscene()
		if opts.cutscene then
			CutscenePlayer.play(playerGui, opts.cutscene, afterCutscene)
		else
			afterCutscene()
		end
	end

	if opts.preStage then
		ScreenTransition.play({ lines = opts.preStageLines, onBlack = opts.preStage, onDone = startCutscene })
	else
		startCutscene()
	end
end

return StoryBeat
