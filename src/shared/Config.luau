--!strict
-- Config.luau — ตัวเลข canon ทั้งหมด ถอดมาจาก docs/02-game-design-locked.md
--
-- กฎ: ห้าม hardcode ตัวเลข balance ที่อื่น อ่านจากไฟล์นี้เท่านั้น
-- ถ้า design doc เปลี่ยน → แก้ที่นี่ที่เดียว → test ใน tests/ ต้องยังผ่าน
-- ถ้าไฟล์นี้ขัดกับ design doc → design doc ถูก แก้ไฟล์นี้ตาม อย่าแก้ doc ตามโค้ด

local Config = {}

-- ★ ไม่ใช่ balance number — allowlist คนใช้ /dev นอก Studio (docs/15-dev-console.md)
-- Studio เปิดให้ทุกคนเสมอ (ไม่ต้องอยู่ list นี้) · list นี้คุมสิทธิ์เฉพาะตอนเข้าเล่นเกม published จริง
-- CoolingLikeAir, mikmikrobolx, tanxddddd (resolve ด้วย Players:GetUserIdFromNameAsync 10 ส.ค. 2569)
Config.DevUserIds = { 3010077941, 183036806, 632366901 }

-- §1 Phase gate — ตัดจาก follower ปัจจุบันเท่านั้น ไม่ผูกจำนวนคลิป
Config.PhaseGates = {
	{ phase = 1, min = 0, max = 10_000 },
	{ phase = 2, min = 10_000, max = 100_000 },
	{ phase = 3, min = 100_000, max = 1_000_000 },
}
-- Canon event ทั้งหมด (docs/02 §9.4 — ตาม timeline PDF หน้า 4 หลังตัดพ่อแม่โทรมา/งานเสริม)
-- ทุกตัวยิง dialogue จาก Content.CanonEvents["milestone_"..เลข] + drain mod ×1.25 24 ชม.
Config.StoryMilestones = {
	1_000, -- ยังอยู่เฟส 1 (Homeless)
	10_000, -- เข้าเฟส 2 + recruit เพื่อน 1
	30_000, -- มีเรื่องกับ Hater
	100_000, -- เข้าเฟส 3 + recruit เพื่อน 2
	500_000, -- เพื่อนร่วมทาง Issue = ทรยศ
	700_000, -- มีเรื่องกับ CC
	1_000_000, -- ถึงเป้า
}
Config.BetrayalMilestone = 500_000
Config.BetrayalMentalPenalty = -25
-- faasai เข้าร่วม (StoryBeat เคาะประตู→นั่งเตียง) — ยิงตอน follower ถึงค่านี้ในเฟส 2 (ปรับได้)
Config.FaasaiJoinFollower = 30_000
-- BCA (Bangkok Creator Award) — คิวต่อท้ายทันทีหลัง milestone 1M ก่อน ending cutscene
-- ไม่ใช้ตัวเลข milestone เพราะเวลาหยุดที่ 1M พอดี follower ไม่มีทางเกิน
Config.BCAEventId = "bca"
Config.BCAAfterMilestone = 1_000_000

-- §2 Follower ต่อคลิป = base(สุ่ม) × VidQ × mental, มีโอกาส viral
Config.FollowerBase = {
	[1] = { min = 400, max = 900 },
	[2] = { min = 1_400, max = 2_600 },
	[3] = { min = 9_000, max = 15_000 },
}

Config.MaxClipAccuracy = 200
-- label C/B/A/S เท่านั้น ห้ามใช้ bad/normal/good/awesome
Config.VidQTiers = {
	{ tier = "C", minAcc = 0, maxAcc = 50, mult = 0.5 },
	{ tier = "B", minAcc = 51, maxAcc = 100, mult = 1.0 },
	{ tier = "A", minAcc = 101, maxAcc = 150, mult = 1.5 },
	{ tier = "S", minAcc = 151, maxAcc = 200, mult = 2.0 },
}

Config.Viral = { chance = 0.12, multMin = 4, multMax = 8 }

-- §3 Mental bar
Config.Mental = {
	start = 80,
	drainPercent = 1,
	drainEverySeconds = 4.5,
	introducedInPhase = 2,
	-- โซน: cap โบนัสที่ 1.25 จงใจ ห้าม stack กับ viral(×4–8) + S(×2) จน pacing พัง
	zones = {
		{ min = 70, max = 100, multMin = 1.0, multMax = 1.25 },
		{ min = 40, max = 69, multMin = 1.0, multMax = 1.0 },
		{ min = 1, max = 39, multMin = 0.6, multMax = 1.0 },
	},
	badEndAt = 0, -- 0% = Bad End ②
	deltas = {
		clipEdit = -20,
		npcChoiceBad = -10,
		rentMissed = -15,
		npcChoiceGood = 15,
		-- ตอบ comment (PDF หน้า 8 ล่าง — user lock 21 ก.ค.)
		commentHeartPos = 10, -- กดใจ comment ⊕
		commentHeartNeg = -10, -- กดใจ comment ⊖
		commentAccept = 10, -- ยอมรับปัญหา (⊖/◎)
		commentSarcasm = -5, -- ประชด (⊖/◎)
		commentInsult = -10, -- ด่า (⊖ เท่านั้น)
		viralClip = 25,
		-- ★ แก้ 9 ส.ค. (user): ตัดหน่วยเวลาที่เคยผูกไว้ทิ้ง เอาแค่ค่าใจที่เพิ่มจริงในหลอด (เดิม 20/25/15)
		activityExercise = 30,
		activityRest = 40,
		activityEat = 20,
	},
	-- Activity system (PDF หน้า 6): ทำติดกันเกิน maxStreak → cooldown ข้ามวัน
	activity = { maxStreak = 3, cooldownDays = 1 },

	-- ★ ฉากสั้นตอนทำ activity (docs/02 §3 + §9 "cutscene 5–10 วิ + ฟื้น mental") — ยังว่างทุกตัว 9 ส.ค.
	--   ว่าง = กดแล้วได้ผลใจทันทีไม่มีฉากคั่น (เกมเล่นได้ครบ ไม่ค้างรอ content)
	--   ใส่ steps เมื่อไหร่ = เล่นฉากทันที **ไม่ต้องแก้โค้ดที่ไหนเลย** (ActivityCutscene อ่านตารางนี้ตรงๆ)
	--   รูปแบบ step เหมือน CutscenePlayer ทุกอย่าง: camera / text / wait / anim / face / sound / bgm / move / focus
	--   ตัวอย่างที่จะใส่ทีหลัง:
	--     Bed = { { type = "camera", cam = "Cam_BedRest", t = 1 }, { type = "anim", actor = "player", name = "Sleep" },
	--             { type = "text", text = "หลับตาสักครู่..." }, { type = "wait", t = 5 } }
	activityCutscenes = {
		Bed = {},
		Kitchen = {},
		Exercise = {},
	},

	-- Drain/Recovery modifiers (lock 19 ก.ค. — docs/02 §3)
	-- kind: "drain" = คูณอัตรา drain | "recover" = คูณ delta ฝั่งบวก
	-- อายุ: hours = หมดตามชั่วโมงเกม | untilEvent = "sleep"|"activity"|"activityOrGood"
	mods = {
		NoSleep = { mult = 1.5, kind = "drain", untilEvent = "sleep" },
		CanonEvent = { mult = 1.25, kind = "drain", hours = 24 },
		EditStreak5 = { mult = 1.5, kind = "drain", untilEvent = "activity", streak = 5 },
		CommentBadStreak3 = { mult = 2, kind = "drain", untilEvent = "activityOrGood", streak = 3 },
		CommentGoodStreak3 = { mult = 1.25, kind = "recover", hours = 24, streak = 3 },
		ViralStreak2 = { mult = 2, kind = "recover", hours = 36 },
		-- dormant: dialogue ทางเดียวไม่มี choice (docs/02 §6) — เก็บไว้เผื่อดึง NPC choice กลับ
		NpcBadStreak3 = { mult = 2, kind = "drain", untilEvent = "activityOrGood", streak = 3 },
		NpcGoodStreak3 = { mult = 1.5, kind = "recover", hours = 24, streak = 3 },
	},
	modCap = 3, -- คูณซ้อนกันได้ไม่เกิน ×3 ทั้งสองฝั่ง
	awakeHoursForNoSleep = 20,
}

-- §4 Economy
Config.MoneyRatePerFollower = { [1] = 0.8, [2] = 1.2, [3] = 1.5 }

-- ค่าใช้จ่ายรอบ 7 วันในเกม ไม่นับจำนวนคลิป
Config.WeeklyExpenses = {
	[1] = { rent = 1_500, internet = 300, food = 400 }, -- รวม 2,200
	[2] = { rent = 3_000, internet = 500, food = 600 }, -- รวม 4,100
	[3] = { rent = 6_000, internet = 800, food = 900 }, -- รวม 7,700
}

-- อุปกรณ์ 6 ระดับ (user lock 21 ก.ค. — เริ่มฟรีระดับ 1, ซื้อเพิ่ม 5 ครั้ง/สาย)
-- ราคา: costs[ระดับปัจจุบัน] = ราคาซื้อระดับถัดไป
-- ระบบพนักงาน (docs/02 §9.8 — lock 21 ก.ค.)
-- คลิป auto: ไม่กิน footage, ไม่มี viral, ไม่คูณ mental | นับ VidQ% ครึ่งเดียว | สร้าง comment ปกติ
Config.Staff = {
	clipsPerDayPerSpeed = 20, -- คลิป/วัน = speed / 20
	hireCap = 4,              -- จ้างพร้อมกันได้ 4 (companion ไม่นับ)
	vidqWeight = 0.5,         -- คลิปพนักงานนับเข้า VidQ% ครึ่งเดียว (กัน ending ถูกทีมกลบ)

	-- quality → โอกาสได้ tier (สุ่มทุกคลิป) — ช่วงเรียงจากน้อยไปมาก
	tierChanceByQuality = {
		{ maxQuality = 40, C = 0.60, B = 0.30, A = 0.10, S = 0.00 },
		{ maxQuality = 70, C = 0.20, B = 0.45, A = 0.30, S = 0.05 },
		{ maxQuality = 90, C = 0.05, B = 0.25, A = 0.45, S = 0.25 },
		{ maxQuality = math.huge, C = 0.00, B = 0.10, A = 0.40, S = 0.50 },
	},

	-- roster จ้าง: ปลดต้องครบทั้ง phase และ follower | pool คงที่ ไม่สุ่ม stat
	-- 2 แกน trade-off: speed = ปริมาณคลิป (โต follower) · quality = เกรด tier (ปกป้อง VidQ%/ending)
	--   speed สูง/quality ต่ำ = follower พุ่งแต่ลาก VidQ% ลง (คลิปทีมนับ VidQ ครึ่งเดียว) = เสี่ยง ending แย่
	--   salary กินเพดานเงิน 1.47M = แย่งงบกับ upgrade · hireCap 4 บังคับเลือกสาย
	-- flag (optional) = ปลดต่อเมื่อ state.flags[flag] ติด (ทีมล้างแค้นหลัง faasai ทรยศ)
	-- leavesOnSplit = true → ลาออกตอน event ตีกัน (StaffService.splitStaff · flags.staffSplit)
	-- ตัว believer ไม่ tag = อยู่ต่อ · default นี้ปรับได้หลัง playtest
	roster = {
		-- เฟส 2: trade-off ชัด เลือกได้สายเดียว
		{ id = "hire_editor",    phase = 2, follower = 15_000,  speed = 32, quality = 30, salary = 9_000,  leavesOnSplit = true }, -- สายเร็ว transactional
		{ id = "hire_artisan",   phase = 2, follower = 30_000,  speed = 15, quality = 65, salary = 11_000 }, -- สายคุณภาพ (อยู่ต่อ)
		{ id = "hire_allround2", phase = 2, follower = 60_000,  speed = 22, quality = 45, salary = 10_000 }, -- all-rounder (อยู่ต่อ)
		-- เฟส 3: เก่งหลายด้าน (multi-skill) salary แพง
		{ id = "hire_pro",       phase = 3, follower = 150_000, speed = 45, quality = 70, salary = 32_000, leavesOnSplit = true }, -- โปรตามเงิน
		{ id = "hire_volume",    phase = 3, follower = 250_000, speed = 70, quality = 50, salary = 42_000, leavesOnSplit = true }, -- mercenary ตามยอด
		{ id = "hire_master",    phase = 3, follower = 450_000, speed = 35, quality = 90, salary = 46_000 }, -- สายคราฟต์ (อยู่ต่อ)
		-- ทีมล้างแค้น: ปลดเมื่อ faasai ทรยศ (flags.betrayed ตั้งที่ BetrayalMilestone 500K พร้อม companion_1 ออก)
		{ id = "hire_fierce1",   phase = 3, follower = 500_000, speed = 60, quality = 78, salary = 55_000, flag = "betrayed" },
		{ id = "hire_fierce2",   phase = 3, follower = 500_000, speed = 55, quality = 85, salary = 58_000, flag = "betrayed" },
	},

	-- worldNPC ผู้ภักดี: auto-hire ตอน split (ไม่อยู่ใน roster = player จ้างเองไม่ได้) การันตีมีคนเหลือเสมอ
	-- มี salary ปกติ · ไม่นับ hireCap ตอน force-add · Boss เอา model worldNPC มาใส่ (ตั้งชื่อโมเดลตาม id)
	loyalAfterSplit = { id = "hire_loyal", speed = 30, quality = 60, salary = 18_000 },

	-- เพื่อนร่วมทาง: auto มาตามเนื้อเรื่อง ฟรี ไล่ไม่ได้ ไม่นับ cap
	-- companion_1 โต exponential ตอนเข้าเฟส 3 แล้วหายที่ 500K (ทรยศ)
	companions = {
		{ id = "companion_1", joinFollower = 10_000, speed = 20, quality = 30,
			growAtPhase = 3, grownSpeed = 45, grownQuality = 75, leavesOnBetrayal = true },
		{ id = "companion_2", joinFollower = 100_000, speed = 40, quality = 85 },
	},
}

-- Bank ⊖⊕ (PDF หน้า 9 — user lock 21 ก.ค., step/ผลใจเลือกโดย agent — docs/02 §9.7)
-- ยอดจ่ายจริง/สัปดาห์ = WeeklyExpenses base + offset×step | ผลใจคิดตอนตัดรอบ 7 วัน
Config.Spending = {
	food = { step = 200, minOffset = -1, maxOffset = 3, mentalUp = 2, mentalDown = -4 },
	rent = { step = 500, minOffset = -2, maxOffset = 2, mentalUp = 1, mentalDown = -3, missedAtOffset = -2 },
	staff = { step = 1_000, minOffset = 0, maxOffset = 5 }, -- ผลผูกระบบพนักงาน (ยังไม่ทำ) — กันงบไว้ก่อน
}

-- ⚠️⚠️ ขยายเป็น 15 ระดับ (28 ก.ค.) — docs/02 §9.5 ยังเขียนว่า **6 ระดับ** อยู่ ต้องอัปเอกสารตาม
-- ระดับ 1-6 คงราคา/ค่าที่ล็อกไว้เป๊ะทุกตัว · 7-15 เป็นของต่อยอด (agent เลือก **รอ user lock**)
--
-- 💰 เงินทั้งเกมมีจำกัด: 10K×0.8 + 90K×1.2 + 900K×1.5 ≈ 1.47 ล้าน หักค่าใช้จ่ายเหลือ ~1.3 ล้าน
--    → ระดับ 1-6 ทั้ง 3 สายรวม ~1.27 ล้าน = เอื้อมถึงพอดีถ้าทุ่มสายเดียว
--    → ระดับ 7-15 **จงใจซื้อไม่ไหวในรอบเดียว** เป็นเป้าให้เห็นว่ายังไปต่อได้ ไม่ใช่ของที่ต้องซื้อครบ
--    ถ้าอยากให้ซื้อครบ 15 ต้องขยายเศรษฐกิจ (MoneyRatePerFollower) ซึ่งล็อกอยู่ — ต้อง user ตัดสิน
Config.UpgradeCosts = {
	-- ราคา = จ่ายตอนอยู่ระดับ N เพื่อขึ้น N+1 → 14 ขั้นสำหรับ 15 ระดับ
	camera = { 2_000, 8_000, 30_000, 120_000, 300_000, -- 1-6 ล็อก (docs/02 §4)
		750_000, 1_800_000, 4_200_000, 10_000_000, 24_000_000,
		56_000_000, 130_000_000, 300_000_000, 700_000_000 },
	storage = { 1_500, 6_000, 25_000, 100_000, 250_000, -- 1-6 ล็อก (docs/02 §4)
		600_000, 1_400_000, 3_300_000, 8_000_000, 19_000_000,
		45_000_000, 105_000_000, 250_000_000, 600_000_000 },
	-- ⚠️ pc = สายใหม่ ยังไม่มีใน docs/02 — ราคาทั้งเส้น agent เลือก **รอ user lock**
	-- ผลของมัน (ตัดต่อไวขึ้น = อะไร) ยัง unwired จงใจ: ซื้อได้/เก็บระดับได้ แต่ยังไม่มีผลกับเกม
	pc = { 5_000, 20_000, 60_000, 180_000, 450_000,
		1_100_000, 2_600_000, 6_200_000, 15_000_000, 36_000_000,
		85_000_000, 200_000_000, 480_000_000, 1_100_000_000 },
}

-- 1-6 ล็อก (480p→4320p) · 7-15 ต่อยอดเป็น fps/RAW เพราะ resolution ชนเพดานจริงแล้ว
Config.ResolutionLadder = { "480p", "720p", "1080p", "1440p", "2160p", "4320p",
	"4320p 60fps", "4320p 120fps", "8640p", "8640p 60fps",
	"8640p 120fps", "8640p RAW", "8640p 240fps", "17280p", "17280p RAW" }

-- 1-6 ล็อก (128GB→8TB) · 7-15 ต่อ ×2 ถึง 16PB
Config.StorageLadderGB = { 128, 256, 512, 1024, 4096, 8192,
	16_384, 32_768, 65_536, 131_072, 262_144,
	524_288, 1_048_576, 4_194_304, 16_777_216 }

-- โมเดล Tool ใน ReplicatedStorage.ToolModels มีถึง Camera_6 เท่านั้น (ระดับกล้องมี 15)
-- ระดับ 7+ ใช้โมเดลตัวท้ายสุดแทน — ไม่งั้น ToolService หาโมเดลไม่เจอ = ผู้เล่นไม่มีกล้องในมือเลย
-- ทีมปั้นโมเดลเพิ่มเมื่อไหร่ ขยับเลขนี้ตาม
Config.CameraModelCount = 6

-- ★ ระดับ 6 = Tool "Camera_6" ทำหน้าที่ **รีโมทเรียกรถเข็นกล้อง IMAX** (แก้ดีไซน์ 5 ส.ค.)
--   กล้องอยู่กับ player ตลอด ไม่ได้เอา Tool ออก · กดตอนยืน = เสกรถออกมาใหม่ทุกครั้ง
--   (ดีไซน์เดิม 3 ส.ค. คือเอา Tool ออกแล้วมีรถอยู่ในแมพ — user เปลี่ยนใจ)
--   ตัวคูณ GB/คลิก ยังใช้ footagePerClickGB[6] = 32 เหมือนเดิม ไม่แตะ balance
Config.CameraCartLevel = 6
Config.CameraCartToolSource = "Camera_6" -- ToolSource ของ Tool ที่เรียกรถ (RecordTool ข้ามตัวนี้ CameraCart คุมเอง)
Config.CameraCartTemplate = "CameraCart" -- ชื่อ Model ต้นฉบับใน ReplicatedStorage.ToolModels
Config.CameraCartSpawnStuds = 12 -- เสกห่างหน้าตัวผู้เล่นกี่ studs (กันโผล่ทับตัว)

-- ⚠️ ต้องตรงกับ SPRINT_SPEED ใน StarterCharacterScripts.SprintHandler (สำเนา src/studio-only/)
--    สคริปต์นั้น Rojo ไม่ sync เลย require ข้ามมาไม่ได้ — แก้ที่นั่นต้องแก้ตรงนี้ด้วย
Config.PlayerSprintSpeed = 50 -- เดินปกติ 16 · กด Shift วิ่ง 50
-- รถเร็วกว่าวิ่ง 1.5 เท่า (user lock 3 ส.ค.) — คุ้มค่าที่ไม่มี Tool ถือแล้ว
Config.CameraCartSpeed = Config.PlayerSprintSpeed * 1.5 -- = 75 studs/วินาที
-- user ปรับเองแล้วบอกว่าโอเค 3 ส.ค. (เดิม 1.6 วงเลี้ยวกว้างไป 47 studs)
Config.CameraCartTurnRate = 3 -- เรเดียน/วินาที ตอนเคลื่อนที่ (รัศมีวงเลี้ยว ≈ speed/turnRate = 25 studs)

-- ร้านค้าในแมพ (Part `Interact_Shop`) — คนละตัวกับแอป Shop บนจอคอม (PDF หน้า 9)
-- names[N] = ของที่ได้เมื่ออยู่ระดับ N แล้วกดซื้อ (→ ระดับ N+1) · ชิ้นสุดท้าย = ระดับ 15
-- ห้ามใส่ราคา/สเปคซ้ำที่นี่ — ราคามาจาก UpgradeCosts, สเปคคำนวณจาก ladder (ShopKiosk.specFor)
Config.ShopCatalog = {
	{ key = "pc", label = "💻 คอมพิวเตอร์", icon = "💻", note = "ตัดต่อไวขึ้น", startName = "โน้ตบุ๊คมือสอง",
		names = {
			"คอมประกอบมือสอง", "คอมสเปคตัดต่อ", "iMac มือสอง", "PC การ์ดจอแยก", "Workstation 8 คอร์",
			"Mac Studio", "PC เรนเดอร์ 2 การ์ดจอ", "Workstation 16 คอร์", "เครื่องเรนเดอร์ฟาร์มเล็ก",
			"Render Farm 4 เครื่อง", "Render Farm 16 เครื่อง", "เช่า Cloud Render",
			"Render Cluster ส่วนตัว", "ซูเปอร์คอมตัดต่อทั้งตึก",
		} },
	{ key = "storage", label = "💾 ที่เก็บข้อมูล", icon = "💾", note = "เก็บ footage ได้มากขึ้น", startName = "SSD พกพา",
		names = {
			"SSD NVMe เกรดเกมเมอร์", 'External HDD 2.5"', "HDD ตั้งโต๊ะ", "NAS 2 เบย์", "NAS 4 เบย์ RAID",
			"NAS 8 เบย์", "Server Rack มือสอง", "Server Rack ป้ายแดง", "ตู้ Rack เต็มตู้",
			"ห้อง Server ส่วนตัว", "เช่า Cloud Storage", "เช่าตึกทำ Data Center",
			"Data Center ของตัวเอง", "Data Center ทั้งเครือ",
		} },
	{ key = "camera", label = "📷 อุปกรณ์ถ่ายรูป", icon = "📷", note = "อัด footage ไวขึ้นต่อคลิก", startName = "มือถือเครื่องเก่า",
		names = {
			"มือถือใหม่", "กล้อง compact", "กล้อง mirrorless", "กล้อง DSLR โปร", "กล้อง cinema",
			"กล้อง cinema + เลนส์โปร", "กล้อง cinema 120fps", "โดรนถ่ายภาพ 8K", "ชุดกล้อง 3 ตัว + สวิตเชอร์",
			"เครน + กล้องรีโมท", "สตูดิโอกรีนสกรีน", "ชุดถ่าย 360° VR",
			"ทีมกล้องมืออาชีพ", "สตูดิโอถ่ายทำระดับหนัง",
		} },
}

-- ระบบอัดคลิป (user lock 21 ก.ค. + เลขต่อคลิกเลือกโดย agent — docs/02 §9.5)
-- สูตรต่อคลิก: GB = footagePerClickGB[กล้อง] × (bonus? bonusMult : 1) × (ในโซน? zoneMult : 1)
Config.Record = {
	-- GB ต่อคลิก ตามระดับกล้อง — เต็ม storage ระดับเดียวกัน ~128 คลิก (L5-6 ~256 จงใจ บังคับพึ่งโซน/พนักงาน)
	-- 1-6 ล็อก · 7-15 คุมอัตราส่วน storage[N]/perClick[N] = 256 เท่าเดิม (จำนวนคลิกต่อเต็มถังคงที่)
	footagePerClickGB = { 1, 2, 4, 8, 16, 32,
		64, 128, 256, 512, 1_024, 2_048, 4_096, 16_384, 65_536 },
	clickCooldownSeconds = 0.6, -- กันสแปมแบบ simulator (user feedback 21 ก.ค.)
	-- Bonus proc (PDF หน้า 7 "+2.4 Bonus!") — เกิดได้ทุกที่ ซ้อนกับโซนได้
	bonusChance = 0.1,
	bonusMult = 2.4,
	-- โซนถ่าย (จุดแดง PDF หน้า 4): อัดนอกโซนได้ base rate, ในโซน × ตัวคูณตามเฟส
	zoneMultByPhase = { [1] = 1.5, [2] = 2, [3] = 2.5 },
	zoneDurationSeconds = 120, -- โซนอยู่ 2 นาทีจริง แล้วสุ่มย้ายจุด (กัน AFK)
	-- ตัด 1 คลิป: default 32 GB = baseline ×1.0 ของ ClipSizes (denominator ของ sizeMult ด้วย)
	-- เดิม lock 27 ก.ค. คงที่ · unlock 8 ส.ค. ให้ผู้เล่นเลือกขนาดได้ (docs/02 §9.5) — 32 ยังเป็น baseline/ค่า default
	-- กล้อง L1: 32 คลิก/32GB, storage L1 เก็บได้ 4 คลิป | กล้อง L6: 1 คลิก/32GB = เหตุผลที่ต้องอัปกล้อง
	footagePerClipGB = 32,
	zoneRadiusStuds = 18, -- รัศมีวงโซน (agent เลือก — ปรับได้ ไม่มีใน PDF)
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎯 RecordQTE — DBD-style skill check ตอนถ่ายคลิป (v3 10 ส.ค. user — แก้จาก "นับ bounce" เป็น "นับครั้งที่กด")
--   คลิกถ่ายสำเร็จ → สุ่ม chance เจอ QTE → เข็มวิ่งกลับไปมา (ping-pong) บนแถบเส้นล่างจอ "อิสระ" ไม่หยุด
--     ชนขอบ = สลับทิศเอง ไม่นับเป็นอะไร (แค่ physics ของเข็ม) — N ครั้งที่ต้องกด Space (PC)/แตะ (มือถือ)
--     ต่างหาก คือตัวตัดสิน ไม่เกี่ยวกับจำนวน bounce เลย (สุ่ม hitsMin-hitsMax ต่อ QTE)
--   กด 1 ครั้ง = เกรดจากตำแหน่งเข็ม ณ ตอนนั้น (ไม่แตะ pos/dir ของเข็ม เข็มเดินหน้าต่อตามเดิม)
--   เล่นจนกดครบ N ครั้งเสมอ — ไม่มี fail-fast, กดพลาดได้ 0 แต่ยังนับเป็น 1 ใน N ครั้งเสมอ
--   reward สะสมทีละครั้งที่กด เพดานรวม rewardMultMax (×10) ไม่ว่า N เท่าไหร่: ต่อครั้ง Perfect = max/N, Good = ×goodRewardRatio ของนั้น
--   ยิ่งกดสำเร็จไปแล้วกี่ครั้ง ยิ่งเร่งไว (sweepSecondsFor ผูกกับจำนวนที่กดไปแล้ว ไม่ใช่เวลาที่ผ่านไปเฉยๆ)
--   ⚠️ timeoutSeconds = safety net ถ้าไม่กดเลย (เผลอ/ค้าง) — เกินนี้ auto-จบให้ ที่เหลือนับ miss กัน lock ตลอดไป
--   reward เป็น footage เพิ่ม (additive, cap ด้วย storage) → ไม่กระทบเพดานเงิน 1.47M โดยตรง (footage cap อยู่แล้ว)
--   ระหว่าง QTE: InteractLock.lock() ปิด E + freeze เดิน/กระโดด · geometry (0..1 ตามความยาวแถบ) tune อิสระ ไม่มีใน PDF
-- ═══════════════════════════════════════════════════════════════════════════
Config.RecordQTE = {
	chance = 0.02,           -- โอกาสเจอ QTE ต่อคลิกถ่ายสำเร็จ 1 ครั้ง (2%)
	hitsMin = 1, hitsMax = 5, -- จำนวนครั้งที่ต้องกด Space จริง (ไม่ใช่จำนวน bounce ของเข็ม) สุ่มต่อ QTE
	rewardMultMax = 10,      -- เพดานรวมทั้ง QTE (Perfect ครบทุกครั้ง = ได้เท่านี้ ไม่ว่า N เท่าไหร่)
	goodRewardRatio = 0.5,   -- Good ต่อครั้ง = สัดส่วนนี้ของ Perfect ต่อครั้ง (เท่าเดิม: Good ครึ่งนึงของ Perfect)
	sweepSecondsStart = 1.2, -- ความเร็วเข็มก่อนกดครั้งแรก (ช้าสุด วิ/เที่ยว)
	sweepSecondsMin = 0.5,   -- พื้นความเร็ว (เร่งไม่เกินนี้)
	timeoutSeconds = 15,     -- ไม่กดเลยเกินนี้ = auto-จบ (ที่เหลือ miss) กัน InteractLock ค้างตลอดไป
	sweepSpeedupPerHit = 0.15, -- ลด sweepSeconds กี่วิ ต่อจำนวนครั้งที่กดสำเร็จไปแล้ว 1 ครั้ง (ไม่ใช่ต่อ bounce)
	centerMin = 0.30, centerMax = 0.80, -- กึ่งกลางโซนสำเร็จสุ่มครั้งเดียวตอนเริ่ม (คงที่ตลอด — เข็มวิ่งผ่านเป้าเดิมซ้ำๆ)
	goodHalfWidth = 0.11,      -- โซน Good (กว้าง): |pos-center| ≤ นี่ = อย่างน้อย Good
	perfectHalfWidth = 0.035,  -- โซน Perfect (แคบ กลางโซน Good): ≤ นี่ = Perfect
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎬 ClipSizes — เลือกขนาด footage ก่อนตัด (risk↔reward, user lock 8 ส.ค.)
--   ขนาด↑ = QTE ยากขึ้น (วงบนจอเยอะ + หดเร็ว + วงมาก) แลกกับ reward ×(gb/32)
--   • rewardMult ไม่เก็บที่นี่ — คำนวณ Formulas.clipSizeMult(gb)=gb/footagePerClipGB (proportional lock)
--   • difficulty (hits/maxOnScreen/spawnInterval/approach) tune ได้อิสระตรงนี้
--   • baseline = แถว gb=32 (= preset "duo" เดิม) · เพิ่มแถว 256/512… ได้เลย ("ไปเรื่อยๆ")
--   • ผู้เล่นเลือกได้เฉพาะขนาดที่ footage ปัจจุบัน ≥ gb (EditQTE.clipSizesFor กรองให้)
-- ═══════════════════════════════════════════════════════════════════════════
Config.ClipSizes = {
	{ gb = 8,   hits = 10, maxOnScreen = 1, spawnInterval = 0.55, approach = 1.70 },
	{ gb = 16,  hits = 14, maxOnScreen = 2, spawnInterval = 0.48, approach = 1.55 },
	{ gb = 32,  hits = 20, maxOnScreen = 2, spawnInterval = 0.40, approach = 1.40 }, -- baseline ×1.0
	{ gb = 64,  hits = 28, maxOnScreen = 3, spawnInterval = 0.34, approach = 1.20 },
	{ gb = 128, hits = 40, maxOnScreen = 4, spawnInterval = 0.28, approach = 1.05 },
}

Config.SponsorUnlockFollowers = 10_000
Config.SponsorOfferChance = 0.05 -- PDF หน้า 6: offer เด้งเอง 5%/วัน (เฟส 2-3) ไม่ใช่ปุ่มกดเรียก
Config.SponsorOfferMinPhase = 2
-- ★ แก้ดีไซน์ 9 ส.ค. (user): sponsor ไม่ต้องเลือกวางวันในปฏิทินแล้ว — offer เด้งเป็น notification
--   กดรับ = ได้ buff "เงินจากคลิป ×Mult" ทันที นาน Days วันในเกม (ปฏิทินถูกพับไว้ ดู CalendarService)
--   offer ที่ไม่กดรับหมดอายุตอนขึ้นวันใหม่ (ไม่งั้นค้าง = สุ่มใบใหม่ไม่ได้ตลอดกาล เพราะไม่มี UI ปฏิทินให้เปิดดูแล้ว)
Config.SponsorBuffMult = 2 -- เงินจากคลิปที่อัปโหลดระหว่าง buff ×เท่านี้ (follower ไม่คูณ — คูณเฉพาะเงิน)
Config.SponsorBuffDays = 1 -- buff อยู่กี่วันในเกมนับจากวันที่กดรับ

-- §5 Ending resolver — priority order สำคัญ เช็คแย่สุด→ดีสุด return ทันทีที่ match
-- ห้ามสลับลำดับ เงื่อนไข overlap กัน
Config.EndingPriority = { "Bad1", "Bad2", "Bad3", "Good1", "Neutral1", "Neutral2" }

-- VidQ % = สัดส่วนของคลิปที่ถ่ายจริงทั้งหมด
-- Choice % = สัดส่วนของ choice ที่ตอบทั้งหมด (⊕ + ◎ + ⊖ = 100%) — comment เท่านั้นที่นับ
Config.EndingThresholds = {
	Bad3 = { vidq = { cMin = 33, bMax = 33 }, choice = { negMin = 50, neuMax = 25 } },
	Neutral1 = { vidq = { cMax = 20, bMax = 33, aMin = 13, sMax = 13 }, choice = { spreadMax = 25 } },
	Neutral2 = { vidq = { cMax = 26, bMax = 33 }, choice = { negMax = 37.5, neuMin = 25 } },
	Good1 = {
		vidq = { cMax = 16, bMax = 33, aMin = 30, sMax = 20 },
		choice = { posMin = 62.5, negMax = 12.5, neuMax = 12.5 },
	},
}
-- Bad1 = เงินหมด โดนไล่ที่ 2 รอบ (phase 1–2) | Bad2 = mental ≤ 0 (phase 2–3) — ทั้งคู่ optional
-- Neutral/Good ต้องถึง 1M ก่อน

-- Dialogue: typewriter + กล้องตอนคุย NPC (ปรับค่าที่นี่ที่เดียว)
Config.Dialogue = {
	charDelay = { normal = 0.03, slow = 0.08, fast = 0.012 }, -- วิ/ตัวอักษร (น้อย = เร็ว)
	-- กล่องข้อความสไตล์ Undertale-lite: **ขนาดคงที่เป็น px** ข้อความยาวขึ้น = ตัดบรรทัดใหม่
	-- (ไม่ใช่ยืดกล่อง/ย่อฟอนต์) · ตัวอักษรขนาดเดียวตลอดเกม · สีคุมให้ contrast น้อยกว่า Undertale จริง
	-- (ไม่ใช่ดำ/ขาวล้วน กันดูก็อปตรงๆ) อัตราส่วนกว้าง:สูง ~5:1 แบบกล่องหนัง
	box = {
		width = 900,     -- กว้างกล่อง (px)
		height = 176,    -- สูงกล่อง (px) — พอดี 3 บรรทัดที่ textSize 30
		bottomGap = 30,  -- ห่างจากขอบล่างจอ (px)
		textSize = 30,   -- ขนาดตัวอักษรคงที่ ไม่ย่อตามความยาว
		padding = 20,    -- ระยะขอบในกล่อง (px)
		portrait = 132,  -- ด้านของช่อง viewport หน้าตัวละครฝั่งซ้าย (px) — ไม่มี rig = ซ่อน ข้อความกินเต็มกล่อง
		border = 3,      -- ความหนาขอบขาว (Frame ทึบวางนอกกล่อง ไม่ใช่ UIStroke — ดู DialogueUI.show)
		bgColor = Color3.fromRGB(28, 27, 34),     -- พื้นกล่อง (เทาเข้มอมม่วง ไม่ใช่ดำสนิท)
		textColor = Color3.fromRGB(236, 233, 240),   -- ตัวอักษร (ขาวหม่น)
	},
	zoomLevels = { 6, 10, 16 }, -- ระยะกล้อง ใกล้/ปกติ/ไกล (studs, น้อย = ซูมเข้า)
	zoomDefault = 2, -- เริ่มที่ระดับไหน (index ใน zoomLevels)
	camHeight = 1.5, -- ความสูงกล้องเหนือจุดหัว NPC
	camTweenTime = 0.45, -- ความลื่นตอนเปลี่ยนซูม (วิ)
}

-- ระบบเสียง (docs/02 §9.9) — ความดังปรับที่ Sound object ใน Studio ไม่ใช่ที่นี่
Config.Audio = {
	bgmFade = 1.2,            -- วินาที crossfade ตอนเปลี่ยนเพลง/บรรยากาศ
	defaultBGM = "",          -- เพลงตอนไม่อยู่ในโซนไหน ("" = เงียบ)
	zoneCheckInterval = 0.35, -- เช็คว่าอยู่โซนไหนทุกกี่วินาที
	voiceMinGap = 0.045,      -- blip ตอนพิมพ์ห่างกันอย่างน้อยกี่วิ (กันถี่จนหูแตก)
	voicePitchVary = 0.12,    -- สุ่ม pitch ±เท่าไหร่ ให้เสียงพูดไม่ซ้ำเป๊ะ
	-- เสียงเดิน = footstep script แบบ material-based (ServerScriptService) ไม่ผ่าน AudioService แล้ว
}

-- Comment ต่อคลิป (PDF หน้า 8 — user lock 21 ก.ค.): slot ⊖/◎/⊕ อย่างละใบ ทอยแยกอิสระตามเกรดคลิป
-- แต้มไม่รวม 100 จงใจ — แต่ละช่องคือโอกาสของ slot ตัวเอง ไม่ออก = เงียบ (สูงสุด 3 ใบ/คลิป)
Config.Comments = {
	chanceByTier = {
		C = { neg = 0.40, neu = 0.25, pos = 0.10 },
		B = { neg = 0.40, neu = 0.36, pos = 0.40 },
		A = { neg = 0.20, neu = 0.30, pos = 0.40 },
		S = { neg = 0.05, neu = 0.40, pos = 0.50 },
	},
	-- การนับ % เข้า ending (agent เสนอ — ยังไม่ lock): heart⊕/ยอมรับ→pos, ประชด→neu, heart⊖/ด่า→neg, ปล่อยผ่าน→ไม่นับ
	countAs = {
		heartPos = "pos", heartNeg = "neg",
		accept = "pos", sarcasm = "neu", insult = "neg",
	},
}

-- เงินตั้งต้น + เวลา — ที่มา: PDF ต้นฉบับหน้า 9, 6 (design doc ไม่ระบุ — flag ไว้แล้วใน docs/08)
Config.StartMoney = 2_500

Config.Time = {
	secondsPerGameHour = 7.5, -- 1 วันเกม = 3 นาทีจริง ÷ 24
	dayStartHour = 8,
	sleep = { normalHours = 8, windowStart = 18, windowEnd = 6, outsideHours = 12 },
}

return Config
