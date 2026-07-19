-- PCScreen.luau — On-screen GUI เต็มจอแบบ Jim's Computer (PDF หน้า 5 "UI PC")
-- เปิดเมื่อกด Interact_Camera — desktop มี icon แอป กดเปิดแอปในจอ กด Exit ออก
-- กรอบเครื่อง/wallpaper เปลี่ยนตามเฟส: 1 โน้ตบุ๊คมือสอง / 2 คอมตั้งโต๊ะ / 3 เครื่องเทพ RGB
-- (style = หน้าตาล้วน ไม่ใช่ตัวเลข balance เลยไม่อยู่ Config)
local PCScreen = {}
PCScreen.running = false

local STYLES = {
	[1] = { deviceName = "💻 โน้ตบุ๊คมือสอง", bezel = Color3.fromRGB(70, 70, 70),
		wall = Color3.fromRGB(95, 115, 135), inset = 0.10 },
	[2] = { deviceName = "🖥️ คอมตั้งโต๊ะ", bezel = Color3.fromRGB(25, 25, 25),
		wall = Color3.fromRGB(40, 120, 200), inset = 0.05 },
	[3] = { deviceName = "🌈 เครื่องเทพ RGB", bezel = Color3.fromRGB(12, 12, 18),
		wall = Color3.fromRGB(30, 22, 55), inset = 0.03, neon = true },
}

-- deps = { fireAction, getState, startQTE } | appList เติมใน init (แยกไฟล์ต่อแอป)
function PCScreen.open(playerGui, deps, apps)
	if PCScreen.running then return end
	PCScreen.running = true
	deps.fireAction({ type = "FreezeTime", on = true }) -- นั่งคอม = เวลาหยุด (ตาม design ตัดคลิป freeze)

	local state = deps.getState()
	local style = STYLES[math.clamp(state and state.phase or 1, 1, 3)]

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_PCScreen"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local bezel = Instance.new("Frame") -- กรอบเครื่อง
	bezel.Size = UDim2.new(1, 0, 1, 0)
	bezel.BackgroundColor3 = style.bezel
	bezel.Parent = gui

	if style.neon then -- ขอบ RGB เฟส 3
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = Color3.fromRGB(120, 80, 255)
		stroke.Parent = bezel
	end

	local screen = Instance.new("Frame") -- จอใน
	screen.Position = UDim2.new(style.inset, 0, style.inset, 0)
	screen.Size = UDim2.new(1 - style.inset * 2, 0, 1 - style.inset * 2, 0)
	screen.BackgroundColor3 = style.wall
	screen.Parent = bezel

	local deviceLabel = Instance.new("TextLabel")
	deviceLabel.Size = UDim2.new(0, 260, 0, 28)
	deviceLabel.Position = UDim2.new(0.5, -130, 1, -30)
	deviceLabel.BackgroundTransparency = 1
	deviceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	deviceLabel.TextScaled = true
	deviceLabel.Text = style.deviceName
	deviceLabel.Parent = bezel

	-- host แอปที่เปิดอยู่
	local appFrame = Instance.new("Frame")
	appFrame.Position = UDim2.new(0.22, 0, 0.06, 0)
	appFrame.Size = UDim2.new(0.72, 0, 0.86, 0)
	appFrame.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
	appFrame.Visible = false
	appFrame.Parent = screen
	local ac = Instance.new("UICorner")
	ac.CornerRadius = UDim.new(0, 10)
	ac.Parent = appFrame

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

	-- icon grid ซ้าย
	for i, app in apps do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 150, 0, 44)
		btn.Position = UDim2.new(0, 16, 0, 10 + (i - 1) * 52)
		btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		btn.BackgroundTransparency = 0.25
		btn.TextScaled = true
		btn.Text = app.label
		btn.Parent = screen
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 8)
		bc.Parent = btn
		btn.Activated:Connect(function()
			if app.external then -- เช่น Edit QTE เปิด overlay ของตัวเอง
				app.external()
			else
				openApp(app)
			end
		end)
	end

	-- ปุ่มปิดเครื่อง
	local exit = Instance.new("TextButton")
	exit.Size = UDim2.new(0, 110, 0, 36)
	exit.Position = UDim2.new(1, -126, 0, 10)
	exit.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	exit.TextColor3 = Color3.new(1, 1, 1)
	exit.TextScaled = true
	exit.Text = "⏻ Exit"
	exit.Parent = screen
	exit.Activated:Connect(function()
		deps.fireAction({ type = "FreezeTime", on = false })
		gui:Destroy()
		PCScreen.running = false
	end)

	gui.Parent = playerGui

	-- state ใหม่ → ส่งให้แอปที่เปิดอยู่
	function PCScreen.refresh(newState)
		state = newState
		if PCScreen.running and currentApp and currentApp.refresh then
			currentApp.refresh(newState)
		end
	end
end

return PCScreen
