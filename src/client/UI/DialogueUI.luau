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
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Audio = if isStudio
	then require(script.Parent.Parent.AudioService)
	else require("../AudioService")
local AnimPlayer = if isStudio
	then require(script.Parent.Parent.AnimPlayer)
	else require("../AnimPlayer")

local DialogueUI = {}
DialogueUI.running = false

local TONES = { plus = true, neutral = true, minus = true }

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
	DialogueUI.running = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_Dialogue"
	gui.ResetOnSpawn = false

	local box = Instance.new("TextButton") -- ทั้งกล่องคือปุ่ม continue
	box.Size = UDim2.new(0.8, 0, 0.22, 0)
	box.Position = UDim2.new(0.1, 0, 0.72, 0)
	box.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	box.BackgroundTransparency = 0.1
	box.TextColor3 = Color3.new(1, 1, 1)
	box.TextScaled = true
	box.TextWrapped = true
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.AutoButtonColor = false
	box.Text = ""
	box.Parent = gui

	local nameLabel = Instance.new("TextLabel") -- ชื่อคนพูด เกาะมุมซ้ายบนของกล่อง
	nameLabel.Size = UDim2.new(0.3, 0, 0.06, 0)
	nameLabel.Position = UDim2.new(0.1, 0, 0.66, 0)
	nameLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	nameLabel.BackgroundTransparency = 0.1
	nameLabel.TextColor3 = Color3.fromRGB(255, 215, 120)
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = ""
	nameLabel.Visible = false
	nameLabel.Parent = gui

	local choiceFrame = Instance.new("Frame") -- ลิสต์ช้อย ลอยเหนือกล่อง
	choiceFrame.Size = UDim2.new(0.5, 0, 0.3, 0)
	choiceFrame.Position = UDim2.new(0.45, 0, 0.34, 0)
	choiceFrame.BackgroundTransparency = 1
	choiceFrame.Visible = false
	choiceFrame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = choiceFrame

	gui.Parent = playerGui

	local picks = {}

	-- พิมพ์ข้อความ 1 บรรทัด แล้วรอคลิกไปต่อ
	local function speak(speaker: string?, text: string)
		nameLabel.Visible = speaker ~= nil
		nameLabel.Text = speaker or ""
		local segs = DialogueUI.parseTags(text)
		local full = ""
		for _, s in segs do full ..= s.text end
		local skip = false
		local conn = box.Activated:Connect(function() skip = true end)
		box.Text = ""
		for _, seg in segs do
			local delay = Config.Dialogue.charDelay[seg.speed] or Config.Dialogue.charDelay.normal
			-- utf8 ทีละตัวอักษร (ภาษาไทยตัวละหลาย byte)
			for _, code in utf8.codes(seg.text) do
				if skip then break end
				box.Text ..= utf8.char(code)
				if code ~= 32 then Audio.voice(voiceName) end -- เว้นวรรคไม่ต้องมีเสียง
				task.wait(delay)
			end
			if skip then break end
		end
		box.Text = full
		conn:Disconnect()
		-- รอคลิกไปบรรทัดถัดไป
		local go = false
		local conn2 = box.Activated:Connect(function()
			go = true
			Audio.sfx("ui_click")
		end)
		while not go do task.wait() end
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
			btn.Parent = choiceFrame
			btn.Activated:Connect(function()
				if picked then return end
				picked = c
				Audio.sfx("ui_click")
			end)
		end
		choiceFrame.Visible = true
		while not picked do task.wait() end
		choiceFrame.Visible = false
		for _, b in choiceFrame:GetChildren() do
			if b:IsA("TextButton") then b:Destroy() end
		end
		return picked
	end

	task.spawn(function()
		local queue = table.clone(lines)
		local i = 1
		local movedActors = {} -- ตัวที่ถูกสั่งท่า — จบบทแล้วหยุดให้หมด กันค้างท่าเดิม
		while i <= #queue do
			local item = DialogueUI.lineOf(queue[i])
			-- ท่าทาง/อารมณ์ เล่นก่อนข้อความขึ้น (Genshin: ขยับพร้อมเริ่มพูด)
			local moved = AnimPlayer.applyLine(item, voiceName)
			if moved then movedActors[moved] = true end
			if item.choices then
				local c = ask(item.choices)
				table.insert(picks, c.tone or "neutral")
				-- บทตอบกลับแทรกต่อท้ายทันที แล้วเดินเส้นเดิมต่อ (ไม่ branching)
				if c.reply then
					for k = #c.reply, 1, -1 do
						table.insert(queue, i + 1, c.reply[k])
					end
				end
			elseif item.text then
				speak(item.speaker, item.text)
			end -- ไม่มี text = บรรทัดสั่งท่าล้วน ข้ามไปบรรทัดถัดไปทันที
			i += 1
		end
		for actor in movedActors do AnimPlayer.stop(actor) end
		gui:Destroy()
		DialogueUI.running = false
		if onDone then onDone(picks) end
	end)
end

return DialogueUI
