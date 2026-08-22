-- MenuUI — Main Menu แบบ "ฉากจริง": กล้องบินไปหาของในห้อง
--   เล่นต่อ → บินเข้าจอคอม → วาบขาว → เข้าเกม · โหลดเซฟ → สมุดบนโต๊ะ → เลือก → จอคอม
--   ตั้งค่า/เครดิต → โปสเตอร์บนผนัง · ไม่มี Workspace.MenuScene = ตกกลับเมนูปุ่มลอย (openFallback)
local isStudio = script ~= nil

local MenuUI = {}

local CREDIT_TEXT = "ทีมหอยทากเทอร์โบ28\nรณกร ขันสำรอง | วรกร วิรามวิทวัส | ฉันทัช อัศวชนานนท์\nMUICT-AST Tech Competition 2569"

-- หน้าไหน → Part กล้องชื่ออะไร (ทีมขยับ Part = มุมเปลี่ยน ไม่ต้องแตะโค้ด)
local SCREEN_CAM = {
	home = "MenuCam_Home",
	book = "MenuCam_Book",
	setting = "MenuCam_Setting",
	credit = "MenuCam_Credits",
	launching = "MenuCam_PC",
}

function MenuUI.camFor(screen: string): string
	return SCREEN_CAM[screen] or SCREEN_CAM.home
end

-- ข้อความในสมุด 1 บรรทัด (ว่าง = ยังไม่เขียน)
function MenuUI.slotLine(i: number, sum): string
	if not sum then
		return ("Page %d — empty  (start new)"):format(i)
	end
	return ("Page %d — Day %d · %s followers · Phase %d"):format(i, sum.day, tostring(sum.follower), sum.phase)
end

-- ช่องที่เซฟล่าสุด (ปุ่มเล่นต่อใช้ช่องนี้) — ไม่มี save = nil
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

-- เมนูออกแบบพอดีจอสูง ~580px · จอเตี้ยกว่าต้องหดทั้งแผง (scale ทั้งชุด ไม่คำนวณ pixel ทีละปุ่ม)
local MENU_DESIGN = {
	panelWidth = 420,
	topPad = 280, -- ที่ว่างเหนือปุ่มแรก (GuiInset บวกเพิ่มตอน glue — pure fn แตะ GuiService ไม่ได้)
	buttonHeight = 62,
	buttonGap = 12,
	buttonCount = 4,
	refHeight = 580, -- ความสูงจอที่ตัวเลขข้างบนพอดี ไม่ต้องหด
	minScale = 0.6,
}

-- สัดส่วนภาพจริงของ menu_logo = 1024×576 (16:9) · ใช้คำนวณกรอบ title ให้ตรงเป๊ะ
-- (กรอบเกินสัดส่วนภาพ = ScaleType.Fit จัดกลางให้ โลโก้ลอยกลางจอ)
local TITLE_ASPECT = 1024 / 576

-- viewport {X,Y} → ตัวเลข layout ล้วน (lune เทสได้)
function MenuUI.layout(viewport)
	local scale = math.clamp(viewport.Y / MENU_DESIGN.refHeight, MENU_DESIGN.minScale, 1)
	local stackHeight = MENU_DESIGN.buttonCount * MENU_DESIGN.buttonHeight
		+ (MENU_DESIGN.buttonCount - 1) * MENU_DESIGN.buttonGap
	return {
		scale = scale,
		panelWidth = MENU_DESIGN.panelWidth * scale,
		topPad = MENU_DESIGN.topPad,
		stackHeight = stackHeight,
		buttonHeight = MENU_DESIGN.buttonHeight,
		buttonGap = MENU_DESIGN.buttonGap,
	}
end

if not isStudio then return MenuUI end

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Audio = require(script.Parent.Parent.AudioService)
local UIAssets = require(game:GetService("ReplicatedStorage").Shared.UIAssets)
local PreloadService = require(script.Parent.Parent.PreloadService)

local CAM_TIME = 1.2
local FLASH_IN, FLASH_HOLD, FLASH_OUT = 0.35, 2.4, 0.6

-- ชื่อของจริงในห้องเมนู — ชื่อเดียว ไม่มีเดา (เปลี่ยนใน Studio แล้วมาแก้ตารางนี้ · พังดังๆ ดีกว่าหยิบผิด)
local SCENE = "MenuScreen"
local CLICK = { -- ของที่กดได้ (ลูกของ MenuScreen)
	pc = "PC",
	book = "OpenBook",
	setting = "setting",
	credit = "credit",
}
local CAM = { -- Part มุมกล้อง (ลูกของ MenuScreen)
	home = "MenuCam_Home",
	book = "MenuCam_Book",
	setting = "MenuCam_Setting",
	credit = "MenuCam_Credits",
	launching = "MenuCam_PC", -- ⚠️ ยังไม่มีในห้อง — ไม่มี = ตอนกด PC กล้องอยู่ที่เดิม
}

-- client เริ่มก่อน workspace replicate เสร็จ → ต้องรอ
local function scene()
	local r = workspace:FindFirstChild(SCENE)
	if r then return r end
	local t0 = os.clock()
	while os.clock() - t0 < 8 do
		task.wait(0.1)
		r = workspace:FindFirstChild(SCENE)
		if r then return r end
	end
	return nil
end

local function findExact(root, name: string)
	local f = root:FindFirstChild(name)
	if not f then
		warn(("[MenuUI] ไม่เจอ Workspace.%s.%s — ตรวจชื่อใน Studio หรือแก้ตาราง CLICK/CAM ใน MenuUI")
			:format(SCENE, name))
	end
	return f
end

-- หน้าจอที่ใช้แปะ UI = BasePart ที่มีหน้ากว้างสุดในกลุ่ม (ชี้มาที่ Model = ไล่หาชิ้นที่เป็นจอ/หน้ากระดาษ)
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

-- หน้าไหนของ Part หันเข้าหากล้อง (ทีมหมุน Part ทางไหนก็ได้ โค้ดหาเอง)
local function faceToward(part, camPos)
	local toCam = (camPos - part.Position)
	if toCam.Magnitude < 1e-3 then return Enum.NormalId.Front end
	toCam = toCam.Unit
	local best, bestScore = Enum.NormalId.Front, -math.huge
	for _, f in faceAreas(part) do
		local n = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(f[1]))
		local score = n:Dot(toCam) * f[2] -- หน้าที่ทั้งหันเข้ากล้องและกว้าง (กันเลือกขอบบางๆ)
		if score > bestScore then best, bestScore = f[1], score end
	end
	return best
end

-- ล็อกตัวละครระหว่างอยู่ในเมนู · MoveLocked = บอก SprintHandler อย่ายุ่ง WalkSpeed
local function freezeCharacter(player, on: boolean)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:SetAttribute("MoveLocked", on or nil)
		hum.WalkSpeed = on and 0 or 16
		hum.JumpPower = on and 0 or 50
	end
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = on and 1 or 0
		end
	end
end

-- กล้อง = ตำแหน่ง + ทิศที่ Part หันหน้า · มองตรงลง/ขึ้น lookAt degenerate → ใช้ UpVector ของ Part
local function cfOf(part)
	local look = part.CFrame.LookVector
	local up = math.abs(look.Y) > 0.99 and part.CFrame.UpVector or Vector3.yAxis
	return CFrame.lookAt(part.Position, part.Position + look, up)
end

-- tween ใส่ CFrameValue ไม่ใช่กล้องตรงๆ — camGuard คัดลอกลงกล้องทุกเฟรม
-- (tween ลงกล้องตรงๆ = default camera script ของ Roblox เขียนทับตอนตัวละครเกิด)
local function tweenCamTo(holder, goalCF, time: number)
	if not goalCF then return end
	TweenService:Create(holder, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = goalCF }):Play()
end

-- ไม่แปะ SurfaceGui บนของจริง — สร้าง "แผ่น canvas ล่องหน" ลอยหน้าของแทน (หันเข้ากล้องเป๊ะ ตัวหนังสือตั้งตรง)
-- เหตุผล: ของจริงเป็น MeshPart/Model หมุนทางไหนก็ได้ เดาหน้าที่เห็นไม่ได้ + ผิว mesh นูนกว่ากล่อง UI จมหาย
-- camCF = CFrame กล้องตอนดูหน้านั้นจริง (ผ่าน cfOf แล้ว ไม่มี roll) — ห้ามส่ง CFrame ดิบของ Part กล้อง
local function makeCanvas(target, camCF, playerGui, name, marginScale)
	if not target or not camCF then return nil end
	local boxCF, size
	if target:IsA("BasePart") then
		boxCF, size = target.CFrame, target.Size
	else
		boxCF, size = target:GetBoundingBox()
	end
	local center = boxCF.Position

	local n = (camCF.Position - center)
	if n.Magnitude < 1e-3 then return nil end
	local dist = n.Magnitude
	n = n.Unit

	local up = camCF.UpVector -- ด้านบนของภาพที่ผู้เล่นเห็นจริง (กล้องก้ม/เงยเท่าไหร่ก็ตรง)
	local pos, cf

	-- ขนาดแผ่น = "เงา" ของวัตถุบนแกนขวา/บนของกล้อง — ฉาย 8 มุมของทุก Part ลงแกนกล้องตรงๆ
	-- (แกนโลก/แกน box พลาดทั้งคู่: โปสเตอร์ผนังกับสมุดโต๊ะหมุนคนละแบบ)
	local right = up:Cross(n).Unit
	local parts = {}
	if target:IsA("BasePart") then
		parts[1] = target
	else
		for _, d in target:GetDescendants() do
			if d:IsA("BasePart") then table.insert(parts, d) end
		end
	end
	local minR, maxR, minU, maxU = math.huge, -math.huge, math.huge, -math.huge
	for _, pt in parts do
		local hx, hy, hz = pt.Size.X / 2, pt.Size.Y / 2, pt.Size.Z / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local wp = pt.CFrame * Vector3.new(sx * hx, sy * hy, sz * hz)
					local r, u2 = wp:Dot(right), wp:Dot(up)
					minR, maxR = math.min(minR, r), math.max(maxR, r)
					minU, maxU = math.min(minU, u2), math.max(maxU, u2)
				end
			end
		end
	end
	if minR == math.huge then return nil end
	local w, h = maxR - minR, maxU - minU
	-- จัดกึ่งกลางให้ตรงกับเงาจริง (bounding box อาจเบี้ยวจากชิ้นที่ยื่นออกมา)
	center = center + right * ((minR + maxR) / 2 - center:Dot(right))
		+ up * ((minU + maxU) / 2 - center:Dot(up))
	pos = center + n * math.min(0.15, dist * 0.15)
	cf = CFrame.lookAt(pos, pos + n, up)
	local m = marginScale or 0.92

	local p = Instance.new("Part")
	p.Name = "MenuCanvas_" .. name
	p.Size = Vector3.new(w * m, h * m, 0.05)
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = true -- ต้อง true ไม่งั้นเมาส์ ray ไม่โดน = ปุ่ม SurfaceGui กดไม่ได้
	p.CanTouch = false
	p.Transparency = 1
	p.Parent = workspace

	local sg = Instance.new("SurfaceGui")
	sg.Name = name
	sg.Adornee = p
	sg.Face = Enum.NormalId.Front
	-- canvas ยาว ~1000 px เสมอ (ของเล็กอย่างสมุดถ้าใช้ px คงที่ ตัวหนังสือจะเละ)
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

-- ปุ่มธีม HUD เข้ม · ⚠️ Enum.Font ไม่ใช่ Font.fromName("Mali") (fromName "Temp read failed" ทุก session)
local MENU_FONT = Font.fromEnum(Enum.Font.FredokaOne)
local PANEL_BG = Color3.fromRGB(20, 20, 30)
local PANEL_BG_HOVER = Color3.fromRGB(35, 35, 48)
local TEXT_COLOR = Color3.new(1, 1, 1)
local STROKE_COLOR = Color3.fromRGB(27, 27, 27)

-- rot = องศาเอียง · color param เก่าเลิกใช้ (คง signature กันของพัง)
local function textButton(parent, text, pos, size, _color, rot)
	rot = rot or 0
	local shadow = Instance.new("Frame") -- เงา สร้างก่อน = วาดใต้ปุ่ม
	shadow.Position = pos + UDim2.fromOffset(4, 6)
	shadow.Size = size
	shadow.Rotation = rot
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.72
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = parent
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 12)
	sc.Parent = shadow

	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = size
	b.Rotation = rot
	b.BackgroundColor3 = PANEL_BG
	b.BackgroundTransparency = 0.25
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.TextColor3 = TEXT_COLOR
	b.FontFace = MENU_FONT
	b.TextScaled = true
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Text = text
	b.ZIndex = 1
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = b
	local st = Instance.new("UIStroke")
	st.Color = STROKE_COLOR
	st.Thickness = 1
	st.Transparency = 0
	st.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 20)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = b
	b.MouseEnter:Connect(function() b.BackgroundColor3 = PANEL_BG_HOVER end)
	b.MouseLeave:Connect(function() b.BackgroundColor3 = PANEL_BG end)
	b.Destroying:Connect(function() shadow:Destroy() end) -- ปุ่มหาย เงาหายด้วย
	-- ★ แก้ 10 ส.ค. (user เจอ: แผ่นโปร่งแสงมุมมนลอยค้างมุมจอ) — เงาเป็นคนละ instance กับปุ่ม เดิมไม่มีอะไร
	--   sync ตอน Visible เปลี่ยน (ผูกแค่ตอน Destroy) พอโค้ดสั่ง b.Visible = false (เช่น Btn_Back ตอนอยู่หน้า home)
	--   เงาไม่รู้เรื่อง ค้างโชว์เดี่ยวๆ ทับฉาก
	local function syncShadow() shadow.Visible = b.Visible end
	b:GetPropertyChangedSignal("Visible"):Connect(syncShadow)
	syncShadow()
	return b
end

-- เพลงเมนูตามเฟส: มี Sound "Menu<เฟส>" ใน SoundService.BGM = ใช้ตัวนั้น · ไม่มี = "Menu"
local function resolveMenuBGM(phase: number): string
	local folder = game:GetService("SoundService"):FindFirstChild("BGM")
	local named = "Menu" .. tostring(phase)
	if folder and folder:FindFirstChild(named) then return named end
	return "Menu"
end

-- รายละเอียดในห้องเปลี่ยนตามเฟส: instance ที่ตั้ง attribute ShowPhase = n โผล่เฉพาะเซฟถึงเฟส n ขึ้นไป
-- ponytail: ซ่อนทางเดียว (ไม่ toggle กลับ) — เมนูเปิดครั้งเดียวต่อ session ตามเฟสของเซฟ
local function hideTree(inst: Instance)
	local function h(o)
		if o:IsA("BasePart") or o:IsA("Decal") or o:IsA("Texture") then
			o.LocalTransparencyModifier = 1
		elseif o:IsA("Light") then
			o.Enabled = false
		end
	end
	h(inst)
	for _, d in inst:GetDescendants() do h(d) end
end
local function applyMenuVariant(root: Instance?, phase: number)
	if not root then return end
	for _, inst in root:GetDescendants() do
		local sp = inst:GetAttribute("ShowPhase")
		if typeof(sp) == "number" and phase < sp then hideTree(inst) end
	end
end

-- deps = { fireAction } — เปิดค้างจนกดเริ่มเล่น (เวลาถูก freeze)
function MenuUI.open(playerGui, deps)
	deps.fireAction({ type = "FreezeTime", on = true })
	deps.fireAction({ type = "RequestSlots" })
	-- ★ แก้ 12 ส.ค. (user: "แมพโหลดไม่ทัน") — โหลด asset เฟส 1 ไว้ล่วงหน้าตั้งแต่ยืนดูเมนู (fire-and-forget)
	--   เผื่อเซฟไม่มี/New Game (เริ่มเฟส 1 เสมอ) — เซฟที่ข้ามเฟสไปแล้วแค่เสียแรง preload เปล่าๆ ไม่พังอะไร
	PreloadService.preloadMap("Map_Phase1")

	-- เพลงเมนู lock กันโซนในแมพแย่งสั่ง (ตัวละคร spawn ในแมพจริง โซนจะเล่นทับ) · launch() ดับตอนเข้าเกม
	Audio.lockBGM(true)
	Audio.bgm("Menu")

	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local root = scene()
	-- ⚠️ StreamingEnabled: ห้องเมนูอยู่ไกลจากตัวผู้เล่น ถ้าไม่ตั้ง ModelStreamingMode = Persistent
	-- client จะได้แต่ Model เปล่าๆ ไม่มี Part ข้างใน (docs/05 §3.7)
	-- ★ แก้ 12 ส.ค. (user เจอตกไป fallback ซ้ำหลายรอบ) — เดิมรอแค่ 5 วิ ห้อง MenuScreen อยู่ไกลมาก
	--   (Y~2007) แม้ ModelStreamingMode = Persistent (ยืนยันตั้งถูกแล้ว) Play-test ใน Studio (server+client
	--   เครื่องเดียว) อาจ stream ช้ากว่าเล่นจริงพอให้ 5 วิไม่พอ → เพิ่มเป็น 15 วิ กันหลุด fallback ผิดพลาด
	--   ยังคง fallback ไว้ทำงานถ้าห้องหายจริง (เกมต้องเข้าได้เสมอ) แค่ให้เวลาพอสำหรับกรณี stream ช้า
	local home = root and root:WaitForChild("MenuCam_Home", 15)
	if not root or not home then
		warn("[MenuUI] " .. (root and "ห้องเมนูไม่มี MenuCam_Home (ตั้ง ModelStreamingMode = Persistent หรือยัง?)"
			or "ไม่มี Workspace.MenuScene / MenuScreen") .. " — ใช้เมนูปุ่มลอยแทน (docs/05 §3.7)")
		return MenuUI.openFallback(playerGui, deps)
	end

	local savedCam = { cf = camera.CFrame, type = camera.CameraType }
	camera.CameraType = Enum.CameraType.Scriptable
	local camHolder = Instance.new("CFrameValue")

	-- default camera script แย่งกล้องคืนทุกครั้งที่ตัวละครเกิด → ยึด CameraType+CFrame ทุกเฟรม + ซ่อนตัวละคร
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

	-- ซ่อน HUD + วงโซนถ่าย ระหว่างอยู่เมนู
	local hud = playerGui:FindFirstChild("Gui_HUD")
	if hud then hud.Enabled = false end
	local ring = workspace:FindFirstChild("FilmZoneRing")
	if ring then
		ring.Transparency = 1
		for _, b in ring:GetDescendants() do
			if b:IsA("BillboardGui") then b.Enabled = false end
		end
	end

	-- หาของในห้องตามชื่อจริง (ตาราง CLICK/CAM)
	local bookModel = findExact(root, CLICK.book)
	local pcScreen = screenPartOf(findExact(root, CLICK.pc))
	local bookPart = screenPartOf(bookModel)
	local setPart = screenPartOf(findExact(root, CLICK.setting))
	local credPart = screenPartOf(findExact(root, CLICK.credit))

	local camParts = {}
	for key, name in CAM do camParts[key] = root:FindFirstChild(name) end

	-- ไม่มี Part กล้องหน้าจอคอม → คำนวณเอง (ลอยหน้าจอพอดีเฟรม ทีมไม่ต้องวางเพิ่ม)
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

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_MainMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- flash คลุมทั้งจอรวม topbar — homePanel ชดเชย GuiInset เอง (fitHomePanel)
	gui.DisplayOrder = 10

	local GuiService = game:GetService("GuiService")
	local homePanel = Instance.new("Frame")
	homePanel.Size = UDim2.new(0, 420, 1, 0)
	homePanel.BackgroundTransparency = 1
	homePanel.Parent = gui

	local homeScale = Instance.new("UIScale")
	homeScale.Parent = homePanel

	-- โลโก้ถ้ามีรูป ไม่มีก็ตัวหนังสือ · parent = gui ตรงๆ (homePanel กว้างแค่ 420 title ต้องยืดเกือบเต็มจอ)
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
	title.Parent = gui

	-- จอเตี้ย: หด homePanel ให้ปุ่มไม่ล้น + เว้น GuiInset · title กรอบตรงสัดส่วนภาพจริง (กัน Fit จัดกลาง)
	local function fitHomePanel()
		local vp = camera.ViewportSize
		local inset = GuiService:GetGuiInset()
		local layout = MenuUI.layout(Vector2.new(vp.X, math.max(1, vp.Y - inset.Y)))
		homePanel.Position = UDim2.new(0, 0, 0, inset.Y)
		homePanel.Size = UDim2.new(0, 420, 1, -inset.Y)
		homeScale.Scale = layout.scale
		local titleH = MENU_DESIGN.topPad - 30
		title.Position = UDim2.new(0, 40, 0, inset.Y + 10)
		title.Size = UDim2.new(0, titleH * TITLE_ASPECT, 0, titleH)
	end
	fitHomePanel()
	-- disconnect ตอนเมนูปิด ไม่งั้นเปิดเมนูซ้ำ = ค้างหลาย connection (ดู launch)
	local viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitHomePanel)

	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.Visible = false
	flash.ZIndex = 50
	flash.Parent = gui

	local back = textButton(gui, "◀ Back", UDim2.new(0, 40, 1, -80), UDim2.new(0, 200, 0, 52),
		Color3.fromRGB(60, 60, 80))
	back.Name = "Btn_Back"
	back:SetAttribute("Sfx", "ui_back")
	back.Visible = false

	gui.Parent = playerGui

	-- SurfaceGui บนของจริง
	local canvasParts = {}
	local function canvasFor(target, screenKey, name)
		local sg, p = makeCanvas(target, camCFFor(screenKey), playerGui, name)
		if p then table.insert(canvasParts, p) end
		return sg
	end
	local bookGui = canvasFor(bookModel, "book", "Gui_MenuBook")
	local setGui = canvasFor(setPart, "setting", "Gui_MenuSetting")
	local credGui = canvasFor(credPart, "credit", "Gui_MenuCredit")
	local pcPart = pcScreen

	local slotBtns = {}
	local delBtns = {}
	if bookGui then
		local paper = UIAssets.book_page
		if paper ~= "" then -- texture กระดาษ (ไม่มีก็เป็นสีพื้นของ Part)
			local img = Instance.new("ImageLabel")
			img.Size = UDim2.new(1, 0, 1, 0)
			img.BackgroundTransparency = 1
			img.Image = paper
			img.ScaleType = Enum.ScaleType.Crop
			img.Parent = bookGui
		end
		-- ทุกตำแหน่ง scale ล้วน: ของแต่ละชิ้นสัดส่วนไม่เท่ากัน (สมุดแนวตั้ง จอแนวนอน)
		local head = Instance.new("TextLabel")
		head.Size = UDim2.new(0.9, 0, 0.1, 0)
		head.Position = UDim2.new(0.05, 0, 0.02, 0)
		head.BackgroundTransparency = 1
		head.TextColor3 = Color3.fromRGB(40, 35, 30)
		head.TextScaled = true
		head.Text = "Save Files"
		head.Parent = bookGui
		for i = 1, 4 do
			local b = textButton(bookGui, MenuUI.slotLine(i, nil),
				UDim2.new(0.05, 0, 0.15 + (i - 1) * 0.2, 0), UDim2.new(0.9, 0, 0.17, 0),
				Color3.fromRGB(245, 240, 225))
			b.BackgroundTransparency = 0.1
			slotBtns[i] = b
			-- ปุ่มลบเซฟ (โชว์เฉพาะ slot ที่มี save)
			local del = Instance.new("TextButton")
			del.Size = UDim2.new(0.1, 0, 0.1, 0)
			del.Position = UDim2.new(0.83, 0, 0.155 + (i - 1) * 0.2, 0)
			del.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
			del.TextColor3 = Color3.new(1, 1, 1)
			del.TextScaled = true
			del.Text = "✕"
			del.ZIndex = 5
			del.Visible = false
			del.Parent = bookGui
			local dc = Instance.new("UICorner")
			dc.CornerRadius = UDim.new(0, 8)
			dc.Parent = del
			del.Activated:Connect(function()
				deps.fireAction({ type = "DeleteSlot", slot = i })
			end)
			delBtns[i] = del
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
		head.Text = "Settings"
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
				deps.fireAction({ type = "SetSetting", key = "volume", value = Audio.getVolume() })
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

		-- ปิดป้ายลอย (ชื่อเหนือ NPC + ป้ายบอกวิธี) — ใช้ตอนอัดคลิปแนะนำเกม
		local seedSettings = deps.getState and deps.getState()
		local billboard = textButton(setGui, "", UDim2.new(0.05, 0, 0.56, 0), UDim2.new(0.9, 0, 0.11, 0))
		local function billboardText()
			local on = seedSettings and seedSettings.settings and seedSettings.settings.hideBillboards
			billboard.Text = "🏷️ ป้ายลอย (NPC/โซน): " .. (on and "ปิด" or "เปิด")
		end
		billboardText()
		billboard.Activated:Connect(function()
			local st = deps.getState and deps.getState()
			local cur = st and st.settings and st.settings.hideBillboards
			seedSettings = st
			deps.fireAction({ type = "SetSetting", key = "hideBillboards", value = not cur })
			billboardText()
		end)
	end

	local function showSurface(which)
		if bookGui then bookGui.Enabled = which == "book" end
		if setGui then setGui.Enabled = which == "setting" end
		if credGui then credGui.Enabled = which == "credit" end
	end
	showSurface(nil)

	-- เปลี่ยนหน้า
	local screen = "home"
	local function goto_(name)
		if MenuUI.busy then return end
		screen = name
		homePanel.Visible = name == "home"
		title.Visible = name == "home" -- โลโก้เกมโชว์เฉพาะหน้า home — เข้า save/setting/credit ต้องหายด้วย (parent = gui ไม่ใช่ homePanel เลยไม่หายตาม)
		back.Visible = name ~= "home"
		showSurface(name)
		tweenCamTo(camHolder, camCFFor(name), CAM_TIME)
	end
	back.Activated:Connect(function() goto_("home") end)

	-- เข้าเกม: บินเข้าจอ → วาบขาว → ค้าง → เผยเกม
	local function launch(action)
		if MenuUI.busy then return end
		MenuUI.busy = true
		local isNewGame = action ~= nil and action.type == "NewGame"
		homePanel.Visible = false
		title.Visible = false -- เข้าเกม = ซ่อนโลโก้ด้วย (goto_ ไม่ได้ถูกเรียกทางนี้)
		back.Visible = false
		showSurface(nil)
		tweenCamTo(camHolder, camCFFor("launching"), CAM_TIME)

		task.delay(CAM_TIME, function()
			if action then deps.fireAction(action) end
			Audio.bgm(nil) -- ดับเพลงเมนู (new game: cutscene lock เอง · continue: unlock ล่าง)
			if pcPart then -- จอสว่างเองด้วย
				local mat, col = pcPart.Material, pcPart.Color
				pcPart.Material = Enum.Material.Neon
				pcPart.Color = Color3.new(1, 1, 1)
				-- คืนสภาพจอหลังวาบ (ของที่ทีมปั้น ห้ามทิ้งไว้ขาวถาวร)
				task.delay(FLASH_IN + FLASH_HOLD + FLASH_OUT, function()
					if pcPart.Parent then
						pcPart.Material, pcPart.Color = mat, col
					end
				end)
			end
			flash.Visible = true
			TweenService:Create(flash, TweenInfo.new(FLASH_IN), { BackgroundTransparency = 0 }):Play()

			task.delay(FLASH_IN + FLASH_HOLD, function()
				-- คืนกล้อง/ตัวละครใต้ผ้าขาว แล้วค่อยเผย
				camGuard:Disconnect()
				viewportConn:Disconnect()
				freezeCharacter(player, false)
				if isNewGame and deps.onNewGame then
					deps.onNewGame() -- cutscene ยึดกล้องใต้ผ้าขาว · HUD/ring/unfreeze ให้ intro จัดการ
				else
					local char = player.Character or player.CharacterAdded:Wait()
					local hum = char:FindFirstChildOfClass("Humanoid")
					camera.CameraSubject = hum or char:FindFirstChild("HumanoidRootPart") -- ต้องตั้ง ไม่งั้นกล้องค้างกลางอากาศ
					camera.CameraType = Enum.CameraType.Custom
					if hud then hud.Enabled = true end
					if ring then
						ring.Transparency = 0.7
						for _, b in ring:GetDescendants() do
							if b:IsA("BillboardGui") then b.Enabled = true end
						end
					end
					deps.fireAction({ type = "FreezeTime", on = false })
					Audio.lockBGM(false) -- เล่นต่อ: คืนสิทธิ์ให้โซนคุมเพลง gameplay
				end
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

	-- ปุ่มหน้า home
	local latest = nil
	local slotsReady = false   -- true เมื่อ slotList รอบแรก (ครบทุกช่อง) มาถึง
	local slotRetries = 0      -- auto-retry เมื่อ DataStore อ่านบางช่องไม่สำเร็จ (กันเมนูค้างโชว์ "ไม่มีเซฟ")
	local pendingContinue = false -- กดเล่นต่อตอน slot ยังไม่โหลด → ค้างไว้ตัดสินหลังโหลด
	local continueBtn = textButton(homePanel, "Continue", UDim2.new(0, 40, 0, 280), UDim2.new(0, 340, 0, 62),
		nil, -1.4)
	continueBtn.Name = "Btn_Continue"
	local function doContinue()
		launch(latest and { type = "LoadSlot", slot = latest } or { type = "NewGame", slot = 1 })
	end
	continueBtn.Activated:Connect(function()
		if MenuUI.busy or pendingContinue then return end
		if slotsReady then
			doContinue()
		else
			-- ★ slotList ยังไม่มา: latest=nil = "ยังไม่รู้" ไม่ใช่ "ไม่มีเซฟ"
			--   เดา NewGame = ทับ auto-save ช่อง 1 ทิ้ง → ค้างเจตนาไว้ รอ updateSlots ตัดสินจากข้อมูลจริง
			pendingContinue = true
			continueBtn.Text = "Loading…"
			deps.fireAction({ type = "RequestSlots" })
		end
	end)
	local function navBtn(label, y, target, rot)
		local b = textButton(homePanel, label, UDim2.new(0, 40, 0, y), UDim2.new(0, 340, 0, 62), nil, rot)
		b.Name = "Btn_" .. target
		b.Activated:Connect(function() goto_(target) end)
	end
	navBtn("Save Files", 354, "book", 1.0)
	navBtn("Settings", 428, "setting", -0.7)
	navBtn("Credits", 502, "credit", 1.3)

	-- ช่องมีหลาย snapshot → กางให้เลือกจุดเซฟที่จะ restore
	local currentSlots = nil
	local function snapEntryText(e)
		local tag = e.which == "auto" and "🔄 อัตโนมัติ" or ("💾 บันทึก #" .. tostring(e.which))
		return ("%s — วันที่ %s · %s follower · เฟส %s"):format(tag, tostring(e.day), tostring(e.follower), tostring(e.phase))
	end
	local function openSnapshotPicker(slot, entries)
		local g = Instance.new("ScreenGui")
		g.Name = "Gui_SnapPicker"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true -- dim คลุมถึงขอบบนสุด
		g.DisplayOrder = 30
		local dim = Instance.new("TextButton")
		dim.Size = UDim2.fromScale(1, 1)
		dim.BackgroundColor3 = Color3.new(0, 0, 0)
		dim.BackgroundTransparency = 0.45
		dim.Text = ""
		dim:SetAttribute("Sfx", "none")
		dim.Parent = g
		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(580, 62 + #entries * 66)
		panel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
		panel.BorderSizePixel = 0
		panel.Parent = g
		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0, 12)
		pc.Parent = panel
		local title = Instance.new("TextLabel")
		title.Position = UDim2.fromOffset(24, 14)
		title.Size = UDim2.fromOffset(532, 30)
		title.BackgroundTransparency = 1
		title.FontFace = Font.fromEnum(Enum.Font.GothamBold)
		title.TextSize = 20
		title.TextColor3 = Color3.fromRGB(240, 240, 245)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = ("เลือกจุดเซฟ — ช่อง %d"):format(slot)
		title.Parent = panel
		for idx, e in entries do
			local y = 50 + (idx - 1) * 66
			local row = Instance.new("TextButton")
			row.Size = UDim2.fromOffset(472, 56)
			row.Position = UDim2.fromOffset(24, y)
			row.BackgroundColor3 = Color3.fromRGB(46, 46, 58)
			row.TextColor3 = Color3.new(1, 1, 1)
			row.FontFace = Font.fromEnum(Enum.Font.Gotham)
			row.TextSize = 16
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Text = "  " .. snapEntryText(e)
			row:SetAttribute("Sfx", "ui_click")
			row.Parent = panel
			local rc = Instance.new("UICorner")
			rc.CornerRadius = UDim.new(0, 8)
			rc.Parent = row
			row.Activated:Connect(function()
				g:Destroy()
				launch({ type = "LoadSlot", slot = slot, which = e.which })
			end)
			local del = Instance.new("TextButton")
			del.Size = UDim2.fromOffset(56, 56)
			del.Position = UDim2.fromOffset(500, y)
			del.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
			del.TextColor3 = Color3.new(1, 1, 1)
			del.TextScaled = true
			del.Text = "✕"
			del:SetAttribute("Sfx", "ui_back")
			del.Parent = panel
			local dc = Instance.new("UICorner")
			dc.CornerRadius = UDim.new(0, 8)
			dc.Parent = del
			del.Activated:Connect(function()
				deps.fireAction({ type = "DeleteSnapshot", slot = slot, which = e.which })
				g:Destroy() -- updateSlots รีเฟรช กดช่องใหม่เห็นอัปเดต
			end)
		end
		dim.Activated:Connect(function() g:Destroy() end)
		g.Parent = playerGui
	end

	for i = 1, 4 do
		local b = slotBtns[i]
		if b then
			b.Activated:Connect(function()
				-- ช่องนี้อ่านไม่สำเร็จ (ไม่ใช่ว่าง) → ลองใหม่ อย่าเดา NewGame ทับเซฟที่อาจมี
				if b:GetAttribute("ReadFailed") then
					slotRetries = 0
					deps.fireAction({ type = "RequestSlots" })
					return
				end
				if not slotsReady then return end -- ยังไม่รู้ว่าช่องนี้มีเซฟไหม อย่าเดา
				if not b:GetAttribute("HasSave") then
					launch({ type = "NewGame", slot = i })
					return
				end
				local entries = currentSlots and currentSlots[i] and currentSlots[i].entries
				if entries and #entries > 1 then
					openSnapshotPicker(i, entries)
				else
					launch({ type = "LoadSlot", slot = i })
				end
			end)
		end
	end

	-- state ใหม่ (หลัง RequestSlots) → เขียนลงสมุด
	function MenuUI.updateSlots(state)
		if not MenuUI.running then return end
		local slots = state.slotList
		if not slots then return end
		local failed = state.slotsFailed -- {[slot]=true} อ่านไม่สำเร็จ (≠ ว่าง)
		currentSlots = slots
		latest = MenuUI.latestSlot(slots)
		-- ความคืบหน้า = เฟสของเซฟล่าสุด → เพลงเมนู + รายละเอียดห้องเปลี่ยนตาม
		local menuPhase = (latest and slots[latest] and slots[latest].phase) or 1
		applyMenuVariant(root, menuPhase)
		Audio.bgm(resolveMenuBGM(menuPhase))
		for i = 1, 4 do
			local b = slotBtns[i]
			if b then
				if failed and failed[i] then
					b.Text = ("ช่อง %d — โหลดไม่สำเร็จ · แตะลองใหม่"):format(i)
					b:SetAttribute("HasSave", false)
					b:SetAttribute("ReadFailed", true)
				else
					b.Text = MenuUI.slotLine(i, slots[i])
					b:SetAttribute("HasSave", slots[i] ~= nil)
					b:SetAttribute("ReadFailed", false)
				end
			end
			if delBtns[i] then delBtns[i].Visible = (not (failed and failed[i])) and slots[i] ~= nil end
		end
		-- บางช่องอ่านไม่สำเร็จ = ข้อมูลพร่อง → อย่า lock slotsReady, auto-retry + คง pendingContinue (กัน NewGame ทับ)
		if failed and next(failed) then
			continueBtn.Text = "Loading save…"
			if slotRetries < 6 then
				slotRetries += 1
				task.delay(1.2, function()
					if MenuUI.running and not slotsReady then deps.fireAction({ type = "RequestSlots" }) end
				end)
			end
			return
		end
		-- อ่านครบทุกช่อง → ปุ่มตัดสินใจได้ · Continue ที่ค้างไว้ทำต่อ
		slotRetries = 0
		continueBtn.Text = latest and ("Continue (Page %d)"):format(latest) or "New Story"
		slotsReady = true
		if pendingContinue then
			pendingContinue = false
			doContinue()
		end
	end

	-- seed จาก state ที่ server prefetch slotList มาแล้วตอน join → พร้อมทันที (ไม่รอ RequestSlots 1.6s)
	local seed = deps.getState and deps.getState()
	if seed and seed.slotList then MenuUI.updateSlots(seed) end
end

-- fallback: ไม่มี MenuScene ในแมพ (เกมต้องเข้าได้เสมอ)
function MenuUI.openFallback(playerGui, deps)
	PreloadService.preloadMap("Map_Phase1") -- เหตุผลเดียวกับ MenuUI.open — ดูคอมเมนต์ที่นั่น
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_MainMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
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
	local slotsReady, pendingContinue = false, false
	local slotRetries = 0
	local function startGame(action)
		local isNewGame = action ~= nil and action.type == "NewGame"
		if action then deps.fireAction(action) end
		deps.fireAction({ type = "FreezeTime", on = false })
		MenuUI.updateSlots = nil
		local hud = playerGui:FindFirstChild("Gui_HUD")
		if hud then hud.Enabled = true end
		gui:Destroy()
		if isNewGame and deps.onNewGame then deps.onNewGame() end
	end
	local function doContinue()
		startGame(latest and { type = "LoadSlot", slot = latest } or { type = "NewGame", slot = 1 })
	end
	local continueBtn = textButton(bg, "Continue", UDim2.new(0.5, -160, 0, 130), UDim2.new(0, 320, 0, 48),
		Color3.fromRGB(45, 95, 175))
	continueBtn.Activated:Connect(function()
		if slotsReady then
			doContinue()
		elseif not pendingContinue then
			-- slotList ยังไม่มา — อย่าเดา NewGame ทับเซฟ รอข้อมูลก่อน
			pendingContinue = true
			continueBtn.Text = "Loading…"
			deps.fireAction({ type = "RequestSlots" })
		end
	end)
	for i = 1, 4 do
		local b = textButton(bg, MenuUI.slotLine(i, nil), UDim2.new(0.5, -160, 0, 130 + i * 56),
			UDim2.new(0, 320, 0, 48))
		b.Activated:Connect(function()
			if b:GetAttribute("ReadFailed") then -- อ่านไม่สำเร็จ (ไม่ใช่ว่าง) → ลองใหม่ อย่าเดา NewGame ทับ
				slotRetries = 0
				deps.fireAction({ type = "RequestSlots" })
				return
			end
			if not slotsReady then return end
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
		local failed = state.slotsFailed
		latest = MenuUI.latestSlot(slots)
		for i = 1, 4 do
			if failed and failed[i] then
				btns[i].Text = ("ช่อง %d — โหลดไม่สำเร็จ · แตะลองใหม่"):format(i)
				btns[i]:SetAttribute("HasSave", false)
				btns[i]:SetAttribute("ReadFailed", true)
			else
				btns[i].Text = MenuUI.slotLine(i, slots[i])
				btns[i]:SetAttribute("HasSave", slots[i] ~= nil)
				btns[i]:SetAttribute("ReadFailed", false)
			end
		end
		if failed and next(failed) then -- ข้อมูลพร่อง → auto-retry (กัน NewGame ทับเซฟ)
			continueBtn.Text = "Loading save…"
			if slotRetries < 6 then
				slotRetries += 1
				task.delay(1.2, function()
					if gui.Parent and not slotsReady then deps.fireAction({ type = "RequestSlots" }) end
				end)
			end
			return
		end
		slotRetries = 0
		continueBtn.Text = latest and ("Continue (Page %d)"):format(latest) or "New Story"
		slotsReady = true
		if pendingContinue then
			pendingContinue = false
			doContinue()
		end
	end

	local seed = deps.getState and deps.getState()
	if seed and seed.slotList then MenuUI.updateSlots(seed) end
end

return MenuUI
