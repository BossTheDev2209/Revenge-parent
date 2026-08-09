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
-- ★ CalendarService ถูกพับไว้ 9 ส.ค. (user) — sponsor ย้ายไปเป็น notification ดู SponsorService
--   ไฟล์ CalendarService.luau + CalendarApp.luau ยังอยู่ครบ แค่ไม่ wire · จะรื้อกลับมา require ตรงนี้
local SponsorService = require(SSS.Services.SponsorService)
local EndingService = require(SSS.Services.EndingService)
local StaffService = require(SSS.Services.StaffService)
local RecordService = require(SSS.Services.RecordService)
local ToolService = require(SSS.Services.ToolService)
local Config = require(RS.Shared.Config)
local Formulas = require(RS.Shared.Formulas)

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

-- ===== โซนถ่าย: หา FilmSpot_* เฉพาะเฟสปัจจุบัน แล้วสุ่มย้ายทุก 120 วิ (docs/02 §9.5) =====
-- แยกรายเฟส: spot อยู่ใต้ Workspace.FilmSpots.phase<N> — player ย้อนเฟสไม่ได้ จุดถ่ายเฟสก่อนใช้ไม่ได้
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
	if s.pendingRecordQTE then return end -- มี QTE ค้างรอเล่นอยู่ = ไม่รับคลิกใหม่ (กันซ้อน QTE)
	local r = RecordService.record(s, { now = os.clock(), inZone = a.inZone == true })
	if r.qte then s.pendingRecordQTE = os.clock() end -- ค่า = id ให้ client dedupe (ไม่ retrigger จาก push ซ้ำ)
end)
-- client เล่น QTE เสร็จ → ส่งเกรด (perfect/good/miss) — server ให้ footage bonus (docs/02 §9.5)
--   เชื่อเกรด client (singleplayer เหมือน inZone/คะแนน) · server คุมสูตร reward + cap + เคลียร์ pending เอง
ActionRouter.register("RecordQTEResult", function(s, a)
	if not s.pendingRecordQTE then return end -- ไม่มี QTE ค้าง = ทิ้ง (กัน client ยิงมั่วเอา reward)
	s.pendingRecordQTE = nil
	local grade = a.grade
	if grade ~= "perfect" and grade ~= "good" then grade = "miss" end -- validate → miss
	RecordService.grantQTE(s, grade)
end)
ActionRouter.register("FinishEdit", function(s, a)
	-- footage ไม่พอ = ไม่ได้คลิป ไม่เสียใจ (client กันไว้แล้วชั้นนึง นี่คือชั้นตัดสิน)
	-- a.footageGB = ขนาดที่ผู้เล่นเลือก (ไม่ส่ง = 32) — หักตามขนาด แล้วเก็บลงคลิปเพื่อคูณ reward
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
	if tag then MentalService.onCommentAnswered(s, tag) end -- streak สองฝั่ง (skip/neu ไม่แตะ streak)
	checkEnding(s)
end)
ActionRouter.register("BuyUpgrade", function(s, a)
	MoneyService.buyUpgrade(s, a.item)
end)
-- ย้อนไปใช้อุปกรณ์ระดับเก่าที่ซื้อไว้แล้ว (ผลลดลงจริง) — ToolService.sync หลัง route จะสลับ Tool ให้เอง
-- Tool Camera_6 = รีโมทเรียกรถเข็นกล้อง — เสกใหม่ทุกครั้งที่กด (ลบคันเก่าก่อน)
-- ต้องถึงระดับ CameraCartLevel จริงถึงเรียกได้ — server ตัดสิน ไม่เชื่อ client
ActionRouter.register("SummonCart", function(s, a, player)
	if Formulas.activeLevel(s, "camera") < Config.CameraCartLevel then return end
	ToolService.summonCart(player)
end)
ActionRouter.register("EquipLevel", function(s, a)
	MoneyService.equipLevel(s, a.item, a.level)
end)
ActionRouter.register("AdjustSpending", function(s, a) -- ⊖⊕ ใน Bank
	MoneyService.adjustSpending(s, a.card, a.dir)
end)
ActionRouter.register("HireStaff", function(s, a) -- แอป Manage (docs/02 §9.8)
	StaffService.hire(s, a.id)
end)
ActionRouter.register("FireStaff", function(s, a)
	StaffService.fire(s, a.id)
end)
-- event "พนักงานตีกัน" (scripted — beat ฝั่ง client ยิงตอนถึงจังหวะ) — ครั้งเดียว
-- hire ที่ tag leavesOnSplit ลาออก + worldNPC ผู้ภักดี auto เข้า · ผลเก็บใน s.lastStaffSplit ให้ client โชว์ DM/cutscene
ActionRouter.register("StaffSplit", function(s)
	if s.flags.staffSplit then return end
	s.flags.staffSplit = true
	s.lastStaffSplit = StaffService.splitStaff(s) -- { left = {ids}, joined = id? }
end)
-- ตั้งที่อยู่ StoryNPC (beat เรียกใต้จอดำ) — StoryNPCPlacer ฝั่ง client ย้ายตัวตามหลัง push
ActionRouter.register("SetNpcLoc", function(s, a)
	if type(a.actor) == "string" and type(a.loc) == "string" then
		s.npcLoc[a.actor] = a.loc
	end
end)
-- ตั้ง story flag ให้ persist (beat เล่นจบแล้ว mark ไม่ให้ยิงซ้ำ เช่น faasai_joined) — เฉพาะ flag ขึ้นต้น story_ หรือ *_joined กันตั้งมั่ว
-- singleplayer story: client เป็นคนคุมจังหวะ beat อยู่แล้ว — server แค่เก็บ/push ให้เซฟติดไปด้วย
ActionRouter.register("SetFlag", function(s, a)
	if type(a.name) == "string" then
		s.flags[a.name] = a.value ~= false
	end
end)
ActionRouter.register("Sleep", function(s)
	TimeService.sleep(s) -- ข้ามเวลา 8/12 ชม.ตามช่วงที่นอน
	MentalService.onSleep(s) -- ล้าง NoSleep + นับตื่นใหม่
end)
-- กดรับงาน sponsor จาก toast — ไม่มี day แล้ว (buff เริ่มทันที ดู SponsorService)
ActionRouter.register("AcceptSponsor", function(s)
	SponsorService.accept(s)
end)
ActionRouter.register("FreezeTime", function(s, a)
	TimeService.setFrozen(a.on == true)
	s.frozen = a.on == true -- ให้ HUD หยุดนาฬิกานาทีตอน cutscene/คุย
end)
-- Main Menu (PDF หน้า 1): slot list ส่งกลับทาง state.slotList — ไม่เพิ่ม Remote
ActionRouter.register("RequestSlots", function(s, a, player)
	local slots, failed = GameState.listSlots(player.UserId)
	s.slotList = slots
	s.slotsFailed = next(failed) and failed or nil -- ช่องที่ DataStore อ่านไม่สำเร็จ → client โชว์ "ลองใหม่" ไม่ใช่ "ว่าง"
end)
ActionRouter.register("LoadSlot", function(s, a, player)
	-- a.which = "auto" | เลข index snapshot | ไม่ส่ง (= ล่าสุดในช่อง)
	local loaded = GameState.loadSlot(player.UserId, tonumber(a.slot) or 1, a.which)
	if loaded then
		GameState.replaceWith(s, loaded)
		s.started = true -- commit เข้าเกมแล้ว → autosave ทำงานได้
		-- โหลดเซฟ = ให้ client วาปไปสปอว์นของเฟสนั้นตรงๆ ไม่เล่น cutscene ข้ามเฟส (bug: เข้าใหม่ขึ้น cutscene/baseplate)
		s.spawnTarget = "Spawn_Phase" .. s.phase
	end
end)
-- client วาปตาม spawnTarget แล้ว → เคลียร์ (ไม่งั้น push ถัดไปวาปซ้ำ · ไม่อยู่ใน newGame defaults = ไม่ค้างในเซฟ)
ActionRouter.register("ConsumeSpawn", function(s)
	s.spawnTarget = nil
end)
-- อัป slotList แบบ authoritative เฉพาะช่องที่เปลี่ยน (ไม่ re-read ทั้ง 4 ช่องจาก DataStore หลัง write)
-- bug 8 ส.ค.: listSlots หลัง Remove/SetAsync เจอ GetAsync cache/throttle race → ช่องอื่นเพี้ยน/หาย (cascade)
ActionRouter.register("SaveSlot", function(s, a, player)
	s.slot = tonumber(a.slot) or s.slot
	local _, sum = GameState.saveSlot(player.UserId, s, false) -- manual = push เข้า snapshot history
	s.slotList = s.slotList or {}
	s.slotList[s.slot] = sum -- summary ช่องนี้จาก file ในมือ (cache-proof) ช่องอื่นคงเดิม
end)
ActionRouter.register("DeleteSlot", function(s, a, player)
	local slot = tonumber(a.slot) or 0
	GameState.deleteSlot(player.UserId, slot)
	if s.slotList then s.slotList[slot] = nil end -- ลบเฉพาะช่องนี้ ช่องอื่นไม่แตะ = ไม่หายตาม
end)
ActionRouter.register("DeleteSnapshot", function(s, a, player)
	local slot = tonumber(a.slot) or 0
	local _, sum = GameState.deleteSnapshot(player.UserId, slot, a.which)
	if s.slotList then s.slotList[slot] = sum end -- sum=nil ถ้าช่องว่างหมด → หายเฉพาะช่องนี้
end)
-- วาป player ไป Part ตามชื่อ — ทำที่ server เพราะ StreamingEnabled อาจ stream part ออกจาก client
ActionRouter.register("TeleportTo", function(s, a, player)
	local part = type(a.target) == "string" and workspace:FindFirstChild(a.target, true)
	local char = player and player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if part and part:IsA("BasePart") and root then
		root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
		if player then
			-- ตัวละครมาถึงปลายทางแล้ว = ให้เป็นศูนย์ streaming เอง คืน focus จาก cutscene (โซนนี้ preload ไว้แล้ว = ไม่ pause)
			pcall(function() player.ReplicationFocus = nil end)
			-- สั่ง stream แมพรอบจุดปลายทาง (เผื่อยังไม่โหลด — client รอจอดำ waitStreamedAround)
			pcall(function() player:RequestStreamingAround(part.Position) end)
		end
	elseif not part then
		warn("[Main.server] TeleportTo: ไม่เจอ Part", tostring(a.target))
	end
end)
-- ย้ายศูนย์กลาง streaming ไป Part อื่น (preload แมพจุดนั้นทั้งที่ player ยังไม่ไป) — ใช้ตอน cutscene ส่องแมพไกล
-- target ว่าง = คืน focus ให้ตัวละคร · ReplicationFocus มีเฉพาะ Roblox ปัจจุบัน (pcall กัน Studio เก่า)
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
	fresh.started = true -- commit เข้าเกมใหม่แล้ว → autosave ทำงานได้ (เขียนทับช่องนี้ตามเจตนาผู้เล่น)
	GameState.replaceWith(s, fresh)
	-- freeze เวลาที่ server ทันที (กัน lighting เพี้ยน/ข้ามวันตอนเล่น intro) — client unfreeze หลัง intro จบ
	TimeService.setFrozen(true)
end)
-- คุย NPC จบบทเต็ม → จำเฟสไว้ (คุยซ้ำเฟสเดิมเล่นบท repeat) persist ในเซฟ
-- preference (เซฟไปกับเกม) — client เปลี่ยนค่าแล้วส่งมาเก็บ → persist ในเซฟ · โหลดคืนได้ (docs settings)
ActionRouter.register("SetSetting", function(s, a)
	s.settings = s.settings or {}
	if a.key == "volume" or a.key == "bgmVol" or a.key == "sfxVol" or a.key == "ambientVol" then
		s.settings[a.key] = math.clamp(tonumber(a.value) or 1, 0, 1)
	elseif a.key == "shadow" or a.key == "musicMuted" then
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

-- lighting ผูกกับนาฬิกาเกม (แทน Toolbox DayNight เดิมที่เดินแยก ไม่สน freeze) — freeze เวลา = ฟ้าหยุด
-- ClockTime = ชั่วโมงเกมตรงๆ (0-23) · เรียกทุกจุดที่ timeOfDay เปลี่ยน (action/onHour/boot)
local Lighting = game:GetService("Lighting")
local function syncLighting(s)
	Lighting.ClockTime = s.timeOfDay
end

-- ===== dev console (Studio เท่านั้น) — /dev <cmd> จาก DevConsole.client ตั้งค่า state ตรงๆ =====
-- guard IsStudio: published game ยิงมาก็ไม่ทำ (กันโกง) · push อัตโนมัติหลัง route
ActionRouter.register("DevCmd", function(s, a, player)
	-- Studio เปิดให้ทุกคนเสมอ · นอก Studio (published จริง) เปิดเฉพาะ UserId ใน Config.DevUserIds (docs/15)
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
		s.flags[a.value] = a.value2 ~= "false" -- ไม่ใส่ค่า/ไม่ใช่ "false" = true
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
		s.pendingRecordQTE = os.clock() -- force-trigger RecordQTE (client watch → เปิด skill-check ทันที ไม่ต้องรอสุ่ม 2%)
	else
		warn("[DevCmd] ไม่รู้จัก:", c)
	end
end)

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
	GameState.push(state) -- ส่ง state ทันที ไม่รอ DataStore
	-- prefetch slotList ระหว่างผู้เล่นยังโหลดเข้าเกม (listSlots yield ~1.6s) → พร้อมก่อนเมนูเปิด
	-- เมนูเปิดมา seed จาก state.slotList ที่ push นี้ส่งไปแล้ว = ไม่ต้องรอ RequestSlots อีกรอบ
	task.spawn(function()
		local slots, failed = GameState.listSlots(player.UserId)
		state.slotList = slots
		state.slotsFailed = next(failed) and failed or nil -- prefetch พลาดบางช่อง → client auto-retry เอง (ไม่ต้อง rejoin)
		GameState.push(state)
	end)
end)

-- autosave ทุก 60 วิ ถ้ามีอะไรเปลี่ยน + ตอนปิดเกม
task.spawn(function()
	while true do
		task.wait(60)
		local player = Players:GetPlayers()[1]
		-- state.started = ผู้เล่น commit เข้าเกมแล้ว · ยังอยู่หน้าเมนู = ห้ามเซฟ placeholder ทับเซฟจริง
		if player and state.started and GameState.isDirty() then
			GameState.saveSlot(player.UserId, state, true) -- autosave = auto-snapshot (ทับตัวเดียว ไม่รก history)
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
	-- offer เก่าที่ไม่กดรับหมดอายุ + สุ่มใบใหม่ (client เด้ง toast เองเมื่อเห็น sponsorOffer เปลี่ยนเป็น true)
	SponsorService.onDay(s, math.random)
	checkEnding(s)
end)
TimeService.start(state)
syncLighting(state) -- ตั้งฟ้าให้ตรงเวลาเริ่ม (ไม่งั้นค้างค่า default จนชั่วโมงแรก)

-- โซนถ่ายย้ายจุดเอง (กัน AFK จุดเดิม) — เช็คทุก 2 วิ ย้ายจริงเมื่อครบ 120 วิ
task.spawn(function()
	while true do
		if RecordService.tickZone(state, os.clock(), filmSpots(state.phase), math.random) then
			GameState.push(state)
		end
		task.wait(2)
	end
end)

game:BindToClose(function()
	local player = Players:GetPlayers()[1]
	-- ปิดเกมตอนยังอยู่เมนู (ยังไม่ commit) = ไม่เซฟ ไม่งั้น placeholder ทับเซฟจริงช่อง 1
	if player and state.started then GameState.saveSlot(player.UserId, state, true) end -- ปิดเกม = auto-snapshot
end)
