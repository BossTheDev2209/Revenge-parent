-- clean_accessories.luau — ล้างของที่โหลดมาจาก Toolbox แล้วจัดหมวดใน ReplicatedStorage.Accessories
--
-- ⚠️ ทำไมต้องล้าง: model ฟรีใน Toolbox แถม Script/LocalScript มาบ่อยมาก (backdoor / โฆษณา / spawn ของ)
--    เอาเข้าเกมทั้งดุ้น = เสี่ยงเกมโดนแฮก/โดนรายงาน ไฟล์นี้ลบ script ทุกตัวใน Accessories ทิ้งให้หมด
--    (Accessory ที่ดีไม่ต้องมี script เลย มีแค่ Handle + Mesh + Attachment)
--
-- ทำอะไร:
--   1. ลบ Script / LocalScript / ModuleScript / RemoteEvent / RemoteFunction ทุกตัว
--   2. ของที่ insert มาเป็น Model (ไม่ใช่ Accessory) → ดึง Accessory ข้างในออกมา ทิ้งเปลือก
--   3. ตัวไหนไม่มี Handle หรือไม่มี Attachment = ใช้กับ NPC ไม่ได้ → ย้ายเข้า _ใช้ไม่ได้ ให้ดูเอง
--   4. จัดเข้าโฟลเดอร์ตามชนิด (Hair / Hat / Glasses / Back / Waist / Neck / อื่นๆ)

local RS = game:GetService("ReplicatedStorage")
local lib = RS:FindFirstChild("Accessories")
assert(lib, "ไม่เจอ ReplicatedStorage.Accessories")

local BAD_CLASSES = {
	Script = true, LocalScript = true, ModuleScript = true,
	RemoteEvent = true, RemoteFunction = true, BindableEvent = true, BindableFunction = true,
}

-- ชื่อ attachment → ชื่อโฟลเดอร์หมวด (เอาไว้จัดของที่ AccessoryType ไม่ได้ตั้งมา)
local BY_ATTACHMENT = {
	HairAttachment = "Hair",
	HatAttachment = "Hat",
	FaceFrontAttachment = "Glasses",
	FaceCenterAttachment = "Glasses",
	BodyBackAttachment = "Back",
	BodyFrontAttachment = "Front",
	WaistCenterAttachment = "Waist",
	WaistFrontAttachment = "Waist",
	WaistBackAttachment = "Waist",
	NeckAttachment = "Neck",
	LeftCollarAttachment = "Neck",
	RightCollarAttachment = "Neck",
}

local removedScripts, moved, broken = 0, {}, {}

local function folderFor(name: string): Folder
	local f = lib:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = lib
	end
	return f
end

-- 1) ลบ script ทุกตัวในคลัง
for _, d in lib:GetDescendants() do
	if BAD_CLASSES[d.ClassName] then
		d:Destroy()
		removedScripts += 1
	end
end

-- 2) ดึง Accessory ออกจากเปลือก Model
for _, child in lib:GetChildren() do
	if child:IsA("Model") then
		local inner = child:FindFirstChildWhichIsA("Accessory", true)
		if inner then
			inner.Name = child.Name
			inner.Parent = lib
			child:Destroy()
		end
	end
end

-- 3-4) เช็คว่าใช้ได้ + จัดหมวด
for _, acc in lib:GetChildren() do
	if acc:IsA("Accessory") then
		local handle = acc:FindFirstChild("Handle")
		local attName
		if handle then
			for _, a in handle:GetChildren() do
				if a:IsA("Attachment") then
					attName = a.Name
					break
				end
			end
		end
		if not handle or not attName then
			acc.Parent = folderFor("_ใช้ไม่ได้")
			table.insert(broken, acc.Name .. (handle and " (ไม่มี attachment)" or " (ไม่มี Handle)"))
		else
			local group = BY_ATTACHMENT[attName] or "อื่นๆ"
			acc.Parent = folderFor(group)
			-- ไม่ให้มันชนของอื่นตอนอยู่ในคลัง
			handle.Anchored = false
			handle.CanCollide = false
			handle.Massless = true
			table.insert(moved, ("%-18s → %-8s (%s)"):format(acc.Name, group, attName))
		end
	end
end

table.sort(moved)
local out = { ("ลบ script/remote ที่แถมมา: %d ตัว"):format(removedScripts), "" }
table.insert(out, "จัดหมวดแล้ว:")
for _, l in moved do table.insert(out, "  " .. l) end
if #broken > 0 then
	table.insert(out, "")
	table.insert(out, "ใช้กับ NPC ไม่ได้ (ย้ายไป _ใช้ไม่ได้):")
	for _, l in broken do table.insert(out, "  " .. l) end
end
return table.concat(out, "\n")
