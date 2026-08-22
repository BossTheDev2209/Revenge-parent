-- Manage — ซ้าย: Video per day + แถบ speed/Quality/Salary · ขวา: การ์ดพนักงาน Hirable/Active (hire/fire)
-- server ตัดสินเงื่อนไขทั้งหมด — client แค่ยิง action
-- baked template อยู่ Gui_PC.Screen.AppTemplates.Manage · ชื่อลูกที่โค้ดอ้าง ห้ามเปลี่ยน:
--   Left.PerDayLabel · Left.{Speed,Quality,Salary}{Val,Track.Fill} · Right.{HirableList, ActiveList}
--   CardTemplate.{NameLabel, Status, ArtSlot, ActionBtn, Stats}
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../../shared/Config")
-- โมเดลตัวจริงของพนักงานบนการ์ด (roster[].model ใน Workspace.NPC.HirableNPC)
local ModelViewport = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.ModelViewport)
	else nil

local Manage = {}

local BLUE = Color3.fromRGB(30, 60, 160)

-- ชื่อโมเดลของ id นั้น — state.staff เก็บแค่ stat · ย้อนหาใน Config ทั้ง roster และ hire_loyal (pure)
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
	content.Visible = true -- template ซ่อนไว้ clone ต้องเปิดเอง
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
	local npcFolder = workspace:FindFirstChild("NPC")
	local hirableFolder = npcFolder and npcFolder:FindFirstChild("HirableNPC") -- ไม่มี = การ์ดใช้ emoji

	-- CardTemplate (user แต่งใน Studio) : Gui_PC.Screen.AppTemplates.Manage.CardTemplate · ไม่มี = fallback code-build
	local cardTemplate = template:FindFirstChild("CardTemplate")
	local dupInClone = content:FindFirstChild("CardTemplate")
	if dupInClone then dupInClone:Destroy() end -- copy ที่ติดมากับ content ลบทิ้ง

	-- เซ็ตค่า dynamic ลงการ์ด (แตะแค่ข้อมูล ไม่แตะ layout/ฟอนต์/พื้นหลัง ซึ่ง user คุมใน template)
	local function populateCard(refs, r, hired)
		if refs.name then refs.name.Text = tostring(r.id) end
		if refs.status then
			refs.status.Text = hired and "Active" or "Hirable"
			refs.status.TextColor3 = hired and Color3.fromRGB(40, 170, 70) or Color3.fromRGB(220, 50, 50)
		end
		if refs.stats then
			refs.stats.Text = ("speed ⏱️ : %d\nQuality 🎬 : %d\nSalary 💵 : %s"):format(
				r.speed, r.quality, r.salary >= 1000 and ("%dk"):format(r.salary / 1000) or tostring(r.salary))
		end
		if refs.btn then
			refs.btn.Text = hired and "fire" or "hire"
			local col = hired and Color3.fromRGB(180, 50, 50) or BLUE
			refs.btn.TextColor3 = col
			local st = refs.btn:FindFirstChildOfClass("UIStroke")
			if st then st.Color = col end
			refs.btn.Activated:Connect(function()
				deps.fireAction({ type = hired and "FireStaff" or "HireStaff", id = r.id })
			end)
		end
		-- กรอบรูป: render โมเดลจริงลง ViewportFrame · ไม่เจอ = emoji เหมือนเดิม
		if refs.portrait then
			refs.portrait.Text = "🧑"
			local rigName = Manage.modelNameFor(r.id)
			if ModelViewport and rigName and hirableFolder then
				local vp = ModelViewport.new(refs.portrait)
				if vp.showBust(hirableFolder:FindFirstChild(rigName)) then
					refs.portrait.Text = ""
				else
					vp.destroy()
				end
			end
		end
	end

	-- fallback: สร้างการ์ดจากโค้ด เมื่อไม่มี CardTemplate ใน Studio
	local function buildCardFromCode(parent, r, hired)
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Color3.new(1, 1, 1)
		card.Parent = parent
		stroke(card)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Position = UDim2.new(0, 6, 0, 4)
		nameLabel.Size = UDim2.new(0.5, 0, 0, 22)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = BLUE
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = card

		local status = Instance.new("TextLabel")
		status.Name = "Status"
		status.Position = UDim2.new(0.55, 0, 0, 4)
		status.Size = UDim2.new(0.42, -6, 0, 20)
		status.BackgroundTransparency = 1
		status.TextScaled = true
		status.TextXAlignment = Enum.TextXAlignment.Right
		status.Parent = card

		local portrait = Instance.new("TextLabel")
		portrait.Name = "ArtSlot"
		portrait.Position = UDim2.new(0, 8, 0, 28)
		portrait.Size = UDim2.new(0, 46, 0, 40)
		portrait.BackgroundColor3 = Color3.new(1, 1, 1)
		portrait.TextScaled = true
		portrait.Parent = card
		stroke(portrait)

		local btn = Instance.new("TextButton")
		btn.Name = "ActionBtn"
		btn.Position = UDim2.new(0, 8, 0, 72)
		btn.Size = UDim2.new(0, 46, 0, 24)
		btn.BackgroundColor3 = Color3.new(1, 1, 1)
		btn.TextScaled = true
		btn.Parent = card
		stroke(btn)

		local stats = Instance.new("TextLabel")
		stats.Name = "Stats"
		stats.Position = UDim2.new(0, 62, 0, 28)
		stats.Size = UDim2.new(1, -70, 0, 68)
		stats.BackgroundTransparency = 1
		stats.TextColor3 = BLUE
		stats.TextSize = 13
		stats.TextXAlignment = Enum.TextXAlignment.Left
		stats.TextYAlignment = Enum.TextYAlignment.Top
		stats.Parent = card

		return { name = nameLabel, status = status, portrait = portrait, btn = btn, stats = stats }
	end

	-- การ์ด 1 ใบ — clone CardTemplate หรือ fallback code-build · จำนวนเปลี่ยนตาม roster
	local function makeCard(parent, r, hired)
		if not parent then return end
		if cardTemplate then
			local card = cardTemplate:Clone()
			card.Name = "Card_" .. tostring(r.id)
			card.Visible = true -- template ซ่อนไว้ clone ต้องเปิดเอง
			card.Parent = parent
			populateCard({
				name = card:FindFirstChild("NameLabel"),
				status = card:FindFirstChild("Status"),
				stats = card:FindFirstChild("Stats"),
				btn = card:FindFirstChild("ActionBtn"),
				portrait = card:FindFirstChild("ArtSlot"),
			}, r, hired)
		else
			populateCard(buildCardFromCode(parent, r, hired), r, hired)
		end
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
		-- hirable: roster ที่ปลดล็อก (ตรงกับ StaffService.availableHires) + ยังไม่จ้าง
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
		-- active: ทุกตัวใน state.staff (รวม hire_loyal ที่ auto เข้าตอน split) — ใช้ stat ที่เก็บใน state
		for _, s in staff do
			makeCard(activeList, s, true)
		end
	end
	return app
end

return Manage
