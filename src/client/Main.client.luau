-- Main.client.luau — จุดเริ่มเดียวของ client: Remote + HUD + PC Screen + Interact + Dialogue + Ending
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HUD = require(script.Parent.UI.HUD)
local PCScreen = require(script.Parent.UI.PCScreen)
local EditQTE = require(script.Parent.UI.Apps.EditQTE)
local Upload = require(script.Parent.UI.Apps.Upload)
local Feedback = require(script.Parent.UI.Apps.Feedback)
local Bank = require(script.Parent.UI.Apps.Bank)
local CalendarApp = require(script.Parent.UI.Apps.CalendarApp)
local ShopKiosk = require(script.Parent.UI.Apps.ShopKiosk)
local Message = require(script.Parent.UI.Apps.Message)
local Manage = require(script.Parent.UI.Apps.Manage)
local DialogueUI = require(script.Parent.UI.DialogueUI)
local CutscenePlayer = require(script.Parent.UI.CutscenePlayer)
local MenuUI = require(script.Parent.UI.MenuUI)
local SavePanel = require(script.Parent.UI.SavePanel)
local InteractBinder = require(script.Parent.InteractBinder)
local Audio = require(script.Parent.AudioService)
local RecordTool = require(script.Parent.RecordTool)
local CameraCart = require(script.Parent.CameraCart)
local CameraFocus = require(script.Parent.CameraFocus)
local ScreenTransition = require(script.Parent.ScreenTransition)
local StoryNPCPlacer = require(script.Parent.StoryNPCPlacer)
local Notify = require(script.Parent.Notify)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local actionRemote = RS.Shared.Remotes.Action
local Content = RS.Shared.Content

local latestState = nil

local function fireAction(action)
	actionRemote:FireServer(action)
end

Audio.init(Players.LocalPlayer) -- โซนเพลง + เสียงเดิน
RecordTool.init(Players.LocalPlayer, fireAction, function() return latestState end) -- Tool อัดคลิป + วงโซน
-- ระดับ 6: ไม่มี Tool ถือ — ขับรถเข็นกล้องแทน + คลิกอัดตอนนั่ง (Config.CameraCartLevel)
CameraCart.init(Players.LocalPlayer, fireAction, function() return latestState end)

-- รอให้แมพรอบจุดวาปใหม่ stream โหลดเข้า client ก่อน (StreamingEnabled ทำให้แมพไกลยังไม่โหลดตอนวาปถึง)
-- ใช้ตอนจอดำระหว่าง transition · anchor ตัวกันตกทะลุพื้นระหว่างรอ · มีพื้นข้างล่าง = โหลดแล้ว · timeout กันค้าง
local function waitStreamedAround(timeout)
	local char = Players.LocalPlayer.Character
	local lockRoot = char and char:FindFirstChild("HumanoidRootPart")
	local wasAnchored = lockRoot and lockRoot.Anchored or false
	if lockRoot then lockRoot.Anchored = true end -- กันตกทะลุพื้นก่อนแมพโหลด (server ยัง set CFrame วาปได้อยู่)
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

-- ฉากเปิดเกม (cutscene mode 1) เล่นหลังกด New Game → จบต่อ transition วาปเข้าห้องเฟส 1
local function playOpening()
	local Opening = require(Content.Cutscenes.Opening)
	fireAction({ type = "FreezeTime", on = true })
	CutscenePlayer.play(playerGui, Opening, function()
		ScreenTransition.play({
			onBlack = function()
				local char = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
				local root = char:FindFirstChild("HumanoidRootPart")
				-- วาปที่ server (StreamingEnabled อาจ stream Spawn_Phase1 ออกจาก client)
				fireAction({ type = "TeleportTo", target = "Spawn_Phase1" })
				-- คืนกล้องให้ player ตอนจอดำ — เมนูข้ามขั้นนี้ให้ new game และ CutscenePlayer
				-- คืนเป็น savedType ซึ่งตอนนั้นยังเป็น Scriptable (เมนูตั้งไว้) กล้องเลยค้าง
				local cam = workspace.CurrentCamera
				cam.CameraSubject = char:FindFirstChildOfClass("Humanoid") or root
				cam.CameraType = Enum.CameraType.Custom
				waitStreamedAround(6) -- รอแมพเฟส 1 โหลดก่อน fade กลับ (กันเห็นห้องโล่ง)
			end,
			onDone = function()
				fireAction({ type = "FreezeTime", on = false })
				-- เริ่มเล่นจริงหลัง intro: เปิด HUD + วงโซนถ่าย (เมนูข้ามให้ new game)
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

-- เสียงกดปุ่ม: ผูกที่เดียวให้ทุกปุ่มใน PlayerGui — **1 คลิกจริง = 1 เสียง**
-- (เดิมเล่นใน fireAction = ต่อ action ที่ยิง server ปุ่มเดียวยิง 2 action ก็ดัง 2 ที)
-- ปุ่มไหนอยากได้เสียงอื่น ตั้ง attribute `Sfx` = ชื่อใน SoundService.SFX · `Sfx = "none"` = เงียบ
-- ไม่มีไฟล์เสียงชื่อนั้น = เงียบ + warn ครั้งเดียว (ไม่พัง)
local soundBound = setmetatable({}, { __mode = "k" }) -- weak: ปุ่มโดนลบแล้วปล่อยหลุดเอง
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

-- ปุ่มบน HUD: Setting เปิด/ปิดแผงตั้งค่า (แผง toolbox StarterGui.SettingsGUI) · Music สลับปิด/เปิดเพลง (เก็บลงเซฟ)
local MUTE_ICON = "rbxassetid://76621637786639" -- ไอคอนตอนปิดเพลง
local musicNormalImg = nil -- ไอคอนปกติ (เก็บตอน wire ไว้คืนเวลาเลิก mute)
local function refreshMuteIcon(muted)
	local b = playerGui:FindFirstChild("Gui_HUD") and playerGui.Gui_HUD:FindFirstChild("MusicButton")
	if b and musicNormalImg then b.Image = muted and MUTE_ICON or musicNormalImg end
end
local hudGui = playerGui:FindFirstChild("Gui_HUD")
if hudGui then
	local setBtn = hudGui:FindFirstChild("SettingButton")
	if setBtn then
		setBtn.Activated:Connect(function()
			local panel = playerGui:FindFirstChild("SettingsGUI")
			local main = panel and panel:FindFirstChild("SettingsMain")
			if main then main.Visible = not main.Visible end
		end)
	end
	local musicBtn = hudGui:FindFirstChild("MusicButton")
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

-- ซ่อน backpack/hotbar เวลามีหน้าต่างเต็มจอบัง (cutscene/บทคุย/เมนู/คอม/ร้าน/ตัดคลิป/เตียง)
-- ที่เดียวคุมรวม: เฝ้า ScreenGui ชื่อพวกนี้โผล่/หายใต้ playerGui แล้ว toggle CoreGui.Backpack
local StarterGui = game:GetService("StarterGui")
local MODAL_GUIS = {
	Gui_Cutscene = true, Gui_Dialogue = true, Gui_MainMenu = true,
	Gui_ShopKiosk = true, Gui_EditQTE = true, Gui_BedMenu = true, Gui_PC = true,
	Gui_SavePanel = true,
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
-- modal บางตัว (Gui_PC, Gui_MainMenu) เป็น ScreenGui ถาวรใน StarterGui เปิด/ปิดด้วย .Enabled
-- ไม่ใช่ add/remove → ChildAdded/ChildRemoved ไม่ยิง → refreshBackpack ไม่ถูกเรียกตอนปิด
-- อาการ: ปิด PC แล้ว hotbar ไม่กลับมา = มือถือ "หาย" จาก inventory จนไปเปิด/ปิดแอปอื่น (สร้าง/ลบ ScreenGui)
-- → ต้องฟัง .Enabled ของ modal ScreenGui ทุกตัวเพิ่ม
local function watchModal(g)
	if g:IsA("ScreenGui") and MODAL_GUIS[g.Name] then
		g:GetPropertyChangedSignal("Enabled"):Connect(refreshBackpack)
	end
end
for _, g in playerGui:GetChildren() do watchModal(g) end
playerGui.ChildAdded:Connect(function(g)
	watchModal(g) -- modal ที่เพิ่ง add เข้ามา ก็ผูกฟัง Enabled ต่อไปด้วย
	refreshBackpack()
end)
playerGui.ChildRemoved:Connect(refreshBackpack)
refreshBackpack() -- ตั้ง hotbar ให้ตรงสถานะตั้งแต่เริ่ม

-- เกมเริ่มที่เมนู (freeze จนกดเล่น) · onNewGame = เล่น intro หลังเริ่มเกมใหม่
MenuUI.open(playerGui, { fireAction = fireAction, onNewGame = playOpening,
	getState = function() return latestState end }) -- seed slotList ที่ server prefetch มาแล้ว (ไม่ต้องรอ)

-- ปุ่มเซฟเล็กมุมซ้ายล่างระหว่างเล่น
local saveGui = Instance.new("ScreenGui")
saveGui.Name = "Gui_SaveButton"
saveGui.ResetOnSpawn = false
local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(0, 100, 0, 36)
saveBtn.Position = UDim2.new(0, 8, 1, -44)
saveBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
saveBtn.TextColor3 = Color3.new(1, 1, 1)
saveBtn.TextScaled = true
saveBtn.Text = "💾 เซฟ"
saveBtn:SetAttribute("Sfx", "save")
saveBtn.Parent = saveGui
saveGui.Parent = playerGui
saveBtn.Activated:Connect(function()
	SavePanel.open(playerGui, { fireAction = fireAction, getState = function() return latestState end })
end)

local pcDeps = {
	fireAction = fireAction,
	getState = function() return latestState end,
}

-- PC Screen (PDF หน้า 5 "UI PC") — id ตรง key ใน UIAssets ("app_"..id)
-- ★ ลำดับนี้ = ลำดับไอคอนบน desktop ตามภาพร่าง `ui screenshot/PC ui.png`
--   คอลัมน์ 1 (บนลงล่าง): upgrade(shop) · edit · upload · feedback · bank | คอลัมน์ 2: calendar · message
local PC_APPS = {
	-- upgrade บนคอม = เปิดหน้าร้านตัวเดียวกับร้านในแมพ (layout ตามภาพร่าง PDF หน้า 9 อยู่ที่ ShopKiosk)
	{ id = "shop", name = "upgrade", label = "🛒 Shop", external = function()
		ShopKiosk.open(playerGui, pcDeps)
	end },
	{ id = "edit", name = "edit", label = "✂️ ตัดคลิป", external = function()
		EditQTE.start(playerGui, fireAction, function() return latestState end)
	end },
	{ id = "upload", name = "upload", label = "⬆️ อัปโหลด", create = Upload.create },
	{ id = "feedback", name = "feedback", label = "📊 Feedback", create = Feedback.create },
	{ id = "bank", name = "bank", label = "🏦 Bank", create = Bank.create },
	{ id = "calendar", name = "calendar", label = "📅 ปฏิทิน", create = CalendarApp.create },
	{ id = "message", name = "message", label = "✉️ Message", create = Message.create },
	-- hidden = ไม่มี icon บน desktop (PDF มี 7 icon) — เข้าผ่านปุ่มในแอป Bank เท่านั้น
	{ id = "manage", name = "พนักงาน", label = "👥 Manage", create = Manage.create, hidden = true },
}

-- fade ตัวผู้เล่นจาง↔ทึบ (LocalTransparencyModifier — ไม่แตะค่า Transparency จริงของ rig)
-- ใช้ตอนเข้า/ออกบทคุย NPC: ตัวผู้เล่นบังหน้า NPC (หันหลังให้กล้อง) → จางออกตอนคุย กลับมาตอนจบ
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

-- กรองบรรทัดตามเงื่อนไข: ifSeen="X" (โชว์ถ้าเคยคุยจบ NPC X) · ifNotSeen="X" (โชว์ถ้ายังไม่เคย)
-- ใช้ทำบทที่เปลี่ยนตาม "เคยคุยกับใครมาก่อน" ข้ามตัวละคร — กรอง reply ในช้อยด้วย
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

-- คุย NPC: freeze เวลา → กล้องโฟกัส NPC + ตัวผู้เล่นจางหาย → typewriter → กลับมา + คืนกล้อง
-- interactPart = Part Interact_NPC ในโมเดล NPC (ใช้หา Head ให้กล้องเล็ง) — ไม่ส่งมา = ไม่ขยับกล้อง
local function startDialogue(dialogueName, interactPart)
	local mod = Content.Dialogue:FindFirstChild(dialogueName)
	if not mod then
		warn("[Main.client] ไม่มีบท:", dialogueName)
		return
	end
	-- เคยคุยจบบทเต็มในเฟสนี้แล้ว → เล่นบท repeat (docs/02 §9.4)
	local seen = latestState and latestState.seenDialogue
		and latestState.seenDialogue[dialogueName] == latestState.phase
	-- บทเปลี่ยนตามเฟส + หลังทรยศ + คุยซ้ำ
	local lines = InteractBinder.pickLines(require(mod), latestState, seen)
	if not lines then
		warn("[Main.client] บทว่างสำหรับเฟสนี้:", dialogueName)
		return
	end
	lines = filterConds(lines, latestState and latestState.seenDialogue) -- ตัดบรรทัด ifSeen/ifNotSeen ที่ไม่เข้าเงื่อนไข
	local npc = interactPart and interactPart:FindFirstAncestorWhichIsA("Model")
	local head = npc and (npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart"))
	fireAction({ type = "FreezeTime", on = true })
	-- กล้องโฟกัส NPC (tween ลื่นเอง) + ตัวผู้เล่นจางหายพร้อมกัน → เริ่มบท
	if head then CameraFocus.focus(head) end
	fadePlayer(true, 0.3)
	-- เสียงพิมพ์ใช้ SoundService.Voice.<ชื่อบท> (เช่น Voice.Friend1) — ไม่มี = Voice.Default
	DialogueUI.show(playerGui, lines, function(_, quit)
		-- จบ/เลิกคุย: ตัวผู้เล่นกลับมาทึบ + คืนกล้อง + unfreeze (ทุกกรณี)
		fadePlayer(false, 0.3)
		if head then CameraFocus.release() end
		fireAction({ type = "FreezeTime", on = false })
		-- กดเลิกคุย (quit) = ไม่นับว่าคุยจบ · คุยจบเต็มครั้งแรกของเฟสนี้ → จำไว้ (คุยซ้ำได้บท repeat)
		if not quit and not seen then fireAction({ type = "DialogueSeen", name = dialogueName }) end
	end, dialogueName)
end

-- state มาใหม่ทุกครั้ง: HUD + PC + menu + canon event + ending
local endingPlayed = false
local prevClips, primed = 0, false -- primed กัน state แรก/โหลดเซฟไม่ให้ยิงเสียง
local prevStaffClips, prevFollower, prevMoney = 0, 0, 0 -- toast ทีมลงคลิป / DM ปลดล็อก (เทียบ delta)
local appliedVolume = nil -- ระดับเสียงล่าสุดที่ apply จาก settings (กัน apply ทับตอน user ปรับ)
local appliedShadow, appliedMusicMuted = nil, nil -- เงา/ปิดเพลง: apply จากเซฟครั้งเดียว ไม่ทับตอน user สลับเอง
local appliedBus = {} -- ระดับเสียงแยกกลุ่ม bgm/sfx/ambient ที่ apply จากเซฟล่าสุด
local prevPhase, phasePrimed = 1, false -- phasePrimed กัน state แรก/โหลดเซฟไม่ให้วาปข้ามเฟสเอง
RS.Shared.Remotes.StateChanged.OnClientEvent:Connect(function(state)
	latestState = state
	HUD.update(state)

	-- ใช้ค่า preference จากเซฟ (เช่นระดับเสียง) — apply เมื่อค่าเปลี่ยน (โหลดเซฟ) ไม่ทับตอน user ปรับเอง
	if state.settings and state.settings.volume and state.settings.volume ~= appliedVolume then
		appliedVolume = state.settings.volume
		Audio.setVolume(appliedVolume)
	end
	if state.settings and state.settings.shadow ~= nil and state.settings.shadow ~= appliedShadow then
		appliedShadow = state.settings.shadow
		game:GetService("Lighting").GlobalShadows = appliedShadow
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
	-- musicMuted apply หลัง bgmVol เสมอ — setMusicMuted จะจำ PreMute เป็นระดับ bgm ที่เพิ่ง apply (ไม่ใช่ค่าเก่า)
	if state.settings and state.settings.musicMuted ~= nil and state.settings.musicMuted ~= appliedMusicMuted then
		appliedMusicMuted = state.settings.musicMuted
		Audio.setMusicMuted(appliedMusicMuted)
		refreshMuteIcon(appliedMusicMuted)
	end

	-- โหลดเซฟ: วาปไปสปอว์นของเฟสนั้นตรงๆ + prime prevPhase กันเล่น cutscene ข้ามเฟส (bug #4/#7)
	-- ทำก่อน phase logic ข้างล่าง (state เดียวกันถือทั้ง phase ใหม่ + spawnTarget → ไม่มี race)
	if state.spawnTarget then
		local target = state.spawnTarget
		prevPhase, phasePrimed = state.phase, true
		fireAction({ type = "ConsumeSpawn" })
		task.spawn(function()
			fireAction({ type = "TeleportTo", target = target })
			waitStreamedAround(6)
		end)
	end

	-- เสียงเหตุการณ์: อัปคลิปสำเร็จ / ไวรัล (ดูจาก state ที่เปลี่ยน ไม่ต้องมี remote เพิ่ม)
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

	-- ทีม/เพื่อนร่วมทาง auto ลงคลิป (produceDaily รายวัน) → follower/เงินขึ้นเอง → toast แจ้ง ไม่งั้นงงว่ามาจากไหน
	local staffCount = #state.staffClips
	if primed and staffCount > prevStaffClips then
		local fDelta = state.follower - prevFollower
		if fDelta > 0 then Notify.gain(fDelta, math.max(0, state.money - prevMoney)) end
	end
	-- DM ปลดล็อกตามยอด follower (ตั้ง unlockFollower ในก้อน DM) → toast ครั้งเดียวตอนข้ามยอด
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
	prevStaffClips, prevFollower, prevMoney = staffCount, state.follower, state.money
	prevClips, primed = uploaded, true
	if PCScreen.running and PCScreen.refresh then PCScreen.refresh(state) end
	if ShopKiosk.running and ShopKiosk.refresh then ShopKiosk.refresh(state) end -- ซื้อแล้วราคา/ระดับอัปทันที
	StoryNPCPlacer.apply(state) -- ย้าย StoryNPC ตาม npcLoc (ทำจริงเฉพาะตัวที่ loc เปลี่ยน)
	if MenuUI.updateSlots then MenuUI.updateSlots(state) end

	-- canon event ค้างคิว → เล่นบทจาก CanonEvents แล้วแจ้ง server ว่าดูแล้ว
	local eventId = state.pendingEvents[1]
	if eventId and not DialogueUI.running and not CutscenePlayer.running then
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

	-- ข้ามเฟส: follower ทะลุ gate → state.phase เพิ่ม → จอดำ + วาปเข้าแมพเฟสใหม่ (reuse ScreenTransition)
	-- รอบท milestone (pendingEvents) + ฉากอื่นให้จบก่อนค่อยย้ายที่ · ไม่ย้อนเฟส (ไม่วาปตอน phase ลด)
	if not phasePrimed then
		prevPhase, phasePrimed = state.phase, true
	elseif state.phase < prevPhase then
		prevPhase = state.phase -- New Game / โหลดเซฟเฟสต่ำกว่า: sync เฉยๆ ไม่วาป
	elseif state.phase > prevPhase and not state.flags.ending
		and #state.pendingEvents == 0
		and not DialogueUI.running and not CutscenePlayer.running and not ScreenTransition.running then
		prevPhase = state.phase
		-- ปิด GUI โมดัลที่เปิดค้าง (คอม/ร้าน) ก่อนข้ามเฟส ไม่งั้นค้างบนจอหลังวาป (bug: ปลดล็อกตอนใช้คอม)
		if PCScreen.running and PCScreen.forceClose then PCScreen.forceClose() end
		if ShopKiosk.running and ShopKiosk.close then ShopKiosk.close() end
		local PhaseText = require(Content.Cutscenes.PhaseTransitions)
		local target = "Spawn_Phase" .. state.phase
		fireAction({ type = "FreezeTime", on = true })
		ScreenTransition.play({
			lines = PhaseText[state.phase],
			onBlack = function()
				fireAction({ type = "TeleportTo", target = target })
				waitStreamedAround(6) -- รอแมพเฟสใหม่โหลดก่อน fade กลับ
			end,
			onDone = function()
				fireAction({ type = "FreezeTime", on = false })
			end,
		})
	end

	-- จบเกม → เล่น cutscene ending (ครั้งเดียว) — รอ canon event ค้างให้จบก่อน (เช่น BCA หลัง 1M)
	if state.flags.ending and not endingPlayed
		and #state.pendingEvents == 0 and not DialogueUI.running then
		endingPlayed = true
		local steps = require(Content.Endings[state.flags.ending])
		CutscenePlayer.play(playerGui, steps, function()
			DialogueUI.show(playerGui, { "[slow]— จบ — [normal](" .. state.flags.ending .. ")" })
		end)
	end
end)

InteractBinder.init({
	fireAction = fireAction,
	playerGui = playerGui,
	getState = function() return latestState end, -- ประตูใช้เช็ค follower ก่อนปล่อยผ่าน (docs/02 §9.9)
	openPC = function(screenPart) -- Interact_pcMonitor = zoom เข้าจอ | Interact_Camera เก่า = เปิดเฉยๆ
		PCScreen.open(playerGui, pcDeps, PC_APPS, screenPart)
	end,
	openShop = function() -- ร้านในแมพ (Interact_Shop) — คนละอันกับแอป Shop บนจอคอม
		ShopKiosk.open(playerGui, pcDeps)
	end,
	startDialogue = startDialogue,
})
