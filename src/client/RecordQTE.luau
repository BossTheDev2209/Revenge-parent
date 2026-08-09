-- RecordQTE.luau — DBD-style skill-check ตอนถ่ายคลิป (docs/02 §9.5)
-- แถบเส้นแนวนอนล่างจอ เข็มกวาดซ้าย→ขวา · กด Space (PC) / แตะ (มือถือ) ให้ตรงโซน
--   Perfect (โซนแคบกลาง) / Good (โซนกว้าง) / Miss (นอกโซน หรือปล่อยจนหมดเวลา)
-- server เป็นคนสุ่ม 2% + คิด reward (RecordService) — ไฟล์นี้แค่เล่น skill-check แล้วส่งเกรดกลับ
--
-- pure ส่วน: gradeFor (เทส lune ได้) · Roblox glue: start (สร้างแถบ + input + lock)
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

-- ===== Roblox glue =====
function RecordQTE.start(playerGui, fireAction)
	if RecordQTE.running then return end
	RecordQTE.running = true

	local Q = Config.RecordQTE
	local RunService = game:GetService("RunService")
	local CAS = game:GetService("ContextActionService")
	local UIS = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")
	local InteractLock = require(script.Parent.InteractLock)
	local Audio = require(script.Parent.AudioService)

	InteractLock.lock() -- ปิด E + freeze เดิน/กระโดด ตลอด QTE

	-- โซนสำเร็จ: กึ่งกลางสุ่มในช่วง Config (0..1) · Perfect ซ้อนกลางโซน Good
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
	prompt.Position = UDim2.new(0.5, 0, 1, -158)
	prompt.Size = UDim2.fromOffset(460, 34)
	prompt.BackgroundTransparency = 1
	prompt.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	prompt.TextSize = 22
	prompt.TextColor3 = Color3.fromRGB(240, 242, 250)
	prompt.TextStrokeTransparency = 0.5
	prompt.Text = UIS.TouchEnabled and "แตะจอ! ให้เข็มตรงโซน" or "กด SPACE! ให้เข็มตรงโซน"
	prompt.Parent = gui

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

	-- เข็มกวาด
	local needle = Instance.new("Frame")
	needle.Name = "Needle"
	needle.AnchorPoint = Vector2.new(0.5, 0.5)
	needle.Position = UDim2.new(0, 0, 0.5, 0)
	needle.Size = UDim2.new(0, 5, 1, 4)
	needle.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
	needle.BorderSizePixel = 0
	needle.ZIndex = 5
	needle.Parent = track
	local nc = Instance.new("UICorner")
	nc.CornerRadius = UDim.new(0, 3)
	nc.Parent = needle

	-- ---------- state ----------
	local startAt = os.clock()
	local resolved = false
	local heartbeat
	local currentPos = 0

	local function cleanup()
		if heartbeat then heartbeat:Disconnect() end
		pcall(function() CAS:UnbindAction(ACTION) end)
		InteractLock.unlock()
		RecordQTE.running = false
		task.delay(0.55, function() if gui then gui:Destroy() end end)
	end

	local function finish(grade: string)
		if resolved then return end
		resolved = true
		Audio.sfx(grade == "perfect" and "qte_perfect" or grade == "good" and "qte_good" or "qte_miss")
		-- แสดงผลสั้นๆ ก่อนปิด
		local resultColor = grade == "perfect" and Color3.fromRGB(245, 240, 180)
			or grade == "good" and Color3.fromRGB(90, 210, 140)
			or Color3.fromRGB(235, 90, 90)
		prompt.Text = grade == "perfect" and "PERFECT!  +Footage ×10"
			or grade == "good" and "GOOD  +Footage ×5"
			or "MISS"
		prompt.TextColor3 = resultColor
		needle.BackgroundColor3 = resultColor
		TweenService:Create(track, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(prompt, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			TextTransparency = 1, TextStrokeTransparency = 1,
		}):Play()
		fireAction({ type = "RecordQTEResult", grade = grade })
		cleanup()
	end

	local function press()
		if resolved then return end
		finish(RecordQTE.gradeFor(currentPos, center, Q.perfectHalfWidth, Q.goodHalfWidth))
	end

	-- เข็มกวาด 0→1 ตาม sweepSeconds · ถึงปลายยังไม่กด = miss (หมดเวลา)
	heartbeat = RunService.Heartbeat:Connect(function()
		if resolved then return end
		currentPos = (os.clock() - startAt) / Q.sweepSeconds
		if currentPos >= 1 then
			currentPos = 1
			needle.Position = UDim2.new(1, 0, 0.5, 0)
			finish("miss")
			return
		end
		needle.Position = UDim2.new(currentPos, 0, 0.5, 0)
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
