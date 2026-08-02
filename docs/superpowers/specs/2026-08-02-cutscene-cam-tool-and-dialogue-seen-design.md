# Design — CutsceneCamTool rework + dialogue-seen

วันที่: 2026-08-02 · ทีม: หอยทากเทอร์โบ28

2 งานทำรอบเดียว: (1) rework plugin วางกล้อง cutscene ให้ authoring ง่ายขึ้น, (2) จำว่าเคยคุย NPC แล้ว ไม่เล่นบทเดิมซ้ำ

---

## งาน 1 — CutsceneCamTool rework

### ปัญหาเดิม
- plugin ตั้งชื่อ `Cam_01` generic ทุก cutscene → content script ต้องอ้างชื่อ cutscene-specific เอง → ชื่อไม่ตรง cutscene ไม่เล่น (บั๊กจริง 2 ส.ค.: script เขียน `Opening_01` แต่ part ชื่อ `Cam_01`)
- กล้องไกล spawn โดน StreamingEnabled cull ออกจาก client → ต้องห่อ Persistent Model เองทีหลัง
- easing hardcode `Quad InOut` ใน CutscenePlayer — คุม ease in/out/hard cut ต่อกล้องไม่ได้

### โครงกล้องใน Workspace (ใหม่)
```
CutsceneCams/
  <Cutscene>/            ← Model, ModelStreamingMode = Persistent (client เห็นเสมอ)
    <Cutscene>_01        ← Part + attribute FOV, Ease, TweenTime
    <Cutscene>_02
```
- subfolder ต่อ cutscene = จัดกลุ่ม + เป็น Persistent Model แก้ streaming ในตัว
- ชื่อ part มี prefix cutscene = unique กัน recursive `FindFirstChild(cam, true)` จับผิดตัว

### plugin เปลี่ยน (tools/CutsceneCamTool.plugin.luau)
- **TextBox "Cutscene"** — พิมพ์ชื่อกลุ่ม (เช่น `Opening`) จำค่าล่าสุด (ใช้ `plugin:GetSetting`/`SetSetting`)
- **Place Cam** — วาง part ลง Model `CutsceneCams/<Cutscene>/` (สร้าง Model + set `ModelStreamingMode = Persistent` ถ้ายังไม่มี) ตั้งชื่อ `<Cutscene>_NN` เลขรันในกลุ่มนั้น set default `Ease="InOut"`, `TweenTime=1`
- **ปุ่ม Ease** — วนค่า `InOut → In → Out → Cut` set attribute `Ease` บน part ที่เลือก ปุ่มโชว์ค่าปัจจุบัน
- **Aim / Look Thru** — เหมือนเดิม
- **Tour** — อ่าน `Ease`/`TweenTime` จริงเวลา preview (ใช้ easing map เดียวกับ runtime)

### CutscenePlayer อ่าน easing (src/client/UI/CutscenePlayer.luau)
`moveCam` รับ ease style/dir. ลำดับความสำคัญ (step ทับ attribute ทับ default):
```
ease = step.ease or part:GetAttribute("Ease") or "InOut"
t    = step.t   or part:GetAttribute("TweenTime") or 0
ease == "Cut" หรือ t == 0 → ตัดภาพทันที (เหมือนเดิม)
```
map easing (style คง `Quad`):
| Ease | EasingDirection |
|------|-----------------|
| In | In |
| Out | Out |
| InOut | InOut |
| Cut | (ตัดทันที ไม่ tween) |

`camera` step ที่ใช้ `pos/look` (ไม่มี part) ใช้ `step.ease`/`step.t` อย่างเดียว (ไม่มี attribute ให้อ่าน) default InOut

### content script
เขียนแค่ `{ type = "camera", cam = "Opening_02" }` — easing/เวลามาจาก attribute. ใส่ `t=`/`ease=` เมื่ออยาก override ในโค้ด

### validate (CutscenePlayer.VALID.camera)
`ease` optional: ถ้าใส่ต้องเป็น string ใน `{In, Out, InOut, Cut}`

### เก็บกวาดของเดิม
- ย้าย `CutsceneCams/Persistent/Cam_01..05` → `CutsceneCams/Opening/`, rename `Opening_01..05` (via Studio MCP)
- Opening.luau กลับไปใช้ `Opening_01/02`
- อัปเดต docs/engines/cutscene.md §3 + docs/05-build-conventions.md

---

## งาน 2 — dialogue-seen (จำว่าเคยคุยแล้ว)

### เป้า
คุย NPC ซ้ำในเฟสเดิมไม่เล่นบทเต็มซ้ำ เล่นบทสั้นแทน (Undertale-style) — เหตุผล feel/immersion ล้วน
(**หมายเหตุ:** `tone` ไม่ผูก mental — ล็อก 28 ก.ค. dialogue.md §tone — ไม่มี exploit ให้กัน)

### content — ตารางเสริม `again` (optional)
(ชื่อ field ต้อง `again` ไม่ใช่ `repeat` — `repeat` เป็น keyword Lua parse ไม่ผ่าน)
```lua
again = {
  { speaker = "แม่", text = "บอกไปแล้วไง ไปทำงานได้แล้ว" },
}
```
ไม่เขียน `again` = คุยซ้ำเล่นบทเต็มเหมือนเดิม (ไม่ regress)

### pickLines (src/client/InteractBinder.luau) — เพิ่ม param `seen`
```
InteractBinder.pickLines(mod, state, seen)
  seen == true และ mod.again → return mod.again
  ไม่งั้น → เลือกตามเฟส/after เหมือนเดิม
```

### state — `state.seenDialogue = { [name] = phase }`
- เก็บเฟสล่าสุดที่คุย NPC ตัวนั้นจนจบ (บทเต็ม)
- `seen = state.seenDialogue[name] == state.phase` (เฟสขยับ = ไม่ seen = เล่นเต็มรอบนึงก่อน แล้วค่อยซ้ำ)
- init `{}` ตอน newGame (GameState) · อยู่ในตาราง state ที่เซฟอยู่แล้ว → persist ฟรี **(verify: SaveService serialize ทั้ง state)**

### wiring (src/client/Main.client.luau `startDialogue`)
- ก่อนโชว์: `seen = latestState.seenDialogue และ latestState.seenDialogue[dialogueName] == latestState.phase`
- ส่ง `seen` เข้า `pickLines(require(mod), latestState, seen)`
- หลังบทจบ (ใน onDone) fire `{ type = "DialogueSeen", name = dialogueName }` **เฉพาะตอนเล่นบทเต็ม** (ไม่ใช่ตอนเล่น repeat — กัน overwrite เฟสเดิมซ้ำ ไม่มีผลแต่ไม่จำเป็น)

### server (src/server/Main.server.luau route + GameState)
- action `DialogueSeen` → `state.seenDialogue[action.name] = state.phase` → broadcast StateChanged
- GameState.newGame: `state.seenDialogue = {}`

### test (tests/RunTests.luau)
pickLines pure:
- seen=true + มี `again` → ได้ `again`
- seen=true + ไม่มี `again` → ได้บทเฟส (fallback)
- seen=false → ได้บทเฟสเสมอ

---

## ลำดับทำ
1. plugin rework + easing map
2. CutscenePlayer อ่าน ease/attribute + validate
3. ย้าย/rename cams ใน Studio + Opening.luau
4. pickLines seen param + test
5. DialogueSeen action (server) + GameState init + verify save persist
6. Main.client wiring
7. docs: cutscene.md, dialogue.md, build-conventions
8. รันเทส + Play ทดสอบจริง
