-- HUD.luau — placeholder HUD สร้างเอง (รอทีมสร้าง Gui_HUD จริงตาม docs/06 แล้วค่อยเปลี่ยน controller)
local HUD = {}

function HUD.init(playerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_HUD_Placeholder"
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 560, 0, 34)
	label.Position = UDim2.new(0, 8, 0, 8)
	label.BackgroundTransparency = 0.4
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = "รอ state..."
	label.Parent = gui
	gui.Parent = playerGui
	HUD.label = label
end

function HUD.update(state)
	HUD.label.Text = ("Follower %d | ฿%d | Mental %d%% | วัน %d %02d:00 | เฟส %d"):format(
		state.follower, state.money, math.floor(state.mental), state.day, state.timeOfDay, state.phase)
end

return HUD
