# Opening cutscene + scene transition — design (1 ส.ค. 2569)

## เป้าหมาย
- ฉากเปิดตอนกด New Game (mode 1 "หนัง"): ฉากพ่อแม่ในบ้าน แล้ววาปเข้าห้องเฟส 1
- ระบบ transition ใช้ซ้ำได้ (จอดำ + ข้อความ + teleport) สำหรับ intro และเปลี่ยนเฟส 1→2→3
- จัดระเบียบ CutsceneCams (ต่อ scene) + FilmSpots (ต่อเฟส)
- บททั้งหมด = placeholder ที่ agent เขียน · Boss ใช้ระบบเป็นพอ (ไม่ต้องเขียนบท)

## 1. ScreenTransition (module ใหม่)
`src/client/ScreenTransition.luau`
```lua
Transition.play({ lines = {"..."}, onBlack = function() end, fadeTime = 0.6, hold = 2, onDone = function() end })
```
- ScreenGui + Frame ดำเต็มจอ DisplayOrder สูง (ทับทุกอย่าง)
- fade เข้า (BackgroundTransparency 1→0, `fadeTime` วิ)
- พอดำสนิท เรียก `onBlack()` (teleport / สลับของ ตอนมองไม่เห็น)
- โชว์ text ทีละบรรทัด กลางจอ auto รอ `hold` วิ/บรรทัด (คลิกข้ามได้)
- fade กลับ (0→1) → ลบ gui → `onDone()`
- guard: กันเรียกซ้อน (`running` flag)
- pure ที่เทสได้: น้อย — แค่ helper คำนวณเวลารวม (ถ้ามี) · logic หลักเป็น glue

## 2. Opening cutscene
- content: `src/shared/Content/Cutscenes/Opening.luau` — return steps table (รูปแบบเดียวกับ Content/Endings) ใช้ step: camera / text / wait / anim / face / bgm / sound
- โครงฉาก (placeholder โดย agent): พ่อ/แม่ในบ้าน กดดัน → ตัด/เลื่อนกล้องหลายช็อต → จบด้วย Transition วาปเข้าห้องเฟส 1
- trigger: กด New Game (MenuUI) → fireAction NewGame → client เล่น `CutscenePlayer.play(Opening)` → onDone → `Transition.play` (onBlack = teleport ไป spawn เฟส 1)
- cams: `Workspace.CutsceneCams/Opening/` ตั้งชื่อ `Opening_1`, `Opening_2`, ...

## 3. Organization
### CutsceneCams
- subfolder ต่อ scene: `CutsceneCams/Opening/`, `CutsceneCams/Phase1to2/`, ...
- cam part ตั้งชื่อ **unique** (prefix scene) เพราะ CutscenePlayer หา cam แบบ recursive (`FindFirstChild(name, true)`) — ชื่อซ้ำข้าม scene = หาผิดตัว
- ไม่แก้ engine — แค่ convention การตั้งชื่อ/วาง

### FilmSpots (ต่อเฟส)
- ย้ายไป `Workspace.FilmSpots/Phase1|Phase2|Phase3/` (BasePart อะไรก็ได้ในโฟลเดอร์ ไม่ต้อง prefix)
- แก้ `filmSpots(state)` ใน Main.server: คืนเฉพาะ BasePart ใต้ `FilmSpots["Phase"..state.phase]` (เดิม scan ทั้ง workspace หา prefix `FilmSpot_`)
- ตั้งชื่อ spot unique ข้ามเฟส (client หา zone part by name แบบ recursive)
- ⚠️ แตะ logic ระบบ record (lock docs/02 §9.5) — **เป็นแค่ scoping ว่าใช้ spot ไหน ไม่แตะสูตร/ตัวเลข** สอดคล้อง "ไม่ย้อนแมพเฟสเก่า" · ไม่ขัด design doc

## 4. เปลี่ยนเฟส (reuse Transition)
- server: หลัง follower ข้าม gate (`state.phase` เพิ่ม) → คิว marker ใน `pendingEvents` เช่น `phase_2`
- client: เจอ marker `phase_N` → เล่น `Transition.play` (บรรทัดปูเรื่อง + onBlack teleport ไป spawn เฟส N) แทน dialogue → แจ้ง EventSeen
- ตัวอย่างบรรทัด (placeholder): "ในที่สุดฉันก็เก็บเงินพอ... พอจะเช่าบ้านของตัวเองอยู่ได้สักที"

## Teleport target
- แต่ละเฟสมี spawn part (เช่น `Workspace.Map_PhaseN.Spawn` หรือ attribute) — Transition onBlack ย้าย HumanoidRootPart ไปจุดนั้น (client-side, singleplayer เหมือน Interact_Door)

## นอก scope (YAGNI)
- ไม่ทำ backtrack ไปแมพเฟสเก่า
- ไม่ทำ transition แบบมี branching / เลือกได้
- opening ไม่ save flag "เคยดู" (เล่นทุก New Game ตามที่ตกลง)

## ไฟล์ที่แตะ
- ใหม่: `src/client/ScreenTransition.luau`, `src/shared/Content/Cutscenes/Opening.luau`
- แก้: `src/server/Services/...`/`Main.server.luau` (phase marker + filmSpots scoping), `src/client/Main.client.luau` (New Game → opening → transition; phase marker handler), MenuUI (New Game hook ถ้าจำเป็น)
- Studio: สร้าง `CutsceneCams/Opening/`, `FilmSpots/PhaseN/`, spawn parts ต่อเฟส (Boss วาง cam ด้วย plugin)
- docs: อัปเดต `docs/engines/cutscene.md` + คู่มือใช้ให้ Boss
