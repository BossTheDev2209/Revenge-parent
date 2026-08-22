-- AnimPlayer — คลังท่าทาง/สีหน้าตัวละคร เรียกจากบทด้วย "ชื่อท่า"
-- Animation object อยู่ ReplicatedStorage.Animations/ · สีหน้าอยู่ ReplicatedStorage.Faces/ (Decal หรือ StringValue)
--   ท่ากลางอยู่ราก · ท่าเฉพาะตัวอยู่โฟลเดอร์ชื่อ = ชื่อไฟล์บท (ใช้ของตัวเองก่อน แล้วค่อยท่ากลาง)
-- เรียกจากบท: { anim = เล่นครั้งเดียว } · { pose = ยืนค้าง loop } · { face = เปลี่ยนสีหน้า } · { actor = ตัวอื่นขยับ }
-- pure: candidates / modelPrefix (เทส lune) | glue: play/setFace/stop
local AnimPlayer = {}

local FOLDER_NAME = "Animations"
local FACE_FOLDER_NAME = "Faces"
local FADE = 0.15

-- ชื่อ actor → ชื่อโมเดลในแมพ (เฉพาะตัวที่ชื่อโมเดลไม่ได้ขึ้นต้นด้วยชื่อ actor ตรงๆ)
local ACTOR_MODEL = {
	["แม่"] = "NPC_special_แม่",
	["พ่อ"] = "NPC_special_พ่อ",
	["ฟ้าใส"] = "NPC_special_ฟ้าใส", -- เพื่อนร่วมทาง 1
	["เจียเจีย"] = "NPC_special_เจียเจีย", -- เพื่อนร่วมทาง 2
	["พี่เปิ้ล"] = "NPC_special_พี่เปิ้ล", -- CC คู่แข่ง
	["ลุงสืบ"] = "NPC_01_ลุงสืบ",
	["พี่แหนม"] = "NPC_02_พี่แหนม",
	["ลุงชัย"] = "NPC_03_ลุงชัย",
	["ป้าไหม"] = "NPC_04_ป้าไหม",
	["หมวย"] = "NPC_05_หมวย",
	["ออโต้"] = "NPC_06_ออโต้",
	["ลุงฮาซาน"] = "NPC_07_ลุงฮาซาน",
	["พี่โชคชัย"] = "NPC_08_พี่โชคชัย",
	["น้ำปั่น"] = "NPC_09_น้ำปั่น",
	["เกรซ"] = "NPC_10_เกรซ",
	["พี่มีนา"] = "NPC_11_พี่มีนา",
	["ลุงนรินท์"] = "NPC_12_ลุงนรินท์",
}

-- ชื่อ actor → prefix โมเดลที่ไปหาใน Workspace (ไม่รู้จัก = ใช้ชื่อนั้นตรงๆ)
function AnimPlayer.modelPrefix(actor: string): string
	return ACTOR_MODEL[actor] or actor
end

-- ลำดับที่ไปหา Animation: ของเฉพาะตัวก่อน แล้วค่อยท่ากลาง
function AnimPlayer.candidates(actor: string?, animName: string): { string }
	if actor and actor ~= "" then
		return { actor .. "/" .. animName, animName }
	end
	return { animName }
end

local tracks = {} -- [Animator][ชื่อท่า] = AnimationTrack (โหลดครั้งเดียวต่อตัวละคร)
local posed = {} -- [Animator] = ท่า loop ที่ค้างอยู่
local originalFace = {} -- [Decal หน้า] = texture เดิม (คืนตอนจบฉาก)
local held = {} -- [ชื่อ prop] = Weld ที่ hold() สร้างไว้

-- เดินตาม path "A/B" ในโฟลเดอร์ที่ให้
local function resolve(root: Instance?, path: string): Instance?
	if not root then return nil end
	local node = root
	for part in path:gmatch("[^/]+") do
		node = node and node:FindFirstChild(part)
	end
	return node
end

local function folderNamed(name: string): Instance?
	return game:GetService("ReplicatedStorage"):FindFirstChild(name)
end

function AnimPlayer.findAnimation(actor: string?, animName: string): Animation?
	local root = folderNamed(FOLDER_NAME)
	for _, path in AnimPlayer.candidates(actor, animName) do
		local node = resolve(root, path)
		if node and node:IsA("Animation") then return node end
	end
	return nil
end

-- texture ของสีหน้า — รับได้ทั้ง Decal (.Texture) และ StringValue (.Value)
function AnimPlayer.findFaceTexture(actor: string?, faceName: string): string?
	local root = folderNamed(FACE_FOLDER_NAME)
	for _, path in AnimPlayer.candidates(actor, faceName) do
		local node = resolve(root, path)
		if node then
			if node:IsA("Decal") then return node.Texture end
			if node:IsA("StringValue") and node.Value ~= "" then return node.Value end
		end
	end
	return nil
end

-- หาตัวละครในแมพ: "player" = ผู้เล่น | อื่น = โมเดลชื่อขึ้นต้นด้วย prefix
-- ⚠️ ค้นเฉพาะใน Workspace.NPC ห้ามค้นทั้ง workspace — ฉาก cutscene มีโมเดลชื่อซ้ำ (ตัวโพส) จะเจอผิดตัว
function AnimPlayer.findRig(actor: string?): Model?
	if not actor or actor == "" then return nil end
	if actor == "player" then
		return game:GetService("Players").LocalPlayer.Character
	end
	local prefix = AnimPlayer.modelPrefix(actor)
	local root = workspace:FindFirstChild("NPC")
	if not root then return nil end
	local exact = root:FindFirstChild(prefix, true)
	if exact and exact:IsA("Model") and exact:FindFirstChildOfClass("Humanoid") then return exact end
	for _, folder in root:GetChildren() do
		for _, m in folder:GetChildren() do
			if m:IsA("Model") and m.Name:sub(1, #prefix) == prefix and m:FindFirstChildOfClass("Humanoid") then
				return m
			end
		end
	end
	return nil
end

-- Humanoid (ตัวละคร) หรือ AnimationController (prop) — 2 ทางที่มี Animator ได้
local function animatorOf(rig: Instance?): Animator?
	local controller = rig and (rig:FindFirstChildOfClass("Humanoid") or rig:FindFirstChildOfClass("AnimationController"))
	if not controller then return nil end
	return controller:FindFirstChildOfClass("Animator") or Instance.new("Animator", controller)
end

-- หา prop ใน workspace (ไม่ใช่ตัวละคร) · ⚠️ ชื่อต้อง unique ทั้งโปรเจกต์
function AnimPlayer.findObject(name: string): Model?
	return workspace:FindFirstChild(name, true)
end

-- เล่นท่า — loop = ท่ายืนค้าง (หยุดท่าค้างเดิมให้) · ไม่เจอ = warn ครั้งเดียว บทเล่นต่อไม่ค้าง
function AnimPlayer.play(actor: string?, animName: string, loop: boolean?): boolean
	local rig = AnimPlayer.findRig(actor)
	local animator = animatorOf(rig)
	if not animator then
		warn(("[AnimPlayer] ไม่เจอตัวละคร '%s' (ต้องเป็นโมเดลมี Humanoid ชื่อขึ้นต้น %s)")
			:format(tostring(actor), AnimPlayer.modelPrefix(actor or "?")))
		return false
	end
	local anim = AnimPlayer.findAnimation(actor, animName)
	if not anim then
		warn(("[AnimPlayer] ไม่เจอท่า '%s' ใน ReplicatedStorage.%s"):format(animName, FOLDER_NAME))
		return false
	end

	tracks[animator] = tracks[animator] or {}
	local key = anim:GetFullName()
	local track = tracks[animator][key]
	if not track then
		track = animator:LoadAnimation(anim)
		tracks[animator][key] = track
	end

	if loop then
		local old = posed[animator]
		if old and old ~= track then old:Stop(FADE) end
		posed[animator] = track
	end
	track.Looped = loop == true
	track:Play(FADE)
	return true
end

-- Decal หน้า (R6 = Head.face) — nil ถ้าไม่มีหัว/หน้า
function AnimPlayer.faceDecal(rig: Model?): Decal?
	local head = rig and rig:FindFirstChild("Head")
	if not head then return nil end
	local d = head:FindFirstChild("face")
	if d and d:IsA("Decal") then return d end
	return head:FindFirstChildOfClass("Decal")
end

-- เปลี่ยนสีหน้า — ค้างจนสั่งหน้าใหม่/จบฉาก (stop คืนหน้าเดิม)
function AnimPlayer.setFace(actor: string?, faceName: string): boolean
	local rig = AnimPlayer.findRig(actor)
	local decal = AnimPlayer.faceDecal(rig)
	if not decal then
		warn(("[AnimPlayer] ตัวละคร '%s' ไม่มีหน้า (ต้องมี Head.face เป็น Decal)"):format(tostring(actor)))
		return false
	end
	local texture = AnimPlayer.findFaceTexture(actor, faceName)
	if not texture then
		warn(("[AnimPlayer] ไม่เจอสีหน้า '%s' ใน ReplicatedStorage.%s"):format(faceName, FACE_FOLDER_NAME))
		return false
	end
	if originalFace[decal] == nil then originalFace[decal] = decal.Texture end
	decal.Texture = texture
	return true
end

-- หยุดทุกท่า + คืนหน้าเดิม (ตอนจบ cutscene)
function AnimPlayer.stop(actor: string?)
	local rig = AnimPlayer.findRig(actor)
	local decal = AnimPlayer.faceDecal(rig)
	if decal and originalFace[decal] ~= nil then
		decal.Texture = originalFace[decal]
		originalFace[decal] = nil
	end
	local animator = animatorOf(rig)
	if not animator then return end
	for _, t in tracks[animator] or {} do t:Stop(FADE) end
	posed[animator] = nil
end

-- object animation (prop ไม่มีชีวิต) — ต้องมี AnimationController ใต้ prop · ชื่อ prop = "actor" ในการค้นท่า
function AnimPlayer.playObject(objectName: string, animName: string, loop: boolean?): boolean
	local obj = AnimPlayer.findObject(objectName)
	local animator = animatorOf(obj)
	if not animator then
		warn(("[AnimPlayer] playObject: ไม่เจอ '%s' (ต้องมี AnimationController ในตัว)"):format(tostring(objectName)))
		return false
	end
	local anim = AnimPlayer.findAnimation(objectName, animName)
	if not anim then
		warn(("[AnimPlayer] playObject: ไม่เจอท่า '%s' ใน ReplicatedStorage.%s"):format(animName, FOLDER_NAME))
		return false
	end
	tracks[animator] = tracks[animator] or {}
	local key = anim:GetFullName()
	local track = tracks[animator][key]
	if not track then
		track = animator:LoadAnimation(anim)
		tracks[animator][key] = track
	end
	track.Looped = loop == true
	track:Play(FADE)
	return true
end

function AnimPlayer.stopObject(objectName: string)
	local animator = animatorOf(AnimPlayer.findObject(objectName))
	if not animator then return end
	for _, t in tracks[animator] or {} do t:Stop(FADE) end
end

-- ถือ prop ติดมือ (ผูก Weld กับแขนที่ actor ขยับอยู่แล้ว) · จัด prop แนบมือใน Studio ก่อนเรียก
-- limb ไม่ใส่ = "Right Arm" (R6) · คืน false ถ้าหา actor/prop ไม่เจอ (ไม่พัง)
function AnimPlayer.hold(actor: string?, propName: string, limbName: string?): boolean
	local rig = AnimPlayer.findRig(actor)
	local prop = AnimPlayer.findObject(propName)
	local limb = rig and rig:FindFirstChild(limbName or "Right Arm")
	local primary = prop and (prop:IsA("BasePart") and prop or prop:IsA("Model") and (prop.PrimaryPart or prop:FindFirstChildWhichIsA("BasePart")))
	if not (limb and limb:IsA("BasePart") and primary) then
		warn(("[AnimPlayer] hold: หา actor/prop ไม่เจอ (%s / %s)"):format(tostring(actor), tostring(propName)))
		return false
	end
	AnimPlayer.unhold(propName) -- กัน weld ซ้อนถ้าเรียกซ้ำ
	local weld = Instance.new("Weld")
	weld.Name = "PropHold_" .. propName
	weld.Part0 = limb
	weld.Part1 = primary
	weld.C0 = limb.CFrame:ToObjectSpace(primary.CFrame) -- เก็บตำแหน่งสัมพัทธ์ปัจจุบัน
	weld.Parent = limb
	held[propName] = weld
	return true
end

-- ปลด prop ออกจากมือ
function AnimPlayer.unhold(propName: string)
	local w = held[propName]
	if w then
		w:Destroy()
		held[propName] = nil
	end
end

-- เล่นตาม field ในบท 1 บรรทัด — คืน actor ที่ถูกสั่ง (ให้ผู้เรียกเก็บไว้ stop ทีหลัง)
function AnimPlayer.applyLine(item, defaultActor: string?): string?
	if type(item) ~= "table" then return nil end
	local actor = item.actor or defaultActor
	if item.pose then AnimPlayer.play(actor, item.pose, true) end
	if item.anim then AnimPlayer.play(actor, item.anim, false) end
	if item.face then AnimPlayer.setFace(actor, item.face) end
	return (item.pose or item.anim or item.face) and actor or nil
end

return AnimPlayer
