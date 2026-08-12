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
	credit = "MenuCam_Credits", -- ชื่อจริงในห้องมี s (ยืนยัน 29 ก.ค.)
	launching = "MenuCam_PC",
}

function MenuUI.camFor(screen: string): string
	return SCREEN_CAM[screen] or SCREEN_CAM.home
end

-- ข้อความในสมุด 1 บรรทัด (ช่องว่าง = ยังไม่เขียน)
function MenuUI.slotLine(i: number, sum): string
	if not sum then
		return ("Page %d — empty  (start new)"):format(i)
	end
	return ("Page %d — Day %d · %s followers · Phase %d"):format(i, sum.day, tostring(sum.follower), sum.phase)
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

-- เมนูหลักออกแบบพอดีจอสูง ~580px (ตัวเลข pixel เดิม: title 20-270, ปุ่มแรก y=280, ปุ่มสุดท้ายจบ 502+62=564)
-- มือถือแนวนอน (~390px สูง) ต้องหดทั้งแผง ไม่งั้นปุ่มล้นขอบล่าง — scale ทั้งชุดแทนคำนวณ pixel ใหม่ทีละปุ่ม
-- topPad ขยับ 210→280 (12 ส.ค.) เปิดพื้นที่ให้ title สูงขึ้นจริง (ไม่ใช่แค่กว้างขึ้น) ตาม user
local MENU_DESIGN = {
	panelWidth = 420,
	topPad = 280, -- ที่ว่างเหนือปุ่มแรก (โลโก้/หัวเรื่อง) — GuiInset บวกเพิ่มตอน glue ไม่ใช่ตรงนี้ (pure fn แตะ GuiService ไม่ได้)
	buttonHeight = 62,
	buttonGap = 12, -- ระยะห่างเดิมจาก y ของปุ่ม (354-280-62=12)
	buttonCount = 4,
	refHeight = 580, -- ความสูงจอที่ตัวเลขข้างบนพอดีเป๊ะ ไม่ต้องหด
	minScale = 0.6, -- กันตัวหนังสือเล็กจนอ่านไม่ออกบนจอเตี้ยมาก
}

-- สัดส่วนภาพจริงของ UIAssets.menu_logo — วัดด้วย AssetService:CreateEditableImageAsync (12 ส.ค.) = 1024×576 (16:9)
-- ต้องใช้ค่านี้คำนวณกรอบ title ให้สัดส่วนตรงเป๊ะ ไม่งั้น ScaleType.Fit จะ letterbox แล้ว center เนื้อภาพเข้ากลางกรอบ
-- (กรอบกว้าง/สูงเกินสัดส่วนภาพจริง = มีช่องว่าง Fit เอาไป "จัดกลาง" ให้ — เคยพลาดจนโลโก้ลอยกลางจอ 12 ส.ค.)
local TITLE_ASPECT = 1024 / 576

-- viewport = Vector2-like ({X=,Y=}) → ตัวเลข layout ล้วนๆ ไม่แตะ Instance เลย (lune เทสได้)
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

-- ===== Roblox glue =====

if not isStudio then return MenuUI end

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Audio = require(script.Parent.Parent.AudioService)
local UIAssets = require(game:GetService("ReplicatedStorage").Shared.UIAssets)

local CAM_TIME = 1.2
local FLASH_IN, FLASH_HOLD, FLASH_OUT = 0.35, 2.4, 0.6

-- ★ ชื่อของจริงที่ทีมตั้งไว้ในห้องเมนู (ยืนยัน 29 ก.ค. 2569) — **ชื่อเดียว ไม่มีเดา ไม่มีสำรอง**
-- เปลี่ยนชื่อของใน Studio เมื่อไหร่ = มาแก้ตารางนี้ให้ตรง (ตั้งใจให้พังดังๆ ดีกว่าไปหยิบของผิดชิ้นมาใช้)
local SCENE = "MenuScreen" -- Workspace.MenuScreen
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

-- client เริ่มก่อน workspace replicate เสร็จ → ต้องรอ ไม่ใช่ FindFirstChild เฉยๆ
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

-- หาชิ้นเดียวตามชื่อที่ระบุ ไม่เจอ = warn บอกชื่อที่หา (ไปเปลี่ยนชื่อใน Studio หรือแก้ตารางข้างบน)
local function findExact(root, name: string)
	local f = root:FindFirstChild(name)
	if not f then
		warn(("[MenuUI] ไม่เจอ Workspace.%s.%s — ตรวจชื่อใน Studio หรือแก้ตาราง CLICK/CAM ใน MenuUI")
			:format(SCENE, name))
	end
	return f
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
		-- MoveLocked = บอก script อื่นที่แตะ WalkSpeed (SprintHandler) ว่าอย่ายุ่งตอนล็อก
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

-- กล้อง = ตำแหน่ง + ทิศที่ Part หันหน้า
-- มองตรงลง/ตรงขึ้น: lookAt กับ up โลกจะ degenerate (roll มั่ว) → ใช้ UpVector ของ Part แทน
-- แปลว่าทีมหมุน Part กล้องที่มองลง = หมุนภาพที่เห็นได้จริง (เช่นให้สมุดวางขวางจอ)
local function cfOf(part)
	local look = part.CFrame.LookVector
	local up = math.abs(look.Y) > 0.99 and part.CFrame.UpVector or Vector3.yAxis
	return CFrame.lookAt(part.Position, part.Position + look, up)
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

	-- ใช้หน้า Front + CFrame.lookAt เหมือน PCScreen: LookVector = หน้าจอ, +Y = ด้านบน canvas
	-- (หน้า Top เคยลองแล้ว mapping ของ canvas ไม่ตรงกับที่คิด ตัวหนังสือหมุน 90°)
	-- ใช้แกน Y ของโลกเป็น "ด้านบน" ไม่ใช่ UpVector ของ Part กล้อง — ทีมหมุน Part เอียงได้
	local up = camCF.UpVector -- ด้านบนของภาพที่ผู้เล่นเห็นจริง (กล้องมองก้ม/เงยเท่าไหร่ก็ตรงเสมอ)
	local pos, cf

	-- ขนาดแผ่น = "เงา" ของวัตถุจริงบนแกนขวา/บนของกล้อง
	-- คำนวณจากมุมทั้ง 8 ของทุก Part ฉายลงแกนกล้องตรงๆ — ไม่ต้องเดาว่า bounding box หันทางไหน
	-- (เคยลองใช้แกนโลก/แกน box แล้วพลาดทั้งคู่: โปสเตอร์ติดผนังกับสมุดวางโต๊ะถูกหมุนคนละแบบ)
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
	-- จัดกึ่งกลางให้ตรงกับเงาจริง (bounding box อาจเบี้ยวจากชิ้นส่วนที่ยื่นออกมา)
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
	p.CanQuery = true -- ต้อง true ไม่งั้นเมาส์ยิง ray ไม่โดน = ปุ่ม SurfaceGui บนสมุด/หน้าจอกดไม่ได้
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

-- ===== ปุ่มกระดาษโน้ต (พอร์ตจาก Figma component MenuButton — ธีมสมุดเล่าเรื่อง) =====
-- ⚠️ เคยใช้ Font.fromName("Mali",...) แต่พังจริง ("Temp read failed" ซ้ำทุก session ไม่ใช่ cache กระตุก)
-- เปลี่ยนเป็น Enum.Font (ของ client จริง) — variant Hover = พื้นแดงอ่อน
local MENU_FONT = Font.fromEnum(Enum.Font.FredokaOne) -- ชุดเดียวกับ HUD (ข้อความในเกม) — 12 ส.ค. เปลี่ยนจาก GothamMedium
-- สี/stroke อิงจาก GuiHUD (HUD.luau: panel()=navy 20,20,30 @0.25 transparency, popup()=ตัวขาว+stroke เข้ม 27,27,27 หนา 1)
-- เปลี่ยนจากธีมกระดาษครีมเดิม (CREAM/INK) → ธีม HUD เข้ม 12 ส.ค. ตาม user
local PANEL_BG = Color3.fromRGB(20, 20, 30)
local PANEL_BG_HOVER = Color3.fromRGB(35, 35, 48)
local TEXT_COLOR = Color3.new(1, 1, 1)
local STROKE_COLOR = Color3.fromRGB(27, 27, 27)

-- rot = องศาเอียง (imperfect) — ไม่ใส่ = 0 · color param เก่าเลิกใช้ (คง signature กันของพัง)
local function textButton(parent, text, pos, size, _color, rot)
	rot = rot or 0
	-- เงา = frame ข้างหลัง สร้างก่อน = ถูกวาดใต้ปุ่ม
	local shadow = Instance.new("Frame")
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
	b.BackgroundTransparency = 0.25 -- ตรงกับ HUD panel()
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.TextColor3 = TEXT_COLOR
	b.FontFace = MENU_FONT
	b.TextScaled = true
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Text = text -- ข้อความล้วน (ฟอนต์ Mali ไม่มี glyph สัญลักษณ์ → bullet ทำเป็นรูปแยก)
	b.ZIndex = 1
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = b
	local st = Instance.new("UIStroke")
	st.Color = STROKE_COLOR -- ตรงกับ HUD popup() text stroke
	st.Thickness = 1
	st.Transparency = 0
	st.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 20) -- เดิม 52 เว้นที่ bullet — ตัด bullet ออกแล้ว (12 ส.ค.) เลยชิดซ้ายได้
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = b
	-- (เอา bullet จุดแดงออกแล้ว 12 ส.ค. ตาม user — เหลือแค่ข้อความล้วน)
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

-- เพลงเมนูตามความคืบหน้า (Undertale ref): มี Sound "Menu<เฟส>" = ใช้ตัวนั้น · ไม่มี = "Menu" ธรรมดา
-- ทีมวาง Menu / Menu2 / Menu3 ใน SoundService.BGM ได้ตามใจ (เฟสไหนไม่มี track เฉพาะ = ตกมาใช้ Menu)
local function resolveMenuBGM(phase: number): string
	local folder = game:GetService("SoundService"):FindFirstChild("BGM")
	local named = "Menu" .. tostring(phase)
	if folder and folder:FindFirstChild(named) then return named end
	return "Menu"
end

-- รายละเอียดในห้องเมนูเปลี่ยนตามความคืบหน้า (Undertale ref): instance ที่ตั้ง attribute `ShowPhase = n`
-- จะโผล่เฉพาะเมื่อเซฟล่าสุดถึงเฟส n ขึ้นไป · ยังไม่ถึง = ซ่อน (LocalTransparencyModifier ไม่แตะค่าจริง)
-- เมนูเปิดครั้งเดียวต่อ session ตามเฟสของเซฟ → ซ่อนอย่างเดียวพอ ไม่ต้อง restore
-- ponytail: ซ่อนทางเดียว (ไม่ toggle กลับ) — ถ้าอนาคตมี return-to-menu แล้วเฟสเปลี่ยน ค่อยเพิ่ม snapshot/restore
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

-- deps = { fireAction = fn } — เปิดค้างจนกดเริ่มเล่น (เวลาถูก freeze ไว้)
function MenuUI.open(playerGui, deps)
	deps.fireAction({ type = "FreezeTime", on = true })
	deps.fireAction({ type = "RequestSlots" })

	-- เพลงเมนูเฉพาะ — lock กันโซนในแมพแย่งสั่งเพลงระหว่างอยู่เมนู (ตัวละคร spawn ในแมพจริง โซนจะเล่นทับ)
	-- ทีมวาง Sound ชื่อ "Menu" ใน SoundService.BGM (ไม่มี = เงียบ + warn ครั้งเดียว ไม่พัง) · launch() ดับตอนเข้าเกม
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

	-- ===== หาของในห้องตามชื่อจริงที่ทีมตั้ง (ตาราง CLICK/CAM ข้างบน) =====
	local bookModel = findExact(root, CLICK.book)
	local pcScreen = screenPartOf(findExact(root, CLICK.pc))
	local bookPart = screenPartOf(bookModel)
	local setPart = screenPartOf(findExact(root, CLICK.setting))
	local credPart = screenPartOf(findExact(root, CLICK.credit))

	local camParts = {}
	for key, name in CAM do camParts[key] = root:FindFirstChild(name) end

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
	gui.IgnoreGuiInset = true -- flash ต้องคลุมทั้งจอรวม topbar ตอนวาบขาว — ชดเชย homePanel เองด้วย GuiInset แทน (fitHomePanel ข้างล่าง)
	gui.DisplayOrder = 10

	local GuiService = game:GetService("GuiService")
	local homePanel = Instance.new("Frame")
	homePanel.Size = UDim2.new(0, 420, 1, 0)
	homePanel.BackgroundTransparency = 1
	homePanel.Parent = gui

	local homeScale = Instance.new("UIScale")
	homeScale.Parent = homePanel

	-- โลโก้ถ้ามีรูป ไม่มีก็ใช้ตัวหนังสือ
	-- ★ parent = gui ตรงๆ ไม่ใช่ homePanel (12 ส.ค.) — homePanel กว้างแค่ 420px (คอลัมน์ปุ่ม)
	--   title ต้องใหญ่ยืดเกือบเต็มจอตาม user ถ้าอยู่ใน homePanel จะโดนตัดกว้างแค่ 420
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

	-- มือถือจอเตี้ย (แนวนอน): หด homePanel ทั้งชุดให้ปุ่มไม่ล้นจอ + เว้น GuiInset กันชนไอคอน topbar
	-- (UIScale ย่อของข้างในทั้งหมดพร้อมกัน ตำแหน่ง/ขนาดปุ่มเดิมเป็น pixel design คงที่ ไม่ต้องคำนวณใหม่ทีละปุ่ม)
	-- title กว้างเกือบเต็มจอ (ยืดขวาเกือบสุดขอบ ตาม user 12 ส.ค.) สูงไม่เกิน topPad กันทับปุ่มแรก
	-- ScaleType.Fit เดิมกันโลโก้ยืด/บิดอัตราส่วนอยู่แล้ว — เฟรมกว้าง/สูงแค่กำหนดขอบเขตสูงสุด ไม่บังคับสัดส่วนภาพ
	local function fitHomePanel()
		local vp = camera.ViewportSize
		local inset = GuiService:GetGuiInset()
		local layout = MenuUI.layout(Vector2.new(vp.X, math.max(1, vp.Y - inset.Y)))
		homePanel.Position = UDim2.new(0, 0, 0, inset.Y)
		homePanel.Size = UDim2.new(0, 420, 1, -inset.Y)
		homeScale.Scale = layout.scale
		-- กรอบ = สัดส่วนภาพจริงเป๊ะ (TITLE_ASPECT) ไม่มีช่องว่างให้ Fit เอาไปจัดกลาง — ชิดซ้ายจริง ไม่ลอยกลางจอ
		local titleH = MENU_DESIGN.topPad - 30
		title.Position = UDim2.new(0, 40, 0, inset.Y + 10)
		title.Size = UDim2.new(0, titleH * TITLE_ASPECT, 0, titleH)
	end
	fitHomePanel()
	-- หมุนจอ/resize ต้องหดใหม่ · ต้อง disconnect ตอนเมนูปิด ไม่งั้นเปิดเมนูซ้ำ = ค้างหลาย connection (ดู launch ด้านล่าง)
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
	back:SetAttribute("Sfx", "ui_back") -- เสียงย้อนกลับ คนละตัวกับกดเข้า (ตัวผูกกลางใน Main.client เล่นให้)
	back.Visible = false

	gui.Parent = playerGui

	-- ===== SurfaceGui บนของจริง =====
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
		head.Text = "Save Files"
		head.Parent = bookGui
		for i = 1, 4 do
			local b = textButton(bookGui, MenuUI.slotLine(i, nil),
				UDim2.new(0.05, 0, 0.15 + (i - 1) * 0.2, 0), UDim2.new(0.9, 0, 0.17, 0),
				Color3.fromRGB(245, 240, 225))
			b.BackgroundTransparency = 0.1
			slotBtns[i] = b
			-- ปุ่มลบเซฟ (โชว์เฉพาะ slot ที่มี save) — มุมขวาของหน้า
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
				deps.fireAction({ type = "DeleteSlot", slot = i }) -- server ลบ + refresh slotList
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
				deps.fireAction({ type = "SetSetting", key = "volume", value = Audio.getVolume() }) -- เก็บลงเซฟ
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

		-- ปิดป้ายลอย (ชื่อเหนือหัว NPC + ป้ายบอกวิธีเล่น ฯลฯ) — ใช้ตอนอัดคลิปแนะนำเกม ไม่อยากให้ UI ลอยเกะกะ
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

	-- ===== เปลี่ยนหน้า =====
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

	-- ===== เข้าเกม: บินเข้าจอ → วาบขาว → ค้าง → เผยเกม =====
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
			Audio.bgm(nil) -- ดับเพลงเมนูตอนเข้าเกม (new game: cutscene lock/dab เอง · continue: unlock ล่าง)
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
				viewportConn:Disconnect() -- กัน connection ค้างทุกครั้งที่เปิดเมนู (menu เปิดได้แค่ครั้งเดียวต่อ session แต่กันไว้)
				-- คืนกล้องให้ default camera script: ต้องตั้ง CameraSubject ด้วย
				-- ไม่งั้นกล้องค้างอยู่กลางอากาศ ไม่ตามตัวผู้เล่น
				freezeCharacter(player, false)
				if isNewGame and deps.onNewGame then
					-- New Game: cutscene ยึดกล้องใต้ผ้าขาว fade เผยเห็น cutscene ไม่เห็นแวบ baseplate
					deps.onNewGame() -- HUD/ring/unfreeze ให้ intro จัดการหลังจบ
				else
					local char = player.Character or player.CharacterAdded:Wait()
					local hum = char:FindFirstChildOfClass("Humanoid")
					camera.CameraSubject = hum or char:FindFirstChild("HumanoidRootPart")
					camera.CameraType = Enum.CameraType.Custom
					if hud then hud.Enabled = true end
					if ring then
						ring.Transparency = 0.7
						for _, b in ring:GetDescendants() do
							if b:IsA("BillboardGui") then b.Enabled = true end
						end
					end
					deps.fireAction({ type = "FreezeTime", on = false })
					Audio.lockBGM(false) -- เล่นต่อ (ไม่มี cutscene): คืนสิทธิ์ให้โซนในแมพคุมเพลง gameplay
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

	-- ===== ปุ่มหน้า home =====
	local latest = nil
	local slotsReady = false   -- true เมื่อ slotList รอบแรก (ครบทุกช่อง) มาถึง (updateSlots ทำงาน)
	local slotRetries = 0      -- auto-retry RequestSlots เมื่อ DataStore อ่านบางช่องไม่สำเร็จ (กันเมนูค้างโชว์ "ไม่มีเซฟ" จนต้อง rejoin)
	local pendingContinue = false -- กด "เล่นต่อ" ตอน slot ยังไม่โหลด → ค้างไว้ตัดสินหลังโหลด
	local continueBtn = textButton(homePanel, "Continue", UDim2.new(0, 40, 0, 280), UDim2.new(0, 340, 0, 62),
		nil, -1.4)
	continueBtn.Name = "Btn_Continue"
	-- มีเซฟ = โหลดช่องล่าสุด · ไม่มีเซฟจริง = เริ่มใหม่ช่อง 1
	local function doContinue()
		launch(latest and { type = "LoadSlot", slot = latest } or { type = "NewGame", slot = 1 })
	end
	continueBtn.Activated:Connect(function()
		if MenuUI.busy or pendingContinue then return end
		if slotsReady then
			doContinue()
		else
			-- ★ slotList ยังไม่มา: latest=nil แปลว่า "ยังไม่รู้" ไม่ใช่ "ไม่มีเซฟ"
			--   เดา NewGame ตรงนี้ = ทับ auto-save ช่อง 1 ทิ้ง (เจอจริง 5 ส.ค. หน้าต่าง ~1.5 วิ)
			--   → ค้างเจตนาไว้ รอ updateSlots มาถึงแล้วตัดสินจากข้อมูลจริง
			pendingContinue = true
			continueBtn.Text = "Loading…"
			deps.fireAction({ type = "RequestSlots" }) -- เผื่อ request แรกหาย
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

	-- ช่องมีหลาย snapshot → กางให้เลือกจุดเซฟที่จะ restore (auto + manual ล่าสุด→เก่า)
	local currentSlots = nil
	local function snapEntryText(e)
		local tag = e.which == "auto" and "🔄 อัตโนมัติ" or ("💾 บันทึก #" .. tostring(e.which))
		return ("%s — วันที่ %s · %s follower · เฟส %s"):format(tag, tostring(e.day), tostring(e.follower), tostring(e.phase))
	end
	local function openSnapshotPicker(slot, entries)
		local g = Instance.new("ScreenGui")
		g.Name = "Gui_SnapPicker"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true -- dim ต้องคลุมถึงขอบบนสุด ไม่งั้นเหลือแถบสว่างใต้ topbar
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
				g:Destroy() -- ปิด · updateSlots รีเฟรชรายการ กดช่องใหม่เห็นอัปเดต
			end)
		end
		dim.Activated:Connect(function() g:Destroy() end)
		g.Parent = playerGui
	end

	for i = 1, 4 do
		local b = slotBtns[i]
		if b then
			b.Activated:Connect(function()
				-- ช่องนี้ DataStore อ่านไม่สำเร็จ (ไม่ใช่ว่าง) → ลองอ่านใหม่ อย่าเดา NewGame ทับเซฟที่อาจมีอยู่
				if b:GetAttribute("ReadFailed") then
					slotRetries = 0 -- ผู้เล่นสั่งเอง → รีเซ็ตโควตา auto-retry
					deps.fireAction({ type = "RequestSlots" })
					return
				end
				-- slot ยังไม่โหลด = ยังไม่รู้ว่าช่องนี้มีเซฟไหม อย่าเดา NewGame ทับ (ปกติโหลดเสร็จก่อนกางสมุดอยู่แล้ว)
				if not slotsReady then return end
				if not b:GetAttribute("HasSave") then
					launch({ type = "NewGame", slot = i })
					return
				end
				local entries = currentSlots and currentSlots[i] and currentSlots[i].entries
				if entries and #entries > 1 then
					openSnapshotPicker(i, entries) -- หลายจุดเซฟ = ให้เลือก
				else
					launch({ type = "LoadSlot", slot = i }) -- อันเดียว = โหลดล่าสุดเลย
				end
			end)
		end
	end

	-- state ใหม่มา (หลัง RequestSlots) → เขียนลงสมุด
	function MenuUI.updateSlots(state)
		if not MenuUI.running then return end
		local slots = state.slotList
		if not slots then return end
		local failed = state.slotsFailed -- {[slot]=true} ที่ DataStore อ่านไม่สำเร็จ (≠ ว่าง)
		currentSlots = slots -- ให้ snapshot picker อ่าน entries
		latest = MenuUI.latestSlot(slots)
		-- ความคืบหน้า = เฟสของเซฟล่าสุด (ไม่มีเซฟ = เฟส 1) → เพลงเมนู + รายละเอียดห้องเปลี่ยนตาม
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
		-- บางช่องอ่าน DataStore ไม่สำเร็จ = ข้อมูลยังพร่อง → อย่า lock slotsReady จากของพร่อง (ไม่งั้นเมนูค้างโชว์ "ไม่มีเซฟ" จนต้อง rejoin)
		--   auto-retry เอง + คง pendingContinue ไว้ให้ Continue รอจนอ่านครบ (กัน NewGame ทับเซฟ)
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
		-- อ่านครบทุกช่องแล้ว → ปุ่มตัดสินใจได้ · ถ้าผู้เล่นกด "เล่นต่อ" ค้างไว้ตอนยังโหลด ทำต่อตอนนี้
		slotRetries = 0
		continueBtn.Text = latest and ("Continue (Page %d)"):format(latest) or "New Story"
		slotsReady = true
		if pendingContinue then
			pendingContinue = false
			doContinue()
		end
	end

	-- seed จาก state ที่ server prefetch slotList มาแล้วตอน join → พร้อมทันที ไม่ต้องรอ RequestSlots (1.6s)
	local seed = deps.getState and deps.getState()
	if seed and seed.slotList then MenuUI.updateSlots(seed) end
end

-- ===== fallback: ไม่มี MenuScene ในแมพ (เกมต้องเข้าได้เสมอ) =====
function MenuUI.openFallback(playerGui, deps)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_MainMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- dim/bg เต็มจอต้องคลุมถึงขอบบนสุด ไม่งั้นเหลือแถบสว่างใต้ topbar
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
	local slotRetries = 0 -- auto-retry เมื่อ DataStore อ่านบางช่องไม่สำเร็จ (กันเมนูค้างโชว์ "ไม่มีเซฟ")
	local function startGame(action)
		local isNewGame = action ~= nil and action.type == "NewGame"
		if action then deps.fireAction(action) end
		deps.fireAction({ type = "FreezeTime", on = false })
		MenuUI.updateSlots = nil
		local hud = playerGui:FindFirstChild("Gui_HUD")
		if hud then hud.Enabled = true end -- เปิด HUD ตอนเข้าเกมจริง (path เมนูสำรอง)
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
			-- slotList ยังไม่มา — อย่าเดา NewGame ทับเซฟ (เหมือน path เมนูหลัก) รอข้อมูลก่อน
			pendingContinue = true
			continueBtn.Text = "Loading…"
			deps.fireAction({ type = "RequestSlots" })
		end
	end)
	for i = 1, 4 do
		local b = textButton(bg, MenuUI.slotLine(i, nil), UDim2.new(0.5, -160, 0, 130 + i * 56),
			UDim2.new(0, 320, 0, 48))
		b.Activated:Connect(function()
			if b:GetAttribute("ReadFailed") then -- DataStore อ่านช่องนี้ไม่สำเร็จ (ไม่ใช่ว่าง) → ลองใหม่ อย่าเดา NewGame ทับ
				slotRetries = 0
				deps.fireAction({ type = "RequestSlots" })
				return
			end
			if not slotsReady then return end -- ยังไม่รู้ว่าช่องนี้มีเซฟไหม อย่าเดา
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
		local failed = state.slotsFailed -- {[slot]=true} DataStore อ่านไม่สำเร็จ (≠ ว่าง)
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
		-- บางช่องอ่านไม่สำเร็จ = ข้อมูลพร่อง → อย่า lock slotsReady, auto-retry เอง (กัน NewGame ทับเซฟ)
		if failed and next(failed) then
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

	-- seed จาก state ที่ server prefetch slotList มาแล้วตอน join → พร้อมทันที ไม่ต้องรอ RequestSlots
	local seed = deps.getState and deps.getState()
	if seed and seed.slotList then MenuUI.updateSlots(seed) end
end

return MenuUI
