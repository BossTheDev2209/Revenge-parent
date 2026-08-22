-- RecordQTE — skill-check ตอนถ่ายคลิป: เข็มวิ่ง ping-pong บนแถบล่างจอ กด N ครั้ง (Space/แตะ)
--   กด 1 ครั้ง = เกรดจากตำแหน่งเข็มตอนนั้น เข็มเดินหน้าต่อ (ไม่รีเซ็ต/สลับทิศจากการกด)
--   เล่นจนครบ N เสมอ ไม่ fail-fast · โซนกึ่งกลางสุ่มครั้งเดียวคงที่ · ยิ่งกดไปเยอะ เข็มยิ่งไว
--   timeout: ไม่กดเลยเกิน timeoutSeconds = auto-จบ (ที่เหลือ miss) กัน InteractLock ค้าง
-- server สุ่ม chance + จำนวนครั้ง + คิด reward (RecordService) · ไฟล์นี้แค่เล่นแล้วส่งเกรดทั้งชุดกลับ
-- pure: gradeFor / sweepSecondsFor (เทส lune) · glue: start
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../shared/Config")

local RecordQTE = {}
RecordQTE.running = false

-- ตำแหน่งเข็ม (0..1) เทียบกึ่งกลางโซน → เกรด (pure)
function RecordQTE.gradeFor(pos: number, center: number, perfectHW: number, goodHW: number): string
	local d = math.abs(pos - center)
	if d <= perfectHW then return "perfect" end
	if d <= goodHW then return "good" end
	return "miss"
end

-- ความเร็วเข็มเมื่อกดสำเร็จไปแล้ว hitIndex-1 ครั้ง — เร่งจนถึงพื้น sweepSecondsMin (pure)
function RecordQTE.sweepSecondsFor(hitIndex: number, cfg): number
	local s = cfg.sweepSecondsStart - (hitIndex - 1) * cfg.sweepSpeedupPerHit
	return math.max(cfg.sweepSecondsMin, s)
end

-- hitsRequired: จำนวนครั้งที่ต้องกด (server สุ่มส่งมา) · zoneMult: { perfect, good } จากของกิน (ไม่ส่ง = 1)
--   โซนที่กว้างขึ้นใช้ทั้งวาดบนจอและตัดเกรดตัวเดียวกัน (เห็นตรงกับที่ได้จริง)
function RecordQTE.start(playerGui, fireAction, hitsRequired: number, zoneMult)
	if RecordQTE.running then return end
	RecordQTE.running = true
	hitsRequired = math.max(1, hitsRequired or 1)

	local Q = Config.RecordQTE
	local perfectHW = Q.perfectHalfWidth * ((zoneMult and zoneMult.perfect) or 1)
	local goodHW = math.min(Q.goodHalfWidth * ((zoneMult and zoneMult.good) or 1), 0.19) -- clamp กันโซนล้นจนได้แต้มฟรี
	local RunService = game:GetService("RunService")
	local CAS = game:GetService("ContextActionService")
	local UIS = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")
	local InteractLock = require(script.Parent.InteractLock)
	local Audio = require(script.Parent.AudioService)

	InteractLock.lock() -- ปิด E + freeze เดิน/กระโดด ตลอด QTE

	local center = Q.centerMin + math.random() * (Q.centerMax - Q.centerMin) -- สุ่มครั้งเดียว คงที่ตลอด
	local ACTION = "RecordQTE_Press"

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_RecordQTE"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Parent = playerGui

	local prompt = Instance.new("TextLabel")
	prompt.AnchorPoint = Vector2.new(0.5, 1)
	prompt.Position = UDim2.new(0.5, 0, 1, -178)
	prompt.Size = UDim2.fromOffset(460, 34)
	prompt.BackgroundTransparency = 1
	prompt.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	prompt.TextSize = 22
	prompt.TextColor3 = Color3.fromRGB(240, 242, 250)
	prompt.TextStrokeTransparency = 0.5
	prompt.Text = UIS.TouchEnabled and "แตะจอ! ให้เข็มตรงโซน" or "กด SPACE! ให้เข็มตรงโซน"
	prompt.Parent = gui

	local hitLabel = Instance.new("TextLabel")
	hitLabel.AnchorPoint = Vector2.new(0.5, 1)
	hitLabel.Position = UDim2.new(0.5, 0, 1, -150)
	hitLabel.Size = UDim2.fromOffset(200, 24)
	hitLabel.BackgroundTransparency = 1
	hitLabel.FontFace = Font.fromEnum(Enum.Font.Gotham)
	hitLabel.TextSize = 16
	hitLabel.TextColor3 = Color3.fromRGB(190, 194, 208)
	hitLabel.TextStrokeTransparency = 0.6
	hitLabel.Text = ("กดแล้ว 0/%d"):format(hitsRequired)
	hitLabel.Parent = gui

	local TRACK_W = 460
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -104)
	track.Size = UDim2.fromOffset(TRACK_W, 46)
	track.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	track.BackgroundTransparency = 0.1
	track.BorderSizePixel = 0
	track.Parent = gui
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 10)
	tc.Parent = track
	local tstroke = Instance.new("UIStroke")
	tstroke.Color = Color3.fromRGB(70, 74, 92)
	tstroke.Thickness = 1.5
	tstroke.Parent = track

	-- โซน Good (กว้าง) กับ Perfect (แคบ) — วาดเป็นสัดส่วนความกว้าง track
	local function zone(halfW, color, trans)
		local z = Instance.new("Frame")
		z.AnchorPoint = Vector2.new(0.5, 0.5)
		z.Position = UDim2.new(center, 0, 0.5, 0)
		z.Size = UDim2.new(halfW * 2, 0, 1, -8)
		z.BackgroundColor3 = color
		z.BackgroundTransparency = trans
		z.BorderSizePixel = 0
		z.ZIndex = 2
		z.Parent = track
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = z
		return z
	end
	zone(goodHW, Color3.fromRGB(70, 180, 120), 0.35)     -- Good = เขียว
	zone(perfectHW, Color3.fromRGB(245, 240, 180), 0.05) -- Perfect = ขาวนวล

	local NEEDLE_COLOR = Color3.fromRGB(255, 90, 90)
	local needle = Instance.new("Frame")
	needle.Name = "Needle"
	needle.AnchorPoint = Vector2.new(0.5, 0.5)
	needle.Position = UDim2.new(0, 0, 0.5, 0)
	needle.Size = UDim2.new(0, 5, 1, 4)
	needle.BackgroundColor3 = NEEDLE_COLOR
	needle.BorderSizePixel = 0
	needle.ZIndex = 5
	needle.Parent = track
	local nc = Instance.new("UICorner")
	nc.CornerRadius = UDim.new(0, 3)
	nc.Parent = needle
	local nScale = Instance.new("UIScale")
	nScale.Parent = needle

	-- pos/dir = physics ของเข็ม (bounce เองที่ขอบ) · hitsDone/grades = ผูกกับการกด — คนละแกนโดยเจตนา
	local pos, dir = 0, 1
	local hitsDone = 0
	local grades = {}
	local resolved = false
	local startedAt = os.clock()
	local heartbeat
	local inGoodBand = false -- กันเล่น qte_tick ทุก frame

	local GRADE_COLOR = {
		perfect = Color3.fromRGB(245, 240, 180),
		good = Color3.fromRGB(90, 210, 140),
		miss = Color3.fromRGB(235, 90, 90),
	}

	local function cleanup()
		if heartbeat then heartbeat:Disconnect() end
		pcall(function() CAS:UnbindAction(ACTION) end)
		InteractLock.unlock()
		RecordQTE.running = false
		task.delay(0.6, function() if gui then gui:Destroy() end end)
	end

	-- แฟลชสีเข็มตามเกรด + pop เล็กๆ (ไม่บล็อกการเล่นต่อ)
	local function flashGrade(grade)
		local c = GRADE_COLOR[grade]
		needle.BackgroundColor3 = c
		nScale.Scale = 1.6
		TweenService:Create(nScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		TweenService:Create(needle, TweenInfo.new(0.35), { BackgroundColor3 = NEEDLE_COLOR }):Play()
	end

	local function finishAll()
		resolved = true
		local perfectN, goodN, missN = 0, 0, 0
		for _, g in grades do
			if g == "perfect" then perfectN += 1
			elseif g == "good" then goodN += 1
			else missN += 1 end
		end
		local jackpot = missN == 0 and goodN == 0 and perfectN == #grades and perfectN > 0
		Audio.sfx(perfectN > 0 and "qte_perfect" or goodN > 0 and "qte_good" or "qte_miss")
		if jackpot then Audio.sfx("qte_jackpot") end
		local resultColor = jackpot and Color3.fromRGB(255, 215, 90)
			or (perfectN + goodN) > 0 and Color3.fromRGB(120, 210, 150)
			or Color3.fromRGB(235, 90, 90)
		prompt.Text = jackpot and "JACKPOT! Perfect ครบทุกครั้ง!"
			or ("จบ! Perfect×%d  Good×%d  Miss×%d"):format(perfectN, goodN, missN)
		prompt.TextColor3 = resultColor
		hitLabel.Text = ""
		TweenService:Create(track, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(prompt, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
			TextTransparency = 1, TextStrokeTransparency = 1,
		}):Play()
		fireAction({ type = "RecordQTEResult", grades = grades })
		cleanup()
	end

	-- กด 1 ครั้ง = บันทึกเกรดจากตำแหน่งเข็มปัจจุบัน (ไม่แตะ pos/dir)
	local function press()
		if resolved then return end
		local grade = RecordQTE.gradeFor(pos, center, perfectHW, goodHW)
		table.insert(grades, grade)
		hitsDone += 1
		flashGrade(grade)
		Audio.sfx("qte_hit_" .. grade, 0.05)
		if hitsDone >= hitsRequired then
			finishAll()
		else
			hitLabel.Text = ("กดแล้ว %d/%d"):format(hitsDone, hitsRequired)
		end
	end

	-- เข็มขยับอิสระทุก frame (เร็วตาม hitsDone) ชนขอบสลับทิศเอง · timeout = auto-เติม miss ที่เหลือ
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		if resolved then return end
		if os.clock() - startedAt > Q.timeoutSeconds then
			while #grades < hitsRequired do table.insert(grades, "miss") end
			finishAll()
			return
		end
		local speed = 1 / RecordQTE.sweepSecondsFor(hitsDone + 1, Q)
		pos += dir * speed * dt
		if pos >= 1 then
			pos = 1
			dir = -1
		elseif pos <= 0 then
			pos = 0
			dir = 1
		end
		needle.Position = UDim2.new(pos, 0, 0.5, 0)
		local nowInGoodBand = math.abs(pos - center) <= goodHW
		if nowInGoodBand and not inGoodBand then Audio.sfx("qte_tick") end
		inGoodBand = nowInGoodBand
	end)

	-- input: PC = Space (sink กันกระโดด) · มือถือ = แตะจอทั้งจอ
	CAS:BindAction(ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then press() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space)

	if UIS.TouchEnabled then
		local tapCatcher = Instance.new("TextButton") -- จับแตะเต็มจอ (หลังแถบ)
		tapCatcher.Name = "TapCatcher"
		tapCatcher.BackgroundTransparency = 1
		tapCatcher.Text = ""
		tapCatcher.Size = UDim2.fromScale(1, 1)
		tapCatcher.ZIndex = 0
		tapCatcher:SetAttribute("Sfx", "none")
		tapCatcher.Parent = gui
		tapCatcher.Activated:Connect(press)
	end
end

return RecordQTE
