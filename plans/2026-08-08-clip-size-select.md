# Plan — เลือกขนาด footage/คลิป ก่อนตัด (risk↔reward)

**Date:** 2026-08-08 · **Owner:** สาย A · **Feature:** ก่อนเข้า QTE ตัดคลิป ให้เลือกขนาด footage (8/16/32/64/128 GB…) ขนาด↑ = QTE ยากขึ้น (วงเยอะ+หดเร็ว+วงมาก) แลกกับ follower/เงิน ×ตามขนาด

## Decisions (user lock 2026-08-08)
- **Reward curve = Proportional:** `sizeMult = footageGB / 32` (32 = baseline ×1.0). 8→×0.25, 16→×0.5, 64→×2, 128→×4.
- **Mental = flat −20/คลิป** ทุกขนาด (ไม่แตะ `Config.Mental.deltas.clipEdit`). คลิปใหญ่ = คุ้มใจ, แลกกับ QTE โหด — ตัวบาลานซ์คือใจ ไม่ใช่ economy.
- **Economy ปลอดภัยโดยโครงสร้าง:** เพดานเงิน ~1.47M ผูกกับเพดาน follower 1M (money = Σ follower×rate, follower รวม=1M ตายตัว). คูณ reward ต่อคลิป = ไปถึง 1M ด้วยคลิปน้อยลง เพดานไม่ขยับ.

## ⚠️ Locked conflict (resolved by user)
`Config.Record.footagePerClipGB = 32` เดิม lock 27 ก.ค. = คงที่. feature ทำให้แปรผัน → user อนุมัติ unlock. footagePerClipGB=32 **คงไว้เป็น baseline (sizeMult denominator) + ค่า default**. อัปเดต `docs/02` §9.5 ให้ตรง.

## ClipSizes table (source of truth = Config)
| gb | rewardMult(=gb/32) | hits | maxOnScreen | spawnInterval | approach |
|----|----|----|----|----|----|
| 8  | 0.25 | 10 | 1 | 0.55 | 1.70 |
| 16 | 0.5  | 14 | 2 | 0.48 | 1.55 |
| 32 | 1.0  | 20 | 2 | 0.40 | 1.40 | ← baseline (= duo เดิม)
| 64 | 2.0  | 28 | 3 | 0.34 | 1.20 |
| 128| 4.0  | 40 | 4 | 0.28 | 1.05 |

difficulty (hits/maxOnScreen/spawnInterval/approach) = **เก็บใน Config.ClipSizes จริง (ไม่ใช่สูตร)** user tune ได้. rewardMult = **คำนวณ** `gb/footagePerClipGB` (proportional lock ไม่เก็บซ้ำ กันหลุด sync).

## Score normalization (สำคัญ)
hits แปรผัน → total max = hits×10 ต่างกัน. VidQ ใช้ 0–200 คงที่. ต้อง normalize ก่อนส่ง:
`normalizeScore(total, hits) = clamp(round(total/(hits*10) * 200), 0, 200)` → VidQ = %ความแม่น ไม่ผูกจำนวนวง.

## Changes
1. **Config.luau** — `Config.ClipSizes` (5 แถวบน). footagePerClipGB=32 คงไว้.
2. **Formulas.luau** — `clipSizeMult(gb) = gb / Config.Record.footagePerClipGB`.
3. **RecordService.luau** — `spendForClip(state, footageGB?)` หักตามขนาด (default 32, backward-compat). `canEdit(state, footageGB?)` default 32; เพิ่ม `minClipGB()` = ClipSizes[1].gb.
4. **FollowerService.luau** — `finishEdit` เก็บ `footageGB`+`sizeMult` บน clip. `uploadClip` คูณ `sizeMult` เข้า gained (money ตาม).
5. **Main.server.luau** — ส่ง `a.footageGB` เข้า spendForClip.
6. **EditQTE.luau** — `normalizeScore`, `clipSizesFor(state)` (กรอง gb≤footage), หน้าจอเลือกขนาด (slider snap ตาม step ที่ซื้อได้), round ใช้ param ตามขนาด, ส่ง `FinishEdit{score=normalized, footageGB}`. canEdit gate = minClipGB (8).
7. **docs/02 §9.5** — อัปเดต locked footage → variable + ตาราง.
8. **tests/RunTests.luau** — do-end blocks: clipSizeMult, normalizeScore, clipSizesFor, spendForClip variable, uploadClip×sizeMult, finishEdit เก็บ footageGB.

## Backward compat
finishEdit/spendForClip ไม่มี footageGB → default 32, sizeMult=1.0 → เทสเดิมผ่านหมด.

## Out of scope
- pc-upgrade "ตัดต่อไวขึ้น" ยัง unwired (deferred เดิม)
- cover image ไม่ display = asset id/moderation ของ user เอง ไม่ใช่ size (ScaleType.Crop จัดการ size แล้ว) — แจ้ง ไม่แก้
