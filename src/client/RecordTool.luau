-- RecordTool — ฝั่ง client ของระบบอัดคลิป: ผูก Tool → ยิง RecordFootage + วาดวงโซน + นับเวลา
-- server คุมสูตร/cooldown/cap ทั้งหมด ไฟล์นี้แค่บอก "อยู่ในโซนไหม" กับวาดภาพ
-- ทีมแมพ: วาง Part ชื่อ FilmSpot_<อะไรก็ได้> กระจายในแมพ · ไม่มี = อัดที่ base rate (ไม่พัง)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../shared/Formulas")
local Audio = if isStudio
	then require(script.Parent.AudioService)
	else require("./AudioService")

local RecordTool = {}

-- อยู่ในวงโซนไหม (pure)
function RecordTool.inZone(playerPos, spotPos, radius: number): boolean
	if not spotPos then return false end
	local dx, dz = playerPos.X - spotPos.X, playerPos.Z - spotPos.Z
	return dx * dx + dz * dz <= radius * radius
end

function RecordTool.init(player, fireAction, getState)
	local ring = Instance.new("Part")
	ring.Name = "FilmZoneRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Transparency = 0.7
	ring.Color = Color3.fromRGB(255, 70, 70)
	ring.Size = Vector3.new(0.2, Config.Record.zoneRadiusStuds * 2, Config.Record.zoneRadiusStuds * 2)
	ring.CFrame = CFrame.new(0, -500, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 160, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = ring
	local zoneLabel = Instance.new("TextLabel")
	zoneLabel.Size = UDim2.new(1, 0, 1, 0)
	zoneLabel.BackgroundTransparency = 1
	zoneLabel.TextColor3 = Color3.new(1, 1, 1)
	zoneLabel.TextStrokeTransparency = 0.3
	zoneLabel.TextScaled = true
	zoneLabel.Parent = billboard
	billboard.Parent = ring

	local function spotPart()
		local s = getState()
		local name = s and s.filmZone and s.filmZone.spot
		return name and workspace:FindFirstChild(name, true) or nil
	end

	-- ผูก Tool ทุกชิ้นที่ ToolService ส่งมา · Camera_N = RecordFootage · Notebook = วางลงพื้น
	local bound = {}
	local function bindTool(tool)
		if not tool:IsA("Tool") or bound[tool] then return end
		local src = tool:GetAttribute("ToolSource")
		if not src then return end
		if src == Config.CameraCartToolSource then return end -- รถเข็นมี CameraCart คุมเอง (กันยิงซ้อน)
		bound[tool] = true
		tool.Activated:Connect(function()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root then return end
			if src == "Notebook" then
				-- วางห่างตัว 4 studs หันจอเข้าหาผู้เล่น · yaw +90° เพราะจอกางตามแกน local X ของฐาน ไม่ใช่ LookVector
				-- (ยืนยันจริงใน Studio: +90° dot +1.0 หันมา | -90° หันหลัง | 0/180° หันข้าง)
				local cf = root.CFrame * CFrame.new(0, -2.5, -4) * CFrame.Angles(0, math.pi / 2, 0)
				Audio.sfx("notebook_place")
				fireAction({ type = "PlaceNotebook", cf = cf })
			else
				local part = spotPart()
				local inside = RecordTool.inZone(root.Position, part and part.Position, Config.Record.zoneRadiusStuds)
				fireAction({ type = "RecordFootage", inZone = inside })
			end
		end)
	end
	local function bindAll()
		local bp = player:FindFirstChildOfClass("Backpack")
		if bp then
			for _, t in bp:GetChildren() do bindTool(t) end
		end
		if player.Character then
			for _, t in player.Character:GetChildren() do bindTool(t) end
		end
	end

	-- Roblox สร้าง Backpack ใหม่ทุกครั้งที่ตัวละครเกิด — ต้องต่อ ChildAdded กับตัวใหม่ทุกรอบ
	-- (ไม่งั้น Tool ที่มาทีหลัง — ซื้อกล้องใหม่/ข้ามเฟส — ไม่มีใครผูก = คลิกแล้วเงียบ)
	local function hookBackpack(child)
		if not child:IsA("Backpack") then return end
		for _, t in child:GetChildren() do bindTool(t) end
		child.ChildAdded:Connect(bindTool)
	end

	bindAll()
	local bp0 = player:FindFirstChildOfClass("Backpack")
	if bp0 then hookBackpack(bp0) end
	player.ChildAdded:Connect(hookBackpack)
	player.CharacterAdded:Connect(function() task.delay(1, bindAll) end)

	-- ตัวเลขลอยตอนอัดติด "+1.2" / "+2.4 Bonus!" — อ่านจากส่วนต่าง footageGB (server คิด ที่นี่แค่โชว์)
	local function floatGain(amount: number, bonus: boolean)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = root.CFrame * CFrame.new(math.random(-70, 70) / 10, math.random(0, 40) / 10, math.random(-50, 20) / 10)
		anchor.Parent = workspace

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 160, 0, 44)
		bb.AlwaysOnTop = true
		bb.Adornee = anchor
		bb.Parent = anchor
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 1, 0)
		l.BackgroundTransparency = 1
		l.TextColor3 = Color3.fromRGB(180, 110, 255)
		l.TextStrokeTransparency = 0.4
		l.TextScaled = true
		l.Text = bonus and ("+%.1f Bonus!"):format(amount) or ("+%.1f"):format(amount)
		l.Parent = bb
		Audio.sfx(bonus and "record_bonus" or "record_gain", nil, 0.5)

		local tween = game:GetService("TweenService"):Create(l, TweenInfo.new(1.2), {
			TextTransparency = 1, TextStrokeTransparency = 1,
		})
		tween:Play()
		tween.Completed:Connect(function() anchor:Destroy() end)
	end

	task.spawn(function()
		local prev = nil
		while true do
			local s = getState()
			local now = s and s.footageGB or nil
			if prev and now and now > prev + 0.001 then
				local gained = now - prev
				local base = Config.Record.footagePerClickGB[Formulas.activeLevel(s, "camera")]
					or Config.Record.footagePerClickGB[1]
				floatGain(gained, gained > base + 0.001) -- ได้เกิน base = ติดโบนัสโซน
			end
			prev = now
			task.wait(0.1)
		end
	end)

	-- เข้าโซน: เช็คทุกเฟรมแยกจากลูปวาดวง — ต้องได้ยินเสียงทันที (เล่นเฉพาะตอนเข้า)
	do
		local wasInside = false
		game:GetService("RunService").Heartbeat:Connect(function()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local part = spotPart()
			local inside = root ~= nil and RecordTool.inZone(root.Position, part and part.Position, Config.Record.zoneRadiusStuds)
			if inside and not wasInside then
				Audio.sfx("zone_enter")
			end
			wasInside = inside
		end)
	end

	-- วงโซนตามจุดปัจจุบัน + นับถอยหลัง · hideBillboards คุมทั้งวงและตัวเลขตรงนี้เอง
	local RING_TRANSPARENCY = ring.Transparency
	task.spawn(function()
		while true do
			local s = getState()
			local part = spotPart()
			local hideAll = s and s.settings and s.settings.hideBillboards
			ring.Transparency = hideAll and 1 or RING_TRANSPARENCY
			zoneLabel.TextTransparency = hideAll and 1 or 0
			zoneLabel.TextStrokeTransparency = hideAll and 1 or 0.3
			if part then
				ring.CFrame = CFrame.new(part.Position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
				local left = math.max(0, (s.filmZone.expiresAt or 0) - os.clock())
				zoneLabel.Text = ("×%.1f  %ds"):format(
					Config.Record.zoneMultByPhase[s.phase] or 1, math.floor(left))
			else
				ring.CFrame = CFrame.new(0, -500, 0) * CFrame.Angles(0, 0, math.rad(90))
			end
			task.wait(0.5)
		end
	end)
end

return RecordTool
