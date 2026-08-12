-- Manage.luau — **layout ตามภาพร่าง `ui screenshot/PC-Bank-2 ui (manage-hire).png`** (PDF หน้า 9 ล่าง, docs/02 §9.8)
--   ซ้าย : "Video per day : x/y" + เส้นคั่น + 3 แถบ speed / Quality / Salary
--   ขวา  : การ์ดพนักงาน 2 คอลัมน์ — ส่วนบน Hirable (แดง) / เส้นคั่นหนา / ส่วนล่าง Active (เขียว)
--   การ์ด: ชื่อ + กรอบรูป (★ เว้นว่างรอรูปวาด) + ปุ่ม hire/fire ซ้าย · speed/Quality/Salary ขวา
-- server ตัดสินเงื่อนไขทั้งหมด — client แค่ยิง action
--
-- ★ baked เป็น instance จริงแล้ว (9 ส.ค.) — โครงคงที่ (แผงซ้าย/แถบ/container ขวา) bake เป็น template
--   การ์ดพนักงานยังสร้างจาก data ตอน refresh (จำนวนเปลี่ยนตาม roster/hire state — ยาวไม่แน่นอนจริง)
--   template จริงอยู่ Gui_PC.Screen.AppTemplates.Manage (แต่งใน Studio ได้)
--   ชื่อลูกที่โค้ดอ้าง ห้ามเปลี่ยน: Left.PerDayLabel · Left.{Speed,Quality,Salary}{Val,Track.Fill}
--   Right.{HirableList, ActiveList} (ScrollingFrame ว่าง มี UIGridLayout ติดมาแล้ว)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../../shared/Config")
-- โมเดลตัวจริงของพนักงานบนการ์ด (12 ส.ค. 2569, user) — ชื่อโมเดลมาจาก roster[].model (Workspace.NPC.HirableNPC)
local ModelViewport = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.ModelViewport)
	else nil

local Manage = {}

local BLUE = Color3.fromRGB(30, 60, 160)

-- ชื่อโมเดลของพนักงาน id นั้น — state.staff เก็บแค่ stat (id/speed/quality/salary) ไม่มี model
-- ต้องย้อนหาใน Config ด้วย id ทั้ง roster และ hire_loyal (ตัว auto ตอน split ไม่อยู่ใน roster)
-- pure: เทสได้ด้วย lune
function Manage.modelNameFor(id: string): string?
	for _, r in Config.Staff.roster do
		if r.id == id then return r.model end
	end
	local loyal = Config.Staff.loyalAfterSplit
	return (loyal and loyal.id == id) and loyal.model or nil
end

local function stroke(inst, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color or BLUE
	s.Thickness = thick or 2
	s.Parent = inst
	return s
end

function Manage.create(frame, deps)
	local guiPC = frame:FindFirstAncestorOfClass("ScreenGui")
	local template = guiPC and guiPC:FindFirstChild("Screen") and guiPC.Screen.AppTemplates:FindFirstChild("Manage")
	if not template then
		warn("[Manage] ไม่มี template Gui_PC.Screen.AppTemplates.Manage — แต่งใน Studio ให้ครบก่อน")
		return {}
	end
	local content = template:Clone()
	content.Name = "ManageContent"
	content.Visible = true -- template ซ่อนไว้ (Visible=false) กัน render ทับกันตอนพักเป็นแม่แบบ — clone ต้องเปิดเอง
	content.Parent = frame

	local left = content:FindFirstChild("Left")
	local perDayLabel = left and left:FindFirstChild("PerDayLabel")
	local bars = {}
	if left then
		for _, key in { "Speed", "Quality", "Salary" } do
			local track = left:FindFirstChild(key .. "Track")
			bars[key] = {
				val = left:FindFirstChild(key .. "Val"),
				fill = track and track:FindFirstChild("Fill"),
			}
		end
	end
	local right = content:FindFirstChild("Right")
	local hirableList = right and right:FindFirstChild("HirableList")
	local activeList = right and right:FindFirstChild("ActiveList")
	-- โมเดลพนักงานทั้งหมดอยู่โฟลเดอร์เดียว (docs/05) — ไม่มีโฟลเดอร์ = การ์ดใช้ emoji เหมือนเดิม
	local npcFolder = workspace:FindFirstChild("NPC")
	local hirableFolder = npcFolder and npcFolder:FindFirstChild("HirableNPC")

	-- การ์ด 1 ใบตามภาพร่าง — ยาวไม่แน่นอน (จำนวนเปลี่ยนตาม roster/hire state) ยังสร้างจาก data
	local function makeCard(parent, r, hired)
		if not parent then return end
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

		-- ★ กรอบรูปพนักงาน — render โมเดลตัวจริงลง ViewportFrame (12 ส.ค. 2569, user)
		--   หาโมเดลไม่เจอ/ไม่มี field model = ตกกลับไปใช้ emoji เหมือนเดิม (ไม่พัง)
		local portrait = Instance.new("TextLabel")
		portrait.Name = "ArtSlot"
		portrait.Position = UDim2.new(0, 8, 0, 28)
		portrait.Size = UDim2.new(0, 46, 0, 40)
		portrait.BackgroundColor3 = Color3.new(1, 1, 1)
		portrait.TextScaled = true
		portrait.Text = "🧑"
		portrait.Parent = card
		stroke(portrait)
		local rigName = Manage.modelNameFor(r.id)
		if ModelViewport and rigName and hirableFolder then
			local vp = ModelViewport.new(portrait)
			if vp.showBust(hirableFolder:FindFirstChild(rigName)) then
				portrait.Text = "" -- โชว์โมเดลแล้ว ไม่ต้องมี emoji ซ้อนหลัง
			else
				vp.destroy()
			end
		end

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
		if perDayLabel then
			perDayLabel.Text = ("Video per day : %.1f/%d"):format(perDay, Config.Staff.hireCap)
		end
		if bars.Speed.val then bars.Speed.val.Text = (": %d/%d"):format(speed, capSpeed) end
		if bars.Speed.fill then bars.Speed.fill.Size = UDim2.new(math.clamp(speed / capSpeed, 0, 1), -4, 1, -4) end
		local avgQ = n > 0 and math.floor(quality / n) or 0
		if bars.Quality.val then bars.Quality.val.Text = (": %d/100"):format(avgQ) end
		if bars.Quality.fill then bars.Quality.fill.Size = UDim2.new(math.clamp(avgQ / 100, 0, 1), -4, 1, -4) end
		if bars.Salary.val then bars.Salary.val.Text = (": ฿%d"):format(salary) end
		if bars.Salary.fill then bars.Salary.fill.Size = UDim2.new(math.clamp(salary / 100000, 0, 1), -4, 1, -4) end

		for _, list in { hirableList, activeList } do
			if list then
				for _, ch in list:GetChildren() do
					if ch:IsA("Frame") then ch:Destroy() end
				end
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
