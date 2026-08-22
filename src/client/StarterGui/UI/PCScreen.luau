-- PCScreen — Universal PC UI (ScreenGui เต็มจอ + กล้อง zoom เข้าจอ) · กด E ที่ Interact_pcMonitor
-- instance จริง: StarterGui.Gui_PC (แต่งใน Studio ได้) · ไม่มี = build() จากโค้ด
-- ชื่อที่โค้ดอ้าง ห้ามเปลี่ยน: Screen.{Wallpaper, DeviceLabel, ExitButton, AppFrame, IconBar.IconTemplate}
-- ไอคอนต่อแอป: วาง ImageButton ชื่อ "Icon_<app.id>" ใต้ Screen.IconBar เอง (ไม่มี = fallback clone IconTemplate)
local isStudio = script ~= nil
local UIAssets = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.UIAssets)
	else require("../../../shared/UIAssets")
-- InteractLock/Audio อยู่ StarterPlayerScripts — absolute path (script.Parent.Parent ใช้ไม่ได้หลังย้าย PCScreen ไป StarterGui)
local InteractLock = if isStudio
	then require(game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild("InteractLock"))
	else nil
local Audio = if isStudio
	then require(game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild("AudioService"))
	else nil

local function sfx(name: string)
	if Audio then Audio.sfx(name) end
end

local PCScreen = {}
PCScreen.running = false
local ZOOM_TIME = 0.4

-- หน้าตาเครื่องต่อเฟส (สีถูกทับด้วย wallpaper รูปถ้าทีมใส่ asset)
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

-- build fallback: สร้างโครง Gui_PC จากโค้ด (ทุกชิ้น Scale + responsive)
local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = o
end
function PCScreen.build(parent): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_PC"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Enabled = false

	local screen = Instance.new("Frame")
	screen.Name = "Screen"
	screen.Size = UDim2.fromScale(1, 1)
	screen.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	screen.Parent = gui

	local wall = Instance.new("ImageLabel")
	wall.Name = "Wallpaper"
	wall.Size = UDim2.fromScale(1, 1)
	wall.BackgroundTransparency = 1
	wall.ScaleType = Enum.ScaleType.Crop
	wall.Parent = screen

	local appFrame = Instance.new("Frame")
	appFrame.Name = "AppFrame"
	appFrame.AnchorPoint = Vector2.new(1, 0.5)
	appFrame.Position = UDim2.fromScale(0.985, 0.5)
	appFrame.Size = UDim2.fromScale(0.74, 0.9)
	appFrame.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
	appFrame.Visible = false
	appFrame.Parent = screen
	corner(appFrame, 10)

	local iconBar = Instance.new("Frame")
	iconBar.Name = "IconBar"
	iconBar.AnchorPoint = Vector2.new(0, 0.5)
	iconBar.Position = UDim2.fromScale(0.012, 0.5)
	iconBar.Size = UDim2.fromScale(0.2, 0.92)
	iconBar.BackgroundTransparency = 1
	iconBar.Parent = screen

	local tmpl = Instance.new("ImageButton")
	tmpl.Name = "IconTemplate"
	tmpl.Visible = false
	tmpl.Size = UDim2.fromScale(1, 0.15)
	tmpl.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tmpl.BackgroundTransparency = 0.2
	tmpl.Parent = iconBar
	corner(tmpl, 8)
	local nm = Instance.new("TextLabel")
	nm.Name = "Name"
	nm.AnchorPoint = Vector2.new(0.5, 1)
	nm.Position = UDim2.fromScale(0.5, 1)
	nm.Size = UDim2.fromScale(1.2, 0.28)
	nm.BackgroundTransparency = 1
	nm.TextColor3 = Color3.new(1, 1, 1)
	nm.TextStrokeTransparency = 0.4
	nm.TextScaled = true
	nm.Parent = tmpl

	local dev = Instance.new("TextLabel")
	dev.Name = "DeviceLabel"
	dev.AnchorPoint = Vector2.new(1, 1)
	dev.Position = UDim2.fromScale(0.98, 0.99)
	dev.Size = UDim2.fromScale(0.3, 0.05)
	dev.BackgroundTransparency = 1
	dev.TextColor3 = Color3.fromRGB(230, 230, 230)
	dev.TextStrokeTransparency = 0.5
	dev.TextScaled = true
	dev.TextXAlignment = Enum.TextXAlignment.Right
	dev.Parent = screen

	local exit = Instance.new("TextButton")
	exit.Name = "ExitButton"
	exit.AnchorPoint = Vector2.new(1, 0)
	exit.Position = UDim2.fromScale(0.99, 0.02)
	exit.Size = UDim2.fromScale(0.055, 0.08)
	exit.Text = "⏻"
	exit.TextScaled = true
	exit.TextColor3 = Color3.new(1, 1, 1)
	exit.BackgroundColor3 = Color3.fromRGB(200, 45, 45)
	exit.ZIndex = 5
	exit.Parent = screen
	corner(exit, 8)

	gui.Parent = parent
	return gui
end

-- deps = { fireAction, getState } | apps = { {id, name, label, create|external, hidden} }
-- screenPart = Interact_pcMonitor ของเครื่องที่กด (กล้อง zoom หาจอ)
function PCScreen.open(playerGui, deps, apps, screenPart)
	if PCScreen.running then return end
	if not screenPart or not screenPart:IsA("BasePart") then
		warn("[PCScreen] ต้องมี part จอ (Interact_pcMonitor) — เปิดไม่ได้")
		return
	end
	PCScreen.running = true
	if InteractLock then InteractLock.lock() end
	deps.fireAction({ type = "FreezeTime", on = true })

	local savedCam = zoomToScreen(screenPart)
	local state = deps.getState()
	local style = STYLES[math.clamp(state and state.phase or 1, 1, 3)]

	local gui = playerGui:FindFirstChild("Gui_PC") or playerGui:WaitForChild("Gui_PC", 5) or PCScreen.build(playerGui)
	local screen = gui:FindFirstChild("Screen")
	local appFrame = screen and screen:FindFirstChild("AppFrame")
	local iconBar = screen and screen:FindFirstChild("IconBar")
	local template = iconBar and iconBar:FindFirstChild("IconTemplate")
	if not (screen and appFrame and iconBar and template) then
		warn("[PCScreen] Gui_PC โครงไม่ครบ (ต้องมี Screen.{AppFrame,IconBar.IconTemplate}) — แก้ชื่อใน Studio ให้ตรง")
		deps.fireAction({ type = "FreezeTime", on = false })
		local camera = workspace.CurrentCamera
		camera.CFrame = savedCam.cf
		camera.CameraType = savedCam.type
		PCScreen.running = false
		if InteractLock then InteractLock.unlock() end
		return
	end

	screen.Visible = true -- บังคับกัน Screen.Visible=false ค้างจาก Studio (เจอจริง: เปิดคอมมาจอว่าง)

	screen.BackgroundColor3 = style.wall
	-- wallpaper: ทับเฉพาะตอน UIAssets มีรูปจริง — คีย์ว่าง ("") ห้ามทับ (ไม่งั้นล้างรูปที่ทีมใส่ทิ้ง)
	local wall = screen:FindFirstChild("Wallpaper")
	if wall and wall:IsA("ImageLabel") then
		local wallAsset = UIAssets[style.wallAsset]
		if wallAsset and wallAsset ~= "" then wall.Image = wallAsset end
	end
	local dev = screen:FindFirstChild("DeviceLabel")
	if dev then dev.Text = style.deviceName end

	local currentApp = nil
	local openApp
	deps.openApp = function(id) -- แอปในแอป (Bank → Manage)
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
		appFrame.Visible = true
		currentApp = app.create(appFrame, deps)
		if currentApp and currentApp.refresh and state then currentApp.refresh(state) end
		sfx("app_open")
	end
	-- silent = ปิดทั้งเครื่อง (closeScreen เล่น pc_off แทน กันเสียงซ้อน)
	local function closeApp(silent: boolean?)
		appFrame.Visible = false
		appFrame:ClearAllChildren()
		currentApp = nil
		if not silent then sfx("app_close") end
	end

	-- ไอคอน: ใช้ instance จริงชื่อ "Icon_<id>" ถ้าทีมแต่งไว้ (โค้ดไม่แตะสี/รูป/ตำแหน่ง) · ไม่มี = fallback clone
	iconBar.Visible = true -- บังคับกัน IconBar.Visible=false ค้างจาก Studio (BackgroundTransparency=1 อยู่แล้ว)
	local iconClones = {} -- เฉพาะตัวที่ fallback-clone (ต้อง Destroy ตอนปิด)
	local iconConns = {} -- ทุกตัว กัน connection ซ้อน
	local i = 0
	for _, app in apps do
		if app.hidden then
			-- ยังไม่ถึงเฟส (bank/message) หรือถาวร (manage) — icon จริงต้องถูกซ่อนตรงๆ (ไม่ใช่แค่ไม่วาดใหม่)
			local btn = app.id and iconBar:FindFirstChild("Icon_" .. app.id)
			if btn then btn.Visible = false end
		else
			i += 1
			local btn = iconBar:FindFirstChild("Icon_" .. (app.id or i))
			if not btn then
				btn = template:Clone()
				btn.Name = "Icon_" .. (app.id or i)
				btn.LayoutOrder = i
				btn.Position = UDim2.fromScale(0, (i - 1) * 0.17) -- fallback ถ้าไม่มี layout
				local assetId = app.id and UIAssets["app_" .. app.id] or ""
				if assetId ~= "" then btn.Image = assetId end
				local nameLbl = btn:FindFirstChild("Name")
				if nameLbl then nameLbl.Text = app.name or app.label end
				btn.Parent = iconBar
				table.insert(iconClones, btn)
			end
			btn.Visible = true
			table.insert(iconConns, btn.Activated:Connect(function()
				if app.external then app.external() else openApp(app) end
			end))
		end
	end

	gui.Enabled = true

	local exitConn = nil
	local function closeScreen()
		deps.fireAction({ type = "FreezeTime", on = false })
		local camera = workspace.CurrentCamera
		camera.CFrame = savedCam.cf
		camera.CameraType = savedCam.type
		gui.Enabled = false
		closeApp(true)
		for _, conn in iconConns do conn:Disconnect() end
		for _, b in iconClones do b:Destroy() end -- เฉพาะ fallback clone — instance จริงเก็บไว้
		if exitConn then exitConn:Disconnect() end
		PCScreen.running = false
		PCScreen.forceClose = nil
		if InteractLock then InteractLock.unlock() end
		sfx("pc_off")
	end
	PCScreen.forceClose = closeScreen

	-- Exit: มีแอปเปิด = กลับ desktop · อยู่ desktop = ปิดคอม
	local exit = screen:FindFirstChild("ExitButton")
	if exit then
		exitConn = exit.Activated:Connect(function()
			if appFrame.Visible then closeApp() else closeScreen() end
		end)
	end

	function PCScreen.refresh(newState)
		state = newState
		if PCScreen.running and currentApp and currentApp.refresh then
			currentApp.refresh(newState)
		end
	end
end

return PCScreen
