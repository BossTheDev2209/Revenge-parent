-- tests/RunTests.luau — เทสสมองคณิตทั้งเกม (Formulas.luau) เทียบกับ docs/02-game-design-locked.md
--
-- รันได้ 2 ทาง:
--   local : lune run tests/RunTests.luau
--   Studio: วางเป็น Script ใน ServerScriptService.Tests → ติ๊ก Enabled → Play → ดู Output → ติ๊กกลับ
local isStudio = script ~= nil
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../src/shared/Formulas")

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

print(("Tests: %d passed, %d failed"):format(pass, fail))
if fail > 0 then error("มีเทสไม่ผ่าน") end
