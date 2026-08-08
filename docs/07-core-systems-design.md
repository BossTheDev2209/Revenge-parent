# 07 — Core Systems: จัดอันดับ + ออกแบบ 5 ตัวแรก

อ้างอิง: `02-game-design-locked.md` (ตัวเลขทุกตัว), `06-architecture.md` (โครง)
สถานะ: proposed (19 ก.ค. 2569)

---

## 1. จัดอันดับทุกระบบ — ยาก × สำคัญ (5 = สุด)

เรียงจาก ยาก+สำคัญ รวมกันมากสุด → น้อยสุด

| ระบบ | ยาก | สำคัญ | เหตุผลสั้น |
|------|:---:|:-----:|-----------|
| **Time/Calendar** | 5 | 5 | ทุกระบบเกาะเวลา: ค่าเช่าราย 7 วัน, canon event, freeze, นอน |
| **GameState + Save** | 4 | 5 | ฐานของทุกอย่าง + DataStore + 4 save slot |
| **Formulas + Ending resolver** | 3 | 5 | ผูกคะแนนตรรกะระบบ 20pt ตรงๆ — ผิด = เสียคะแนนซ้อน |
| **Edit QTE (ตัดคลิป)** | 4 | 4 | core gameplay ที่ผู้เล่นเล่นบ่อยสุด + กำหนด VidQ |
| **Mental system** | 3 | 4 | drain ต่อเนื่อง + modifier ซ้อน + activity cooldown |
| Cutscene player | 4 | 3 | ending ต้องใช้ แต่รอ storyboard ได้ |
| Dialogue typewriter | 2 | 4 | สำคัญแต่ engine เดียวจบ ไม่ยาก |
| Comment/Feedback | 2 | 4 | choice % feed ending แต่ logic แค่นับ |
| ActionRouter + Remotes | 2 | 4 | สำคัญแต่ pattern ตายตัว |
| Phase gate | 1 | 3 | if 3 บรรทัด |
| InteractBinder | 2 | 3 | loop แปะ prompt |
| HUD | 1 | 3 | อ่าน state วาดจอ |
| Bank/จ้างพนักงาน | 2 | 2 | CRUD ธรรมดา |
| Record app | 1 | 2 | เดินกด click +1 |
| Shop/Upgrade | 1 | 2 | ตาราง config + ปุ่มซื้อ |
| Upload/DM/Message | 1 | 2 | UI ล้วน |

**จุดร่วม ยาก∩สำคัญ → คัด 5:**

1. Time/Calendar
2. GameState + Save
3. Formulas + Ending resolver
4. Edit QTE
5. Mental system

ที่เหลือ logic ง่าย รอโครง 5 ตัวนี้เสร็จแล้วเสียบตาม

---

## 2. หลักออกแบบร่วม (ทำให้อ่านง่ายทั้ง 5 ตัว)

- **ทุก service = ModuleScript หน้าตาเดียวกัน:** ตาราง function ธรรมดา ไม่มี class ไม่มี metatable
- **Wiring อยู่ที่ `Main` ที่เดียว** — อยากรู้ว่าอะไรต่อกับอะไร อ่านไฟล์เดียว
- **ตัวเลขอยู่ Config, logic อ่าน Config** — service ไม่มีเลขฝัง
- **สุ่มทุกจุดรับ `rng` เป็น parameter** — เทสได้เพราะ fix ค่าได้

---

## 3. Design ทีละตัว

### 3.1 TimeService — นาฬิกากลางของเกม

**ปัญหาที่แก้:** ค่าเช่า, canon event, mental drain, นอน, freeze — ถ้าต่างคนต่างนับเวลา = พังแน่
**ทางแก้:** นาฬิกาเดียว loop เดียว ระบบอื่นมา "สมัครฟัง" เอา

```lua
-- ServerScriptService.Services.TimeService (โครง)
local TimeService = {
	onHour = {},   -- list ของ function โดนเรียกทุกชั่วโมงเกม
	onDay  = {},   -- list ของ function โดนเรียกทุกเที่ยงคืนเกม
	frozen = false,
}

function TimeService.start(state)
	task.spawn(function()
		while true do
			task.wait(TimeConfig.secondsPerGameHour)  -- 3 นาที/วัน ÷ 24 = 7.5 วิ/ชม.
			if not TimeService.frozen then
				state.timeOfDay += 1
				if state.timeOfDay >= 24 then
					state.timeOfDay = 0
					state.day += 1
					for _, f in TimeService.onDay do f(state) end
				end
				for _, f in TimeService.onHour do f(state) end
			end
		end
	end)
end

function TimeService.freeze(on)  TimeService.frozen = on  end   -- dialogue/cutscene เรียก
function TimeService.sleep(state, hours) ... end                -- ข้ามเวลา + กัน range นอน
```

**ใครฟังอะไร (wiring ใน Main — ที่เดียว):**

| ฟัง | ทำอะไร |
|-----|--------|
| `onDay` | MoneyService: `day % 7 == 0` → หักรายจ่าย |
| `onDay` | CalendarService: เช็ค block วันนี้ → trigger canon/select event |
| `onDay` | MentalService: ลด cooldown activity / หมดอายุ modifier |
| `onHour` | HUD (ผ่าน StateChanged): อัปเดตนาฬิกา · MentalService drain · `Lighting.ClockTime` (server) |

**Calendar = แค่ตารางใน state:** `state.calendar[day] = {type="Canon", id="Hater"}`
วาง block = เขียนตาราง | ถึงวัน = TimeService ปลุก CalendarService อ่านตาราง | จบ
Canon event lock วัน = flag `locked=true` ใน block — UI ไม่ให้ลาก

### 3.1.1 นาฬิกา (นาที) + ดวงอาทิตย์ (lighting)

**เวลาเดินฝั่ง server รายชั่วโมง** (`state.timeOfDay` integer) แต่ **แสดงผล/แสงลื่นฝั่ง client** — server tick 7.5 วิ/ชม. ถ้าโชว์ตรงๆ = นาฬิกากระโดด :00 ทุกชั่วโมง + ดวงอาทิตย์กระตุก

- **HUD interpolate เอง** (`HUD.gameHour` float, RunService.Heartbeat): เดินนาทีระหว่าง server tick → โชว์ `HH:MM` + ขับ `Lighting.ClockTime` ต่อเฟรมให้ดวงอาทิตย์ลื่น · snap เข้าชั่วโมง server ทุก tick, cap ที่ :59 กันวิ่งล้ำ
- **freeze:** server broadcast `state.frozen` (set ที่ action `FreezeTime`) → HUD หยุดเดินนาที/แสงตอน cutscene/คุย NPC (เวลาเกมหยุด แสงต้องหยุดด้วย)
- **Lighting.ClockTime มาจาก `state.timeOfDay` ที่เดียว** (`syncLighting` ใน Main.server รายชั่วโมงสำหรับ script ฝั่ง server เช่นไฟถนน `autoturnlight` · client override ทับให้ลื่น) — **ห้ามมี day/night loop แยก** (Toolbox `DayNight` เดินเองไม่สน freeze → ปิดถาวร ดู [05-build-conventions](05-build-conventions.md))

**ทำไมไม่ยาก:** loop เดียว 20 บรรทัด + ตารางใครฟังอะไรอยู่ใน Main อ่านออกใน 1 นาที

---

### 3.2 GameState + Save — ความจริงหนึ่งเดียว

**หลัก:** state = ตาราง Lua เปล่าก้อนเดียว (หน้าตาตาม 06 §3) ทุก service แก้ก้อนนี้ตรงๆ แล้วเรียก `push()`

```lua
-- ServerScriptService.Services.GameState (โครง)
local GameState = { state = nil }

function GameState.newGame()        -- คืน state เริ่มต้น (เงิน 2500, mental 80, day 1)
function GameState.push()           -- ยิง StateChanged ให้ client + ตั้ง dirty flag
function GameState.saveSlot(player, slot)   -- pcall DataStore key = userId.."_"..slot
function GameState.loadSlot(player, slot)
function GameState.listSlots(player)        -- คืน {slot, follower, day, phase} ×4 ให้หน้า save
```

- **4 slot** ตาม design (Main Menu: Continue = slot ล่าสุด)
- Autosave: ทุก 60 วิ ถ้า dirty + ตอน `PlayerRemoving` + `game:BindToClose`
- DataStore ทุกครั้งห่อ `pcall` — fail = แจ้งผู้เล่น "เซฟไม่สำเร็จ" ไม่ crash
- **กติกา:** service แก้ state → ต้องจบด้วย `push()` เสมอ (ลืม = จอไม่อัปเดต เห็นทันที หาง่าย)

**ทำไมไม่ยาก:** ไม่มี getter/setter ซ้อน — อยากรู้เกมเก็บอะไร อ่านตาราง `newGame()` ตารางเดียว

---

### 3.3 Formulas + Ending resolver — สมองคณิตทั้งเกม

**หลัก:** pure function 100% — input เข้า output ออก ไม่แตะ state ไม่แตะ Roblox API → เทสได้ใน RunTests

```lua
-- ReplicatedStorage.Shared.Formulas (โครง — เลขทั้งหมดมาจาก Config)
function Formulas.vidqTier(score)            -- 0-50=C, 51-100=B, 101-150=A, 151-200=S
function Formulas.vidqMultiplier(tier)       -- C=0.5, B=1, A=1.5, S=2
function Formulas.mentalMultiplier(pct, rng) -- 3 โซน: 70-100→1-1.25 / 40-69→1 / 1-39→0.6-1
function Formulas.followerGain(phase, tier, mentalPct, rng)
	-- base สุ่มตามเฟส × vidqMultiplier × mentalMultiplier
	-- แล้ว rng() < 0.12 → คูณ viral 4-8, คืน (จำนวน, isViral)
function Formulas.moneyGain(followers, phase)  -- followers × rate เฟส (0.8/1.2/1.5)

function Formulas.resolveEnding(stats)
	-- stats = { vidqPct = {C=.., B=.., A=.., S=..}, choicePct = {plus=.., neutral=.., minus=..} }
	-- ไล่ตาม EndingConfig ทีละอัน "ตามลำดับ" คืนตัวแรกที่ match:
	-- Bad3 → Good1 → Neutral1 → Neutral2
	-- (Bad1 เงิน / Bad2 mental ไม่ผ่านตัวนี้ — trigger สดกลางเกมที่ MoneyService/MentalService)
end
```

- เงื่อนไข % ทั้งหมดอยู่ `EndingConfig` เป็น **list เรียงลำดับ priority** — อยากปรับเลข/สลับลำดับ แก้ config ไม่แตะโค้ด
- `rng` รับเป็น parameter (default `math.random`) → เทส fix ได้: "rng คืน 0.05 ต้อง viral"

**ทำไมไม่ยาก:** ไฟล์เดียว ~80 บรรทัด แต่ละ function ตรงตาราง design doc 1:1 — เปิดเทียบกันอ่านออกทันที
**เทสขั้นต่ำ (RunTests):** tier ครบ 4 ช่วง, ending ทั้ง 4 + ลำดับ priority, viral ติด/ไม่ติด, โซน mental ทั้ง 3

---

### 3.4 Edit QTE — มินิเกมตัดคลิป (osu-style redesign 8 ส.ค. 2569)

> ⚠️ **redesign ตัดสินใจในแชท 8 ส.ค. 2569 ไม่ใช่ requirement จาก PDF เดิม** — spec เก่า (ปุ่มตัวอักษรทีละตัว คีย์บอร์ดอย่างเดียว) ถูกแทนที่ทั้งหมด รายละเอียดเต็ม + เหตุผลอยู่ที่ `plans/2026-08-08-editqte-osu-redesign.md`

**Spec ปัจจุบัน:** **chain เดียว 20 วง**เด้งทีละอันต่อเนื่อง (ห่างกัน 0.45 วิ) วงก่อนหน้ายังหดค้าง → ~3-4 อันซ้อนบนจอ ไหลไม่ขาด · วงแหวนหด 1.5 วิ/วง เข้าหาวงเป้าหมาย แม่นแค่ไหน = คะแนน เต็ม 200 → tier

**Flow:**

```
นั่ง seat (Interact_Camera) → Gui_Computer เปิด App_Edit
→ เลือก footage (slider GB) → เริ่ม QTE
→ chain: เด้งวงทีละอัน ห่างกัน SPAWN_INTERVAL (0.45 วิ) วงก่อนหน้ายังหดค้างบนจอ
   แต่ละวงมี label (PC=ตัวอักษร / มือถือ=เลข) + วงแหวนหด 1.5 วิ เข้าหาวงเป้าหมาย
   กดตอนวงแหวนหดมาทับวงเป้าหมายพอดี = คะแนนเต็ม 10 · กดเร็วไป = น้อยลง · ไม่กดจนหมดเวลา = พลาด (แดง 0)
   จนครบ 20 วง → รอวงที่ยังค้างบนจอ resolve หมด
→ รวมคะแนนทุกวง → ยิง Action {type="FinishEdit", score=จำนวน}
→ server: clamp 0-200 → Formulas.vidqTier → เก็บ clip ลง state.clips → push()
```

- **ทั้งมินิเกมอยู่ client ตัวเดียว** (`UI.Apps.EditQTE`) — server รับแค่คะแนนจบ (singleplayer ไม่ต้องกัน cheat) **ไม่แตะ server เลย** — `FinishEdit{score}` รูปแบบเดิมเป๊ะ
- **Input แยก platform:** PC (มีคีย์บอร์ด) = วงแสดง**ตัวอักษร** กดคีย์นั้น (คลิกเมาส์ก็ได้) · มือถือ (ไม่มีคีย์บอร์ด) = วงแสดง**เลข** แตะวง — ตรวจ `TouchEnabled and not KeyboardEnabled`
- คีย์ PC ไม่ซ้ำวงที่ซ้อนเวลากัน: `EditQTE.pickFreeKey(pool, used, rng)` · ตำแหน่งเลี่ยงวง active: `EditQTE.pickPosition(margin, avoid, rng)`
- คะแนนต่อวง: `EditQTE.scoreFor(t, window)` = ไล่เส้นตรง 0→10 พีคตอน t=window (วงแหวนหดมาเท่าวงเป้าหมายพอดี)
- สี 4 tier ต่อวง (`EditQTE.tierFor`/`colorFor`): เขียว=S(9-10) ฟ้า=A(6-8) เหลือง=B(3-5) แดง=C(0-2/พลาด)
- **เสียงตามเกรด (variant SFX):** เล่นตอนกดแต่ละวงตาม tier ผ่าน `AudioService.sfx(name)` · แก้ที่ `EditQTE.SFX` (map tier → ชื่อ Sound ใน `SoundService.SFX`: `qte_perfect`/`qte_good`/`qte_ok`/`qte_miss`) · ทีมเสียงวาง Sound ชื่อนี้แล้วเล่นเอง — ยังไม่มี = เงียบ ไม่พัง
- Responsive: `UIScale` + fit-to-screen (pattern เดียวกับ `ShopKiosk.fitScale`)
- ตัดคลิปเสร็จ → MentalService.apply(-20) ตาม config

**ทำไมไม่ยาก:** state ของมินิเกมมีแค่ `ปุ่มที่เท่าไหร่ / คะแนนสะสม` — loop เดียว 20 รอบ
**อนาคต:** อยากเพิ่มความยากต่อเฟส = เพิ่ม `window` ต่อเฟสใน config — ไม่แตะโค้ด

---

### 3.5 MentalService — หลอดใจ

**3 งาน:** ไหลลงตามเวลา / รับบวกลบจาก action / activity ฟื้นใจ

```lua
-- ServerScriptService.Services.MentalService (โครง)
function MentalService.apply(state, delta, reason)
	-- บวกลบ + clamp 0-100 + push() ; ถ้า 0 → ยิง Bad End 2
function MentalService.tick(state)
	-- ผูกกับ TimeService: ลด drainBase × ตัวคูณ modifier ที่ active
	-- (drain 1% / 4.5 วิจริง = แปลงเป็นต่อชั่วโมงเกมใน config)
function MentalService.doActivity(state, name)
	-- name = "Exercise" | "Bed" | "Kitchen" (ตรงชื่อ Interact_)
	-- เช็ค: ใช้ติดกันเกิน 3 ครั้ง → cooldown 1 วันเกม (ตาม design หน้า 6)
	-- ผ่าน → บอก client เล่น cutscene 5-10 วิ → apply(+ค่าใน MentalConfig)
```

- **Modifier (อดนอน ×1.5, canon event ×1.25, ตัดคลิปติด 5 อัน ×1.5 ฯลฯ):**
  เก็บใน `state.mentalMods = { {id="NoSleep", mult=1.5, expireDay=12}, ... }`
  drain จริง = base × ผลคูณทุกตัวที่ยังไม่หมดอายุ — TimeService.onDay ลบตัวหมดอายุทิ้ง
- ฝั่งบวกเร่งฟื้น (choice ดีติด 3 ครั้ง ×1.5 ฯลฯ) ใช้ตาราง mods เดียวกัน — mult < 1 ของ drain
- ตาราง +/− ทั้งหมด (ตัดคลิป -20, comment ดี +10, ไวรัล +25 …) = `MentalConfig.deltas` — service แค่ `apply(deltas[reason])`

**ทำไมไม่ยาก:** function 3 ตัว + ตาราง mods ก้อนเดียว — ไม่มี timer แยกต่อ modifier (เช็คหมดอายุด้วยเลขวัน)
**อนาคต:** เพิ่ม modifier ใหม่ = เพิ่มแถวใน config + จุดที่ยัด mod เข้า state — ไม่แตะ tick

---

## 4. ลำดับสร้าง 5 ตัวนี้

| # | ทำ | ได้อะไร |
|---|-----|---------|
| 1 | Config ทุกตัวเลข + Formulas + RunTests | สมองเกมถูกพิสูจน์ก่อนมี UI |
| 2 | GameState + Remotes + ActionRouter | กระดูกสันหลัง |
| 3 | TimeService + wiring ใน Main | เกมมี "วัน" — ค่าเช่า/ปฏิทินตามมาฟรี |
| 4 | MentalService | ผูก tick เข้า TimeService ที่มีแล้ว |
| 5 | Edit QTE (client) + FinishEdit (server) | core loop ครบ: ตัด → อัป → follower → เงิน |

จบ 5 ขั้น = เกมเดโม่ได้จริงหนึ่ง loop — ที่เหลือ (Dialogue, Comment, Bank, Shop, Ending cutscene) เสียบเข้าโครงนี้ทีละอัน
