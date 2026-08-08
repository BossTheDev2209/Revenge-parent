# EditQTE — Osu-style Concurrent Circles + Mobile Tap + Responsive

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** ผู้เล่นเล่น QTE เดิม (`Interact_Camera` → ตัดคลิป) แต่กลไกเปลี่ยนจาก "กดตัวอักษรสุ่มทีละตัวกลางจอ (คีย์บอร์ดอย่างเดียว)" เป็น "แตะ/คลิกวงกลม 2-4 วงที่โผล่พร้อมกันทั่วจอ วงแหวนหดเข้าหาวงเป้าหมาย" แบบ osu — เล่นได้เหมือนกันทั้ง PC และมือถือโดยไม่มี branch แยก platform

**บริบท:** user (สาย A ผลิตคลิป) ตัดสินใจเรื่องนี้เอง 8 ส.ค. 2569 ผ่านการ brainstorm ในแชท — ไม่ใช่ requirement จาก docs เดิม เก็บ log การตัดสินใจไว้ที่นี่แทน (docs/07 §3.4 / docs/09 §5 เป็นแค่ draft ที่ตามหลัง ต้องอัปเดตให้ตรง)

**Architecture:** เหมือนเดิม — `EditQTE.luau` = pure functions (เทสด้วย lune/pcall harness) + UI glue (Studio เท่านั้น) ไม่แตะ server เลย (`FinishEdit` รับแค่ `score` 0-200 รวม ไม่สนใจว่าประกอบมายังไง)

**แก้เพิ่มรอบ 5 (8 ส.ค. — พื้นหลัง mock เต็มรูปแบบ) — user feedback (อ้างภาพ Premiere Pro):**
- `buildEditorMock` วาดฉากหลังจำลองโปรแกรมตัดต่อ (แทน gradient เปล่า) ZIndex 0-1 ใต้วง QTE:
  toolbar บน · media bin ซ้าย · **effect panel ขวา** (Effect Controls: Motion/Position/Scale/Rotation/Opacity/Time Remap + ค่าจำลอง) · timeline หลายแทร็ก+clip+playhead ล่าง
- **preview กลางเปลี่ยนตาม progress เนื้อเรื่อง:** `EditQTE.previewCoverKey(phase)` เลือก `UIAssets.clip_cover_N`
  ตามเฟส (1→1/2, 2→3/4, 3→5/6) · มีรูป = ImageLabel + overlay มืดให้วงเด่น · ยังไม่มีรูป = placeholder "🎞️ คลิปเฟส N"
- ใส่รูปจริงทีหลัง: `edit_workspace_bg` (ทั้งฉาก) หรือ `clip_cover_1..6` (เฉพาะ preview กลาง) — โค้ดใช้อัตโนมัติ

**แก้เพิ่มรอบ 4 (8 ส.ค. — alternate version "duo") — user feedback:**
- ทำ **2 เวอร์ชันเลือกได้** ด้วย preset (สลับ `EditQTE.MODE` บรรทัดเดียว ไม่ duplicate โค้ด):
  - `flow` = ไหลต่อเนื่องมากสุด ~4 อันบนจอ (ของรอบ 3)
  - `duo` = มากสุด **2 อัน**บนจอ ตำแหน่ง**ไม่ซ้อนกัน** (อ่านง่าย ไม่ตาลาย) — default ตอนนี้
- preset คุม `maxOnScreen` / `spawnInterval` / `approach` · round loop รอ `active < maxOnScreen` ก่อนเด้งอันใหม่
- `pickPosition` เปลี่ยนเป็น **best-of-12** (สุ่มผู้สมัคร 12 จุด เลือกอันไกลจากวง active สุด) กันวงใหม่ทับวงเดิม
- ★ บั๊กที่เจอ+แก้: วงกดแล้วโชว์สี tier ค้าง 0.25 วิ ก่อนหาย — เดิมปลด active/ตำแหน่ง**ทันทีที่กด** ทำให้
  นับวงบนจอไม่ครบ (เห็น 3 ทั้งที่ cap 2) + วงใหม่โผล่ทับวงที่กำลัง fade (gap 0.019) →
  แยก `onResolve` (คะแนน/เสียง ตอนกด) ออกจาก `onCleared` (คืน slot/ตำแหน่ง/คีย์ ตอน destroy จริง)
  → เทสหลังแก้: max 2 อัน · gap 0.459 (ไม่ทับ)

**แก้เพิ่มรอบ 3 (8 ส.ค. — เปลี่ยนจาก "เวฟ block" เป็น "chain") — user feedback:**
- **ไม่แบ่ง block แล้ว:** เดิมแบ่งเป็นเวฟ 2-4 วง รอครบเวฟ · เปลี่ยนเป็น **chain เดียว 20 วง**ที่เด้งทีละอันต่อเนื่อง (ห่างกัน `SPAWN_INTERVAL` 0.45 วิ) วงก่อนหน้ายังหดค้างบนจอ → ~3-4 อันซ้อนกันพร้อมกัน ไหลไม่ขาด (เหมือน osu จริง)
- **stagger หายไปเอง:** ไม่ต้องมี `startDelay` แล้ว เพราะการ spawn ทีละอันห่างกันคือ stagger ในตัว — วงโผล่ปุ๊บเริ่มหดทันที
- **เสียงตามเกรด (variant SFX):** เล่นเสียงตอนกดแต่ละวงตาม tier (S/A/B/C) ผ่าน `AudioService.sfx(name)` (ระบบเสียงกลาง คุม master volume ให้) · **user แก้ได้ที่ `EditQTE.SFX`** (map tier → ชื่อ Sound ใน `SoundService.SFX`) — ทีมเสียงวาง Sound ชื่อ `qte_perfect`/`qte_good`/`qte_ok`/`qte_miss` แล้วเล่นเอง ยังไม่มี = เงียบ (warn once ไม่พัง)
- **pure ใหม่:** `pickFreeKey` (เลือกคีย์ว่างไม่ชนวง active) แทน `pickKeysUnique` · `pickPosition` (สุ่ม 1 ตำแหน่งเลี่ยงวง active) แทน `randomPositions` · ลบ `planWaves` ทิ้ง

**แก้เพิ่มรอบ 2 (8 ส.ค. หลังเทสรอบแรก) — user feedback:**
- **การหดเหลื่อมกัน (stagger):** ทุกวงในเวฟยัง**โผล่พร้อมกัน** (เห็นล่วงหน้า) แต่วงแหวนเริ่ม**หดไล่กัน** — วงที่ 1 หดก่อน วงที่ 2 หดตามหลัง `STAGGER` วิ ระหว่างรอ ring คงขนาดเต็ม (ยังไม่หด · กดตอนยังไม่หด = 0 คะแนน กันกดมั่ว)
- **Input แยก platform (เปลี่ยนจากรอบแรกที่ใช้ .Activated เดียว):**
  - **PC (มีคีย์บอร์ด):** วงแสดง**ตัวอักษร** (สุ่มไม่ซ้ำต่อเวฟจาก `KEY_POOL`) กดคีย์นั้น → resolve วงนั้น · คลิกเมาส์บนวงก็ได้ผลด้วย (.Activated)
  - **Mobile (ไม่มีคีย์บอร์ด):** วงแสดง**เลขลำดับ** 1..N แตะวง (.Activated)
  - ตรวจด้วย `UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled`

**Spec ที่ล็อกจากแชท 8 ส.ค.:**
- รวม 20 วงเหมือนเดิม (`TOTAL_HITS`) แต่จัดเป็น **เวฟ**: สุ่มขนาดเวฟ 2-4 วง (`MIN_CONCURRENT`/`MAX_CONCURRENT`) โผล่พร้อมกันทั้งเวฟ รอครบทุกวงในเวฟ (กด/พลาด/หมดเวลา) ก่อนขึ้นเวฟถัดไป จนครบงบ 20 (เวฟสุดท้ายอาจเล็กกว่า 2 ถ้างบเหลือไม่พอ)
- วงแหวนหด 1.5 วิ/วง (`APPROACH_TIME` เดิม `QTE_WINDOW`) **คะแนนพีคตอนวงแหวนหดมาเท่าวงเป้าหมายพอดี (t=window)** ไม่ใช่กลาง window แบบเดิม — ไล่เส้นตรง 0→10
- Label กลางวง = **เลขลำดับ 1..N ในเวฟนั้น** (ไม่ใช่ตัวอักษรให้พิมพ์)
- Input: **`.Activated` ของปุ่มวงกลมเท่านั้น** — ไม่มี `UserInputType.Keyboard`/`Touch` branch แยกอีกต่อไป (Roblox ยิง Activated ให้ทั้งคลิกเมาส์+แตะจอเอง)
- พลาด (ไม่กดในเวลา) = แดง, 0 คะแนน, เข้า bucket C เหมือนกดคะแนนต่ำ
- สี 4 tier: เขียว=S(≥9) / ฟ้า=A(≥6) / เหลือง=B(≥3) / แดง=C(<3 หรือพลาด) — ผูกกับ bucket เดิมในโค้ด ไม่ต้องคิดใหม่
- Responsive: reuse `ShopKiosk.fitScale` pattern (`UIScale` + `AnchorPoint(0.5,0.5)`)
- ใช้ `UIAssets.edit_workspace_bg`/`qte_ring_outer`/`qte_ring_target` ถ้ามี (ยังว่างทุกช่อง ณ 8 ส.ค.) ไม่มี = fallback โปรแกรมมิ่ง (Frame+UIGradient+UIStroke ธีมเข้ม)

**Tech Stack:** Luau, lune (pcall harness ผ่าน `mcp_driver.py`), Roblox Studio MCP

---

### Task 1: Pure functions ใหม่ (TDD)

**Files:** Modify `src/client/UI/Apps/EditQTE.luau`, `tests/RunTests.luau`

ลบเทสเดิม (บรรทัด 476-485 `tests/RunTests.luau`) แทนด้วย:

```lua
-- ===== EditQTE scoring ใหม่ (redesign 8 ส.ค. — พีคตอนวงแหวนปิดพอดี ไม่ใช่กลาง window) =====
check("วงแหวนปิดพอดี (t=window) = 10 เต็ม", EditQTE.scoreFor(1.5, 1.5) == 10)
check("กดทันทีที่โผล่ (t=0) = 0", EditQTE.scoreFor(0, 1.5) == 0)
check("กดครึ่งทาง = 5", EditQTE.scoreFor(0.75, 1.5) == 5)
check("กด 90% ทาง ~9", EditQTE.scoreFor(1.35, 1.5) == 9)
check("ไม่ติดลบ (t เกิน window)", EditQTE.scoreFor(99, 1.5) == 0)
check("t ติดลบไม่พัง", EditQTE.scoreFor(-1, 1.5) == 0)

-- ===== tierFor / colorFor (สี 4 ระดับ ผูก S/A/B/C) =====
check("9-10 = S (เขียว)", EditQTE.tierFor(10) == "S" and EditQTE.tierFor(9) == "S")
check("6-8 = A (ฟ้า)", EditQTE.tierFor(6) == "A" and EditQTE.tierFor(8) == "A")
check("3-5 = B (เหลือง)", EditQTE.tierFor(3) == "B" and EditQTE.tierFor(5) == "B")
check("0-2 = C (แดง)", EditQTE.tierFor(0) == "C" and EditQTE.tierFor(2) == "C")
check("colorFor คืน Color3 ครบ 4 tier", typeof(EditQTE.colorFor("S")) == "Color3"
	and typeof(EditQTE.colorFor("A")) == "Color3" and typeof(EditQTE.colorFor("B")) == "Color3"
	and typeof(EditQTE.colorFor("C")) == "Color3")

-- ===== planWaves (สุ่มเวฟ 2-4 วง จนครบงบ 20) =====
local waves = EditQTE.planWaves(20, 2, 4, rngQueue({ 0, 0.5, 0.99, 0.2 }))
local sum = 0
for _, n in waves do
	check("ทุกเวฟอยู่ในช่วง 2-4 (ยกเว้นเวฟสุดท้ายถ้างบไม่พอ)", n >= 1 and n <= 4)
	sum += n
end
check("รวมทุกเวฟ = งบทั้งหมด 20 พอดี", sum == 20)
check("งบ 1 = เวฟเดียวขนาด 1 (เล็กกว่า min ได้ตอนงบไม่พอ)",
	#EditQTE.planWaves(1, 2, 4, rngQueue({ 0 })) == 1
	and EditQTE.planWaves(1, 2, 4, rngQueue({ 0 }))[1] == 1)

-- ===== randomPositions (ตำแหน่งวงกลมกระจาย ไม่ล้นขอบ) =====
local pos = EditQTE.randomPositions(4, 0.12, rngQueue({ 0.1, 0.2, 0.9, 0.8, 0.3, 0.4, 0.6, 0.5 }))
check("ตำแหน่งครบตามจำนวนที่ขอ", #pos == 4)
local inBounds = true
for _, p in pos do
	if p.x < 0.12 or p.x > 0.88 or p.y < 0.12 or p.y > 0.88 then inBounds = false end
end
check("ทุกตำแหน่งอยู่ในกรอบ margin ไม่ล้นขอบ", inBounds)
```

implement (`src/client/UI/Apps/EditQTE.luau`) — แทนที่ `QTE_KEYS`/`pickKeys`/`scoreFor` เดิม:

```lua
local TOTAL_HITS = 20
local MIN_CONCURRENT = 2
local MAX_CONCURRENT = 4
local APPROACH_TIME = 1.5 -- วิ — เวลาที่วงแหวนใช้หดจากขนาดเริ่มมาเท่าวงเป้าหมาย

-- คะแนนต่อวง: พีคตอนวงแหวนหดมาเท่าวงเป้าหมายพอดี (t=window) ไล่เส้นตรงจาก 0 (เพิ่งโผล่)
-- เปลี่ยนจากเดิมที่พีคกลาง window (redesign 8 ส.ค. — ให้ตรงกับภาพ "วงบีบมาทับกันพอดี = perfect")
function EditQTE.scoreFor(t: number, window: number): number
	if t <= 0 or window <= 0 then return 0 end
	return math.clamp(math.floor(10 * math.min(t, window) / window), 0, 10)
end

-- 9-10=S(เขียว) 6-8=A(ฟ้า) 3-5=B(เหลือง) 0-2=C(แดง) — พลาด/หมดเวลาก็เข้า C ผ่าน got=0
function EditQTE.tierFor(points: number): string
	if points >= 9 then return "S"
	elseif points >= 6 then return "A"
	elseif points >= 3 then return "B"
	else return "C" end
end

local TIER_COLOR = {
	S = Color3.fromRGB(80, 230, 140),  -- เขียว
	A = Color3.fromRGB(90, 170, 255),  -- ฟ้า
	B = Color3.fromRGB(255, 210, 80),  -- เหลือง
	C = Color3.fromRGB(255, 90, 90),   -- แดง (รวมกรณีพลาด/หมดเวลา)
}
function EditQTE.colorFor(tier: string): Color3
	return TIER_COLOR[tier] or TIER_COLOR.C
end

-- แบ่งงบรวม (20) เป็นเวฟสุ่มขนาด min-max วง — เวฟสุดท้ายเล็กกว่า min ได้ถ้างบเหลือไม่พอ
function EditQTE.planWaves(total: number, minC: number, maxC: number, rng): { number }
	rng = rng or math.random
	local waves = {}
	local remaining = total
	while remaining > 0 do
		local roll = minC + math.floor(rng() * (maxC - minC + 1))
		local size = math.min(roll, remaining)
		table.insert(waves, size)
		remaining -= size
	end
	return waves
end

-- ตำแหน่งวงกลม n วง กระจายในกรอบ (0,0)-(1,1) เว้น margin ขอบ กันชนกันเองแบบหยาบๆ (retry สุ่มใหม่ถ้าใกล้กันเกิน)
function EditQTE.randomPositions(n: number, margin: number, rng): { { x: number, y: number } }
	rng = rng or math.random
	local out = {}
	local minGap = margin * 1.5
	for i = 1, n do
		local x, y
		local tries = 0
		repeat
			x = margin + rng() * (1 - margin * 2)
			y = margin + rng() * (1 - margin * 2)
			tries += 1
			local tooClose = false
			for _, p in out do
				if (p.x - x) ^ 2 + (p.y - y) ^ 2 < minGap ^ 2 then tooClose = true break end
			end
			if not tooClose or tries > 8 then break end
		until false
		table.insert(out, { x = x, y = y })
	end
	return out
end
```

ลบ `pickKeys`/`QTE_KEYS`/`QTE_COUNT`/`QTE_WINDOW` เดิมทิ้ง (ไม่ใช้แล้ว)

Commit: `feat(editqte): pure functions ใหม่ — wave concurrency + peak-at-close scoring + tier colors`

### Task 2: UI glue ใหม่ — เวฟวงกลมพร้อมกัน + responsive + input universal

**Files:** Modify `src/client/UI/Apps/EditQTE.luau` (ส่วน `EditQTE.start`)

- ครอบทั้งแผงด้วย `UIScale` + `fitScale` แบบ `ShopKiosk.luau` (design size คงที่ 720×560 เหมือนเดิม แค่ย่อทั้งแผงตาม viewport)
- พื้นหลัง: ถ้า `UIAssets.edit_workspace_bg ~= ""` ใช้ ImageLabel เต็มแผง ไม่มี = Frame ธีมเข้ม (`UIGradient` + `UIStroke`) แทนกล่องเทาเดิม
- ต่อวง: `ImageButton` วงกลม (`UICorner` รัศมีครึ่งขนาด) — ถ้ามี `qte_ring_target`/`qte_ring_outer` ใช้รูป tint สี ไม่มี = programmatic (Frame กลม + UIStroke หนา)
  - วงเป้าหมาย (ขนาดคงที่) อยู่ด้านหลัง, วงแหวนหด (Size ลดจาก ~2.5× เป้าหมาย → เท่าเป้าหมายพอดีตอน t=window) อยู่ด้านหน้า อัปเดตผ่าน `RunService.Heartbeat`
  - label ตัวเลขลำดับ (1..N ของเวฟนั้น) กลางวง
- input: `circleButton.Activated:Connect(...)` เท่านั้น — บันทึกเวลา ณ ตอนกด เทียบกับ `os.clock()` ตอน spawn วงนั้น → `EditQTE.scoreFor`
- 1 เวฟ = `task.spawn` แยกต่อวง แต่ละ coroutine จบเมื่อ (กดแล้ว) หรือ (หมด `APPROACH_TIME` ไม่มีคนกด → auto-miss สีแดง) — ใช้ counter/`BindableEvent` รอครบทุก coroutine ในเวฟก่อนขึ้นเวฟถัดไป
- ผลรวมคะแนนสะสมทุกวง (เหมือนเดิม) → จบ 20 วง → `fireAction({type="FinishEdit", score=total})` เหมือนเดิมทุกอย่าง (ไม่แตะ server)
- จอสรุปเดิม (`buckets.S/A/B/C`, `Edit more`/`Done`) ใช้โครงเดิมได้ แค่เปลี่ยนที่มาของ bucket มาจาก `EditQTE.tierFor` แทนการคำนวณ inline เดิม

Commit: `feat(editqte): UI ใหม่ — เวฟวงกลม osu-style + responsive + tap/click universal`

### Task 3: Sync docs ให้ตรงโค้ด

- `docs/07-core-systems-design.md §3.4` — แก้ flow: ไม่มีตัวอักษรให้พิมพ์แล้ว, เวฟ 2-4 วงพร้อมกัน, พีคคะแนนตอนวงแหวนปิด (ไม่ใช่กลาง window), เวลารวมไม่ใช่ 30 วิตายตัวอีกต่อไป (ขึ้นกับจำนวนเวฟ)
- `docs/09-app-ui-spec.md §5` — อัปเดตสถานะตาราง QTE เป็นดีไซน์ใหม่ + note ว่ารองรับมือถือแล้ว (universal `.Activated`)
- flag ว่า docs/07 เป็น draft ที่ตามหลัง ไม่ใช่ source of truth (docs/02 ไม่มีรายละเอียดกลไกนี้ ไม่ต้องแก้)

Commit: `docs: sync QTE redesign เข้า docs/07 + docs/09`

### Task 4: Sync Studio + verify + Play smoke

- sync `EditQTE.luau` + `RunTests.luau` เข้า Studio, reset ActionRouter/TimeService, รันเทส — คาด pass เพิ่มขึ้น (ลบ 5 เทสเก่า pickKeys/scoreFor เดิม เพิ่ม ~17 เทสใหม่)
- Play smoke: ซื้อกล้อง/อัด footage ให้พอ → เปิด Edit → เห็นเวฟ 2-4 วงพร้อมกัน → คลิกแต่ละวง → คะแนนสะสมสมเหตุสมผล → ครบ 20 → จอสรุปโชว์ tier/สี ถูกต้อง → Edit more/Done ทำงาน
- หมายเหตุ: `VirtualInputManager` ใช้ยิง touch จำลองใน execute_luau ไม่ได้ (ติด capability lock — เจอมาแล้วรอบก่อน) verify มือถือทำได้แค่ตรวจโค้ดว่าไม่มี `UserInputType` branch หลงเหลือ (ถ้าไม่มี = ปลอดภัยเชิงโครงสร้าง เพราะ `.Activated` เป็น built-in behavior ของ Roblox ไม่ต้องเทสแยก)

---

## Self-Review

- **Coverage:** เวฟ 2-4 พร้อมกัน ✓ พีคคะแนนตอนวงปิด ✓ เลขแทนตัวอักษร ✓ input universal (ไม่มี keyboard-only) ✓ สี 4 tier ✓ responsive ✓ ใช้ UIAssets ถ้ามี fallback ถ้าไม่มี ✓
- **ไม่แตะ server เลย:** `FinishEdit{score}` รูปแบบเดิมเป๊ะ — risk ต่ำสุดในส่วน balance/VidQ formula
- **Breaking change ที่ตั้งใจ:** ลบ `pickKeys`/`QTE_KEYS` และเทสเก่าที่อ้างอิงพีคกลาง window ทิ้งทั้งหมด (ไม่ backward compatible กับกลไกเดิม — user ยืนยันแล้วว่าต้องการเปลี่ยน ไม่ใช่เพิ่มเติม)
- **เสี่ยงสุด:** Task 2 (UI glue เวฟ concurrent) — เดิมเป็น loop เดียว sequential ง่ายกว่ามาก ตอนนี้ต้องคุม N coroutine พร้อมกันต่อเวฟ ต้องเทส manual ใน Play จริงละเอียดกว่าปกติ
