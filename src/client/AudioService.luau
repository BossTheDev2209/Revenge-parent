-- AudioService.luau — เครื่องเสียงทั้งเกม (client) — docs/02 §9.9
--
-- ★ ทีมทำแค่: อัปโหลดเสียง → วาง Sound object ตามโครงข้างล่าง → ตั้งชื่อ → **จบ ไม่ต้องแตะโค้ด**
--
--   SoundService/
--     BGM/       เพลงพื้นหลัง (ตั้ง Looped = true)   เช่น Street, Apartment, House, Menu
--     Ambient/   เสียงบรรยากาศซ้อนเพลง (Looped)      เช่น rain, city, room_tone
--     Voice/     blip ตอนพิมพ์บท 1 ตัวอักษร (สั้นมาก) เช่น Default, Friend1, CC1, Hater
--     SFX/       เสียงสั้นครั้งเดียว                    เช่น ui_click, upload_done, viral
--
-- โซนเพลง: Part ชื่อ `Zone_<อะไรก็ได้>` + Attribute `Music` = ชื่อใน BGM
--          (ใส่ `Ambient` = ชื่อใน Ambient / `Priority` = number ก็ได้ ทับซ้อนกันเอาเลขมากกว่า)
--
-- ไม่มีเสียงชื่อนั้น = warn ครั้งเดียวแล้วเงียบ **เกมไม่พัง**
--
--   SFX/ ที่ยังไม่มีเสียง (wire ไว้แล้วในโค้ด รอทีมอัดเสียงใส่):
--     qte_tick             เข็ม skillcheck แตะเข้าโซน good
--     qte_hit_perfect / qte_hit_good / qte_hit_miss   ผลแต่ละครั้งที่กด
--     qte_jackpot           จบรอบด้วย perfect ล้วน
--     camera_shutter         กดกล้องอัดคลิป
--     record_bonus / record_gain   ตัวเลขลอย +Bonus / +ปกติ
--     notebook_place          วางโน้ตบุ๊คลงพื้น
--     zone_enter / zone_exit    เข้า/ออกวงโซนถ่าย
--     app_open / app_close      เปิด/ปิดแอปในคอม
--     pc_off                    ปิดหน้าจอคอมทั้งจอ
--
-- pure: insideBox / bestZone (เทสใน lune ได้) | glue: ที่เหลือ
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../shared/Config")

local AudioService = {}

-- ===== pure =====

-- จุดอยู่ในกล่องไหม (พิกัดแปลงเป็น local ของกล่องแล้ว) — p/size = {x=,y=,z=}
function AudioService.insideBox(p, size): boolean
	return math.abs(p.x) <= size.x / 2
		and math.abs(p.y) <= size.y / 2
		and math.abs(p.z) <= size.z / 2
end

-- โซนที่ชนะเมื่อยืนซ้อนหลายโซน = priority มากสุด (เท่ากัน = ตัวแรกที่เจอ)
function AudioService.bestZone(zones)
	local best = nil
	for _, z in zones do
		if not best or (z.priority or 0) > (best.priority or 0) then best = z end
	end
	return best
end

-- ===== glue (Studio เท่านั้น) =====

local SoundService = if isStudio then game:GetService("SoundService") else nil
local warned = {}

-- SoundService ไม่มี property Volume — คุมระดับเสียงรวมต้องผ่าน SoundGroup
local masterGroup = nil
local function master()
	if not masterGroup then
		masterGroup = SoundService:FindFirstChild("Master")
		if not masterGroup then
			masterGroup = Instance.new("SoundGroup")
			masterGroup.Name = "Master"
			masterGroup.Parent = SoundService
		end
	end
	return masterGroup
end

function AudioService.getVolume(): number
	return master().Volume
end

function AudioService.setVolume(v: number)
	master().Volume = math.clamp(v, 0, 1)
end

-- เสียงแยกกลุ่มย่อยใต้ Master: Music(เพลง)/SFX/Ambient — สไลเดอร์คุมแยก · Master คุมรวมทั้งหมด
local groups = {}
local function group(name)
	if not groups[name] then
		local g = master():FindFirstChild(name)
		if not g then g = Instance.new("SoundGroup"); g.Name = name; g.Parent = master() end
		groups[name] = g
	end
	return groups[name]
end
local function music() return group("Music") end
local KIND = { bgm = "Music", sfx = "SFX", ambient = "Ambient" }

-- stateless: อ่าน/เขียน Volume ของ SoundGroup ตรงๆ — coherent กับแผงตั้งค่าที่ยุ่ง SoundGroup ตรงเหมือนกัน (มัน sandboxed, require ไม่ได้)
function AudioService.setGroupVolume(kind: string, v: number)
	group(KIND[kind] or "SFX").Volume = math.clamp(v, 0, 1)
end

function AudioService.getGroupVolume(kind: string): number
	return group(KIND[kind] or "SFX").Volume
end

-- mute เพลง: จำระดับก่อน mute ไว้ที่ attribute PreMute (คืนค่าเดิมตอนเลิก mute)
function AudioService.setMusicMuted(on: boolean)
	local m = music()
	if on then
		if m.Volume > 0 then m:SetAttribute("PreMute", m.Volume) end
		m.Volume = 0
	else
		m.Volume = m:GetAttribute("PreMute") or 1
	end
end

function AudioService.isMusicMuted(): boolean
	return music().Volume <= 0
end

local function findSound(folderName: string, soundName: string)
	if not soundName or soundName == "" then return nil end
	local folder = SoundService:FindFirstChild(folderName)
	local snd = folder and folder:FindFirstChild(soundName)
	if not snd then
		local key = folderName .. "/" .. soundName
		if not warned[key] then
			warned[key] = true
			warn("[Audio] ไม่มีเสียง: " .. key .. " (วาง Sound ชื่อนี้ใน SoundService." .. folderName .. ")")
		end
		return nil
	end
	return snd
end

-- เสียงสั้น: clone แล้วเล่นทับกันได้ ไม่ตัดกันเอง · volumeScale = คูณ Volume เดิม (เบาลง เช่น toast)
function AudioService.sfx(name: string, pitchVary: number?, volumeScale: number?)
	local src = findSound("SFX", name)
	if not src then return end
	local s = src:Clone()
	if pitchVary and pitchVary > 0 then
		s.PlaybackSpeed = src.PlaybackSpeed + (math.random() * 2 - 1) * pitchVary
	end
	if volumeScale then s.Volume = src.Volume * volumeScale end
	s.SoundGroup = group("SFX")
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	task.delay(10, function() if s.Parent then s:Destroy() end end) -- กันค้างถ้า Ended ไม่ยิง
end

-- blip ตอนพิมพ์ตัวอักษร (DialogueUI เรียก) — throttle กันถี่เกินจนหูแตก
local lastVoice = 0
function AudioService.voice(npcName: string?)
	local now = os.clock()
	if now - lastVoice < Config.Audio.voiceMinGap then return end
	lastVoice = now
	local src = findSound("Voice", npcName or "Default") or findSound("Voice", "Default")
	if not src then return end
	local s = src:Clone()
	s.PlaybackSpeed = src.PlaybackSpeed + (math.random() * 2 - 1) * Config.Audio.voicePitchVary
	s.SoundGroup = group("SFX")
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
end

-- เพลง: เปลี่ยนแบบ fade | ชื่อเดิม = ไม่ทำอะไร | nil/"" = เงียบ
local currentBGM, bgmName = nil, nil
local bgmTargetVol = 0 -- ระดับเสียงเต็มของเพลงปัจจุบัน (ก่อน duck)
local ducked = false   -- หรี่เพลงอยู่ไหม (ตอนคุย NPC)
local DUCK_LEVEL = 0.22
local function fadeOut(snd, t)
	if not snd then return end
	game:GetService("TweenService"):Create(snd, TweenInfo.new(t), { Volume = 0 }):Play()
	task.delay(t, function() if snd.Parent then snd:Destroy() end end)
end

function AudioService.bgm(name: string?, fadeTime: number?)
	if name == bgmName then return end
	local t = fadeTime or Config.Audio.bgmFade
	fadeOut(currentBGM, t)
	currentBGM, bgmName = nil, name
	local src = findSound("BGM", name)
	if not src then return end
	local s = src:Clone()
	s.Looped = true
	bgmTargetVol = src.Volume
	s.Volume = 0
	s.SoundGroup = music()
	s.Parent = SoundService
	s:Play()
	local goal = if ducked then bgmTargetVol * DUCK_LEVEL else bgmTargetVol
	game:GetService("TweenService"):Create(s, TweenInfo.new(t), { Volume = goal }):Play()
	currentBGM = s
end

-- หรี่เพลงชั่วคราว (ตอนคุย NPC ให้ได้ยิน blip ชัด) แล้วคืนตอนคุยจบ — ไม่เปลี่ยนเพลง แค่ปรับ volume
function AudioService.duckBGM(on: boolean, fadeTime: number?)
	ducked = on
	if not currentBGM then return end
	local goal = if on then bgmTargetVol * DUCK_LEVEL else bgmTargetVol
	game:GetService("TweenService"):Create(currentBGM, TweenInfo.new(fadeTime or 0.4), { Volume = goal }):Play()
end

-- เสียงบรรยากาศ: ซ้อนบนเพลง (คนละเลเยอร์)
local currentAmb, ambName = nil, nil
function AudioService.ambient(name: string?)
	if name == ambName then return end
	fadeOut(currentAmb, Config.Audio.bgmFade)
	currentAmb, ambName = nil, name
	local src = findSound("Ambient", name)
	if not src then return end
	local s = src:Clone()
	s.Looped = true
	local target = src.Volume
	s.Volume = 0
	s.SoundGroup = group("Ambient")
	s.Parent = SoundService
	s:Play()
	game:GetService("TweenService"):Create(s, TweenInfo.new(Config.Audio.bgmFade), { Volume = target }):Play()
	currentAmb = s
end

-- ===== โซนเพลง: Part ชื่อ Zone_* + Attribute Music/Ambient/Priority =====
local zoneParts = {}
local function collectZones()
	table.clear(zoneParts)
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Name:match("^Zone_") then
			table.insert(zoneParts, d)
		end
	end
end

-- เพลงที่ล็อกไว้ (cutscene/event) — โซนหยุดสั่งเพลงจนกว่าจะปลด
local locked = false
function AudioService.lockBGM(on: boolean)
	locked = on
end

local function updateZone(root)
	if locked or not root then return end
	local hits = {}
	for _, part in zoneParts do
		if part.Parent then
			local lp = part.CFrame:PointToObjectSpace(root.Position)
			if AudioService.insideBox({ x = lp.X, y = lp.Y, z = lp.Z },
				{ x = part.Size.X, y = part.Size.Y, z = part.Size.Z }) then
				table.insert(hits, {
					name = part:GetAttribute("Music"),
					ambient = part:GetAttribute("Ambient"),
					priority = part:GetAttribute("Priority") or 0,
				})
			end
		end
	end
	local z = AudioService.bestZone(hits)
	AudioService.bgm(z and z.name or Config.Audio.defaultBGM)
	AudioService.ambient(z and z.ambient or nil)
end

-- เสียงเดิน: ใช้ footstep script แบบ material-based (ServerScriptService) แทน — ถอดของเดิมออกแล้ว

-- เรียกครั้งเดียวจาก Main.client
function AudioService.init(player)
	collectZones()
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d.Name:match("^Zone_") then table.insert(zoneParts, d) end
	end)

	local accum = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		accum += dt
		if accum >= Config.Audio.zoneCheckInterval then
			accum = 0
			updateZone(root)
		end
	end)
end

return AudioService
