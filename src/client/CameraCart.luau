-- CameraCart.luau — รถเข็นกล้อง IMAX (อุปกรณ์ระดับ 6) นั่งขับได้ + อัดคลิปตอนนั่ง
--
-- ทำไมไม่ใช้ physics/ล้อ: dolly กล้องต้องเคลื่อนนิ่งๆ คุมทิศได้แม่น
-- ล้อ+suspension บนโมเดล 160 ชิ้นจะเด้ง/พลิกคว่ำ และทำให้ภาพที่ถ่ายสั่น
-- → root part anchored ตัวเดียว ที่เหลือ weld ติด แล้วขยับ root ด้วย CFrame ทุกเฟรม
--   ตัวละครที่นั่งอยู่ถูก weld กับ Seat เลยไปด้วยกันเอง ไม่ต้องย้ายเอง
--
-- ทีมแมพต้องทำ: Model ชื่อ `CameraCart` ใน Workspace มี Seat ชื่อ `CartSeat` เป็น PrimaryPart
-- ไม่มีรถในแมพ = ไม่พัง (warn เฉยๆ) — ระดับ 6 แค่ไม่มีอะไรให้ขับ
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../shared/Formulas")

local CameraCart = {}

-- ===== pure (เทสได้) =====

-- ปลดล็อกรถเมื่อระดับกล้องถึงขั้นที่ทำให้ไม่มี Tool ถือแล้ว (Config.CameraCartLevel)
function CameraCart.canDrive(state): boolean
	if not state then return false end
	return Formulas.activeLevel(state, "camera") >= Config.CameraCartLevel
end

-- ความเร็ว/การเลี้ยว 1 เฟรม → (ระยะที่เดินหน้า, มุมที่หมุน เรเดียน)
-- throttle/steer = -1..1 (จาก VehicleSeat หรือ WASD) · dt = เวลาเฟรมนั้น
-- เลี้ยวได้เฉพาะตอนเคลื่อนที่ (เหมือนรถจริง จอดอยู่หมุนอยู่กับที่ไม่ได้)
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

-- ★ offset ที่จะเอาไปคูณกับ CFrame ปัจจุบัน — คำนวณแกนไว้ในนี้ให้เทสจับได้
--   Roblox: "หน้า" ของ part = แกน **−Z** (ตรงกับ LookVector) ไม่ใช่ +X
--   เคยพลาดใช้ CFrame.new(move,0,0) = +X → กด W แล้วรถเดินไปทางขวาแทนเดินหน้า (3 ส.ค.)
function CameraCart.stepOffset(throttle: number, steer: number, dt: number): CFrame
	local move, turn = CameraCart.step(throttle, steer, dt)
	return CFrame.Angles(0, turn, 0) * CFrame.new(0, 0, -move)
end

-- ===== Roblox glue =====

-- deps = { fireAction, getState }
function CameraCart.init(player, fireAction, getState)
	local RunService = game:GetService("RunService")
	local UIS = game:GetService("UserInputService")

	local function cart()
		local m = workspace:FindFirstChild("CameraCart")
		return m, m and m.PrimaryPart or nil
	end

	local seatedRoot = nil -- root ของรถที่กำลังนั่งอยู่ (nil = ไม่ได้นั่ง)

	-- เช็คว่านั่งอยู่บนรถไหม — อ่านจาก Humanoid.SeatPart ทุกครั้งที่สถานะเปลี่ยน
	local function watchCharacter(char)
		local hum = char:WaitForChild("Humanoid", 5)
		if not hum then return end
		hum.Seated:Connect(function(active, seat)
			local m, root = cart()
			if active and seat and root and seat == root then
				if CameraCart.canDrive(getState()) then
					seatedRoot = root
				else
					-- ยังไม่ถึงระดับ 6 = นั่งได้แต่ขับไม่ได้ (บอกให้รู้ ไม่ใช่เงียบ)
					seatedRoot = nil
					warn(("[CameraCart] ต้องมีอุปกรณ์ระดับ %d ก่อนถึงจะขับได้")
						:format(Config.CameraCartLevel))
				end
			else
				seatedRoot = nil
			end
		end)
	end
	if player.Character then watchCharacter(player.Character) end
	player.CharacterAdded:Connect(watchCharacter)

	-- ขับ: WASD (ผ่าน VehicleSeat ก็ได้ แต่ Seat ธรรมดาต้องอ่าน key เอง)
	RunService.RenderStepped:Connect(function(dt)
		if not seatedRoot or not seatedRoot.Parent then return end
		local throttle = 0
		local steer = 0
		if UIS:IsKeyDown(Enum.KeyCode.W) then throttle += 1 end
		if UIS:IsKeyDown(Enum.KeyCode.S) then throttle -= 1 end
		if UIS:IsKeyDown(Enum.KeyCode.D) then steer += 1 end
		if UIS:IsKeyDown(Enum.KeyCode.A) then steer -= 1 end
		if throttle == 0 and steer == 0 then return end

		seatedRoot.CFrame = seatedRoot.CFrame * CameraCart.stepOffset(throttle, steer, dt)
	end)

	-- อัดคลิปตอนนั่ง: คลิกซ้าย (ไม่มี Tool ให้ Activated แล้ว ระดับ 6 ถือมือเปล่า)
	UIS.InputBegan:Connect(function(input, processed)
		if processed then return end -- คลิกโดน UI อยู่ = ไม่นับ
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if not seatedRoot then return end
		local s = getState()
		if not CameraCart.canDrive(s) then return end
		-- โซนถ่ายเช็คจากตำแหน่งรถ (คนนั่งอยู่บนรถ ตำแหน่งเดียวกัน)
		local name = s and s.filmZone and s.filmZone.spot
		local spot = name and workspace:FindFirstChild(name, true)
		local inside = false
		if spot and spot:IsA("BasePart") then
			local d = seatedRoot.Position - spot.Position
			inside = (d.X * d.X + d.Z * d.Z) <= Config.Record.zoneRadiusStuds ^ 2
		end
		fireAction({ type = "RecordFootage", inZone = inside })
	end)
end

return CameraCart
