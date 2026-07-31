-- normalize_accessories.luau — ซ่อมของจาก Toolbox ให้ใส่ NPC ได้จริง แล้วจัดหมวด
--
-- ของฟรีใน Toolbox ตั้งชื่อมั่วเกือบทุกชิ้น: Handle ชื่ออื่น / attachment ชื่อผิด / ไม่มี attachment เลย
-- ไฟล์นี้แก้ให้ตามชื่อที่เราตั้งไว้ (Hat_* / Glasses_* / Scarf_* / Backpack_* / Belt_* / Hair_*)
-- แล้วย้ายเข้าโฟลเดอร์หมวด — หลังจากนี้ tools/attach_accessory.luau ใส่ให้ NPC ได้เลย
--
-- รัน: python tools/mcp_driver.py <steps.json → execute_luau luau_file=ไฟล์นี้ datamodel_type=Edit>

local RS = game:GetService("ReplicatedStorage")
local lib = RS:FindFirstChild("Accessories")
assert(lib, "ไม่เจอ ReplicatedStorage.Accessories")

-- prefix ชื่อของเรา → { attachment ที่ต้องใช้, หมวด, AccessoryType, offset ในตัว handle, ขนาดสูงสุด }
-- max = ขนาดใหญ่สุดที่ยังดูเข้ากับตัว R6 (ตัว 2×2×1, หัว 2×1×1) — ของ Toolbox ใหญ่เกินแทบทุกชิ้น
local SPEC = {
	Hair = { att = "HairAttachment", group = "Hair", accType = Enum.AccessoryType.Hair, y = 0,
		max = Vector3.new(2.2, 2.2, 2.2) },
	Hat = { att = "HatAttachment", group = "Hat", accType = Enum.AccessoryType.Hat, y = -0.2,
		max = Vector3.new(1.7, 1.4, 1.7) },
	Glasses = { att = "FaceFrontAttachment", group = "Glasses", accType = Enum.AccessoryType.Face, y = 0,
		max = Vector3.new(1.7, 0.6, 0.8) },
	Scarf = { att = "NeckAttachment", group = "Neck", accType = Enum.AccessoryType.Neck, y = 0,
		max = Vector3.new(1.8, 0.9, 1.4) },
	Backpack = { att = "BodyBackAttachment", group = "Back", accType = Enum.AccessoryType.Back, y = 0,
		max = Vector3.new(1.6, 2.0, 0.9) },
	Belt = { att = "WaistCenterAttachment", group = "Waist", accType = Enum.AccessoryType.Waist, y = 0,
		max = Vector3.new(2.2, 0.7, 1.3) },
}

-- ย่อให้พอดีตัว — คูณ Mesh.Scale ตามด้วย ไม่งั้น SpecialMesh ยังใหญ่เท่าเดิม
local function fitSize(handle: BasePart, max: Vector3)
	local s = handle.Size
	local factor = math.min(max.X / s.X, max.Y / s.Y, max.Z / s.Z)
	if factor >= 1 then return nil end
	handle.Size = s * factor
	local mesh = handle:FindFirstChildOfClass("SpecialMesh")
	if mesh then mesh.Scale = mesh.Scale * factor end
	return factor
end

local BAD_CLASSES = {
	Script = true, LocalScript = true, ModuleScript = true, RemoteEvent = true,
	RemoteFunction = true, BindableEvent = true, BindableFunction = true, Sound = true,
}

-- โฟลเดอร์หมวดของเราเอง — ห้ามไปนับเป็น "เปลือกของ Toolbox" (ชื่อชนกับ prefix เช่น Hair)
local GROUP_NAMES = { Hair = true, Hat = true, Glasses = true, Neck = true, Back = true,
	Waist = true, ["อื่นๆ"] = true, ["_ใช้ไม่ได้"] = true }

local log = {}
local function say(s) table.insert(log, s) end

local function specFor(name: string)
	for prefix, spec in SPEC do
		if name:sub(1, #prefix) == prefix then return spec end
	end
	return nil
end

local function folderFor(name: string): Folder
	local f = lib:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = lib
	end
	return f
end

-- ของหลอก: โมเดลตัวละครทั้งตัว (มี Humanoid) ไม่ใช่ accessory — ทิ้ง
for _, c in lib:GetDescendants() do
	if c:IsA("Humanoid") then
		local top = c
		while top.Parent and top.Parent ~= lib do top = top.Parent end
		say("ทิ้ง " .. top.Name .. " — เป็นโมเดลตัวละครทั้งตัว ไม่ใช่ accessory")
		top:Destroy()
		break
	end
end

-- ลบ script/เสียงที่แถมมา (accessory ที่ดีมีแค่ Handle + Mesh + Attachment)
local killed = 0
for _, d in lib:GetDescendants() do
	if BAD_CLASSES[d.ClassName] then
		d:Destroy()
		killed += 1
	end
end
say(("ลบ script/เสียงที่แถมมา %d ตัว"):format(killed))

-- เปลือก Model/Folder → ดึงของข้างในออกมา (บางเจ้าห่อ Accessory, บางเจ้าให้ Part เปล่า)
for _, child in lib:GetChildren() do
	if GROUP_NAMES[child.Name] then
		continue -- โฟลเดอร์หมวดของเรา ไม่ใช่เปลือก
	end
	if child:IsA("Model") or (child:IsA("Folder") and specFor(child.Name)) then
		local inner = child:FindFirstChildWhichIsA("Accessory", true)
		if inner then
			inner.Name = child.Name
			inner.Parent = lib
			child:Destroy()
		else
			-- ไม่มี Accessory ข้างใน → ห่อ BasePart ที่ใหญ่สุดเป็น Accessory ให้เอง
			local best
			for _, p in child:GetDescendants() do
				if p:IsA("BasePart") then
					local v = p.Size.X * p.Size.Y * p.Size.Z
					if not best or v > best.Size.X * best.Size.Y * best.Size.Z then best = p end
				end
			end
			if best then
				local acc = Instance.new("Accessory")
				acc.Name = child.Name
				best.Parent = acc
				acc.Parent = lib
				child:Destroy()
				say("ห่อ " .. acc.Name .. " เป็น Accessory ให้ (ของเดิมเป็น Part เปล่า)")
			end
		end
	end
end

-- ซ่อมแต่ละชิ้นตาม SPEC — รวมของที่จัดหมวดไปแล้วรอบก่อนด้วย (รันซ้ำได้ ไม่พัง)
local sorted, skipped = {}, {}
local all = {}
for _, d in lib:GetDescendants() do
	if d:IsA("Accessory") then table.insert(all, d) end
end
for _, acc in all do
	do
		local spec = specFor(acc.Name)
		if not spec then
			table.insert(skipped, acc.Name .. " (ชื่อไม่ขึ้นต้นด้วยหมวดที่รู้จัก)")
			continue
		end
		-- Handle: ของหลายเจ้าตั้งชื่ออื่น → เปลี่ยนเป็น Handle
		local handle = acc:FindFirstChild("Handle")
		if not handle or not handle:IsA("BasePart") then
			handle = acc:FindFirstChildWhichIsA("BasePart")
			if handle then handle.Name = "Handle" end
		end
		if not handle then
			table.insert(skipped, acc.Name .. " (ไม่มีชิ้นส่วนเลย)")
			continue
		end

		-- attachment: ลบของเดิมที่ชื่อผิดทิ้ง แล้วใส่ชื่อที่ถูกต้องตามหมวด
		local existing
		for _, a in handle:GetChildren() do
			if a:IsA("Attachment") then
				existing = existing or a
				if a.Name ~= spec.att then a.Name = spec.att end
			end
		end
		if not existing then
			existing = Instance.new("Attachment")
			existing.Name = spec.att
			existing.Parent = handle
		end
		-- ★ บังคับรีเซ็ต offset: ของ Toolbox ตั้ง attachment มั่ว (เจอกระเป๋าไปโผล่หน้าอกแทนหลัง)
		-- ให้ handle ไปนั่งตรงจุดบนตัวพอดี แล้วค่อยขยับเองทีหลังถ้าอยากละเอียด
		existing.CFrame = CFrame.new(0, spec.y, 0)
		-- เหลือ attachment เดียวพอ (หลายอัน = tool เลือกผิดตัว)
		for _, a in handle:GetChildren() do
			if a:IsA("Attachment") and a ~= existing then a:Destroy() end
		end

		acc.AccessoryType = spec.accType
		handle.Anchored = false
		handle.CanCollide = false
		handle.Massless = true
		local shrunk = fitSize(handle, spec.max)
		acc.Parent = folderFor(spec.group)
		table.insert(sorted, ("%-18s → %-8s (%s)%s"):format(acc.Name, spec.group, spec.att,
			shrunk and (" ย่อ ×%.2f"):format(shrunk) or ""))
	end
end

-- โฟลเดอร์ว่างที่เหลือจากรอบก่อน ทิ้งไป
for _, f in lib:GetChildren() do
	if f:IsA("Folder") and #f:GetChildren() == 0 then f:Destroy() end
end

table.sort(sorted)
say("")
say("พร้อมใช้:")
for _, l in sorted do say("  " .. l) end
if #skipped > 0 then
	say("")
	say("ข้าม:")
	for _, l in skipped do say("  " .. l) end
end
return table.concat(log, "\n")
