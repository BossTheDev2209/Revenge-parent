-- Bank.luau — ยอดเงิน + การ์ดรายจ่าย 3 ใบพร้อม ⊖⊕ (PDF หน้า 9 — user lock 21 ก.ค.)
-- ⊖⊕ ปรับงบ/สัปดาห์เป็น step ต่อการ์ด (Config.Spending) — server ตัดสิน ขอบเขต client แค่ยิง action
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../shared/Config")

local Bank = {}

local CARDS = {
	{ key = "food", icon = "🍚", name = "ค่าอาหาร" },
	{ key = "rent", icon = "🏠", name = "ค่าเช่า" },
	{ key = "staff", icon = "👥", name = "ค่าพนักงาน" },
}

function Bank.create(frame, deps)
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Text = "🏦 Bank"
	title.Parent = frame

	local summary = Instance.new("TextLabel")
	summary.Position = UDim2.new(0, 8, 0, 40)
	summary.Size = UDim2.new(1, -16, 0, 96)
	summary.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	summary.TextScaled = true
	summary.TextWrapped = true
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.TextYAlignment = Enum.TextYAlignment.Top
	summary.Parent = frame

	-- การ์ด 3 ใบ: [ชื่อ+ยอด] [⊖] [⊕] [ผล]
	local rows = {}
	for i, def in CARDS do
		local row = Instance.new("Frame")
		row.Position = UDim2.new(0, 8, 0, 140 + (i - 1) * 62)
		row.Size = UDim2.new(1, -16, 0, 56)
		row.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
		row.Parent = frame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Position = UDim2.new(0, 6, 0, 4)
		nameLabel.Size = UDim2.new(0.4, 0, 0, 28)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local hint = Instance.new("TextLabel")
		hint.Position = UDim2.new(0, 6, 0, 32)
		hint.Size = UDim2.new(1, -12, 0, 20)
		hint.BackgroundTransparency = 1
		hint.TextScaled = true
		hint.TextXAlignment = Enum.TextXAlignment.Left
		hint.TextColor3 = Color3.fromRGB(110, 110, 120)
		hint.Parent = row

		local function stepBtn(text, x, dir)
			local b = Instance.new("TextButton")
			b.Position = UDim2.new(x, 0, 0, 4)
			b.Size = UDim2.new(0, 40, 0, 28)
			b.BackgroundColor3 = dir > 0 and Color3.fromRGB(70, 140, 80) or Color3.fromRGB(160, 70, 70)
			b.TextColor3 = Color3.new(1, 1, 1)
			b.TextScaled = true
			b.Text = text
			b.Parent = row
			b.Activated:Connect(function()
				deps.fireAction({ type = "AdjustSpending", card = def.key, dir = dir })
			end)
		end
		stepBtn("⊖", 0.55, -1)
		stepBtn("⊕", 0.75, 1)

		rows[def.key] = { name = nameLabel, hint = hint }
	end

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
			rows[def.key].name.Text = ("%s %s ฿%d"):format(def.icon, def.name, actual)
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

		local nextBill = state.day + (7 - (state.day - 1) % 7)
		if nextBill <= state.day then nextBill += 7 end
		summary.Text = table.concat({
			("ยอดคงเหลือ: ฿%s"):format(tostring(state.money)),
			("🌐 เน็ต ฿%d (คงที่) | รวม/สัปดาห์ ฿%d — ตัดรอบวัน %d"):format(w.internet, total, nextBill),
			("ค้างค่าเช่า: %d ครั้ง%s"):format(state.flags.rentMissed or 0,
				(state.flags.rentMissed or 0) > 0 and " ⚠️ (2 ครั้ง = โดนไล่ที่!)" or ""),
		}, "\n")
	end
	return app
end

return Bank
