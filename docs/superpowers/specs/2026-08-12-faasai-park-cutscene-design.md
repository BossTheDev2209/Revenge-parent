# Faasai Park Date — dialogue chain design

**วันที่:** 12 ส.ค. 2569 · **สถานะ:** approved by user, พร้อมทำ plan
**อ้างอิง:** `C:\Users\khunb\AppData\Local\Temp\handoff-faasai-park-cutscene.md` (session ก่อนหน้า), `docs/16-story-bible.md` §L19,72 (ฟ้าใส "เดท/คุยกัน" arc), `docs/engines/dialogue.md` §7 (byLoc/cam field spec)

---

## 1. เป้าหมาย

ต่อยอด `byLoc.park` skeleton ที่มีอยู่แล้ว (`src/shared/Content/Dialogue/ฟ้าใส.luau`) ให้เป็นฉากเดทที่สวนสาธารณะ เฟส 2:
follower ถึงเกณฑ์ → ฟ้าใสหายจากห้อง ไปอยู่สวน → DM แจ้ง → player เดินไปคุย → **บทหลัก (spicy, ล็อกออกกลางคันไม่ได้)** → เด้งต่อทันที **บทส่งท้าย (ไม่ spicy)** → ฟ้าใสวาปกลับห้อง จบฉาก

## 2. Flow เต็ม

```
follower ≥ Config.FaasaiParkFollower (เฟส 2, ยิงครั้งเดียว)
  → SetFlag faasai_park + SetNpcLoc ฟ้าใส park (หายจากห้องทันที ไม่มี cutscene นำ)
  → DM ใหม่เด้ง toast (unlockFollower = ค่าเดียวกัน, เนื้อหา placeholder ให้ user แก้เอง)

player เดินไปสวน กด Interact_NPC_ฟ้าใส ปกติ
  → byLoc.park.p เล่น (ฟ้าใสนั่ง loop anim "IdlePark", cam ตัดมุมตามบรรทัด)
  → บทนี้ "lock" — ปุ่ม "← เลิกคุย" ไม่โชว์เลยทั้งบท (field ใหม่ ดู §3)
  → คุยจบ (ทางเดียวที่จบได้ คือเล่นจนหมดบท เพราะ quit ปิด)
    → ทันที (ไม่ต้องกด E ใหม่) เข้าบทที่ 2: Faasai.parkFarewell
       (top-level key ใหม่ บรรทัดแรก pose="Idle" → pop ออกจาก IdlePark ยืนคุยปกติ)
    → คุยจบ/quit (ปุ่มเลิกคุยโชว์ปกติบทนี้) → SetNpcLoc ฟ้าใส room (วาปกลับเงียบๆ)
       player ไม่ตามกลับอัตโนมัติ เดินเองจากสวน
    → SetFlag faasai_park_dated (กันซ้ำ + hook ให้บทอื่นอ้างทีหลังผ่าน flags/ifSeen เดิม)
```

## 3. Engine ที่ต้องเพิ่ม — quit-lock ต่อบท

ตอนนี้ `DialogueUI.show` โชว์ปุ่ม "← เลิกคุย" เสมอ ไม่มีทางปิด ต้องเพิ่ม field ใหม่ต่อบรรทัด (mirror หลักการเดียวกับ `cam`/`usesCustomCam`: สแกนทุกบรรทัดของบทก่อนเริ่ม, เจอ field นี้ที่ไหนก็ได้ = มีผลกับทั้งบท):

```lua
byLoc.park.p = {
    { speaker = "ฟ้าใส", text = "...", lock = true, cam = "FaasaiPark_01" }, -- lock ใส่บรรทัดไหนก็พอ (แนะนำบรรทัดแรก)
    ...
}
```

- **`lock = true`** (บรรทัดไหนก็ได้ในบท) → `DialogueUI.show` ไม่สร้าง `QuitButton` เลยทั้งบทนั้น (เช็คแบบเดียวกับ `usesCustomCam` — สแกนก่อนเริ่มเล่น)
- เอกสาร: เพิ่มแถวใน `docs/engines/dialogue.md` §7 ตารางระดับ B (ต่อจาก `cam`)
- Blast radius เล็กมาก: field ใหม่ 1 ตัว, ไม่กระทบบทอื่นที่ไม่ใส่ (default ปุ่มโชว์เหมือนเดิม)

## 4. Content keys (ไฟล์ `ฟ้าใส.luau`)

| key | ใช้ตอน | quit ได้ไหม | เนื้อหา |
|---|---|---|---|
| `byLoc.park.p` | คุยครั้งแรกที่สวน (ผ่าน prompt ปกติ) | ❌ (`lock=true`) | **main course** (spicy ตามที่ user ขอ) — user เขียนเอง |
| `byLoc.park.again` | (optional) คุยซ้ำที่ park ถ้า flow ยังไม่ไปต่อ | ✅ ปกติ | ไม่บังคับ ใส่ไว้เผื่ออนาคต |
| `parkFarewell` (ใหม่ top-level) | เด้งอัตโนมัติทันทีหลัง `park.p` จบ (ไม่ผ่าน prompt, ไม่ผ่าน pickLines — เหมือน `Jiajia.p3`) | ✅ ปกติ | ส่งท้ายสั้นๆ ไม่ spicy — user เขียนเอง |

บรรทัดแรกของ `parkFarewell` ต้องมี `pose = "Idle"` (field มีอยู่แล้ว ไม่ต้องเขียนใหม่) ให้ฟ้าใสลุกจากท่านั่ง

## 5. Trigger + chain hook (`Main.client.luau`)

**Trigger block ใหม่** (mirror ของ FaasaiJoin trigger ~line 578, ไม่มี cutscene/StoryBeat — แค่ flag+loc flip):
```lua
if state.phase == 2 and state.follower >= Config.FaasaiParkFollower
    and not state.flags.faasai_park and not state.flags.ending
    and #state.pendingEvents == 0
    and not DialogueUI.running and not CutscenePlayer.running
    and not ScreenTransition.running and not StoryBeat.running then
    fireAction({ type = "SetFlag", name = "faasai_park" })
    fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "park" })
end
```

**Chain hook** — จุดเดียวกับที่ mark `DialogueSeen` ปกติหลัง `runDialogue` (~line 362-365) เติม special-case เฉพาะ `dialogueName=="ฟ้าใส" and loc=="park"`:
```lua
if not quit and locSeenKey and not locSeen then
    fireAction({ type = "DialogueSeen", name = locSeenKey })
    if loc == "park" then
        local Faasai = require(Content.Dialogue["ฟ้าใส"])
        StoryBeat.play(playerGui, {
            dialogue = Faasai.parkFarewell,
            runDialogue = runDialogue,
            settle = function()
                fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "room" })
                fireAction({ type = "SetFlag", name = "faasai_park_dated" })
            end,
        })
    end
end
```
(รายละเอียด wiring จริงปรับตาม shape โค้ดตอนลงมือ — ตรงนี้คือ intent ไม่ใช่ diff สุดท้าย)

## 6. StoryNPCPlacer.luau

เพิ่ม `"park"` เข้า `SEATED_LOC` และ `NO_RAYCAST_LOC` (2 บรรทัด, ตาราง existing) → ท่า loop อัตโนมัติเป็น `IdlePark` (ตาม convention `Idle<Loc>` เดิม), anchor ที่วางเชื่อถือได้ตรงไม่ raycast (เหมือน bed/couch/chair)

## 7. Config.luau

`Config.FaasaiParkFollower = 60_000` (ตัวเลขชั่วคราว — อยู่ระหว่าง `FaasaiJoinFollower=30_000` กับเกทเฟส 3 ที่ 100K, **ไม่ใช่ค่าที่ล็อกใน `docs/02-game-design-locked.md`** เพราะเป็น event gate ใหม่ ไม่ใช่สูตรเศรษฐกิจ — user ปรับได้อิสระใน Config โดยตรง ไม่กระทบตัวเลขที่ล็อก)

## 8. DMs.luau

```lua
{ from = "ฟ้าใส", unlockFollower = Config.FaasaiParkFollower,
  lines = { "[placeholder] มาเจอกันที่สวนหน่อยสิ" } }, -- user แก้คำเองได้
```
Toast auto อยู่แล้ว (ระบบเดิม) ไม่ต้องเขียนโค้ดเพิ่ม

## 9. งานที่ user ทำเองใน Studio (ไม่ใช่ code)

- `NPCHome_ฟ้าใส_park` anchor (`NpcAnchorTool`)
- animation `IdlePark` ใน `ReplicatedStorage.Animations.ฟ้าใส`
- `CutsceneCamTool` parts จริงแทน placeholder `FaasaiPark_01`/`_02` (`Workspace.CutsceneCams`)
- เนื้อหาบทจริงทั้ง `byLoc.park.p` (spicy) และ `parkFarewell` (ไม่ spicy) — ผ่าน `dialogue-editor.html` หรือแก้ `.luau` ตรง (⚠️ verify key ครบหลังใช้ editor — ดู gotcha ใน handoff)

## 10. Out of scope (อย่าดึงกลับ)

- `choices[].teleport` (ให้เลือกแมพปลายทาง) — ไม่ได้ถามถึงในฉากนี้ ข้ามไปตามที่ handoff เคยตั้งคำถามไว้แต่ user ไม่ยืนยันใช้
- `again` เนื้อหาจริงของ `byLoc.park` — ใส่ skeleton ว่างพอ ไม่บังคับต้องมีเนื้อหาจริง (unreachable ในเคสปกติ เพราะ loc เปลี่ยนกลับ room ทันทีหลังจบเดท)
