-- CalendarApp.luau — **layout ตามภาพร่าง `ui screenshot/PC-Calendar ui.png`** (design doc §4, PDF หน้า 6)
--   คอลัมน์ซ้าย "Event" = การ์ด block ที่ยังไม่ได้วาง (กดเลือก แล้วกดวันในกริด = วาง)
--   ขวา = กริดเดือน 7 คอลัมน์ (Sat–Fri) × 5 แถว · วันนี้มีวงกลม · block ระบายสีทับช่อง
-- สี block: แดง = Canon (ล็อกวัน ย้ายไม่ได้) · ม่วง = Select · ดำ = วันตัดรอบเงิน (ทุก 7 วัน)
--
-- ⚠️ ระบบปฏิทินถูกพับไว้ 9 ส.ค. (ดู SponsorService) — ไฟล์นี้ไม่ได้ require ที่ไหนตอนนี้
-- ★ baked เป็น instance จริงแล้วเหมือนกัน (9 ส.ค., ครบตามที่ตกลง) — 35 ช่องกริดจำนวนคงที่เสมอ
--   bake ได้ทั้งหมด เหลือแค่ Tray (การ์ด sponsor 0-1 ใบ) ที่ยังสร้างจาก data
--   template จริงอยู่ Gui_PC.Screen.AppTemplates.CalendarApp (แต่งใน Studio ได้)
--   ชื่อลูกที่โค้ดอ้าง ห้ามเปลี่ยน: EventCol.Tray (ว่าง) · Grid.Cell1-35.{Num,Block,Today} · Hint
local CalendarApp = {}

local RED = Color3.fromRGB(220, 50, 50)
local PURPLE = Color3.fromRGB(150, 60, 200)

local function stroke(inst, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(60, 80, 200)
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
	local guiPC = frame:FindFirstAncestorOfClass("ScreenGui")
	local template = guiPC and guiPC:FindFirstChild("Screen") and guiPC.Screen.AppTemplates:FindFirstChild("CalendarApp")
	if not template then
		warn("[CalendarApp] ไม่มี template Gui_PC.Screen.AppTemplates.CalendarApp — แต่งใน Studio ให้ครบก่อน")
		return {}
	end
	local content = template:Clone()
	content.Name = "CalendarAppContent"
	content.Visible = true -- template ซ่อนไว้ (Visible=false) กัน render ทับกันตอนพักเป็นแม่แบบ — clone ต้องเปิดเอง
	content.Parent = frame

	local eventCol = content:FindFirstChild("EventCol")
	local tray = eventCol and eventCol:FindFirstChild("Tray")
	local grid = content:FindFirstChild("Grid")
	local hint = content:FindFirstChild("Hint")

	local cells = {}
	if grid then
		for i = 1, 35 do
			local cell = grid:FindFirstChild("Cell" .. i)
			if cell then
				cells[i] = {
					cell = cell,
					num = cell:FindFirstChild("Num"),
					block = cell:FindFirstChild("Block"),
					today = cell:FindFirstChild("Today"),
					day = 0,
					conn = nil,
				}
			end
		end
	end

	local selected = nil -- การ์ดใน tray ที่กำลังถือ

	local app = {}
	function app.refresh(state)
		-- tray: ตอนนี้มีของอย่างเดียวคือ sponsor offer ที่ค้างอยู่ (docs/09 §3) — ยาวไม่แน่นอน สร้างจาก data
		if tray then
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
					if hint then hint.Text = "เลือกวันว่างในปฏิทินเพื่อวางงาน sponsor" end
				end)
			end
		end
		if hint then
			hint.Text = state.sponsorOffer and "💼 มีงาน sponsor เข้ามา — กดการ์ดซ้าย แล้วเลือกวัน" or ""
		end

		-- กริดเริ่มที่วันนี้ (ช่องแรก = วันนี้) ยาว 35 วัน — จำนวนช่องคงที่ แค่ปรับข้อมูล
		for i, cellData in cells do
			local day = state.day + (i - 1)
			cellData.day = day
			if cellData.num then cellData.num.Text = tostring(day) end
			if cellData.today then cellData.today.Visible = (i == 1) end

			local block = state.calendar[day]
			local isBill = (day - 1) % 7 == 0 -- วันตัดรอบเงินทุก 7 วัน (ภาพร่างมีช่อง "จ่ายค่าเช่า")
			if cellData.block then
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
			end

			if cellData.conn then cellData.conn:Disconnect() end
			cellData.conn = cellData.cell.Activated:Connect(function()
				if selected == "sponsor" and not block then
					deps.fireAction({ type = "AcceptSponsor", day = day })
					selected = nil
					if hint then hint.Text = "" end
				end
			end)
		end
	end
	return app
end

return CalendarApp
