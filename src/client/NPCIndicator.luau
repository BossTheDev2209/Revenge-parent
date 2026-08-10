-- NPCIndicator.luau — วงขาวใต้เท้า NPC + หันตัวมองผู้เล่นเมื่อเข้าใกล้ (จำกัดองศาจากทิศตั้งต้น)
--
-- ★ component ล้วน ไม่ผูกกับระบบไหน — เรียก attach เมื่อไหร่ก็ได้ ไม่แตะ InteractBinder/Dialogue/บทพูด
--   ยังไม่ได้เปิดใช้อัตโนมัติ (ตั้งใจ — กันชนกับงานที่ทำค้างอยู่) เปิดเมื่อพร้อมด้วย:
--     local NPCIndicator = require(script.Parent.NPCIndicator)
--     NPCIndicator.attachAll(workspace.NPC.WorldNPC)       -- ทั้งโฟลเดอร์
--     NPCIndicator.attachAll(workspace.NPC.StoryNPC)       -- StoryNPC ก็ใช้ตัวเดียวกัน
--     local h = NPCIndicator.attach(someModel, { maxAngle = 45 })   -- ทีละตัว + ปรับค่า
--     h:destroy()                                          -- ถอดคืน (ลบวง + คืนท่าหันตั้งต้น)
--
-- วงแหวน = SurfaceGui + UICorner(0.5) + UIStroke — **ไม่ใช้ asset/decal ภายนอกเลย**
--   (หา decal วงกลมฟรีใน Toolbox ได้ แต่ asset ภายนอกโดน moderate/หายได้ ของ built-in คุมเองจบกว่า)
--
-- **หันทั้งตัวแบบ stiff** — `model:PivotTo(basePivot * CFrame.Angles(0, yaw, 0))` หมุนรอบแกน Y ทั้งโมเดล
--   ไม่ยุ่ง Motor6D/ข้อต่อคอ ไม่ต้องมี IKControl · ทำงานได้ทั้ง rig ที่ anchor เฉพาะ HumanoidRootPart
--   และที่ anchor ทุกชิ้น (PivotTo ย้าย CFrame ให้ทุก part ตรงๆ) — ดู docs/05 §3 เรื่อง anchor NPC
--   Dev Forum ที่มีอยู่เป็นสูตรหันเฉพาะหัวด้วย Motor6D ซึ่งซับซ้อนกว่าและยังไม่มี thread ไหนแก้ clamp ได้จบ
--
-- clamp องศา: **wrap เข้าช่วง ±180 ก่อน แล้วค่อย clamp** (ดู clampYawDelta)
--   ไม่ wrap ก่อน = ทิศตั้งต้นใกล้ ±180 ค่าจะเด้งเป็น ±340 แล้ว clamp ผิดข้าง — บั๊กที่คนใน Dev Forum ติดกัน
-- isStudio guard: yawOf/clampYawDelta pure ล้วน เทสได้ด้วย lune (ไม่มี `game` ตอน require)
local isStudio = script ~= nil
local RunService = isStudio and game:GetService("RunService")
local Players = isStudio and game:GetService("Players")

local NPCIndicator = {}

local DEFAULTS = {
	radius = 3.2, -- รัศมีวง (studs)
	color = Color3.new(1, 1, 1),
	thickness = 6, -- ความหนาเส้นวง (px บน SurfaceGui)
	transparency = 0.15,
	lookRadius = 14, -- เข้าใกล้กว่านี้ = เริ่มหันมอง (studs)
	maxAngle = 70, -- หันได้ไม่เกินกี่องศาจากทิศที่วางไว้ตอนแรก (ซ้าย/ขวาข้างละเท่านี้)
	turnSpeed = 6, -- ความไวในการหัน (ยิ่งมากยิ่งเด้งไว)
	ringVisible = true,
}

-- ===== pure (เทสด้วย lune) =====

-- มุมหันของทิศทาง: หน้าโมเดล (0,0,-1) = 0 เรเดียน · หมุนทวนเข็มเมื่อมองจากด้านบนเป็นบวก
-- ใช้คู่กับ CFrame.Angles(0, yaw, 0) ได้ตรงๆ
function NPCIndicator.yawOf(dirX: number, dirZ: number): number
	return math.atan2(-dirX, -dirZ)
end

-- ส่วนต่างมุมที่หันได้จริง เทียบทิศตั้งต้น — **wrap เข้าช่วง ±180 ก่อน แล้วค่อย clamp**
-- ไม่ wrap ก่อน = ตอนทิศตั้งต้นอยู่ใกล้ ±180 ค่าจะเด้งเป็น ±340 แล้ว clamp ผิดข้าง (บั๊กที่ Dev Forum ติด)
function NPCIndicator.clampYawDelta(baseYaw: number, targetYaw: number, maxAngleDeg: number): number
	local d = (targetYaw - baseYaw) % (2 * math.pi)
	if d > math.pi then d -= 2 * math.pi end
	local limit = math.rad(math.abs(maxAngleDeg))
	return math.clamp(d, -limit, limit)
end

-- ===== วงแหวน =====

local function buildRing(model: Model, opts): Part
	local cf, size = model:GetBoundingBox()
	local d = opts.radius * 2

	local ring = Instance.new("Part")
	ring.Name = "NPCRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Transparency = 1 -- ตัว Part ไม่โชว์ — เห็นแค่เส้นวงบน SurfaceGui
	ring.Size = Vector3.new(d, 0.05, d)
	-- วางที่พื้นใต้เท้า ยกขึ้นนิดกัน z-fighting กับพื้น
	ring.CFrame = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 + 0.05, cf.Position.Z)

	local sg = Instance.new("SurfaceGui")
	sg.Name = "Ring"
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 50
	sg.LightInfluence = 0 -- เรืองเองไม่ตามแสงฉาก (กลางคืนยังเห็น)
	sg.Parent = ring

	local circle = Instance.new("Frame")
	circle.Size = UDim2.fromScale(1, 1)
	circle.BackgroundTransparency = 1
	circle.Parent = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0) -- 0.5 = กลมพอดี
	corner.Parent = circle

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = opts.thickness
	stroke.Color = opts.color
	stroke.Transparency = opts.transparency
	stroke.Parent = circle

	return ring
end

-- ===== registry + loop เดียวคุมทุกตัว =====

local active = {} -- [handle] = true
local conn = nil

local function ringFolder(): Folder
	local f = workspace:FindFirstChild("NPCIndicators")
	if not f then
		f = Instance.new("Folder")
		f.Name = "NPCIndicators"
		f.Parent = workspace
	end
	return f
end

local function step(dt: number)
	local char = Players.LocalPlayer and Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	for h in active do
		if not h.model.Parent then
			h:destroy()
		else
			local target = 0
			if hrp then
				local delta = hrp.Position - h.basePivot.Position
				if delta.Magnitude <= h.opts.lookRadius then
					local want = NPCIndicator.yawOf(delta.X, delta.Z)
					target = NPCIndicator.clampYawDelta(h.baseYaw, want, h.opts.maxAngle)
				end
			end
			-- ไกลออกไป target = 0 → หันกลับทิศตั้งต้นเอง
			local alpha = math.min(dt * h.opts.turnSpeed, 1)
			h.yaw += (target - h.yaw) * alpha
			h.model:PivotTo(h.basePivot * CFrame.Angles(0, h.yaw, 0))
		end
	end
	if next(active) == nil and conn then
		conn:Disconnect()
		conn = nil
	end
end

--[[ ผูกวง + การหันมองให้ NPC หนึ่งตัว
	model = Model ของ NPC (ต้องมี PrimaryPart ไม่งั้น pivot เพี้ยนตอนหมุน)
	opts  = ทับค่าใน DEFAULTS เฉพาะคีย์ที่ใส่มา
	คืน handle: h:destroy() ถอดคืน · h:setRingVisible(bool) เปิด/ปิดเฉพาะวง ]]
function NPCIndicator.attach(model: Model, opts: { [string]: any }?)
	assert(model and model:IsA("Model"), "NPCIndicator.attach ต้องการ Model")

	local o = {}
	for k, v in DEFAULTS do o[k] = v end
	for k, v in opts or {} do o[k] = v end

	if not model.PrimaryPart then
		warn(("[NPCIndicator] %s ไม่มี PrimaryPart — pivot อิงกรอบโมเดล หมุนแล้วอาจขยับตำแหน่ง")
			:format(model:GetFullName()))
	end

	local basePivot = model:GetPivot()
	local ring = buildRing(model, o)
	ring.Parent = ringFolder() -- ไม่ยัดในโมเดล: จะไปกวน pivot ตอน PivotTo
	local sg = ring:FindFirstChildOfClass("SurfaceGui")
	sg.Enabled = o.ringVisible

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.AutoRotate = false end -- กัน Humanoid หมุนแย่งกัน

	local look = basePivot.LookVector
	local handle = {
		model = model,
		opts = o,
		ring = ring,
		basePivot = basePivot,
		baseYaw = NPCIndicator.yawOf(look.X, look.Z),
		yaw = 0,
	}

	function handle:setRingVisible(on: boolean)
		sg.Enabled = on
	end

	function handle:destroy()
		active[self] = nil
		if self.ring then self.ring:Destroy() end
		if self.model.Parent then self.model:PivotTo(self.basePivot) end -- คืนท่าหันตั้งต้น
	end

	active[handle] = true
	if not conn then conn = RunService.Heartbeat:Connect(step) end
	return handle
end

-- ผูกให้ทุก Model ลูกตรงของ container (เช่น workspace.NPC.WorldNPC) — คืน list ของ handle
function NPCIndicator.attachAll(container: Instance, opts: { [string]: any }?)
	local handles = {}
	for _, m in container:GetChildren() do
		if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
			table.insert(handles, NPCIndicator.attach(m, opts))
		end
	end
	return handles
end

function NPCIndicator.detachAll()
	for h in active do h:destroy() end
end

return NPCIndicator
