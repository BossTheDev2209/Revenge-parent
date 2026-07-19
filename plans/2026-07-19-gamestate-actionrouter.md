# GameState + Save + ActionRouter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** กระดูกสันหลังของเกม — state ตารางเดียว + save 4 slot + ประตูรับ Action จาก client — ตาม docs/06 §3, docs/07 §3.2

**Architecture:** แยก pure logic (newGame/mergeDefaults/slotSummary/route — เทสได้ด้วย lune) ออกจาก Roblox glue (DataStore/Remotes — บางที่สุด verify ใน Studio ผ่าน MCP driver) ทุกไฟล์ dual-mode ตาม pattern `Formulas.luau` (`local isStudio = script ~= nil`)

**Tech Stack:** Luau, lune (`scratchpad/tools/lune.exe` — หายให้โหลดใหม่ตาม docs/08 §1), `tools/mcp_driver.py` สำหรับ sync Studio

**การตัดสินใจใน plan นี้:**
- `state.choices` ใช้ key `pos/neu/neg` ให้ตรงชื่อที่ `Formulas.resolveEnding` ใช้
- Continue = slot ที่ `savedAt` (os.time) ล่าสุด — ไม่ต้องมี key พิเศษ
- `mergeDefaults` เติม key ที่ขาดตอน load (save เก่าไม่พังเมื่อ state โตขึ้น = future proof)
- DataStore fail = warn + เล่นต่อ ไม่ crash (ใน Studio Edit mode fail เป็นปกติ)

---

### Task 1: เพิ่มตัวเลขที่ขาดใน Config (StartMoney + Time)

**Files:**
- Modify: `src/shared/Config.luau` (ท้ายไฟล์ ก่อน `return Config`)

- [ ] **Step 1: เพิ่ม section**

```lua
-- เงินตั้งต้น + เวลา — ที่มา: PDF ต้นฉบับหน้า 9, 6 (design doc ไม่ระบุ — flag ไว้แล้วใน docs/08)
Config.StartMoney = 2_500

Config.Time = {
	secondsPerGameHour = 7.5, -- 1 วันเกม = 3 นาทีจริง ÷ 24
	dayStartHour = 8,
	sleep = { normalHours = 8, windowStart = 18, windowEnd = 6, outsideHours = 12 },
}
```

- [ ] **Step 2: รันเทสเดิมต้องยังผ่าน (Config ไม่พัง)**

Run: `<lune> run tests/RunTests.luau`
Expected: `Tests: 46 passed, 0 failed`

- [ ] **Step 3: Commit**

```bash
git add src/shared/Config.luau
git commit -m "feat: Config.StartMoney + Config.Time (จาก PDF หน้า 9, 6)"
```

---

### Task 2: GameState pure logic (TDD)

**Files:**
- Create: `src/server/Services/GameState.luau`
- Modify: `tests/RunTests.luau`

- [ ] **Step 1: เทส RED — เพิ่ม require ที่หัวไฟล์เทส (ใต้ require Formulas)**

```lua
local GameState = if isStudio
	then require(game:GetService("ServerScriptService").Services.GameState)
	else require("../src/server/Services/GameState")
```

และเพิ่มก่อนบรรทัด print สรุป:

```lua
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
```

- [ ] **Step 2: รันให้ fail**

Run: `<lune> run tests/RunTests.luau`
Expected: error require GameState ไม่เจอ

- [ ] **Step 3: implement**

```lua
-- GameState.luau — state ตารางเดียวของทั้งเกม + save/load 4 slot
-- pure ส่วน: newGame / mergeDefaults / slotSummary (เทสด้วย lune)
-- Roblox glue: push / saveSlot / loadSlot / listSlots (ใช้ได้เฉพาะใน Studio)
-- กติกา: service แก้ state เสร็จต้องเรียก GameState.push(state) เสมอ ไม่งั้นจอไม่อัปเดต
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../shared/Formulas")

local GameState = {}

function GameState.newGame()
	return {
		follower = 0,
		money = Config.StartMoney,
		mental = Config.Mental.start,
		phase = 1,
		day = 1,
		timeOfDay = Config.Time.dayStartHour,
		clips = {},    -- {tier="B", uploaded=true, ...}
		choices = { pos = 0, neu = 0, neg = 0 }, -- ชื่อตรงกับ Formulas.resolveEnding
		upgrades = { camera = 1, storage = 1 },
		calendar = {}, -- [day] = {type=..., id=...}
		flags = {},    -- canon event ที่ผ่านแล้ว
		slot = 1,
		savedAt = 0,
	}
end

-- เติม key ที่ขาดจาก defaults (recursive) — save เก่าโหลดกับโค้ดใหม่แล้วไม่พัง
function GameState.mergeDefaults(loaded, defaults)
	for k, v in defaults do
		if loaded[k] == nil then
			loaded[k] = v
		elseif type(v) == "table" and type(loaded[k]) == "table" then
			GameState.mergeDefaults(loaded[k], v)
		end
	end
	return loaded
end

-- ข้อมูลย่อไว้โชว์หน้า save select (Main Menu)
function GameState.slotSummary(state)
	return {
		follower = state.follower,
		day = state.day,
		phase = Formulas.phaseFor(state.follower),
		savedAt = state.savedAt,
	}
end

return GameState
```

- [ ] **Step 4: รันให้ผ่าน**

Run: `<lune> run tests/RunTests.luau`
Expected: `Tests: 60 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add tests/RunTests.luau src/server/Services/GameState.luau
git commit -m "feat: GameState pure — newGame/mergeDefaults/slotSummary"
```

---

### Task 3: ActionRouter (TDD)

**Files:**
- Create: `src/server/Services/ActionRouter.luau`
- Modify: `tests/RunTests.luau`

- [ ] **Step 1: เทส RED — เพิ่ม require**

```lua
local ActionRouter = if isStudio
	then require(game:GetService("ServerScriptService").Services.ActionRouter)
	else require("../src/server/Services/ActionRouter")
```

เพิ่มเทสก่อน print สรุป:

```lua
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
```

- [ ] **Step 2: รันให้ fail**

Run: `<lune> run tests/RunTests.luau`
Expected: error require ActionRouter ไม่เจอ

- [ ] **Step 3: implement**

```lua
-- ActionRouter.luau — ประตูรับทุกการกระทำจาก client เส้นเดียว
-- service ลงทะเบียน handler ด้วย register(type, fn) ตอน boot (ใน Main)
-- เพิ่มฟีเจอร์ใหม่ = register type ใหม่ — ห้ามสร้าง RemoteEvent เพิ่ม (docs/06 §3)
local ActionRouter = {}
local handlers = {}

function ActionRouter.register(actionType: string, fn)
	assert(handlers[actionType] == nil, "handler ซ้ำ: " .. actionType)
	handlers[actionType] = fn
end

-- คืน true ถ้ามี handler รับ, false ถ้า action เพี้ยน/ไม่รู้จัก (ไม่ crash — client ส่งมั่วได้)
function ActionRouter.route(state, action): boolean
	local h = type(action) == "table" and action.type and handlers[action.type]
	if not h then
		warn("[ActionRouter] action ไม่รู้จัก:", action and tostring(action.type) or "nil")
		return false
	end
	h(state, action)
	return true
end

return ActionRouter
```

- [ ] **Step 4: รันให้ผ่าน**

Run: `<lune> run tests/RunTests.luau`
Expected: `Tests: 65 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add tests/RunTests.luau src/server/Services/ActionRouter.luau
git commit -m "feat: ActionRouter — register/route + กัน type มั่วจาก client"
```

---

### Task 4: Roblox glue — push/save/load + Main.server

**Files:**
- Modify: `src/server/Services/GameState.luau` (ต่อท้ายก่อน `return GameState`)
- Create: `src/server/Main.server.luau`

ส่วนนี้แตะ Roblox API — lune เทสไม่ได้ verify ใน Studio (Task 5)

- [ ] **Step 1: เพิ่ม glue ใน GameState**

```lua
-- ===== Roblox glue (Studio เท่านั้น — lune ไม่แตะส่วนนี้) =====
local DATASTORE_NAME = "SaveSlots_v1"
local MAX_SLOTS = 4

local function store()
	return game:GetService("DataStoreService"):GetDataStore(DATASTORE_NAME)
end

local dirty = false

-- ยิง state ทั้งก้อนให้ client + ตั้ง dirty รอ autosave (docs/06 §3)
function GameState.push(state)
	dirty = true
	local remote = game:GetService("ReplicatedStorage").Shared.Remotes.StateChanged
	remote:FireAllClients(state)
end

function GameState.isDirty()
	return dirty
end

-- ทุกจุดแตะ DataStore ห่อ pcall — fail = warn + เล่นต่อ (Edit mode fail เป็นเรื่องปกติ)
function GameState.saveSlot(userId: number, state)
	state.savedAt = os.time()
	local ok, err = pcall(function()
		store():SetAsync(userId .. "_" .. state.slot, state)
	end)
	if ok then dirty = false else warn("[GameState] save ไม่สำเร็จ:", err) end
	return ok
end

function GameState.loadSlot(userId: number, slot: number)
	local ok, data = pcall(function()
		return store():GetAsync(userId .. "_" .. slot)
	end)
	if not ok or data == nil then return nil end
	data.slot = slot
	return GameState.mergeDefaults(data, GameState.newGame())
end

-- คืน {[slot] = summary} เฉพาะ slot ที่มี save — หน้า Main Menu ใช้ (Continue = savedAt มากสุด)
function GameState.listSlots(userId: number)
	local out = {}
	for slot = 1, MAX_SLOTS do
		local data = GameState.loadSlot(userId, slot)
		if data then out[slot] = GameState.slotSummary(data) end
	end
	return out
end
```

- [ ] **Step 2: รันเทสเดิมต้องยังผ่าน (glue ไม่พัง pure ส่วน)**

Run: `<lune> run tests/RunTests.luau`
Expected: `Tests: 65 passed, 0 failed`
(glue อยู่หลัง guard `isStudio` ไม่ถูกเรียกใน lune — แต่ต้อง parse ผ่าน)

- [ ] **Step 3: Main.server.luau**

```lua
-- Main.server.luau — จุดเริ่มเดียวของ server: wiring ทุกอย่างอยู่ไฟล์นี้ไฟล์เดียว
-- อยากรู้ว่าอะไรต่อกับอะไร อ่านไฟล์นี้ (docs/07 §2)
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameState = require(SSS.Services.GameState)
local ActionRouter = require(SSS.Services.ActionRouter)

local state = GameState.newGame()

-- client action ทุกอันวิ่งผ่านเส้นนี้เส้นเดียว
RS.Shared.Remotes.Action.OnServerEvent:Connect(function(player, action)
	ActionRouter.route(state, action)
end)

-- ผู้เล่นเข้า → ส่ง state ปัจจุบันให้ทันที
Players.PlayerAdded:Connect(function(player)
	GameState.push(state)
end)

-- autosave ทุก 60 วิ ถ้ามีอะไรเปลี่ยน + ตอนปิดเกม
task.spawn(function()
	while true do
		task.wait(60)
		local player = Players:GetPlayers()[1]
		if player and GameState.isDirty() then
			GameState.saveSlot(player.UserId, state)
		end
	end
end)

game:BindToClose(function()
	local player = Players:GetPlayers()[1]
	if player then GameState.saveSlot(player.UserId, state) end
end)
```

- [ ] **Step 4: Commit**

```bash
git add src/server/Services/GameState.luau src/server/Main.server.luau
git commit -m "feat: GameState glue (push/save 4 slot) + Main.server wiring"
```

---

### Task 5: Sync เข้า Studio + verify

**Files:**
- ใช้ `tools/mcp_driver.py` (วิธี + gotchas: docs/08 §0)

- [ ] **Step 1: สร้าง batch sync**

Python builder อ่าน 4 ไฟล์ (`Config.luau` ที่แก้, `GameState.luau`, `ActionRouter.luau`, `Main.server.luau`) ห่อ `[=====[ ]=====]` แล้ว `put()` แบบเดียวกับรอบแรก (ดู commit `e89fd6b`):
- `Shared.Config` ← Source ใหม่ (มีอยู่แล้ว — เขียนทับได้ เป็นของเรา)
- `Services.GameState` (ModuleScript ใหม่)
- `Services.ActionRouter` (ModuleScript ใหม่)
- `Main` (Script ใหม่ ใน ServerScriptService — **ไม่ Disabled** รันจริง)
- `Tests.RunTests` ← Source ใหม่ (65 เทส)

- [ ] **Step 2: verify ใน Studio ผ่าน execute_luau**

loadstring RunTests + setfenv (สูตรเดียวกับ docs/08 §0)
Expected: console `Tests: 65 passed, 0 failed`

- [ ] **Step 3: อัปเดต docs**

`docs/04-timeline.md` สถานะ + `docs/08` §1 ตาราง (GameState/ActionRouter/Main ใน Studio แล้ว)

- [ ] **Step 4: Commit**

```bash
git add -u
git commit -m "feat: sync GameState/ActionRouter/Main เข้า Studio — เทส 65/65 ใน Studio"
```

---

## Self-Review

- **Spec coverage:** docs/06 §3 state shape → Task 2 ✓ | Remote 2 เส้น → Main ใช้ Action/StateChanged ที่สร้างแล้ว ✓ | 4 slot + Continue ล่าสุด → savedAt ✓ | docs/07 §3.2 push/pcall/กติกา push ✓
- **Placeholder scan:** ไม่มี ✓
- **Type consistency:** `choices{pos,neu,neg}` ตรง Formulas ✓ | `GameState.mergeDefaults(loaded, defaults)` ลำดับ arg ตรงกันทุกที่ ✓ | require path lune: `../../shared/Config` จาก `src/server/Services/` ✓
- **หมายเหตุ:** Menu UI (Continue/เลือก slot) นอก scope — action `LoadSlot/SaveSlot` ยังไม่ register (YAGNI รอแผน UI)
