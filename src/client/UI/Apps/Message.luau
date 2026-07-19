-- Message.luau — DM viewer (design doc §6: script ตายตัว ไม่มีผลต่อ ending) — อ่านอย่างเดียว
local isStudio = script ~= nil
local DMs = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.DMs)
	else require("../../../shared/Content/DMs")

local Message = {}

function Message.create(frame, deps)
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Text = "✉️ Messages"
	title.Parent = frame

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 8, 0, 40)
	list.Size = UDim2.new(1, -16, 1, -48)
	list.BackgroundTransparency = 1
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list

	for _, dm in DMs do
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -8, 0, 30 + #dm.lines * 26)
		l.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		l.TextScaled = true
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = ("【%s】\n%s"):format(dm.from, table.concat(dm.lines, "\n"))
		l.Parent = list
	end

	return {}
end

return Message
