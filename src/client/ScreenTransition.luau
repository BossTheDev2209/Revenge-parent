-- ScreenTransition — จอดำ fade → onBlack (teleport/สลับของ) → ข้อความผ่าน DialogueUI → fade กลับ
-- ของกลาง reuse ได้: intro, เปลี่ยนเฟส, ending, ฉากรับรางวัล ฯลฯ
-- opts = { lines = {"..."}?, onBlack = fn?, fadeTime = 0.6?, onDone = fn? }
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local DialogueUI = require(script.Parent.UI.DialogueUI)

local ScreenTransition = {}
ScreenTransition.running = false

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
		local tin = TweenService:Create(black, TweenInfo.new(fadeTime), { BackgroundTransparency = 0 })
		tin:Play()
		tin.Completed:Wait()

		if opts.onBlack then opts.onBlack() end

		-- ข้อความ = reuse DialogueUI (บรรทัดไม่มี speaker) ดันให้อยู่เหนือจอดำ
		if opts.lines and #opts.lines > 0 and not DialogueUI.running then
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
		ScreenTransition.running = false
		if opts.onDone then opts.onDone() end
	end)
end

return ScreenTransition
