-- Message.luau — แชท HSR style (PDF หน้า 9 กลาง, design doc §6: choice เลือกได้แต่ไม่มีผล NPC ตอบเหมือนเดิม)
-- format DMs (ทีมเขียนบท — docs/10):
--   แบบเก่า: { from="ชื่อ", lines={"...", "..."} }                          → bubble ฝั่ง NPC อย่างเดียว
--   แบบช้อย: { from="ชื่อ", exchanges={ {npc="...", choices={"ก","ข","ค"}, reply="..."} } }
--
-- ★ baked เป็น instance จริงแล้ว (9 ส.ค.) — โครงคงที่ (container ว่างทั้งหมด) bake เป็น template
--   เนื้อหาข้างในทุกส่วนยาวไม่แน่นอนจริง (รายชื่อ/บับเบิลแชท/ปุ่มช้อย) ยังสร้างจาก data เหมือนเดิม
--   template จริงอยู่ Gui_PC.Screen.AppTemplates.Message (แต่งใน Studio ได้)
--   ชื่อลูกที่โค้ดอ้าง ห้ามเปลี่ยน: People, Chat, ChoiceBar (ScrollingFrame/Frame ว่างทั้งหมด)
local isStudio = script ~= nil
local DMs = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.DMs)
	else require("../../../../shared/Content/DMs")

local Message = {}

local function bubble(parent, text, mine)
	local b = Instance.new("TextLabel")
	b.Size = UDim2.new(0.7, 0, 0, 40)
	b.AutomaticSize = Enum.AutomaticSize.Y
	b.Position = UDim2.new(mine and 0.28 or 0.02, 0, 0, 0)
	b.BackgroundColor3 = mine and Color3.fromRGB(90, 170, 90) or Color3.fromRGB(240, 240, 245)
	b.TextColor3 = mine and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
	b.TextSize = 18
	b.TextWrapped = true
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Text = " " .. text .. " "
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = b
	return b
end

function Message.create(frame, deps)
	local guiPC = frame:FindFirstAncestorOfClass("ScreenGui")
	local template = guiPC and guiPC:FindFirstChild("Screen") and guiPC.Screen.AppTemplates:FindFirstChild("Message")
	if not template then
		warn("[Message] ไม่มี template Gui_PC.Screen.AppTemplates.Message — แต่งใน Studio ให้ครบก่อน")
		return {}
	end
	local content = template:Clone()
	content.Name = "MessageContent"
	content.Visible = true -- template ซ่อนไว้ (Visible=false) กัน render ทับกันตอนพักเป็นแม่แบบ — clone ต้องเปิดเอง
	content.Parent = frame

	local people = content:FindFirstChild("People")
	local chat = content:FindFirstChild("Chat")
	local choiceBar = content:FindFirstChild("ChoiceBar")

	local progress = {} -- [dm] = จำนวน exchange ที่คุยจบแล้ว (reset ทุกครั้งที่เปิดแอป — cosmetic)
	local picked = {}   -- [dm] = { [i] = ช้อยที่เลือก }
	local openDM        -- forward declare

	local function renderChat(dm)
		for _, ch in chat:GetChildren() do
			if ch:IsA("TextLabel") then ch:Destroy() end
		end
		for _, ch in choiceBar:GetChildren() do
			ch:Destroy()
		end

		if dm.lines then -- format เก่า: NPC พูดฝ่ายเดียว
			for _, line in dm.lines do
				bubble(chat, line, false)
			end
			return
		end

		local done = progress[dm] or 0
		for i = 1, done do -- exchange ที่จบแล้ว: npc → เรา → npc ตอบ
			local ex = dm.exchanges[i]
			bubble(chat, ex.npc, false)
			bubble(chat, picked[dm][i], true)
			if ex.reply then bubble(chat, ex.reply, false) end
		end

		local ex = dm.exchanges[done + 1]
		if not ex then return end
		bubble(chat, ex.npc, false)
		-- ช้อยเรียงลงเต็มความกว้าง 3 แถว ตามภาพร่าง (ไม่ใช่เรียงข้างกัน)
		for ci, choiceText in ex.choices or {} do
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(0.86, 0, 0, 34)
			b.Position = UDim2.new(0.07, 0, 0, (ci - 1) * 40)
			b.BackgroundColor3 = Color3.new(1, 1, 1)
			b.TextColor3 = Color3.fromRGB(30, 60, 160)
			b.TextScaled = true
			b.TextWrapped = true
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.Text = ("%d.  %s"):format(ci, choiceText)
			local bs = Instance.new("UIStroke")
			bs.Color = Color3.fromRGB(30, 60, 160)
			bs.Thickness = 2
			bs.Parent = b
			b.Parent = choiceBar
			b.Activated:Connect(function()
				-- เลือกอะไรก็ได้ NPC ตอบเหมือนเดิม (design §6)
				picked[dm][done + 1] = choiceText
				progress[dm] = done + 1
				renderChat(dm)
			end)
		end
	end

	openDM = function(dm)
		progress[dm] = progress[dm] or 0
		picked[dm] = picked[dm] or {}
		renderChat(dm)
	end

	for _, dm in DMs do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -8, 0, 44)
		b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		b.TextScaled = true
		b.Text = dm.from
		b.Parent = people
		b.Activated:Connect(function() openDM(dm) end)
	end

	if DMs[1] then openDM(DMs[1]) end
	return {}
end

return Message
