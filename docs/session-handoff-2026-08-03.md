# Session handoff — 2-3 ส.ค. 2569

สรุปงาน cutscene/dialogue/streaming รอบนี้ + รายการทำต่อพรุ่งนี้

## เสร็จแล้วรอบนี้

### CutsceneCamTool rework ([tools/CutsceneCamTool.plugin.luau](../tools/CutsceneCamTool.plugin.luau))
- **Cam Panel** = property editor: เลือก Part กล้อง → แก้ Ease (dropdown InOut/In/Out/Linear/Cut) / TweenTime / FOV · เลือกหลายตัวแก้พร้อมกัน · ค่าต่างกันโชว์ `—`
- Place ลง `CutsceneCams/<Cutscene>/` เป็น Persistent Model อัตโนมัติ (กัน streaming cull) ชื่อ `<Cutscene>_NN`
- Tour พรีวิว ease/เวลาจริง
- ⚠️ plugin ติดตั้งเป็น**สำเนา** — แก้แล้วรัน `pwsh tools/install_plugin.ps1` ทุกครั้ง + reload Studio

### Cutscene engine ([CutscenePlayer.luau](../src/client/UI/CutscenePlayer.luau))
- อ่าน Ease/TweenTime จาก attribute บน Part (step ทับได้ด้วย `ease=`/`t=`) · เพิ่ม Linear · Cut/t=0 = ตัดภาพ
- `text` step: ใส่ `t` = ค้างกี่วิ (ไม่ใส่ = ไม่รอ ใช้ wait เอง) — ไม่ auto-wait แล้ว
- **freeze เวลาเกมเองทุกครั้งที่เล่น** + lock เดินตัวละคร (WalkSpeed/Jump=0) คืนตอนจบ
- letterbox `IgnoreGuiInset=true` (คลุมเต็มจอ)

### dialogue-seen (จำว่าเคยคุย — Undertale style)
- content เพิ่มตาราง `again` (optional) = บทคุยซ้ำในเฟสเดิม · ไม่มี = เล่นบทเต็มเหมือนเดิม
- `state.seenDialogue[name]=phase` persist ในเซฟ · [pickLines](../src/client/InteractBinder.luau) รับ param `seen`
- ไฟล์: InteractBinder, Main.client (wiring + DialogueSeen action), Main.server (route), GameState (init), RunTests (เทส)

### บั๊ก cutscene 7 ข้อ
- blackbars เต็มจอ · text ไม่ค้างนาน · ตัวละครไม่เดินตอน cutscene · เพิ่ม Linear · attribute ให้ part เก่า (sweep Opening_06..19) · ซ่อน backpack เวลามี modal เปิด ([Main.client](../src/client/Main.client.luau) watcher)

### Lighting ผูกนาฬิกาเกม (แก้ฟ้าเพี้ยน/ข้ามวันตอน cutscene)
- **ต้นเหตุ:** Toolbox `ServerScriptService.DayNight` เดิน ClockTime เอง ไม่สน freeze → **ปิดแล้ว (Disabled=true)**
- `Lighting.ClockTime` ขับจาก `state.timeOfDay` ที่ Main.server (`syncLighting`) → freeze เวลา = ฟ้าหยุด
- server freeze เวลาตอน NewGame ด้วย (กัน client sync ช้า)
- ⚠️ อยู่ใน .rbxl — ต้อง save place

### Preload ตอนวาปข้ามแมพ (teleport แล้วโมเดลไม่โหลด)
- [Main.client `waitStreamedAround`](../src/client/Main.client.luau): จอดำค้าง → anchor กันตกทะลุพื้น → รอ raycast เจอพื้น → fade กลับ · ใช้ทั้ง Opening + phase transition
- server `TeleportTo` เรียก `RequestStreamingAround` (มีเฉพาะ live Roblox — pcall กันไว้)

## ทำต่อพรุ่งนี้ (4 ส.ค.)

- [ ] **Preload เฟส 1 ระหว่าง Opening (cam 2 ตัวส่องเฟส 1)** — Studio version เก่าไม่มี ReplicationFocus/RequestStreamingAround, family set (Y2185) กับ Spawn_Phase1 (Y30) ห่าง ~2000 studs
  → ทางแก้: ทำ**ห้องเริ่มเฟส 1** (ที่ cam ส่อง + spawn) เป็น **Persistent Model** (`ModelStreamingMode=Persistent`) · Boss ชี้ Model ห้องใน `Map_Phase1` ให้ set · เปิด streaming เฟส 2 ได้หลังทำ
  → พิจารณา: อัปเดต Studio ให้ได้ API streaming ใหม่ (live Roblox มีอยู่แล้ว)
- [ ] **บั๊กแขนแกว่ง/ห้อยตอนเดิน-วิ่ง** — จากข้อมูล char ปกติหมด (R6, Motor6D ครบ, default anim ครบ, ไม่มี Tool ถือ) · ต้องดูภาพ/คลิปจริง หรือระบุพจน์ให้ชัด (ห้อยนิ่ง vs สะบัด, เกิดกับ NPC ด้วยไหม) ก่อนแก้
- [ ] เขียน content จริงแทน placeholder: PhaseTransitions, Opening text (บางส่วนเขียนแล้ว), Endings×6, Dialogue, CanonEvents (เทส RunTests fail จนกว่าจะเขียน — 21 ตัว)
- [ ] set Persistent ให้ family scene เฟส 0 ถ้าจำเป็น (ตอนย้าย focus)

## เช็คก่อนเริ่มพรุ่งนี้
- Rojo **Connect** (หลุดทุก restart Studio) · plugin ต้อง `pwsh tools/install_plugin.ps1` ถ้าแก้
- save place (.rbxl) — DayNight ปิด + attribute cams + family anchor อยู่ในนั้น
