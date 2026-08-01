# Spec — Opening cutscene + reusable scene transition

**วันที่:** 1 ส.ค. 2569 · **สถานะ:** design (รอ implement)

## เป้าหมาย

ทำให้ Boss "ใช้ระบบเป็น" — เสียบบท/ฉากของตัวเองได้โดยไม่ต้องแตะโค้ด engine:

1. **ฉากเปิดเกม** (mode 1 "หนัง") เล่นตอนกด New Game — ฉากพ่อแม่ในบ้าน แล้วต่อด้วย transition เข้าห้องเฟส 1
2. **Transition ของกลาง** (จอดำ + ข้อความ + วาปแมพ) reuse ได้ทั้ง intro และตอนเปลี่ยนเฟส
3. **จัดระเบียบ** CutsceneCams (ต่อ scene) + FilmSpots (ต่อเฟส) ให้ไม่ปนกัน

**ขอบเขตชัด:** agent สร้างกลไก + template ว่าง + คู่มือ · **บทพูด/ชื่อฉาก/พิกัดกล้อง Boss กรอกเอง** (เก็บบทเป็นความลับได้) ระบบต้องทำงานแม้ template ยังว่าง (แค่ warn ไม่ crash)

**plan แรกทำแค่:** ScreenTransition (module ทั่วไป) + Opening cutscene. ScreenTransition ออกแบบให้ทั่วไป Boss เอาไป reuse เองกับ ending / ฉากรับรางวัล BCA / เปลี่ยนเฟส ทีหลัง (ไม่อยู่ใน plan นี้)

## Non-goals

- ไม่เขียนเนื้อเรื่องจริง (งาน Boss)
- ไม่ทำ cutscene ตอนจบ (มี Endings อยู่แล้ว) หรือ canon event
- ไม่ทำให้ player ย้อนกลับแมพเฟสก่อนหน้า (ยืนยันแล้วว่าไม่ออกแบบให้ย้อน)

## โมเดลแมพ (ยืนยันแล้ว)

`Map_Phase1/2/3` โหลดใน Workspace พร้อมกัน คนละพิกัด · เปลี่ยนเฟส = teleport player ไป spawn ของแมพเฟสใหม่ · ไม่ย้อน

---

## Component 1 — ScreenTransition (module ใหม่, ทั่วไป)

**ไฟล์:** `src/client/ScreenTransition.luau`

จอดำ fade เข้า → (ตอนดำสนิท) ทำงานที่สั่ง → **ขึ้นข้อความผ่าน DialogueUI** → fade กลับ

```lua
ScreenTransition.play({
  lines = { "ในที่สุดฉันก็เก็บเงินพอ..." }, -- ส่งเข้า DialogueUI ตรงๆ (ว่างได้ = ดำเฉยๆ)
  onBlack = function() ... end,  -- เรียกตอนจอดำสนิท (teleport / สลับของ) — optional
  fadeTime = 0.6,                -- วิ fade เข้า/ออก
  onDone = function() ... end,   -- เรียกตอน fade กลับเสร็จ — optional
})
```

**พฤติกรรม:**
- สร้าง ScreenGui `Gui_Transition` · Frame ดำเต็มจอ · fade `BackgroundTransparency` 1→0 (`fadeTime`)
- ดำสนิท → `onBlack()` → **`DialogueUI.show(playerGui, lines, ...)`** โชว์ข้อความ (บรรทัดไม่มี speaker = reuse ตัวเดียวกับตอนคุย NPC, typewriter + คลิกไปต่อ) → รอ DialogueUI จบ
- fade 0→1 → destroy → `onDone()`
- guard `ScreenTransition.running` กันซ้อน

**reuse ข้อความจาก DialogueUI (Boss สั่ง):** ไม่ render text เอง — เรียก `DialogueUI.show` บนพื้นจอดำ ให้หน้าตา/typewriter เหมือนบรรทัดไม่ระบุคนพูดทุกที่ในเกม
- **impl detail:** จอดำต้องอยู่ใต้กล่อง DialogueUI — ตั้ง `Gui_Transition.DisplayOrder` แล้วดัน `Gui_Dialogue.DisplayOrder` สูงกว่า (DialogueUI สร้าง gui เอง ScreenTransition set order หลัง show)

**pure ที่เทสได้:** ไม่มี logic คำนวณ — ทดสอบ manual ใน Play · ข้ามเทส pure (YAGNI)

**แนวทางที่เลือก:** module แยกเล็ก ไม่ยัดใน CutscenePlayer — reuse ได้กว้าง (opening/ending/BCA/เปลี่ยนเฟส) · text delegate ให้ DialogueUI (ไม่ทำ UI ซ้ำ)

---

## Component 2 — Opening cutscene + trigger

**ใช้ CutscenePlayer = mode 1 "หนัง" จริง** (ยืนยัน): ตัวละคร **animate** ได้ (`anim` one-shot/loop, `face` สีหน้า), กล้อง **ขยับ** (`camera` tween), ซับแบบ letterbox **ไม่มีกล่องข้อความ ไม่มีช้อย ไม่รอ input** — เดินตามเวลา (`wait`) เอง · คนละตัวกับ DialogueUI (โหมด 2 ที่ยืนนิ่ง+ตอบโต้). ตัวละครจะขยับจริงเมื่อ Boss ใส่ animation ใน `ReplicatedStorage.Animations` + เขียน `anim` step

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

### FilmSpots ต่อเฟส — **follow-up แยก ไม่อยู่ใน plan opening**
- โครง: `Workspace.FilmSpots/Phase1|Phase2|Phase3/<spot>` · ชื่อ spot unique ทั้งไฟล์
- แก้ `filmSpots(state)` ใน `Main.server`: คืน BasePart เฉพาะใต้ `FilmSpots["Phase"..state.phase]` (เดิม scan ทั้ง workspace หา prefix `FilmSpot_`)
- **⚠️ flag:** แตะระบบ record (lock design doc §9.5) — เปลี่ยนแค่ *ขอบเขตว่าใช้ spot ไหน* ไม่แตะสูตร/cooldown/cap/ตัวเลข · สอดคล้อง "ไม่ย้อนแมพ" · ยืนยันกับ design doc ก่อน merge
- แยกทำทีหลัง ไม่เกี่ยวกับ opening

---

## Component 4 — reuse ทีหลัง (ไม่อยู่ใน plan นี้)

ScreenTransition ออกแบบทั่วไปพอให้ Boss/agent เอาไป reuse เองกับ:
- **เปลี่ยนเฟส:** server เห็น `state.phase` เพิ่ม → คิว event → client `ScreenTransition.play(onBlack = teleport spawn เฟสใหม่)`
- **ending / ฉากรับรางวัล BCA:** เรียก `ScreenTransition.play` คั่นก่อน/หลัง cutscene
- teleport target ต่อเฟส: convention `Spawn_PhaseN` (ออกแบบตอนทำ follow-up)

plan opening **ไม่ต้องทำพวกนี้** — แค่ ScreenTransition ต้อง API ทั่วไปพอ reuse ได้

---

## Data flow (plan นี้)

```
New Game:  MenuUI → NewGame action → Main.client: CutscenePlayer.play(Opening)
           → onDone → ScreenTransition.play(onBlack=teleport เฟส1) → เล่นเกม
```

(เปลี่ยนเฟส / ending / filmSpots = follow-up แยก reuse ScreenTransition/แก้ filmSpots ทีหลัง)

## คู่มือที่ต้องอัปเดต (ให้ Boss ใช้เป็น)

- `docs/engines/cutscene.md` — วิธีเขียน Opening.luau + convention CutsceneCams subfolder + วิธีเรียก ScreenTransition
- `docs/05-build-conventions.md` — โครง CutsceneCams/\<Scene\> (FilmSpots/PhaseN + Spawn_PhaseN เพิ่มตอน follow-up)

## Testing (plan นี้)

- `ScreenTransition` / opening flow = glue (กล้อง/จอ) → เทส manual ใน Play (ไม่มี pure logic คุ้มเทส)
- Opening template = เพิ่ม content guard ใน RunTests (format ถูก ผ่าน `CutscenePlayer.validate`) เหมือน Endings/Dialogue
- (`filmSpots(state)` test = ตอนทำ follow-up FilmSpots)

## ความเสี่ยง / flag

- filmSpots scoping แตะระบบ locked → ยืนยัน design doc §9.5 ก่อน (ไม่แตะตัวเลข)
- teleport spawn ต่อเฟสต้องมี Part จริงในแมพ — ถ้าไม่มี warn + ไม่วาป (ไม่ crash)
- Boss เก็บบทเอง → template ต้องทำงานได้ทั้งตอนว่าง (validate ผ่าน, เล่นแล้วแค่สั้น/ดำเฉยๆ ไม่ error)
