-- Main.client — จุดเริ่มเดียวของ client: Remote + HUD + PC Screen + Interact + Dialogue + Ending
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
-- HUD/PCScreen/Apps/SavePanel อยู่ StarterGui.UI (รอ PlayerGui clone มาก่อน require)
-- DialogueUI/MenuUI/CutscenePlayer ยังอยู่ StarterPlayerScripts.UI (script.Parent.UI)
local StarterGuiUI = playerGui:WaitForChild("UI")
local HUD = require(StarterGuiUI.HUD)
local PCScreen = require(StarterGuiUI.PCScreen)
local SavePanel = require(StarterGuiUI.SavePanel)
local EditQTE = require(StarterGuiUI.Apps.EditQTE)
local Upload = require(StarterGuiUI.Apps.Upload)
local Feedback = require(StarterGuiUI.Apps.Feedback)
local Bank = require(StarterGuiUI.Apps.Bank)
local ShopKiosk = require(StarterGuiUI.Apps.ShopKiosk)
local Message = require(StarterGuiUI.Apps.Message)
local Manage = require(StarterGuiUI.Apps.Manage)
local DialogueUI = require(script.Parent.UI.DialogueUI)
local CutscenePlayer = require(script.Parent.UI.CutscenePlayer)
local MenuUI = require(script.Parent.UI.MenuUI)
local InteractBinder = require(script.Parent.InteractBinder)
local Audio = require(script.Parent.AudioService)
local RecordTool = require(script.Parent.RecordTool)
local RecordQTE = require(script.Parent.RecordQTE)
local CameraCart = require(script.Parent.CameraCart)
local CameraFocus = require(script.Parent.CameraFocus)
local ScreenTransition = require(script.Parent.ScreenTransition)
local StoryNPCPlacer = require(script.Parent.StoryNPCPlacer)
local NPCIndicator = require(script.Parent.NPCIndicator)
local AnimPlayer = require(script.Parent.AnimPlayer) -- หา rig NPC ให้กล้องเล็งตอน StoryBeat
local StoryBeat = require(script.Parent.StoryBeat)
local EndingSequence = require(script.Parent.EndingSequence)
local Notify = require(script.Parent.Notify)
local Config = require(RS.Shared.Config)
local Formulas = require(RS.Shared.Formulas)

local actionRemote = RS.Shared.Remotes.Action
local Content = RS.Shared.Content

local latestState = nil
-- ท่าปิดของ "Door Rig" ครั้งแรกที่เจอ — step swing หมุนสะสม ต้องคืนท่าปิดก่อนเริ่มฉากทุกรอบ
-- ระดับ module ไม่ใช่ใน handler (handler รันใหม่ทุก push จะจับท่าเปิดค้างมาเป็น "ปิด")
local closedDoorPivot = nil

local function fireAction(action)
	actionRemote:FireServer(action)
end

Audio.init(Players.LocalPlayer)
RecordTool.init(Players.LocalPlayer, fireAction, function() return latestState end)
CameraCart.init(Players.LocalPlayer, fireAction, function() return latestState end)

-- วงใต้เท้า + หันมองผู้เล่น · StoryNPC ต้องข้าม 2 กลุ่ม:
--   NPC_special_player = rig อ้างอิง export animation ไม่ใช่ NPC จริง
--   ฟ้าใส/เจียเจีย = StoryNPCPlacer ย้ายตาม npcLoc — NPCIndicator จะดึงกลับ basePivot เดิมทับระบบที่อยู่พัง
-- ⚠️ ชื่อไทยเป็น bare key ใน Lua ไม่ได้ ต้อง ["..."] เสมอ
local NPC_INDICATOR_SKIP = {
	NPC_special_player = true,
	["NPC_special_ฟ้าใส"] = true,
	["NPC_special_เจียเจีย"] = true,
}
NPCIndicator.attachAll(workspace.NPC.WorldNPC)
for _, m in workspace.NPC.StoryNPC:GetChildren() do
	if m:IsA("Model") and not NPC_INDICATOR_SKIP[m.Name] and m:FindFirstChildOfClass("Humanoid") then
		NPCIndicator.attach(m)
	end
end

-- รอแมพรอบจุดวาปใหม่ stream โหลดก่อน fade กลับ (StreamingEnabled) · anchor กันตกทะลุพื้นระหว่างรอ
local function waitStreamedAround(timeout)
	local char = Players.LocalPlayer.Character
	local lockRoot = char and char:FindFirstChild("HumanoidRootPart")
	local wasAnchored = lockRoot and lockRoot.Anchored or false
	if lockRoot then lockRoot.Anchored = true end
	task.wait(0.3) -- รอ teleport ของ server replicate ถึง client ก่อน (ไม่งั้น raycast เจอพื้นจุดเดิม)
	local t0, done = os.clock(), false
	repeat
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = { char }
			if workspace:Raycast(root.Position + Vector3.new(0, 5, 0), Vector3.new(0, -80, 0), rp) then
				done = true -- มีพื้นข้างล่าง = แมพโหลดแล้ว
			end
		end
		if not done then task.wait(0.1) end
	until done or os.clock() - t0 > (timeout or 6)
	if lockRoot and lockRoot.Parent then lockRoot.Anchored = wasAnchored end
	return done
end

-- ฉากเปิดเกม (cutscene mode 1) เล่นหลัง New Game → จบต่อ transition วาปเข้าห้องเฟส 1
local function playOpening()
	local Opening = require(Content.Cutscenes.Opening)
	fireAction({ type = "FreezeTime", on = true })
	CutscenePlayer.play(playerGui, Opening, function()
		ScreenTransition.play({
			onBlack = function()
				local char = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
				local root = char:FindFirstChild("HumanoidRootPart")
				fireAction({ type = "TeleportTo", target = "Spawn_Phase1" }) -- วาปที่ server (StreamingEnabled)
				-- คืนกล้องให้ player (เมนูตั้ง Scriptable ไว้ กล้องจะค้างถ้าไม่คืน)
				local cam = workspace.CurrentCamera
				cam.CameraSubject = char:FindFirstChildOfClass("Humanoid") or root
				cam.CameraType = Enum.CameraType.Custom
				waitStreamedAround(6) -- รอแมพเฟส 1 โหลดก่อน fade (กันเห็นห้องโล่ง)
			end,
			onDone = function()
				fireAction({ type = "FreezeTime", on = false })
				local hudGui = playerGui:FindFirstChild("Gui_HUD")
				if hudGui then hudGui.Enabled = true end
				local ring = workspace:FindFirstChild("FilmZoneRing")
				if ring then
					ring.Transparency = 0.7
					for _, b in ring:GetDescendants() do
						if b:IsA("BillboardGui") then b.Enabled = true end
					end
				end
			end,
		})
	end)
end

-- เสียงกดปุ่ม: ผูกที่เดียวให้ทุกปุ่ม — 1 คลิกจริง = 1 เสียง (ผูกใน fireAction จะดังตามจำนวน action)
-- attribute Sfx = ชื่อใน SoundService.SFX · Sfx = "none" = เงียบ
local soundBound = setmetatable({}, { __mode = "k" }) -- weak
local function bindClickSound(inst)
	if soundBound[inst] or not inst:IsA("GuiButton") then return end
	soundBound[inst] = true
	inst.Activated:Connect(function()
		local key = inst:GetAttribute("Sfx") or "ui_click"
		if key ~= "none" then Audio.sfx(key) end
	end)
end
for _, d in playerGui:GetDescendants() do bindClickSound(d) end
playerGui.DescendantAdded:Connect(bindClickSound)

HUD.init(playerGui)

-- ปุ่ม HUD: Setting เปิด/ปิดแผงตั้งค่า · Music สลับปิด/เปิดเพลง (เก็บลงเซฟ)
local MUTE_ICON = "rbxassetid://76621637786639"
local musicNormalImg = nil -- ไอคอนปกติ (เก็บไว้คืนเวลาเลิก mute)
local function refreshMuteIcon(muted)
	local root = playerGui:FindFirstChild("Gui_HUD") and playerGui.Gui_HUD:FindFirstChild("Root")
	local b = root and root:FindFirstChild("MusicButton")
	if b and musicNormalImg then b.Image = muted and MUTE_ICON or musicNormalImg end
end
local hudGui = playerGui:FindFirstChild("Gui_HUD")
local hudRoot = hudGui and (hudGui:FindFirstChild("Root") or hudGui)
if hudGui then
	local setBtn = hudRoot:FindFirstChild("SettingButton")
	if setBtn then
		setBtn.Activated:Connect(function()
			local panel = playerGui:FindFirstChild("SettingsGUI")
			local main = panel and panel:FindFirstChild("SettingsMain")
			if main then main.Visible = not main.Visible end
		end)
	end
	local musicBtn = hudRoot:FindFirstChild("MusicButton")
	if musicBtn then
		musicNormalImg = musicBtn.Image
		musicBtn.Activated:Connect(function()
			local muted = not Audio.isMusicMuted()
			Audio.setMusicMuted(muted)
			refreshMuteIcon(muted)
			fireAction({ type = "SetSetting", key = "musicMuted", value = muted })
		end)
	end
end

-- ซ่อน backpack/hotbar เวลามีหน้าต่างเต็มจอบัง (cutscene/บท/เมนู/คอม/ร้าน/ตัดคลิป/เตียง)
local StarterGui = game:GetService("StarterGui")
-- ปิดปุ่ม Reset ในเมนู Esc (เกมนี้ไม่มี fatal outcome) — reset ทำให้ Gui_HUD โดน ResetOnSpawn โคลนใหม่จาก StarterGui (เลขกลับเป็น mockup)
pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
local MODAL_GUIS = {
	Gui_Cutscene = true, Gui_Dialogue = true, Gui_MainMenu = true,
	Gui_ShopKiosk = true, Gui_EditQTE = true, Gui_BedMenu = true, Gui_PC = true,
	Gui_SavePanel = true, Gui_Transition = true,
}
local function refreshBackpack()
	local anyOpen = false
	for _, g in playerGui:GetChildren() do
		if MODAL_GUIS[g.Name] and (not g:IsA("ScreenGui") or g.Enabled) then
			anyOpen = true
			break
		end
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, not anyOpen)
end
-- modal บางตัว (Gui_PC, Gui_MainMenu) เป็น ScreenGui ถาวร เปิด/ปิดด้วย .Enabled → ChildAdded/Removed ไม่ยิง
-- ต้องฟัง .Enabled เพิ่ม (ไม่งั้นปิด PC แล้ว hotbar ไม่กลับ)
local function watchModal(g)
	if g:IsA("ScreenGui") and MODAL_GUIS[g.Name] then
		g:GetPropertyChangedSignal("Enabled"):Connect(refreshBackpack)
	end
end
for _, g in playerGui:GetChildren() do watchModal(g) end
playerGui.ChildAdded:Connect(function(g)
	watchModal(g)
	refreshBackpack()
end)
playerGui.ChildRemoved:Connect(refreshBackpack)
refreshBackpack()

-- เกมเริ่มที่เมนู (freeze จนกดเล่น) · onNewGame = เล่น intro · menuDeps reuse ตอนกลับเมนูหลัง ending
local menuDeps = { fireAction = fireAction, onNewGame = playOpening,
	getState = function() return latestState end }

-- ★ ตัวรับ StateChanged ตัวหลักอยู่ล่างไฟล์ — server push slotList (prefetch) มาก่อน client รันถึงตรงนั้น
--   push ที่มาก่อน connect = หายเงียบ → เมนูไม่เห็นเซฟ · ดักตั้งแต่ก่อนเปิดเมนู แล้วปลดตอนตัวหลักพร้อม
local earlyStateConn
earlyStateConn = RS.Shared.Remotes.StateChanged.OnClientEvent:Connect(function(state)
	latestState = state
	if MenuUI.updateSlots then MenuUI.updateSlots(state) end
end)

MenuUI.open(playerGui, menuDeps) -- seed slotList ที่ server prefetch มาแล้ว

-- ปุ่มเซฟมุมซ้ายล่าง + หน้าต่างเลือกช่อง (baked เป็น Gui_SaveButton/Gui_SavePanel) — SavePanel.init ผูก event ให้เอง
SavePanel.init(playerGui, { fireAction = fireAction, getState = function() return latestState end })

local pcDeps = {
	fireAction = fireAction,
	getState = function() return latestState end,
}

-- PC Screen — id ตรง key ใน UIAssets ("app_"..id) · ลำดับ = ลำดับไอคอนบน desktop
-- bank/message ซ่อนจนถึงเฟส 2 (Config.AppMinPhase) — คำนวณสดทุกครั้งที่เปิดจอ (ดู openPC)
local PC_APPS = {
	{ id = "shop", name = "upgrade", label = "🛒 Shop", external = function()
		ShopKiosk.open(playerGui, pcDeps)
	end },
	{ id = "edit", name = "edit", label = "✂️ ตัดคลิป", external = function()
		EditQTE.start(playerGui, fireAction, function() return latestState end)
	end },
	{ id = "upload", name = "upload", label = "⬆️ อัปโหลด", create = Upload.create },
	{ id = "feedback", name = "feedback", label = "📊 Feedback", create = Feedback.create },
	{ id = "bank", name = "bank", label = "🏦 Bank", create = Bank.create },
	{ id = "message", name = "message", label = "✉️ Message", create = Message.create },
	-- hidden = ไม่มี icon บน desktop เข้าผ่านปุ่มในแอป Bank เท่านั้น
	{ id = "manage", name = "พนักงาน", label = "👥 Manage", create = Manage.create, hidden = true },
}

-- fade ตัวผู้เล่นจาง↔ทึบ (LocalTransparencyModifier ไม่แตะ Transparency จริง) — ตอนเข้า/ออกบทคุย (ตัวเองบัง NPC)
local RunService = game:GetService("RunService")
local function fadePlayer(toTransparent: boolean, dur: number)
	local char = Players.LocalPlayer.Character
	if not char then return end
	local parts = {}
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
			table.insert(parts, d)
		end
	end
	local from = toTransparent and 0 or 1
	local to = toTransparent and 1 or 0
	task.spawn(function()
		local t0 = os.clock()
		while true do
			local a = math.clamp((os.clock() - t0) / dur, 0, 1)
			local v = from + (to - from) * a
			for _, d in parts do d.LocalTransparencyModifier = v end
			if a >= 1 then break end
			RunService.RenderStepped:Wait()
		end
	end)
end

-- กรองบรรทัดตามเงื่อนไข: ifSeen="X" (โชว์ถ้าเคยคุยจบ X) · ifNotSeen="X" — กรอง reply ในช้อยด้วย
local function filterConds(lines, seenTbl)
	local out = {}
	for _, item in lines do
		if type(item) ~= "table" then
			table.insert(out, item)
		else
			local ok = true
			if item.ifSeen and not (seenTbl and seenTbl[item.ifSeen]) then ok = false end
			if item.ifNotSeen and seenTbl and seenTbl[item.ifNotSeen] then ok = false end
			if ok then
				if item.choices then
					local it = table.clone(item)
					local chs = {}
					for _, c in item.choices do
						local c2 = table.clone(c)
						if c.reply then c2.reply = filterConds(c.reply, seenTbl) end
						table.insert(chs, c2)
					end
					it.choices = chs
					table.insert(out, it)
				else
					table.insert(out, item)
				end
			end
		end
	end
	return out
end

-- เล่นบทที่เตรียม lines มาแล้ว พร้อมชุดกล้อง/เอฟเฟกต์ของ engine คุย NPC (freeze → โฟกัสหัว + player จาง → typewriter → คืน)
-- แยกออกมาเพราะ StoryBeat ต้องใช้ชุดเดียวกันตอนบทต่อท้าย cutscene · head = Part ที่กล้องเล็ง (ไม่ส่ง = ไม่ขยับกล้อง)
local function runDialogue(lines, head, voiceName, onDone)
	fireAction({ type = "FreezeTime", on = true })
	if head then CameraFocus.focus(head) end
	-- บทที่ตั้งกล้องเอง (item.cam) = ช็อตกว้างเห็นทั้งคู่ → ไม่จางตัวผู้เล่น · บทปกติ = จาง (ตัวเองบัง NPC)
	local keepPlayerVisible = false
	for _, item in lines do
		if type(item) == "table" and item.cam then keepPlayerVisible = true break end
	end
	if not keepPlayerVisible then fadePlayer(true, 0.3) end
	DialogueUI.show(playerGui, lines, function(_, quit, teleportTarget)
		if not keepPlayerVisible then fadePlayer(false, 0.3) end
		if head then CameraFocus.release() end
		fireAction({ type = "FreezeTime", on = false })
		-- ช้อยที่มี .teleport (travel NPC) — วาปตอนบทจบจริงเท่านั้น (กดเลิกกลางคัน = ไม่วาป)
		if teleportTarget and not quit then
			fireAction({ type = "TeleportTo", target = teleportTarget })
			-- กลับจากแมพ 3.1 มาเฟส 3 หลังทรยศ = จุดชนวน betray cutscene (ตั้ง betray_ready)
			if teleportTarget == "Spawn_Phase3" and latestState and latestState.flags
				and latestState.flags.betrayed and not latestState.flags.betray_cutscene_done then
				fireAction({ type = "SetFlag", name = "betray_ready" })
			end
		end
		if onDone then onDone(quit) end
	end, voiceName)
end

-- คุย NPC: หา/เลือกบทตามเฟส+สถานะ แล้วส่งให้ runDialogue · interactPart = Part Interact_NPC (หา Head ให้กล้อง)
local function startDialogue(dialogueName, interactPart)
	local mod = Content.Dialogue:FindFirstChild(dialogueName)
	if not mod then
		warn("[Main.client] ไม่มีบท:", dialogueName)
		return
	end
	-- seen/locSeen/afterSeen = เคยคุยจบบทเต็มในโหมดนั้นแล้ว → เล่นบท repeat (แยกคีย์กัน)
	local seen = latestState and latestState.seenDialogue
		and latestState.seenDialogue[dialogueName] == latestState.phase
	local loc = latestState and latestState.npcLoc and latestState.npcLoc[dialogueName]
	-- ★ แก้ 12 ส.ค. (user: ไปสยามแล้วกลับไม่ได้) — เจียเจียมี 2 ตัวจริง: บ้าน (couch) + traveller ที่สยาม
	--   ทั้งคู่ใช้ Interact_NPC_เจียเจีย เหมือนกัน แต่คุยตัว traveller (ชื่อโมเดลลงท้าย _traveller) = บังคับ loc "siam"
	--   → ได้ byLoc.siam (มีช้อยกลับบ้าน) แทนบทบ้านที่ค้าง loc couch (เดิมโชว์บทบ้าน placeholder ที่สยาม = บั๊ก)
	if interactPart and interactPart.Parent and string.find(interactPart.Parent.Name, "traveller") then
		loc = "siam"
	end
	local locSeenKey = loc and (dialogueName .. "@" .. loc)
	local locSeen = locSeenKey and latestState and latestState.seenDialogue
		and latestState.seenDialogue[locSeenKey] == latestState.phase
	local afterSeenKey = dialogueName .. "@after"
	local afterSeen = latestState and latestState.seenDialogue
		and latestState.seenDialogue[afterSeenKey] == latestState.phase
	local lines = InteractBinder.pickLines(require(mod), latestState, seen, loc, locSeen, afterSeen)
	if not lines then
		warn("[Main.client] บทว่างสำหรับเฟสนี้:", dialogueName)
		return
	end
	lines = filterConds(lines, latestState and latestState.seenDialogue)
	local npc = interactPart and interactPart:FindFirstAncestorWhichIsA("Model")
	-- มีบรรทัดสั่ง cam เอง = ให้บทคุมกล้องเต็มที่ ไม่ zoom-หน้าอัตโนมัติชนกัน
	local usesCustomCam = false
	for _, item in lines do
		if type(item) == "table" and item.cam then usesCustomCam = true break end
	end
	local head = not usesCustomCam and npc and (npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart"))
	runDialogue(lines, head, dialogueName, function(quit)
		if not quit and locSeenKey and not locSeen then fireAction({ type = "DialogueSeen", name = locSeenKey }) end
		if not quit and not seen then fireAction({ type = "DialogueSeen", name = dialogueName }) end
		if not quit and latestState and latestState.flags and latestState.flags.betrayed and not afterSeen then
			fireAction({ type = "DialogueSeen", name = afterSeenKey })
		end
		-- Faasai park date: จบ byLoc.park.p → เด้งบทส่งท้ายทันที (เรียก runDialogue ตรงๆ ไม่ผ่าน StoryBeat ที่ห่อจอดำเสมอ)
		if not quit and dialogueName == "ฟ้าใส" and loc == "park" then
			local Faasai = require(mod)
			local farewellNpc = AnimPlayer.findRig("ฟ้าใส")
			local farewellHead = farewellNpc and (farewellNpc:FindFirstChild("Head") or farewellNpc:FindFirstChild("HumanoidRootPart"))
			runDialogue(Faasai.parkFarewell, farewellHead, "ฟ้าใส", function()
				-- loc="away" = ฟ้าใสหายจาก player จนกว่า jiajia_joined (settle ตั้ง loc="chair") · ต้องมี anchor NPCHome_ฟ้าใส_away
				fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "away" })
				fireAction({ type = "SetFlag", name = "faasai_park_dated" })
			end)
		end
	end)
end

-- state มาใหม่ทุกครั้ง: HUD + PC + menu + canon event + ending
local endingPlayed = false
local prevClips, primed = 0, false -- primed กัน state แรก/โหลดเซฟไม่ให้ยิงเสียง
local prevStaffClips, prevFollower, prevMoney = 0, 0, 0 -- toast ทีมลงคลิป / DM ปลดล็อก (เทียบ delta)
local prevRentMissed = 0
local prevSponsorOffer = false -- toast sponsor เด้งตอน false→true เท่านั้น
local appliedVolume = nil -- ระดับเสียงล่าสุดที่ apply จาก settings (กัน apply ทับตอน user ปรับ)
local appliedShadow, appliedMusicMuted = nil, nil
local appliedHideBillboards = nil
local appliedBus = {} -- ระดับเสียงแยกกลุ่มที่ apply จากเซฟล่าสุด
local prevPhase, phasePrimed = 1, false -- phasePrimed กันวาปข้ามเฟสเองตอน state แรก/โหลดเซฟ
local lastQTEId = nil -- dedupe pendingRecordQTE กัน push ซ้ำ retrigger
if earlyStateConn then earlyStateConn:Disconnect() end -- ตัวหลักพร้อมแล้ว ปลดตัวดักชั่วคราว
RS.Shared.Remotes.StateChanged.OnClientEvent:Connect(function(state)
	latestState = state
	HUD.update(state)

	-- preference จากเซฟ — apply เมื่อค่าเปลี่ยน (โหลดเซฟ) ไม่ทับตอน user ปรับเอง
	if state.settings and state.settings.volume and state.settings.volume ~= appliedVolume then
		appliedVolume = state.settings.volume
		Audio.setVolume(appliedVolume)
	end
	if state.settings and state.settings.shadow ~= nil and state.settings.shadow ~= appliedShadow then
		appliedShadow = state.settings.shadow
		game:GetService("Lighting").GlobalShadows = appliedShadow
	end
	-- ป้ายลอย: mirror ลง workspace Attribute ให้แผง Settings (LocalScript sandboxed อ่าน state ไม่ถึง)
	if state.settings and state.settings.hideBillboards ~= nil and state.settings.hideBillboards ~= appliedHideBillboards then
		appliedHideBillboards = state.settings.hideBillboards
		workspace:SetAttribute("HideBillboards", appliedHideBillboards)
	end
	if state.settings then
		for _, kv in { { "bgmVol", "bgm" }, { "sfxVol", "sfx" }, { "ambientVol", "ambient" } } do
			local v = state.settings[kv[1]]
			if v and v ~= appliedBus[kv[2]] then
				appliedBus[kv[2]] = v
				Audio.setGroupVolume(kv[2], v)
			end
		end
	end
	-- musicMuted apply หลัง bgmVol เสมอ (setMusicMuted จำ PreMute เป็นระดับ bgm ที่เพิ่ง apply)
	if state.settings and state.settings.musicMuted ~= nil and state.settings.musicMuted ~= appliedMusicMuted then
		appliedMusicMuted = state.settings.musicMuted
		Audio.setMusicMuted(appliedMusicMuted)
		refreshMuteIcon(appliedMusicMuted)
	end

	-- ของที่ไม่ joint-animate — ล่องหน/โผล่ตาม flag ล้วน · ฟ้าใส join เอากระเป๋า+คอมมาด้วย หายตอนทรยศ
	if state.flags then
		local faasaiJoined = state.flags.faasai_joined == true
		local betrayed = state.flags.betrayed == true
		local jiajiaJoined = state.flags.jiajia_joined == true
		-- flag faasai_joined ตั้งตอนเริ่ม trigger (กันยิงซ้ำ) — กระเป๋ารอ join เสร็จจริง (seenDialogue mark) ก่อนโผล่
		local faasaiJoinDone = state.seenDialogue and state.seenDialogue["ฟ้าใส"] ~= nil
		local function setVisible(name, show)
			local inst = workspace:FindFirstChild(name, true)
			if not inst then return end
			for _, p in inst:GetDescendants() do
				if p:IsA("BasePart") then
					p.Transparency = show and 0 or 1
					p.CanCollide = false
				end
			end
			if inst:IsA("BasePart") then inst.Transparency = show and 0 or 1; inst.CanCollide = false end
		end
		-- ★ แก้ 12 ส.ค. (user: "กระเป๋าฟ้าใสโผล่มาก่อนคัตซีน") — เดิมชื่อ "Handle1" ชนกับมือจับประตูทั่วแมพ
		--   (14 จุด!) FindFirstChild(deep) เลยไปจับมือจับประตูแทน กระเป๋าฟ้าใสจริงไม่เคยถูกโค้ดแตะ เห็นตลอด
		--   user เปลี่ยนชื่อกระเป๋าฟ้าใส (ชมพู) เป็น FaasaiBag_Bed แล้ว (อยู่ Workspace.Animation, unique ทั้งแมพ)
		--   ⚠️ คนละใบกับ "กระเป๋าพระเอก" (ดำ) = PlayerRoom.FashionBag ที่ต้องโผล่ตลอด — โค้ดนี้ห้ามแตะ FashionBag
		setVisible("FaasaiBag_Bed", faasaiJoinDone) -- กระเป๋าฟ้าใสที่เตียง (เฟส 2) โผล่หลัง cutscene+dialogue join จบ ค้างตลอดหลังจากนั้น
		-- ⚠️ "Handle2" ก็ชนซ้ำเหมือนกัน (30 จุด — มือจับประตู) แต่หาตัวจริง (กระเป๋าที่เก้าอี้ เฟส 3) ไม่เจอ
		--   ในแมพตอนนี้ (ไม่มี Part เดี่ยวๆ ใกล้เก้าอี้ที่ชื่อ Handle2/Handle เลย) — รอ user ชี้ตัวจริงก่อนแก้
		setVisible("Handle2", faasaiJoined and not betrayed) -- กระเป๋าที่เก้าอี้ (เฟส 3) หายตอนทรยศ — ยังบัคอยู่ ดูคอมเมนต์บน
		setVisible("Notebook", faasaiJoinDone and not betrayed) -- คอมที่เตียง (เฟส 2) โผล่หลัง join จบเหมือน Handle1 หายตอนทรยศ
		setVisible("MacbookChair", faasaiJoined and not betrayed) -- คอมที่เก้าอี้ (เฟส 3)
		setVisible("MacbookCouch", jiajiaJoined) -- คอมเจียเจีย ค้างตลอด (ยังไม่มีเงื่อนไขหาย)
	end

	-- โหลดเซฟ: วาปไปสปอว์นของเฟสตรงๆ + prime prevPhase กันเล่น cutscene ข้ามเฟส
	if state.spawnTarget then
		local target = state.spawnTarget
		prevPhase, phasePrimed = state.phase, true
		fireAction({ type = "ConsumeSpawn" })
		task.spawn(function()
			fireAction({ type = "TeleportTo", target = target })
			waitStreamedAround(6)
		end)
	end

	-- เสียงเหตุการณ์: อัปคลิปสำเร็จ / ไวรัล (ดูจาก state ที่เปลี่ยน)
	local uploaded = 0
	for _, c in state.clips do
		if c.uploaded then uploaded += 1 end
	end
	if primed and uploaded > prevClips then
		local last
		for _, c in state.clips do
			if c.uploaded then last = c end
		end
		Audio.sfx(last and last.viral and "viral" or "upload_done")
	end

	-- จ่ายค่าเช่าไม่ทัน/เงินหมด (flags.rentMissed เพิ่มตอนตัดรอบ) · tonumber กัน /dev flag ตั้ง boolean
	local rentMissed = tonumber(state.flags.rentMissed) or 0
	if primed and rentMissed > prevRentMissed then
		Audio.sfx("rent_missed")
	end
	prevRentMissed = rentMissed

	-- ทีม auto ลงคลิป → follower/เงินขึ้นเอง → toast แจ้ง (ไม่งั้นงงว่ามาจากไหน)
	local staffCount = #state.staffClips
	if primed and staffCount > prevStaffClips then
		local fDelta = state.follower - prevFollower
		if fDelta > 0 then Notify.gain(fDelta, math.max(0, state.money - prevMoney)) end
	end
	-- DM ปลดล็อกตามยอด → toast ครั้งเดียวตอนข้ามยอด
	if primed then
		for _, dm in require(Content.DMs) do
			local uf = dm.unlockFollower
			if uf and prevFollower < uf and state.follower >= uf then
				local preview = dm.lines and dm.lines[1]
					or (dm.exchanges and dm.exchanges[1] and dm.exchanges[1].npc)
				Notify.dm(dm.from, preview)
			end
		end
	end
	-- งาน sponsor เข้า → toast กดรับ · เด้งเฉพาะ false→true · ไม่เช็ค primed (โหลดเซฟที่มี offer ค้างก็ควรเห็น)
	if state.sponsorOffer and not prevSponsorOffer then
		Notify.sponsor(("×%d"):format(Config.SponsorBuffMult), function()
			fireAction({ type = "AcceptSponsor" })
		end)
	end
	prevSponsorOffer = state.sponsorOffer == true

	prevStaffClips, prevFollower, prevMoney = staffCount, state.follower, state.money
	prevClips, primed = uploaded, true
	if PCScreen.running and PCScreen.refresh then PCScreen.refresh(state) end
	if ShopKiosk.running and ShopKiosk.refresh then ShopKiosk.refresh(state) end -- ซื้อแล้วราคา/ระดับอัปทันที
	StoryNPCPlacer.apply(state)
	if MenuUI.updateSlots then MenuUI.updateSlots(state) end

	-- QTE ถ่ายคลิป (server ตั้ง pendingRecordQTE) → เล่น skill-check แล้วส่งเกรดกลับ · dedupe ด้วย id
	local qte = state.pendingRecordQTE
	local qid = qte and qte.id
	if qid and qid ~= lastQTEId and not RecordQTE.running
		and not DialogueUI.running and not CutscenePlayer.running then
		lastQTEId = qid
		local pMult, gMult = Formulas.qteZoneMult(state) -- ของกินที่ออกฤทธิ์ทำให้โซนกว้างขึ้น
		RecordQTE.start(playerGui, fireAction, qte.hits, { perfect = pMult, good = gMult })
	end

	-- canon event ค้างคิว → เล่นบทจาก CanonEvents แล้วแจ้ง server ว่าดูแล้ว
	local eventId = state.pendingEvents[1]
	if eventId and not DialogueUI.running and not CutscenePlayer.running then
		if eventId == Config.BCAEventId and state.flags.ending == "Good1" and not EndingSequence.running then
			endingPlayed = true
			fireAction({ type = "EventSeen", id = eventId })
			EndingSequence.playTrueEnding(playerGui, { fireAction = fireAction, getState = function() return latestState end, menuDeps = menuDeps })
		else
			local events = require(Content.CanonEvents)
			local ev = events[eventId]
			if ev then
				DialogueUI.show(playerGui, ev.dialogue, function()
					fireAction({ type = "EventSeen", id = eventId })
				end)
			else
				fireAction({ type = "EventSeen", id = eventId })
			end
		end
	end

	-- ข้ามเฟส: follower ทะลุ gate → phase เพิ่ม → จอดำ + วาปเข้าแมพเฟสใหม่ · รอบท+ฉากอื่นจบก่อน · ไม่ย้อนเฟส
	if not phasePrimed then
		prevPhase, phasePrimed = state.phase, true
	elseif state.phase < prevPhase then
		prevPhase = state.phase -- New Game / โหลดเซฟเฟสต่ำกว่า: sync เฉยๆ ไม่วาป
	elseif state.phase > prevPhase and not state.flags.ending
		and #state.pendingEvents == 0
		and not DialogueUI.running and not CutscenePlayer.running and not ScreenTransition.running then
		prevPhase = state.phase
		-- ปิด GUI โมดัลที่เปิดค้าง (คอม/ร้าน) ก่อนข้ามเฟส ไม่งั้นค้างบนจอหลังวาป
		if PCScreen.running and PCScreen.forceClose then PCScreen.forceClose() end
		if ShopKiosk.running and ShopKiosk.close then ShopKiosk.close() end
		local PhaseText = require(Content.Cutscenes.PhaseTransitions)
		local target = "Spawn_Phase" .. state.phase
		-- แทน [date] ด้วยจำนวนวัน ณ ตอนข้ามเฟส (clone กันแก้โมดูล content ที่ require ร่วม)
		local steps = PhaseText[state.phase]
		if steps then
			local subbed = {}
			for _, st in steps do
				if st.type == "text" and st.text and st.text:find("%[date%]") then
					local c = table.clone(st)
					c.text = st.text:gsub("%[date%]", tostring(state.day))
					table.insert(subbed, c)
				else
					table.insert(subbed, st)
				end
			end
			steps = subbed
		end
		fireAction({ type = "FreezeTime", on = true })
		ScreenTransition.play({
			steps = steps,
			onBlack = function()
				fireAction({ type = "TeleportTo", target = target })
				waitStreamedAround(6)
			end,
			onDone = function()
				fireAction({ type = "FreezeTime", on = false })
			end,
		})
	end

	-- faasai เข้าร่วม: follower ถึง threshold ในเฟส 2 → StoryBeat (เคาะประตู→นั่งเตียง) ครั้งเดียว
	if state.phase == 2 and state.follower >= Config.FaasaiJoinFollower
		and not state.flags.faasai_joined and not state.flags.ending
		and #state.pendingEvents == 0
		and not DialogueUI.running and not CutscenePlayer.running
		and not ScreenTransition.running and not StoryBeat.running then
		fireAction({ type = "SetFlag", name = "faasai_joined" }) -- mark กันยิงซ้ำ
		local FaasaiJoin = require(Content.Cutscenes.FaasaiJoin)
		local Faasai = require(Content.Dialogue["ฟ้าใส"])

		-- สลับประตูจริงกับ "Door Rig" (duplicate ไว้หมุนด้วย step swing) — ห้ามหมุนของจริง (script เดิมจำ opened/closed จะ desync)
		-- คืนของจริงตอน settle · หา Door Rig แบบ deep search (ถูกย้าย/สร้างใหม่หลายรอบ)
		local function swapDoor(showCutsceneDoor: boolean)
			local realDoor = workspace.Map.Map_Phase2.Playerhouse.PlayerRoom:FindFirstChild("PlayerRoomDoor1")
			local cutsceneDoor = workspace:FindFirstChild("Door Rig", true)
			if realDoor then
				for _, p in realDoor:GetDescendants() do
					if p:IsA("BasePart") then
						p.Transparency = showCutsceneDoor and 1 or 0
						p.CanCollide = not showCutsceneDoor
					end
				end
			end
			if cutsceneDoor then
				-- คืนบานให้ปิดสนิททุกครั้งที่เริ่ม (step swing หมุนสะสม เล่นซ้ำจะเปิดเกิน)
				if showCutsceneDoor then
					closedDoorPivot = closedDoorPivot or cutsceneDoor:GetPivot()
					cutsceneDoor:PivotTo(closedDoorPivot)
				end
				for _, p in cutsceneDoor:GetDescendants() do
					if p:IsA("BasePart") then
						p.Transparency = showCutsceneDoor and 0 or 1
						p.CanCollide = false -- duplicate ไม่มี logic ควบคุม ห้ามชน
					end
				end
			end
		end

		StoryBeat.play(playerGui, {
			-- จัดตำแหน่งทั้งคู่ก่อนคัตซีน ให้ตรงจุดเริ่ม root motion · วาป+รอ stream ก่อน SetNpcLoc เสมอ
			preStage = function()
				fireAction({ type = "TeleportTo", target = "NPCHome_Player_room" })
				waitStreamedAround(6)
				fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "room" })
				swapDoor(true)
			end,
			cutscene = FaasaiJoin,
			dialogue = Faasai.p2 or Faasai.p1, -- บทเฟส 2 (มาขอฝึกงาน)
			-- ใช้ engine คุยชุดเดียวกับกด prompt · ต้อง mark DialogueSeen เอง (ไม่ผ่าน startDialogue) ไม่งั้นคุยซ้ำได้ p2 เต็มตลอด
			runDialogue = function(lines, done)
				local npc = AnimPlayer.findRig("ฟ้าใส")
				local head = npc and (npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart"))
				runDialogue(lines, head, "ฟ้าใส", function(quit)
					if not quit then fireAction({ type = "DialogueSeen", name = "ฟ้าใส" }) end
					done()
				end)
			end,
			settle = function()
				fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "bed" })
				swapDoor(false)
			end,
			-- CutscenePlayer freeze ไว้ตอนเริ่ม caller ต้องปลดเอง (กันค้างแช่แข็งหลังจบ beat)
			onDone = function()
				fireAction({ type = "FreezeTime", on = false })
			end,
		})
	end

	-- faasai เดทที่สวน: follower ถึง FaasaiParkFollower ในเฟส 2 (เป็นเพื่อนแล้ว) → หายจากห้อง ไปสวน (ไม่มี cutscene นำ)
	if state.phase == 2 and state.follower >= Config.FaasaiParkFollower
		and state.flags.faasai_joined and not state.flags.faasai_park and not state.flags.ending
		and #state.pendingEvents == 0
		and not DialogueUI.running and not CutscenePlayer.running
		and not ScreenTransition.running and not StoryBeat.running then
		fireAction({ type = "SetFlag", name = "faasai_park" }) -- mark กันยิงซ้ำ
		fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "park" })
	end

	-- เจียเจียเข้าร่วม: follower ถึง joinFollower ของ companion_2 ในเฟส 3 → StoryBeat ครั้งเดียว
	-- threshold มาจาก Config.Staff.companions ที่เดียว (ตัวเดียวกับ StaffService — ไม่ตั้งเลขซ้ำ)
	if state.phase == 3 and state.follower >= Config.Staff.companions[2].joinFollower
		and not state.flags.jiajia_joined and not state.flags.ending
		and #state.pendingEvents == 0
		and not DialogueUI.running and not CutscenePlayer.running
		and not ScreenTransition.running and not StoryBeat.running then
		fireAction({ type = "SetFlag", name = "jiajia_joined" }) -- mark กันยิงซ้ำ
		local JiajiaJoin = require(Content.Cutscenes.JiajiaJoin)
		local Jiajia = require(Content.Dialogue["เจียเจีย"])

		StoryBeat.play(playerGui, {
			-- ฉากอยู่เฟส 3 ไกลจาก trigger — วาป+รอ stream ก่อน SetNpcLoc (ไม่งั้น anchor ยังไม่ stream StoryNPCPlacer หาไม่เจอ)
			preStage = function()
				fireAction({ type = "TeleportTo", target = "NPCHome_Player_jiajiajoin" })
				waitStreamedAround(6)
				fireAction({ type = "SetNpcLoc", actor = "เจียเจีย", loc = "jiajiajoin" })
				fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "jiajiajoin" })
			end,
			cutscene = JiajiaJoin,
			-- p3 = บทเต็มครั้งแรก · ต้อง mark DialogueSeen เอง ไม่งั้นคุยซ้ำได้ p3 เต็มตลอด
			dialogue = Jiajia.p3,
			runDialogue = function(lines, done)
				local npc = AnimPlayer.findRig("เจียเจีย")
				local head = npc and (npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart"))
				runDialogue(lines, head, "เจียเจีย", function(quit)
					if not quit then fireAction({ type = "DialogueSeen", name = "เจียเจีย" }) end
					done()
				end)
			end,
			-- ที่อยู่ถาวรเฟส 3: เจียเจีย=couch, ฟ้าใส=chair
			settle = function()
				fireAction({ type = "SetNpcLoc", actor = "เจียเจีย", loc = "couch" })
				fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "chair" })
			end,
			onDone = function()
				fireAction({ type = "FreezeTime", on = false })
			end,
		})
	end

	-- ฟ้าใสทรยศ: betrayed (500K) + กลับจากแมพ 3.1 (betray_ready) → cutscene ครั้งเดียว
	-- betray_ready ตั้งใน runDialogue ตอน travel NPC วาปกลับ Spawn_Phase3 ขณะ betrayed
	if state.phase == 3 and state.flags.betrayed
		and state.flags.betray_ready and not state.flags.betray_cutscene_done and not state.flags.ending
		and #state.pendingEvents == 0
		and not DialogueUI.running and not CutscenePlayer.running
		and not ScreenTransition.running and not StoryBeat.running then
		fireAction({ type = "SetFlag", name = "betray_cutscene_done" }) -- mark กันยิงซ้ำ
		local FaasaiBetray = require(Content.Cutscenes.FaasaiBetray)
		local Jiajia = require(Content.Dialogue["เจียเจีย"])

		StoryBeat.play(playerGui, {
			preStage = function()
				fireAction({ type = "TeleportTo", target = "NPCHome_Player_faasai_betray" })
				waitStreamedAround(6)
				fireAction({ type = "SetNpcLoc", actor = "เจียเจีย", loc = "faasai_betray" })
			end,
			cutscene = FaasaiBetray,
			-- ปฏิกิริยาครั้งเดียวต่อจากคัตซีน (betrayReact ไม่ใช่ .after ที่ pickLines เลือกทุกครั้งหลังจากนี้)
			-- ไม่ mark DialogueSeen (seenDialogue["เจียเจีย"] ถูก mark ตอน join แล้ว)
			dialogue = Jiajia.betrayReact,
			runDialogue = function(lines, done)
				local npc = AnimPlayer.findRig("เจียเจีย")
				local head = npc and (npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart"))
				runDialogue(lines, head, "เจียเจีย", function() done() end)
			end,
			settle = function()
				fireAction({ type = "SetNpcLoc", actor = "เจียเจีย", loc = "couch" }) -- กลับที่อยู่ถาวร (ฟ้าใสหายไปแล้ว)
			end,
			onDone = function()
				fireAction({ type = "FreezeTime", on = false })
			end,
		})
	end

	-- จบเกม → เล่น cutscene ending (ครั้งเดียว) → fade ดำ → กลับ main menu · รอ canon event ค้างจบก่อน
	if state.flags.ending and not endingPlayed
		and #state.pendingEvents == 0 and not DialogueUI.running then
		endingPlayed = true
		local endId = state.flags.ending
		local steps = require(Content.Endings[endId])
		CutscenePlayer.play(playerGui, steps, function()
			ScreenTransition.play({
				lines = { "[slow]— จบ — [normal](" .. endId .. ")" },
				onDone = function()
					-- คง endingPlayed=true กัน ending เล่นซ้ำวนขณะเมนูเปิด (flags.ending ยังตั้งอยู่)
					MenuUI.open(playerGui, menuDeps)
				end,
			})
		end)
	end
end)

InteractBinder.init({
	fireAction = fireAction,
	playerGui = playerGui,
	getState = function() return latestState end, -- ประตูเช็ค follower ก่อนปล่อยผ่าน
	openPC = function(screenPart)
		-- ซ่อน icon ที่ยังไม่ถึงเฟส (Config.AppMinPhase) — เช็คสดทุกครั้งที่เปิดจอ (แตะเฉพาะ bank/message ไม่ยุ่ง manage)
		for _, app in PC_APPS do
			if Config.AppMinPhase[app.id] then
				app.hidden = not Formulas.appUnlocked(latestState.phase, app.id)
			end
		end
		PCScreen.open(playerGui, pcDeps, PC_APPS, screenPart)
	end,
	openShop = function()
		ShopKiosk.open(playerGui, pcDeps)
	end,
	startDialogue = startDialogue,
})
