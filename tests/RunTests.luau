-- tests/RunTests.luau — เทสสมองคณิตทั้งเกม (Formulas.luau) เทียบกับ docs/02-game-design-locked.md
--
-- รันได้ 2 ทาง:
--   local : lune run tests/RunTests.luau
--   Studio: วางเป็น Script ใน ServerScriptService.Tests → ติ๊ก Enabled → Play → ดู Output → ติ๊กกลับ
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

local pass, fail = 0, 0
local function check(name: string, ok: boolean)
	if ok then pass += 1 else fail += 1; print("FAIL: " .. name) end
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

-- ===== MoneyService (design doc §4 — หักราย 7 วัน) =====
check("รวมรายจ่าย phase 1 = 2200", MoneyService.weeklyTotal(1) == 2_200)
check("รวมรายจ่าย phase 3 = 7700", MoneyService.weeklyTotal(3) == 7_700)
local mo = GameState.newGame()
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

print(("Tests: %d passed, %d failed"):format(pass, fail))
if fail > 0 then error("มีเทสไม่ผ่าน") end
