-- ModelViewport.luau — render โมเดล 3 มิติจริงลง ViewportFrame (แทนรูปภาพแบน)
-- ใช้ 2 ที่: DialogueUI (หน้าตัวละครที่คุยด้วย) และในอนาคต ShopKiosk (ตัวสินค้าจริงแทนไอคอน)
--
-- showBust(rig)   — clone ตัวละครเต็มตัว (ครบเสื้อผ้า/ทรงผม/accessory) ซูมกล้องที่หัว+บ่า
-- showModel(model) — clone โมเดลอะไรก็ได้ ซูมกล้องให้พอดีกรอบอัตโนมัติ (สำหรับของ/ไอเทม)
-- clear()         — เอาโมเดลออก ซ่อน viewport
-- destroy()       — ทำลายทิ้งถาวร (ตอนปิด UI)
--
-- ทำไม clone ไม่ mirror ของจริงสด: ViewportFrame render ได้แค่ลูกของตัวเอง ไม่ใช่ Workspace ตรงๆ
-- เรียก showBust ใหม่ทุกครั้งที่จะโชว์ (เช่นทุกบรรทัดบท) = ได้ท่า/สีหน้าล่าสุดของตัวจริง ณ วินาทีนั้น
local ModelViewport = {}

local STRIP_CLASSES = { Script = true, LocalScript = true, Sound = true }

local function stripUnsafe(model: Model)
	for _, d in model:GetDescendants() do
		if STRIP_CLASSES[d.ClassName] then
			d:Destroy()
		end
	end
end

-- parent = GuiObject ที่จะใส่ viewport ลงไป (เต็มพื้นที่ของ parent เสมอ — ไปคุม Size/Position ที่ parent เอา)
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

	-- ตัวละครเต็มตัว (R6) วางไว้กลาง WorldModel ตำแหน่งคงที่ (0,3,0) — ไม่ขึ้นกับพิกัดจริงในแมพ
	-- กล้องซูมจาก Head.CFrame.LookVector หลัง pivot รีเซ็ตแล้ว = หันทิศเดียวกันเสมอไม่ว่า rig ต้นทางหันไปทางไหน
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
		-- ซูมแบบ bust จริง (หัว+บ่า ไม่เอาครึ่งตัว) — คำนวณจาก FOV แนวตั้ง: d = span / (2*tan(fov/2))
		-- span ~2.6 studs (หัว+บ่านิดๆ) ที่ FOV เริ่มต้น 25° ได้ dist ~5.9 studs
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

	-- โมเดลอะไรก็ได้ (ของ/ไอเทม) — คำนวณ bounding box เอง ซูมให้พอดีกรอบเสมอไม่ว่าโมเดลใหญ่เล็กแค่ไหน
	-- รับ Tool ได้ด้วย (กล้องใน ToolModels เป็น Tool ไม่ใช่ Model) — GetBoundingBox เป็นเมธอดของ Model เท่านั้น
	-- เลยห่อ Tool/Folder ใน Model ชั่วคราวก่อน · ของที่เป็น Model อยู่แล้วไม่โดนแตะ (DialogueUI ใช้เหมือนเดิม)
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
