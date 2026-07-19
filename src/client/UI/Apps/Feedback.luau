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

	local buttons = {}
	for i = 1, 3 do
		local b = Instance.new("TextButton")
		b.Position = UDim2.new(0, 8, 0, 240 + (i - 1) * 46)
		b.Size = UDim2.new(1, -16, 0, 40)
		b.BackgroundColor3 = Color3.fromRGB(70, 70, 100)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextScaled = true
		b.TextWrapped = true
		b.Visible = false
		b.Parent = frame
		b.Activated:Connect(function()
			deps.fireAction({ type = "AnswerComment", reply = i })
		end)
		buttons[i] = b
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

		-- comment แรกในคิว
		local pending = state.pendingComments[1]
		if pending and Comments[pending.id] then
			local c = Comments[pending.id]
			commentLabel.Text = ("💬 (%d รอตอบ) %s"):format(#state.pendingComments, c.text)
			for i = 1, 3 do
				buttons[i].Visible = true
				buttons[i].Text = c.replies[i].text
			end
		else
			commentLabel.Text = "ไม่มี comment ค้าง 🎉"
			for i = 1, 3 do buttons[i].Visible = false end
		end
	end
	return app
end

return Feedback
