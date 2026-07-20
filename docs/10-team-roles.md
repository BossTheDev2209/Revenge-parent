# 10 — แบ่งหน้าที่ทีม + กติกาใช้ agent พร้อมกัน

**ใครต้องอ่าน:** ทั้ง 3 คน อ่านให้จบก่อนเปิด Studio / เปิด agent
**หลักการเดียวที่ทำให้ 3 agent ทำงานพร้อมกันได้:** แบ่งตาม container ใน Studio — **โซนใครโซนมัน ห้ามข้าม** เพราะ agent เขียนทับไฟล์กันได้โดยไม่มีตัวกัน (MCP ไม่ผ่าน script lock ของ Team Create)

---

## 1. หน้าที่หลัก 3 คน

| หน้าที่ | คนทำ | โซน Studio ที่แตะได้ | โซน repo |
|---------|------|---------------------|----------|
| **Cutscene** — วางมุมกล้อง + storyboard ending ×6 | เพื่อน 1 | `Workspace.CutsceneCams` + `ReplicatedStorage.Shared.Content.Endings` | `src/shared/Content/Endings/` |
| **Dialogue** — เขียนบท NPC + DM + comment | เพื่อน 2 | `ReplicatedStorage.Shared.Content` (ยกเว้น Endings) | `src/shared/Content/` |
| **UI + Engine** — โค้ดทั้งหมด สั่งผ่าน agent | บอส (รณกร) | `ServerScriptService`, `StarterPlayerScripts`, `Shared/Config`, `Formulas`, `UIAssets`, `Remotes` | `src/`, `tests/`, `docs/` |

**บท NPC = ทางเดียว ไม่มี choice** (design doc §7 ล็อคแล้ว) — choice มีที่เดียว: DM ในแอป Message (เลือกได้แต่ NPC ตอบเหมือนเดิม) กับตอบ comment ⊕◎⊖

---

## 2. งานเหลือที่ยังไม่มีเจ้าของ (pool — หยิบแบ่งกันเอง)

- [ ] แมพห้องเช่า + props เฟส 1-2 (ตั้งชื่อตาม docs/05 §2)
- [ ] วาง Part `Interact_NPC_Mom`, `Interact_NPC_01..05` (6 จุด — **คอขวด** ไม่มี = คุย NPC ไม่ได้)
- [ ] โมเดล NPC 6 ตัว (R6, Anchored ยืนเฉยๆ พอ)
- [ ] วาง `FilmSpot_*` ~6-10 จุด (ระบบอัดคลิป — รอ engine ก่อนก็ได้)
- [ ] Tool 3 ชิ้น: `Tool_Camera` / `Tool_Phone` / `Tool_Selfie` (รอ engine)
- [ ] วาดรูป UI 14+ ชิ้น (list เต็มถาม agent — "list HUD GUI ที่ต้องวาด")
- [ ] เครื่อง PC เฟส 2 / เฟส 3 (จอ `Interact_pcMonitor` ขนาด 4×2.6 เท่าเครื่องเทส)

---

## 3. คู่มือ Cutscene (เพื่อน 1)

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

**เช็คงานตัวเอง:** ผิด format เกมไม่พัง — จะขึ้น warn ใน Output ว่า step ไหนพัง / ถ้าพิมพ์ชื่อ Part ผิด จะ warn "ไม่เจอ Part กล้อง"

---

## 4. คู่มือ Dialogue (เพื่อน 2)

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
