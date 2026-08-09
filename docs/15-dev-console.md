# Dev Console — `/dev` chat command (Studio เท่านั้น)

โค้ด: [`src/client/DevConsole.client.luau`](../src/client/DevConsole.client.luau) (`TextChatCommand`) →
ยิง action `DevCmd` → [`src/server/Main.server.luau`](../src/server/Main.server.luau) handler

**Guard 2 ชั้น** — `RunService:IsStudio()` ทั้งฝั่ง client (ไม่ register command เลย) และ server (handler เช็คอีกที)
→ published game ใช้ไม่ได้ ไม่ต้องถอดออกก่อนส่ง

**หลัง sync ไฟล์ใหม่ต้อง restart playtest** — `ActionRouter.register` รันตอน server boot ครั้งเดียว
(ดู [`CLAUDE.md` rule 10](../CLAUDE.md)) live-sync source ไม่พอ ต้องกด Stop→Play ใหม่

พิมพ์ `/dev help` หรือ `/d help` ในแชทเกมดู list สดได้เหมือนกัน

---

## Syntax

```
/dev <cmd> [value] [value2]
/d <cmd> [value] [value2]      -- alias สั้น
```

## รายการคำสั่ง

| cmd          | args                   | ทำอะไร                                                                                         | หมายเหตุ                                                                                            |
| ------------ | ---------------------- | ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `follower`   | `<n>`                  | ตั้ง `state.follower = n` + คำนวณ `phase` ใหม่จากยอด                                           | ยิง `checkMilestones` + `checkEnding` จริง — milestone event/betrayed/BCA queue ขึ้นเหมือนเล่นจริง  |
| `phase`      | `<1-3>`                | ตั้ง `follower` = gate ของเฟสนั้น (0 / 10,000 / 100,000) + `phase` | ยิง `checkMilestones` เหมือนกัน                                                                     |
| `money`      | `<n>`                  | ตั้ง `state.money = n`                                                                         | ไม่ clamp                                                                                           |
| `time`       | `<0-23>`               | ตั้ง `state.timeOfDay` + sync `Lighting.ClockTime` ทันที                                       | clamp 0-23                                                                                          |
| `mental`     | `<0-100>`              | ตั้ง `state.mental`                                                                            | clamp 0-100                                                                                         |
| `day`        | `<n>`                  | ตั้ง `state.day`                                                                               | ใช้ทดสอบ `[date]` ใน `PhaseTransitions`                                                             |
| `flag`       | `<ชื่อ> [true\|false]` | ตั้ง `state.flags[ชื่อ]`                                                                       | ไม่ใส่ค่า/ค่า ≠ `"false"` → `true` · ดู "flag ที่มีอยู่จริง" ด้านล่าง                               |
| `ending`     | `<id>`                 | ตั้ง `state.flags.ending = id` + freeze เวลา                                                   | id ต้องตรงชื่อไฟล์ใน `Content/Endings/` (ดูตาราง)                                                   |
| `npcloc`     | `<actor> <loc>`        | ตั้ง `state.npcLoc[actor] = loc`                                                               | `StoryNPCPlacer` ย้าย/idle ตัวจริงตาม push ถัดไป — ต้องมี anchor Part `NPCHome_<actor>_<loc>` ในแมพ |
| `staffsplit` | —                      | ยิง `StaffService.splitStaff` ตรงๆ (bypass flag guard เพื่อยิงซ้ำได้ตอน dev)                   | tag `leavesOnSplit` ออก + `hire_loyal` เข้า                                                         |
| `preview`    | `<key>`                | เล่น `Content.Cutscenes.PhaseTransitions[key]` ตรงๆ ฝั่ง client (`ScreenTransition.play`)      | **client-only ไม่ผ่าน server/phase จริง** — ทดสอบ `[3]`/`[4]` ได้ทันทีไม่ต้องไล่ follower · `[date]` แทนด้วย day ล่าสุดที่ push มา |

---

## `flag` — ชื่อที่ระบบอ่านจริง (grep แล้ว ไม่ใช่เดา)

| ชื่อ flag       | ใครตั้ง/อ่าน                                                                                                  | ผล                                                                     |
| --------------- | ------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `betrayed`      | `Main.server.checkMilestones` ตั้งตอน follower ถึง `BetrayalMilestone` (500,000)                              | `StaffService.availableHires`/`hire` ปลด `hire_fierce1`/`hire_fierce2` |
| `staffSplit`    | `StaffSplit` action ตั้ง (กันยิงซ้ำ)                                                                          | event ตีกันเล่นแล้ว                                                    |
| `mentalZero`    | `MentalService` ตั้งตอน mental ถึง 0                                                                          | `EndingService` อ่านเป็น Bad End ②                                     |
| `rentMissed`    | `MoneyService` (เป็น **ตัวเลข** ไม่ใช่ boolean — นับจำนวนครั้ง)                                               | ครบ 2 = Bad End ①                                                      |
| `ending`        | `checkEnding`/`DevCmd ending` ตั้งเป็น **ending id** (string ไม่ใช่ boolean)                                  | client เล่น cutscene จบเกม                                             |
| `milestone_<n>` | `checkMilestones` ตั้งอัตโนมัติต่อ milestone ใน `Config.StoryMilestones` (1000/10000/30000/100000/500000/...) | กันยิง event ซ้ำ                                                       |

⚠️ `rentMissed` และ `ending` **ไม่ใช่ boolean** — `/dev flag rentMissed true` จะตั้งเป็น `true` (ผิด type ที่โค้ดจริงคาดหวัง number/string) ใช้ `/dev ending <id>` แทนสำหรับ ending

---

## `ending` — id ที่มีจริง (`src/shared/Content/Endings/*.luau`)

`Good1` · `Neutral1` · `Neutral2` · `Bad1` · `Bad2` · `Bad3`

---

## ตัวอย่างใช้งาน

```
/dev follower 10000       -- ข้ามเข้าเฟส 2 (ยิง milestone 10K จริง — เพื่อนร่วมทางคนแรกเข้าทีม)
/dev follower 500000      -- ทดสอบทรยศ (betrayed ติด + fierce hire ปลด + companion_1 ออก)
/dev phase 3               -- กระโดดเฟส 3 แบบไว (ไม่ผ่าน milestone ระหว่างทาง 30K/100K)
/dev flag betrayed         -- ปลด hire_fierce1/2 ตรงๆ ไม่ต้องรอ follower
/dev staffsplit            -- ทดสอบ event ตีกัน (ต้องมี staff hired ก่อนถึงเห็นผล)
/dev npcloc ฟ้าใส room     -- ทดสอบ StoryNPCPlacer (ต้องมี Part NPCHome_ฟ้าใส_room ในแมพก่อน)
/dev ending Good1           -- เล่น ending cutscene ตรงๆ ไม่ต้องเล่นจนจบเกม
/dev day 7                  -- ทดสอบ [date] substitution ใน PhaseTransitions[2]
/dev preview 3               -- เล่น PhaseTransitions[3] ตรงๆ ไม่ต้องเก็บ follower ถึง 100,000 จริง
/dev preview 4               -- เล่น PhaseTransitions[4] (BCA→พ่อแม่) — ไม่มีทาง auto-trigger เพราะ phase สูงสุด = 3
```

**ทำไม `[2]`/`[3]` ไม่เล่นเอง:** ต้องข้าม follower gate จริงจากค่าที่ต่ำกว่ามาก่อน (Main.client เทียบ `prevPhase` ระหว่าง session)
`/dev phase 3` ก็ทริกเกอร์ได้ถ้า phase ปัจจุบันต่ำกว่า 3 อยู่ — แต่ `preview` เร็วกว่าและไม่แตะ state จริง (เงิน/staff/flag ไม่เปลี่ยน)

## ⏳ ยังไม่มี cmd (เพิ่มได้ถ้าต้องใช้บ่อย)

`upgrade <line> <level>` · `hire <id>` · `additem`/`footage <gb>` — บอกได้ถ้าอยากได้ จะเพิ่มใน `Main.server.luau` `DevCmd` handler
