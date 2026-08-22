-- NPCIndicator — วงขาวใต้เท้า NPC + หันตัวมองผู้เล่นเมื่อเข้าใกล้ (จำกัดองศาจากทิศตั้งต้น)
-- component ล้วน: attach(model, opts?) / attachAll(container) / handle:destroy()
-- หันทั้งตัวด้วย PivotTo (ไม่ยุ่ง Motor6D/คอ) — ใช้ได้ทั้ง rig ที่ anchor HRP และ anchor ทุกชิ้น
-- วงแหวน = SurfaceGui + UICorner + UIStroke ไม่ใช้ asset ภายนอก (กันโดน moderate)
-- isStudio guard: yawOf/clampYawDelta pure เทสด้วย lune ได้
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
	maxAngle = 70, -- หันได้ไม่เกินกี่องศาจากทิศตั้งต้น (ข้างละเท่านี้)
	turnSpeed = 6, -- ความไวในการหัน
	ringVisible = true,
}

-- มุมหันของทิศทาง: หน้าโมเดล (0,0,-1) = 0 · ใช้คู่ CFrame.Angles(0, yaw, 0)
function NPCIndicator.yawOf(dirX: number, dirZ: number): number
	return math.atan2(-dirX, -dirZ)
end

-- ส่วนต่างมุมที่หันได้ เทียบทิศตั้งต้น — ⚠️ wrap เข้าช่วง ±180 ก่อน แล้วค่อย clamp
-- (ไม่ wrap = ทิศตั้งต้นใกล้ ±180 ค่าเด้งเป็น ±340 แล้ว clamp ผิดข้าง)
function NPCIndicator.clampYawDelta(baseYaw: number, targetYaw: number, maxAngleDeg: number): number
	local d = (targetYaw - baseYaw) % (2 * math.pi)
	if d > math.pi then d -= 2 * math.pi end
	local limit = math.rad(math.abs(maxAngleDeg))
	return math.clamp(d, -limit, limit)
end

local function buildRing(model: Model, opts): Part
	local cf, size = model:GetBoundingBox()
	local d = opts.radius * 2

	local ring = Instance.new("Part")
	ring.Name = "NPCRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Transparency = 1 -- Part ไม่โชว์ — เห็นแค่เส้นวงบน SurfaceGui
	ring.Size = Vector3.new(d, 0.05, d)
	ring.CFrame = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 + 0.05, cf.Position.Z) -- พื้นใต้เท้า ยกกัน z-fighting

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
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = circle

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = opts.thickness
	stroke.Color = opts.color
	stroke.Transparency = opts.transparency
	stroke.Parent = circle

	return ring
end

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

-- ผูกวง + การหันมองให้ NPC หนึ่งตัว · model ต้องมี PrimaryPart · opts ทับ DEFAULTS
-- คืน handle: h:destroy() ถอดคืน · h:setRingVisible(bool)
function NPCIndicator.attach(model: Model, opts: { [string]: any }?)
	assert(model and model:IsA("Model"), "NPCIndicator.attach ต้องการ Model")

	local o = {}
	for k, v in DEFAULTS do o[k] = v end
	for k, v in opts or {} do o[k] = v end

	if not model.PrimaryPart then
		warn(("[NPCIndicator] %s ไม่มี PrimaryPart — หมุนแล้วอาจขยับตำแหน่ง"):format(model:GetFullName()))
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

-- ผูกทุก Model ลูกตรงของ container — คืน list ของ handle
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
