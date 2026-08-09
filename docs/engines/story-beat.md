# Engine: Story Beat — cutscene ที่ trigger จาก state (ไม่ใช่ ending/opening)

**ไฟล์โค้ด:** `StarterPlayerScripts.StoryBeat` (orchestrator) + `StoryNPCPlacer` + `CutscenePlayer` (step `move`/`objAnim`/`hold`/`unhold`/`visible`) + `AnimPlayer` (`playObject`/`hold`/`unhold` — object animation) + `ScreenTransition` (narration/dialogue แทรก)
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

**ก่อนใช้ เช็คก่อนว่าจำเป็นไหม:** ถ้าทำ animation clip เดียวยาวครอบทั้งฉาก (เคาะ→คุย→เดิน→นั่ง) ด้วย **Moon Animator** (bake root motion ได้จริง — ตัวเดินจริงในโลก ไม่ใช่เดินอยู่กับที่) **ไม่ต้องใช้ `move` เลย** ใช้ `anim` เดียว (`loop=false`) พอ ความรู้สึก cutscene มาจากกล้องตัด/แพนคลอไปกับ clip
`move` มีไว้สำหรับกรณี **ไม่ได้ bake root motion ในclip** (เช่น anim ท่ายืน/นั่งแยกกัน อยากให้ engine เดินให้ระหว่าง 2 ท่า) — ทางเลือกสำรอง ไม่ใช่ทางหลัก

field ทั้งหมด → ดูตาราง [cutscene.md §2](cutscene.md) (เป็นที่เดียวที่เก็บ field spec ของทุก step ไม่ให้ซ้ำ 2 ที่)

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

**`loc` คืออะไร:** เป็น**ป้ายข้อความที่เราตั้งเอง** ไม่ใช่คำสงวนของ Roblox/engine — แค่ label บอกว่า "ตอนนี้ตัวนี้อยู่ที่ไหนในเนื้อเรื่อง" (`"room"`/`"door"`/`"park"`/`"away"` ฯลฯ เลือกคำเองได้หมด) `anchorName(actor, loc)` แค่เอา 2 ค่านี้มาต่อเป็นชื่อ Part (`"NPCHome_" .. actor .. "_" .. loc`) — **ไม่มี list ชื่อคงที่ให้เลือก** มีแค่คู่ที่โค้ดจริงเรียก `SetNpcLoc` ไว้เท่านั้นที่ต้องมี Part จริงรองรับ (เพิ่มคู่ใหม่ = เพิ่มทั้ง `fireAction SetNpcLoc` ที่ไหนสักจุด + สร้าง Part ชื่อตรงกัน)

**ไม่ต้องห่วงเรื่อง scope การค้นหา (`FindFirstChild(name, true)` ค้นทั้ง workspace ไม่จำกัดโฟลเดอร์)** — เรียกเฉพาะตอน `loc` **เปลี่ยน** เท่านั้น (มี guard กันเรียกซ้ำทุก state push) ทั้งเกมเรียกรวมหลักสิบครั้งตลอดรอบเล่น ไม่ใช่ทุก frame — จำกัด folder จะเร็วขึ้นจริงแต่วัดผลไม่ออก ไม่คุ้มเพิ่มกฎที่ทีมต้องจำ (ต้องวางถูกโฟลเดอร์ไม่งั้นหาไม่เจอ)

**ทีมเตรียม:** วาง Part เปล่าชื่อ `NPCHome_<actor>_<loc>` ตรงจุดที่อยากให้ NPC ยืน (วางไว้ตรงไหนในแมพก็ได้ ไม่ต้องอยู่โฟลเดอร์เฉพาะ) เช่น:

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

## 6. เตรียมโมเดล NPC ใหม่ + player ในฉาก (FAQ)

**วาง NPC ตัวละครหลัก (เนื้อเรื่อง) ไว้ตรงไหน:**

```
Workspace.NPC.StoryNPC.NPC_special_<ชื่อ>   -- แม่/พ่อ/ฟ้าใส/เจียเจีย/พี่เปิ้ล
```

ชื่อ model ต้องตรงกับ `AnimPlayer.ACTOR_MODEL` เป๊ะ (ดู [05-build-conventions.md §NPC roster](../05-build-conventions.md)) — `findRig` หาจากชื่อนี้ตรงๆ ผิดชื่อ = warn เงียบ ไม่มี error แต่ท่า/portrait ไม่ขึ้น

**ในตัว model ต้องมี:** `Animator` ใต้ Humanoid (ไม่มี = ท่าไม่เล่นเลย) · `Head.face` (Decal, ใช้กับ step `face`) · anchor **เฉพาะ** `HumanoidRootPart` (anchor ทั้งตัว = ท่าไม่ขยับ) · Part `Interact_NPC_<ชื่อ>` **เป็นลูกของ model เอง** (ไม่ใช่โฟลเดอร์แยก) ถ้าอยากให้คุยได้แบบ NPC ปกตินอกเหนือจาก cutscene

**player ในฉาก — ไม่มีโมเดลแยกให้ดึง:** step `{ actor = "player" }` (ไม่ว่า `anim`/`face`/`move`) เล่นบน **ตัว player จริงในเกมตรงๆ** (`AnimPlayer.findRig("player")` คืน `Players.LocalPlayer.Character` ตรงๆ) ไม่ต้องเตรียม model player แยกไว้ในแมพ

**แต่ตอน authoring ใน Moon Animator ต้องมี rig ให้คีย์เฟรม** (ไม่มี player จริงให้แก้ตอนอยู่ใน Edit mode) — วิธีทำ:
1. ก๊อป `Workspace.NPC.R6` (rig ต้นแบบ — **ห้ามแก้ตัวจริง**) มาวางเป็น scratch rig ชั่วคราว
2. วางคู่กับ `NPC_special_<ชื่อ>` ตรงตำแหน่งฉาก คีย์เฟรมทั้งคู่ให้อินเทอร์แอคกัน
3. Export เป็น **2 Animation object แยกกัน** (clip NPC / clip player) เข้า `ReplicatedStorage.Animations` — เพราะรันจริงเรียกคนละ step (`actor="ฟ้าใส"` / `actor="player"`) แยกกัน
4. **ลบ scratch rig ทิ้งหลัง export** — ห้ามทิ้งไว้ใต้ `Workspace.NPC` เด็ดขาด (`findRig` ค้นเจาะจงแค่โฟลเดอร์นี้ ตัวปลอมชื่อชนจะไปแย่งของจริงตอนรัน — คอมเมนต์เตือนไว้ในโค้ดเอง [AnimPlayer.luau:112-113](../../src/client/AnimPlayer.luau#L112))

**ตำแหน่ง/ทิศตอนคีย์เฟรม:** root motion ที่ bake เป็นการเคลื่อนที่**สัมพัทธ์**จากจุดเริ่ม ไม่ใช่พิกัดโลกตายตัว — สิ่งที่สำคัญคือ**ทิศที่หัน** ณ เฟรมแรกให้ตรงกับตอนเล่นจริง (เช่น player หันเข้าประตู) ไม่ใช่พิกัด XY เป๊ะ — เล่นจริงจะสัมพัทธ์กับตำแหน่ง/ทิศของตัวจริง ณ ตอนนั้นเอง

**`StoryNPCPlacer` ไม่เกี่ยวกับตอน authoring** — เป็นระบบ runtime อย่างเดียว ขับด้วย `state.npcLoc` (server push) ไม่ทำงานตอนแก้ใน Edit mode และไม่รู้จัก `"player"` เป็น actor เลย (ระบบนี้คุมแค่ StoryNPC)

---

## 7. Object animation + ถือ prop + สลับของจริง/duplicate

3 step ใหม่ (field spec เต็ม → [cutscene.md §2](cutscene.md)) แก้ปัญหา "ต้องขยับของในแมพที่ไม่ใช่ตัวละคร" เช่น โล่รางวัล BCA หรือประตูที่ต้องเปิดเป็นส่วนหนึ่งของฉาก

### 7.1 `objAnim` — animate prop ไม่มีชีวิตตรงๆ

ใช้เมื่อ prop ต้องขยับ**เอง** (ฝาเปิด, บานหมุน) โดยไม่มีใครถือ — ใช้ pipeline เดียวกับ animation ตัวละครทุกอย่าง (`AnimationController` แทน `Humanoid`, Moon Animator ทำงานเหมือนกัน) ต้อง**rig prop ให้มี Motor6D ก่อน**:

1. เลือกใน Studio: ปุ่ม **Easy Weld** ของ Moon Animator (แปลง Weld ธรรมดาที่ต่อกันอยู่แล้วให้เป็น Motor6D อัตโนมัติ — ไม่ต้องสร้าง Motor6D มือ) เจอ **Clean** ล้าง Weld/RigAttachment เก่าทิ้งได้หลัง rig เสร็จ ไม่กระทบระบบเรา
2. เพิ่ม `AnimationController` เป็น**ลูกตรง**ของ prop model (`Humanoid` ก็ได้เหมือนกัน — โค้ดเช็คทั้งคู่ `AnimPlayer.animatorOf`)
3. Animate ปกติ export เป็น `Animation` เข้า `ReplicatedStorage.Animations` เหมือนท่าตัวละคร (ตั้งชื่อ prop = "actor" ในการค้นหา เช่น `ReplicatedStorage.Animations.TrophyBCA/Open`)

```lua
{ type = "objAnim", object = "TrophyBCA", name = "Open", loop = false }
```

### 7.2 `hold` / `unhold` — ถือ prop ติดมือ (โล่รางวัล, โทรศัพท์ ฯลฯ)

**ง่ายกว่า `objAnim` มาก — ใช้ทางนี้ก่อนถ้า prop แค่ต้อง "อยู่ในมือ" ไม่ต้องขยับเอง** (เช่นรับโล่ตอน BCA — แขน player ยกเอง ท่ามันก็ยกตามเอง ไม่ต้อง animate โล่เลย):

```lua
{ type = "hold", actor = "player", prop = "TrophyBCA" }   -- limb ไม่ใส่ = "Right Arm" (R6)
-- ... anim ท่ารับโล่เล่นต่อ, prop ติดมือไปเอง ...
{ type = "unhold", prop = "TrophyBCA" }                    -- ไม่เรียกเองก็ได้ auto-unhold ตอนจบฉาก
```

**ก่อนเรียก `hold`:** จัดตำแหน่ง prop ให้แนบมือ (ใน Studio, Edit mode) ไว้ก่อน — engine เก็บ**ตำแหน่งสัมพัทธ์ ณ ตอนเรียก** เป๊ะ ไม่มีค่า offset ให้ตั้งในโค้ด
**หลังฉากจบ prop จะปลดออกอัตโนมัติ** (คืนอิสระ ไม่ตามมือแล้ว) เว้นแต่ใส่ `persist = true` ที่ step `hold` (อยากให้ player ถือค้างต่อหลัง cutscene จบ)
prop เป็นได้ทั้ง **Part เดี่ยว** หรือ **Model** (มี `PrimaryPart` หรือไม่มีก็ได้ ระบบหา BasePart แรกที่เจอให้)

### 7.3 `visible` — สลับของจริงกับ duplicate สำหรับ animate

**ใช้เมื่อ object นั้นมี logic ของตัวเองอยู่แล้ว** (เช่นประตูที่กด E เปิด-ปิดได้ปกตินอกคัตซีน) — **ห้าม `objAnim` ตรงกับของจริง** เพราะ script เดิมมี state (`opened` ฯลฯ) ที่ไม่รู้จัก animation ของเรา จะ desync (ครั้งหน้ากด E จริงจะเปิดซ้ำ/มุมเพี้ยน)

**วิธีที่ปลอดภัย = duplicate แล้วสลับโชว์:**

1. Duplicate object จริง (เช่น `Door1`) → ตั้งชื่อ**ไม่ซ้ำทั้งโปรเจกต์** (`Door1` ซ้ำหลายที่ในแมพอยู่แล้ว — ห้ามซ้ำอีก) เช่น `FaasaiDoorCutscene`
2. **ลบ script/ProximityPrompt เดิมออกจาก duplicate** — เอาไว้แค่ mesh ล้วนๆ ไม่มี logic อะไรทั้งนั้น
3. Rig duplicate ด้วย Motor6D (Easy Weld) + `AnimationController` ตาม §7.1 แล้ว animate ปกติ
4. ในบท คัตซีน สลับโชว์ตอนเริ่ม/จบ:

```lua
{ type = "visible", target = "Door1", show = false },              -- ซ่อนของจริง
{ type = "visible", target = "FaasaiDoorCutscene", show = true },  -- โชว์ duplicate
{ type = "objAnim", object = "FaasaiDoorCutscene", name = "DoorOpen" },
{ type = "wait", t = 3 },
{ type = "visible", target = "FaasaiDoorCutscene", show = false }, -- ซ่อน duplicate
{ type = "visible", target = "Door1", show = true },               -- โชว์ของจริงกลับ (ปิดสนิทเหมือนเดิม — state ไม่เคยเปลี่ยน)
```

ของจริงไม่เคยถูกแตะเลยตลอด — ปลอดภัย 100% ไม่มีทาง desync ไม่ว่า script เดิมจะซับซ้อนแค่ไหน

---

## 8. ทดสอบด้วย Dev Console

ก่อนวาง anchor/cam ในแมพครบ ทดสอบเนื้อหาได้เลยผ่าน `/dev` (ดู [15-dev-console.md](../15-dev-console.md)):

```
/dev preview 4          -- เล่น Content.Cutscenes.PhaseTransitions[4] ตรงๆ (client-only)
/dev npcloc ฟ้าใส room  -- ทดสอบ StoryNPCPlacer ย้ายตัว (ต้องมี anchor Part ก่อน)
/dev tp 2                -- วาปไปแมพเฟส 2 ดู anchor/cam ที่วางไว้
```

---

## 9. ผิดแล้วเป็นยังไง

| ทำผิด | ผลลัพธ์ |
|---|---|
| `move` หา actor/Part ไม่เจอ | warn ใน Output, ข้าม step นั้น เล่นต่อ |
| `npcLoc` ตั้งชื่อ anchor ไม่ตรง (`NPCHome_<actor>_<loc>`) | warn "ไม่เจอ anchor", NPC ไม่ขยับ |
| `dialogue` step บทพัง (format ผิด) | `ScreenTransition.validateSteps` ฟ้อง error ชัดว่า step ไหน — ไม่เล่นทั้งฉาก |
| `text` step ไม่มี `text`/`t` | validate ฟ้องเหมือนกัน |
| `objAnim` หา prop ไม่เจอ/ไม่มี `AnimationController` | warn ใน Output, ไม่เล่น ไม่พัง |
| `objAnim` หาท่าไม่เจอใน `ReplicatedStorage.Animations` | warn ใน Output, ไม่เล่น ไม่พัง |
| `hold` หา actor/limb/prop ไม่เจอ | warn ใน Output, ไม่ผูก ไม่พัง |
| `visible` หา target ไม่เจอ (ชื่อผิด/ซ้ำกับตัวอื่นในแมพ) | warn ใน Output, ไม่ทำอะไร — เช็คชื่อ unique ทั้งโปรเจกต์ |
