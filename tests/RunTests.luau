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

print(("Tests: %d passed, %d failed"):format(pass, fail))
if fail > 0 then error("มีเทสไม่ผ่าน") end
