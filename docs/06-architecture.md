# 06 — Game Architecture (Roblox Studio)

**ของจริงอยู่ใน Studio ทั้งหมด** — repo `src/` เป็นแค่ backup mirror (agent sync ให้ตามกฎ CLAUDE.md ข้อ 7)
ทีมทำงานใน Studio อย่างเดียว ไม่มี sync tool ไม่ต้องแตะ repo

**หลักการเดียวที่ต้องจำ:** แยก **ข้อมูล** (ตัวเลข + ข้อความ) ออกจาก **logic** (โค้ดคำนวณ)
คนไม่โค้ดแก้ได้เฉพาะโฟลเดอร์ `Config` กับ `Content` — instance อื่นไม่ต้องแตะ ไม่ต้องอ่าน ไม่ต้องกลัว

สถานะ: proposed (19 ก.ค. 2569) | อ้างอิง: `02-game-design-locked.md` §11, `05-build-conventions.md`

---

## 1. Explorer tree ใน Studio

สร้าง Folder/ModuleScript ตามนี้เป๊ะ — ชื่อคือ address ที่โค้ดใช้หา ห้ามเปลี่ยนชื่อเอง

```
ReplicatedStorage
└── Shared (Folder)
    ├── Config (Folder)                ★ ตัวเลขทุกตัวของเกมอยู่ที่นี่ที่เดียว (ModuleScript ทั้งหมด)
    │   ├── PhaseConfig                - phase gate (10K/100K/1M), base follower ต่อเฟส, rate เงินต่อเฟส
    │   ├── VidQConfig                 - tier C/B/A/S: ช่วง accuracy + multiplier
    │   ├── ViralConfig                - โอกาส 12%, ช่วง ×4–8
    │   ├── MentalConfig               - 3 โซน, ค่าเริ่ม 80, drain 1%/4.5s, ตาราง +/− mental, activity
    │   ├── EconomyConfig              - ค่าใช้จ่ายรายสัปดาห์ต่อเฟส, ราคา upgrade กล้อง/storage
    │   ├── EndingConfig               - เงื่อนไข % ทั้ง 6 ending + priority order
    │   └── TimeConfig                 - 1 วันเกม = 3 นาที, ชั่วโมงนอน, ความยาว playthrough
    │
    ├── Content (Folder)               ★ ข้อความทุกอย่างของเกม (งานเขียนบทลงตรงนี้)
    │   ├── Dialogue (Folder)          - บท NPC ทางเดียว 1 ModuleScript / 1 ตัว
    │   │   ├── Mom, Dad, Friend1, Friend2, CC1, Hater
    │   ├── Comments                   - pool ข้อความ comment + choice ตอบ + tag ⊕/◎/⊖
    │   ├── CanonEvents                - บท Canon Event ต่อเฟส
    │   ├── DMs                        - บท DM (script ตายตัว ไม่มีผล)
    │   └── Endings (Folder)           - บท cutscene 1 ModuleScript / 1 ending
    │       └── Bad1, Bad2, Bad3, Neutral1, Neutral2, Good1
    │
    ├── Formulas (ModuleScript)        - pure function ล้วน: followerGain(), moneyGain(),
    │                                    mentalMultiplier(), vidqTier(), resolveEnding()
    └── Remotes (Folder)
        ├── Action (RemoteEvent)       - client → server ทุกการกระทำ
        └── StateChanged (RemoteEvent) - server → client ส่ง state

ServerScriptService
├── Main (Script)                      - จุดเริ่มเดียวของ server: require service ทุกตัวตามลำดับ
├── Services (Folder)                  - ModuleScript ทั้งหมด
│   ├── GameState                      - ตาราง state เดียวของทั้งเกม + save/load (DataStore)
│   ├── ActionRouter                   - รับ Action จาก client → แจกให้ service ที่ถูกต้อง
│   ├── FollowerService                - อัปคลิป → Formulas.followerGain → บวก state
│   ├── MoneyService                   - เงินจากคลิป + หักรายจ่ายราย 7 วัน + upgrade
│   ├── MentalService                  - drain ตามเวลา + delta จาก action + activity cooldown
│   ├── PhaseService                   - อ่าน follower → เฟสปัจจุบัน + trigger เปลี่ยนเฟส
│   ├── CalendarService                - เวลาเกม, block ปฏิทิน 3 ประเภท, sponsor
│   └── EndingService                  - เช็คเงื่อนไขตาม priority → สั่งเล่น cutscene
└── Tests (Folder)
    └── RunTests (Script, Disabled)    - assert เทส Formulas ตรงตาราง design doc
                                         วิธีรัน: ติ๊ก Enabled → กด Play → ดู Output → ติ๊กกลับ

StarterPlayer
└── StarterPlayerScripts
    ├── Main (LocalScript)             - จุดเริ่มเดียวของ client: ต่อ Remote + เปิด UI
    ├── InteractBinder (ModuleScript)  - หา Interact_* ทุกตัวใน map → แปะ ProximityPrompt
    │                                    → กดแล้วยิง Action (ตาราง mapping ในไฟล์เดียว)
    └── UI (Folder)                    - ModuleScript ควบคุม Gui
        ├── HUD                        - follower / เงิน / mental bar / นาฬิกา
        ├── DialogueUI                 - typewriter engine (Undertale style) + tag [slow][fast]
        ├── CutscenePlayer             - เล่น cutscene จาก Content.Endings
        └── Apps (Folder)              - 1 ModuleScript / 1 แอปหน้าคอม
            └── Record, Edit, Upload, Feedback, Bank, CalendarApp, Message, Shop

StarterGui                             - ทีมสร้างหน้าตา Gui ที่นี่ (mockup ก่อน ไม่ต้องต่อ logic)
├── Gui_HUD (ScreenGui)
├── Gui_Dialogue (ScreenGui)
├── Gui_Cutscene (ScreenGui)
└── Gui_Computer (ScreenGui)           - ข้างในมี Frame ต่อแอป ชื่อ App_Record, App_Edit,
                                         App_Upload, App_Feedback, App_Bank, App_Calendar,
                                         App_Message, App_Shop (โค้ด UI จะหา Frame ตามชื่อนี้)

Workspace                              - map/NPC/Interact_ ตาม docs/05 เหมือนเดิม ไม่เปลี่ยน
```

**กฎแบ่งเขต:** ทีมสร้างอิสระ = `StarterGui` (หน้าตา) + `Workspace` (ฉาก/NPC) | Claude เขียน = ที่เหลือทั้งหมด

---

## 2. อยากแก้ X → ไปที่ไหนใน Explorer (สำหรับคนไม่โค้ด)

| อยากแก้ | Instance | แตะ logic ไหม |
|---------|----------|----------------|
| base follower ต่อเฟส / rate เงิน | `ReplicatedStorage.Shared.Config.PhaseConfig` | ❌ |
| ช่วงคะแนน tier C/B/A/S | `…Config.VidQConfig` | ❌ |
| ตัวเลข mental +/− | `…Config.MentalConfig` | ❌ |
| ราคา upgrade / ค่าเช่า | `…Config.EconomyConfig` | ❌ |
| เงื่อนไข % ending | `…Config.EndingConfig` | ❌ |
| บทพูด NPC | `…Content.Dialogue.<ชื่อ>` | ❌ |
| ข้อความ comment + choice | `…Content.Comments` | ❌ |
| บท Canon Event | `…Content.CanonEvents` | ❌ |
| บท ending cutscene | `…Content.Endings.<ชื่อ>` | ❌ |
| หน้าตา UI | `StarterGui.Gui_*` | ❌ |
| **สูตรคำนวณ** | `…Shared.Formulas` | ⚠️ เรียก Claude |
| **พฤติกรรมระบบ** | `ServerScriptService.Services.*` | ⚠️ เรียก Claude |

รูปแบบ Config/Content = ตาราง Lua ธรรมดา ตัวอย่าง:

```lua
-- ReplicatedStorage.Shared.Config.PhaseConfig
return {
	[1] = { gate = 10_000,    base = {400, 900},      moneyRate = 0.8 },
	[2] = { gate = 100_000,   base = {1_400, 2_600},  moneyRate = 1.2 },
	[3] = { gate = 1_000_000, base = {9_000, 15_000}, moneyRate = 1.5 },
}
```

แก้เลขในวงเล็บ เซฟ จบ — ไม่มี if ไม่มี function ให้พัง
**แก้เสร็จบอก Claude ให้ sync ลง repo ด้วย** (ไม่งั้น backup เก่า)

---

## 3. Data flow — Remote แค่ 2 เส้น

```
[ผู้เล่นกด Interact_Camera]
        │ ProximityPrompt (InteractBinder แปะให้อัตโนมัติ)
        ▼
client ──Action {type="RecordClip"}──▶  ActionRouter (server)
                                            │ แจกให้ FollowerService
                                            │ service เรียก Formulas + แก้ GameState
                                            ▼
client ◀──StateChanged {state ทั้งก้อน}── GameState
        │
        ▼
HUD / Apps อ่าน state ใหม่ → วาดจอใหม่
```

- **Action** (client→server): ทุกการกระทำวิ่งเส้นเดียว มี `type` บอกว่าทำอะไร
- **StateChanged** (server→client): state ทั้งก้อนส่งกลับทุกครั้งที่เปลี่ยน
  (singleplayer, state เล็ก — ไม่ต้อง optimize แยก field)

เพิ่มฟีเจอร์ใหม่ = เพิ่ม `type` ใน ActionRouter + 1 service function — ไม่สร้าง Remote ใหม่

**GameState หน้าตาเดียว รู้ไว้พอ:**

```lua
{
	follower = 0, money = 2500, mental = 80,
	phase = 1, day = 1, timeOfDay = 8,
	clips = {},        -- {vidqTier="B", uploaded=true, ...}
	choices = {plus=0, neutral=0, minus=0},
	upgrades = {camera=1, storage=1},
	calendar = {},     -- block ที่วางไว้
	flags = {},        -- canon event ที่ผ่านแล้ว
}
```

---

## 4. Backup mirror — Studio ↔ repo

Claude เป็นคนเดียวที่แตะ repo. ทุกครั้งที่ Claude เขียน/แก้ script ใน Studio ผ่าน MCP → เขียนไฟล์เดียวกันลง repo + commit

| Studio | repo |
|--------|------|
| `ReplicatedStorage.Shared.*` | `src/shared/…` |
| `ServerScriptService.Main`, `Services.*` | `src/server/…` |
| `ServerScriptService.Tests.*` | `tests/…` |
| `StarterPlayerScripts.*` | `src/client/…` |

ทีมแก้ Config/Content เองใน Studio ได้เลย ไม่ต้องแจ้ง — agent **pull จาก Studio ก่อนเริ่มงานทุก session** (workflow ⭐ ใน docs/08)

---

## 5. ลำดับ implement (ตาม dependency)

| # | งาน | ต้องมีก่อน |
|---|------|-----------|
| 1 | สร้าง Folder skeleton ทั้งหมดใน Studio + Config ครบทุกตัวเลขจาก design doc | — |
| 2 | `Formulas` + `Tests/RunTests` | 1 — **เทสก่อนคุ้มสุด** เพราะผูกคะแนนตรรกะระบบ 20pt |
| 3 | `GameState` + `ActionRouter` + Remotes 2 ตัว | 1 |
| 4 | `FollowerService` + `MoneyService` + `HUD` | 2, 3 — ได้ core loop เล่นได้ |
| 5 | `MentalService` + `PhaseService` | 4 |
| 6 | `InteractBinder` + `Apps` (Record→Edit→Upload→Feedback ก่อน) | 4 — ทีมสร้าง `Interact_` + `Gui_*` คู่ขนานได้เลย |
| 7 | `CalendarService` + Bank/Shop/CalendarApp | 5 |
| 8 | `DialogueUI` + Content.Dialogue | 3 — ไม่ block ใคร ทำแทรกได้ |
| 9 | `EndingService` + `CutscenePlayer` + Content.Endings | 5, 8 |

หลัง #4 เกมรันได้จริง — ที่เหลือเติมทีละระบบโดยไม่รื้อของเก่า

---

## 6. กติกากันพัง

1. **ตัวเลขใหม่ทุกตัวลง Config เท่านั้น** — เจอเลข hardcode ใน Services = bug ให้แจ้ง
2. Config/Content ทุกตัว `return` ตารางเดียว ไม่มี logic
3. Service ห้าม require กันเอง — คุยผ่าน GameState (กัน dependency พันกัน)
4. ทีมห้ามสร้าง/แก้ script เอง (กฎ docs/05 §5 เดิม) — วาง Part/Gui ชื่อถูกแล้วปล่อย
5. เพิ่ม NPC/event/ending = เพิ่ม ModuleScript ใน Content + ลงทะเบียน 1 บรรทัด — ห้ามแก้ engine
6. แก้อะไรใน Studio สำเร็จ → Save ทันที + แจ้ง Claude sync repo
