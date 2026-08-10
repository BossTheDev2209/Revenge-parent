# Handoff — RojoDoctor: plugin ตรวจสุขภาพ Rojo sync

**เขียน:** 10 ส.ค. 2569 · **สถานะ:** ยังไม่เริ่มเขียนโค้ด — handoff ให้ agent ตัวถัดไป
**ที่มา:** audit ครบ 236 commit เจอ Rojo incident 6 เคส (ตาราง + pattern เต็ม → `docs/08-studio-sync-handoff.md`)

## ปัญหาที่ต้องแก้

Rojo **ไม่เคยแจ้ง error ตอนพัง** ทุกเคสที่เกิดมาคนเพิ่งรู้ตัวหลังเสียเวลาไปแล้วเป็นวัน:
แก้โค้ดแล้วเกมไม่เปลี่ยน (ไฟล์ไม่มีปลายทางใน map / plugin หลุด), งานหายจาก full-sync, instance ซ้ำ, session lock ค้าง

ต้องมีปุ่มเดียวที่ตอบได้ว่า **"ตอนนี้โค้ดที่รันอยู่ใน Studio ตรงกับดิสก์จริงไหม"** ก่อนจะไปนั่ง debug logic

## Scope

Studio plugin ชื่อ **`RojoDoctor`** — toolbar `Streaming Fix` (ใช้ toolbar เดิม อย่าสร้างใหม่) ปุ่ม **`Rojo Doctor`**
กดแล้วรันเช็คทั้งหมด → print ผลเป็นรายการ ✅/❌ ใน Output **อ่านอย่างเดียว ห้ามแก้ instance ใดๆ เอง**

## เช็คที่ต้องมี (เรียงตามความสำคัญ)

| # | เช็ค | ทำยังไง | เกณฑ์ fail |
|---|---|---|---|
| 1 | **ไฟล์ที่ไม่มีปลายทางใน map** (pattern ①⑥ — เคสที่แพงที่สุด) | อ่าน `default.project.json` → ไล่ทุก `$path` ว่า map ไป container ไหน · เทียบกับ instance จริงในเกม | มีไฟล์ใน `src/` ที่ไม่ตรงกับ instance ที่โค้ด require จริง |
| 2 | **ดิสก์ ≠ Studio** (pattern ①②) | เทียบ `#Source` + checksum ต่อไฟล์ · **normalize `\r\n` → `\n` ก่อนเทียบเสมอ** ไม่งั้น false positive ทุกไฟล์ | length หรือ checksum ต่าง |
| 3 | **โมดูลชื่อซ้ำ** (pattern ④) | สแกน `LuaSourceContainer` ทุกตัวใต้ container ที่ Rojo จัดการ นับชื่อซ้ำ | ชื่อเดียวกัน ≥2 ตัว |
| 4 | **session lock ค้าง** (pattern ⑤) | หา instance ชื่อขึ้นต้น `__Rojo` (เคยเจอ `ServerStorage.__Rojo_SessionLock`) | เจอทั้งที่ไม่ได้ connect อยู่ |
| 5 | **หลาย session ชนกัน** | ยิง `HttpService` ไปที่ port 34870–34890 ดูว่ามีกี่ตัวตอบ (`/api/rojo` คืน JSON มี `sessionId`) | ตอบมากกว่า 1 port |
| 6 | **plugin connected อยู่ไหม** (pattern ②) | เช็ค ① + ④ ประกอบกัน (Rojo ไม่มี API บอกสถานะตรงๆ) | — |

## ข้อควรระวังตอนทำ (เสียเวลามาแล้วทั้งนั้น)

- **plugin โหลดจาก "สำเนา"** ที่ `%LOCALAPPDATA%\Roblox\Plugins` ไม่ auto-update จาก repo → แก้ไฟล์ใน `tools/` แล้วต้องรัน `tools/install_plugin.ps1` ทุกครั้ง แล้ว **restart Studio** (ปุ่ม toolbar สร้างตอน Studio เริ่มเท่านั้น — ไฟล์อยู่ครบแต่ปุ่มไม่โผล่ = ยังไม่ restart)
  → เพิ่ม entry ใหม่ในอาเรย์ `$plugins` ของ `install_plugin.ps1` ด้วย
- **plugin อ่านไฟล์บนดิสก์ตรงๆ ไม่ได้** (ไม่มี filesystem API) — ทางที่ใช้ได้:
  - ให้ `rojo serve` เป็นคนบอก: `HttpService:GetAsync("http://localhost:34872/api/read/...")` (ต้องเปิด HttpEnabled)
  - หรืออ่าน `sourcemap.json` ที่ `rojo sourcemap` gen ไว้ — แต่ไฟล์นี้ `.gitignore` อยู่ (`21e1589`) ต้องสั่ง gen เอง
  - **เลือกทางแรกก่อน** ไม่ต้องพึ่งไฟล์ที่อาจไม่มี
- **ห้ามให้ plugin แก้/ลบอะไรเอง** — รายงานอย่างเดียว (CLAUDE.md rule 7) · การลบ session lock / instance ซ้ำ ให้คนตัดสินใจ
- ยังไม่ต้องทำ auto-fix หรือ UI สวย — Output print พอ

## Definition of done

- [ ] `tools/RojoDoctor.plugin.luau` + เพิ่มใน `tools/install_plugin.ps1`
- [ ] กดปุ่มแล้วได้รายการ ✅/❌ ครบ 5 เช็ค พร้อมบอกชัดว่าไฟล์ไหน/instance ไหนมีปัญหา
- [ ] **ทดสอบกับของจริง:** ย้อน `default.project.json` ให้ตัด node `StarterGui` ออกชั่วคราว → เช็ค #1 ต้องจับได้ → ใส่คืน
- [ ] เขียนวิธีใช้ลง `tools/README.md` + ลิงก์จาก `docs/08`
- [ ] commit + push

## อ้างอิง

- ทะเบียน incident + pattern ทั้ง 6: `docs/08-studio-sync-handoff.md`
- CLAUDE.md rule 10 (เช็ค sync ก่อน debug logic) · rule 12 (Team Create + git safety)
- plugin ตัวอย่างที่มีอยู่แล้ว: `tools/LodFix.plugin.luau` (โครง toolbar/ปุ่ม/`ChangeHistoryService` ก๊อปได้เลย)
