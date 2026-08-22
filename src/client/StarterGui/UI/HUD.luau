-- HUD — UI ติดจอตลอด: follower/money + progress เฟส · นาฬิกา/ปฏิทิน · storage/กล้อง · mental bar · hotbar
-- กล่องที่ยังไม่มีรูป (UIAssets คีย์ว่าง) = กล่องสีทึบ + emoji
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../../shared/Formulas")
local UIAssets = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.UIAssets)
	else require("../../../shared/UIAssets")

local HUD = {}

-- นาฬิกา + ดวงอาทิตย์เดินลื่น: server tick รายชั่วโมง → client interpolate float ต่อเฟรม
-- หยุดเมื่อ state.frozen · cap ที่ :59 จนกว่า server จะ tick ชั่วโมงถัดไป (กันวิ่งล้ำ)
local Lighting = game:GetService("Lighting")
local SPGH = Config.Time.secondsPerGameHour
HUD.gameHour = nil -- ชั่วโมงเกมแบบ float
HUD.serverHour = nil -- ชั่วโมง integer ล่าสุดจาก server
HUD.frozen = false
-- หลอดใจ: server ผลัก state.mental มาทุก 1 วิ (MentalService.tickDrain) แต่ยัง "ก้อน" อยู่ดี (network tick)
-- ★ แก้ 10 ส.ค. (user: "guiหลอดก็ไม่ค่อยสมูท") — ไล่ตาม server แบบ exponential follow ทุกเฟรมแทนการ snap ตรงๆ
-- (เทคนิคเดียวกับ HUD.gameHour ด้านบน — client interpolate ระหว่าง server tick ให้ลื่นตา)
HUD.mentalDisplay = nil -- ค่าที่ GUI วาดจริง (float, ไล่ตาม HUD.mentalServer)
HUD.mentalServer = nil -- ค่าจริงล่าสุดจาก server
local MENTAL_FOLLOW_SPEED = 6 -- ต่อวิ — ไล่ทัน gap ปกติ (~0.67%/วิ) ภายใน <1 วิ แต่ยังเห็นเป็นการไหล ไม่ใช่กระตุก

game:GetService("RunService").Heartbeat:Connect(function(dt)
	if HUD.serverHour == nil then return end
	if not HUD.frozen then
		HUD.gameHour = math.min(HUD.gameHour + dt / SPGH, HUD.serverHour + 59 / 60)
	end
	-- SceneClock (ตั้งโดย cutscene/dialogue "time") = ล็อกดวงอาทิตย์ให้ฉาก · nil = เดินตามเวลาปกติ
	local sceneClock = Lighting:GetAttribute("SceneClock")
	Lighting.ClockTime = (sceneClock or HUD.gameHour) % 24
	if HUD.clockLabel then
		local h = math.floor(HUD.gameHour) % 24
		local m = math.floor((HUD.gameHour - math.floor(HUD.gameHour)) * 60)
		HUD.clockLabel.Text = ("%02d:%02d"):format(h, m)
	end

	if HUD.mentalServer and HUD.mentalFill then
		HUD.mentalDisplay = HUD.mentalDisplay
			+ (HUD.mentalServer - HUD.mentalDisplay) * math.min(dt * MENTAL_FOLLOW_SPEED, 1)
		local pct = math.clamp(HUD.mentalDisplay, 0, 100) / 100
		local w = HUD.mentalFill.Size.X
		HUD.mentalFill.Size = UDim2.new(w.Scale, w.Offset, pct, 0)
		HUD.mentalFill.BackgroundColor3 = HUD.mentalDisplay >= 70 and Color3.fromRGB(80, 220, 120)
			or HUD.mentalDisplay >= 40 and Color3.fromRGB(240, 200, 80)
			or Color3.fromRGB(230, 80, 80)
	end
end)

-- ขนาด/ตำแหน่งอ้างภาพร่าง (แก้ที่เดียว)
local STAT_W, STAT_H = 210, 46 -- กล่อง follower / money
local BAR_W, BAR_H = 470, 22 -- แถบ progress
local SIDE_W, SIDE_H = 230, 40 -- กล่อง storage / กล้อง
local SIDE_Y = 0.40
local MENTAL_W = 26
local MENTAL_TOP, MENTAL_BOT = 0.22, 0.86

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = inst
	return c
end

local function panel(parent, pos, size, bg)
	local f = Instance.new("Frame")
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = bg or Color3.fromRGB(20, 20, 30)
	f.BackgroundTransparency = 0.25
	f.Parent = parent
	corner(f)
	return f
end

-- ไอคอนช่องซ้าย: รูปจาก UIAssets ถ้ามี ไม่มีก็ emoji
local function statLabel(parent, assetKey, fallbackEmoji, text)
	local iconId = UIAssets[assetKey] or ""
	local pad = 8
	if iconId ~= "" then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.new(0, 28, 0, 28)
		img.Position = UDim2.new(0, 8, 0.5, -14)
		img.BackgroundTransparency = 1
		img.Image = iconId
		img.Parent = parent
		pad = 44
	end
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -pad - 8, 1, -8)
	l.Position = UDim2.new(0, pad, 0, 4)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = (iconId ~= "" and "" or fallbackEmoji .. " ") .. text
	l.Parent = parent
	l:SetAttribute("prefix", iconId ~= "" and "" or fallbackEmoji .. " ")
	return l
end

local function setStat(l: TextLabel?, text: string)
	if not l then return end
	l.Text = (l:GetAttribute("prefix") or "") .. text
end

-- 1,024 แบบ PDF (pure)
function HUD.comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- แถบ progress สู่ 1M ไม่ linear: เฟส 10%/40%/50% (linear เฟส 1 จะกินแค่ 1% ผู้เล่นรู้สึกไม่ขยับ)
function HUD.progressPct(follower: number): number
	local f = math.max(0, follower)
	if f < 10_000 then return f / 10_000 * 0.10 end
	if f < 100_000 then return 0.10 + (f - 10_000) / 90_000 * 0.40 end
	return math.min(1, 0.50 + (f - 100_000) / 900_000 * 0.50)
end

-- build() = สร้างโครงจากศูนย์ | init() = ใช้ของจริงใน StarterGui ถ้ามี (ทีมแก้หน้าตาใน Studio ได้)
-- ชื่อ instance ที่โค้ดอ้าง ห้ามเปลี่ยน: FollowerLabel MoneyLabel PhaseLabel ProgressFill ClockLabel DayLabel StorageLabel CameraLabel MentalFill
function HUD.build(parent): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_HUD"
	gui.ResetOnSpawn = false
	gui.Enabled = false -- เริ่มซ่อน — เมนูค่อยเปิด HUD ตอนกดเล่น (กันแฟลชทับฉากเมนู)

	-- บนกลาง: follower + money เรียงข้างกัน
	local half = STAT_W + 5
	local fBox = panel(gui, UDim2.new(0.5, -half, 0, 10), UDim2.new(0, STAT_W, 0, STAT_H))
	local mBox = panel(gui, UDim2.new(0.5, 5, 0, 10), UDim2.new(0, STAT_W, 0, STAT_H))
	fBox.Name = "FollowerBox"
	mBox.Name = "MoneyBox"
	HUD.followerLabel = statLabel(fBox, "hud_follower", "👤", "0")
	HUD.moneyLabel = statLabel(mBox, "hud_money", "💰", "฿0")
	HUD.followerLabel.Name = "FollowerLabel"
	HUD.moneyLabel.Name = "MoneyLabel"
	HUD.statTopY = 10 + STAT_H

	-- แถบ progress ใต้กล่องทั้งสอง
	local track = panel(gui, UDim2.new(0.5, -BAR_W / 2, 0, 10 + STAT_H + 6),
		UDim2.new(0, BAR_W, 0, BAR_H), Color3.fromRGB(15, 15, 20))
	track.Name = "ProgressTrack"
	local pfill = Instance.new("Frame")
	pfill.Name = "ProgressFill"
	pfill.Size = UDim2.new(0, 0, 1, -6)
	pfill.Position = UDim2.new(0, 3, 0, 3)
	pfill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
	pfill.Parent = track
	corner(pfill, 6)
	for _, m in { 10_000, 100_000 } do -- ขีดรอยต่อเฟส
		local tick = Instance.new("Frame")
		tick.Size = UDim2.new(0, 2, 1, 0)
		tick.Position = UDim2.new(HUD.progressPct(m), 0, 0, 0)
		tick.BackgroundColor3 = Color3.new(1, 1, 1)
		tick.BorderSizePixel = 0
		tick.Parent = track
	end
	HUD.phaseLabel = Instance.new("TextLabel")
	HUD.phaseLabel.Name = "PhaseLabel"
	HUD.phaseLabel.Size = UDim2.new(1, -8, 1, 0)
	HUD.phaseLabel.Position = UDim2.new(0, 4, 0, 0)
	HUD.phaseLabel.BackgroundTransparency = 1
	HUD.phaseLabel.TextColor3 = Color3.new(1, 1, 1)
	HUD.phaseLabel.TextStrokeTransparency = 0.4
	HUD.phaseLabel.TextSize = 14
	HUD.phaseLabel.Text = "Phase 1"
	HUD.phaseLabel.Parent = track
	local goal = Instance.new("TextLabel")
	goal.Size = UDim2.new(0, 60, 0, BAR_H)
	goal.Position = UDim2.new(0.5, BAR_W / 2 + 6, 0, 10 + STAT_H + 6)
	goal.BackgroundTransparency = 1
	goal.TextColor3 = Color3.new(1, 1, 1)
	goal.TextStrokeTransparency = 0.5
	goal.TextScaled = true
	goal.TextXAlignment = Enum.TextXAlignment.Left
	goal.Text = "1M"
	goal.Parent = gui
	HUD.progressFill = pfill

	-- บนขวา: นาฬิกา + ป้ายปฏิทิน
	HUD.clockLabel = Instance.new("TextLabel")
	HUD.clockLabel.Name = "ClockLabel"
	HUD.clockLabel.Size = UDim2.new(0, 110, 0, 40)
	HUD.clockLabel.Position = UDim2.new(1, -186, 0, 12)
	HUD.clockLabel.BackgroundTransparency = 1
	HUD.clockLabel.TextColor3 = Color3.new(1, 1, 1)
	HUD.clockLabel.TextStrokeTransparency = 0.4
	HUD.clockLabel.TextScaled = true
	HUD.clockLabel.TextXAlignment = Enum.TextXAlignment.Right
	HUD.clockLabel.Text = "08:00"
	HUD.clockLabel.Parent = gui

	local calId = UIAssets.hud_calendar or ""
	local calBox
	if calId ~= "" then
		calBox = Instance.new("ImageLabel")
		calBox.Image = calId
		calBox.BackgroundTransparency = 1
	else
		calBox = Instance.new("Frame")
		calBox.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		calBox.BackgroundTransparency = 0.25
		corner(calBox)
	end
	calBox.Name = "CalendarBox"
	calBox.Size = UDim2.new(0, 62, 0, 62)
	calBox.Position = UDim2.new(1, -70, 0, 8)
	calBox.Parent = gui
	HUD.dayLabel = Instance.new("TextLabel") -- เลขวันพิมพ์ทับกลางรูปปฏิทิน
	HUD.dayLabel.Name = "DayLabel"
	HUD.dayLabel.Size = UDim2.new(1, 0, 0.55, 0)
	HUD.dayLabel.Position = UDim2.new(0, 0, 0.38, 0)
	HUD.dayLabel.BackgroundTransparency = 1
	HUD.dayLabel.TextColor3 = calId ~= "" and Color3.fromRGB(30, 30, 40) or Color3.new(1, 1, 1)
	HUD.dayLabel.TextScaled = true
	HUD.dayLabel.Text = "1"
	HUD.dayLabel.Parent = calBox

	-- ซ้ายกลาง: storage / กล้อง + ปุ่มกลม
	local stBox = panel(gui, UDim2.new(0, 16, SIDE_Y, 0), UDim2.new(0, SIDE_W, 0, SIDE_H))
	local camBox = panel(gui, UDim2.new(0, 16, SIDE_Y, SIDE_H + 8), UDim2.new(0, SIDE_W, 0, SIDE_H))
	stBox.Name = "StorageBox"
	camBox.Name = "CameraBox"
	HUD.storageLabel = statLabel(stBox, "hud_storage", "💾", "0 GB / 128 GB")
	HUD.cameraLabel = statLabel(camBox, "hud_camera", "📷", "720p")
	HUD.storageLabel.Name = "StorageLabel"
	HUD.cameraLabel.Name = "CameraLabel"
	HUD.sideAnchorY = SIDE_Y

	local function roundBtn(assetKey, fallback, x)
		local id = UIAssets[assetKey] or ""
		local b
		if id ~= "" then
			b = Instance.new("ImageButton")
			b.Image = id
			b.BackgroundTransparency = 1
		else
			b = Instance.new("TextButton")
			b.Text = fallback
			b.TextScaled = true
			b.TextColor3 = Color3.new(1, 1, 1)
			b.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
			b.BackgroundTransparency = 0.25
			corner(b, 20)
		end
		b.Size = UDim2.new(0, 40, 0, 40)
		b.Position = UDim2.new(0, x, SIDE_Y, SIDE_H * 2 + 18)
		b.Parent = gui
		return b
	end
	local setBtn = roundBtn("btn_setting", "⚙️", 16)
	local soundBtn = roundBtn("btn_sound", "🔊", 64)

	-- แผงเสียง (ทางลัดระหว่างเล่น · ตัวเต็มอยู่หน้า Setting ของ Main Menu)
	local vpanel = panel(gui, UDim2.new(0, 16, SIDE_Y, SIDE_H * 2 + 66), UDim2.new(0, 230, 0, 88))
	vpanel.Visible = false
	-- AudioService อยู่ StarterPlayerScripts — absolute path (script.Parent.Parent ใช้ไม่ได้หลังย้าย HUD ไป StarterGui)
	local Audio = require(game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild("AudioService"))
	local volLabel = Instance.new("TextLabel")
	volLabel.Size = UDim2.new(1, -12, 0, 34)
	volLabel.Position = UDim2.new(0, 6, 0, 2)
	volLabel.BackgroundTransparency = 1
	volLabel.TextColor3 = Color3.new(1, 1, 1)
	volLabel.TextScaled = true
	volLabel.TextXAlignment = Enum.TextXAlignment.Left
	volLabel.Text = ("🔊 เสียง %d%%"):format(math.floor(Audio.getVolume() * 100 + 0.5))
	volLabel.Parent = vpanel
	local function volBtn(text, x, dir)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 60, 0, 32)
		b.Position = UDim2.new(0, x, 0, 44)
		b.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextScaled = true
		b.Text = text
		b.Parent = vpanel
		b.Activated:Connect(function()
			Audio.setVolume(Audio.getVolume() + dir * 0.1)
			volLabel.Text = ("🔊 เสียง %d%%"):format(math.floor(Audio.getVolume() * 100 + 0.5))
		end)
	end
	volBtn("⊖", 10, -1)
	volBtn("⊕", 80, 1)
	local function toggleVol() vpanel.Visible = not vpanel.Visible end
	setBtn.Activated:Connect(toggleVol)
	soundBtn.Activated:Connect(toggleVol)

	-- ---------- ขวาสุด: mental bar แนวตั้ง ----------
	-- ★ แก้ 10 ส.ค. (user เพื่อนขอ: ซ่อนบาร์ก่อน phase 2) — ห่อทุกชิ้น (บาร์+หัวใจ+ป้าย%) ใน Frame
	-- เดียว "MentalGroup" เต็มจอโปร่งใส แทนที่จะพารากับ gui ตรงๆ แยกกัน (ก่อนหน้านี้ toggle ซ่อนไม่ได้
	-- เพราะไม่มีตัวห่อให้สั่ง Visible ทีเดียว — ดู HUD.update ท้ายไฟล์)
	-- ตำแหน่งชิ้นในนี้ยังอ้างอิงมุมจอเหมือนเดิมทุกค่า เพราะ MentalGroup ครอบเต็มจอพอดี (0,0 ถึง 1,1)
	local mentalGroup = Instance.new("Frame")
	mentalGroup.Name = "MentalGroup"
	mentalGroup.Size = UDim2.new(1, 0, 1, 0)
	mentalGroup.Position = UDim2.new(0, 0, 0, 0)
	mentalGroup.BackgroundTransparency = 1
	mentalGroup.Parent = gui
	HUD.mentalGroup = mentalGroup

	local barBack = panel(mentalGroup, UDim2.new(1, -46, MENTAL_TOP, 0),
		UDim2.new(0, MENTAL_W, MENTAL_BOT - MENTAL_TOP, 0), Color3.fromRGB(15, 15, 20))
	barBack.Name = "MentalTrack"
	barBack.BackgroundTransparency = 0.1
	barBack.ClipsDescendants = true -- แถบในไม่โผล่พ้นขอบมนของราง
	local fill = Instance.new("Frame")
	fill.Name = "MentalFill"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.new(0, 2, 1, -2)
	fill.Size = UDim2.new(1, -4, 0.8, 0)
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
	fill.Parent = barBack
	corner(fill, 6)
	HUD.mentalFill = fill

	local function heart(emoji, yScale, yOff)
		local h = Instance.new("TextLabel")
		h.Size = UDim2.new(0, 34, 0, 30)
		h.Position = UDim2.new(1, -50, yScale, yOff)
		h.BackgroundTransparency = 1
		h.TextScaled = true
		h.Text = emoji
		h.Parent = mentalGroup
		return h
	end
	heart("❤️", MENTAL_TOP, -34) -- หัวใจเต็มบนหัวบาร์
	heart("💔", MENTAL_BOT, 4) -- หัวใจแตกใต้บาร์
	for _, tick in { { 100, MENTAL_TOP }, { 50, (MENTAL_TOP + MENTAL_BOT) / 2 }, { 0, MENTAL_BOT } } do
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(0, 40, 0, 18)
		t.Position = UDim2.new(1, -92, tick[2], -9)
		t.BackgroundTransparency = 1
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0.5
		t.TextSize = 13
		t.TextXAlignment = Enum.TextXAlignment.Right
		t.Text = tick[1] .. "%"
		t.Parent = mentalGroup
	end

	-- hotbar: ไม่วาดเอง ใช้ backpack ของ Roblox (ล่างกลาง 3 ช่องพอดีภาพร่าง)

	HUD.gui = gui
	HUD.prev = nil
	gui.Parent = parent
	return gui
end

-- ผูกโค้ดเข้ากับ instance ใน StarterGui — path ตรงๆ ไม่เดาชื่อ (ย้ายใน Studio แล้วมาแก้ตารางนี้ · พังดังๆ ดีกว่าหยิบผิด)
local BINDINGS = {
	{ field = "followerLabel", path = { "FollowerBox", "FollowerLabel" } },
	{ field = "moneyLabel", path = { "MoneyBox", "MoneyLabel" } },
	{ field = "phaseLabel", path = { "ProgressTrack", "PhaseLabel" } },
	{ field = "progressFill", path = { "ProgressTrack", "ProgressFill" } },
	{ field = "clockLabel", path = { "ClockLabel" } },
	{ field = "dayLabel", path = { "Calendar", "DayLabel" } },
	{ field = "storageLabel", path = { "StorageBox", "StorageLabel" } },
	{ field = "cameraLabel", path = { "CameraBox", "CameraLabel" } },
	-- บาร์ใจ + หัวใจ + ป้าย % อยู่ใน MentalGroup เดียวกัน (ระยะห่างคงที่ทุกขนาดจอ)
	{ field = "mentalFill", path = { "MentalGroup", "MentalTrack", "MentalFill" } },
	-- ตัวกลุ่มทั้งก้อน (บาร์+หัวใจ+ป้าย%) เอาไว้ซ่อนทั้งชุดก่อน phase 2 (แก้ 10 ส.ค. — user: bar ยังไม่ควร
	-- โผล่ก่อนระบบ introduce ตาม docs/02 §3 "ระบบ introduce ตอน: phase 2")
	{ field = "mentalGroup", path = { "MentalGroup" } },
}

function HUD.bind(gui)
	HUD.gui = gui
	HUD.prev = nil
	-- ทุกชิ้นอยู่ใต้ Root (Frame เต็มจอไว้จัดกลุ่ม/ซ่อนทั้งชุด) · build() จากโค้ดไม่มี Root → ใช้ gui ตรงๆ
	local base = gui:FindFirstChild("Root") or gui
	local missing = {}
	for _, b in BINDINGS do
		local node = base
		for _, step in b.path do
			node = node and node:FindFirstChild(step)
		end
		HUD[b.field] = node
		if not node then table.insert(missing, "Gui_HUD." .. table.concat(b.path, ".")) end
	end
	if #missing > 0 then
		warn("[HUD] ไม่เจอชิ้นส่วนตาม path (ช่องนั้นจะไม่อัปเดต — แก้ตาราง BINDINGS ใน HUD.luau ให้ตรงของจริง):\n  "
			.. table.concat(missing, "\n  "))
	end
	-- ★ แก้ 12 ส.ค. (user: หลอด phase ไม่ขยับ) — ProgressFill ห้ามมี UIAspectRatioConstraint
	--   มันล็อกความกว้างตามอัตราส่วน (เจอ 0.0333 → กว้างแค่ ~1px) ทับ Size.X ที่โค้ด set ตาม follower
	--   fill เป็นตัวชี้ progress ต้องยืดกว้างอิสระ — ลบทิ้งตอน bind กันเพื่อน author/copy constraint ติดมา
	if HUD.progressFill then
		local arc = HUD.progressFill:FindFirstChildOfClass("UIAspectRatioConstraint")
		if arc then arc:Destroy() end
	end
end

-- ใช้ของจริงใน StarterGui ถ้ามี · StarterGui→PlayerGui ก๊อป async: WaitForChild ก่อน · timeout = build() fallback
function HUD.init(playerGui)
	local gui = playerGui:FindFirstChild("Gui_HUD") or playerGui:WaitForChild("Gui_HUD", 5)
	if gui then
		HUD.bind(gui)
	else
		HUD.build(playerGui)
	end
end

-- ตัวเลขเด้งจางหาย 1.5 วิ เหนือกล่องที่เปลี่ยน · เกาะกล่องจริง (responsive ตามจอ)
function HUD.popup(hostBox, text: string, color: Color3)
	if not hostBox then return end
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0) -- ลอยลงล่าง (กล่องอยู่ขอบบนจอ ลอยขึ้นจะหลุด)
	l.Position = UDim2.fromScale(0.5, 1.05)
	l.Size = UDim2.fromScale(0.7, 0.7)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.ZIndex = 10
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(27, 27, 27)
	stroke.Parent = l
	l.Parent = hostBox
	local ts = game:GetService("TweenService")
	ts:Create(l, TweenInfo.new(1.5), { TextTransparency = 1, Position = UDim2.fromScale(0.5, 1.7) }):Play()
	local st = ts:Create(stroke, TweenInfo.new(1.5), { Transparency = 1 })
	st:Play()
	st.Completed:Connect(function() l:Destroy() end)
end

-- ช่อง storage = footage ที่อัดมา (GB) ไม่ใช่จำนวนคลิป · เต็ม = FULL (pure)
function HUD.storageText(state): string
	local cap = Config.StorageLadderGB[Formulas.activeLevel(state, "storage")]
		or Config.StorageLadderGB[1]
	local used = math.floor(state.footageGB or 0)
	local function fmt(gb)
		return gb >= 1024 and ("%gT"):format(gb / 1024) or ("%d GB"):format(gb)
	end
	if used >= cap then return ("%s/%s FULL"):format(fmt(cap), fmt(cap)) end
	return ("%d GB / %s"):format(used, fmt(cap))
end

function HUD.update(state)
	-- delta popup เกาะกล่องที่เปลี่ยน
	local p = HUD.prev
	if p then
		local dF, dM = state.follower - p.follower, state.money - p.money
		local dG = (state.footageGB or 0) - (p.footageGB or 0)
		local fBox = HUD.followerLabel and HUD.followerLabel.Parent
		local mBox = HUD.moneyLabel and HUD.moneyLabel.Parent
		if dF ~= 0 then
			HUD.popup(fBox, ("%+d"):format(dF),
				dF > 0 and Color3.fromRGB(90, 230, 130) or Color3.fromRGB(240, 90, 90))
		end
		if dM ~= 0 then
			HUD.popup(mBox, ("%+d"):format(dM),
				dM > 0 and Color3.fromRGB(240, 220, 80) or Color3.fromRGB(240, 90, 90))
		end
		local _ = dG -- +GB ลอยรอบตัวผู้เล่นตอนกดอัดแทน (RecordTool.floatGain)
	end
	HUD.prev = { follower = state.follower, money = state.money, footageGB = state.footageGB or 0 }

	-- ทุกช่องเช็ค nil — ทีมลบ/เปลี่ยนชื่อชิ้นไหน เกมต้องไม่พัง แค่ช่องนั้นไม่อัปเดต
	setStat(HUD.followerLabel, HUD.comma(state.follower))
	setStat(HUD.moneyLabel, ("฿%s"):format(HUD.comma(state.money)))
	if HUD.progressFill then
		-- ★ แก้ 12 ส.ค. (user: หลอด phase ไม่เคยเพิ่ม) — fill ต้อง anchor ซ้าย (โตซ้าย→ขวา) เสมอ
		--   เพื่อน author เป็น AnchorPoint กึ่งกลาง (0.5) → พอ set Size.X มันโตออกสองข้าง ครึ่งหลุดขอบซ้าย
		--   เลยดูเหมือนไม่ขยับ · บังคับ anchor.X=0 / pos.X=0 ในโค้ด (คง Y เดิม) กัน re-author ผิดซ้ำ
		local ap = HUD.progressFill.AnchorPoint
		HUD.progressFill.AnchorPoint = Vector2.new(0, ap.Y)
		local posY = HUD.progressFill.Position.Y
		HUD.progressFill.Position = UDim2.new(0, 0, posY.Scale, posY.Offset)
		HUD.progressFill.Size = UDim2.new(HUD.progressPct(state.follower), -6, 1, -6)
	end
	-- นาฬิกา: sync ชั่วโมงกับ server (snap เมื่อ tick ใหม่) แล้วปล่อย Heartbeat เดินนาทีเอง
	if HUD.gameHour == nil or state.timeOfDay ~= HUD.serverHour then
		HUD.gameHour = state.timeOfDay
	end
	HUD.serverHour = state.timeOfDay
	HUD.frozen = state.frozen == true
	if HUD.dayLabel then HUD.dayLabel.Text = tostring(state.day) end
	if HUD.phaseLabel then HUD.phaseLabel.Text = ("Phase %d"):format(state.phase) end
	setStat(HUD.storageLabel, HUD.storageText(state))
	setStat(HUD.cameraLabel, tostring(Config.ResolutionLadder[Formulas.activeLevel(state, "camera")] or "?"))

	-- ซ่อนทั้งกลุ่มก่อน phase 2 (ตรงกับ MentalService.effective — ระบบยังไม่ทำงานจริงช่วงนี้อยู่แล้ว)
	if HUD.mentalGroup then
		HUD.mentalGroup.Visible = state.phase >= Config.Mental.introducedInPhase
	end
	-- วาดจริงใน Heartbeat ด้านบน (exponential follow ให้ลื่น) — ที่นี่แค่บอกเป้าหมายล่าสุด
	-- ครั้งแรก/หลัง respawn (mentalDisplay ยังไม่มีค่า) = snap ตรงไม่ไล่ กันวาดจากเลข nil/ค้างข้ามชีวิต
	if HUD.mentalFill then
		HUD.mentalDisplay = HUD.mentalDisplay or state.mental
		HUD.mentalServer = state.mental
	end
end

return HUD
