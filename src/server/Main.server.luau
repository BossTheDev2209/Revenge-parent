-- Main.server.luau — จุดเริ่มเดียวของ server: wiring ทุกอย่างอยู่ไฟล์นี้ไฟล์เดียว
-- อยากรู้ว่าอะไรต่อกับอะไร อ่านไฟล์นี้ (docs/07 §2)
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameState = require(SSS.Services.GameState)
local ActionRouter = require(SSS.Services.ActionRouter)
local TimeService = require(SSS.Services.TimeService)
local MentalService = require(SSS.Services.MentalService)
local FollowerService = require(SSS.Services.FollowerService)
local MoneyService = require(SSS.Services.MoneyService)

local state = GameState.newGame()

-- ทุกการกระทำของผู้เล่น — service ไม่เรียก push เอง Main push หลัง route สำเร็จ
ActionRouter.register("FinishEdit", function(s, a)
	FollowerService.finishEdit(s, a)
	MentalService.apply(s, "clipEdit")
end)
ActionRouter.register("UploadClip", function(s, a)
	local ok, viral = FollowerService.uploadClip(s, a, MentalService.effective(s))
	if ok and viral then MentalService.apply(s, "viralClip") end
end)

-- client action ทุกอันวิ่งผ่านเส้นนี้เส้นเดียว
RS.Shared.Remotes.Action.OnServerEvent:Connect(function(player, action)
	if ActionRouter.route(state, action) then
		GameState.push(state)
	end
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

-- นาฬิกาเกม: เดินตลอด, ทุกชั่วโมง mental drain + push (client เห็นนาฬิกา/หลอดใจขยับ)
TimeService.onHour(function(s)
	MentalService.onHour(s)
	GameState.push(s)
end)
-- ทุกวันใหม่: ครบ 7 วันหักรายจ่าย — จ่ายไม่ไหวหัก mental ต่อ
TimeService.onDay(function(s)
	if MoneyService.onDay(s) then
		MentalService.apply(s, "rentMissed")
	end
end)
TimeService.start(state)

game:BindToClose(function()
	local player = Players:GetPlayers()[1]
	if player then GameState.saveSlot(player.UserId, state) end
end)
