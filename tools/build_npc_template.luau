-- build_npc_template.luau — สร้าง NPC template + ตัวจริง 5 ตัวใน Workspace.NPC
-- รันครั้งเดียวผ่าน Studio MCP:
--   python tools/mcp_driver.py <steps.json ที่มี execute_luau luau_file ชี้ไฟล์นี้ datamodel_type=Edit>
--
-- ทำอะไร (ไม่ลบ ไม่แก้ของเดิม — clone จาก Workspace.NPC.R6 อย่างเดียว):
--   • NPC_Template            ← ตัวแม่ ก๊อปไปทำตัวใหม่ได้เรื่อยๆ
--   • NPC_01_ป้าแดง … NPC_05_เกรียน  ← 5 ตัวตาม docs/05 §4 พร้อม Interact_NPC_0X ในตัว
-- แต่ละตัวเตรียมไว้ให้แล้ว: Animator / Shirt / Pants ว่าง / attachment ครบทุกจุด /
--   face decal / ป้ายชื่อลอย / ปิดชื่อ+เลือดของ Humanoid / HumanoidRootPart anchored (ส่วนอื่นไม่ anchor ไม่งั้นท่าไม่ขยับ)
-- เหลือให้ทีมทำ: วาง Accessory (ผม/หมวก/แว่น) ลงในโมเดล + ใส่ id ที่ Shirt/Pants + เปลี่ยน face + ลากไปวางจุดที่ต้องการ

local folder = workspace:FindFirstChild("NPC")
assert(folder, "ไม่เจอ Workspace.NPC — สร้าง Folder ชื่อ NPC ก่อน")
local source = folder:FindFirstChild("R6")
assert(source and source:FindFirstChildOfClass("Humanoid"), "ไม่เจอ Workspace.NPC.R6 (rig R6 ต้นแบบ)")

-- attachment มาตรฐาน R6 — ต้องครบ ไม่งั้น Accessory บางชิ้นแปะไม่ติด
local ATTACHMENTS = {
	Torso = {
		NeckAttachment = CFrame.new(0, 1, 0),
		LeftCollarAttachment = CFrame.new(-1, 1, 0),
		RightCollarAttachment = CFrame.new(1, 1, 0),
		BodyFrontAttachment = CFrame.new(0, 0, -0.5),
		BodyBackAttachment = CFrame.new(0, 0, 0.5),
		WaistCenterAttachment = CFrame.new(0, -1, 0),
		WaistFrontAttachment = CFrame.new(0, -1, -0.5),
		WaistBackAttachment = CFrame.new(0, -1, 0.5),
	},
	Head = {
		HatAttachment = CFrame.new(0, 0.6, 0),
		HairAttachment = CFrame.new(0, 0.6, 0),
		FaceFrontAttachment = CFrame.new(0, 0, -0.6),
		FaceCenterAttachment = CFrame.new(0, 0, 0),
	},
	["Left Arm"] = {
		LeftShoulderAttachment = CFrame.new(0, 1, 0),
		LeftGripAttachment = CFrame.new(0, -1, 0) * CFrame.Angles(0, math.rad(180), 0),
	},
	["Right Arm"] = {
		RightShoulderAttachment = CFrame.new(0, 1, 0),
		RightGripAttachment = CFrame.new(0, -1, 0) * CFrame.Angles(0, math.rad(180), 0),
	},
	["Left Leg"] = { LeftFootAttachment = CFrame.new(0, -1, 0) },
	["Right Leg"] = { RightFootAttachment = CFrame.new(0, -1, 0) },
}

-- ตัวละครตาม docs/05 §4 / docs/02 §9.4 — ชื่อไฟล์บทผูกอยู่แล้วใน InteractBinder
local ROSTER = {
	{ id = "01", name = "ป้าแดง", dialogue = "Landlord", note = "เจ้าของห้องเช่า (เฟส 1-2)" },
	{ id = "02", name = "เจ", dialogue = "Friend1", note = "เพื่อนคนแรก ทรยศ 500K (เฟส 2+)" },
	{ id = "03", name = "ปาล์ม", dialogue = "Friend2", note = "เพื่อนคนสอง อยู่จนจบ (เฟส 3)" },
	{ id = "04", name = "ไคโตะ", dialogue = "CC1", note = "Content Creator คู่แข่ง (เฟส 2-3)" },
	{ id = "05", name = "เกรียน", dialogue = "Hater", note = "เกรียน (เฟส 2)" },
}

local function ensureAttachments(model)
	for partName, list in ATTACHMENTS do
		local part = model:FindFirstChild(partName)
		if part then
			for aName, cf in list do
				if not part:FindFirstChild(aName) then
					local a = Instance.new("Attachment")
					a.Name = aName
					a.CFrame = cf
					a.Parent = part
				end
			end
		end
	end
end

-- ทำ rig ให้พร้อมเป็น NPC
local function prepare(model, label: string, interactName: string?, note: string?)
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- ปิดชื่อ/เลือดของ Roblox ใช้ป้ายเราเอง
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.WalkSpeed = 0 -- NPC ยืนอยู่กับที่ (ท่าทางมาจาก AnimPlayer)
	hum.JumpPower = 0
	hum.AutoRotate = false
	hum.BreakJointsOnDeath = false
	if not hum:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = hum -- ต้องมี ไม่งั้น AnimPlayer เล่นท่าไม่ได้
	end

	-- เฉพาะ HumanoidRootPart ที่ anchor — ส่วนอื่น anchor แล้วท่าจะไม่ขยับ
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = (d.Name == "HumanoidRootPart")
			d.CanCollide = (d.Name ~= "HumanoidRootPart")
		end
	end

	ensureAttachments(model)

	-- ช่องเสื้อ/กางเกงว่าง รอวาง id (ทีมแค่ paste rbxassetid ไม่ต้องสร้าง object เอง)
	if not model:FindFirstChildOfClass("Shirt") then
		local s = Instance.new("Shirt")
		s.Name = "Shirt"
		s.Parent = model
	end
	if not model:FindFirstChildOfClass("Pants") then
		local p = Instance.new("Pants")
		p.Name = "Pants"
		p.Parent = model
	end

	-- จุดกดคุย + ป้ายชื่อ (ป้ายจางตามระยะเองด้วย InteractBinder)
	if interactName then
		local head = model:FindFirstChild("Head")
		local old = model:FindFirstChild(interactName)
		if old then old:Destroy() end
		local part = Instance.new("Part")
		part.Name = interactName
		part.Size = Vector3.new(4, 6, 4)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = true
		part.CFrame = model:GetPivot()
		part.Parent = model

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 180, 0, 40)
		bb.StudsOffset = Vector3.new(0, 3.5, 0)
		bb.AlwaysOnTop = true
		bb.Parent = part
		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.new(1, 0, 1, 0)
		txt.BackgroundTransparency = 1
		txt.TextColor3 = Color3.new(1, 1, 1)
		txt.TextStrokeTransparency = 0.3
		txt.TextScaled = true
		txt.Text = label
		txt.Parent = bb
	end

	if note then
		model:SetAttribute("Note", note)
	end
	return model
end

local created = {}
local basePivot = source:GetPivot()

-- 1) ตัวแม่
local existingTemplate = folder:FindFirstChild("NPC_Template")
if existingTemplate then existingTemplate:Destroy() end
local template = source:Clone()
template.Name = "NPC_Template"
template.Parent = folder
template:PivotTo(basePivot * CFrame.new(0, 0, -8))
prepare(template, "NPC_Template", nil, "ก๊อปตัวนี้ไปทำ NPC ตัวใหม่ — ใส่ Accessory/Shirt/Pants/face แล้วเปลี่ยนชื่อ")
table.insert(created, template.Name)

-- 2) ตัวจริง 5 ตัว
for i, r in ROSTER do
	local name = ("NPC_%s_%s"):format(r.id, r.name)
	local old = folder:FindFirstChild(name)
	if old then old:Destroy() end
	local npc = source:Clone()
	npc.Name = name
	npc.Parent = folder
	npc:PivotTo(basePivot * CFrame.new(i * 6, 0, 0))
	prepare(npc, r.name, "Interact_NPC_" .. r.id, ("%s · บท: %s"):format(r.note, r.dialogue))
	table.insert(created, name)
end

return "สร้างแล้ว:\n  " .. table.concat(created, "\n  ")
