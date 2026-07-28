-- Feedback.luau — **layout ตาม PDF หน้า 8** (ไม่มีภาพร่างแยกในโฟลเดอร์ ui screenshot)
--   ซ้าย : Latest upload (list คลิป + views) + กราฟ follower 7 วัน (★ แท่งเปล่ารอ history จริง)
--   ขวา  : Comment from [คลิป] + ปุ่มตอบ (ช่องเดียวที่นับ choice — design doc §6)
-- ย้ายการตอบ comment จาก floating CommentUI เข้ามาที่นี่ตาม PDF หน้า 5
local isStudio = script ~= nil
local Comments = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.Comments)
	else require("../../../shared/Content/Comments")

local Feedback = {}

local function stroke(inst, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(40, 40, 50)
	s.Thickness = thick or 1
	s.Parent = inst
	return s
end

function Feedback.create(frame, deps)
	frame.BackgroundColor3 = Color3.fromRGB(240, 242, 246)

	-- ===== ซ้าย =====
	local leftHead = Instance.new("TextLabel")
	leftHead.Position = UDim2.new(0, 8, 0, 6)
	leftHead.Size = UDim2.new(0.48, -8, 0, 24)
	leftHead.BackgroundTransparency = 1
	leftHead.TextColor3 = Color3.fromRGB(30, 60, 160)
	leftHead.TextScaled = true
	leftHead.TextXAlignment = Enum.TextXAlignment.Left
	leftHead.Text = "Latest upload"
	leftHead.Parent = frame

	local history = Instance.new("ScrollingFrame")
	history.Position = UDim2.new(0, 8, 0, 32)
	history.Size = UDim2.new(0.48, -8, 0.42, 0)
	history.BackgroundColor3 = Color3.new(1, 1, 1)
	history.ScrollBarThickness = 4
	history.CanvasSize = UDim2.new(0, 0, 0, 0)
	history.AutomaticCanvasSize = Enum.AutomaticSize.Y
	history.Parent = frame
	stroke(history)
	local hl = Instance.new("UIListLayout")
	hl.Padding = UDim.new(0, 4)
	hl.Parent = history

	local graphHead = Instance.new("TextLabel")
	graphHead.Position = UDim2.new(0, 8, 0.47, 0)
	graphHead.Size = UDim2.new(0.48, -8, 0, 22)
	graphHead.BackgroundTransparency = 1
	graphHead.TextColor3 = Color3.fromRGB(30, 60, 160)
	graphHead.TextScaled = true
	graphHead.TextXAlignment = Enum.TextXAlignment.Left
	graphHead.Text = "follower (last 7 days)"
	graphHead.Parent = frame

	-- กราฟแท่ง 7 วัน — state ยังไม่เก็บ history รายวัน (docs/14 §2) ใช้คลิป 7 ใบล่าสุดแทนไปก่อน
	local graph = Instance.new("Frame")
	graph.Position = UDim2.new(0, 8, 0.53, 0)
	graph.Size = UDim2.new(0.48, -8, 0.42, 0)
	graph.BackgroundColor3 = Color3.new(1, 1, 1)
	graph.Parent = frame
	stroke(graph)
	local bars = {}
	for i = 1, 7 do
		local col = Instance.new("Frame")
		col.AnchorPoint = Vector2.new(0, 1)
		col.Position = UDim2.new((i - 1) / 7 + 0.02, 0, 1, -4)
		col.Size = UDim2.new(1 / 7 - 0.03, 0, 0, 0)
		col.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
		col.BorderSizePixel = 0
		col.Parent = graph
		bars[i] = col
	end

	-- ===== ขวา =====
	local commentHead = Instance.new("TextLabel")
	commentHead.Position = UDim2.new(0.52, 0, 0, 6)
	commentHead.Size = UDim2.new(0.46, 0, 0, 24)
	commentHead.BackgroundTransparency = 1
	commentHead.TextColor3 = Color3.fromRGB(30, 60, 160)
	commentHead.TextScaled = true
	commentHead.TextXAlignment = Enum.TextXAlignment.Left
	commentHead.Text = "Comment"
	commentHead.Parent = frame

	local commentLabel = Instance.new("TextLabel")
	commentLabel.Position = UDim2.new(0.52, 0, 0, 32)
	commentLabel.Size = UDim2.new(0.46, 0, 0, 84)
	commentLabel.BackgroundColor3 = Color3.fromRGB(255, 250, 210)
	commentLabel.TextScaled = true
	commentLabel.TextWrapped = true
	commentLabel.Text = ""
	commentLabel.Parent = frame
	stroke(commentLabel)

	local buttonArea = Instance.new("Frame")
	buttonArea.Position = UDim2.new(0.52, 0, 0, 124)
	buttonArea.Size = UDim2.new(0.46, 0, 1, -132)
	buttonArea.BackgroundTransparency = 1
	buttonArea.Parent = frame

	local function makeButton(text, response, order, color)
		local b = Instance.new("TextButton")
		b.Position = UDim2.new(0, 0, 0, (order - 1) * 46)
		b.Size = UDim2.new(1, 0, 0, 40)
		b.BackgroundColor3 = color or Color3.fromRGB(70, 70, 100)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextScaled = true
		b.TextWrapped = true
		b.Text = text
		b.Parent = buttonArea
		b.Activated:Connect(function()
			deps.fireAction({ type = "AnswerComment", response = response })
		end)
	end

	local app = {}
	function app.refresh(state)
		-- list คลิปที่อัปแล้ว (ใหม่สุดบน)
		for _, ch in history:GetChildren() do
			if ch:IsA("TextLabel") then ch:Destroy() end
		end
		local recent = {}
		for i = #state.clips, 1, -1 do
			local c = state.clips[i]
			if c.uploaded then
				table.insert(recent, c)
				local row = Instance.new("TextLabel")
				row.Size = UDim2.new(1, -10, 0, 26)
				row.BackgroundTransparency = 1
				row.TextColor3 = Color3.fromRGB(40, 40, 50)
				row.TextScaled = true
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.Text = ("  #%d  %s  +%s follower%s"):format(
					i, c.tier, tostring(c.gained or 0), c.viral and "  🔥VIRAL" or "")
				row.Parent = history
				if #recent >= 8 then break end
			end
		end
		if #recent == 0 then
			local l = Instance.new("TextLabel")
			l.Size = UDim2.new(1, -10, 0, 26)
			l.BackgroundTransparency = 1
			l.TextColor3 = Color3.fromRGB(120, 120, 130)
			l.TextScaled = true
			l.Text = "ยังไม่มีคลิปที่อัปแล้ว"
			l.Parent = history
		end

		-- กราฟ: 7 คลิปล่าสุด สเกลตามค่าสูงสุด
		local maxGain = 1
		for _, c in recent do maxGain = math.max(maxGain, c.gained or 0) end
		for i = 1, 7 do
			local c = recent[8 - i] -- ซ้าย = เก่ากว่า
			local h = c and (c.gained or 0) / maxGain or 0
			bars[i].Size = UDim2.new(1 / 7 - 0.03, 0, h * 0.9, 0)
		end

		-- comment แรกในคิว — ปุ่มตาม sentiment (server เป็นคนตัดสินความถูกต้องอยู่แล้ว)
		for _, ch in buttonArea:GetChildren() do
			ch:Destroy()
		end
		local pending = state.pendingComments[1]
		if pending and Comments[pending.id] then
			local c = Comments[pending.id]
			local mark = pending.sentiment == "pos" and "⊕" or pending.sentiment == "neg" and "⊖" or "◎"
			commentLabel.Text = ("💬 %s (%d รอตอบ) %s"):format(mark, #state.pendingComments, c.text)

			-- ช้อยตอบ (⊖/◎) — สุ่มลำดับกัน player กดบนตลอด (user 21 ก.ค.)
			local opts = {}
			if c.replies then
				for kind, text in c.replies do
					table.insert(opts, { text = text, response = kind })
				end
				for i = #opts, 2, -1 do
					local j = math.random(i)
					opts[i], opts[j] = opts[j], opts[i]
				end
			end
			local order = 0
			for _, o in opts do
				order += 1
				makeButton(o.text, o.response, order)
			end
			if pending.sentiment ~= "neu" then -- กดใจได้เฉพาะ ⊕/⊖
				order += 1
				makeButton("❤️ กดใจ", "heart", order, Color3.fromRGB(170, 60, 90))
			end
			order += 1
			makeButton("🙈 ปล่อยผ่าน", "skip", order, Color3.fromRGB(90, 90, 90))
		else
			commentLabel.Text = "ไม่มี comment ค้าง 🎉"
		end
	end
	return app
end

return Feedback
