-- EditQTE.luau — มินิเกมตัดคลิป (docs/07 §3.4 + PDF หน้า 7): 20 ปุ่ม 1.5 วิ/ปุ่ม เต็ม 200
-- pure: scoreFor / pickKeys (lune เทส) | UI glue: start() overlay สร้างเอง (รอทีมทำ Gui_Computer จริง)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../../shared/Formulas")

local TOTAL_HITS = 20 -- จำนวนวงต่อ 1 คลิป (chain ไหลต่อเนื่อง ไม่แบ่ง block)

local EditQTE = {}
EditQTE.running = false

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎮 เวอร์ชันการเล่น — สลับ MODE ตรงนี้ได้เลย (user เลือกได้ว่าชอบแบบไหน)
--   flow = วงไหลต่อเนื่อง มากสุด ~4 อันบนจอ (เร็ว มันส์ เหมาะคนชิน)
--   duo  = มากสุด 2 อันบนจอ ตำแหน่งไม่ซ้อนกัน (อ่านง่าย ไม่ตาลาย)
--   • maxOnScreen = วงสูงสุดที่โผล่พร้อมกัน · spawnInterval = ห่างการเด้งวงถัดไป (วิ)
--   • approach = เวลาที่วงแหวนหดจนทับวงเป้าหมาย (วิ) — สั้นลง = ยากขึ้น
-- ═══════════════════════════════════════════════════════════════════════════
EditQTE.MODE = "duo"
EditQTE.PRESETS = {
	flow = { maxOnScreen = 4, spawnInterval = 0.45, approach = 1.5 },
	duo = { maxOnScreen = 2, spawnInterval = 0.4, approach = 1.4 },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🔊 ระบบเสียง QTE — user สาย A แก้ตรงนี้ได้เลย (ไม่ต้องแตะ logic)
--   เล่นเสียง 1 ครั้งตอนกดแต่ละวง ตามเกรดที่ได้ (S/A/B/C)
--   ค่าคือ "ชื่อ Sound" ที่วางไว้ใน SoundService.SFX (ทีมเสียงวาง Sound object ตั้งชื่อตามนี้ จบ)
--   • เปลี่ยนเสียง: แก้ชื่อให้ตรงกับ Sound ที่มี หรือวาง Sound ใหม่ใน SoundService.SFX ใช้ชื่อนี้
--   • ปิดเสียงเกรดไหน: ใส่ "" · ระดับเสียงรวมคุมผ่านแอปตั้งค่า (master SoundGroup) อัตโนมัติ
-- ═══════════════════════════════════════════════════════════════════════════
EditQTE.SFX = {
	S = "qte_perfect", -- กดเป๊ะ (เขียว)
	A = "qte_good",    -- ดี (ฟ้า)
	B = "qte_ok",      -- พอใช้ (เหลือง)
	C = "qte_miss",    -- พลาด/หมดเวลา (แดง)
}

-- คะแนนต่อวง: พีคตอนวงแหวนหดมาเท่าวงเป้าหมายพอดี (t=window) ไล่เส้นตรงจาก 0 (เพิ่งโผล่)
-- redesign 8 ส.ค. — เดิมพีคกลาง window (10×(1-|t-half|/half)) เปลี่ยนให้ตรงกับภาพ "วงบีบมาทับกันพอดี = perfect"
function EditQTE.scoreFor(t: number, window: number): number
	if t <= 0 or window <= 0 then return 0 end
	return math.clamp(math.floor(10 * math.min(t, window) / window), 0, 10)
end

-- 9-10=S(เขียว) 6-8=A(ฟ้า) 3-5=B(เหลือง) 0-2=C(แดง) — พลาด/หมดเวลาก็เข้า C ผ่าน points=0
function EditQTE.tierFor(points: number): string
	if points >= 9 then
		return "S"
	elseif points >= 6 then
		return "A"
	elseif points >= 3 then
		return "B"
	else
		return "C"
	end
end

local TIER_COLOR = {
	S = Color3.fromRGB(80, 230, 140), -- เขียว
	A = Color3.fromRGB(90, 170, 255), -- ฟ้า
	B = Color3.fromRGB(255, 210, 80), -- เหลือง
	C = Color3.fromRGB(255, 90, 90), -- แดง (รวมกรณีพลาด/หมดเวลา)
}
function EditQTE.colorFor(tier: string): Color3
	return TIER_COLOR[tier] or TIER_COLOR.C
end

-- ชุดคีย์สำหรับ PC — โซนซ้ายมือ เอื้อมง่าย ไม่ต้องขยับมือจากเมาส์มาก
local KEY_POOL = { "Q", "W", "E", "R", "A", "S", "D", "F" }
EditQTE.KEY_POOL = KEY_POOL

-- เลือกคีย์ว่าง 1 ตัว (ไม่ชนกับวงที่ยัง active) — chain มีหลายวงพร้อมกัน คีย์ต้องไม่ซ้ำ
-- used = set { [keyName]=true } ของคีย์ที่ถูกใช้อยู่ · ไม่มีว่าง = คืนสุ่มทั้ง pool (เกิดยาก pool 8 > concurrent ~3)
function EditQTE.pickFreeKey(pool, used, rng): string
	rng = rng or math.random
	local free = {}
	for _, k in pool do
		if not (used and used[k]) then
			table.insert(free, k)
		end
	end
	local bag = if #free > 0 then free else pool
	return bag[math.floor(rng() * #bag) + 1]
end

-- สุ่ม 1 ตำแหน่งในกรอบ (0,0)-(1,1) เว้น margin ขอบ — เลือกจุดที่ "ไกลจากวง active มากสุด"
-- (best-of-N: สุ่มผู้สมัคร 12 จุด เลือกอันห่างสุด) กันวงใหม่โผล่ทับวงเดิมจนมองไม่เห็น
-- มีที่ว่าง = ไม่ทับแน่นอน · จอเต็ม = เลือกที่ห่างสุดเท่าที่ได้ (ดีกว่า retry แล้วยอมทับ)
function EditQTE.pickPosition(margin: number, avoid, rng): { x: number, y: number }
	rng = rng or math.random
	local best, bestDist = nil, -1
	for _ = 1, 12 do
		local x = margin + rng() * (1 - margin * 2)
		local y = margin + rng() * (1 - margin * 2)
		local nearest = math.huge
		if avoid then
			for _, p in avoid do
				local d = (p.x - x) ^ 2 + (p.y - y) ^ 2
				if d < nearest then
					nearest = d
				end
			end
		end
		if nearest > bestDist then
			best, bestDist = { x = x, y = y }, nearest
		end
	end
	return best
end

-- footage พอตัด 1 คลิปไหม (pure — กติกาเดียวกับ RecordService ฝั่ง server)
function EditQTE.canEdit(state): boolean
	return state ~= nil and (state.footageGB or 0) >= Config.Record.footagePerClipGB
end

-- ข้อความเตือนกลางจอ 2 วิ (ใช้ตอน footage ไม่พอ)
function EditQTE.toast(playerGui, text: string)
	local g = Instance.new("ScreenGui")
	g.ResetOnSpawn = false
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(0, 520, 0, 50)
	l.Position = UDim2.new(0.5, -260, 0.35, 0)
	l.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	l.Text = text
	l.Parent = g
	g.Parent = playerGui
	task.delay(2, function() g:Destroy() end)
end

-- ===== UI glue (Studio เท่านั้น) =====
-- osu-style redesign (8 ส.ค.): chain 20 วงไหลต่อเนื่อง (ไม่แบ่ง block) + เสียงตามเกรด
--   PC = กดตัวอักษร · มือถือ = แตะเลข · เสียงเล่นตอนกดแต่ละวงตาม tier (EditQTE.SFX)
local UIAssets = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.UIAssets)
	else nil
-- AudioService อยู่ที่ SPS.AudioService (EditQTE = SPS.UI.Apps.EditQTE → ขึ้น 3 ชั้น)
local AudioService = if isStudio
	then require(script.Parent.Parent.Parent.AudioService)
	else nil

-- เล่นเสียงตามเกรด — ผ่านระบบกลาง AudioService.sfx (คุม master volume ให้เอง)
-- ชื่อเสียงมาจาก EditQTE.SFX (user แก้ได้) ต้องมี Sound ชื่อนั้นใน SoundService.SFX ไม่งั้นเงียบ (ไม่พัง)
local function playGradeSfx(tier: string)
	local name = EditQTE.SFX[tier]
	if AudioService and name and name ~= "" then
		AudioService.sfx(name)
	end
end

local COLORS = {
	panel = Color3.fromRGB(18, 20, 28),
	header = Color3.fromRGB(26, 29, 40),
	workspace = Color3.fromRGB(24, 27, 37),
	accent = Color3.fromRGB(90, 140, 240),
	text = Color3.fromRGB(235, 236, 242),
	dim = Color3.fromRGB(150, 154, 168),
	circleFill = Color3.fromRGB(40, 44, 58),
	ring = Color3.fromRGB(220, 224, 236),
}

local PLAY_MARGIN = 0.22 -- scale — เว้นขอบกันวงแหวนขนาดใหญ่สุดล้นขอบ play area

local function mk(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

-- 1 วงกลม: วงเป้าหมาย (ปุ่มกดจริง label ตรงกลาง) + วงแหวนหดเข้าหา (โผล่ปุ๊บเริ่มหดเลย)
--   labelText = ตัวอักษร (PC) หรือเลขลำดับ (mobile) · approachTime = เวลาหดจนทับ (จาก preset)
--   คืน press() = ฟังก์ชัน resolve วงนี้ (คีย์บอร์ด PC เรียกผ่านตัวนี้ · เมาส์/แตะเรียกเองผ่าน .Activated)
-- onResolve(points, tier) = ตอนกด/หมดเวลา (คิดคะแนน+เสียงทันที) · onCleared() = ตอนวงหายจากจอจริง
--   แยกกันเพราะวงโชว์สี tier ค้าง 0.25 วิ ก่อนหาย — ต้องยังนับเป็น "วงบนจอ" ช่วงนั้น (cap/กันซ้อน)
local function spawnCircle(RunService, parent, posScale, labelText: string, approachTime: number, onResolve, onCleared)
	local SIZE_TARGET = 84
	local SIZE_START = 190

	local ring = mk("Frame", parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(posScale.x, posScale.y),
		Size = UDim2.fromOffset(SIZE_START, SIZE_START),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
	mk("UICorner", ring, { CornerRadius = UDim.new(1, 0) })
	local ringStroke = mk("UIStroke", ring, { Thickness = 4, Color = COLORS.ring, Transparency = 0.1 })

	local btn = mk("TextButton", parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(posScale.x, posScale.y),
		Size = UDim2.fromOffset(SIZE_TARGET, SIZE_TARGET),
		BackgroundColor3 = COLORS.circleFill,
		AutoButtonColor = false,
		Text = labelText,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		FontFace = Font.fromEnum(Enum.Font.GothamBold),
		ZIndex = 3,
	})
	mk("UICorner", btn, { CornerRadius = UDim.new(1, 0) })
	mk("UIStroke", btn, { Thickness = 3, Color = COLORS.accent, Transparency = 0.15 })
	local pad = mk("UIPadding", btn, {}) -- กัน label ชิดขอบวงกลมตอน TextScaled
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.PaddingTop = UDim.new(0, 18)
	pad.PaddingBottom = UDim.new(0, 18)

	local resolved = false
	local startAt = os.clock() -- โผล่ปุ๊บวงแหวนเริ่มหดทันที

	local function finish(points: number)
		if resolved then return end
		resolved = true
		local tier = EditQTE.tierFor(points)
		btn.BackgroundColor3 = EditQTE.colorFor(tier)
		ring.Visible = false
		onResolve(points, tier) -- คะแนน/เสียง/done ทันทีที่กด
		task.delay(0.25, function() -- โชว์สี tier ค้างแป๊บ แล้วค่อยหาย + ปลด slot บนจอ
			btn:Destroy()
			ring:Destroy()
			if onCleared then onCleared() end
		end)
	end

	-- กด (คีย์/เมาส์/แตะ) — คิดคะแนนจากเวลาเทียบ startAt
	local function press()
		finish(EditQTE.scoreFor(os.clock() - startAt, approachTime))
	end
	btn.Activated:Connect(press)

	task.spawn(function()
		while not resolved do
			local t = os.clock() - startAt
			if t >= approachTime then
				finish(0) -- หมดเวลา = พลาด (แดง)
				break
			end
			local k = t / approachTime
			ring.Size = UDim2.fromOffset(SIZE_START - (SIZE_START - SIZE_TARGET) * k, SIZE_START - (SIZE_START - SIZE_TARGET) * k)
			RunService.Heartbeat:Wait()
		end
	end)

	return press
end

-- ฉากหลังจำลอง "หน้าโปรแกรมตัดต่อ" (ใช้เมื่อยังไม่มีรูป UIAssets.edit_workspace_bg)
-- ทุกชิ้น ZIndex 0-1 → อยู่ใต้วงกลม QTE (ZIndex 2-3) เสมอ · ใส่รูปจริงทีหลัง = ImageLabel ทับ mock นี้
-- โครง: toolbar บน · media bin ซ้าย · preview กลาง · timeline หลายแทร็ก+clip+playhead ล่าง
local function buildEditorMock(area)
	local BG = Color3.fromRGB(22, 24, 33)
	local PANEL2 = Color3.fromRGB(30, 33, 45)
	local LINE = Color3.fromRGB(46, 50, 66)
	area.BackgroundColor3 = BG

	-- ===== toolbar บนสุด =====
	local bar = mk("Frame", area, { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = PANEL2, BorderSizePixel = 0, ZIndex = 0 })
	for i, c in { Color3.fromRGB(230, 90, 90), Color3.fromRGB(235, 190, 80), Color3.fromRGB(90, 200, 120) } do
		local d = mk("Frame", bar, { Size = UDim2.fromOffset(9, 9), Position = UDim2.fromOffset(10 + (i - 1) * 14, 8), BackgroundColor3 = c, BorderSizePixel = 0, ZIndex = 1 })
		mk("UICorner", d, { CornerRadius = UDim.new(1, 0) })
	end
	for i = 1, 6 do
		local s = mk("Frame", bar, { Size = UDim2.fromOffset(16, 12), Position = UDim2.fromOffset(70 + (i - 1) * 22, 7), BackgroundColor3 = LINE, BorderSizePixel = 0, ZIndex = 1 })
		mk("UICorner", s, { CornerRadius = UDim.new(0, 3) })
	end

	-- ===== media bin ซ้าย (คลังคลิป) =====
	local bin = mk("Frame", area, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(0, 120, 1, -136), BackgroundColor3 = PANEL2, BorderSizePixel = 0, ZIndex = 0 })
	for r = 0, 3 do
		local th = mk("Frame", bin, { Position = UDim2.fromOffset(10, 10 + r * 46), Size = UDim2.fromOffset(100, 38), BackgroundColor3 = LINE, BorderSizePixel = 0, ZIndex = 1 })
		mk("UICorner", th, { CornerRadius = UDim.new(0, 4) })
		mk("UIGradient", th, { Color = ColorSequence.new(Color3.fromRGB(62, 68, 92), Color3.fromRGB(38, 42, 56)), Rotation = 30 })
	end

	-- ===== preview กลาง (คำจางๆ ให้รู้ว่าเป็นจอ preview) =====
	mk("TextLabel", area, { Position = UDim2.fromOffset(120, 26), Size = UDim2.new(1, -120, 1, -136), BackgroundTransparency = 1, Text = "PREVIEW", TextColor3 = Color3.fromRGB(48, 52, 70), TextSize = 22, FontFace = Font.fromEnum(Enum.Font.GothamBold), ZIndex = 0 })

	-- ===== timeline ล่าง =====
	local tl = mk("Frame", area, { Position = UDim2.new(0, 0, 1, -110), Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = PANEL2, BorderSizePixel = 0, ZIndex = 0 })
	local ruler = mk("Frame", tl, { Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = Color3.fromRGB(26, 28, 38), BorderSizePixel = 0, ZIndex = 1 })
	for i = 0, 20 do
		mk("Frame", ruler, { Position = UDim2.new(i / 20, 0, 0, 8), Size = UDim2.fromOffset(1, 8), BackgroundColor3 = LINE, BorderSizePixel = 0, ZIndex = 1 })
	end
	local clipColors = { Color3.fromRGB(70, 120, 210), Color3.fromRGB(150, 100, 200), Color3.fromRGB(80, 170, 130) }
	local layout = { { { 0.02, 0.28 }, { 0.34, 0.22 } }, { { 0.05, 0.4 } }, { { 0.2, 0.18 }, { 0.5, 0.35 } } }
	for row = 1, 3 do
		local ty = 20 + (row - 1) * 30
		mk("Frame", tl, { Position = UDim2.fromOffset(0, ty), Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Color3.fromRGB(24, 26, 36), BorderSizePixel = 0, ZIndex = 0 })
		for _, b in layout[row] do
			local blk = mk("Frame", tl, { Position = UDim2.new(b[1], 4, 0, ty + 3), Size = UDim2.new(b[2], -4, 0, 22), BackgroundColor3 = clipColors[row], BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 1 })
			mk("UICorner", blk, { CornerRadius = UDim.new(0, 3) })
		end
	end
	local ph = mk("Frame", tl, { Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = Color3.fromRGB(235, 90, 90), BorderSizePixel = 0, ZIndex = 1 })
	mk("Frame", ph, { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(10, 8), Position = UDim2.new(0.5, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(235, 90, 90), BorderSizePixel = 0, ZIndex = 1 })
end

-- fireAction = function(actionTable) ยิงเข้า Remotes.Action (Main.client ส่งมา)
-- getState = function() คืน state ล่าสุด (ใช้เช็ค footage ก่อนตัดทุกรอบ)
function EditQTE.start(playerGui, fireAction, getState)
	if EditQTE.running then return end
	getState = getState or function() return nil end
	if not EditQTE.canEdit(getState()) then
		EditQTE.toast(playerGui, ("footage ไม่พอ! ต้องมี %d GB — ออกไปอัดคลิปก่อน")
			:format(Config.Record.footagePerClipGB))
		return
	end
	EditQTE.running = true

	local RunService = game:GetService("RunService")
	local GuiService = game:GetService("GuiService")
	local UIS = game:GetService("UserInputService")

	-- มือถือ/แท็บเล็ต (touch ไม่มีคีย์บอร์ด) = แตะเลข · PC/มีคีย์บอร์ด = กดตัวอักษร
	local useTouch = UIS.TouchEnabled and not UIS.KeyboardEnabled

	local PANEL_W, PANEL_H = 720, 560

	local gui = mk("ScreenGui", nil, { Name = "Gui_EditQTE", ResetOnSpawn = false, DisplayOrder = 8 })
	mk("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5 })

	local panel = mk("Frame", gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PANEL_W, PANEL_H),
		BackgroundColor3 = COLORS.panel,
	})
	mk("UICorner", panel, { CornerRadius = UDim.new(0, 16) })
	mk("UIStroke", panel, { Thickness = 2, Color = COLORS.accent, Transparency = 0.3 })

	-- responsive: ย่อทั้งแผงให้พอดีจอ (pattern เดียวกับ ShopKiosk.fitScale)
	local uiScale = mk("UIScale", panel, {})
	local cam = workspace.CurrentCamera
	local function fitToScreen()
		local vp = cam.ViewportSize
		local inset = GuiService:GetGuiInset()
		local margin = 24
		local fit = math.min((vp.X - margin * 2) / PANEL_W, (vp.Y - inset.Y - margin * 2) / PANEL_H)
		uiScale.Scale = math.clamp(fit, 0.35, 1)
	end
	fitToScreen()
	local fitConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

	local header = mk("Frame", panel, {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = COLORS.header,
	})
	mk("UICorner", header, { CornerRadius = UDim.new(0, 16) })
	mk("TextLabel", header, {
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -40, 1, 0),
		BackgroundTransparency = 1,
		Text = "🎬  โปรแกรมตัดต่อ",
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		FontFace = Font.fromEnum(Enum.Font.GothamBold),
	})

	-- ★ พื้นหลังโปรแกรมตัดต่อ — มีรูป (UIAssets.edit_workspace_bg) ใช้เลย · ไม่มี = mock วาดด้วยโค้ด
	local workspaceArea = mk("Frame", panel, {
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 0, 380),
		BackgroundColor3 = COLORS.workspace,
		ClipsDescendants = true,
	})
	mk("UICorner", workspaceArea, { CornerRadius = UDim.new(0, 12) })
	if UIAssets and UIAssets.edit_workspace_bg ~= "" then
		mk("ImageLabel", workspaceArea, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIAssets.edit_workspace_bg,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 0,
		})
	else
		buildEditorMock(workspaceArea) -- จำลองหน้าโปรแกรมตัดต่อด้วยโค้ด (ทับได้ด้วยรูปจริงทีหลัง)
	end

	local waveInfo = mk("TextLabel", panel, {
		Position = UDim2.fromOffset(20, 448),
		Size = UDim2.new(1, -40, 0, 30),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.dim,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})

	-- ---------- จอสรุป (ซ่อนไว้ก่อน) ----------
	local summary = Instance.new("Frame")
	summary.Position = UDim2.new(0, 20, 0, 60)
	summary.Size = UDim2.new(1, -40, 0, 418)
	summary.BackgroundTransparency = 1
	summary.Visible = false
	summary.Parent = panel

	local scoreRow = Instance.new("TextLabel")
	scoreRow.Size = UDim2.new(1, 0, 0, 40)
	scoreRow.BackgroundTransparency = 1
	scoreRow.TextColor3 = COLORS.accent
	scoreRow.TextScaled = true
	scoreRow.TextXAlignment = Enum.TextXAlignment.Left
	scoreRow.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	scoreRow.Text = ""
	scoreRow.Parent = summary

	local rule = Instance.new("Frame")
	rule.Position = UDim2.new(0, 0, 0, 46)
	rule.Size = UDim2.new(1, 0, 0, 2)
	rule.BackgroundColor3 = COLORS.header
	rule.BorderSizePixel = 0
	rule.Parent = summary

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Position = UDim2.new(0, 0, 0, 56)
	statsLabel.Size = UDim2.new(0.5, -10, 1, -66)
	statsLabel.BackgroundTransparency = 1
	statsLabel.TextColor3 = COLORS.text
	statsLabel.TextSize = 18
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Text = ""
	statsLabel.Parent = summary

	local vrule = Instance.new("Frame")
	vrule.Position = UDim2.new(0.5, 0, 0, 56)
	vrule.Size = UDim2.new(0, 2, 1, -66)
	vrule.BackgroundColor3 = COLORS.header
	vrule.BorderSizePixel = 0
	vrule.Parent = summary

	local footageLabel = Instance.new("TextLabel")
	footageLabel.Position = UDim2.new(0.53, 0, 0, 56)
	footageLabel.Size = UDim2.new(0.47, 0, 0, 30)
	footageLabel.BackgroundTransparency = 1
	footageLabel.TextColor3 = COLORS.text
	footageLabel.TextScaled = true
	footageLabel.TextXAlignment = Enum.TextXAlignment.Left
	footageLabel.Text = ""
	footageLabel.Parent = summary

	gui.Parent = playerGui

	local preset = EditQTE.PRESETS[EditQTE.MODE] or EditQTE.PRESETS.flow

	local round
	round = function()
		local total = 0
		local done = 0
		local active = 0 -- วงที่โชว์อยู่บนจอตอนนี้ (spawn แล้วยังไม่ resolve) — ใช้ cap maxOnScreen
		local buckets = { S = 0, A = 0, B = 0, C = 0 }
		local activeKeys = {} -- คีย์ที่วง active ใช้อยู่ (PC — กันคีย์ซ้ำในวงที่ซ้อนเวลากัน)
		local activePos = {} -- ตำแหน่งวง active (กันวงใหม่โผล่ทับวงเดิม)
		local byKey = {} -- ชื่อคีย์ → press() ของวง active ตัวนั้น (PC)
		summary.Visible = false
		workspaceArea.Visible = true
		waveInfo.Visible = true

		-- คีย์บอร์ด (PC) — ต่อครั้งเดียวตลอด chain · กดคีย์ = resolve วงของคีย์นั้น
		local keyConn
		if not useTouch then
			keyConn = UIS.InputBegan:Connect(function(input, gp)
				if gp or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
				local fn = byKey[input.KeyCode.Name]
				if fn then fn() end -- press() guard resolved อยู่แล้ว
			end)
		end

		local howto = if useTouch then "แตะวงตามเลข" else "กดตัวอักษรบนวง"
		-- chain: เด้งวงทีละอัน · cap ไม่เกิน preset.maxOnScreen อันบนจอ (duo = 2) · ตำแหน่งไม่ทับวง active
		for i = 1, TOTAL_HITS do
			-- รอให้มีที่ว่าง (จำนวนวงบนจอไม่เกิน maxOnScreen) ก่อนเด้งอันใหม่
			while active >= preset.maxOnScreen do
				RunService.Heartbeat:Wait()
			end
			waveInfo.Text = ("อันที่ %d/%d — %s ตอนวงแหวนหดมาทับพอดี  |  สะสม %d/200")
				:format(i, TOTAL_HITS, howto, total)
			local pos = EditQTE.pickPosition(PLAY_MARGIN, activePos)
			local posKey = pos -- reference เดียวกัน ใช้ลบออกจาก activePos ตอน resolve
			table.insert(activePos, posKey)
			local key = if useTouch then nil else EditQTE.pickFreeKey(KEY_POOL, activeKeys)
			if key then activeKeys[key] = true end
			local label = if useTouch then tostring(i) else key
			active += 1

			local press
			press = spawnCircle(RunService, workspaceArea, pos, label, preset.approach,
				function(points, tier) -- onResolve: ทันทีที่กด/หมดเวลา
					total += points
					buckets[tier] += 1
					done += 1
					playGradeSfx(tier)
				end,
				function() -- onCleared: วงหายจากจอจริง (หลังโชว์สี 0.25 วิ) → คืน slot + ตำแหน่ง + คีย์
					active -= 1
					if key then
						activeKeys[key] = nil
						if byKey[key] == press then byKey[key] = nil end
					end
					for idx, p in activePos do
						if p == posKey then
							table.remove(activePos, idx)
							break
						end
					end
				end)
			if key then byKey[key] = press end
			task.wait(preset.spawnInterval)
		end

		-- รอวงที่ยังค้างบนจอ (spawn ครบแล้วแต่ยังหดไม่จบ) ให้ resolve หมดก่อนสรุป
		while done < TOTAL_HITS do
			RunService.Heartbeat:Wait()
		end
		if keyConn then
			keyConn:Disconnect()
		end

		fireAction({ type = "FinishEdit", score = total })

		-- จอสรุป: Edit more = ตัดคลิปใหม่ต่อเลย | Done = ออก (อัปที่แอป Upload)
		local tier = Formulas.vidqTier(total)
		workspaceArea.Visible = false
		waveInfo.Visible = false
		summary.Visible = true
		scoreRow.Text = ("Score : %d/200      Video Quality : %s"):format(total, tier)
		statsLabel.Text = ("stats:   %d  S\n           %d  A\n           %d  B\n           %d  C\n\nตัดอีกคลิป เสียใจอีก %d")
			:format(buckets.S, buckets.A, buckets.B, buckets.C, math.abs(Config.Mental.deltas.clipEdit))
		local st = getState()
		local capGB = Config.StorageLadderGB[st and Formulas.activeLevel(st, "storage") or 1]
			or Config.StorageLadderGB[1]
		footageLabel.Text = ("footage left: %d GB / %d GB"):format(
			math.floor(st and st.footageGB or 0), capGB)

		local function summaryBtn(text, xScale, color)
			local b = Instance.new("TextButton")
			b.AnchorPoint = Vector2.new(0.5, 1)
			b.Position = UDim2.new(xScale, 0, 1, -6)
			b.Size = UDim2.new(0, 150, 0, 40)
			b.Text = text
			b.TextScaled = true
			b.TextColor3 = Color3.new(1, 1, 1)
			b.BackgroundColor3 = color
			b.Parent = summary
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 8)
			c.Parent = b
			return b
		end
		local more = summaryBtn("Edit more", 0.63, COLORS.accent)
		local close = summaryBtn("Done", 0.87, Color3.fromRGB(90, 92, 104))

		more.Activated:Connect(function()
			if not EditQTE.canEdit(getState()) then
				EditQTE.toast(playerGui, ("footage ไม่พอ! ต้องมี %d GB — ออกไปอัดคลิปก่อน")
					:format(Config.Record.footagePerClipGB))
				return
			end
			more:Destroy()
			close:Destroy()
			task.spawn(round)
		end)
		close.Activated:Connect(function()
			fitConn:Disconnect()
			gui:Destroy()
			EditQTE.running = false
		end)
	end

	task.spawn(round)
end

return EditQTE
