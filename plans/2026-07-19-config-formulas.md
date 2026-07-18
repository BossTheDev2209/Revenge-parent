# Config + Formulas + Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** สร้างสมองคณิตของเกมทั้งหมด (Config 7 ตัว + Formulas pure functions) พร้อมเทสที่พิสูจน์ว่าตรงตาราง `docs/02-game-design-locked.md` ทุกตัวเลข

**Architecture:** ตัวเลขทั้งหมดอยู่ ModuleScript ใน `src/shared/Config/` (ตาราง Lua เปล่า) — logic คำนวณอยู่ `src/shared/Formulas.lua` เป็น pure function ที่รับ `rng` ฉีดได้ — เทสรันได้ทั้ง local (lune) และใน Studio (RunTests Script) ด้วยไฟล์เดียวกัน

**Tech Stack:** Luau, lune (test runner local), git. ไม่มี dependency อื่น

**หมายเหตุ env:** session นี้ไม่มี Roblox Studio MCP ต่ออยู่ — งานทั้งหมดลง repo (`src/`, `tests/`) ซึ่งเป็น mirror; ยก script เข้า Studio ตามโครง `docs/06-architecture.md` §1 ทีหลัง (copy-paste ตรงๆ ได้ โค้ดรองรับสองโหมดแล้ว)

**ตัวเลขที่ design doc ไม่ระบุ (ดึงจาก PDF ต้นฉบับ — flag แล้วในแชท):**
- เงินตั้งต้น 2,500 บาท (PDF หน้า 9)
- กติกานอน 8/12 ชม. + ช่วง 18:00–6:00 (PDF หน้า 6)
- Mental drain modifiers (อดนอน ×1.5 ฯลฯ) — **ยังไม่ทำในแผนนี้** (YAGNI — รอแผน MentalService)

---

### Task 1: git init + commit สภาพปัจจุบัน

**Files:** สร้าง `.gitignore`

- [ ] **Step 1: init + gitignore**

```bash
cd /c/Users/khunb/projects/RobloxProjects/getting-1m-follower
git init -b main
printf '*.rbxl\n*.rbxlx.lock\n' > .gitignore
```

- [ ] **Step 2: commit baseline**

```bash
git add -A
git commit -m "chore: baseline docs + assets ก่อนเริ่ม implement"
```

Expected: commit สำเร็จ มีไฟล์ docs/ assets/ CLAUDE.md plans/

---

### Task 2: หา test runner (lune)

- [ ] **Step 1: เช็คว่ามี runner อยู่แล้วไหม**

```bash
lune --version || luau --version || echo "none"
```

- [ ] **Step 2 (ถ้า none): ติดตั้ง lune**

ลองตามลำดับ หยุดที่ตัวแรกที่สำเร็จ:

```bash
scoop install lune || winget install lune || cargo install lune
```

ถ้าทุกทางล้ม: ดาวน์โหลด release binary จาก https://github.com/lune-org/lune/releases (`lune-*-windows-x86_64.zip`) แตกลง scratchpad แล้วใช้ path เต็ม

- [ ] **Step 3: ยืนยัน**

```bash
lune --version
```

Expected: พิมพ์ version ออกมา

---

### Task 3: Config 7 ไฟล์ (data ล้วน ไม่มี logic — ไม่ต้อง TDD แต่ต้อง re-derive จาก design doc)

**Files:**
- Create: `src/shared/Config/PhaseConfig.lua`
- Create: `src/shared/Config/VidQConfig.lua`
- Create: `src/shared/Config/ViralConfig.lua`
- Create: `src/shared/Config/MentalConfig.lua`
- Create: `src/shared/Config/EconomyConfig.lua`
- Create: `src/shared/Config/EndingConfig.lua`
- Create: `src/shared/Config/TimeConfig.lua`

- [ ] **Step 1: PhaseConfig** (design doc §1, §2, §4)

```lua
-- ReplicatedStorage.Shared.Config.PhaseConfig
-- ที่มา: docs/02-game-design-locked.md §1 (gate), §2 (base), §4 (moneyRate)
return {
	[1] = { gate = 10_000,    base = { 400, 900 },      moneyRate = 0.8 },
	[2] = { gate = 100_000,   base = { 1_400, 2_600 },  moneyRate = 1.2 },
	[3] = { gate = 1_000_000, base = { 9_000, 15_000 }, moneyRate = 1.5 },
}
```

- [ ] **Step 2: VidQConfig** (design doc §2 + QTE spec จาก PDF หน้า 7)

```lua
-- ReplicatedStorage.Shared.Config.VidQConfig
-- ที่มา: docs/02-game-design-locked.md §2 | qte: PDF หน้า 7
return {
	maxScore = 200,
	tiers = { -- เรียงต่ำ→สูง เช็คด้วย score <= max
		{ name = "C", max = 50,  multiplier = 0.5 },
		{ name = "B", max = 100, multiplier = 1.0 },
		{ name = "A", max = 150, multiplier = 1.5 },
		{ name = "S", max = 200, multiplier = 2.0 },
	},
	qte = { count = 20, windowSeconds = 1.5, keys = { "Q", "W", "E", "A", "S", "D", "Z", "X", "C" } },
}
```

- [ ] **Step 3: ViralConfig** (design doc §2)

```lua
-- ReplicatedStorage.Shared.Config.ViralConfig
-- ที่มา: docs/02-game-design-locked.md §2
return { chance = 0.12, multRange = { 4, 8 } }
```

- [ ] **Step 4: MentalConfig** (design doc §3)

```lua
-- ReplicatedStorage.Shared.Config.MentalConfig
-- ที่มา: docs/02-game-design-locked.md §3
return {
	start = 80,
	drainPercent = 1, drainIntervalSeconds = 4.5,
	zones = { -- เช็คบนลงล่าง: mental >= min | mental 0 = Bad End 2 (service จัดการ)
		{ min = 70, multRange = { 1.0, 1.25 } },
		{ min = 40, multRange = { 1.0, 1.0 } },
		{ min = 1,  multRange = { 0.6, 1.0 } },
	},
	deltas = {
		EditClip = -20, NpcBad = -10, CommentBad = -5, RentLate = -15,
		NpcGood = 15, CommentGood = 10, Viral = 25,
		Exercise = 20, Bed = 25, Kitchen = 15, -- ชื่อตรง Interact_ (docs/05 §3)
	},
	activity = { maxStreak = 3, cooldownDays = 1 },
}
```

- [ ] **Step 5: EconomyConfig** (design doc §4)

```lua
-- ReplicatedStorage.Shared.Config.EconomyConfig
-- ที่มา: docs/02-game-design-locked.md §4 | startMoney: PDF หน้า 9 (design doc ไม่ระบุ)
return {
	startMoney = 2500,
	weekly = { -- หักทุก 7 วันเกม
		[1] = { rent = 1500, internet = 300, food = 400 },
		[2] = { rent = 3000, internet = 500, food = 600 },
		[3] = { rent = 6000, internet = 800, food = 900 },
	},
	upgrades = { -- ราคา 4 ระดับ
		camera  = { 2000, 8000, 30000, 120000 },
		storage = { 1500, 6000, 25000, 100000 },
	},
}
```

- [ ] **Step 6: EndingConfig** (design doc §5 Trigger Conditions ฉบับ % — ตัวเลข .5 เก็บครบ)

```lua
-- ReplicatedStorage.Shared.Config.EndingConfig
-- ที่มา: docs/02-game-design-locked.md §5
-- order = priority เช็คบนลงล่าง คืนตัวแรกที่เข้าเงื่อนไข
-- (Bad1 เงิน / Bad2 mental ไม่อยู่ในนี้ — trigger สดกลางเกม)
-- combine ไม่ระบุ = "OR" (vidq ผ่าน หรือ choice ผ่าน)
return {
	order = { "Bad3", "Good1", "Neutral1", "Neutral2" },
	Bad3 = {
		vidq   = { Cmin = 0.33, Bmax = 0.33 },
		choice = { minusMin = 0.50, neutralMax = 0.25 },
	},
	Good1 = {
		vidq    = { Cmax = 0.16, Bmax = 0.33, Amin = 0.30, Smax = 0.20 },
		choice  = { plusMin = 0.625, minusMax = 0.125, neutralMax = 0.125 },
		combine = "AND",
	},
	Neutral1 = {
		vidq   = { Cmax = 0.20, Bmax = 0.33, Amin = 0.13, Smax = 0.13 },
		choice = { balance = 0.25 }, -- |minus − plus| + neutral < 0.25
	},
	Neutral2 = {
		vidq   = { Cmax = 0.26, Bmax = 0.33 },
		choice = { minusMax = 0.375, neutralMin = 0.25 },
	},
}
```

- [ ] **Step 7: TimeConfig** (design doc "1 playthrough 90–120 นาที" + PDF หน้า 6)

```lua
-- ReplicatedStorage.Shared.Config.TimeConfig
-- ที่มา: PDF หน้า 6 (1 วันเกม = 3 นาทีจริง) — design doc ไม่ระบุรายละเอียดเวลา
return {
	secondsPerGameHour = 7.5, -- 3 นาที ÷ 24 ชม.
	dayStartHour = 8,
	sleep = { normalHours = 8, windowStart = 18, windowEnd = 6, outsideHours = 12 },
}
```

- [ ] **Step 8: ตรวจทวนตัวเลขทุกตัวกับ design doc อีกรอบ** (กฎ CLAUDE.md ข้อ 2 — re-derive ไม่ใช่จำ)

เปิด `docs/02-game-design-locked.md` เทียบทีละตาราง: §1 gate, §2 base/tier/viral, §3 mental, §4 economy, §5 ending %

- [ ] **Step 9: Commit**

```bash
git add src/shared/Config
git commit -m "feat: Config 7 ตัว — ตัวเลขทั้งหมดจาก design doc"
```

---

### Task 4: Test scaffold + vidqTier/vidqMultiplier (TDD เริ่มที่นี่)

**Files:**
- Create: `tests/RunTests.lua` (mirror ของ `ServerScriptService.Tests.RunTests` ใน Studio)
- Create: `src/shared/Formulas.lua`

- [ ] **Step 1: เขียน scaffold + เทส tier (ยังไม่มี Formulas — ต้อง fail)**

```lua
-- tests/RunTests.lua
-- รันได้ 2 ทาง: local `lune run tests/RunTests.lua` | Studio: Script ใน ServerScriptService.Tests
--   (ใน Studio: ติ๊ก Enabled → Play → ดู Output → ติ๊กกลับ)
local isStudio = script ~= nil
local Formulas = isStudio
	and require(game:GetService("ReplicatedStorage").Shared.Formulas)
	or require("../src/shared/Formulas")

local pass, fail = 0, 0
local function check(name, ok)
	if ok then pass += 1 else fail += 1; print("FAIL: " .. name) end
end

-- rng ปลอม: คืนค่าจากคิวตามลำดับ (เอาไว้ fix ผลสุ่ม)
local function rngQueue(vals)
	local i = 0
	return function() i += 1; return vals[i] end
end

-- ===== vidqTier (design doc §2) =====
check("tier C ล่างสุด", Formulas.vidqTier(0) == "C")
check("tier C ขอบบน", Formulas.vidqTier(50) == "C")
check("tier B ขอบล่าง", Formulas.vidqTier(51) == "B")
check("tier B ขอบบน", Formulas.vidqTier(100) == "B")
check("tier A ขอบล่าง", Formulas.vidqTier(101) == "A")
check("tier A ขอบบน", Formulas.vidqTier(150) == "A")
check("tier S ขอบล่าง", Formulas.vidqTier(151) == "S")
check("tier S เต็ม", Formulas.vidqTier(200) == "S")
check("clamp เกิน 200", Formulas.vidqTier(999) == "S")
check("clamp ติดลบ", Formulas.vidqTier(-5) == "C")

-- ===== vidqMultiplier (design doc §2) =====
check("mult C", Formulas.vidqMultiplier("C") == 0.5)
check("mult B", Formulas.vidqMultiplier("B") == 1.0)
check("mult A", Formulas.vidqMultiplier("A") == 1.5)
check("mult S", Formulas.vidqMultiplier("S") == 2.0)

print(("Tests: %d passed, %d failed"):format(pass, fail))
if fail > 0 then error("มีเทสไม่ผ่าน") end
```

- [ ] **Step 2: รันให้ fail**

Run: `lune run tests/RunTests.lua`
Expected: error หา `../src/shared/Formulas` ไม่เจอ

- [ ] **Step 3: เขียน Formulas ขั้นต่ำ (แค่ tier + multiplier)**

```lua
-- ReplicatedStorage.Shared.Formulas
-- pure function ทั้งไฟล์ — ห้ามแตะ state / Roblox API (เทสได้ใน RunTests)
-- จุดสุ่มทุกจุดรับ rng() -> [0,1) เป็น parameter (default math.random) เพื่อให้เทส fix ค่าได้
local isStudio = script ~= nil
local function cfg(name)
	if isStudio then return require(script.Parent.Config[name]) end
	return require("./Config/" .. name)
end
local Phase = cfg("PhaseConfig")
local VidQ = cfg("VidQConfig")
local Viral = cfg("ViralConfig")
local Mental = cfg("MentalConfig")
local Ending = cfg("EndingConfig")

local Formulas = {}

function Formulas.vidqTier(score)
	score = math.clamp(score, 0, VidQ.maxScore)
	for _, t in VidQ.tiers do
		if score <= t.max then return t.name end
	end
end

function Formulas.vidqMultiplier(tier)
	for _, t in VidQ.tiers do
		if t.name == tier then return t.multiplier end
	end
	error("unknown tier: " .. tostring(tier))
end

return Formulas
```

- [ ] **Step 4: รันให้ผ่าน**

Run: `lune run tests/RunTests.lua`
Expected: `Tests: 14 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add tests/RunTests.lua src/shared/Formulas.lua
git commit -m "feat: Formulas.vidqTier + vidqMultiplier ผ่านเทสขอบทุกช่วง"
```

---

### Task 5: mentalMultiplier

**Files:**
- Modify: `src/shared/Formulas.lua`
- Modify: `tests/RunTests.lua`

- [ ] **Step 1: เพิ่มเทส (ต่อท้ายก่อนบรรทัด print สรุป)**

```lua
-- ===== mentalMultiplier (design doc §3 — 3 โซน) =====
local rng0 = function() return 0 end
local rngHi = function() return 0.999 end
check("โซนสูง ขอบล่าง rng=0 → 1.0", Formulas.mentalMultiplier(70, rng0) == 1.0)
check("โซนสูง rng สูง → เข้าใกล้ 1.25", Formulas.mentalMultiplier(100, rngHi) > 1.24)
check("โซนสูง ไม่ทะลุ cap 1.25", Formulas.mentalMultiplier(100, rngHi) <= 1.25)
check("โซนกลาง = 1.0 เสมอ (ล่าง)", Formulas.mentalMultiplier(40, rngHi) == 1.0)
check("โซนกลาง = 1.0 เสมอ (บน)", Formulas.mentalMultiplier(69, rng0) == 1.0)
check("โซนต่ำ rng=0 → 0.6", Formulas.mentalMultiplier(1, rng0) == 0.6)
check("โซนต่ำ ไม่เกิน 1.0", Formulas.mentalMultiplier(39, rngHi) <= 1.0)
check("mental 0 → 0 (Bad End 2 อยู่นอกสูตร)", Formulas.mentalMultiplier(0, rng0) == 0)
```

- [ ] **Step 2: รันให้ fail**

Run: `lune run tests/RunTests.lua`
Expected: FAIL — `mentalMultiplier` เป็น nil

- [ ] **Step 3: implement (เพิ่มก่อน `return Formulas`)**

```lua
function Formulas.mentalMultiplier(pct, rng)
	rng = rng or math.random
	for _, z in Mental.zones do
		if pct >= z.min then
			local lo, hi = z.multRange[1], z.multRange[2]
			return lo + (hi - lo) * rng()
		end
	end
	return 0 -- mental 0: ให้ MentalService ยิง Bad End 2 — สูตรแค่คืน 0
end
```

- [ ] **Step 4: รันให้ผ่าน**

Run: `lune run tests/RunTests.lua`
Expected: `Tests: 22 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add -u
git commit -m "feat: Formulas.mentalMultiplier 3 โซน cap 1.25"
```

---

### Task 6: followerGain + moneyGain

**Files:**
- Modify: `src/shared/Formulas.lua`
- Modify: `tests/RunTests.lua`

- [ ] **Step 1: เพิ่มเทส**

ลำดับ rng ใน followerGain (ต้องตรง implementation): ① base ② mentalMultiplier ③ viral chance ④ viral mult (ถ้าติด)

```lua
-- ===== followerGain (design doc §2: base × VidQ × mental, viral 12% ×4–8) =====
-- ลำดับ rng: base, mentalZone, viralChance, viralMult
local n, viral = Formulas.followerGain(1, "B", 50, rngQueue({ 0, 0, 0.5 }))
check("phase1 B mental กลาง ไม่ viral = base ต่ำสุด 400", n == 400 and viral == false)

n, viral = Formulas.followerGain(1, "S", 50, rngQueue({ 0, 0, 0.5 }))
check("tier S คูณ 2 → 800", n == 800 and viral == false)

n, viral = Formulas.followerGain(1, "B", 50, rngQueue({ 0, 0, 0.05, 0 }))
check("viral ติด (rng 0.05 < 0.12) คูณ 4 → 1600", n == 1600 and viral == true)

n, viral = Formulas.followerGain(1, "B", 50, rngQueue({ 0.999, 0, 0.5 }))
check("base สุ่มสูงสุด phase1 ≈ 900", n >= 898 and n <= 900)

n, viral = Formulas.followerGain(3, "B", 50, rngQueue({ 0, 0, 0.5 }))
check("phase3 base ต่ำสุด 9000", n == 9000)

-- ===== moneyGain (design doc §4: follower × rate) =====
check("rate phase1 0.8", Formulas.moneyGain(1000, 1) == 800)
check("rate phase2 1.2", Formulas.moneyGain(1000, 2) == 1200)
check("rate phase3 1.5", Formulas.moneyGain(1000, 3) == 1500)
check("ปัดเศษลง", Formulas.moneyGain(999, 1) == 799)
```

- [ ] **Step 2: รันให้ fail**

Run: `lune run tests/RunTests.lua`
Expected: FAIL — `followerGain` เป็น nil

- [ ] **Step 3: implement**

```lua
-- ลำดับเรียก rng (เทสอิงลำดับนี้): ① base ② mentalMultiplier ③ viral chance ④ viral mult
function Formulas.followerGain(phase, tier, mentalPct, rng)
	rng = rng or math.random
	local p = Phase[phase]
	local base = p.base[1] + (p.base[2] - p.base[1]) * rng()
	local n = base * Formulas.vidqMultiplier(tier) * Formulas.mentalMultiplier(mentalPct, rng)
	local isViral = rng() < Viral.chance
	if isViral then
		n = n * (Viral.multRange[1] + (Viral.multRange[2] - Viral.multRange[1]) * rng())
	end
	return math.floor(n), isViral
end

function Formulas.moneyGain(followers, phase)
	return math.floor(followers * Phase[phase].moneyRate)
end
```

- [ ] **Step 4: รันให้ผ่าน**

Run: `lune run tests/RunTests.lua`
Expected: `Tests: 31 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add -u
git commit -m "feat: Formulas.followerGain (viral 12%) + moneyGain"
```

---

### Task 7: resolveEnding

**Files:**
- Modify: `src/shared/Formulas.lua`
- Modify: `tests/RunTests.lua`

- [ ] **Step 1: เพิ่มเทส**

```lua
-- ===== resolveEnding (design doc §5 — priority: Bad3 → Good1 → Neutral1 → Neutral2) =====
local function stats(vC, vB, vA, vS, p, nu, m)
	return { vidq = { C = vC, B = vB, A = vA, S = vS }, choice = { plus = p, neutral = nu, minus = m } }
end

check("Bad3 ทาง vidq (C เยอะ)",
	Formulas.resolveEnding(stats(0.40, 0.30, 0.20, 0.10, 0.5, 0.3, 0.2)) == "Bad3")
check("Bad3 ทาง choice (⊖ ≥ 50%)",
	Formulas.resolveEnding(stats(0.10, 0.20, 0.50, 0.20, 0.3, 0.1, 0.6)) == "Bad3")
check("Good1 (vidq ดี AND choice ⊕ ท่วม)",
	Formulas.resolveEnding(stats(0.10, 0.20, 0.50, 0.20, 0.80, 0.10, 0.10)) == "Good1")
check("Good1 ไม่ผ่านถ้า choice ไม่ถึง (AND)",
	Formulas.resolveEnding(stats(0.10, 0.20, 0.50, 0.20, 0.50, 0.10, 0.40)) ~= "Good1")
check("Neutral1 ทาง balance |⊖−⊕|+◎ < 25%",
	Formulas.resolveEnding(stats(0.25, 0.50, 0.15, 0.10, 0.45, 0.05, 0.50)) == "Neutral1")
check("Neutral2 ตาข่ายรอง (vidq ผ่าน Cmax 26%)",
	Formulas.resolveEnding(stats(0.25, 0.30, 0.25, 0.20, 0.30, 0.30, 0.40)) == "Neutral2")
check("priority: เข้าได้ทั้ง Bad3+Good1 ต้องได้ Bad3",
	Formulas.resolveEnding(stats(0.40, 0.20, 0.20, 0.20, 0.80, 0.10, 0.10)) == "Bad3")
check("ไม่เข้าอะไรเลย → fallback Neutral2",
	Formulas.resolveEnding(stats(0.30, 0.40, 0.20, 0.10, 0.30, 0.30, 0.40)) == "Neutral2")
```

- [ ] **Step 2: รันให้ fail**

Run: `lune run tests/RunTests.lua`
Expected: FAIL — `resolveEnding` เป็น nil

- [ ] **Step 3: implement**

```lua
-- เช็คเงื่อนไขฝั่ง VidQ % ของ ending หนึ่งตัว (เงื่อนไขไหนไม่ระบุ = ไม่เช็ค)
local function vidqPass(c, v)
	if not c then return false end
	if c.Cmin and v.C < c.Cmin then return false end
	if c.Cmax and v.C > c.Cmax then return false end
	if c.Bmax and v.B > c.Bmax then return false end
	if c.Amin and v.A < c.Amin then return false end
	if c.Smax and v.S > c.Smax then return false end
	return true
end

-- เช็คเงื่อนไขฝั่ง choice % (plus/neutral/minus รวมกัน = 1)
local function choicePass(c, ch)
	if not c then return false end
	if c.balance then return math.abs(ch.minus - ch.plus) + ch.neutral < c.balance end
	if c.plusMin and ch.plus < c.plusMin then return false end
	if c.minusMin and ch.minus < c.minusMin then return false end
	if c.minusMax and ch.minus > c.minusMax then return false end
	if c.neutralMin and ch.neutral < c.neutralMin then return false end
	if c.neutralMax and ch.neutral > c.neutralMax then return false end
	return true
end

-- stats = { vidq = {C,B,A,S}, choice = {plus,neutral,minus} } — สัดส่วน 0–1
-- Bad1 (เงิน) / Bad2 (mental) trigger สดกลางเกม ไม่ผ่านฟังก์ชันนี้
function Formulas.resolveEnding(stats)
	for _, name in Ending.order do
		local e = Ending[name]
		local v = vidqPass(e.vidq, stats.vidq)
		local c = choicePass(e.choice, stats.choice)
		local hit = if e.combine == "AND" then (v and c) else (v or c)
		if hit then return name end
	end
	return "Neutral2" -- ถึง 1M แต่ไม่เข้าเงื่อนไขไหน — ending กลางสุดคือตาข่ายสุดท้าย
end
```

- [ ] **Step 4: รันให้ผ่าน**

Run: `lune run tests/RunTests.lua`
Expected: `Tests: 39 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add -u
git commit -m "feat: Formulas.resolveEnding — priority order + เงื่อนไข % ครบ 4"
```

---

### Task 8: ปิดงาน

- [ ] **Step 1: รันเทสทั้งชุดรอบสุดท้าย**

Run: `lune run tests/RunTests.lua`
Expected: `Tests: 39 passed, 0 failed`

- [ ] **Step 2: อัปเดตสถานะใน `docs/04-timeline.md`**

เพิ่มบรรทัดใน "สถานะจริง":
```
- ✅ Config + Formulas + เทส 39 ข้อ (19 ก.ค.) — repo `src/shared/` รอยกเข้า Studio
```

- [ ] **Step 3: Commit**

```bash
git add -u
git commit -m "docs: อัปเดตสถานะ timeline — Config+Formulas เสร็จ"
```

---

## Self-Review

- **Spec coverage:** design doc §1 gate→PhaseConfig ✓ | §2 สูตร follower/tier/viral→Task 4,6 ✓ | §3 mental 3 โซน→Task 5 ✓ | §4 economy→EconomyConfig+moneyGain ✓ | §5 ending % + priority→Task 7 ✓ | §6–8 (choice source, dialogue, cutscene) = นอก scope แผนนี้ (แผน service/UI ถัดไป)
- **Placeholder scan:** ไม่มี TBD/TODO — โค้ดเต็มทุก step ✓
- **Type consistency:** `stats.vidq{C,B,A,S}` + `choice{plus,neutral,minus}` ตรงกันทุก task ✓ | ลำดับ rng ใน followerGain ระบุใน comment + เทสอิงตรงกัน ✓
