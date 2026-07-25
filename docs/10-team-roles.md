# 10 — แบ่งหน้าที่ทีม + กติกาใช้ agent พร้อมกัน

**ใครต้องอ่าน:** ทั้ง 3 คน อ่านให้จบก่อนเปิด Studio / เปิด agent
**หลักการเดียวที่ทำให้ 3 agent ทำงานพร้อมกันได้:** แบ่งตาม container ใน Studio — **โซนใครโซนมัน ห้ามข้าม** เพราะ agent เขียนทับไฟล์กันได้โดยไม่มีตัวกัน (MCP ไม่ผ่าน script lock ของ Team Create)

**ทำไมไม่แบ่งเป็น "คนนึง script / คนนึง UI / คนนึงบท":** ทุกฟีเจอร์ต้องมีโค้ด คนถือ script จะกลายเป็นคอขวดคนเดียว ส่วนอีกสองคนรอ — และทุกคนมี agent เขียนโค้ดให้อยู่แล้ว **แบ่งเป็นฟีเจอร์แนวตั้งแทน: แต่ละคนถือฟีเจอร์ของตัวเองครบเส้น** (engine + UI + รูป + ส่วนแมพที่เกี่ยว + 1 deliverable)

---

## 1. สามสาย — แต่ละสายถือครบเส้น

### 🎥 สาย A — "ผลิตคลิป" (ระบบอัด/ตัด/อุปกรณ์)

| ชั้น | งาน |
|------|-----|
| Engine | `RecordService` (footageGB, โซนสุ่มย้ายจุด 120 วิ, bonus 10%, เต็ม=FULL), Tool 3 ชิ้น, **ผูก resolution → VidQ** (ตอนนี้ซื้อกล้องยังไม่มีผลกับคุณภาพคลิป!) |
| UI | HUD ทั้งชุด (progress bar 1M, delta popup, storage GB, hotbar, ปุ่ม setting), Edit app (slider footage + QTE บน timeline + ปุ่ม Edit more), Shop app (การ์ด 6 ระดับ 2 หมวด) |
| แมพ | `FilmSpot_*` ~8 จุด, เครื่อง PC เฟส 2/3 (จอ `Interact_pcMonitor` 4×2.6) |
| รูป | HUD 14 ชิ้น + Shop 12 ชิ้น |
| ส่ง | วิดีโอ gameplay 3–5 นาที |

**ไฟล์ที่แตะ:** `Services/RecordService`, `UI/HUD`, `UI/Apps/{EditQTE,Shop}`, `StarterPack`, `Workspace.FilmSpot_*`

📋 **spec เต็ม (อ่านก่อนเขียน ห้าม assume):**
- ระบบอัดคลิป + อุปกรณ์ 6 ระดับ + โซน + bonus + cooldown → **docs/02 §9.5** (ตัวเลขล็อกครบ)
- HUD ทุกชิ้น + Record UI → **docs/09 §1, §4** | Edit → **§5** | Shop การ์ด → **§10**
- ตัวเลข balance ทั้งหมด (`Config.Record`, `UpgradeCosts`, `ResolutionLadder`, `StorageLadderGB`) → `Shared.Config`
- ⚠️ resolution→VidQ **ยังไม่มีสูตร** — เสนอ user ก่อน implement (docs/09 §1 หมายเหตุ)

### 💼 สาย B — "ธุรกิจ & ทีมงาน"

| ชั้น | งาน |
|------|-----|
| Engine | `StaffService` (**design ตัวเลขเองก่อน** — 2 สาย: เพื่อนร่วมทาง = คุณภาพสูง/story, พนักงานจ้าง = ปริมาณ, เงินเดือนตัดรอบ 7 วัน), `state.history[day]` + `clip.views` (ฐานกราฟ+income/week), sponsor offer สุ่ม 5%/วัน เฟส 2-3 |
| UI | Manage app (จ้าง/ไล่), Calendar app (grid เดือน 7×5 + block 3 สี + กดเลือกย้าย + marker วันตัดรอบ), Feedback (กราฟ 7 วัน + list คลิปกดได้), Upload (2-pane + title 3 ช้อย) |
| แมพ | ห้องเช่า + props + `Interact_Bed/Kitchen/Exercise` |
| รูป | icon แอป 8 ชิ้น + wallpaper 3 ชิ้น |
| Content | `DMs` (พนักงาน/sponsor/คู่แข่ง), `ClipTitles` |
| ส่ง | สไลด์ PDF (Canva `DAHJLyI79DE`) |

**ไฟล์ที่แตะ:** `Services/{StaffService,CalendarService,MoneyService}`, `UI/Apps/{Manage,CalendarApp,Feedback,Upload,Bank}`, `Content/{DMs,ClipTitles}`

📋 **spec เต็ม (อ่านก่อนเขียน ห้าม assume):**
- Bank ⊖⊕ (ตัวเลข step/ผลใจล็อกแล้ว) → **docs/02 §9.7** | Calendar (block ยาว/ย้าย = engine เสร็จแล้ว) → **docs/09 §3** | Feedback กราฟ → **§7** | Upload → **§6**
- sponsor offer สุ่ม 5%/วัน เฟส 2-3, คลิป sponsor ไม่ได้ follower แต่เงิน ×2-4, block มี time unit (1 unit=1 ช่อง ไม่เกิน 3) → **docs/09 §3** (mechanic ยังไม่ implement — logic วางไว้ครึ่งเดียว)
- ✅ **`StaffService` = ทำเสร็จแล้ว 21 ก.ค.** (engine + Manage UI + เทส) — spec/ตัวเลขทั้งหมดอยู่ **docs/02 §9.8** แก้ตัวเลขที่ `Config.Staff` ที่เดียว

### 📖 สาย C — "เรื่องราว & ฉากจบ" — **บอส (รณกร)**

| ชั้น | งาน |
|------|-----|
| Content | บท NPC 10 บทสนทนา (เฟส 1: 2 / เฟส 2: 4 / เฟส 3: 4), Canon Events ทุก milestone + **event ทรยศ ~500K**, comments pool ~24 ใบ (⊖/◎/⊕ อย่างละ 8), **บทหลังทรยศ** ของเพื่อนคนแรก |
| Cutscene | Ending 6 อัน — **เต็ม 2 (Good1, Neutral2) / ย่อ 4** (จอเดียว + text 3-4 บรรทัด) |
| Engine | flag บทหลังทรยศใน `InteractBinder` (เล็ก ~1 ชม.) |
| แมพ | โมเดล NPC + `Interact_NPC_*`, `CutsceneCams` (Part มุมกล้อง) |
| ส่ง | วิดีโอแนะนำ 3 นาที + Word doc (ลิงก์เกม/description/ตั้งค่า public+ปิด copy) |

**ไฟล์ที่แตะ:** `Content/{Dialogue,CanonEvents,Comments,Endings}`, `UI/{DialogueUI,CutscenePlayer}`, `InteractBinder`, `Workspace.{NPC_*,CutsceneCams}`

📋 **spec เต็ม (อ่านก่อนเขียน ห้าม assume):**
- NPC 2/4/4 + arc เพื่อนร่วมทาง/ทรยศ 500K + ending 2 เกรด → **docs/02 §9.4** | comment ตามเกรด → **§9.6**
- format ไฟล์บท/canon/ending/comment + วิธีเลือกบทตามเฟส → **`docs/engines/`** (engine เสร็จหมด เหลือเติมข้อความ)
- **เนื้อเรื่องทั้งหมด = งาน user เขียน** agent มีหน้าที่จัด format ลงไฟล์ + เทส ไม่แต่งเรื่องเอง

---

## 1.2 งานที่เพิ่งเพิ่ม 26 ก.ค. (เคยไม่มีเจ้าของ — audit เจอ)

| งาน | สาย | รายละเอียด |
|------|-----|------------|
| **ระบบที่อยู่ + `Interact_Door`** | **B** | ปลดที่อยู่ตาม follower (10K/100K) กลับที่เก่าได้, ประตู teleport (Attribute `Target` + `MinFollower`) — docs/02 §9.9 |
| **Bad End ① ขั้น "โดนไล่ที่"** | **B** | ค้างเช่าครั้งที่ 1 = ล็อกที่อยู่คืน + ส่งกลับ Map_Phase1 / ครั้งที่ 2 ค่อยจบเกม |
| **ระบบ Tycoon เหยียบปุ่ม** | **B** | `Buy_<ชื่อ>` (Attribute Price) + `Item_<ชื่อ>` + จำลง save — convention docs/05 §3.5 |
| **หน้า Main Menu เต็มรูปแบบ** | **A** | ตามร่าง user: Title + ปุ่ม 4 อันชิดซ้าย + ภาพตัวละครนั่งคอมฝั่งขวา + หน้า Setting จริง (graphic/language/audio) |
| **ระบบเสียง** — ✅ engine เสร็จ 26 ก.ค. เหลือหาไฟล์เสียงมาวาง | **C** | คู่มือ `docs/engines/audio.md` |
| **ตั้งค่าเกมตอนส่ง** | **C** | เผยแพร่ Public, ปิด Allow Copying, ใส่ description ตามกติกา, เปิด Studio API access (ให้ save ทำงาน) — docs/03 |

---

## 1.5 ไฟล์กลาง — ห้ามแก้พร้อมกัน

`Shared.Config` · `Services.GameState` · `ServerScriptService.Main` · `Tests.RunTests` — ทั้งสามสายต้องเติมของตัวเองลงไฟล์พวกนี้ (ตัวเลข balance / field ใน state / register action / เทส)

**กติกา:** ประกาศในแชททีมก่อนแก้ → แก้ → commit+push ทันทีในนัดเดียว ห้ามค้างไว้ข้ามวัน ถ้าไม่แน่ใจให้บอสแก้ให้

---

## 3. คู่มือ engine — ย้ายไป `docs/engines/` แล้ว

| Engine | คู่มือ |
|--------|-------|
| 🗣️ Dialogue (บท NPC) | `docs/engines/dialogue.md` |
| 🎬 Cutscene (ending + มุมกล้อง) | `docs/engines/cutscene.md` |
| 🔊 Audio (เพลง/เสียงพูด/SFX) | `docs/engines/audio.md` |

---

## 5. กติกาใช้ agent พร้อมกัน (ทุกคน ทุก agent)

1. **แตะได้เฉพาะโซนตัวเอง** (ตาราง §1) — เจอบั๊กโซนคนอื่น บอกในแชททีม ห้ามแก้เอง ห้ามให้ agent "ช่วยแก้ให้"
2. **เริ่ม session ให้ agent อ่าน `AGENTS.md` ก่อนเสมอ** แล้ว pull สภาพจริงจาก Studio (วิธีอยู่ docs/08)
3. **จบก้อนงาน commit + push ทันที** — โซนไม่ทับกัน = ไม่มี merge conflict / ใครไม่ push งานหายเองไม่มีใครช่วยได้
4. **แก้ format/โครงสร้างไฟล์ = งานฝั่ง engine** — เติมข้อความในกรอบเดิมได้เสรี อยากได้ field ใหม่ให้บอกบอส
5. **Play test ทีละคน** — Team Create แชร์ world เดียว นัดกันในแชทก่อนกด Play
6. Team Create **auto-save ตลอด ลบของคนอื่น = หายจริง** — ระวัง Ctrl+Z ข้ามโซน

## 6. Setup เครื่องใหม่ (เพื่อนทำครั้งเดียว)

1. รับสิทธิ์: บอสเพิ่มใน Creator Hub → Configure → Collaborators (Edit) + GitHub collaborator
2. `git clone <repo>` → เปิดอ่าน `AGENTS.md`
3. Studio: เปิด place จาก Shared with Me
4. (ถ้าจะใช้ agent คุม Studio) ติดตั้ง MCP plugin ใน Studio → ต่อ agent ตาม docs/08 — `tools/mcp_driver.py` หา path Studio อัตโนมัติแล้ว ไม่ต้องแก้อะไร
