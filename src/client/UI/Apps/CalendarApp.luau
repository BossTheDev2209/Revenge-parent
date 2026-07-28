-- CalendarApp.luau — **layout ตามภาพร่าง `ui screenshot/PC-Calendar ui.png`** (design doc §4, PDF หน้า 6)
--   คอลัมน์ซ้าย "Event" = การ์ด block ที่ยังไม่ได้วาง (กดเลือก แล้วกดวันในกริด = วาง)
--   ขวา = กริดเดือน 7 คอลัมน์ (Sat–Fri) × 5 แถว · วันนี้มีวงกลม · block ระบายสีทับช่อง
-- สี block: แดง = Canon (ล็อกวัน ย้ายไม่ได้) · ม่วง = Select · ดำ = วันตัดรอบเงิน (ทุก 7 วัน)
local CalendarApp = {}

local BLUE = Color3.fromRGB(60, 80, 200)
local RED = Color3.fromRGB(220, 50, 50)
local PURPLE = Color3.fromRGB(150, 60, 200)
local DAY_NAMES = { "Sat", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri" }
local ROWS = 5

local function stroke(inst, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color or BLUE
	s.Thickness = thick or 1
	s.Parent = inst
	return s
end

-- สีตามชนิด block (state.calendar[day].type)
function CalendarApp.blockColor(t: string?): Color3
	if t == "canon" then return RED end
	if t == "sponsor" then return Color3.fromRGB(230, 150, 30) end
	return PURPLE
end

function CalendarApp.create(frame, deps)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)

	-- ---------- คอลัมน์ซ้าย: Event ----------
	local eventCol = Instance.new("Frame")
	eventCol.Position = UDim2.new(0, 6, 0, 6)
	eventCol.Size = UDim2.new(0.26, -8, 1, -12)
	eventCol.BackgroundTransparency = 1
	eventCol.Parent = frame

	local eventHead = Instance.new("TextLabel")
	eventHead.Size = UDim2.new(1, 0, 0, 34)
	eventHead.BackgroundTransparency = 1
	eventHead.TextColor3 = Color3.fromRGB(30, 30, 40)
	eventHead.TextScaled = true
	eventHead.Text = "Event"
	eventHead.Parent = eventCol
	stroke(eventHead, BLUE)

	local tray = Instance.new("ScrollingFrame")
	tray.Position = UDim2.new(0, 0, 0, 40)
	tray.Size = UDim2.new(1, 0, 1, -40)
	tray.BackgroundTransparency = 1
	tray.ScrollBarThickness = 4
	tray.CanvasSize = UDim2.new(0, 0, 0, 0)
	tray.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tray.Parent = eventCol
	local trayLayout = Instance.new("UIListLayout")
	trayLayout.Padding = UDim.new(0, 8)
	trayLayout.Parent = tray

	-- ---------- ขวา: กริดเดือน ----------
	local grid = Instance.new("Frame")
	grid.Position = UDim2.new(0.26, 4, 0, 6)
	grid.Size = UDim2.new(0.74, -10, 1, -12)
	grid.BackgroundTransparency = 1
	grid.Parent = frame

	local HEAD_H = 0.12
	for i, name in DAY_NAMES do
		local h = Instance.new("TextLabel")
		h.Position = UDim2.new((i - 1) / 7, 0, 0, 0)
		h.Size = UDim2.new(1 / 7, 0, HEAD_H, 0)
		h.BackgroundColor3 = Color3.new(1, 1, 1)
		h.TextColor3 = BLUE
		h.TextScaled = true
		h.Text = name
		h.Parent = grid
		stroke(h, BLUE)
	end

	-- 35 ช่อง (5 สัปดาห์) — แต่ละช่องมีเลขวัน + แถบ block ทับ
	local cells = {}
	for r = 1, ROWS do
		for c = 1, 7 do
			local idx = (r - 1) * 7 + c
			local cell = Instance.new("TextButton")
			cell.Position = UDim2.new((c - 1) / 7, 0, HEAD_H + (r - 1) * (1 - HEAD_H) / ROWS, 0)
			cell.Size = UDim2.new(1 / 7, 0, (1 - HEAD_H) / ROWS, 0)
			cell.BackgroundColor3 = Color3.new(1, 1, 1)
			cell.AutoButtonColor = false
			cell.Text = ""
			cell.Parent = grid
			stroke(cell, BLUE)

			local num = Instance.new("TextLabel")
			num.Size = UDim2.new(1, -4, 0.4, 0)
			num.Position = UDim2.new(0, 2, 0, 2)
			num.BackgroundTransparency = 1
			num.TextColor3 = Color3.fromRGB(60, 60, 80)
			num.TextScaled = true
			num.TextXAlignment = Enum.TextXAlignment.Left
			num.Text = ""
			num.Parent = cell

			local block = Instance.new("TextLabel") -- แถบชื่อ event ทับช่อง
			block.Position = UDim2.new(0, 2, 0.42, 0)
			block.Size = UDim2.new(1, -4, 0.5, 0)
			block.BackgroundColor3 = PURPLE
			block.BackgroundTransparency = 0.75
			block.TextColor3 = Color3.fromRGB(40, 20, 60)
			block.TextScaled = true
			block.TextWrapped = true
			block.Text = ""
			block.Visible = false
			block.Parent = cell

			local today = Instance.new("Frame") -- วงกลมวันนี้ (ภาพร่างวงรอบเลข)
			today.Size = UDim2.new(0, 26, 0, 26)
			today.Position = UDim2.new(0, 2, 0, 2)
			today.BackgroundTransparency = 1
			today.Visible = false
			today.Parent = cell
			local tc = Instance.new("UICorner")
			tc.CornerRadius = UDim.new(1, 0)
			tc.Parent = today
			stroke(today, BLUE, 2)

			cells[idx] = { cell = cell, num = num, block = block, today = today, day = 0, conn = nil }
		end
	end

	-- ---------- state ของการวาง ----------
	local selected = nil -- การ์ดใน tray ที่กำลังถือ
	local hint = Instance.new("TextLabel")
	hint.Position = UDim2.new(0, 6, 1, -20)
	hint.Size = UDim2.new(1, -12, 0, 18)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.fromRGB(200, 120, 30)
	hint.TextScaled = true
	hint.Text = ""
	hint.Parent = frame

	local app = {}
	function app.refresh(state)
		-- tray: ตอนนี้มีของอย่างเดียวคือ sponsor offer ที่ค้างอยู่ (docs/09 §3)
		for _, ch in tray:GetChildren() do
			if ch:IsA("TextButton") then ch:Destroy() end
		end
		selected = nil
		if state.sponsorOffer then
			local card = Instance.new("TextButton")
			card.Size = UDim2.new(1, 0, 0, 64)
			card.BackgroundColor3 = Color3.fromRGB(255, 245, 225)
			card.TextColor3 = Color3.fromRGB(150, 90, 20)
			card.TextScaled = true
			card.TextWrapped = true
			card.Text = "💼 งาน sponsor\n(กดเลือก แล้วกดวันว่าง)"
			card.Parent = tray
			stroke(card, Color3.fromRGB(230, 150, 30), 2)
			card.Activated:Connect(function()
				selected = "sponsor"
				hint.Text = "เลือกวันว่างในปฏิทินเพื่อวางงาน sponsor"
			end)
		end
		hint.Text = state.sponsorOffer and "💼 มีงาน sponsor เข้ามา — กดการ์ดซ้าย แล้วเลือกวัน" or ""

		-- กริดเริ่มที่วันนี้ (ช่องแรก = วันนี้) ยาว 35 วัน
		for i, cellData in cells do
			local day = state.day + (i - 1)
			cellData.day = day
			cellData.num.Text = tostring(day)
			cellData.today.Visible = (i == 1)

			local block = state.calendar[day]
			local isBill = (day - 1) % 7 == 0 -- วันตัดรอบเงินทุก 7 วัน (ภาพร่างมีช่อง "จ่ายค่าเช่า")
			if block then
				cellData.block.Visible = true
				cellData.block.BackgroundColor3 = CalendarApp.blockColor(block.type)
				cellData.block.Text = block.id or block.type
			elseif isBill then
				cellData.block.Visible = true
				cellData.block.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
				cellData.block.Text = "จ่ายค่าเช่า"
			else
				cellData.block.Visible = false
			end

			if cellData.conn then cellData.conn:Disconnect() end
			cellData.conn = cellData.cell.Activated:Connect(function()
				if selected == "sponsor" and not block then
					deps.fireAction({ type = "AcceptSponsor", day = day })
					selected = nil
					hint.Text = ""
				end
			end)
		end
	end
	return app
end

return CalendarApp
