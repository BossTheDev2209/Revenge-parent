-- Feedback.luau — **layout ตาม PDF หน้า 8** (ไม่มีภาพร่างแยกในโฟลเดอร์ ui screenshot)
--   ซ้าย : Latest upload (list คลิป + views) + กราฟ follower 7 วัน (★ แท่งเปล่ารอ history จริง)
--   ขวา  : Comment from [คลิป] + ปุ่มตอบ (ช่องเดียวที่นับ choice — design doc §6)
-- ย้ายการตอบ comment จาก floating CommentUI เข้ามาที่นี่ตาม PDF หน้า 5
--
-- ★ baked เป็น instance จริงแล้ว (9 ส.ค.) — โครงคงที่ (หัวข้อ/กราฟ 7 แท่ง/กรอบ) bake เป็น template
--   ส่วนที่ยาวไม่แน่นอนจริง (list คลิป/ปุ่มตอบ comment) ยังสร้างจาก data ตอน refresh เหมือนเดิม
--   template จริงอยู่ Gui_PC.Screen.AppTemplates.Feedback (แต่งใน Studio ได้)
--   ชื่อลูกที่โค้ดอ้าง ห้ามเปลี่ยน: History (ScrollingFrame ว่าง) · Graph.Bar1-7 · CommentLabel · ButtonArea (ว่าง)
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
	content.Parent = frame

	local history = content:FindFirstChild("History")
	local graph = content:FindFirstChild("Graph")
	local bars = {}
	if graph then
		for i = 1, 7 do bars[i] = graph:FindFirstChild("Bar" .. i) end
	end
	local commentLabel = content:FindFirstChild("CommentLabel")
	local buttonArea = content:FindFirstChild("ButtonArea")

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
		-- list คลิปที่อัปแล้ว (ใหม่สุดบน) — ยาวไม่แน่นอน ยังสร้างจาก data
		if history then
			for _, ch in history:GetChildren() do
				if ch:IsA("TextLabel") then ch:Destroy() end
			end
		end
		local recent = {}
		for i = #state.clips, 1, -1 do
			local c = state.clips[i]
			if c.uploaded then
				table.insert(recent, c)
				if history then
					local row = Instance.new("TextLabel")
					row.Size = UDim2.new(1, -10, 0, 26)
					row.BackgroundTransparency = 1
					row.TextColor3 = Color3.fromRGB(40, 40, 50)
					row.TextScaled = true
					row.TextXAlignment = Enum.TextXAlignment.Left
					row.Text = ("  #%d  %s  +%s follower%s"):format(
						i, c.tier, tostring(c.gained or 0), c.viral and "  🔥VIRAL" or "")
					row.Parent = history
				end
				if #recent >= 8 then break end
			end
		end
		if #recent == 0 and history then
			local l = Instance.new("TextLabel")
			l.Size = UDim2.new(1, -10, 0, 26)
			l.BackgroundTransparency = 1
			l.TextColor3 = Color3.fromRGB(120, 120, 130)
			l.TextScaled = true
			l.Text = "ยังไม่มีคลิปที่อัปแล้ว"
			l.Parent = history
		end

		-- กราฟ: 7 คลิปล่าสุด สเกลตามค่าสูงสุด (แท่งคงที่ 7 อันจาก template แค่ปรับความสูง)
		local maxGain = 1
		for _, c in recent do maxGain = math.max(maxGain, c.gained or 0) end
		for i = 1, 7 do
			local c = recent[8 - i] -- ซ้าย = เก่ากว่า
			local h = c and (c.gained or 0) / maxGain or 0
			if bars[i] then bars[i].Size = UDim2.new(1 / 7 - 0.03, 0, h * 0.9, 0) end
		end

		-- comment แรกในคิว — ปุ่มตาม sentiment (server เป็นคนตัดสินความถูกต้องอยู่แล้ว) — ยาวไม่แน่นอน
		if buttonArea then
			for _, ch in buttonArea:GetChildren() do ch:Destroy() end
		end
		local pending = state.pendingComments[1]
		if pending and Comments[pending.id] then
			local c = Comments[pending.id]
			local mark = pending.sentiment == "pos" and "⊕" or pending.sentiment == "neg" and "⊖" or "◎"
			if commentLabel then
				commentLabel.Text = ("💬 %s (%d รอตอบ) %s"):format(mark, #state.pendingComments, c.text)
			end

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
		elseif commentLabel then
			commentLabel.Text = "ไม่มี comment ค้าง 🎉"
		end
	end
	return app
end

return Feedback
