# Spec — Opening cutscene + reusable scene transition

**วันที่:** 1 ส.ค. 2569 · **สถานะ:** design (รอ implement)

## เป้าหมาย

ทำให้ Boss "ใช้ระบบเป็น" — เสียบบท/ฉากของตัวเองได้โดยไม่ต้องแตะโค้ด engine:

1. **ฉากเปิดเกม** (mode 1 "หนัง") เล่นตอนกด New Game — ฉากพ่อแม่ในบ้าน แล้วต่อด้วย transition เข้าห้องเฟส 1
2. **Transition ของกลาง** (จอดำ + ข้อความ + วาปแมพ) reuse ได้ทั้ง intro และตอนเปลี่ยนเฟส
3. **จัดระเบียบ** CutsceneCams (ต่อ scene) + FilmSpots (ต่อเฟส) ให้ไม่ปนกัน

**ขอบเขตชัด:** agent สร้างกลไก + template ว่าง + คู่มือ · **บทพูด/ชื่อฉาก/พิกัดกล้อง Boss กรอกเอง** (เก็บบทเป็นความลับได้) ระบบต้องทำงานแม้ template ยังว่าง (แค่ warn ไม่ crash)

## Non-goals

- ไม่เขียนเนื้อเรื่องจริง (งาน Boss)
- ไม่ทำ cutscene ตอนจบ (มี Endings อยู่แล้ว) หรือ canon event
- ไม่ทำให้ player ย้อนกลับแมพเฟสก่อนหน้า (ยืนยันแล้วว่าไม่ออกแบบให้ย้อน)

## โมเดลแมพ (ยืนยันแล้ว)

`Map_Phase1/2/3` โหลดใน Workspace พร้อมกัน คนละพิกัด · เปลี่ยนเฟส = teleport player ไป spawn ของแมพเฟสใหม่ · ไม่ย้อน

---

## Component 1 — ScreenTransition (module ใหม่)

**ไฟล์:** `src/client/ScreenTransition.luau`

จอดำ fade เข้า → (ตอนดำสนิท) ทำงานที่สั่ง → ขึ้นข้อความทีละบรรทัด → fade กลับ

```lua
ScreenTransition.play({
  lines = { "ในที่สุดฉันก็เก็บเงินพอ..." }, -- ข้อความบนจอดำ (ว่างได้ = ดำเฉยๆ)
  onBlack = function() ... end,  -- เรียกตอนจอดำสนิท (teleport / สลับของ) — optional
  fadeTime = 0.6,                -- วิ fade เข้า/ออก
  hold = 2,                      -- วิ/บรรทัด (คลิกข้ามได้)
  onDone = function() ... end,   -- เรียกตอน fade กลับเสร็จ — optional
})
```

**พฤติกรรม:**
- สร้าง ScreenGui `Gui_Transition` DisplayOrder สูง (ทับทุกอย่าง) · Frame ดำเต็มจอ
- fade `BackgroundTransparency` 1→0 (`fadeTime`) → `onBlack()` → โชว์ line ทีละบรรทัด (รอ `hold` วิ หรือคลิก) → fade 0→1 → destroy → `onDone()`
- guard `ScreenTransition.running` กันซ้อน (เหมือน DialogueUI/CutscenePlayer)

**pure ที่เทสได้:** ไม่มี logic คำนวณมาก — ทดสอบด้วย demo/manual · ข้ามเทส pure (YAGNI)

**แนวทางที่เลือก:** module แยกเล็ก ไม่ยัดใน CutscenePlayer เพราะ (ก) reuse ตอนเปลี่ยนเฟสที่ไม่ใช่ cutscene เต็ม (ข) CutscenePlayer มีหน้าที่ letterbox+ซับ+กล้อง คนละงาน

---

## Component 2 — Opening cutscene + trigger

**Content template:** `src/shared/Content/Cutscenes/Opening.luau`
- return ลิสต์ steps ของ CutscenePlayer (`camera`/`text`/`wait`/`anim`/`face`/`bgm`/`sound`)
- agent วาง **โครง placeholder** (comment กำกับว่าแต่ละ step ทำอะไร + ตัวอย่าง 1-2 step) · Boss เติมบท/ชื่อ cam/anim เอง
- ต้องผ่าน `CutscenePlayer.validate` แม้ยังเป็น placeholder (step ถูก format)

**Trigger (client):**
- กด New Game ใน MenuUI → `fireAction({type="NewGame"})` (มีอยู่แล้ว)
- หลังจากนั้น client เล่น `CutscenePlayer.play(Opening, onDone)` → `onDone` เรียก `ScreenTransition.play` วาปเข้าห้องเฟส 1 → เริ่มเล่น
- จุดต่อ: MenuUI.open รับ callback ใหม่ `onNewGame` จาก Main.client — Main.client เป็นคนเล่น cutscene (มี CutscenePlayer/ScreenTransition อยู่แล้ว)

**Cams:** `Workspace.CutsceneCams/Opening/` — cam ชื่อ unique เช่น `Opening_1`

---

## Component 3 — Organization

### CutsceneCams ต่อ scene
- โครง: `Workspace.CutsceneCams/<Scene>/<cam>` เช่น `CutsceneCams/Opening/Opening_1`
- **ชื่อ cam ต้อง unique ทั้งไฟล์** (prefix ชื่อ scene) — เพราะ CutscenePlayer หา cam ด้วย `FindFirstChild(name, true)` (recursive) ชื่อซ้ำ = เจอผิดตัว
- subfolder ไว้ให้คนอ่าน/จัดกลุ่ม · engine ไม่ต้องแก้ (recursive find ทำงานข้าม subfolder อยู่แล้ว)
- อัปเดต `docs/engines/cutscene.md` ให้บอก convention นี้

### FilmSpots ต่อเฟส
- โครง: `Workspace.FilmSpots/Phase1|Phase2|Phase3/<spot>` · ชื่อ spot unique ทั้งไฟล์
- แก้ `filmSpots(state)` ใน `Main.server`: คืน BasePart เฉพาะใต้ `FilmSpots["Phase"..state.phase]` (เดิม scan ทั้ง workspace หา prefix `FilmSpot_`)
- **⚠️ flag:** แตะระบบ record (lock design doc §9.5) — แต่เปลี่ยนแค่ *ขอบเขตว่าใช้ spot ไหน* ไม่แตะสูตร/cooldown/cap/ตัวเลข · สอดคล้อง "ไม่ย้อนแมพ" · ยืนยันกับ design doc ก่อน merge

---

## Component 4 — Phase-transition hook (reuse Transition)

- **Server:** ตรวจ `state.phase` เพิ่มขึ้น (หลัง uploadClip ข้าม gate) → push event ชนิด transition เข้า `state.pendingEvents` เช่น `"phase_2"` (ใช้ pipeline pendingEvents เดิม)
- **Client:** `StateChanged` เจอ event `phase_N` → เล่น `ScreenTransition.play` (บรรทัดที่ Boss เขียนใน template ต่อเฟส) `onBlack` = teleport ไป spawn เฟสใหม่ → fireAction `EventSeen`
- Content: `Content/Cutscenes/PhaseTransition.luau` = แมพ `{ phase_2 = {lines=..., spawn=...}, phase_3 = {...} }` (Boss เติม)
- teleport target: Part spawn ต่อเฟส เช่น `Workspace.Map_Phase2` มี Part ชื่อ `Spawn_Phase2` (attribute หรือ convention)

---

## Data flow สรุป

```
New Game:  MenuUI → NewGame action → Main.client: CutscenePlayer.play(Opening)
           → onDone → ScreenTransition.play(onBlack=teleport เฟส1) → เล่นเกม

เปลี่ยนเฟส: server phase↑ → pendingEvents "phase_N" → StateChanged
           → client ScreenTransition.play(onBlack=teleport เฟสN) → EventSeen

Record:    Main.server filmSpots(state) → เฉพาะ FilmSpots/Phase{state.phase}
```

## คู่มือที่ต้องอัปเดต (ให้ Boss ใช้เป็น)

- `docs/engines/cutscene.md` — วิธีเขียน Opening.luau + PhaseTransition.luau + convention CutsceneCams subfolder + ScreenTransition
- `docs/05-build-conventions.md` — โครง FilmSpots/PhaseN + Spawn_PhaseN + CutsceneCams/Scene

## Testing

- `ScreenTransition` / opening flow = glue (กล้อง/จอ) → เทส manual ใน Play (ไม่มี pure logic คุ้มเทส)
- `filmSpots(state)` เปลี่ยน = เพิ่มเทสใน RunTests: วาง spot จำลอง 2 เฟส → เรียก filmSpots ด้วย state.phase ต่างกัน → คืนเฉพาะเฟสนั้น
- Opening/PhaseTransition template = เพิ่ม content guard ใน RunTests (format ถูก, ผ่าน validate) เหมือน Endings/Dialogue

## ความเสี่ยง / flag

- filmSpots scoping แตะระบบ locked → ยืนยัน design doc §9.5 ก่อน (ไม่แตะตัวเลข)
- teleport spawn ต่อเฟสต้องมี Part จริงในแมพ — ถ้าไม่มี warn + ไม่วาป (ไม่ crash)
- Boss เก็บบทเอง → template ต้องทำงานได้ทั้งตอนว่าง (validate ผ่าน, เล่นแล้วแค่สั้น/ดำเฉยๆ ไม่ error)
