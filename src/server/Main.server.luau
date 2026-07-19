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
local CommentService = require(SSS.Services.CommentService)
local CalendarService = require(SSS.Services.CalendarService)
local EndingService = require(SSS.Services.EndingService)
local Config = require(RS.Shared.Config)

local state = GameState.newGame()

-- follower ข้าม milestone (1K/10K/100K/1M) → flag + คิว event ให้ client เล่นบท
local function checkMilestones(s)
	for _, m in Config.StoryMilestones do
		local key = "milestone_" .. m
		if s.follower >= m and not s.flags[key] then
			s.flags[key] = true
			table.insert(s.pendingEvents, key)
		end
	end
end

-- เช็คจบเกมหลังทุกความเปลี่ยนแปลงสำคัญ — เจอแล้วหยุดเวลา รอ client เล่น cutscene
local function checkEnding(s)
	local ending = EndingService.check(s)
	if ending then
		s.flags.ending = ending
		TimeService.setFrozen(true)
	end
end

-- ทุกการกระทำของผู้เล่น — service ไม่เรียก push เอง Main push หลัง route สำเร็จ
ActionRouter.register("FinishEdit", function(s, a)
	FollowerService.finishEdit(s, a)
	MentalService.apply(s, "clipEdit")
end)
ActionRouter.register("UploadClip", function(s, a)
	if a.clip == "latest" then a.clip = #s.clips end
	local ok, viral = FollowerService.uploadClip(s, a, MentalService.effective(s))
	if ok then
		if viral then MentalService.apply(s, "viralClip") end
		CommentService.generate(s)
		checkMilestones(s)
		checkEnding(s)
	end
end)
ActionRouter.register("DoActivity", function(s, a)
	MentalService.doActivity(s, a.activity)
end)
ActionRouter.register("AnswerComment", function(s, a)
	local tag = CommentService.answer(s, a)
	if tag == "pos" then MentalService.apply(s, "commentChoiceGood")
	elseif tag == "neg" then MentalService.apply(s, "commentChoiceBad") end
	checkEnding(s)
end)
ActionRouter.register("PlaceBlock", function(s, a)
	CalendarService.place(s, tonumber(a.day) or 0, { type = "Schedule", id = a.id })
end)
ActionRouter.register("AcceptSponsor", function(s, a)
	CalendarService.acceptSponsor(s, tonumber(a.day) or 0)
end)
ActionRouter.register("FreezeTime", function(s, a)
	TimeService.setFrozen(a.on == true)
end)
ActionRouter.register("EventSeen", function(s, a)
	for i, id in s.pendingEvents do
		if id == a.id then
			table.remove(s.pendingEvents, i)
			break
		end
	end
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
-- ทุกวันใหม่: ครบ 7 วันหักรายจ่าย — จ่ายไม่ไหวหัก mental ต่อ + block ปฏิทิน + เช็คจบเกม
TimeService.onDay(function(s)
	if MoneyService.onDay(s) then
		MentalService.apply(s, "rentMissed")
	end
	CalendarService.onDay(s)
	checkEnding(s)
end)
TimeService.start(state)

game:BindToClose(function()
	local player = Players:GetPlayers()[1]
	if player then GameState.saveSlot(player.UserId, state) end
end)
