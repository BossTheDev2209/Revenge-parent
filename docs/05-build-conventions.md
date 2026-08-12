# 05 — Build Conventions (Studio)

**ใครต้องอ่าน:** ทุกคนที่แตะ Roblox Studio + Claude Code (อ่านผ่าน CLAUDE.md)
**ทำไมต้องมี:** Claude สั่ง Studio ผ่าน MCP **ด้วยชื่อ instance** ถ้าตั้งชื่อมั่ว มันหาไม่เจอ ต้องมารื้อทีหลัง
**สถานะ:** draft — แก้ได้ ตกลงกันในทีมแล้วค่อย commit

---

## 1. สร้างได้เลยวันนี้ ไม่ต้องรอ architecture

Architecture = follower คำนวณยังไง / เก็บ state ที่ไหน / server-client คุยกันยังไง
**ไม่แตะ geometry เลย** → งานล่างนี้ทำคู่ขนานได้ ไม่มีทางต้องรื้อเพราะโค้ด

| งาน | เงื่อนไขเดียวที่ต้องทำตาม |
|-----|---------------------------|
| ห้องเช่า (ผนัง พื้น หน้าต่าง ประตู) | §2 ตั้งชื่อ |
| โต๊ะ + คอม + กล้อง + ไฟ | §2 + §3 แยก `Interact_` ออกมา |
| เตียง / ครัว / มุมออกกำลังกาย | §3 — 3 จุดนี้คือ Activity system (design doc §3) ขาดไม่ได้ |
| Lighting, บรรยากาศ, props | ไม่มี — ทำอิสระ |
| ตัวละครหลัก + แม่ (R6 classic) | §4 |
| NPC 6 ตัว (โมเดล + จุดยืน) | §4 |
| UI mockup (หน้าตาเฉยๆ ยังไม่ต่อ logic) | ตั้งชื่อให้รู้เรื่อง |

**ทำได้เลย = ทำเลย** อย่ารอ Claude เขียน service เสร็จ มันเขียนเร็วกว่าเราสร้างฉากอยู่แล้ว ให้มันตามเรา

---

## 2. ตั้งชื่อทุกอย่าง — ห้าม Part / Part2 / Model

รูปแบบ: `หมวด_ชื่อ` ภาษาอังกฤษ ไม่มีเว้นวรรค

```
Room_Player          ห้องเช่าทั้งห้อง (Model ครอบ)
Desk_Setup           โต๊ะทำงาน
Furniture_Bed
Furniture_Kitchen
NPC_Mom
NPC_01_<ชื่อ>  ...  NPC_06_<ชื่อ>
Interact_Camera      (ดู §3)
```

ผิด: `Part`, `Model`, `MeshPart5`, `โต๊ะ`, `desk final ver2`

---

## 3. จุดที่ผู้เล่นจะกด = Part แยกชิ้น ชื่อขึ้นต้น `Interact_`

**อย่าฝังรวมเป็นก้อนเดียวกับเฟอร์นิเจอร์** — Claude ต้องแปะ ProximityPrompt/ClickDetector ลงไปทีหลัง ถ้าไม่มี Part แยก มันแปะไม่ได้

จุดที่ต้องมีแน่นอน:
```
Interact_Camera      ถ่าย/ตัดคลิป
Interact_Bed         พักผ่อน   → mental +25
Interact_Kitchen     กินข้าว   → mental +15
Interact_Exercise    ออกกำลังกาย → mental +20
Interact_NPC_<ชื่อ>  คุย NPC — ชื่อ Part = ชื่อโมเดลตัด prefix (ดู §4 ล่าง)
```

### NPC roster (อัป 10 ส.ค. 2569 — 17 ตัว, ตั้งชื่อจริงแล้วตั้งแต่ 5 ส.ค.)

ชื่อ Part interact ใน**แต่ละโมเดล** (เป็น Part ลูกของ model นั้นตรงๆ ไม่ใช่โฟลเดอร์แยก) = `Interact_NPC_<ชื่อ>`
บทผูกจากชื่อนี้ในตาราง `NPC_DIALOGUE` (`InteractBinder.luau:37`) → ไฟล์ใน `Content/Dialogue` **ชื่อไฟล์ = ชื่อ NPC ตรงๆ** (ไม่มี key กลาง Mom/Friend1/CC1 แล้ว — เลิกใช้ตั้งแต่ 5 ส.ค. 2569)

**5 พิเศษ (เนื้อเรื่อง) — `Workspace.NPC.StoryNPC`** เจอได้หลายเฟส บทเปลี่ยนตามเฟส (p1/p2/p3/after):

| โมเดล | ไฟล์บท | ใคร |
|---|---|---|
| `NPC_special_แม่` | `Content/Dialogue/แม่.luau` | แม่ |
| `NPC_special_พ่อ` | `Content/Dialogue/พ่อ.luau` | พ่อ |
| `NPC_special_ฟ้าใส` | `Content/Dialogue/ฟ้าใส.luau` | เพื่อนร่วมทางคนแรก (ทรยศ 500K) |
| `NPC_special_เจียเจีย` | `Content/Dialogue/เจียเจีย.luau` | เพื่อนร่วมทางคนสอง (อยู่จนจบ) |
| `NPC_special_พี่เปิ้ล` | `Content/Dialogue/พี่เปิ้ล.luau` | Content Creator คู่แข่ง/ตัวร้ายเบื้องหลัง |

ชื่อพวกนี้ตรงกับ `AnimPlayer.ACTOR_MODEL` ด้วย ([AnimPlayer.luau:33-51](../src/client/AnimPlayer.luau#L33)) — step `anim`/`face`/`move` ใน cutscene ใช้ actor string เดียวกันนี้ (เช่น `{type="anim", actor="ฟ้าใส", ...}`) หา rig จากชื่อนี้ตรงๆ

**12 ประจำเฟส (คนละคนต่อเฟส 4/เฟส) — `Workspace.NPC.WorldNPC`** บทเดี่ยว บางตัวมีช้อย:

| เฟส | โมเดล → ไฟล์บท |
|---|---|
| 1 | ลุงสืบ · พี่แหนม · ลุงชัย · ป้าไหม |
| 2 | หมวย · ออโต้ · ลุงฮาซาน · พี่โชคชัย |
| 3 | น้ำปั่น · เกรซ · พี่มีนา · ลุงนรินท์ |

> ไฟล์บททั้ง 17 อยู่ `ReplicatedStorage.Shared.Content.Dialogue.*` (12 world ยัง `[placeholder]` รอเขียน)
> ⚠️ ไฟล์เก่า `Landlord` / `Hater` ยังอยู่แต่**ไม่มี NPC ผูก** — บอสจะรีไซเคิลเป็นตัวไหนก็ map เพิ่มใน `NPC_DIALOGUE` เอง หรือลบทิ้ง

**บทเปลี่ยนเองตามเฟส** — NPC ตัวเดียววางครั้งเดียวพอ ระบบเลือกบทให้ตามเฟสปัจจุบัน + สถานะทรยศ (ทีมไม่ต้องทำอะไรเพิ่ม)

### ✅ ตัว NPC สร้างรอไว้แล้ว (29 ก.ค. 2569) — `Workspace.NPC`

```
Workspace/NPC/
  R6              ← rig ต้นแบบเดิม (ไม่แตะ)
  NPC_Template    ← ก๊อปไปทำตัวใหม่
  NPC_01_ป้าแดง · NPC_02_เจ · NPC_03_ปาล์ม · NPC_04_ไคโตะ · NPC_05_เกรียน
```

ทุกตัวเตรียมให้แล้ว: `Animator` (ไม่มีอันนี้ท่าไม่เล่น) · `Shirt`/`Pants` ว่างรอ id · attachment ครบ 19 จุด (ผม/หมวก/แว่น/กระเป๋าหลังแปะติดหมด) · `Head.face` · ป้ายชื่อลอย · `Interact_NPC_0X` ในตัวโมเดล · ปิดชื่อ+หลอดเลือดของ Roblox · **anchor เฉพาะ HumanoidRootPart** (anchor ทั้งตัว = ท่าไม่ขยับ)

**เหลือให้ทีมทำ:** ใส่ `ShirtTemplate`/`PantsTemplate` id → ใส่ Accessory (ผม/หมวก) → เปลี่ยน `Head.face.Texture` → ลากตัวไปวางจุดที่ต้องการในแมพ (ลากทั้งโมเดล `Interact_` ติดไปเอง)

#### คลังของแต่งตัว — `ReplicatedStorage.Accessories` (ทำไว้แล้ว 29 ก.ค.)

```
Accessories/
  Hair/     Hair_Messy
  Hat/      Hat_Beanie · Hat_Cap
  Glasses/  Glasses_Oliver · Glasses_Round
  Neck/     Scarf_Knit
  Back/     Backpack_Basic
  Waist/    Belt_Simple
```

ตัวอย่างใส่ครบชุดดูได้ที่ `NPC_03_ปาล์ม` (หมวก+แว่น+ผ้าพันคอ+กระเป๋า+เข็มขัด) · `NPC_02_เจ` (ผม)

> ⚠️ **ของฟรีใน Toolbox เชื่อไม่ได้** — ที่เจอมากับตัว: แถม Script/RemoteEvent มา 12 ตัว (backdoor เสี่ยงเกมโดนแฮก), เข็มขัดที่จริงเป็นโมเดลตัวละครทั้งตัวพร้อมไฟล์เสียง, กระเป๋าติดหน้าอกแทนหลัง, ผ้าพันคอใหญ่คลุมหัว
> → **ห้ามลากของจาก Toolbox เข้าเกมตรงๆ** ให้ผ่าน `tools/normalize_accessories.luau` ทุกชิ้น มันจะ:
> ลบ script/เสียงที่แถมมา · เปลี่ยนชื่อ Handle/attachment ให้ถูก · รีเซ็ต offset ที่ตั้งมามั่ว · ย่อขนาดให้พอดีตัว R6 · จัดเข้าโฟลเดอร์หมวด
>
> **ตั้งชื่อของใหม่ให้ขึ้นต้นด้วยหมวด** (`Hair_` `Hat_` `Glasses_` `Scarf_` `Backpack_` `Belt_`) ไม่งั้นสคริปต์ไม่รู้ว่าจะเอาไปแปะจุดไหน

#### ใส่ Accessory ยังไง (ตัวอย่างทำไว้แล้วที่ `NPC_02_เจ`)

⚠️ **ลาก Accessory เข้าโมเดลเฉยๆ ใน Edit mode มันไม่ติด** — ต้องเชื่อม attachment เอง ใช้ `tools/attach_accessory.luau` แทน

1. หาของ: Toolbox ค้น "hair"/"hat" (หรือให้ agent ใช้ `search_asset`) → เอา asset id
2. insert เข้า `ReplicatedStorage.Accessories` (คลังกลาง เอาไปใช้ซ้ำกับตัวอื่นได้)
3. แก้ 2 บรรทัด `CONFIG` ในไฟล์ (ชื่อ NPC + ชื่อ Accessory) แล้วรันผ่าน `tools/mcp_driver.py`
   → สคริปต์หา attachment คู่กันเอง (`HairAttachment`/`HatAttachment`/...) วางตำแหน่ง + weld ให้ครบ
   → ของชนิดเดียวกันที่ใส่อยู่เดิมถูกถอดออกก่อน (ใส่ผมทับผมจะทะลุ)
สร้างใหม่/สร้างซ้ำ: `tools/build_npc_template.luau` (รันผ่าน `tools/mcp_driver.py`)

**คลังท่าทาง/สีหน้า สร้างแล้วเช่นกัน:** `ReplicatedStorage.Animations` และ `.Faces` มีโฟลเดอร์ย่อยต่อตัวละครรออยู่ (วิธีใส่ → `docs/engines/dialogue.md §2.5`)

- ทำเป็น Part โปร่งใส (Transparency 1) วางทับจุดนั้นก็ได้ ไม่ต้องสวย
- **ห้องสวยแค่ไหน ถ้าไม่มี `Interact_` = ต่อ logic ไม่ได้**
- ⚠️ **ชื่อห้ามมีเว้นวรรคหน้า/ท้าย** — `"Spawn_Phase1 "` กับ `"Spawn_Phase1"` คนละชื่อ โค้ดหาไม่เจอ (เจอจริง 2 ส.ค.) · โค้ดจะไม่เดา/ไม่ trim ให้ ต้องตั้งชื่อให้ตรงเป๊ะ
- ⚠️ **NPC จัดท่านิ่งใน cutscene ต้อง anchor ทุก part** — R6 rig ที่ไม่ anchored พอ play จริง physics + Motor6D joint ประกอบร่างกลับท่ายืน (+ Animate script เล่น idle ทับ) = ท่าที่จัดหายหมด (เจอจริง 2 ส.ค. ฉากพ่อแม่ที่ `Map_Phase0.npc`) · **fix:** anchor **ทุก** BasePart (ไม่ใช่แค่ HumanoidRootPart) + `Humanoid.AutoRotate = false` · anchored part นิ่งสนิท joint/physics/Animate ขยับไม่ได้ · จะขยับจริงค่อยใช้ระบบ `anim` (ต้อง unanchored + มี Animation object)
- ⚠️ **ล็อกการเดิน player ต้องตั้ง `MoveLocked` ด้วย ไม่ใช่แค่ WalkSpeed=0** — `StarterCharacterScripts.SprintHandler` คุม WalkSpeed อยู่ (Shift = วิ่ง) ถ้าตั้งแค่ `WalkSpeed = 0` มันจะ set ทับกลับ = เดินได้ระหว่าง cutscene (เจอจริง 5 ส.ค.) · **fix:** `Humanoid:SetAttribute("MoveLocked", true)` ตอนล็อก แล้ว `SetAttribute("MoveLocked", nil)` ตอนปลด — SprintHandler เห็นแล้วหยุดยุ่ง + คืนความเร็วเองตอนปลด · ตั้งอยู่แล้วที่ `CutscenePlayer` และ `MenuUI.freezeCharacter` · สคริปต์ตัวจริงอยู่ Studio สำเนาที่ [src/studio-only/](../src/studio-only/README.md)
- ⚠️ **Lighting ผูกนาฬิกาเกม — ห้ามใส่ day/night loop แยก** — `Lighting.ClockTime` ขับจาก `state.timeOfDay` ที่ Main.server (`syncLighting`) เท่านั้น freeze เวลา (cutscene/เมนู/คุย) = ฟ้าหยุดด้วย · Toolbox `ServerScriptService.DayNight` เดิน ClockTime เองไม่สน freeze → **ปิด (Disabled=true) แล้ว 2 ส.ค.** อย่าเปิดคืน/อย่าใส่ script เดินฟ้าเองใหม่ (เจอจริง: cutscene ฟ้าเพี้ยน/ข้ามวันเพราะ 2 นาฬิกาแยกกัน) · `autoturnlight` (ไฟถนน Toolbox) อ่าน ClockTime = ตามเวลาเกมเอง
- ⚠️ **วาปข้ามแมพ (TeleportTo) ต้องรอ stream โหลดก่อนเผยจอ** — StreamingEnabled ทำให้แมพปลายทางยังไม่โหลดตอนวาปถึง (เห็นห้องโล่ง/ตกทะลุพื้น) · `Main.client.waitStreamedAround` เรียกตอนจอดำใน transition: anchor ตัวกันตก → รอ raycast เจอพื้น → ค่อย fade กลับ (timeout 6s) · server `TeleportTo` เรียก `RequestStreamingAround` สั่ง preload จุดปลายทาง (มีเฉพาะ live Roblox — Studio เก่าไม่มี pcall กันไว้) · **teleport ใหม่ให้ผ่าน pattern นี้ อย่าวาปแล้วเผยจอทันที**
- ⚠️ **CutsceneCams ต้อง Persistent (StreamingEnabled เปิดอยู่)** — cam มักวางไกลจุดที่ player ยืนตอนเล่น cutscene → streaming ตัด Part ออกจาก client → `CutscenePlayer` (รัน client) หา cam ไม่เจอ กล้องค้าง (เจอจริง 2 ส.ค.) · **fix:** cam ต้องอยู่ใน `Model` ที่ `ModelStreamingMode = Persistent` · **CutsceneCamTool ทำให้อัตโนมัติ** (Model ต่อ cutscene = `CutsceneCams/<Scene>/`) — วางด้วย plugin ก็ปลอดภัยเลย ไม่ต้องห่อเอง
- ⚠️ **Union/MeshPart หายตอนมองไกล (LOD imposter ใต้ StreamingEnabled)** — Roblox แทน Union/MeshPart ระยะไกลด้วย imposter 2D บางทีหายทั้งชิ้น · **fix ต้องทำตอน edit-time เท่านั้น:** `Model.LevelOfDetail` เป็น plugin-only property — สคริปต์ในเกม (Script/LocalScript) อ่าน/เขียนไม่ได้เลย (`lacking capability Plugin`) ห้ามพยายามแก้ด้วย runtime script · **เครื่องมือ:** `tools/LodFix.plugin.luau` (toolbar "Streaming Fix" → "Fix LOD") ปิด LOD ให้ **ทุก Model ที่มี Union/MeshPart (ทุกขนาด)** — imposter เกิดที่ระดับโมเดล ไม่เกี่ยวขนาดชิ้น (แมพนี้ mesh เล็กหมด เคยกรอง ≥6 stud เลยจับได้ 0 · แก้ 9 ส.ค.) · ติดตั้งด้วย `tools/install_plugin.ps1` · **รันซ้ำทุกครั้งที่เพิ่ม union/mesh model ใหม่ แล้ว Ctrl+S บันทึก `.rbxl` ไม่งั้น revert** (การเซ็ต property อยู่ใน place ไม่ใช่ `src/` — git ไม่ track) · รายละเอียด: memory `lod-levelofdetail-plugin-only.md`

ชื่อพิเศษเพิ่มเติม (ระบบใหม่):
```
CutsceneCams (Folder ใน Workspace) → <Scene>/<Scene>_<เลข>  มุมกล้อง cutscene เช่น Opening/Opening_1
FilmSpot_<ชื่อจุด>                                        จุดกดถ่ายคลิป (ระบบ Record — docs/09 §4)
Spawn_Phase<N>                                            จุดที่ player โผล่เมื่อเข้าเฟสนั้น (intro ใช้ Spawn_Phase1)
Interact_Shop                                             ร้านขายอุปกรณ์ในแมพ (docs/09 §10)
ReplicatedStorage.ToolModels → Camera_1..6 / Selfie / Notebook / NotebookPlaced / CameraCart   โมเดล Tool (§3.6)
Zone_<ชื่อ>                                               โซนเพลง (Attribute Music/Ambient/Priority)
Buy_<ชื่อ> + Item_<ชื่อ>                                   ปุ่ม tycoon + ของที่โผล่ (§3.5)
```

### 3.6 โมเดล Tool — `ReplicatedStorage.ToolModels` (lock 27 ก.ค.)

**StarterPack ต้องว่างเสมอ** — `ToolService` แจก Tool ให้เองตาม state (อัปกล้อง/ข้ามเฟส = สลับให้ทันที)
ทีมมีหน้าที่**เปลี่ยนโมเดลข้างใน** ห้ามเปลี่ยนชื่อ ห้ามใส่ script

| ชื่อใน ToolModels | คืออะไร | โผล่ตอนไหน |
|---|---|---|
| `Camera_1` | **มือถือ** 480p | เริ่มเกม |
| `Camera_2` | มือถือใหม่ 720p | ซื้อในแอป Shop |
| `Camera_3` | กล้อง compact 1080p | ” |
| `Camera_4` | กล้อง mirrorless 1440p | ” |
| `Camera_5` | กล้องโปร 2160p | ” |
| `Camera_6` | กล้องซินิมา 4320p | ” |
| `Notebook` | โน้ตบุ๊คพับเก็บ (Tool) | **เฟส 1 เท่านั้น** ตอนยังไม่ได้วาง |

> **อุปกรณ์ถ่ายมีสายเดียว** (lock 27 ก.ค.) — ไม่มี Tool มือถือ/ไม้เซลฟี่แยก. มือถือ = กล้องระดับ 1, ไม้เซลฟี่จะเอาไปเป็นหน้าตาของระดับไหนก็ได้ตามใจคนปั้นโมเดล
| `NotebookPlaced` | โน้ตบุ๊คกางบนพื้น (Model) | ตอนกดวาง |
| `CameraCart` | **รถเข็นกล้อง IMAX (Model ไม่ใช่ Tool)** | ถือ `Camera_6` แล้วกดตอนยืน = เสกออกมา (docs/02 §9.5) |

**กติกาเฉพาะ `CameraCart`** (user lock 5 ส.ค.) — เป็น **Model** ไม่ใช่ Tool อยู่ใน ToolModels เหมือน `NotebookPlaced`:
- `PrimaryPart` ต้องเป็น **`Seat`** ชื่อ `CartSeat` และเป็นชิ้น**เดียว**ที่ `Anchored = true`
- ชิ้นอื่นทั้งหมด `Anchored = false` + `WeldConstraint` ติดกับ `CartSeat` — ชิ้นไหนไม่ weld = หล่นทิ้งกลางแมพตอนเสก
- ห้ามใส่ script ในโมเดล (`CameraCart.luau` ฝั่ง client ขยับ Seat ด้วย CFrame ให้เอง)
- ระบบลบคันเก่าก่อนเสกใหม่เสมอ → ห้ามมี `CameraCart` วางค้างใน Workspace

**กติกาโมเดล:**
- ทุกอันเป็น `Tool` ที่มี Part ชื่อ **`Handle`** (ตัวที่มือจับ) ส่วนที่เหลือ weld ติดเข้ากับ Handle
- ชื่อ Tool ที่โชว์บน hotbar ระบบตั้งให้เอง ("กล้อง (1080p)" / "ไม้เซลฟี่" / "โน้ตบุ๊ค") ไม่ต้องตั้งเอง
- **`NotebookPlaced` เป็น Model** ต้องมี 2 Part นี้:
  - `Interact_pcMonitor` — จอ (UI แปะบนนี้) · **ขนาด/แนวหมุนอิสระ** `MenuUI.faceToward()` หาหน้าที่กว้างสุดที่หันเข้ากล้องเองตอนรัน
  - `Interact_NotebookPack` — ตัวฐาน (กดเก็บกลับ) ตั้งเป็น `PrimaryPart`
  - ทั้งคู่ `Anchored ✓` · ไม่ต้องใส่ ProximityPrompt (ระบบใส่ให้)

#### ⚠️ บทเรียนจริง 9–10 ส.ค. 2569 — โน้ตบุ๊ค 6 บั๊กซ้อน อ่านก่อนแตะโมเดลนี้

1. **`PrimaryPart` ห้ามว่าง และห้ามเป็น `Interact_pcMonitor`** — `ToolService.placeNotebook` เรียก `Model:PivotTo(cf)` ซึ่งจัด **CFrame ของ PrimaryPart** ให้เท่า `cf`
   - `PrimaryPart = nil` → Roblox ใช้ pivot ที่คิดไว้ตอน group ของเก่า → โมเดลไปโผล่ไกล ~50 studs (อาการ "กดวางแล้วไม่มีอะไรโผล่")
   - `PrimaryPart = Interact_pcMonitor` → จอเป็นชิ้น**เอียง** `PivotTo` จับมันตั้งตรง = เหวี่ยงคีย์บอร์ดคว่ำ (อาการ "หน้าคว่ำ")
   - **ต้องเป็น `Interact_NotebookPack` เท่านั้น** (ฐานวางแบน `Up = (0,1,0)`)
2. **จอกางตามแกน "ลึก" ของฐาน (local X) ไม่ใช่ LookVector** — ยืนยันจาก Size: จอ `Z=2.09` ≈ ฐาน `Z=2.22` → Z คือ**ความกว้าง**, X คือความลึก. กางตาม Z จะได้จอทรงมือถือ
   → เพราะแบบนี้ [`RecordTool.luau:84`](../src/client/RecordTool.luau) ต้อง yaw **`+math.pi/2`** ไม่ใช่ `math.pi`
   **ใครหมุน/สร้างโมเดลนี้ใหม่ ต้อง re-derive เลข yaw นั้นด้วย** ไม่งั้นจอหันข้าง/หันหลัง
3. **ห้ามตัดสิน "จอหันทางไหน" จาก normal ของแผ่นจอ** — แผ่นบาง (0.001) มี 2 หน้าเหมือนกันเป๊ะ เดาผิดข้างได้ 180° ทั้งที่ `dot` ออกมา `+1.000` สวยงาม (พลาดจริงมาแล้ว 1 รอบ เสีย test cycle ของ user)
   **เกณฑ์ที่ถูก:** เวกเตอร์ **จอ→คีย์บอร์ด ต้องชี้ไปหาผู้เล่น** (คนนั่งฝั่งคีย์บอร์ด) — เกณฑ์นี้ทำนายอาการที่เจอจริงถูกทั้ง 2 ครั้ง
4. **ฝาจอห้ามหนา 0.001** — อ่านเป็นใบมีดลอย. หนา ~0.08 พอ และต้อง**ขยายออกด้านหลังจอ** ไม่ใช่ทับผิวจอ · ตัว `Interact_pcMonitor` คงบางไว้กัน z-fighting
5. **Tool `Notebook`: `Handle` ห้ามมี `WeldConstraint` ที่ `Part0 == Part1`** (self-weld) — พอ equip ตัวละครที่ weld กับ Handle ผ่าน Motor6D จะถูกเหวี่ยงไปหา Tool แทนที่ Tool จะมาเข้ามือ · และตั้ง `Handle.CanCollide = false`
6. **ชื่อ Part ต้องเป๊ะ** — `InteractBinder.luau:147` เช็ค `Interact_NotebookPack` ตรงตัว. เคยตั้งเป็น `Interact_Notebook` → กด E เก็บไม่ได้ (แก้ชื่อ ไม่ใช่เขียน resolver — CLAUDE.md rule 8)

- ตอนนี้เป็น**กล่องเปล่า placeholder** ทั้งหมด เปลี่ยนได้เลย (ยกเว้นข้อ 1–6 ข้างบน)

### 3.7 ห้อง Main Menu — `Workspace.MenuScene` (lock 27 ก.ค. — แผน `plans/2026-07-27-menu-scene.md`)

เมนูหลัก = **ห้องจริง** กล้องบินไปหาของแต่ละชิ้นตามปุ่มที่กด ไม่ใช่ปุ่มลอยบนพื้นดำ

**วางที่ไหน:** ห่างแมพจริง ≥500 studs (แนะนำยกขึ้นฟ้า y≈2000) ห้ามเห็นจากในเกม · **`Anchored ✓` ทุกชิ้น**
โค้ดไม่ย้าย/ไม่ลบอะไรในโฟลเดอร์นี้ ปั้นอิสระ

**Part กล้อง 5 ตัว** — `Transparency 1`, `CanCollide ✗`, เล็กๆ พอ
กล้องจะไปทับ**ตำแหน่ง + ทิศที่ Part หันหน้า** เป๊ะ จัดมุมโดยขยับ Part ในวิวพอร์ต ไม่ต้องแตะโค้ด

| ชื่อ | มุมอะไร |
|------|---------|
| `MenuCam_Home` | มุมตั้งต้น — **หน้าแรกที่ผู้เล่นเห็น จัดให้สวยที่สุด** เว้นซ้ายจอ ~420px ให้ปุ่ม |
| `MenuCam_PC` | จ่อหน้าจอคอม (ปลายทางตอนกดเล่นต่อ) |
| `MenuCam_Book` | ก้มมองสมุดบนโต๊ะ ให้หน้าสมุดเต็มเฟรม |
| `MenuCam_Setting` | จ่อโปสเตอร์ตั้งค่า |
| `MenuCam_Credit` | จ่อโปสเตอร์เครดิต |

**Part ที่ UI ไปแปะ 4 ตัว** — หน้าที่ต้องการให้เห็น = ด้าน **Front**

| ชื่อ | ขนาดแนะนำ | ใช้ทำอะไร |
|------|-----------|-----------|
| `MenuScreen_PC` | **4 × 2.6 studs** | จอคอมในเมนู — ตอนเข้าเกม Part นี้จะกลายเป็น Neon ขาววาบ |
| `MenuScreen_Book` | 4 × 3 | หน้าสมุดกาง = save 4 ช่อง (เขียนเป็นลายมือ) |
| `MenuScreen_Setting` | 3 × 4 | โปสเตอร์/กระดาษโน้ตติดผนัง = หน้าตั้งค่า |
| `MenuScreen_Credit` | 3 × 4 | โปสเตอร์เครดิต |

**ของตกแต่งที่เหลือ:** ไม่ต้องตั้งชื่อ — ยิ่งเล่าเรื่อง "ห้องเช่าคนไม่มีอะไร" ยิ่งได้คะแนนออกแบบฉาก
แนะนำ `PointLight` ที่จอคอมดวงเดียว ห้องมืดๆ → ตอนวาบขาวจะเด่นมาก

> **ยังไม่ปั้น = ไม่พัง** โค้ดตกกลับเป็นเมนูปุ่มลอยแบบเดิมอัตโนมัติ (เตือนใน output ว่าไม่เจอ MenuScene)

**`FilmSpot_*` (จุดถ่ายคลิป — docs/02 §9.5) 🔴 ยังไม่มีสักจุด งานนี้ปลดล็อกระบบอัดคลิปทั้งระบบ:**
Part เล็กๆ (ขนาดเท่าไหร่ก็ได้ ระบบใช้แค่ตำแหน่ง) `Anchored ✓ CanCollide ✗ Transparency 1` วางกระจายจุดที่ "น่าถ่ายคลิป" ในแมพ
— หน้าร้าน ป้ายรถเมล์ สะพานลอย ระเบียงห้อง ฯลฯ **วางหลายจุดไว้เลย** ระบบสุ่มเปิดทีละจุด 120 วิ แล้วย้ายเอง
ยิ่งมีหลายจุด ผู้เล่นยิ่งต้องเดิน ไม่ยืนกดที่เดิม · **ตั้งชื่อพอ ไม่ต้องใส่ ProximityPrompt ไม่ต้องใส่ script**
ไม่มีสักจุด = ไม่พัง แต่ไม่มีโซน ×1.5–2.5 ให้เก็บ (อัดได้ base rate เฉยๆ)
🔵 **แยกรายเฟส (บังคับ):** วาง FilmSpot ไว้ใต้ `Workspace.FilmSpots.phase<N>` (เช่น `FilmSpots.phase1`, `FilmSpots.phase2`) — player ย้อนเฟสไม่ได้ ระบบเลือกเฉพาะ spot ของเฟสปัจจุบัน · เฟสไหนไม่มีโฟลเดอร์ = ไม่มีโซนถ่ายในเฟสนั้น · ชื่อ spot ห้ามซ้ำข้ามเฟส (client หาด้วยชื่อ)

**`Zone_*` (โซนเพลง — docs/02 §9.9):** Part โปร่งใส Transparency 1, CanCollide ✗, Anchored ✓ ครอบพื้นที่ที่อยากให้เพลงนี้ดัง → ใส่ Attribute `Music` = ชื่อ Sound ใน `SoundService.BGM` (ทับซ้อนกันได้ ใส่ `Priority` ให้ตัวที่ควรชนะ)

**⚠️ `Interact_pcMonitor` = จอคอม ต้องทำตามนี้เป๊ะ** (UI แปะบนหน้า part จริงด้วย SurfaceGui):
- **ขนาด 4 × 2.6 × (หนาเท่าไหร่ก็ได้) studs** — ทุกเครื่องทุกเฟสต้องเท่ากัน ไม่งั้น UI ยืด/หด
- **ด้าน Front (−Z) = หน้าจอ** — หันด้านนี้ออกมาทางผู้เล่น (กด F ดูลูกศรใน Studio)
- Anchored ✓ | เป็น Part เดี่ยว ไม่ต้อง union
- ตัวเครื่อง/ขาตั้ง/กรอบ = Part อื่นในโมเดลเดียวกัน ตั้งชื่ออะไรก็ได้

### ⭐ กฎทอง: อยากให้อะไร interact ได้ → **ตั้งชื่อไว้เฉยๆ พอ**

**สร้าง Part/Model → ตั้งชื่อขึ้นต้น `Interact_` → จบ**
- ❌ **ห้ามใส่ ProximityPrompt / ClickDetector / Script เอง** — โค้ดแปะให้ตอนเกมรัน ใส่เองจะซ้อนกันกดสองที
- ✅ ตั้งชื่อที่โค้ดยังไม่รู้จักก็**วางไว้ได้เลย** — กดแล้วจะขึ้น warn ใน Output ว่า "ยังไม่ผูก logic: ชื่อนั้น" เกมไม่พัง แล้วบอก agent ทีหลังว่าอยากให้มันทำอะไร
- ตั้งชื่อให้อ่านรู้เรื่อง ภาษาอังกฤษ ไม่มีเว้นวรรค เช่น `Interact_Fridge`, `Interact_Shower`

---

## 3.5 ระบบ Tycoon — เหยียบปุ่มแล้วของโผล่ (เฟส 2 บ้านหลายชั้น)

**หลักการ:** ทีม**วางของจริงตรงตำแหน่งที่อยากให้มันอยู่เลย** โค้ดจะซ่อนให้ตอนเกมเริ่ม แล้วเอากลับมาตอนซื้อ — ไม่ต้องคำนวณพิกัดเอง

**ตั้งชื่อเป็นคู่ ชื่อหลังต้องตรงกันเป๊ะ:**

```
Map_Phase2/
  House1/                         ← Model/Folder ของบ้าน
    Buy_Bed        (Part เหยียบ)  ← Attribute: Price = 5000
    Item_Bed       (Model ของจริง) ← วางตรงตำแหน่งจริง
    Buy_Sofa       + Attribute Price = 3000
    Item_Sofa
    Buy_Floor2     + Attribute Price = 50000   ← ชั้น 2 ก็เป็น item ได้
    Item_Floor2    (Model ทั้งชั้น: พื้น+ผนัง+บันได)
```

**Buy_ Part (ปุ่มเหยียบ):**
- Part แบนๆ วางกับพื้น Anchored ✓ CanCollide ✓
- **ต้องมี Attribute ชื่อ `Price` แบบ number** (คลิกที่ Part → Properties → Attributes → +)
- ป้ายราคาลอยเหนือปุ่ม โค้ดสร้างให้เอง ไม่ต้องทำ

**Item_ Model (ของที่จะโผล่):**
- วางให้เสร็จสวยตรงที่จริง Anchored ✓
- จะเป็น Part เดี่ยวหรือ Model กี่ชิ้นก็ได้
- **ห้ามใส่ Script** ในนั้น

**สิ่งที่โค้ดทำให้อัตโนมัติ:** ซ่อน Item_ ตอนเริ่ม / ป้ายราคา / เหยียบแล้วหักเงิน / ของโผล่ + ปุ่มหาย / **จำลง save** (ซื้อแล้วซื้อเลย โหลดเกมกลับมาของยังอยู่)

**กฎ:** ชื่อหลัง `Buy_` กับ `Item_` **ต้องตรงกันตัวต่อตัว** ไม่งั้นจับคู่ไม่ได้ | ปุ่มที่ไม่มี `Item_` คู่ = โค้ด warn แล้วข้าม

---

## 4. NPC — เอาแค่ยืนได้ก่อน

ต้องมี: `Model` → `Humanoid` + `HumanoidRootPart` + ตั้งชื่อตาม §2 + `Anchored` ยืนกับที่

**ยังไม่ต้องทำ:** animation, pathfinding, ให้มันเดิน
Dialogue engine (design doc §7) เป็น **ทางเดียว ไม่มี branching** — ต้องการแค่โมเดลที่ยืนอยู่กับปุ่มกดคุย

ทำ 6 ตัวให้ครบก่อน แล้วค่อยกลับมาทำสวย

---

## 5. ห้าม

| ห้าม | เพราะ |
|------|-------|
| ใส่ Script / ProximityPrompt / ClickDetector เอง | ชนกับที่ Claude เขียนทีหลัง วาง Part ชื่อถูกแล้วปล่อย |
| สร้าง map เฟส 3 (mini siam 3 studios) | design doc §9 ตัดไป backlog แล้ว — เริ่ม studio เดียว ถนัดแค่ไหนก็ห้าม นี่คือ scope creep |
| Toolbox ที่มีตัวละคร/โลโก้/เพลงมีเจ้าของ | ผิดกติกา = **ตกรอบ** ไม่ใช่แค่เสียแต้ม |
| เปิด Studio พร้อมกันสองคน | MCP ต่อ instance ที่เปิดอยู่ save ทับกัน = งานหาย |
| แก้เกมหลัง 12 ส.ค. 18:00 | กรรมการเช็ค Last Updated → ปิดงานจริง **11 ส.ค.** |

**PC app template ต้องนอนใน `Frame` ที่ขนาด/ตำแหน่ง/ARC ตรงกับ `AppFrame` เป๊ะ ห้ามเป็น `Folder`** (เจอจริง 12 ส.ค. — `AppTemplates` เคยเป็น `Folder`, ไม่มี bounds ของตัวเอง เลยทำให้ template ข้างในที่ตั้ง `Size = {1,0},{1,0}` ไปยึดเต็มจอแทนที่จะยึด `AppFrame` จริง แต่งใน Studio แล้วขนาดที่เห็นกับตอนเปิดจริงไม่ตรงกัน — แก้แล้วโดยเปลี่ยน `AppTemplates` เป็น `Frame` ก็อปปี้ `Size`/`Position`/`AnchorPoint`/`UIAspectRatioConstraint` จาก `AppFrame` ตรงๆ, `Visible = false`) เพิ่มแอปใหม่ = วาง template ใต้ `Screen.AppTemplates` เหมือนเดิม ไม่ต้องทำอะไรเพิ่ม

## 5.5 Responsive UI — HUD/แผง ไม่เพี้ยนข้ามอุปกรณ์ (มือถือ/แท็บเล็ต/PC)

เกมเล่นทั้งมือถือ+PC → GUI ต้อง scale ตามจอ ไม่ใช่ pixel ตายตัว

### 🔑 หลักการ (lock 10 ส.ค. 2569 หลังลองผิด 2 รอบ) — **ขนาดย่อพร้อมกัน / ตำแหน่งเกาะขอบจอ**

เป้าหมายของ HUD ที่ responsive จริงมี 2 ข้อ **และต้องได้พร้อมกัน**:

| เป้าหมาย | ทำยังไง |
|---|---|
| **ทุกชิ้นย่อ/ขยายเท่ากันหมด ไม่มีชิ้นไหนบิด** | `Size` ใส่ **สัดส่วนของแบบทั้งสองแกน** + `UIAspectRatioConstraint` `FitWithinMaxSize` ต่อชิ้น |
| **ตำแหน่งเกาะขอบ/มุมจอ ไม่มีขอบว่าง** | `Position` เป็น Scale ของจอจริง (ไม่ใช่ของ Root ที่ล็อกอัตราส่วน) |

**กลไกที่ทำให้ได้ทั้งสองข้อ — เข้าใจอันนี้อันเดียวพอ:**

ARC `FitWithinMaxSize` = ย่อให้พอดีกรอบ `Size` โดยรักษาสัดส่วน → มันเลือก **ด้านที่บีบกว่า** เอง
ถ้าตั้ง `Size = (กว้างตามแบบ/กว้างจอแบบ, สูงตามแบบ/สูงจอแบบ)` แล้ว ชิ้นนั้นจะได้ขนาด = **`min(จอกว้าง/แบบกว้าง, จอสูง/แบบสูง)`** อัตโนมัติ
= uniform scale เป๊ะๆ โดยไม่ต้องมี `UIScale` ไม่ต้องมีโค้ดอ่าน viewport ไม่ต้องมี ARC ครอบทั้งชุด

> **ตัวอย่าง:** กล่องแบบ 243×51 px บนแบบ 1672×742 → `Size = UDim2.fromScale(243/1672, 51/742)` + ARC ratio `243/51`
> จอ 1920×1080: `min(1920/1672, 1080/742) = min(1.148, 1.455) = 1.148` → กล่องได้ 279×59 (ขยาย 1.148 เท่าทั้งสองแกน)

**สูตรแปลงของที่วางไว้แล้ว** (ใช้ตอนต้องแก้ของเก่า): วัดขนาด render จริงที่ aspect ต้นแบบได้ `w × h` → `Size = UDim2.fromScale(w/แบบกว้าง, h/แบบสูง)` · `ARC.AspectRatio = w/h`

### ❌ 2 ทางที่ลองแล้วพัง — อย่าทำซ้ำ

| ทางที่พัง | เกิดอะไร |
|---|---|
| **Root frame + ARC ครอบทั้งชุด** (letterbox) | ทั้งชุดไม่บิดจริง **แต่เกิดขอบว่างบน-ล่าง 10.5% บนจอ 16:9** (1920×1080 = ว่างบน 114px, 2K = 152px) เพราะ Root หดตามอัตราส่วน แล้วลากทุกชิ้นหลุดจากขอบจอตามไปด้วย |
| **`Size.X = 1` ให้ ARC คิดความกว้างจากความสูงล้วน** | จอ 16:9 สูงกว่าแบบ → ชิ้นส่วนโตตามความสูง (×1.455) แต่พื้นที่แนวนอนโตแค่ ×1.148 → **คอลัมน์ซ้ายล้นออกนอกจอ** |

> ยังต้องมี `Frame` ชื่อ **`Root`** ครอบไว้ (`Size (1,1)`, `AnchorPoint (0.5,0.5)`, `Position (0.5,0.5)`, โปร่งใส) — แต่ **ห้ามใส่ ARC ที่ Root** · Root มีไว้จัดกลุ่ม/ซ่อนโชว์ทั้งชุด ไม่ได้มีไว้ล็อกอัตราส่วน
> `HUD.bind` และ `SavePanel.init` อ้าง path ผ่าน `Gui_HUD.Root.<ชื่อ>` — ย้ายของใน Studio แล้วมาแก้ path ให้ตรง

**⚠️ ของใน `.rbxl` ไม่ใช่ `src/` — แก้ GUI ใน Studio แล้วต้อง Ctrl+S + publish เอง ไม่งั้น revert (git ไม่ track)**

| กฎ | ทำไม |
|----|------|
| **`Size` ใส่สัดส่วนของแบบทั้ง 2 แกน + ARC ทุกชิ้น** | ได้ uniform scale ฟรีจาก `min()` ของ ARC (ดูกลไกบน) · ชิ้นที่ไม่มี ARC = ไม่ย่อตาม จะหลุดชุด |
| **ห้ามใช้ Offset เป็นขนาด/ตำแหน่งหลัก** | Offset = pixel คงที่ → 4K จิ๋ว, จอเล็กล้น (เจอจริง: ป้าย `50` ค้าง 48×19px, ปุ่มเซฟ bossver ค้าง `{0,56},{0,645}`) |
| **`Position` เป็น Scale + ตั้ง `AnchorPoint`** | ยึดสัดส่วนจอจริง = เกาะขอบ/มุม ไม่เลื่อนหลุด |
| **เช็คขอบซ้าย/ขวาว่าไม่ติดลบ** — `Position.X.Scale − Size.X.Scale × AnchorPoint.X ≥ ~0.012` | เจอจริง: คอลัมน์ซ้ายขอบอยู่ที่ −0.006 = ล้นนอกจอมาตลอดตั้งแต่แรก เพิ่งเห็นตอนจอมือถือมีขอบมน/notch |
| **Text ใช้ `TextScaled = true`** | ตัวอักษรโตตามกล่อง · ไม่ใช้ `TextSize` คงที่ |
| **Font = `FredokaOne`** + `UIStroke` บางๆ (thickness ~1, สีเข้ม `RGB(27,27,27)`) | ให้ทุก UI ดูเป็นชุดเดียว |
| ป้ายลอย/popup **parent ไว้กับกล่องที่มันเกาะ** ไม่ใช่ ScreenGui + offset | เกาะกล่อง = ขยับ+scale ตามกล่องเอง (เช่น `HUD.popup` เกาะ FollowerBox) |
| **ชิ้นที่ต้องอยู่ติดกันเป็นชุด ให้ครอบด้วย Frame กลุ่ม + ARC แล้ววางตำแหน่งเทียบกรอบกลุ่ม** | ดู §ชุดที่ต้องไม่ถ่างออกจากกัน ล่าง |
| **บาร์ที่มีขอบมน: ตั้ง `ClipsDescendants = true` ที่ราง** | แถบในมีมุมมนคนละรัศมีกับราง จะโผล่พ้นขอบ (`MentalTrack`) |
| **ปุ่ม/แผงที่ควรหายตอนอยู่เมนู ให้อยู่ใน `Gui_HUD.Root`** | ซ่อน/โผล่ตาม `Gui_HUD.Enabled` เอง ไม่ต้องเขียน logic toggle เพิ่ม (เช่น `SaveBtn`) |

### 🧩 ชุดที่ต้องไม่ถ่างออกจากกัน — ครอบด้วย Frame กลุ่ม

ทำตามหลักการบนแล้ว **ขนาด**ทุกชิ้นย่อเท่ากันจริง แต่ **ตำแหน่ง**ยังผูกจอตรงๆ (X ตามความกว้าง, Y ตามความสูง) — จอ 16:9 สูงกว่าแบบ ระยะห่างแนวตั้งเลยยืดเร็วกว่าที่ชิ้นส่วนโต

> **เจอจริง 10 ส.ค. (จอ 4K):** ที่ 3840×2160 ตำแหน่งยืด ×2.91 (`2160/742`) แต่ชิ้นส่วนโตแค่ ×2.30 (`min(3840/1672, 2160/742)`) → ไอคอนหัวใจลอยห่างหัว/ท้าย mental bar จนอ่านไม่ออกว่ามันคือ indicator ของบาร์

**กติกา: ชิ้นไหน "ต้องอ่านคู่กันถึงจะเข้าใจ" = ต้องอยู่ใน Frame กลุ่มเดียวกัน** (บาร์+ไอคอนหัว/ท้าย+ป้ายสเกล, ไอคอน+ตัวเลขในกล่องเดียว, ป้าย+ลูกศรชี้)

วิธีทำ (ตัวอย่างจริง `MentalGroup` = `MentalTrack` + `Heart` + `BrokenHeart` + ป้าย `100`/`50`/`0`):
1. หา **กรอบรวม (bounding box)** ของทุกชิ้นในชุด ที่ viewport ต้นแบบ → ได้ `gw × gh` ที่มุม `(bx0, by0)`
2. สร้าง `Frame` กลุ่ม โปร่งใส `AnchorPoint (0.5,0.5)` · `Size = fromScale(gw/แบบกว้าง, gh/แบบสูง)` · `Position` = จุดกลางกรอบรวม (scale ของจอ) · **ใส่ ARC `AspectRatio = gw/gh`**
3. ย้ายทุกชิ้นเข้ากลุ่ม แล้วคิดใหม่ **เทียบกรอบกลุ่ม**: `Size = fromScale(w/gw, h/gh)` · `Position = fromScale((cx−bx0)/gw, (cy−by0)/gh)`

ผลลัพธ์: ทั้งชุดกลายเป็นก้อนเดียว ระยะห่างภายในคงที่เป๊ะทุกจอ เหลือแค่ตัวก้อนที่ขยับ/ย่อตามจอ
(ยืนยันด้วยตัวเลข: ช่องไฟหัวใจ-บาร์ = `0.229` เท่าความกว้างบาร์ เท่ากันหมดตั้งแต่ 1280×720 ถึง 3840×2160)

> **ช่องไฟในกลุ่มตั้งเป็น px บนแบบ แล้วปล่อยให้ normalize เอง** — เช่น `MentalGroup` เว้นหัวใจห่างปลายบาร์ 6px บนแบบ 1672×742 · พอย่อ/ขยาย ช่องไฟก็ย่อตามเป็นสัดส่วนเดิม ไม่ต้องใส่ offset ตายตัว
> ไอคอนที่เป็น **indicator ของบาร์ ต้องอยู่นอกบาร์** ไม่ใช่ทับหัว/ท้ายบาร์ — ทับแล้วอ่านไม่ออกว่าหมายถึงปลายบาร์ฝั่งนั้น

> ⚠️ ย้ายของเข้ากลุ่ม = **path เปลี่ยน** ต้องไปแก้ตาราง `BINDINGS` ใน `HUD.luau` ให้ตรง (`MentalTrack.MentalFill` → `MentalGroup.MentalTrack.MentalFill`)
> ⚠️ อย่าเอาของไป parent ไว้กับชิ้นที่ `ClipsDescendants = true` (เช่นรางบาร์) มันจะโดนตัดหาย — ใช้ Frame กลุ่มที่ไม่ clip ครอบแทน

**เช็คก่อนปิดงานทุกครั้ง — คำนวณ ไม่ใช่กะด้วยตา:** วน `Gui_HUD.Root` ทุกชิ้น คิด rect ที่ viewport `1920×1080` / `2560×1440` / `2436×1125` / `2560×1080` / aspect ต้นแบบ แล้ว assert ว่า **ไม่มีชิ้นไหน `x0<0`, `x1>W`, `y0<0`, `y1>H` และไม่มีคู่ไหนทับกัน** (ยกเว้นป้าย milestone ที่ตั้งใจซ้อนขอบ `ProgressTrack`)
สูตร rect ต่อชิ้น: `w = min(Size.X.Scale×W, Size.Y.Scale×H × ARC.AspectRatio)` · `h = w / ARC.AspectRatio` · `x0 = Position.X.Scale×W − w×AnchorPoint.X`
ดูตาจริงเสริมได้ที่ Studio → **Test → Device** หรือ resize หน้าต่าง Studio (ไวกว่า)

---

## 6. กฎสำหรับ Claude Code

- ห้ามลบ/แก้ instance ที่มีอยู่แล้วโดยไม่ถามก่อน (ตัวละคร/ฉากที่ทีมปั้นมือ = งานหลายวัน)
- สร้างใหม่/อ่าน = ทำได้เลย
- ทุกครั้งที่เขียนหรือแก้ Script ใน Studio → เขียนไฟล์เดียวกันลง `src/` ด้วย แล้ว commit
  (ของจริงอยู่ใน Studio, `src/` คือ backup — ถ้าไม่ sync จะย้อนกลับไม่ได้ตอนพัง)
- save Studio ทุกครั้งที่ทำอะไรสำเร็จ

---

## 7. เช็คก่อนลงมือวันนี้

- [ ] ของที่มีอยู่แล้วใน Studio ตั้งชื่อตาม §2 หรือยัง — **รื้อชื่อทีหลังเจ็บกว่าทำถูกตั้งแต่แรก**
- [ ] ตกลงแล้วว่าใครถือ Studio ตอนไหน
- [ ] ทุกคนอ่านไฟล์นี้แล้ว
