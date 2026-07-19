-- Main.client.luau — จุดเริ่มเดียวของ client: ต่อ Remote + เปิด HUD
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HUD = require(script.Parent.UI.HUD)

HUD.init(Players.LocalPlayer:WaitForChild("PlayerGui"))
RS.Shared.Remotes.StateChanged.OnClientEvent:Connect(function(state)
	HUD.update(state)
end)
