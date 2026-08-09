-- SavePanel.luau — ปุ่มเซฟเล็กมุมซ้ายล่าง (Gui_SaveButton) + หน้าต่างเลือกช่องเซฟ 4 ช่อง (Gui_SavePanel)
-- สองอย่างนี้เป็นฟีเจอร์เดียวกัน (กดปุ่ม → เปิดหน้าต่าง) เก็บรวมไฟล์เดียว
--
-- ★ baked เป็น instance จริงใน StarterGui แล้ว (9 ส.ค. — แพทเทิร์นเดียวกับ Gui_PC/Gui_HUD)
--   ทั้งสอง gui ถาวร ไม่ Instance.new()/Destroy() ใหม่ทุกครั้งอีกต่อไป
--   เปิด/ปิด = toggle Gui_SavePanel.Enabled (เหมือน PCScreen) · SavePanel.init() wire event ครั้งเดียว
-- ชื่อลูกที่โค้ดอ้าง ห้ามเปลี่ยน (ที่เหลือแต่ง/ย้ายได้ใน Studio):
--   Gui_SaveButton.SaveBtn
--   Gui_SavePanel.{Dim, Panel.{Title, Slot1..Slot4}}
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

function SavePanel.buildButton(parent): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_SaveButton"
	gui.ResetOnSpawn = false
	local btn = Instance.new("TextButton")
	btn.Name = "SaveBtn"
	btn.Size = UDim2.new(0, 100, 0, 36)
	btn.Position = UDim2.new(0, 8, 1, -44)
	btn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextScaled = true
	btn.Text = "💾 เซฟ"
	btn:SetAttribute("Sfx", "save")
	btn.Parent = gui
	gui.Parent = parent
	return gui
end

function SavePanel.buildPanel(parent): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_SavePanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Enabled = false

	local dim = Instance.new("TextButton") -- ฉากหลังมืด กดปิด
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.Text = ""
	dim:SetAttribute("Sfx", "none")
	dim.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(520, 420)
	panel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, 12)

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
	local btnGui = playerGui:FindFirstChild("Gui_SaveButton") or playerGui:WaitForChild("Gui_SaveButton", 5)
		or SavePanel.buildButton(playerGui)
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

	local btn = btnGui:FindFirstChild("SaveBtn") or btnGui:FindFirstChildOfClass("TextButton")
	if btn then
		btn.Activated:Connect(SavePanel.open)
	else
		warn("[SavePanel] Gui_SaveButton โครงไม่ครบ (ต้องมี SaveBtn) — แก้ชื่อใน Studio ให้ตรง")
	end
end

return SavePanel
