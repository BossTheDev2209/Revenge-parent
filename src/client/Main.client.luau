-- Main.client.luau — จุดเริ่มเดียวของ client: ต่อ Remote + เปิด HUD + ผูก Interact
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HUD = require(script.Parent.UI.HUD)
local EditQTE = require(script.Parent.UI.Apps.EditQTE)
local InteractBinder = require(script.Parent.InteractBinder)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local actionRemote = RS.Shared.Remotes.Action

local function fireAction(action)
	actionRemote:FireServer(action)
end

HUD.init(playerGui)
RS.Shared.Remotes.StateChanged.OnClientEvent:Connect(function(state)
	HUD.update(state)
end)

InteractBinder.init({
	fireAction = fireAction,
	startQTE = function()
		EditQTE.start(playerGui, fireAction)
	end,
})
