# Mental Drain/Recovery Modifiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** modifiers ตามตารางที่ lock ใน `docs/02` §3 (19 ก.ค.) — อดนอน/canon/ตัดคลิป 5 ติด/comment streak/viral streak + ระบบนอนจริง (Sleep action)

**Architecture:** logic ทั้งหมดใน MentalService (pure — event hooks: onEdit/onActivityDone/onCommentAnswered/onViral/onSleep/onHour) | Main แค่เรียก hook | mod อายุ 2 แบบ: หมดตามชั่วโมงเกมสะสม (`expireHour`) หรือหมดตาม event (`untilEvent`) | Interact_Bed เปิด 2 ปุ่ม: พักผ่อน (activity) / นอน (ข้ามเวลา)

**State ใหม่:** `mentalMods={}`, `streaks={edit=0,commentBad=0,commentGood=0}`, `awakeHours=0`, `lastViralDay=0`

**Config ใหม่:** `Config.Mental.mods` (ตาราง 8 ตัว รวม dormant NPC), `modCap=3`, `awakeHoursForNoSleep=20`

**Action ใหม่:** `Sleep{}`

## Tasks

1. Config.Mental.mods + state fields (เทสเดิมผ่าน) → commit
2. MentalService core (TDD): `totalHours`, `addMod` (refresh ไม่ซ้ำ), `drainMultiplier`/`recoverMultiplier` (คูณ+cap 3), `expireMods` ใน onHour, applyDelta บวก × recoverMultiplier → commit
3. Event hooks (TDD): `onEdit` (streak 5→EditStreak5), `onActivityDone` (ล้าง edit streak + mods untilEvent activity/activityOrGood), `onCommentAnswered` (streaks + CommentBad/GoodStreak3, ตอบดีล้าง CommentBadStreak3), `onViral` (วันติดกัน→ViralStreak2), `onSleep` (awakeHours=0 + ลบ NoSleep), onHour นับ awakeHours ≥20→NoSleep, canon: `onCanonEvent` (CanonEvent 24h) → commit
4. Wiring Main (เรียก hook จาก handler เดิม + action Sleep = TimeService.sleep + onSleep) + Interact_Bed เมนู 2 ปุ่มใน InteractBinder → commit
5. Sync Studio + verify + docs/04 + commit

## Self-Review
- ตาราง docs/02 §3 ครบทุกแถว ✓ dormant NPC อยู่ config ไม่ wire ✓ cap ×3 สองฝั่ง ✓ นอนล้าง NoSleep ✓ viral 2 วันติด นับด้วย lastViralDay ✓
