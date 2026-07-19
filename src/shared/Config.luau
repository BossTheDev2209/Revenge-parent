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
Config.StoryMilestones = { 1_000, 10_000, 100_000, 1_000_000 }

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
		commentChoiceBad = -5,
		rentMissed = -15,
		npcChoiceGood = 15,
		commentChoiceGood = 10,
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

Config.UpgradeCosts = {
	camera = { 2_000, 8_000, 30_000, 120_000 },
	storage = { 1_500, 6_000, 25_000, 100_000 },
}
Config.ResolutionLadder = { "720p", "1080p", "1440p", "2160p", "4320p" }

Config.SponsorUnlockFollowers = 10_000

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

-- Comment ต่อคลิป (PDF หน้า 8)
Config.CommentsPerClip = 3

-- เงินตั้งต้น + เวลา — ที่มา: PDF ต้นฉบับหน้า 9, 6 (design doc ไม่ระบุ — flag ไว้แล้วใน docs/08)
Config.StartMoney = 2_500

Config.Time = {
	secondsPerGameHour = 7.5, -- 1 วันเกม = 3 นาทีจริง ÷ 24
	dayStartHour = 8,
	sleep = { normalHours = 8, windowStart = 18, windowEnd = 6, outsideHours = 12 },
}

return Config
