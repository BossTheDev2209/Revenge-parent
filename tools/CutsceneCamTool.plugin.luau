-- CutsceneCamTool — Studio plugin ช่วยวาง/ส่อง/พรีวิว + แก้ attribute มุมกล้อง cutscene
-- ติดตั้ง: copy ไฟล์นี้ไป  %LOCALAPPDATA%\Roblox\Plugins\CutsceneCamTool.lua  แล้วเปิด Studio ใหม่
--          (แก้ไฟล์ใน repo แล้วต้อง copy ทับใหม่ทุกครั้ง — plugin ที่ติดตั้งเป็นสำเนา ไม่ auto-update)
--
-- Panel (ปุ่ม "Cam Panel"): ช่อง Cutscene (กลุ่มที่ Place ลง) + property ของ Part ที่เลือก
--   เลือก Part กล้อง → panel โชว์ Ease / TweenTime / FOV ของมัน · แก้ = เขียนลงทุก Part ที่เลือกพร้อมกัน
--   ไม่เลือกอะไร = ค่าในช่องเป็น "ค่าเริ่มต้นของ Part ที่จะ Place ถัดไป"
-- toolbar:
--   Place Cam — สร้าง Part กล้องตรงมุมมองตอนนี้ (ลงกลุ่มตามช่อง Cutscene) + ใส่ FOV/Ease/TweenTime
--   Aim Cam   — เอา Part ที่เลือกมาตั้งตามมุมมองตอนนี้ (แก้ช็อตเดิม)
--   Look Thru — ย้ายมุมมอง Studio ไปยืนที่ Part ที่เลือก = เห็นภาพจริงที่ player จะเห็น
--   Tour      — ไล่กล้องผ่าน Part ที่เลือกตามลำดับชื่อ ใช้ Ease/TweenTime จริง (กดซ้ำ = หยุด)

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "CutsceneCams"
local DEFAULT_FOV = 70
local DEFAULT_TWEEN = 1
local EASE_OPTIONS = { "InOut", "In", "Out", "Linear", "Cut" } -- ต้องตรงกับ CutscenePlayer.EASE + "Cut"

-- ค่าเริ่มต้นสำหรับ Part ที่จะ Place ถัดไป (จำข้ามครั้ง)
local placeCutscene = plugin:GetSetting("cutscene") or "Opening"
local placeEase = plugin:GetSetting("ease") or "InOut"
local placeTween = plugin:GetSetting("tween") or DEFAULT_TWEEN
local placeFov = DEFAULT_FOV

-- ===== helpers =====
local function camFolder(): Folder
	local f = workspace:FindFirstChild(FOLDER_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = workspace
	end
	return f
end

-- Model ต่อ cutscene — Persistent เพื่อ client เห็นเสมอ (กล้องมักไกล spawn โดน streaming cull)
local function groupModel(name: string): Model
	local folder = camFolder()
	local m = folder:FindFirstChild(name)
	if not m or not m:IsA("Model") then
		m = Instance.new("Model")
		m.Name = name
		m.Parent = folder
	end
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	return m
end

local function nextName(model: Instance, prefix: string): string
	local n = 1
	while model:FindFirstChild(("%s_%02d"):format(prefix, n)) do
		n += 1
	end
	return ("%s_%02d"):format(prefix, n)
end

local function sanitize(s: string): string
	s = (s or ""):gsub("%s+", ""):gsub("[^%w_]", "")
	return s ~= "" and s or "Cutscene"
end

local function selectedParts(): { BasePart }
	local out = {}
	for _, inst in Selection:Get() do
		if inst:IsA("BasePart") then
			table.insert(out, inst)
		end
	end
	return out
end

-- ค่าร่วมของ attribute ในกลุ่ม Part — คืน value ถ้าเท่ากันหมด, nil ถ้าต่างกัน (mixed)
local function commonAttr(parts, attr, default)
	local val, has = nil, false
	for _, p in parts do
		local v = p:GetAttribute(attr)
		if v == nil then v = default end
		if not has then
			val, has = v, true
		elseif v ~= val then
			return nil -- mixed
		end
	end
	return val
end

-- เขียน attribute ลงทุก Part ที่เลือก (undo ได้)
local function applyAttr(parts, attr, value)
	local rec = ChangeHistoryService:TryBeginRecording("Set cam " .. attr)
	for _, p in parts do
		p:SetAttribute(attr, value)
	end
	if rec then
		ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end
end

local function quadAlpha(a: number, ease: string): number
	if ease == "In" then
		return a * a
	elseif ease == "Out" then
		return 1 - (1 - a) * (1 - a)
	elseif ease == "InOut" then
		return if a < 0.5 then 2 * a * a else 1 - (-2 * a + 2) ^ 2 / 2
	end
	return a -- Linear/Cut/ไม่รู้จัก = linear
end

-- ===== toolbar =====
local toolbar = plugin:CreateToolbar("Cutscene Cams")
local panelBtn = toolbar:CreateButton("Cam Panel", "เปิด/ปิด panel property กล้อง", "rbxasset://textures/ui/GuiImagePlaceholder.png")
local placeBtn = toolbar:CreateButton("Place Cam", "สร้าง Part กล้องตรงมุมมองตอนนี้", "rbxasset://textures/ui/GuiImagePlaceholder.png")
local aimBtn = toolbar:CreateButton("Aim Cam", "ตั้ง Part ที่เลือก ให้ตรงมุมมองตอนนี้", "rbxasset://textures/ui/GuiImagePlaceholder.png")
local lookBtn = toolbar:CreateButton("Look Thru", "ส่องผ่าน Part ที่เลือก", "rbxasset://textures/ui/GuiImagePlaceholder.png")
local tourBtn = toolbar:CreateButton("Tour", "ไล่ดูทุก Part ที่เลือกตามลำดับชื่อ", "rbxasset://textures/ui/GuiImagePlaceholder.png")

-- ===== panel UI =====
local widget = plugin:CreateDockWidgetPluginGui(
	"CutsceneCamPanel",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 260, 300, 220, 260)
)
widget.Title = "Cutscene Cams"

local root = Instance.new("Frame")
root.Size = UDim2.new(1, 0, 1, 0)
root.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
root.BorderSizePixel = 0
root.Parent = widget
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = root
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = root

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function makeLabel(text: string, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 18)
	l.BackgroundTransparency = 1
	l.TextColor3 = color or Color3.fromRGB(220, 220, 220)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextScaled = true
	l.Text = text
	l.LayoutOrder = nextOrder()
	l.Parent = root
	return l
end

-- Cutscene name
makeLabel("Cutscene (กลุ่มที่ Place ลง)")
local box = Instance.new("TextBox")
box.Size = UDim2.new(1, 0, 0, 28)
box.PlaceholderText = "เช่น Opening"
box.Text = placeCutscene
box.ClearTextOnFocus = false
box.TextScaled = true
box.LayoutOrder = nextOrder()
box.Parent = root

-- สถานะ selection
local statusLabel = makeLabel("", Color3.fromRGB(150, 200, 150))

-- แถว property: label + control
local function makeRow(name: string)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 28)
	row.BackgroundTransparency = 1
	row.LayoutOrder = nextOrder()
	row.Parent = root
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.38, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextScaled = true
	lbl.Text = name
	lbl.Parent = row
	local function attachControl(c: GuiObject)
		c.Size = UDim2.new(0.62, 0, 1, 0)
		c.Position = UDim2.new(0.38, 0, 0, 0)
		c.Parent = row
	end
	return row, attachControl
end

-- Ease dropdown (ปุ่มโชว์ค่า + list options โผล่ใต้)
local _, attachEase = makeRow("Ease")
local easeBtn = Instance.new("TextButton")
easeBtn.TextScaled = true
easeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
easeBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
easeBtn.Text = placeEase
attachEase(easeBtn)

local dropdown = Instance.new("Frame")
dropdown.Size = UDim2.new(0, 120, 0, #EASE_OPTIONS * 24)
dropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
dropdown.BorderSizePixel = 1
dropdown.Visible = false
dropdown.ZIndex = 50
dropdown.Parent = widget
local ddLayout = Instance.new("UIListLayout")
ddLayout.Parent = dropdown

-- TweenTime + FOV (textbox ตัวเลข)
local _, attachTween = makeRow("TweenTime (วิ)")
local tweenBox = Instance.new("TextBox")
tweenBox.TextScaled = true
tweenBox.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
tweenBox.TextColor3 = Color3.fromRGB(240, 240, 240)
tweenBox.ClearTextOnFocus = false
tweenBox.Text = tostring(placeTween)
attachTween(tweenBox)

local _, attachFov = makeRow("FOV")
local fovBox = Instance.new("TextBox")
fovBox.TextScaled = true
fovBox.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
fovBox.TextColor3 = Color3.fromRGB(240, 240, 240)
fovBox.ClearTextOnFocus = false
fovBox.Text = tostring(placeFov)
attachFov(fovBox)

makeLabel("แก้ค่า = เขียนลงทุก Part ที่เลือก", Color3.fromRGB(150, 150, 150))

-- ===== sync UI <-> selection =====
local refreshing = false

-- โหลดค่าจาก Part ที่เลือกขึ้น UI (mixed = "—")
local function refreshFromSelection()
	refreshing = true
	local parts = selectedParts()
	if #parts == 0 then
		statusLabel.Text = "ไม่ได้เลือก Part (ค่านี้ = default ตอน Place)"
		easeBtn.Text = placeEase
		tweenBox.Text = tostring(placeTween)
		fovBox.Text = tostring(placeFov)
	else
		statusLabel.Text = ("เลือก %d Part"):format(#parts)
		local e = commonAttr(parts, "Ease", "InOut")
		local tw = commonAttr(parts, "TweenTime", DEFAULT_TWEEN)
		local fv = commonAttr(parts, "FOV", DEFAULT_FOV)
		easeBtn.Text = e or "—"
		tweenBox.Text = tw and tostring(tw) or "—"
		fovBox.Text = fv and tostring(fv) or "—"
	end
	refreshing = false
end

-- ตั้งค่า attr: เขียนลง Part ที่เลือก + จำเป็น default ตอน Place
local function setEase(v: string)
	placeEase = v
	plugin:SetSetting("ease", v)
	easeBtn.Text = v
	local parts = selectedParts()
	if #parts > 0 then applyAttr(parts, "Ease", v) end
end

-- dropdown options
for _, opt in EASE_OPTIONS do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 24)
	b.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	b.TextColor3 = Color3.fromRGB(240, 240, 240)
	b.TextScaled = true
	b.Text = opt
	b.ZIndex = 51
	b.Parent = dropdown
	b.Activated:Connect(function()
		dropdown.Visible = false
		setEase(opt)
	end)
end

easeBtn.Activated:Connect(function()
	if dropdown.Visible then
		dropdown.Visible = false
		return
	end
	-- วางใต้ปุ่ม Ease — แปลงเป็นพิกัดภายใน widget (ลบตำแหน่ง widget ออก)
	local rel = easeBtn.AbsolutePosition - widget.AbsolutePosition
	dropdown.Position = UDim2.fromOffset(rel.X, rel.Y + easeBtn.AbsoluteSize.Y)
	dropdown.Visible = true
end)

local function commitNumber(tb: TextBox, attr: string, default: number, setDefault: (number) -> ())
	if refreshing then return end
	local n = tonumber(tb.Text)
	if not n then
		refreshFromSelection() -- พิมพ์ไม่ใช่ตัวเลข = คืนค่าเดิม
		return
	end
	setDefault(n)
	local parts = selectedParts()
	if #parts > 0 then applyAttr(parts, attr, n) end
end

tweenBox.FocusLost:Connect(function()
	commitNumber(tweenBox, "TweenTime", DEFAULT_TWEEN, function(n)
		placeTween = n
		plugin:SetSetting("tween", n)
	end)
end)
fovBox.FocusLost:Connect(function()
	commitNumber(fovBox, "FOV", DEFAULT_FOV, function(n)
		placeFov = n
	end)
end)

box.FocusLost:Connect(function()
	placeCutscene = sanitize(box.Text)
	box.Text = placeCutscene
	plugin:SetSetting("cutscene", placeCutscene)
end)

Selection.SelectionChanged:Connect(refreshFromSelection)
panelBtn.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	if widget.Enabled then refreshFromSelection() end
end)
refreshFromSelection()

-- ===== Place / Aim / Look / Tour =====
-- Part หันหน้าทางไหน = ด้าน Front (-Z) ตรงกับ LookVector ของกล้องพอดี
placeBtn.Click:Connect(function()
	local cam = workspace.CurrentCamera
	local rec = ChangeHistoryService:TryBeginRecording("Place cutscene cam")
	local model = groupModel(placeCutscene)
	local p = Instance.new("Part")
	p.Name = nextName(model, placeCutscene)
	p.Size = Vector3.new(1, 1, 1)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.CFrame = cam.CFrame
	p:SetAttribute("FOV", placeFov)
	p:SetAttribute("Ease", placeEase)
	p:SetAttribute("TweenTime", placeTween)
	p.Parent = model
	Selection:Set({ p })
	if rec then
		ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end
	print(("[CamTool] วาง %s (Ease=%s %.1fs) ใน %s"):format(p.Name, placeEase, placeTween, model:GetFullName()))
end)

aimBtn.Click:Connect(function()
	local parts = selectedParts()
	if #parts == 0 then
		warn("[CamTool] เลือก Part กล้องก่อน")
		return
	end
	local cam = workspace.CurrentCamera
	local rec = ChangeHistoryService:TryBeginRecording("Aim cutscene cam")
	for _, p in parts do
		p.CFrame = cam.CFrame
		p:SetAttribute("FOV", cam.FieldOfView)
	end
	if rec then
		ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end
	refreshFromSelection()
end)

lookBtn.Click:Connect(function()
	local p = selectedParts()[1]
	if not p then
		warn("[CamTool] เลือก Part กล้องก่อน")
		return
	end
	local cam = workspace.CurrentCamera
	cam.CFrame = p.CFrame
	cam.FieldOfView = p:GetAttribute("FOV") or DEFAULT_FOV
end)

local touring = false
tourBtn.Click:Connect(function()
	if touring then
		touring = false
		return
	end
	local parts = selectedParts()
	if #parts < 2 then
		warn("[CamTool] เลือกอย่างน้อย 2 Part (Tour ไล่ตามลำดับชื่อ)")
		return
	end
	table.sort(parts, function(a, b)
		return a.Name < b.Name
	end)

	touring = true
	task.spawn(function()
		local cam = workspace.CurrentCamera
		for i = 1, #parts - 1 do
			local from, to = parts[i], parts[i + 1]
			local fromFov = from:GetAttribute("FOV") or DEFAULT_FOV
			local toFov = to:GetAttribute("FOV") or DEFAULT_FOV
			-- ช็อตปลายทางกำหนด easing/เวลา (เหมือน runtime moveCam ใช้ attribute ของ part ปลายทาง)
			local ease = to:GetAttribute("Ease") or "InOut"
			local dur = to:GetAttribute("TweenTime") or DEFAULT_TWEEN
			cam.CFrame, cam.FieldOfView = from.CFrame, fromFov
			print(("[CamTool] %s -> %s (Ease=%s %.1fs)"):format(from.Name, to.Name, ease, dur))
			if ease == "Cut" or dur <= 0 then
				cam.CFrame, cam.FieldOfView = to.CFrame, toFov
				local t = 0
				while t < 0.4 and touring do
					t += RunService.Heartbeat:Wait()
				end
			else
				local t = 0
				while t < dur and touring do
					t += RunService.Heartbeat:Wait()
					local a = quadAlpha(math.clamp(t / dur, 0, 1), ease)
					cam.CFrame = from.CFrame:Lerp(to.CFrame, a)
					cam.FieldOfView = fromFov + (toFov - fromFov) * a
				end
			end
			if not touring then
				return
			end
		end
		touring = false
		print("[CamTool] Tour จบ")
	end)
end)
