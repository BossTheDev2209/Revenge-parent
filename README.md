# Getting 1M Follower to Prove Parent Wrong

Roblox game — MUICT-AST Tech Competition 2569 (Thailand Simulation Gen Z on Roblox)
ทีม หอยทากเทอร์โบ28

## repo นี้คืออะไร

**สำเนาสำรอง + doc ให้ agent อ่านเท่านั้น — ไม่ใช่ที่ทำงาน**
ของจริงทุกอย่างอยู่ใน **Roblox Studio** (Team Create) ทั้งโค้ด บท ตัวเลข รูป แมพ
โค้ดใน `src/` คือ mirror ที่ agent เขียนตามหลังทุกครั้งที่แก้ Studio — ไว้กันงานหายและให้ agent อ่าน ไม่มี Rojo ไม่มี sync อัตโนมัติ

## เริ่มยังไง (เครื่องใหม่)

```bash
git clone https://github.com/BossTheDev2209/Revenge-parent.git
cd Revenge-parent
```

เปิด agent (Claude Code / อื่นๆ) ในโฟลเดอร์นี้ แล้วบอกมันว่า:
```
อ่าน AGENTS.md, docs/11-workflow-rules.md, docs/10-team-roles.md ก่อน — ฉันคือสาย A/B/C
```

## แผนที่

| ที่ | อะไร |
|-----|------|
| `AGENTS.md` | agent ทุกตัวอ่านก่อนเริ่ม (Codex/Cursor/Gemini ด้วย) |
| `CLAUDE.md` | context ที่ Claude Code โหลดอัตโนมัติทุก session |
| `docs/02-game-design-locked.md` | **single source of truth** ของทุกระบบ/ตัวเลข |
| `docs/03-deliverables.md` | checklist ส่งงาน 12 ส.ค. |
| `docs/05-build-conventions.md` | กฎตั้งชื่อ instance ใน Studio |
| `docs/08-studio-sync-handoff.md` | วิธีให้ agent คุม Studio ผ่าน MCP |
| `docs/09-app-ui-spec.md` | สเปก UI แต่ละแอปเทียบร่าง PDF |
| `docs/10-team-roles.md` | แบ่งงาน 3 สาย + คู่มือเขียนบท/วางกล้อง |
| `docs/11-workflow-rules.md` | **กฎ Studio + GitHub — บังคับอ่าน** |
| `assets/reference/` | สไลด์เก่า/poster/กำหนดการ — read-only |
