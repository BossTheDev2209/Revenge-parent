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
local InteractBinder = require(script.Parent.InteractBinder)
local Audio = require(script.Parent.AudioService)
local RecordTool = require(script.Parent.RecordTool)
local CameraFocus = require(script.Parent.CameraFocus)
local ScreenTransition = require(script.Parent.ScreenTransition)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local actionRemote = RS.Shared.Remotes.Action
local Content = RS.Shared.Content

local latestState = nil

local function fireAction(action)
	Audio.sfx("ui_click") -- ทุกการกดในเกมมีเสียงเดียวกัน (ไม่มีไฟล์ = เงียบ)
	actionRemote:FireServer(action)
end

Audio.init(Players.LocalPlayer) -- โซนเพลง + เสียงเดิน
RecordTool.init(Players.LocalPlayer, fireAction, function() return latestState end) -- Tool อัดคลิป + วงโซน

-- ฉากเปิดเกม (cutscene mode 1) เล่นหลังกด New Game → จบต่อ transition วาปเข้าห้องเฟส 1
local function playOpening()
	local Opening = require(Content.Cutscenes.Opening)
	fireAction({ type = "FreezeTime", on = true })
	CutscenePlayer.play(playerGui, Opening, function()
		ScreenTransition.play({
			onBlack = function()
				local target = workspace:FindFirstChild("Spawn_Phase1", true)
				local char = Players.LocalPlayer.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if target and target:IsA("BasePart") and root then
					root.CFrame = target.CFrame + Vector3.new(0, 3, 0)
				elseif not target then
					warn("[Main.client] ไม่มี Spawn_Phase1 ในแมพ — intro ไม่วาป (วาง Part ชื่อนี้ในห้องเฟส 1)")
				end
			end,
			onDone = function() fireAction({ type = "FreezeTime", on = false }) end,
		})
	end)
end

HUD.init(playerGui)
-- เกมเริ่มที่เมนู (freeze จนกดเล่น) · onNewGame = เล่น intro หลังเริ่มเกมใหม่
MenuUI.open(playerGui, { fireAction = fireAction, onNewGame = playOpening })

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
saveBtn.Parent = saveGui
saveGui.Parent = playerGui
saveBtn.Activated:Connect(function()
	fireAction({ type = "SaveSlot" })
	saveBtn.Text = "✅ เซฟแล้ว"
	task.delay(1.5, function() saveBtn.Text = "💾 เซฟ" end)
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

-- คุย NPC: freeze เวลา → กล้องโฟกัส NPC → typewriter → unfreeze + คืนกล้อง
-- interactPart = Part Interact_NPC ในโมเดล NPC (ใช้หา Head ให้กล้องเล็ง) — ไม่ส่งมา = ไม่ขยับกล้อง
local function startDialogue(dialogueName, interactPart)
	local mod = Content.Dialogue:FindFirstChild(dialogueName)
	if not mod then
		warn("[Main.client] ไม่มีบท:", dialogueName)
		return
	end
	-- บทเปลี่ยนตามเฟส + หลังทรยศ (docs/02 §9.4)
	local lines = InteractBinder.pickLines(require(mod), latestState)
	if not lines then
		warn("[Main.client] บทว่างสำหรับเฟสนี้:", dialogueName)
		return
	end
	local npc = interactPart and interactPart:FindFirstAncestorWhichIsA("Model")
	local head = npc and (npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart"))
	fireAction({ type = "FreezeTime", on = true })
	if head then CameraFocus.focus(head) end
	-- เสียงพิมพ์ใช้ SoundService.Voice.<ชื่อบท> (เช่น Voice.Friend1) — ไม่มี = Voice.Default
	DialogueUI.show(playerGui, lines, function()
		if head then CameraFocus.release() end
		fireAction({ type = "FreezeTime", on = false })
	end, dialogueName)
end

-- state มาใหม่ทุกครั้ง: HUD + PC + menu + canon event + ending
local endingPlayed = false
local prevClips, primed = 0, false -- primed กัน state แรก/โหลดเซฟไม่ให้ยิงเสียง
RS.Shared.Remotes.StateChanged.OnClientEvent:Connect(function(state)
	latestState = state
	HUD.update(state)

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
	prevClips, primed = uploaded, true
	if PCScreen.running and PCScreen.refresh then PCScreen.refresh(state) end
	if ShopKiosk.running and ShopKiosk.refresh then ShopKiosk.refresh(state) end -- ซื้อแล้วราคา/ระดับอัปทันที
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
