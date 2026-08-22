-- Notify — toast มุมขวาล่างสไตล์ Win11 (เลื่อนเข้าจากขวา ซ้อนขึ้นบน หายเอง)
-- Notify.gain(follower, money) = ทีม auto ลงคลิป · Notify.sponsor / Notify.dm
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Audio = require(script.Parent.AudioService)

local Notify = {}

local HOLD = 4.5 -- วิ ก่อนหายเอง
local SLIDE = 0.28 -- วิ เลื่อนเข้า/ออก
local WIDTH, HEIGHT = 300, 74

local container = nil
local function ensureContainer()
	if container and container.Parent then return container end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_Notify"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50 -- เหนือ HUD ต่ำกว่า cutscene/dialogue
	gui.IgnoreGuiInset = true
	local frame = Instance.new("Frame") -- คอลัมน์ชิดขวาล่าง ซ้อนขึ้นบน
	frame.Name = "Stack"
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -16, 1, -16)
	frame.Size = UDim2.fromOffset(WIDTH, 600)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	gui.Parent = pg
	container = frame
	return frame
end

-- opts = { title, body, icon, accent, sound, soundVol, hold, action = { text, onClick } }
function Notify.push(opts)
	local stack = ensureContainer()

	local holder = Instance.new("Frame") -- layout คุมตำแหน่ง holder · card ข้างในเลื่อน/จางเอง
	holder.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = -os.clock() // 1 -- ใหม่สุดล่างสุด
	holder.ClipsDescendants = false
	holder.Parent = stack

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.Position = UDim2.fromScale(0.18, 0) -- เริ่มเยื้องขวา เดี๋ยว tween เข้า 0
	card.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 70, 80)
	stroke.Thickness = 1
	stroke.Transparency = 1
	stroke.Parent = card

	local accentBar = Instance.new("Frame") -- แถบสีซ้าย
	accentBar.Size = UDim2.new(0, 4, 1, -16)
	accentBar.Position = UDim2.fromOffset(8, 8)
	accentBar.BackgroundColor3 = opts.accent or Color3.fromRGB(90, 170, 90)
	accentBar.BackgroundTransparency = 1
	accentBar.BorderSizePixel = 0
	accentBar.Parent = card
	local abCorner = Instance.new("UICorner")
	abCorner.CornerRadius = UDim.new(1, 0)
	abCorner.Parent = accentBar

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromOffset(30, 30)
	iconLabel.Position = UDim2.fromOffset(20, 10)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = opts.icon or "🔔"
	iconLabel.TextSize = 24
	iconLabel.TextTransparency = 1
	iconLabel.Parent = card

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Position = UDim2.fromOffset(58, 12)
	titleLabel.Size = UDim2.fromOffset(WIDTH - 70, 22)
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	titleLabel.TextSize = 15
	titleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Text = opts.title or ""
	titleLabel.TextTransparency = 1
	titleLabel.Parent = card

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Position = UDim2.fromOffset(58, 36)
	bodyLabel.Size = UDim2.fromOffset(WIDTH - 70 - (opts.action and 84 or 0), 30) -- มีปุ่ม = หลบที่ให้ปุ่ม
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.FontFace = Font.fromEnum(Enum.Font.Gotham)
	bodyLabel.TextSize = 13
	bodyLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.TextWrapped = true
	bodyLabel.Text = opts.body or ""
	bodyLabel.TextTransparency = 1
	bodyLabel.Parent = card

	if opts.sound ~= false then
		Audio.sfx(opts.sound or "ui_click", nil, opts.soundVol or 0.4)
	end

	-- เลื่อนเข้า + จางขึ้น
	local ease = TweenInfo.new(SLIDE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(card, ease, { Position = UDim2.fromScale(0, 0), BackgroundTransparency = 0.05 }):Play()
	TweenService:Create(stroke, ease, { Transparency = 0 }):Play()
	TweenService:Create(accentBar, ease, { BackgroundTransparency = 0 }):Play()
	for _, l in { iconLabel, titleLabel, bodyLabel } do
		TweenService:Create(l, ease, { TextTransparency = 0 }):Play()
	end

	local dismissed = false
	local function dismiss()
		if dismissed then return end
		dismissed = true
		local out = TweenInfo.new(SLIDE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(card, out, { Position = UDim2.fromScale(0.3, 0), BackgroundTransparency = 1 }):Play()
		TweenService:Create(stroke, out, { Transparency = 1 }):Play()
		TweenService:Create(accentBar, out, { BackgroundTransparency = 1 }):Play()
		for _, l in { iconLabel, titleLabel, bodyLabel } do
			TweenService:Create(l, out, { TextTransparency = 1 }):Play()
		end
		task.delay(SLIDE, function() holder:Destroy() end)
	end

	local closeBtn = Instance.new("TextButton") -- คลิกที่ไหนบนการ์ด = ปิด
	closeBtn.Size = UDim2.fromScale(1, 1)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = ""
	closeBtn:SetAttribute("Sfx", "none")
	closeBtn.Parent = card
	closeBtn.Activated:Connect(dismiss)

	-- ★ ปุ่ม action ต้อง parent หลัง closeBtn — ลูกที่มาทีหลัง (ZIndex เท่ากัน) อยู่บนสุด กินคลิกก่อน
	if opts.action then
		local act = Instance.new("TextButton")
		act.Size = UDim2.fromOffset(74, 30)
		act.Position = UDim2.new(1, -84, 1, -37)
		act.BackgroundColor3 = opts.accent or Color3.fromRGB(90, 170, 90)
		act.TextColor3 = Color3.fromRGB(20, 20, 24)
		act.FontFace = Font.fromEnum(Enum.Font.GothamBold)
		act.TextSize = 14
		act.Text = opts.action.text or "รับ"
		act.AutoButtonColor = true
		act.Parent = card
		local ac = Instance.new("UICorner")
		ac.CornerRadius = UDim.new(0, 6)
		ac.Parent = act
		act.Activated:Connect(function()
			if dismissed then return end -- กันกดรัวสองที = ยิง action ซ้ำ
			if opts.action.onClick then opts.action.onClick() end
			dismiss()
		end)
	end

	task.delay(opts.hold or HOLD, dismiss)
end

function Notify.gain(followerDelta: number, moneyDelta: number?)
	local body = ("+%s follower"):format(tostring(followerDelta))
	if moneyDelta and moneyDelta > 0 then body ..= ("  ·  +฿%s"):format(tostring(moneyDelta)) end
	Notify.push({
		title = "ทีมลงคลิปให้",
		body = body,
		icon = "📈",
		accent = Color3.fromRGB(90, 190, 110),
		sound = "upload_done", soundVol = 0.35,
	})
end

-- งาน sponsor เข้า — กดรับ = buff เงินเริ่มทันที · ค้าง 12 วิ (ให้ทันตัดสินใจ) ปล่อยหาย = สละสิทธิ์
function Notify.sponsor(multText: string, onAccept)
	Notify.push({
		title = "💼 มีงาน sponsor เข้า!",
		body = ("กดรับ → เงินจากคลิป %s วันนี้"):format(multText),
		icon = "💰",
		accent = Color3.fromRGB(235, 175, 60),
		sound = "upload_done", soundVol = 0.45,
		hold = 12,
		action = { text = "รับงาน", onClick = onAccept },
	})
end

function Notify.dm(from: string, preview: string?)
	Notify.push({
		title = "DM ใหม่ · " .. from,
		body = preview or "",
		icon = "💬",
		accent = Color3.fromRGB(80, 150, 240),
		sound = "ui_click", soundVol = 0.5,
	})
end

return Notify
