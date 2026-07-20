-- Feedback.luau — ผลงานคลิปล่าสุด + ตอบ comment (ช่องเดียวที่นับ choice — design doc §6)
-- ย้ายการตอบ comment จาก floating CommentUI เข้ามาที่นี่ตาม PDF หน้า 5
local isStudio = script ~= nil
local Comments = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.Comments)
	else require("../../../shared/Content/Comments")

local Feedback = {}

function Feedback.create(frame, deps)
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Text = "📊 Feedback"
	title.Parent = frame

	local history = Instance.new("TextLabel")
	history.Position = UDim2.new(0, 8, 0, 40)
	history.Size = UDim2.new(1, -16, 0, 130)
	history.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	history.TextScaled = true
	history.TextWrapped = true
	history.TextXAlignment = Enum.TextXAlignment.Left
	history.Text = ""
	history.Parent = frame

	local commentLabel = Instance.new("TextLabel")
	commentLabel.Position = UDim2.new(0, 8, 0, 180)
	commentLabel.Size = UDim2.new(1, -16, 0, 56)
	commentLabel.BackgroundColor3 = Color3.fromRGB(255, 250, 210)
	commentLabel.TextScaled = true
	commentLabel.TextWrapped = true
	commentLabel.Text = ""
	commentLabel.Parent = frame

	local buttonArea = Instance.new("Frame")
	buttonArea.Position = UDim2.new(0, 8, 0, 240)
	buttonArea.Size = UDim2.new(1, -16, 0, 236) -- สูงสุด 5 ปุ่ม (⊖: ช้อย 3 + ใจ + ปล่อยผ่าน)
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
		-- ผลงาน 5 คลิปล่าสุดที่อัปแล้ว
		local lines = {}
		for i = #state.clips, 1, -1 do
			local c = state.clips[i]
			if c.uploaded then
				table.insert(lines, ("#%d %s +%s follower%s"):format(
					i, c.tier, tostring(c.gained or 0), c.viral and " 🔥VIRAL" or ""))
				if #lines >= 5 then break end
			end
		end
		history.Text = #lines > 0 and table.concat(lines, "\n") or "ยังไม่มีคลิปที่อัปแล้ว"

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
