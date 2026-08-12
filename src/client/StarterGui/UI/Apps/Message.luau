-- Message.luau — แชท HSR style (PDF หน้า 9 กลาง, design doc §6: choice เลือกได้แต่ไม่มีผล NPC ตอบเหมือนเดิม)
-- format DMs (ทีมเขียนบท — docs/10):
--   แบบเก่า: { from="ชื่อ", lines={"...", "..."} }                          → bubble ฝั่ง NPC อย่างเดียว
--   แบบช้อย: { from="ชื่อ", exchanges={ {npc="...", choices={"ก","ข","ค"}, reply="..."} } }
--
-- ★ baked เป็น instance จริงแล้ว (9 ส.ค.) — โครงคงที่ (container ว่างทั้งหมด) bake เป็น template
--   เนื้อหาข้างในทุกส่วนยาวไม่แน่นอนจริง (รายชื่อ/บับเบิลแชท/ปุ่มช้อย) ยังสร้างจาก data เหมือนเดิม
--   template จริงอยู่ Gui_PC.Screen.AppTemplates.Message (แต่งใน Studio ได้)
--   ชื่อลูกที่โค้ดอ้าง ห้ามเปลี่ยน: People, Chat, ChoiceBar (ScrollingFrame/Frame ว่างทั้งหมด)
--
-- ★ 12 ส.ค. — responsive pass (docs/05 §5.5 "ห้าม pixel ตายตัว") + ขอบมนทุกชิ้น (user)
--   แก้ 5 อย่างที่เจอตอนวัดของจริง:
--   1) แถวรายชื่อ/ปุ่มช้อยเคยสูงเป็น px ตายตัว (44/34) + ระยะ 40px → 3 ช้อยกินสูง 120px แต่ ChoiceBar
--      สูงจริงแค่ 111.8px = ปุ่มสุดท้ายล้นกรอบ · เปลี่ยนเป็น scale ทั้งหมด อิงกรอบจริง
--   2) TextScaled บนกล่องสูง 44px = ตัวหนังสือยืดเต็มกล่อง ใหญ่เว่อร์เทียบบับเบิลที่ล็อก TextSize 18
--      → คุมเพดานด้วย UITextSizeConstraint ทุกชิ้น ขนาดคำนวณจากความกว้างกรอบ
--   3) บับเบิลฝั่งเราไม่เคยชิดขวา เพราะ Chat มี UIListLayout ซึ่งทับ Position ทิ้ง
--      → ห่อบับเบิลใน row เต็มความกว้างแล้วจัดซ้าย/ขวาใน row แทน
--   4) Chat/People ตั้ง SortOrder = Name แต่โค้ดไม่เคยตั้งชื่อ → ชื่อซ้ำกันหมด ลำดับไม่การันตี
--      → ตั้งชื่อเป็นเลขลำดับ ("%03d") + LayoutOrder ให้ถูกทั้งสอง SortOrder
--   5) ขนาดตัวอักษรคิดครั้งเดียวตอนเปิดแอป → ย่อ/ขยายจอระหว่างเปิดค้างไว้ ไม่ตาม
--      → ผูก AbsoluteSize signal คิดใหม่ทุกครั้งที่กรอบเปลี่ยนขนาด
local isStudio = script ~= nil
local DMs = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.DMs)
	else require("../../../../shared/Content/DMs")
-- จำนวนเงินก้อนต่อ payoutId (โชว์บนปุ่มเฉยๆ — server ตัดสินจ่ายจริงที่ SponsorService.claimDM)
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../../shared/Config")
-- ตัวจัดรูปตัวเลข 1,024 ใช้ตัวเดียวกับ HUD (อย่าเขียนซ้ำ — รูปแบบต้องตรงกันทั้งเกม)
local comma = (if isStudio then require(script.Parent.Parent.HUD) else require("../HUD")).comma

local Message = {}

-- ===== helper: ขอบมน / ระยะขอบใน / เพดานขนาดตัวอักษร =====
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

-- TextScaled ล้วน = ตัวยืดเต็มกล่อง (ใหญ่เกิน) · คุมเพดานไว้ ได้ทั้ง responsive และไม่เบ้
local function capText(inst)
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = 8
	c.MaxTextSize = 18 -- ค่าเริ่ม ถูกคำนวณทับทันทีโดย applyTextSizes()
	c.Parent = inst
	return c
end

-- สัดส่วนขนาดตัวอักษรต่อ "ความกว้างกรอบแอปจริง" (docs/05 §5.5 — ห้ามค่าคงที่)
-- { ratio, ต่ำสุด, สูงสุด } · จอใหญ่ = ตัวใหญ่ตาม แต่ไม่เกินเพดาน
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
	content.Visible = true -- template ซ่อนไว้ (Visible=false) กัน render ทับกันตอนพักเป็นแม่แบบ — clone ต้องเปิดเอง
	content.Parent = frame

	local people = content:FindFirstChild("People")
	local chat = content:FindFirstChild("Chat")
	local choiceBar = content:FindFirstChild("ChoiceBar")

	-- ===== responsive text — คำนวณใหม่ทุกครั้งที่กรอบเปลี่ยนขนาด =====
	-- เดิมคิดครั้งเดียวตอนเปิดแอป → ย่อ/ขยายหน้าต่างระหว่างเปิดค้างไว้ ตัวหนังสือไม่ตาม
	-- kind "cap" = UITextSizeConstraint.MaxTextSize (คู่กับ TextScaled) | "size" = TextSize ตรงๆ
	local scalables = {}
	local function track(inst, kind: string, spec)
		table.insert(scalables, { inst = inst, kind = kind, spec = spec })
		return inst
	end
	local function applyTextSizes()
		local basis = content.AbsoluteSize.X
		if basis <= 0 then basis = 660 end -- ยังไม่ render = ใช้ค่ากลางกันหาร 0
		for i = #scalables, 1, -1 do
			local s = scalables[i]
			if not s.inst.Parent then
				table.remove(scalables, i) -- ของที่ถูก Destroy ไปแล้ว (re-render) ทิ้งจาก list
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
	-- กรอบแอปเปลี่ยนขนาดเมื่อไหร่ (ผู้เล่นย่อหน้าต่าง/หมุนจอ) = คิดใหม่ทันที
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyTextSizes)

	local progress = {} -- [dm] = จำนวน exchange ที่คุยจบแล้ว (reset ทุกครั้งที่เปิดแอป — cosmetic)
	local picked = {}   -- [dm] = { [i] = ช้อยที่เลือก }
	local openDM        -- forward declare

	-- บับเบิล 1 อัน — ห่อใน row เต็มความกว้างเพราะ Chat มี UIListLayout (ทับ Position ของลูกตรงทิ้ง)
	--   ฝั่งเรา (mine) ชิดขวา · NPC ชิดซ้าย · สูงยืดตามข้อความ (AutomaticSize.Y)
	local seq = 0
	local function bubble(text, mine)
		seq += 1
		local row = Instance.new("Frame")
		row.Name = ("%03d"):format(seq) -- SortOrder = Name → ต้องเรียงได้จริง
		row.LayoutOrder = seq           -- เผื่อสลับเป็น SortOrder.LayoutOrder ทีหลัง
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

	-- ===== เงินก้อน sponsor ตาม milestone (12 ส.ค. 2569, user) =====
	-- ปุ่มโผล่ท้ายแชทเฉพาะ DM ที่มี payoutId · 3 สถานะ: รับได้ / ยังไม่ถึงยอด / รับแล้ว
	-- client แค่โชว์กับยิง action — เงื่อนไขจริง (ถึง milestone ไหม, รับไปแล้วยัง) server ตัดสินซ้ำเสมอ
	-- ดึง state ทันทีตั้งแต่แรก — PCScreen เรียก create() ก่อน refresh() ถ้าไม่ดึงเอง
	-- ปุ่มรอบแรกจะวาดด้วยข้อมูลว่าง (ขึ้น "ยังไม่ถึงยอด" ทั้งที่ถึงแล้ว) แล้วค่อยกระพริบแก้ทีหลัง
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

	local renderChat -- forward declare — body เรียก renderChat ซ้ำตอนกดช้อย
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
		for i = 1, done do -- exchange ที่จบแล้ว: npc → เรา → npc ตอบ
			local ex = dm.exchanges[i]
			bubble(ex.npc, false)
			bubble(picked[dm][i], true)
			if ex.reply then bubble(ex.reply, false) end
		end

		local ex = dm.exchanges[done + 1]
		if not ex then return end
		bubble(ex.npc, false)

		-- ช้อยเรียงลงเต็มความกว้าง 3 แถว ตามภาพร่าง (ไม่ใช่เรียงข้างกัน)
		-- ★ scale ล้วน: n ช้อยแบ่งความสูง ChoiceBar เท่าๆ กัน เว้นช่องไฟ 12% → ไม่มีทางล้นกรอบ
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
			bs.Thickness = 2
			bs.Parent = b
			b.Activated:Connect(function()
				-- เลือกอะไรก็ได้ NPC ตอบเหมือนเดิม (design §6)
				picked[dm][done + 1] = choiceText
				progress[dm] = done + 1
				renderChat(dm)
			end)
		end
	end

	-- ห่อ body ไว้ เพราะ body มี early return 2 จุด (format เก่า / คุยจบแล้ว)
	-- ถ้าเรียก applyTextSizes/payoutButton ท้าย body ตรงๆ สองเส้นทางนั้นจะข้ามไป
	renderChat = function(dm)
		renderChatBody(dm)
		payoutButton(dm) -- ต่อท้ายแชทเสมอ (ไม่มี payoutId = ฟังก์ชันคืนเลย)
		applyTextSizes() -- ของที่เพิ่ง track เข้ามารอบนี้ ต้องได้ขนาดทันที ไม่ใช่รอ resize
	end

	-- ลายเซ็นสถานะปุ่มเงินของ DM ที่เปิดอยู่ — ใช้ตัดสินว่า refresh ต้องวาดใหม่ไหม
	-- (state ถูก push บ่อยมากตามเวลาในเกม วาดใหม่ทุกครั้ง = แชทกระพริบ + เปลืองเปล่า)
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

	-- รายชื่อคนซ้าย — สูงเป็น scale ของ People (เดิม 44px ตายตัว) + ขอบมน + เพดานตัวอักษร
	local rowIdx = 0
	for _, dm in DMs do
		rowIdx += 1
		local b = Instance.new("TextButton")
		b.Name = ("%03d"):format(rowIdx)
		b.LayoutOrder = rowIdx
		b.Size = UDim2.fromScale(0.94, 0.098) -- เดิม offset -8px ตายตัว → scale ล้วน
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

	applyTextSizes()
	if DMs[1] then openDM(DMs[1]) end

	local app = {}
	-- state ใหม่จาก server → อัปเดตปุ่มเงินก้อน (กดรับสำเร็จ = server ตั้ง dmClaimed แล้ว push กลับมา)
	-- วาดใหม่เฉพาะตอนสถานะปุ่มเปลี่ยนจริง ไม่ใช่ทุก push
	function app.refresh(state)
		latestState = state
		local sig = payoutSig(currentDM)
		if sig ~= lastPayoutSig then
			lastPayoutSig = sig
			if currentDM then renderChat(currentDM) end
		end
	end
	return app
end

return Message
