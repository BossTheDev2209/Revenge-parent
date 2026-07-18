# Getting 1M Follower to Prove Parent Wrong

Roblox game — MUICT-AST Tech Competition 2569 (Thailand Simulation Gen Z on Roblox)
ทีม หอยทากเทอร์โบ28

## เริ่มยังไง

```bash
cd getting-1m-follower
git init && git add -A && git commit -m "init: project context + scaffold"
claude
```

ใน Claude Code:
```
/superpowers-framework
```
แล้วสั่งงานได้เลย — `CLAUDE.md` โหลดอัตโนมัติ ไม่ต้อง paste context ซ้ำ

## Rojo (ถ้าจะ sync โค้ดเข้า Studio)

```bash
aftman install          # หรือ: cargo install rojo
rojo serve default.project.json
```
เปิด Studio → Rojo plugin → Connect

ถ้าทีมยังทำงานใน Studio ตรงๆ ทั้งหมด: repo นี้ยังใช้เป็น context + plan + design doc ได้ปกติ
โค้ดใน `src/` จะเป็นแค่ reference ที่ copy-paste เข้า Studio เอา

## แผนที่

| ที่ | อะไร |
|-----|------|
| `CLAUDE.md` | context ที่ agent อ่านทุก session |
| `docs/02-game-design-locked.md` | **single source of truth** ของทุกระบบ/ตัวเลข |
| `docs/03-deliverables.md` | checklist ส่งงาน 12 ส.ค. |
| `docs/04-timeline.md` | แผนรายสัปดาห์ + สถานะจริง |
| `plans/` | superpowers plan ต่อ feature |
| `assets/reference/` | สไลด์เก่า/poster/กำหนดการ — read-only |
