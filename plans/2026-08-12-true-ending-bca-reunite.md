# True Ending (Good1) — BCA ceremony + Reunite cutscene

**Date:** 2026-08-12 · **User request:** flow ฉากจบ 2 ช่วง — (1) BCA part: cutscene รับรางวัล → บังคับเดินพรมแดง → fade ดำ → self-talk dialogue (player คุยกับตัวเอง หน้า player เองใน viewport ใส่ชุดสูท) → fade ดำเข้า PhaseTransitions[4] (2) Reunite part: fade ดำกลับมา → cutscene → จบ → main menu = True ending

## Decisions (confirmed with user)

1. **"บังคับเดินพรมแดง" = ปลดล็อค WASD ให้เดินเอง** ไม่ใช่สคริปต์คุมการเดิน — ศูนย์ engine ใหม่, เสี่ยงน้อยสุด, รองรับ touch device ได้ฟรี
2. **สเกลเต็มนี้ใช้เฉพาะ Good1 (True End)** — ending อื่น (Neutral1/Neutral2/Bad1-3) ยังใช้ path เดิมเป๊ะ (`CutscenePlayer.play(Endings[endId]) → "จบ" → MenuUI.open`) ไม่แตะ
3. **Shirt/Pants asset สูทมีแล้ว** — user จะให้ `rbxassetid` มาทีหลัง ใส่เป็นค่าว่างใน `Config` รอเติม (blocking content, ไม่ blocking โครงสร้าง)

## Root mechanism (reuse map — ทุกอย่างในนี้มีอยู่แล้ว ไม่คิดใหม่)

| ช่วง | ใช้ระบบเดิม | หลักฐาน |
|---|---|---|
| BCA award cutscene (กล้อง/anim/พิธีกร) | `CutscenePlayer.play` (`cam`/`text`/`anim`/`move`/`hold` steps) | `src/client/UI/CutscenePlayer.luau` — teammate วางกล้อง `CutsceneCams.BCA.BCA_11..21` ใน Studio อยู่แล้ว ตอนนี้ |
| พิธีกรงาน BCA (NPC ยืนที่ podium) | `StoryNPCPlacer` anchor `NPCHome_<actor>_<loc>` | teammate สร้าง `NPCHome_พิธีกร_bca` ไว้แล้ว — แค่ push `state.npcLoc["พิธีกร"]="bca"` |
| เดินพรมแดงเอง | ปลดล็อค WalkSpeed ปกติ (ไม่ freeze) + detect ถึงจุดหมาย | pattern เดียวกับ `waitStreamedAround` (poll ระยะ) ใน `Main.client.luau` — ใช้ซ้ำ ไม่เขียนใหม่ |
| self-talk คุยกับตัวเอง หน้า player เองใน viewport | `DialogueUI.show` กับ `{ speaker = "คุณ", ... }` | `DialogueUI.luau:432-435` — `speaker=="คุณ"` เรียก `AnimPlayer.findRig("player")` → `ModelViewport.showBust` อัตโนมัติอยู่แล้ว ไม่ต้องเขียนอะไรเพิ่ม |
| ชุดสูทระหว่างฉากนี้ | ใหม่ (เล็ก) — apply/restore `Shirt`/`Pants` | ไม่มี precedent ในโค้ด ต้องเขียนแต่เป็นฟังก์ชันสั้นๆ (ดู Changes #3) |
| fade ดำ → PhaseTransitions[4] | `ScreenTransition.play` | **`PhaseTransitions[4]` มีสตับอยู่แล้ว** (`src/shared/Content/Cutscenes/PhaseTransitions.luau:26-55`, comment "จาก BCA ไปหาพ่อแม่อีกครั้ง" จบด้วยบทเจียเจียชวนไป) — เนื้อหาตรงกับ flow นี้เป๊ะ ใช้ตามที่มี |
| Reunite cutscene | `CutscenePlayer.play` เหมือน BCA — ต้องมีกล้องชุดใหม่ `CutsceneCams.Reunite.*` | ยังไม่มีใครวาง — ใส่ในแผนให้ทีมสร้าง |
| จบ + กลับเมนู | `ScreenTransition.play({lines={"...จบ..."}}) → MenuUI.open` | path เดิมเป๊ะที่ใช้กับทุก ending วันนี้ (`Main.client.luau:812-818`) |

**ทำไมไม่ใช้ `StoryBeat.play`:** shape ของมันคือ `preStage→cutscene→dialogue→settle→onDone` (1 cutscene + 1 dialogue) — flow นี้มี **2 cutscene + phase-transition คั่นกลาง + ช่วงเดินอิสระ** ไม่พอดี shape เดิม เขียน orchestrator ใหม่ที่ hand-chain primitive เดิม (เหมือนที่ `playOpening()` ทำอยู่แล้วใน `Main.client.luau` — ไม่ใช่แพทเทิร์นใหม่)

## Changes

1. **`src/shared/Config.luau`** — เพิ่ม `Config.TrueEnding` ใกล้ `BCAEventId`:
   ```lua
   Config.TrueEnding = {
       suitShirtId = "", -- ⏳ รอ user ให้ rbxassetid
       suitPantsId = "", -- ⏳ รอ user ให้ rbxassetid
       walkTarget = "BCA_PodiumMark", -- Part ใน Workspace ที่ผู้เล่นต้องเดินไปถึง (ทีมวางในแมพ)
       walkTimeout = 30, -- กันค้างถ้าเดินหลงทาง
   }
   ```

2. **`src/client/EndingSequence.luau`** (ไฟล์ใหม่ — module เดียว กันบวม `Main.client.luau` ที่ยาวอยู่แล้ว) — export `EndingSequence.playTrueEnding(playerGui, deps)`:
   - รับ `deps = { fireAction, getState, playerGui, menuDeps }` (ตัดมาจาก scope ของ `Main.client.luau`)
   - ลำดับ (ตรง flow ที่ user อธิบายทุกจุด รวม fade ดำ 2 รอบ):
     1. `applySuit()` — **ใส่สูทตั้งแต่ก่อน cutscene เริ่ม** (user: "ตลอดทั้ง cutscene นี้จะใส่ชุดสูท" = ทั้ง BCA cutscene, ไม่ใช่แค่ตอน dialogue)
     2. `FreezeTime on` → `CutscenePlayer.play(BCAWalk)` (รับโล่ + พูดปิดงาน ตามที่วางกล้อง BCA_11-21 ไว้แล้ว)
     3. `FreezeTime off` (ปลดให้เดินเอง — ยังใส่สูทอยู่) → poll ระยะถึง `Config.TrueEnding.walkTarget` (ฟังก์ชัน `waitReachPoint`, เขียนใหม่ตาม pattern `waitStreamedAround`)
     4. ถึงจุดหมาย → `FreezeTime on` + **fade ดำสั้นๆ ก่อนเข้า dialogue** (`ScreenTransition.play({ onBlack = function() end, onDone = function() DialogueUI.show(playerGui, selfTalkLines, dialogueDone) end })` — ไม่ต้องมี steps/lines ยาว แค่ fade wrap ตามที่ user สั่ง "ถึง → fade ดำ → เข้า dialogue")
     5. `DialogueUI.show` จบ (บททุกบรรทัด `speaker="คุณ"`) → `ScreenTransition.play({steps = PhaseTransitions[4], onBlack=..., onDone=...})` (fade ดำเข้า transition ที่มีอยู่แล้ว)
     6. `CutscenePlayer.play(ReuniteSteps)` → `restoreSuit()` → `ScreenTransition.play({lines={"[slow]— จบ — [normal](Good1)"}, onDone = function() deps.fireAction({type="FreezeTime",on=false}); MenuUI.open(playerGui, deps.menuDeps) end})`
   - `applySuit()`/`restoreSuit()`: เก็บ `Shirt.ShirtTemplate`/`Pants.PantsTemplate` เดิมของ character ไว้ก่อนสวม คืนตอนจบ (pattern เดียวกับ `movedActors`/`heldProps` restore ที่มีอยู่แล้วใน `CutscenePlayer.luau:230-231,361-362`)
   - `waitReachPoint(targetName, timeout)`: poll `Heartbeat` เทียบระยะ `HumanoidRootPart.Position` กับ `workspace:FindFirstChild(targetName, true).Position` — โครงเดียวกับ `waitStreamedAround` ใน `Main.client.luau` เป๊ะ (ใกล้กว่า X studs = ถึงแล้ว)

3. **`src/client/Main.client.luau`**:
   - `require("./EndingSequence")` เพิ่มต้นไฟล์ (บรรทัดใกล้ require อื่นๆ ~L25-35)
   - แก้ pendingEvents-drain block (**L577-587**): ก่อนเรียก generic `CanonEvents[eventId]`, เช็คก่อน — `if eventId == Config.BCAEventId and latestState.flags.ending == "Good1" then endingPlayed = true; EndingSequence.playTrueEnding(playerGui, {...}); fireAction({type="EventSeen", id=eventId}); return` (ตั้ง `endingPlayed=true` กันบล็อก ending ทั่วไปที่ L805 ยิงซ้ำทีหลัง) — eventId อื่นหรือ ending อื่นตกลงไป path เดิมไม่แตะ

4. **`src/shared/Content/Cutscenes/BCAWalk.luau`** (ไฟล์ใหม่) — CutscenePlayer steps สำหรับ cutscene รับโล่ (ใช้กล้อง `BCA_11`..`BCA_21` ที่ทีมวางแล้ว) จบด้วยปล่อยกล้องคืน player ก่อน onDone (แพทเทิร์นเดียวกับ cutscene อื่นทุกไฟล์ใน `Content/Cutscenes/`)

5. **`src/shared/Content/Cutscenes/Reunite.luau`** (ไฟล์ใหม่) — ต้องมีกล้อง `Workspace.CutsceneCams.Reunite.*` ให้ทีมวางก่อน (ยังไม่มีใครวาง ณ ตอนนี้ — ต่างจาก BCA) — เนื้อหาต้องมีพ่อ/แม่ตาม design doc §8 ("พ่อแม่ต้องยังอยู่ใน ending cutscene ทุกอัน")

6. **`src/shared/Content/Dialogue/SelfTalkBCA.luau`** (ไฟล์ใหม่ — ไม่ใช่ NPC dialogue ปกติ ไม่ผ่าน `InteractBinder`/`pickLines` เรียกตรงจาก `EndingSequence`) — ทุกบรรทัด `speaker = "คุณ"` (โชว์หน้า player เองอัตโนมัติ) — `[placeholder]` รอ user เขียนบทจริง

7. **`src/shared/Content/Endings/Good1.luau`** — เปลี่ยนจาก placeholder เป็น comment ชี้ไปว่า endId นี้ไม่ผ่าน generic `CutscenePlayer.play` แล้ว (ถูก intercept ที่ pendingEvents "bca" ใน `Main.client.luau` แทน) กัน dev คนอื่นงงว่าทำไมไฟล์นี้ไม่ถูกอ่าน

8. **`docs/02-game-design-locked.md` §5** — เพิ่ม subsection สั้นๆ บันทึก mechanism นี้ (BCA canon event intercept เฉพาะ Good1) กัน design doc ตกยุคกับโค้ด

9. **`tests/RunTests.luau`** — เทส pure logic: `EndingSequence` ควรแยกฟังก์ชัน pure ออกมาให้เทสได้อย่างน้อย 1 จุด (เสนอ: แยก `EndingSequence.reachedTarget(playerPos, targetPos, threshold): boolean` เป็น pure function แทนที่จะฝังใน `waitReachPoint` — เทส boundary เหมือน `InteractBinder.labelAlpha` ที่มีอยู่แล้ว)

## ของที่ต้องให้ทีมทำใน Studio (ไม่ใช่โค้ด)

- Part ชื่อ `BCA_PodiumMark` (จุดหมายปลายทางพรมแดง) — ทีมช่วยวางในแมพ BCA
- `Workspace.CutsceneCams.Reunite.Reunite_01`..`Reunite_06` — กล้อง cutscene reunite (ยังไม่มี ต่างจาก BCA ที่ tanxddddd วางแล้ว — ชื่อ 6 ตัวนี้ตัดสินใจระหว่าง implement แล้ว ตาม convention `<Scene>_<NN>`)
- NPC พ่อ/แม่ วางที่ anchor สำหรับฉาก reunite — `NPCHome_พ่อ_reunite` / `NPCHome_แม่_reunite` / `NPCHome_Player_reunite` (3 anchor ตาม convention `NPCHome_<actor>_<loc>` เดิม — ตัดสินใจระหว่าง implement แล้วเช่นกัน)
- Shirt/Pants asset id สูท → ใส่ใน `Config.TrueEnding` (รอ user)
- เนื้อหาบทจริงแทน `[placeholder]` ใน `BCAWalk.luau`/`Reunite.luau`/`SelfTalkBCA.luau`

## Verification

- lune: `EndingSequence.reachedTarget` boundary test (pure, ไม่ต้อง Studio)
- Studio: ต้องรอ Rojo reconnect + `BCA_PodiumMark`/Reunite cams วางจริงก่อนถึง playtest ได้เต็ม flow — ระหว่างนี้ verify แค่โค้ด compile + pendingEvents branch logic ด้วย `execute_luau` (ปลอม `state.flags.ending="Good1"` + `pendingEvents={"bca"}` เช็คว่า intercept ทำงานไม่ตกไป generic path)
- Manual playtest เต็ม flow ต้องรอเนื้อหาจริง (กล้อง/บท/asset) ครบก่อน — เขียนโค้ดให้แล้วแต่เทสภาพจริงยังทำไม่ได้จนกว่าของจาก Studio/user มาครบ

## Out of scope (flagged, ไม่ทำตอนนี้)

- Neutral2 (อีก ending ที่ได้ "เต็ม" grade ตาม design doc §5) ยังไม่มี flow คู่ขนาน — ถ้าจะทำทีหลัง โครง `EndingSequence` นี้ reuse ได้ (แค่เขียน cutscene/บทชุดใหม่ ไม่ต้องแก้ engine)
- ตัด mini-game/debate ตาม scope discipline ใน CLAUDE.md — ฉากนี้ไม่มี interactive check ระหว่างเดิน (แค่เดินไปเฉยๆ)
- travel NPC round-trip loophole (คุยกับเจียเจีย ณ Map_phase3-1 ต้องมีทางกลับ) — ไม่เกี่ยวกับฟีเจอร์นี้ ยกมาจาก session ก่อนหน้า ยังไม่ได้แก้

## Implementation status (12 ส.ค. 2569 — ปิด 7/7 task ผ่าน subagent-driven-development)

ทุก task (1-7 ด้านบน) เสร็จแล้วใน branch `worktree-true-ending-bca-reunite` (git worktree `.claude/worktrees/true-ending-bca-reunite`) — โค้ด/โครงสร้างพร้อม แต่**ยังเล่นจริงไม่ได้**จนกว่าจะมีของจาก "ของที่ต้องให้ทีมทำใน Studio" ด้านบนครบ (asset สูท, Reunite cams, NPC anchors, เนื้อหาบทจริงแทน `[placeholder]`) — ดู commit log ของ branch นี้สำหรับรายละเอียดการ review แต่ละ task
