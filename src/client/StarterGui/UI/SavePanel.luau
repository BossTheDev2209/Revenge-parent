-- SavePanel.luau — ปุ่มเซฟเล็กมุมซ้ายล่าง (Gui_SaveButton) + หน้าต่างเลือกช่องเซฟ 4 ช่อง (Gui_SavePanel)
-- สองอย่างนี้เป็นฟีเจอร์เดียวกัน (กดปุ่ม → เปิดหน้าต่าง) เก็บรวมไฟล์เดียว
--
-- ★ baked เป็น instance จริงใน StarterGui แล้ว (9 ส.ค. — แพทเทิร์นเดียวกับ Gui_PC/Gui_HUD)
--   ทั้งสอง gui ถาวร ไม่ Instance.new()/Destroy() ใหม่ทุกครั้งอีกต่อไป
--   เปิด/ปิด = toggle Gui_SavePanel.Enabled (เหมือน PCScreen) · SavePanel.init() wire event ครั้งเดียว
-- ชื่อลูกที่โค้ดอ้าง ห้ามเปลี่ยน (ที่เหลือแต่ง/ย้ายได้ใน Studio):
--   Gui_HUD.Root.SaveBtn   ← ปุ่มอยู่ในชุด HUD (10 ส.ค.) ไม่ใช่ ScreenGui แยกแล้ว
--   Gui_SavePanel.{Dim, Panel.{Title, Slot1..Slot4}}
-- อยู่ใน Gui_HUD.Root เพราะ: scale ตามชุด HUD ชุดเดียวกัน + ซ่อน/โผล่ตาม Gui_HUD.Enabled เอง
-- (อยู่ในเมนู HUD ปิด = ปุ่มเซฟหายไปด้วย ไม่ลอยทับฉากเมนู)
--
-- กดช่องว่าง = เซฟใหม่ · กดช่องที่มีของ = กดซ้ำอีกทีเพื่อทับ (กันเผลอทับเซฟอื่น)
-- อ่าน slotList จาก state (fireAction RequestSlots) — ต่อ StateChanged อัปเดต label เอง **เฉพาะตอนเปิดอยู่**
-- (connect ครั้งเดียวตลอดอายุเกม เพราะ gui ถาวรแล้ว ไม่ต้อง connect/disconnect ทุกรอบเปิด-ปิด)
local isStudio = script ~= nil
local RS = if isStudio then game:GetService("ReplicatedStorage") else nil

local SavePanel = {}
SavePanel.running = false

local SLOTS = 4

-- pure: ข้อความสรุปช่องเซฟ (nil = ว่าง) · count = จำนวน snapshot ในช่อง
function SavePanel.slotText(i: number, sum): string
	if not sum then return ("ช่อง %d — [ว่าง] กดเพื่อเซฟ"):format(i) end
	local snaps = sum.count and sum.count > 0 and ("  · %d จุดเซฟ"):format(sum.count) or ""
	return ("ช่อง %d — วันที่ %d · %s follower · เฟส %d%s"):format(i, sum.day, tostring(sum.follower), sum.phase, snaps)
end

-- ===== build fallback: สร้างจากโค้ด (ไม่มี instance ให้ใช้) — แพทเทิร์นเดียวกับ HUD.build/PCScreen.build =====
local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = o
end

function SavePanel.buildPanel(parent): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_SavePanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.IgnoreGuiInset = true -- dim คลุมเต็มจอถึงแถบบนสุด (ไม่เว้นช่อง topbar ~36px)

	local dim = Instance.new("TextButton") -- ฉากหลังมืด กดปิด
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.Text = ""
	dim:SetAttribute("Sfx", "none")
	dim.Parent = gui

	local PANEL_W, PANEL_H = 520, 420
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5) -- กลาง = UIScale ย่อออกจากจุดกึ่งกลาง แผงอยู่กลางจอเสมอ
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
	panel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, 12)

	-- ★ 12 ส.ค. responsive (docs/05 §5.5) — layout ในแผงเป็นพิกเซลตายตัวตามดีไซน์
	--   ย่อทั้งแผงด้วย UIScale ให้พอดีจอแทน (แพทเทิร์นเดียวกับ ShopKiosk.fitScale / EditQTE.fitToScreen)
	--   เดิมแผง 520×420 ตายตัว → มือถือ/จอเล็กแนวตั้ง แผงล้นจอ กดปุ่มล่างไม่ถึง
	--   gui ตัวนี้ถาวร (สร้างครั้งเดียว toggle ด้วย .Enabled) → connection อยู่ยาวได้ ไม่ต้อง disconnect
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = panel
	local cam = workspace.CurrentCamera
	local function fitToScreen()
		if not cam then return end
		local vp = cam.ViewportSize
		local inset = game:GetService("GuiService"):GetGuiInset()
		local margin = 24
		local fit = math.min((vp.X - margin * 2) / PANEL_W, (vp.Y - inset.Y - margin * 2) / PANEL_H)
		uiScale.Scale = math.clamp(fit, 0.35, 1) -- ไม่ขยายเกิน 1 (ดีไซน์เป็นขนาดเต็มอยู่แล้ว)
	end
	fitToScreen()
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen) end

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(24, 16)
	title.Size = UDim2.fromOffset(472, 34)
	title.BackgroundTransparency = 1
	title.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(240, 240, 245)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "💾 เซฟเกม"
	title.Parent = panel

	for i = 1, SLOTS do
		local b = Instance.new("TextButton")
		b.Name = "Slot" .. i
		b.Size = UDim2.fromOffset(472, 62)
		b.Position = UDim2.fromOffset(24, 60 + (i - 1) * 72)
		b.BackgroundColor3 = Color3.fromRGB(44, 44, 54)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.FontFace = Font.fromEnum(Enum.Font.Gotham)
		b.TextSize = 17
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Text = SavePanel.slotText(i, nil)
		b:SetAttribute("Sfx", "save")
		b.Parent = panel
		corner(b, 8)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 16)
		pad.Parent = b
	end

	gui.Parent = parent
	return gui
end

-- ===== glue: หา instance ที่ baked ไว้ (หรือ build fallback) แล้ว wire event ครั้งเดียว =====
-- deps = { fireAction, getState } — เรียกครั้งเดียวตอน Main.client เริ่ม (แพทเทิร์นเดียวกับ HUD.init)
function SavePanel.init(playerGui, deps)
	local panelGui = playerGui:FindFirstChild("Gui_SavePanel") or playerGui:WaitForChild("Gui_SavePanel", 5)
		or SavePanel.buildPanel(playerGui)

	local panel = panelGui:FindFirstChild("Panel")
	local title = panel and panel:FindFirstChild("Title")
	local dim = panelGui:FindFirstChild("Dim")
	if not (panel and title and dim) then
		warn("[SavePanel] Gui_SavePanel โครงไม่ครบ (ต้องมี Dim, Panel.Title) — แก้ชื่อใน Studio ให้ตรง")
		return
	end
	local rows = {}
	for i = 1, SLOTS do rows[i] = panel:FindFirstChild("Slot" .. i) end

	local function refresh()
		local state = deps.getState()
		local slots = state and state.slotList
		for i = 1, SLOTS do
			local sum = slots and slots[i]
			local b = rows[i]
			if b then
				b.Text = SavePanel.slotText(i, sum)
				b.BackgroundColor3 = sum and Color3.fromRGB(46, 60, 46) or Color3.fromRGB(44, 44, 54)
			end
		end
	end

	local function close()
		panelGui.Enabled = false
		SavePanel.running = false
	end

	function SavePanel.open()
		if SavePanel.running then return end
		SavePanel.running = true
		deps.fireAction({ type = "RequestSlots" })
		title.Text = "💾 เซฟเกม"
		panelGui.Enabled = true
		refresh()
	end
	SavePanel.close = close

	dim.Activated:Connect(close)
	for i, b in rows do
		if b then
			b.Activated:Connect(function()
				deps.fireAction({ type = "SaveSlot", slot = i }) -- เพิ่มจุดเซฟใหม่เข้าช่อง (เก็บ 5 ล่าสุด)
				title.Text = ("✅ เพิ่มจุดเซฟช่อง %d แล้ว"):format(i)
				task.delay(1.2, close)
			end)
		end
	end
	-- gui ถาวรแล้ว connect ครั้งเดียวพอ — refresh เฉพาะตอนเปิดอยู่ (ไม่งั้นอัปเดตทิ้งเปล่าตลอดเกม)
	RS.Shared.Remotes.StateChanged.OnClientEvent:Connect(function()
		if panelGui.Enabled then refresh() end
	end)

	-- ปุ่มเซฟอยู่ในชุด HUD — path ตรงๆ ไม่มีการค้นหา/เดาชื่อ (ย้ายใน Studio แล้วมาแก้ path ตรงนี้)
	local hudRoot = playerGui:FindFirstChild("Gui_HUD") and playerGui.Gui_HUD:FindFirstChild("Root")
	local btn = hudRoot and hudRoot:FindFirstChild("SaveBtn")
	if btn then
		btn.Activated:Connect(SavePanel.open)
	else
		warn("[SavePanel] ไม่เจอ Gui_HUD.Root.SaveBtn — ปุ่มเซฟจะกดไม่ได้")
	end
end

return SavePanel
