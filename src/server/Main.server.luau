-- Main.server.luau — จุดเริ่มเดียวของ server: wiring ทุกอย่างอยู่ไฟล์นี้ไฟล์เดียว
-- อยากรู้ว่าอะไรต่อกับอะไร อ่านไฟล์นี้ (docs/07 §2)
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameState = require(SSS.Services.GameState)
local ActionRouter = require(SSS.Services.ActionRouter)

local state = GameState.newGame()

-- client action ทุกอันวิ่งผ่านเส้นนี้เส้นเดียว
RS.Shared.Remotes.Action.OnServerEvent:Connect(function(player, action)
	ActionRouter.route(state, action)
end)

-- ผู้เล่นเข้า → ส่ง state ปัจจุบันให้ทันที
Players.PlayerAdded:Connect(function(player)
	GameState.push(state)
end)

-- autosave ทุก 60 วิ ถ้ามีอะไรเปลี่ยน + ตอนปิดเกม
task.spawn(function()
	while true do
		task.wait(60)
		local player = Players:GetPlayers()[1]
		if player and GameState.isDirty() then
			GameState.saveSlot(player.UserId, state)
		end
	end
end)

game:BindToClose(function()
	local player = Players:GetPlayers()[1]
	if player then GameState.saveSlot(player.UserId, state) end
end)
