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

function HUD.init(playerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_HUD"
	gui.ResetOnSpawn = false

	HUD.followerLabel = label(box(gui, { 0, 8 }, { 0, 8 }, 190, 34), "👤 0")
	HUD.moneyLabel = label(box(gui, { 0, 8 }, { 0, 48 }, 190, 34), "💰 ฿0")
	HUD.clockLabel = label(box(gui, { 1, -178 }, { 0, 8 }, 170, 34), "วัน 1 | 08:00")
	HUD.phaseLabel = label(box(gui, { 1, -178 }, { 0, 48 }, 170, 34), "เฟส 1")
	HUD.storageLabel = label(box(gui, { 0, 8 }, { 1, -132 }, 210, 34), "💾 0 GB / 128 GB")
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

	-- แถบ progress สู่ 1M กลางบนจอ + ขีด milestone (PDF หน้า 5)
	local track = box(gui, { 0.5, -260 }, { 0, 10 }, 520, 20, Color3.fromRGB(15, 15, 20))
	local pfill = Instance.new("Frame")
	pfill.Size = UDim2.new(0, 0, 1, -6)
	pfill.Position = UDim2.new(0, 3, 0, 3)
	pfill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
	pfill.Parent = track
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 6)
	pc.Parent = pfill
	for _, m in { 10_000, 100_000 } do -- รอยต่อเฟส
		local tick = Instance.new("Frame")
		tick.Size = UDim2.new(0, 2, 1, 0)
		tick.Position = UDim2.new(HUD.progressPct(m), 0, 0, 0)
		tick.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		tick.BorderSizePixel = 0
		tick.Parent = track
	end
	local goal = Instance.new("TextLabel")
	goal.Size = UDim2.new(0, 120, 0, 20)
	goal.Position = UDim2.new(0.5, 264, 0, 10)
	goal.BackgroundTransparency = 1
	goal.TextColor3 = Color3.new(1, 1, 1)
	goal.TextStrokeTransparency = 0.5
	goal.TextScaled = true
	goal.TextXAlignment = Enum.TextXAlignment.Left
	goal.Text = "/ 1M"
	goal.Parent = gui
	HUD.progressFill = pfill

	-- ปุ่มตั้งค่า + แผงเสียง (ตัวเต็มอยู่หน้า Setting ของ Main Menu — นี่คือทางลัดระหว่างเล่น)
	local setBtn = Instance.new("TextButton")
	setBtn.Size = UDim2.new(0, 36, 0, 36)
	setBtn.Position = UDim2.new(0, 116, 1, -44) -- ขวาปุ่มเซฟ (Main.client วางปุ่มเซฟที่ x=8 กว้าง 100)
	setBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	setBtn.BackgroundTransparency = 0.25
	setBtn.TextColor3 = Color3.new(1, 1, 1)
	setBtn.TextScaled = true
	setBtn.Text = "⚙️"
	setBtn.Parent = gui
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 8)
	sc.Parent = setBtn

	local panel = box(gui, { 0, 8 }, { 1, -230 }, 220, 88) -- เหนือช่อง storage ไม่ทับอะไร
	panel.Visible = false
	local volLabel = label(panel, "🔊 เสียง 100%")
	volLabel.Size = UDim2.new(1, -12, 0, 34)
	local function volBtn(text, x, dir)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 60, 0, 32)
		b.Position = UDim2.new(0, x, 0, 44)
		b.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextScaled = true
		b.Text = text
		b.Parent = panel
		b.Activated:Connect(function()
			local sound = game:GetService("SoundService")
			sound.Volume = math.clamp(sound.Volume + dir * 0.1, 0, 1)
			volLabel.Text = ("🔊 เสียง %d%%"):format(math.floor(sound.Volume * 100 + 0.5))
		end)
	end
	volBtn("⊖", 10, -1)
	volBtn("⊕", 80, 1)
	setBtn.Activated:Connect(function() panel.Visible = not panel.Visible end)

	-- ที่เก็บ popup ตัวเลขเด้ง (+300 ข้างตัวเลข)
	HUD.gui = gui
	HUD.prev = nil

	gui.Parent = playerGui
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
	if used >= cap then return ("💾 %s/%s FULL"):format(fmt(cap), fmt(cap)) end
	return ("💾 %d GB / %s"):format(used, fmt(cap))
end

function HUD.update(state)
	-- delta popup: เทียบ state ก่อนหน้า (PDF หน้า 5 "+300" / "+20")
	local p = HUD.prev
	if p then
		local dF, dM = state.follower - p.follower, state.money - p.money
		local dG = (state.footageGB or 0) - (p.footageGB or 0)
		if dF ~= 0 then
			HUD.popup(UDim2.new(0, 204, 0, 12), ("%+d"):format(dF),
				dF > 0 and Color3.fromRGB(90, 230, 130) or Color3.fromRGB(240, 90, 90))
		end
		if dM ~= 0 then
			HUD.popup(UDim2.new(0, 204, 0, 52), ("%+d"):format(dM),
				dM > 0 and Color3.fromRGB(240, 220, 80) or Color3.fromRGB(240, 90, 90))
		end
		if dG > 0 then
			HUD.popup(UDim2.new(0, 224, 1, -128), ("+%.1f GB"):format(dG), Color3.fromRGB(120, 200, 255))
		end
	end
	HUD.prev = { follower = state.follower, money = state.money, footageGB = state.footageGB or 0 }

	HUD.followerLabel.Text = ("👤 %s"):format(HUD.comma(state.follower))
	HUD.moneyLabel.Text = ("💰 ฿%s"):format(HUD.comma(state.money))
	if HUD.progressFill then
		HUD.progressFill.Size = UDim2.new(HUD.progressPct(state.follower), -6, 1, -6)
	end
	HUD.clockLabel.Text = ("วัน %d | %02d:00"):format(state.day, state.timeOfDay)
	HUD.phaseLabel.Text = ("เฟส %d"):format(state.phase)
	HUD.storageLabel.Text = HUD.storageText(state)
	HUD.cameraLabel.Text = ("📷 %s"):format(Config.ResolutionLadder[state.upgrades.camera] or "?")

	local pct = math.clamp(state.mental, 0, 100) / 100
	HUD.mentalFill.Size = UDim2.new(1, -4, pct, 0)
	-- สีตามโซน (design doc §3): เขียว ≥70 / เหลือง 40-69 / แดง <40
	HUD.mentalFill.BackgroundColor3 = state.mental >= 70 and Color3.fromRGB(80, 220, 120)
		or state.mental >= 40 and Color3.fromRGB(240, 200, 80)
		or Color3.fromRGB(230, 80, 80)
end

return HUD
