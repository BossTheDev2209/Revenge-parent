-- SavePanel.luau — หน้าต่างเซฟระหว่างเล่น: เลือกช่องเซฟ 4 ช่อง (เหมือนสมุดเซฟในเมนู)
-- กดช่องว่าง = เซฟใหม่ · กดช่องที่มีของ = กดซ้ำอีกทีเพื่อทับ (กันเผลอทับเซฟอื่น)
-- อ่าน slotList จาก state (fireAction RequestSlots) — ต่อ StateChanged อัปเดต label เองตอนเซฟเสร็จ
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local SavePanel = {}
SavePanel.running = false

local SLOTS = 4

-- pure: ข้อความสรุปช่องเซฟ (nil = ว่าง) · count = จำนวน snapshot ในช่อง
function SavePanel.slotText(i: number, sum): string
	if not sum then return ("ช่อง %d — [ว่าง] กดเพื่อเซฟ"):format(i) end
	local snaps = sum.count and sum.count > 0 and ("  · %d จุดเซฟ"):format(sum.count) or ""
	return ("ช่อง %d — วันที่ %d · %s follower · เฟส %d%s"):format(i, sum.day, tostring(sum.follower), sum.phase, snaps)
end

function SavePanel.open(playerGui, deps)
	if SavePanel.running then return end
	SavePanel.running = true
	deps.fireAction({ type = "RequestSlots" })

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_SavePanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20

	local dim = Instance.new("TextButton") -- ฉากหลังมืด กดปิด
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.Text = ""
	dim:SetAttribute("Sfx", "none")
	dim.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(520, 420)
	panel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 12)
	pc.Parent = panel

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(24, 16)
	title.Size = UDim2.fromOffset(472, 34)
	title.BackgroundTransparency = 1
	title.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(240, 240, 245)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "💾 เซฟเกม"
	title.Parent = panel

	local rows = {}
	-- เซฟ = เพิ่ม "จุดเซฟ" ใหม่เข้าช่อง (เก็บ 5 จุดล่าสุด) ไม่ทับของเดิม → ไม่ต้องยืนยันทับ
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

	for i = 1, SLOTS do
		local b = Instance.new("TextButton")
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
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 8)
		bc.Parent = b
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 16)
		pad.Parent = b
		rows[i] = b
		b.Activated:Connect(function()
			deps.fireAction({ type = "SaveSlot", slot = i }) -- เพิ่มจุดเซฟใหม่เข้าช่อง (เก็บ 5 ล่าสุด)
			title.Text = ("✅ เพิ่มจุดเซฟช่อง %d แล้ว"):format(i)
			task.delay(1.2, function() if gui.Parent then gui:Destroy() end end)
			SavePanel.running = false
		end)
	end

	local conn = RS.Shared.Remotes.StateChanged.OnClientEvent:Connect(refresh)
	local function close()
		conn:Disconnect()
		gui:Destroy()
		SavePanel.running = false
	end
	dim.Activated:Connect(close)
	gui.AncestryChanged:Connect(function(_, parent)
		if not parent then conn:Disconnect() end
	end)

	gui.Parent = playerGui
	refresh()
end

return SavePanel
