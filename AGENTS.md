# AGENTS.md — คู่มือ agent ทุกตัวในโปรเจกต์นี้ (Claude Code / Codex / Cursor / อื่นๆ)

อ่านไฟล์นี้ก่อนทำอะไรทั้งนั้น แล้วอ่านต่อ: `CLAUDE.md` (กติกาหลักทั้งหมด — ใช้กับ agent ทุกตัว ไม่ใช่แค่ Claude) → `docs/11-workflow-rules.md` (กฎ Studio + GitHub — **บังคับ**) → `docs/10-team-roles.md` (โซนของคนที่สั่งงานอยู่) → `docs/08-studio-sync-handoff.md` (วิธีคุยกับ Roblox Studio ผ่าน MCP)

## กฎเหล็ก

1. **ถามผู้ใช้ก่อนเริ่มว่าเขาถือโซนไหน** (Cutscene / Dialogue / UI+Engine — ตาราง docs/10 §1) แล้ว**ทำงานเฉพาะในโซนนั้น** งานนอกโซน = ตอบว่า "งานนี้อยู่โซนของ X" แล้วหยุด
2. **Studio = source of truth** — script/content ของจริงอยู่ใน Roblox Studio, repo นี้คือ mirror/backup เริ่ม session ให้ pull สภาพจริงจาก Studio ก่อน (docs/08 ⭐) แก้ใน Studio เสร็จต้อง mirror ลง `src/` แล้ว commit push ทุกครั้ง
3. **ตัวเลข balance ทุกตัว** ต้อง re-derive จาก `docs/02-game-design-locked.md` เท่านั้น ห้ามใช้จากความจำ ขัดกัน = flag ทันที ห้ามแก้เงียบ
4. **ห้ามลบ/แก้ instance ใน Studio ที่ตัวเองไม่ได้สร้าง** โดยไม่ถามก่อน — ฉาก/NPC คืองานปั้นมือหลายวัน
5. เทสอยู่ `tests/RunTests.luau` (รันได้ทั้ง lune และใน Studio) — แตะโค้ด engine แล้วต้องรันให้เขียวก่อน commit
6. **ห้ามแก้อะไรหลัง 12 ส.ค. 2569 18:00** (กรรมการเช็ค Last Updated)

## แผนที่โปรเจกต์

| อยากรู้เรื่อง | อ่าน |
|----------------|------|
| กติกาแข่ง + กำหนดส่ง | `docs/01`, `docs/03`, `docs/04` |
| **PDF ต้นฉบับ ถอดความละเอียดหน้าต่อหน้า** | `docs/12-pdf-source-of-truth.md` ← อ่านก่อนถ้าสงสัยว่า feature จริงคืออะไร |
| ระบบเกมทุกตัวเลข (ล็อค) | `docs/02-game-design-locked.md` |
| ตั้งชื่อ instance ใน Studio | `docs/05-build-conventions.md` |
| architecture / แก้ X ไปไฟล์ไหน | `docs/06-architecture.md` |
| คุยกับ Studio ผ่าน MCP + gotchas | `docs/08-studio-sync-handoff.md` |
| gap UI แต่ละแอป vs ร่าง PDF | `docs/09-app-ui-spec.md` |
| โซนหน้าที่ 3 คน + คู่มือเขียนบท/วางกล้อง | `docs/10-team-roles.md` |
| กฎ Studio + GitHub (บังคับอ่าน) | `docs/11-workflow-rules.md` |
