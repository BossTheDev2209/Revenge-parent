-- AnimPlayer.luau — คลังท่าทาง/อารมณ์ของตัวละคร เรียกจากบทด้วย "ชื่อท่า" (Genshin ref)
-- ทีมทำแค่: อัปโหลด animation → วาง Animation object ใน `ReplicatedStorage.Animations` → ตั้งชื่อ → เรียกในบท
--
-- โครงโฟลเดอร์ (ชื่อท่าซ้ำได้ ตัวไหนมีของตัวเองใช้ของตัวเองก่อน):
--   ReplicatedStorage.Animations/
--     Idle, Point, HeadScratch, Angry, ...        ← ท่ากลาง ใครก็ใช้ได้
--     Friend1/  Point, Cry, ...                    ← ท่าเฉพาะตัว (ชื่อโฟลเดอร์ = ชื่อไฟล์บท)
--     CC1/      Smug, ...
--
-- เรียกจากบท (docs/engines/dialogue.md §4, cutscene.md §5):
--   { speaker = "เจ", text = "...", anim = "HeadScratch" }   -- เล่นครั้งเดียวตอนบรรทัดนี้ขึ้น
--   { speaker = "เจ", text = "...", pose = "Angry" }         -- ท่ายืนค้าง (loop) จนกว่าจะสั่งท่าใหม่
--   ใส่ actor = "CC1" เพิ่ม ถ้าอยากให้ "ตัวอื่น" ขยับแทนคนพูด
--
-- pure: candidates / modelPrefix (เทสด้วย lune) | glue: play/stop (ต้องมี Humanoid)
local AnimPlayer = {}

local FOLDER_NAME = "Animations"
local FADE = 0.15

-- ชื่อไฟล์บท → prefix ของโมเดลในแมพ (docs/05 §4: NPC_01_<ชื่อ>)
local ACTOR_MODEL = {
	Landlord = "NPC_01",
	Friend1 = "NPC_02",
	Friend2 = "NPC_03",
	CC1 = "NPC_04",
	Hater = "NPC_05",
	Mom = "NPC_Mom",
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

local function animFolder(): Instance?
	return game:GetService("ReplicatedStorage"):FindFirstChild(FOLDER_NAME)
end

-- หา Animation object ตามลำดับ candidates
function AnimPlayer.findAnimation(actor: string?, animName: string): Animation?
	local root = animFolder()
	if not root then return nil end
	for _, path in AnimPlayer.candidates(actor, animName) do
		local node = root
		for part in path:gmatch("[^/]+") do
			node = node and node:FindFirstChild(part)
		end
		if node and node:IsA("Animation") then return node end
	end
	return nil
end

-- หาตัวละครในแมพ: "player" = ตัวผู้เล่น | ชื่ออื่น = โมเดลที่ชื่อขึ้นต้นด้วย prefix
function AnimPlayer.findRig(actor: string?): Model?
	if not actor or actor == "" then return nil end
	if actor == "player" then
		return game:GetService("Players").LocalPlayer.Character
	end
	local prefix = AnimPlayer.modelPrefix(actor)
	local exact = workspace:FindFirstChild(prefix, true)
	if exact and exact:IsA("Model") and exact:FindFirstChildOfClass("Humanoid") then return exact end
	for _, m in workspace:GetChildren() do
		if m:IsA("Model") and m.Name:sub(1, #prefix) == prefix and m:FindFirstChildOfClass("Humanoid") then
			return m
		end
	end
	return nil
end

local function animatorOf(rig: Model?): Animator?
	local hum = rig and rig:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	return hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
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

-- หยุดทุกท่าของตัวละครนั้น (ใช้ตอนจบ cutscene)
function AnimPlayer.stop(actor: string?)
	local animator = animatorOf(AnimPlayer.findRig(actor))
	if not animator then return end
	for _, t in tracks[animator] or {} do t:Stop(FADE) end
	posed[animator] = nil
end

-- เล่นตาม field ในบท 1 บรรทัด/1 step — คืน actor ที่ขยับ (ให้ผู้เรียกเก็บไว้ stop ทีหลัง)
-- item = { anim = "ชื่อท่า"?, pose = "ชื่อท่า"?, actor = "ชื่อตัวละคร"? }
function AnimPlayer.applyLine(item, defaultActor: string?): string?
	if type(item) ~= "table" then return nil end
	local actor = item.actor or defaultActor
	if item.pose then AnimPlayer.play(actor, item.pose, true) end
	if item.anim then AnimPlayer.play(actor, item.anim, false) end
	return (item.pose or item.anim) and actor or nil
end

return AnimPlayer
