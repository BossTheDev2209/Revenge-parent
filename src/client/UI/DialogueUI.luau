-- DialogueUI — cutscene โหมด 2 "ฉากคุย": กล้องนิ่ง + กล่องข้อความ (Undertale-lite) + ช้อย
-- 1 บรรทัด: "ข้อความ" | { speaker, text } | { choices = { {text, tone, reply, teleport}, ... } }
-- เพิ่ม field ในบรรทัดไหนก็ได้: anim (ครั้งเดียว) · pose (ค้าง) · face (สีหน้า) · actor (ตัวอื่นขยับ) · cam · lock · time
-- tone = plus/neutral/minus (⊕/◎/⊖) — ป้ายกำกับ ส่งกลับทาง onDone(picks) · ไม่ผูก mental (input จริงอยู่ที่ comment)
-- reply = บทตอบกลับหลังเลือก แล้วบรรจบเส้นเดิม (ไม่ branching) · tag [slow]/[fast]/[normal]/[b]/[i] กลางประโยค
-- pure: parseTags/tokenize/lineOf/validate/bullet/layout | glue: show()
local isStudio = script ~= nil
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Audio = if isStudio
	then require(script.Parent.Parent.AudioService)
	else require("../AudioService")
local AnimPlayer = if isStudio
	then require(script.Parent.Parent.AnimPlayer)
	else require("../AnimPlayer")
local ModelViewport = if isStudio
	then require(script.Parent.Parent.ModelViewport)
	else nil
local InteractLock = if isStudio
	then require(script.Parent.Parent.InteractLock)
	else nil

local DialogueUI = {}
DialogueUI.running = false

-- easing สำหรับ item.cam — ตรงกับ CutscenePlayer.EASE
local EASE = {
	In = { Enum.EasingStyle.Quad, Enum.EasingDirection.In },
	Out = { Enum.EasingStyle.Quad, Enum.EasingDirection.Out },
	InOut = { Enum.EasingStyle.Quad, Enum.EasingDirection.InOut },
	Linear = { Enum.EasingStyle.Linear, Enum.EasingDirection.InOut },
}

-- กล่องออกแบบที่ 900x176px — จอแคบ/เตี้ยกว่านี้ต้องหด (UIScale ตัวเดียวหดทั้งกล่อง+ขอบ+ข้อความ) · pure
local BOX_MARGIN_SCALE = 0.06 -- เว้นขอบซ้ายขวาข้างละ 6%
local BOX_VISIBLE_HEIGHT_SCALE = 0.76 -- พื้นที่ระหว่างแถบดำบน-ล่าง
local BOX_MIN_SCALE = 0.5
function DialogueUI.layout(viewport)
	local B = Config.Dialogue.box
	local naturalW = B.width + B.border * 2
	local naturalH = B.height + B.border * 2 + B.bottomGap
	local maxW = viewport.X * (1 - BOX_MARGIN_SCALE * 2)
	local maxH = viewport.Y * BOX_VISIBLE_HEIGHT_SCALE
	local scale = math.min(1, maxW / naturalW, maxH / naturalH)
	return { scale = math.max(BOX_MIN_SCALE, scale) }
end

local TONES = { plus = true, neutral = true, minus = true }

-- ⚠️ Enum.Font ไม่ใช่ Font.fromName("Mali") — fromName "Temp read failed" ทุก session ในเครื่องนี้ (Roblox fallback glyph ไทยเอง)
local DIALOGUE_FONT = if isStudio then Font.fromEnum(Enum.Font.Gotham) else nil

local FMT_OPEN = { b = "<b>", i = "<i>" }
local FMT_CLOSE = { ["/b"] = "</b>", ["/i"] = "</i>" }
local SPEED_TAG = { slow = true, fast = true, normal = true }
local function escapeRich(ch: string): string
	if ch == "&" then return "&amp;" end
	if ch == "<" then return "&lt;" end
	if ch == ">" then return "&gt;" end
	return ch
end

-- ดอกจันนำหน้าประโยคแบบ Undertale — ต้นข้อความ + หลัง \n ที่คนเขียนใส่เอง (ตัดบรรทัดอัตโนมัติไม่นับ)
function DialogueUI.bullet(text: string): string
	if text == "" then return text end
	return "* " .. (text:gsub("\n", "\n* "))
end

-- "[slow]ก[fast]ข" → { {speed,text}, ... } เริ่ม normal
function DialogueUI.parseTags(line: string)
	local segs = {}
	local speed = "normal"
	local pos = 1
	while true do
		local s, e, tag = line:find("%[(%a+)%]", pos)
		if not s then
			local rest = line:sub(pos)
			if #rest > 0 then table.insert(segs, { speed = speed, text = rest }) end
			break
		end
		local before = line:sub(pos, s - 1)
		if #before > 0 then table.insert(segs, { speed = speed, text = before }) end
		speed = tag
		pos = e + 1
	end
	return segs
end

-- ข้อความ+tag → token list · { m = markup } (ใส่ทันที) | { c = ตัวอักษร, speed } (พิมพ์ทีละตัว)
-- ดอกจัน "* " นำหน้าประโยค · รองรับ [b]/[i]/[/b]/[/i] inline
function DialogueUI.tokenize(text: string)
	local toks = {}
	local speed = "normal"
	local pos, n = 1, #text
	local atLineStart = true
	while pos <= n do
		-- ดอกจันใส่ก่อน markup/ตัวแรกของบรรทัด (ไม่งั้นโดนครอบ <b> ทับ)
		if atLineStart and text:sub(pos, pos) ~= "\n" then
			table.insert(toks, { c = "*", speed = speed })
			table.insert(toks, { c = " ", speed = speed })
			atLineStart = false
		end
		local s, e, tag = text:find("^%[(%a*/?%a+)%]", pos)
		if s then
			if SPEED_TAG[tag] then
				speed = tag
			elseif FMT_OPEN[tag] then
				table.insert(toks, { m = FMT_OPEN[tag] })
			elseif FMT_CLOSE[tag] then
				table.insert(toks, { m = FMT_CLOSE[tag] })
			end -- tag แปลกๆ ทิ้ง
			pos = e + 1
		else
			local b = text:byte(pos)
			local len = if b >= 0xF0 then 4 elseif b >= 0xE0 then 3 elseif b >= 0xC0 then 2 else 1 -- UTF-8 width
			local ch = text:sub(pos, pos + len - 1)
			if ch == "\n" then
				table.insert(toks, { c = "\n", speed = speed })
				atLineStart = true
			else
				table.insert(toks, { c = ch, speed = speed })
			end
			pos = pos + len
		end
	end
	return toks
end

-- แปลง 1 บรรทัดให้เป็นรูปเดียว → { speaker?, text?, choices? }
function DialogueUI.lineOf(item)
	if type(item) == "string" then return { text = item } end
	if type(item) == "table" then return item end
	return { text = tostring(item) }
end

-- เช็คบทก่อนเล่น — คืน (ผ่านไหม, error)
function DialogueUI.validate(lines)
	if type(lines) ~= "table" then return false, "ไม่ใช่ตาราง" end
	for i, item in lines do
		if type(item) == "string" then
			continue
		elseif type(item) ~= "table" then
			return false, ("บรรทัด %d: ต้องเป็นข้อความหรือตาราง"):format(i)
		elseif item.anim ~= nil and type(item.anim) ~= "string" then
			return false, ("บรรทัด %d: anim ต้องเป็นชื่อท่า (string)"):format(i)
		elseif item.pose ~= nil and type(item.pose) ~= "string" then
			return false, ("บรรทัด %d: pose ต้องเป็นชื่อท่า (string)"):format(i)
		elseif item.face ~= nil and type(item.face) ~= "string" then
			return false, ("บรรทัด %d: face ต้องเป็นชื่อสีหน้า (string)"):format(i)
		elseif item.actor ~= nil and type(item.actor) ~= "string" then
			return false, ("บรรทัด %d: actor ต้องเป็นชื่อตัวละคร (string)"):format(i)
		elseif item.cam ~= nil and type(item.cam) ~= "string" then
			return false, ("บรรทัด %d: cam ต้องเป็นชื่อ Part ใน CutsceneCams (string)"):format(i)
		elseif item.lock ~= nil and type(item.lock) ~= "boolean" then
			return false, ("บรรทัด %d: lock ต้องเป็น true/false (boolean)"):format(i)
		elseif item.time ~= nil and type(item.time) ~= "number" then
			return false, ("บรรทัด %d: time ต้องเป็นชั่วโมง 0-24 (number)"):format(i)
		elseif item.choices then
			if type(item.choices) ~= "table" or #item.choices == 0 then
				return false, ("บรรทัด %d: choices ว่าง"):format(i)
			end
			for j, c in item.choices do
				if type(c) ~= "table" or type(c.text) ~= "string" then
					return false, ("บรรทัด %d ช้อย %d: ต้องมี text"):format(i, j)
				end
				if c.tone ~= nil and not TONES[c.tone] then
					return false, ("บรรทัด %d ช้อย %d: tone ต้องเป็น plus/neutral/minus"):format(i, j)
				end
				if c.teleport ~= nil and type(c.teleport) ~= "string" then
					return false, ("บรรทัด %d ช้อย %d: teleport ต้องเป็นชื่อ Part (string)"):format(i, j)
				end
				if c.reply ~= nil then
					local ok, err = DialogueUI.validate(c.reply)
					if not ok then return false, ("บรรทัด %d ช้อย %d > %s"):format(i, j, err) end
				end
			end
		elseif item.anim or item.pose or item.face then
			-- บรรทัดสั่งท่า/สีหน้าล้วน (stage direction ไม่ขึ้นกล่อง) ผ่านได้
			if item.text ~= nil and type(item.text) ~= "string" then
				return false, ("บรรทัด %d: text ต้องเป็นข้อความ"):format(i)
			end
		elseif type(item.text) ~= "string" then
			return false, ("บรรทัด %d: ต้องมี text"):format(i)
		end
	end
	return true
end

-- แสดง lines typewriter — คลิกระหว่างพิมพ์ = โชว์ทั้งบรรทัด, คลิกอีกที = บรรทัดถัดไป
-- voiceName = ชื่อ Sound ใน SoundService.Voice (blip) + actor เริ่มต้นของท่าทาง · onDone(picks, quit, teleportTarget)
function DialogueUI.show(playerGui, lines, onDone, voiceName)
	if DialogueUI.running then return end
	local ok, err = DialogueUI.validate(lines)
	if not ok then
		warn("[DialogueUI] บทพัง:", err)
		return
	end
	-- item.lock (บรรทัดไหนก็ได้) = บังคับเล่นจนจบ ปิดปุ่มเลิกคุย — สแกนก่อนสร้าง UI (มีผลทั้งบท)
	local locked = false
	for _, item in lines do
		if type(item) == "table" and item.lock then locked = true break end
	end
	DialogueUI.running = true
	if InteractLock then InteractLock.lock() end
	Audio.duckBGM(true) -- หรี่เพลงตอนคุย ได้ยิน blip ชัด

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_Dialogue"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local B = Config.Dialogue.box

	-- แถบหนังบน-ล่าง (เหมือน cutscene mode 1)
	local barTop = Instance.new("Frame")
	barTop.Name = "BarTop"
	barTop.Size = UDim2.new(1, 0, 0.12, 0)
	barTop.BackgroundColor3 = Color3.new(0, 0, 0)
	barTop.BorderSizePixel = 0
	barTop.Parent = gui
	local barBottom = barTop:Clone()
	barBottom.Name = "BarBottom"
	barBottom.Position = UDim2.new(0, 0, 0.88, 0)
	barBottom.Parent = gui

	-- container ครอบ boxBorder+box — UIScale ตัวเดียวหดทั้งคู่พร้อมกัน (ดู DialogueUI.layout)
	local boxContainer = Instance.new("Frame")
	boxContainer.Name = "BoxContainer"
	boxContainer.Size = UDim2.fromScale(1, 1)
	boxContainer.BackgroundTransparency = 1
	boxContainer.Parent = gui
	local boxScale = Instance.new("UIScale")
	boxScale.Parent = boxContainer

	-- ขอบขาว: Frame ทึบชั้นหลังกล่อง ใหญ่กว่าด้านละ border px (UIStroke คร่อมกึ่งกลางขอบ ไม่ได้อยู่นอกล้วน)
	local boxBorder = Instance.new("Frame")
	boxBorder.Name = "BoxBorder"
	boxBorder.AnchorPoint = Vector2.new(0.5, 1)
	boxBorder.Position = UDim2.new(0.5, 0, 1, -B.bottomGap + B.border)
	boxBorder.Size = UDim2.fromOffset(B.width + B.border * 2, B.height + B.border * 2)
	boxBorder.BackgroundColor3 = Color3.new(1, 1, 1)
	boxBorder.BorderSizePixel = 0
	boxBorder.Parent = boxContainer

	-- กล่องขนาดคงที่ ยึดกลางล่างจอ (ทั้งกล่องคือปุ่ม continue) — ยาวขึ้นตัดบรรทัด ไม่ยืด ไม่ย่อฟอนต์
	local box = Instance.new("TextButton")
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -B.bottomGap)
	box.Size = UDim2.fromOffset(B.width, B.height)
	box.BackgroundColor3 = B.bgColor
	box.BackgroundTransparency = 0
	box.BorderSizePixel = 0
	box.AutoButtonColor = false
	box.Text = "" -- ข้อความจริงอยู่ TextLabel ข้างใน
	box:SetAttribute("Sfx", "dialogue_advance")
	box.Parent = boxContainer

	-- หน้าตัวละครฝั่งซ้าย = โมเดล 3 มิติจริงของ NPC (ModelViewport) · หา rig ไม่เจอ = ซ่อนช่อง ข้อความกินที่แทน
	local portraitVP = ModelViewport and ModelViewport.new(box)
	if portraitVP then
		portraitVP.instance.Size = UDim2.fromOffset(B.portrait, B.portrait)
		portraitVP.instance.Position = UDim2.fromOffset(B.padding, B.padding)
	end

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.BackgroundTransparency = 1
	textLabel.FontFace = DIALOGUE_FONT
	textLabel.RichText = true
	textLabel.TextSize = B.textSize -- คงที่ ไม่ TextScaled
	textLabel.TextWrapped = true
	textLabel.TextColor3 = B.textColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.Text = ""
	textLabel.Parent = box

	-- ข้อความกินที่ที่เหลือหลังหักช่อง portrait (ไม่โชว์ = กินเต็ม)
	local function layoutText()
		local showingPortrait = portraitVP ~= nil and portraitVP.instance.Visible
		local left = showingPortrait and (B.padding * 2 + B.portrait) or B.padding
		textLabel.Position = UDim2.fromOffset(left, B.padding)
		textLabel.Size = UDim2.fromOffset(B.width - left - B.padding, B.height - B.padding * 2)
	end
	layoutText()

	local nameLabel = Instance.new("TextLabel") -- ชื่อคนพูด มุมซ้ายบนกล่อง
	nameLabel.AnchorPoint = Vector2.new(0, 1)
	nameLabel.Position = UDim2.new(0, 0, 0, -4)
	nameLabel.Size = UDim2.fromOffset(240, 30)
	nameLabel.BackgroundColor3 = Color3.new(1, 1, 1)
	nameLabel.BackgroundTransparency = 0
	nameLabel.BorderSizePixel = 0
	nameLabel.FontFace = DIALOGUE_FONT
	nameLabel.TextSize = B.textSize - 4
	nameLabel.TextColor3 = Color3.fromRGB(20, 20, 24)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = ""
	nameLabel.Visible = false
	nameLabel.Parent = box
	local namePad = Instance.new("UIPadding")
	namePad.PaddingLeft = UDim.new(0, 8)
	namePad.Parent = nameLabel

	local choiceFrame = Instance.new("Frame") -- ลิสต์ช้อย ยึดขวากลางจอ
	choiceFrame.AnchorPoint = Vector2.new(1, 0.5)
	choiceFrame.Position = UDim2.new(1, -60, 0.45, 0)
	choiceFrame.Size = UDim2.fromOffset(360, 300)
	choiceFrame.BackgroundTransparency = 1
	choiceFrame.Visible = false
	choiceFrame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = choiceFrame

	-- ปุ่มเลิกคุย — กดแล้วออกจากบท ไม่นับว่าคุยจบ (ไม่ยิง DialogueSeen) · locked = ไม่สร้างปุ่ม
	local quit = false
	if not locked then
		local quitBtn = Instance.new("TextButton")
		quitBtn.Name = "QuitButton"
		quitBtn.AnchorPoint = Vector2.new(0, 0)
		quitBtn.Position = UDim2.new(0, 24, 0.12, 10)
		quitBtn.Size = UDim2.fromOffset(120, 38)
		quitBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		quitBtn.BackgroundTransparency = 0.35
		quitBtn.TextColor3 = Color3.new(1, 1, 1)
		quitBtn.TextScaled = true
		quitBtn.Text = "← เลิกคุย"
		quitBtn:SetAttribute("Sfx", "ui_back")
		quitBtn.Parent = gui
		local quitCorner = Instance.new("UICorner")
		quitCorner.CornerRadius = UDim.new(0, 6)
		quitCorner.Parent = quitBtn
		quitBtn.Activated:Connect(function() quit = true end)
	end

	-- ซ่อน GUI อื่นที่เปิดอยู่ (HUD/ปุ่มเซฟ/Tool บังการมองเห็น) — จำไว้คืนตอนจบ
	local hiddenGuis = {}
	for _, g in playerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(hiddenGuis, g)
		end
	end

	gui.Parent = playerGui

	-- หดกล่องให้พอดีจอ (refit ตอนหมุนจอ)
	local camera = workspace.CurrentCamera
	local function fitBox()
		boxScale.Scale = DialogueUI.layout(camera.ViewportSize).scale
	end
	fitBox()
	local viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitBox)

	local picks = {}
	local teleportTarget = nil
	-- item.cam = วางมุมด้วย CutsceneCamTool · ตัดกล้องตอนบรรทัดนั้นขึ้น · caller ต้องไม่ส่ง head ให้ CameraFocus (ชนกัน)
	local camSaved = nil -- เก็บ CameraType/Subject/FOV เดิม เซ็ตครั้งแรกที่เจอ item.cam
	local timeSet = false
	local function cutTo(camName: string)
		local folder = workspace:FindFirstChild("CutsceneCams")
		local part = folder and folder:FindFirstChild(camName, true) or workspace:FindFirstChild(camName, true)
		if not (part and part:IsA("BasePart")) then
			warn("[DialogueUI] ไม่เจอ Part กล้อง:", camName)
			return
		end
		if not camSaved then
			-- ⚠️ ต้องเก็บ FieldOfView ด้วย ไม่งั้น FOV ค้างค่า item.cam ทั้งเกมหลังเลิกคุย
			camSaved = { type = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView }
		end
		camera.CameraType = Enum.CameraType.Scriptable
		local ease = part:GetAttribute("Ease") or "InOut"
		local t = part:GetAttribute("TweenTime") or 0
		if ease == "Cut" then t = 0 end
		local e = EASE[ease]
		local fov = part:GetAttribute("FOV")
		if t > 0 then
			TweenService:Create(camera, TweenInfo.new(t, (e and e[1]) or Enum.EasingStyle.Quad, (e and e[2]) or Enum.EasingDirection.InOut),
				{ CFrame = part.CFrame, FieldOfView = fov or camera.FieldOfView }):Play()
		else
			camera.CFrame = part.CFrame
			if fov then camera.FieldOfView = fov end
		end
	end

	-- พิมพ์ข้อความ 1 บรรทัด แล้วรอคลิก · actor = หา rig สำหรับ portrait (ไม่ส่ง = คนที่คุยอยู่)
	local function speak(item, actor: string?)
		local speaker, text = item.speaker, item.text
		nameLabel.Visible = speaker ~= nil
		nameLabel.Text = speaker or ""

		-- ไม่มีชื่อ = ไม่โชว์หน้า · speaker="คุณ" = โชว์หน้า player เอง (ไม่ใช่ NPC)
		if portraitVP then
			if speaker then
				portraitVP.showBust(AnimPlayer.findRig(speaker == "คุณ" and "player" or (actor or voiceName)))
			else
				portraitVP.clear()
			end
		end
		layoutText()

		-- typewriter บน RichText: พิมพ์ทีละตัว ปิด tag <b>/<i> ที่เปิดค้างทุกเฟรมให้ markup valid
		local toks = DialogueUI.tokenize(text)
		local shown, openStack = {}, {}
		local function closers()
			local c = ""
			for k = #openStack, 1, -1 do c ..= "</" .. openStack[k] .. ">" end
			return c
		end
		local function applyMarkup(m)
			shown[#shown + 1] = m
			local cn = m:match("^</(%a+)>$")
			if cn then
				for k = #openStack, 1, -1 do
					if openStack[k] == cn then table.remove(openStack, k) break end
				end
			else
				local on = m:match("^<(%a+)>$")
				if on then table.insert(openStack, on) end
			end
		end
		-- markup เต็ม (ปิด tag ครบ) — ใช้ตอนกดข้าม/จบให้โชว์หมดทันที
		local full
		do
			local buf, stk = {}, {}
			for _, t in toks do
				if t.m then
					buf[#buf + 1] = t.m
					local cn = t.m:match("^</(%a+)>$")
					if cn then for k = #stk, 1, -1 do if stk[k] == cn then table.remove(stk, k) break end end
					else local on = t.m:match("^<(%a+)>$"); if on then table.insert(stk, on) end end
				else
					buf[#buf + 1] = escapeRich(t.c)
				end
			end
			for k = #stk, 1, -1 do buf[#buf + 1] = "</" .. stk[k] .. ">" end
			full = table.concat(buf)
		end

		local skip = false
		local conn = box.Activated:Connect(function() skip = true end)
		textLabel.Text = ""
		for _, t in toks do
			if skip or quit then break end
			if t.m then
				applyMarkup(t.m)
			else
				shown[#shown + 1] = escapeRich(t.c)
				textLabel.Text = table.concat(shown) .. closers()
				if t.c ~= " " and t.c ~= "\n" then Audio.voice(voiceName) end -- เว้นวรรค/ขึ้นบรรทัดไม่มีเสียง
				task.wait(Config.Dialogue.charDelay[t.speed] or Config.Dialogue.charDelay.normal)
			end
		end
		textLabel.Text = full
		if not textLabel.TextFits then -- กล่องคงที่ = บทยาวเกินตัดหาย เตือนให้ซอยประโยค
			warn(("[DialogueUI] บทยาวเกินกล่อง ตัดเป็นหลายบรรทัดในลิสต์: %q"):format(text:sub(1, 40)))
		end
		conn:Disconnect()
		-- รอคลิกไปบรรทัดถัดไป · เสียงคลิกมาจากตัวผูกกลางใน Main.client (ไม่เรียก Audio.sfx เองกันดัง 2 ที)
		local go = false
		local conn2 = box.Activated:Connect(function()
			go = true
		end)
		while not go and not quit do task.wait() end
		conn2:Disconnect()
	end

	-- โชว์ช้อย รอเลือก คืนช้อยที่เลือก (nil = กดเลิกคุยระหว่างเลือก)
	local function ask(choices)
		local picked = nil
		for i, c in choices do
			local btn = Instance.new("TextButton")
			btn.Name = "Choice_" .. i
			btn.Size = UDim2.new(1, 0, 0, 34)
			btn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
			btn.BackgroundTransparency = 0.15
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.TextScaled = true
			btn.Text = c.text
			btn.LayoutOrder = i
			btn:SetAttribute("Sfx", "dialogue_choice")
			btn.Parent = choiceFrame
			btn.Activated:Connect(function()
				if picked then return end
				picked = c
			end)
		end
		choiceFrame.Visible = true
		while not picked and not quit do task.wait() end
		choiceFrame.Visible = false
		for _, b in choiceFrame:GetChildren() do
			if b:IsA("TextButton") then b:Destroy() end
		end
		return picked
	end

	task.spawn(function()
		local movedActors = {} -- ตัวที่ถูกสั่งท่า — จบบทหยุดให้หมด
		-- pcall ครอบ playback: บทพังกลางคันก็ยังวิ่ง cleanup (ไม่งั้น InteractLock ค้าง = เดิน/กระโดดไม่ได้หลังคุย)
		local ok, err = pcall(function()
			local queue = table.clone(lines)
			local i = 1
			while i <= #queue and not quit do
				local item = DialogueUI.lineOf(queue[i])
				if item.cam then cutTo(item.cam) end -- ตัดกล้องตามบรรทัด ไม่ใช่ timer
				if item.time then game:GetService("Lighting"):SetAttribute("SceneClock", item.time); timeSet = true end
				local moved = AnimPlayer.applyLine(item, voiceName) -- ท่าเล่นก่อนข้อความขึ้น
				if moved then movedActors[moved] = true end
				if item.choices then
					local c = ask(item.choices)
					if c then
						table.insert(picks, c.tone or "neutral")
						if c.teleport then teleportTarget = c.teleport end -- ยิงตอนจบบท
						-- บทตอบกลับแทรกต่อท้ายทันที แล้วเดินเส้นเดิม (ไม่ branching)
						if c.reply then
							for k = #c.reply, 1, -1 do
								table.insert(queue, i + 1, c.reply[k])
							end
						end
					end
				elseif item.text then
					speak(item, item.actor or voiceName)
				end -- ไม่มี text = บรรทัดสั่งท่าล้วน ข้าม
				i += 1
			end
		end)
		if not ok then warn("[DialogueUI] บทพังกลางคัน:", err) end
		-- cleanup เสมอ (แม้บทพัง)
		for actor in movedActors do AnimPlayer.stop(actor) end
		if timeSet then game:GetService("Lighting"):SetAttribute("SceneClock", nil) end
		if camSaved then -- คืนกล้องที่ item.cam ยึด (CameraFocus ไม่รู้จักตัวนี้)
			camera.CameraType = camSaved.type
			camera.CameraSubject = camSaved.subject
				or (Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid"))
			camera.FieldOfView = camSaved.fov
		end
		viewportConn:Disconnect()
		gui:Destroy()
		for _, g in hiddenGuis do if g.Parent then g.Enabled = true end end
		DialogueUI.running = false
		if InteractLock then InteractLock.unlock() end
		Audio.duckBGM(false)
		-- onDone(picks, quit, teleportTarget) เรียกเสมอ · quit=true = ไม่นับว่าคุยจบ · teleportTarget = caller ยิง TeleportTo เอง
		if onDone then onDone(picks, quit, teleportTarget) end
	end)
end

return DialogueUI
