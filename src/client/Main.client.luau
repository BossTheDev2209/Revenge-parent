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
local Shop = require(script.Parent.UI.Apps.Shop)
local Message = require(script.Parent.UI.Apps.Message)
local DialogueUI = require(script.Parent.UI.DialogueUI)
local CutscenePlayer = require(script.Parent.UI.CutscenePlayer)
local MenuUI = require(script.Parent.UI.MenuUI)
local InteractBinder = require(script.Parent.InteractBinder)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local actionRemote = RS.Shared.Remotes.Action
local Content = RS.Shared.Content

local latestState = nil

local function fireAction(action)
	actionRemote:FireServer(action)
end

HUD.init(playerGui)
MenuUI.open(playerGui, { fireAction = fireAction }) -- เกมเริ่มที่เมนู (freeze จนกดเล่น)

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

-- PC Screen (PDF หน้า 5 "UI PC") — id ตรง key ใน UIAssets ("app_"..id)
local PC_APPS = {
	{ id = "edit", name = "ตัดคลิป", label = "✂️ ตัดคลิป", external = function()
		EditQTE.start(playerGui, fireAction)
	end },
	{ id = "upload", name = "อัปโหลด", label = "⬆️ อัปโหลด", create = Upload.create },
	{ id = "feedback", name = "feedback", label = "📊 Feedback", create = Feedback.create },
	{ id = "bank", name = "ธนาคาร", label = "🏦 Bank", create = Bank.create },
	{ id = "calendar", name = "ปฏิทิน", label = "📅 ปฏิทิน", create = CalendarApp.create },
	{ id = "shop", name = "ร้านค้า", label = "🛒 Shop", create = Shop.create },
	{ id = "message", name = "ข้อความ", label = "✉️ Message", create = Message.create },
	{ id = "manage", name = "พนักงาน", label = "👥 Manage", create = function(frame)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 1, 0)
		l.BackgroundTransparency = 1
		l.TextScaled = true
		l.Text = "👥 จ้างพนักงาน\n(เร็วๆนี้)"
		l.Parent = frame
		return {}
	end },
}

local pcDeps = {
	fireAction = fireAction,
	getState = function() return latestState end,
}

-- คุย NPC: freeze เวลา → typewriter → unfreeze (design doc §7 — ทางเดียว ไม่นับ choice)
local function startDialogue(dialogueName)
	local mod = Content.Dialogue:FindFirstChild(dialogueName)
	if not mod then
		warn("[Main.client] ไม่มีบท:", dialogueName)
		return
	end
	fireAction({ type = "FreezeTime", on = true })
	DialogueUI.show(playerGui, require(mod), function()
		fireAction({ type = "FreezeTime", on = false })
	end)
end

-- state มาใหม่ทุกครั้ง: HUD + PC + menu + canon event + ending
local endingPlayed = false
RS.Shared.Remotes.StateChanged.OnClientEvent:Connect(function(state)
	latestState = state
	HUD.update(state)
	if PCScreen.running and PCScreen.refresh then PCScreen.refresh(state) end
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

	-- จบเกม → เล่น cutscene ending (ครั้งเดียว)
	if state.flags.ending and not endingPlayed then
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
	openPC = function(screenPart) -- Interact_pcMonitor = zoom เข้าจอ | Interact_Camera เก่า = เปิดเฉยๆ
		PCScreen.open(playerGui, pcDeps, PC_APPS, screenPart)
	end,
	startDialogue = startDialogue,
})
