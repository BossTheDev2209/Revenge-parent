-- Main.server — จุดเริ่มเดียวของ server: wiring ทุกอย่างอยู่ไฟล์นี้ไฟล์เดียว
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
local SponsorService = require(SSS.Services.SponsorService)
local EndingService = require(SSS.Services.EndingService)
local StaffService = require(SSS.Services.StaffService)
local RecordService = require(SSS.Services.RecordService)
local ToolService = require(SSS.Services.ToolService)
local Config = require(RS.Shared.Config)
local Formulas = require(RS.Shared.Formulas)

local state = GameState.newGame()

-- follower ข้าม milestone → flag + คิว event ให้ client เล่นบท + drain แรงขึ้น 1 วัน
local function checkMilestones(s)
	for _, m in Config.StoryMilestones do
		local key = "milestone_" .. m
		if s.follower >= m and not s.flags[key] then
			s.flags[key] = true
			table.insert(s.pendingEvents, key)
			MentalService.onCanonEvent(s)
			-- ทรยศ: เสียเพื่อนคนแรก + ใจร่วง · flags.betrayed = สัญญาณให้ StaffService ถอด producer แพงสุด
			if m == Config.BetrayalMilestone then
				s.flags.betrayed = true
				MentalService.applyDelta(s, Config.BetrayalMentalPenalty)
			end
			-- BCA ต่อท้าย 1M ทันที (เวลาหยุดที่ 1M follower ไม่มีทางเกิน)
			if m == Config.BCAAfterMilestone then
				table.insert(s.pendingEvents, Config.BCAEventId)
			end
		end
	end
	StaffService.syncCompanions(s) -- เพื่อนเข้า/โต/ออก ตาม follower+เฟส+ทรยศ
end

-- เจอ ending → หยุดเวลา รอ client เล่น cutscene
local function checkEnding(s)
	local ending = EndingService.check(s)
	if ending then
		s.flags.ending = ending
		TimeService.setFrozen(true)
	end
end

-- โซนถ่ายรายเฟส: FilmSpot_* ใต้ Workspace.FilmSpots.phase<N> (player ย้อนเฟสไม่ได้)
local function filmSpots(phase: number)
	local names = {}
	local root = workspace:FindFirstChild("FilmSpots")
	local folder = root and root:FindFirstChild("phase" .. tostring(phase))
	if folder then
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") and d.Name:sub(1, 9) == "FilmSpot_" then
				table.insert(names, d.Name)
			end
		end
	end
	return names
end

-- ทุกการกระทำของผู้เล่น — service ไม่เรียก push เอง Main push หลัง route สำเร็จ
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
	-- inZone มาจาก client (เชื่อเหมือนคะแนน QTE) — server คุมสูตร/cooldown/cap เอง
	if s.pendingRecordQTE then return end -- มี QTE ค้างอยู่ = ไม่รับคลิกใหม่
	local r = RecordService.record(s, { now = os.clock(), inZone = a.inZone == true })
	if r.qte then
		local hits = RecordService.pickHitsRequired(Config.RecordQTE.hitsMin, Config.RecordQTE.hitsMax)
		s.pendingRecordQTE = { id = os.clock(), hits = hits } -- id ให้ client dedupe
	end
end)
-- client กด QTE ครบแล้ว → ส่งเกรดทั้งชุด (1 ค่าต่อครั้งกด) · server ให้ footage bonus + cap
ActionRouter.register("RecordQTEResult", function(s, a)
	if not s.pendingRecordQTE then return end -- ไม่มี QTE ค้าง = ทิ้ง (กันยิงมั่วเอา reward)
	s.pendingRecordQTE = nil
	local grades = {}
	if type(a.grades) == "table" then
		for _, g in a.grades do
			table.insert(grades, (g == "perfect" or g == "good") and g or "miss") -- validate ทีละค่า
		end
	end
	RecordService.grantQTE(s, grades)
end)
ActionRouter.register("FinishEdit", function(s, a)
	-- footage ไม่พอ = ไม่ได้คลิป ไม่เสียใจ · a.footageGB = ขนาดที่เลือก (ไม่ส่ง = 32)
	if not RecordService.spendForClip(s, a.footageGB) then return end
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
	if tag then MentalService.onCommentAnswered(s, tag) end -- streak สองฝั่ง
	checkEnding(s)
end)
ActionRouter.register("BuyUpgrade", function(s, a)
	MoneyService.buyUpgrade(s, a.item)
end)
-- Tool Camera_6 = รีโมทเรียกรถเข็นกล้อง — ต้องถึง CameraCartLevel จริง (server ตัดสิน)
ActionRouter.register("SummonCart", function(s, a, player)
	if Formulas.activeLevel(s, "camera") < Config.CameraCartLevel then return end
	ToolService.summonCart(player)
end)
ActionRouter.register("EquipLevel", function(s, a)
	MoneyService.equipLevel(s, a.item, a.level)
end)
-- ซื้อของกินที่แอป Shop = ดื่มทันที · server ตัดเงิน/ตั้งเวลาหมดฤทธิ์
ActionRouter.register("BuyConsumable", function(s, a)
	MoneyService.buyConsumable(s, a.item)
end)
ActionRouter.register("AdjustSpending", function(s, a) -- ⊖⊕ ใน Bank
	MoneyService.adjustSpending(s, a.card, a.dir)
end)
ActionRouter.register("HireStaff", function(s, a)
	StaffService.hire(s, a.id)
end)
ActionRouter.register("FireStaff", function(s, a)
	StaffService.fire(s, a.id)
end)
-- event "พนักงานตีกัน" (beat ฝั่ง client ยิงตอนถึงจังหวะ) — ครั้งเดียว
ActionRouter.register("StaffSplit", function(s)
	if s.flags.staffSplit then return end
	s.flags.staffSplit = true
	s.lastStaffSplit = StaffService.splitStaff(s) -- { left = {ids}, joined = id? }
end)
-- ตั้งที่อยู่ StoryNPC (beat เรียกใต้จอดำ) — StoryNPCPlacer ฝั่ง client ย้ายตามหลัง push
ActionRouter.register("SetNpcLoc", function(s, a)
	if type(a.actor) == "string" and type(a.loc) == "string" then
		s.npcLoc[a.actor] = a.loc
	end
end)
-- ตั้ง story flag ให้ persist — เฉพาะ flag ขึ้นต้น story_ หรือ *_joined กันตั้งมั่ว
ActionRouter.register("SetFlag", function(s, a)
	if type(a.name) == "string" then
		s.flags[a.name] = a.value ~= false
	end
end)
ActionRouter.register("Sleep", function(s)
	TimeService.sleep(s)   -- ข้ามเวลา 8/12 ชม.ตามช่วงที่นอน
	MentalService.onSleep(s) -- ล้าง NoSleep + นับตื่นใหม่
end)
ActionRouter.register("AcceptSponsor", function(s)
	SponsorService.accept(s)
end)
-- กดรับเงินก้อน sponsor ตาม milestone จากแอป Inbox — client ส่งแค่ id, server ตัดสินทั้งหมด
-- ⚠️ ห้าม push ลง s.pendingEvents (คิวนั้นเก็บ string id ของ canon event เท่านั้น)
--    ยัด table ลงไป = client หา CanonEvents[table] ไม่เจอ → คิวไม่มีวันว่าง → ข้ามเฟส/ending ค้างถาวร
ActionRouter.register("ClaimDMPayout", function(s, a)
	SponsorService.claimDM(s, a.id)
end)
ActionRouter.register("FreezeTime", function(s, a)
	TimeService.setFrozen(a.on == true)
	s.frozen = a.on == true -- ให้ HUD หยุดนาฬิกาตอน cutscene/คุย
end)
ActionRouter.register("RequestSlots", function(s, a, player)
	local slots, failed = GameState.listSlots(player.UserId)
	s.slotList = slots
	s.slotsFailed = next(failed) and failed or nil -- ช่องที่อ่านไม่สำเร็จ → client โชว์ "ลองใหม่"
end)
ActionRouter.register("LoadSlot", function(s, a, player)
	local loaded = GameState.loadSlot(player.UserId, tonumber(a.slot) or 1, a.which)
	if loaded then
		GameState.replaceWith(s, loaded)
		s.started = true -- commit เข้าเกมแล้ว → autosave ทำงานได้
		s.spawnTarget = "Spawn_Phase" .. s.phase -- วาปไปสปอว์นของเฟสตรงๆ ไม่เล่น cutscene ข้ามเฟส
	end
end)
-- client วาปตาม spawnTarget แล้ว → เคลียร์ (ไม่งั้น push ถัดไปวาปซ้ำ)
ActionRouter.register("ConsumeSpawn", function(s)
	s.spawnTarget = nil
end)
-- อัป slotList เฉพาะช่องที่เปลี่ยน (ไม่ re-read ทั้ง 4 ช่อง — กัน GetAsync cache race)
ActionRouter.register("SaveSlot", function(s, a, player)
	s.slot = tonumber(a.slot) or s.slot
	local _, sum = GameState.saveSlot(player.UserId, s, false) -- manual = push เข้า snapshot history
	s.slotList = s.slotList or {}
	s.slotList[s.slot] = sum
end)
ActionRouter.register("DeleteSlot", function(s, a, player)
	local slot = tonumber(a.slot) or 0
	GameState.deleteSlot(player.UserId, slot)
	if s.slotList then s.slotList[slot] = nil end
end)
ActionRouter.register("DeleteSnapshot", function(s, a, player)
	local slot = tonumber(a.slot) or 0
	local _, sum = GameState.deleteSnapshot(player.UserId, slot, a.which)
	if s.slotList then s.slotList[slot] = sum end
end)
-- วาป player ไป Part ตามชื่อ — ทำที่ server เพราะ StreamingEnabled อาจ stream part ออกจาก client
ActionRouter.register("TeleportTo", function(s, a, player)
	local part = type(a.target) == "string" and workspace:FindFirstChild(a.target, true)
	local char = player and player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if part and part:IsA("BasePart") and root then
		root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
		if player then
			pcall(function() player.ReplicationFocus = nil end) -- คืน focus จาก cutscene
			pcall(function() player:RequestStreamingAround(part.Position) end)
		end
	elseif not part then
		warn("[Main.server] TeleportTo: ไม่เจอ Part", tostring(a.target))
	end
end)
-- ย้ายศูนย์กลาง streaming ไป Part อื่น (preload แมพจุดนั้น) — ใช้ตอน cutscene ส่องแมพไกล
ActionRouter.register("SetFocus", function(s, a, player)
	if not player then return end
	if type(a.target) == "string" then
		local part = workspace:FindFirstChild(a.target, true)
		if part and part:IsA("BasePart") then
			pcall(function() player.ReplicationFocus = part end)
		end
	else
		pcall(function() player.ReplicationFocus = nil end)
	end
end)
ActionRouter.register("NewGame", function(s, a)
	local fresh = GameState.newGame()
	fresh.slot = tonumber(a.slot) or 1
	fresh.started = true
	GameState.replaceWith(s, fresh)
	TimeService.setFrozen(true) -- กัน lighting เพี้ยน/ข้ามวันตอนเล่น intro (client unfreeze หลัง intro)
end)
-- preference (เซฟไปกับเกม) — client เปลี่ยนค่าแล้วส่งมาเก็บ
ActionRouter.register("SetSetting", function(s, a)
	s.settings = s.settings or {}
	if a.key == "volume" or a.key == "bgmVol" or a.key == "sfxVol" or a.key == "ambientVol" then
		s.settings[a.key] = math.clamp(tonumber(a.value) or 1, 0, 1)
	elseif a.key == "shadow" or a.key == "musicMuted" or a.key == "hideBillboards" then
		s.settings[a.key] = a.value == true
	end
end)
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

-- lighting ผูกกับนาฬิกาเกม — freeze เวลา = ฟ้าหยุด · ClockTime = ชั่วโมงเกมตรงๆ (0-23)
local Lighting = game:GetService("Lighting")
local function syncLighting(s)
	Lighting.ClockTime = s.timeOfDay
end

-- dev console (Studio เท่านั้น + Config.DevUserIds ตอน published) — /dev <cmd> ตั้ง state ตรงๆ
ActionRouter.register("DevCmd", function(s, a, player)
	local allowed = game:GetService("RunService"):IsStudio()
		or (player and table.find(Config.DevUserIds, player.UserId) ~= nil)
	if not allowed then return end
	local c = tostring(a.cmd):lower()
	local n = tonumber(a.value)
	if c == "money" and n then
		s.money = n
	elseif c == "follower" and n then
		s.follower = n
		s.phase = Formulas.phaseFor(n)
		checkMilestones(s) -- ยิง milestone event/betrayed/BCA ตามยอด
		checkEnding(s)
	elseif c == "phase" and n then
		local gate = { [1] = 0, [2] = 10_000, [3] = 100_000 }
		s.follower = gate[n] or s.follower
		s.phase = math.clamp(n, 1, 3)
		checkMilestones(s)
	elseif c == "time" and n then
		s.timeOfDay = math.clamp(n, 0, 23)
		syncLighting(s)
	elseif c == "mental" and n then
		s.mental = math.clamp(n, 0, 100)
	elseif c == "day" and n then
		s.day = n
	elseif c == "flag" and a.value then
		s.flags[a.value] = a.value2 ~= "false"
	elseif c == "ending" and a.value then
		s.flags.ending = a.value
		TimeService.setFrozen(true)
	elseif c == "npcloc" and a.value and a.value2 then
		s.npcLoc[a.value] = a.value2
	elseif c == "staffsplit" then
		s.flags.staffSplit = false -- อนุญาตยิงซ้ำระหว่าง dev
		s.lastStaffSplit = StaffService.splitStaff(s)
		s.flags.staffSplit = true
	elseif c == "qte" then
		-- force-trigger RecordQTE · /dev qte <n> = บังคับจำนวนครั้งที่ต้องกด
		local hits = n or RecordService.pickHitsRequired(Config.RecordQTE.hitsMin, Config.RecordQTE.hitsMax)
		s.pendingRecordQTE = { id = os.clock(), hits = math.clamp(hits, 1, 20) }
	else
		warn("[DevCmd] ไม่รู้จัก:", c)
	end
end)

-- client action ทุกอันวิ่งผ่านเส้นนี้เส้นเดียว
RS.Shared.Remotes.Action.OnServerEvent:Connect(function(player, action)
	if ActionRouter.route(state, action, player) then
		ToolService.sync(player, state) -- อัปกล้อง/ข้ามเฟส/วางโน้ตบุ๊ค = Tool ในมือเปลี่ยนทันที
		syncLighting(state)
		GameState.push(state)
	end
end)

-- ผู้เล่นเข้า → ส่ง state ปัจจุบันทันที + prefetch slotList
Players.PlayerAdded:Connect(function(player)
	ToolService.sync(player, state)
	player.CharacterAdded:Connect(function()
		task.wait(0.5) -- รอ Backpack ใหม่หลังเกิด
		ToolService.sync(player, state)
	end)
	GameState.push(state)
	-- prefetch ระหว่างผู้เล่นยังโหลดเข้าเกม (listSlots yield ~1.6s) → พร้อมก่อนเมนูเปิด
	task.spawn(function()
		local slots, failed = GameState.listSlots(player.UserId)
		state.slotList = slots
		state.slotsFailed = next(failed) and failed or nil
		GameState.push(state)
	end)
end)

-- autosave ทุก 60 วิ ถ้ามีอะไรเปลี่ยน (เฉพาะ started=true — กัน placeholder ทับเซฟจริง)
task.spawn(function()
	while true do
		task.wait(60)
		local player = Players:GetPlayers()[1]
		if player and state.started and GameState.isDirty() then
			GameState.saveSlot(player.UserId, state, true)
		end
	end
end)

-- นาฬิกาเกม: เดินตลอด, ทุกชั่วโมง mod หมดอายุ/นับตื่น + push (client เห็นนาฬิกาขยับ)
-- ★ mental natural drain ไม่อยู่ตรงนี้แล้ว (แก้ 10 ส.ค. — ดู loop ท้ายไฟล์ "หลอดใจไหลลื่นทุกวิ")
TimeService.onHour(function(s)
	MentalService.onHour(s)
	for _, e in MoneyService.expireBuffs(s) do -- ของกินหมดฤทธิ์ → หักใจ
		MentalService.applyDelta(s, e.mental)
	end
	syncLighting(s)
	GameState.push(s)
end)
-- ทุกวันใหม่: ทีมผลิตคลิป → ครบ 7 วันหักรายจ่าย + เงินเดือนทีม + เช็คจบเกม
TimeService.onDay(function(s)
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
	SponsorService.onDay(s, math.random) -- offer เก่าหมดอายุ + สุ่มใบใหม่
	checkEnding(s)
end)
TimeService.start(state)
syncLighting(state)

-- โซนถ่ายย้ายจุดเอง (กัน AFK) — เช็คทุก 2 วิ ย้ายจริงเมื่อครบ 120 วิ
task.spawn(function()
	while true do
		if RecordService.tickZone(state, os.clock(), filmSpots(state.phase), math.random) then
			GameState.push(state)
		end
		task.wait(2)
	end
end)

-- หลอดใจไหลลื่นทุกวิ (แก้ 10 ส.ค. — user: "ลดไวเกินขนาด...ลดฮวบๆ ไม่สมูท")
-- เดิม natural drain ผูกกับ TimeService.onHour → ยิงทีเดียว 1.667%+ ทุก 7.5 วิจริง (ก้อนใหญ่ ไม่สมูท)
-- ย้ายมา tick ทุก 1 วิจริงแทน อัตราเฉลี่ยเท่าเดิมเป๊ะ (1%/4.5วิ ตาม design doc §3) แค่ก้อนเล็กลง ~7 เท่า
-- เว้นตอน dialogue/cutscene freeze เวลา (TimeService.isFrozen) ให้ตรงกับที่ TimeService.tick หยุดเหมือนกัน
task.spawn(function()
	while true do
		task.wait(1)
		-- ก่อนเฟส 2 / กำลังหลับ / กำลัง freeze (dialogue-cutscene) = tickDrain no-op อยู่แล้ว
		-- เช็คซ้ำตรงนี้กัน push เปล่าทุกวิทั้งที่ใจไม่ขยับ (ประหยัด remote traffic)
		if not TimeService.isFrozen() and state.phase >= Config.Mental.introducedInPhase and not state.sleeping then
			MentalService.tickDrain(state, 1)
			GameState.push(state)
		end
	end
end)

game:BindToClose(function()
	local player = Players:GetPlayers()[1]
	if player and state.started then GameState.saveSlot(player.UserId, state, true) end
end)
