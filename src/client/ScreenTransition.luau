-- ScreenTransition — จอดำ fade → (เล่าเรื่องบนจอดำ) → onBlack (teleport/สลับของ) → fade กลับ
-- ใช้ซ้ำ: intro, เปลี่ยนเฟส, ending, ฉากรับรางวัล
-- opts: steps = timed narration (auto-advance) · lines = DialogueUI คลิกต่อ (steps ทับ lines)
--   onBlack = fn ตอนจอดำสนิท · fadeTime = 0.6 · onDone = fn
-- step (ยึด field): { text, t? } narration · { dialogue, voice? } กล่อง DialogueUI แทรก · { t } หน่วงเวลา
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local DialogueUI = require(script.Parent.UI.DialogueUI)
local Audio = require(script.Parent.AudioService)
local InteractLock = require(script.Parent.InteractLock)

local ScreenTransition = {}
ScreenTransition.running = false

-- เช็ค steps ก่อนเล่น — คืน (ผ่านไหม, error) · ยึด field: text/dialogue/t
function ScreenTransition.validateSteps(steps)
	if type(steps) ~= "table" then return false, "ไม่ใช่ตาราง" end
	for i, s in steps do
		if type(s) ~= "table" then return false, ("step %d: ต้องเป็นตาราง"):format(i) end
		if type(s.text) == "string" then
			if s.t ~= nil and type(s.t) ~= "number" then return false, ("step %d: t ต้องเป็นตัวเลข"):format(i) end
		elseif type(s.dialogue) == "table" then
			local ok, err = DialogueUI.validate(s.dialogue)
			if not ok then return false, ("step %d dialogue > %s"):format(i, err) end
		elseif type(s.t) ~= "number" then
			return false, ("step %d: ต้องมี text / dialogue / t"):format(i)
		end
	end
	return true
end

function ScreenTransition.play(opts)
	if ScreenTransition.running then return end
	ScreenTransition.running = true
	opts = opts or {}
	local fadeTime = opts.fadeTime or 0.6
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_Transition"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false
	local black = Instance.new("Frame")
	-- overshoot 40px บน-ล่าง กัน topbar/gui inset โผล่ (IgnoreGuiInset บางทีไม่พอ)
	black.Position = UDim2.new(0, 0, 0, -40)
	black.Size = UDim2.new(1, 0, 1, 80)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.Parent = gui
	gui.Parent = playerGui

	task.spawn(function()
		InteractLock.lock() -- ล็อกเดิน + ปิด prompt ตลอด transition (ref-count ซ้อน DialogueUI ได้)
		Audio.lockBGM(true) -- ห้ามโซนสั่งเพลงระหว่าง transition (วาปเข้าโซนใหม่ = เพลงเด้งกลางฉาก)
		Audio.bgm(nil)      -- ดับเพลงที่ค้างมาก่อนหน้า

		local tin = TweenService:Create(black, TweenInfo.new(fadeTime), { BackgroundTransparency = 0 })
		tin:Play()
		tin.Completed:Wait()

		if opts.onBlack then opts.onBlack() end -- teleport/สลับแมพ (แมพใหม่ stream ระหว่างเล่า)

		-- เล่าเรื่องบนจอดำ (auto-timed) — text ขึ้นกลางจอ ขอบดำรอบตัวอักษร
		if opts.steps and #opts.steps > 0 then
			local ok, err = ScreenTransition.validateSteps(opts.steps)
			if not ok then
				warn("[ScreenTransition] steps พัง:", err)
			else
				local label = Instance.new("TextLabel")
				label.Size = UDim2.new(0.8, 0, 0.3, 0)
				label.Position = UDim2.new(0.1, 0, 0.35, 0)
				label.BackgroundTransparency = 1
				label.TextColor3 = Color3.new(1, 1, 1)
				label.TextScaled = true
				label.TextWrapped = true
				label.TextXAlignment = Enum.TextXAlignment.Center
				label.Text = ""
				label.TextTransparency = 1 -- เริ่มซ่อน ค่อย fade เข้า
				label.Parent = black
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = 2
				stroke.Color = Color3.new(0, 0, 0)
				stroke.Transparency = 1
				stroke.Parent = label

				-- fade ตัวอักษร (to=0 โผล่ / to=1 หาย) — รอจบก่อนไปต่อ ให้แต่ละข้อความสลับกันนุ่ม
				local TEXT_FADE = 0.35
				local function fadeText(to: number)
					local strokeTo = to < 0.5 and 0.4 or 1
					local a = TweenService:Create(label, TweenInfo.new(TEXT_FADE), { TextTransparency = to })
					local b = TweenService:Create(stroke, TweenInfo.new(TEXT_FADE), { Transparency = strokeTo })
					a:Play()
					b:Play()
					a.Completed:Wait()
				end

				local hasText = false
				for _, s in opts.steps do
					if type(s.dialogue) == "table" then
						-- กล่องข้อความแทรก (reuse DialogueUI) — ซ่อน narration ก่อน คุยจบแล้วเล่าต่อ
						if hasText then fadeText(1) hasText = false end
						local done = false
						DialogueUI.show(playerGui, s.dialogue, function() done = true end, s.voice)
						local dg = playerGui:FindFirstChild("Gui_Dialogue")
						if dg then dg.DisplayOrder = 101 end
						while not done do task.wait() end
					elseif type(s.text) == "string" then
						if hasText then fadeText(1) end -- อันเก่า fade หายก่อน
						label.Text = s.text
						fadeText(0)                     -- อันใหม่ fade เข้า
						hasText = true
						if s.t then task.wait(s.t) end
					elseif s.t then
						task.wait(s.t)
					end
				end
				if hasText then fadeText(1) end -- ข้อความสุดท้าย fade ก่อน bg (กันเห็นแมพทั้งที่ text ยังอยู่)
			end
		elseif opts.lines and #opts.lines > 0 and not DialogueUI.running then
			local done = false
			DialogueUI.show(playerGui, opts.lines, function() done = true end)
			local dg = playerGui:FindFirstChild("Gui_Dialogue")
			if dg then dg.DisplayOrder = 101 end
			while not done do task.wait() end
		end

		local tout = TweenService:Create(black, TweenInfo.new(fadeTime), { BackgroundTransparency = 1 })
		tout:Play()
		tout.Completed:Wait()
		gui:Destroy()
		Audio.lockBGM(false) -- คืนสิทธิ์ให้โซนคุมเพลงต่อ
		InteractLock.unlock()
		ScreenTransition.running = false
		if opts.onDone then opts.onDone() end
	end)
end

return ScreenTransition
