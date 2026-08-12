-- DialogueUI.luau — **cutscene โหมด 2 "ฉากคุย"** (Genshin ref: กล้องนิ่ง + กล่องข้อความ + ช้อย)
-- ต่างจากโหมด 1 (CutscenePlayer) ที่เป็นหนัง ซับไม่มีกรอบ กดอะไรไม่ได้ — เทียบตาราง docs/engines/README.md
--
-- 1 บรรทัดในลิสต์เป็นได้ 3 แบบ:
--   "ข้อความ"                                    — ไม่มีชื่อคนพูด
--   { speaker = "แม่", text = "ข้อความ" }         — มีชื่อคนพูดข้างบนกล่อง
--   { choices = { {text=, tone=, reply={...}}, ... } } — ให้ player เลือก
--
-- ท่าทาง/อารมณ์ (Genshin ref) — ใส่เพิ่มในบรรทัดไหนก็ได้ ไม่ใส่ = ตัวละครไม่ขยับ:
--   anim  = "HeadScratch"  เล่นครั้งเดียวตอนบรรทัดนี้ขึ้น
--   pose  = "Angry"        ท่ายืนค้าง (loop) จนกว่าจะสั่ง pose ใหม่
--   face  = "Angry"        สีหน้า (ค้างจนสั่งหน้าใหม่ · จบบทคืนหน้าเดิมอัตโนมัติ)
--   actor = "CC1"          ให้ตัวอื่นขยับแทนคนพูด (ไม่ใส่ = ตัวที่กำลังคุยด้วย)
--   ท่าอยู่ ReplicatedStorage.Animations · สีหน้าอยู่ ReplicatedStorage.Faces (ดู AnimPlayer.luau)
-- tone = "plus" | "neutral" | "minus" (⊕/◎/⊖) — ป้ายกำกับเฉยๆ ส่งกลับทาง onDone(picks)
--        ✅ ล็อก 28 ก.ค. 2569: **ไม่ผูก mental ถาวร** ทุกช้อยผลเท่ากันหมด — input ที่มีผลจริงอยู่ที่ comment เท่านั้น (docs/02 §9.6)
-- reply = บทตอบกลับหลังเลือก แล้ว**บรรจบกลับเส้นเดิม** (ไม่ branching — design doc §7)
--
-- tag [slow] [fast] [normal] คุมความเร็วกลางบรรทัด — pure: parseTags/lineOf/validate | glue: show()
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

-- easing สำหรับ item.cam (นอกเหนือ zoom-หน้าอัตโนมัติของ CameraFocus) — ตรงกับ CutscenePlayer.EASE เป๊ะ
local EASE = {
	In = { Enum.EasingStyle.Quad, Enum.EasingDirection.In },
	Out = { Enum.EasingStyle.Quad, Enum.EasingDirection.Out },
	InOut = { Enum.EasingStyle.Quad, Enum.EasingDirection.InOut },
	Linear = { Enum.EasingStyle.Linear, Enum.EasingDirection.InOut },
}

-- กล่องออกแบบไว้ที่ 900x176px (Config.Dialogue.box) — จอแคบ/เตี้ยกว่านี้ต้องหด ไม่งั้นล้นขอบจอ/ทะลุแถบดำ
-- pure: รับ viewport {X,Y} คืน scale (≤1) ให้ UIScale ตัวเดียวหดทั้งกล่อง+ขอบ+ข้อความไปด้วยกัน
local BOX_MARGIN_SCALE = 0.06 -- เว้นขอบซ้ายขวาข้างละ 6% ของจอกันกล่องชิดขอบเป๊ะ
local BOX_VISIBLE_HEIGHT_SCALE = 0.76 -- พื้นที่ระหว่างแถบดำบน (12%) - ล่าง (12%)
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

-- ฟอนต์เดียวกับเมนู — isStudio guard เพราะ lune ไม่มี Font
-- ⚠️ เคยใช้ Font.fromName("Mali",...) แต่ "Temp read failed" ทุก session (เช็คแล้ว ไม่ใช่ cache กระตุกครั้งเดียว
-- พังจริงในเครื่องนี้) → เปลี่ยนมาใช้ Enum.Font (ของ client จริง ไม่ต้องโหลดแยก) Roblox fallback glyph ไทยเองอยู่แล้ว
local DIALOGUE_FONT = if isStudio then Font.fromEnum(Enum.Font.Gotham) else nil

-- tag กลางประโยค: [slow]/[fast]/[normal] คุมความเร็ว · [b]…[/b] ตัวหนา · [i]…[/i] ตัวเอียง (ผ่าน RichText)
local FMT_OPEN = { b = "<b>", i = "<i>" }
local FMT_CLOSE = { ["/b"] = "</b>", ["/i"] = "</i>" }
local SPEED_TAG = { slow = true, fast = true, normal = true }
local function escapeRich(ch: string): string
	if ch == "&" then return "&amp;" end
	if ch == "<" then return "&lt;" end
	if ch == ">" then return "&gt;" end
	return ch
end

-- ===== pure =====

-- ใส่ดอกจันนำหน้าประโยคแบบ Undertale — ต้นข้อความ 1 ตัว และหลังขึ้นบรรทัดใหม่ทุกครั้ง
-- (`\n` ที่คนเขียนบทใส่เอง = ประโยคใหม่ · การตัดบรรทัดอัตโนมัติเพราะยาวเกิน ไม่นับ ไม่ได้ดอกจัน)
function DialogueUI.bullet(text: string): string
	if text == "" then return text end
	return "* " .. (text:gsub("\n", "\n* "))
end


-- "[slow]ก[fast]ข" → { {speed="slow",text="ก"}, {speed="fast",text="ข"} } — เริ่มต้น normal
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

-- แปลงข้อความ+tag → token list สำหรับ typewriter RichText
--   { m = "<b>" }              markup (ใส่ทันที ไม่หน่วง ไม่มีเสียง)
--   { c = "ก", speed="slow" }  ตัวอักษร 1 ตัว (พิมพ์ทีละตัวตามความเร็ว)
-- ดอกจัน "* " นำหน้าประโยค (ต้นข้อความ + หลัง \n) แบบ Undertale · รองรับ [b]/[i]/[/b]/[/i] inline
function DialogueUI.tokenize(text: string)
	local toks = {}
	local speed = "normal"
	local pos, n = 1, #text
	local atLineStart = true
	while pos <= n do
		-- ดอกจันนำหน้าประโยค ใส่ก่อน markup/ตัวอักษรตัวแรกของบรรทัด (ไม่งั้นโดนครอบ <b> ทับ)
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
			local len = if b >= 0xF0 then 4 elseif b >= 0xE0 then 3 elseif b >= 0xC0 then 2 else 1
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

-- แปลง 1 บรรทัดให้เป็นรูปเดียวกันหมด → { speaker=string?, text=string?, choices=table? }
function DialogueUI.lineOf(item)
	if type(item) == "string" then return { text = item } end
	if type(item) == "table" then return item end
	return { text = tostring(item) }
end

-- เช็คบทก่อนเล่น — คืน (ผ่านไหม, ข้อความ error)
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
			-- บรรทัดสั่งท่า/สีหน้าล้วน (ไม่มี text) = stage direction ไม่ขึ้นกล่องข้อความ ผ่านได้
			if item.text ~= nil and type(item.text) ~= "string" then
				return false, ("บรรทัด %d: text ต้องเป็นข้อความ"):format(i)
			end
		elseif type(item.text) ~= "string" then
			return false, ("บรรทัด %d: ต้องมี text"):format(i)
		end
	end
	return true
end

-- ===== UI glue (Studio เท่านั้น) =====
-- แสดง lines ทีละบรรทัด typewriter — คลิกระหว่างพิมพ์ = โชว์ทั้งบรรทัด, คลิกอีกที = บรรทัดถัดไป
-- voiceName = ชื่อ Sound ใน SoundService.Voice (blip ตอนพิมพ์) — ไม่ส่ง = ใช้ Default
--             ใช้เป็น **actor เริ่มต้น** ของท่าทางด้วย (ชื่อไฟล์บท = ชื่อ NPC ที่คุยอยู่)
-- onDone(picks) — picks = ลิสต์ tone ที่ player เลือกตามลำดับ (ว่างถ้าบทไม่มีช้อย)
function DialogueUI.show(playerGui, lines, onDone, voiceName)
	if DialogueUI.running then return end
	local ok, err = DialogueUI.validate(lines)
	if not ok then
		warn("[DialogueUI] บทพัง:", err)
		return
	end
	-- item.lock (บรรทัดไหนก็ได้) = บทบังคับเล่นจนจบ ปิดปุ่ม "เลิกคุย" ทั้งบท
	-- สแกนก่อนสร้าง UI (หลักการเดียวกับ usesCustomCam ใน Main.client — เจอที่ไหนในบท มีผลทั้งบท)
	local locked = false
	for _, item in lines do
		if type(item) == "table" and item.lock then locked = true break end
	end
	DialogueUI.running = true
	if InteractLock then InteractLock.lock() end -- ปิด prompt + ล็อกเดินตลอดบท
	Audio.duckBGM(true) -- หรี่เพลงตอนคุย ได้ยิน blip ชัด

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_Dialogue"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- แถบหนังคลุมเต็มจอ (เหมือน CutscenePlayer)

	local B = Config.Dialogue.box

	-- แถบหนังบน-ล่าง (ขนาด/สีเดียวกับ cutscene mode 1) — คุยกับ NPC = โหมดหนังเหมือนกัน
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

	-- container ครอบ boxBorder+box ไว้ด้วยกัน — UIScale ตัวเดียวหดทั้งคู่พร้อมกันไม่ให้เพี้ยนสัมพัทธ์กัน
	-- (จอแคบกว่า 900px = กล่องล้นขอบ/ทะลุแถบดำ ถ้าไม่หด — ดู DialogueUI.layout ด้านบน)
	local boxContainer = Instance.new("Frame")
	boxContainer.Name = "BoxContainer"
	boxContainer.Size = UDim2.fromScale(1, 1)
	boxContainer.BackgroundTransparency = 1
	boxContainer.Parent = gui
	local boxScale = Instance.new("UIScale")
	boxScale.Parent = boxContainer

	-- ขอบขาวแบบ Undertale — Frame สีขาวทึบหนึ่งชั้น "หลัง" กล่อง ใหญ่กว่ากล่องรอบด้านละ border px
	-- (ไม่ใช้ UIStroke เพราะ UIStroke คร่อมกึ่งกลางขอบ ครึ่งในครึ่งนอก — ต้องการขอบที่อยู่ "นอก" กล่องล้วนๆ)
	local boxBorder = Instance.new("Frame")
	boxBorder.Name = "BoxBorder"
	boxBorder.AnchorPoint = Vector2.new(0.5, 1)
	boxBorder.Position = UDim2.new(0.5, 0, 1, -B.bottomGap + B.border)
	boxBorder.Size = UDim2.fromOffset(B.width + B.border * 2, B.height + B.border * 2)
	boxBorder.BackgroundColor3 = Color3.new(1, 1, 1) -- ขาวโพลน
	boxBorder.BorderSizePixel = 0
	boxBorder.Parent = boxContainer

	-- กล่องขนาดคงที่ ยึดกลางล่างจอ (Undertale ref) — ข้อความยาวขึ้นตัดบรรทัด ไม่ยืดกล่อง ไม่ย่อฟอนต์
	local box = Instance.new("TextButton") -- ทั้งกล่องคือปุ่ม continue
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -B.bottomGap)
	box.Size = UDim2.fromOffset(B.width, B.height)
	box.BackgroundColor3 = B.bgColor
	box.BackgroundTransparency = 0
	box.BorderSizePixel = 0
	box.AutoButtonColor = false
	box.Text = "" -- ข้อความจริงอยู่ TextLabel ข้างใน (กล่องเป็นแค่ปุ่มกดไปต่อ)
	box:SetAttribute("Sfx", "dialogue_advance") -- เสียงคลิกไปบรรทัดถัดไป (คนละเสียงกับปุ่ม UI ทั่วไป)
	box.Parent = boxContainer

	-- หน้าตัวละครฝั่งซ้าย = เรนเดอร์โมเดล 3 มิติจริงของ NPC ที่คุยด้วย (ไม่ใช่รูปภาพ) — ดู ModelViewport.luau
	-- ไม่เจอ rig ของตัวนั้นในแมพตอนนี้ (เช่น actor พิมพ์ผิด) = ซ่อนช่อง ข้อความเลื่อนไปกินที่แทน ไม่พัง
	local portraitVP = ModelViewport and ModelViewport.new(box)
	if portraitVP then
		portraitVP.instance.Size = UDim2.fromOffset(B.portrait, B.portrait)
		portraitVP.instance.Position = UDim2.fromOffset(B.padding, B.padding)
	end

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.BackgroundTransparency = 1
	textLabel.FontFace = DIALOGUE_FONT
	textLabel.RichText = true -- รองรับ <b>/<i> จาก tag [b]/[i] กลางประโยค
	textLabel.TextSize = B.textSize -- คงที่ ไม่ใช้ TextScaled (ไม่งั้นยาวขึ้นตัวเล็กลง)
	textLabel.TextWrapped = true -- ยาวเกิน = ขึ้นบรรทัดใหม่
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

	local nameLabel = Instance.new("TextLabel") -- ชื่อคนพูด เกาะมุมซ้ายบนของกล่อง — พื้นขาวโพลน ไม่มีขอบ
	nameLabel.AnchorPoint = Vector2.new(0, 1)
	nameLabel.Position = UDim2.new(0, 0, 0, -4)
	nameLabel.Size = UDim2.fromOffset(240, 30)
	nameLabel.BackgroundColor3 = Color3.new(1, 1, 1)
	nameLabel.BackgroundTransparency = 0
	nameLabel.BorderSizePixel = 0
	nameLabel.FontFace = DIALOGUE_FONT
	nameLabel.TextSize = B.textSize - 4
	nameLabel.TextColor3 = Color3.fromRGB(20, 20, 24) -- เข้มเกือบดำ อ่านออกบนพื้นขาว
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = ""
	nameLabel.Visible = false
	nameLabel.Parent = box
	local namePad = Instance.new("UIPadding")
	namePad.PaddingLeft = UDim.new(0, 8)
	namePad.Parent = nameLabel

	local choiceFrame = Instance.new("Frame") -- ลิสต์ช้อย ยึดขวากลางจอ (Genshin ref)
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

	-- ปุ่มเลิกคุย มุมซ้ายบนใต้แถบหนัง — กดแล้วออกจากบทเลย **ไม่นับว่าคุยจบ** (ไม่ยิง DialogueSeen)
	-- locked = true (item.lock) → ไม่สร้างปุ่มเลย (quit ค้าง false ตลอด บทเดินต่อจนจบทางเดียว)
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

	-- ซ่อน GUI อื่นที่เปิดอยู่ระหว่างคุย (HUD/ปุ่มเซฟ/Tool ฯลฯ บังการมองเห็น) — จำไว้คืนตอนจบ
	local hiddenGuis = {}
	for _, g in playerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(hiddenGuis, g)
		end
	end

	gui.Parent = playerGui

	-- หดกล่องให้พอดีจอ (มือถือ/จอเตี้ย) — refit ตอนหมุนจอ, disconnect ตอนจบบท
	local camera = workspace.CurrentCamera
	local function fitBox()
		boxScale.Scale = DialogueUI.layout(camera.ViewportSize).scale
	end
	fitBox()
	local viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitBox)

	local picks = {}
	local teleportTarget = nil
	-- item.cam (นอกเหนือ zoom-หน้าอัตโนมัติของ CameraFocus) — วางมุมด้วย CutsceneCamTool เหมือน cutscene mode 1
	-- ตัดกล้องตอนบรรทัดนั้นขึ้น (ไม่ใช่ timer) — caller ต้องไม่ส่ง head ให้ CameraFocus.focus (เดี๋ยวชนกัน) ดู docs/engines/dialogue.md
	local camSaved = nil -- เก็บ CameraType/Subject เดิมไว้คืนตอนจบ — เซ็ตครั้งแรกที่เจอ item.cam เท่านั้น (ไม่ยุ่งบทที่ไม่ใช้)
	local timeSet = false -- บทตั้ง item.time (ล็อกดวงอาทิตย์) ไหม — จบบทเคลียร์ SceneClock คืนเวลาจริง (เฉพาะบทที่ตั้ง)
	local function cutTo(camName: string)
		local folder = workspace:FindFirstChild("CutsceneCams")
		local part = folder and folder:FindFirstChild(camName, true) or workspace:FindFirstChild(camName, true)
		if not (part and part:IsA("BasePart")) then
			warn("[DialogueUI] ไม่เจอ Part กล้อง:", camName)
			return
		end
		if not camSaved then
			-- ⚠️ ต้องเก็บ FieldOfView ด้วย ไม่ใช่แค่ CameraType/Subject — เคยพลาดจน FOV ค้างค่า item.cam ทั้งเกมหลังเลิกคุย (12 ส.ค.)
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
	end -- ช้อยไหนมี .teleport = จำชื่อ Part ปลายทางไว้ ยิงตอนบทจบจริง (ไม่ใช่ branching — เนื้อเรื่องเดินเส้นเดิม แค่จบแล้วไปคนละที่)

	-- พิมพ์ข้อความ 1 บรรทัด แล้วรอคลิกไปต่อ
	-- actor = ใช้หา rig สำหรับ portrait viewport (ไม่ส่ง = คนที่คุยอยู่)
	local function speak(item, actor: string?)
		local speaker, text = item.speaker, item.text
		nameLabel.Visible = speaker ~= nil
		nameLabel.Text = speaker or ""

		-- ไม่มีชื่อคนพูด = ไม่โชว์หน้าตัวละคร (bullet เฉยๆ) · มีชื่อ = เรนเดอร์ rig สดจากแมพ ณ ตอนนี้
		-- speaker = "คุณ" (พูดคนเดียว ไม่ใช่คิดในใจแบบวงเล็บ) = โชว์หน้า player เอง ไม่ใช่ NPC ที่คุยด้วย
		if portraitVP then
			if speaker then
				portraitVP.showBust(AnimPlayer.findRig(speaker == "คุณ" and "player" or (actor or voiceName)))
			else
				portraitVP.clear()
			end
		end
		layoutText()

		-- typewriter บน RichText: พิมพ์ทีละตัว แต่ปิด tag <b>/<i> ที่เปิดค้างทุกเฟรมให้ markup valid เสมอ
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
		-- กล่องขนาดคงที่ = บทยาวเกินจะโดนตัดหาย เตือนคนเขียนบทให้ซอยประโยค (อย่าย่อฟอนต์)
		if not textLabel.TextFits then
			warn(("[DialogueUI] บทยาวเกินกล่อง ตัดเป็นหลายบรรทัดในลิสต์: %q"):format(text:sub(1, 40)))
		end
		conn:Disconnect()
		-- รอคลิกไปบรรทัดถัดไป (หรือกดเลิกคุย)
		local go = false
		-- เสียงคลิกมาจากตัวผูกกลางใน Main.client (อ่าน attribute Sfx) — ไม่เรียก Audio.sfx เองกันดัง 2 ที
		local conn2 = box.Activated:Connect(function()
			go = true
		end)
		while not go and not quit do task.wait() end
		conn2:Disconnect()
	end

	-- โชว์ช้อย รอ player เลือก คืนช้อยที่เลือก
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
			btn:SetAttribute("Sfx", "dialogue_choice") -- เสียงเลือกช้อย (ตัวผูกกลางใน Main.client เล่นให้)
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
		return picked -- nil = กดเลิกคุยระหว่างเลือก
	end

	task.spawn(function()
		local movedActors = {} -- ตัวที่ถูกสั่งท่า — จบบทแล้วหยุดให้หมด กันค้างท่าเดิม
		-- pcall ครอบ playback: บทพังกลางคัน (anim/face หาย ฯลฯ) ก็ยังวิ่ง cleanup ข้างล่างเสมอ
		-- ไม่งั้น InteractLock ค้าง = prompt ปิด + กระโดด/เดินไม่ได้หลังคุย (bug "บางครั้งกระโดดไม่ได้")
		local ok, err = pcall(function()
			local queue = table.clone(lines)
			local i = 1
			while i <= #queue and not quit do
				local item = DialogueUI.lineOf(queue[i])
				if item.cam then cutTo(item.cam) end -- ตัดกล้องตามบรรทัด ไม่ใช่ timer (ต่างจาก CutscenePlayer)
				if item.time then game:GetService("Lighting"):SetAttribute("SceneClock", item.time); timeSet = true end -- ล็อกดวงอาทิตย์ให้ฉาก (เช่น park=17) คืนตอนจบบท
				-- ท่าทาง/อารมณ์ เล่นก่อนข้อความขึ้น (Genshin: ขยับพร้อมเริ่มพูด)
				local moved = AnimPlayer.applyLine(item, voiceName)
				if moved then movedActors[moved] = true end
				if item.choices then
					local c = ask(item.choices)
					if c then -- nil = กดเลิกคุยระหว่างเลือก (quit)
						table.insert(picks, c.tone or "neutral")
						if c.teleport then teleportTarget = c.teleport end -- จำไว้ ยิงตอนจบบท ไม่ใช่ตอนนี้
						-- บทตอบกลับแทรกต่อท้ายทันที แล้วเดินเส้นเดิมต่อ (ไม่ branching)
						if c.reply then
							for k = #c.reply, 1, -1 do
								table.insert(queue, i + 1, c.reply[k])
							end
						end
					end
				elseif item.text then
					-- รูปหน้า: ตัวที่บรรทัดนี้ระบุ (actor) ไม่งั้นคนที่คุยอยู่ · face = อารมณ์ (มีรูปตามอารมณ์ก็ใช้)
					speak(item, item.actor or voiceName)
				end -- ไม่มี text = บรรทัดสั่งท่าล้วน ข้ามไปบรรทัดถัดไปทันที
				i += 1
			end
		end)
		if not ok then warn("[DialogueUI] บทพังกลางคัน:", err) end
		-- cleanup เสมอ (แม้บทพัง)
		for actor in movedActors do AnimPlayer.stop(actor) end
		if timeSet then game:GetService("Lighting"):SetAttribute("SceneClock", nil) end -- คืนดวงอาทิตย์เวลาจริง (เฉพาะบทที่ตั้ง time)
		if camSaved then -- คืนกล้องที่ item.cam ยึดไป (CameraFocus ไม่รู้จักตัวนี้ ต้องคืนเอง)
			camera.CameraType = camSaved.type
			camera.CameraSubject = camSaved.subject
				or (Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid"))
			camera.FieldOfView = camSaved.fov
		end
		viewportConn:Disconnect()
		gui:Destroy()
		for _, g in hiddenGuis do if g.Parent then g.Enabled = true end end -- คืน GUI ที่ซ่อนไว้
		DialogueUI.running = false
		if InteractLock then InteractLock.unlock() end
		Audio.duckBGM(false) -- คืนเสียงเพลงเต็ม
		-- onDone(picks, quit, teleportTarget) เรียกเสมอ — caller ต้องคืนกล้อง/unfreeze ทุกกรณี
		-- quit=true (กดเลิกคุย) = ไม่นับว่าคุยจบ · caller เช็ค quit เองว่าจะยิง DialogueSeen ไหม
		-- teleportTarget = ไม่ nil ถ้า player เลือกช้อยที่มี .teleport (เช่น เมนูเลือกแมพปลายทาง) — caller เป็นคนยิง TeleportTo เอง
		if onDone then onDone(picks, quit, teleportTarget) end
	end)
end

return DialogueUI
