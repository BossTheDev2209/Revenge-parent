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

## เสร็จเพิ่ม (4 ส.ค.)

### Preload แมพระหว่าง cutscene — step `focus` ✅
- Studio อัปเดตล่าสุดแล้ว → `ReplicationFocus`/`RequestStreamingAround` **มีครบ** (เดิมเก่าเลยไม่มี)
- step ใหม่ `{ type="focus", target="Spawn_Phase1" }` ใน cutscene ([CutscenePlayer](../src/client/UI/CutscenePlayer.luau)) → server `SetFocus` ย้ายศูนย์ streaming ([Main.server](../src/server/Main.server.luau)) → แมพเป้าโหลดตอน cutscene เล่น (cam ส่องเห็น)
- **ไม่ต้องทำ Persistent room แล้ว** (วิธี focus แทน) — เปิด streaming เฟส 2 ได้
- **fix reload/pause:** ห้าม clear focus ตอนจบฉาก · `TeleportTo` เป็นคน clear หลังย้ายตัวเข้าโซน (โซน preload ไว้ = ไม่ unload/pause) · ข้อจำกัด: focus ใช้กับ cutscene ที่จบด้วย TeleportTo เข้าโซนนั้น

### นาฬิกาเดินระดับนาที + ดวงอาทิตย์ลื่น ✅
- [HUD](../src/client/UI/HUD.luau) interpolate `gameHour` (float) ต่อเฟรมจาก server tick รายชั่วโมง → แสดง **HH:MM** + ขับ `Lighting.ClockTime` ลื่น (แทน server set รายชั่วโมงกระตุก)
- หยุดตอน cutscene/คุย NPC ผ่าน `state.frozen` ([FreezeTime handler](../src/server/Main.server.luau))
- server ยัง set ClockTime รายชั่วโมงให้ script ฝั่ง server (autoturnlight) · client override ทับให้ลื่น

### อื่นๆ
- merge commit เพื่อน (วรกร) `b1d4fe4` shop ย้อนระดับอุปกรณ์ — pull เข้าแล้ว ไม่ชน
- plugin re-install หลัง Studio อัปเดต (`pwsh tools/install_plugin.ps1`)

## ทำต่อ

- [ ] **บั๊กแขนแกว่ง/ห้อยตอนเดิน-วิ่ง** — จากข้อมูล char ปกติหมด (R6, Motor6D ครบ, default anim ครบ, ไม่มี Tool ถือ) · ต้องดูภาพ/คลิปจริง หรือระบุพจน์ให้ชัด (ห้อยนิ่ง vs สะบัด, เกิดกับ NPC ด้วยไหม) ก่อนแก้
- [ ] จัดตำแหน่ง cam เฟส 1 ใน Opening ให้ใกล้/ในเฟส 1 (focus โหลด geometry ให้ · แต่ cam วางไกล = ภาพยังเห็นไกล)
- [ ] เขียน content จริงแทน placeholder: PhaseTransitions, Opening text (เขียนแล้วเยอะ), Endings×6, Dialogue, CanonEvents (เทส RunTests fail จนกว่าจะเขียน — ~21 ตัว)
- [ ] commit + push งานรอบนี้ (uncommitted: focus preload, minutes/sun, install_plugin)

## เช็คก่อนเริ่ม session ใหม่
- Rojo **Connect** (หลุดทุก restart Studio) · plugin ต้อง `pwsh tools/install_plugin.ps1` ถ้าแก้ + reload Studio
- save place (.rbxl) — DayNight ปิด + attribute cams + family anchor อยู่ในนั้น
