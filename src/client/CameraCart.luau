-- CameraCart.luau — รถเข็นกล้อง IMAX (อุปกรณ์ระดับ 6) เรียกออกมาด้วย Tool + นั่งขับ
--
-- ดีไซน์ (user lock 5 ส.ค.): กล้องอยู่กับ player ตลอด ไม่ได้เอา Tool ออก
--   ถือ Tool `Camera_6` อยู่ → กดตอนยืน = **เสกรถออกมาใหม่หน้าตัว** (คันเก่าถูกลบ)
--   ขึ้นไปนั่ง → WASD ขับ · กดตอนนั่ง = อัดคลิป (ใช้ตัวคูณระดับ 6 ตามปกติ)
--
-- ทำไมไม่ใช้ physics/ล้อ: dolly กล้องต้องเคลื่อนนิ่ง คุมทิศแม่น
-- ล้อ+suspension บนโมเดล ~160 ชิ้นจะเด้ง/พลิกคว่ำ ภาพที่ถ่ายสั่น
-- → root part anchored ตัวเดียว ที่เหลือ weld ติด แล้วขยับ root ด้วย CFrame ทุกเฟรม
--   ตัวละครที่นั่งถูก weld กับ Seat อยู่แล้ว เลยไปด้วยกันเอง ไม่ต้องย้ายเอง
--
-- ทีมแมพ: template อยู่ที่ `ReplicatedStorage.ToolModels.CameraCart`
--   ต้องมี Seat เป็น PrimaryPart + anchored ตัวเดียว · ชิ้นอื่น weld ติด Seat + ไม่ anchored
-- ไม่มี template = warn เฉยๆ ไม่พัง (กดเรียกแล้วไม่มีอะไรโผล่)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../shared/Formulas")

local CameraCart = {}

-- ===== pure (เทสได้) =====

-- ปลดล็อกรถเมื่อระดับกล้อง "ที่ถืออยู่จริง" ถึงขั้นที่กำหนด (ย้อนไปใช้ระดับต่ำ = เรียกไม่ได้)
function CameraCart.canDrive(state): boolean
	if not state then return false end
	return Formulas.activeLevel(state, "camera") >= Config.CameraCartLevel
end

-- ความเร็ว/การเลี้ยว 1 เฟรม → (ระยะที่เดินหน้า, มุมที่หมุน เรเดียน)
-- throttle/steer = -1..1 · dt = เวลาเฟรมนั้น
-- เลี้ยวได้เฉพาะตอนเคลื่อนที่ (เหมือนรถจริง จอดอยู่หมุนกับที่ไม่ได้)
function CameraCart.step(throttle: number, steer: number, dt: number): (number, number)
	local t = math.clamp(throttle, -1, 1)
	local s = math.clamp(steer, -1, 1)
	local move = t * Config.CameraCartSpeed * dt
	local turn = 0
	if math.abs(move) > 1e-4 then
		-- ถอยหลังให้เลี้ยวกลับทางเหมือนรถจริง
		turn = -s * Config.CameraCartTurnRate * dt * (move >= 0 and 1 or -1)
	end
	return move, turn
end

-- ★ offset ที่เอาไปคูณกับ CFrame ปัจจุบัน — คำนวณแกนไว้ในนี้ให้เทสจับได้
--   Roblox: "หน้า" ของ part = แกน **−Z** (ตรงกับ LookVector) ไม่ใช่ +X
--   เคยพลาดใช้ CFrame.new(move,0,0) = +X → กด W แล้วรถเดินไปทางขวา (3 ส.ค.)
function CameraCart.stepOffset(throttle: number, steer: number, dt: number): CFrame
	local move, turn = CameraCart.step(throttle, steer, dt)
	return CFrame.Angles(0, turn, 0) * CFrame.new(0, 0, -move)
end

-- ===== Roblox glue =====

-- deps = { fireAction, getState }
function CameraCart.init(player, fireAction, getState)
	local RunService = game:GetService("RunService")
	local UIS = game:GetService("UserInputService")

	local seatedRoot = nil -- root ของรถที่กำลังนั่ง (nil = ไม่ได้นั่ง)

	local function cartRoot()
		local m = workspace:FindFirstChild(Config.CameraCartTemplate)
		return m and m.PrimaryPart or nil
	end

	-- นั่งอยู่บนรถไหม — เช็คทุกครั้งที่สถานะนั่งเปลี่ยน (รถถูกเสกใหม่เรื่อยๆ เทียบ instance ตรงๆ ไม่ได้)
	local function watchCharacter(char)
		local hum = char:WaitForChild("Humanoid", 5)
		if not hum then return end
		hum.Seated:Connect(function(active, seat)
			seatedRoot = (active and seat and seat == cartRoot()) and seat or nil
		end)
	end
	if player.Character then watchCharacter(player.Character) end
	player.CharacterAdded:Connect(watchCharacter)

	-- ขับด้วย WASD (Seat ธรรมดาไม่ส่ง Throttle/Steer เหมือน VehicleSeat ต้องอ่าน key เอง)
	RunService.RenderStepped:Connect(function(dt)
		if not seatedRoot or not seatedRoot.Parent then return end
		local throttle, steer = 0, 0
		if UIS:IsKeyDown(Enum.KeyCode.W) then throttle += 1 end
		if UIS:IsKeyDown(Enum.KeyCode.S) then throttle -= 1 end
		if UIS:IsKeyDown(Enum.KeyCode.D) then steer += 1 end
		if UIS:IsKeyDown(Enum.KeyCode.A) then steer -= 1 end
		if throttle == 0 and steer == 0 then return end
		seatedRoot.CFrame = seatedRoot.CFrame * CameraCart.stepOffset(throttle, steer, dt)
	end)

	-- ★ ผูก Tool กล้องที่เป็นรีโมทเรียกรถ (RecordTool ข้าม ToolSource ตัวนี้ให้แล้ว)
	--   กดตอนยืน = เสกรถ · กดตอนนั่งบนรถ = อัดคลิป
	local bound = setmetatable({}, { __mode = "k" }) -- weak: Tool โดนลบแล้วปล่อยหลุด
	local function bindTool(tool)
		if not tool:IsA("Tool") or bound[tool] then return end
		if tool:GetAttribute("ToolSource") ~= Config.CameraCartToolSource then return end
		bound[tool] = true
		tool.Activated:Connect(function()
			local s = getState()
			if not CameraCart.canDrive(s) then return end
			if seatedRoot then
				-- นั่งอยู่ = อัดคลิป (เช็คโซนจากตำแหน่งรถ คนนั่งอยู่บนรถ ตำแหน่งเดียวกัน)
				local name = s and s.filmZone and s.filmZone.spot
				local spot = name and workspace:FindFirstChild(name, true)
				local inside = false
				if spot and spot:IsA("BasePart") then
					local d = seatedRoot.Position - spot.Position
					inside = (d.X * d.X + d.Z * d.Z) <= Config.Record.zoneRadiusStuds ^ 2
				end
				fireAction({ type = "RecordFootage", inZone = inside })
			else
				fireAction({ type = "SummonCart" }) -- server เสกให้ (Seat ต้องเป็นของจริงฝั่ง server)
			end
		end)
	end

	-- Backpack ถูกสร้างใหม่ทุกครั้งที่ตัวละครเกิด → ต้องต่อ ChildAdded กับตัวใหม่ทุกรอบ
	-- (บทเรียนเดียวกับ RecordTool 28 ก.ค.: ต่อครั้งเดียว = Tool ที่มาทีหลังไม่ถูกผูก)
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
end

return CameraCart
