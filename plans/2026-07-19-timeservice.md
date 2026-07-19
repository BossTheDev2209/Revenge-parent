# TimeService Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** นาฬิกากลางของเกม — tick รายชั่วโมง, onHour/onDay callback, freeze, นอนข้ามเวลา — ตาม docs/07 §3.1 + PDF หน้า 6

**Architecture:** logic ทั้งหมด pure (tick/callback/sleep — เทสด้วย lune) — Roblox glue มีแค่ `start()` = loop `task.wait` เรียก `tick` ระบบอื่นสมัครฟังผ่าน onHour/onDay, wiring อยู่ใน Main ที่เดียว

**Tech Stack:** Luau, lune, `tools/mcp_driver.py` (sync Studio — จำ gotcha require cache: Destroy+สร้างใหม่, docs/08 §0)

**การตัดสินใจ:**
- tick = 1 ชั่วโมงเกม (7.5 วิจริง จาก `Config.Time.secondsPerGameHour`) — mental drain ละเอียดกว่านี้เป็นเรื่องของ MentalService plan หน้า
- `sleep()` เดินเวลาทีละชั่วโมงผ่าน tick ปกติ → onDay ยิงถูกจังหวะเสมอ ไม่ต้องมี logic ข้ามวันแยก
- กติกานอน (PDF หน้า 6): เริ่มนอนช่วง 18:00–5:59 = ข้าม 8 ชม. | นอกช่วง = ข้าม 12 ชม.
- หักค่าเช่าราย 7 วัน = รอ MoneyService (แผนถัดไป) — TimeService แค่เปิดช่อง onDay ไว้

---

### Task 1: TimeService pure (TDD)

**Files:**
- Create: `src/server/Services/TimeService.luau`
- Modify: `tests/RunTests.luau`

- [ ] **Step 1: เทส RED — เพิ่ม require (ใต้ require ActionRouter)**

```lua
local TimeService = if isStudio
	then require(game:GetService("ServerScriptService").Services.TimeService)
	else require("../src/server/Services/TimeService")
```

เพิ่มเทสก่อน print สรุป:

```lua
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
```

- [ ] **Step 2: รันให้ fail**

Run: `<lune> run tests/RunTests.luau`
Expected: error require TimeService ไม่เจอ

- [ ] **Step 3: implement**

```lua
-- TimeService.luau — นาฬิกากลางของเกม: tick รายชั่วโมงเกม
-- ระบบอื่นห้ามนับเวลาเอง — สมัครฟังผ่าน onHour/onDay (wiring ใน Main ที่เดียว)
-- pure ทั้งไฟล์ยกเว้น start() (Roblox loop)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")

local TimeService = {}
local hourFns, dayFns = {}, {}
local frozen = false

function TimeService.onHour(fn) table.insert(hourFns, fn) end
function TimeService.onDay(fn) table.insert(dayFns, fn) end

function TimeService.setFrozen(b: boolean) frozen = b end -- dialogue/cutscene เรียก
function TimeService.isFrozen(): boolean return frozen end

-- เดินเวลา 1 ชั่วโมงเกม + ยิง callback (no-op ถ้า frozen)
function TimeService.tick(state)
	if frozen then return end
	state.timeOfDay += 1
	if state.timeOfDay >= 24 then
		state.timeOfDay = 0
		state.day += 1
		for _, f in dayFns do f(state) end
	end
	for _, f in hourFns do f(state) end
end

-- PDF หน้า 6: เริ่มนอนช่วง 18:00–5:59 ข้าม 8 ชม. | นอกช่วงข้าม 12 ชม.
function TimeService.sleepHours(hour: number): number
	local s = Config.Time.sleep
	local inWindow = hour >= s.windowStart or hour < s.windowEnd
	return inWindow and s.normalHours or s.outsideHours
end

-- นอน: เดินเวลาทีละชั่วโมงผ่าน tick ปกติ → onDay/onHour ยิงถูกจังหวะเอง
function TimeService.sleep(state)
	for _ = 1, TimeService.sleepHours(state.timeOfDay) do
		TimeService.tick(state)
	end
end

-- ===== Roblox glue (Studio เท่านั้น) =====
function TimeService.start(state)
	task.spawn(function()
		while true do
			task.wait(Config.Time.secondsPerGameHour)
			TimeService.tick(state)
		end
	end)
end

return TimeService
```

- [ ] **Step 4: รันให้ผ่าน**

Run: `<lune> run tests/RunTests.luau`
Expected: `Tests: 78 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add tests/RunTests.luau src/server/Services/TimeService.luau
git commit -m "feat: TimeService — tick/onHour/onDay/freeze/sleep ตามกติกา PDF หน้า 6"
```

---

### Task 2: Wiring ใน Main

**Files:**
- Modify: `src/server/Main.server.luau`

- [ ] **Step 1: เพิ่ม require + start + push รายชั่วโมง (ใต้ require ActionRouter)**

```lua
local TimeService = require(SSS.Services.TimeService)
```

ท้ายไฟล์ (ก่อน BindToClose):

```lua
-- นาฬิกาเกม: เดินตลอด, ทุกชั่วโมงเกม push state (client เห็นนาฬิกา/วันขยับ)
TimeService.onHour(function(s)
	GameState.push(s)
end)
TimeService.start(state)
```

- [ ] **Step 2: เทสเดิมยังผ่าน**

Run: `<lune> run tests/RunTests.luau`
Expected: `Tests: 78 passed, 0 failed`

- [ ] **Step 3: Commit**

```bash
git add src/server/Main.server.luau
git commit -m "feat: wiring TimeService ใน Main — นาฬิกาเดิน + push รายชั่วโมง"
```

---

### Task 3: Sync Studio + verify

- [ ] **Step 1: sync ผ่าน `tools/mcp_driver.py`** — replace (Destroy+สร้างใหม่ตาม gotcha docs/08 §0): `Services.TimeService` (ใหม่), `Main` (Script), `Tests.RunTests`

- [ ] **Step 2: verify** — loadstring RunTests + setfenv → Expected: `Tests: 78 passed, 0 failed`

- [ ] **Step 3: อัปเดต `docs/04-timeline.md` + `docs/08` ตารางสถานะ → commit**

```bash
git add -u
git commit -m "feat: sync TimeService เข้า Studio — เทส 78/78"
```

---

## Self-Review

- **Spec coverage:** docs/07 §3.1 loop เดียว ✓ onHour/onDay ✓ freeze ✓ | PDF หน้า 6 กติกานอน 8/12 + ช่วง 18–6 ✓ | ค่าเช่า/calendar = แผน MoneyService/Calendar ถัดไป (ระบุแล้ว)
- **Placeholder scan:** ไม่มี ✓
- **Type consistency:** `state.timeOfDay/day` ตรง GameState.newGame ✓ | callback รับ `(state)` ทุกตัว ✓
- **หมายเหตุ:** callback ที่ register ในเทสจะติดอยู่ใน module state ตลอดการรันเทส — เทสหลังจากนี้ที่เรียก tick ต้องรู้ว่า counter ขยับ (ใช้ snapshot before แบบเทสนอนแล้ว)
