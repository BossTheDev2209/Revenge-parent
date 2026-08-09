-- AnimPlayer.luau — คลังท่าทาง/อารมณ์ของตัวละคร เรียกจากบทด้วย "ชื่อท่า" (Genshin ref)
-- ทีมทำแค่: อัปโหลด animation → วาง Animation object ใน `ReplicatedStorage.Animations` → ตั้งชื่อ → เรียกในบท
--
-- โครงโฟลเดอร์ (ชื่อท่าซ้ำได้ ตัวไหนมีของตัวเองใช้ของตัวเองก่อน):
--   ReplicatedStorage.Animations/
--     Idle, Point, HeadScratch, Angry, ...        ← ท่ากลาง ใครก็ใช้ได้
--     Friend1/  Point, Cry, ...                    ← ท่าเฉพาะตัว (ชื่อโฟลเดอร์ = ชื่อไฟล์บท)
--     CC1/      Smug, ...
--
-- สีหน้า = คนละระบบกับ animation (R6 เปลี่ยนอารมณ์ด้วยการสลับรูปหน้า ไม่ใช่ท่า):
--   ReplicatedStorage.Faces/
--     Angry, Sad, Happy, Shock, ...              ← หน้ากลาง
--     Friend1/  Angry, Cry, ...                  ← หน้าเฉพาะตัว
--   ข้างในเป็น **Decal** (ตั้ง Texture) หรือ **StringValue** (ใส่ rbxassetid://... ใน Value) ก็ได้
--
-- เรียกจากบท (docs/engines/dialogue.md §2.5, cutscene.md §2):
--   { speaker = "เจ", text = "...", anim = "HeadScratch" }   -- เล่นครั้งเดียวตอนบรรทัดนี้ขึ้น
--   { speaker = "เจ", text = "...", pose = "Angry" }         -- ท่ายืนค้าง (loop) จนกว่าจะสั่งท่าใหม่
--   { speaker = "เจ", text = "...", face = "Angry" }         -- เปลี่ยนสีหน้า (ค้างจนสั่งหน้าใหม่/จบฉาก)
--   ใส่ actor = "CC1" เพิ่ม ถ้าอยากให้ "ตัวอื่น" ขยับแทนคนพูด
--
-- pure: candidates / modelPrefix (เทสด้วย lune) | glue: play/setFace/stop (ต้องมี Humanoid)
local AnimPlayer = {}

local FOLDER_NAME = "Animations"
local FACE_FOLDER_NAME = "Faces"
local FADE = 0.15

-- ชื่อไฟล์บท → prefix ของโมเดลในแมพ (docs/05 §4)
-- ตอนนี้ **ชื่อไฟล์บท = ชื่อในชื่อโมเดล** ทุกตัวแล้ว (ตั้งชื่อจริง 5 ส.ค. 2569) — findRig หาแบบ
-- "โมเดลไหนชื่อขึ้นต้นด้วย prefix" เจอเอง (`NPC_special_แม่` ขึ้นต้นด้วย "แม่" ไม่จริง → ต้อง map)
-- เลยแมปเฉพาะตัวที่ชื่อโมเดลมี prefix นำหน้า
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

-- ===== pure =====

-- ชื่อ actor → prefix โมเดลที่ควรไปหาใน Workspace (ไม่รู้จัก = ใช้ชื่อนั้นตรงๆ)
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

-- ===== Roblox glue =====

local tracks = {} -- [Animator][ชื่อท่า] = AnimationTrack (โหลดครั้งเดียวต่อตัวละคร)
local posed = {} -- [Animator] = ท่า loop ที่ค้างอยู่
local originalFace = {} -- [Decal หน้า] = texture เดิม (คืนตอนจบฉาก)
local held = {} -- [ชื่อ prop] = Weld ที่ hold() สร้างไว้ (unhold ลบทิ้ง)

-- เดินตาม path "A/B" ในโฟลเดอร์ที่ให้ — คืน instance ที่เจอ
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

-- หา Animation object ตามลำดับ candidates
function AnimPlayer.findAnimation(actor: string?, animName: string): Animation?
	local root = folderNamed(FOLDER_NAME)
	for _, path in AnimPlayer.candidates(actor, animName) do
		local node = resolve(root, path)
		if node and node:IsA("Animation") then return node end
	end
	return nil
end

-- หา texture ของสีหน้า — รับได้ทั้ง Decal (ใช้ .Texture) และ StringValue (ใช้ .Value)
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

-- หาตัวละครในแมพ: "player" = ตัวผู้เล่น | ชื่ออื่น = โมเดลที่ชื่อขึ้นต้นด้วย prefix
-- ค้นเฉพาะใน Workspace.NPC (StoryNPC/WorldNPC ตัวจริงที่เล่นเกม) — **ห้ามค้นทั้ง workspace**
-- เพราะฉาก cutscene มีโมเดลชื่อซ้ำ (ท่าโพสสำหรับฉาก เช่น Map_Phase0.npc) ถ้าค้นกว้างไปสุ่มไปเจอตัวโพสแทนตัวจริง
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

-- Humanoid (ตัวละคร) หรือ AnimationController (prop ไม่มีชีวิต) — 2 ทางเดียวที่มี Animator ได้
local function animatorOf(rig: Instance?): Animator?
	local controller = rig and (rig:FindFirstChildOfClass("Humanoid") or rig:FindFirstChildOfClass("AnimationController"))
	if not controller then return nil end
	return controller:FindFirstChildOfClass("Animator") or Instance.new("Animator", controller)
end

-- หา prop/object เท่าไหร่ก็ได้ในแมพ (ไม่ใช่ตัวละคร) — ต่างจาก findRig ที่จำกัดแค่ Workspace.NPC
-- prop วางกระจายทุกที่ได้ ⚠️ ชื่อต้อง unique ทั้งโปรเจกต์ (ชื่อซ้ำ = เจอตัวแรกที่ค้นทั้ง workspace อาจไม่ใช่ตัวที่ตั้งใจ)
function AnimPlayer.findObject(name: string): Model?
	return workspace:FindFirstChild(name, true)
end

-- เล่นท่า — loop = true คือท่ายืนค้าง (pose) ท่าเดิมที่ค้างอยู่จะถูกหยุดให้
-- ไม่มีโฟลเดอร์/ไม่มีท่า/ไม่มีโมเดล = warn ครั้งเดียว **บทเล่นต่อปกติ ไม่ค้าง**
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

-- Decal หน้าของตัวละคร (R6 = Head.face) — คืน nil ถ้าโมเดลไม่มีหัว/ไม่มีหน้า
function AnimPlayer.faceDecal(rig: Model?): Decal?
	local head = rig and rig:FindFirstChild("Head")
	if not head then return nil end
	local d = head:FindFirstChild("face")
	if d and d:IsA("Decal") then return d end
	return head:FindFirstChildOfClass("Decal")
end

-- เปลี่ยนสีหน้า — ค้างจนกว่าจะสั่งหน้าใหม่หรือจบฉาก (stop คืนหน้าเดิมให้)
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

-- หยุดทุกท่า + คืนหน้าเดิมของตัวละครนั้น (ใช้ตอนจบ cutscene)
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

-- ===== object animation (prop ไม่มีชีวิต — โล่รางวัล/กล่อง/ประตูที่เราสร้างเอง) =====
-- ต้องมี AnimationController ใต้ prop model ก่อน (Instance.new("AnimationController") วางเอง ครั้งเดียว)
-- Moon Animator animate ได้เหมือน Humanoid ทุกอย่าง — โฟลเดอร์ Animations ใช้ระบบ candidates เดียวกัน
-- (ชื่อ prop = "actor" ในการค้นหา — ท่าเฉพาะ prop นั้นอยู่ ReplicatedStorage.Animations.<ชื่อ prop>/<ท่า>)
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

-- ===== ถือ prop ติดมือ (โล่รางวัล ฯลฯ) — ไม่ต้อง animate prop เอง แค่ผูกกับแขนที่ actor ขยับอยู่แล้ว =====
-- จัดตำแหน่ง prop ให้แนบมือ (PrimaryPart) ใน Studio ไว้ก่อนเรียก — Weld เก็บ offset ปัจจุบัน ณ ตอนเรียกไว้เป๊ะ
-- limb ไม่ใส่ = "Right Arm" (R6) · คืน false ถ้าหา actor/prop ไม่เจอ (ไม่พัง เล่นต่อได้)
function AnimPlayer.hold(actor: string?, propName: string, limbName: string?): boolean
	local rig = AnimPlayer.findRig(actor)
	local prop = AnimPlayer.findObject(propName)
	local limb = rig and rig:FindFirstChild(limbName or "Right Arm")
	-- prop เป็นได้ทั้ง Part เดี่ยว (ใช้ตัวมันเอง) หรือ Model (ใช้ PrimaryPart/BasePart แรกที่เจอ)
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
	weld.C0 = limb.CFrame:ToObjectSpace(primary.CFrame) -- เก็บตำแหน่งสัมพัทธ์ปัจจุบัน (จัด prop แนบมือไว้ก่อนแล้ว)
	weld.Parent = limb
	held[propName] = weld
	return true
end

-- ปลด prop ออกจากมือ (คืนอิสระให้ physics/ตำแหน่งเดิมของมันเอง)
function AnimPlayer.unhold(propName: string)
	local w = held[propName]
	if w then
		w:Destroy()
		held[propName] = nil
	end
end

-- เล่นตาม field ในบท 1 บรรทัด/1 step — คืน actor ที่ถูกสั่ง (ให้ผู้เรียกเก็บไว้ stop ทีหลัง)
-- item = { anim = "ชื่อท่า"?, pose = "ชื่อท่า"?, face = "ชื่อหน้า"?, actor = "ชื่อตัวละคร"? }
function AnimPlayer.applyLine(item, defaultActor: string?): string?
	if type(item) ~= "table" then return nil end
	local actor = item.actor or defaultActor
	if item.pose then AnimPlayer.play(actor, item.pose, true) end
	if item.anim then AnimPlayer.play(actor, item.anim, false) end
	if item.face then AnimPlayer.setFace(actor, item.face) end
	return (item.pose or item.anim or item.face) and actor or nil
end

return AnimPlayer
