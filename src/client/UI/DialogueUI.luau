-- DialogueUI.luau — typewriter ทางเดียวแบบ Undertale (design doc §7) ไม่มี choice
-- tag [slow] [fast] [normal] คุมความเร็วกลางบรรทัด — pure: parseTags | glue: show()
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Audio = if isStudio
	then require(script.Parent.Parent.AudioService)
	else require("../AudioService")

local DialogueUI = {}
DialogueUI.running = false

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

-- ===== UI glue (Studio เท่านั้น) =====
-- แสดง lines ทีละบรรทัด typewriter — คลิกระหว่างพิมพ์ = โชว์ทั้งบรรทัด, คลิกอีกที = บรรทัดถัดไป
-- voiceName = ชื่อ Sound ใน SoundService.Voice (blip ตอนพิมพ์) — ไม่ส่ง = ใช้ Default
function DialogueUI.show(playerGui, lines, onDone, voiceName)
	if DialogueUI.running then return end
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
	gui.Parent = playerGui

	task.spawn(function()
		for _, line in lines do
			local segs = DialogueUI.parseTags(line)
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
		gui:Destroy()
		DialogueUI.running = false
		if onDone then onDone() end
	end)
end

return DialogueUI
