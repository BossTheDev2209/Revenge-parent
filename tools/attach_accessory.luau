-- attach_accessory.luau — แปะ Accessory เข้าตัว NPC ให้ติดจริงใน Edit mode
-- (ลาก Accessory เข้าโมเดลเฉยๆ ใน Edit มันไม่ weld ให้ ต้องเชื่อม attachment เอง — ไฟล์นี้ทำให้)
--
-- ใช้ยังไง: แก้ 2 บรรทัด CONFIG ข้างล่าง แล้วรัน
--   python tools/mcp_driver.py <steps.json → execute_luau luau_file=tools/attach_accessory.luau, datamodel_type=Edit>
--
-- วิธีหาของมาใส่: Studio → Toolbox → ค้น "hair" (หรือ MCP search_asset) → เอา asset id มา insert
-- ของที่ insert แล้วเก็บไว้ที่ ReplicatedStorage.Accessories เอาไปใช้ซ้ำกับตัวอื่นได้

local CONFIG = {
	npc = "NPC_02_เจ", -- ชื่อโมเดลใน Workspace.NPC
	accessory = "HairSample", -- ชื่อ Accessory ใน ReplicatedStorage.Accessories
}

local RS = game:GetService("ReplicatedStorage")

-- ย้ายของที่เพิ่ง insert เข้าคลังกลาง (ครั้งแรกครั้งเดียว)
local lib = RS:FindFirstChild("Accessories")
if not lib then
	lib = Instance.new("Folder")
	lib.Name = "Accessories"
	lib.Parent = RS
end
local loose = RS:FindFirstChild(CONFIG.accessory)
if loose and loose:IsA("Accessory") then loose.Parent = lib end

local source = lib:FindFirstChild(CONFIG.accessory)
assert(source, "ไม่เจอ ReplicatedStorage.Accessories." .. CONFIG.accessory)
local npc = workspace.NPC:FindFirstChild(CONFIG.npc)
assert(npc, "ไม่เจอ Workspace.NPC." .. CONFIG.npc)

-- เอาของเดิมชนิดเดียวกันออกก่อน (ใส่ผมซ้อนผมจะทะลุกัน)
for _, c in npc:GetChildren() do
	if c:IsA("Accessory") and c.AccessoryType == source.AccessoryType then c:Destroy() end
end

local acc = source:Clone()
local handle = acc:FindFirstChild("Handle")
assert(handle, "Accessory ไม่มี Handle")

-- หา attachment คู่กัน: ใน Handle ชื่อไหน ตัวละครต้องมีชื่อเดียวกัน (HairAttachment/HatAttachment/...)
local accAtt, bodyAtt, bodyPart
for _, a in handle:GetChildren() do
	if a:IsA("Attachment") then
		for _, part in npc:GetChildren() do
			if part:IsA("BasePart") then
				local match = part:FindFirstChild(a.Name)
				if match and match:IsA("Attachment") then
					accAtt, bodyAtt, bodyPart = a, match, part
					break
				end
			end
		end
	end
	if accAtt then break end
end
assert(accAtt, "หา attachment ที่ตรงกันไม่เจอ (Accessory ใช้ชื่อ attachment แปลก)")

acc.Parent = npc
handle.Anchored = false
handle.CanCollide = false
handle.Massless = true
-- วางให้ตรงจุดก่อน แล้วค่อยเชื่อม (ไม่งั้นมันจะกระเด็นไปตำแหน่ง weld เดิม)
handle.CFrame = bodyAtt.WorldCFrame * accAtt.CFrame:Inverse()

-- Studio เชื่อม weld ให้เองหลัง parent (คนละเฟรม) — รอให้มันทำก่อน แล้วค่อยล้างทิ้งให้เหลือของเรา
-- ไม่รอ = ได้ weld 2 อันตีกัน ผมจะเบี้ยว
task.wait()
for _, old in handle:GetChildren() do
	if old:IsA("Weld") or old:IsA("Motor6D") then old:Destroy() end
end
local weld = Instance.new("Weld")
weld.Name = "AccessoryWeld"
weld.Part0 = bodyPart
weld.Part1 = handle
weld.C0 = bodyAtt.CFrame
weld.C1 = accAtt.CFrame
weld.Parent = handle

return ("ใส่ %s (%s) ให้ %s แล้ว — เชื่อมที่ %s ผ่าน %s")
	:format(acc.Name, tostring(acc.AccessoryType), npc.Name, bodyPart.Name, accAtt.Name)
