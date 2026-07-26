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

-- client เริ่มก่อน workspace replicate เสร็จ → ต้องรอ ไม่ใช่ FindFirstChild เฉยๆ
local function scene()
	local r = workspace:FindFirstChild("MenuScene") or workspace:FindFirstChild("MenuScreen")
	if r then return r end
	local t0 = os.clock()
	while os.clock() - t0 < 8 do
		task.wait(0.1)
		r = workspace:FindFirstChild("MenuScene") or workspace:FindFirstChild("MenuScreen")
		if r then return r end
	end
	return nil
end

-- ชื่อสำรองของแต่ละชิ้น: ชื่อตามสเปกก่อน ไม่เจอค่อยเดาจากชื่อที่ทีมตั้งเอง
-- (ทีมปั้นห้องมาก่อนสเปกจะนิ่ง — โค้ดยอมปรับตามของจริง ดีกว่าให้ไปไล่เปลี่ยนชื่อทั้งห้อง)
local ALIAS = {
	pc = { "MenuScreen_PC", "PC", "Monitor", "Computer" },
	book = { "MenuScreen_Book", "Open Book", "Book", "Notebook" },
	setting = { "MenuScreen_Setting", "setting", "Setting", "Settings" },
	credit = { "MenuScreen_Credit", "MenuScreen_Credits", "credit", "Credit", "Credits" },
}
local CAM_ALIAS = {
	home = { "MenuCam_Home" },
	book = { "MenuCam_Book" },
	setting = { "MenuCam_Setting", "MenuCam_Settings" },
	credit = { "MenuCam_Credit", "MenuCam_Credits" },
	launching = { "MenuCam_PC", "MenuCam_Computer" },
}

local function findAny(root, names)
	for _, n in names do
		local f = root:FindFirstChild(n, true)
		if f then return f end
	end
	return nil
end

-- หน้าจอที่ใช้แปะ UI = BasePart ที่มี "หน้ากว้างสุด" ในกลุ่มนั้น
-- (ถ้าชี้มาที่ Model เช่น PC หรือ Open Book ก็ไล่หาชิ้นที่เป็นจอ/หน้ากระดาษให้เอง)
local function faceAreas(p)
	local s = p.Size
	return {
		{ Enum.NormalId.Front, s.X * s.Y }, { Enum.NormalId.Back, s.X * s.Y },
		{ Enum.NormalId.Left, s.Z * s.Y }, { Enum.NormalId.Right, s.Z * s.Y },
		{ Enum.NormalId.Top, s.X * s.Z }, { Enum.NormalId.Bottom, s.X * s.Z },
	}
end

local function biggestFaceArea(p)
	local best = 0
	for _, f in faceAreas(p) do best = math.max(best, f[2]) end
	return best
end

local function screenPartOf(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst end
	local best, bestArea = nil, -1
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			local a = biggestFaceArea(d)
			if a > bestArea then best, bestArea = d, a end
		end
	end
	return best
end

-- หน้าไหนของ Part ที่หันเข้าหากล้อง (ทีมหมุน Part ทางไหนก็ได้ โค้ดหาเอง)
local function faceToward(part, camPos)
	local toCam = (camPos - part.Position)
	if toCam.Magnitude < 1e-3 then return Enum.NormalId.Front end
	toCam = toCam.Unit
	local best, bestScore = Enum.NormalId.Front, -math.huge
	for _, f in faceAreas(part) do
		local n = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(f[1]))
		-- เอาหน้าที่ทั้ง "หันเข้าหากล้อง" และ "กว้าง" (กันเลือกขอบบางๆ ของจอ)
		local score = n:Dot(toCam) * f[2]
		if score > bestScore then best, bestScore = f[1], score end
	end
	return best
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
local function tweenCamTo(holder, goalCF, time: number)
	if not goalCF then return end
	TweenService:Create(holder, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = goalCF }):Play()
end

-- ★ ไม่แปะ SurfaceGui บนของที่ทีมปั้นตรงๆ — สร้าง "แผ่น canvas ล่องหน" ลอยหน้าของแทน
-- เหตุผล: ของจริงเป็น MeshPart/Model หมุนมั่วทางไหนก็ได้ เดาว่าหน้าไหนคือหน้าที่เห็นไม่ได้ 100%
-- และผิวจริงของ mesh มักนูนกว่ากล่อง bounding box ทำให้ UI จมหายเข้าไปในเนื้อโมเดล
-- แผ่นลอยหน้า = หันเข้ากล้องเป๊ะเสมอ ตัวหนังสือตั้งตรงเสมอ ไม่ว่าทีมจะวางของท่าไหน
-- camCF = CFrame ของกล้อง "ตอนดูหน้านั้นจริงๆ" (ผ่าน cfOf แล้ว = ไม่มี roll)
-- ห้ามส่ง CFrame ของ Part กล้องดิบๆ มา — ทีมหมุน Part เอียงได้ ตัวหนังสือจะเอียงตาม
local function makeCanvas(target, camCF, playerGui, name, marginScale)
	if not target or not camCF then return nil end
	local center, size
	if target:IsA("BasePart") then
		center, size = target.Position, target.Size
	else
		local cf, s = target:GetBoundingBox()
		center, size = cf.Position, s
	end

	local n = (camCF.Position - center)
	if n.Magnitude < 1e-3 then return nil end
	local dist = n.Magnitude
	n = n.Unit

	-- ใช้หน้า Front + CFrame.lookAt เหมือน PCScreen: LookVector = หน้าจอ, +Y = ด้านบน canvas
	-- (หน้า Top เคยลองแล้ว mapping ของ canvas ไม่ตรงกับที่คิด ตัวหนังสือหมุน 90°)
	-- ใช้แกน Y ของโลกเป็น "ด้านบน" ไม่ใช่ UpVector ของ Part กล้อง — ทีมหมุน Part เอียงได้
	local up = camCF.UpVector -- ด้านบนของภาพที่ผู้เล่นเห็นจริง (กล้องมองก้ม/เงยเท่าไหร่ก็ตรงเสมอ)
	local pos = center + n * math.min(0.15, dist * 0.15)
	local cf = CFrame.lookAt(pos, pos + n, up)

	-- ขนาดแผ่น = 2 ด้านที่ใหญ่สุดของของชิ้นนั้น (เรียงมาก→น้อย)
	local dims = { size.X, size.Y, size.Z }
	table.sort(dims, function(a, b) return a > b end)
	local h, w = dims[1], dims[2]
	local m = marginScale or 0.92

	local p = Instance.new("Part")
	p.Name = "MenuCanvas_" .. name
	p.Size = Vector3.new(w * m, h * m, 0.05)
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Parent = workspace

	local sg = Instance.new("SurfaceGui")
	sg.Name = name
	sg.Adornee = p
	sg.Face = Enum.NormalId.Front
	-- canvas ยาว ~1000 px เสมอ (ของชิ้นเล็กอย่างสมุดถ้าใช้ 250 คงที่ ตัวหนังสือจะเละ)
	sg.PixelsPerStud = math.clamp(1000 / math.max(p.Size.X, p.Size.Y, 0.1), 100, 2000)
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.LightInfluence = 0
	sg.AlwaysOnTop = false
	sg.Active = true
	sg.ResetOnSpawn = false
	sg.Parent = playerGui
	sg:SetAttribute("CanvasPart", true)
	return sg, p
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
		warn("[MenuUI] " .. (root and "ห้องเมนูไม่มี MenuCam_Home (ตั้ง ModelStreamingMode = Persistent หรือยัง?)"
			or "ไม่มี Workspace.MenuScene / MenuScreen") .. " — ใช้เมนูปุ่มลอยแทน (docs/05 §3.7)")
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

	-- ซ่อน HUD + วงโซนถ่าย ระหว่างอยู่ในเมนู (ไม่งั้นลอยทับฉาก)
	local hud = playerGui:FindFirstChild("Gui_HUD")
	if hud then hud.Enabled = false end
	local ring = workspace:FindFirstChild("FilmZoneRing")
	if ring then
		ring.Transparency = 1
		for _, b in ring:GetDescendants() do
			if b:IsA("BillboardGui") then b.Enabled = false end
		end
	end

	-- ===== หาของในห้อง (ยอมรับทั้งชื่อตามสเปกและชื่อที่ทีมตั้งเอง) =====
	local pcScreen = screenPartOf(findAny(root, ALIAS.pc))
	local bookPart = screenPartOf(findAny(root, ALIAS.book))
	local setPart = screenPartOf(findAny(root, ALIAS.setting))
	local credPart = screenPartOf(findAny(root, ALIAS.credit))

	local camParts = {}
	for key, names in CAM_ALIAS do camParts[key] = findAny(root, names) end

	-- ไม่มี Part กล้องหน้าจอคอม → คำนวณเอง: ลอยหน้าจอพอดีเฟรม (ทีมไม่ต้องวางเพิ่ม)
	local pcCamCF = nil
	if not camParts.launching and pcScreen then
		local face = faceToward(pcScreen, (camParts.home or home).Position)
		local n = pcScreen.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face))
		local span = math.max(pcScreen.Size.X, pcScreen.Size.Y, pcScreen.Size.Z)
		local dist = (span / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.1
		local eye = pcScreen.Position + n * dist
		pcCamCF = CFrame.lookAt(eye, pcScreen.Position)
	end

	local function camCFFor(screenName)
		local p = camParts[screenName]
		if p then return cfOf(p) end
		if screenName == "launching" and pcCamCF then return pcCamCF end
		return cfOf(camParts.home or home)
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
	back.Name = "Btn_Back"
	back.Visible = false

	gui.Parent = playerGui

	-- ===== SurfaceGui บนของจริง =====
	local canvasParts = {}
	local function canvasFor(target, screenKey, name)
		local sg, p = makeCanvas(target, camCFFor(screenKey), playerGui, name)
		if p then table.insert(canvasParts, p) end
		return sg
	end
	local bookGui = canvasFor(findAny(root, ALIAS.book), "book", "Gui_MenuBook")
	local setGui = canvasFor(setPart, "setting", "Gui_MenuSetting")
	local credGui = canvasFor(credPart, "credit", "Gui_MenuCredit")
	local pcPart = pcScreen

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
		-- ทุกตำแหน่งเป็น scale ล้วน: ของแต่ละชิ้นในห้องสัดส่วนไม่เท่ากัน
		-- (สมุดเป็น MeshPart แนวตั้ง จอเป็นแนวนอน) ใช้ pixel ตายตัวแล้วจะหลุดกรอบ
		local head = Instance.new("TextLabel")
		head.Size = UDim2.new(0.9, 0, 0.1, 0)
		head.Position = UDim2.new(0.05, 0, 0.02, 0)
		head.BackgroundTransparency = 1
		head.TextColor3 = Color3.fromRGB(40, 35, 30)
		head.TextScaled = true
		head.Text = "สมุดบันทึก"
		head.Parent = bookGui
		for i = 1, 4 do
			local b = textButton(bookGui, MenuUI.slotLine(i, nil),
				UDim2.new(0.05, 0, 0.15 + (i - 1) * 0.2, 0), UDim2.new(0.9, 0, 0.17, 0),
				Color3.fromRGB(245, 240, 225))
			b.TextColor3 = Color3.fromRGB(40, 35, 30)
			b.BackgroundTransparency = 0.1
			slotBtns[i] = b
		end
	end

	if credGui then
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(0.9, 0, 0.9, 0)
		l.Position = UDim2.new(0.05, 0, 0.05, 0)
		l.BackgroundTransparency = 1
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextScaled = true
		l.Text = CREDIT_TEXT
		l.Parent = credGui
	end

	if setGui then
		local head = Instance.new("TextLabel")
		head.Size = UDim2.new(0.9, 0, 0.1, 0)
		head.Position = UDim2.new(0.05, 0, 0.03, 0)
		head.BackgroundTransparency = 1
		head.TextColor3 = Color3.new(1, 1, 1)
		head.TextScaled = true
		head.Text = "ตั้งค่า"
		head.Parent = setGui

		local volLabel = Instance.new("TextLabel")
		volLabel.Size = UDim2.new(0.9, 0, 0.08, 0)
		volLabel.Position = UDim2.new(0.05, 0, 0.18, 0)
		volLabel.BackgroundTransparency = 1
		volLabel.TextColor3 = Color3.new(1, 1, 1)
		volLabel.TextScaled = true
		volLabel.Text = ("🔊 เสียง %d%%"):format(math.floor(Audio.getVolume() * 100 + 0.5))
		volLabel.Parent = setGui
		local function vol(text, x, dir)
			local b = textButton(setGui, text, UDim2.new(x, 0, 0.29, 0), UDim2.new(0.4, 0, 0.11, 0))
			b.Activated:Connect(function()
				Audio.setVolume(Audio.getVolume() + dir * 0.1)
				volLabel.Text = ("🔊 เสียง %d%%"):format(math.floor(Audio.getVolume() * 100 + 0.5))
			end)
		end
		vol("⊖", 0.05, -1)
		vol("⊕", 0.55, 1)

		local shadow = textButton(setGui, "", UDim2.new(0.05, 0, 0.45, 0), UDim2.new(0.9, 0, 0.11, 0))
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
		tweenCamTo(camHolder, camCFFor(name), CAM_TIME)
	end
	back.Activated:Connect(function() goto_("home") end)

	-- ===== เข้าเกม: บินเข้าจอ → วาบขาว → ค้าง → เผยเกม =====
	local function launch(action)
		if MenuUI.busy then return end
		MenuUI.busy = true
		homePanel.Visible = false
		back.Visible = false
		showSurface(nil)
		tweenCamTo(camHolder, camCFFor("launching"), CAM_TIME)

		task.delay(CAM_TIME, function()
			if action then deps.fireAction(action) end
			if pcPart then -- จอสว่างเองด้วย ไม่ใช่แค่แผ่นขาวทับจอผู้เล่น
				local mat, col = pcPart.Material, pcPart.Color
				pcPart.Material = Enum.Material.Neon
				pcPart.Color = Color3.new(1, 1, 1)
				-- คืนสภาพจอหลังวาบจบ (เป็นของที่ทีมปั้น ห้ามทิ้งไว้ขาวถาวร)
				task.delay(FLASH_IN + FLASH_HOLD + FLASH_OUT, function()
					if pcPart.Parent then
						pcPart.Material, pcPart.Color = mat, col
					end
				end)
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
				if ring then
					ring.Transparency = 0.7
					for _, b in ring:GetDescendants() do
						if b:IsA("BillboardGui") then b.Enabled = true end
					end
				end
				deps.fireAction({ type = "FreezeTime", on = false })
				MenuUI.running = false
				MenuUI.updateSlots = nil
				if bookGui then bookGui:Destroy() end
				if setGui then setGui:Destroy() end
				if credGui then credGui:Destroy() end
				for _, p in canvasParts do p:Destroy() end

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
	continueBtn.Name = "Btn_Continue"
	continueBtn.Parent = homePanel
	continueBtn.Activated:Connect(function()
		launch(latest and { type = "LoadSlot", slot = latest } or { type = "NewGame", slot = 1 })
	end)
	local function navBtn(label, y, target)
		local b = textButton(homePanel, label, UDim2.new(0, 40, 0, y), UDim2.new(0, 340, 0, 62))
		b.Name = "Btn_" .. target
		b.Activated:Connect(function() goto_(target) end)
	end
	navBtn("📖 สมุดบันทึก (โหลดเซฟ)", 284, "book")
	navBtn("⚙️ ตั้งค่า", 358, "setting")
	navBtn("👥 เครดิต", 432, "credit")

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
