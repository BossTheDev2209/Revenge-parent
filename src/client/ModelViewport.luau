-- ModelViewport — render โมเดล 3 มิติจริงลง ViewportFrame (แทนรูปภาพแบน)
-- showBust(rig) = ตัวละครเต็มตัว ซูมหัว+บ่า · showModel(model) = โมเดลอะไรก็ได้ ซูมพอดีกรอบ
-- clear() = ซ่อน · destroy() = ทำลายถาวร
-- clone ไม่ mirror ของจริง: ViewportFrame render ได้แค่ลูกของตัวเอง · เรียกใหม่ทุกครั้ง = ได้ท่าล่าสุด
local ModelViewport = {}

local STRIP_CLASSES = { Script = true, LocalScript = true, Sound = true }

local function stripUnsafe(model: Model)
	for _, d in model:GetDescendants() do
		if STRIP_CLASSES[d.ClassName] then
			d:Destroy()
		end
	end
end

-- parent = GuiObject ที่ใส่ viewport (เต็มพื้นที่ parent เสมอ — คุม Size/Position ที่ parent)
function ModelViewport.new(parent: Instance)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "ModelViewport"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Visible = false
	vp.Parent = parent

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = vp

	local camera = Instance.new("Camera")
	camera.Parent = vp
	vp.CurrentCamera = camera

	local current: Model? = nil

	local handle = { instance = vp }

	local function clearClone()
		if current then
			current:Destroy()
			current = nil
		end
	end

	-- ตัวละครเต็มตัว วางกลาง WorldModel ตำแหน่งคงที่ (0,3,0) · กล้องซูมจาก Head.LookVector หลัง pivot รีเซ็ต
	function handle.showBust(rig: Model?, opts: { distance: number?, yOffset: number?, fov: number? }?)
		clearClone()
		if not rig then
			vp.Visible = false
			return false
		end
		local clone = rig:Clone()
		stripUnsafe(clone)
		clone:PivotTo(CFrame.new(0, 3, 0))
		clone.Parent = worldModel
		current = clone

		local head = clone:FindFirstChild("Head")
		if not head or not head:IsA("BasePart") then
			vp.Visible = false
			return false
		end
		-- ซูม bust: d = span / (2*tan(fov/2)) · span ~2.6 (หัว+บ่า) ที่ FOV 25° ได้ dist ~5.9
		local fov = (opts and opts.fov) or 25
		local span = (opts and opts.span) or 2.6
		local dist = (opts and opts.distance) or (span / (2 * math.tan(math.rad(fov) / 2)))
		local yOffset = (opts and opts.yOffset) or -head.Size.Y * 0.4
		local lookAt = head.Position + Vector3.new(0, yOffset, 0)
		local camPos = head.Position + head.CFrame.LookVector * dist + Vector3.new(0, yOffset, 0)
		camera.CFrame = CFrame.lookAt(camPos, lookAt)
		camera.FieldOfView = fov
		vp.Visible = true
		return true
	end

	-- โมเดลอะไรก็ได้ — คำนวณ bounding box ซูมพอดีกรอบ · Tool ไม่มี GetBoundingBox → ห่อใน Model ก่อน
	function handle.showModel(model: Instance?, opts: { zoom: number?, fov: number? }?)
		clearClone()
		if not model then
			vp.Visible = false
			return false
		end
		local clone = model:Clone()
		stripUnsafe(clone)
		if not clone:IsA("Model") then
			local wrap = Instance.new("Model")
			clone.Parent = wrap
			clone = wrap
		end
		clone.Parent = worldModel
		current = clone

		local cf, size = clone:GetBoundingBox()
		local dist = math.max(size.X, size.Y, size.Z, 1) * ((opts and opts.zoom) or 1.8)
		camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.6, dist * 0.45, dist * 0.7), cf.Position)
		camera.FieldOfView = (opts and opts.fov) or 35
		vp.Visible = true
		return true
	end

	function handle.clear()
		clearClone()
		vp.Visible = false
	end

	function handle.destroy()
		clearClone()
		vp:Destroy()
	end

	return handle
end

return ModelViewport
