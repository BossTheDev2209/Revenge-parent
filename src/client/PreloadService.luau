-- PreloadService.luau — โหลด asset ล่วงหน้า (mesh/texture/sound/animation) กัน "กดแล้วโหลดไม่ทัน"
-- user 12 ส.ค.: อยากให้หน้าเมนูโหลด asset เฟส 1 รอไว้ + ก่อนเข้า cutscene โหลด anim ที่จะใช้รอไว้
--
-- ★ คนละระบบกับ StreamingEnabled/ModelStreamingMode (docs/05 §3.7, MenuUI.luau ตอนแก้ MenuCam_Home timeout)
--   StreamingEnabled = คุมว่า "instance ไหนอยู่ใน DataModel ของ client" (part หายไปเลยถ้าไกลเกิน)
--   PreloadService (ไฟล์นี้) = คุมว่า "เนื้อไฟล์ asset (mesh/texture/sound/animation) โหลดมาแคชไว้หรือยัง"
--   ของ 2 อย่างนี้แก้กันคนละทาง — instance ต้องอยู่ใน DataModel ก่อนถึงจะส่งเข้า PreloadAsync ได้
--
-- ทุกฟังก์ชัน fire-and-forget (task.spawn) — พลาด/ช้าไม่บล็อกอะไร ไม่ทำเกมค้าง
-- แค่เพิ่มโอกาสให้ asset แคชไว้ก่อนใช้จริง ไม่ใช่การันตี 100%
local isStudio = script ~= nil
local AnimPlayer = if isStudio
	then require(script.Parent.AnimPlayer)
	else require("./AnimPlayer")

local PreloadService = {}

-- ยิง preload พื้นหลัง ไม่บล็อก caller — error ก็แค่ warn ไม่ทำอะไรพัง
-- ★ game:GetService เรียกแบบ lazy ในนี้ (ไม่ใช่ top-level) — ไฟล์นี้ถูก require จาก CutscenePlayer
--   ที่เทสผ่าน lune ได้ (ไม่มี `game` global นอก Roblox) top-level call จะพังทันทีตอนเทส (แพทเทิร์นเดียวกับ AnimPlayer.luau)
function PreloadService.preload(instances: { Instance })
	if #instances == 0 then return end
	task.spawn(function()
		local ok, err = pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(instances)
		end)
		if not ok then warn("[PreloadService] preload พลาด:", err) end
	end)
end

-- โหลดทุก asset ใต้ container ล่วงหน้า (ต้อง stream เข้า client แล้วก่อน ไม่งั้นไม่มีอะไรให้โหลด)
function PreloadService.preloadContainer(container: Instance?)
	if not container then return end
	PreloadService.preload(container:GetDescendants())
end

-- โหลดแมพของเฟสที่ระบุ (เรียกตอนอยู่หน้าเมนู ก่อนกดเล่นจริง) — ชื่อ mapName เช่น "Map_Phase1"
function PreloadService.preloadMap(mapName: string)
	local map = workspace:FindFirstChild("Map")
	local target = map and map:FindFirstChild(mapName)
	if not target then
		warn("[PreloadService] ไม่เจอ workspace.Map." .. mapName .. " (ยัง stream ไม่เข้า หรือชื่อไม่ตรง) — ข้าม preload")
		return
	end
	PreloadService.preloadContainer(target)
end

-- สแกน step ของ cutscene หา anim/objAnim แล้ว preload animation ที่ steps นั้นจะเรียกจริง
-- ใช้ AnimPlayer.findAnimation ตัวเดียวกับตอนเล่นจริง (ดู AnimPlayer.luau) — ชื่อไม่ตรงจะไม่เจอเหมือนกันทั้งคู่
-- ไม่ maintain asset id list แยก กันไฟล์ 2 ไฟล์ไม่ตรงกัน (เจอ pattern นี้มาแล้วในเทส ActivityCutscene.NAMES)
function PreloadService.preloadCutscene(steps: { any })
	local found = {}
	for _, step in steps do
		local actor = step.type == "objAnim" and step.object or step.actor
		if (step.type == "anim" or step.type == "objAnim") and actor and step.name then
			local anim = AnimPlayer.findAnimation(actor, step.name)
			if anim then table.insert(found, anim) end
		end
	end
	PreloadService.preload(found)
end

return PreloadService
