-- Message — แชท HSR style (design doc §6: choice เลือกได้แต่ NPC ตอบเหมือนเดิม)
-- format DMs: { from, lines={...} } (NPC พูดฝ่ายเดียว) หรือ { from, exchanges={ {npc, choices, reply} } }
-- baked template อยู่ Gui_PC.Screen.AppTemplates.Message · ชื่อลูกที่โค้ดอ้าง ห้ามเปลี่ยน: People, Chat, ChoiceBar
-- responsive: ทุกชิ้น scale + เพดานขนาดตัวอักษร (ห้าม pixel ตายตัว) คิดใหม่ทุกครั้งที่กรอบเปลี่ยนขนาด
local isStudio = script ~= nil
local DMs = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.DMs)
	else require("../../../../shared/Content/DMs")
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../../shared/Config")
-- comma: ตัวจัดรูปตัวเลขตัวเดียวกับ HUD (รูปแบบต้องตรงกันทั้งเกม)
local comma = (if isStudio then require(script.Parent.Parent.HUD) else require("../HUD")).comma

local Message = {}

local function corner(inst, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

local function padding(inst, x: number, y: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, x)
	p.PaddingRight = UDim.new(0, x)
	p.PaddingTop = UDim.new(0, y)
	p.PaddingBottom = UDim.new(0, y)
	p.Parent = inst
	return p
end

-- TextScaled ล้วน = ตัวยืดเต็มกล่อง — คุมเพดานไว้
local function capText(inst)
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = 8
	c.MaxTextSize = 18 -- ถูก applyTextSizes() คำนวณทับ
	c.Parent = inst
	return c
end

-- สัดส่วนขนาดตัวอักษรต่อความกว้างกรอบ · { ratio, ต่ำสุด, สูงสุด }
local TEXT = {
	people = { 0.026, 11, 20 }, -- แถวรายชื่อ
	bubble = { 0.028, 12, 22 }, -- บับเบิลแชท
	choice = { 0.024, 11, 18 }, -- ปุ่มช้อย
}

function Message.create(frame, deps)
	local guiPC = frame:FindFirstAncestorOfClass("ScreenGui")
	local template = guiPC and guiPC:FindFirstChild("Screen") and guiPC.Screen.AppTemplates:FindFirstChild("Message")
	if not template then
		warn("[Message] ไม่มี template Gui_PC.Screen.AppTemplates.Message — แต่งใน Studio ให้ครบก่อน")
		return {}
	end
	local content = template:Clone()
	content.Name = "MessageContent"
	content.Visible = true -- template ซ่อนไว้ clone ต้องเปิดเอง
	content.Parent = frame

	local people = content:FindFirstChild("People")
	local chat = content:FindFirstChild("Chat")
	local choiceBar = content:FindFirstChild("ChoiceBar")

	-- responsive text — คำนวณใหม่ทุกครั้งที่กรอบเปลี่ยนขนาด · kind "cap" = MaxTextSize | "size" = TextSize ตรงๆ
	local scalables = {}
	local function track(inst, kind: string, spec)
		table.insert(scalables, { inst = inst, kind = kind, spec = spec })
		return inst
	end
	local function applyTextSizes()
		local basis = content.AbsoluteSize.X
		if basis <= 0 then basis = 660 end -- ยังไม่ render = ค่ากลางกันหาร 0
		for i = #scalables, 1, -1 do
			local s = scalables[i]
			if not s.inst.Parent then
				table.remove(scalables, i) -- ของที่ถูก Destroy (re-render) ทิ้งจาก list
			else
				local ratio, lo, hi = s.spec[1], s.spec[2], s.spec[3]
				local size = math.clamp(math.floor(basis * ratio + 0.5), lo, hi)
				if s.kind == "cap" then
					s.inst.MaxTextSize = size
				else
					s.inst.TextSize = size
				end
			end
		end
	end
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyTextSizes)

	local progress = {} -- [dm] = จำนวน exchange ที่คุยจบ (reset ทุกครั้งที่เปิดแอป)
	local picked = {}   -- [dm] = { [i] = ช้อยที่เลือก }
	local openDM

	-- บับเบิล 1 อัน — ห่อใน row เต็มความกว้าง (Chat มี UIListLayout ทับ Position ของลูกตรง) · mine = ชิดขวา
	local seq = 0
	local function bubble(text, mine)
		seq += 1
		local row = Instance.new("Frame")
		row.Name = ("%03d"):format(seq) -- SortOrder = Name → ต้องเรียงได้จริง
		row.LayoutOrder = seq
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundTransparency = 1
		row.Parent = chat

		local b = Instance.new("TextLabel")
		b.Name = "Bubble"
		b.AnchorPoint = Vector2.new(if mine then 1 else 0, 0)
		b.Position = UDim2.fromScale(if mine then 0.98 else 0.02, 0)
		b.Size = UDim2.new(0.72, 0, 0, 0)
		b.AutomaticSize = Enum.AutomaticSize.Y
		b.BackgroundColor3 = if mine then Color3.fromRGB(90, 170, 90) else Color3.fromRGB(240, 240, 245)
		b.TextColor3 = if mine then Color3.new(1, 1, 1) else Color3.fromRGB(25, 25, 30)
		b.TextWrapped = true
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.TextYAlignment = Enum.TextYAlignment.Top
		b.Text = text
		b.Parent = row
		corner(b, 12)
		padding(b, 12, 9)
		track(b, "size", TEXT.bubble)
		return b
	end

	-- เงินก้อน sponsor ตาม milestone — ปุ่มโผล่ท้ายแชทเฉพาะ DM ที่มี payoutId · 3 สถานะ (รับได้/ยังไม่ถึง/รับแล้ว)
	-- client แค่โชว์+ยิง action · ดึง state ตั้งแต่แรก (PCScreen เรียก create() ก่อน refresh())
	local latestState = deps.getState and deps.getState() or nil
	local function payoutButton(dm)
		local id = dm.payoutId
		local amount = id and Config.DMPayouts[id]
		if not amount then return end

		local claimed = latestState and latestState.dmClaimed and latestState.dmClaimed[id]
		local follower = (latestState and latestState.follower) or 0
		local reached = follower >= (dm.unlockFollower or 0)

		local b = Instance.new("TextButton")
		b.Name = "999_payout" -- SortOrder = Name → ท้ายสุดของแชทเสมอ
		b.LayoutOrder = 999
		b.Size = UDim2.new(0.6, 0, 0, 0)
		b.AutomaticSize = Enum.AutomaticSize.Y
		b.TextWrapped = true
		b.TextXAlignment = Enum.TextXAlignment.Center
		b.AutoButtonColor = claimed ~= true and reached
		if claimed then
			b.Text = ("✓ รับค่าจ้างแล้ว  ฿%s"):format(comma(amount))
			b.BackgroundColor3 = Color3.fromRGB(205, 208, 215)
			b.TextColor3 = Color3.fromRGB(95, 98, 108)
		elseif reached then
			b.Text = ("💰 กดรับค่าจ้าง  ฿%s"):format(comma(amount))
			b.BackgroundColor3 = Color3.fromRGB(70, 165, 85)
			b.TextColor3 = Color3.new(1, 1, 1)
		else
			b.Text = ("🔒 ถึง %s ผู้ติดตามก่อน"):format(comma(dm.unlockFollower or 0))
			b.BackgroundColor3 = Color3.fromRGB(205, 208, 215)
			b.TextColor3 = Color3.fromRGB(95, 98, 108)
		end
		b.Parent = chat
		corner(b, 10)
		padding(b, 14, 10)
		track(b, "size", TEXT.bubble)

		if claimed or not reached then return end
		b.Activated:Connect(function()
			if b:GetAttribute("sent") then return end -- กันกดรัวระหว่างรอ state รอบใหม่
			b:SetAttribute("sent", true)
			b.Text = "กำลังรับ..."
			b.BackgroundColor3 = Color3.fromRGB(150, 155, 165)
			deps.fireAction({ type = "ClaimDMPayout", id = id })
		end)
	end

	local renderChat
	local function renderChatBody(dm)
		-- ล้างทั้ง row (Frame) ไม่ใช่แค่ TextLabel — UIListLayout ไม่ใช่ GuiObject จึงรอด
		for _, ch in chat:GetChildren() do
			if ch:IsA("GuiObject") then ch:Destroy() end
		end
		for _, ch in choiceBar:GetChildren() do
			if ch:IsA("GuiObject") then ch:Destroy() end
		end
		seq = 0

		if dm.lines then -- format เก่า: NPC พูดฝ่ายเดียว
			for _, line in dm.lines do
				bubble(line, false)
			end
			return
		end

		local done = progress[dm] or 0
		for i = 1, done do -- exchange ที่จบ: npc → เรา → npc ตอบ
			local ex = dm.exchanges[i]
			bubble(ex.npc, false)
			bubble(picked[dm][i], true)
			if ex.reply then bubble(ex.reply, false) end
		end

		local ex = dm.exchanges[done + 1]
		if not ex then return end
		bubble(ex.npc, false)

		-- ช้อยเรียงลงเต็มความกว้าง · scale ล้วน: n ช้อยแบ่งความสูง ChoiceBar เท่าๆ กัน (ไม่ล้นกรอบ)
		local choices = ex.choices or {}
		local n = #choices
		local slot = if n > 0 then 1 / n else 1
		for ci, choiceText in choices do
			local b = Instance.new("TextButton")
			b.Name = ("%03d"):format(ci)
			b.LayoutOrder = ci
			b.Size = UDim2.fromScale(0.86, slot * 0.88)
			b.Position = UDim2.fromScale(0.07, (ci - 1) * slot)
			b.BackgroundColor3 = Color3.new(1, 1, 1)
			b.TextColor3 = Color3.fromRGB(30, 60, 160)
			b.TextScaled = true
			b.TextWrapped = true
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.Text = ("%d.  %s"):format(ci, choiceText)
			b.Parent = choiceBar
			corner(b, 8)
			padding(b, 10, 4)
			track(capText(b), "cap", TEXT.choice)
			local bs = Instance.new("UIStroke")
			bs.Color = Color3.fromRGB(30, 60, 160)
			bs.Thickness = 1
			bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- ขอบปุ่มเท่านั้น ไม่ stroke ตัวหนังสือ
			bs.Parent = b
			b.Activated:Connect(function()
				-- เลือกอะไรก็ได้ NPC ตอบเหมือนเดิม (design §6)
				picked[dm][done + 1] = choiceText
				progress[dm] = done + 1
				renderChat(dm)
			end)
		end
	end

	-- คุยจบทั้งบทหรือยัง — ปุ่มรับเงินโผล่เฉพาะตอนจบ · lines = จบทันที · exchanges = ตอบครบทุก exchange
	local function convDone(dm): boolean
		if dm.lines then return true end
		if dm.exchanges then return (progress[dm] or 0) >= #dm.exchanges end
		return true
	end

	-- ห่อ body เพราะ body มี early return 2 จุด (format เก่า/คุยจบ) — ต้องเรียก payoutButton/applyTextSizes ท้ายเสมอ
	renderChat = function(dm)
		renderChatBody(dm)
		if convDone(dm) then payoutButton(dm) end
		applyTextSizes() -- ของที่เพิ่ง track รอบนี้ ต้องได้ขนาดทันที
	end

	-- ลายเซ็นสถานะปุ่มเงิน — ใช้ตัดสินว่า refresh ต้องวาดใหม่ไหม (state push บ่อย วาดทุกครั้ง = แชทกระพริบ)
	local function payoutSig(dm): string
		local id = dm and dm.payoutId
		if not id then return "none" end
		local claimed = (latestState and latestState.dmClaimed and latestState.dmClaimed[id]) == true
		local reached = ((latestState and latestState.follower) or 0) >= (dm.unlockFollower or 0)
		return tostring(claimed) .. "|" .. tostring(reached)
	end

	local currentDM, lastPayoutSig = nil, nil
	openDM = function(dm)
		progress[dm] = progress[dm] or 0
		picked[dm] = picked[dm] or {}
		currentDM = dm
		renderChat(dm)
		lastPayoutSig = payoutSig(dm)
	end

	-- รายชื่อคนซ้าย — โชว์เฉพาะคนที่ทักมาแล้ว (ยังไม่ถึงยอด = ไม่เห็นชื่อ กันสปอยล์) · ถึงยอด Main.client เด้ง toast
	local function unlockedDMs()
		local f = (latestState and latestState.follower) or 0
		local list = {}
		for _, dm in DMs do
			if f >= (dm.unlockFollower or 0) then table.insert(list, dm) end
		end
		return list
	end

	local function buildPeople(list)
		for _, ch in people:GetChildren() do
			if ch:IsA("GuiObject") then ch:Destroy() end
		end
		for i, dm in list do
			local b = Instance.new("TextButton")
			b.Name = ("%03d"):format(i)
			b.LayoutOrder = i
			b.Size = UDim2.fromScale(0.94, 0.098)
			b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			b.TextColor3 = Color3.fromRGB(25, 25, 30)
			b.TextScaled = true
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.Text = dm.from
			b.Parent = people
			corner(b, 8)
			padding(b, 10, 5)
			track(capText(b), "cap", TEXT.people)
			b.Activated:Connect(function() openDM(dm) end)
		end
	end

	-- ยังไม่มีใครทักมา (เข้าเฟส 2 แต่ follower ยังไม่ถึงก้อนแรก)
	local function showEmpty()
		currentDM = nil
		for _, ch in chat:GetChildren() do
			if ch:IsA("GuiObject") then ch:Destroy() end
		end
		for _, ch in choiceBar:GetChildren() do
			if ch:IsA("GuiObject") then ch:Destroy() end
		end
		local l = Instance.new("TextLabel")
		l.Name = "001"
		l.Size = UDim2.new(1, 0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.BackgroundTransparency = 1
		l.TextColor3 = Color3.fromRGB(120, 124, 134)
		l.TextWrapped = true
		l.Text = "ยังไม่มีใครทักมา\nทำคลิปให้คนรู้จักมากกว่านี้ก่อน"
		l.Parent = chat
		track(l, "size", TEXT.bubble)
		applyTextSizes()
	end

	local shown = unlockedDMs()
	local shownCount = #shown
	buildPeople(shown)
	applyTextSizes()
	if shown[1] then openDM(shown[1]) else showEmpty() end

	local app = {}
	-- state ใหม่ → มีคนทักใหม่ไหม / ปุ่มเงินเปลี่ยนสถานะไหม · วาดใหม่เฉพาะตอนเปลี่ยนจริง (state push บ่อย)
	function app.refresh(state)
		latestState = state

		local list = unlockedDMs()
		if #list ~= shownCount then
			shownCount = #list
			local keep = currentDM
			buildPeople(list)
			-- คนที่เปิดค้างยังอยู่ในรายชื่อ = เปิดค้างเหมือนเดิม ไม่กระโดดไปคนอื่น
			local stillThere = false
			for _, dm in list do
				if dm == keep then stillThere = true end
			end
			if stillThere then
				openDM(keep)
			elseif list[1] then
				openDM(list[1]) -- โหลดเซฟที่ follower ต่ำกว่าเดิม → คนที่เปิดอยู่หาย
			else
				showEmpty()
			end
			return
		end

		local sig = payoutSig(currentDM)
		if sig ~= lastPayoutSig then
			lastPayoutSig = sig
			if currentDM then renderChat(currentDM) end
		end
	end
	return app
end

return Message
