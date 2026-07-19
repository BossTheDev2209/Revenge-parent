# 08 — Studio Sync Handoff (สำหรับ agent ทุกตัวที่มาทำต่อ)

**เขียนเมื่อ:** 19 ก.ค. 2569 | **สถานะ:** รอ Studio MCP ต่อ — งานฝั่ง repo เสร็จแล้ว รอยกเข้า Studio
**อ่านก่อน:** `CLAUDE.md` → `docs/02` (ตัวเลข) → `docs/06` (โครง Studio) → ไฟล์นี้ (งานที่ค้าง)

---

## 1. สภาพปัจจุบัน (ณ commit `77b0f54`)

| ของ | ที่อยู่ | สถานะ |
|-----|---------|-------|
| Config ตัวเลขทั้งเกม | `src/shared/Config.luau` | ✅ ครบ ตรง design doc — ไฟล์เดียว ไม่แตก 7 ไฟล์ (ตัดสินใจแล้ว: ctrl+F ง่ายกว่าสำหรับทีม) |
| Formulas 7 functions | `src/shared/Formulas.luau` | ✅ ผ่านเทส 46 ข้อ |
| เทส | `tests/RunTests.luau` | ✅ dual-mode: lune local + Studio Script |
| ใน Studio | — | ❌ **ยังไม่มีอะไรเลย — นี่คืองานถัดไป** |

Test runner local: `lune` binary อยู่ scratchpad (หายได้ — โหลดใหม่: GitHub lune-org/lune release `windows-x86_64.zip` แตก zip รัน `lune.exe run tests/RunTests.luau`)

**หมายเหตุ docs/06:** เขียนไว้ว่า Config แยก 7 ไฟล์ — ความจริงใช้ไฟล์เดียว `Config.luau` (reuse ของที่มีอยู่ก่อน) โครงส่วนอื่นตาม docs/06 ปกติ

---

## 2. เงื่อนไขก่อนเริ่ม: Studio MCP ต้องต่ออยู่

Session 19 ก.ค. ไม่มี Studio MCP → ทำไม่ได้ ถ้าเซสชันของคุณ search tool แล้วไม่เจอ (`ToolSearch "roblox studio"`) แปลว่ายังไม่ต่อ ให้บอก user ว่า:

1. เปิด Roblox Studio + เปิด place ของโปรเจกต์
2. ติดตั้ง/เปิดปลั๊กอิน official Roblox Studio MCP (github.com/Roblox/studio-rust-mcp-server) แล้วลงทะเบียนกับ Claude (`claude mcp` ใน session interactive)
3. เปิดเซสชันใหม่

**ห้าม** พยายามเขียน script เข้า Studio ผ่าน UI automation (Windows-MCP/computer-use) — เสี่ยงพังของที่ทีมปั้นมือ

---

## 3. งานที่ต้องทำผ่าน Studio MCP (ตามลำดับ ห้ามสลับ)

กฎเหล็กระหว่างทำ (จาก `CLAUDE.md` + `docs/05 §6`):
- **ห้ามลบ/แก้ instance ที่มีอยู่แล้ว** โดยไม่ถาม user — ของทีมปั้นมือ
- สร้างใหม่/อ่าน = ทำได้เลย
- ถ้าเจอ instance ชื่อชนกับที่จะสร้าง → หยุด ถาม user

### 3.1 สร้าง skeleton (ตาม docs/06 §1)

```
ReplicatedStorage
└── Shared (Folder)
    └── Remotes (Folder)
        ├── Action (RemoteEvent)
        └── StateChanged (RemoteEvent)
ServerScriptService
├── Services (Folder)
└── Tests (Folder)
```

(`Main`, `StarterPlayerScripts` ยังไม่ต้อง — สร้างตอนแผน service ถัดไป)

### 3.2 ยก 3 ไฟล์เข้า Studio — **copy source ตรงๆ ห้ามแก้**

| repo | Studio instance | ประเภท |
|------|-----------------|--------|
| `src/shared/Config.luau` | `ReplicatedStorage.Shared.Config` | ModuleScript |
| `src/shared/Formulas.luau` | `ReplicatedStorage.Shared.Formulas` | ModuleScript |
| `tests/RunTests.luau` | `ServerScriptService.Tests.RunTests` | **Script, Enabled = false** |

โค้ดรองรับสองโหมดแล้ว (`local isStudio = script ~= nil` แตก branch require เอง) — วางแล้วใช้ได้เลย

### 3.3 Verify ใน Studio

1. ติ๊ก `RunTests.Enabled = true`
2. กด Play (หรือ Run)
3. Output ต้องขึ้น `Tests: 46 passed, 0 failed`
4. ติ๊ก Enabled กลับเป็น false
5. **Save place**

ถ้า fail: อย่าแก้ใน Studio — แก้ที่ repo ให้เทส lune ผ่านก่อน แล้ว copy ทับใหม่ (repo คือต้นทางของ logic, Studio คือต้นทางของ scene/UI)

### 3.4 หลังผ่าน

- commit repo ถ้ามีอะไรเปลี่ยน + อัปเดตสถานะใน `docs/04-timeline.md`
- บอก user ว่า Studio มีสมองเกมแล้ว ทีมสร้างฉาก/`Interact_`/`Gui_*` ต่อได้ (docs/05 §1, docs/06 §1 ท้ายตาราง)

---

## 4. แผนถัดไปหลัง sync เสร็จ (เรียงตาม docs/07 §4)

แต่ละอันต้องผ่าน superpowers: **plan ใน `plans/` → TDD → implement** (ดูตัวอย่างแผนที่ทำเสร็จแล้ว: `plans/2026-07-19-config-formulas.md`)

| # | ระบบ | design อยู่ | หมายเหตุ |
|---|------|-------------|----------|
| 1 | GameState + Save (4 slot) + Remotes + ActionRouter | docs/07 §3.2 | state shape อยู่ docs/06 §3 |
| 2 | TimeService + wiring ใน Main | docs/07 §3.1 | ตัวเลขเวลา: PDF หน้า 6 (design doc ไม่มี — flag แล้ว) |
| 3 | MentalService | docs/07 §3.5 | drain mods ยังไม่ design ละเอียด — ต้องถาม user เรื่องอายุ modifier |
| 4 | FollowerService + MoneyService + HUD | docs/07 §4 | Formulas พร้อมแล้ว แค่ต่อท่อ |
| 5 | Edit QTE | docs/07 §3.4 | client ล้วน |

## 5. Gotchas ที่เจอมาแล้ว (อย่าเหยียบซ้ำ)

- **Config หน่วย %** (33 ไม่ใช่ 0.33) + key ชื่อ `cMin/bMax/posMin/negMax/spreadMax` — Formulas อิงชื่อพวกนี้
- **ลำดับ rng ใน `followerGain`:** ① base ② mentalZone ③ viralChance ④ viralMult — เทส fix ตามลำดับนี้ ห้ามสลับ
- **เงื่อนไข ⊖ = 50% พอดี → โดน Bad3 กิน** (`negMin = 50` เป็น ≥) — เคยเขียนเทสผิดมาแล้ว
- **Good1 = AND** (vidq และ choice ต้องผ่านทั้งคู่) — ending อื่น OR; hardcode ใน `resolveEnding` พร้อม comment
- resolveEnding fallback = `Neutral2` เมื่อไม่เข้าเงื่อนไขไหนเลย
- `Bad1`/`Bad2` อยู่ใน `EndingPriority` แต่ไม่มี threshold — resolver ข้าม, trigger สดกลางเกม (MoneyService/MentalService)
- PDF ต้นฉบับ (`assets/reference/*.pdf`): **ขีดดำ = ตัดชั่วคราวไม่ใช่ลบ**, โน้ตเก่ากว่า design doc — ขัดกันยึด design doc
