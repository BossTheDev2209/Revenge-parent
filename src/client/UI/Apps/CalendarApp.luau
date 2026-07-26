-- CalendarApp.luau — ปฏิทิน 7 วันข้างหน้า + รับงาน sponsor (design doc §4, PDF หน้า 6)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../shared/Config")

local CalendarApp = {}

function CalendarApp.create(frame, deps)
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Text = "📅 ปฏิทิน"
	local offerHint = Instance.new("TextLabel")
	offerHint.Position = UDim2.new(0, 8, 0, 36)
	offerHint.Size = UDim2.new(1, -16, 0, 20)
	offerHint.BackgroundTransparency = 1
	offerHint.TextScaled = true
	offerHint.TextColor3 = Color3.fromRGB(200, 120, 30)
	offerHint.Text = ""
	offerHint.Parent = frame
	title.Parent = frame

	local rows = {}
	for i = 1, 7 do
		local row = Instance.new("Frame")
		row.Position = UDim2.new(0, 8, 0, 60 + i * 48 - 40)
		row.Size = UDim2.new(1, -16, 0, 42)
		row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		row.Parent = frame
		local dayLabel = Instance.new("TextLabel")
		dayLabel.Size = UDim2.new(0.6, 0, 1, 0)
		dayLabel.BackgroundTransparency = 1
		dayLabel.TextScaled = true
		dayLabel.TextXAlignment = Enum.TextXAlignment.Left
		dayLabel.Parent = row
		local btn = Instance.new("TextButton")
		btn.Position = UDim2.new(0.62, 0, 0, 4)
		btn.Size = UDim2.new(0.36, 0, 1, -8)
		btn.BackgroundColor3 = Color3.fromRGB(255, 170, 60)
		btn.TextScaled = true
		btn.Text = "รับ sponsor"
		btn.Visible = false
		btn.Parent = row
		rows[i] = { label = dayLabel, btn = btn, conn = nil }
	end

	local app = {}
	function app.refresh(state)
		offerHint.Text = state.sponsorOffer and "💼 มีงาน sponsor เข้ามา — เลือกวันวางได้" or ""
		for i = 1, 7 do
			local day = state.day + i
			local r = rows[i]
			local block = state.calendar[day]
			r.label.Text = block
					and ("  วัน %d — %s%s"):format(day, block.type, block.id and (" (" .. block.id .. ")") or "")
				or ("  วัน %d — ว่าง"):format(day)
			-- ปุ่มโผล่เฉพาะตอนมี offer ค้าง (สุ่ม 5%/วัน เฟส 2-3 — ไม่ใช่กดเรียกเอง)
			local canSponsor = not block and state.sponsorOffer == true
			r.btn.Visible = canSponsor
			if r.conn then r.conn:Disconnect() end
			if canSponsor then
				r.conn = r.btn.Activated:Connect(function()
					deps.fireAction({ type = "AcceptSponsor", day = day })
				end)
			end
		end
	end
	return app
end

return CalendarApp
