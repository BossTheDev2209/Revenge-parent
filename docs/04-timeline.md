# Timeline — 15 มิ.ย. – 12 ส.ค. 2569 (8 สัปดาห์)

| สัปดาห์ | ช่วง | แผน |
|---------|------|-----|
| W1–2 | 15–28 มิ.ย. | Core idle loop, ระบบ follower/เงิน, UI ห้องเช่า, map หลัก |
| W3–4 | 29 มิ.ย.–12 ก.ค. | Story events, milestone 1K/10K, path split, branching |
| W5–6 | 13–26 ก.ค. | Assets ตัวละคร/ฉาก, Activity system (แทน Thai mini-games ที่ตัดแล้ว), upgrade tree, 100K milestone |
| W7 | 27 ก.ค.–3 ส.ค. | Endings ทั้ง 6, 1M ending, effects/เสียง, internal playtest |
| W8 | 4–12 ส.ค. | Bug fix, optimize, pitch deck finalize, ส่งผลงาน |

## สถานะจริง (อัปเดตทุกครั้งที่ปิด task — ห้ามปล่อยให้ค้าง)

- ✅ Design lock (12 ก.ค.) — `docs/02-game-design-locked.md`
- ✅ Architecture + จัดอันดับระบบ (19 ก.ค.) — `docs/06`, `docs/07`
- ✅ Config + Formulas + เทส 46 ข้อผ่าน (19 ก.ค.) — `src/shared/`
- ✅ Sync เข้า Studio ผ่าน MCP (19 ก.ค.) — วิธี+driver อยู่ docs/08 §0
- ✅ GameState + Save 4 slot + ActionRouter + Main.server (19 ก.ค.) — เทส 65/65 ผ่านทั้ง lune และใน Studio
- ✅ TimeService — นาฬิกากลาง tick/freeze/นอน 8-12 ชม. (19 ก.ค.) — เทส 78/78 ผ่านทั้งสองที่
- ✅ **Core loop เดโม่ได้** (19 ก.ค.): Mental(พื้นฐาน)/Follower/Money + HUD placeholder + wiring — เทส 102/102 ทั้ง lune/Studio + Play mode ไม่มี error — mental drain modifiers รอ user ตัดสิน (docs/08 §4)
- ✅ **เล่นได้ด้วยมือจริง** (19 ก.ค.): Edit QTE 20 ปุ่ม + InteractBinder + Activity system (streak 3/cooldown) + placeholder Interact_ parts 4 จุด — เทส 115/115 — docs/07 top-5 ครบทั้ง 5 ตัวแล้ว
- ✅ **Engine ครบทุกตัว** (19 ก.ค.): Dialogue typewriter+tag / Comment choice ⊕◎⊖ / Calendar+Sponsor / EndingService (Bad1/Bad2 สด + % ที่ 1M) / CutscenePlayer / Canon milestone events — เทส 151/151 ทั้ง lune+Studio — **เหลือแค่เติมบทใน Content/ ไม่ต้องแตะโค้ด**
- ✅ Main Menu + Save/Load UI (19 ก.ค.): Continue/save 4 ช่อง/Credit/ปุ่มเซฟ — เทส 155/155
- ✅ Mental modifiers ครบ (19 ก.ค. — user lock 4 decision ใน docs/02 §3): อดนอน 20 ชม./canon/ตัด 5 ติด/comment streak/viral 2 วันติด + cap ×3 + action Sleep + เมนูเตียง — เทส 172/172
- ✅ HUD v2 + PC Screen แบบ Jim's Computer (19 ก.ค.): แยก UI 2 ชั้นตาม PDF หน้า 5 — เครื่องต่างตามเฟส (โน้ตบุ๊ค/desktop/RGB), apps 8: Edit/Upload/Feedback(+ตอบ comment)/Bank/ปฏิทิน+sponsor/Shop(BuyUpgrade)/Message/Manage(รอ) — เทส 176/176
- ✅ **Upgrade กล้อง → VidQ: ล็อกแล้วว่าไม่แตะกันเลย** (26 ก.ค., แก้จากบรรทัดเดิมที่ค้าง flag ไว้) — VidQ tier มาจากคะแนน QTE ตอนตัดคลิปอย่างเดียว กล้องคูณแค่ GB/คลิกตอนอัด (docs/02 §9.5)
- ⚠️ **ต้องทำใน Studio (คนเดียวที่ทำได้คือทีม):** Game Settings → Security → เปิด "Enable Studio Access to API Services" (place ต้อง publish ก่อน) — ไม่งั้น save ใช้ไม่ได้ (ตอนนี้ error 403 แต่เกมไม่ crash)
- ✅ Canva deck 13 สไลด์ (`DAHJLyI79DE`) — ยังต้องเพิ่มภาพแนวคิด slide 10
- ✅ **ร้านค้าในแมพ `Interact_Shop`** (28 ก.ค.): 3 สาย (กล้อง/ที่เก็บ/คอมพิวเตอร์) ขยายจาก 6 → **15 ระดับ** layout ตามภาพร่าง PDF หน้า 9 เป๊ะ (แถวละหมวด + การ์ด 4 ใบ + ลูกศรเลื่อน) — ระดับ 1-6 ล็อกเดิมไม่ขยับ, 7-15 + สาย pc ทั้งเส้น ⏳ รอ user lock ราคา/ผล — docs/02 §9.5, docs/09 §10, docs/13 §5 อัปเดตตรงกับโค้ดแล้ว
- ✅ **ป้าย `Interact_*` จางตามระยะ** (28 ก.ค.): ระบบกลางใน InteractBinder — ≤14 studs ชัดเต็ม (ครอบระยะกด ProximityPrompt พอดี) / ≥30 หายสนิท ปิด BillboardGui ไปเลย — ใช้กับป้ายทุกจุดในแมพอัตโนมัติ ไม่ใช่แค่ร้าน
- ✅ **Cutscene แยก 2 โหมดชัดเจน + Studio plugin ตั้งกล้อง** (28 ก.ค. — บอส): cinematic (`CutscenePlayer` — ไม่มีกล่องข้อความ ตัดฉากอิสระ) vs dialogue scene (`DialogueUI` — กล่องข้อความ + ชื่อผู้พูด + choice) แยกตามเรฟ Genshin ที่บอสให้ + `tools/CutsceneCamTool.plugin.luau` ตั้ง/ดูมุมกล้องใน Studio ได้จริง (Place Cam / Aim Cam / Look Thru / Tour) — choice มี tone แต่ **ล็อกแล้วว่าไม่มีผลกับ mental** (กัน branching ทางอ้อม — docs/engines/dialogue.md)
- ✅ **เทสกันไม้ตายเนื้อหา** (28 ก.ค.): เทส fail อัตโนมัติถ้าไฟล์เนื้อหาไหนยังมี `[placeholder]` ค้าง ครอบทั้ง 21 ไฟล์ (CanonEvents 8 + Dialogue 7 + Endings 6) — ใช้นับ progress เขียนบทแทนกะด้วยตา **ตอนนี้ 0/21**
- ⚠️ **เทสชุดเต็มยังไม่เคยรันจบใน Play mode** ตั้งแต่ 19 ก.ค. — Edit mode cache `require` ไว้ ตรวจได้แค่ทีละส่วน ต้องรันจริงที่ `ServerScriptService.Tests.RunTests` (ติ๊ก Enabled → Play → ดู Output) ก่อนเชื่อตัวเลข pass/fail รวม
- 🟡 ตัวละครหลัก + แม่ build ใน Studio R6 บางส่วน (ทิศทาง: R6 classic, ไม่ใช้ AI concept art)
- 🔴 Story system placement ยังไม่ชัด
- 🔴 Content เขียนจริงยังไม่มี: choice text, NPC script, Canon Event, ending cutscene ×6 (0/21 — ดูเทสกันไม้ตายด้านบน)

## Market projection ที่ใช้พูด (ห้าม inflate)

10 players ตอน launch → 300–500 ภายในวัน pitch
