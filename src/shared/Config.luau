--!strict
-- Config.luau — ตัวเลข canon ทั้งหมด ถอดมาจาก docs/02-game-design-locked.md
-- กฎ: ห้าม hardcode ตัวเลข balance ที่อื่น · design doc เปลี่ยน → แก้ที่นี่ที่เดียว → เทสต้องยังผ่าน
-- ไฟล์นี้ขัดกับ design doc = design doc ถูก แก้ไฟล์นี้ตาม

local Config = {}

-- allowlist คนใช้ /dev นอก Studio (Studio เปิดให้ทุกคนเสมอ) — ไม่ใช่ balance number
Config.DevUserIds = { 3010077941, 183036806, 632366901 }

-- §1 Phase gate — ตัดจาก follower ปัจจุบันเท่านั้น ไม่ผูกจำนวนคลิป
Config.PhaseGates = {
	{ phase = 1, min = 0, max = 10_000 },
	{ phase = 2, min = 10_000, max = 100_000 },
	{ phase = 3, min = 100_000, max = 1_000_000 },
}

-- แอปบนจอคอมที่ต้องรอเฟส · ไม่มีชื่อในนี้ = เข้าได้ตั้งแต่เฟส 1 (Formulas.appUnlocked)
Config.AppMinPhase = { bank = 2, message = 2 }

-- Canon event: ยิง dialogue จาก Content.CanonEvents["milestone_"..เลข] + drain mod ×1.25 24 ชม.
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
Config.FaasaiJoinFollower = 30_000 -- faasai เข้าร่วม (StoryBeat เคาะประตู) — เฟส 2
Config.FaasaiParkFollower = 60_000 -- เดทที่สวน เฟส 2 · ปรับได้อิสระ (ไม่ล็อกใน docs)
-- BCA คิวต่อท้ายทันทีหลัง 1M (ไม่ใช้ตัวเลข milestone เพราะเวลาหยุดที่ 1M พอดี)
Config.BCAEventId = "bca"
Config.BCAAfterMilestone = 1_000_000
Config.TrueEnding = {
	suitShirtId = "", -- ⏳ รอ user ให้ rbxassetid
	suitPantsId = "", -- ⏳ รอ user ให้ rbxassetid
	walkTarget = "BCA_PodiumMark", -- Part ใน Workspace ที่ต้องเดินไปถึง (ทีมวางในแมพ)
	walkTimeout = 30, -- กันค้างถ้าเดินหลงทาง
}

-- §2 Follower ต่อคลิป = base(สุ่ม) × VidQ × mental, มีโอกาส viral
-- ★ ปรับ 12 ส.ค. 2569 (user, pacing pass): เดิม 400-900/1,400-2,600/9,000-15,000 → หารครึ่งทุกเฟส
--   เหตุผล: เพดานเงิน/phase gate ผูกกับ follower สะสมต่อเฟส (คงที่) ไม่ใช่จำนวนคลิป (§1, บทเรียนท้ายเอกสาร)
--   → ลด base ต่อคลิปครึ่งหนึ่ง = clip ต่อรอบเกมเพิ่มเป็น ~2 เท่า (~78→~156 คลิปทั้งเกม)
--   ยาวขึ้นจาก ~34 นาที (ของเดิม) → ~67 นาที ทั้งเกม โดย**ไม่แตะเพดานเงิน 1.47M เลย**
--   (เพดานเงิน = Σ follower ต่อเฟส(คงที่จาก PhaseGates) × rate(คงที่) — ไม่ขึ้นกับ FollowerBase)
Config.FollowerBase = {
	[1] = { min = 200, max = 450 },
	[2] = { min = 700, max = 1_300 },
	[3] = { min = 4_500, max = 7_500 },
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
	-- cap โบนัสที่ 1.25 จงใจ — ห้าม stack กับ viral(×4–8) + S(×2) จน pacing พัง
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
		commentHeartPos = 10, -- กดใจ comment ⊕
		commentHeartNeg = -10, -- กดใจ comment ⊖
		commentAccept = 10, -- ยอมรับปัญหา (⊖/◎)
		commentSarcasm = -5, -- ประชด (⊖/◎)
		commentInsult = -10, -- ด่า (⊖ เท่านั้น)
		viralClip = 25,
		activityExercise = 30,
		activityRest = 40,
		activityEat = 20,
	},
	-- ทำ activity ติดกันเกิน maxStreak → cooldown ข้ามวัน
	activity = { maxStreak = 3, cooldownDays = 1 },

	-- ฉากสั้นตอนทำ activity · ว่าง = ได้ผลใจทันทีไม่มีฉากคั่น
	-- ใส่ steps เมื่อไหร่ = เล่นฉากทันที ไม่ต้องแก้โค้ด (ActivityCutscene อ่านตารางนี้ · รูปแบบ step = CutscenePlayer)
	activityCutscenes = {
		Bed = {},
		Kitchen = {},
		-- ★ เพิ่ม 12 ส.ค. (user) — anim จริง ReplicatedStorage.Animations.player.PushUp
		--   (id 131382246842697 ยืนยันโหลดผ่านจริงแล้ว Length=0.3 — ต้อง grant permission แท็บ
		--   Experiences ก่อนถึงเล่นได้ ดู docs/17) ไม่มี camera step = กล้องอยู่มุมเดิม (ยังไม่มี Part เฉพาะ)
		--   คลิปสั้น (0.3วิ ท่าเดียว) ตั้ง loop=true ให้ดูต่อเนื่องตลอด 6 วิ — CutscenePlayer หยุด track ให้เองตอนจบฉาก
		Exercise = {
			{ type = "anim", actor = "player", name = "PushUp", loop = true },
			{ type = "text", text = "วิดพื้นสักหน่อย ผ่อนคลายๆ..." },
			{ type = "wait", t = 6 },
		},
	},

	-- kind: "drain" = คูณอัตรา drain | "recover" = คูณ delta ฝั่งบวก
	-- อายุ: hours = หมดตามชั่วโมงเกม | untilEvent = "sleep"|"activity"|"activityOrGood"
	mods = {
		NoSleep = { mult = 1.5, kind = "drain", untilEvent = "sleep" },
		CanonEvent = { mult = 1.25, kind = "drain", hours = 24 },
		EditStreak5 = { mult = 1.5, kind = "drain", untilEvent = "activity", streak = 5 },
		CommentBadStreak3 = { mult = 2, kind = "drain", untilEvent = "activityOrGood", streak = 3 },
		CommentGoodStreak3 = { mult = 1.25, kind = "recover", hours = 24, streak = 3 },
		ViralStreak2 = { mult = 2, kind = "recover", hours = 36 },
	},
	modCap = 3, -- คูณซ้อนกันได้ไม่เกิน ×3 ทั้งสองฝั่ง
	awakeHoursForNoSleep = 20,
}

-- §4 Economy
Config.MoneyRatePerFollower = { [1] = 0.8, [2] = 1.2, [3] = 1.5 }

-- ค่าใช้จ่ายรอบ 7 วัน ไม่นับจำนวนคลิป · เฟส 1 ไม่มีค่าเช่า (Homeless)
Config.WeeklyExpenses = {
	[1] = { rent = 0, internet = 300, food = 400 }, -- รวม 700
	[2] = { rent = 3_000, internet = 500, food = 600 }, -- รวม 4,100
	[3] = { rent = 6_000, internet = 800, food = 900 }, -- รวม 7,700
}

-- ระบบพนักงาน — คลิป auto: ไม่กิน footage, ไม่มี viral, ไม่คูณ mental, นับ VidQ% ครึ่งเดียว
Config.Staff = {
	clipsPerDayPerSpeed = 20, -- คลิป/วัน = speed / 20
	hireCap = 4,              -- จ้างพร้อมกันได้ 4 (companion ไม่นับ)
	vidqWeight = 0.5,         -- คลิปพนักงานนับเข้า VidQ% ครึ่งเดียว (กัน ending ถูกทีมกลบ)

	-- quality → โอกาสได้ tier (สุ่มทุกคลิป)
	tierChanceByQuality = {
		{ maxQuality = 40, C = 0.60, B = 0.30, A = 0.10, S = 0.00 },
		{ maxQuality = 70, C = 0.20, B = 0.45, A = 0.30, S = 0.05 },
		{ maxQuality = 90, C = 0.05, B = 0.25, A = 0.45, S = 0.25 },
		{ maxQuality = math.huge, C = 0.00, B = 0.10, A = 0.40, S = 0.50 },
	},

	-- roster จ้าง: ปลดต้องครบทั้ง phase และ follower
	-- trade-off: speed = ปริมาณคลิป (โต follower) · quality = เกรด tier (ปกป้อง VidQ%/ending)
	-- flag = ปลดต่อเมื่อ state.flags[flag] ติด · leavesOnSplit = ลาออกตอน event ตีกัน
	-- model = โมเดลใน Workspace.NPC.HirableNPC ให้ Manage app render (หาไม่เจอ = โชว์ emoji แทน)
	roster = {
		{ id = "hire_editor",    phase = 2, follower = 15_000,  speed = 32, quality = 30, salary = 9_000,  leavesOnSplit = true, model = "NPC_พนักงาน001" }, -- สายเร็ว
		{ id = "hire_artisan",   phase = 2, follower = 30_000,  speed = 15, quality = 65, salary = 11_000, model = "NPC_พนักงาน002" }, -- สายคุณภาพ
		{ id = "hire_allround2", phase = 2, follower = 60_000,  speed = 22, quality = 45, salary = 10_000, model = "NPC_พนักงาน003" }, -- all-rounder
		{ id = "hire_pro",       phase = 3, follower = 150_000, speed = 45, quality = 70, salary = 32_000, leavesOnSplit = true, model = "NPC_พนักงาน004" }, -- โปรตามเงิน
		{ id = "hire_volume",    phase = 3, follower = 250_000, speed = 70, quality = 50, salary = 42_000, leavesOnSplit = true, model = "NPC_พนักงาน005" }, -- mercenary
		{ id = "hire_master",    phase = 3, follower = 450_000, speed = 35, quality = 90, salary = 46_000, model = "NPC_พนักงาน006" }, -- สายคราฟต์
		-- ทีมล้างแค้น: ปลดเมื่อ faasai ทรยศ (flags.betrayed ที่ 500K)
		{ id = "hire_fierce1",   phase = 3, follower = 500_000, speed = 60, quality = 78, salary = 55_000, flag = "betrayed", model = "NPC_พนักงาน007" },
		{ id = "hire_fierce2",   phase = 3, follower = 500_000, speed = 55, quality = 85, salary = 58_000, flag = "betrayed", model = "NPC_พนักงาน008" },
	},

	-- worldNPC ผู้ภักดี: auto-hire ตอน split (จ้างเองไม่ได้) การันตีมีคนเหลือเสมอ
	loyalAfterSplit = { id = "hire_loyal", speed = 30, quality = 60, salary = 18_000 },

	-- เพื่อนร่วมทาง: auto ตามเนื้อเรื่อง ฟรี ไล่ไม่ได้ ไม่นับ cap
	companions = {
		{ id = "companion_1", joinFollower = 10_000, speed = 20, quality = 30,
			growAtPhase = 3, grownSpeed = 45, grownQuality = 75, leavesOnBetrayal = true },
		{ id = "companion_2", joinFollower = 100_000, speed = 40, quality = 85 },
	},
}

-- Bank ⊖⊕: ยอดจ่ายจริง/สัปดาห์ = WeeklyExpenses base + offset×step · ผลใจคิดตอนตัดรอบ
-- เหลือ ⊖⊕ เฉพาะค่าอาหาร · ค่าเช่า fixed (min=max=0) · Bad End ① = เงินไม่พอ 2 รอบ (MoneyService.onDay)
Config.Spending = {
	food = { step = 200, minOffset = -1, maxOffset = 3, mentalUp = 2, mentalDown = -4 },
	rent = { step = 500, minOffset = 0, maxOffset = 0, mentalUp = 1, mentalDown = -3 },
}

-- อุปกรณ์ 6 ระดับ · ราคา costs[ระดับปัจจุบัน] = ราคาขึ้นระดับถัดไป (5 ขั้น)
-- 💰 เพดานเงินทั้งเกม ≈ 1.47M หักรายจ่ายเหลือ ~1.3M · upgrade 2 สายรวม 842,500
--    เหลือส่วนเกิน ~460K ไม่มีอะไรซื้อต่อ = balance hole ที่ยังไม่ปิด (ไม่ใช่ blocker)
Config.UpgradeCosts = {
	camera = { 2_000, 8_000, 30_000, 120_000, 300_000 },
	storage = { 1_500, 6_000, 25_000, 100_000, 250_000 },
}

-- 480p→4320p (6 ระดับ ตรงกับ Shop)
Config.ResolutionLadder = { "480p", "720p", "1080p", "1440p", "2160p", "4320p" }

-- 128GB→8TB (6 ระดับ)
Config.StorageLadderGB = { 128, 256, 512, 1024, 4096, 8192 }

-- โมเดลใน ToolModels มีถึง Camera_6 = ครบทุกระดับ · เกินจำนวนโมเดล = ToolService ใช้ตัวท้ายสุดแทน
Config.CameraModelCount = 6

-- ระดับ 6 = Tool "Camera_6" ทำหน้าที่รีโมทเรียกรถเข็นกล้อง (กล้องอยู่กับ player ตลอด กดตอนยืน = เสกรถใหม่)
Config.CameraCartLevel = 6
Config.CameraCartToolSource = "Camera_6" -- Tool ที่เรียกรถ (RecordTool ข้าม CameraCart คุมเอง)
Config.CameraCartTemplate = "CameraCart" -- ชื่อ Model ต้นฉบับใน ToolModels
Config.CameraCartSpawnStuds = 12 -- เสกห่างหน้าผู้เล่นกี่ studs

-- ⚠️ ต้องตรงกับ SPRINT_SPEED ใน studio-only/SprintHandler (Rojo ไม่ sync require ข้ามไม่ได้ — แก้ 2 ที่)
Config.PlayerSprintSpeed = 50 -- เดินปกติ 16 · Shift วิ่ง 50
Config.CameraCartSpeed = Config.PlayerSprintSpeed * 1.5 -- รถเร็วกว่าวิ่ง 1.5 เท่า = 75
Config.CameraCartTurnRate = 3 -- เรเดียน/วินาที (รัศมีวงเลี้ยว ≈ speed/turnRate = 25 studs)

-- ร้านค้าในแมพ (Interact_Shop) — คนละตัวกับแอป Shop บนคอม
-- names[N] = ของที่ได้ตอนอยู่ระดับ N แล้วกดซื้อ (→ N+1) · ชิ้นสุดท้าย = ระดับ 6
-- ราคามาจาก UpgradeCosts, สเปคคำนวณจาก ladder (ShopKiosk.specFor)
Config.ShopCatalog = {
	{ key = "storage", label = "💾 ที่เก็บข้อมูล", icon = "💾", note = "เก็บ footage ได้มากขึ้น", startName = "SSD พกพา",
		names = {
			"SSD NVMe เกรดเกมเมอร์", 'External HDD 2.5"', "HDD ตั้งโต๊ะ", "NAS 2 เบย์", "NAS 4 เบย์ RAID",
		} },
	{ key = "camera", label = "📷 อุปกรณ์ถ่ายรูป", icon = "📷", note = "อัด footage ไวขึ้นต่อคลิก", startName = "มือถือเครื่องเก่า",
		names = {
			"มือถือใหม่", "กล้อง compact", "กล้อง mirrorless", "กล้อง DSLR โปร", "กล้อง cinema",
		} },
}

-- ระบบอัดคลิป · สูตรต่อคลิก: GB = footagePerClickGB[กล้อง] × (bonus? bonusMult) × (ในโซน? zoneMult)
Config.Record = {
	-- GB ต่อคลิก ตามระดับกล้อง — เต็ม storage ระดับเดียวกัน ~128 คลิก (L6 ~256 บังคับพึ่งโซน/พนักงาน)
	footagePerClickGB = { 1, 2, 4, 8, 16, 32 },
	clickCooldownSeconds = 0.6, -- กันสแปมแบบ simulator
	bonusChance = 0.1,          -- proc "+Bonus!" เกิดได้ทุกที่ ซ้อนกับโซนได้
	bonusMult = 2.4,
	zoneMultByPhase = { [1] = 1.5, [2] = 2, [3] = 2.5 }, -- อัดในโซน × ตัวคูณตามเฟส
	zoneDurationSeconds = 120,  -- โซนอยู่ 2 นาทีจริง แล้วสุ่มย้าย (กัน AFK)
	footagePerClipGB = 32,      -- ตัด 1 คลิป default = baseline ×1.0 ของ ClipSizes (denominator ของ sizeMult)
	zoneRadiusStuds = 18,
}

-- RecordQTE — skill check ตอนถ่ายคลิป: เข็มวิ่ง ping-pong บนแถบ กด Space N ครั้ง (สุ่ม hitsMin-hitsMax)
--   กด 1 ครั้ง = เกรดจากตำแหน่งเข็มตอนนั้น · เล่นจนครบ N เสมอ ไม่มี fail-fast
--   reward สะสม เพดานรวม rewardMultMax ไม่ว่า N: Perfect/ครั้ง = max/N, Good = ×goodRewardRatio
--   reward เป็น footage (cap ด้วย storage) · ระหว่าง QTE freeze เดิน+ปิด E · geometry เป็นสัดส่วน 0..1
Config.RecordQTE = {
	chance = 0.1,            -- โอกาสเจอ QTE ต่อคลิกถ่ายสำเร็จ
	hitsMin = 1, hitsMax = 5, -- จำนวนครั้งที่ต้องกด (สุ่มต่อ QTE)
	rewardMultMax = 10,      -- เพดานรวมทั้ง QTE
	goodRewardRatio = 0.5,   -- Good/ครั้ง = ครึ่งของ Perfect/ครั้ง
	sweepSecondsStart = 1.2, -- ความเร็วเข็มก่อนกดครั้งแรก (ช้าสุด วิ/เที่ยว)
	sweepSecondsMin = 0.5,   -- พื้นความเร็ว (เร่งไม่เกินนี้)
	timeoutSeconds = 15,     -- ไม่กดเลยเกินนี้ = auto-จบ กัน InteractLock ค้าง
	sweepSpeedupPerHit = 0.15, -- ลด sweepSeconds ต่อครั้งที่กดสำเร็จ
	centerMin = 0.30, centerMax = 0.80, -- กึ่งกลางโซนสำเร็จ สุ่มครั้งเดียวตอนเริ่ม
	goodHalfWidth = 0.11,      -- |pos-center| ≤ นี่ = อย่างน้อย Good
	perfectHalfWidth = 0.035,  -- ≤ นี่ = Perfect
}

-- ของกินใช้แล้วหมด · ซื้อ = ดื่มทันที ไม่มีคลังของ
-- ⚠️ จงใจไม่เพิ่มโอกาสเกิด QTE (QTE = lockout) — ให้ผลเป็น "โซน QTE กว้างขึ้น" แทน
Config.Consumables = {
	{
		key = "energy",
		label = "🥤 เครื่องดื่มชูกำลัง",
		icon = "🥤",
		price = 12_000,          -- money sink เฟส 2+ (เฟส 1 ได้ ~8,000 = ซื้อไม่ไหว)
		durationHours = 24,
		mentalOnExpire = -8,     -- crash ตอนหมดฤทธิ์ — ทางลัดต้องมีต้นทุน
		-- good ×1.5 ไม่ใช่ ×2 จงใจ: center สุ่มถึง 0.80 ถ้า good กว้างไป (0.22) จะชนขอบขวาได้ Good ฟรี
		qtePerfectMult = 2.0,
		qteGoodMult = 1.5,
		desc = "โซน QTE กว้างขึ้น 1 วัน · หมดฤทธิ์ใจ −8",
	},
}

-- ClipSizes — เลือกขนาด footage ก่อนตัด (risk↔reward): ขนาด↑ = QTE ยากขึ้น แลก reward ×(gb/32)
--   rewardMult คำนวณที่ Formulas.clipSizeMult · เลือกได้เฉพาะขนาดที่ footage ปัจจุบัน ≥ gb
Config.ClipSizes = {
	{ gb = 8,   hits = 10, maxOnScreen = 1, spawnInterval = 0.55, approach = 1.70 },
	{ gb = 16,  hits = 14, maxOnScreen = 2, spawnInterval = 0.48, approach = 1.55 },
	{ gb = 32,  hits = 20, maxOnScreen = 2, spawnInterval = 0.40, approach = 1.40 }, -- baseline ×1.0
	{ gb = 64,  hits = 28, maxOnScreen = 3, spawnInterval = 0.34, approach = 1.20 },
	{ gb = 128, hits = 40, maxOnScreen = 4, spawnInterval = 0.28, approach = 1.05 },
}

Config.SponsorUnlockFollowers = 10_000
Config.SponsorOfferChance = 0.05 -- offer เด้งเอง 5%/วัน (เฟส 2-3)
Config.SponsorOfferMinPhase = 2
-- กดรับ = buff เงินคลิป ×Mult ทันที · offer ที่ไม่กดหมดอายุตอนขึ้นวันใหม่ (มีแค่ toast พลาดแล้วพลาดเลย)
Config.SponsorBuffMult = 2 -- เงินจากคลิประหว่าง buff ×เท่านี้ (follower ไม่คูณ)
Config.SponsorBuffDays = 1

-- เงินก้อน sponsor ตาม milestone (ก้อนเดียว ครั้งเดียวต่อ payoutId) · key ต้องตรง payoutId ใน DMs.luau
--   อิงสูตร "คลิปเฉลี่ยของเฟส × 2–4" · รวม 147,000 → ดัน balance hole เป็น ~607K (จูนที่ตารางนี้)
Config.DMPayouts = {
	sponsor_shabu  = 5_000,  -- ร้านชาบูป้านิด (14K, เฟส 2)
	sponsor_gadget = 12_000, -- GadgetTH (50K, เฟส 2)
	sponsor_agency = 40_000, -- VIRALHOUSE (120K, เฟส 3)
	sponsor_chill  = 90_000, -- CHILL (400K, เฟส 3)
}

-- §5 Ending resolver — เช็คแย่สุด→ดีสุด return ทันทีที่ match · ห้ามสลับลำดับ (เงื่อนไข overlap)
Config.EndingPriority = { "Bad1", "Bad2", "Bad3", "Good1", "Neutral1", "Neutral2" }

-- VidQ % = สัดส่วนคลิปที่ถ่ายทั้งหมด · Choice % = สัดส่วน choice ที่ตอบ (comment เท่านั้นที่นับ)
Config.EndingThresholds = {
	Bad3 = { vidq = { cMin = 33, bMax = 33 }, choice = { negMin = 50, neuMax = 25 } },
	Neutral1 = { vidq = { cMax = 20, bMax = 33, aMin = 13, sMax = 13 }, choice = { spreadMax = 25 } },
	Neutral2 = { vidq = { cMax = 26, bMax = 33 }, choice = { negMax = 37.5, neuMin = 25 } },
	Good1 = {
		vidq = { cMax = 16, bMax = 33, aMin = 30, sMax = 20 },
		choice = { posMin = 62.5, negMax = 12.5, neuMax = 12.5 },
	},
}
-- Bad1 = เงินหมดโดนไล่ 2 รอบ | Bad2 = mental ≤ 0 (ทั้งคู่ optional) · Neutral/Good ต้องถึง 1M ก่อน

-- Dialogue: typewriter + กล้องตอนคุย NPC · กล่องขนาดคงที่เป็น px ข้อความยาว = ตัดบรรทัดใหม่
Config.Dialogue = {
	charDelay = { normal = 0.03, slow = 0.08, fast = 0.012 }, -- วิ/ตัวอักษร (น้อย = เร็ว)
	box = {
		width = 900,     -- กว้างกล่อง (px)
		height = 176,    -- สูงกล่อง (px) — พอดี 3 บรรทัดที่ textSize 30
		bottomGap = 30,  -- ห่างจากขอบล่างจอ
		textSize = 30,
		padding = 20,
		portrait = 132,  -- ช่อง viewport หน้าตัวละครฝั่งซ้าย · ไม่มี rig = ซ่อน
		border = 3,      -- ความหนาขอบขาว (Frame ทึบวางนอกกล่อง — ดู DialogueUI.show)
		bgColor = Color3.fromRGB(28, 27, 34),     -- พื้นกล่อง (เทาเข้มอมม่วง)
		textColor = Color3.fromRGB(236, 233, 240),   -- ตัวอักษร (ขาวหม่น)
	},
	zoomLevels = { 6, 10, 16 }, -- ระยะกล้อง ใกล้/ปกติ/ไกล (studs)
	zoomDefault = 2, -- index ใน zoomLevels
	camHeight = 1.5, -- ความสูงกล้องเหนือหัว NPC
	camTweenTime = 0.45,
}

-- ระบบเสียง — ความดังปรับที่ Sound object ใน Studio ไม่ใช่ที่นี่
Config.Audio = {
	bgmFade = 1.2,            -- วินาที crossfade ตอนเปลี่ยนเพลง
	defaultBGM = "",          -- เพลงตอนไม่อยู่โซนไหน ("" = เงียบ)
	zoneCheckInterval = 0.35,
	voiceMinGap = 0.045,      -- blip ตอนพิมพ์ห่างกันอย่างน้อยกี่วิ
	voicePitchVary = 0.12,    -- สุ่ม pitch ±เท่าไหร่ ให้เสียงไม่ซ้ำเป๊ะ
}

-- Comment ต่อคลิป: slot ⊖/◎/⊕ อย่างละใบ ทอยแยกอิสระตามเกรด · แต้มไม่รวม 100 จงใจ (สูงสุด 3 ใบ/คลิป)
Config.Comments = {
	chanceByTier = {
		C = { neg = 0.40, neu = 0.25, pos = 0.10 },
		B = { neg = 0.40, neu = 0.36, pos = 0.40 },
		A = { neg = 0.20, neu = 0.30, pos = 0.40 },
		S = { neg = 0.05, neu = 0.40, pos = 0.50 },
	},
	-- heart⊕/ยอมรับ→pos, ประชด→neu, heart⊖/ด่า→neg, ปล่อยผ่าน→ไม่นับ
	countAs = {
		heartPos = "pos", heartNeg = "neg",
		accept = "pos", sarcasm = "neu", insult = "neg",
	},
}

Config.StartMoney = 2_500

Config.Time = {
	secondsPerGameHour = 7.5, -- 1 วันเกม = 3 นาทีจริง ÷ 24
	dayStartHour = 8,
	sleep = { normalHours = 8, windowStart = 18, windowEnd = 6, outsideHours = 12 },
}

return Config
