-- Manage.luau — จ้าง/ไล่พนักงาน (PDF หน้า 9 ล่าง, docs/02 §9.8)
-- ซ้าย: สรุปทีม | ขวา: การ์ดพนักงาน hire/fire — server ตัดสินเงื่อนไขทั้งหมด
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../shared/Config")

local Manage = {}

local function label(parent, y, h, text, size)
	local l = Instance.new("TextLabel")
	l.Position = UDim2.new(0, 6, 0, y)
	l.Size = UDim2.new(1, -12, 0, h)
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextSize = size or 16
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	return l
end

function Manage.create(frame, deps)
	-- ซ้าย: สรุปทีม
	local summary = Instance.new("Frame")
	summary.Position = UDim2.new(0, 6, 0, 6)
	summary.Size = UDim2.new(0.35, -8, 1, -12)
	summary.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
	summary.Parent = frame
	local sumTitle = label(summary, 6, 24, "👥 ทีมของเรา", 18)
	local sumBody = label(summary, 36, 200, "")

	-- ขวา: การ์ดพนักงาน
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0.35, 6, 0, 6)
	list.Size = UDim2.new(0.65, -12, 1, -12)
	list.BackgroundTransparency = 1
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.Parent = frame
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -8, 0, 96)
	grid.CellPadding = UDim2.new(0, 6, 0, 6)
	grid.Parent = list

	local app = {}
	function app.refresh(state)
		local staff = state.staff or {}
		local companions = state.companions or {}

		-- สรุปทีม (นับ companion ด้วย)
		local speed, quality, salary, n = 0, 0, 0, 0
		for _, m in staff do
			speed += m.speed; quality += m.quality; salary += m.salary or 0; n += 1
		end
		for _, m in companions do
			speed += m.speed; quality += m.quality; n += 1
		end
		local perDay = speed / Config.Staff.clipsPerDayPerSpeed
		sumBody.Text = table.concat({
			("คลิป/วัน: %.1f"):format(perDay),
			("Speed รวม: %d"):format(speed),
			("Quality เฉลี่ย: %d"):format(n > 0 and math.floor(quality / n) or 0),
			("Salary/สัปดาห์: ฿%d"):format(salary),
			"",
			("จ้างแล้ว %d / %d"):format(#staff, Config.Staff.hireCap),
			("เพื่อนร่วมทาง: %d (ฟรี)"):format(#companions),
		}, "\n")

		-- การ์ด: โชว์เฉพาะที่ปลดล็อกแล้ว (phase และ follower ครบ)
		for _, ch in list:GetChildren() do
			if ch:IsA("Frame") then ch:Destroy() end
		end
		for _, r in Config.Staff.roster do
			local unlocked = state.phase >= r.phase and state.follower >= r.follower
			if unlocked then
				local hired = false
				for _, s in staff do
					if s.id == r.id then hired = true end
				end

				local card = Instance.new("Frame")
				card.BackgroundColor3 = hired and Color3.fromRGB(230, 250, 230) or Color3.fromRGB(255, 255, 255)
				card.Parent = list
				label(card, 4, 20, ("%s  %s"):format(r.id, hired and "🟢 Active" or "🔴 Hirable"), 15)
				label(card, 26, 44, ("⚡ Speed %d\n⭐ Quality %d\n💰 ฿%d/สัปดาห์"):format(r.speed, r.quality, r.salary), 13)

				local btn = Instance.new("TextButton")
				btn.Position = UDim2.new(1, -76, 1, -30)
				btn.Size = UDim2.new(0, 70, 0, 26)
				btn.BackgroundColor3 = hired and Color3.fromRGB(180, 70, 70) or Color3.fromRGB(70, 140, 80)
				btn.TextColor3 = Color3.new(1, 1, 1)
				btn.TextScaled = true
				btn.Text = hired and "fire" or "hire"
				btn.Parent = card
				btn.Activated:Connect(function()
					deps.fireAction({ type = hired and "FireStaff" or "HireStaff", id = r.id })
				end)
			end
		end
	end
	return app
end

return Manage
