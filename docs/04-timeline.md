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
- ✅ Canva deck 13 สไลด์ (`DAHJLyI79DE`) — ยังต้องเพิ่มภาพแนวคิด slide 10
- 🟡 ตัวละครหลัก + แม่ build ใน Studio R6 บางส่วน (ทิศทาง: R6 classic, ไม่ใช้ AI concept art)
- 🔴 Story system placement ยังไม่ชัด
- 🔴 Activity system (ออกกำลังกาย/พักผ่อน/กินข้าว) ยังไม่ implement — *หมายเหตุ: brief เก่าเขียนว่า "Thai mini-games ยังไม่ embed" แต่ design doc §9 ตัด mini-games แยกถาวรแล้ว ยึด design doc*
- 🔴 Content เขียนจริงยังไม่มี: choice text, NPC script, Canon Event, ending cutscene ×6

## Market projection ที่ใช้พูด (ห้าม inflate)

10 players ตอน launch → 300–500 ภายในวัน pitch
