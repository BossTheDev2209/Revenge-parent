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
local STYLES = {
	[1] = { deviceName = "โน้ตบุ๊คมือสอง", wall = Color3.fromRGB(95, 115, 135), wallAsset = "wallpaper_phase1" },
	[2] = { deviceName = "คอมตั้งโต๊ะ", wall = Color3.fromRGB(40, 120, 200), wallAsset = "wallpaper_phase2" },
	[3] = { deviceName = "เครื่องเทพ RGB", wall = Color3.fromRGB(30, 22, 55), wallAsset = "wallpaper_phase3", neon = true },
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

	local wallId = UIAssets[style.wallAsset]
	if wallId ~= "" then
		local wall = Instance.new("ImageLabel")
		wall.Size = UDim2.new(1, 0, 1, 0)
		wall.BackgroundTransparency = 1
		wall.Image = wallId
		wall.ScaleType = Enum.ScaleType.Crop
		wall.Parent = screen
	end

	if style.neon then
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 6
		stroke.Color = Color3.fromRGB(120, 80, 255)
		stroke.Parent = screen
	end

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
			btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			btn.BackgroundTransparency = 0.25
			local bc = Instance.new("UICorner")
			bc.CornerRadius = UDim.new(0, 8)
			bc.Parent = btn
		end
		btn.Size = UDim2.new(0, ICON, 0, ICON)
		btn.Position = UDim2.new(0, x, 0, y)
		btn.Parent = screen

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0, ICON + 20, 0, LABEL_H)
		name.Position = UDim2.new(0, x - 10, 0, y + ICON + 2)
		name.BackgroundTransparency = 1
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextStrokeTransparency = 0.4
		name.TextScaled = true
		name.Text = app.name or app.label
		name.Parent = screen

		btn.Activated:Connect(function()
			if app.external then app.external() else openApp(app) end
		end)
	end

	local deviceLabel = Instance.new("TextLabel")
	deviceLabel.Size = UDim2.new(0.3, 0, 0, 24)
	deviceLabel.Position = UDim2.new(0.68, 0, 1, -28)
	deviceLabel.BackgroundTransparency = 1
	deviceLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	deviceLabel.TextStrokeTransparency = 0.5
	deviceLabel.TextScaled = true
	deviceLabel.Text = style.deviceName
	deviceLabel.Parent = screen

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
		exit.Text = "Exit ⏻"
		exit.TextScaled = true
		exit.TextColor3 = Color3.fromRGB(30, 60, 160)
		exit.BackgroundColor3 = Color3.new(1, 1, 1)
		exit.Size = UDim2.new(0, 120, 0, 44)
		exit.Position = UDim2.new(1, -136, 0, 14)
		local es = Instance.new("UIStroke")
		es.Color = Color3.fromRGB(30, 60, 160)
		es.Thickness = 2
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
		if InteractLock then InteractLock.unlock() end
	end
	exit.Activated:Connect(closeScreen)
	backup.Activated:Connect(closeScreen)

	function PCScreen.refresh(newState)
		state = newState
		if PCScreen.running and currentApp and currentApp.refresh then
			currentApp.refresh(newState)
		end
	end
end

return PCScreen
