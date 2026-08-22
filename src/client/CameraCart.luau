-- CameraCart — รถเข็นกล้อง IMAX (ระดับ 6): ถือ Tool Camera_6 · กดตอนยืน = เสกรถ · นั่งขับ WASD · กดตอนนั่ง = อัดคลิป
-- ไม่ใช้ physics/ล้อ (ภาพสั่น): root part เดียว anchored ที่เหลือ weld ติด ขยับ root ด้วย CFrame ทุกเฟรม
-- template อยู่ ReplicatedStorage.ToolModels.CameraCart (Seat = PrimaryPart + anchored ตัวเดียว) · ไม่มี = warn เฉยๆ
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../shared/Formulas")

local CameraCart = {}

-- ปลดล็อกรถเมื่อระดับกล้องที่ถืออยู่จริงถึงขั้น (ย้อนไปใช้ระดับต่ำ = เรียกไม่ได้)
function CameraCart.canDrive(state): boolean
	if not state then return false end
	return Formulas.activeLevel(state, "camera") >= Config.CameraCartLevel
end

-- 1 เฟรม → (ระยะเดินหน้า, มุมหมุน) · throttle/steer = -1..1 · เลี้ยวได้เฉพาะตอนเคลื่อนที่
function CameraCart.step(throttle: number, steer: number, dt: number): (number, number)
	local t = math.clamp(throttle, -1, 1)
	local s = math.clamp(steer, -1, 1)
	local move = t * Config.CameraCartSpeed * dt
	local turn = 0
	if math.abs(move) > 1e-4 then
		turn = -s * Config.CameraCartTurnRate * dt * (move >= 0 and 1 or -1) -- ถอยหลัง = เลี้ยวกลับทาง
	end
	return move, turn
end

-- offset คูณกับ CFrame ปัจจุบัน · ⚠️ "หน้า" ของ part = แกน −Z (LookVector) ไม่ใช่ +X
function CameraCart.stepOffset(throttle: number, steer: number, dt: number): CFrame
	local move, turn = CameraCart.step(throttle, steer, dt)
	return CFrame.Angles(0, turn, 0) * CFrame.new(0, 0, -move)
end

-- deps = { fireAction, getState }
function CameraCart.init(player, fireAction, getState)
	local RunService = game:GetService("RunService")
	local UIS = game:GetService("UserInputService")

	-- นั่งบนรถคันปัจจุบันไหม — เช็ค SeatPart จริง ณ ตอนนั้น (event hum.Seated อาจ stale → เสกรถทับคันที่นั่ง)
	local function seatedOnCart()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local m = workspace:FindFirstChild(Config.CameraCartTemplate)
		local root = m and m.PrimaryPart
		return (hum and root and hum.SeatPart == root) and root or nil
	end

	-- แรงโน้มถ่วงจำลอง: รถ anchored ไม่ตกเอง → raycast หาพื้นแล้วยกฐานให้แตะพื้น · ไม่เจอพื้น = คืน CFrame เดิม
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	local function restOnGround(model, seat, goalCF)
		groundParams.FilterDescendantsInstances = { model, player.Character }
		local cf, size = model:GetBoundingBox()
		local baseToSeat = seat.Position.Y - (cf.Position.Y - size.Y / 2) -- seat→ฐาน (คงที่ รถ weld แข็ง)
		local from = Vector3.new(goalCF.X, goalCF.Y + size.Y, goalCF.Z)
		local hit = workspace:Raycast(from, Vector3.new(0, -size.Y * 6, 0), groundParams)
		if not hit then return goalCF end
		return CFrame.new(goalCF.X, hit.Position.Y + baseToSeat, goalCF.Z) * (goalCF - goalCF.Position)
	end

	-- ขับด้วย WASD (Seat ธรรมดาไม่ส่ง Throttle/Steer เหมือน VehicleSeat ต้องอ่าน key เอง)
	RunService.RenderStepped:Connect(function(dt)
		local seat = seatedOnCart()
		if not seat then return end
		local model = workspace:FindFirstChild(Config.CameraCartTemplate) -- ตัวบนสุด (seat.Parent ไม่ใช่ตัวบนสุด)
		if not model then return end
		local throttle, steer = 0, 0
		if UIS:IsKeyDown(Enum.KeyCode.W) then throttle += 1 end
		if UIS:IsKeyDown(Enum.KeyCode.S) then throttle -= 1 end
		if UIS:IsKeyDown(Enum.KeyCode.D) then steer += 1 end
		if UIS:IsKeyDown(Enum.KeyCode.A) then steer -= 1 end
		if throttle == 0 and steer == 0 then return end
		local goal = seat.CFrame * CameraCart.stepOffset(throttle, steer, dt)
		seat.CFrame = restOnGround(model, seat, goal)
	end)

	-- Tool กล้องที่เป็นรีโมทเรียกรถ · กดตอนยืน = เสกรถ · กดตอนนั่ง = อัดคลิป
	local bound = setmetatable({}, { __mode = "k" }) -- weak: Tool โดนลบแล้วปล่อยหลุด
	local function bindTool(tool)
		if not tool:IsA("Tool") or bound[tool] then return end
		if tool:GetAttribute("ToolSource") ~= Config.CameraCartToolSource then return end
		bound[tool] = true
		tool.Activated:Connect(function()
			local s = getState()
			if not CameraCart.canDrive(s) then return end
			local seat = seatedOnCart()
			if seat then
				-- นั่งอยู่ = อัดคลิป (เช็คโซนจากตำแหน่งรถ)
				local name = s and s.filmZone and s.filmZone.spot
				local spot = name and workspace:FindFirstChild(name, true)
				local inside = false
				if spot and spot:IsA("BasePart") then
					local d = seat.Position - spot.Position
					inside = (d.X * d.X + d.Z * d.Z) <= Config.Record.zoneRadiusStuds ^ 2
				end
				fireAction({ type = "RecordFootage", inZone = inside })
			else
				fireAction({ type = "SummonCart" }) -- server เสกให้ (Seat ต้องเป็นของจริงฝั่ง server)
			end
		end)
	end

	-- Backpack ถูกสร้างใหม่ทุกครั้งที่ตัวละครเกิด → ต้องต่อ ChildAdded กับตัวใหม่ทุกรอบ
	local function bindAll()
		local bp = player:FindFirstChildOfClass("Backpack")
		if bp then for _, t in bp:GetChildren() do bindTool(t) end end
		if player.Character then for _, t in player.Character:GetChildren() do bindTool(t) end end
	end
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

	-- ป้ายบอกวิธีเล่นเหนือรถ (ดีไซน์ ยืน=เสก / นั่ง=อัด คนเล่นไม่รู้ว่าต้องขึ้นนั่งก่อน)
	local hintGui = Instance.new("BillboardGui")
	hintGui.Name = "CartHint"
	hintGui.Size = UDim2.new(0, 230, 0, 54)
	hintGui.StudsOffset = Vector3.new(0, 4.5, 0)
	hintGui.AlwaysOnTop = true
	hintGui.Enabled = false
	local hintLabel = Instance.new("TextLabel")
	hintLabel.Size = UDim2.new(1, 0, 1, 0)
	hintLabel.BackgroundTransparency = 1
	hintLabel.TextColor3 = Color3.new(1, 1, 1)
	hintLabel.TextStrokeTransparency = 0.25
	hintLabel.TextScaled = true
	hintLabel.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	hintLabel.Parent = hintGui
	hintGui.Parent = player:WaitForChild("PlayerGui")

	local seatedAt = nil -- os.clock ตอนเพิ่งนั่ง (nil = ยังไม่นั่ง)
	task.spawn(function()
		while true do
			local m = workspace:FindFirstChild(Config.CameraCartTemplate)
			local seat = m and m.PrimaryPart
			if seat then
				hintGui.Adornee = seat
				if seatedOnCart() then
					if not seatedAt then seatedAt = os.clock() end
					-- โชว์ป้าย 2 วิแรกหลังนั่ง แล้วซ่อน (รู้แล้วไม่ต้องเตือนค้างบังจอ)
					hintLabel.Text = "🎬 กดกล้องเพื่ออัดคลิป"
					hintGui.Enabled = (os.clock() - seatedAt) < 2
				else
					seatedAt = nil
					hintLabel.Text = "⬆️ ขึ้นนั่งเพื่ออัดคลิป"
					hintGui.Enabled = true
				end
			else
				seatedAt = nil
				hintGui.Enabled = false
			end
			task.wait(0.25)
		end
	end)
end

return CameraCart
