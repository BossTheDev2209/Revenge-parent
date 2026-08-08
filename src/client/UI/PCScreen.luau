-- PCScreen.luau — Universal PC UI แปะบนจอจริงในโลก (SurfaceGui) — PDF หน้า 5 "UI PC"
-- ใช้ได้กับเครื่องทุกตัว: convention = model มี part ชื่อ `Interact_pcMonitor` **ขนาดจอ 4 × 2.6 studs**
--   กด E → กล้อง zoom เข้าจอ → UI ขึ้นบนหน้า part จริง → ปุ่ม RETURN (ScreenGui) ออก
--
-- ★ CANVAS = 1000 × 650 px  (4 studs × PIXELS_PER_STUD 250 | 2.6 × 250)
--   ทุกตำแหน่งในไฟล์นี้อิงสัดส่วน (Scale) เป็นหลัก — เปลี่ยนขนาด part แล้วยัง layout ถูก
-- รูปทั้งหมดอ่านจาก ReplicatedStorage.Shared.UIAssets — ว่าง = fallback ตัวหนังสือ (docs/13)
local isStudio = script ~= nil
local UIAssets = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.UIAssets)
	else require("../../shared/UIAssets")
local InteractLock = if isStudio then require(script.Parent.Parent.InteractLock) else nil

local PCScreen = {}
PCScreen.running = false

local PIXELS_PER_STUD = 250 -- จอ 4×2.6 studs → canvas 1000×650 px
local ZOOM_TIME = 0.4

-- หน้าตาเครื่องต่อเฟส (สีถูกทับด้วย wallpaper รูปถ้าทีมใส่ asset แล้ว)
--   gTop/gBot = ไล่สี wallpaper การ์ตูน · accent = สีเด่น (taskbar start/widget) · bar = สี taskbar
local STYLES = {
	[1] = { deviceName = "โน้ตบุ๊คมือสอง", wall = Color3.fromRGB(95, 115, 135), wallAsset = "wallpaper_phase1",
		gTop = Color3.fromRGB(126, 206, 255), gBot = Color3.fromRGB(176, 232, 210), accent = Color3.fromRGB(88, 150, 240), bar = Color3.fromRGB(40, 52, 74) },
	[2] = { deviceName = "คอมตั้งโต๊ะ", wall = Color3.fromRGB(40, 120, 200), wallAsset = "wallpaper_phase2",
		gTop = Color3.fromRGB(90, 172, 240), gBot = Color3.fromRGB(44, 72, 150), accent = Color3.fromRGB(92, 186, 255), bar = Color3.fromRGB(26, 36, 64) },
	[3] = { deviceName = "เครื่องเทพ RGB", wall = Color3.fromRGB(30, 22, 55), wallAsset = "wallpaper_phase3", neon = true,
		gTop = Color3.fromRGB(72, 40, 122), gBot = Color3.fromRGB(18, 10, 36), accent = Color3.fromRGB(162, 102, 255), bar = Color3.fromRGB(22, 14, 44) },
}

-- กล้องบินไปหน้าจอ: ระยะพอดีให้จอเต็มเฟรมแนวตั้ง
local function zoomToScreen(screenPart)
	local camera = workspace.CurrentCamera
	local saved = { cf = camera.CFrame, type = camera.CameraType }
	camera.CameraType = Enum.CameraType.Scriptable
	local dist = (screenPart.Size.Y / 2) / math.tan(math.rad(camera.FieldOfView / 2)) + screenPart.Size.Z
	local front = screenPart.CFrame * CFrame.new(0, 0, -dist) -- Front face = -Z
	local target = CFrame.lookAt(front.Position, screenPart.Position)
	game:GetService("TweenService"):Create(camera, TweenInfo.new(ZOOM_TIME, Enum.EasingStyle.Quad),
		{ CFrame = target }):Play()
	return saved
end

-- deps = { fireAction, getState } | apps = { {id, name, label, create|external} }
-- screenPart = Interact_pcMonitor ของเครื่องที่กด (จำเป็น — UI แปะบน part นี้)
function PCScreen.open(playerGui, deps, apps, screenPart)
	if PCScreen.running then return end
	if not screenPart or not screenPart:IsA("BasePart") then
		warn("[PCScreen] ต้องมี part จอ (Interact_pcMonitor) — เปิดไม่ได้")
		return
	end
	PCScreen.running = true
	if InteractLock then InteractLock.lock() end -- ปิด prompt + ล็อกเดิน (กด E/WASD ในแอปไม่โดน prompt/ไม่เดิน)
	deps.fireAction({ type = "FreezeTime", on = true })

	local savedCam = zoomToScreen(screenPart)
	local state = deps.getState()
	local style = STYLES[math.clamp(state and state.phase or 1, 1, 3)]

	-- ===== UI บนหน้าจอจริง =====
	-- อยู่ใน PlayerGui + Adornee = part (วิธีมาตรฐานให้ปุ่มบน SurfaceGui กดได้)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Gui_PCScreen"
	surface.Adornee = screenPart
	surface.Face = Enum.NormalId.Front
	surface.PixelsPerStud = PIXELS_PER_STUD
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.LightInfluence = 0 -- สว่างเท่ากันทุกสภาพแสง (จอเรืองแสงเอง)
	surface.AlwaysOnTop = false
	surface.Active = true
	surface.ResetOnSpawn = false

	local screen = Instance.new("Frame")
	screen.Size = UDim2.new(1, 0, 1, 0)
	screen.BackgroundColor3 = style.wall
	screen.Parent = surface

	-- helper สร้าง instance สั้นๆ (ใช้แต่งจอ desktop — layer ตกแต่ง ZIndex 0 ใต้ปุ่ม/แอป)
	local function mk(class, parent, props)
		local o = Instance.new(class)
		for k, v in props do o[k] = v end
		o.Parent = parent
		return o
	end

	local wallId = UIAssets[style.wallAsset]
	if wallId ~= "" then
		mk("ImageLabel", screen, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			Image = wallId, ScaleType = Enum.ScaleType.Crop, ZIndex = 0 })
	else
		-- ไม่มีรูป = วาด wallpaper การ์ตูนเอง: ไล่สีทแยง + ก้อนนุ่มกระจาย (เมฆ/โบเก้) เติมมิติ
		screen.BackgroundColor3 = Color3.new(1, 1, 1) -- ให้ gradient โชว์สีจริง
		mk("UIGradient", screen, { Color = ColorSequence.new(style.gTop, style.gBot), Rotation = 115 })
		local blobCol = style.neon and Color3.fromRGB(185, 125, 255) or Color3.new(1, 1, 1)
		for _, b in { { 0.13, 0.18, 160 }, { 0.74, 0.13, 120 }, { 0.88, 0.58, 180 }, { 0.30, 0.82, 140 }, { 0.55, 0.42, 100 } } do
			local blob = mk("Frame", screen, {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(b[1], b[2]),
				Size = UDim2.fromOffset(b[3], b[3]), BackgroundColor3 = blobCol,
				BackgroundTransparency = style.neon and 0.82 or 0.87, BorderSizePixel = 0, ZIndex = 0,
			})
			mk("UICorner", blob, { CornerRadius = UDim.new(1, 0) })
		end
	end

	if style.neon then
		mk("UIStroke", screen, { Thickness = 6, Color = Color3.fromRGB(120, 80, 255) })
	end

	-- ★ ชั้นตกแต่ง desktop (taskbar + widget) — ซ่อนตอนเปิดแอป (openApp/closeApp toggle) กัน bleed ทับแอป
	local desktopDecor = mk("Frame", screen, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0 })

	-- host แอปที่เปิดอยู่ (ขวาของ desktop icon)
	local appFrame = Instance.new("Frame")
	appFrame.Position = UDim2.new(0.22, 0, 0.04, 0)
	appFrame.Size = UDim2.new(0.74, 0, 0.92, 0)
	appFrame.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
	appFrame.Visible = false
	appFrame.Parent = screen

	local currentApp = nil
	local openApp
	-- แอปในแอป (เช่น Bank → Manage): แอปเรียก deps.openApp("manage") ได้
	deps.openApp = function(id)
		for _, a in apps do
			if a.id == id then
				if a.external then a.external() else openApp(a) end
				return
			end
		end
		warn("[PCScreen] ไม่รู้จักแอป: " .. tostring(id))
	end

	function openApp(app)
		appFrame:ClearAllChildren()
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = appFrame
		appFrame.Visible = true
		desktopDecor.Visible = false -- ซ่อน taskbar/widget ตอนเปิดแอป (กันโผล่ทับ)
		currentApp = app.create(appFrame, deps)
		if currentApp and currentApp.refresh and state then currentApp.refresh(state) end
	end

	-- desktop icon คอลัมน์ซ้าย (ตามภาพร่าง PDF) — ไอคอน 80×80 + ชื่อใต้
	local ICON, LABEL_H, GAP = 80, 22, 8
	local desktopApps = {}
	for _, a in apps do
		if not a.hidden then table.insert(desktopApps, a) end
	end
	for i, app in desktopApps do
		local col = math.floor((i - 1) / 5)
		local row = (i - 1) % 5
		local x = 24 + col * (ICON + 40)
		local y = 20 + row * (ICON + LABEL_H + GAP)
		-- เงา + แผ่นรองสติกเกอร์ ใต้ไอคอน (การ์ตูน ยกลอยจาก wallpaper) — ZIndex 0 ใต้ปุ่มจริง
		local sh = mk("Frame", screen, { Position = UDim2.fromOffset(x + 3, y + 5), Size = UDim2.fromOffset(ICON, ICON),
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.72, BorderSizePixel = 0, ZIndex = 0 })
		mk("UICorner", sh, { CornerRadius = UDim.new(0, 18) })
		local tile = mk("Frame", screen, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(ICON, ICON),
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.06, BorderSizePixel = 0, ZIndex = 0 })
		mk("UICorner", tile, { CornerRadius = UDim.new(0, 18) })
		mk("UIStroke", tile, { Thickness = 2.5, Color = style.accent, Transparency = 0.2 })

		local assetId = app.id and UIAssets["app_" .. app.id] or ""
		local btn
		if assetId ~= "" then
			btn = Instance.new("ImageButton")
			btn.Image = assetId
			btn.BackgroundTransparency = 1
		else
			btn = Instance.new("TextButton")
			btn.Text = app.label
			btn.TextScaled = true
			btn.FontFace = Font.fromEnum(Enum.Font.GothamBold)
			btn.BackgroundTransparency = 1
			btn.TextColor3 = Color3.fromRGB(40, 46, 66)
		end
		btn.Size = UDim2.new(0, ICON, 0, ICON)
		btn.Position = UDim2.new(0, x, 0, y)
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 18)
		bc.Parent = btn
		btn.Parent = screen -- ZIndex ปุ่ม = default 1 (บนแผ่นรอง) · Activated เดิมไม่แตะ

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0, ICON + 24, 0, LABEL_H)
		name.Position = UDim2.new(0, x - 12, 0, y + ICON + 3)
		name.BackgroundTransparency = 1
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextStrokeTransparency = 0.15
		name.TextScaled = true
		name.FontFace = Font.fromEnum(Enum.Font.GothamBold)
		name.Text = app.name or app.label
		name.Parent = screen

		btn.Activated:Connect(function()
			if app.external then app.external() else openApp(app) end
		end)
	end

	-- ===== widget การ์ตูนกลางจอ (เติมช่องว่าง desktop) — โชว์ตอนไม่ได้เปิดแอป =====
	local card = mk("Frame", desktopDecor, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.58, 0.46),
		Size = UDim2.fromOffset(360, 210), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.08, BorderSizePixel = 0, ZIndex = 0,
	})
	mk("UICorner", card, { CornerRadius = UDim.new(0, 24) })
	mk("UIStroke", card, { Thickness = 3, Color = style.accent, Transparency = 0.15 })
	local cardShadow = mk("Frame", desktopDecor, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.58, 0.47),
		Size = UDim2.fromOffset(368, 218), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = 0,
	})
	mk("UICorner", cardShadow, { CornerRadius = UDim.new(0, 26) })
	cardShadow.ZIndex = 0
	mk("TextLabel", card, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromScale(0.9, 0.34), BackgroundTransparency = 1, Text = "🎬  " .. style.deviceName,
		TextColor3 = Color3.fromRGB(38, 44, 64), TextScaled = true, FontFace = Font.fromEnum(Enum.Font.GothamBold), ZIndex = 1 })
	local dNow = (state and state.day) or 1
	local pNow = (state and state.phase) or 1
	mk("TextLabel", card, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromScale(0.86, 0.2), BackgroundTransparency = 1,
		Text = ("📅 วันที่ %d      ▸ เฟส %d"):format(dNow, pNow),
		TextColor3 = Color3.fromRGB(90, 98, 122), TextScaled = true, FontFace = Font.fromEnum(Enum.Font.GothamMedium), ZIndex = 1 })
	mk("TextLabel", card, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.9),
		Size = UDim2.fromScale(0.88, 0.22), BackgroundTransparency = 1, Text = "เลือกแอปทางซ้ายเพื่อเริ่มทำงาน ✨",
		TextColor3 = style.accent, TextScaled = true, FontFace = Font.fromEnum(Enum.Font.GothamMedium), ZIndex = 1 })

	-- ===== taskbar ล่าง (ฟีล PC) — start + ชื่อเครื่อง + จุด pin + นาฬิกาวัน =====
	local tb = mk("Frame", desktopDecor, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, -24, 0, 50), BackgroundColor3 = style.bar,
		BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 0,
	})
	mk("UICorner", tb, { CornerRadius = UDim.new(0, 14) })
	mk("UIStroke", tb, { Thickness = 2, Color = style.accent, Transparency = 0.55 })
	local start = mk("Frame", tb, { Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(150, 32),
		BackgroundColor3 = style.accent, BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 1 })
	mk("UICorner", start, { CornerRadius = UDim.new(0, 10) })
	mk("TextLabel", start, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -16, 1, 0), BackgroundTransparency = 1,
		Text = "⊞  " .. style.deviceName, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true, FontFace = Font.fromEnum(Enum.Font.GothamBold), ZIndex = 2 })
	-- จุด pin กลาง (ตกแต่ง)
	for d = 0, 3 do
		local dot = mk("Frame", tb, { Position = UDim2.fromOffset(180 + d * 30, 15), Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 1 })
		mk("UICorner", dot, { CornerRadius = UDim.new(0, 6) })
	end
	mk("TextLabel", tb, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(150, 26), BackgroundTransparency = 1, Text = ("🔋  วันที่ %d"):format(dNow),
		TextColor3 = Color3.fromRGB(220, 226, 240), TextXAlignment = Enum.TextXAlignment.Right,
		TextScaled = true, FontFace = Font.fromEnum(Enum.Font.GothamMedium), ZIndex = 1 })

	surface.Parent = playerGui

	-- ===== ปุ่มออก: **มุมขวาบนของจอ** ตามภาพร่าง `ui screenshot/PC ui.png` ("Exit ⏻") =====
	-- อยู่บน SurfaceGui เดียวกับ desktop (surface.Active = true ทำให้กดได้)
	local exitId = UIAssets.btn_exit
	local exit
	if exitId ~= "" then
		exit = Instance.new("ImageButton")
		exit.Image = exitId
		exit.BackgroundTransparency = 1
		exit.Size = UDim2.new(0, 56, 0, 56)
		exit.Position = UDim2.new(1, -70, 0, 14)
	else
		exit = Instance.new("TextButton")
		exit.Text = "✕  ออก"
		exit.TextScaled = true
		exit.FontFace = Font.fromEnum(Enum.Font.GothamBold)
		exit.TextColor3 = Color3.new(1, 1, 1)
		exit.BackgroundColor3 = Color3.fromRGB(232, 78, 88) -- ปุ่มปิดหน้าต่างแบบ PC (แดงมน)
		exit.Size = UDim2.new(0, 118, 0, 44)
		exit.Position = UDim2.new(1, -134, 0, 14)
		local ec = Instance.new("UICorner")
		ec.CornerRadius = UDim.new(0, 12)
		ec.Parent = exit
		local ep = Instance.new("UIPadding")
		ep.PaddingTop = UDim.new(0, 10)
		ep.PaddingBottom = UDim.new(0, 10)
		ep.Parent = exit
		local es = Instance.new("UIStroke")
		es.Color = Color3.new(1, 1, 1)
		es.Thickness = 2
		es.Transparency = 0.4
		es.Parent = exit
	end
	exit.ZIndex = 5
	exit.Parent = screen

	-- ปุ่มสำรองบน ScreenGui — กันเคสกด SurfaceGui ไม่ติด (มือถือ/กล้องเอียง) จะได้ไม่ค้างในจอ
	local overlay = Instance.new("ScreenGui")
	overlay.Name = "Gui_PCExit"
	overlay.ResetOnSpawn = false
	overlay.IgnoreGuiInset = true
	local backup = Instance.new("TextButton")
	backup.Text = "⏻"
	backup.TextScaled = true
	backup.TextColor3 = Color3.new(1, 1, 1)
	backup.BackgroundColor3 = Color3.fromRGB(200, 45, 45)
	backup.BackgroundTransparency = 0.35
	backup.Size = UDim2.new(0, 44, 0, 44)
	backup.Position = UDim2.new(1, -56, 0, 12)
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 10)
	bc.Parent = backup
	backup.Parent = overlay
	overlay.Parent = playerGui

	local function closeScreen()
		deps.fireAction({ type = "FreezeTime", on = false })
		local camera = workspace.CurrentCamera
		camera.CFrame = savedCam.cf
		camera.CameraType = savedCam.type
		surface:Destroy()
		overlay:Destroy()
		PCScreen.running = false
		PCScreen.forceClose = nil
		if InteractLock then InteractLock.unlock() end
	end
	PCScreen.forceClose = closeScreen -- ให้ที่อื่นสั่งปิดได้ (เช่น ข้ามเฟสตอนกำลังใช้คอม)
	-- ปุ่ม Exit บนจอ: มีแอปเปิดอยู่ = กลับ desktop (ไม่ใช่ปิดคอม) · อยู่ desktop = ปิดคอม
	-- (เดิมกดออกแอปแล้วปิดคอมเลย — bug)
	local function closeApp()
		appFrame.Visible = false
		appFrame:ClearAllChildren()
		currentApp = nil
		desktopDecor.Visible = true -- กลับ desktop = โชว์ taskbar/widget อีกครั้ง
	end
	exit.Activated:Connect(function()
		if appFrame.Visible then closeApp() else closeScreen() end
	end)
	backup.Activated:Connect(closeScreen) -- ปุ่มสำรอง (ScreenGui) = ปิดคอมเสมอ กันค้างในจอ

	function PCScreen.refresh(newState)
		state = newState
		if PCScreen.running and currentApp and currentApp.refresh then
			currentApp.refresh(newState)
		end
	end
end

return PCScreen
