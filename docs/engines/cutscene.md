# Engine: Cutscene — ฉากจบ 6 แบบ (= cutscene **โหมด 1 "หนัง"**)

**หน้าตา:** แถบดำบน-ล่าง (คลุมเต็มจอ `IgnoreGuiInset`) + กล้องเปลี่ยนบ่อย/เลื่อนได้ + **ซับไตเติลกลางล่าง ไม่มีกรอบข้อความ** + player กดอะไรไม่ได้
**ทุก cutscene engine หยุดให้เอง** (ไม่ต้องสั่งในบท): หยุดนาฬิกาเกม (`FreezeTime`) + ล็อกไม่ให้ player เดิน (WalkSpeed/Jump=0) + ล็อกเพลงโซน · คืนให้หมดตอนจบฉาก · ดวงอาทิตย์หยุดตามเวลา (ดู [07 §3.1.1](../07-core-systems-design.md))
**โหมด 2 "ฉากคุย"** (กล้องนิ่ง กล่องข้อความ ช้อย) = `DialogueUI` → [dialogue.md](dialogue.md) · ตารางเทียบ 2 โหมด → [README.md](README.md)

**ไฟล์โค้ด:** `StarterPlayerScripts.UI.CutscenePlayer`
**ไฟล์เนื้อหา:** `ReplicatedStorage.Shared.Content.Endings.<ชื่อ ending>` (6 ไฟล์) ← **ทีมแก้แค่ตรงนี้**
**มุมกล้อง:** `Workspace.CutsceneCams` → Part ชื่อ `Cam_*` ← **ทีมวางในแมพ**

---

## 1. เกิดขึ้นเมื่อไหร่

ระบบตัดสินว่าจบเกม (ถึง 1M / เงินหมด 2 รอบ / ใจ 0) → **หยุดเวลา** → แถบดำบน-ล่างแบบหนัง → เล่น step ทีละอันตามลำดับ → ขึ้น "— จบ —"

ถ้ามี canon event ค้างคิว (เช่น BCA หลัง 1M) **ระบบรอให้เล่นจบก่อน** แล้วค่อยเข้า ending

---

## 2. เขียนยังไง — ลิสต์ของคำสั่ง (step list)

```lua
return {
    { type = "camera", cam = "Cam_Good1_01" },      -- ย้ายกล้องไป Part ชื่อนี้
    { type = "bgm",    name = "Ending_Sad" },       -- เปลี่ยนเพลง (ไม่ใส่ name = เงียบ)
    { type = "anim",   actor = "player", name = "SitDown" }, -- สั่งท่าตัวละคร
    { type = "face",   actor = "player", name = "Sad" },     -- เปลี่ยนสีหน้า
    { type = "text",   text = "[slow]ข้อความ" },    -- ขึ้นข้อความ (ค้างจนถึง step ถัดไป)
    { type = "wait",   t = 2 },                     -- เว้นจังหวะ 2 วินาที
    { type = "sound",  name = "door_slam" },        -- เสียงประกอบครั้งเดียว
}
```

| type | ต้องใส่ | หมายเหตุ |
|---|---|---|
| `camera` | `cam` (ชื่อ Part) | ใส่ `t=วินาที` เพิ่ม = เลื่อนกล้องนุ่มๆ แทนตัดภาพ · หรือแบบพิกัด `pos={x,y,z}, look={x,y,z}` ก็ได้ (ไม่แนะนำ) |
| `text` | `text` | ใช้ tag `[slow]` `[fast]` ได้เหมือนบท NPC · ค้างอยู่จนกว่าจะมี text ถัดไป |
| `wait` | `t` (วินาที) | |
| `bgm` | — | `name` = ชื่อใน `SoundService.BGM` · ไม่ใส่ = เงียบสนิท |
| `sound` | `name` | ชื่อใน `SoundService.SFX` |
| `anim` | `actor` + `name` | สั่งท่าตัวละคร · ใส่ `loop = true` = ท่าค้าง · ท่าอยู่ `ReplicatedStorage.Animations` (วิธีเตรียม → [dialogue.md §2.5](dialogue.md)) |
| `face` | `actor` + `name` | เปลี่ยนสีหน้า · หน้าอยู่ `ReplicatedStorage.Faces` · จบฉากคืนหน้าเดิมอัตโนมัติ |
| `focus` | `target` (ชื่อ Part) | **preload แมพไกล** (StreamingEnabled): ย้ายศูนย์ streaming ไป Part นั้น แมพรอบๆ จะโหลดทั้งที่ player ยังไม่ไป · วาง **ก่อน** cam ที่ส่องแมพนั้น ~2-3 วิ (ใส่ wait คั่นให้โหลดทัน) · focus ค้างจนกว่า `TeleportTo` (จบ intro) จะย้ายตัวเข้าโซนนั้นแล้ว **คืน focus ให้ตัวละครเอง** (ไม่ pause/reload) · **ใช้กับ cutscene ที่จบด้วยการวาปเข้าโซน focus เท่านั้น** |
| `move` | `actor` + `to` (ชื่อ Part) | เดิน actor ไปยืนตรง Part นั้น · `t=วินาที` ไม่ใส่ = วาปทันที · **ไม่เล่นท่าเดินให้เอง** ใส่ `anim` คู่กันเอง · รายละเอียด+เมื่อไหร่ควรใช้ → [story-beat.md §3](story-beat.md) |
| `objAnim` | `object` + `name` | เล่น animation บน prop ไม่มีชีวิต (โล่รางวัล/ประตู duplicate ฯลฯ) ผ่าน `AnimationController` · `loop=true` ค้างท่า · ต้อง rig ด้วย Motor6D ก่อน (Moon Animator "Easy Weld") → [story-beat.md §7](story-beat.md) |
| `hold` | `actor` + `prop` | Weld prop ติดมือ actor (`limb` ไม่ใส่ = `"Right Arm"`) — แขนขยับตามท่า prop ติดตามไปเอง · auto-unhold ตอนจบฉาก (ใส่ `persist=true` ถ้าอยากให้ค้างถือต่อ) → [story-beat.md §7](story-beat.md) |
| `unhold` | `prop` | ปลด prop ออกจากมือก่อนฉากจบ (ปกติไม่ต้องเรียกเอง ระบบ auto-unhold ให้) |
| `visible` | `target` (ชื่อ Part/Model) + `show` (boolean) | โชว์/ซ่อน object (Transparency+CanCollide) — ใช้สลับของจริงกับ duplicate สำหรับ animate → [story-beat.md §7](story-beat.md) |
| `time` | `hour` (0-24) | ล็อกตำแหน่งดวงอาทิตย์/แสงให้ฉาก (ไม่เดินเวลาเกมจริง) — เช่น `{ type="time", hour=0 }` BCA กลางคืน, `hour=8` Ending เช้า · ตั้งครั้งเดียวค้างทั้งฉาก จบฉากคืนเวลาจริงอัตโนมัติ |

**ไม่ใส่ step `camera` เลยก็ได้** — กล้องอยู่ที่เดิมที่ player ยืน แล้วขึ้นแถบดำ+ข้อความ (ใช้ได้จริงสำหรับ ending แบบย่อ)

---

## 3. วางมุมกล้อง — ใช้ plugin ไม่ต้องหมุน Part เอง ไม่ต้องเดาว่าหันทางไหน

**กฎที่ระบบใช้:** ตำแหน่ง Part = ตำแหน่งกล้อง · **ด้าน Front ของ Part (แกน −Z) = ทิศที่กล้องมอง**
ตรงกับ LookVector ของกล้องพอดี → `camera.CFrame = part.CFrame` ได้ภาพเดียวกับตอนวางเป๊ะ

### ติดตั้ง plugin (ครั้งเดียวต่อเครื่อง)

copy `tools/CutsceneCamTool.plugin.luau` ไปที่ `%LOCALAPPDATA%\Roblox\Plugins\CutsceneCamTool.lua` แล้วเปิด Studio ใหม่
จะได้ toolbar **Cutscene Cams** 5 ปุ่ม + panel

⚠️ **plugin ที่ติดตั้งเป็นสำเนา** — แก้ไฟล์ `tools/CutsceneCamTool.plugin.luau` แล้วต้อง **copy ทับใน `%LOCALAPPDATA%\Roblox\Plugins\` + restart Studio** ทุกครั้ง ไม่งั้นยังรันตัวเก่า

**Cam Panel** = property editor ของกล้อง:
- ช่อง **Cutscene** — ชื่อกลุ่มที่ Place ลง · กล้องลง Model `CutsceneCams/<ชื่อ>/` ชื่อ `<ชื่อ>_01`, `_02`... เลขรันเอง · Model set `ModelStreamingMode=Persistent` ให้ (client เห็นเสมอ)
- **เลือก Part กล้อง** → panel โชว์ **Ease** (dropdown) / **TweenTime** / **FOV** ของ Part นั้น · แก้ = เขียนลง**ทุก Part ที่เลือกพร้อมกัน** (เหมือน Properties ของ Studio) · เลือกหลายตัวค่าต่างกัน = โชว์ `—`
- ไม่เลือกอะไร = ค่าในช่อง = default ของ Part ที่จะ Place ถัดไป

| ปุ่ม | ทำอะไร |
|---|---|
| **Cam Panel** | เปิด/ปิด property panel |
| **Place Cam** | เลื่อนมุมมอง Studio ให้ได้ช็อตที่ชอบ แล้วกด → Part กล้องหันถูกทาง + ใส่ FOV/Ease/TweenTime ตาม panel · ลงกลุ่มตามช่อง Cutscene ตั้งชื่อให้เลย |
| **Aim Cam** | เลือก Part เดิม + เลื่อนมุมมองให้สวยกว่าเดิม แล้วกด → อัปเดตช็อตนั้น |
| **Look Thru** | เลือก Part แล้วกด → มุมมอง Studio กระโดดไปยืนตรงนั้น = **เห็นภาพจริงที่ player จะเห็น** |
| **Tour** | เลือกหลาย Part แล้วกด → ไล่กล้องผ่านทีละตัวตามลำดับชื่อ ใช้ Ease/TweenTime จริง = พรีวิวทั้งฉาก (กดซ้ำ = หยุด) |

(ทำมือก็ได้: Part เล็กๆ Anchored ✓ Transparency 1 CanCollide ✗ หัน Front ไปทางที่อยากให้มอง อยู่ใน Model Persistent — แต่เสียเวลากว่าเยอะ)

### FOV / easing / การเลื่อนกล้อง

- attribute **`FOV`** บน Part (plugin ใส่ให้เอง) → ตอนเล่นจริงกล้องใช้ค่านี้ ไม่มี = ใช้ค่าเดิมของ player
- attribute **`Ease`** = `InOut` / `In` / `Out` / `Linear` / `Cut` + **`TweenTime`** (วินาที) บน Part — plugin ปุ่ม **Ease** วนค่าให้ (เลือก Part อยู่ = set ให้เลย)
  ตอนเล่น step `{ type="camera", cam="..." }` อ่าน 2 ค่านี้เอง — **ไม่ต้องใส่ `t` ในบท** · `Cut` หรือ TweenTime 0 = ตัดภาพทันที · `Linear` = เลื่อนเร็วคงที่ (In/Out/InOut = Quad นุ่มหัว/ท้าย)
- override ในโค้ดได้: `{ type="camera", cam="...", t=3, ease="In" }` (step ทับ attribute)
  **ไม่หยุดรอ** — บทเดินต่อทันที (ให้ข้อความขึ้นระหว่างกล้องเลื่อนได้) อยากรอให้ใส่ `{type="wait", t=3}` ต่อท้าย

**step `text` คุมเวลาได้ 2 ทาง:**
- ใส่ `t` ในตัว text เลย: `{ type="text", text="...", t=3 }` = โชว์ค้าง 3 วิ แล้วไปต่อ
- หรือปล่อย text ไม่มี `t` (ไม่รอ) แล้วต่อ `{ type="wait", t=... }` เอง
subtitle ค้างจนสั่ง `text` ใหม่/จบฉากเสมอ · ไม่ใส่ `t` ทั้งสองที่ = เด้ง step ถัดไปทันที

**ข้อจำกัดที่ต้องคิดตอนเขียนบท:** กล้องมองได้เฉพาะของที่**มีอยู่จริงในแมพ** — อยากได้ฉาก "บ้านพ่อแม่" ต้องมีห้องนั้นก่อน เขียนฉากจบให้เกิดในที่ที่มีอยู่แล้ว (ข้างถนน/ห้องเช่า/บ้าน) จะรอดกว่า

---

## 4. Ending 6 แบบ + เกรดการผลิต

**จำนวนต้องครบ 6 ห้ามตัด** (กรรมการเช็คความสมบูรณ์) แต่ไม่ต้องอลังการเท่ากัน:

| Ending | เงื่อนไข | เกรด |
|---|---|---|
| `Good1` | ถึง 1M + คลิปคุณภาพสูง + ตอบดี ≥62.5% | **เต็ม** (หลายมุมกล้อง บทยาว) — ใช้โชว์ pitch |
| `Neutral2` | ถึง 1M แบบกลางๆ (คนส่วนใหญ่ได้อันนี้) | **เต็ม** |
| `Neutral1` | ถึง 1M แบบสายกลาง ⊕⊖ พอกัน | ย่อ |
| `Bad1` | เงินหมด โดนไล่ที่ 2 รอบ | ย่อ |
| `Bad2` | mental ถึง 0 | ย่อ |
| `Bad3` | ตอบ ⊖ เยอะเกิน โดนแบน | ย่อ |

**ย่อ = กล้องมุมเดียว/ไม่มีกล้อง + ข้อความ 3-4 บรรทัด** — ไม่ใช่ของปลอม Undertale ก็ทำแบบนี้

⚠️ **Roblox compliance:** ห้ามมีเนื้อหาความตาย/ฆ่าตัวตายเด็ดขาด → Bad End ทุกอันต้อง reframe เป็น**ความล้มเหลวทางสังคม/อาชีพ** (ผิด = เกมโดนลบ = ส่งลิงก์ไม่ได้ = ตกรอบ)

---

## 5. ผิดแล้วเป็นยังไง

| ทำผิด | ผลลัพธ์ |
|---|---|
| พิมพ์ชื่อ Part กล้องผิด | warn "ไม่เจอ Part กล้อง" กล้องไม่ขยับ **เล่นต่อได้** |
| `type` ผิด / ลืมใส่ field | **ไม่เล่นทั้งฉาก** + warn บอกว่า step ที่เท่าไหร่พัง |
| ลืมสร้าง Folder `CutsceneCams` | หา Part ทั้ง Workspace แทน (ยังหาเจอถ้าชื่อไม่ซ้ำ) |
| ไม่มีเพลงชื่อนั้น | warn ครั้งเดียว เงียบ เล่นต่อปกติ |

**เช็คงานตัวเอง:** เทสมีตัวตรวจว่าไฟล์ ending ทั้ง 6 `validate` ผ่าน — บอก agent ให้รันเทสหลังแก้บท

---

## 6. ฉากเปิดเกม (Opening) — เล่นตอนกด New Game (เพิ่ม 1 ส.ค. 2569)

ใช้ engine เดียวกับ ending (mode 1) — ต่างแค่ trigger + ไฟล์เนื้อหา

**ไฟล์เนื้อหา:** `Content.Cutscenes.Opening` — list step เหมือน ending ทุกอย่าง (`camera`/`text`/`anim`/`face`/`wait`/`bgm`/`sound`)
**trigger:** กด New Game → เล่น Opening → จบต่อ **transition วาปเข้าห้องเฟส 1** อัตโนมัติ (โค้ด Main.client — ไม่ต้องแตะ)

**ที่ต้องเตรียมในแมพ:**
1. พิมพ์ `Opening` ในช่อง Cutscene ของ panel แล้วกด Place Cam → ได้ Model `CutsceneCams/Opening/` (Persistent) พร้อม Part `Opening_01`, `Opening_02`... ชื่อ unique + streaming-safe ให้เอง อ้างชื่อนี้ในบท
2. Part ชื่อ **`Spawn_Phase1`** ในห้องเฟส 1 = จุดที่ player โผล่หลัง intro (ไม่มี = warn + ไม่วาป ไม่ crash)

⚠️ **ชื่อต้องเป๊ะ ห้ามมีเว้นวรรคท้าย** — `"Spawn_Phase1 "` หาไม่เจอ (โค้ดไม่เดา ไม่ trim ให้)

**ลำดับที่โค้ดทำให้ (ไม่ต้องแตะ):** เมนูส่งต่อกล้องให้ cutscene ใต้ผ้าขาว (ไม่เห็นแวบ baseplate) → เล่น Opening → จอดำ → วาป + คืนกล้องให้ player → fade กลับ + เปิด HUD
- **วาปทำที่ server** (`TeleportTo` action) เพราะ StreamingEnabled อาจ stream `Spawn_Phase1` ออกจาก client → client หา Part ไม่เจอ
- **ต้องคืนกล้องเอง** หลัง cutscene: `CutscenePlayer` คืน CameraType ที่จับตอนเริ่ม ซึ่งตอน intro คือ `Scriptable` (เมนูตั้งไว้) → ถ้าไม่ตั้ง `Custom` + `CameraSubject` player จะค้างมุม cutscene

**จัดโฟลเดอร์ cam ต่อ scene:** `CutsceneCams/<Scene>/<cam>` เช่น `CutsceneCams/Opening/Opening_1` · subfolder ไว้ให้คนอ่าน engine หาข้าม subfolder เองอยู่แล้ว

---

## 7. ScreenTransition — จอดำ + ข้อความ + วาป (ของกลาง)

`StarterPlayerScripts.ScreenTransition` — จอดำ fade → ทำงานตอนดำ (teleport/สลับของ) → ข้อความ (ผ่าน DialogueUI บรรทัดไม่มีชื่อ) → fade กลับ

```lua
local ScreenTransition = require(StarterPlayerScripts.ScreenTransition)
ScreenTransition.play({
    lines = { "ในที่สุดฉันก็เก็บเงินพอ..." }, -- ข้อความบนจอดำ (ว่างได้ = ดำเฉยๆ)
    onBlack = function() -- ตอนจอดำสนิท: วาป player / สลับแมพ
        local root = game.Players.LocalPlayer.Character.HumanoidRootPart
        root.CFrame = workspace.Spawn_Phase2.CFrame + Vector3.new(0, 3, 0)
    end,
    fadeTime = 0.6,
    onDone = function() end, -- fade กลับเสร็จ
})
```

reuse ได้ทุกที่: intro (โค้ดทำให้แล้ว), เปลี่ยนเฟส (โค้ดทำให้แล้ว), ending, ฉากรับรางวัล BCA — เรียก `ScreenTransition.play` เอง

### ข้ามเฟส — ต่อสายอัตโนมัติแล้ว (เพิ่ม 2 ส.ค. 2569)

follower ทะลุ gate (10K → เฟส 2, 100K → เฟส 3) → `Main.client` เห็น `state.phase` เพิ่ม → จอดำ + วาปเข้าแมพเฟสใหม่เอง **ไม่ต้องแตะโค้ด**

**ที่ต้องเตรียมในแมพ:** Part ชื่อ **`Spawn_Phase2`** และ **`Spawn_Phase3`** = จุดที่ player โผล่ในแมพเฟสนั้น (เหมือน `Spawn_Phase1`) · ไม่มี = warn + ไม่วาป ไม่ crash

**ข้อความบนจอดำต่อเฟส:** `Content.Cutscenes.PhaseTransitions` — `{ [2] = {บรรทัด...}, [3] = {บรรทัด...} }` · Boss เติมบทเอง · ว่าง = จอดำเฉยๆ แล้ววาป

**ลำดับที่โค้ดทำให้:** รอบท milestone (เช่น "ทะลุ 10K") เล่นจบก่อน → หยุดเวลา → จอดำ → วาป `Spawn_PhaseN` → fade กลับ + เดินเวลาต่อ · ไม่ย้อนเฟส (phase ลดจากโหลดเซฟ/New Game = ไม่วาป)
