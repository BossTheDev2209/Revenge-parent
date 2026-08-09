# CLAUDE.md — Getting 1M Follower to Prove Parent Wrong

ไฟล์นี้ Claude Code โหลดอัตโนมัติทุก session. อ่านให้จบก่อนแตะโค้ด

## Project

- **เกม:** Getting 1M Follower to Prove Parent Wrong — story-driven idle tycoon, singleplayer
- **การแข่ง:** MUICT-AST Tech Competition 2569 / "Thailand Simulation Gen Z on Roblox" (Mahidol ICT)
- **ทีม:** หอยทากเทอร์โบ28 — รณกร ขันสำรอง, วรกร วิรามวิทวัส, ฉันทัช อัศวชนานนท์
- **Target player:** Gen Z ไทย 13–18
- **Platform:** Roblox Studio, R6 classic
- **จุดขาย:** ความ relatable แบบไทยจริง (แรงกดดันพ่อแม่, ชีวิตห้องเช่า, content creator grind) ไม่ใช่ aesthetic ไทยผิวเผิน

## Hard dates (Asia/Bangkok)

| วันที่ | เรื่อง |
|--------|--------|
| 12 ส.ค. 2569 18:00 | ส่ง deliverables ทั้งหมด — **ห้ามแก้เกมหลังจากนี้ กรรมการเช็ค Last Updated** |
| 15 ส.ค. 2569 | Pitching ที่ MUICT — slot 19/20, block 14:25–15:25, ลงทะเบียน 08:45 |

Format การนำเสนอ: พูด 10 นาที + Q&A 5 นาที

## Deliverables (ครบทุกข้อ = 20pt ความสมบูรณ์)

1. Roblox game link — Public, ปิด copy, ใส่ description ตามที่กำหนด (ส่งในไฟล์ Word/doc)
2. ไฟล์ `.rbxl`
3. วิดีโอแนะนำ ~3 นาที
4. วิดีโอ gameplay 3–5 นาที
5. สไลด์ PDF — **lock หลังส่ง** (source: Canva design ID `DAHJLyI79DE`)
6. เอกสารสนับสนุน (optional)

## Scoring (100pt)

ความสมบูรณ์ของข้อเสนอ 20 | ความเป็นไทย 20 | ตรรกะระบบ 20 | ออกแบบตัวละคร/ฉาก 20 | Feasibility 20

→ implication: **ตรรกะระบบ 20pt ผูกกับสูตรใน `docs/02-game-design-locked.md` โดยตรง** ถ้าโค้ดกับเอกสารไม่ตรงกัน เสียคะแนนซ้อนสองหมวด (ตรรกะ + ความสมบูรณ์)

## Source of truth

`docs/02-game-design-locked.md` คือ single source of truth ของทุกระบบ/ตัวเลข
ถ้าโน้ตอื่น สไลด์ หรือ memory ขัดกับไฟล์นั้น → ยึดไฟล์นั้น แล้ว flag ความขัดแย้งทันที ห้ามแก้เงียบๆ

## Locked systems (สรุป — รายละเอียดเต็มอยู่ใน design doc)

- **Phase gate** ตัดจาก follower ปัจจุบันเท่านั้น ไม่ผูกจำนวนคลิป: เฟส1 0→10K, เฟส2 10K→100K, เฟส3 100K→1M
- **Follower/คลิป** = base สุ่มตามเฟส × VidQ multiplier × mental multiplier, มีโอกาส 12% viral ×4–8
- **VidQ tier** = C/B/A/S เท่านั้น (ห้ามใช้ bad/normal/good/awesome)
- **Mental bar** 3 โซน, cap โบนัสที่ ×1.25, 0% = Bad End ②
- **Economy** เงิน = follower ที่ได้ × rate ของเฟส (0.8 / 1.2 / 1.5), หักค่าใช้จ่ายรอบ 7 วันในเกม
  → **เพดานเงินทั้งเกม ≈ 1.47 ล้าน** (หักรายจ่ายเหลือ ~1.3 ล้าน) — ราคา upgrade ทุกสายต้องอยู่ในกรอบนี้
- **Upgrade** 3 สาย (กล้อง / ที่เก็บ / คอมพิวเตอร์) สายละ **15 ระดับ** — ระดับ 1-6 ล็อก 21 ก.ค. ห้ามขยับ
  ระดับ 7-15 + สายคอมพิวเตอร์ทั้งสาย = ⏳ **รอ user lock** (สาย pc ซื้อได้แต่ยัง unwired จงใจ)
- **Endings** 6 ending, Bad End ① (โดนไล่ออกจากห้อง) และ ② (หมดใจ) เป็น optional challenge ไม่ใช่ fail state บังคับ
- **NPC dialogue** = typewriter ทางเดียวแบบ Undertale ไม่มี branching; input ⊕/◎/⊖ มาจาก comment เท่านั้น
- **Roblox compliance** — ตัดเนื้อหา fatal outcome ออกหมด reframe เป็นความล้มเหลวทางสังคม/อาชีพ

## Content ที่ยังไม่มี (blocking การส่ง)

- [ ] choice text จริง
- [ ] NPC dialogue script
- [ ] Canon Event script
- [ ] ending cutscene storyboard ×6
- [ ] ~~Thai mini-game mechanics~~ → **ตัดถาวรแล้ว** ตาม design doc §9 แทนด้วย Activity system (ออกกำลังกาย/พักผ่อน/กินข้าว → cutscene 5–10 วิ + ฟื้น mental) ไม่ต้องออกแบบ mini-game เพิ่ม

## Scope discipline

ตัดไป backlog แล้ว ห้ามดึงกลับเว้นแต่ timeline เหลือจริง: minigame debate กับ NPC, กลไกโทรหาพ่อแม่, map เฟส 3 แบบเต็ม

ก่อนรับ feature ใหม่ ให้ตอบให้ได้ก่อนว่ากินเวลากี่ชั่วโมง และเบียดงานไหนใน 5 อย่างข้างบน

## Build conventions

`docs/05-build-conventions.md` — กฎตั้งชื่อ instance, `Interact_` parts, NPC, สิ่งที่ห้าม
**agent ต้องอ่านก่อนแตะ Studio ผ่าน MCP** ทีมสร้างฉาก/NPC คู่ขนานได้ ไม่ต้องรอ architecture

## Working rules สำหรับ agent

1. **Superpowers** — `/superpowers-framework` (สำเนาอยู่ที่ `.claude/skills/superpowers-framework/SKILL.md`) เริ่มที่ brainstorm → plan ใน `plans/` → TDD → review ห้ามข้ามขั้น
2. **ตัวเลขทุกตัว** ที่แตะ ต้อง re-derive จาก design doc ไม่ใช่จากความจำ
3. **ตอบตรง** ไม่ต้องเยินยอ เห็นแผนพัง บอกพร้อมทางออก
4. ภาษา: ไทยผสมอังกฤษตามศัพท์เทคนิค
5. แก้เฉพาะสิ่งที่ถูกสั่ง เจอ error ที่อื่น → flag ไว้ ไม่แก้เอง
6. อย่าเชื่อว่าไฟล์ที่ user อ้างถึงมีอยู่จริง เช็คก่อน
7. **Roblox Studio MCP (official)** — ห้ามลบ/แก้ instance เดิมโดยไม่ถาม, สร้างใหม่/อ่านได้เลย
   ทุก Script ที่เขียนเข้า Studio ต้อง mirror ลง `src/` แล้ว commit ไม่งั้นย้อนกลับไม่ได้
8. **user ทำผิด convention → แก้ให้ตรงระบบเดิม ห้ามสร้างระบบใหม่มารองรับของที่ผิด**
   เช่น user ตั้งชื่อ instance ผิด / วางของผิดที่ / โครงไม่ตรงสเปก → **แก้ชื่อ/ย้าย/จัดของ user ให้เข้าระบบเดิม**
   ไม่ใช่เขียน resolver/alias/fallback ใหม่มาเดาของที่ผิด
   *(ตัวอย่างจริง: MainMenu model เคยใส่ระบบเดาชื่อ part → ถอดออก ใช้ชื่อจริง · NPC ชื่อ Part ซ้ำ → เปลี่ยนชื่อให้ unique ไม่ทำ resolver)*
9. **ก่อนสร้างระบบใหม่แก้ปัญหา ลองทางที่ง่ายกว่าก่อนเสมอ** — คลิป YouTube สอน, script แจกฟรี, Toolbox, plugin, built-in ของ Roblox
   สร้างระบบใหม่เองเป็นทางเลือกสุดท้าย · เจอทางง่ายแล้วเสนอ user ก่อนลงมือ
   *(⚠️ Toolbox/free script เชื่อไม่ได้ 100% — เช็ค/ล้าง script แถม backdoor ก่อนใช้เสมอ)*
   **อย่ากลัว Toolbox — ถ้าตรวจได้ก็ใช้** (ponytail): ทางที่ง่ายกว่าจาก Toolbox/asset สำเร็จรูป = สแกน backdoor ก่อน (require assetId / HttpGet / loadstring / getfenv) แล้ว **ใช้เลย** ไม่ต้องเขียนเองแข่ง
   **user เอา asset จาก Toolbox มาให้/ชี้ให้ใช้ = ใช้ของนั้น** (configure ให้เข้าระบบเรา · ตัด logic ที่ไม่เกี่ยว) ห้ามเมินแล้วสร้างเวอร์ชันตัวเองขึ้นมาใหม่
   *(ตัวอย่างจริง 8 ส.ค.: user เอาแผง Settings จาก Toolbox "Cafe Settings System" มาให้ → agent ดันสร้างแผงเองก่อน · ที่ถูก = สแกน (ปลอดภัย) แล้วเอาแผงนั้นมา rewire เข้า AudioService/Lighting/SetSetting)*
10. **พฤติกรรมใน Studio ไม่ตรงกับโค้ด → เช็ค Rojo sync ก่อน ห้ามแก้ logic** — ยืนยันว่าโค้ดเข้า Studio จริงก่อน (เทียบ `.Source` ที่ sync กับไฟล์ใน `src/`) แล้วค่อย debug logic
    Rojo plugin หลุดทุกครั้งที่ restart Studio → ต้องกด Connect ใหม่ · edit ที่ไม่ sync = กำลัง debug โค้ดคนละตัวกับที่รันอยู่ (เสียเวลาเปล่า)
    *(ตัวอย่างจริง 1 ส.ค.: prompt กดไม่ทำงาน → เกือบ rewrite bind logic แต่จริงๆ InteractBinder fix ไม่ sync เข้า Studio เพราะ plugin หลุดหลัง restart)*
11. **ติดปัญหาที่จะเสียเวลานาน → ค้น Roblox Dev Forum ก่อนลุยเดาเอง** — ปัญหา Roblox เฉพาะทาง (property plugin-only, พฤติกรรม StreamingEnabled, sandbox/capability, quirk ของ engine) มักมีคนเจอ+เฉลยแล้วใน `devforum.roblox.com` · เจอ thread ที่ตรง = ประหยัดชั่วโมง อย่าเพิ่ง rewrite/สร้างระบบใหม่จากการเดา
    ค้นก่อนเมื่อ: debug วนเกิน ~2 รอบไม่คืบ, เจอ error/behavior ที่ไม่เข้าใจสาเหตุ, หรือกำลังจะเขียน workaround ใหญ่ · เอาคำตอบมา cross-check กับของจริงใน Studio ก่อนใช้เสมอ (โพสต์ใน forum อาจเก่า/ผิด/คนละเวอร์ชัน)
12. **⚠️⚠️ Team Create + git ร่วมกัน — กันงานทับหาย (tragedy 9 ส.ค.: full-sync ทับงาน Phase/interaction/บทหมวย ที่ยังไม่ commit หายเกลี้ยง)**
    - **ห้าม full-sync (`gen_sync` ทั้งโปรเจกต์ / put ทุกไฟล์) เด็ดขาด** — มัน destroy+recreate สคริปต์ทุกไฟล์จาก git → ทับงานที่อีกคนแก้ใน Studio แต่ยังไม่ commit หายหมด · **sync เฉพาะไฟล์ที่ตัวเองแก้** (surgical single-file — เขียน `.Source` ตรงตัว หรือให้ Rojo sync เฉพาะไฟล์ที่เปลี่ยน)
    - **commit git ทันทีทุกครั้งที่แก้เสร็จ** — งานที่อยู่ Studio อย่างเดียว = เสี่ยงโดน sync ของอีกคนทับ · **git คือตัวรอดเดียว** (บทหมวยหายเพราะ author ใน Studio ไม่เคย commit)
    - **`git pull --rebase` ก่อน `git push` ทุกครั้ง** (กัน history ชนกัน)
    - **แบ่ง ownership ไฟล์** ช่วงแก้พร้อมกัน — ตกลงใครถือไฟล์ไหน อย่าแก้ไฟล์เดียวกันพร้อมกัน · **ก่อนแตะ Studio: pull git ล่าสุด + เช็คว่าอีกคนไม่ได้ถือไฟล์นั้น**
    - **ของที่อยู่ใน `.rbxl` ไม่ใช่ `src/` ต้อง save/publish place เอง** (git ไม่ track): property ของ service (เช่น `ProximityPromptService.Enabled`), `Model.LevelOfDetail`, GUI instance ใน StarterGui, บทที่ author ใน Studio → **Ctrl+S + publish** ไม่งั้นหาย/revert · ของพวกนี้ mirror ลง `src/` (หรือ `src/studio-only/`) + commit ด้วยถ้าทำได้
13. **งานที่ user คลิกไม่กี่ทีแล้วเร็ว/ชัวร์กว่า agent ดิ้น → commit ก่อน แล้วบอก user ทำเอง อย่า automate** (ประหยัดเวลา+cost)
    ถ้าทางเดียวที่ agent จะทำเองคือ workaround ที่เปราะ/ยาว (surgical write `.Source` ทั้งไฟล์ใหญ่, คลิก UI ผ่าน MCP, เดา state) แต่ user ทำมือได้ใน **1-2 คลิก** → หยุด บอก user ทำ
    - **Connect Rojo** (plugin หลุดทุก restart) — คลิกเดียวใน plugin · agent write `.Source` เองทั้งไฟล์ = เสี่ยงพัง+เปลือง token
    - **playtest / กด Play + ดูผลด้วยตา** — user เห็นไวกว่า agent สั่ง execute_luau ทีละอัน
    - **Ctrl+S / publish place** — ของใน `.rbxl` (ดูข้อ 12)
    ยกเว้น: งานที่ต้องทำซ้ำหลายรอบ/หลายไฟล์ หรือ user ไม่อยู่ตอบ → agent ทำเอง · **หลัก: งาน one-shot คลิกเดียว = โยนให้ user, งานวน/เยอะ = agent ทำ**
    *(ตัวอย่างจริง 9 ส.ค.: Rojo หลุด 3 รอบ agent เกือบ direct-write ScreenTransition+Main.client 590 บรรทัดเข้า Studio — ที่ถูก = push git แล้วบอก user กด Connect Rojo คลิกเดียวจบ)*

## Layout

```
CLAUDE.md                  ← นี่
docs/                      ← design doc + กติกา + timeline + deliverables
plans/                     ← superpowers plan ต่อ feature
src/server|client|shared/  ← Luau (mirror ของ Studio — ไม่มี Rojo, agent เขียนตามหลังทุกครั้งที่แก้ Studio)
tests/                     ← TestEZ spec
assets/reference/          ← สไลด์เก่า, poster, กำหนดการทางการ (read-only)
```
