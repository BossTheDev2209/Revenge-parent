-- Message.luau — แชท HSR style (PDF หน้า 9 กลาง, design doc §6: choice เลือกได้แต่ไม่มีผล NPC ตอบเหมือนเดิม)
-- format DMs (ทีมเขียนบท — docs/10):
--   แบบเก่า: { from="ชื่อ", lines={"...", "..."} }                          → bubble ฝั่ง NPC อย่างเดียว
--   แบบช้อย: { from="ชื่อ", exchanges={ {npc="...", choices={"ก","ข","ค"}, reply="..."} } }
local isStudio = script ~= nil
local DMs = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.DMs)
	else require("../../../shared/Content/DMs")

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
	-- ซ้าย: รายชื่อคน | ขวา: แชท + แถวช้อยล่าง
	local people = Instance.new("ScrollingFrame")
	people.Size = UDim2.new(0.28, -8, 1, -8)
	people.Position = UDim2.new(0, 4, 0, 4)
	people.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
	people.AutomaticCanvasSize = Enum.AutomaticSize.Y
	people.CanvasSize = UDim2.new(0, 0, 0, 0)
	people.Parent = frame
	local pl = Instance.new("UIListLayout")
	pl.Padding = UDim.new(0, 4)
	pl.Parent = people

	local chat = Instance.new("ScrollingFrame")
	chat.Size = UDim2.new(0.72, -12, 1, -64)
	chat.Position = UDim2.new(0.28, 4, 0, 4)
	chat.BackgroundColor3 = Color3.fromRGB(250, 250, 252)
	chat.AutomaticCanvasSize = Enum.AutomaticSize.Y
	chat.CanvasSize = UDim2.new(0, 0, 0, 0)
	chat.Parent = frame
	local cl = Instance.new("UIListLayout")
	cl.Padding = UDim.new(0, 6)
	cl.Parent = chat

	local choiceBar = Instance.new("Frame")
	choiceBar.Size = UDim2.new(0.72, -12, 0, 52)
	choiceBar.Position = UDim2.new(0.28, 4, 1, -56)
	choiceBar.BackgroundTransparency = 1
	choiceBar.Parent = frame

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
		for ci, choiceText in ex.choices or {} do
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1 / #ex.choices, -6, 1, 0)
			b.Position = UDim2.new((ci - 1) / #ex.choices, 3, 0, 0)
			b.BackgroundColor3 = Color3.fromRGB(70, 110, 180)
			b.TextColor3 = Color3.new(1, 1, 1)
			b.TextScaled = true
			b.TextWrapped = true
			b.Text = choiceText
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
