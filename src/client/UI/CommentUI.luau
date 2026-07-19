-- CommentUI.luau — panel ตอบ comment (ช่องทางเดียวที่นับ choice % — design doc §6)
-- โชว์ปุ่มมุมขวาล่างเมื่อมี comment รอตอบ กดเปิด panel: ข้อความ + 3 ตัวเลือก
local isStudio = script ~= nil
local Comments = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.Comments)
	else require("../../shared/Content/Comments")

local CommentUI = {}

function CommentUI.init(playerGui, fireAction)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_Comments"
	gui.ResetOnSpawn = false

	local badge = Instance.new("TextButton")
	badge.Size = UDim2.new(0, 180, 0, 40)
	badge.Position = UDim2.new(1, -190, 1, -50)
	badge.BackgroundColor3 = Color3.fromRGB(80, 120, 255)
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.TextScaled = true
	badge.Visible = false
	badge.Parent = gui

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 420, 0, 220)
	panel.Position = UDim2.new(1, -430, 1, -280)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	panel.Visible = false
	panel.Parent = gui
	local commentLabel = Instance.new("TextLabel")
	commentLabel.Size = UDim2.new(1, -16, 0, 60)
	commentLabel.Position = UDim2.new(0, 8, 0, 8)
	commentLabel.BackgroundTransparency = 1
	commentLabel.TextColor3 = Color3.new(1, 1, 1)
	commentLabel.TextScaled = true
	commentLabel.TextWrapped = true
	commentLabel.Parent = panel
	local buttons = {}
	for i = 1, 3 do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -16, 0, 42)
		b.Position = UDim2.new(0, 8, 0, 60 + i * 48 - 40)
		b.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextScaled = true
		b.TextWrapped = true
		b.Parent = panel
		b.Activated:Connect(function()
			fireAction({ type = "AnswerComment", reply = i })
			panel.Visible = false
		end)
		buttons[i] = b
	end
	badge.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	gui.Parent = playerGui

	-- เรียกทุกครั้งที่ state มา (จาก Main.client)
	function CommentUI.update(state)
		local pending = state.pendingComments[1]
		badge.Visible = pending ~= nil
		badge.Text = pending and ("💬 comment รอตอบ (%d)"):format(#state.pendingComments) or ""
		if not pending then
			panel.Visible = false
			return
		end
		local c = Comments[pending.id]
		if not c then return end
		commentLabel.Text = c.text
		for i = 1, 3 do
			buttons[i].Text = c.replies[i].text
		end
	end
end

return CommentUI
