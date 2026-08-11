# Faasai Park Date Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ฟ้าใสหายจากห้องไปสวนสาธารณะที่ follower threshold ใหม่ → DM แจ้ง → player คุย 2 บทต่อกัน (บทหลัก `lock=true` คุยจบครบบทเดียว ห้ามเลิกคุยกลางคัน + บทส่งท้ายคุยจบแยกกลับห้อง) → ฟ้าใสวาปกลับห้องอัตโนมัติ

**Architecture:** เพิ่ม field ใหม่ 1 ตัว (`lock`) ในระบบบทคุย mode 2 (mirror หลักการ scan-all-lines เดียวกับ `cam`/`usesCustomCam`) + reuse `StoryBeat.play` เดิม (ไม่มี cutscene) เป็นตัว chain บทที่ 2 ต่อจากบทที่ 1 อัตโนมัติ + reuse `byLoc`/`SEATED_LOC`/DM-`unlockFollower` ทั้งหมดที่มีอยู่แล้ว

**Tech Stack:** Luau, Rojo live-sync ไป Roblox Studio, TestEZ-style assert ใน `tests/RunTests.luau` (รันจริงผ่าน `ServerScriptService.Tests.RunTests` ใน Play mode — ไม่มี local test runner ในเครื่องนี้ ดู Task 8)

**อ้างอิง spec:** `docs/superpowers/specs/2026-08-12-faasai-park-cutscene-design.md`

---

### Task 1: `Config.FaasaiParkFollower`

**Files:**
- Modify: `src/shared/Config.luau:40`
- Test: `tests/RunTests.luau` (เพิ่มใกล้ๆ ที่ทดสอบ Config อื่น — ใส่ต่อท้ายไฟล์ก่อนบรรทัด `print(...)`/`return {...}` สุดท้าย ดู Task 8 สำหรับตำแหน่งรวม)

- [ ] **Step 1: เขียนเทสที่ fail ก่อน**

เปิด `tests/RunTests.luau` หา anchor นี้ (ท้ายไฟล์ ก่อนบรรทัด `print(("Tests: %d passed...`):

```lua
print(("Tests: %d passed, %d failed"):format(pass, fail))
```

แทรกก่อนบรรทัดนั้น:

```lua
-- ===== Faasai Park Date — trigger threshold ใหม่ (12 ส.ค. 2569) =====
check("FaasaiParkFollower อยู่ระหว่าง FaasaiJoinFollower กับเกทเฟส 3 (100K)",
	Config.FaasaiParkFollower > Config.FaasaiJoinFollower and Config.FaasaiParkFollower < 100_000)
```

- [ ] **Step 2: ยืนยันว่า fail** (ตอนนี้ `Config.FaasaiParkFollower` เป็น `nil` — `nil > number` จะ error ไม่ใช่แค่ false)

รันผ่าน Roblox Studio MCP (`mcp__Roblox_Studio__execute_luau`, ต้อง Play mode + Rojo synced อยู่ก่อน — ดู Task 8 วิธีรันเต็ม) คาดว่า error `attempt to compare nil with number`

- [ ] **Step 3: เพิ่มค่าจริง**

`src/shared/Config.luau:40` ปัจจุบัน:
```lua
Config.FaasaiJoinFollower = 30_000
```
แก้เป็น:
```lua
Config.FaasaiJoinFollower = 30_000
Config.FaasaiParkFollower = 60_000 -- เดทที่สวน เฟส 2 (12 ส.ค.) — ตัวเลขชั่วคราว ไม่ใช่ค่าที่ล็อกใน docs/02, ปรับได้อิสระ
```

- [ ] **Step 4: รันเทสอีกรอบ ยืนยันผ่าน**

- [ ] **Step 5: Commit**

```bash
git add src/shared/Config.luau tests/RunTests.luau
git commit -m "feat(config): add FaasaiParkFollower threshold"
```

---

### Task 2: `lock` field — `DialogueUI.validate` type check

**Files:**
- Modify: `src/client/UI/DialogueUI.luau:178-179`
- Test: `tests/RunTests.luau:1160-1161` ใกล้ๆ

- [ ] **Step 1: เขียนเทสที่ fail ก่อน**

หา anchor ใน `tests/RunTests.luau`:
```lua
check("actor ไม่ใช่ string = ไม่ผ่าน", DialogueUI.validate({ { text = "ก", pose = "A", actor = true } }) == false)
```
เพิ่มต่อท้ายบรรทัดนั้น:
```lua
check("lock=true ผ่าน", DialogueUI.validate({ { speaker = "ฟ้าใส", text = "ก", lock = true } }) == true)
check("lock ไม่ใช่ boolean = ไม่ผ่าน", DialogueUI.validate({ { text = "ก", lock = "yes" } }) == false)
```

- [ ] **Step 2: ยืนยันว่า fail** — เคสแรกควรผ่านอยู่แล้ว (unknown field ไม่ทำให้ validate พัง) แต่เคสสอง (`lock = "yes"`) จะผ่านผิด (คืน `true` แทนที่จะเป็น `false`) เพราะยังไม่มีการเช็ค type

- [ ] **Step 3: เพิ่ม type check**

`src/client/UI/DialogueUI.luau:178-179` ปัจจุบัน:
```lua
		elseif item.cam ~= nil and type(item.cam) ~= "string" then
			return false, ("บรรทัด %d: cam ต้องเป็นชื่อ Part ใน CutsceneCams (string)"):format(i)
```
แก้เป็น (เพิ่ม elseif ใหม่ต่อท้าย):
```lua
		elseif item.cam ~= nil and type(item.cam) ~= "string" then
			return false, ("บรรทัด %d: cam ต้องเป็นชื่อ Part ใน CutsceneCams (string)"):format(i)
		elseif item.lock ~= nil and type(item.lock) ~= "boolean" then
			return false, ("บรรทัด %d: lock ต้องเป็น true/false (boolean)"):format(i)
```

- [ ] **Step 4: รันเทสอีกรอบ ยืนยันผ่านทั้งคู่**

- [ ] **Step 5: Commit**

```bash
git add src/client/UI/DialogueUI.luau tests/RunTests.luau
git commit -m "feat(dialogue): validate item.lock as boolean"
```

---

### Task 3: `lock` field — ซ่อนปุ่ม "เลิกคุย" ทั้งบท

**Files:**
- Modify: `src/client/UI/DialogueUI.luau:216-359`

ไม่มี unit test ส่วนนี้ได้ (`DialogueUI.show` สร้าง `Instance` จริงใน `PlayerGui` — ต้อง Studio runtime, RunTests.luau ไม่เคย test ฝั่ง `.show()` เลย มี test เฉพาะ `.validate()`/`.lineOf()` ที่เป็น pure function — ยึด convention เดิม) verify ด้วย playtest แทน (ดู Task 9)

- [ ] **Step 1: เพิ่ม scan ก่อนสร้าง UI**

`src/client/UI/DialogueUI.luau:216-224` ปัจจุบัน:
```lua
function DialogueUI.show(playerGui, lines, onDone, voiceName)
	if DialogueUI.running then return end
	local ok, err = DialogueUI.validate(lines)
	if not ok then
		warn("[DialogueUI] บทพัง:", err)
		return
	end
	DialogueUI.running = true
	if InteractLock then InteractLock.lock() end -- ปิด prompt + ล็อกเดินตลอดบท
```
แก้เป็น:
```lua
function DialogueUI.show(playerGui, lines, onDone, voiceName)
	if DialogueUI.running then return end
	local ok, err = DialogueUI.validate(lines)
	if not ok then
		warn("[DialogueUI] บทพัง:", err)
		return
	end
	-- item.lock (บรรทัดไหนก็ได้) = บทบังคับเล่นจนจบ ปิดปุ่ม "เลิกคุย" ทั้งบท
	-- สแกนก่อนสร้าง UI (หลักการเดียวกับ usesCustomCam ใน Main.client — เจอที่ไหนในบท มีผลทั้งบท)
	local locked = false
	for _, item in lines do
		if type(item) == "table" and item.lock then locked = true break end
	end
	DialogueUI.running = true
	if InteractLock then InteractLock.lock() end -- ปิด prompt + ล็อกเดินตลอดบท
```

- [ ] **Step 2: ห่อการสร้างปุ่มด้วย `if not locked`**

`src/client/UI/DialogueUI.luau:342-359` ปัจจุบัน:
```lua
	-- ปุ่มเลิกคุย มุมซ้ายบนใต้แถบหนัง — กดแล้วออกจากบทเลย **ไม่นับว่าคุยจบ** (ไม่ยิง DialogueSeen)
	local quit = false
	local quitBtn = Instance.new("TextButton")
	quitBtn.Name = "QuitButton"
	quitBtn.AnchorPoint = Vector2.new(0, 0)
	quitBtn.Position = UDim2.new(0, 24, 0.12, 10)
	quitBtn.Size = UDim2.fromOffset(120, 38)
	quitBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	quitBtn.BackgroundTransparency = 0.35
	quitBtn.TextColor3 = Color3.new(1, 1, 1)
	quitBtn.TextScaled = true
	quitBtn.Text = "← เลิกคุย"
	quitBtn:SetAttribute("Sfx", "ui_back")
	quitBtn.Parent = gui
	local quitCorner = Instance.new("UICorner")
	quitCorner.CornerRadius = UDim.new(0, 6)
	quitCorner.Parent = quitBtn
	quitBtn.Activated:Connect(function() quit = true end)
```
แก้เป็น:
```lua
	-- ปุ่มเลิกคุย มุมซ้ายบนใต้แถบหนัง — กดแล้วออกจากบทเลย **ไม่นับว่าคุยจบ** (ไม่ยิง DialogueSeen)
	-- locked = true (item.lock) → ไม่สร้างปุ่มเลย (quit ค้าง false ตลอด บทเดินต่อจนจบทางเดียว)
	local quit = false
	if not locked then
		local quitBtn = Instance.new("TextButton")
		quitBtn.Name = "QuitButton"
		quitBtn.AnchorPoint = Vector2.new(0, 0)
		quitBtn.Position = UDim2.new(0, 24, 0.12, 10)
		quitBtn.Size = UDim2.fromOffset(120, 38)
		quitBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		quitBtn.BackgroundTransparency = 0.35
		quitBtn.TextColor3 = Color3.new(1, 1, 1)
		quitBtn.TextScaled = true
		quitBtn.Text = "← เลิกคุย"
		quitBtn:SetAttribute("Sfx", "ui_back")
		quitBtn.Parent = gui
		local quitCorner = Instance.new("UICorner")
		quitCorner.CornerRadius = UDim.new(0, 6)
		quitCorner.Parent = quitBtn
		quitBtn.Activated:Connect(function() quit = true end)
	end
```

- [ ] **Step 3: Commit**

```bash
git add src/client/UI/DialogueUI.luau
git commit -m "feat(dialogue): item.lock hides quit button for forced dialogue"
```

---

### Task 4: doc — `dialogue.md` field reference

**Files:**
- Modify: `docs/engines/dialogue.md`

- [ ] **Step 1: เพิ่มแถวใน §7 ระดับ B**

หา table แถว `cam` (บรรทัด ~340):
```
| `cam` | ชื่อ Part กล้อง (`Workspace.CutsceneCams`, วางด้วย `CutsceneCamTool` ปุ่ม Place Cam) — ตัดกล้องไปจุดนั้น**ทันทีที่บรรทัดนี้ขึ้น** | ทุกบรรทัด — มีแม้ 1 บรรทัด = ปิด zoom-หน้าอัตโนมัติทั้งบท |
```
เพิ่มแถวใหม่ต่อท้าย:
```
| `lock` | `true` = ปิดปุ่ม "← เลิกคุย" **ทั้งบท** (บังคับเล่นจนจบทางเดียว ใช้กับบทหลักของฉากพิเศษ) | ทุกบรรทัด — มีแม้ 1 บรรทัด (`true`) = ปิดทั้งบท เหมือนหลักการ `cam` |
```

- [ ] **Step 2: เพิ่มโน้ตสั้นๆ ใกล้ๆ ส่วน `cam` ใน §2**

หลังย่อหน้า `cam` (บรรทัด ~45-47 ใน §2) เพิ่มย่อหน้าใหม่:
```markdown
**`lock` (เพิ่ม 12 ส.ค. 2569):** ใส่ `true` ในบรรทัดไหนก็ได้ (เหมือน `cam`) — ปิดปุ่ม "← เลิกคุย" ทั้งบทนั้น
ใช้กับบทที่ต้องคุยจนจบทางเดียว (เช่น main course ของฉากเดท) — ไม่มีทางออกกลางคัน `quit` จะเป็น `false` เสมอจนบทจบเอง
```

- [ ] **Step 3: Commit**

```bash
git add docs/engines/dialogue.md
git commit -m "docs(dialogue): document item.lock field"
```

---

### Task 5: `StoryNPCPlacer.luau` — `"park"` เข้า seated/no-raycast set

**Files:**
- Modify: `src/client/StoryNPCPlacer.luau:25,30`

ไม่มี unit test (ตารางเป็น local ภายในไฟล์ ไม่ export — `bed`/`couch`/`chair` เดิมก็ไม่มี test คลุมจุดนี้เหมือนกัน ยึด convention เดิม) verify ด้วย playtest (ต้องมี anchor `NPCHome_ฟ้าใส_park` + animation `IdlePark` ก่อนถึงเห็นผลจริง — งาน user ใน Task 9)

- [ ] **Step 1: แก้ทั้ง 2 ตาราง**

`src/client/StoryNPCPlacer.luau:25`:
```lua
local SEATED_LOC = { bed = true, couch = true, chair = true }
```
แก้เป็น:
```lua
local SEATED_LOC = { bed = true, couch = true, chair = true, park = true }
```

`src/client/StoryNPCPlacer.luau:30`:
```lua
local NO_RAYCAST_LOC = { jiajiajoin = true, bed = true, couch = true, chair = true }
```
แก้เป็น:
```lua
local NO_RAYCAST_LOC = { jiajiajoin = true, bed = true, couch = true, chair = true, park = true }
```

- [ ] **Step 2: Commit**

```bash
git add src/client/StoryNPCPlacer.luau
git commit -m "feat(npc-placer): park loc uses seated pose + trusted anchor"
```

---

### Task 6: เนื้อหา `ฟ้าใส.luau` — `byLoc.park` (lock) + `parkFarewell` (ใหม่)

**Files:**
- Modify: `src/shared/Content/Dialogue/ฟ้าใส.luau:138-151`
- Test: `tests/RunTests.luau` ใกล้บรรทัด 1298 (`ฟ้าใส มีครบ p1/p2/after`)

- [ ] **Step 1: เขียนเทสที่ fail ก่อน**

หา anchor ใน `tests/RunTests.luau`:
```lua
check("ฟ้าใส มีครบ p1/p2/after (arc ทรยศ)", f1.p1 ~= nil and f1.p2 ~= nil and f1.after ~= nil)
```
เพิ่มต่อท้ายบรรทัดนั้น:
```lua
check("ฟ้าใส byLoc.park.p มี lock=true (main course ห้ามเลิกคุย)",
	(function()
		for _, item in f1.byLoc.park.p do
			if type(item) == "table" and item.lock == true then return true end
		end
		return false
	end)())
check("ฟ้าใส มี parkFarewell (บทส่งท้ายหลัง park.p จบ)", f1.parkFarewell ~= nil and #f1.parkFarewell > 0)
check("parkFarewell บรรทัดแรก pose=Idle (ลุกจากท่านั่ง)",
	type(f1.parkFarewell[1]) == "table" and f1.parkFarewell[1].pose == "Idle")
```

- [ ] **Step 2: ยืนยันว่า fail** — 3 เคสใหม่ fail (`byLoc.park.p` ยังไม่มี `lock`, `parkFarewell` ยังไม่มี key)

- [ ] **Step 3: แก้เนื้อหาไฟล์บท**

`src/shared/Content/Dialogue/ฟ้าใส.luau:138-151` ปัจจุบัน:
```lua
		-- คุยที่สวนสาธารณะ (npcLoc="park" — ยังไม่มี trigger ตั้งค่านี้ ต้องเพิ่มทีหลัง)
		-- ⚠️ spicy ตามที่ขอ — เขียนแทนบรรทัด [placeholder] ได้เลย ห้ามลบ field cam (กล้องพัง ตกกลับไป zoom-หน้าเดิม)
		-- ตั้งชื่อ Part กล้องใน Workspace.CutsceneCams ผ่าน tools/CutsceneCamTool.plugin.luau (ปุ่ม Place Cam)
		-- แล้วใส่ชื่อ Part ที่ cam ตรงนี้ — ตัวอย่างเดาไว้ 2 ชื่อ ปรับตามที่วางจริง
		park = {
			p = {
				{ speaker = "ฟ้าใส", text = "[placeholder] ฟ้าใสชวนคุยที่สวนสาธารณะ ครั้งแรก", cam = "FaasaiPark_01" },
				{ speaker = "ฟ้าใส", text = "[placeholder] บรรทัดต่อไป — ตัดกล้องมุมอื่น", cam = "FaasaiPark_02" },
			},
			again = {
				{ speaker = "ฟ้าใส", text = "[placeholder] ฟ้าใสที่สวนสาธารณะ คุยซ้ำ", cam = "FaasaiPark_01" },
			},
		},
	},
}
```
แก้เป็น:
```lua
		-- คุยที่สวนสาธารณะ (npcLoc="park" — trigger = Config.FaasaiParkFollower ใน Main.client)
		-- ⚠️ main course spicy ตามที่ user ขอ — เขียนแทนบรรทัด [placeholder] ได้เลย
		--   ห้ามลบ field cam (กล้องพัง ตกกลับไป zoom-หน้าเดิม) ห้ามลบ lock=true (เปิดปุ่มเลิกคุยกลับมา ผิด flow ที่ตกลงกันไว้)
		-- ตั้งชื่อ Part กล้องใน Workspace.CutsceneCams ผ่าน tools/CutsceneCamTool.plugin.luau (ปุ่ม Place Cam)
		-- แล้วใส่ชื่อ Part ที่ cam ตรงนี้ — ตัวอย่างเดาไว้ 2 ชื่อ ปรับตามที่วางจริง
		park = {
			p = {
				{ speaker = "ฟ้าใส", text = "[placeholder] ฟ้าใสชวนคุยที่สวนสาธารณะ ครั้งแรก (main course)", cam = "FaasaiPark_01", lock = true },
				{ speaker = "ฟ้าใส", text = "[placeholder] บรรทัดต่อไป — ตัดกล้องมุมอื่น", cam = "FaasaiPark_02" },
			},
			-- เผื่ออนาคต (loc กลับมาเป็น park อีกรอบจากฉากอื่น) — เคสปกติเข้าไม่ถึง เพราะจบ park.p แล้ววาปกลับห้องทันที
			again = {
				{ speaker = "ฟ้าใส", text = "[placeholder] ฟ้าใสที่สวนสาธารณะ คุยซ้ำ", cam = "FaasaiPark_01" },
			},
		},
	},

	-- parkFarewell — บทส่งท้าย (ไม่ spicy) เด้งอัตโนมัติทันทีหลัง byLoc.park.p จบ (ดู StoryBeat chain ใน Main.client)
	-- ไม่ผ่าน pickLines/byLoc (top-level key ตรงๆ เหมือน Jiajia.p3 ที่ StoryBeat เรียกตรง) ไม่ต้องมี lock (คุยจบ/เลิกคุยได้ปกติ)
	-- บรรทัดแรกต้องมี pose="Idle" — ลุกจากท่านั่ง loop (IdlePark) มายืนคุยปกติ (field มีอยู่แล้ว ดู docs/engines/dialogue.md §2.5)
	parkFarewell = {
		{ speaker = "ฟ้าใส", text = "[placeholder] ลุกจากม้านั่ง — บทส่งท้ายก่อนแยกย้ายกลับห้อง", pose = "Idle" },
		"[placeholder] บทส่งท้ายต่อ ไม่ spicy",
	},
}
```

- [ ] **Step 4: รันเทสอีกรอบ ยืนยันผ่านทั้งหมด (รวม 3 เคสใหม่ + `ฟ้าใส มีครบ p1/p2/after` เดิมต้องยังผ่าน)**

- [ ] **Step 5: Commit**

```bash
git add src/shared/Content/Dialogue/ฟ้าใส.luau tests/RunTests.luau
git commit -m "content(dialogue): faasai park.p lock + parkFarewell skeleton"
```

---

### Task 7: DM ใหม่ — `DMs.luau`

**Files:**
- Modify: `src/shared/Content/DMs.luau`

Schema validate อัตโนมัติอยู่แล้ว (loop เช็คทุก entry ใน `tests/RunTests.luau:1505-1516`) — ไม่ต้องเขียนเทสใหม่ เพิ่ม entry ให้ตรง schema เดิมพอ (ดู test เดิม Task ก่อนหน้าเพื่อยืนยัน `from`/`lines` ยังผ่าน)

⚠️ **ตัวเลข hardcode ตรงนี้จงใจ ไม่ require Config** — `DMs.luau` ทั้งไฟล์ไม่มี `require` เลยสักตัว (pure return-table) แถวเดิมของ `Sponsor` ก็ hardcode `5_000` ตรงๆ ไม่อ้าง Config เหมือนกัน (rule 8 ของ CLAUDE.md: แก้ให้ตรงระบบเดิม อย่าสร้าง pattern ใหม่) → ตัวเลขต้องตรงกับ `Config.FaasaiParkFollower` (Task 1) **ด้วยมือ** ถ้าใน Task 1 เปลี่ยนเลข ต้องกลับมาแก้ตรงนี้ด้วย

- [ ] **Step 1: เพิ่ม entry**

`src/shared/Content/DMs.luau` ปัจจุบัน (ท้ายไฟล์):
```lua
	{ from = "Sponsor", unlockFollower = 5_000, exchanges = {
		{ npc = "สวัสดีครับ สนใจรับงานรีวิวสินค้าไหมครับ", choices = { "สนใจครับ!", "ขอคิดดูก่อน", "ไม่สนใจ" }, reply = "โอเคครับ รายละเอียดงานเดี๋ยวส่งให้ทางนี้นะครับ [placeholder]" },
	} },
}
```
แก้เป็น:
```lua
	{ from = "Sponsor", unlockFollower = 5_000, exchanges = {
		{ npc = "สวัสดีครับ สนใจรับงานรีวิวสินค้าไหมครับ", choices = { "สนใจครับ!", "ขอคิดดูก่อน", "ไม่สนใจ" }, reply = "โอเคครับ รายละเอียดงานเดี๋ยวส่งให้ทางนี้นะครับ [placeholder]" },
	} },
	{ from = "ฟ้าใส", unlockFollower = 60_000, -- ต้องตรงกับ Config.FaasaiParkFollower (Task 1) — hardcode ตาม convention entry อื่นในไฟล์นี้
		lines = { "[placeholder] มาเจอกันที่สวนหน่อยสิ" } }, -- user แก้คำเอง — เนื้อหา DM จริงไม่ล็อก (design doc §6)
}
```

- [ ] **Step 2: รันเทส DMs schema เดิมอีกรอบ ยืนยันผ่าน** (entry ใหม่ต้องผ่าน `DMs[N] มี from` / `มี lines หรือ exchanges`)

- [ ] **Step 3: Commit**

```bash
git add src/shared/Content/DMs.luau
git commit -m "content(dm): faasai park invite toast"
```

---

### Task 8: รันชุดเทสเต็มใน Studio (checkpoint ก่อนแตะ Main.client)

**Files:** ไม่มีไฟล์ใหม่ — checkpoint verification

- [ ] **Step 1:** เช็คกับ user ว่า Rojo connect อยู่ (rule 10 — plugin หลุดทุก restart Studio) ถ้าไม่ ให้ user กด Connect ก่อน (1 คลิก — อย่า automate)
- [ ] **Step 2:** ให้ Studio อยู่ใน Play mode (ถาม user กด Play ถ้ายังไม่ได้กด)
- [ ] **Step 3:** รันผ่าน `mcp__Roblox_Studio__execute_luau` (server context):
```lua
local R = require(game:GetService("ServerScriptService").Tests.RunTests)
return R
```
- [ ] **Step 4:** เช็คผลลัพธ์ `R.fail == 0` — ถ้ามี fail ดู `R.failures` แก้ก่อนไป Task 9 (ห้ามเชื่อว่า pass ถ้าไม่เห็นผลจริง — `superpowers:verification-before-completion`)

---

### Task 9: `Main.client.luau` — trigger block + chain hook

**Files:**
- Modify: `src/client/Main.client.luau:362-365` (chain hook)
- Modify: `src/client/Main.client.luau:650` (trigger block, แทรกหลัง FaasaiJoin block จบ)

ไม่มี unit test ส่วนนี้ (orchestration wiring — `faasai_joined`/`jiajia_joined` trigger เดิมก็ไม่มี test คลุมเหมือนกัน ดู grep ยืนยันใน spec) verify ด้วย playtest เต็ม flow (Task 10)

- [ ] **Step 1: เพิ่ม chain hook**

`src/client/Main.client.luau:362-365` ปัจจุบัน:
```lua
	runDialogue(lines, head, dialogueName, function(quit)
		if not quit and locSeenKey and not locSeen then fireAction({ type = "DialogueSeen", name = locSeenKey }) end
		-- กดเลิกคุย (quit) = ไม่นับว่าคุยจบ · คุยจบเต็มครั้งแรกของเฟสนี้ → จำไว้ (คุยซ้ำได้บท repeat)
		if not quit and not seen then fireAction({ type = "DialogueSeen", name = dialogueName }) end
	end)
```
แก้เป็น:
```lua
	runDialogue(lines, head, dialogueName, function(quit)
		if not quit and locSeenKey and not locSeen then fireAction({ type = "DialogueSeen", name = locSeenKey }) end
		-- กดเลิกคุย (quit) = ไม่นับว่าคุยจบ · คุยจบเต็มครั้งแรกของเฟสนี้ → จำไว้ (คุยซ้ำได้บท repeat)
		if not quit and not seen then fireAction({ type = "DialogueSeen", name = dialogueName }) end
		-- Faasai park date: จบ byLoc.park.p แบบไม่ quit (บังคับอยู่แล้วผ่าน lock=true) → เด้งบทส่งท้ายทันที
		-- ไม่มี cutscene/preStage — player+NPC อยู่ตำแหน่งเดิมที่สวนอยู่แล้ว StoryBeat แค่ห่อ dialogue+settle
		if not quit and dialogueName == "ฟ้าใส" and loc == "park" then
			local Faasai = require(mod)
			StoryBeat.play(playerGui, {
				dialogue = Faasai.parkFarewell,
				runDialogue = function(farewellLines, done)
					local npc = AnimPlayer.findRig("ฟ้าใส")
					local farewellHead = npc and (npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart"))
					runDialogue(farewellLines, farewellHead, "ฟ้าใส", function() done() end)
				end,
				settle = function()
					fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "room" })
					fireAction({ type = "SetFlag", name = "faasai_park_dated" })
				end,
			})
		end
	end)
```

- [ ] **Step 2: เพิ่ม trigger block**

`src/client/Main.client.luau:650` ปัจจุบัน (จบ FaasaiJoin `StoryBeat.play` block):
```lua
			onDone = function()
				fireAction({ type = "FreezeTime", on = false })
			end,
		})
	end

	-- เจียเจียเข้าร่วม: follower ถึง joinFollower ของ companion_2 ในเฟส 3 → StoryBeat ครั้งเดียว
```
แก้เป็น (แทรกบล็อกใหม่ระหว่าง `end` ของ FaasaiJoin กับ comment เจียเจีย):
```lua
			onDone = function()
				fireAction({ type = "FreezeTime", on = false })
			end,
		})
	end

	-- faasai เดทที่สวน: follower ถึง Config.FaasaiParkFollower ในเฟส 2 (ต้องเป็นเพื่อนร่วมทางแล้ว) → หายจากห้อง ไปสวน
	-- ไม่มี cutscene นำ (ต่างจาก faasai_joined) — แค่ flag+loc flip เงียบๆ แล้ว DM แจ้ง (Notify ผ่าน DMs.luau unlockFollower เดิม)
	if state.phase == 2 and state.follower >= Config.FaasaiParkFollower
		and state.flags.faasai_joined and not state.flags.faasai_park and not state.flags.ending
		and #state.pendingEvents == 0
		and not DialogueUI.running and not CutscenePlayer.running
		and not ScreenTransition.running and not StoryBeat.running then
		fireAction({ type = "SetFlag", name = "faasai_park" }) -- mark กันยิงซ้ำ
		fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "park" })
	end

	-- เจียเจียเข้าร่วม: follower ถึง joinFollower ของ companion_2 ในเฟส 3 → StoryBeat ครั้งเดียว
```

- [ ] **Step 3: Commit**

```bash
git add src/client/Main.client.luau
git commit -m "feat(faasai): park date trigger + forced farewell dialogue chain"
```

---

### Task 10: Playtest เต็ม flow + งาน user ใน Studio

**Files:** ไม่มีไฟล์โค้ด — checklist งาน Studio (rule 13: user คลิกเร็วกว่า agent — ไม่ automate)

- [ ] **Step 1 (user):** วาง `NPCHome_ฟ้าใส_park` ผ่าน `NpcAnchorTool` (actor=`ฟ้าใส`, loc=`park`) ที่จุดจริงในสวน
- [ ] **Step 2 (user):** อัปโหลด animation `IdlePark` ลง `ReplicatedStorage.Animations.ฟ้าใส` (ท่านั่ง loop)
- [ ] **Step 3 (user):** วาง `CutsceneCamTool` parts จริงแทน `FaasaiPark_01`/`FaasaiPark_02` (หรือชื่ออื่นถ้าเขียนบทแล้วเปลี่ยนชื่อ — ต้องตรงกับที่ใส่ใน `cam` field เป๊ะ)
- [ ] **Step 4 (user):** เขียนเนื้อหาจริงแทน `[placeholder]` ทั้ง `byLoc.park.p` (main course) และ `parkFarewell` (ส่งท้าย) — **ห้ามลบ `lock = true` ในบรรทัดแรกของ `park.p`** และ **ห้ามลบ `pose = "Idle"` ในบรรทัดแรกของ `parkFarewell`**
- [ ] **Step 5 (user):** กด Connect Rojo (ถ้าหลุด) + Play
- [ ] **Step 6 (agent, ถ้า user พร้อม):** ใช้ DevConsole/`SetFlag`/`SetFollower` (ดู `src/client/DevConsole.client.luau`) เร่ง follower ให้ถึง `Config.FaasaiParkFollower` โดยตรง แทนเล่นไล่จริง (เร็วกว่า)
- [ ] **Step 7:** เช็คด้วยตา (user ดูจอ เร็วกว่า agent screen_capture วนหลายรอบ — rule 13): DM เด้ง → ฟ้าใสหายจากห้อง → เจอที่สวนนั่ง loop → คุย `park.p` ไม่มีปุ่มเลิกคุย → จบปุ๊บ ลุกยืน คุย `parkFarewell` ต่อทันที (มีปุ่มเลิกคุยกลับมา) → จบ → ฟ้าใสหายจากสวน กลับไปโผล่ในห้อง
- [ ] **Step 8:** ถ้าตรงไหนพัง กลับไป `superpowers:systematic-debugging` — เช็ค live state ก่อนเดา (rule 6 ใน CLAUDE.md เดิม: เช็ค Rojo sync ก่อนแก้ logic)

---

## Self-review notes (เขียนตอน plan นี้เสร็จ)

- **Spec coverage:** ครบทุกข้อใน spec §3-§9 (Task 2-3=§3, Task 6=§4, Task 9=§5, Task 5=§6, Task 1=§7, Task 7=§8, Task 10=§9) §10 (out of scope) ไม่มี task ตรงกับที่ตั้งใจ — ถูกต้อง
- **Placeholder scan:** โค้ดทุก step มีเนื้อจริงครบ ไม่มี "TBD"/"เพิ่ม validation" ลอยๆ — เนื้อหาบทจริง (`[placeholder]` ข้อความ) เป็น **ของที่ user เขียนเอง ระบุชัดใน Task 10 Step 4** ไม่ใช่ placeholder ของแผนนี้
- **Type consistency:** `lock`/`locked` ใช้ชื่อเดียวกันตลอด (`item.lock` ข้อมูล → `locked` ตัวแปร local ใน `DialogueUI.show`) · `parkFarewell` สะกดเดียวกันทั้ง Task 6/9 · `faasai_park`/`faasai_park_dated` เป็นคนละ flag คนละหน้าที่ (กันยิง trigger ซ้ำ vs. mark จบเดทแล้ว) ใช้ตรงตามที่ spec §5 ระบุ
