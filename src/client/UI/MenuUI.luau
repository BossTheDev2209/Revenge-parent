-- MenuUI.luau — Main Menu แบบ "ฉากจริง": กล้องบินไปหาของในห้อง ไม่ใช่ปุ่มลอยบนพื้นดำ
-- แผนเต็ม: plans/2026-07-27-menu-scene.md | ของที่ทีมต้องปั้น: docs/05 §3.7
--
--   เล่นต่อ  → บินเข้าจอคอม → จอสว่างวาบขาว → ค้าง ~2.4 วิ → เข้าเกม
--   โหลดเซฟ → บินลงสมุดบนโต๊ะ (ลายมือ 4 ช่อง) → เลือก → บินต่อเข้าจอคอม → วาบ → เข้าเกม
--   ตั้งค่า / เครดิต → บินไปโปสเตอร์บนผนัง
--
-- ไม่มี Workspace.MenuScene = ตกกลับเป็นเมนูปุ่มลอยแบบเดิม (เกมต้องเข้าได้เสมอ)
local isStudio = script ~= nil

local MenuUI = {}

local CREDIT_TEXT = "ทีมหอยทากเทอร์โบ28\nรณกร ขันสำรอง | วรกร วิรามวิทวัส | ฉันทัช อัศวชนานนท์\nMUICT-AST Tech Competition 2569"

-- ===== pure (เทสด้วย lune) =====

-- หน้าไหน → Part กล้องชื่ออะไร (ทีมขยับ Part = มุมเปลี่ยน ไม่ต้องแตะโค้ด)
local SCREEN_CAM = {
	home = "MenuCam_Home",
	book = "MenuCam_Book",
	setting = "MenuCam_Setting",
	credit = "MenuCam_Credit",
	launching = "MenuCam_PC",
}

function MenuUI.camFor(screen: string): string
	return SCREEN_CAM[screen] or SCREEN_CAM.home
end

-- ข้อความในสมุด 1 บรรทัด (ช่องว่าง = ยังไม่เขียน)
function MenuUI.slotLine(i: number, sum): string
	if not sum then
		return ("หน้า %d — ยังว่าง  (เริ่มเขียนใหม่)"):format(i)
	end
	return ("หน้า %d — วันที่ %d · %s follower · เฟส %d"):format(i, sum.day, tostring(sum.follower), sum.phase)
end

-- ช่องที่เซฟล่าสุด (ปุ่ม "เล่นต่อ" ใช้ช่องนี้) — ไม่มี save เลยคืน nil
function MenuUI.latestSlot(slots)
	local best, bestAt = nil, -1
	for i = 1, 4 do
		local s = slots and slots[i]
		if s and (s.savedAt or 0) > bestAt then
			best, bestAt = i, s.savedAt or 0
		end
	end
	return best
end

-- ===== Roblox glue =====

if not isStudio then return MenuUI end

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Audio = require(script.Parent.Parent.AudioService)
local UIAssets = require(game:GetService("ReplicatedStorage").Shared.UIAssets)

local CAM_TIME = 1.2
local FLASH_IN, FLASH_HOLD, FLASH_OUT = 0.35, 2.4, 0.6

local function scene()
	return workspace:FindFirstChild("MenuScene")
end

-- ล็อกตัวละครไว้ระหว่างอยู่ในเมนู (ไม่งั้นเดินได้ตั้งแต่ยังไม่กดเล่น)
local function freezeCharacter(player, on: boolean)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = on and 0 or 16
		hum.JumpPower = on and 0 or 50
	end
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = on and 1 or 0
		end
	end
end

local function cfOf(part)
	return CFrame.lookAt(part.Position, part.Position + part.CFrame.LookVector)
end

-- tween ใส่ CFrameValue ไม่ใช่ camera ตรงๆ — camGuard เป็นคนคัดลอกลงกล้องทุกเฟรม
-- (ถ้า tween ลงกล้องตรงๆ default camera script ของ Roblox จะเขียนทับตอนตัวละครเกิด)
local function tweenCamTo(holder, part, time: number)
	if not part then return end
	TweenService:Create(holder, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = cfOf(part) }):Play()
end

local function surfaceOn(part, playerGui, name)
	if not part then return nil end
	local sg = Instance.new("SurfaceGui")
	sg.Name = name
	sg.Adornee = part
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 250
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.LightInfluence = 0
	sg.Active = true
	sg.ResetOnSpawn = false
	sg.Parent = playerGui
	return sg
end

local function textButton(parent, text, pos, size, color)
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = color or Color3.fromRGB(30, 30, 45)
	b.BackgroundTransparency = 0.15
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.Text = text
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = b
	return b
end

-- deps = { fireAction = fn } — เปิดค้างจนกดเริ่มเล่น (เวลาถูก freeze ไว้)
function MenuUI.open(playerGui, deps)
	deps.fireAction({ type = "FreezeTime", on = true })
	deps.fireAction({ type = "RequestSlots" })

	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local root = scene()
	-- ⚠️ StreamingEnabled: ห้องเมนูอยู่ไกลจากตัวผู้เล่น ถ้าไม่ตั้ง ModelStreamingMode = Persistent
	-- client จะได้แต่ Model เปล่าๆ ไม่มี Part ข้างใน (docs/05 §3.7)
	local home = root and root:WaitForChild("MenuCam_Home", 5)
	if not root or not home then
		warn("[MenuUI] " .. (root and "MenuScene ไม่มี MenuCam_Home (ตั้ง ModelStreamingMode = Persistent หรือยัง?)"
			or "ไม่มี Workspace.MenuScene") .. " — ใช้เมนูปุ่มลอยแทน (docs/05 §3.7)")
		return MenuUI.openFallback(playerGui, deps)
	end

	local savedCam = { cf = camera.CFrame, type = camera.CameraType }
	camera.CameraType = Enum.CameraType.Scriptable
	local camHolder = Instance.new("CFrameValue")

	-- default camera script ของ Roblox แย่งกล้องคืนทุกครั้งที่ตัวละครเกิด
	-- → ยึดทั้ง CameraType และ CFrame ทุกเฟรม + ซ่อนตัวละครไปด้วย (transparency ก็โดน reset)
	local camGuard = RunService.RenderStepped:Connect(function()
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = camHolder.Value
		local char = player.Character
		if char then
			for _, d in char:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 1 end
			end
		end
	end)
	freezeCharacter(player, true)
	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		if MenuUI.running then freezeCharacter(player, true) end
	end)
	MenuUI.running = true
	MenuUI.busy = false

	-- ซ่อน HUD ระหว่างอยู่ในเมนู (ไม่งั้นหลอดใจ/ตัวเลขลอยทับฉาก)
	local hud = playerGui:FindFirstChild("Gui_HUD")
	if hud then hud.Enabled = false end

	local function part(name)
		return root:FindFirstChild(name, true)
	end
	camHolder.Value = cfOf(home)
	camera.CFrame = camHolder.Value

	-- ===== ScreenGui: ปุ่มหลัก (หน้า home) + ปุ่มย้อนกลับ + แผ่นวาบขาว =====
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_MainMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10

	local homePanel = Instance.new("Frame")
	homePanel.Size = UDim2.new(0, 420, 1, 0)
	homePanel.BackgroundTransparency = 1
	homePanel.Parent = gui

	-- โลโก้ถ้ามีรูป ไม่มีก็ใช้ตัวหนังสือ
	local title
	if UIAssets.menu_logo ~= "" then
		title = Instance.new("ImageLabel")
		title.Image = UIAssets.menu_logo
		title.ScaleType = Enum.ScaleType.Fit
		title.BackgroundTransparency = 1
	else
		title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.TextColor3 = Color3.new(1, 1, 1)
		title.TextStrokeTransparency = 0.3
		title.TextScaled = true
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "Getting 1M Follower\nto Prove Parent Wrong"
	end
	title.Size = UDim2.new(1, -40, 0, 110)
	title.Position = UDim2.new(0, 40, 0, 70)
	title.Parent = homePanel

	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.Visible = false
	flash.ZIndex = 50
	flash.Parent = gui

	local back = textButton(gui, "◀ ย้อนกลับ", UDim2.new(0, 40, 1, -80), UDim2.new(0, 200, 0, 52),
		Color3.fromRGB(60, 60, 80))
	back.Visible = false

	gui.Parent = playerGui

	-- ===== SurfaceGui บนของจริง =====
	local bookGui = surfaceOn(part("MenuScreen_Book"), playerGui, "Gui_MenuBook")
	local setGui = surfaceOn(part("MenuScreen_Setting"), playerGui, "Gui_MenuSetting")
	local credGui = surfaceOn(part("MenuScreen_Credit"), playerGui, "Gui_MenuCredit")
	local pcPart = part("MenuScreen_PC")

	local slotBtns = {}
	if bookGui then
		local paper = UIAssets.book_page
		if paper ~= "" then -- texture กระดาษ (ไม่มีก็ปล่อยเป็นสีพื้นของ Part)
			local img = Instance.new("ImageLabel")
			img.Size = UDim2.new(1, 0, 1, 0)
			img.BackgroundTransparency = 1
			img.Image = paper
			img.ScaleType = Enum.ScaleType.Crop
			img.Parent = bookGui
		end
		local head = Instance.new("TextLabel")
		head.Size = UDim2.new(1, -40, 0, 90)
		head.Position = UDim2.new(0, 20, 0, 10)
		head.BackgroundTransparency = 1
		head.TextColor3 = Color3.fromRGB(40, 35, 30)
		head.TextScaled = true
		head.Text = "สมุดบันทึก"
		head.Parent = bookGui
		for i = 1, 4 do
			local b = textButton(bookGui, MenuUI.slotLine(i, nil),
				UDim2.new(0, 20, 0, 100 + (i - 1) * 110), UDim2.new(1, -40, 0, 96),
				Color3.fromRGB(245, 240, 225))
			b.TextColor3 = Color3.fromRGB(40, 35, 30)
			b.BackgroundTransparency = 0.1
			slotBtns[i] = b
		end
	end

	if credGui then
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -40, 1, -40)
		l.Position = UDim2.new(0, 20, 0, 20)
		l.BackgroundTransparency = 1
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextScaled = true
		l.Text = CREDIT_TEXT
		l.Parent = credGui
	end

	if setGui then
		local head = Instance.new("TextLabel")
		head.Size = UDim2.new(1, -40, 0, 80)
		head.Position = UDim2.new(0, 20, 0, 10)
		head.BackgroundTransparency = 1
		head.TextColor3 = Color3.new(1, 1, 1)
		head.TextScaled = true
		head.Text = "ตั้งค่า"
		head.Parent = setGui

		local volLabel = Instance.new("TextLabel")
		volLabel.Size = UDim2.new(1, -40, 0, 60)
		volLabel.Position = UDim2.new(0, 20, 0, 100)
		volLabel.BackgroundTransparency = 1
		volLabel.TextColor3 = Color3.new(1, 1, 1)
		volLabel.TextScaled = true
		volLabel.Text = ("🔊 เสียง %d%%"):format(math.floor(Audio.getVolume() * 100 + 0.5))
		volLabel.Parent = setGui
		local function vol(text, x, dir)
			local b = textButton(setGui, text, UDim2.new(0, x, 0, 165), UDim2.new(0, 90, 0, 70))
			b.Activated:Connect(function()
				Audio.setVolume(Audio.getVolume() + dir * 0.1)
				volLabel.Text = ("🔊 เสียง %d%%"):format(math.floor(Audio.getVolume() * 100 + 0.5))
			end)
		end
		vol("⊖", 20, -1)
		vol("⊕", 130, 1)

		local shadow = textButton(setGui, "", UDim2.new(0, 20, 0, 255), UDim2.new(1, -40, 0, 70))
		local function shadowText()
			shadow.Text = "🌓 เงา: " .. (game:GetService("Lighting").GlobalShadows and "เปิด" or "ปิด")
		end
		shadowText()
		shadow.Activated:Connect(function()
			local L = game:GetService("Lighting")
			L.GlobalShadows = not L.GlobalShadows
			shadowText()
		end)
	end

	local function showSurface(which)
		if bookGui then bookGui.Enabled = which == "book" end
		if setGui then setGui.Enabled = which == "setting" end
		if credGui then credGui.Enabled = which == "credit" end
	end
	showSurface(nil)

	-- ===== เปลี่ยนหน้า =====
	local screen = "home"
	local function goto_(name)
		if MenuUI.busy then return end
		screen = name
		homePanel.Visible = name == "home"
		back.Visible = name ~= "home"
		showSurface(name)
		tweenCamTo(camHolder, part(MenuUI.camFor(name)), CAM_TIME)
	end
	back.Activated:Connect(function() goto_("home") end)

	-- ===== เข้าเกม: บินเข้าจอ → วาบขาว → ค้าง → เผยเกม =====
	local function launch(action)
		if MenuUI.busy then return end
		MenuUI.busy = true
		homePanel.Visible = false
		back.Visible = false
		showSurface(nil)
		tweenCamTo(camHolder, part("MenuCam_PC"), CAM_TIME)

		task.delay(CAM_TIME, function()
			if action then deps.fireAction(action) end
			if pcPart then -- จอสว่างเองด้วย ไม่ใช่แค่แผ่นขาวทับจอผู้เล่น
				pcPart.Material = Enum.Material.Neon
				pcPart.Color = Color3.new(1, 1, 1)
			end
			flash.Visible = true
			TweenService:Create(flash, TweenInfo.new(FLASH_IN), { BackgroundTransparency = 0 }):Play()

			task.delay(FLASH_IN + FLASH_HOLD, function()
				-- คืนกล้อง/ตัวละคร "ใต้ผ้าขาว" แล้วค่อยเปิดเผย
				camGuard:Disconnect()
				-- คืนกล้องให้ default camera script: ต้องตั้ง CameraSubject ด้วย
				-- ไม่งั้นกล้องค้างอยู่กลางอากาศ ไม่ตามตัวผู้เล่น
				local char = player.Character or player.CharacterAdded:Wait()
				local hum = char:FindFirstChildOfClass("Humanoid")
				camera.CameraSubject = hum or char:FindFirstChild("HumanoidRootPart")
				camera.CameraType = Enum.CameraType.Custom
				freezeCharacter(player, false)
				if hud then hud.Enabled = true end
				deps.fireAction({ type = "FreezeTime", on = false })
				MenuUI.running = false
				MenuUI.updateSlots = nil
				if bookGui then bookGui:Destroy() end
				if setGui then setGui:Destroy() end
				if credGui then credGui:Destroy() end

				local out = TweenService:Create(flash, TweenInfo.new(FLASH_OUT), { BackgroundTransparency = 1 })
				out:Play()
				out.Completed:Connect(function() gui:Destroy() end)
			end)
		end)
	end

	-- ===== ปุ่มหน้า home =====
	local latest = nil
	local continueBtn = textButton(homePanel, "▶ เล่นต่อ", UDim2.new(0, 40, 0, 210), UDim2.new(0, 340, 0, 62),
		Color3.fromRGB(45, 95, 175))
	continueBtn.Parent = homePanel
	continueBtn.Activated:Connect(function()
		launch(latest and { type = "LoadSlot", slot = latest } or { type = "NewGame", slot = 1 })
	end)
	textButton(homePanel, "📖 สมุดบันทึก (โหลดเซฟ)", UDim2.new(0, 40, 0, 284), UDim2.new(0, 340, 0, 62))
		.Activated:Connect(function() goto_("book") end)
	textButton(homePanel, "⚙️ ตั้งค่า", UDim2.new(0, 40, 0, 358), UDim2.new(0, 340, 0, 62))
		.Activated:Connect(function() goto_("setting") end)
	textButton(homePanel, "👥 เครดิต", UDim2.new(0, 40, 0, 432), UDim2.new(0, 340, 0, 62))
		.Activated:Connect(function() goto_("credit") end)

	for i = 1, 4 do
		local b = slotBtns[i]
		if b then
			b.Activated:Connect(function()
				local has = b:GetAttribute("HasSave")
				launch(has and { type = "LoadSlot", slot = i } or { type = "NewGame", slot = i })
			end)
		end
	end

	-- state ใหม่มา (หลัง RequestSlots) → เขียนลงสมุด
	function MenuUI.updateSlots(state)
		if not MenuUI.running then return end
		local slots = state.slotList
		if not slots then return end
		latest = MenuUI.latestSlot(slots)
		continueBtn.Text = latest and ("▶ เล่นต่อ (หน้า %d)"):format(latest) or "▶ เริ่มเรื่องใหม่"
		for i = 1, 4 do
			local b = slotBtns[i]
			if b then
				b.Text = MenuUI.slotLine(i, slots[i])
				b:SetAttribute("HasSave", slots[i] ~= nil)
			end
		end
	end
end

-- ===== fallback: ไม่มี MenuScene ในแมพ (เกมต้องเข้าได้เสมอ) =====
function MenuUI.openFallback(playerGui, deps)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_MainMenu"
	gui.ResetOnSpawn = false
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	bg.Parent = gui
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 80)
	title.Position = UDim2.new(0, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Text = "Getting 1M Follower\nto Prove Parent Wrong"
	title.Parent = bg
	gui.Parent = playerGui

	local btns, latest = {}, nil
	local function startGame(action)
		if action then deps.fireAction(action) end
		deps.fireAction({ type = "FreezeTime", on = false })
		MenuUI.updateSlots = nil
		gui:Destroy()
	end
	local continueBtn = textButton(bg, "เล่นต่อ", UDim2.new(0.5, -160, 0, 130), UDim2.new(0, 320, 0, 48),
		Color3.fromRGB(45, 95, 175))
	continueBtn.Activated:Connect(function()
		startGame(latest and { type = "LoadSlot", slot = latest } or { type = "NewGame", slot = 1 })
	end)
	for i = 1, 4 do
		local b = textButton(bg, MenuUI.slotLine(i, nil), UDim2.new(0.5, -160, 0, 130 + i * 56),
			UDim2.new(0, 320, 0, 48))
		b.Activated:Connect(function()
			startGame(b:GetAttribute("HasSave") and { type = "LoadSlot", slot = i } or { type = "NewGame", slot = i })
		end)
		btns[i] = b
	end
	local credLabel = Instance.new("TextLabel")
	credLabel.Size = UDim2.new(0, 500, 0, 90)
	credLabel.Position = UDim2.new(0.5, -250, 1, -110)
	credLabel.BackgroundTransparency = 0.4
	credLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	credLabel.TextColor3 = Color3.new(1, 1, 1)
	credLabel.TextScaled = true
	credLabel.Text = CREDIT_TEXT
	credLabel.Parent = bg

	function MenuUI.updateSlots(state)
		local slots = state.slotList
		if not slots or not gui.Parent then return end
		latest = MenuUI.latestSlot(slots)
		continueBtn.Text = latest and ("เล่นต่อ (หน้า %d)"):format(latest) or "เริ่มเรื่องใหม่"
		for i = 1, 4 do
			btns[i].Text = MenuUI.slotLine(i, slots[i])
			btns[i]:SetAttribute("HasSave", slots[i] ~= nil)
		end
	end
end

return MenuUI
