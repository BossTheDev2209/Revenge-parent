-- EditQTE.luau — มินิเกมตัดคลิป (docs/07 §3.4 + PDF หน้า 7): 20 ปุ่ม 1.5 วิ/ปุ่ม เต็ม 200
-- pure: scoreFor / pickKeys (lune เทส) | UI glue: start() overlay สร้างเอง (รอทีมทำ Gui_Computer จริง)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../../shared/Formulas")

local TOTAL_HITS = 20
local MIN_CONCURRENT = 2
local MAX_CONCURRENT = 4
local APPROACH_TIME = 1.5 -- วิ — เวลาที่วงแหวนใช้หดจากขนาดเริ่มมาเท่าวงเป้าหมาย

local EditQTE = {}
EditQTE.running = false

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

-- แบ่งงบรวม (20) เป็นเวฟสุ่มขนาด min-max วง — เวฟสุดท้ายเล็กกว่า min ได้ถ้างบเหลือไม่พอ
function EditQTE.planWaves(total: number, minC: number, maxC: number, rng): { number }
	rng = rng or math.random
	local waves = {}
	local remaining = total
	while remaining > 0 do
		local roll = minC + math.floor(rng() * (maxC - minC + 1))
		local size = math.min(roll, remaining)
		table.insert(waves, size)
		remaining -= size
	end
	return waves
end

-- ชุดคีย์สำหรับ PC — โซนซ้ายมือ เอื้อมง่าย ไม่ต้องขยับมือจากเมาส์มาก
local KEY_POOL = { "Q", "W", "E", "R", "A", "S", "D", "F" }

-- สุ่มคีย์ไม่ซ้ำ n ตัวจาก pool (แต่ละวงในเวฟต้องคีย์ต่างกัน ไม่งั้นกดคีย์เดียว resolve หลายวง)
-- Fisher-Yates partial — n เกิน #pool ได้แค่เท่า #pool (n สูงสุด = MAX_CONCURRENT พอกับ pool อยู่แล้ว)
function EditQTE.pickKeysUnique(n: number, pool, rng): { string }
	rng = rng or math.random
	local bag = {}
	for i, v in pool do
		bag[i] = v
	end
	local out = {}
	local count = math.min(n, #bag)
	for i = 1, count do
		local j = i + math.floor(rng() * (#bag - i + 1))
		bag[i], bag[j] = bag[j], bag[i]
		out[i] = bag[i]
	end
	return out
end

-- ตำแหน่งวงกลม n วง กระจายในกรอบ (0,0)-(1,1) เว้น margin ขอบ กันชนกันเองแบบหยาบๆ (retry สุ่มใหม่ถ้าใกล้กันเกิน)
function EditQTE.randomPositions(n: number, margin: number, rng): { { x: number, y: number } }
	rng = rng or math.random
	local out = {}
	local minGap = margin * 1.5
	for _ = 1, n do
		local x, y
		local tries = 0
		repeat
			x = margin + rng() * (1 - margin * 2)
			y = margin + rng() * (1 - margin * 2)
			tries += 1
			local tooClose = false
			for _, p in out do
				if (p.x - x) ^ 2 + (p.y - y) ^ 2 < minGap ^ 2 then
					tooClose = true
					break
				end
			end
			if not tooClose or tries > 8 then
				break
			end
		until false
		table.insert(out, { x = x, y = y })
	end
	return out
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
-- osu-style redesign (8 ส.ค.): เวฟ 2-4 วงพร้อมกัน แทนตัวอักษรทีละตัว
--   input เดียว (.Activated) ใช้ได้ทั้งคลิกเมาส์และแตะจอ — ไม่มี branch แยก platform
local UIAssets = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.UIAssets)
	else nil

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
local STAGGER = 0.32 -- วิ — วงถัดไปเริ่มหดช้ากว่าวงก่อนหน้าเท่านี้ (โผล่พร้อมกัน แต่หดไล่กัน)

local function mk(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

-- 1 วงกลม: วงเป้าหมาย (ปุ่มกดจริง label ตรงกลาง) + วงแหวนหดเข้าหา
--   labelText = ตัวอักษร (PC) หรือเลขลำดับ (mobile) · startDelay = รอกี่วิก่อนวงแหวนเริ่มหด (stagger)
--   คืน press() = ฟังก์ชัน resolve วงนี้ (คีย์บอร์ด PC เรียกผ่านตัวนี้ · เมาส์/แตะเรียกเองผ่าน .Activated)
-- onResolve(points 0-10, tier) เรียกครั้งเดียวเสมอ ไม่ว่ากดทันหรือหมดเวลา
local function spawnCircle(RunService, parent, posScale, labelText: string, startDelay: number, onResolve)
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
	local ringStroke = mk("UIStroke", ring, { Thickness = 4, Color = COLORS.ring, Transparency = 0.4 })

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
	local startAt = os.clock() + startDelay -- เวลาที่วงแหวน "เริ่มหด" (ก่อนหน้านี้ค้างขนาดเต็ม)

	local function finish(points: number)
		if resolved then return end
		resolved = true
		local tier = EditQTE.tierFor(points)
		btn.BackgroundColor3 = EditQTE.colorFor(tier)
		ring.Visible = false
		task.delay(0.25, function()
			btn:Destroy()
			ring:Destroy()
		end)
		onResolve(points, tier)
	end

	-- กด (คีย์/เมาส์/แตะ) — คิดคะแนนจากเวลาเทียบ startAt · กดก่อนวงเริ่มหด (t<0) = scoreFor คืน 0
	local function press()
		finish(EditQTE.scoreFor(os.clock() - startAt, APPROACH_TIME))
	end
	btn.Activated:Connect(press)

	task.spawn(function()
		while not resolved do
			local t = os.clock() - startAt
			if t >= APPROACH_TIME then
				finish(0) -- หมดเวลา = พลาด (แดง)
				break
			elseif t < 0 then
				-- ยังไม่ถึงคิวหด — ค้างขนาดเต็ม + จางๆ ให้รู้ว่ายังไม่ active
				ringStroke.Transparency = 0.7
			else
				ringStroke.Transparency = 0.1
				local k = t / APPROACH_TIME
				ring.Size = UDim2.fromOffset(SIZE_START - (SIZE_START - SIZE_TARGET) * k, SIZE_START - (SIZE_START - SIZE_TARGET) * k)
			end
			RunService.Heartbeat:Wait()
		end
	end)

	return press
end

-- 1 เวฟ = n วงโผล่พร้อมกัน หดเหลื่อมกัน (stagger) — block จนครบทุกวง คืน (คะแนนรวม, bucket)
-- useTouch = true → label เลข แตะจอ · false → label ตัวอักษร กดคีย์บอร์ด (คลิกเมาส์ก็ได้)
local function runWave(RunService, UIS, playArea, n: number, useTouch: boolean): (number, { [string]: number })
	local positions = EditQTE.randomPositions(n, PLAY_MARGIN)
	local keys = if useTouch then {} else EditQTE.pickKeysUnique(n, KEY_POOL)
	local byKey = {} -- ชื่อคีย์ → press() (เฉพาะ PC)
	local doneCount = 0
	local waveTotal = 0
	local buckets = { S = 0, A = 0, B = 0, C = 0 }

	local keyConn
	if not useTouch then
		keyConn = UIS.InputBegan:Connect(function(input, gp)
			if gp or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			local fn = byKey[input.KeyCode.Name]
			if fn then fn() end -- press() มี guard resolved อยู่แล้ว กดคีย์วงที่ resolve ไปแล้ว = no-op
		end)
	end

	for i = 1, n do
		local label = if useTouch then tostring(i) else keys[i]
		local press = spawnCircle(RunService, playArea, positions[i], label, (i - 1) * STAGGER,
			function(points, tier)
				waveTotal += points
				buckets[tier] += 1
				doneCount += 1
			end)
		if not useTouch and keys[i] then
			byKey[keys[i]] = press
		end
	end

	while doneCount < n do
		RunService.Heartbeat:Wait()
	end
	if keyConn then
		keyConn:Disconnect()
	end
	return waveTotal, buckets
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

	-- ★ พื้นหลังโปรแกรมตัดต่อ — มีรูป (UIAssets.edit_workspace_bg) ใช้เลย ไม่มี = ธีมเข้มแทนกล่องเทา
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
		local grad = mk("UIGradient", workspaceArea, {
			Color = ColorSequence.new(Color3.fromRGB(32, 36, 50), Color3.fromRGB(18, 20, 28)),
			Rotation = 45,
		})
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

	local round
	round = function()
		local waves = EditQTE.planWaves(TOTAL_HITS, MIN_CONCURRENT, MAX_CONCURRENT)
		local total = 0
		local buckets = { S = 0, A = 0, B = 0, C = 0 }
		summary.Visible = false
		workspaceArea.Visible = true
		waveInfo.Visible = true

		local howto = if useTouch then "แตะวงตามลำดับเลข" else "กดตัวอักษรบนวง"
		for waveIdx, n in waves do
			waveInfo.Text = ("เวฟ %d/%d — %s ตอนวงแหวนหดมาทับพอดี  |  สะสม %d/200")
				:format(waveIdx, #waves, howto, total)
			local waveTotal, waveBuckets = runWave(RunService, UIS, workspaceArea, n, useTouch)
			total += waveTotal
			for k, v in waveBuckets do
				buckets[k] += v
			end
			task.wait(0.3) -- เว้นจังหวะสั้นๆ ให้เห็นผลก่อนเวฟถัดไปโผล่
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
