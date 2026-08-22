-- Upload.luau — **layout ตามภาพร่าง `ui screenshot/PC-Upload ui.png`** (PDF หน้า 8)
--   ซ้าย  : คอลัมน์ "Storage" = คลิปที่ตัดแล้วยังไม่อัป (thumbnail) · กรอบแดง = ที่เลือกอยู่
--   กลาง  : กรอบ preview ใหญ่ (★ เว้นว่างรอรูปปกคลิป `clip_cover_*` — docs/13 §4)
--   ล่าง  : title 3 ช้อย | description 3 ช้อย (กรอบแดง = ที่เลือก) + ปุ่ม upload! มุมขวาล่าง
-- ★ 12 ส.ค. (user) — เติมช้อยจริงจาก Content.ClipTitles (docs/14 §2 resolved: มีให้เลือกแล้ว)
--   สุ่ม 3 title + 3 desc ไม่ซ้ำกันตอนเปิดแอป (Upload.create) นิ่งตลอดที่แอปเปิดอยู่ ไม่สุ่มใหม่ทุก refresh (กันกระพริบ)
--   ⚠️ ยังเป็น flavor text ล้วน เลือกช้อยไหนไม่มีผลต่อเกม (docs/14 §2 เดิม — ยังไม่ได้ล็อกว่าจะมีผลอะไร)
--
-- ★ baked เป็น instance จริงแล้ว (9 ส.ค.) — โครงคงที่ทั้งหมด bake เป็น template รวมปุ่ม title/desc
--   ทั้ง 6 ปุ่ม (จำนวนคงที่ 3+3 เสมอ ไม่เคยเปลี่ยน) — เหลือแค่ List (คลิปค้างอัป) ที่ยาวไม่แน่นอนจริง
--   template จริงอยู่ Gui_PC.Screen.AppTemplates.Upload (แต่งใน Studio ได้)
--   ชื่อลูกที่โค้ดอ้าง ห้ามเปลี่ยน: List (ว่าง) · Preview.PreviewText · Title/DescBtn1-3 · UploadBtn
local isStudio = script ~= nil
local ClipTitles = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.ClipTitles)
	else require("../../../../shared/Content/ClipTitles")
local UIAssets = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.UIAssets)
	else require("../../../../shared/UIAssets")

-- สุ่ม n รายการไม่ซ้ำจาก pool (pool สั้นกว่า n = คืนเท่าที่มี ไม่ crash)
local function pickRandom(pool, n)
	local idx = {}
	for i = 1, #pool do idx[i] = i end
	for i = #idx, 2, -1 do
		local j = math.random(i)
		idx[i], idx[j] = idx[j], idx[i]
	end
	local picked = {}
	for i = 1, math.min(n, #idx) do picked[i] = pool[idx[i]] end
	return picked
end
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
	content.Visible = true -- template ซ่อนไว้ clone ต้องเปิดเอง
	content.Parent = frame

	local list = content:FindFirstChild("List")
	local preview = content:FindFirstChild("Preview")
	local previewText = preview and preview:FindFirstChild("PreviewText")

	-- ★ 12 ส.ค. (user) — โชว์ปกคลิปจริง (UIAssets.clip_cover_1..6) ในกรอบ preview
	--   ก่อนหน้านี้กรอบนี้มีแค่ PreviewText เฉยๆ ไม่เคยสร้าง ImageLabel เลย (เว้นว่างรอตลอด)
	--   คลิปแต่ละอันไม่มีคีย์ cover ผูกไว้ (ไม่ใช่ balance data) เลยเลือกแบบ deterministic ตาม index
	--   ในลิสต์ (clip 1→cover_1, clip 2→cover_2, ... วน 6) ให้แต่ละคลิปคงที่ ไม่สุ่มใหม่ทุก refresh
	local coverImage, coverOverlay
	if preview then
		coverImage = Instance.new("ImageLabel")
		coverImage.Name = "CoverImage"
		coverImage.Size = UDim2.fromScale(1, 1)
		coverImage.BackgroundTransparency = 1
		coverImage.ScaleType = Enum.ScaleType.Crop
		coverImage.ZIndex = 0
		coverImage.Visible = false
		coverImage.Parent = preview

		coverOverlay = Instance.new("Frame") -- มืดคลุมครึ่งนึงกัน PreviewText อ่านไม่ออกบนรูปสว่าง
		coverOverlay.Name = "CoverOverlay"
		coverOverlay.Size = UDim2.fromScale(1, 1)
		coverOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
		coverOverlay.BackgroundTransparency = 0.55
		coverOverlay.BorderSizePixel = 0
		coverOverlay.ZIndex = 1
		coverOverlay.Visible = false
		coverOverlay.Parent = preview

		if previewText then previewText.ZIndex = 2 end
	end

	local function showCover(clipIndex)
		if not coverImage then return end
		local key = "clip_cover_" .. (((clipIndex - 1) % 6) + 1)
		local img = UIAssets[key]
		if img and img ~= "" then
			coverImage.Image = img
			coverImage.Visible = true
			coverOverlay.Visible = true
		else
			coverImage.Visible = false
			coverOverlay.Visible = false
		end
	end

	local titleBtns, descBtns = {}, {}
	for i = 1, 3 do
		titleBtns[i] = content:FindFirstChild("TitleBtn" .. i)
		descBtns[i] = content:FindFirstChild("DescBtn" .. i)
	end

	-- สุ่มครั้งเดียวตอนเปิดแอป (ไม่สุ่มใหม่ทุก state refresh — กันช้อยเปลี่ยนขณะผู้เล่นกำลังเลือก)
	local pickedTitles = pickRandom(ClipTitles.titles, 3)
	local pickedDescs = pickRandom(ClipTitles.descriptions, 3)
	for i, b in titleBtns do
		if b and pickedTitles[i] then b.Text = pickedTitles[i] end
	end
	for i, b in descBtns do
		if b and pickedDescs[i] then b.Text = pickedDescs[i] end
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
		paint()

		local any = false
		for i, clip in state.clips do
			if not clip.uploaded then
				any = true
				if list then
					-- ★ 12 ส.ค. responsive (docs/05 §5.5): เดิมสูง 62px + กว้าง -18px ตายตัว
					--   → scale ล้วนของ List (ScrollingFrame + UIListLayout + AutoCanvas โตเอง เลื่อนได้)
					local thumb = Instance.new("TextButton")
					thumb.Name = ("%03d"):format(i) -- เผื่อ SortOrder = Name เรียงถูก
					thumb.LayoutOrder = i
					thumb.Size = UDim2.fromScale(0.94, 0.135)
					thumb.BackgroundColor3 = Color3.fromRGB(232, 234, 240)
					thumb.TextColor3 = Color3.fromRGB(60, 60, 70)
					thumb.TextScaled = true
					thumb.Text = ("▶ #%d  %s"):format(i, clip.tier)
					thumb.Parent = list
					stroke(thumb)
					-- TextScaled บนกล่อง scale = ตัวยืดเต็ม คุมเพดานอิงความกว้างกรอบแอปจริง
					local cap = Instance.new("UITextSizeConstraint")
					cap.MinTextSize = 8
					cap.MaxTextSize = math.clamp(math.floor(content.AbsoluteSize.X * 0.024 + 0.5), 10, 18)
					cap.Parent = thumb
					thumb.Activated:Connect(function()
						selectClip(i, thumb)
						showCover(i)
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
			if coverImage then coverImage.Visible = false end
			if coverOverlay then coverOverlay.Visible = false end
		end
	end
	return app
end

return Upload
