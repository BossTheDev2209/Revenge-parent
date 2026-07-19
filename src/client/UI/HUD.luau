-- HUD.luau — UI ติดจอตลอดเวลา (PDF หน้า 5 "UI ทั้งหมด")
-- บนซ้าย: follower + เงิน | บนขวา: เวลา/วัน | ขวา: mental bar แนวตั้ง | ล่างซ้าย: storage + กล้อง
-- placeholder หน้าตา — ทีมทำสวยแทนได้ ขอแค่คง function init/update
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")

local HUD = {}

local function box(parent, x, y, w, h, bg)
	local f = Instance.new("Frame")
	f.Position = UDim2.new(x[1], x[2], y[1], y[2])
	f.Size = UDim2.new(0, w, 0, h)
	f.BackgroundColor3 = bg or Color3.fromRGB(20, 20, 30)
	f.BackgroundTransparency = 0.25
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = f
	return f
end

local function label(parent, text)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -12, 1, 0)
	l.Position = UDim2.new(0, 6, 0, 0)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

function HUD.init(playerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_HUD"
	gui.ResetOnSpawn = false

	HUD.followerLabel = label(box(gui, { 0, 8 }, { 0, 8 }, 190, 34), "👤 0")
	HUD.moneyLabel = label(box(gui, { 0, 8 }, { 0, 48 }, 190, 34), "💰 ฿0")
	HUD.clockLabel = label(box(gui, { 1, -178 }, { 0, 8 }, 170, 34), "วัน 1 | 08:00")
	HUD.phaseLabel = label(box(gui, { 1, -178 }, { 0, 48 }, 170, 34), "เฟส 1")
	HUD.storageLabel = label(box(gui, { 0, 8 }, { 1, -132 }, 210, 34), "🎬 คลิป 0")
	HUD.cameraLabel = label(box(gui, { 0, 8 }, { 1, -92 }, 210, 34), "📷 720p")

	-- mental bar แนวตั้ง ขวากลางจอ
	local barBack = box(gui, { 1, -34 }, { 0.5, -120 }, 22, 240, Color3.fromRGB(15, 15, 20))
	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.new(0, 2, 1, -2)
	fill.Size = UDim2.new(1, -4, 0.8, 0)
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
	fill.Parent = barBack
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 6)
	fc.Parent = fill
	local heart = Instance.new("TextLabel")
	heart.Size = UDim2.new(0, 30, 0, 24)
	heart.Position = UDim2.new(1, -38, 0.5, -146)
	heart.BackgroundTransparency = 1
	heart.Text = "❤️"
	heart.TextScaled = true
	heart.Parent = gui
	HUD.mentalFill = fill

	gui.Parent = playerGui
end

function HUD.update(state)
	HUD.followerLabel.Text = ("👤 %s"):format(tostring(state.follower))
	HUD.moneyLabel.Text = ("💰 ฿%s"):format(tostring(state.money))
	HUD.clockLabel.Text = ("วัน %d | %02d:00"):format(state.day, state.timeOfDay)
	HUD.phaseLabel.Text = ("เฟส %d"):format(state.phase)
	HUD.storageLabel.Text = ("🎬 คลิป %d"):format(#state.clips)
	HUD.cameraLabel.Text = ("📷 %s"):format(Config.ResolutionLadder[state.upgrades.camera] or "?")

	local pct = math.clamp(state.mental, 0, 100) / 100
	HUD.mentalFill.Size = UDim2.new(1, -4, pct, 0)
	-- สีตามโซน (design doc §3): เขียว ≥70 / เหลือง 40-69 / แดง <40
	HUD.mentalFill.BackgroundColor3 = state.mental >= 70 and Color3.fromRGB(80, 220, 120)
		or state.mental >= 40 and Color3.fromRGB(240, 200, 80)
		or Color3.fromRGB(230, 80, 80)
end

return HUD
