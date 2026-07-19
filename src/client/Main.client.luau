-- Main.client.luau — จุดเริ่มเดียวของ client: Remote + HUD + Interact + Comment + Dialogue + Ending
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HUD = require(script.Parent.UI.HUD)
local EditQTE = require(script.Parent.UI.Apps.EditQTE)
local DialogueUI = require(script.Parent.UI.DialogueUI)
local CutscenePlayer = require(script.Parent.UI.CutscenePlayer)
local CommentUI = require(script.Parent.UI.CommentUI)
local InteractBinder = require(script.Parent.InteractBinder)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local actionRemote = RS.Shared.Remotes.Action
local Content = RS.Shared.Content

local function fireAction(action)
	actionRemote:FireServer(action)
end

HUD.init(playerGui)
CommentUI.init(playerGui, fireAction)

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

-- state มาใหม่ทุกครั้ง: HUD + comment + canon event + ending
local endingPlayed = false
RS.Shared.Remotes.StateChanged.OnClientEvent:Connect(function(state)
	HUD.update(state)
	CommentUI.update(state)

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
			fireAction({ type = "EventSeen", id = eventId }) -- ไม่มีบท ข้ามทิ้ง
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
	startQTE = function()
		EditQTE.start(playerGui, fireAction)
	end,
	startDialogue = startDialogue,
})
