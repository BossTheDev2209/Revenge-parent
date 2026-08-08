-- tests/RunTests.luau — เทสสมองคณิตทั้งเกม (Formulas.luau) เทียบกับ docs/02-game-design-locked.md
--
-- sync เป็น ModuleScript ที่ SSS.Tests.RunTests (gen_sync) แล้วรัน:
--   Studio: Play → execute_luau (Server) → require(SSS.Tests.RunTests) → อ่าน {pass,fail,failures}
--           (1 รอบ/1 play session — service เป็น singleton state ค้างข้ามรอบ)
--   local : lune run tests/RunTests.luau (ถ้ามี lune)
local isStudio = script ~= nil
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../src/shared/Formulas")

local GameState = if isStudio
	then require(game:GetService("ServerScriptService").Services.GameState)
	else require("../src/server/Services/GameState")

local ActionRouter = if isStudio
	then require(game:GetService("ServerScriptService").Services.ActionRouter)
	else require("../src/server/Services/ActionRouter")

local TimeService = if isStudio
	then require(game:GetService("ServerScriptService").Services.TimeService)
	else require("../src/server/Services/TimeService")

local MentalService = if isStudio
	then require(game:GetService("ServerScriptService").Services.MentalService)
	else require("../src/server/Services/MentalService")
local FollowerService = if isStudio
	then require(game:GetService("ServerScriptService").Services.FollowerService)
	else require("../src/server/Services/FollowerService")
local MoneyService = if isStudio
	then require(game:GetService("ServerScriptService").Services.MoneyService)
	else require("../src/server/Services/MoneyService")

local EditQTE = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.UI.Apps.EditQTE)
	else require("../src/client/UI/Apps/EditQTE")

local ShopKiosk = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.UI.Apps.ShopKiosk)
	else require("../src/client/UI/Apps/ShopKiosk")

local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../src/shared/Config")

local CommentService = if isStudio
	then require(game:GetService("ServerScriptService").Services.CommentService)
	else require("../src/server/Services/CommentService")
local CalendarService = if isStudio
	then require(game:GetService("ServerScriptService").Services.CalendarService)
	else require("../src/server/Services/CalendarService")
local EndingService = if isStudio
	then require(game:GetService("ServerScriptService").Services.EndingService)
	else require("../src/server/Services/EndingService")
local DialogueUI = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.UI.DialogueUI)
	else require("../src/client/UI/DialogueUI")
local CutscenePlayer = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.UI.CutscenePlayer)
	else require("../src/client/UI/CutscenePlayer")

local pass, fail = 0, 0
local failures = {}
local function check(name: string, ok: boolean)
	if ok then pass += 1 else fail += 1; failures[#failures + 1] = name; print("FAIL: " .. name) end
end

-- rng ปลอม: คืนค่าจากคิวตามลำดับ ไว้ fix ผลสุ่มให้เทสได้
local function rngQueue(vals)
	local i = 0
	return function() i += 1; return vals[i] end
end

-- ===== phaseFor (design doc §1 — gate ตัดจาก follower ปัจจุบันเท่านั้น) =====
check("phase 1 เริ่มต้น", Formulas.phaseFor(0) == 1)
check("phase 1 ขอบบน 9,999", Formulas.phaseFor(9_999) == 1)
check("phase 2 ที่ 10,000 พอดี", Formulas.phaseFor(10_000) == 2)
check("phase 2 ที่ 10,001", Formulas.phaseFor(10_001) == 2)
check("phase 2 ขอบบน 99,999", Formulas.phaseFor(99_999) == 2)
check("phase 3 ที่ 100,000 พอดี", Formulas.phaseFor(100_000) == 3)
check("phase 3 ค้างที่ 1M+", Formulas.phaseFor(1_500_000) == 3)

-- ===== vidqTier (design doc §2 — boundary ทุกช่วง) =====
check("tier C ล่างสุด 0", Formulas.vidqTier(0) == "C")
check("tier C ขอบบน 50", Formulas.vidqTier(50) == "C")
check("tier B ขอบล่าง 51", Formulas.vidqTier(51) == "B")
check("tier B ขอบบน 100", Formulas.vidqTier(100) == "B")
check("tier A ขอบล่าง 101", Formulas.vidqTier(101) == "A")
check("tier A ขอบบน 150", Formulas.vidqTier(150) == "A")
check("tier S ขอบล่าง 151", Formulas.vidqTier(151) == "S")
check("tier S เต็ม 200", Formulas.vidqTier(200) == "S")
check("clamp เกิน 200", Formulas.vidqTier(999) == "S")
check("clamp ติดลบ", Formulas.vidqTier(-5) == "C")

-- ===== vidqMultiplier (design doc §2) =====
check("mult C = 0.5", Formulas.vidqMultiplier("C") == 0.5)
check("mult B = 1.0", Formulas.vidqMultiplier("B") == 1.0)
check("mult A = 1.5", Formulas.vidqMultiplier("A") == 1.5)
check("mult S = 2.0", Formulas.vidqMultiplier("S") == 2.0)

-- ===== mentalMultiplier (design doc §3 — 3 โซน, boundary 0/1/39/40/69/70/100) =====
local rng0 = function() return 0 end
local rngHi = function() return 0.999 end
check("โซนสูง ขอบล่าง 70 rng=0 → 1.0", Formulas.mentalMultiplier(70, rng0) == 1.0)
check("โซนสูง 100 rng สูง → เข้าใกล้ 1.25", Formulas.mentalMultiplier(100, rngHi) > 1.24)
check("โซนสูง ไม่ทะลุ cap 1.25", Formulas.mentalMultiplier(100, rngHi) <= 1.25)
check("โซนกลาง ขอบล่าง 40 = 1.0 เสมอ", Formulas.mentalMultiplier(40, rngHi) == 1.0)
check("โซนกลาง ขอบบน 69 = 1.0 เสมอ", Formulas.mentalMultiplier(69, rng0) == 1.0)
check("โซนต่ำ ขอบล่าง 1 rng=0 → 0.6", Formulas.mentalMultiplier(1, rng0) == 0.6)
check("โซนต่ำ ขอบบน 39 ไม่เกิน 1.0", Formulas.mentalMultiplier(39, rngHi) <= 1.0)
check("mental 0 → 0 (Bad End 2 เป็นหน้าที่ service)", Formulas.mentalMultiplier(0, rng0) == 0)

-- ===== followerGain (design doc §2: base(สุ่ม) × VidQ × mental, viral 12% ×4–8) =====
-- ลำดับเรียก rng (implementation ต้องตรง): ① base ② mentalZone ③ viralChance ④ viralMult
local n, viral = Formulas.followerGain(1, "B", 50, rngQueue({ 0, 0, 0.5 }))
check("phase1 B mental กลาง ไม่ viral = base ต่ำสุด 400", n == 400 and viral == false)

n, viral = Formulas.followerGain(1, "S", 50, rngQueue({ 0, 0, 0.5 }))
check("tier S คูณ 2 → 800", n == 800 and viral == false)

n, viral = Formulas.followerGain(1, "B", 50, rngQueue({ 0, 0, 0.05, 0 }))
check("viral ติด (0.05 < 0.12) คูณต่ำสุด 4 → 1600", n == 1600 and viral == true)

n, viral = Formulas.followerGain(1, "B", 50, rngQueue({ 0.999, 0, 0.5 }))
check("base สุ่มบนสุด phase1 ≈ 900", n >= 898 and n <= 900)

n, viral = Formulas.followerGain(3, "B", 50, rngQueue({ 0, 0, 0.5 }))
check("phase3 base ต่ำสุด 9000", n == 9000)

-- ===== moneyGain (design doc §4: follower × rate เฟส) =====
check("rate phase1 0.8", Formulas.moneyGain(1000, 1) == 800)
check("rate phase2 1.2", Formulas.moneyGain(1000, 2) == 1200)
check("rate phase3 1.5", Formulas.moneyGain(1000, 3) == 1500)
check("ปัดเศษลง", Formulas.moneyGain(999, 1) == 799)

-- ===== resolveEnding (design doc §5 — หน่วย % ตาม Config.EndingThresholds) =====
-- priority: Bad3 → Good1 → Neutral1 → Neutral2 (Bad1 เงิน / Bad2 mental trigger สดกลางเกม ไม่ผ่านสูตรนี้)
local function stats(vC, vB, vA, vS, pos, neu, neg)
	return { vidq = { C = vC, B = vB, A = vA, S = vS }, choice = { pos = pos, neu = neu, neg = neg } }
end

check("Bad3 ทาง vidq (C ≥ 33%)",
	Formulas.resolveEnding(stats(40, 30, 20, 10, 50, 30, 20)) == "Bad3")
check("Bad3 ทาง choice (⊖ ≥ 50%)",
	Formulas.resolveEnding(stats(10, 20, 50, 20, 30, 10, 60)) == "Bad3")
check("Good1 (vidq ดี AND ⊕ ≥ 62.5%)",
	Formulas.resolveEnding(stats(10, 20, 50, 20, 80, 10, 10)) == "Good1")
check("Good1 ไม่ผ่านถ้า choice ไม่ถึง (AND)",
	Formulas.resolveEnding(stats(10, 20, 50, 20, 50, 10, 40)) ~= "Good1")
check("Neutral1 ทาง spread |⊖−⊕|+◎ < 25%",
	Formulas.resolveEnding(stats(25, 50, 15, 10, 47, 5, 48)) == "Neutral1")
check("Neutral2 (vidq C ≤ 26%)",
	Formulas.resolveEnding(stats(25, 30, 25, 20, 30, 30, 40)) == "Neutral2")
check("priority: เข้าทั้ง Bad3+Good1 ต้องได้ Bad3",
	Formulas.resolveEnding(stats(40, 20, 20, 20, 80, 10, 10)) == "Bad3")
check("ไม่เข้าอะไรเลย → fallback Neutral2",
	Formulas.resolveEnding(stats(30, 40, 20, 10, 30, 30, 40)) == "Neutral2")

-- ===== GameState.newGame (docs/06 §3 state shape) =====
local s = GameState.newGame()
check("เงินตั้งต้น 2500", s.money == 2500)
check("mental เริ่ม 80", s.mental == 80)
check("เริ่ม phase 1 วัน 1", s.phase == 1 and s.day == 1)
check("เริ่มเวลา 8 โมง", s.timeOfDay == 8)
check("follower 0", s.follower == 0)
check("choices ว่าง", s.choices.pos == 0 and s.choices.neu == 0 and s.choices.neg == 0)
check("upgrades เริ่ม level 1", s.upgrades.camera == 1 and s.upgrades.storage == 1)
check("slot default 1", s.slot == 1)
-- started=false ตอนบูต → autosave/BindToClose ไม่เขียน placeholder ทับเซฟจริงระหว่างอยู่เมนู (6 ส.ค.)
check("started=false ตอนเริ่ม (ยังไม่ commit เข้าเกม)", s.started == false)
check("mergeDefaults เติม started ให้เซฟเก่าที่ไม่มี field นี้",
	GameState.mergeDefaults({ money = 1 }, GameState.newGame()).started == false)
check("ตาราง clips/calendar/flags ว่าง", #s.clips == 0 and next(s.calendar) == nil and next(s.flags) == nil)

-- ===== GameState.mergeDefaults (save เก่า + key ใหม่ = ไม่พัง) =====
local old = { money = 999, choices = { pos = 5 } }
local merged = GameState.mergeDefaults(old, GameState.newGame())
check("ค่าเดิมอยู่ครบ", merged.money == 999 and merged.choices.pos == 5)
check("key ที่ขาดถูกเติม", merged.mental == 80 and merged.choices.neg == 0)
check("ตารางซ้อนถูกเติมทั้งก้อน", merged.upgrades.camera == 1)

-- ===== GameState.slotSummary =====
local sum = GameState.slotSummary({ follower = 55_000, day = 12, money = 1, mental = 1,
	clips = {}, choices = {}, upgrades = {}, calendar = {}, flags = {}, savedAt = 123 })
check("summary: follower/day/savedAt", sum.follower == 55_000 and sum.day == 12 and sum.savedAt == 123)
check("summary: phase คำนวณจาก follower", sum.phase == 2)

-- ===== ActionRouter (docs/06 §3 — Action เส้นเดียว แจกตาม type) =====
local hitState, hitAction = nil, nil
ActionRouter.register("TestPing", function(st, a)
	hitState, hitAction = st, a
end)
local fakeState = { money = 1 }
check("route เจอ handler คืน true",
	ActionRouter.route(fakeState, { type = "TestPing", x = 7 }) == true)
check("handler ได้ state + action ถูกตัว", hitState == fakeState and hitAction.x == 7)
check("type ไม่รู้จัก คืน false ไม่ crash",
	ActionRouter.route(fakeState, { type = "ไม่มีจริง" }) == false)
check("action เพี้ยน (nil) คืน false", ActionRouter.route(fakeState, nil) == false)
local dupOk = pcall(function()
	ActionRouter.register("TestPing", function() end)
end)
check("register ชื่อซ้ำต้อง error (กันเขียนทับเงียบ)", dupOk == false)

-- ===== TimeService (docs/07 §3.1 — นาฬิกาเดียว ระบบอื่นสมัครฟัง) =====
local hourCount, dayCount = 0, 0
TimeService.onHour(function() hourCount += 1 end)
TimeService.onDay(function() dayCount += 1 end)

local ts = GameState.newGame() -- timeOfDay 8, day 1
TimeService.tick(ts)
check("tick: 8 โมง → 9 โมง วันเดิม", ts.timeOfDay == 9 and ts.day == 1)
check("tick ยิง onHour ไม่ยิง onDay", hourCount == 1 and dayCount == 0)

ts.timeOfDay = 23
TimeService.tick(ts)
check("tick: 23 → 0 ขึ้นวันใหม่", ts.timeOfDay == 0 and ts.day == 2)
check("ข้ามเที่ยงคืนยิง onDay", dayCount == 1)

TimeService.setFrozen(true)
TimeService.tick(ts)
check("frozen: เวลาไม่เดิน callback ไม่ยิง", ts.timeOfDay == 0 and hourCount == 2)
TimeService.setFrozen(false)

-- กติกานอน (PDF หน้า 6): เริ่มนอน 18:00–5:59 ข้าม 8 ชม. | นอกช่วง ข้าม 12 ชม.
check("นอน 17:00 (นอกช่วง) = 12 ชม.", TimeService.sleepHours(17) == 12)
check("นอน 18:00 (ขอบล่าง) = 8 ชม.", TimeService.sleepHours(18) == 8)
check("นอน 23:00 = 8 ชม.", TimeService.sleepHours(23) == 8)
check("นอน 0:00 = 8 ชม.", TimeService.sleepHours(0) == 8)
check("นอน 5:00 (ขอบบน) = 8 ชม.", TimeService.sleepHours(5) == 8)
check("นอน 6:00 (พ้นช่วง) = 12 ชม.", TimeService.sleepHours(6) == 12)

local before = { h = hourCount, d = dayCount }
ts.timeOfDay = 22
ts.day = 5
TimeService.sleep(ts)
check("นอน 4 ทุ่ม ข้าม 8 ชม. → ตื่น 6 โมง วันถัดไป", ts.timeOfDay == 6 and ts.day == 6)
check("นอนยิง callback ครบทุกชั่วโมงที่ข้าม",
	hourCount == before.h + 8 and dayCount == before.d + 1)
check("นอนจบแล้ว flag sleeping ถูกปิด", ts.sleeping == false)

-- ชั่วโมงที่หลับต้องไม่ drain ใจ (fix 29 ก.ค. — เดิมนอน 8 ชม. เสียใจ 13%)
local slp = GameState.newGame()
slp.phase = 2
slp.mental = 80
slp.timeOfDay = 22
MentalService.onHour(slp) -- ตื่นอยู่ = drain ปกติ
local awakeDrain = 80 - slp.mental
slp.mental = 80
slp.sleeping = true
for _ = 1, 8 do MentalService.onHour(slp) end
slp.sleeping = false
check("ตื่น 1 ชม. เสียใจ ≈ 1.667", math.abs(awakeDrain - 5 / 3) < 0.001)
check("หลับ 8 ชม. ใจไม่ลด", slp.mental == 80)
check("หลับไม่นับชั่วโมงตื่น (ไม่ติด NoSleep เอง)", slp.awakeHours == 1)

-- ===== MentalService (design doc §3 — ไม่มี modifiers ตาม option ข) =====
check("drain ต่อชั่วโมงเกม = 1% × 7.5/4.5 ≈ 1.667",
	math.abs(MentalService.drainPerHour - 5 / 3) < 0.001)
local ms = GameState.newGame() -- phase 1, mental 80
check("phase 1: effective = 50 (โซนกลาง มัลติ 1.0 — bar ยังไม่เข้าระบบ)",
	MentalService.effective(ms) == 50)
MentalService.apply(ms, "clipEdit")
check("phase 1: mental ไม่ขยับ", ms.mental == 80)
ms.phase = 2
check("phase 2: effective = ค่าจริง", MentalService.effective(ms) == 80)
MentalService.apply(ms, "clipEdit")
check("ตัดคลิป -20 → 60", ms.mental == 60)
ms.mental = 95
MentalService.apply(ms, "viralClip")
check("clamp บน 100", ms.mental == 100)
ms.mental = 10
MentalService.apply(ms, "clipEdit")
check("ลงถึง 0 + ตั้ง flag Bad End 2", ms.mental == 0 and ms.flags.mentalZero == true)
ms.mental = 50
MentalService.onHour(ms)
check("onHour หัก drain", math.abs(ms.mental - (50 - 5 / 3)) < 0.001)

-- ===== FollowerService (docs/07 §3.4 ฝั่ง server + §4) =====
local fs = GameState.newGame()
FollowerService.finishEdit(fs, { score = 160 })
check("finishEdit: clip tier S ยังไม่อัป", fs.clips[1].tier == "S" and fs.clips[1].uploaded == false)
FollowerService.finishEdit(fs, { score = 999 })
check("finishEdit: clamp คะแนน 0-200", fs.clips[2].score == 200)
FollowerService.finishEdit(fs, { score = 70 })

local upOk, upViral = FollowerService.uploadClip(fs, { clip = 3 }, 50, rngQueue({ 0, 0, 0.5 }))
check("upload clip B: +400 follower", upOk == true and fs.follower == 400)
check("เงินเข้า 400×0.8 = 320", fs.money == 2500 + 320)
check("clip ถูก mark uploaded", fs.clips[3].uploaded == true)
check("ไม่ viral", upViral == false)
check("อัปซ้ำไม่ได้", FollowerService.uploadClip(fs, { clip = 3 }, 50, rngQueue({ 0, 0, 0.5 })) == false)
check("index มั่วไม่ crash", FollowerService.uploadClip(fs, { clip = 99 }, 50, rngQueue({})) == false)

fs.follower = 9_900
local upOk2, upViral2 = FollowerService.uploadClip(fs, { clip = 1 }, 50, rngQueue({ 0, 0, 0.05, 0 }))
check("clip S viral: base 400 ×2 ×4 = 3200", upOk2 and upViral2 and fs.follower == 9_900 + 3_200)
check("ข้าม gate → phase 2", fs.phase == 2)

-- Edit more = ตัดคลิปใหม่ต่อเลย: ทุกรอบ QTE ได้คลิปใหม่ 1 อัน (mental -20 ต่อรอบ Main จัดการ)
local re = GameState.newGame()
FollowerService.finishEdit(re, { score = 80 })
FollowerService.finishEdit(re, { score = 150 })
check("Edit more: ได้คลิปใหม่ทุกรอบ", #re.clips == 2)
check("Edit more: คลิปแยกกัน คะแนนไม่ทับ", re.clips[1].score == 80 and re.clips[2].score == 150)

-- ===== RecordService (docs/02 §9.5 — ตัวเลขทุกตัวจาก Config.Record) =====
local RecordService = if isStudio
	then require(game:GetService("ServerScriptService").Services.RecordService)
	else require("../src/server/Services/RecordService")

local noBonus = function() return 0.99 end -- >= bonusChance 0.1
local yesBonus = function() return 0.01 end

local rc = GameState.newGame()
check("ความจุเริ่มต้น = 128 GB", RecordService.capacity(rc) == 128)
rc.upgrades.storage = 6
check("ความจุระดับ 6 = 8192 GB", RecordService.capacity(rc) == 8192)
rc.upgrades.storage = 1

check("gainFor กล้อง 1 ไม่มีอะไร = 1 GB", RecordService.gainFor(1, false, 1) == 1)
check("gainFor กล้อง 6 = 32 GB", RecordService.gainFor(6, false, 1) == 32)
check("gainFor bonus ×2.4", RecordService.gainFor(1, true, 1) == 2.4)
check("gainFor bonus ซ้อนโซนได้ (1 ×2.4 ×1.5)", RecordService.gainFor(1, true, 1.5) == 3.6)
check("zoneMult เฟส 1/2/3 = 1.5/2/2.5", RecordService.zoneMult(1) == 1.5
	and RecordService.zoneMult(2) == 2 and RecordService.zoneMult(3) == 2.5)

local r1 = RecordService.record(rc, { now = 100, rng = noBonus })
check("คลิกแรก: ได้ 1 GB", r1.ok and r1.gained == 1 and rc.footageGB == 1)
local r2 = RecordService.record(rc, { now = 100.3, rng = noBonus })
check("คลิกซ้ำใน 0.6 วิ = cooldown ไม่ได้ GB", r2.ok == false and r2.reason == "cooldown" and rc.footageGB == 1)
local r3 = RecordService.record(rc, { now = 100.6, rng = noBonus })
check("พ้น cooldown 0.6 วิ = อัดได้", r3.ok and rc.footageGB == 2)
local r4 = RecordService.record(rc, { now = 102, rng = yesBonus })
check("bonus proc = 2.4 GB + flag", r4.ok and r4.bonus == true and r4.gained == 2.4)
local r5 = RecordService.record(rc, { now = 103, inZone = true, rng = noBonus })
check("ในโซน เฟส 1 = 1 ×1.5", r5.gained == 1.5)

-- เต็มความจุ
local rf = GameState.newGame()
rf.footageGB = 127.5
local rFull = RecordService.record(rf, { now = 10, rng = noBonus })
check("คลิกสุดท้ายตัดให้พอดี cap ไม่ล้น", rFull.gained == 0.5 and rf.footageGB == 128)
check("เต็มแล้ว = isFull", RecordService.isFull(rf) == true)
local rAfter = RecordService.record(rf, { now = 20, rng = noBonus })
check("เต็มแล้วอัดต่อไม่ได้", rAfter.ok == false and rAfter.reason == "full")

-- วงจรปิด: footage → คลิป (lock 27 ก.ค. — 32 GB/คลิป คงที่ ไม่ผูก VidQ)
local rce = GameState.newGame()
check("footage 0 = ตัดไม่ได้", RecordService.canEdit(rce) == false)
check("ตัดไม่ได้ = ไม่หัก footage", RecordService.spendForClip(rce) == false and rce.footageGB == 0)
rce.footageGB = 31.9
check("ขาดนิดเดียวก็ยังไม่ได้", RecordService.canEdit(rce) == false)
rce.footageGB = 70
check("ครบ 32 = ตัดได้", RecordService.canEdit(rce) == true)
check("ตัดแล้วหัก 32", RecordService.spendForClip(rce) == true and rce.footageGB == 38)
check("ตัดรอบ 2 ได้", RecordService.spendForClip(rce) == true and rce.footageGB == 6)
check("เหลือ 6 GB ตัดรอบ 3 ไม่ได้", RecordService.spendForClip(rce) == false and rce.footageGB == 6)
check("EditQTE.canEdit ตรงกับ server", EditQTE.canEdit(rce) == RecordService.canEdit(rce))
rce.footageGB = 32
check("EditQTE.canEdit พอดี 32 = ได้", EditQTE.canEdit(rce) == true)
check("EditQTE.canEdit ไม่มี state = ไม่ได้", EditQTE.canEdit(nil) == false)

-- Tool ในมือต้องตรง state (กล้อง 6 ระดับ 6 โมเดล, โน้ตบุ๊คเฉพาะเฟส 1)
local ToolService = if isStudio
	then require(game:GetService("ServerScriptService").Services.ToolService)
	else require("../src/server/Services/ToolService")
local function toolSet(state)
	local set = {}
	for _, n in ToolService.desiredTools(state) do set[n] = true end
	return set
end
local ts = GameState.newGame()
local t1 = toolSet(ts)
check("เฟส 1 เริ่มเกม: กล้อง L1 + โน้ตบุ๊ค", t1.Camera_1 and t1.Notebook)
check("ไม่มี Tool มือถือ/ไม้เซลฟี่แยก (อุปกรณ์ถ่ายมีสายเดียว)", t1.Phone == nil and t1.Selfie == nil)
ts.upgrades.camera = 4
check("อัปกล้อง = เปลี่ยนโมเดลเป็น Camera_4", toolSet(ts).Camera_4 and toolSet(ts).Camera_1 == nil)
ts.notebookPlaced = true
check("วางโน้ตบุ๊คแล้ว Tool หายจากมือ", toolSet(ts).Notebook == nil)
ts.notebookPlaced = false
ts.phase = 2
check("เฟส 2 ไม่มีโน้ตบุ๊ค (ห้องมีคอมจริงแล้ว)", toolSet(ts).Notebook == nil)
ts.upgrades.camera = 99
-- แก้ 5 ส.ค.: ทุกระดับมี Tool กล้องเสมอ — ระดับ 6 Tool ทำหน้าที่รีโมทเรียกรถเพิ่ม
check("ระดับกล้องเกินตาราง = clamp ที่โมเดลตัวท้ายสุด", toolSet(ts).Camera_6 == true)
ts.upgrades.camera = Config.CameraCartLevel - 1
check("ระดับก่อนถึงรถ ยังได้ Tool ตามระดับปกติ",
	toolSet(ts)["Camera_" .. (Config.CameraCartLevel - 1)] == true)
check("ชื่อบน hotbar โชว์ resolution ไม่ใช่ key", ToolService.displayName("Camera_3") == "กล้อง (1080p)")
check("ชื่อ Notebook เป็นไทย", ToolService.displayName("Notebook") == "โน้ตบุ๊ค")

-- โซนถ่าย: สุ่มจุด + ย้ายทุก 120 วิ
local rz = GameState.newGame()
local spots = { "FilmSpot_A", "FilmSpot_B", "FilmSpot_C" }
check("ไม่มีจุดในแมพ = ไม่ตั้งโซน", RecordService.tickZone(rz, 0, {}, rngQueue({ 0 })) == false)
check("ตั้งโซนครั้งแรก", RecordService.tickZone(rz, 0, spots, rngQueue({ 0 })) == true)
check("โซนมี spot + หมดอายุที่ 120", rz.filmZone.spot == "FilmSpot_A" and rz.filmZone.expiresAt == 120)
check("โซนยังไม่หมดอายุ = ไม่ย้าย", RecordService.tickZone(rz, 119, spots, rngQueue({ 0 })) == false)
check("หมดอายุ = ย้าย", RecordService.tickZone(rz, 120, spots, rngQueue({ 0 })) == true)
check("ย้ายแล้วต้องไม่ใช่จุดเดิม", rz.filmZone.spot ~= "FilmSpot_A")
check("จุดเดียวในแมพ = อยู่ที่เดิมได้", RecordService.pickSpot({ "FilmSpot_A" }, rngQueue({ 0 }), "FilmSpot_A") == "FilmSpot_A")

local RecordTool = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.RecordTool)
	else require("../src/client/RecordTool")
check("อยู่กลางวง = ในโซน", RecordTool.inZone({ X = 0, Z = 0 }, { X = 0, Z = 0 }, 18) == true)
check("ขอบวงพอดี = ในโซน", RecordTool.inZone({ X = 18, Z = 0 }, { X = 0, Z = 0 }, 18) == true)
check("เลยขอบ = นอกโซน", RecordTool.inZone({ X = 0, Z = 18.1 }, { X = 0, Z = 0 }, 18) == false)
check("ความสูงไม่นับ (เช็คแค่ระนาบ XZ)", RecordTool.inZone({ X = 3, Z = 3 }, { X = 0, Z = 0 }, 18) == true)
check("ไม่มีโซน = นอกโซนเสมอ", RecordTool.inZone({ X = 0, Z = 0 }, nil, 18) == false)

-- ===== MoneyService (design doc §4 — หักราย 7 วัน + Bank ⊖⊕ lock 21 ก.ค.) =====
local mo = GameState.newGame()
check("รวมรายจ่าย phase 1 = 2200", MoneyService.weeklyTotal(mo) == 2_200)
mo.phase = 3
check("รวมรายจ่าย phase 3 = 7700", MoneyService.weeklyTotal(mo) == 7_700)
mo.phase = 1
mo.money = 5_000
mo.day = 8
check("วัน 8 (ครบสัปดาห์แรก) หักแล้วเหลือ 2800",
	MoneyService.onDay(mo) == false and mo.money == 2_800)
mo.day = 9
MoneyService.onDay(mo)
check("วัน 9 ไม่หัก", mo.money == 2_800)
mo.day = 1
MoneyService.onDay(mo)
check("วัน 1 ไม่หัก", mo.money == 2_800)
mo.day = 15
mo.money = 1_000
check("เงินไม่พอ: เหลือ 0 + นับ rentMissed + คืน true",
	MoneyService.onDay(mo) == true and mo.money == 0 and mo.flags.rentMissed == 1)

-- Bank ⊖⊕ (PDF หน้า 9)
local spb = GameState.newGame()
check("เพิ่มค่ากิน 1 step", MoneyService.adjustSpending(spb, "food", 1) == true and spb.spending.food == 1)
check("weeklyTotal รวม offset: 2200+200", MoneyService.weeklyTotal(spb) == 2_400)
spb.spending.food = 3
check("เกิน maxOffset ไม่ได้", MoneyService.adjustSpending(spb, "food", 1) == false)
spb.spending.food = -1
check("ต่ำกว่า minOffset ไม่ได้", MoneyService.adjustSpending(spb, "food", -1) == false)
check("card มั่ว = false", MoneyService.adjustSpending(spb, "รถ", 1) == false)
check("lifestyle: กินถูกสุด = -4/สัปดาห์", MoneyService.lifestyleMental(spb) == -4)
spb.spending.food = 2
spb.spending.rent = 1
check("lifestyle: กินดี +4 เช่าดี +1 = +5", MoneyService.lifestyleMental(spb) == 5)
spb.spending.food = 0
spb.spending.rent = -2
spb.money = 99_999
spb.day = 8
local brokeB, billedB = MoneyService.onDay(spb)
check("เช่า offset -2 = นับค้างเช่าแม้เงินพอ", brokeB == false and billedB == true and spb.flags.rentMissed == 1)
check("ยอดหักตาม offset: เช่า 500+กิน 400+เน็ต 300 = 1200", spb.money == 99_999 - 1_200)
check("staff งบโบนัส: +2 step = 2200+2000", (function()
	local s2 = GameState.newGame()
	s2.spending.staff = 2
	return MoneyService.weeklyTotal(s2) == 4_200
end)())

-- ===== doActivity (PDF หน้า 6 — ติดกัน 3 ครั้ง cooldown 1 วัน) =====
local da = GameState.newGame()
da.phase = 2
da.mental = 50
check("Bed +25 (activityRest)", MentalService.doActivity(da, "Bed") == true and da.mental == 75)
da.mental = 50
MentalService.doActivity(da, "Kitchen") -- ครั้ง 2 (+15 → 65)
MentalService.doActivity(da, "Exercise") -- ครั้ง 3 (+20 → 85) → เข้า cooldown
check("ครั้ง 3 ยังได้ผล", da.mental == 85)
check("cooldown ถึงวันพรุ่งนี้ + streak รีเซ็ต",
	da.activity.cooldownUntilDay == da.day + 1 and da.activity.streak == 0)
check("ระหว่าง cooldown ใช้ไม่ได้", MentalService.doActivity(da, "Bed") == false)
da.day += 1
check("วันใหม่ใช้ได้อีก", MentalService.doActivity(da, "Bed") == true)
check("activity มั่วคืน false", MentalService.doActivity(da, "อาบน้ำ") == false)

-- ===== EditQTE scoring ใหม่ (redesign 8 ส.ค. — พีคตอนวงแหวนปิดพอดี ไม่ใช่กลาง window) =====
check("วงแหวนปิดพอดี (t=window) = 10 เต็ม", EditQTE.scoreFor(1.5, 1.5) == 10)
check("กดทันทีที่โผล่ (t=0) = 0", EditQTE.scoreFor(0, 1.5) == 0)
check("กดครึ่งทาง = 5", EditQTE.scoreFor(0.75, 1.5) == 5)
check("กด 90% ทาง ~9", EditQTE.scoreFor(1.35, 1.5) == 9)
-- t เกิน window ไม่มีทางเกิดจริง (timeout ยิง auto-miss ก่อนกดได้เสมอ) แค่ต้องไม่ทะลุกรอบ 0-10
check("t เกิน window ไม่ทะลุคะแนนเต็ม 10", EditQTE.scoreFor(99, 1.5) == 10)
check("t ติดลบไม่พัง คืน 0", EditQTE.scoreFor(-1, 1.5) == 0)

-- ===== tierFor / colorFor (สี 4 ระดับ ผูก S/A/B/C) =====
check("9-10 = S (เขียว)", EditQTE.tierFor(10) == "S" and EditQTE.tierFor(9) == "S")
check("6-8 = A (ฟ้า)", EditQTE.tierFor(6) == "A" and EditQTE.tierFor(8) == "A")
check("3-5 = B (เหลือง)", EditQTE.tierFor(3) == "B" and EditQTE.tierFor(5) == "B")
check("0-2 = C (แดง)", EditQTE.tierFor(0) == "C" and EditQTE.tierFor(2) == "C")
check("colorFor คืน Color3 ครบ 4 tier", typeof(EditQTE.colorFor("S")) == "Color3"
	and typeof(EditQTE.colorFor("A")) == "Color3" and typeof(EditQTE.colorFor("B")) == "Color3"
	and typeof(EditQTE.colorFor("C")) == "Color3")

-- ===== planWaves (สุ่มเวฟ 2-4 วง จนครบงบ 20) =====
-- ★ ห่อ do...end: ไฟล์นี้เป็น chunk เดียวยาวมาก ชนเพดาน Luau 200 local registers/chunk แล้ว
--   (เจอจริง 8 ส.ค. ตอนเพิ่มเทส EditQTE ชุดนี้) — scope ให้แคบ คืน register ให้โค้ดข้างล่างใช้ต่อ
do
	-- ไม่ fix rng: จำนวนรอบสุ่มไม่แน่นอน (ขึ้นกับ roll แต่ละครั้ง) ต่างจากเทสอื่นที่รู้จำนวนเรียกล่วงหน้า
	-- เชคแค่ invariant (ช่วง 1-4, รวม=งบ) ไม่ต้องเป๊ะค่าไหน — math.random ปกติพอ
	local waves = EditQTE.planWaves(20, 2, 4)
	local sum = 0
	for _, n in waves do
		check("ทุกเวฟอยู่ในช่วง 1-4 (ยกเว้นเวฟสุดท้ายถ้างบไม่พอ)", n >= 1 and n <= 4)
		sum += n
	end
	check("รวมทุกเวฟ = งบทั้งหมด 20 พอดี", sum == 20)
	local oneWave = EditQTE.planWaves(1, 2, 4, rngQueue({ 0 }))
	check("งบ 1 = เวฟเดียวขนาด 1 (เล็กกว่า min ได้ตอนงบไม่พอ)", #oneWave == 1 and oneWave[1] == 1)
end

-- ===== pickKeysUnique (คีย์ PC ไม่ซ้ำกันในเวฟ) =====
do
	local keys = EditQTE.pickKeysUnique(4, { "Q", "W", "E", "R", "A" }, rngQueue({ 0, 0, 0, 0 }))
	check("ได้ครบ 4 คีย์", #keys == 4)
	local seen, dup = {}, false
	for _, k in keys do
		if seen[k] then dup = true end
		seen[k] = true
	end
	check("คีย์ไม่ซ้ำกันในเวฟ", not dup)
	check("ขอเกิน pool = ได้แค่เท่า pool", #EditQTE.pickKeysUnique(9, { "Q", "W" }, rngQueue({ 0, 0 })) == 2)
end

-- ===== randomPositions (ตำแหน่งวงกลมกระจาย ไม่ล้นขอบ) =====
do
	local pos = EditQTE.randomPositions(4, 0.12, rngQueue({ 0.1, 0.2, 0.9, 0.8, 0.3, 0.4, 0.6, 0.5 }))
	check("ตำแหน่งครบตามจำนวนที่ขอ", #pos == 4)
	local inBounds = true
	for _, p in pos do
		if p.x < 0.12 or p.x > 0.88 or p.y < 0.12 or p.y > 0.88 then inBounds = false end
	end
	check("ทุกตำแหน่งอยู่ในกรอบ margin ไม่ล้นขอบ", inBounds)
end

-- ===== sponsorPay (PDF หน้า 6: เงินคลิปเฉลี่ย ×2–4) =====
check("sponsorPay phase1 rng=0 → 650×0.8×2 = 1040", Formulas.sponsorPay(1, rng0) == 1040)
local sp = Formulas.sponsorPay(1, rngHi)
check("sponsorPay rng สูง → เข้าใกล้ ×4", sp >= 2070 and sp <= 2080)
local ns = GameState.newGame()
check("state ใหม่มี pendingComments/pendingEvents",
	#ns.pendingComments == 0 and #ns.pendingEvents == 0)

-- ===== CommentService (design doc §6 + PDF หน้า 8 lock 21 ก.ค. — slot ⊖/◎/⊕ ทอยแยก) =====
-- rng ลำดับ: ทอย neg → (ถ้าออก เลือกใบ) → ทอย neu → ... → ทอย pos
local cs = GameState.newGame()
-- tier B (neg 40% neu 36% pos 40%): ทอย neg 0.39=ออก เลือกใบแรก, neu 0.9=เงียบ, pos 0.39=ออก เลือกใบแรก
CommentService.generate(cs, "B", rngQueue({ 0.39, 0, 0.9, 0.39, 0 }))
check("tier B ออก ⊖ กับ ⊕ (◎ เงียบ)", #cs.pendingComments == 2
	and cs.pendingComments[1].sentiment == "neg" and cs.pendingComments[2].sentiment == "pos")
local csQuiet = GameState.newGame()
CommentService.generate(csQuiet, "C", rngQueue({ 0.99, 0.99, 0.99 }))
check("ทอยแป้กหมด = คลิปเงียบ 0 ใบ", #csQuiet.pendingComments == 0)
check("tier มั่วไม่ crash", (CommentService.generate(GameState.newGame(), "Z", rngQueue({ 0 })) or true) == true)

-- ตอบใบแรก (⊖): heart = -10 นับ neg
local h1, tag1, reason1 = CommentService.answer(cs, { response = "heart" })
check("heart ⊖ = นับ neg + reason commentHeartNeg", h1 == true and tag1 == "neg"
	and reason1 == "commentHeartNeg" and cs.choices.neg == 1)
-- ใบสอง (⊕): ช้อย accept ใช้ไม่ได้ / heart ได้ = pos
local hBad = CommentService.answer(cs, { response = "insult" })
check("ด่าใส่ comment ⊕ ไม่ได้ ไม่ pop", hBad == false and #cs.pendingComments == 1)
local h2, tag2, reason2 = CommentService.answer(cs, { response = "heart" })
check("heart ⊕ = นับ pos", h2 == true and tag2 == "pos" and reason2 == "commentHeartPos" and cs.choices.pos == 1)
check("หมดคิวตอบอีก = false", CommentService.answer(cs, { response = "heart" }) == false)

-- ช้อยตอบ + skip
local cs2 = GameState.newGame()
CommentService.generate(cs2, "S", rngQueue({ 0, 0, 0.9, 0.9 })) -- ⊖ ออกใบแรก (S neg 5%? 0<0.05 จริง)
check("S ออก ⊖ ได้ (5%)", #cs2.pendingComments == 1 and cs2.pendingComments[1].sentiment == "neg")
local _, tagA, reasonA = CommentService.answer(cs2, { response = "accept" })
check("ยอมรับปัญหา = นับ pos +ใจ", tagA == "pos" and reasonA == "commentAccept")
CommentService.generate(cs2, "A", rngQueue({ 0.9, 0.1, 0, 0.9 })) -- ◎ ออก
check("A ออก ◎", cs2.pendingComments[1] and cs2.pendingComments[1].sentiment == "neu")
local _, tagS, reasonS = CommentService.answer(cs2, { response = "sarcasm" })
check("ประชด = นับ neu -5", tagS == "neu" and reasonS == "commentSarcasm" and cs2.choices.neu == 1)
CommentService.generate(cs2, "B", rngQueue({ 0.1, 0, 0.9, 0.9 }))
local before = { pos = cs2.choices.pos, neu = cs2.choices.neu, neg = cs2.choices.neg }
local hSkip, tagSkip = CommentService.answer(cs2, { response = "skip" })
check("ปล่อยผ่าน = pop แต่ไม่นับ", hSkip == true and tagSkip == nil and #cs2.pendingComments == 0
	and cs2.choices.pos == before.pos and cs2.choices.neu == before.neu and cs2.choices.neg == before.neg)

-- ===== CalendarService =====
local cal = GameState.newGame()
cal.day = 5
check("วางวันอนาคตได้", CalendarService.place(cal, 7, { type = "Schedule", id = "Marathon" }) == true)
check("วางวันนี้/อดีตไม่ได้", CalendarService.place(cal, 5, { type = "Schedule" }) == false)
cal.calendar[9] = { type = "Canon", id = "Hater", locked = true }
check("ทับ Canon ไม่ได้", CalendarService.place(cal, 9, { type = "Schedule" }) == false)
check("sponsor: ไม่มี offer ค้าง กดไม่ได้", CalendarService.acceptSponsor(cal, 8) == false)
cal.follower = 15_000
cal.phase = 2
check("sponsor offer: ก่อน 10K ไม่สุ่ม", (function()
	local c = GameState.newGame(); c.phase = 2; c.follower = 500
	return CalendarService.rollSponsorOffer(c, function() return 0 end) == false
end)())
check("sponsor offer: เฟส 1 ไม่สุ่ม", (function()
	local c = GameState.newGame(); c.follower = 15_000
	return CalendarService.rollSponsorOffer(c, function() return 0 end) == false
end)())
check("sponsor offer: สุ่มพลาด (>=5%) ไม่ได้", CalendarService.rollSponsorOffer(cal, function() return 0.5 end) == false)
check("sponsor offer: สุ่มติด (<5%) ได้", CalendarService.rollSponsorOffer(cal, function() return 0.01 end) == true)
check("sponsor offer: มีค้างแล้วไม่ซ้อน", CalendarService.rollSponsorOffer(cal, function() return 0.01 end) == false)
check("sponsor: มี offer แล้ววางได้", CalendarService.acceptSponsor(cal, 8) == true)
check("sponsor: offer ถูกใช้หมด กดซ้ำไม่ได้", cal.sponsorOffer == false)
cal.day = 8
local money0 = cal.money
local blk = CalendarService.onDay(cal, rng0)
check("วัน sponsor: เงินเข้า + block หาย",
	blk.type == "Sponsor" and cal.money > money0 and cal.calendar[8] == nil)
check("วันไม่มี block คืน nil", CalendarService.onDay(GameState.newGame(), rng0) == nil)

-- block หลายวัน + ย้าย (lock 21 ก.ค. — UX ทาง ก)
local cal2 = GameState.newGame()
cal2.day = 2
check("วาง block 3 วัน ครองทุกช่อง", CalendarService.place(cal2, 5, { type = "Schedule", id = "Job", length = 3 }) == true
	and cal2.calendar[5] ~= nil and cal2.calendar[7] ~= nil and cal2.calendar[5].startDay == 5)
check("วางทับกลาง block ยาวไม่ได้", CalendarService.place(cal2, 6, { type = "Schedule" }) == false)
check("ย้ายทั้งก้อนจากช่องกลางได้", CalendarService.moveBlock(cal2, 6, 10) == true
	and cal2.calendar[5] == nil and cal2.calendar[7] == nil
	and cal2.calendar[10].startDay == 10 and cal2.calendar[12] ~= nil)
check("ย้ายไปวันผ่านแล้วไม่ได้ + block คืนที่เดิม",
	CalendarService.moveBlock(cal2, 10, 1) == false and cal2.calendar[10] ~= nil and cal2.calendar[12] ~= nil)
cal2.calendar[20] = { type = "Canon", id = "X", locked = true }
check("ย้าย Canon ไม่ได้", CalendarService.moveBlock(cal2, 20, 25) == false)

-- block ยาว: ผลเกิดวันจบงาน
local cal3 = GameState.newGame()
cal3.day = 2
CalendarService.place(cal3, 3, { type = "Sponsor", length = 2 })
cal3.day = 3
local m0 = cal3.money
check("วันแรกของงานยาว: ยังไม่จ่าย แค่เคลียร์ช่อง",
	CalendarService.onDay(cal3, rng0) == nil and cal3.money == m0 and cal3.calendar[3] == nil)
cal3.day = 4
local doneBlk = CalendarService.onDay(cal3, rng0)
check("วันจบงาน: จ่ายเงิน + เคลียร์",
	doneBlk ~= nil and doneBlk.type == "Sponsor" and cal3.money > m0 and cal3.calendar[4] == nil)

-- ===== StaffService (docs/02 §9.8 lock 21 ก.ค.) =====
local StaffService = if isStudio
	then require(game:GetService("ServerScriptService").Services.StaffService)
	else require("../src/server/Services/StaffService")

check("speed 20 = 1 คลิป/วัน", StaffService.clipsPerDay(20) == 1)
check("speed 70 = 3.5 คลิป/วัน", StaffService.clipsPerDay(70) == 3.5)
-- rollTier: quality 35 → แถวแรก (C 60 / B 30 / A 10 / S 0)
check("quality ต่ำ roll 0.5 = C", StaffService.rollTier(35, rngQueue({ 0.5 })) == "C")
check("quality ต่ำ roll 0.8 = B", StaffService.rollTier(35, rngQueue({ 0.8 })) == "B")
check("quality ต่ำ roll 0.99 = A (S เป็น 0%)", StaffService.rollTier(35, rngQueue({ 0.99 })) == "A")
check("quality 95 roll 0.99 = S", StaffService.rollTier(95, rngQueue({ 0.99 })) == "S")
check("quality 95 roll 0 = B (ไม่มี C)", StaffService.rollTier(95, rngQueue({ 0 })) == "B")

-- ปลดล็อกต้องครบทั้ง phase และ follower
local st = GameState.newGame()
st.phase = 2
st.follower = 14_000
check("follower ไม่ถึง = ยังไม่ปลด", #StaffService.availableHires(st) == 0)
st.follower = 15_000
check("ครบทั้งคู่ = ปลด slot 1", #StaffService.availableHires(st) == 1)
st.phase = 1
check("เฟสไม่ถึงแม้ follower พอ = ไม่ปลด", #StaffService.availableHires(st) == 0)

-- จ้าง/ไล่
st.phase = 2
check("จ้าง hire_1 ได้", StaffService.hire(st, "hire_1") == true and #st.staff == 1)
check("จ้างซ้ำไม่ได้", StaffService.hire(st, "hire_1") == false)
check("จ้างตัวที่ยังไม่ปลดไม่ได้", StaffService.hire(st, "hire_4") == false)
check("ไล่ออกได้", StaffService.fire(st, "hire_1") == true and #st.staff == 0)
check("ไล่คนที่ไม่มีไม่ได้", StaffService.fire(st, "hire_1") == false)
-- cap 4
local stCap = GameState.newGame()
stCap.phase = 3
stCap.follower = 500_000
for _, r in Config.Staff.roster do StaffService.hire(stCap, r.id) end
check("จ้างครบ 4 ตาม cap", #stCap.staff == Config.Staff.hireCap)

-- companion: เข้าเอง โตตามเฟส หายตอนทรยศ
local co = GameState.newGame()
co.follower = 10_000
co.phase = 2
StaffService.syncCompanions(co)
check("companion_1 เข้าที่ 10K (speed 20)", #co.companions == 1
	and co.companions[1].id == "companion_1" and co.companions[1].speed == 20)
co.follower = 100_000
co.phase = 3
StaffService.syncCompanions(co)
check("เข้าเฟส 3: companion_1 โต + companion_2 เข้า", #co.companions == 2
	and co.companions[1].speed == 45 and co.companions[1].quality == 75)
co.flags.betrayed = true
StaffService.syncCompanions(co)
check("ทรยศ: companion_1 หาย เหลือ companion_2", #co.companions == 1
	and co.companions[1].id == "companion_2")

-- ผลิตรายวัน: เศษคลิปสะสมข้ามวัน
local pr = GameState.newGame()
pr.phase = 2
pr.follower = 15_000
StaffService.hire(pr, "hire_1") -- speed 20 = 1 คลิป/วัน
local f0, m0 = pr.follower, pr.money
local out = StaffService.produceDaily(pr, rngQueue({ 0.5 }))
check("1 คลิป/วัน ได้ follower+เงิน", #out == 1 and pr.follower > f0 and pr.money > m0
	and #pr.staffClips == 1)
local half = GameState.newGame()
half.phase = 2
half.follower = 40_000
StaffService.hire(half, "hire_2") -- speed 35 = 1.75 คลิป/วัน
StaffService.produceDaily(half, rngQueue({ 0.5, 0.5 }))
check("วันแรก 1.75 → ได้ 1 คลิป เศษ 0.75", #half.staffClips == 1)
StaffService.produceDaily(half, rngQueue({ 0.5, 0.5, 0.5 }))
check("วันสอง 0.75+1.75=2.5 → ได้อีก 2 คลิป", #half.staffClips == 3)
check("ทีมว่าง = ไม่ผลิต", #StaffService.produceDaily(GameState.newGame(), rng0) == 0)

-- เงินเดือน + ลาออก
local sal = GameState.newGame()
sal.phase = 3
sal.follower = 500_000
StaffService.hire(sal, "hire_1") -- 8k
StaffService.hire(sal, "hire_4") -- 60k
check("รวมเงินเดือน 68k", StaffService.weeklySalary(sal) == 68_000)
local left = StaffService.resign(sal, 10_000)
check("จ่ายไม่ไหว: คนแพงสุดออกก่อน", left[1] == "hire_4" and #sal.staff == 1
	and sal.staff[1].id == "hire_1")
check("เงินพอแล้วไม่ไล่เพิ่ม", StaffService.weeklySalary(sal) == 8_000)

-- VidQ%: คลิปทีมนับครึ่งเดียว
local vw = GameState.newGame()
table.insert(vw.clips, { tier = "S", uploaded = true })
table.insert(vw.staffClips, { tier = "C" })
local stats = EndingService.computeStats(vw)
check("คลิป player 1 (S) + ทีม 1 (C) → S 66.7% / C 33.3% (ทีมนับ 0.5)",
	math.abs(stats.vidq.S - 200 / 3) < 0.1 and math.abs(stats.vidq.C - 100 / 3) < 0.1)

-- ===== EndingService =====
local es = GameState.newGame()
check("เกมปกติยังไม่จบ", EndingService.check(es) == nil)
es.flags.rentMissed = 2
es.flags.mentalZero = true
check("Bad1 มาก่อน Bad2", EndingService.check(es) == "Bad1")
es.flags.rentMissed = 0
check("mental หมด → Bad2", EndingService.check(es) == "Bad2")
local eg = GameState.newGame()
eg.follower = 1_000_000
eg.clips = { { tier = "A" }, { tier = "A" }, { tier = "S" }, { tier = "B" }, { tier = "A" } }
eg.choices = { pos = 8, neu = 1, neg = 1 }
check("1M + สายดี → Good1", EndingService.check(eg) == "Good1")
eg.flags.ending = "Good1"
check("จบแล้วเช็คอีก = nil", EndingService.check(eg) == nil)
local st = EndingService.computeStats(eg)
check("stats vidq % ถูก (A 60%)", st.vidq.A == 60 and st.vidq.S == 20 and st.vidq.C == 0)
check("stats choice % ถูก (pos 80%)", st.choice.pos == 80 and st.choice.neg == 10)

-- ===== DialogueUI.parseTags (design doc §7) =====
local seg = DialogueUI.parseTags("สวัสดี")
check("ไม่มี tag = normal ก้อนเดียว", #seg == 1 and seg[1].speed == "normal" and seg[1].text == "สวัสดี")
seg = DialogueUI.parseTags("[slow]ก[fast]ข")
check("tag นำหน้า + กลางบรรทัด", #seg == 2 and seg[1].speed == "slow" and seg[1].text == "ก"
	and seg[2].speed == "fast" and seg[2].text == "ข")
seg = DialogueUI.parseTags("ปกติ[slow]ช้า")
check("เริ่ม normal แล้วเปลี่ยน", seg[1].speed == "normal" and seg[2].speed == "slow" and seg[2].text == "ช้า")

-- ===== DialogueUI.bullet — ดอกจันนำหน้าประโยคแบบ Undertale =====
check("ใส่ดอกจันต้นข้อความ", DialogueUI.bullet("สวัสดี") == "* สวัสดี")
check("ขึ้นบรรทัดใหม่ในบท = ได้ดอกจันอีกตัว", DialogueUI.bullet("ก\nข") == "* ก\n* ข")
check("ข้อความว่าง = ไม่ใส่ดอกจัน", DialogueUI.bullet("") == "")

-- ===== DialogueUI.validate — format บรรทัด 3 แบบ (โหมด 2 "ฉากคุย") =====
check("บทข้อความล้วน ผ่าน", DialogueUI.validate({ "ก", "ข" }) == true)
check("บทมี speaker ผ่าน", DialogueUI.validate({ { speaker = "แม่", text = "ก" } }) == true)
check("ตารางไม่มี text/choices = ไม่ผ่าน", DialogueUI.validate({ { speaker = "แม่" } }) == false)
check("ช้อยครบ ผ่าน", DialogueUI.validate({
	{ choices = { { text = "ขอโทษ", tone = "plus", reply = { "…" } }, { text = "เงียบ" } } },
}) == true)
check("ช้อยว่าง = ไม่ผ่าน", DialogueUI.validate({ { choices = {} } }) == false)

-- ===== CameraFocus.frameCFrame (โฟกัสกล้องหน้า NPC ตอนคุย) =====
local CameraFocus = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.CameraFocus)
	else require("../src/client/CameraFocus")
-- NPC ที่ CFrame.new(0,5,0) หันหน้า -Z, ระยะ 10: กล้องต้องอยู่หน้า NPC ยกระดับตา มองกลับมาหา NPC
local camCF = CameraFocus.frameCFrame(CFrame.new(0, 5, 0), 10)
check("กล้องถอยตามระยะ (รวมความสูงตา)",
	math.abs((camCF.Position - Vector3.new(0, 5, 0)).Magnitude - math.sqrt(10 ^ 2 + 1.5 ^ 2)) < 0.01)
check("กล้องยกสูงระดับตา 6.5", math.abs(camCF.Position.Y - 6.5) < 0.01)
check("กล้องอยู่หน้า NPC (ฝั่ง -Z) มองกลับหา NPC", camCF.Position.Z < 0 and camCF.LookVector.Z > 0)
check("ช้อยไม่มี text = ไม่ผ่าน", DialogueUI.validate({ { choices = { { tone = "plus" } } } }) == false)
check("tone มั่ว = ไม่ผ่าน", DialogueUI.validate({ { choices = { { text = "ก", tone = "angry" } } } }) == false)
check("reply พังข้างใน = ไม่ผ่าน", DialogueUI.validate({
	{ choices = { { text = "ก", reply = { { speaker = "แม่" } } } } },
}) == false)
check("lineOf: string → text", DialogueUI.lineOf("ก").text == "ก")

-- ===== ท่าทาง/อารมณ์ (AnimPlayer) =====
local AnimPlayer = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.AnimPlayer)
	else require("../src/client/AnimPlayer")
check("บทใส่ anim ผ่าน", DialogueUI.validate({ { speaker = "เจ", text = "ก", anim = "Point" } }) == true)
check("บทใส่ pose + actor ผ่าน", DialogueUI.validate({ { text = "ก", pose = "Angry", actor = "CC1" } }) == true)
check("บรรทัดสั่งท่าล้วน (ไม่มี text) ผ่าน", DialogueUI.validate({ { pose = "Idle" } }) == true)
check("anim ไม่ใช่ string = ไม่ผ่าน", DialogueUI.validate({ { text = "ก", anim = 5 } }) == false)
check("actor ไม่ใช่ string = ไม่ผ่าน", DialogueUI.validate({ { text = "ก", pose = "A", actor = true } }) == false)
check("หาท่าเฉพาะตัวก่อนท่ากลาง",
	AnimPlayer.candidates("Friend1", "Point")[1] == "Friend1/Point"
	and AnimPlayer.candidates("Friend1", "Point")[2] == "Point")
check("ไม่ระบุ actor = หาแค่ท่ากลาง", #AnimPlayer.candidates(nil, "Idle") == 1)
check("ชื่อไฟล์บท → prefix โมเดลในแมพ", AnimPlayer.modelPrefix("ฟ้าใส") == "NPC_special_ฟ้าใส")
check("ชื่อที่ไม่มีในตาราง = ใช้ชื่อนั้นตรงๆ", AnimPlayer.modelPrefix("Boss_Final") == "Boss_Final")
check("cutscene step anim ผ่าน",
	CutscenePlayer.validate({ { type = "anim", actor = "Friend1", name = "Point" } }) == true)
check("cutscene step anim ขาด name = ไม่ผ่าน",
	CutscenePlayer.validate({ { type = "anim", actor = "Friend1" } }) == false)

-- สีหน้า (R6 = สลับ Decal บนหัว คนละระบบกับ animation)
check("บทใส่ face ผ่าน", DialogueUI.validate({ { speaker = "เจ", text = "ก", face = "Angry" } }) == true)
check("บรรทัดสั่ง face ล้วนผ่าน", DialogueUI.validate({ { face = "Sad", actor = "CC1" } }) == true)
check("face ไม่ใช่ string = ไม่ผ่าน", DialogueUI.validate({ { text = "ก", face = 1 } }) == false)
check("cutscene step face ผ่าน",
	CutscenePlayer.validate({ { type = "face", actor = "player", name = "Shock" } }) == true)
check("cutscene step face ขาด actor = ไม่ผ่าน",
	CutscenePlayer.validate({ { type = "face", name = "Shock" } }) == false)

-- ===== CutscenePlayer.validate =====
local okc = CutscenePlayer.validate({ { type = "text", text = "x" }, { type = "wait", t = 1 },
	{ type = "camera", pos = { 0, 5, 0 }, look = { 0, 0, 0 } } })
check("script ถูก = ผ่าน", okc == true)
check("type มั่ว = ไม่ผ่าน", CutscenePlayer.validate({ { type = "explode" } }) == false)
check("wait ไม่มี t = ไม่ผ่าน", CutscenePlayer.validate({ { type = "wait" } }) == false)
check("camera cam=ชื่อPart ผ่าน", CutscenePlayer.validate({ { type = "camera", cam = "Cam_Bad1_01" } }) == true)
check("camera ไม่มีทั้ง cam/pos = ไม่ผ่าน", CutscenePlayer.validate({ { type = "camera" } }) == false)
check("camera ใส่ t (เลื่อนกล้อง) ผ่าน", CutscenePlayer.validate({ { type = "camera", cam = "Cam_Good1_01", t = 2 } }) == true)
check("camera t ไม่ใช่ตัวเลข = ไม่ผ่าน", CutscenePlayer.validate({ { type = "camera", cam = "A", t = "ช้า" } }) == false)
-- content จริงทั้ง 6 ending ต้อง validate ผ่าน
local Endings = if isStudio
	then game:GetService("ReplicatedStorage").Shared.Content.Endings
	else nil
for _, name in { "Bad1", "Bad2", "Bad3", "Neutral1", "Neutral2", "Good1" } do
	local stepsMod = if isStudio then require(Endings[name]) else require("../src/shared/Content/Endings/" .. name)
	check("Content.Endings." .. name .. " validate ผ่าน", CutscenePlayer.validate(stepsMod) == true)
end

-- ===== Dialogue: เลือกบทตามเฟส/หลังทรยศ (docs/02 §9.4) =====
local InteractBinder = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.InteractBinder)
	else require("../src/client/InteractBinder")
local sample = { p1 = { "หนึ่ง" }, p2 = { "สอง" }, after = { "หลังทรยศ" } }
-- ป้าย Interact_* จางตามระยะ (user feedback 28 ก.ค. — ป้ายเด่นเกินไป)
check("ยืนติดป้าย = ชัดเต็ม", InteractBinder.labelAlpha(0) == 0)
check("ในระยะกดได้ (10 studs) = ยังชัดเต็ม", InteractBinder.labelAlpha(10) == 0)
check("ไกลสุด = หายสนิท", InteractBinder.labelAlpha(30) == 1 and InteractBinder.labelAlpha(999) == 1)
check("ระหว่างทาง = จางไล่ระดับ", InteractBinder.labelAlpha(22) > 0 and InteractBinder.labelAlpha(22) < 1)
check("ยิ่งไกลยิ่งจาง (ไม่กลับทาง)",
	InteractBinder.labelAlpha(16) < InteractBinder.labelAlpha(20)
	and InteractBinder.labelAlpha(20) < InteractBinder.labelAlpha(26))

-- ประตู (docs/02 §9.9): follower ถึงเกณฑ์ = ผ่าน, ไม่ถึง = ข้อความบอกเกณฑ์
check("ประตูไม่มี MinFollower = เข้าได้เลย", (InteractBinder.doorCheck(0, nil)) == true)
check("ประตู 10K: มี 9,999 = เข้าไม่ได้", (InteractBinder.doorCheck(9999, 10000)) == false)
check("ประตู 10K: มี 10,000 = เข้าได้", (InteractBinder.doorCheck(10000, 10000)) == true)
local _, doorWhy = InteractBinder.doorCheck(0, 100000)
check("ประตูล็อกบอกเกณฑ์เป็น K", doorWhy == "ยังเข้าไม่ได้ (ต้องมี 100K follower)")

check("เฟส 1 ได้ p1", InteractBinder.pickLines(sample, { phase = 1, flags = {} })[1] == "หนึ่ง")
check("เฟส 2 ได้ p2", InteractBinder.pickLines(sample, { phase = 2, flags = {} })[1] == "สอง")
check("เฟส 3 ไม่มี p3 → ถอยลงมา p2", InteractBinder.pickLines(sample, { phase = 3, flags = {} })[1] == "สอง")
check("betrayed = ใช้ after ทุกเฟส",
	InteractBinder.pickLines(sample, { phase = 2, flags = { betrayed = true } })[1] == "หลังทรยศ")
check("betrayed แต่ NPC ไม่มี after → บทเฟสปกติ",
	InteractBinder.pickLines({ p1 = { "ปกติ" } }, { phase = 1, flags = { betrayed = true } })[1] == "ปกติ")
check("format เก่า (list string) ใช้ได้เหมือนเดิม",
	InteractBinder.pickLines({ "เก่า" }, { phase = 3, flags = {} })[1] == "เก่า")

-- คุยซ้ำ (seen): มีตาราง again = เล่น again, ไม่มี = ถอยไปบทเฟส
local seenSample = { p1 = { "เต็ม" }, again = { "ซ้ำ" } }
check("seen + มี again = ได้บท again",
	InteractBinder.pickLines(seenSample, { phase = 1, flags = {} }, true)[1] == "ซ้ำ")
check("seen แต่ไม่มี again = ได้บทเฟสปกติ",
	InteractBinder.pickLines(sample, { phase = 1, flags = {} }, true)[1] == "หนึ่ง")
check("ไม่ seen = ได้บทเฟสเสมอ (ไม่แตะ again)",
	InteractBinder.pickLines(seenSample, { phase = 1, flags = {} }, false)[1] == "เต็ม")

-- content จริง: ทุก NPC ที่ผูกใน binder ต้องมีบทให้ทุกเฟสที่เจอได้
local DialogueFolder = if isStudio then game:GetService("ReplicatedStorage").Shared.Content.Dialogue else nil
for _, name in { "ฟ้าใส", "เจียเจีย", "พี่เปิ้ล" } do
	local mod = if isStudio then require(DialogueFolder[name]) else require("../src/shared/Content/Dialogue/" .. name)
	local got = InteractBinder.pickLines(mod, { phase = 3, flags = {} })
	check("Dialogue." .. name .. " มีบทใช้ได้ที่เฟส 3", type(got) == "table" and type(got[1]) == "string")
end
-- ฟ้าใส = NPC เดียวที่ต้องมีชุด after (arc ทรยศ docs/02 §9.4) — โครงต้องอยู่แม้บทยังไม่เขียน
local f1 = if isStudio then require(DialogueFolder["ฟ้าใส"]) else require("../src/shared/Content/Dialogue/ฟ้าใส")
check("ฟ้าใส มีครบ p1/p2/after (arc ทรยศ)", f1.p1 ~= nil and f1.p2 ~= nil and f1.after ~= nil)

-- Canon event ทรยศต้องมีบทตรง milestone ที่ Config ชี้
local Events = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.CanonEvents)
	else require("../src/shared/Content/CanonEvents")
for _, m in Config.StoryMilestones do
	check(("CanonEvents มี milestone_%d"):format(m), Events["milestone_" .. m] ~= nil)
end
check("milestone ทรยศอยู่ใน StoryMilestones",
	table.find(Config.StoryMilestones, Config.BetrayalMilestone) ~= nil)
check("BCA มีบท + ผูกหลัง 1M (docs/02 §9.4)", Events[Config.BCAEventId] ~= nil
	and table.find(Config.StoryMilestones, Config.BCAAfterMilestone) ~= nil)
check("milestone เรียงจากน้อยไปมาก (event ยิงตามลำดับเรื่อง)", (function()
	for i = 2, #Config.StoryMilestones do
		if Config.StoryMilestones[i] <= Config.StoryMilestones[i - 1] then return false end
	end
	return true
end)())

-- ===== กันไม้ตาย: เนื้อหาจริงต้องไม่มี [placeholder] ค้าง (docs/10 — เนื้อเรื่อง = งาน user เขียน) =====
-- เทสนี้ FAIL ไปเรื่อยๆ จนกว่าจะเติมบทจริงครบ — ใช้เป็นตัวนับความคืบหน้า ไม่ใช่ตัวชี้ผิด/ถูกของเนื้อเรื่อง
local function hasPlaceholder(lines)
	for _, l in lines do
		if type(l) == "string" and l:find("[placeholder", 1, true) then return true end
	end
	return false
end

for key, ev in Events do
	check(("CanonEvents.%s ไม่มี [placeholder] ค้าง"):format(key), not hasPlaceholder(ev.dialogue or {}))
end

local DialogueFiles = { "แม่", "พ่อ", "ฟ้าใส", "เจียเจีย", "พี่เปิ้ล" }
for _, name in DialogueFiles do
	local mod = if isStudio
		then require(game:GetService("ReplicatedStorage").Shared.Content.Dialogue[name])
		else require("../src/shared/Content/Dialogue/" .. name)
	-- format ใหม่ = { p1=..., p2=..., after=... } | format เก่า = list ตรงๆ (ดู InteractBinder.pickLines)
	local flat = {}
	if type(mod[1]) == "string" then
		flat = mod
	else
		for _, group in mod do
			for _, l in group do table.insert(flat, l) end
		end
	end
	check(("Dialogue.%s ไม่มี [placeholder] ค้าง"):format(name), not hasPlaceholder(flat))
end

local EndingFiles = { "Good1", "Neutral1", "Neutral2", "Bad1", "Bad2", "Bad3" }
for _, name in EndingFiles do
	local steps = if isStudio
		then require(game:GetService("ReplicatedStorage").Shared.Content.Endings[name])
		else require("../src/shared/Content/Endings/" .. name)
	local texts = {}
	for _, s in steps do
		if s.type == "text" and s.text then table.insert(texts, s.text) end
	end
	check(("Endings.%s ไม่มี [placeholder] ค้าง"):format(name), not hasPlaceholder(texts))
end

-- ===== Cutscenes (Opening ฯลฯ — format ผ่าน CutscenePlayer.validate + track placeholder) =====
local CutsceneFiles = { "Opening" }
for _, name in CutsceneFiles do
	local steps = if isStudio
		then require(game:GetService("ReplicatedStorage").Shared.Content.Cutscenes[name])
		else require("../src/shared/Content/Cutscenes/" .. name)
	check(("Cutscenes.%s format ผ่าน validate"):format(name), CutscenePlayer.validate(steps) == true)
	local texts = {}
	for _, s in steps do
		if s.type == "text" and s.text then table.insert(texts, s.text) end
	end
	check(("Cutscenes.%s ไม่มี [placeholder] ค้าง"):format(name), not hasPlaceholder(texts))
end

-- PhaseTransitions — map เฟส→บรรทัด (ไม่ใช่ step list ไม่ผ่าน validate) · track placeholder ต่อเฟส
local PhaseTransitions = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.Cutscenes.PhaseTransitions)
	else require("../src/shared/Content/Cutscenes/PhaseTransitions")
for _, ph in { 2, 3 } do
	check(("PhaseTransitions[%d] ไม่มี [placeholder] ค้าง"):format(ph), not hasPlaceholder(PhaseTransitions[ph] or {}))
end

-- ===== Comments pool schema (docs/02 §9.6 — ทีมเติม comment แล้ว format ต้องไม่พัง) =====
local CommentsPool = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.Comments)
	else require("../src/shared/Content/Comments")
local poolCount = { neg = 0, neu = 0, pos = 0 }
for i, c in CommentsPool do
	check(("Comments[%d] sentiment ถูกต้อง"):format(i), poolCount[c.sentiment] ~= nil)
	if poolCount[c.sentiment] then poolCount[c.sentiment] += 1 end
	check(("Comments[%d] มีข้อความ"):format(i), type(c.text) == "string" and #c.text > 0)
	if c.sentiment == "neg" then
		check(("Comments[%d] (⊖) ต้องมี accept/sarcasm/insult ครบ"):format(i),
			c.replies ~= nil and c.replies.accept and c.replies.sarcasm and c.replies.insult ~= nil)
	elseif c.sentiment == "neu" then
		check(("Comments[%d] (◎) ต้องมี accept/sarcasm"):format(i),
			c.replies ~= nil and c.replies.accept and c.replies.sarcasm ~= nil)
	end
end
check("pool ต้องมีครบทั้ง 3 sentiment (ไม่งั้น slot นั้นไม่มีอะไรโผล่)",
	poolCount.neg >= 1 and poolCount.neu >= 1 and poolCount.pos >= 1)

-- ===== HUD storage = GB ไม่ใช่จำนวนคลิป (docs/09 §0 ข้อ 4) =====
local HUD = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.UI.HUD)
	else require("../src/client/UI/HUD")
local hudS = GameState.newGame()
-- ⚠️ 28 ก.ค.: ไอคอนย้ายออกจากข้อความไปเป็นรูป/emoji แยกช่อง (HUD ใหม่ตามภาพร่าง) → ไม่มี "💾 " นำหน้าแล้ว
check("storage เริ่มต้น = 0 GB / 128 GB", HUD.storageText(hudS) == "0 GB / 128 GB")
hudS.footageGB = 64.7
check("storage ปัดลงเป็นจำนวนเต็ม", HUD.storageText(hudS) == "64 GB / 128 GB")
hudS.footageGB = 128
check("storage เต็ม = FULL", HUD.storageText(hudS):find("FULL") ~= nil)
hudS.footageGB = 0
hudS.upgrades.storage = 4
check("ความจุ ≥1024 โชว์เป็น T", HUD.storageText(hudS) == "0 GB / 1T")

check("comma: หลักเดียว", HUD.comma(7) == "7")
check("comma: 1024 = 1,024", HUD.comma(1024) == "1,024")
check("comma: 1000000 = 1,000,000", HUD.comma(1_000_000) == "1,000,000")
check("comma: 100 ไม่ใส่ comma", HUD.comma(100) == "100")

-- progress bar แบ่ง 10/40/50 ตามเฟส ไม่ linear (docs/09 §0)
check("progress 0 = 0%", HUD.progressPct(0) == 0)
check("progress 10K = 10% พอดี (จบเฟส 1)", math.abs(HUD.progressPct(10_000) - 0.10) < 1e-9)
check("progress 100K = 50% พอดี (จบเฟส 2)", math.abs(HUD.progressPct(100_000) - 0.50) < 1e-9)
check("progress 1M = 100%", math.abs(HUD.progressPct(1_000_000) - 1) < 1e-9)
check("progress 5K = 5% (กลางเฟส 1)", math.abs(HUD.progressPct(5_000) - 0.05) < 1e-9)
check("progress เกิน 1M ไม่ล้น", HUD.progressPct(5_000_000) == 1)
check("progress ติดลบ = 0", HUD.progressPct(-100) == 0)

-- ===== MenuUI แบบฉากจริง (plans/2026-07-27-menu-scene.md) =====
local MenuUI = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.UI.MenuUI)
	else require("../src/client/UI/MenuUI")
check("หน้า home → กล้อง Home", MenuUI.camFor("home") == "MenuCam_Home")
check("หน้าสมุด → กล้อง Book", MenuUI.camFor("book") == "MenuCam_Book")
check("ตอนเข้าเกม → กล้อง PC", MenuUI.camFor("launching") == "MenuCam_PC")
check("ชื่อหน้ามั่ว → ตกกลับ Home ไม่ error", MenuUI.camFor("อะไรไม่รู้") == "MenuCam_Home")
check("ช่องว่าง = ยังไม่เขียน", MenuUI.slotLine(2, nil):find("ยังว่าง") ~= nil)
check("ช่องมี save โชว์ วัน/follower/เฟส", (function()
	local t = MenuUI.slotLine(1, { day = 12, follower = 5400, phase = 2 })
	return t:find("12") and t:find("5400") and t:find("เฟส 2") ~= nil
end)())
check("latestSlot: ไม่มี save เลย = nil", MenuUI.latestSlot({}) == nil)
check("latestSlot: เลือกช่องที่เซฟล่าสุด", MenuUI.latestSlot({
	[1] = { savedAt = 100 }, [3] = { savedAt = 900 }, [4] = { savedAt = 500 },
}) == 3)
check("latestSlot: savedAt หาย = ถือว่า 0 ไม่ crash", MenuUI.latestSlot({ [2] = {} }) == 2)

-- ===== AudioService (docs/02 §9.9) =====
local Audio = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.AudioService)
	else require("../src/client/AudioService")
local box10 = { x = 10, y = 10, z = 10 }
check("จุดกลางกล่อง = อยู่ใน", Audio.insideBox({ x = 0, y = 0, z = 0 }, box10) == true)
check("ขอบพอดี = อยู่ใน", Audio.insideBox({ x = 5, y = -5, z = 5 }, box10) == true)
check("เลยขอบแกนเดียว = อยู่นอก", Audio.insideBox({ x = 5.1, y = 0, z = 0 }, box10) == false)
check("ไม่มีโซน = nil", Audio.bestZone({}) == nil)
check("โซนซ้อน เอา priority มากสุด", Audio.bestZone({
	{ name = "a", priority = 0 }, { name = "b", priority = 5 }, { name = "c", priority = 2 },
}).name == "b")
check("priority เท่ากัน เอาตัวแรก", Audio.bestZone({
	{ name = "a", priority = 1 }, { name = "b", priority = 1 },
}).name == "a")
check("ไม่ใส่ priority = 0", Audio.bestZone({ { name = "a" }, { name = "b", priority = 1 } }).name == "b")
-- footstep* ไม่อยู่ใน Config แล้ว — ใช้ระบบ material-based ที่ SSS.Footsteps แทน (5 ส.ค.)
check("Config.Audio ครบ", Config.Audio.bgmFade > 0 and Config.Audio.voiceMinGap > 0
	and Config.Audio.zoneCheckInterval > 0)
-- กล่องบทสนทนาขนาดคงที่ (Undertale ref) — ค่าต้องสมเหตุผล ไม่งั้น layout พัง
local DB = Config.Dialogue.box
check("Config.Dialogue.box ครบ", DB.width > 0 and DB.height > 0 and DB.textSize > 0
	and DB.padding >= 0 and DB.portrait >= 0 and DB.portrait + DB.padding * 3 < DB.width)
check("Config.Dialogue.box มีสีครบ (bg/text)",
	typeof(DB.bgColor) == "Color3" and typeof(DB.textColor) == "Color3")
-- cutscene step เสียงต้อง validate ผ่าน
check("cutscene step bgm ผ่าน", CutscenePlayer.validate({ { type = "bgm", name = "Street" } }) == true)
check("cutscene step bgm ไม่ใส่ชื่อ = เงียบ ผ่าน", CutscenePlayer.validate({ { type = "bgm" } }) == true)
check("cutscene step sound ต้องมีชื่อ", CutscenePlayer.validate({ { type = "sound" } }) == false)

-- ===== DMs schema (docs/10 — เพื่อนทีม content แก้แล้ว format ต้องไม่พัง) =====
local DMsContent = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.DMs)
	else require("../src/shared/Content/DMs")
for i, dm in DMsContent do
	check(("DMs[%d] มี from"):format(i), type(dm.from) == "string")
	check(("DMs[%d] มี lines หรือ exchanges"):format(i),
		type(dm.lines) == "table" or type(dm.exchanges) == "table")
	if dm.exchanges then
		for j, ex in dm.exchanges do
			check(("DMs[%d].exchanges[%d] npc เป็น string"):format(i, j), type(ex.npc) == "string")
			check(("DMs[%d].exchanges[%d] choices ว่างไม่ได้"):format(i, j),
				ex.choices == nil or (type(ex.choices) == "table" and #ex.choices > 0))
		end
	end
end

-- ===== Main Menu support (PDF หน้า 1 — Continue/save 4 ช่อง) =====
check("latestSlot เลือก savedAt มากสุด",
	GameState.latestSlot({ [2] = { savedAt = 5 }, [4] = { savedAt = 9 } }) == 4)
check("ไม่มี save = nil", GameState.latestSlot({}) == nil)
local dst = GameState.newGame()
dst.money = 1
local src2 = GameState.newGame()
src2.money = 777
local same = GameState.replaceWith(dst, src2)
check("replaceWith: ตาราง identity เดิม + ค่าใหม่", same == dst and dst.money == 777)
local gotPlayer = nil
ActionRouter.register("TestPlayer", function(st, a, plr) gotPlayer = plr end)
ActionRouter.route(fakeState, { type = "TestPlayer" }, "PLAYER")
check("route ส่ง player เป็น arg 3", gotPlayer == "PLAYER")

-- ===== Mental modifiers (docs/02 §3 lock 19 ก.ค.) =====
local mm = GameState.newGame()
mm.phase = 2
check("ไม่มี mod: drainMultiplier = 1", MentalService.drainMultiplier(mm) == 1)
MentalService.addMod(mm, "NoSleep")
MentalService.addMod(mm, "EditStreak5")
check("ซ้อน 1.5×1.5 = 2.25", MentalService.drainMultiplier(mm) == 2.25)
MentalService.addMod(mm, "CommentBadStreak3")
check("cap ที่ ×3 (1.5×1.5×2=4.5 → 3)", MentalService.drainMultiplier(mm) == 3)
MentalService.addMod(mm, "NoSleep")
local nCount = 0
for _, m in mm.mentalMods do if m.id == "NoSleep" then nCount += 1 end end
check("addMod ซ้ำไม่เบิ้ล", nCount == 1)

-- recovery: comment ดี +10 × CommentGoodStreak3 (1.25) = 12.5
local mr = GameState.newGame()
mr.phase = 2
mr.mental = 50
MentalService.addMod(mr, "CommentGoodStreak3")
MentalService.apply(mr, "commentAccept")
check("delta บวกคูณ recover mod: 50+12.5", mr.mental == 62.5)
mr.mental = 50
MentalService.apply(mr, "clipEdit")
check("delta ลบไม่โดน recover mod: 50-20", mr.mental == 30)

-- expiry ตามชั่วโมงเกม
local me = GameState.newGame()
me.phase = 2
MentalService.addMod(me, "CanonEvent") -- 24 ชม.
check("CanonEvent ติด", MentalService.drainMultiplier(me) == 1.25)
me.day = 2
me.timeOfDay = 9 -- ผ่านไป 25 ชม.จากวัน1 8:00
MentalService.expireMods(me)
check("ครบ 24 ชม.แล้วหาย", MentalService.drainMultiplier(me) == 1)

-- streak hooks
local mh = GameState.newGame()
mh.phase = 2
for _ = 1, 5 do MentalService.onEdit(mh) end
check("ตัด 5 ติด → EditStreak5", MentalService.drainMultiplier(mh) == 1.5)
MentalService.onActivityDone(mh)
check("activity ล้าง EditStreak5 + streak", MentalService.drainMultiplier(mh) == 1 and mh.streaks.edit == 0)
for _ = 1, 3 do MentalService.onCommentAnswered(mh, "neg") end
check("comment แย่ 3 ติด → ×2", MentalService.drainMultiplier(mh) == 2)
MentalService.onCommentAnswered(mh, "pos")
check("ตอบดีล้าง CommentBadStreak3", MentalService.drainMultiplier(mh) == 1)
MentalService.onCommentAnswered(mh, "pos")
MentalService.onCommentAnswered(mh, "pos")
check("comment ดี 3 ติด → recover 1.25", MentalService.recoverMultiplier(mh) == 1.25)

-- อดนอน + นอน
local mn = GameState.newGame()
mn.phase = 2
for _ = 1, 20 do MentalService.onHourAwake(mn) end
check("ตื่นครบ 20 ชม. → NoSleep", MentalService.drainMultiplier(mn) == 1.5)
MentalService.onSleep(mn)
check("นอนแล้วหาย + นับใหม่", MentalService.drainMultiplier(mn) == 1 and mn.awakeHours == 0)

-- viral 2 วันติด
local mv = GameState.newGame()
mv.phase = 2
mv.day = 5
MentalService.onViral(mv)
check("viral วันแรกยังไม่ติด", MentalService.recoverMultiplier(mv) == 1)
mv.day = 6
MentalService.onViral(mv)
check("viral 2 วันติด → recover ×2", MentalService.recoverMultiplier(mv) == 2)

-- ===== buyUpgrade (6 ระดับ ซื้อ 5 ครั้ง — user lock 21 ก.ค.) =====
local bu = GameState.newGame()
bu.money = 3_000
check("ซื้อกล้อง lv2 (2000)", MoneyService.buyUpgrade(bu, "camera") == true
	and bu.upgrades.camera == 2 and bu.money == 1_000)
check("เงินไม่พอ (lv3 = 8000)", MoneyService.buyUpgrade(bu, "camera") == false and bu.upgrades.camera == 2)
bu.money = 999_999
bu.upgrades.storage = 15 -- ระดับสูงสุด (ขยายจาก 6 → 15 เมื่อ 28 ก.ค. — ดูหมวดร้านค้าท้ายไฟล์)
check("max level แล้วซื้อไม่ได้", MoneyService.buyUpgrade(bu, "storage") == false)
check("item มั่วไม่ crash", MoneyService.buyUpgrade(bu, "รถ") == false)
check("ladder 15 ระดับตรงกันทุกตาราง", #Config.ResolutionLadder == 15
	and #Config.StorageLadderGB == 15 and #Config.Record.footagePerClickGB == 15
	and #Config.UpgradeCosts.camera == 14 and #Config.UpgradeCosts.storage == 14)
check("เริ่มเกม = 480p/128GB", Config.ResolutionLadder[1] == "480p" and Config.StorageLadderGB[1] == 128)

-- ===== ร้านค้าในแมพ (Interact_Shop) — 3 หมวด หมวดละ 15 ระดับ =====
local sk = GameState.newGame()
check("upgrades มีสาย pc เริ่มที่ 1", sk.upgrades.pc == 1)
check("catalog 3 หมวด", #Config.ShopCatalog == 3)

-- ทุกตารางต้องยาว 15 ระดับเท่ากัน ไม่งั้นบันไดขาดกลางคัน
check("ladder ยาว 15 ระดับตรงกันทุกตาราง", #Config.ResolutionLadder == 15
	and #Config.StorageLadderGB == 15 and #Config.Record.footagePerClickGB == 15)

for _, e in Config.ShopCatalog do
	local costs = Config.UpgradeCosts[e.key]
	check(("หมวด %s: 15 ระดับ (ของเริ่ม 1 + ซื้อได้ 14)"):format(e.key),
		ShopKiosk.tierCount(e) == 15 and #e.names == 14)
	check(("หมวด %s: ราคาครบทุกขั้นที่ขาย"):format(e.key), costs ~= nil and #costs == #e.names)
	check(("หมวด %s: มีชื่อของเริ่มต้น (ระดับ 1 ไม่ได้ซื้อ)"):format(e.key), e.startName ~= nil)
end

local camEntry, stoEntry, pcEntry
for _, e in Config.ShopCatalog do
	if e.key == "camera" then camEntry = e elseif e.key == "storage" then stoEntry = e else pcEntry = e end
end

-- สเปคบนแถวต้องมาจาก ladder ไม่ใช่ข้อความที่พิมพ์ซ้ำใน catalog
check("spec กล้อง = resolution + GB/คลิก ของระดับนั้น",
	ShopKiosk.specFor("camera", 2) == "720p · 2 GB/คลิก")
check("spec storage < 1024 = GB", ShopKiosk.specFor("storage", 2) == "256 GB")
check("spec storage ≥ 1024 = TB", ShopKiosk.specFor("storage", 4) == "1 TB")
check("spec storage ≥ 1PB = PB", ShopKiosk.specFor("storage", 13) == "1 PB")
check("spec storage ระดับ 15 = 16 PB", ShopKiosk.specFor("storage", 15) == "16 PB")
check("spec pc = nil (ยังไม่มี ladder)", ShopKiosk.specFor("pc", 2) == nil)

-- ระดับ 1 = ของติดตัวตอนเริ่ม ไม่มีราคา · ระดับ 2+ = ของที่ซื้อ
check("ระดับ 1 = ชื่อของเริ่มต้น", ShopKiosk.nameAt(camEntry, 1) == "มือถือเครื่องเก่า")
check("ระดับ 2 = ของชิ้นแรกที่ซื้อ", ShopKiosk.nameAt(camEntry, 2) == "มือถือใหม่")
check("ระดับ 15 = ชื่อสุดท้ายใน names", ShopKiosk.nameAt(camEntry, 15) == camEntry.names[14])

local camOffer = ShopKiosk.offerFor(camEntry, sk)
check("ของชิ้นแรกหมวดกล้อง = มือถือใหม่ ราคา 2000 ได้ระดับ 2",
	camOffer.name == "มือถือใหม่" and camOffer.price == 2_000 and camOffer.level == 2)
check("ราคาตรงกับ UpgradeCosts ที่เดียว", camOffer.price == Config.UpgradeCosts.camera[1])
check("offer storage ชิ้นแรกได้ 256 GB", ShopKiosk.offerFor(stoEntry, sk).spec == "256 GB")
check("offer pc ชิ้นแรกไม่มี spec แต่ซื้อได้", ShopKiosk.offerFor(pcEntry, sk).price == Config.UpgradeCosts.pc[1])

-- บันได: สถานะทุกขั้นต้องสอดคล้องกับระดับปัจจุบัน (ข้ามขั้นซื้อไม่ได้)
local tiers = ShopKiosk.tiersFor(camEntry, sk)
check("บันไดยาว 15 ขั้น", #tiers == 15)
check("ขั้น 1 = ใช้อยู่ ไม่มีราคา", tiers[1].status == "current" and tiers[1].price == nil)
check("ขั้น 2 = ซื้อได้ถัดไป", tiers[2].status == "next" and tiers[2].price == 2_000)
check("ขั้น 3+ = ล็อกไว้ก่อน", tiers[3].status == "locked" and tiers[15].status == "locked")
sk.upgrades.camera = 6
local t6 = ShopKiosk.tiersFor(camEntry, sk)
check("อยู่ระดับ 6: ขั้นก่อนหน้าเป็น owned", t6[5].status == "owned" and t6[1].status == "owned")
check("อยู่ระดับ 6: ขั้น 6 ใช้อยู่ / ขั้น 7 ซื้อได้", t6[6].status == "current" and t6[7].status == "next")

-- ซื้อครบ 15 แล้วต้องหยุดขาย
sk.upgrades.camera = 15
check("ระดับสูงสุดแล้ว = ไม่มีของขายต่อ", ShopKiosk.offerFor(camEntry, sk) == nil)
check("ระดับสูงสุด: ขั้นสุดท้าย = ใช้อยู่", ShopKiosk.tiersFor(camEntry, sk)[15].status == "current")

-- ระดับ 1-6 ต้องเป็นค่าที่ล็อกใน docs/02 §9.5 เป๊ะ (ขยาย 15 ห้ามขยับของเดิม)
check("[ล็อก] storage 1-6 ไม่ขยับ", Config.StorageLadderGB[1] == 128 and Config.StorageLadderGB[2] == 256
	and Config.StorageLadderGB[3] == 512 and Config.StorageLadderGB[4] == 1024
	and Config.StorageLadderGB[5] == 4096 and Config.StorageLadderGB[6] == 8192)
check("[ล็อก] GB/คลิก 1-6 ไม่ขยับ", Config.Record.footagePerClickGB[1] == 1
	and Config.Record.footagePerClickGB[6] == 32)
check("[ล็อก] resolution 1-6 ไม่ขยับ", Config.ResolutionLadder[1] == "480p"
	and Config.ResolutionLadder[6] == "4320p")
check("[ล็อก] ราคา 1-6 ไม่ขยับ", Config.UpgradeCosts.camera[1] == 2_000
	and Config.UpgradeCosts.camera[5] == 300_000 and Config.UpgradeCosts.storage[1] == 1_500
	and Config.UpgradeCosts.storage[5] == 250_000)

-- อัตราส่วน storage/GB-ต่อคลิก = จำนวนคลิกต่อเต็มถัง ต้องคงที่ ไม่งั้น balance เพี้ยนเงียบๆ
for lv = 1, 15 do
	local clicks = Config.StorageLadderGB[lv] / Config.Record.footagePerClickGB[lv]
	check(("ระดับ %d: เต็มถังใน 128-256 คลิก"):format(lv), clicks == 128 or clicks == 256)
end

-- ===== รถเข็นกล้อง IMAX = อุปกรณ์ระดับ 6 (user lock 3 ส.ค.) =====
local CameraCart = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.CameraCart)
	else require("../src/client/CameraCart")

local cartS = GameState.newGame()
check("ระดับ 1 ขับรถไม่ได้", CameraCart.canDrive(cartS) == false)
cartS.upgrades.camera = Config.CameraCartLevel - 1
check("ระดับก่อนหน้า 1 ขั้น ยังขับไม่ได้", CameraCart.canDrive(cartS) == false)
cartS.upgrades.camera = Config.CameraCartLevel
check("ถึงระดับรถแล้วขับได้", CameraCart.canDrive(cartS) == true)
check("state ว่างไม่ crash", CameraCart.canDrive(nil) == false)

-- ย้อนกลับไปใช้กล้องระดับต่ำ = ขับรถไม่ได้ (ผลต้องตามตัวที่ถือจริง)
cartS.upgrades.camera = 8
MoneyService.equipLevel(cartS, "camera", 2)
check("ซื้อถึง 8 แต่ย้อนไปใช้ 2 = ขับไม่ได้", CameraCart.canDrive(cartS) == false)
MoneyService.equipLevel(cartS, "camera", Config.CameraCartLevel)
check("ย้อนกลับมาระดับรถ = ขับได้อีก", CameraCart.canDrive(cartS) == true)

-- ระดับรถ = ยังมี Tool กล้อง (Tool ตัวนั้นคือรีโมทเรียกรถ) — user lock 5 ส.ค.
local cartTool = GameState.newGame()
cartTool.upgrades.camera = Config.CameraCartLevel
check("ระดับรถ = ยังแจก Tool กล้อง (ใช้เป็นรีโมท)",
	ToolService.desiredTools(cartTool)[1] == Config.CameraCartToolSource)
check("ToolSource ของรีโมทตรงกับโมเดลระดับสูงสุดที่มีจริง",
	Config.CameraCartToolSource == "Camera_" .. Config.CameraModelCount)
cartTool.upgrades.camera = Config.CameraCartLevel - 1
check("ระดับก่อนหน้ายังแจก Tool กล้องปกติ",
	ToolService.desiredTools(cartTool)[1] == "Camera_" .. (Config.CameraCartLevel - 1))

-- ย้อนกลับไป equip กล้องต่ำกว่าระดับรถ = ไม่ควรมีรีโมทอยู่ในมือ
-- (sync ใช้เงื่อนไขเดียวกันนี้ตัดสินว่าจะลบรถที่เสกค้างในแมพทิ้งไหม)
local cartDown = GameState.newGame()
cartDown.upgrades.camera = Config.CameraCartLevel + 2
MoneyService.equipLevel(cartDown, "camera", Config.CameraCartLevel - 1)
local downSet = {}
for _, n in ToolService.desiredTools(cartDown) do downSet[n] = true end
check("ซื้อเกินระดับรถ แต่ย้อนไปใช้ต่ำกว่า = ไม่มีรีโมทเรียกรถ",
	downSet[Config.CameraCartToolSource] ~= true)
MoneyService.equipLevel(cartDown, "camera", Config.CameraCartLevel)
local upSet = {}
for _, n in ToolService.desiredTools(cartDown) do upSet[n] = true end
check("equip กลับมาระดับรถ = รีโมทกลับมา", upSet[Config.CameraCartToolSource] == true)

-- สูตรขับ: เดินหน้า/ถอย/เลี้ยว
local mv, tn = CameraCart.step(1, 0, 1)
check("คันเร่งเต็ม 1 วิ = เดินหน้าเท่า CameraCartSpeed", mv == Config.CameraCartSpeed and tn == 0)
check("ถอยหลัง = ระยะติดลบ", (CameraCart.step(-1, 0, 1)) == -Config.CameraCartSpeed)
check("จอดอยู่เลี้ยวไม่ได้ (เหมือนรถจริง)", select(2, CameraCart.step(0, 1, 1)) == 0)
local _, turnFwd = CameraCart.step(1, 1, 1)
local _, turnBack = CameraCart.step(-1, 1, 1)
check("เลี้ยวตอนเดินหน้ากับถอยหลัง หมุนกลับทางกัน", turnFwd ~= 0 and turnBack ~= 0 and (turnFwd * turnBack) < 0)
check("input เกินช่วงถูก clamp", CameraCart.step(99, 0, 1) == Config.CameraCartSpeed)
-- ความเร็วรถผูกกับความเร็ววิ่งของ player (user lock 3 ส.ค.: เร็วกว่าวิ่ง 1.5 เท่า)
check("รถเร็วกว่าวิ่ง 1.5 เท่าพอดี",
	math.abs(Config.CameraCartSpeed - Config.PlayerSprintSpeed * 1.5) < 1e-6)
check("รถเร็วกว่าวิ่งจริง (ไม่งั้นขับแล้วช้ากว่าเดินเท้า)",
	Config.CameraCartSpeed > Config.PlayerSprintSpeed)

-- ★ แกนเคลื่อนที่ — บั๊ก 3 ส.ค.: ใช้ +X (ด้านขวา) แทน −Z (ด้านหน้า) กด W แล้วรถเดินข้าง
-- Roblox: หน้าของ part = −Z ตรงกับ LookVector · เทสนี้จับ regression แกนสลับโดยตรง
local fwd = CameraCart.stepOffset(1, 0, 1).Position
check("เดินหน้า = ไปทาง −Z ไม่ใช่ +X", fwd.Z < 0 and math.abs(fwd.X) < 1e-6 and math.abs(fwd.Y) < 1e-6)
check("ระยะเดินหน้าเท่า CameraCartSpeed", math.abs(math.abs(fwd.Z) - Config.CameraCartSpeed) < 1e-6)
local back = CameraCart.stepOffset(-1, 0, 1).Position
check("ถอยหลัง = ไปทาง +Z (ตรงข้ามเดินหน้า)", back.Z > 0 and math.abs(back.X) < 1e-6)
check("จอดอยู่ไม่ขยับ", CameraCart.stepOffset(0, 1, 1).Position.Magnitude < 1e-6)
-- เลี้ยวขวา (D) = หมุนรอบแกน Y ทางลบ
local right = CameraCart.stepOffset(1, 1, 1)
local _, ry = right:ToEulerAnglesYXZ()
check("กด D = เลี้ยวขวา (หมุน Y ทางลบ)", ry < 0)
local left = CameraCart.stepOffset(1, -1, 1)
local _, ly = left:ToEulerAnglesYXZ()
check("กด A = เลี้ยวซ้าย (หมุน Y ทางบวก)", ly > 0)

-- ===== layout ตามภาพร่าง PDF หน้า 9: แถวละ 4 การ์ด + ลูกศรเลื่อน =====
check("แถวละ 4 การ์ด ตาม PDF", ShopKiosk.CARDS_PER_ROW == 4)
check("15 ระดับ = 4 หน้า (4/4/4/3)", ShopKiosk.pageCount(15, 4) == 4)
check("ของน้อยกว่า 1 หน้า ก็ยังนับเป็น 1 หน้า", ShopKiosk.pageCount(3, 4) == 1 and ShopKiosk.pageCount(0, 4) == 1)
check("ระดับ 1-4 อยู่หน้า 1", ShopKiosk.pageOf(1, 4) == 1 and ShopKiosk.pageOf(4, 4) == 1)
check("ระดับ 5 ขึ้นหน้า 2", ShopKiosk.pageOf(5, 4) == 2)
check("ระดับ 15 อยู่หน้า 4", ShopKiosk.pageOf(15, 4) == 4)
check("เลื่อนเกินขอบถูก clamp", ShopKiosk.clampPage(99, 15, 4) == 4 and ShopKiosk.clampPage(-3, 15, 4) == 1)

-- ===== ย้อนกลับไปใช้อุปกรณ์ระดับเก่า (user lock 1 ส.ค. — ผลลดลงจริงตามตัวที่ถือ) =====
local eq = GameState.newGame()
eq.upgrades.camera = 4
check("ไม่เคยเลือก = ใช้ระดับสูงสุดที่ซื้อ", Formulas.activeLevel(eq, "camera") == 4)
check("save เก่าไม่มี field equipped ก็ไม่โดนลดระดับ",
	Formulas.activeLevel({ upgrades = { camera = 5 } }, "camera") == 5)

check("เลือกย้อนกลับได้ถ้าซื้อไว้แล้ว", MoneyService.equipLevel(eq, "camera", 2) == true
	and Formulas.activeLevel(eq, "camera") == 2)
check("ซื้อไว้ระดับ 4 ยังอยู่ครบ ไม่หายไปกับการย้อน", eq.upgrades.camera == 4)
check("ระดับที่ยังไม่ได้ซื้อ เลือกไม่ได้", MoneyService.equipLevel(eq, "camera", 5) == false
	and Formulas.activeLevel(eq, "camera") == 2)
check("ระดับต่ำกว่า 1 / ไม่ใช่จำนวนเต็ม เลือกไม่ได้",
	MoneyService.equipLevel(eq, "camera", 0) == false
	and MoneyService.equipLevel(eq, "camera", 2.5) == false
	and MoneyService.equipLevel(eq, "camera", "สอง") == false)
check("สายมั่วไม่ crash", MoneyService.equipLevel(eq, "รถ", 1) == false)

-- ผลต้องลดจริงทุกระบบที่เกี่ยวข้อง ไม่ใช่แค่หน้าตา
local eqRec = GameState.newGame()
eqRec.upgrades.camera, eqRec.upgrades.storage = 4, 4
eqRec.lastRecordAt = -999
local full = RecordService.record(eqRec, { now = 500, inZone = false, rng = function() return 0.9 end })
check("ระดับ 4 อัดได้ 8 GB", full.gained == Config.Record.footagePerClickGB[4])
check("ระดับ 4 ความจุ 1024 GB", RecordService.capacity(eqRec) == Config.StorageLadderGB[4])

MoneyService.equipLevel(eqRec, "camera", 1)
MoneyService.equipLevel(eqRec, "storage", 1)
eqRec.lastRecordAt = -999
local low = RecordService.record(eqRec, { now = 900, inZone = false, rng = function() return 0.9 end })
check("ย้อนกล้องเป็นระดับ 1 = อัดได้ 1 GB จริง", low.gained == Config.Record.footagePerClickGB[1])
check("ย้อน storage เป็นระดับ 1 = ความจุลดเหลือ 128 GB", RecordService.capacity(eqRec) == Config.StorageLadderGB[1])
check("Tool ในมือเปลี่ยนตามตัวที่เลือก", ToolService.desiredTools(eqRec)[1] == "Camera_1")

-- ซื้อของใหม่ = สวมให้ทันที (ไม่งั้นจ่ายเงินแล้วยังถือของเก่า)
local eqBuy = GameState.newGame()
eqBuy.money = 2_000
MoneyService.equipLevel(eqBuy, "camera", 1)
check("ซื้อแล้วสวมตัวใหม่ให้อัตโนมัติ", MoneyService.buyUpgrade(eqBuy, "camera") == true
	and Formulas.activeLevel(eqBuy, "camera") == 2)

-- การ์ดในร้านต้องแยก "ใช้อยู่" กับ "ซื้อแล้วแต่ไม่ได้ใช้"
local eqShop = GameState.newGame()
eqShop.upgrades.camera = 3
MoneyService.equipLevel(eqShop, "camera", 1)
local camEnt
for _, e in Config.ShopCatalog do if e.key == "camera" then camEnt = e end end
local st = ShopKiosk.tiersFor(camEnt, eqShop)
check("ขั้นที่ถืออยู่ = current", st[1].status == "current")
check("ขั้นที่ซื้อแล้วแต่ไม่ได้ถือ = owned (กดใช้ได้)", st[2].status == "owned" and st[3].status == "owned")
check("ขั้นถัดจากที่ซื้อสูงสุด = next", st[4].status == "next")
check("เลยกว่านั้น = locked", st[5].status == "locked")

-- ===== responsive: ย่อแผงให้พอดีจอ (user feedback 1 ส.ค. — ตกขอบบน PC) =====
-- แผงออกแบบไว้ 778 × 704 px ตามภาพร่าง PDF
local PW, PH = 778, 704
check("จอใหญ่กว่าแผง = ไม่ขยาย (คงขนาดออกแบบ)", ShopKiosk.fitScale(PW, PH, 2560, 1400) == 1)
check("จอ 1080p (หัก topbar) = ยังพอดี ไม่ต้องย่อ", ShopKiosk.fitScale(PW, PH, 1920, 1080 - 36) == 1)
-- เตี้ยกว่าแผง = ต้องย่อ ไม่ใช่ปล่อยล้น
local narrow = ShopKiosk.fitScale(PW, PH, 1280, 720 - 36)
check("จอ 720p เตี้ยกว่าแผง = ย่อลง", narrow < 1 and narrow > ShopKiosk.MIN_SCALE)
check("ย่อแล้วสูงไม่เกินจอจริง", PH * narrow + ShopKiosk.SCREEN_MARGIN * 2 <= 720 - 36 + 0.01)
check("ย่อแล้วกว้างไม่เกินจอจริง", PW * narrow + ShopKiosk.SCREEN_MARGIN * 2 <= 1280 + 0.01)
-- ยึดด้านที่คับที่สุดเสมอ (จอกว้างมากแต่เตี้ย ต้องย่อตามความสูง)
check("จอกว้างแต่เตี้ย = ย่อตามความสูง",
	math.abs(ShopKiosk.fitScale(PW, PH, 3000, 500) - (500 - 48) / PH) < 0.001)
check("จอเล็กมาก = ไม่ย่อต่ำกว่า MIN_SCALE", ShopKiosk.fitScale(PW, PH, 200, 200) == ShopKiosk.MIN_SCALE)
-- รูปสินค้ามีแค่ระดับ 1-6 (UIAssets) — ระดับ 7+ ต้องคืน nil ให้การ์ดใช้ emoji แทน ไม่ใช่รูปพัง
check("ระดับ 7+ ไม่มีคีย์รูป = nil (ใช้ emoji แทน)", ShopKiosk.imageFor("camera", 9) == nil)
check("ระดับ 1-6 ยังไม่ได้วาด (ค่าว่าง) = nil ไม่ใช่ \"\"", ShopKiosk.imageFor("camera", 1) == nil)
for _, e in Config.ShopCatalog do
	check(("หมวด %s มี icon ไว้ fallback ตอนไม่มีรูป"):format(e.key), e.icon ~= nil and e.icon ~= "")
end
-- tiersFor ต้องแนบรูปมาให้ UI ด้วย (การ์ดใน PDF มีรูป)
check("tiersFor แนบ field image", select(2, pcall(function()
	return ShopKiosk.tiersFor(camEntry, GameState.newGame())[1].image
end)) == nil)

-- โมเดล Tool มีถึง Camera_6 — clamp ยังต้องทำงานสำหรับระดับที่ยังถือ Tool อยู่
local hi = GameState.newGame()
hi.upgrades.camera = 12
check("ระดับ 12 = ใช้โมเดลตัวท้ายสุด (clamp ไม่หลุดตาราง)",
	ToolService.desiredTools(hi)[1] == "Camera_" .. Config.CameraModelCount)
local midLv = GameState.newGame()
midLv.upgrades.camera = math.min(Config.CameraModelCount, Config.CameraCartLevel - 1)
check("ระดับสูงสุดที่ยังถือ Tool = ใช้โมเดลที่มีจริง ไม่หลุดตาราง",
	ToolService.desiredTools(midLv)[1] == "Camera_" .. midLv.upgrades.camera)

-- ซื้อผ่าน action เดิม (BuyUpgrade → MoneyService) ต้องขยับระดับ pc จริง
local pcBuy = GameState.newGame()
pcBuy.money = Config.UpgradeCosts.pc[1]
check("ซื้อ pc ชิ้นแรกได้ เงินหมดพอดี", MoneyService.buyUpgrade(pcBuy, "pc") == true
	and pcBuy.upgrades.pc == 2 and pcBuy.money == 0)
check("เงินไม่พอซื้อ pc ชิ้นที่สองไม่ได้", MoneyService.buyUpgrade(pcBuy, "pc") == false
	and pcBuy.upgrades.pc == 2)

-- save เก่า (ไม่มี pc) โหลดกับโค้ดใหม่ต้องไม่พัง
local oldSave = { upgrades = { camera = 2, storage = 1 } }
GameState.mergeDefaults(oldSave, GameState.newGame())
check("save เก่าไม่มี pc → เติมเป็น 1 ไม่ทับ camera", oldSave.upgrades.pc == 1 and oldSave.upgrades.camera == 2)

print(("Tests: %d passed, %d failed"):format(pass, fail))
-- คืน table ให้ execute_luau อ่านผลตรงๆ — ไม่ต้อง clone Source + patch print + pcall probe อีก
return { pass = pass, fail = fail, failures = failures }
