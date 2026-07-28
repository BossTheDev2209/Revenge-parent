--!strict
-- Config.luau — ตัวเลข canon ทั้งหมด ถอดมาจาก docs/02-game-design-locked.md
--
-- กฎ: ห้าม hardcode ตัวเลข balance ที่อื่น อ่านจากไฟล์นี้เท่านั้น
-- ถ้า design doc เปลี่ยน → แก้ที่นี่ที่เดียว → test ใน tests/ ต้องยังผ่าน
-- ถ้าไฟล์นี้ขัดกับ design doc → design doc ถูก แก้ไฟล์นี้ตาม อย่าแก้ doc ตามโค้ด

local Config = {}

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
		activityExercise = 20,
		activityRest = 25,
		activityEat = 15,
	},
	-- Activity system (PDF หน้า 6): ทำติดกันเกิน maxStreak → cooldown ข้ามวัน
	activity = { maxStreak = 3, cooldownDays = 1 },

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
	roster = {
		{ id = "hire_1", phase = 2, follower = 15_000, speed = 20, quality = 35, salary = 8_000 },
		{ id = "hire_2", phase = 2, follower = 40_000, speed = 35, quality = 45, salary = 15_000 },
		{ id = "hire_3", phase = 3, follower = 150_000, speed = 50, quality = 60, salary = 30_000 },
		{ id = "hire_4", phase = 3, follower = 450_000, speed = 70, quality = 80, salary = 60_000 },
	},

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

Config.UpgradeCosts = {
	camera = { 2_000, 8_000, 30_000, 120_000, 300_000 },
	storage = { 1_500, 6_000, 25_000, 100_000, 250_000 },
	-- ⚠️ pc = สายใหม่ ยังไม่มีใน docs/02 — ราคา agent เลือก **รอ user lock**
	-- ผลของมัน (ตัดต่อไวขึ้น = อะไร) ยัง unwired จงใจ: ซื้อได้/เก็บระดับได้ แต่ยังไม่มีผลกับเกม
	pc = { 5_000, 20_000 },
}
Config.ResolutionLadder = { "480p", "720p", "1080p", "1440p", "2160p", "4320p" }
Config.StorageLadderGB = { 128, 256, 512, 1024, 4096, 8192 } -- 128GB → 8TB

-- ร้านค้าในแมพ (Part `Interact_Shop`) — คนละตัวกับแอป Shop บนจอคอม (PDF หน้า 9)
-- ⚠️ เวอร์ชันเทส: หมวดละ 2 ชิ้น — เพิ่มของ = เติมชื่อใน names + ราคาใน UpgradeCosts ให้ยาวเท่ากัน
-- ห้ามใส่ราคา/สเปคซ้ำที่นี่ — ราคามาจาก UpgradeCosts, สเปคคำนวณจาก ladder (ShopKiosk.specFor)
Config.ShopCatalog = {
	{ key = "pc", label = "💻 คอมพิวเตอร์", note = "ตัดต่อไวขึ้น",
		names = { "คอมประกอบมือสอง", "คอมสเปคตัดต่อ" } },
	{ key = "storage", label = "💾 ที่เก็บข้อมูล", note = "เก็บ footage ได้มากขึ้น",
		names = { "SSD NVMe เกรดเกมเมอร์", 'External HDD 2.5"' } },
	{ key = "camera", label = "📷 อุปกรณ์ถ่ายรูป", note = "อัด footage ไวขึ้นต่อคลิก",
		names = { "มือถือใหม่", "กล้อง compact" } },
}

-- ระบบอัดคลิป (user lock 21 ก.ค. + เลขต่อคลิกเลือกโดย agent — docs/02 §9.5)
-- สูตรต่อคลิก: GB = footagePerClickGB[กล้อง] × (bonus? bonusMult : 1) × (ในโซน? zoneMult : 1)
Config.Record = {
	-- GB ต่อคลิก ตามระดับกล้อง — เต็ม storage ระดับเดียวกัน ~128 คลิก (L5-6 ~256 จงใจ บังคับพึ่งโซน/พนักงาน)
	footagePerClickGB = { 1, 2, 4, 8, 16, 32 },
	clickCooldownSeconds = 0.6, -- กันสแปมแบบ simulator (user feedback 21 ก.ค.)
	-- Bonus proc (PDF หน้า 7 "+2.4 Bonus!") — เกิดได้ทุกที่ ซ้อนกับโซนได้
	bonusChance = 0.1,
	bonusMult = 2.4,
	-- โซนถ่าย (จุดแดง PDF หน้า 4): อัดนอกโซนได้ base rate, ในโซน × ตัวคูณตามเฟส
	zoneMultByPhase = { [1] = 1.5, [2] = 2, [3] = 2.5 },
	zoneDurationSeconds = 120, -- โซนอยู่ 2 นาทีจริง แล้วสุ่มย้ายจุด (กัน AFK)
	-- ตัด 1 คลิปกิน footage เท่านี้ (lock 27 ก.ค.) — คงที่ ไม่ผูก VidQ เพราะ VidQ รู้หลังตัดจบ
	-- กล้อง L1: 32 คลิก/คลิป, storage L1 เก็บได้ 4 คลิป | กล้อง L6: 1 คลิก/คลิป = เหตุผลที่ต้องอัปกล้อง
	footagePerClipGB = 32,
	zoneRadiusStuds = 18, -- รัศมีวงโซน (agent เลือก — ปรับได้ ไม่มีใน PDF)
}

Config.SponsorUnlockFollowers = 10_000
Config.SponsorOfferChance = 0.05 -- PDF หน้า 6: offer เด้งเอง 5%/วัน (เฟส 2-3) ไม่ใช่ปุ่มกดเรียก
Config.SponsorOfferMinPhase = 2

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

-- Dialogue typewriter (design doc §7) — วิ/ตัวอักษร (เลขเลือกเอง ปรับได้)
Config.Dialogue = { charDelay = { normal = 0.03, slow = 0.08, fast = 0.012 } }

-- ระบบเสียง (docs/02 §9.9) — ความดังปรับที่ Sound object ใน Studio ไม่ใช่ที่นี่
Config.Audio = {
	bgmFade = 1.2,            -- วินาที crossfade ตอนเปลี่ยนเพลง/บรรยากาศ
	defaultBGM = "",          -- เพลงตอนไม่อยู่ในโซนไหน ("" = เงียบ)
	zoneCheckInterval = 0.35, -- เช็คว่าอยู่โซนไหนทุกกี่วินาที
	voiceMinGap = 0.045,      -- blip ตอนพิมพ์ห่างกันอย่างน้อยกี่วิ (กันถี่จนหูแตก)
	voicePitchVary = 0.12,    -- สุ่ม pitch ±เท่าไหร่ ให้เสียงพูดไม่ซ้ำเป๊ะ
	footstepInterval = 0.42,  -- ระยะห่างก้าวเดิน (ปรับตามความเร็วอัตโนมัติ)
	footstepPitchVary = 0.08,
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
