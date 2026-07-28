-- Upload.luau — **layout ตามภาพร่าง `ui screenshot/PC-Upload ui.png`** (PDF หน้า 8)
--   ซ้าย  : คอลัมน์ "Storage" = คลิปที่ตัดแล้วยังไม่อัป (thumbnail) · กรอบแดง = ที่เลือกอยู่
--   กลาง  : กรอบ preview ใหญ่ (★ เว้นว่างรอรูปปกคลิป `clip_cover_*` — docs/13 §4)
--   ล่าง  : title 3 ช้อย | description 3 ช้อย (กรอบแดง = ที่เลือก) + ปุ่ม upload! มุมขวาล่าง
-- ⚠️ title/description **ยังไม่มีผลต่อเกม** + ยังไม่มีไฟล์ `Content.ClipTitles` (สาย B — docs/14 §2)
--    ตอนนี้โชว์ช้อยเปล่า "1. / 2. / 3." ไว้ให้เห็นโครง กดเลือกได้ กรอบแดงขยับตาม
local Upload = {}

local RED = Color3.fromRGB(230, 50, 50)
local BLUE = Color3.fromRGB(60, 80, 200)

local function stroke(inst, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(40, 40, 50)
	s.Thickness = thick or 1
	s.Parent = inst
	return s
end

function Upload.create(frame, deps)
	frame.BackgroundColor3 = Color3.fromRGB(240, 242, 246)

	-- ---------- ซ้าย: Storage ----------
	local storageHead = Instance.new("TextLabel")
	storageHead.Position = UDim2.new(0, 6, 0, 6)
	storageHead.Size = UDim2.new(0.2, -8, 0, 28)
	storageHead.BackgroundColor3 = Color3.new(1, 1, 1)
	storageHead.TextColor3 = BLUE
	storageHead.TextScaled = true
	storageHead.Text = "Storage"
	storageHead.Parent = frame
	stroke(storageHead, BLUE, 2)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 6, 0, 36)
	list.Size = UDim2.new(0.2, -8, 1, -44)
	list.BackgroundColor3 = Color3.new(1, 1, 1)
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = frame
	stroke(list, BLUE, 2)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.Parent = list

	-- ---------- กลาง: preview ----------
	local preview = Instance.new("Frame")
	preview.Name = "ArtSlot_Preview"
	preview.Position = UDim2.new(0.21, 6, 0, 6)
	preview.Size = UDim2.new(0.79, -14, 0.56, 0)
	preview.BackgroundColor3 = Color3.fromRGB(225, 228, 234)
	preview.Parent = frame
	stroke(preview)
	local previewText = Instance.new("TextLabel")
	previewText.Size = UDim2.new(1, 0, 1, 0)
	previewText.BackgroundTransparency = 1
	previewText.TextColor3 = Color3.fromRGB(120, 120, 130)
	previewText.TextScaled = true
	previewText.TextWrapped = true
	previewText.Text = "Select video to upload first!"
	previewText.Parent = preview

	-- ---------- ล่าง: title / description ----------
	local pickedTitle, pickedDesc = 1, 1
	local function optionColumn(xScale, wScale, caption, count)
		local cap = Instance.new("TextLabel")
		cap.Position = UDim2.new(xScale, 0, 0.6, 0)
		cap.Size = UDim2.new(wScale, 0, 0, 20)
		cap.BackgroundTransparency = 1
		cap.TextColor3 = Color3.fromRGB(40, 40, 50)
		cap.TextScaled = true
		cap.TextXAlignment = Enum.TextXAlignment.Left
		cap.Text = caption
		cap.Parent = frame

		local btns = {}
		for i = 1, count do
			local b = Instance.new("TextButton")
			b.Position = UDim2.new(xScale, 0, 0.66 + (i - 1) * 0.11, 0)
			b.Size = UDim2.new(wScale, 0, 0.1, 0)
			b.BackgroundColor3 = Color3.new(1, 1, 1)
			b.TextColor3 = Color3.fromRGB(40, 40, 50)
			b.TextScaled = true
			b.TextWrapped = true
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.Text = ("%d."):format(i)
			b.Parent = frame
			stroke(b)
			btns[i] = b
		end
		return btns
	end
	local titleBtns = optionColumn(0.21, 0.3, "title", 3)
	local descBtns = optionColumn(0.54, 0.3, "description", 3)

	local function paint()
		for i, b in titleBtns do
			b:FindFirstChildOfClass("UIStroke").Color = i == pickedTitle and RED or Color3.fromRGB(40, 40, 50)
			b:FindFirstChildOfClass("UIStroke").Thickness = i == pickedTitle and 3 or 1
		end
		for i, b in descBtns do
			b:FindFirstChildOfClass("UIStroke").Color = i == pickedDesc and RED or Color3.fromRGB(40, 40, 50)
			b:FindFirstChildOfClass("UIStroke").Thickness = i == pickedDesc and 3 or 1
		end
	end
	for i, b in titleBtns do
		b.Activated:Connect(function() pickedTitle = i; paint() end)
	end
	for i, b in descBtns do
		b.Activated:Connect(function() pickedDesc = i; paint() end)
	end

	-- ---------- ปุ่ม upload ----------
	local uploadBtn = Instance.new("TextButton")
	uploadBtn.Position = UDim2.new(0.86, 0, 0.84, 0)
	uploadBtn.Size = UDim2.new(0.13, 0, 0.12, 0)
	uploadBtn.BackgroundColor3 = Color3.new(1, 1, 1)
	uploadBtn.TextColor3 = Color3.fromRGB(40, 40, 50)
	uploadBtn.TextScaled = true
	uploadBtn.Text = "⬆️ upload!"
	uploadBtn.Parent = frame
	stroke(uploadBtn, nil, 2)

	local selectedClip = nil
	local function selectClip(index, thumb)
		selectedClip = index
		for _, ch in list:GetChildren() do
			if ch:IsA("TextButton") then
				ch:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(40, 40, 50)
				ch:FindFirstChildOfClass("UIStroke").Thickness = 1
			end
		end
		if thumb then
			thumb:FindFirstChildOfClass("UIStroke").Color = RED
			thumb:FindFirstChildOfClass("UIStroke").Thickness = 3
		end
	end

	uploadBtn.Activated:Connect(function()
		if not selectedClip then
			previewText.Text = "Select video to upload first!"
			return
		end
		deps.fireAction({ type = "UploadClip", clip = selectedClip })
		selectedClip = nil
	end)

	local app = {}
	function app.refresh(state)
		for _, ch in list:GetChildren() do
			if ch:IsA("TextButton") then ch:Destroy() end
		end
		for i = 1, 3 do -- รอ Content.ClipTitles จากสาย B แล้วค่อยเติมข้อความจริง
			titleBtns[i].Text = ("%d. …"):format(i)
			descBtns[i].Text = ("%d. …"):format(i)
		end
		paint()

		local any = false
		for i, clip in state.clips do
			if not clip.uploaded then
				any = true
				local thumb = Instance.new("TextButton")
				thumb.Size = UDim2.new(1, -18, 0, 62)
				thumb.BackgroundColor3 = Color3.fromRGB(232, 234, 240)
				thumb.TextColor3 = Color3.fromRGB(60, 60, 70)
				thumb.TextScaled = true
				thumb.Text = ("▶ #%d  %s"):format(i, clip.tier)
				thumb.Parent = list
				stroke(thumb)
				thumb.Activated:Connect(function()
					selectClip(i, thumb)
					previewText.Text = ("คลิป #%d — tier %s (%d/200)"):format(i, clip.tier, clip.score)
				end)
			end
		end
		if not any then
			previewText.Text = "ไม่มีคลิปค้าง — ไปตัดคลิปก่อน (แอป ✂️)"
			selectedClip = nil
		end
	end
	return app
end

return Upload
