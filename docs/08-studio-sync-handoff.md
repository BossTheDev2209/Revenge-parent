# 08 — Studio Sync Handoff (สำหรับ agent ทุกตัวที่มาทำต่อ)

**เขียนเมื่อ:** 19 ก.ค. 2569 | **สถานะ: ✅ SYNC เสร็จแล้ว (19 ก.ค.)** — Config/Formulas/RunTests อยู่ใน Studio, เทส 46 ข้อผ่านใน Studio จริง
**อ่านก่อน:** `CLAUDE.md` → `docs/02` (ตัวเลข) → `docs/06` (โครง Studio) → ไฟล์นี้ (§6 วิธีคุย Studio MCP)

## ⭐⭐ Workflow ใหม่ (user สั่ง 1 ส.ค. 2569): **Rojo — disk = source of truth**

**แทนที่ Studio-first ด้านล่างสำหรับ "สคริปต์" · gen_sync/mcp_driver เหลือเป็น fallback**

- แก้ไฟล์ใน `src/` บนดิสก์ → **Rojo push เข้า Studio สดๆ อัตโนมัติ** (ไม่เปลือง token, ไม่ต้อง gen_sync/driver)
- ตั้งค่า: `rokit.toml` (pin rojo 7.7.0) + `default.project.json` (map เฉพาะ container ที่ src/ mirror)
- **ทุก node ใส่ `$ignoreUnknownInstances: true`** — Rojo แตะเฉพาะสคริปต์ที่ mirror · ของที่ Boss สร้างใน Studio (NPC, Remotes, HUD, map, รูป) **ไม่โดนแตะ** · Workspace/StarterGui/Lighting ไม่อยู่ใน map เลย
- เปิดใช้: `rojo serve` (terminal) → ใน Studio กดปุ่ม Rojo → **Connect** (localhost:34872) ครั้งเดียวต่อ session
- ⚠️ **หลัง connect: แก้สคริปต์บนดิสก์เท่านั้น** — แก้สคริปต์ใน Studio จะโดนดิสก์ทับตอน sync รอบถัดไป
  (ของ **ไม่ใช่สคริปต์** — โมเดล/NPC/รูป/UI instance — ยังทำใน Studio ตามเดิม ปลอดภัยด้วย ignoreUnknownInstances)
- รันเทสยังใช้ MCP `execute_luau` → `require(SSS.Tests.RunTests)` เหมือนเดิม (Rojo ทำแค่ sync)

### 🚨 ทะเบียน "Rojo incident" ทั้งหมดที่เคยเกิดในโปรเจกต์นี้ (audit ครบ 236 commit — 10 ส.ค. 2569)

ทุกเคสด้านล่างเกิดจริง มี commit อ้างอิงได้ · **ทั้งหมดมีจุดร่วมเดียวกัน: Rojo ไม่เคยแจ้ง error ตอนพัง**

| วันที่ | เคส | commit | เสียหายจริง |
|---|---|---|---|
| 21 ก.ค. | ถอด Rojo ออกทั้งโปรเจกต์ ต้องตามลบ `__Rojo_SessionLock` ที่ค้างใน Studio เอง | `b5e126d` | instance ขยะค้างใน place |
| 1 ส.ค. | plugin หลุดหลัง restart Studio → แก้โค้ดบนดิสก์แล้วไม่เข้า Studio → **เกือบ rewrite `InteractBinder` ทั้งไฟล์** ทั้งที่ logic ถูกอยู่แล้ว | `edfd7d5` (rule 10) | เกือบเสียงานทั้งไฟล์ |
| 9 ส.ค. | **full-sync destroy+recreate สคริปต์ทุกไฟล์จาก git** → งานที่ author ใน Studio แต่ยังไม่ commit **หายเกลี้ยง** (บทหมวย, Phase label, interaction) | `d269d81` (rule 12) | กู้คืนได้บางส่วนจาก JSON export → `ff77435`, `4e2bbf3` |
| 9 ส.ค. | sync รอบก่อนทิ้ง `ActivityCutscene` ซ้ำไว้ 2 ตัวใน `StarterPlayerScripts` (เนื้อหาเหมือนกันเป๊ะ) | `edc1827` | instance ซ้ำ เสี่ยง require ผิดตัว |
| 9 ส.ค. | รายงานว่า "อัดคลิปแล้ว footage ไม่เพิ่ม" → ไล่ debug logic เป็นชุด **สุดท้ายคือ stale sync เทสโค้ดเก่า** | `59d5f11` | เสียเวลา debug ของที่ไม่ได้พัง |
| 9→10 ส.ค. | `git mv` ไฟล์เข้า `src/client/StarterGui/` + ย้าย instance ใน Studio ครบ **แต่ลืมอัป `default.project.json`** → 11 โมดูล (HUD/SavePanel/PCScreen/Apps×8) แก้ทิ้งเปล่าอยู่ 1 วันเต็ม | `edc1827` → แก้ที่ `d2f24c4` | HUD ค้างค่า placeholder, ปุ่มเซฟเก่าโผล่ |

**pattern ที่ต้องระวัง (สรุปจากทั้ง 6 เคส):**

| pattern | อาการที่เห็น | วิธีจับ |
|---|---|---|
| **① silent no-op** — ไฟล์ไม่มีปลายทางใน map | แก้โค้ดแล้ว "ไม่มีอะไรเปลี่ยน" ไม่มี error เลย | เทียบ marker string / `#Source` ระหว่างดิสก์กับ instance ที่เกม require จริง |
| **② stale plugin** — Rojo หลุดหลัง restart | พฤติกรรมไม่ตรงโค้ด · แก้แล้วเหมือนไม่ได้แก้ | เช็คสถานะ connect **ก่อน** debug logic เสมอ (rule 10) |
| **③ destructive full-sync** — destroy+recreate ทุกไฟล์ | งานใน Studio ที่ยังไม่ commit หายหมด | ห้าม full-sync เด็ดขาด · commit ทันทีทุกครั้ง (rule 12) |
| **④ duplicate instance** | มีโมดูลชื่อซ้ำ 2 ตัว require ได้ผลไม่แน่นอน | สแกนชื่อซ้ำใต้ container ที่ Rojo จัดการ |
| **⑤ leftover session lock** | `ServerStorage.__Rojo_SessionLock` ค้างหลัง disconnect ไม่สะอาด | เช็ค instance ชื่อขึ้นต้น `__Rojo` |
| **⑥ ย้ายไฟล์แล้วลืม map** | เหมือน ① แต่เกิดหลัง refactor ย้ายโฟลเดอร์ | หลัง `git mv` ทุกครั้ง **ต้องเปิด `default.project.json` ทวนทันที** |

> **สภาพเครื่อง ณ 10 ส.ค.:** `rojo.exe` รัน 2 process ปกติ (shim ของ rokit + binary จริง 7.7.0) ฟังที่ port **34872** ตัวเดียว —
> ถ้าเจอ **หลาย port** ในช่วง 34870-34890 = มีหลาย session ชนกัน ให้ฆ่าให้เหลือตัวเดียวก่อนทำงาน

### ⚠️⚠️ กับดัก "แก้แล้วไม่มีอะไรเปลี่ยน" — ไฟล์ที่ไม่มีใน `default.project.json` = แก้ทิ้งเปล่า (เจอจริง 10 ส.ค. 2569)

`src/client` map ไป `StarterPlayerScripts` **ทั้งโฟลเดอร์** → `src/client/StarterGui/UI/HUD.luau` เลยไปโผล่ที่
`StarterPlayerScripts.StarterGui.UI.HUD` ซึ่ง**ไม่มีใคร require** ส่วนตัวจริงที่เกมใช้คือ `StarterGui.UI.HUD`
(instance baked ใน `.rbxl`) ที่ตอนนั้น **ไม่มีใน map เลย → Rojo ไม่เคยแตะ**

ผลคือแก้ `HUD.luau`/`SavePanel.luau`/`PCScreen.luau`/`Apps/*` บนดิสก์แล้ว **เกมยังรันโค้ดเก่า** โดยไม่มี error อะไรเลย
อาการที่เห็น: HUD โชว์ค่า placeholder ที่คนแต่ง GUI พิมพ์ไว้ (999,999) เพราะ `HUD.bind` หา path ไม่เจอ → ไม่เคยอัปเดต ·
ปุ่มเซฟเขียวตัวเก่าโผล่ตั้งแต่หน้าเมนู เพราะ `SavePanel` เวอร์ชันเก่ายังมี `buildButton` fallback อยู่

**แก้แล้ว 10 ส.ค.** — เพิ่ม node `StarterGui.UI` → `src/client/StarterGui/UI` ใน `default.project.json`

**กติกาสำหรับ agent ต่อไป — ก่อนแก้สคริปต์ใดๆ ใน `src/` ให้เช็คก่อนว่ามันมีปลายทางจริง:**
1. เปิด `default.project.json` ดูว่า path นั้นถูก map ไป container ไหน
2. ยืนยันใน Studio ว่า **ตัวที่เกม require จริง** อยู่ path เดียวกับที่ map (ไม่ใช่ instance ชื่อซ้ำคนละที่)
3. หลังแก้ ตรวจว่าเข้าจริง: `#instance.Source` หรือหา marker string ที่เพิ่งเพิ่ม — **อย่าเชื่อว่า Rojo connected = ทุกไฟล์ถึงปลายทาง**

> วิธีเทียบว่าดิสก์กับ Studio ตรงกันไหมโดยไม่ต้องอ่านทั้งไฟล์: normalize `\r\n` → `\n` แล้วเทียบ `#Source` + checksum
> (ใช้ยืนยัน 10 ส.ค. ว่า 9 จาก 11 โมดูลตรงกันเป๊ะ เหลือแค่ 2 ตัวที่ต่าง = ไม่มีงานใครค้างใน Studio ปลอดภัยที่จะเปิด map)

---

## ⚠️ Workflow เก่า (user สั่ง 20 ก.ค.) — **superseded โดย Rojo ข้างบนสำหรับสคริปต์**: Studio = ของจริงทุกอย่าง

*(ยังใช้ได้ถ้าไม่ได้เปิด Rojo — เช่น pull เนื้อหาที่ทีมแก้ใน Studio กลับมา, หรือ sync ผ่าน gen_sync/mcp_driver ตอน plugin ไม่ต่อ)*

- **ข้อมูลเกมทั้งหมด (script, Content, UIAssets, รูป) อยู่ใน Studio ที่เดียว** — เสมือนทีม 3 คนทำใน Studio ล้วนๆ
- repo `getting-1m-follower` = **backup + สะพาน**: docs ให้ agent อ่าน + git history กันงานหาย — ไม่ใช่ที่ทำงานจริง
- **agent เริ่มงานทุกครั้ง: pull จาก Studio ก่อน** — ทีมอาจแก้ Config/Content ใน Studio ไปแล้ว
  (`script_read` หรือ execute_luau dump `.Source` → เทียบ/เขียนทับไฟล์ mirror ใน repo → commit "sync-back")
- แก้โค้ด: เขียนเข้า Studio ผ่าน MCP → mirror ลง repo → commit (ลำดับนี้ ไม่ใช่กลับกัน)
- รูปภาพ: ทีมอัปโหลดใน Studio ได้ asset id → ใส่ `ReplicatedStorage.Shared.UIAssets` ใน Studio ตรงๆ ได้เลย
- TDD local (lune) ยังใช้ได้ — รันกับ mirror ใน repo หลัง pull ล่าสุด

## 0. วิธีคุยกับ Studio MCP จาก session ที่ tool ไม่โหลด (ใช้จริงมาแล้ว)

MCP `Roblox_Studio` ลงทะเบียนใน local config แล้ว — session ใหม่ได้ tool `mcp__Roblox_Studio__*` ปกติ (ยืนยันแล้ว 19 ก.ค.)
ถ้า tool ไม่โผล่ ใช้ **direct stdio driver**: `tools/mcp_driver.py` — และ **driver ใช้คู่กับ native session ได้** (WS host รับหลาย client)
payload ใหญ่ (sync ทั้งชุด) ใช้ driver สะดวกกว่า (python อ่านไฟล์จาก disk ตรง) — native tool เหมาะกับ call สั้นๆ (play/console/inspect)

```bash
# steps.json = [{"tool": "...", "args": {...}}, ...]
python tools/mcp_driver.py steps.json
```

### ⭐ sync ทั้งโปรเจกต์ในคำสั่งเดียว (ท่ามาตรฐาน — เร็วกว่ายิงทีละไฟล์มาก)

```bash
python tools/gen_sync.py /tmp/sync_all.luau
python tools/mcp_driver.py /tmp/steps.json
```

`tools/gen_sync.py` **สแกน `src/` + `tests/` จากดิสก์เอง** (ไม่มี list ให้ลืมอัปเดต) แล้ว gen เป็น luau ก้อนเดียว
ที่ `folder()` สร้างโฟลเดอร์ที่ขาด + `put(parent, name, class, [=====[...]=====])` ทุกไฟล์
`steps.json` ใช้ step แบบ `luau_file` ชี้ไปที่ไฟล์ที่ gen มา — ไม่ต้อง inline โค้ดในแชท:

```json
[{"tool": "execute_luau", "luau_file": "C:/.../sync_all.luau", "args": {"datamodel_type": "Edit"}}]
```

แผนที่ path: `src/shared/**` → `RS.Shared` · `src/server/Services/**` → `SSS.Services` · `src/client/**` → `SPS`
· `src/server/Main.server.luau` → `SSS.Main` (Script) · `src/client/Main.client.luau` → `SPS.Main` (LocalScript) · `tests/RunTests.luau` → `SSS.Tests.RunTests`

ข้อเท็จจริงที่เจ็บมาแล้ว (อ่านก่อนใช้):
- **`execute_luau` ต้องส่ง `"datamodel_type": "Edit"` เสมอ** ไม่งั้น error
- **StudioMCP.exe = WS host ที่ Studio ต่อเข้ามา** — รันได้ทีละตัว (bind port 13469)
  โปรเซสเก่าค้าง = ตัวใหม่ต่อไม่ได้ ("Not connected to the WS host") → `taskkill //F` ตัวเก่าก่อน
  driver ฆ่าตัวเองตอนจบแล้ว แต่เช็ค `tasklist //FI "IMAGENAME eq StudioMCP.exe"` ถ้าเจอปัญหา
- step แรกของ batch retry 60 วิอัตโนมัติ (รอ Studio plugin reconnect เข้า host ใหม่)
- path ใน steps.json ต้องเป็น Windows format (`C:/...`) ไม่ใช่ git-bash (`/c/...`)
- ส่ง source code เข้า Studio: ห่อด้วย long bracket `[=====[ ... ]=====]` (เช็คก่อนว่า source ไม่มี `]=====]`)
- เทสใน Studio ไม่ต้องกด Play: `execute_luau` รัน `RunTests.Source` แล้ว **อ่าน table ที่ return** (`{pass, fail, failures}`) — RunTests คืนผลตรงๆ ไม่ต้อง clone/patch print/pcall probe อีก
- tool มีครบ 27 ตัว: `execute_luau`, `inspect_instance`, `script_read`, `multi_edit`, `search_game_tree`, `get_console_output`, `start_stop_play`, `screen_capture` ฯลฯ
- **Place เป็น Team Create** — ทีมออนไลน์พร้อมกันได้ ระวังแก้ชนกัน + Team Create autosave เอง
- **Studio require cache:** อัป `Source` ของ ModuleScript ที่เคยถูก require แล้ว = โมดูลเก่ายังถูก cache
  → sync module ที่แก้แล้วต้อง **`:Destroy()` instance เดิมแล้วสร้างใหม่** (เฉพาะของเราเอง — ของทีมห้ามแตะ)
  require ตาม path จะเจอ instance ใหม่ = fresh เสมอ
- **Module state ค้างข้ามรอบเทส:** service ที่มี state ภายใน (ActionRouter handlers, TimeService callbacks)
  จะสะสม state ถ้าเทสรันซ้ำใน session เดิม → **ก่อน verify ทุกรอบ replace service ที่ stateful ทั้งหมด**
  (ปัจจุบัน: ActionRouter, TimeService — เพิ่ม service ใหม่ที่มี state = เพิ่มใน list นี้)

---

## 1. สภาพปัจจุบัน (ณ commit `77b0f54`)

| ของ | ที่อยู่ | สถานะ |
|-----|---------|-------|
| Config ตัวเลขทั้งเกม | `src/shared/Config.luau` | ✅ ครบ ตรง design doc — ไฟล์เดียว ไม่แตก 7 ไฟล์ (ตัดสินใจแล้ว: ctrl+F ง่ายกว่าสำหรับทีม) |
| Formulas 7 functions | `src/shared/Formulas.luau` | ✅ ผ่านเทส 46 ข้อ |
| เทส | `tests/RunTests.luau` | ✅ dual-mode: lune local + Studio Script |
| ใน Studio | `ReplicatedStorage.Shared.Config` + `.Formulas`, `Shared.Remotes.Action/StateChanged`, `ServerScriptService.Main` (Script รันจริง), `Services.GameState` + `.ActionRouter`, `Tests.RunTests` (Disabled) | ✅ sync แล้ว 19 ก.ค. — เทสรันใน Studio ผ่าน 65/65 |
| GameState + Save 4 slot + ActionRouter | `src/server/Services/`, `src/server/Main.server.luau` | ✅ เสร็จ 19 ก.ค. (`plans/2026-07-19-gamestate-actionrouter.md`) |
| TimeService + Mental(พื้นฐาน) + Follower + Money + HUD placeholder + client Main | `src/server/Services/`, `src/client/` | ✅ เสร็จ 19 ก.ค. — core loop เดโม่ได้ (`plans/2026-07-19-timeservice.md`, `plans/2026-07-19-coreloop.md`) |
| Edit QTE + InteractBinder + Activity system | `src/client/UI/Apps/EditQTE.luau`, `src/client/InteractBinder.luau` | ✅ เสร็จ 19 ก.ค. — เล่นเต็ม loop ด้วยมือ, placeholder `Interact_*` neon 4 จุดใกล้ spawn (ทีมย้ายได้) (`plans/2026-07-19-qte-interact.md`) |
| **Engines ครบชุด**: Dialogue / Comment / Calendar+Sponsor / Ending / Cutscene / Canon events | `src/server/Services/{Comment,Calendar,Ending}Service.luau`, `src/client/UI/{DialogueUI,CutscenePlayer,CommentUI}.luau`, `src/shared/Content/**` | ✅ เสร็จ 19 ก.ค. — เทส 151/151 (`plans/2026-07-19-engines-complete.md`) |

**Actions ทั้งหมดที่ระบบรับ (client → `Remotes.Action`):**
`FinishEdit{score}` `UploadClip{clip|"latest"}` `DoActivity{activity="Bed|Kitchen|Exercise"}` `AnswerComment{reply=1..3}` `PlaceBlock{day,id}` `AcceptSponsor{day}` `FreezeTime{on}` `EventSeen{id}` `RequestSlots{}` `LoadSlot{slot}` `SaveSlot{slot?}` `NewGame{slot}`

**⚠️ Save ใช้จริงต้องเปิด:** Game Settings → Security → Enable Studio Access to API Services (place ต้อง publish ก่อน) — ยังไม่เปิด = 403 warn แต่เกมเล่นได้

**ทีมเติมบท = แก้เฉพาะ `ReplicatedStorage.Shared.Content/**` (หรือ `src/shared/Content/` แล้วให้ Claude sync):**
Dialogue 6 ไฟล์ (tag `[slow][fast][normal]`) | Comments (pool + replies 3 tag pos/neu/neg) | CanonEvents (milestone_*) | Endings 6 ไฟล์ (step: text/wait/camera) — ทุกไฟล์มี format ตัวอย่างใน comment หัวไฟล์ ห้ามแตะโค้ดนอก Content
| ของเดิมใน Studio ก่อน sync | `Shared.Hello`, `ServerScriptService.Server`, `StarterPlayerScripts.Client` | template hello-world — **ปล่อยไว้ ไม่ลบ** (กฎห้ามลบของเดิม) |

Test runner local: `lune` binary อยู่ scratchpad (หายได้ — โหลดใหม่: GitHub lune-org/lune release `windows-x86_64.zip` แตก zip รัน `lune.exe run tests/RunTests.luau`)

**หมายเหตุ docs/06:** เขียนไว้ว่า Config แยก 7 ไฟล์ — ความจริงใช้ไฟล์เดียว `Config.luau` (reuse ของที่มีอยู่ก่อน) โครงส่วนอื่นตาม docs/06 ปกติ

---

## 2. เงื่อนไขก่อนเริ่ม: Studio MCP ต้องต่ออยู่

Session 19 ก.ค. ไม่มี Studio MCP → ทำไม่ได้ ถ้าเซสชันของคุณ search tool แล้วไม่เจอ (`ToolSearch "roblox studio"`) แปลว่ายังไม่ต่อ ให้บอก user ว่า:

1. เปิด Roblox Studio + เปิด place ของโปรเจกต์
2. ติดตั้ง/เปิดปลั๊กอิน official Roblox Studio MCP (github.com/Roblox/studio-rust-mcp-server) แล้วลงทะเบียนกับ Claude (`claude mcp` ใน session interactive)
3. เปิดเซสชันใหม่

**ห้าม** พยายามเขียน script เข้า Studio ผ่าน UI automation (Windows-MCP/computer-use) — เสี่ยงพังของที่ทีมปั้นมือ

---

## 3. งานที่ต้องทำผ่าน Studio MCP (ตามลำดับ ห้ามสลับ)

กฎเหล็กระหว่างทำ (จาก `CLAUDE.md` + `docs/05 §6`):
- **ห้ามลบ/แก้ instance ที่มีอยู่แล้ว** โดยไม่ถาม user — ของทีมปั้นมือ
- สร้างใหม่/อ่าน = ทำได้เลย
- ถ้าเจอ instance ชื่อชนกับที่จะสร้าง → หยุด ถาม user

### 3.1 สร้าง skeleton (ตาม docs/06 §1)

```
ReplicatedStorage
└── Shared (Folder)
    └── Remotes (Folder)
        ├── Action (RemoteEvent)
        └── StateChanged (RemoteEvent)
ServerScriptService
├── Services (Folder)
└── Tests (Folder)
```

(`Main`, `StarterPlayerScripts` ยังไม่ต้อง — สร้างตอนแผน service ถัดไป)

### 3.2 ยก 3 ไฟล์เข้า Studio — **copy source ตรงๆ ห้ามแก้**

| repo | Studio instance | ประเภท |
|------|-----------------|--------|
| `src/shared/Config.luau` | `ReplicatedStorage.Shared.Config` | ModuleScript |
| `src/shared/Formulas.luau` | `ReplicatedStorage.Shared.Formulas` | ModuleScript |
| `tests/RunTests.luau` | `ServerScriptService.Tests.RunTests` | **Script, Enabled = false** |

โค้ดรองรับสองโหมดแล้ว (`local isStudio = script ~= nil` แตก branch require เอง) — วางแล้วใช้ได้เลย

### 3.3 Verify ใน Studio

1. ติ๊ก `RunTests.Enabled = true`
2. กด Play (หรือ Run)
3. Output ต้องขึ้น `Tests: 46 passed, 0 failed`
4. ติ๊ก Enabled กลับเป็น false
5. **Save place**

ถ้า fail: debug ได้ทั้งสองทาง แต่**ผลสุดท้ายต้องลงเอยใน Studio** แล้ว mirror กลับ repo (Studio = ของจริง — ดู ⭐ Workflow ข้างบน)

### 3.4 หลังผ่าน

- commit repo ถ้ามีอะไรเปลี่ยน + อัปเดตสถานะใน `docs/04-timeline.md`
- บอก user ว่า Studio มีสมองเกมแล้ว ทีมสร้างฉาก/`Interact_`/`Gui_*` ต่อได้ (docs/05 §1, docs/06 §1 ท้ายตาราง)

---

## 4. แผนถัดไปหลัง sync เสร็จ (เรียงตาม docs/07 §4)

แต่ละอันต้องผ่าน superpowers: **plan ใน `plans/` → TDD → implement** (ดูตัวอย่างแผนที่ทำเสร็จแล้ว: `plans/2026-07-19-config-formulas.md`)

| # | ระบบ | design อยู่ | หมายเหตุ |
|---|------|-------------|----------|
| 1 | GameState + Save (4 slot) + Remotes + ActionRouter | docs/07 §3.2 | state shape อยู่ docs/06 §3 |
| 2 | TimeService + wiring ใน Main | docs/07 §3.1 | ตัวเลขเวลา: PDF หน้า 6 (design doc ไม่มี — flag แล้ว) |
| 3 | MentalService | docs/07 §3.5 | drain mods ยังไม่ design ละเอียด — ต้องถาม user เรื่องอายุ modifier |
| 4 | FollowerService + MoneyService + HUD | docs/07 §4 | Formulas พร้อมแล้ว แค่ต่อท่อ |
| 5 | Edit QTE | docs/07 §3.4 | client ล้วน |

## 5. Gotchas ที่เจอมาแล้ว (อย่าเหยียบซ้ำ)

- **Config หน่วย %** (33 ไม่ใช่ 0.33) + key ชื่อ `cMin/bMax/posMin/negMax/spreadMax` — Formulas อิงชื่อพวกนี้
- **ลำดับ rng ใน `followerGain`:** ① base ② mentalZone ③ viralChance ④ viralMult — เทส fix ตามลำดับนี้ ห้ามสลับ
- **เงื่อนไข ⊖ = 50% พอดี → โดน Bad3 กิน** (`negMin = 50` เป็น ≥) — เคยเขียนเทสผิดมาแล้ว
- **Good1 = AND** (vidq และ choice ต้องผ่านทั้งคู่) — ending อื่น OR; hardcode ใน `resolveEnding` พร้อม comment
- resolveEnding fallback = `Neutral2` เมื่อไม่เข้าเงื่อนไขไหนเลย
- `Bad1`/`Bad2` อยู่ใน `EndingPriority` แต่ไม่มี threshold — resolver ข้าม, trigger สดกลางเกม (MoneyService/MentalService)
- PDF ต้นฉบับ (`assets/reference/*.pdf`): **ขีดดำ = ตัดชั่วคราวไม่ใช่ลบ**, โน้ตเก่ากว่า design doc — ขัดกันยึด design doc
