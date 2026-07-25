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
- 🔴 **`StaffService` = BLOCKED ยังไม่มี spec — ห้ามเขียนโค้ดจนกว่า design session เสร็จ** (docs/02 §9.8 ยังว่าง) ถ้า agent เจอ task นี้: หยุด บอก user ให้ทำ design กับ Claude ก่อน **ห้ามเดาตัวเลข speed/quality/salary เอง**

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
- format ไฟล์บท/canon/ending/comment + วิธีเลือกบทตามเฟส → **§3, §4 ด้านล่าง** (engine เสร็จหมด เหลือเติมข้อความ)
- **เนื้อเรื่องทั้งหมด = งาน user เขียน** agent มีหน้าที่จัด format ลงไฟล์ + เทส ไม่แต่งเรื่องเอง

---

## 1.5 ไฟล์กลาง — ห้ามแก้พร้อมกัน

`Shared.Config` · `Services.GameState` · `ServerScriptService.Main` · `Tests.RunTests` — ทั้งสามสายต้องเติมของตัวเองลงไฟล์พวกนี้ (ตัวเลข balance / field ใน state / register action / เทส)

**กติกา:** ประกาศในแชททีมก่อนแก้ → แก้ → commit+push ทันทีในนัดเดียว ห้ามค้างไว้ข้ามวัน ถ้าไม่แน่ใจให้บอสแก้ให้

---

## 3. คู่มือ Cutscene (สาย C)

Cutscene = list ของ step เล่นตามลำดับ อยู่ใน `ReplicatedStorage.Shared.Content.Endings/<ชื่อ ending>` (ModuleScript 6 ไฟล์: Bad1 Bad2 Bad3 Neutral1 Neutral2 Good1)

**step มี 3 ชนิด:**

```lua
return {
	{ type = "camera", cam = "Cam_Bad1_01" },        -- ตัดกล้องไปที่ Part ชื่อนี้
	{ type = "text", text = "[slow]ข้อความขึ้นจอ" }, -- ขึ้นข้อความ (อยู่จนข้อความถัดไป)
	{ type = "wait", t = 2 },                         -- หน่วง 2 วินาที
	{ type = "camera", cam = "Cam_Bad1_02" },
	{ type = "text", text = "ประโยคต่อไป" },
}
```

**วิธีวางมุมกล้อง — ไม่ต้องพิมพ์พิกัดเลย:**
1. สร้าง Folder ชื่อ `CutsceneCams` ใน Workspace (ครั้งเดียว)
2. สร้าง Part เล็กๆ ตั้งชื่อ `Cam_<ending>_<เลข>` เช่น `Cam_Bad1_01` — ตั้ง Anchored ✓, Transparency 1, CanCollide ✗
3. **หันหน้า Part (แกนลูกศร Front ตอนกด F ดู) ไปทางที่อยากให้กล้องมอง** — ตำแหน่ง Part = ตำแหน่งกล้อง
4. เขียน step `{ type = "camera", cam = "ชื่อPart" }` ในไฟล์ ending

ทริค: กดมุมมองในเกมให้สวยก่อน แล้วสร้าง Part ตรงตำแหน่งกล้องปัจจุบันก็ได้

**Part กล้องที่บทเรียกใช้อยู่ตอนนี้ (ต้องมีครบก่อนส่ง — ไม่มี = warn แล้วกล้องไม่ขยับ):**

| Part | ใช้ใน | ฉาก |
|------|-------|-----|
| `Cam_Good1_01` | Good1 | ห้องเช่าเดิม ว่างเปล่า |
| `Cam_Good1_02` | Good1 | สตูดิโอใหม่ ปาล์มนั่งตัดคลิป |
| `Cam_Good1_03` | Good1 | หน้าประตูสตูดิโอ (เจมาขอโทษ) |
| `Cam_Good1_04` | Good1 | หน้าบ้านพ่อแม่ |
| `Cam_Good1_05` | Good1 | โต๊ะกินข้าวที่บ้าน |
| `Cam_Neutral2_01` | Neutral2 | จอคอม เลข 1,000,000 |
| `Cam_Neutral2_02` | Neutral2 | สตูดิโอกลางดึก ไม่มีใคร |
| `Cam_Neutral2_03` | Neutral2 | มือถือ หน้าแชทครอบครัว |
| `Cam_Neutral2_04` | Neutral2 | หน้าต่าง แสงเช้า |
| `Cam_Neutral1_01` | Neutral1 | โต๊ะทำงานตอนกลางวัน |
| `Cam_BadShared_01` | Bad1/2/3 | ห้องเช่า มุมหม่น (ใช้ร่วม 3 ending) |

**เช็คงานตัวเอง:** ผิด format เกมไม่พัง — จะขึ้น warn ใน Output ว่า step ไหนพัง / ถ้าพิมพ์ชื่อ Part ผิด จะ warn "ไม่เจอ Part กล้อง"

---

## 4. คู่มือ Dialogue (สาย C)

ทุกไฟล์อยู่ `ReplicatedStorage.Shared.Content` — แก้ **เฉพาะข้อความในเครื่องหมายคำพูด** ห้ามลบ comma/วงเล็บ

**บท NPC** (`Content.Dialogue/Mom, Dad, Friend1, Friend2, CC1, Hater`):
```lua
return {
	"แม่: กลับมาทำไม... [slow]ไม่มีเงินใช่ไหมล่ะ",  -- 1 บรรทัด = 1 กล่องข้อความ
	"แม่: [fast]บอกกี่ครั้งแล้ว!",                    -- tag คุมความเร็ว: [slow] [fast] [normal]
}
```

**DM มีช้อย** (`Content.DMs`) — เลือกได้แต่ NPC ตอบเหมือนเดิมทุกช้อย (ตาม design §6):
```lua
{ from = "Sponsor", exchanges = {
	{ npc = "NPC ทัก", choices = { "ช้อย 1", "ช้อย 2", "ช้อย 3" }, reply = "NPC ตอบ" },
	{ npc = "คุยต่อ...", choices = { "ก", "ข", "ค" }, reply = "..." },
} },
```

**Comment + ช้อยตอบ** (`Content.Comments`): แต่ละ comment มี replies 3 อัน tag `pos/neu/neg` — tag มีผลต่อ ending จริง ห้ามสลับมั่ว

**Canon Event** (`Content.CanonEvents`): บทตอน follower ถึง milestone — format เดียวกับบท NPC

**เช็คงานตัวเอง:** บอกบอสให้ agent รันเทส — format พังเทสจะฟ้องทันทีว่าไฟล์ไหนบรรทัดไหน

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
