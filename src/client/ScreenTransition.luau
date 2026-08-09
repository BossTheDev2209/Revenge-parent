-- ScreenTransition — จอดำ fade → (เล่าเรื่องบนจอดำ) → onBlack (teleport/สลับของ) → fade กลับ
-- ของกลาง reuse ได้: intro, เปลี่ยนเฟส, ending, ฉากรับรางวัล ฯลฯ
-- opts = {
--   steps = {..}?,   -- timed narration บนจอดำ (Genshin/HSR: text ขึ้นกลางจอ auto-advance ไม่ต้องคลิก) — ดู VALID_STEP
--   lines = {"..."}?, -- (เดิม) DialogueUI คลิกต่อ — steps ทับ lines ถ้าใส่ทั้งคู่
--   onBlack = fn?,    -- ทำตอนจอดำสนิท (หลังเล่าเรื่องจบ) — teleport/สลับแมพ
--   fadeTime = 0.6?, onDone = fn?,
-- }
-- step (ยึด field ไม่ใช่ type):
--   { text="...", t=วินาที? }   narration ขึ้นกลางจอ (ไม่ใส่ t = ค้างจนมี step ถัดไป)
--   { dialogue={..lines..}, voice=? }  กล่องข้อความ DialogueUI แทรก (reuse — คลิกต่อ) เช่น เจียเจียพูดกลางฉากดำ
--   { t=วินาที }                หน่วงเวลาเปล่า
--   [date] ฯลฯ ต้อง substitute ก่อนส่งเข้ามา (ที่นี่ไม่รู้ state)
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local DialogueUI = require(script.Parent.UI.DialogueUI)
local Audio = require(script.Parent.AudioService)

local ScreenTransition = {}
ScreenTransition.running = false

-- เช็ค steps ก่อนเล่น (คล้าย engine อื่น) — คืน (ผ่านไหม, error)
-- ยึด field ไม่ใช่ type:
--   text(string) = narration ขึ้นกลางจอ · dialogue(table) = กล่องข้อความ DialogueUI แทรก (reuse engine) · t(number) = หน่วงเวลา
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
	black.Size = UDim2.new(1, 0, 1, 0)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.Parent = gui
	gui.Parent = playerGui

	task.spawn(function()
		Audio.lockBGM(true) -- ห้ามโซนสั่งเพลงระหว่าง transition (วาปเข้าโซนใหม่ = เพลงจะเด้งกลางฉาก)
		Audio.bgm(nil)      -- ดับเพลงที่ค้างมาก่อนหน้า

		local tin = TweenService:Create(black, TweenInfo.new(fadeTime), { BackgroundTransparency = 0 })
		tin:Play()
		tin.Completed:Wait()

		if opts.onBlack then opts.onBlack() end -- ก่อนเล่าเรื่อง: teleport/สลับแมพ (แมพใหม่ stream ระหว่างเล่า)

		-- เล่าเรื่องบนจอดำ (auto-timed ไม่ต้องคลิก) — text ขึ้นกลางจอ ขอบดำรอบตัวอักษร
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
				label.Parent = black
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = 2
				stroke.Color = Color3.new(0, 0, 0)
				stroke.Transparency = 0.4
				stroke.Parent = label
				for _, s in opts.steps do
					if type(s.dialogue) == "table" then
						-- กล่องข้อความแทรก (reuse DialogueUI) — ซ่อน narration, คุยจบ (คลิกต่อ) แล้วเล่าต่อ
						label.Visible = false
						local done = false
						DialogueUI.show(playerGui, s.dialogue, function() done = true end, s.voice)
						local dg = playerGui:FindFirstChild("Gui_Dialogue")
						if dg then dg.DisplayOrder = 101 end
						while not done do task.wait() end
						label.Visible = true
					elseif type(s.text) == "string" then
						label.Text = s.text
						if s.t then task.wait(s.t) end
					elseif s.t then
						task.wait(s.t)
					end
				end
			end
		-- (เดิม) DialogueUI คลิกต่อ — ใช้เมื่อไม่ใส่ steps
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
		Audio.lockBGM(false) -- คืนสิทธิ์ให้โซนคุมเพลงต่อ (โซนใหม่จะเริ่มเพลงหลังฉากจบ)
		ScreenTransition.running = false
		if opts.onDone then opts.onDone() end
	end)
end

return ScreenTransition
