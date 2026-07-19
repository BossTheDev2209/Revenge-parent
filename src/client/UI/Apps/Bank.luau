-- Bank.luau — ยอดเงิน + รายจ่ายราย 7 วันตามเฟส (PDF หน้า 9, design doc §4) — อ่านอย่างเดียว
-- จ้าง/ไล่พนักงาน = แอป Manage (ยังไม่ scope)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../shared/Config")

local Bank = {}

function Bank.create(frame, deps)
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Text = "🏦 Bank"
	title.Parent = frame

	local body = Instance.new("TextLabel")
	body.Position = UDim2.new(0, 8, 0, 40)
	body.Size = UDim2.new(1, -16, 1, -48)
	body.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	body.TextScaled = true
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = frame

	local app = {}
	function app.refresh(state)
		local w = Config.WeeklyExpenses[state.phase]
		local total = w.rent + w.internet + w.food
		-- วันตัดรอบถัดไป: วัน 8, 15, 22, ... (day-1)%7==0
		local nextBill = state.day + (7 - (state.day - 1) % 7)
		if nextBill <= state.day then nextBill += 7 end
		body.Text = table.concat({
			("ยอดคงเหลือ: ฿%s"):format(tostring(state.money)),
			"",
			("รายจ่ายต่อสัปดาห์ (เฟส %d):"):format(state.phase),
			("  🏠 ค่าเช่า ฿%d"):format(w.rent),
			("  🌐 เน็ต ฿%d"):format(w.internet),
			("  🍚 ค่ากิน ฿%d"):format(w.food),
			("  รวม ฿%d — ตัดรอบวัน %d"):format(total, nextBill),
			"",
			("ค้างค่าเช่า: %d ครั้ง%s"):format(state.flags.rentMissed or 0,
				(state.flags.rentMissed or 0) > 0 and " ⚠️ (2 ครั้ง = โดนไล่ที่!)" or ""),
		}, "\n")
	end
	return app
end

return Bank
