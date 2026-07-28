-- EditQTE.luau — มินิเกมตัดคลิป (docs/07 §3.4 + PDF หน้า 7): 20 ปุ่ม 1.5 วิ/ปุ่ม เต็ม 200
-- pure: scoreFor / pickKeys (lune เทส) | UI glue: start() overlay สร้างเอง (รอทีมทำ Gui_Computer จริง)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../../shared/Formulas")

local QTE_KEYS = { "Q", "W", "E", "A", "S", "D", "Z", "X", "C" }
local QTE_COUNT = 20
local QTE_WINDOW = 1.5

local EditQTE = {}
EditQTE.running = false

-- คะแนนต่อปุ่ม: กดตรงกลาง window เป๊ะ = 10, ขอบ = 0 (ปัดลง)
function EditQTE.scoreFor(t: number, window: number): number
	local half = window / 2
	return math.max(0, math.floor(10 * (1 - math.abs(t - half) / half)))
end

function EditQTE.pickKeys(count: number, keys, rng)
	rng = rng or math.random
	local out = {}
	for i = 1, count do
		out[i] = keys[math.floor(rng() * #keys) + 1]
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

	local UIS = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")

	-- ===== layout ตามภาพร่าง `ui screenshot/PC-Edit-2/3 ui.png` =====
	--   จอตัดต่อ = แผงกลางจอ: กรอบ preview ใหญ่ (★ เว้นว่างรอรูป `edit_workspace_bg`/`clip_cover_*`)
	--   ใต้ preview = timeline + ปุ่มที่ต้องกด | จบรอบ = แถว Score/Video Quality + stats + ปุ่ม
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_EditQTE"
	gui.ResetOnSpawn = false
	local dim = Instance.new("Frame")
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.Parent = gui

	local panelFrame = Instance.new("Frame")
	panelFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	panelFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	panelFrame.Size = UDim2.new(0, 720, 0, 560)
	panelFrame.BackgroundColor3 = Color3.fromRGB(245, 246, 250)
	panelFrame.Parent = dim
	local ps = Instance.new("UIStroke")
	ps.Color = Color3.fromRGB(30, 60, 160)
	ps.Thickness = 3
	ps.Parent = panelFrame

	-- ★ กรอบ preview — พื้นที่รูปคลิป ยังไม่มีรูปก็เป็นกล่องเทา
	local preview = Instance.new("Frame")
	preview.Name = "ArtSlot_Preview"
	preview.Position = UDim2.new(0, 20, 0, 20)
	preview.Size = UDim2.new(1, -40, 0, 300)
	preview.BackgroundColor3 = Color3.fromRGB(225, 228, 234)
	preview.Parent = panelFrame
	local prs = Instance.new("UIStroke")
	prs.Color = Color3.fromRGB(30, 60, 160)
	prs.Thickness = 2
	prs.Parent = preview

	local keyLabel = Instance.new("TextLabel")
	keyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	keyLabel.Size = UDim2.new(0, 150, 0, 150)
	keyLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	keyLabel.TextScaled = true
	keyLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	keyLabel.BackgroundTransparency = 0.15
	keyLabel.TextColor3 = Color3.new(1, 1, 1)
	keyLabel.Parent = preview
	local kc = Instance.new("UICorner")
	kc.CornerRadius = UDim.new(0, 16)
	kc.Parent = keyLabel

	-- timeline ใต้ preview (ภาพร่าง: วง QTE วิ่งบน timeline)
	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 20, 0, 336)
	track.Size = UDim2.new(1, -40, 0, 18)
	track.BackgroundColor3 = Color3.new(1, 1, 1)
	track.Parent = panelFrame
	local ts = Instance.new("UIStroke")
	ts.Color = Color3.fromRGB(30, 60, 160)
	ts.Parent = track
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -4, 1, -4)
	bar.Position = UDim2.new(0, 2, 0, 2)
	bar.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
	bar.BorderSizePixel = 0
	bar.Parent = track

	local info = Instance.new("TextLabel")
	info.Position = UDim2.new(0, 20, 0, 362)
	info.Size = UDim2.new(1, -40, 0, 30)
	info.BackgroundTransparency = 1
	info.TextColor3 = Color3.fromRGB(30, 30, 40)
	info.TextScaled = true
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.Text = "กดปุ่มตามจังหวะ! ตรงกลางแถบ = คะแนนเต็ม"
	info.Parent = panelFrame

	-- ---------- จอสรุป (ซ่อนไว้ก่อน) ----------
	local summary = Instance.new("Frame")
	summary.Position = UDim2.new(0, 20, 0, 336)
	summary.Size = UDim2.new(1, -40, 1, -356)
	summary.BackgroundTransparency = 1
	summary.Visible = false
	summary.Parent = panelFrame

	local scoreRow = Instance.new("TextLabel")
	scoreRow.Size = UDim2.new(1, 0, 0, 40)
	scoreRow.BackgroundTransparency = 1
	scoreRow.TextColor3 = Color3.fromRGB(30, 60, 160)
	scoreRow.TextScaled = true
	scoreRow.TextXAlignment = Enum.TextXAlignment.Left
	scoreRow.Text = ""
	scoreRow.Parent = summary

	local rule = Instance.new("Frame")
	rule.Position = UDim2.new(0, 0, 0, 46)
	rule.Size = UDim2.new(1, 0, 0, 2)
	rule.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	rule.BorderSizePixel = 0
	rule.Parent = summary

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Position = UDim2.new(0, 0, 0, 56)
	statsLabel.Size = UDim2.new(0.5, -10, 1, -66)
	statsLabel.BackgroundTransparency = 1
	statsLabel.TextColor3 = Color3.fromRGB(30, 30, 40)
	statsLabel.TextSize = 18
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Text = ""
	statsLabel.Parent = summary

	local vrule = Instance.new("Frame")
	vrule.Position = UDim2.new(0.5, 0, 0, 56)
	vrule.Size = UDim2.new(0, 2, 1, -66)
	vrule.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	vrule.BorderSizePixel = 0
	vrule.Parent = summary

	local footageLabel = Instance.new("TextLabel")
	footageLabel.Position = UDim2.new(0.53, 0, 0, 56)
	footageLabel.Size = UDim2.new(0.47, 0, 0, 30)
	footageLabel.BackgroundTransparency = 1
	footageLabel.TextColor3 = Color3.fromRGB(30, 30, 40)
	footageLabel.TextScaled = true
	footageLabel.TextXAlignment = Enum.TextXAlignment.Left
	footageLabel.Text = ""
	footageLabel.Parent = summary

	gui.Parent = playerGui

	local made = 0 -- ตัดไปกี่คลิปในการนั่งครั้งนี้
	local round
	round = function()
		local seq = EditQTE.pickKeys(QTE_COUNT, QTE_KEYS)
		local total = 0
		local buckets = { S = 0, A = 0, B = 0, C = 0 } -- นับความแม่นต่อวง (ใช้ C/B/A/S ตาม design lock)
		summary.Visible = false
		track.Visible = true
		info.Visible = true
		bar.Visible = true
		for i, key in seq do
			keyLabel.Text = key
			info.Text = ("ปุ่มที่ %d/%d | คะแนน %d"):format(i, QTE_COUNT, total)
			local t0 = os.clock()
			local pressed = nil
			local conn = UIS.InputBegan:Connect(function(input, gp)
				if gp or pressed then return end
				if input.UserInputType == Enum.UserInputType.Keyboard then
					pressed = { key = input.KeyCode.Name, t = os.clock() - t0 }
				end
			end)
			while os.clock() - t0 < QTE_WINDOW and not pressed do
				bar.Size = UDim2.new(1 - (os.clock() - t0) / QTE_WINDOW, -4, 1, -4)
				RunService.Heartbeat:Wait()
			end
			conn:Disconnect()
			if pressed and pressed.key == key then
				local got = EditQTE.scoreFor(pressed.t, QTE_WINDOW)
				total += got
				local b = got >= 9 and "S" or got >= 6 and "A" or got >= 3 and "B" or "C"
				buckets[b] += 1
				keyLabel.TextColor3 = got >= 7 and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 220, 80)
			else
				buckets.C += 1
				keyLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
			end
			task.wait(0.15)
			keyLabel.TextColor3 = Color3.new(1, 1, 1)
		end

		fireAction({ type = "FinishEdit", score = total })
		made += 1

		-- จอสรุป (ภาพร่าง PC-Edit-3): Edit more = ตัดคลิปใหม่ต่อเลย | Done = ออก (อัปที่แอป Upload)
		local tier = Formulas.vidqTier(total)
		keyLabel.Text = tier
		keyLabel.TextColor3 = Color3.new(1, 1, 1)
		track.Visible = false
		info.Visible = false
		summary.Visible = true
		scoreRow.Text = ("Score : %d/200      Video Quality : %s"):format(total, tier)
		statsLabel.Text = ("stats:   %d  S\n           %d  A\n           %d  B\n           %d  C\n\nตัดอีกคลิป เสียใจอีก %d")
			:format(buckets.S, buckets.A, buckets.B, buckets.C, math.abs(Config.Mental.deltas.clipEdit))
		local st = getState()
		local capGB = Config.StorageLadderGB[st and st.upgrades and st.upgrades.storage or 1]
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
		local more = summaryBtn("Edit more", 0.63, Color3.fromRGB(80, 160, 255))
		local close = summaryBtn("Done", 0.87, Color3.fromRGB(120, 120, 130))

		more.Activated:Connect(function()
			if not EditQTE.canEdit(getState()) then
				EditQTE.toast(playerGui, ("footage ไม่พอ! ต้องมี %d GB — ออกไปอัดคลิปก่อน")
					:format(Config.Record.footagePerClipGB))
				return
			end
			more:Destroy()
			close:Destroy()
			keyLabel.TextColor3 = Color3.new(1, 1, 1)
			bar.Size = UDim2.new(1, -4, 1, -4)
			task.spawn(round)
		end)
		close.Activated:Connect(function()
			gui:Destroy()
			EditQTE.running = false
		end)
	end

	task.spawn(round)
end

return EditQTE
