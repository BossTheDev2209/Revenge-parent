-- RecordTool.luau — ฝั่ง client ของระบบอัดคลิป (docs/02 §9.5)
-- หน้าที่: ผูก Tool 3 ชิ้นใน Backpack → ยิง action RecordFootage + วาดวงโซนถ่าย + นับเวลาโซน
-- server คุมสูตร/cooldown/cap ทั้งหมด ไฟล์นี้แค่บอกว่า "อยู่ในโซนไหม" กับวาดภาพ
--
-- ทีมแมพต้องทำ: วาง Part ชื่อ `FilmSpot_<อะไรก็ได้>` กระจายในแมพหลายจุด (docs/05)
-- ไม่มีสักจุด = ไม่มีโซน อัดได้ที่ base rate ปกติ (ไม่พัง)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../shared/Config")

local RecordTool = {}

-- อยู่ในวงโซนไหม (pure — เทสได้)
function RecordTool.inZone(playerPos, spotPos, radius: number): boolean
	if not spotPos then return false end
	local dx, dz = playerPos.X - spotPos.X, playerPos.Z - spotPos.Z
	return dx * dx + dz * dz <= radius * radius
end

-- ===== Roblox glue =====
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

	-- ผูก Tool ที่ทีมวางไว้ใน StarterPack (ไม่มี = เตือนครั้งเดียว)
	local bound = {}
	local function bindTools()
		for _, name in Config.Record.toolNames do
			local tool = player.Backpack:FindFirstChild(name)
				or (player.Character and player.Character:FindFirstChild(name))
			if tool and tool:IsA("Tool") and not bound[tool] then
				bound[tool] = true
				tool.Activated:Connect(function()
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					local part = spotPart()
					local inside = root ~= nil
						and RecordTool.inZone(root.Position, part and part.Position, Config.Record.zoneRadiusStuds)
					fireAction({ type = "RecordFootage", inZone = inside })
				end)
			end
		end
	end
	bindTools()
	player.CharacterAdded:Connect(function() task.delay(1, bindTools) end)

	-- วงโซนตามจุดปัจจุบัน + นับถอยหลัง
	task.spawn(function()
		while true do
			local s = getState()
			local part = spotPart()
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
