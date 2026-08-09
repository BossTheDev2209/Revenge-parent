-- Upload.luau — **layout ตามภาพร่าง `ui screenshot/PC-Upload ui.png`** (PDF หน้า 8)
--   ซ้าย  : คอลัมน์ "Storage" = คลิปที่ตัดแล้วยังไม่อัป (thumbnail) · กรอบแดง = ที่เลือกอยู่
--   กลาง  : กรอบ preview ใหญ่ (★ เว้นว่างรอรูปปกคลิป `clip_cover_*` — docs/13 §4)
--   ล่าง  : title 3 ช้อย | description 3 ช้อย (กรอบแดง = ที่เลือก) + ปุ่ม upload! มุมขวาล่าง
-- ⚠️ title/description **ยังไม่มีผลต่อเกม** + ยังไม่มีไฟล์ `Content.ClipTitles` (สาย B — docs/14 §2)
--    ตอนนี้โชว์ช้อยเปล่า "1. / 2. / 3." ไว้ให้เห็นโครง กดเลือกได้ กรอบแดงขยับตาม
--
-- ★ baked เป็น instance จริงแล้ว (9 ส.ค.) — โครงคงที่ทั้งหมด bake เป็น template รวมปุ่ม title/desc
--   ทั้ง 6 ปุ่ม (จำนวนคงที่ 3+3 เสมอ ไม่เคยเปลี่ยน) — เหลือแค่ List (คลิปค้างอัป) ที่ยาวไม่แน่นอนจริง
--   template จริงอยู่ Gui_PC.Screen.AppTemplates.Upload (แต่งใน Studio ได้)
--   ชื่อลูกที่โค้ดอ้าง ห้ามเปลี่ยน: List (ว่าง) · Preview.PreviewText · Title/DescBtn1-3 · UploadBtn
local Upload = {}

local RED = Color3.fromRGB(230, 50, 50)

local function stroke(inst, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(40, 40, 50)
	s.Thickness = thick or 1
	s.Parent = inst
	return s
end

function Upload.create(frame, deps)
	local guiPC = frame:FindFirstAncestorOfClass("ScreenGui")
	local template = guiPC and guiPC:FindFirstChild("Screen") and guiPC.Screen.AppTemplates:FindFirstChild("Upload")
	if not template then
		warn("[Upload] ไม่มี template Gui_PC.Screen.AppTemplates.Upload — แต่งใน Studio ให้ครบก่อน")
		return {}
	end
	local content = template:Clone()
	content.Name = "UploadContent"
	content.Parent = frame

	local list = content:FindFirstChild("List")
	local preview = content:FindFirstChild("Preview")
	local previewText = preview and preview:FindFirstChild("PreviewText")

	local titleBtns, descBtns = {}, {}
	for i = 1, 3 do
		titleBtns[i] = content:FindFirstChild("TitleBtn" .. i)
		descBtns[i] = content:FindFirstChild("DescBtn" .. i)
	end

	local pickedTitle, pickedDesc = 1, 1
	local function paint()
		for i, b in titleBtns do
			if b then
				b:FindFirstChildOfClass("UIStroke").Color = i == pickedTitle and RED or Color3.fromRGB(40, 40, 50)
				b:FindFirstChildOfClass("UIStroke").Thickness = i == pickedTitle and 3 or 1
			end
		end
		for i, b in descBtns do
			if b then
				b:FindFirstChildOfClass("UIStroke").Color = i == pickedDesc and RED or Color3.fromRGB(40, 40, 50)
				b:FindFirstChildOfClass("UIStroke").Thickness = i == pickedDesc and 3 or 1
			end
		end
	end
	for i, b in titleBtns do
		if b then b.Activated:Connect(function() pickedTitle = i; paint() end) end
	end
	for i, b in descBtns do
		if b then b.Activated:Connect(function() pickedDesc = i; paint() end) end
	end

	local uploadBtn = content:FindFirstChild("UploadBtn")

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

	if uploadBtn then
		uploadBtn.Activated:Connect(function()
			if not selectedClip then
				if previewText then previewText.Text = "Select video to upload first!" end
				return
			end
			deps.fireAction({ type = "UploadClip", clip = selectedClip })
			selectedClip = nil
		end)
	end

	local app = {}
	function app.refresh(state)
		if list then
			for _, ch in list:GetChildren() do
				if ch:IsA("TextButton") then ch:Destroy() end
			end
		end
		for i = 1, 3 do -- รอ Content.ClipTitles จากสาย B แล้วค่อยเติมข้อความจริง
			if titleBtns[i] then titleBtns[i].Text = ("%d. …"):format(i) end
			if descBtns[i] then descBtns[i].Text = ("%d. …"):format(i) end
		end
		paint()

		local any = false
		for i, clip in state.clips do
			if not clip.uploaded then
				any = true
				if list then
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
						if previewText then
							previewText.Text = ("คลิป #%d — tier %s (%d/200)"):format(i, clip.tier, clip.score)
						end
					end)
				end
			end
		end
		if not any then
			if previewText then previewText.Text = "ไม่มีคลิปค้าง — ไปตัดคลิปก่อน (แอป ✂️)" end
			selectedClip = nil
		end
	end
	return app
end

return Upload
