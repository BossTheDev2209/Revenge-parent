-- HUD.luau — UI ติดจอตลอดเวลา — **layout ตามภาพร่าง PDF หน้า 5 / `assets/reference/ui screenshot/All ui.png`**
--   บนกลาง : [👤 follower] [💰 money] เรียงข้างกัน + แถบ progress เฟสอยู่ใต้ทั้งคู่
--   บนขวา  : นาฬิกา 15:24 + ป้ายปฏิทินเลขวัน
--   ซ้ายกลาง: storage / กล้อง + ปุ่มกลม setting・เสียง ใต้กล่อง
--   ขวาสุด : mental bar แนวตั้งยาว หัวใจบน–หัวใจแตกล่าง + ป้าย 100/50/0%
--   ล่างกลาง: hotbar 3 ช่อง
-- ทุกกล่องเว้นที่ให้ใส่รูปทีหลัง (คีย์ใน UIAssets — docs/13 §1) ยังไม่มีรูป = กล่องสีทึบ + emoji
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local UIAssets = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.UIAssets)
	else require("../../shared/UIAssets")

local HUD = {}

-- ===== ขนาด/ตำแหน่งอ้างภาพร่าง (แก้ที่เดียว) =====
local STAT_W, STAT_H = 210, 46 -- กล่อง follower / money
local BAR_W, BAR_H = 470, 22 -- แถบ progress ใต้กล่อง
local SIDE_W, SIDE_H = 230, 40 -- กล่อง storage / กล้อง ฝั่งซ้าย
local SIDE_Y = 0.40 -- ซ้ายกลางค่อนบน ตามภาพร่าง
local MENTAL_W = 26
local MENTAL_TOP, MENTAL_BOT = 0.22, 0.86 -- บาร์ยาวเกือบเต็มความสูงจอ

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

-- ไอคอนช่องซ้าย: ใช้รูปจาก UIAssets ถ้ามี ไม่มีก็ใช้ emoji (docs/13 กติกา fallback)
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

-- ===== pure (เทสด้วย lune) =====

-- 1,024 แบบ PDF
function HUD.comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- แถบ progress สู่ 1M — ไม่ linear: แบ่งตามเฟส 10% / 40% / 50% (docs/09 §0 lock 21 ก.ค.)
-- ถ้า linear เฟส 1 (0→10K) จะกินแค่ 1% ของบาร์ ผู้เล่นรู้สึกไม่ขยับเลย
function HUD.progressPct(follower: number): number
	local f = math.max(0, follower)
	if f < 10_000 then return f / 10_000 * 0.10 end
	if f < 100_000 then return 0.10 + (f - 10_000) / 90_000 * 0.40 end
	return math.min(1, 0.50 + (f - 100_000) / 900_000 * 0.50)
end

-- ===== UI =====
-- build() = สร้างโครงจากศูนย์ | init() = ถ้ามีของจริงใน StarterGui อยู่แล้วให้ใช้อันนั้น (ทีมแก้หน้าตาใน Studio ได้)
-- ชื่อ instance ที่โค้ดอ้างถึงห้ามเปลี่ยน: FollowerLabel MoneyLabel PhaseLabel ProgressFill
--   ClockLabel DayLabel StorageLabel CameraLabel MentalFill  (ที่เหลือแต่ง/ย้าย/ลบได้ตามใจ)

function HUD.build(parent): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_HUD"
	gui.ResetOnSpawn = false
	gui.Enabled = false -- เริ่มซ่อน — เกมเปิดที่เมนู เมนูค่อยเปิด HUD ตอนกดเล่น (ไม่งั้นแฟลชทับฉากเมนู)

	-- ---------- บนกลาง: follower + money เรียงข้างกัน (ภาพร่าง: กล่องม่วง | กล่องเขียว) ----------
	local half = STAT_W + 5
	local fBox = panel(gui, UDim2.new(0.5, -half, 0, 10), UDim2.new(0, STAT_W, 0, STAT_H))
	local mBox = panel(gui, UDim2.new(0.5, 5, 0, 10), UDim2.new(0, STAT_W, 0, STAT_H))
	fBox.Name = "FollowerBox"
	mBox.Name = "MoneyBox"
	HUD.followerLabel = statLabel(fBox, "hud_follower", "👤", "0")
	HUD.moneyLabel = statLabel(mBox, "hud_money", "💰", "฿0")
	HUD.followerLabel.Name = "FollowerLabel"
	HUD.moneyLabel.Name = "MoneyLabel"
	HUD.statTopY = 10 + STAT_H -- ให้ popup เกาะขอบล่างกล่อง

	-- แถบ progress อยู่ "ใต้กล่องทั้งสอง" ตามภาพร่าง (ไม่ใช่เหนือ)
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
	for _, m in { 10_000, 100_000 } do -- ขีดรอยต่อเฟส (ภาพร่างมีขีดแบ่งช่วง)
		local tick = Instance.new("Frame")
		tick.Size = UDim2.new(0, 2, 1, 0)
		tick.Position = UDim2.new(HUD.progressPct(m), 0, 0, 0)
		tick.BackgroundColor3 = Color3.new(1, 1, 1)
		tick.BorderSizePixel = 0
		tick.Parent = track
	end
	HUD.phaseLabel = Instance.new("TextLabel") -- ป้ายเฟสซ้อนบนบาร์ (ภาพร่างเขียนชื่อช่วงในบาร์)
	HUD.phaseLabel.Name = "PhaseLabel"
	HUD.phaseLabel.Size = UDim2.new(1, -8, 1, 0)
	HUD.phaseLabel.Position = UDim2.new(0, 4, 0, 0)
	HUD.phaseLabel.BackgroundTransparency = 1
	HUD.phaseLabel.TextColor3 = Color3.new(1, 1, 1)
	HUD.phaseLabel.TextStrokeTransparency = 0.4
	HUD.phaseLabel.TextSize = 14
	HUD.phaseLabel.Text = "เฟส 1"
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

	-- ---------- บนขวา: นาฬิกา + ป้ายปฏิทิน (ภาพร่าง: "15:24" ตัวเปล่า + ปฏิทินฉีกเลข 24) ----------
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
	HUD.dayLabel = Instance.new("TextLabel") -- เลขวันพิมพ์ทับกลางรูปปฏิทิน (docs/13 กติกา 5)
	HUD.dayLabel.Name = "DayLabel"
	HUD.dayLabel.Size = UDim2.new(1, 0, 0.55, 0)
	HUD.dayLabel.Position = UDim2.new(0, 0, 0.38, 0)
	HUD.dayLabel.BackgroundTransparency = 1
	HUD.dayLabel.TextColor3 = calId ~= "" and Color3.fromRGB(30, 30, 40) or Color3.new(1, 1, 1)
	HUD.dayLabel.TextScaled = true
	HUD.dayLabel.Text = "1"
	HUD.dayLabel.Parent = calBox

	-- ---------- ซ้ายกลาง: storage / กล้อง + ปุ่มกลม ----------
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

	-- แผงเสียง (ตัวเต็มอยู่หน้า Setting ของ Main Menu — นี่คือทางลัดระหว่างเล่น)
	local vpanel = panel(gui, UDim2.new(0, 16, SIDE_Y, SIDE_H * 2 + 66), UDim2.new(0, 230, 0, 88))
	vpanel.Visible = false
	local Audio = require(script.Parent.Parent.AudioService)
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
	local barBack = panel(gui, UDim2.new(1, -46, MENTAL_TOP, 0),
		UDim2.new(0, MENTAL_W, MENTAL_BOT - MENTAL_TOP, 0), Color3.fromRGB(15, 15, 20))
	barBack.Name = "MentalTrack"
	barBack.BackgroundTransparency = 0.1
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
		h.Parent = gui
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
		t.Parent = gui
	end

	-- ---------- ล่างกลาง: hotbar ----------
	-- ★ ไม่วาดเอง — ใช้ backpack ของ Roblox (ล่างกลาง 3 ช่องพอดีภาพร่างอยู่แล้ว)
	-- อยากได้ช่องตามรูปที่วาด (`hud_hotbar_slot`) ต้องปิด CoreGui backpack แล้วทำเอง = งานแยก (docs/14 §4)

	HUD.gui = gui
	HUD.prev = nil
	gui.Parent = parent
	return gui
end

-- ★ ผูกโค้ดเข้ากับ instance ที่มีอยู่ใน StarterGui — **ระบุ path ตรงๆ ไม่มีการค้นหา ไม่มีการเดาชื่อ**
-- ย้ายของใน Studio แล้ว path เปลี่ยน = มาแก้ตารางนี้ให้ตรง (พังดังๆ ดีกว่าไปหยิบชิ้นผิดมาใช้)
-- path = ลำดับชื่อจาก Gui_HUD ลงไป เช่น { "FollowerBox", "FollowerLabel" } = Gui_HUD.FollowerBox.FollowerLabel
local BINDINGS = {
	{ field = "followerLabel", path = { "FollowerBox", "FollowerLabel" } },
	{ field = "moneyLabel", path = { "MoneyBox", "MoneyLabel" } },
	{ field = "phaseLabel", path = { "ProgressTrack", "PhaseLabel" } },
	{ field = "progressFill", path = { "ProgressTrack", "ProgressFill" } },
	{ field = "clockLabel", path = { "ClockLabel" } },
	{ field = "dayLabel", path = { "CalendarBox", "DayLabel" } },
	{ field = "storageLabel", path = { "StorageBox", "StorageLabel" } },
	{ field = "cameraLabel", path = { "CameraBox", "CameraLabel" } },
	{ field = "mentalFill", path = { "MentalTrack", "MentalFill" } },
}

function HUD.bind(gui)
	HUD.gui = gui
	HUD.prev = nil
	local missing = {}
	for _, b in BINDINGS do
		local node = gui
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
end

-- ใช้ของจริงใน StarterGui ถ้ามี (ทีมแก้หน้าตาใน Studio ได้เลย) ไม่มีค่อยสร้างจากโค้ด
function HUD.init(playerGui)
	local gui = playerGui:FindFirstChild("Gui_HUD")
	if gui then
		HUD.bind(gui)
	else
		HUD.build(playerGui)
	end
end

-- ตัวเลขเด้งจางหาย 1.5 วิ ข้างช่องที่เปลี่ยน (PDF หน้า 5 "1,024 +300")
function HUD.popup(anchor, text: string, color: Color3)
	if not HUD.gui then return end
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(0, 120, 0, 26)
	l.Position = anchor
	l.BackgroundTransparency = 1
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.4
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = HUD.gui
	local tween = game:GetService("TweenService"):Create(l, TweenInfo.new(1.5), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Position = anchor + UDim2.new(0, 0, 0, -26),
	})
	tween:Play()
	tween.Completed:Connect(function() l:Destroy() end)
end

-- ช่อง storage = footage ที่อัดมา (GB) ไม่ใช่จำนวนคลิป — PDF หน้า 5 "790 GB / 1T", เต็ม = FULL
-- pure: เทสได้ด้วย lune
function HUD.storageText(state): string
	local cap = Config.StorageLadderGB[state.upgrades and state.upgrades.storage or 1]
		or Config.StorageLadderGB[1]
	local used = math.floor(state.footageGB or 0)
	local function fmt(gb)
		return gb >= 1024 and ("%gT"):format(gb / 1024) or ("%d GB"):format(gb)
	end
	if used >= cap then return ("%s/%s FULL"):format(fmt(cap), fmt(cap)) end
	return ("%d GB / %s"):format(used, fmt(cap))
end

function HUD.update(state)
	-- delta popup เกาะมุมขวาบนของกล่องที่เปลี่ยน (ภาพร่าง: "+300" ลอยมุมขวาบนกล่อง follower)
	local p = HUD.prev
	if p then
		local dF, dM = state.follower - p.follower, state.money - p.money
		local dG = (state.footageGB or 0) - (p.footageGB or 0)
		if dF ~= 0 then
			HUD.popup(UDim2.new(0.5, -STAT_W - 5 + 12, 0, 2), ("%+d"):format(dF),
				dF > 0 and Color3.fromRGB(90, 230, 130) or Color3.fromRGB(240, 90, 90))
		end
		if dM ~= 0 then
			HUD.popup(UDim2.new(0.5, STAT_W - 40, 0, 2), ("%+d"):format(dM),
				dM > 0 and Color3.fromRGB(240, 220, 80) or Color3.fromRGB(240, 90, 90))
		end
		-- +GB ไม่ขึ้นตรงนี้แล้ว — ภาพร่างให้ลอยรอบตัวผู้เล่นตอนกดอัด (RecordTool.floatGain)
		local _ = dG
	end
	HUD.prev = { follower = state.follower, money = state.money, footageGB = state.footageGB or 0 }

	-- ทุกช่องเช็ค nil — ทีมลบ/เปลี่ยนชื่อชิ้นไหนใน StarterGui เกมต้องไม่พัง แค่ช่องนั้นไม่อัปเดต
	setStat(HUD.followerLabel, HUD.comma(state.follower))
	setStat(HUD.moneyLabel, ("฿%s"):format(HUD.comma(state.money)))
	if HUD.progressFill then
		HUD.progressFill.Size = UDim2.new(HUD.progressPct(state.follower), -6, 1, -6)
	end
	if HUD.clockLabel then HUD.clockLabel.Text = ("%02d:00"):format(state.timeOfDay) end
	if HUD.dayLabel then HUD.dayLabel.Text = tostring(state.day) end
	if HUD.phaseLabel then HUD.phaseLabel.Text = ("เฟส %d"):format(state.phase) end
	setStat(HUD.storageLabel, HUD.storageText(state))
	setStat(HUD.cameraLabel, tostring(Config.ResolutionLadder[state.upgrades.camera] or "?"))

	if HUD.mentalFill then
		local pct = math.clamp(state.mental, 0, 100) / 100
		HUD.mentalFill.Size = UDim2.new(1, -4, pct, 0)
		-- สีตามโซน (design doc §3): เขียว ≥70 / เหลือง 40-69 / แดง <40
		HUD.mentalFill.BackgroundColor3 = state.mental >= 70 and Color3.fromRGB(80, 220, 120)
			or state.mental >= 40 and Color3.fromRGB(240, 200, 80)
			or Color3.fromRGB(230, 80, 80)
	end
end

return HUD
