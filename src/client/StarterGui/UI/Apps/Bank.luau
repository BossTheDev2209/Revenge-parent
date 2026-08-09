-- Bank.luau — **layout ตามภาพร่าง `ui screenshot/PC-Bank-1 ui.png`** (PDF หน้า 9 — user lock 21 ก.ค.)
--   แถวบน  : 3 ตัวเลขสรุป — ยอดคงเหลือ | income per week | All รายจ่ายต่อ week (แดง)
--   แถวกลาง: การ์ด 3 ใบ — ค่าอาหาร / ค่าพนักงาน / ค่าเช่า · ครึ่งบนเว้นว่างไว้ใส่รูป ครึ่งล่าง ⊖ ตัวเลข ⊕
--   ล่างกลาง: ปุ่ม manage
-- ⊖⊕ ปรับงบ/สัปดาห์เป็น step ต่อการ์ด (Config.Spending) — server ตัดสิน ขอบเขต client แค่ยิง action
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../../shared/Config")

local Bank = {}

-- เรียงตามภาพร่าง: อาหาร | พนักงาน | เช่า
local CARDS = {
	{ key = "food", icon = "🍽️", name = "ค่าอาหารต่อ week" },
	{ key = "staff", icon = "👤", name = "ค่าพนักงานต่อ week" },
	{ key = "rent", icon = "🏠", name = "ค่าเช่าต่อ week" },
}

function Bank.create(frame, deps)
	frame.BackgroundColor3 = Color3.fromRGB(238, 240, 245)

	-- ---------- แถวบน: 3 ตัวเลขสรุป ----------
	local heads = {}
	for i, def in { { "ยอดคงเหลือ", Color3.fromRGB(30, 60, 160) },
		{ "income per week", Color3.fromRGB(30, 60, 160) },
		{ "All รายจ่ายต่อ week", Color3.fromRGB(200, 40, 40) } } do
		local col = Instance.new("Frame")
		col.Position = UDim2.new((i - 1) / 3, 8, 0.04, 0)
		col.Size = UDim2.new(1 / 3, -16, 0.3, 0)
		col.BackgroundTransparency = 1
		col.Parent = frame

		local cap = Instance.new("TextLabel")
		cap.Size = UDim2.new(1, 0, 0.45, 0)
		cap.BackgroundTransparency = 1
		cap.TextColor3 = def[2]
		cap.TextScaled = true
		cap.TextWrapped = true
		cap.Text = def[1]
		cap.Parent = col

		local val = Instance.new("TextLabel")
		val.Position = UDim2.new(0, 0, 0.5, 0)
		val.Size = UDim2.new(1, 0, 0.45, 0)
		val.BackgroundTransparency = 1
		val.TextColor3 = def[2]
		val.TextScaled = true
		val.Text = "-"
		val.Parent = col
		heads[i] = val
	end

	-- ---------- แถวกลาง: การ์ด 3 ใบ ----------
	local rows = {}
	for i, def in CARDS do
		local card = Instance.new("Frame")
		card.Position = UDim2.new((i - 1) / 3, 14, 0.4, 0)
		card.Size = UDim2.new(1 / 3, -28, 0.36, 0)
		card.BackgroundColor3 = Color3.new(1, 1, 1)
		card.Parent = frame
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(30, 60, 160)
		st.Thickness = 2
		st.Parent = card

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -8, 0, 20)
		nameLabel.Position = UDim2.new(0, 4, 0, 4)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(30, 60, 160)
		nameLabel.TextScaled = true
		nameLabel.Text = def.name
		nameLabel.Parent = card

		-- ★ ช่องว่างกลางการ์ด = ที่ใส่รูปวาดมือ (ภาพร่างวาดจาน/คน/บ้าน) ตอนนี้ใช้ emoji แทน
		local art = Instance.new("TextLabel")
		art.Name = "ArtSlot"
		art.Position = UDim2.new(0, 4, 0, 26)
		art.Size = UDim2.new(1, -8, 1, -66)
		art.BackgroundTransparency = 1
		art.TextScaled = true
		art.Text = def.icon
		art.Parent = card

		local divider = Instance.new("Frame")
		divider.Position = UDim2.new(0, 0, 1, -34)
		divider.Size = UDim2.new(1, 0, 0, 2)
		divider.BackgroundColor3 = Color3.fromRGB(30, 60, 160)
		divider.BorderSizePixel = 0
		divider.Parent = card

		local amount = Instance.new("TextLabel")
		amount.Position = UDim2.new(0.25, 0, 1, -32)
		amount.Size = UDim2.new(0.5, 0, 0, 30)
		amount.BackgroundTransparency = 1
		amount.TextColor3 = Color3.fromRGB(30, 30, 40)
		amount.TextScaled = true
		amount.Text = "-"
		amount.Parent = card

		local function stepBtn(text, xScale, dir)
			local b = Instance.new("TextButton")
			b.AnchorPoint = Vector2.new(0.5, 0)
			b.Position = UDim2.new(xScale, 0, 1, -31)
			b.Size = UDim2.new(0, 28, 0, 28)
			b.BackgroundColor3 = dir > 0 and Color3.fromRGB(70, 140, 80) or Color3.fromRGB(180, 60, 60)
			b.TextColor3 = Color3.new(1, 1, 1)
			b.TextScaled = true
			b.Text = text
			b.Parent = card
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = b
			b.Activated:Connect(function()
				deps.fireAction({ type = "AdjustSpending", card = def.key, dir = dir })
			end)
		end
		stepBtn("⊖", 0.13, -1)
		stepBtn("⊕", 0.87, 1)

		-- คำเตือน/ผลใจ อยู่ใต้การ์ด (ภาพร่างไม่มี แต่ต้องบอก player ไม่งั้นเล่นไม่รู้เรื่อง)
		local hint = Instance.new("TextLabel")
		hint.Position = UDim2.new((i - 1) / 3, 14, 0.77, 2)
		hint.Size = UDim2.new(1 / 3, -28, 0, 18)
		hint.BackgroundTransparency = 1
		hint.TextColor3 = Color3.fromRGB(110, 110, 120)
		hint.TextScaled = true
		hint.TextWrapped = true
		hint.Text = ""
		hint.Parent = frame

		rows[def.key] = { amount = amount, hint = hint }
	end

	-- ---------- ล่างกลาง: ปุ่ม manage ----------
	local manageBtn = Instance.new("TextButton")
	manageBtn.AnchorPoint = Vector2.new(0.5, 0)
	manageBtn.Position = UDim2.new(0.5, 0, 0.85, 0)
	manageBtn.Size = UDim2.new(0.24, 0, 0, 34)
	manageBtn.BackgroundColor3 = Color3.new(1, 1, 1)
	manageBtn.TextColor3 = Color3.fromRGB(30, 60, 160)
	manageBtn.TextScaled = true
	manageBtn.Text = "👥 manage"
	manageBtn.Parent = frame
	local ms = Instance.new("UIStroke")
	ms.Color = Color3.fromRGB(30, 60, 160)
	ms.Thickness = 2
	ms.Parent = manageBtn
	manageBtn.Activated:Connect(function()
		if deps.openApp then deps.openApp("manage") end
	end)

	-- วันตัดรอบ + ค้างเช่า (ข้อมูลจำเป็น ภาพร่างไม่มีช่อง — วางแถบล่างสุด)
	local footer = Instance.new("TextLabel")
	footer.Position = UDim2.new(0, 8, 1, -26)
	footer.Size = UDim2.new(1, -16, 0, 22)
	footer.BackgroundTransparency = 1
	footer.TextColor3 = Color3.fromRGB(90, 90, 100)
	footer.TextScaled = true
	footer.Text = ""
	footer.Parent = frame

	local app = {}
	function app.refresh(state)
		local w = Config.WeeklyExpenses[state.phase]
		local sp = state.spending or {}
		local S = Config.Spending
		local base = { food = w.food, rent = w.rent, staff = 0 }
		local total = w.internet
		for _, def in CARDS do
			local off = sp[def.key] or 0
			local actual = math.max(0, base[def.key] + off * S[def.key].step)
			total += actual
			rows[def.key].amount.Text = ("฿%d"):format(actual)
			if def.key == "staff" then
				rows[def.key].hint.Text = off > 0 and "งบโบนัสทีม (ผลเมื่อมีพนักงาน)" or "ยังไม่มีพนักงาน"
			elseif off == 0 then
				rows[def.key].hint.Text = "มาตรฐาน"
			elseif def.key == "rent" and off <= S.rent.missedAtOffset then
				rows[def.key].hint.Text = "⚠️ ต่ำกว่าสัญญา = นับค้างเช่าทุกรอบ!"
			else
				local cfg = S[def.key]
				local delta = off > 0 and off * cfg.mentalUp or -off * cfg.mentalDown
				rows[def.key].hint.Text = ("ใจ %+d ต่อสัปดาห์"):format(delta)
			end
		end

		-- income/สัปดาห์ = เงินจากคลิปที่อัปใน 7 วันหลังสุด (clip.day ใส่ตอน uploadClip)
		local income = 0
		for _, c in state.clips do
			if c.uploaded and c.day and (state.day - c.day) < 7 then
				income += math.floor((c.gained or 0) * (Config.MoneyRatePerFollower[state.phase] or 1))
			end
		end

		heads[1].Text = ("฿%d"):format(state.money)
		heads[2].Text = ("฿%d"):format(income)
		heads[3].Text = ("฿%d"):format(total)

		local nextBill = state.day + (7 - (state.day - 1) % 7)
		if nextBill <= state.day then nextBill += 7 end
		footer.Text = ("🌐 เน็ต ฿%d (คงที่) · ตัดรอบวัน %d · ค้างค่าเช่า %d ครั้ง%s"):format(
			w.internet, nextBill, state.flags.rentMissed or 0,
			(state.flags.rentMissed or 0) > 0 and " ⚠️ (2 ครั้ง = โดนไล่ที่!)" or "")
	end
	return app
end

return Bank
