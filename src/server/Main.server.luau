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
local StaffService = require(SSS.Services.StaffService)
local RecordService = require(SSS.Services.RecordService)
local ToolService = require(SSS.Services.ToolService)
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
	StaffService.syncCompanions(s) -- เพื่อนเข้า/โต/ออก ตาม follower+เฟส+ทรยศ (docs/02 §9.8)
end

-- เช็คจบเกมหลังทุกความเปลี่ยนแปลงสำคัญ — เจอแล้วหยุดเวลา รอ client เล่น cutscene
local function checkEnding(s)
	local ending = EndingService.check(s)
	if ending then
		s.flags.ending = ending
		TimeService.setFrozen(true)
	end
end

-- ===== โซนถ่าย: หา FilmSpot_* ในแมพ แล้วสุ่มย้ายทุก 120 วิ (docs/02 §9.5) =====
local function filmSpots()
	local names = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Name:sub(1, 9) == "FilmSpot_" then
			table.insert(names, d.Name)
		end
	end
	return names
end

-- ทุกการกระทำของผู้เล่น — service ไม่เรียก push เอง Main push หลัง route สำเร็จ
-- โน้ตบุ๊คเฟส 1: กดวางลงพื้น → กลายเป็นคอมใช้งานได้ (Interact_pcMonitor อยู่ในโมเดล) / เก็บกลับได้
ActionRouter.register("PlaceNotebook", function(s, a, player)
	if typeof(a.cf) == "CFrame" and ToolService.placeNotebook(s, a.cf) and player then
		ToolService.sync(player, s)
	end
end)
ActionRouter.register("PickupNotebook", function(s, a, player)
	if ToolService.pickupNotebook(s) and player then
		ToolService.sync(player, s)
	end
end)
ActionRouter.register("RecordFootage", function(s, a)
	-- inZone มาจาก client (singleplayer เชื่อ client เหมือนคะแนน QTE) — server คุมสูตร/cooldown/cap เอง
	RecordService.record(s, { now = os.clock(), inZone = a.inZone == true })
end)
ActionRouter.register("FinishEdit", function(s, a)
	-- footage ไม่พอ = ไม่ได้คลิป ไม่เสียใจ (client กันไว้แล้วชั้นนึง นี่คือชั้นตัดสิน)
	if not RecordService.spendForClip(s) then return end
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
-- ย้อนไปใช้อุปกรณ์ระดับเก่าที่ซื้อไว้แล้ว (ผลลดลงจริง) — ToolService.sync หลัง route จะสลับ Tool ให้เอง
ActionRouter.register("EquipLevel", function(s, a)
	MoneyService.equipLevel(s, a.item, a.level)
end)
ActionRouter.register("AdjustSpending", function(s, a) -- ⊖⊕ ใน Bank
	MoneyService.adjustSpending(s, a.card, a.dir)
end)
ActionRouter.register("MoveBlock", function(s, a) -- ย้าย block ปฏิทิน (ทาง ก: กดเลือก+กดปลายทาง)
	CalendarService.moveBlock(s, a.fromDay, a.toDay)
end)
ActionRouter.register("HireStaff", function(s, a) -- แอป Manage (docs/02 §9.8)
	StaffService.hire(s, a.id)
end)
ActionRouter.register("FireStaff", function(s, a)
	StaffService.fire(s, a.id)
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
ActionRouter.register("DeleteSlot", function(s, a, player)
	GameState.deleteSlot(player.UserId, tonumber(a.slot) or 0)
	s.slotList = GameState.listSlots(player.UserId) -- refresh สมุดหน้าเมนู
end)
-- วาป player ไป Part ตามชื่อ — ทำที่ server เพราะ StreamingEnabled อาจ stream part ออกจาก client
ActionRouter.register("TeleportTo", function(s, a, player)
	local part = type(a.target) == "string" and workspace:FindFirstChild(a.target, true)
	local char = player and player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if part and part:IsA("BasePart") and root then
		root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
		-- สั่ง stream แมพรอบจุดปลายทางเข้ามาก่อน (client รอจอดำจนโหลดเสร็จ — waitStreamedAround)
		if player then
			pcall(function() player:RequestStreamingAround(part.Position) end)
		end
	elseif not part then
		warn("[Main.server] TeleportTo: ไม่เจอ Part", tostring(a.target))
	end
end)
ActionRouter.register("NewGame", function(s, a)
	local fresh = GameState.newGame()
	fresh.slot = tonumber(a.slot) or 1
	GameState.replaceWith(s, fresh)
	-- freeze เวลาที่ server ทันที (กัน lighting เพี้ยน/ข้ามวันตอนเล่น intro) — client unfreeze หลัง intro จบ
	TimeService.setFrozen(true)
end)
-- คุย NPC จบบทเต็ม → จำเฟสไว้ (คุยซ้ำเฟสเดิมเล่นบท repeat) persist ในเซฟ
ActionRouter.register("DialogueSeen", function(s, a)
	if type(a.name) == "string" then
		s.seenDialogue[a.name] = s.phase
	end
end)
ActionRouter.register("EventSeen", function(s, a)
	for i, id in s.pendingEvents do
		if id == a.id then
			table.remove(s.pendingEvents, i)
			break
		end
	end
end)

-- lighting ผูกกับนาฬิกาเกม (แทน Toolbox DayNight เดิมที่เดินแยก ไม่สน freeze) — freeze เวลา = ฟ้าหยุด
-- ClockTime = ชั่วโมงเกมตรงๆ (0-23) · เรียกทุกจุดที่ timeOfDay เปลี่ยน (action/onHour/boot)
local Lighting = game:GetService("Lighting")
local function syncLighting(s)
	Lighting.ClockTime = s.timeOfDay
end

-- client action ทุกอันวิ่งผ่านเส้นนี้เส้นเดียว
RS.Shared.Remotes.Action.OnServerEvent:Connect(function(player, action)
	if ActionRouter.route(state, action, player) then
		ToolService.sync(player, state) -- อัปกล้อง/ข้ามเฟส/วางโน้ตบุ๊ค = Tool ในมือเปลี่ยนทันที
		syncLighting(state) -- NewGame/LoadSlot/Sleep เปลี่ยน timeOfDay = ฟ้าตรงทันที
		GameState.push(state)
	end
end)

-- ผู้เล่นเข้า → ส่ง state ปัจจุบันให้ทันที
Players.PlayerAdded:Connect(function(player)
	ToolService.sync(player, state)
	player.CharacterAdded:Connect(function()
		task.wait(0.5) -- รอ Backpack ใหม่หลังเกิด
		ToolService.sync(player, state)
	end)
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
	syncLighting(s)
	GameState.push(s)
end)
-- ทุกวันใหม่: ครบ 7 วันหักรายจ่าย — จ่ายไม่ไหวหัก mental ต่อ + block ปฏิทิน + เช็คจบเกม
TimeService.onDay(function(s)
	-- ทีมผลิตคลิป auto ก่อนตัดรอบเงิน (docs/02 §9.8) — คลิปทีมสร้าง comment ปกติ
	for _, r in StaffService.produceDaily(s) do
		CommentService.generate(s, r.tier)
	end
	checkMilestones(s)

	local broke, billed = MoneyService.onDay(s)
	if broke then
		MentalService.apply(s, "rentMissed")
	end
	if billed then -- เงินเดือนทีม: จ่ายไม่ไหว = คนแพงสุดลาออกทีละคน
		local salary = StaffService.weeklySalary(s)
		if salary > 0 then
			if s.money >= salary then
				s.money -= salary
			else
				StaffService.resign(s, s.money)
				s.money = math.max(0, s.money - StaffService.weeklySalary(s))
			end
		end
	end
	if billed then -- ผลใจไลฟ์สไตล์ (Bank ⊖⊕) เฉพาะวันตัดรอบ
		local delta = MoneyService.lifestyleMental(s)
		if delta ~= 0 then MentalService.applyDelta(s, delta) end
	end
	CalendarService.onDay(s)
	CalendarService.rollSponsorOffer(s, math.random)
	checkEnding(s)
end)
TimeService.start(state)
syncLighting(state) -- ตั้งฟ้าให้ตรงเวลาเริ่ม (ไม่งั้นค้างค่า default จนชั่วโมงแรก)

-- โซนถ่ายย้ายจุดเอง (กัน AFK จุดเดิม) — เช็คทุก 2 วิ ย้ายจริงเมื่อครบ 120 วิ
task.spawn(function()
	while true do
		if RecordService.tickZone(state, os.clock(), filmSpots(), math.random) then
			GameState.push(state)
		end
		task.wait(2)
	end
end)

game:BindToClose(function()
	local player = Players:GetPlayers()[1]
	if player then GameState.saveSlot(player.UserId, state) end
end)
