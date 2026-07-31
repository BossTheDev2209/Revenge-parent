-- InteractBinder.luau — หา Interact_* ทุกตัวใน Workspace แล้วแปะ ProximityPrompt (runtime ฝั่ง client)
-- ทีมวางแค่ Part ชื่อถูกตาม docs/05 §3 — prompt กับ logic มาจากไฟล์นี้
-- deps = { fireAction = fn(actionTable), startQTE = fn() } ส่งมาจาก Main.client (ไม่ require กันเอง)
local InteractBinder = {}

local PROMPT_TEXT = {
	Interact_Camera = "ใช้คอมพิวเตอร์",
	Interact_pcMonitor = "ใช้คอมพิวเตอร์",
	Interact_Bed = "พักผ่อน",
	Interact_Kitchen = "กินข้าว",
	Interact_Exercise = "ออกกำลังกาย",
	Interact_NPC_Mom = "คุยกับแม่",
	Interact_NotebookPack = "เก็บโน้ตบุ๊ค",
	Interact_Shop = "เข้าร้านค้า",
	Interact_Door = "เข้าไป",
}

-- ===== ประตู (docs/02 §9.9) =====
-- Attribute บนบานประตู: `Target` = ชื่อ Part ปลายทาง · `MinFollower` = follower ที่ต้องมี (0/ไม่ใส่ = เข้าได้เลย)
-- ยังไม่ปลด = ขึ้นข้อความบอกว่าต้องมีกี่ follower · ไม่มี Target = เตือนคนวางแมพ
-- pure: ตัดสินว่าเข้าได้ไหม — เทสได้
function InteractBinder.doorCheck(follower: number, minFollower: number?): (boolean, string?)
	local need = tonumber(minFollower) or 0
	if follower >= need then return true end
	return false, ("ยังเข้าไม่ได้ (ต้องมี %s follower)"):format(
		need >= 1000 and ("%dK"):format(need / 1000) or tostring(need))
end

-- Interact_NPC_<ชื่อ> → ไฟล์บทใน Content/Dialogue (ชื่อ Part = ชื่อโมเดลตัด prefix — docs/05 §4)
--   5 พิเศษ (StoryNPC) → ไฟล์บทเดิมที่มีอยู่แล้ว | 12 ประจำเฟส (WorldNPC) → ไฟล์ชื่อตัวเอง
-- key ต้อง bracket-quote: Luau identifier รับ ASCII เท่านั้น ชื่อ Part ไทยเป็น key เปล่าไม่ได้ (คอมไพล์ไม่ผ่าน)
local NPC_DIALOGUE = {
	-- ===== 5 พิเศษ (เนื้อเรื่อง) =====
	["Interact_NPC_แม่"] = "Mom",
	["Interact_NPC_พ่อ"] = "Dad",
	["Interact_NPC_เพื่อนร่วมทาง1"] = "Friend1", -- ทรยศ 500K
	["Interact_NPC_เพื่อนร่วมทาง2"] = "Friend2", -- อยู่จนจบ
	["Interact_NPC_CC"] = "CC1", -- คู่แข่ง
	-- ===== 12 ประจำเฟส (คนละคนต่อเฟส 4/เฟส) — ไฟล์บทอยู่ Content/Dialogue ชื่อเดียวกับ NPC =====
	["Interact_NPC_ลุงสืบ"] = "ลุงสืบ",
	["Interact_NPC_พี่แหนม"] = "พี่แหนม",
	["Interact_NPC_ลุงชัย"] = "ลุงชัย",
	["Interact_NPC_ป้าไหม"] = "ป้าไหม",
	["Interact_NPC_หมวย"] = "หมวย",
	["Interact_NPC_ออโต้"] = "ออโต้",
	["Interact_NPC_ลุงฮาซาน"] = "ลุงฮาซาน",
	["Interact_NPC_พี่โชคชัย"] = "พี่โชคชัย",
	["Interact_NPC_น้ำปั่น"] = "น้ำปั่น",
	["Interact_NPC_เกรซ"] = "เกรซ",
	["Interact_NPC_พี่มีนา"] = "พี่มีนา",
	["Interact_NPC_ลุงนรินท์"] = "ลุงนรินท์",
}

-- เลือกชุดบทจากไฟล์เดียว: หลังทรยศใช้ after ก่อน ไม่งั้นไล่จากเฟสปัจจุบันลงไปหาชุดที่ใกล้สุด
-- ไฟล์เก่าที่เป็น list ของ string ตรงๆ (ไม่มี key เฟส) ใช้ได้เหมือนเดิม
function InteractBinder.pickLines(mod, state)
	if type(mod) ~= "table" then return nil end
	if type(mod[1]) == "string" then return mod end -- format เก่า
	if state and state.flags and state.flags.betrayed and mod.after then return mod.after end
	local phase = state and state.phase or 1
	for p = phase, 1, -1 do
		if mod["p" .. p] then return mod["p" .. p] end
	end
	return mod.p1 or mod.after
end

-- เตียงมี 2 ทาง (docs/02 §3): พักผ่อน = activity ฟื้นใจ | นอน = ข้ามเวลา 8/12 ชม. + ล้าง NoSleep
local function openBedMenu(playerGui, fireAction)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_BedMenu"
	gui.ResetOnSpawn = false
	local function btn(text, x, action)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 180, 0, 48)
		b.Position = UDim2.new(0.5, x, 0.5, -24)
		b.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextScaled = true
		b.Text = text
		b.Parent = gui
		b.Activated:Connect(function()
			if action then fireAction(action) end
			gui:Destroy()
		end)
	end
	btn("😌 พักผ่อน (+ใจ)", -280, { type = "DoActivity", activity = "Bed" })
	btn("😴 นอน (ข้ามเวลา)", -90, { type = "Sleep" })
	btn("❌ ยกเลิก", 100, nil)
	gui.Parent = playerGui
end

-- ข้อความกลางจอ 2 วิ (ประตูล็อก / ประตูยังไม่ตั้ง Attribute)
local function toast(playerGui, text: string)
	local g = Instance.new("ScreenGui")
	g.ResetOnSpawn = false
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(0, 460, 0, 46)
	l.Position = UDim2.new(0.5, -230, 0.32, 0)
	l.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	l.BackgroundTransparency = 0.15
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	l.Text = text
	l.Parent = g
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = l
	g.Parent = playerGui
	task.delay(2, function() g:Destroy() end)
end

-- ป้ายชื่อเหนือจุด interact (BillboardGui ที่ทีมแปะไว้เอง) — จางตามระยะ
-- ไม่งั้นป้ายลอยเด่นทั้งแมพ เห็นตั้งแต่อีกฝั่งเมือง (user feedback 28 ก.ค.)
-- ระยะอ้างอิง ProximityPrompt.MaxActivationDistance (default 10): ชัดเต็มตอนกดได้พอดี
local LABEL_CLEAR_STUDS = 14 -- ใกล้กว่านี้ = ชัดเต็ม
local LABEL_GONE_STUDS = 30 -- ไกลกว่านี้ = หายสนิท

-- pure: ระยะ → ความโปร่งใส (0 = ชัด, 1 = หาย) — เทสได้
function InteractBinder.labelAlpha(distance: number): number
	if distance <= LABEL_CLEAR_STUDS then return 0 end
	if distance >= LABEL_GONE_STUDS then return 1 end
	return (distance - LABEL_CLEAR_STUDS) / (LABEL_GONE_STUDS - LABEL_CLEAR_STUDS)
end

function InteractBinder.init(deps)
	local function onTriggered(name, part)
		if name == "Interact_Camera" or name == "Interact_pcMonitor" then
			-- part = จอจริง: UI แปะบนหน้า part นี้ (SurfaceGui) + กล้อง zoom เข้าหา
			deps.openPC(part)
		elseif name == "Interact_NotebookPack" then
			deps.fireAction({ type = "PickupNotebook" })
		elseif name == "Interact_Shop" then
			deps.openShop()
		elseif name == "Interact_Bed" then
			openBedMenu(deps.playerGui, deps.fireAction)
		elseif name == "Interact_Kitchen" or name == "Interact_Exercise" then
			deps.fireAction({ type = "DoActivity", activity = name:gsub("Interact_", "") })
		elseif name == "Interact_Door" then
			-- teleport ฝั่ง client พอ (singleplayer) — ปลายทางกับเงื่อนไขอ่านจาก Attribute ของบานประตู
			local state = deps.getState and deps.getState() or nil
			local ok, why = InteractBinder.doorCheck(state and state.follower or 0, part:GetAttribute("MinFollower"))
			if not ok then
				toast(deps.playerGui, why)
				return
			end
			local targetName = part:GetAttribute("Target")
			local target = targetName and workspace:FindFirstChild(targetName, true)
			if not target or not target:IsA("BasePart") then
				toast(deps.playerGui, ("ประตูนี้ยังไม่ตั้งปลายทาง (Attribute Target=%s)"):format(tostring(targetName)))
				return
			end
			local char = game:GetService("Players").LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then root.CFrame = target.CFrame + Vector3.new(0, 3, 0) end
		elseif NPC_DIALOGUE[name] then
			deps.startDialogue(NPC_DIALOGUE[name])
		else
			warn("[InteractBinder] ยังไม่ผูก logic:", name)
		end
	end

	-- ป้ายที่ต้องจางตามระยะ — เก็บไว้ให้ loop เดียวอัปเดตทั้งหมด
	local labels = {}
	local function trackLabel(inst)
		local bb = inst:FindFirstChildOfClass("BillboardGui")
		if bb then labels[bb] = inst end
	end

	local function bind(inst)
		if not inst:IsA("BasePart") then return end
		if not inst.Name:match("^Interact_") then return end
		trackLabel(inst)
		if inst:FindFirstChildOfClass("ProximityPrompt") then return end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = PROMPT_TEXT[inst.Name]
			or (inst.Name:match("^Interact_NPC") and "คุย")
			or inst.Name:gsub("Interact_", "")
		prompt.ObjectText = ""
		prompt.HoldDuration = 0.3
		prompt.Triggered:Connect(function()
			onTriggered(inst.Name, inst)
		end)
		prompt.Parent = inst
	end

	for _, d in workspace:GetDescendants() do
		bind(d)
	end
	workspace.DescendantAdded:Connect(bind)

	-- จางป้ายตามระยะ — เดินเข้าใกล้ค่อยโผล่ ไม่ใช่เห็นเด่นทั้งแมพ
	local player = game:GetService("Players").LocalPlayer
	game:GetService("RunService").Heartbeat:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		for bb, part in labels do
			if not bb.Parent or not part.Parent then
				labels[bb] = nil
			else
				local a = root and InteractBinder.labelAlpha((root.Position - part.Position).Magnitude) or 1
				bb.Enabled = a < 1 -- ไกลสุด = ปิดไปเลย ไม่ต้องวาด
				for _, g in bb:GetDescendants() do
					if g:IsA("TextLabel") then
						g.TextTransparency = a
						g.TextStrokeTransparency = 1 - (1 - a) * 0.7 -- ขอบจางเร็วกว่าตัวอักษรนิดนึง
					elseif g:IsA("ImageLabel") then
						g.ImageTransparency = a
					end
				end
			end
		end
	end)
end

return InteractBinder
