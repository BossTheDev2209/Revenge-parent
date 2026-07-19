-- PCScreen.luau — Universal PC UI (PDF หน้า 5 "UI PC", ref Jim's Computer)
-- ใช้ได้กับเครื่องทุกตัว: convention = model มี part ชื่อ `Interact_pcMonitor` (จอขนาดเท่ากันทุกเครื่อง 4×2.6)
--   หน้าจอ = ด้าน Front ของ part → กด E → กล้อง zoom เข้าจอ → GUI เต็มจอ → Exit คืนกล้อง
-- รูป icon/wallpaper อ่านจาก ReplicatedStorage.Shared.UIAssets — ว่าง = fallback ตัวหนังสือ
local isStudio = script ~= nil
local UIAssets = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.UIAssets)
	else require("../../shared/UIAssets")

local PCScreen = {}
PCScreen.running = false

-- หน้าตาเครื่องต่อเฟส (สีถูก override ด้วย wallpaper รูปถ้าทีมใส่ asset แล้ว)
local STYLES = {
	[1] = { deviceName = "โน้ตบุ๊คมือสอง", bezel = Color3.fromRGB(70, 70, 70),
		wall = Color3.fromRGB(95, 115, 135), wallAsset = "wallpaper_phase1" },
	[2] = { deviceName = "คอมตั้งโต๊ะ", bezel = Color3.fromRGB(25, 25, 25),
		wall = Color3.fromRGB(40, 120, 200), wallAsset = "wallpaper_phase2" },
	[3] = { deviceName = "เครื่องเทพ RGB", bezel = Color3.fromRGB(12, 12, 18),
		wall = Color3.fromRGB(30, 22, 55), wallAsset = "wallpaper_phase3", neon = true },
}

local ZOOM_TIME = 0.4

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

-- deps = { fireAction, getState } | apps = { {id, label, create|external} }
-- screenPart = Interact_pcMonitor ของเครื่องที่กด (nil ได้ = ไม่ zoom แค่เปิด GUI)
function PCScreen.open(playerGui, deps, apps, screenPart)
	if PCScreen.running then return end
	PCScreen.running = true
	deps.fireAction({ type = "FreezeTime", on = true })

	local savedCam = screenPart and zoomToScreen(screenPart) or nil

	local state = deps.getState()
	local style = STYLES[math.clamp(state and state.phase or 1, 1, 3)]

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_PCScreen"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local bezel = Instance.new("Frame")
	bezel.Size = UDim2.new(1, 0, 1, 0)
	bezel.BackgroundColor3 = style.bezel
	bezel.BackgroundTransparency = 1 -- โผล่หลัง zoom จบ
	bezel.Parent = gui
	task.delay(ZOOM_TIME * 0.8, function() bezel.BackgroundTransparency = 0 end)

	if style.neon then
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = Color3.fromRGB(120, 80, 255)
		stroke.Parent = bezel
	end

	local screen = Instance.new("Frame")
	screen.Position = UDim2.new(0.04, 0, 0.05, 0)
	screen.Size = UDim2.new(0.92, 0, 0.9, 0)
	screen.BackgroundColor3 = style.wall
	screen.Visible = false
	screen.Parent = bezel
	task.delay(ZOOM_TIME, function() screen.Visible = true end)

	local wallId = UIAssets[style.wallAsset]
	if wallId ~= "" then
		local wall = Instance.new("ImageLabel")
		wall.Size = UDim2.new(1, 0, 1, 0)
		wall.BackgroundTransparency = 1
		wall.Image = wallId
		wall.ScaleType = Enum.ScaleType.Crop
		wall.Parent = screen
	end

	local deviceLabel = Instance.new("TextLabel")
	deviceLabel.Size = UDim2.new(0, 300, 0, 26)
	deviceLabel.Position = UDim2.new(0.5, -150, 1, -28)
	deviceLabel.BackgroundTransparency = 1
	deviceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	deviceLabel.TextScaled = true
	deviceLabel.Text = style.deviceName
	deviceLabel.Parent = bezel

	-- host แอปที่เปิดอยู่
	local appFrame = Instance.new("Frame")
	appFrame.Position = UDim2.new(0.24, 0, 0.05, 0)
	appFrame.Size = UDim2.new(0.72, 0, 0.88, 0)
	appFrame.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
	appFrame.Visible = false
	appFrame.Parent = screen

	local currentApp = nil
	local function openApp(app)
		appFrame:ClearAllChildren()
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = appFrame
		appFrame.Visible = true
		currentApp = app.create(appFrame, deps)
		if currentApp and currentApp.refresh and state then currentApp.refresh(state) end
	end

	-- desktop icons ซ้าย: รูป 64×64 + ชื่อใต้ (แบบ ref) — ไม่มีรูป = ปุ่มตัวหนังสือ
	for i, app in apps do
		local col = math.floor((i - 1) / 5)
		local row = (i - 1) % 5
		local x, y = 20 + col * 110, 16 + row * 104
		local assetId = app.id and UIAssets["app_" .. app.id] or ""
		local btn
		if assetId ~= "" then
			btn = Instance.new("ImageButton")
			btn.Image = assetId
			btn.BackgroundTransparency = 1
			btn.Size = UDim2.new(0, 64, 0, 64)
			btn.Position = UDim2.new(0, x + 13, 0, y)
		else
			btn = Instance.new("TextButton")
			btn.Text = app.label
			btn.TextScaled = true
			btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			btn.BackgroundTransparency = 0.25
			btn.Size = UDim2.new(0, 90, 0, 64)
			btn.Position = UDim2.new(0, x, 0, y)
			local bc = Instance.new("UICorner")
			bc.CornerRadius = UDim.new(0, 8)
			bc.Parent = btn
		end
		btn.Parent = screen
		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0, 90, 0, 22)
		name.Position = UDim2.new(0, x, 0, y + 66)
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

	-- ปุ่มปิดเครื่อง
	local exitId = UIAssets.btn_exit
	local exit
	if exitId ~= "" then
		exit = Instance.new("ImageButton")
		exit.Image = exitId
		exit.BackgroundTransparency = 1
		exit.Size = UDim2.new(0, 44, 0, 44)
	else
		exit = Instance.new("TextButton")
		exit.Text = "⏻ Exit"
		exit.TextScaled = true
		exit.TextColor3 = Color3.new(1, 1, 1)
		exit.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		exit.Size = UDim2.new(0, 100, 0, 34)
	end
	exit.Position = UDim2.new(1, -exit.Size.X.Offset - 12, 0, 10)
	exit.Parent = screen
	exit.Activated:Connect(function()
		deps.fireAction({ type = "FreezeTime", on = false })
		if savedCam then
			local camera = workspace.CurrentCamera
			camera.CFrame = savedCam.cf
			camera.CameraType = savedCam.type
		end
		gui:Destroy()
		PCScreen.running = false
	end)

	gui.Parent = playerGui

	function PCScreen.refresh(newState)
		state = newState
		if PCScreen.running and currentApp and currentApp.refresh then
			currentApp.refresh(newState)
		end
	end
end

return PCScreen
