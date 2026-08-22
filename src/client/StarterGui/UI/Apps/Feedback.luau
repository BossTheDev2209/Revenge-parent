-- Feedback — ซ้าย: list คลิป + กราฟ follower 7 วัน · ขวา: comment + ปุ่มตอบ (ช่องเดียวที่นับ choice)
-- baked template อยู่ Gui_PC.Screen.AppTemplates.Feedback (แต่งใน Studio ได้)
-- ชื่อลูกที่โค้ดอ้าง ห้ามเปลี่ยน: History · Graph.Bar1-7 · CommentLabel · ButtonArea
local isStudio = script ~= nil
local Comments = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.Comments)
	else require("../../../../shared/Content/Comments")

local Feedback = {}

function Feedback.create(frame, deps)
	local guiPC = frame:FindFirstAncestorOfClass("ScreenGui")
	local template = guiPC and guiPC:FindFirstChild("Screen") and guiPC.Screen.AppTemplates:FindFirstChild("Feedback")
	if not template then
		warn("[Feedback] ไม่มี template Gui_PC.Screen.AppTemplates.Feedback — แต่งใน Studio ให้ครบก่อน")
		return {}
	end
	local content = template:Clone()
	content.Name = "FeedbackContent"
	content.Visible = true -- template ซ่อนไว้ (Visible=false) clone ต้องเปิดเอง
	content.Parent = frame

	local history = content:FindFirstChild("History")
	local graph = content:FindFirstChild("Graph")
	local bars = {}
	if graph then
		for i = 1, 7 do bars[i] = graph:FindFirstChild("Bar" .. i) end
	end
	local commentLabel = content:FindFirstChild("CommentLabel")
	local buttonArea = content:FindFirstChild("ButtonArea")

	-- แถวลิสต์คลิปใน History (ScrollingFrame + UIListLayout + AutomaticCanvasSize.Y)
	-- สูงเป็น scale ของ History เอง (เดิม 26px ตายตัว) — canvas โตเองตามจำนวนแถว ล้นแล้วเลื่อนได้
	local histSeq = 0
	local function historyRow()
		histSeq += 1
		local row = Instance.new("TextLabel")
		row.Name = ("%03d"):format(histSeq) -- เผื่อ SortOrder = Name เรียงถูก
		row.LayoutOrder = histSeq
		row.Size = UDim2.fromScale(0.97, 0.145)
		row.BackgroundTransparency = 1
		row.TextColor3 = Color3.fromRGB(40, 40, 50)
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Parent = history
		local cap = Instance.new("UITextSizeConstraint")
		cap.MinTextSize = 8
		cap.MaxTextSize = math.clamp(math.floor(content.AbsoluteSize.X * 0.024 + 0.5), 10, 18)
		cap.Parent = row
		return row
	end

	-- ★ 12 ส.ค. responsive (docs/05 §5.5 "ห้าม pixel ตายตัว")
	--   เดิมปุ่มสูง 40px ระยะ 46px ตายตัว → จอใหญ่ปุ่มจิ๋วเทียบกรอบ · ปุ่มเยอะก็ล้น ButtonArea
	--   ตอนนี้แบ่งความสูง ButtonArea ตามจำนวนปุ่มจริง (เว้นช่องไฟ 12%) — ล้นไม่ได้ไม่ว่ากี่ปุ่ม
	--   ต้องรู้จำนวนก่อนวาง เลยเก็บเป็น list แล้วค่อย render ทีเดียว (แพทเทิร์นเดียวกับ ChoiceBar ใน Message)
	local function renderButtons(specs)
		if not buttonArea then return end
		local n = #specs
		local slot = if n > 0 then 1 / n else 1
		for i, sp in specs do
			local b = Instance.new("TextButton")
			b.Name = ("%03d"):format(i)
			b.LayoutOrder = i
			b.Position = UDim2.fromScale(0, (i - 1) * slot)
			b.Size = UDim2.fromScale(1, slot * 0.88)
			b.BackgroundColor3 = sp.color or Color3.fromRGB(70, 70, 100)
			b.TextColor3 = Color3.new(1, 1, 1)
			b.TextScaled = true
			b.TextWrapped = true
			b.Text = sp.text
			b.Parent = buttonArea
			-- TextScaled ล้วนบนกล่องสูง = ตัวยืดเต็ม คุมเพดานไว้ (อิงความกว้างกรอบแอปจริง)
			local cap = Instance.new("UITextSizeConstraint")
			cap.MinTextSize = 8
			cap.MaxTextSize = math.clamp(math.floor(content.AbsoluteSize.X * 0.026 + 0.5), 11, 20)
			cap.Parent = b
			b.Activated:Connect(function()
				deps.fireAction({ type = "AnswerComment", response = sp.response })
			end)
		end
	end

	local app = {}
	function app.refresh(state)
		-- list คลิปที่อัปแล้ว (ใหม่สุดบน)
		if history then
			for _, ch in history:GetChildren() do
				if ch:IsA("TextLabel") then ch:Destroy() end
			end
		end
		histSeq = 0 -- ล้างพร้อมแถว ไม่งั้นเลขชื่อไต่ขึ้นเรื่อยๆ ข้าม refresh
		local recent = {}
		for i = #state.clips, 1, -1 do
			local c = state.clips[i]
			if c.uploaded then
				table.insert(recent, c)
				if history then
					local row = historyRow()
					row.Text = ("  #%d  %s  +%s follower%s"):format(
						i, c.tier, tostring(c.gained or 0), c.viral and "  🔥VIRAL" or "")
				end
				if #recent >= 8 then break end
			end
		end
		if #recent == 0 and history then
			local l = historyRow()
			l.TextColor3 = Color3.fromRGB(120, 120, 130)
			l.Text = "ยังไม่มีคลิปที่อัปแล้ว"
		end

		-- กราฟ: 7 คลิปล่าสุด สเกลตามค่าสูงสุด (แท่งคงที่ 7 อันจาก template ปรับความสูง)
		local maxGain = 1
		for _, c in recent do maxGain = math.max(maxGain, c.gained or 0) end
		for i = 1, 7 do
			local c = recent[8 - i] -- ซ้าย = เก่ากว่า
			local h = c and (c.gained or 0) / maxGain or 0
			if bars[i] then bars[i].Size = UDim2.new(1 / 7 - 0.03, 0, h * 0.9, 0) end
		end

		-- comment แรกในคิว — ปุ่มตาม sentiment (server เป็นคนตัดสินความถูกต้องอยู่แล้ว) — ยาวไม่แน่นอน
		-- ล้างเฉพาะ GuiObject — UICorner/UIStroke/UIPadding ที่ทีมแต่งไว้บน ButtonArea ต้องรอด
		-- (เดิม Destroy ลูกทุกตัว = ของแต่งหายตั้งแต่ refresh รอบแรก)
		if buttonArea then
			for _, ch in buttonArea:GetChildren() do
				if ch:IsA("GuiObject") then ch:Destroy() end
			end
		end
		local pending = state.pendingComments[1]
		if pending and Comments[pending.id] then
			local c = Comments[pending.id]
			local mark = pending.sentiment == "pos" and "⊕" or pending.sentiment == "neg" and "⊖" or "◎"
			if commentLabel then
				commentLabel.Text = ("💬 %s (%d รอตอบ) %s"):format(mark, #state.pendingComments, c.text)
			end

			-- ช้อยตอบ — สุ่มลำดับกัน player กดบนตลอด
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
			-- รวมปุ่มทั้งหมดก่อน แล้วค่อย render — renderButtons ต้องรู้จำนวนถึงแบ่งความสูงได้
			local specs = {}
			for _, o in opts do
				table.insert(specs, { text = o.text, response = o.response })
			end
			if pending.sentiment ~= "neu" then -- กดใจได้เฉพาะ ⊕/⊖
				table.insert(specs, { text = "❤️ กดใจ", response = "heart", color = Color3.fromRGB(170, 60, 90) })
			end
			table.insert(specs, { text = "🙈 ปล่อยผ่าน", response = "skip", color = Color3.fromRGB(90, 90, 90) })
			renderButtons(specs)
		elseif commentLabel then
			commentLabel.Text = "ไม่มี comment ค้าง 🎉"
		end
	end
	return app
end

return Feedback
