-- Upload.luau — แอปอัปคลิป: list คลิปที่ตัดแล้วยังไม่อัป → กดอัป (PDF หน้า 8)
local Upload = {}

function Upload.create(frame, deps)
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Text = "⬆️ อัปโหลดคลิป"
	title.Parent = frame

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 8, 0, 40)
	list.Size = UDim2.new(1, -16, 1, -48)
	list.BackgroundTransparency = 1
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	local app = {}
	function app.refresh(state)
		for _, c in list:GetChildren() do
			if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
		end
		local any = false
		for i, clip in state.clips do
			if not clip.uploaded then
				any = true
				local b = Instance.new("TextButton")
				b.Size = UDim2.new(1, -8, 0, 44)
				b.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
				b.TextColor3 = Color3.new(1, 1, 1)
				b.TextScaled = true
				b.Text = ("คลิป #%d | tier %s (%d/200) — กดเพื่ออัป"):format(i, clip.tier, clip.score)
				b.Parent = list
				b.Activated:Connect(function()
					deps.fireAction({ type = "UploadClip", clip = i })
				end)
			end
		end
		if not any then
			local l = Instance.new("TextLabel")
			l.Size = UDim2.new(1, -8, 0, 44)
			l.BackgroundTransparency = 1
			l.TextScaled = true
			l.Text = "ไม่มีคลิปค้าง — ไปตัดคลิปก่อน (แอป ✂️)"
			l.Parent = list
		end
	end
	return app
end

return Upload
