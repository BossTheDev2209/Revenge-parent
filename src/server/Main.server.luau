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

-- follower ข้าม milestone (1K/10K/100K/1M) → flag + คิว event ให้ client เล่นบท + drain แรงขึ้น 1 วัน
local function checkMilestones(s)
	for _, m in Config.StoryMilestones do
		local key = "milestone_" .. m
		if s.follower >= m and not s.flags[key] then
			s.flags[key] = true
			table.insert(s.pendingEvents, key)
			MentalService.onCanonEvent(s)
			-- ทรยศ (docs/02 §9.4): เสียเพื่อนคนแรก → บทเปลี่ยนเป็นชุด after + ใจร่วง
			-- flags.betrayed = สัญญาณให้ระบบพนักงาน (สาย B) ถอด producer คุณภาพสูงสุดออก
			if m == Config.BetrayalMilestone then
				s.flags.betrayed = true
				MentalService.applyDelta(s, Config.BetrayalMentalPenalty)
			end
			-- BCA ต่อท้าย 1M ทันที (docs/02 §9.4) — เวลาหยุดที่ 1M follower ไม่มีทางเกิน
			if m == Config.BCAAfterMilestone then
				table.insert(s.pendingEvents, Config.BCAEventId)
			end
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
	MentalService.onEdit(s) -- นับ streak ตัดคลิป 5 ติด
	MentalService.apply(s, "clipEdit")
end)
ActionRouter.register("UploadClip", function(s, a)
	if a.clip == "latest" then a.clip = #s.clips end
	local ok, viral = FollowerService.uploadClip(s, a, MentalService.effective(s))
	if ok then
		if viral then
			MentalService.onViral(s) -- viral 2 วันติด → recover ×2
			MentalService.apply(s, "viralClip")
		end
		CommentService.generate(s, s.clips[a.clip] and s.clips[a.clip].tier)
		checkMilestones(s)
		checkEnding(s)
	end
end)
ActionRouter.register("DoActivity", function(s, a)
	if MentalService.doActivity(s, a.activity) then
		MentalService.onActivityDone(s) -- ล้าง EditStreak5/CommentBadStreak3
	end
end)
ActionRouter.register("AnswerComment", function(s, a)
	local handled, tag, reason = CommentService.answer(s, a)
	if not handled then return end
	if reason then MentalService.apply(s, reason) end
	if tag then MentalService.onCommentAnswered(s, tag) end -- streak สองฝั่ง (skip/neu ไม่แตะ streak)
	checkEnding(s)
end)
ActionRouter.register("BuyUpgrade", function(s, a)
	MoneyService.buyUpgrade(s, a.item)
end)
ActionRouter.register("AdjustSpending", function(s, a) -- ⊖⊕ ใน Bank
	MoneyService.adjustSpending(s, a.card, a.dir)
end)
ActionRouter.register("MoveBlock", function(s, a) -- ย้าย block ปฏิทิน (ทาง ก: กดเลือก+กดปลายทาง)
	CalendarService.moveBlock(s, a.fromDay, a.toDay)
end)
ActionRouter.register("Sleep", function(s)
	TimeService.sleep(s) -- ข้ามเวลา 8/12 ชม.ตามช่วงที่นอน
	MentalService.onSleep(s) -- ล้าง NoSleep + นับตื่นใหม่
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
-- Main Menu (PDF หน้า 1): slot list ส่งกลับทาง state.slotList — ไม่เพิ่ม Remote
ActionRouter.register("RequestSlots", function(s, a, player)
	s.slotList = GameState.listSlots(player.UserId)
end)
ActionRouter.register("LoadSlot", function(s, a, player)
	local loaded = GameState.loadSlot(player.UserId, tonumber(a.slot) or 1)
	if loaded then GameState.replaceWith(s, loaded) end
end)
ActionRouter.register("SaveSlot", function(s, a, player)
	s.slot = tonumber(a.slot) or s.slot
	GameState.saveSlot(player.UserId, s)
end)
ActionRouter.register("NewGame", function(s, a)
	local fresh = GameState.newGame()
	fresh.slot = tonumber(a.slot) or 1
	GameState.replaceWith(s, fresh)
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
	if ActionRouter.route(state, action, player) then
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
	local broke, billed = MoneyService.onDay(s)
	if broke then
		MentalService.apply(s, "rentMissed")
	end
	if billed then -- ผลใจไลฟ์สไตล์ (Bank ⊖⊕) เฉพาะวันตัดรอบ
		local delta = MoneyService.lifestyleMental(s)
		if delta ~= 0 then MentalService.applyDelta(s, delta) end
	end
	CalendarService.onDay(s)
	checkEnding(s)
end)
TimeService.start(state)

game:BindToClose(function()
	local player = Players:GetPlayers()[1]
	if player then GameState.saveSlot(player.UserId, state) end
end)
