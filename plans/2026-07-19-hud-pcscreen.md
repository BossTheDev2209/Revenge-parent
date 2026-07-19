# HUD v2 + PC On-Screen GUI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** แยก UI สองชั้นตาม PDF หน้า 5 — **HUD ติดจอตลอด** (follower/เงิน/นาฬิกา/mental bar แนวตั้ง/storage) กับ **PC Screen เต็มจอแบบ Jim's Computer** เปิดเมื่อกด Interact_Camera — desktop มี icon แอปครบ + กรอบเครื่องเปลี่ยนตามเฟส (1=โน้ตบุ๊คมือสอง, 2=คอมตั้งโต๊ะ, 3=เครื่องเทพ RGB)

**Apps ใน PC (ตาม PDF หน้า 5):** Edit(QTE เดิม) / Upload / Feedback(กราฟย่อ+ตอบ comment — ย้ายจาก floating CommentUI) / Bank / Calendar+Sponsor / Shop(upgrade) / Message(DM) / Manage(placeholder — ระบบพนักงานยังไม่ scope)

**Server เพิ่ม:** `MoneyService.buyUpgrade` + action `BuyUpgrade{item}` (กล้อง/storage 4 ระดับตาม Config — ผลต่อ VidQ ยังไม่ wire, flag)

**App contract:** module มี `create(frame, ctx)` — ctx = `{fireAction, getState, close}` | PCScreen ส่ง state ใหม่เข้า `refresh(state)` ของแอปที่เปิดอยู่

## Tasks

1. `MoneyService.buyUpgrade` (TDD: ซื้อได้/เงินไม่พอ/max level/item มั่ว) + action + Content/DMs.luau → commit
2. HUD v2 — กล่อง follower/เงิน (บนซ้าย), เวลา+วัน (บนขวา), mental bar แนวตั้งสีตามโซน (ขวา), storage+กล้อง (ล่างซ้าย) → commit
3. PCScreen shell — bezel/wallpaper ตามเฟส + icon grid + Exit + app host → commit
4. Apps 6 ตัว (Upload/Feedback/Bank/CalendarApp/Shop/Message) + Manage placeholder → commit
5. Wiring: Interact_Camera → PCScreen, ถอด CommentUI floating (ย้ายเข้า Feedback), Main.client cache state → commit
6. Sync Studio + verify + Play smoke + docs → commit

## Self-Review
- PDF หน้า 5 UI ทั้งหมด: follower/money/clock/mental bar/storage/resolution ✓ | UI PC app ครบ 8 (manage placeholder — flag) ✓ | ต่างเฟสต่างเครื่อง ✓ (style table ใน PCScreen — ไม่ใช่ตัวเลข balance ไม่ลง Config)
- Upgrade ผลต่อ VidQ multiplier = ยังไม่ wire (design ยังไม่ fix สูตร resolution×tier) — flag ใน docs
