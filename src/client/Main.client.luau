-- Main.client.luau — จุดเริ่มเดียวของ client: Remote + HUD + PC Screen + Interact + Dialogue + Ending
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
-- ★ HUD/PCScreen/Apps/SavePanel ย้ายไปอยู่ StarterGui.UI (9 ส.ค. — คุมเรื่องคอม/HUD/แอปในคอม/เซฟรวมที่เดียว)
--   ต้องรอ PlayerGui clone จาก StarterGui มาก่อนถึง require ได้ (WaitForChild กันจังหวะ join ยังไม่ทัน)
--   DialogueUI/MenuUI/CutscenePlayer ยังอยู่ StarterPlayerScripts.UI เดิม (script.Parent.UI)
local StarterGuiUI = playerGui:WaitForChild("UI")
local HUD = require(StarterGuiUI.HUD)
local PCScreen = require(StarterGuiUI.PCScreen)
local SavePanel = require(StarterGuiUI.SavePanel)
local EditQTE = require(StarterGuiUI.Apps.EditQTE)
local Upload = require(StarterGuiUI.Apps.Upload)
local Feedback = require(StarterGuiUI.Apps.Feedback)
local Bank = require(StarterGuiUI.Apps.Bank)
-- ★ CalendarApp ถูกพับไว้ 9 ส.ค. (user) — sponsor ย้ายไปเป็น toast กดรับ (Notify.sponsor + SponsorService)
--   ไฟล์ CalendarApp.luau ยังอยู่ครบ · จะรื้อกลับ = require ตรงนี้ + ใส่ entry คืนใน PC_APPS
local ShopKiosk = require(StarterGuiUI.Apps.ShopKiosk)
local Message = require(StarterGuiUI.Apps.Message)
local Manage = require(StarterGuiUI.Apps.Manage)
local DialogueUI = require(script.Parent.UI.DialogueUI)
local CutscenePlayer = require(script.Parent.UI.CutscenePlayer)
local MenuUI = require(script.Parent.UI.MenuUI)
local InteractBinder = require(script.Parent.InteractBinder)
local Audio = require(script.Parent.AudioService)
local RecordTool = require(script.Parent.RecordTool)
local RecordQTE = require(script.Parent.RecordQTE) -- skill-check ตอนถ่ายคลิป (server สุ่ม 2%)
local CameraCart = require(script.Parent.CameraCart)
local CameraFocus = require(script.Parent.CameraFocus)
local ScreenTransition = require(script.Parent.ScreenTransition)
local StoryNPCPlacer = require(script.Parent.StoryNPCPlacer)
local NPCIndicator = require(script.Parent.NPCIndicator) -- วงใต้เท้า + หันมองผู้เล่น (12 ส.ค. เปิดใช้)
local AnimPlayer = require(script.Parent.AnimPlayer) -- หา rig NPC ให้กล้องเล็งตอน StoryBeat คุยอัตโนมัติ
local StoryBeat = require(script.Parent.StoryBeat)
local Notify = require(script.Parent.Notify)
local Config = require(RS.Shared.Config) -- ตัวคูณ buff sponsor ที่โชว์บน toast (ตัวเลขมาจาก Config ที่เดียว)
local Formulas = require(RS.Shared.Formulas) -- qteZoneMult: ของกินที่ออกฤทธิ์ทำให้โซน QTE กว้างขึ้น

local actionRemote = RS.Shared.Remotes.Action
local Content = RS.Shared.Content

local latestState = nil
-- ท่าปิดของ "Door Rig" ครั้งแรกที่เจอ — step swing หมุนสะสม ต้องคืนท่าปิดก่อนเริ่มฉากทุกรอบ
-- ระดับ module ไม่ใช่ใน handler เพราะ handler รันใหม่ทุก state push (จะจับท่าเปิดค้างมาเป็น "ปิด")
local closedDoorPivot = nil

local function fireAction(action)
	actionRemote:FireServer(action)
end

Audio.init(Players.LocalPlayer) -- โซนเพลง + เสียงเดิน
RecordTool.init(Players.LocalPlayer, fireAction, function() return latestState end) -- Tool อัดคลิป + วงโซน
-- ระดับ 6: ไม่มี Tool ถือ — ขับรถเข็นกล้องแทน + คลิกอัดตอนนั่ง (Config.CameraCartLevel)
CameraCart.init(Players.LocalPlayer, fireAction, function() return latestState end)

-- วงใต้เท้า + หันตัวมองผู้เล่น — NPC ทั่วไป (WorldNPC) + Special NPC (StoryNPC)
-- StoryNPC ทำเอง (ไม่ใช้ attachAll ตรงๆ) ต้องข้าม 2 กลุ่ม:
--   1) NPC_special_player = rig อ้างอิงไว้ export animation (PrimaryPart=Head ไม่ใช่ HumanoidRootPart, มี AnimSaves/Animate) ไม่ใช่ NPC จริง
--   2) ฟ้าใส/เจียเจีย = StoryNPCPlacer ย้ายไปมาตาม state.npcLoc (bed/couch/chair/park/...) ทุก state push
--      NPCIndicator จำ basePivot ตอน attach ค้างไว้แล้ว PivotTo กลับจุดเดิมทุกเฟรม (Heartbeat) — แนบเข้าไปจะดึงกลับตำแหน่งเริ่มเกมตลอด ทับระบบที่อยู่พัง
-- ⚠️ ชื่อไทยเป็น bare key ใน Lua ไม่ได้ (identifier รับแค่ ASCII) ต้อง ["..."] เสมอ — เคยพลาดจนทั้งสคริปต์ parse ไม่ผ่าน 12 ส.ค.
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
	local root = playerGui:FindFirstChild("Gui_HUD") and playerGui.Gui_HUD:FindFirstChild("Root")
	local b = root and root:FindFirstChild("MusicButton")
	if b and musicNormalImg then b.Image = muted and MUTE_ICON or musicNormalImg end
end
local hudGui = playerGui:FindFirstChild("Gui_HUD")
local hudRoot = hudGui and (hudGui:FindFirstChild("Root") or hudGui) -- ชิ้นส่วน HUD อยู่ใต้ Root (ล็อกอัตราส่วน)
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

-- ซ่อน backpack/hotbar เวลามีหน้าต่างเต็มจอบัง (cutscene/บทคุย/เมนู/คอม/ร้าน/ตัดคลิป/เตียง)
-- ที่เดียวคุมรวม: เฝ้า ScreenGui ชื่อพวกนี้โผล่/หายใต้ playerGui แล้ว toggle CoreGui.Backpack
local StarterGui = game:GetService("StarterGui")
-- ปิดปุ่ม "Reset" ในเมนู Esc ของ Roblox เอง (12 ส.ค. 2569, user) — เกมนี้ไม่มี fatal outcome/ตัวละครตายจริง
-- (CLAUDE.md: ตัดเนื้อหา fatal outcome ออกหมด) การรีเซ็ตเองทำให้ Gui_HUD โดน ResetOnSpawn ของ Roblox
-- ทำลาย+โคลนใหม่จาก StarterGui (เจอบั๊กจริง 12 ส.ค.: เลขในจอกลับไปเป็นค่า mockup ที่แต่งไว้ตอนออกแบบ เช่น "999+")
pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
local MODAL_GUIS = {
	Gui_Cutscene = true, Gui_Dialogue = true, Gui_MainMenu = true,
	Gui_ShopKiosk = true, Gui_EditQTE = true, Gui_BedMenu = true, Gui_PC = true,
	Gui_SavePanel = true, Gui_Transition = true, -- ScreenTransition (narration/[date] จอดำ) — เดิมตกหล่น hotbar โผล่ทะลุช่วง narration ล้วน (ไม่มี dialogue box)
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
-- เก็บ deps ไว้ reuse ตอนกลับเมนูหลัง ending (game over → main menu)
local menuDeps = { fireAction = fireAction, onNewGame = playOpening,
	getState = function() return latestState end }

-- ★ ตัวรับ StateChanged ตัวหลักอยู่ล่างไฟล์ (~บรรทัด 340) กว่า client จะรันมาถึงตรงนั้น
--   server push slotList ไปแล้ว (prefetch listSlots เสร็จ ~0.3 วิ เร็วกว่า client boot)
--   push ที่มาก่อน connect = **หายเงียบ ไม่มีใครรับ** → เมนูไม่เห็นเซฟ, กดช่องเซฟไม่ติด
--   (slotsReady ไม่เคยเป็น true → ปุ่มช่อง return ทิ้ง) ต้องกด "เล่นต่อ" ที่ยิง RequestSlots ใหม่เท่านั้นถึงหลุด
--   ยิ่ง DataStore เร็ว ยิ่งพังบ่อย — เลยเป็นๆ หายๆ · ดักตั้งแต่ก่อนเปิดเมนู แล้วปลดตอนตัวหลักพร้อม
local earlyStateConn
earlyStateConn = RS.Shared.Remotes.StateChanged.OnClientEvent:Connect(function(state)
	latestState = state
	if MenuUI.updateSlots then MenuUI.updateSlots(state) end
end)

MenuUI.open(playerGui, menuDeps) -- seed slotList ที่ server prefetch มาแล้ว (ไม่ต้องรอ)

-- ปุ่มเซฟเล็กมุมซ้ายล่าง + หน้าต่างเลือกช่อง — baked เป็น Gui_SaveButton/Gui_SavePanel จริงแล้ว (9 ส.ค.)
-- SavePanel.init ผูก event ให้ทั้งสอง gui ครั้งเดียว (ปุ่มกดแล้วเปิด panel เอง ไม่ต้อง wire ที่นี่)
SavePanel.init(playerGui, { fireAction = fireAction, getState = function() return latestState end })

local pcDeps = {
	fireAction = fireAction,
	getState = function() return latestState end,
}

-- PC Screen (PDF หน้า 5 "UI PC") — id ตรง key ใน UIAssets ("app_"..id)
-- ★ ลำดับนี้ = ลำดับไอคอนบน desktop ตามภาพร่าง `ui screenshot/PC ui.png`
--   คอลัมน์ 1 (บนลงล่าง): upgrade(shop) · edit · upload · feedback · bank | คอลัมน์ 2: calendar · message
-- ★ bank/message ซ่อนจนถึงเฟส 2 (Config.AppMinPhase — 12 ส.ค. 2569, user) — เฟส 1 เหลือ shop/edit/upload/feedback
--   .hidden ของ 2 ตัวนี้ถูกคำนวณสดทุกครั้งที่เปิดจอคอม (ดู openPC ข้างล่าง) ไม่ใช่ค่าคงที่แบบ manage
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
	-- 📅 ปฏิทิน ถูกถอดออก 9 ส.ค. (user) — sponsor ไม่ต้องเลือกวางวันแล้ว ใส่คืนได้ถ้ารื้อปฏิทินกลับ
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

-- เล่นบทที่เตรียม lines มาแล้ว พร้อมชุดกล้อง/เอฟเฟกต์มาตรฐานของ engine คุย NPC
-- (freeze เวลา → กล้องโฟกัสหัว NPC + ตัวผู้เล่นจางหาย → typewriter → คืนทุกอย่าง)
-- แยกออกมาเพราะ StoryBeat ก็ต้องใช้ชุดเดียวกันเป๊ะ ตอนบทต่อท้าย cutscene (ไม่งั้น player ได้คุมกล้องเอง)
-- head = Part ที่กล้องเล็ง (ไม่ส่ง = ไม่ขยับกล้อง) · voiceName = ชื่อเสียงพิมพ์ใน SoundService.Voice
local function runDialogue(lines, head, voiceName, onDone)
	fireAction({ type = "FreezeTime", on = true })
	if head then CameraFocus.focus(head) end
	-- บทที่ตั้งกล้องเอง (item.cam เช่น byLoc.park) = ช็อตซีนกว้างเห็นทั้งคู่ → ไม่จางตัวผู้เล่น (ให้เห็น player เล่น anim loop ด้วย)
	-- บทปกติ (zoom หน้า NPC) = จางตัวผู้เล่นเหมือนเดิม (ตัวเองบัง NPC)
	local keepPlayerVisible = false
	for _, item in lines do
		if type(item) == "table" and item.cam then keepPlayerVisible = true break end
	end
	if not keepPlayerVisible then fadePlayer(true, 0.3) end
	DialogueUI.show(playerGui, lines, function(_, quit, teleportTarget)
		-- จบ/เลิกคุย: ตัวผู้เล่นกลับมาทึบ + คืนกล้อง + unfreeze (ทุกกรณี)
		if not keepPlayerVisible then fadePlayer(false, 0.3) end
		if head then CameraFocus.release() end
		fireAction({ type = "FreezeTime", on = false })
		-- เลือกช้อยที่มี .teleport (เช่น เมนู "อยากไปแมพไหน" ผ่าน travel NPC) — วาปตอนบทจบจริงเท่านั้น (กดเลิกคุยกลางคัน = ไม่วาป)
		if teleportTarget and not quit then
			fireAction({ type = "TeleportTo", target = teleportTarget })
			-- กลับจากแมพ 3.1 มาเฟส 3 (Spawn_Phase3) หลังฟ้าใสทรยศ = จุดชนวน betray cutscene (ตั้ง betray_ready ให้ trigger ด้านล่างเด้ง)
			if teleportTarget == "Spawn_Phase3" and latestState and latestState.flags
				and latestState.flags.betrayed and not latestState.flags.betray_cutscene_done then
				fireAction({ type = "SetFlag", name = "betray_ready" })
			end
		end
		if onDone then onDone(quit) end
	end, voiceName)
end

-- คุย NPC: หา/เลือกบทตามเฟส+สถานะ แล้วส่งให้ runDialogue เล่น
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
	-- บทเปลี่ยนตามเฟส + หลังทรยศ + คุยซ้ำ + ที่อยู่ปัจจุบัน (เช่น คุยสวนสาธารณะ ≠ คุยห้อง — mod.byLoc)
	-- locSeen แยกจาก seen เฟสปกติ — คุยจบเต็มที่ loc นี้ครั้งแรกแล้วจำเป็นคีย์ผสม "<บท>@<loc>" (docs/engines/dialogue.md §byLoc)
	local loc = latestState and latestState.npcLoc and latestState.npcLoc[dialogueName]
	local locSeenKey = loc and (dialogueName .. "@" .. loc)
	local locSeen = locSeenKey and latestState and latestState.seenDialogue
		and latestState.seenDialogue[locSeenKey] == latestState.phase
	-- คุยจบบท after (หลังทรยศ) เต็มครั้งแรกแล้ว → เล่น after.again ถ้ามี (คีย์ผสม "<บท>@after" แยกจาก seen/locSeen)
	local afterSeenKey = dialogueName .. "@after"
	local afterSeen = latestState and latestState.seenDialogue
		and latestState.seenDialogue[afterSeenKey] == latestState.phase
	local lines = InteractBinder.pickLines(require(mod), latestState, seen, loc, locSeen, afterSeen)
	if not lines then
		warn("[Main.client] บทว่างสำหรับเฟสนี้:", dialogueName)
		return
	end
	lines = filterConds(lines, latestState and latestState.seenDialogue) -- ตัดบรรทัด ifSeen/ifNotSeen ที่ไม่เข้าเงื่อนไข
	local npc = interactPart and interactPart:FindFirstAncestorWhichIsA("Model")
	-- มีบรรทัดไหนสั่ง cam เอง (Place Cam plugin) = ให้บทนั้นคุมกล้องเต็มที่ ไม่ต้อง zoom-หน้าอัตโนมัติชนกัน
	local usesCustomCam = false
	for _, item in lines do
		if type(item) == "table" and item.cam then usesCustomCam = true break end
	end
	local head = not usesCustomCam and npc and (npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart"))
	-- เสียงพิมพ์ใช้ SoundService.Voice.<ชื่อบท> (เช่น Voice.Friend1) — ไม่มี = Voice.Default
	runDialogue(lines, head, dialogueName, function(quit)
		if not quit and locSeenKey and not locSeen then fireAction({ type = "DialogueSeen", name = locSeenKey }) end
		-- กดเลิกคุย (quit) = ไม่นับว่าคุยจบ · คุยจบเต็มครั้งแรกของเฟสนี้ → จำไว้ (คุยซ้ำได้บท repeat)
		if not quit and not seen then fireAction({ type = "DialogueSeen", name = dialogueName }) end
		if not quit and latestState and latestState.flags and latestState.flags.betrayed and not afterSeen then
			fireAction({ type = "DialogueSeen", name = afterSeenKey })
		end
		-- Faasai park date: จบ byLoc.park.p แบบไม่ quit (บังคับอยู่แล้วผ่าน lock=true) → เด้งบทส่งท้ายทันที
		-- ไม่ผ่าน StoryBeat — StoryBeat.play ห่อทุก phase ด้วย ScreenTransition (จอดำ fade 0.6s เข้า+ออก) เสมอ
		-- แม้ไม่ส่ง cutscene/preStage/stage เลย (เจอตอน final review 12 ส.ค.) จะเห็นจอกระพริบดำ 2 รอบ ขัดกับที่ตั้งใจ "เด้งต่อทันที"
		-- เรียก runDialogue ตรงๆ แทน (เหมือนคุย NPC ปกติ) ไม่มีจอดำคั่นเลย ตรงตามที่ออกแบบไว้
		if not quit and dialogueName == "ฟ้าใส" and loc == "park" then
			local Faasai = require(mod)
			local farewellNpc = AnimPlayer.findRig("ฟ้าใส")
			local farewellHead = farewellNpc and (farewellNpc:FindFirstChild("Head") or farewellNpc:FindFirstChild("HumanoidRootPart"))
			runDialogue(Faasai.parkFarewell, farewellHead, "ฟ้าใส", function()
				fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "room" })
				fireAction({ type = "SetFlag", name = "faasai_park_dated" })
			end)
		end
	end)
end

-- state มาใหม่ทุกครั้ง: HUD + PC + menu + canon event + ending
local endingPlayed = false
local prevClips, primed = 0, false -- primed กัน state แรก/โหลดเซฟไม่ให้ยิงเสียง
local prevStaffClips, prevFollower, prevMoney = 0, 0, 0 -- toast ทีมลงคลิป / DM ปลดล็อก (เทียบ delta)
local prevRentMissed = 0 -- เสียงตอนจ่ายค่าเช่าไม่ทัน/เงินหมด (เทียบ delta เหมือน prevClips)
local prevSponsorOffer = false -- toast งาน sponsor: เด้งตอน false→true เท่านั้น (ไม่เด้งซ้ำทุก push)
local appliedVolume = nil -- ระดับเสียงล่าสุดที่ apply จาก settings (กัน apply ทับตอน user ปรับ)
local appliedShadow, appliedMusicMuted = nil, nil -- เงา/ปิดเพลง: apply จากเซฟครั้งเดียว ไม่ทับตอน user สลับเอง
local appliedHideBillboards = nil -- ป้ายลอย (NPC/โซน) — 12 ส.ค. 2569, user
local appliedBus = {} -- ระดับเสียงแยกกลุ่ม bgm/sfx/ambient ที่ apply จากเซฟล่าสุด
local prevPhase, phasePrimed = 1, false -- phasePrimed กัน state แรก/โหลดเซฟไม่ให้วาปข้ามเฟสเอง
local lastQTEId = nil -- id ของ pendingRecordQTE ที่เล่นไปแล้ว (dedupe กัน push ซ้ำ retrigger)
if earlyStateConn then earlyStateConn:Disconnect() end -- ตัวหลักพร้อมแล้ว ปลดตัวดักชั่วคราวข้างบน
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
	-- ป้ายลอย (NPC/โซน) — InteractBinder อ่าน state.settings.hideBillboards ตรงๆ ผ่าน getState() อยู่แล้ว
	-- แต่ SettingsController.client.luau (LocalScript sandboxed ฝัง GUI, require ไม่ได้) อ่านไม่ถึง state เลย
	-- เลย mirror ลง workspace Attribute ให้แผง Settings อ่าน/toggle ผ่านตรงนั้นแทน (แบบเดียวกับ Lighting.GlobalShadows)
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
	-- musicMuted apply หลัง bgmVol เสมอ — setMusicMuted จะจำ PreMute เป็นระดับ bgm ที่เพิ่ง apply (ไม่ใช่ค่าเก่า)
	if state.settings and state.settings.musicMuted ~= nil and state.settings.musicMuted ~= appliedMusicMuted then
		appliedMusicMuted = state.settings.musicMuted
		Audio.setMusicMuted(appliedMusicMuted)
		refreshMuteIcon(appliedMusicMuted)
	end

	-- ของที่ขยับไม่ได้ (ไม่ joint-animate) — ล่องหน/โผล่ตาม flag ล้วนๆ แทน (Motor6D สร้างปัญหามาเยอะพอละวันนี้)
	-- ฟ้าใสย้ายเข้า (join) = เอากระเป๋า+คอมมาด้วย ทั้งคู่ค้างจนทรยศ (betray) ถึงหายไปพร้อมกัน (ยกหนี)
	-- เจียเจียไม่มี arc ทรยศ — โผล่ตอนร่วมทีมแล้วค้างตลอด ไม่มีเงื่อนไขหาย
	if state.flags then
		local faasaiJoined = state.flags.faasai_joined == true
		local betrayed = state.flags.betrayed == true
		local jiajiaJoined = state.flags.jiajia_joined == true
		-- flag faasai_joined ตั้งตอน "เริ่ม" trigger (กันยิงซ้ำ) ยังไม่ใช่ตอน cutscene+dialogue จบ
		-- กระเป๋าฟ้าใส (Handle1) ต้องรอ join เสร็จจริงก่อนโผล่ = บท join จบ → seenDialogue["ฟ้าใส"] ถูก mark
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
		setVisible("Handle1", faasaiJoinDone) -- กระเป๋าที่เตียง (เฟส 2) โผล่หลัง cutscene+dialogue join จบ ค้างตลอดหลังจากนั้น
		setVisible("Handle2", faasaiJoined and not betrayed) -- กระเป๋าที่เก้าอี้ (เฟส 3) หายตอนทรยศ
		setVisible("Notebook", faasaiJoinDone and not betrayed) -- คอมที่เตียง (เฟส 2) โผล่หลัง join จบเหมือน Handle1 หายตอนทรยศ
		setVisible("MacbookChair", faasaiJoined and not betrayed) -- คอมที่เก้าอี้ (เฟส 3)
		-- เจียเจียยังไม่มี arc "ชวนออกไปนอกบ้าน" (flag ยังไม่มี — มีแค่ byLoc.park placeholder) → โชว์ตลอดหลัง join ไปก่อน
		-- ไว้สร้าง arc นั้น (คู่กับ faasai_park) แล้วเปลี่ยนเงื่อนไขเป็น "jiajiaJoined and not <flag ใหม่>"
		setVisible("MacbookCouch", jiajiaJoined) -- คอมเจียเจีย ค้างตลอด (ยังไม่มีเงื่อนไขหาย)
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

	-- จ่ายค่าเช่าไม่ทัน/เงินหมด (flags.rentMissed เพิ่มตอนตัดรอบ 7 วัน — MoneyService.onDay ฝั่ง server)
	-- tonumber กัน error ถ้ามีที่อื่นตั้งเป็น boolean (เช่น /dev flag rentMissed — docs เตือนไว้แล้วว่าอย่าใช้)
	local rentMissed = tonumber(state.flags.rentMissed) or 0
	if primed and rentMissed > prevRentMissed then
		Audio.sfx("rent_missed")
	end
	prevRentMissed = rentMissed

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
	-- งาน sponsor เข้า (server สุ่มตอนขึ้นวันใหม่) → toast กดรับได้เลย ไม่ต้องเปิดปฏิทินแล้ว
	-- เด้งเฉพาะขอบขาขึ้น false→true · ไม่เช็ค primed: โหลดเซฟที่มี offer ค้างก็ควรเห็นว่ามีงานรอ
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
	StoryNPCPlacer.apply(state) -- ย้าย StoryNPC ตาม npcLoc (ทำจริงเฉพาะตัวที่ loc เปลี่ยน)
	if MenuUI.updateSlots then MenuUI.updateSlots(state) end

	-- QTE ถ่ายคลิป (server สุ่มตาม Config.RecordQTE.chance ตั้ง pendingRecordQTE = {id, hits}) → เล่น skill-check แล้วส่งเกรดทั้งชุดกลับ
	-- ไม่ทับ dialogue/cutscene · dedupe ด้วย id กัน push ซ้ำเปิดซ้อน
	local qte = state.pendingRecordQTE
	local qid = qte and qte.id
	if qid and qid ~= lastQTEId and not RecordQTE.running
		and not DialogueUI.running and not CutscenePlayer.running then
		lastQTEId = qid
		-- ของกินที่ออกฤทธิ์อยู่ทำให้โซนกว้างขึ้น (Config.Consumables) — คิดจาก state ล่าสุดตอนเปิด QTE
		local pMult, gMult = Formulas.qteZoneMult(state)
		RecordQTE.start(playerGui, fireAction, qte.hits, { perfect = pMult, good = gMult })
	end

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
		-- แทน [date] ด้วยจำนวนวันในเกม ณ ตอนข้ามเฟส (clone กันแก้โมดูล content ที่ require ร่วม)
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
				waitStreamedAround(6) -- รอแมพเฟสใหม่โหลดก่อน fade กลับ
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
		fireAction({ type = "SetFlag", name = "faasai_joined" }) -- mark กันยิงซ้ำ (StoryBeat.running กันระหว่างเล่นด้วย)
		local FaasaiJoin = require(Content.Cutscenes.FaasaiJoin)
		local Faasai = require(Content.Dialogue["ฟ้าใส"])

		-- สลับประตูจริง (มี DoorScript/ProximityPrompt ใช้เล่นปกติ) กับ "Door Rig" (duplicate ไว้หมุนด้วย step swing)
		-- ห้ามหมุนของจริงเด็ดขาด (script เดิมมี state จำ opened/closed ของมันเอง จะ desync — docs/engines/story-beat.md §7.3)
		-- สลับค้างไว้ตลอดฉาก (ท่า+บทคุย) คืนของจริงตอน settle ใต้จอดำเหมือนกัน กันเห็นสลับโผล่ให้เห็น
		-- หา "Door Rig" แบบ deep search (ไม่ fix path) — ตัวนี้ถูกย้าย/ลบ-สร้างใหม่มาหลายรอบระหว่าง authoring
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
				-- คืนบานให้ปิดสนิททุกครั้งที่เริ่มฉาก — step swing หมุนสะสม ถ้าเล่นซ้ำ (dev retest) จะเปิดเกิน
				if showCutsceneDoor then
					closedDoorPivot = closedDoorPivot or cutsceneDoor:GetPivot()
					cutsceneDoor:PivotTo(closedDoorPivot)
				end
				for _, p in cutsceneDoor:GetDescendants() do
					if p:IsA("BasePart") then
						p.Transparency = showCutsceneDoor and 0 or 1
						p.CanCollide = false -- duplicate ไม่มี logic ควบคุม ห้ามชนได้ตลอด กันติดกับ
					end
				end
			end
		end

		StoryBeat.play(playerGui, {
			-- จัดตำแหน่ง/ทิศทั้งคู่ก่อนคัตซีน ให้ตรงกับจุดเริ่ม root motion ของ KnockTalkWalkSit (NPCHome_*_room ที่ประตู)
			-- วาป+รอ stream ก่อน SetNpcLoc เสมอ (เหมือน JiajiaJoin) — เผื่อ trigger ไกลจากห้อง ปกติ follower เข้าเกณฑ์
			-- มักเกิดใกล้บ้าน (เช่นนอน) อยู่แล้วเสี่ยงต่ำ แต่กันไว้ไม่ให้พังถ้า trigger ยิงตอนอยู่ไกล
			preStage = function()
				fireAction({ type = "TeleportTo", target = "NPCHome_Player_room" })
				waitStreamedAround(6)
				fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "room" })
				swapDoor(true)
			end,
			cutscene = FaasaiJoin,
			dialogue = Faasai.p2 or Faasai.p1, -- บทเฟส 2 (มาขอฝึกงาน)
			-- ใช้ engine คุยชุดเดียวกับกด prompt คุย NPC ปกติเป๊ะ (กล้องโฟกัสหัว + player จางหาย + rich text)
			-- ต่างแค่ไม่ต้องกด prompt เอง — เข้าอัตโนมัติหลัง cutscene จบ
			-- ต้อง mark DialogueSeen เอง (ไม่ผ่าน startDialogue ปกติที่ mark ให้) ไม่งั้น prompt คุยซ้ำได้ p2 เต็มซ้ำตลอด
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
			-- CutscenePlayer freeze เวลาไว้ตอนเริ่มแล้วให้ caller ปลดเอง — ย้ำตรงนี้กันค้างแช่แข็งหลังจบ beat
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
	-- threshold มาจาก Config.Staff.companions ที่เดียว (ตัวเดียวกับที่ StaffService ใช้ auto-add เพื่อนร่วมทาง)
	-- ไม่ตั้งเลขซ้ำใน Config อีกตัว — ไม่งั้น cutscene กับ roster เพี้ยนคนละค่าได้
	if state.phase == 3 and state.follower >= Config.Staff.companions[2].joinFollower
		and not state.flags.jiajia_joined and not state.flags.ending
		and #state.pendingEvents == 0
		and not DialogueUI.running and not CutscenePlayer.running
		and not ScreenTransition.running and not StoryBeat.running then
		fireAction({ type = "SetFlag", name = "jiajia_joined" }) -- mark กันยิงซ้ำ
		local JiajiaJoin = require(Content.Cutscenes.JiajiaJoin)
		local Jiajia = require(Content.Dialogue["เจียเจีย"])

		StoryBeat.play(playerGui, {
			-- จัดทั้ง 3 ตัวให้ตรงจุดเริ่ม root motion ของ clip (anchor ก๊อปตำแหน่ง+ทิศจาก rig อ้างอิง Workspace.Animation["Jiajia join"])
			-- ต้องวาปก่อน + รอ stream เข้าให้เสร็จก่อนค่อย SetNpcLoc — ฉากนี้อยู่เฟส 3 (Map_Phase3) ไกลจากที่ trigger ยิง
			-- (follower ถึง threshold อาจอยู่แมพไหนก็ได้) ถ้า SetNpcLoc ไปก่อน anchor NPCHome_*_jiajiajoin ยังไม่ stream
			-- เข้า client → StoryNPCPlacer หาไม่เจอ ("ไม่เจอ anchor") ไม่ retry เองจนกว่าจะมี state push อื่นมาบังเอิญ
			preStage = function()
				fireAction({ type = "TeleportTo", target = "NPCHome_Player_jiajiajoin" })
				waitStreamedAround(6)
				fireAction({ type = "SetNpcLoc", actor = "เจียเจีย", loc = "jiajiajoin" })
				fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "jiajiajoin" })
			end,
			cutscene = JiajiaJoin,
			-- p3 = บทเต็มครั้งแรก (StoryBeat เล่นตรงนี้ ไม่ผ่าน pickLines) · คุยซ้ำทาง prompt ทีหลังตกไป again อัตโนมัติ
			-- ต้อง mark DialogueSeen เอง (ไม่ผ่าน startDialogue ปกติที่ mark ให้) ไม่งั้น prompt คุยซ้ำได้ p3 เต็มซ้ำตลอด
			dialogue = Jiajia.p3,
			runDialogue = function(lines, done)
				local npc = AnimPlayer.findRig("เจียเจีย")
				local head = npc and (npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart"))
				runDialogue(lines, head, "เจียเจีย", function(quit)
					if not quit then fireAction({ type = "DialogueSeen", name = "เจียเจีย" }) end
					done()
				end)
			end,
			-- ที่อยู่ถาวรเฟส 3 (วางแล้วใน Workspace.cutscene_start_part.ที่อยู่) — เจียเจีย=couch, ฟ้าใส=chair
			settle = function()
				fireAction({ type = "SetNpcLoc", actor = "เจียเจีย", loc = "couch" })
				fireAction({ type = "SetNpcLoc", actor = "ฟ้าใส", loc = "chair" })
			end,
			onDone = function()
				fireAction({ type = "FreezeTime", on = false })
			end,
		})
	end

	-- ฟ้าใสทรยศ: betrayed (server ตั้งที่ 500K = Config.BetrayalMilestone) + กลับจากแมพ 3.1 (flag betray_ready) → cutscene ครั้งเดียว
	-- betray_ready ตั้งอัตโนมัติใน runDialogue ตอน travel NPC วาปกลับ "Spawn_Phase3" ขณะ betrayed (ดูข้างบน) — ไป 3.1 ผ่านช้อย teleport ของ travel NPC
	-- (travel NPC = NPC_special_เจียเจีย_traveller ใน Map_phase3-1 + เจียเจียเฟส 3 · ช้อย teleport เลือกแมพปลายทาง)
	-- anchor cutscene: NPCHome_เจียเจีย_faasai_betray / NPCHome_Player_faasai_betray (loc "faasai_betray" — เพิ่มใน StoryNPCPlacer NO_RAYCAST แล้ว)
	if state.phase == 3 and state.flags.betrayed
		and state.flags.betray_ready and not state.flags.betray_cutscene_done and not state.flags.ending
		and #state.pendingEvents == 0
		and not DialogueUI.running and not CutscenePlayer.running
		and not ScreenTransition.running and not StoryBeat.running then
		fireAction({ type = "SetFlag", name = "betray_cutscene_done" }) -- mark กันยิงซ้ำ
		local FaasaiBetray = require(Content.Cutscenes.FaasaiBetray)
		local Jiajia = require(Content.Dialogue["เจียเจีย"])

		StoryBeat.play(playerGui, {
			-- จัดเจียเจีย+player ให้ตรงจุดเริ่ม root motion — วาปก่อน + รอ stream ก่อน SetNpcLoc (เหมือน JiajiaJoin)
			preStage = function()
				fireAction({ type = "TeleportTo", target = "NPCHome_Player_faasai_betray" })
				waitStreamedAround(6)
				fireAction({ type = "SetNpcLoc", actor = "เจียเจีย", loc = "faasai_betray" })
			end,
			cutscene = FaasaiBetray,
			-- ปฏิกิริยาครั้งเดียวต่อจากคัตซีน (12 ส.ค.) — Jiajia.betrayReact ไม่ใช่ .after (after โดน pickLines เลือกทุกครั้งที่คุย prompt หลังจากนี้แทน)
			-- ไม่ mark DialogueSeen (ไม่ใช่บทแรกที่คุยจบผ่าน pickLines — seenDialogue["เจียเจีย"] ถูก mark ไปแล้วตอน join)
			dialogue = Jiajia.betrayReact,
			runDialogue = function(lines, done)
				local npc = AnimPlayer.findRig("เจียเจีย")
				local head = npc and (npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart"))
				runDialogue(lines, head, "เจียเจีย", function() done() end)
			end,
			settle = function()
				fireAction({ type = "SetNpcLoc", actor = "เจียเจีย", loc = "couch" }) -- เจียเจียกลับที่อยู่ถาวร (ฟ้าใสหายไปแล้ว betrayed)
			end,
			onDone = function()
				fireAction({ type = "FreezeTime", on = false })
			end,
		})
	end

	-- จบเกม → เล่น cutscene ending (ครั้งเดียว) → fade ดำ → กลับ main menu (game over)
	-- หมวยทวงตัง/bad end เกิดตอนนอน (rent cycle) แล้ว EndingService ตั้ง flags.ending — client เล่นตรงนี้
	-- รอ canon event ค้างให้จบก่อน (เช่น BCA หลัง 1M)
	if state.flags.ending and not endingPlayed
		and #state.pendingEvents == 0 and not DialogueUI.running then
		endingPlayed = true
		local endId = state.flags.ending
		local steps = require(Content.Endings[endId])
		CutscenePlayer.play(playerGui, steps, function()
			-- cutscene จบ → fade ดำ + "— จบ —" → เปิด main menu (save snapshot ก่อน cutscene ยังอยู่ กดเข้าเล่นซ้ำได้)
			ScreenTransition.play({
				lines = { "[slow]— จบ — [normal](" .. endId .. ")" },
				onDone = function()
					-- คง endingPlayed=true กัน ending เล่นซ้ำวนขณะเมนูเปิด (flags.ending ยังตั้งอยู่)
					-- ⏳ replay-on-reload + save snapshot ก่อน cutscene = follow-up (Boss อยากได้ ยังไม่ทำ)
					MenuUI.open(playerGui, menuDeps)
				end,
			})
		end)
	end
end)

InteractBinder.init({
	fireAction = fireAction,
	playerGui = playerGui,
	getState = function() return latestState end, -- ประตูใช้เช็ค follower ก่อนปล่อยผ่าน (docs/02 §9.9)
	openPC = function(screenPart) -- Interact_pcMonitor = zoom เข้าจอ | Interact_Camera เก่า = เปิดเฉยๆ
		-- ซ่อน icon ที่ยังไม่ถึงเฟส (Config.AppMinPhase — 12 ส.ค. 2569, user) — เช็คสดทุกครั้งที่เปิดจอ
		-- แตะเฉพาะแอปที่มีอยู่ใน AppMinPhase (bank/message) ไม่ยุ่ง hidden ถาวรของ manage
		for _, app in PC_APPS do
			if Config.AppMinPhase[app.id] then
				app.hidden = not Formulas.appUnlocked(latestState.phase, app.id)
			end
		end
		PCScreen.open(playerGui, pcDeps, PC_APPS, screenPart)
	end,
	openShop = function() -- ร้านในแมพ (Interact_Shop) — คนละอันกับแอป Shop บนจอคอม
		ShopKiosk.open(playerGui, pcDeps)
	end,
	startDialogue = startDialogue,
})
