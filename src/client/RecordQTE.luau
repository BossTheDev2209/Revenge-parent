-- RecordQTE.luau — DBD-style skill-check ตอนถ่ายคลิป แบบหลายรอบ (v2 10 ส.ค. — docs/02 §9.5)
-- แถบเส้นแนวนอนล่างจอ เข็มวิ่งกลับไปมา (ping-pong) N รอบ (server สุ่มส่งมา) · กด Space (PC) / แตะ (มือถือ)
--   ให้ตรงโซนตอนเข็มผ่าน · ชนขอบไม่ทันกด = miss รอบนั้น (0) แล้วสลับทิศต่อทันที — เล่นครบทุกรอบเสมอ ไม่ fail-fast
--   ยิ่งรอบหลังยิ่งไว (sweepSecondsFor) · โซนกึ่งกลางสุ่มครั้งเดียวตอนเริ่ม คงที่ตลอด (เข็มวิ่งผ่านเป้าเดิมซ้ำ)
-- server เป็นคนสุ่ม 2% + จำนวนรอบ + คิด reward สะสม (RecordService) — ไฟล์นี้แค่เล่น skill-check แล้วส่งเกรดทั้งชุดกลับ
--
-- pure ส่วน: gradeFor / sweepSecondsFor (เทส lune ได้) · Roblox glue: start (สร้างแถบ + input + lock + state machine)
-- ระหว่าง QTE: InteractLock.lock() ปิด ProximityPrompt (กด E ไม่ได้) + freeze เดิน/กระโดด (reuse ของเดิม)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../shared/Config")

local RecordQTE = {}
RecordQTE.running = false

-- ตำแหน่งเข็ม (0..1 ตามความยาวแถบ) เทียบกึ่งกลางโซน → เกรด (pure — เทสได้)
--   |pos-center| ≤ perfectHW = perfect · ≤ goodHW = good · เกินนั้น = miss
function RecordQTE.gradeFor(pos: number, center: number, perfectHW: number, goodHW: number): string
	local d = math.abs(pos - center)
	if d <= perfectHW then return "perfect" end
	if d <= goodHW then return "good" end
	return "miss"
end

-- ความเร็วรอบที่ round (1-indexed) — เร่งทีละรอบจนถึงพื้น sweepSecondsMin (pure — เทสได้)
function RecordQTE.sweepSecondsFor(round: number, cfg): number
	local s = cfg.sweepSecondsStart - (round - 1) * cfg.sweepSpeedupPerRound
	return math.max(cfg.sweepSecondsMin, s)
end

-- ===== Roblox glue =====
-- rounds: จำนวนรอบทั้งหมด (server สุ่มส่งมาผ่าน state.pendingRecordQTE.rounds)
function RecordQTE.start(playerGui, fireAction, rounds: number)
	if RecordQTE.running then return end
	RecordQTE.running = true
	rounds = math.max(1, rounds or 1)

	local Q = Config.RecordQTE
	local RunService = game:GetService("RunService")
	local CAS = game:GetService("ContextActionService")
	local UIS = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")
	local InteractLock = require(script.Parent.InteractLock)
	local Audio = require(script.Parent.AudioService)

	InteractLock.lock() -- ปิด E + freeze เดิน/กระโดด ตลอด QTE

	-- โซนสำเร็จ: กึ่งกลางสุ่มครั้งเดียวตอนเริ่ม คงที่ตลอดทุกรอบ (เข็มวิ่งผ่านเป้าเดิมซ้ำๆ)
	local center = Q.centerMin + math.random() * (Q.centerMax - Q.centerMin)
	local ACTION = "RecordQTE_Press"

	-- ---------- UI ----------
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

	local roundLabel = Instance.new("TextLabel")
	roundLabel.AnchorPoint = Vector2.new(0.5, 1)
	roundLabel.Position = UDim2.new(0.5, 0, 1, -150)
	roundLabel.Size = UDim2.fromOffset(200, 24)
	roundLabel.BackgroundTransparency = 1
	roundLabel.FontFace = Font.fromEnum(Enum.Font.Gotham)
	roundLabel.TextSize = 16
	roundLabel.TextColor3 = Color3.fromRGB(190, 194, 208)
	roundLabel.TextStrokeTransparency = 0.6
	roundLabel.Text = ("รอบ 1/%d"):format(rounds)
	roundLabel.Parent = gui

	-- แถบ (track) กลางล่างจอ — ขนาดกลาง
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
	zone(Q.goodHalfWidth, Color3.fromRGB(70, 180, 120), 0.35)     -- Good = เขียว
	zone(Q.perfectHalfWidth, Color3.fromRGB(245, 240, 180), 0.05) -- Perfect = ขาวนวล (เด่นสุด)

	-- เข็มวิ่ง (ping-pong)
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

	-- ---------- state machine: pos/dir ต่อเนื่องข้ามรอบ (ไม่กระโดด) ----------
	local pos, dir = 0, 1
	local roundIndex = 1
	local grades = {}
	local resolved = false
	local heartbeat

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

	-- แฟลชสีเข็มตามเกรด + pop เล็กๆ ให้ฟีดแบ็กแต่ละรอบ (ไม่บล็อกการเล่นต่อ)
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
		local resultColor = jackpot and Color3.fromRGB(255, 215, 90)
			or (perfectN + goodN) > 0 and Color3.fromRGB(120, 210, 150)
			or Color3.fromRGB(235, 90, 90)
		prompt.Text = jackpot and "JACKPOT! Perfect ครบทุกรอบ!"
			or ("จบ! Perfect×%d  Good×%d  Miss×%d"):format(perfectN, goodN, missN)
		prompt.TextColor3 = resultColor
		roundLabel.Text = ""
		TweenService:Create(track, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(prompt, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
			TextTransparency = 1, TextStrokeTransparency = 1,
		}):Play()
		fireAction({ type = "RecordQTEResult", grades = grades })
		cleanup()
	end

	-- ตัดจบ 1 รอบ (โดนกด หรือ ชนขอบ) → บันทึกเกรด, สลับทิศต่อจากจุดเดิม (ไม่กระโดด), หรือจบทั้งชุดถ้าครบ N
	local function endRound(grade: string)
		table.insert(grades, grade)
		flashGrade(grade)
		roundIndex += 1
		if roundIndex > rounds then
			finishAll()
			return
		end
		dir = -dir -- สลับทิศจากตำแหน่งปัจจุบันทันที (ต่อเนื่อง ไม่รีเซ็ต pos)
		roundLabel.Text = ("รอบ %d/%d"):format(roundIndex, rounds)
	end

	local function press()
		if resolved then return end
		endRound(RecordQTE.gradeFor(pos, center, Q.perfectHalfWidth, Q.goodHalfWidth))
	end

	-- เข็มขยับตามอัตราเร็วของรอบปัจจุบัน (progress/วิ = 1/sweepSecondsFor(roundIndex))
	-- ชนขอบ (0 หรือ 1) ก่อนกด = miss รอบนั้นอัตโนมัติ แล้วสลับทิศต่อ (เหมือน endRound จากการกด)
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		if resolved then return end
		local speed = 1 / RecordQTE.sweepSecondsFor(roundIndex, Q)
		pos += dir * speed * dt
		if pos >= 1 then
			pos = 1
			needle.Position = UDim2.new(1, 0, 0.5, 0)
			endRound(RecordQTE.gradeFor(1, center, Q.perfectHalfWidth, Q.goodHalfWidth))
			return
		elseif pos <= 0 then
			pos = 0
			needle.Position = UDim2.new(0, 0, 0.5, 0)
			endRound(RecordQTE.gradeFor(0, center, Q.perfectHalfWidth, Q.goodHalfWidth))
			return
		end
		needle.Position = UDim2.new(pos, 0, 0.5, 0)
	end)

	-- input: PC = Space (sink กันกระโดด) · มือถือ = แตะจอทั้งจอ
	CAS:BindAction(ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then press() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space)

	if UIS.TouchEnabled then
		-- ตัวจับแตะเต็มจอ (อยู่หลังแถบ) — แตะที่ไหนก็ได้ = กดจังหวะ
		local tapCatcher = Instance.new("TextButton")
		tapCatcher.Name = "TapCatcher"
		tapCatcher.BackgroundTransparency = 1
		tapCatcher.Text = ""
		tapCatcher.Size = UDim2.fromScale(1, 1)
		tapCatcher.ZIndex = 0
		tapCatcher:SetAttribute("Sfx", "none") -- ไม่เล่นเสียงคลิก UI ทับ
		tapCatcher.Parent = gui
		tapCatcher.Activated:Connect(press)
	end
end

return RecordQTE
