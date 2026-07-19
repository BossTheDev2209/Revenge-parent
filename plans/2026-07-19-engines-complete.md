# Engines Complete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** engine ครบทุกตัวที่เหลือ — Dialogue (typewriter+tag), Comment/Feedback (choice ⊕/◎/⊖), Calendar/Sponsor, Ending resolver รวม Bad1/Bad2, CutscenePlayer — พร้อม **Content skeleton** ที่ทีมเติมบทได้โดยไม่แตะโค้ด

**Architecture:** ยึดหลักเดิม: pure core เทสด้วย lune / UI glue บาง / wiring ใน Main / เนื้อหาทั้งหมดอยู่ `Content/` เป็นตาราง Lua. Content โหลดแบบ dual-mode เหมือน Config

**สิ่งที่ตัดสินใจในแผนนี้ (design doc ไม่ระบุ — flag):**
- Sponsor จ่าย: `เงินคลิปเฉลี่ย(tier B) × 2–4` (PDF หน้า 6 "x2-4 เท่า") → `Formulas.sponsorPay`
- comment ต่อคลิป = 3 (PDF หน้า 8)
- Dialogue ความเร็ว: normal 0.03 / slow 0.08 / fast 0.012 วิ/ตัวอักษร (เลือกเอง — ปรับใน Config ได้)
- Canon Event = milestone cross (1K/10K/100K/1M) → `state.pendingEvents` client เล่น dialogue จาก `Content.CanonEvents`

**State fields ใหม่:** `pendingComments = {}`, `pendingEvents = {}` (mergeDefaults ทำให้ save เก่าไม่พัง)

**Actions ใหม่:** `AnswerComment{reply=1..3}`, `PlaceBlock{day,id}`, `AcceptSponsor{day}`, `FreezeTime{on}`, `EventSeen{id}`

---

## Task 1: Content skeleton + Config เพิ่ม

**Files:** Create `src/shared/Content/Dialogue/{Mom,Dad,Friend1,Friend2,CC1,Hater}.luau`, `Content/Comments.luau`, `Content/CanonEvents.luau`, `Content/Endings/{Bad1,Bad2,Bad3,Neutral1,Neutral2,Good1}.luau` | Modify `Config.luau`

Format ต่อไฟล์ (ทีมแก้ได้เลย):

```lua
-- Dialogue/Mom.luau: list ของ string, tag [slow][fast][normal] คุมความเร็วกลางบรรทัด
return { "แม่: กลับมาทำไม... [slow]ไม่มีเงินใช่ไหม", "แม่: [fast]บอกแล้วว่าอาชีพนี้ไม่มั่นคง!" }

-- Comments.luau: { text, replies = {3 ตัวเลือก แต่ละอันมี tag pos/neu/neg} }
-- CanonEvents.luau: { ["milestone_1000"] = { dialogue = {...} }, ... }
-- Endings/*.luau: list ของ step: {type="text",text=} | {type="wait",t=} | {type="camera",pos={x,y,z},look={x,y,z}}
```

Config เพิ่ม: `Config.Dialogue = { charDelay = { normal = 0.03, slow = 0.08, fast = 0.012 } }`, `Config.CommentsPerClip = 3`

## Task 2: Formulas.sponsorPay + GameState fields (TDD)

```lua
-- เทส
check("sponsorPay phase1 rng=0 → เฉลี่ย 650×0.8×2 = 1040", Formulas.sponsorPay(1, rng0) == 1040)
check("sponsorPay rng สูง → ×4", Formulas.sponsorPay(1, rngHi) >= 2078 and Formulas.sponsorPay(1, rngHi) <= 2080)
check("state ใหม่มี pendingComments/pendingEvents", ...)
-- implement: base เฉลี่ย = (min+max)/2 ของเฟส, × moneyRate × (2 + rng()×2), floor
```

## Task 3: CommentService (TDD)

```lua
CommentService.generate(state, rng)        -- เพิ่ม Config.CommentsPerClip ใบจาก pool → pendingComments {id=}
CommentService.answer(state, action)       -- pop ใบแรก, tag จาก Content (client โกง tag ไม่ได้), choices[tag] += 1, คืน tag|nil
-- เทส: generate 3 ใบ id ถูกตาม rng / answer นับ pos / answer ตอนไม่มี pending คืน nil / reply index มั่วคืน nil (ไม่ pop)
```

## Task 4: CalendarService (TDD)

```lua
CalendarService.place(state, day, block)   -- วางได้เฉพาะวันอนาคต + ช่องว่าง/ไม่ lock — คืน bool
CalendarService.acceptSponsor(state, day)  -- follower >= SponsorUnlockFollowers + place {type="Sponsor"}
CalendarService.onDay(state, rng)          -- block วันนี้: Sponsor → money += sponsorPay แล้วลบ block, คืน block|nil
-- เทส: วางอดีตไม่ได้ / ทับ Canon ไม่ได้ / sponsor ก่อน 10K ไม่ได้ / วัน trigger เงินเข้า + block หาย
```

## Task 5: EndingService (TDD)

```lua
EndingService.computeStats(state)          -- clips → vidq % , choices → % (หน่วยเดียวกับ EndingThresholds)
EndingService.check(state)                 -- ลำดับ: จบแล้ว→nil | rentMissed≥2→Bad1 | mentalZero→Bad2 | ≥1M→resolveEnding | nil
-- เทส: Bad1 ก่อน Bad2 / 1M+choice ดี→Good1 / ยังไม่ 1M ไม่มี flag → nil / จบแล้ว nil / stats % ถูก
```

## Task 6: DialogueUI + CutscenePlayer (pure ส่วน TDD)

```lua
DialogueUI.parseTags(line)   -- "[slow]ก[fast]ข" → {{speed="slow",text="ก"},{speed="fast",text="ข"}} เริ่ม normal
CutscenePlayer.validate(steps) -- เช็ค type ครบ/field ครบ คืน (bool, err)
-- glue: DialogueUI.show(playerGui, lines, onDone) typewriter + click ข้าม | CutscenePlayer.play(playerGui, steps, onDone) camera scriptable + restore
-- เทส parseTags: ไม่มี tag / นำหน้า / กลางบรรทัด / tag ติดกัน | validate: ผ่าน / type มั่ว / wait ไม่มี t
```

## Task 7: Wiring + InteractBinder NPC + sync

- Main.server: actions ใหม่ทั้ง 5 + `CommentService.generate` หลัง upload สำเร็จ + milestone check หลัง upload (`Config.StoryMilestones` cross → flag + pendingEvents) + `CalendarService.onDay` ใน TimeService.onDay + `EndingService.check` หลังทุก route/onDay → `state.flags.ending`
- Main.client: state watcher — `flags.ending` → CutscenePlayer(Content.Endings[id]) | `pendingEvents[1]` ใหม่ → DialogueUI(CanonEvents) + EventSeen
- InteractBinder: `Interact_NPC_*` → DialogueUI(Content.Dialogue[map]) + FreezeTime on/off — map: Mom→Mom, 01→Dad, 02→Friend1, 03→Friend2, 04→CC1, 05→Hater
- sync Studio (replace ทุกไฟล์แตะ + Content folder ทั้งก้อน) + verify + Play smoke + docs + commit

## Self-Review

- Coverage: design doc §6 (comment เท่านั้นที่นับ choice ✓ — DM/Dialogue ไม่แตะ choices) | §7 typewriter ทางเดียว+tag ✓ | §8 cutscene script ✓ | §5 Bad1/Bad2 สด + priority ✓ | sponsor PDF หน้า 6 ✓
- Type consistency: tag `pos/neu/neg` ตรง state.choices ✓ | Endings id ตรง `EndingPriority` ✓
- ไม่ทำ: DM UI (script ตายตัว ไม่มีผล — content ไป), Bank/Shop UI (ไม่ใช่ engine — apps ทีหลัง), mental modifiers (รอ user)
