# Edit QTE + InteractBinder + Activity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ผู้เล่นเล่น loop เต็มโดยไม่พิมพ์ command: เดินไป `Interact_Camera` → QTE 20 ปุ่ม → คะแนน → FinishEdit → ปุ่มอัปโหลด → follower ขยับ + activity ฟื้นใจ (Bed/Kitchen/Exercise พร้อม streak/cooldown)

**Architecture:** EditQTE = pure scoring (`scoreFor`/`pickKeys` — lune เทสได้) + UI glue (overlay สร้างเอง รอทีมทำ Gui จริง) | InteractBinder = client แปะ ProximityPrompt runtime (ไม่แปะใน Edit DataModel — ตรงกฎ docs/05 §5 ที่ห้ามทีมใส่เอง) | Activity = `MentalService.doActivity` (PDF หน้า 6: ติดกัน 3 ครั้ง → cooldown 1 วันเกม)

**Tech Stack:** Luau, lune, mcp_driver (gotchas docs/08 §0)

**Spec QTE (PDF หน้า 7 + docs/07 §3.4):** 20 ปุ่มจาก Q W E A S D Z X C, ปุ่มละ 1.5 วิ, คะแนน/ปุ่ม = `10 × (1 − |t − 0.75| / 0.75)` ปัดลง, เต็ม 200, กดผิด/ไม่กด = 0

---

### Task 1: Config + GameState รองรับ activity

- `Config.Mental` เพิ่ม `activity = { maxStreak = 3, cooldownDays = 1 }` (PDF หน้า 6)
- `GameState.newGame()` เพิ่ม field `activity = { streak = 0, cooldownUntilDay = 0 }`
- เทสเดิมต้องผ่าน (mergeDefaults ทำให้ save เก่าได้ field ใหม่ฟรี)
- Commit: `feat: Config.Mental.activity + state.activity`

### Task 2: MentalService.doActivity (TDD)

เทส:

```lua
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
```

implement (ต่อท้าย MentalService ก่อน return):

```lua
-- Activity system (แทน Thai mini-games — design doc §9): Interact_Bed/Kitchen/Exercise
local ACTIVITY_REASON = { Bed = "activityRest", Kitchen = "activityEat", Exercise = "activityExercise" }

-- คืน true ถ้าทำได้ (client ค่อยเล่น cutscene 5-10 วิ) — ติดกันเกิน maxStreak = cooldown ข้ามวัน
function MentalService.doActivity(state, name): boolean
	local reason = ACTIVITY_REASON[name]
	if not reason then return false end
	if state.day < state.activity.cooldownUntilDay then return false end
	state.activity.streak += 1
	if state.activity.streak >= Config.Mental.activity.maxStreak then
		state.activity.cooldownUntilDay = state.day + Config.Mental.activity.cooldownDays
		state.activity.streak = 0
	end
	MentalService.apply(state, reason)
	return true
end
```

Commit: `feat: MentalService.doActivity — streak 3 + cooldown 1 วัน`

### Task 3: EditQTE pure scoring (TDD)

**Files:** Create `src/client/UI/Apps/EditQTE.luau`

เทส:

```lua
-- ===== EditQTE scoring (PDF หน้า 7 — กดกลาง window เป๊ะ = 10) =====
check("กดกลาง window (0.75s) = 10", EditQTE.scoreFor(0.75, 1.5) == 10)
check("กดทันทีที่ขึ้น (0s) = 0", EditQTE.scoreFor(0, 1.5) == 0)
check("กดวินาทีสุดท้าย = 0", EditQTE.scoreFor(1.5, 1.5) == 0)
check("กดครึ่งทางถึงกลาง = 5", EditQTE.scoreFor(0.375, 1.5) == 5)
check("ไม่ติดลบ", EditQTE.scoreFor(99, 1.5) == 0)
local keys = EditQTE.pickKeys(20, { "Q", "W", "E" }, rngQueue({
	0, 0.4, 0.9, 0, 0.4, 0.9, 0, 0.4, 0.9, 0, 0.4, 0.9, 0, 0.4, 0.9, 0, 0.4, 0.9, 0, 0.4 }))
check("pickKeys ครบ 20 ตัว", #keys == 20)
check("rng fix เลือกถูกตัว", keys[1] == "Q" and keys[2] == "W" and keys[3] == "E")
```

implement — pure ส่วน:

```lua
-- EditQTE.luau — มินิเกมตัดคลิป (docs/07 §3.4): 20 ปุ่ม 1.5 วิ/ปุ่ม เต็ม 200
-- pure: scoreFor / pickKeys (lune เทส) | UI glue: start() overlay สร้างเอง (รอทีมทำ Gui_Computer)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../../shared/Formulas")

local EditQTE = {}

-- คะแนนต่อปุ่ม: กดตรงกลาง window เป๊ะ = 10, ขอบ = 0 (ปัดลง)
function EditQTE.scoreFor(t: number, window: number): number
	local half = window / 2
	return math.max(0, math.floor(10 * (1 - math.abs(t - half) / half)))
end

function EditQTE.pickKeys(count: number, keys, rng)
	rng = rng or math.random
	local out = {}
	for i = 1, count do
		out[i] = keys[math.floor(rng() * #keys) + 1]
	end
	return out
end
```

UI glue (ต่อในไฟล์เดียวกัน — Studio เท่านั้น): overlay ScreenGui + label ปุ่ม + แถบเวลา (Heartbeat), `UserInputService.InputBegan` จับปุ่มแรกใน window, จบ 20 ปุ่ม → `fireAction({type="FinishEdit", score=total})` → จอสรุป (คะแนน + tier จาก `Formulas.vidqTier`) + ปุ่ม "อัปโหลดเลย" → `fireAction({type="UploadClip", clip="latest"})` + ปุ่มปิด, กัน start ซ้อนด้วย `EditQTE.running`

Commit: `feat: EditQTE — pure scoring + UI overlay 20 ปุ่ม`

### Task 4: InteractBinder + wiring

**Files:** Create `src/client/InteractBinder.luau` | Modify `src/server/Main.server.luau`, `src/client/Main.client.luau`

- InteractBinder: scan `workspace:GetDescendants()` + `DescendantAdded` → เจอชื่อ `Interact_*` แปะ ProximityPrompt แล้วโยงตามตาราง: Camera → startQTE | Bed/Kitchen/Exercise → `DoActivity` | อื่น → warn ยังไม่ผูก
- Main.server: register `DoActivity` → `MentalService.doActivity(s, a.activity)` | `UploadClip` handler รองรับ `clip="latest"` (= `#s.clips`)
- Main.client: require ทั้งคู่ + `InteractBinder.init({fireAction=..., startQTE=...})`
- ถ้า Workspace ยังไม่มี `Interact_Camera` (ทีมยังไม่วาง): sync สร้าง placeholder part neon 2×2×2 ใกล้ spawn (ทีมย้ายทีหลังได้ — เป็นชื่อตาม convention docs/05 §3 อยู่แล้ว)

Commit: `feat: InteractBinder + wiring DoActivity/UploadClip latest`

### Task 5: Sync + verify + Play smoke

- replace ทุกไฟล์ที่แตะ (รวม stateful reset: ActionRouter/TimeService) + client ใหม่ + placeholder parts (Interact_Camera/Bed/Kitchen/Exercise ถ้ายังไม่มี)
- verify loadstring → เทสทั้งหมดผ่าน | Play 15 วิ → console สะอาด → stop
- docs/04 + docs/08 + commit

---

## Self-Review

- **Coverage:** QTE spec 20/1.5s/200 ✓ scoring สูตร docs/07 ✓ activity streak/cooldown PDF หน้า 6 ✓ Interact_ ตาม docs/05 §3 ✓ prompt แปะ runtime ไม่แตะ Edit DataModel ✓
- **Type consistency:** `DoActivity{activity="Bed|Kitchen|Exercise"}` ตรง `ACTIVITY_REASON` ✓ `clip="latest"` แปลงใน Main ก่อนถึง service ✓ path lune `../../../shared/Config` จาก `src/client/UI/Apps/` ✓
- **หมายเหตุ:** cutscene activity 5-10 วิ = แค่ freeze สั้นฝั่ง client ยังไม่ทำ (รอ CutscenePlayer) — mental ฟื้นทันทีไปก่อน
