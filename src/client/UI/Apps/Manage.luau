-- Manage.luau — **layout ตามภาพร่าง `ui screenshot/PC-Bank-2 ui (manage-hire).png`** (PDF หน้า 9 ล่าง, docs/02 §9.8)
--   ซ้าย : "Video per day : x/y" + เส้นคั่น + 3 แถบ speed / Quality / Salary
--   ขวา  : การ์ดพนักงาน 2 คอลัมน์ — ส่วนบน Hirable (แดง) / เส้นคั่นหนา / ส่วนล่าง Active (เขียว)
--   การ์ด: ชื่อ + กรอบรูป (★ เว้นว่างรอรูปวาด) + ปุ่ม hire/fire ซ้าย · speed/Quality/Salary ขวา
-- server ตัดสินเงื่อนไขทั้งหมด — client แค่ยิง action
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../shared/Config")

local Manage = {}

local BLUE = Color3.fromRGB(30, 60, 160)

local function stroke(inst, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color or BLUE
	s.Thickness = thick or 2
	s.Parent = inst
	return s
end

function Manage.create(frame, deps)
	frame.BackgroundColor3 = Color3.fromRGB(238, 240, 245)

	-- ===== ซ้าย: สรุปทีม =====
	local left = Instance.new("Frame")
	left.Position = UDim2.new(0, 8, 0, 8)
	left.Size = UDim2.new(0.36, -12, 1, -16)
	left.BackgroundColor3 = Color3.new(1, 1, 1)
	left.Parent = frame
	stroke(left)

	local perDayLabel = Instance.new("TextLabel")
	perDayLabel.Position = UDim2.new(0, 10, 0.08, 0)
	perDayLabel.Size = UDim2.new(1, -20, 0, 26)
	perDayLabel.BackgroundTransparency = 1
	perDayLabel.TextColor3 = BLUE
	perDayLabel.TextScaled = true
	perDayLabel.TextXAlignment = Enum.TextXAlignment.Left
	perDayLabel.Text = "Video per day : 0/0"
	perDayLabel.Parent = left

	local sep = Instance.new("Frame")
	sep.Position = UDim2.new(0.06, 0, 0.26, 0)
	sep.Size = UDim2.new(0.88, 0, 0, 2)
	sep.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	sep.BorderSizePixel = 0
	sep.Parent = left

	-- 3 แถบ: ชื่อซ้าย ค่าขวา แถบใต้
	local bars = {}
	for i, def in { { "speed", "⏱️" }, { "Quality", "🎬" }, { "Salary", "💵" } } do
		local y = 0.34 + (i - 1) * 0.2
		local cap = Instance.new("TextLabel")
		cap.Position = UDim2.new(0.06, 0, y, 0)
		cap.Size = UDim2.new(0.5, 0, 0, 22)
		cap.BackgroundTransparency = 1
		cap.TextColor3 = BLUE
		cap.TextScaled = true
		cap.TextXAlignment = Enum.TextXAlignment.Left
		cap.Text = ("%s %s"):format(def[1], def[2])
		cap.Parent = left

		local val = Instance.new("TextLabel")
		val.Position = UDim2.new(0.5, 0, y, 0)
		val.Size = UDim2.new(0.44, 0, 0, 22)
		val.BackgroundTransparency = 1
		val.TextColor3 = BLUE
		val.TextScaled = true
		val.TextXAlignment = Enum.TextXAlignment.Right
		val.Text = ": -"
		val.Parent = left

		local track = Instance.new("Frame")
		track.Position = UDim2.new(0.06, 0, y + 0.07, 0)
		track.Size = UDim2.new(0.88, 0, 0, 20)
		track.BackgroundColor3 = Color3.new(1, 1, 1)
		track.Parent = left
		stroke(track)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(0, 0, 1, -4)
		fill.Position = UDim2.new(0, 2, 0, 2)
		fill.BackgroundColor3 = BLUE
		fill.BorderSizePixel = 0
		fill.Parent = track

		bars[def[1]] = { val = val, fill = fill }
	end

	-- ===== ขวา: การ์ดพนักงาน 2 ส่วน =====
	local right = Instance.new("Frame")
	right.Position = UDim2.new(0.36, 4, 0, 8)
	right.Size = UDim2.new(0.64, -12, 1, -16)
	right.BackgroundTransparency = 1
	right.Parent = frame

	local function section(yScale, hScale)
		local sc = Instance.new("ScrollingFrame")
		sc.Position = UDim2.new(0, 0, yScale, 0)
		sc.Size = UDim2.new(1, 0, hScale, 0)
		sc.BackgroundTransparency = 1
		sc.ScrollBarThickness = 4
		sc.CanvasSize = UDim2.new(0, 0, 0, 0)
		sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
		sc.Parent = right
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0.5, -6, 0, 104)
		grid.CellPadding = UDim2.new(0, 6, 0, 6)
		grid.Parent = sc
		return sc
	end
	local hirableList = section(0, 0.56)
	local divider = Instance.new("Frame")
	divider.Position = UDim2.new(0, 0, 0.58, 0)
	divider.Size = UDim2.new(1, 0, 0, 3)
	divider.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	divider.BorderSizePixel = 0
	divider.Parent = right
	local activeList = section(0.61, 0.39)

	-- การ์ด 1 ใบตามภาพร่าง
	local function makeCard(parent, r, hired)
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Color3.new(1, 1, 1)
		card.Parent = parent
		stroke(card)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Position = UDim2.new(0, 6, 0, 4)
		nameLabel.Size = UDim2.new(0.5, 0, 0, 22)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = BLUE
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = r.id
		nameLabel.Parent = card

		local status = Instance.new("TextLabel")
		status.Position = UDim2.new(0.55, 0, 0, 4)
		status.Size = UDim2.new(0.42, -6, 0, 20)
		status.BackgroundTransparency = 1
		status.TextColor3 = hired and Color3.fromRGB(40, 170, 70) or Color3.fromRGB(220, 50, 50)
		status.TextScaled = true
		status.TextXAlignment = Enum.TextXAlignment.Right
		status.Text = hired and "Active" or "Hirable"
		status.Parent = card

		-- ★ กรอบรูปพนักงาน — เว้นว่างรอรูปวาด (ตอนนี้ emoji)
		local portrait = Instance.new("TextLabel")
		portrait.Name = "ArtSlot"
		portrait.Position = UDim2.new(0, 8, 0, 28)
		portrait.Size = UDim2.new(0, 46, 0, 40)
		portrait.BackgroundColor3 = Color3.new(1, 1, 1)
		portrait.TextScaled = true
		portrait.Text = "🧑"
		portrait.Parent = card
		stroke(portrait)

		local btn = Instance.new("TextButton")
		btn.Position = UDim2.new(0, 8, 0, 72)
		btn.Size = UDim2.new(0, 46, 0, 24)
		btn.BackgroundColor3 = Color3.new(1, 1, 1)
		btn.TextColor3 = hired and Color3.fromRGB(180, 50, 50) or BLUE
		btn.TextScaled = true
		btn.Text = hired and "fire" or "hire"
		btn.Parent = card
		stroke(btn, hired and Color3.fromRGB(180, 50, 50) or BLUE)
		btn.Activated:Connect(function()
			deps.fireAction({ type = hired and "FireStaff" or "HireStaff", id = r.id })
		end)

		local stats = Instance.new("TextLabel")
		stats.Position = UDim2.new(0, 62, 0, 28)
		stats.Size = UDim2.new(1, -70, 0, 68)
		stats.BackgroundTransparency = 1
		stats.TextColor3 = BLUE
		stats.TextSize = 13
		stats.TextXAlignment = Enum.TextXAlignment.Left
		stats.TextYAlignment = Enum.TextYAlignment.Top
		stats.Text = ("speed ⏱️ : %d\nQuality 🎬 : %d\nSalary 💵 : %s"):format(
			r.speed, r.quality, r.salary >= 1000 and ("%dk"):format(r.salary / 1000) or tostring(r.salary))
		stats.Parent = card
	end

	local app = {}
	function app.refresh(state)
		local staff = state.staff or {}
		local companions = state.companions or {}

		local speed, quality, salary, n = 0, 0, 0, 0
		for _, m in staff do
			speed += m.speed; quality += m.quality; salary += m.salary or 0; n += 1
		end
		for _, m in companions do
			speed += m.speed; quality += m.quality; n += 1
		end
		local perDay = speed / Config.Staff.clipsPerDayPerSpeed
		local capSpeed = Config.Staff.hireCap * 40 -- สเกลแถบเฉยๆ ไม่ใช่ค่า balance
		perDayLabel.Text = ("Video per day : %.1f/%d"):format(perDay, Config.Staff.hireCap)
		bars.speed.val.Text = (": %d/%d"):format(speed, capSpeed)
		bars.speed.fill.Size = UDim2.new(math.clamp(speed / capSpeed, 0, 1), -4, 1, -4)
		local avgQ = n > 0 and math.floor(quality / n) or 0
		bars.Quality.val.Text = (": %d/100"):format(avgQ)
		bars.Quality.fill.Size = UDim2.new(math.clamp(avgQ / 100, 0, 1), -4, 1, -4)
		bars.Salary.val.Text = (": ฿%d"):format(salary)
		bars.Salary.fill.Size = UDim2.new(math.clamp(salary / 100000, 0, 1), -4, 1, -4)

		for _, list in { hirableList, activeList } do
			for _, ch in list:GetChildren() do
				if ch:IsA("Frame") then ch:Destroy() end
			end
		end
		-- hirable: roster ที่ปลดล็อก (phase+follower+flag ครบ · ตรงกับ StaffService.availableHires) + ยังไม่จ้าง
		for _, r in Config.Staff.roster do
			local hired = false
			for _, s in staff do
				if s.id == r.id then hired = true end
			end
			local unlocked = state.phase >= r.phase and state.follower >= r.follower
				and (not r.flag or (state.flags and state.flags[r.flag]))
			if unlocked and not hired then
				makeCard(hirableList, r, false)
			end
		end
		-- active: ทุกตัวใน state.staff (รวม hire_loyal ที่ auto เข้าตอน split ไม่อยู่ roster) — ใช้ stat ที่เก็บใน state
		for _, s in staff do
			makeCard(activeList, s, true)
		end
	end
	return app
end

return Manage
