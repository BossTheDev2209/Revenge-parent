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

local EditQTE = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.UI.Apps.EditQTE)
	else require("../src/client/UI/Apps/EditQTE")

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

-- ===== EditQTE scoring (PDF หน้า 7 — กดกลาง window เป๊ะ = 10) =====
check("กดกลาง window (0.75s) = 10", EditQTE.scoreFor(0.75, 1.5) == 10)
check("กดทันทีที่ขึ้น (0s) = 0", EditQTE.scoreFor(0, 1.5) == 0)
check("กดวินาทีสุดท้าย = 0", EditQTE.scoreFor(1.5, 1.5) == 0)
check("กดครึ่งทางถึงกลาง = 5", EditQTE.scoreFor(0.375, 1.5) == 5)
check("ไม่ติดลบ", EditQTE.scoreFor(99, 1.5) == 0)
local qkeys = EditQTE.pickKeys(20, { "Q", "W", "E" }, rngQueue({
	0, 0.4, 0.9, 0, 0.4, 0.9, 0, 0.4, 0.9, 0, 0.4, 0.9, 0, 0.4, 0.9, 0, 0.4, 0.9, 0, 0.4 }))
check("pickKeys ครบ 20 ตัว", #qkeys == 20)
check("rng fix เลือกถูกตัว", qkeys[1] == "Q" and qkeys[2] == "W" and qkeys[3] == "E")

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

-- ===== CutscenePlayer.validate =====
local okc = CutscenePlayer.validate({ { type = "text", text = "x" }, { type = "wait", t = 1 },
	{ type = "camera", pos = { 0, 5, 0 }, look = { 0, 0, 0 } } })
check("script ถูก = ผ่าน", okc == true)
check("type มั่ว = ไม่ผ่าน", CutscenePlayer.validate({ { type = "explode" } }) == false)
check("wait ไม่มี t = ไม่ผ่าน", CutscenePlayer.validate({ { type = "wait" } }) == false)
check("camera cam=ชื่อPart ผ่าน", CutscenePlayer.validate({ { type = "camera", cam = "Cam_Bad1_01" } }) == true)
check("camera ไม่มีทั้ง cam/pos = ไม่ผ่าน", CutscenePlayer.validate({ { type = "camera" } }) == false)
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
check("เฟส 1 ได้ p1", InteractBinder.pickLines(sample, { phase = 1, flags = {} })[1] == "หนึ่ง")
check("เฟส 2 ได้ p2", InteractBinder.pickLines(sample, { phase = 2, flags = {} })[1] == "สอง")
check("เฟส 3 ไม่มี p3 → ถอยลงมา p2", InteractBinder.pickLines(sample, { phase = 3, flags = {} })[1] == "สอง")
check("betrayed = ใช้ after ทุกเฟส",
	InteractBinder.pickLines(sample, { phase = 2, flags = { betrayed = true } })[1] == "หลังทรยศ")
check("betrayed แต่ NPC ไม่มี after → บทเฟสปกติ",
	InteractBinder.pickLines({ p1 = { "ปกติ" } }, { phase = 1, flags = { betrayed = true } })[1] == "ปกติ")
check("format เก่า (list string) ใช้ได้เหมือนเดิม",
	InteractBinder.pickLines({ "เก่า" }, { phase = 3, flags = {} })[1] == "เก่า")

-- content จริง: ทุก NPC ที่ผูกใน binder ต้องมีบทให้ทุกเฟสที่เจอได้
local DialogueFolder = if isStudio then game:GetService("ReplicatedStorage").Shared.Content.Dialogue else nil
for _, name in { "Friend1", "Friend2", "CC1", "Hater", "Landlord" } do
	local mod = if isStudio then require(DialogueFolder[name]) else require("../src/shared/Content/Dialogue/" .. name)
	local got = InteractBinder.pickLines(mod, { phase = 3, flags = {} })
	check("Dialogue." .. name .. " มีบทใช้ได้ที่เฟส 3", type(got) == "table" and type(got[1]) == "string")
end
-- Friend1 = NPC เดียวที่ต้องมีชุด after (arc ทรยศ docs/02 §9.4) — โครงต้องอยู่แม้บทยังไม่เขียน
local f1 = if isStudio then require(DialogueFolder.Friend1) else require("../src/shared/Content/Dialogue/Friend1")
check("Friend1 มีครบ p1/p2/after (arc ทรยศ)", f1.p1 ~= nil and f1.p2 ~= nil and f1.after ~= nil)

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
check("storage เริ่มต้น = 0 GB / 128 GB", HUD.storageText(hudS) == "💾 0 GB / 128 GB")
hudS.footageGB = 64.7
check("storage ปัดลงเป็นจำนวนเต็ม", HUD.storageText(hudS) == "💾 64 GB / 128 GB")
hudS.footageGB = 128
check("storage เต็ม = FULL", HUD.storageText(hudS):find("FULL") ~= nil)
hudS.footageGB = 0
hudS.upgrades.storage = 4
check("ความจุ ≥1024 โชว์เป็น T", HUD.storageText(hudS) == "💾 0 GB / 1T")

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
check("Config.Audio ครบ", Config.Audio.bgmFade > 0 and Config.Audio.voiceMinGap > 0
	and Config.Audio.footstepInterval > 0 and Config.Audio.zoneCheckInterval > 0)
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
bu.upgrades.storage = 6 -- ระดับสูงสุด (ซื้อครบ 5 ครั้ง)
check("max level แล้วซื้อไม่ได้", MoneyService.buyUpgrade(bu, "storage") == false)
check("item มั่วไม่ crash", MoneyService.buyUpgrade(bu, "รถ") == false)
check("ladder 6 ระดับตรงกันทุกตาราง", #Config.ResolutionLadder == 6
	and #Config.StorageLadderGB == 6 and #Config.Record.footagePerClickGB == 6
	and #Config.UpgradeCosts.camera == 5 and #Config.UpgradeCosts.storage == 5)
check("เริ่มเกม = 480p/128GB", Config.ResolutionLadder[1] == "480p" and Config.StorageLadderGB[1] == 128)

print(("Tests: %d passed, %d failed"):format(pass, fail))
if fail > 0 then error("มีเทสไม่ผ่าน") end
