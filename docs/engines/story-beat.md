# Engine: Story Beat — cutscene ที่ trigger จาก state (ไม่ใช่ ending/opening)

**ไฟล์โค้ด:** `StarterPlayerScripts.StoryBeat` (orchestrator) + `StoryNPCPlacer` + `CutscenePlayer` (step `move` ใหม่) + `ScreenTransition` (narration/dialogue แทรก)
**ใช้ทำ:** ฉากที่เกิดกลางเกมตาม state (follower ถึงค่านึง, flag ติด) เช่น "ฟ้าใสเข้าร่วม", "หมวยทวงตังจบเกม"
**ต่างจาก ending/opening ยังไง:** ending/opening ใช้ `CutscenePlayer`/`ScreenTransition` ตรงๆ ครั้งเดียวตอนจบ/เริ่มเกม — Story Beat คือ **ของกลางประกอบฉาก** ที่ใช้ซ้ำได้หลายจุดกลางเกม (ดู [README.md](README.md) เทียบ engine อื่น)

---

## 1. เมื่อไหร่ใช้ StoryBeat

**ใช้เมื่อ:** ฉากต้องล็อก player + จอดำ + (อาจมี) cutscene + (อาจมี) กล่องคุย ต่อกันเป็นเรื่องเดียว โดย trigger จาก **state เปลี่ยน** (follower/flag) ไม่ใช่จากกด prompt

**ไม่ต้องใช้ (ใช้ engine ตรงๆ พอ):**
- คุย NPC ผ่านกด prompt ปกติ → `DialogueUI.show` ตรงๆ (ดู [dialogue.md](dialogue.md))
- ฉากจบเกม (6 ending) → `CutscenePlayer.play` ตรงๆ ใน `Main.client` (มีอยู่แล้ว)
- ข้ามเฟส/จอดำเฉยๆ → `ScreenTransition.play` ตรงๆ

---

## 2. โครง StoryBeat.play — ล็อกทั้งฉาก จบแล้วปลด

```lua
local StoryBeat = require(...)

StoryBeat.play(playerGui, {
    cutscene = require(Content.Cutscenes.FaasaiJoin), -- (ไม่ใส่ = ข้ามช่วงหนัง) CutscenePlayer step list
    stage    = function()                              -- ใต้จอดำ "ก่อน" dialogue — วาป/จัดฉาก
        fireAction({ type = "TeleportTo", target = "Spawn_FaasaiDoor" })
    end,
    stageLines = { "..." },                            -- ข้อความบนจอดำช่วง stage (ไม่ใส่ = ดำเฉยๆ)
    dialogue = require(Content.Dialogue["ฟ้าใส"]).p2,   -- (ไม่ใส่ = ข้าม) DialogueUI lines ปกติ
    settle   = function()                               -- ใต้จอดำ "หลัง" dialogue — ตั้ง npcLoc/เก็บฉาก
        fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "room" })
    end,
    settleLines = { "..." },
    onDone = function() end,                            -- จบทุกอย่าง คืนคุมแล้ว
})
```

**ลำดับที่เล่นจริง:** ล็อก player (`InteractLock`, ปิด prompt+เดินไม่ได้) → `cutscene` (ถ้ามี) → จอดำ + `stage()` → `dialogue` (ถ้ามี) → จอดำ + `settle()` → ปลดล็อก → `onDone`

**ทำไม `stage`/`settle` ต้องอยู่ "ใต้จอดำ":** ย้าย/เสก NPC ตอนจอดำสนิท = player ไม่เห็นตัวโผล่/หาย (เหมือน [ScreenTransition](#4-narration--dialogue-แทรก-ในจอดำ) `onBlack`)

---

## 3. Step `move` ใน CutscenePlayer — เดิน actor ไป Part

เพิ่มจาก step เดิม (`camera`/`text`/`wait`/`anim`/`face`/`bgm`/`sound`/`focus`) — ดู [cutscene.md §2](cutscene.md)

```lua
{ type = "move", actor = "ฟ้าใส", to = "FaasaiBedSpot", t = 2.5 }
```

| field | ต้องใส่ | หมายเหตุ |
|---|---|---|
| `actor` | ✅ | ชื่อ actor เดียวกับที่ใช้ใน `anim`/`face` (ดู [dialogue.md §2.5](dialogue.md)) |
| `to` | ✅ | ชื่อ **Part** ในแมพ — ตัวจะเดินไปยืนตรงจุดนี้ หันหน้าตามทิศที่เดินมา |
| `t` | ไม่ใส่ = วาปทันที | วินาทีที่ใช้เดิน (lerp ตำแหน่ง) |

**move แค่ย้ายตำแหน่ง ไม่เล่นท่าเดินให้เอง** — ใส่ `anim` คู่กันเองถ้าอยากเห็นท่าเดิน/นั่ง:

```lua
{ type = "anim", actor = "ฟ้าใส", name = "Walk", loop = true },  -- เริ่มเดินก่อน move
{ type = "move", actor = "ฟ้าใส", to = "FaasaiBedSpot", t = 2.5 },
{ type = "anim", actor = "ฟ้าใส", name = "SitDown", loop = true }, -- ถึงแล้วนั่งค้าง
```

**ตัวเดียวย้ายไปมา ไม่สร้างซ้ำ** — best practice: อย่าวาง NPC 2 ตัว (ตัวหน้าประตู + ตัวในห้อง) `move` ย้ายตัวเดิมเข้าฉากได้เลย (ดู §4 ของ StoryNPCPlacer ประกอบ)

---

## 4. StoryNPCPlacer — ที่อยู่ NPC มาจาก state ไม่ใช่วางตายในแมพ

**ปัญหาที่แก้:** NPC ที่ "ย้ายที่อยู่" ตามเนื้อเรื่อง (ฟ้าใสอยู่ห้องเรา, เจียเจียไปสยาม ฯลฯ) ต้องเป็น **instance เดียว** ย้ายไปมา ไม่ Destroy/สร้างใหม่

**ทีมเตรียม:** วาง Part เปล่าชื่อ `NPCHome_<actor>_<loc>` ตรงจุดที่อยากให้ NPC ยืน เช่น:

```
NPCHome_ฟ้าใส_room     -- ข้างเตียงในห้องเรา
NPCHome_ฟ้าใส_door     -- หน้าประตู (จุดเคาะ)
NPCHome_เจียเจีย_park  -- ในสวนสาธารณะ
```

**ตั้งที่อยู่จาก action** (เรียกใน `stage`/`settle` ของ StoryBeat ใต้จอดำ):

```lua
fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "room" })
```

`StoryNPCPlacer` ฝั่ง client อ่าน `state.npcLoc` ทุก push → `PivotTo` ไปยัง anchor Part ที่ตรงชื่อ + เล่น `Idle` loop ให้เอง (ไม่ต้องสั่ง anim เอง) — ทำจริงเฉพาะตัวที่ `loc` เปลี่ยน (ไม่ restart idle ทุก push)

**ไม่มี anchor Part ตรงชื่อ = warn ใน Output + ไม่ย้าย** (ไม่พัง เกมเล่นต่อได้)

---

## 5. Narration + dialogue แทรก ในจอดำ (`ScreenTransition`)

`ScreenTransition.play` (ของกลาง fade ดำ) เล่น **step list** ได้เหมือน cutscene แต่ auto-timed ไม่ต้องคลิก (สไตล์ Genshin/HSR):

```lua
ScreenTransition.play({
    steps = {
        { text = "หลังจากนั่งหลังขดหลังแข็งอยู่บนสะพานลอยมาได้ [date] วัน", t = 3 },
        { text = "ฉันก็เก็บเงินพอย้ายเข้าห้องเช่าได้สักที", t = 4 },
        -- แทรกกล่องข้อความจริง (reuse DialogueUI) กลางจอดำ — เช่นเจียเจียพูดแทรก narration
        { dialogue = { { speaker = "เจียเจีย", text = "ลุกขึ้น!" } }, voice = "เจียเจีย" },
    },
    onBlack = function() end, -- ทำตอนจอดำสนิท (ก่อนเริ่มเล่า steps)
    onDone = function() end,
})
```

| step | ทำอะไร |
|---|---|
| `{ text = "...", t = วินาที? }` | narration ขึ้นกลางจอ (ไม่มีกรอบ) — fade เข้า/ออกเองระหว่างสลับบรรทัด · ไม่ใส่ `t` = ค้างจน step ถัดไป |
| `{ dialogue = {...lines...}, voice = ? }` | **กล่องข้อความจริงแทรกกลางจอดำ** (reuse `DialogueUI` เต็มระบบ — คลิกต่อ, ช้อย, portrait 3D ของ NPC) |
| `{ t = วินาที }` | หน่วงเวลาเปล่า |

**`[date]`** ใน text ต้อง substitute เองก่อนส่งเข้า (ดูตัวอย่างใน `Main.client` — `state.day`), engine ไม่รู้จัก state

**ระหว่างเล่น (ทั้ง narration และ dialogue แทรก):**
- จอดำเต็มจอเสมอ (ไม่มีช่องโหว่เห็นแมพ)
- player ล็อกเดิน + ปิด prompt (เหมือน cutscene อื่น)
- hotbar/backpack ซ่อน
- เพลงโซนถูกล็อก (ไม่มีเพลงแทรกกลาง transition)

---

## 6. ทดสอบด้วย Dev Console

ก่อนวาง anchor/cam ในแมพครบ ทดสอบเนื้อหาได้เลยผ่าน `/dev` (ดู [15-dev-console.md](../15-dev-console.md)):

```
/dev preview 4          -- เล่น Content.Cutscenes.PhaseTransitions[4] ตรงๆ (client-only)
/dev npcloc ฟ้าใส room  -- ทดสอบ StoryNPCPlacer ย้ายตัว (ต้องมี anchor Part ก่อน)
/dev tp 2                -- วาปไปแมพเฟส 2 ดู anchor/cam ที่วางไว้
```

---

## 7. ผิดแล้วเป็นยังไง

| ทำผิด | ผลลัพธ์ |
|---|---|
| `move` หา actor/Part ไม่เจอ | warn ใน Output, ข้าม step นั้น เล่นต่อ |
| `npcLoc` ตั้งชื่อ anchor ไม่ตรง (`NPCHome_<actor>_<loc>`) | warn "ไม่เจอ anchor", NPC ไม่ขยับ |
| `dialogue` step บทพัง (format ผิด) | `ScreenTransition.validateSteps` ฟ้อง error ชัดว่า step ไหน — ไม่เล่นทั้งฉาก |
| `text` step ไม่มี `text`/`t` | validate ฟ้องเหมือนกัน |
