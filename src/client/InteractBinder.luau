-- InteractBinder — หา Interact_* ทุกตัวใน Workspace แล้วแปะ ProximityPrompt + logic (client)
-- ทีมวางแค่ Part ชื่อถูกตาม docs/05 · deps = { fireAction, playerGui, getState, openPC, openShop, startDialogue }
local isStudio = script ~= nil
local ActivityCutscene = if isStudio
	then require(script.Parent.ActivityCutscene)
	else require("./ActivityCutscene")

local InteractBinder = {}

local PROMPT_TEXT = {
	Interact_Camera = "ใช้คอมพิวเตอร์",
	Interact_pcMonitor = "ใช้คอมพิวเตอร์",
	Interact_Bed = "พักผ่อน",
	Interact_Kitchen = "กินข้าว",
	Interact_Exercise = "ออกกำลังกาย",
	-- NPC ไม่ต้องใส่ — ไม่มี key = ขึ้น "คุย" อัตโนมัติ (fallback ล่างไฟล์)
	Interact_NotebookPack = "เก็บโน้ตบุ๊ค",
	Interact_Shop = "เข้าร้านค้า",
	Interact_Door = "เข้าไป",
}

-- ประตู: Attribute Target = Part ปลายทาง · MinFollower = follower ที่ต้องมี (0/ไม่ใส่ = เข้าได้เลย)
-- pure: ตัดสินว่าเข้าได้ไหม
function InteractBinder.doorCheck(follower: number, minFollower: number?): (boolean, string?)
	local need = tonumber(minFollower) or 0
	if follower >= need then return true end
	return false, ("ยังเข้าไม่ได้ (ต้องมี %s follower)"):format(
		need >= 1000 and ("%dK"):format(need / 1000) or tostring(need))
end

-- Interact_NPC_<ชื่อ> → ไฟล์บทใน Content/Dialogue (ชื่อ = ชื่อโมเดลตัด prefix)
-- key ต้อง bracket-quote: Luau identifier รับ ASCII เท่านั้น ชื่อไทยเป็น key เปล่าไม่ได้
local NPC_DIALOGUE = {
	["Interact_NPC_แม่"] = "แม่",
	["Interact_NPC_พ่อ"] = "พ่อ",
	["Interact_NPC_ฟ้าใส"] = "ฟ้าใส", -- เพื่อนร่วมทางคนแรก ทรยศ 500K
	["Interact_NPC_เจียเจีย"] = "เจียเจีย", -- เพื่อนร่วมทางคนสอง อยู่จนจบ
	["Interact_NPC_พี่เปิ้ล"] = "พี่เปิ้ล", -- CC คู่แข่ง
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

-- เลือกชุดบทจากไฟล์เดียว · ลำดับความสำคัญ: after (หลังทรยศ) > byLoc[loc] > again (เคยคุย) > pN ไล่จากเฟสปัจจุบันลง
--   after/byLoc รับ 2 แบบ: ลิสต์ตรง (ไม่แยกซ้ำ) หรือ { p =, again = } (seen flag เป็นคนเลือก)
--   afterSeen/locSeen แยกครั้งแรก/ซ้ำของ after/byLoc ต่างหากจาก seen เฟสปกติ
local function pickAfter(after, afterSeen)
	if after[1] ~= nil then return after end -- ลิสต์ตรง
	if afterSeen and after.again then return after.again end
	return after.p or after.again
end

-- byLoc[loc] = { ... } ตรง | หรือ { p=, again= } แยกครั้งแรก/ซ้ำ — คืนลิสต์ที่ควรเล่น
local function resolveByLoc(byLoc, locSeen)
	if byLoc[1] ~= nil then
		return byLoc -- ลิสต์ตรง (มี index 1 = บรรทัดแรก ไม่ใช่ {p=,again=} ที่เป็น key ล้วน)
	end
	if locSeen and byLoc.again then return byLoc.again end
	return byLoc.p or byLoc.again
end

-- loc ที่เป็น "สถานที่เดินทาง" (คนละที่กับบ้าน) — byLoc ของ loc นี้ชนะแม้ after (บท after เป็นปฏิกิริยา "ที่บ้าน")
-- เช่น สยาม: ต้องได้บทสยาม+ช้อยกลับบ้านเสมอ ไม่งั้นหลังทรยศไปสยามแล้ว after ทับ = กลับบ้านไม่ได้ (user เจอ 12 ส.ค.)
local AFTER_OVERRIDE_LOC = { siam = true }

function InteractBinder.pickLines(mod, state, seen, loc, locSeen, afterSeen)
	if type(mod) ~= "table" then return nil end
	if type(mod[1]) == "string" then return mod end -- format เก่า
	-- byLoc ของสถานที่เดินทาง ชนะทุกอย่าง (รวม after) — เช็คก่อนสุด
	if loc and AFTER_OVERRIDE_LOC[loc] and mod.byLoc and mod.byLoc[loc] then
		return resolveByLoc(mod.byLoc[loc], locSeen)
	end
	if state and state.flags and state.flags.betrayed and mod.after then return pickAfter(mod.after, afterSeen) end
	if mod.byLoc and loc and mod.byLoc[loc] then
		return resolveByLoc(mod.byLoc[loc], locSeen)
	end
	if seen and mod.again then return mod.again end
	local phase = state and state.phase or 1
	for p = phase, 1, -1 do
		if mod["p" .. p] then return mod["p" .. p] end
	end
	return mod.p1 or (mod.after and pickAfter(mod.after, afterSeen))
end

-- เตียงมี 2 ทาง: พักผ่อน = activity ฟื้นใจ (ผ่าน ActivityCutscene) | นอน = ข้ามเวลา + ล้าง NoSleep
local function openBedMenu(playerGui, fireAction, onRest)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_BedMenu"
	gui.ResetOnSpawn = false
	local function btn(text, x, onClick, sfx)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 180, 0, 48)
		b.Position = UDim2.new(0.5, x, 0.5, -24)
		b.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextScaled = true
		b.Text = text
		if sfx then b:SetAttribute("Sfx", sfx) end
		b.Parent = gui
		b.Activated:Connect(function()
			gui:Destroy() -- ปิดเมนูก่อนเสมอ (ฉากต้องไม่มีปุ่มค้างบนจอ)
			if onClick then onClick() end
		end)
	end
	btn("😌 พักผ่อน (+ใจ)", -280, onRest)
	btn("😴 นอน (ข้ามเวลา)", -90, function() fireAction({ type = "Sleep" }) end)
	btn("❌ ยกเลิก", 100, nil, "ui_back")
	gui.Parent = playerGui
end

-- ข้อความกลางจอ 2 วิ (ประตูล็อก / ยังไม่ตั้ง Attribute)
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

-- ป้ายชื่อเหนือจุด interact จางตามระยะ (ไม่งั้นเห็นเด่นทั้งแมพ)
local LABEL_CLEAR_STUDS = 14 -- ใกล้กว่านี้ = ชัดเต็ม
local LABEL_GONE_STUDS = 30 -- ไกลกว่านี้ = หายสนิท

-- pure: ระยะ → ความโปร่งใส (0 = ชัด, 1 = หาย)
function InteractBinder.labelAlpha(distance: number): number
	if distance <= LABEL_CLEAR_STUDS then return 0 end
	if distance >= LABEL_GONE_STUDS then return 1 end
	return (distance - LABEL_CLEAR_STUDS) / (LABEL_GONE_STUDS - LABEL_CLEAR_STUDS)
end

function InteractBinder.init(deps)
	-- ทำ activity ฟื้นใจ · ทำไม่ได้ (cooldown) = โชว์เหตุผลกลางจอ ไม่ใช่กดแล้วเงียบ
	local function doActivity(activityName: string)
		local ok, why = ActivityCutscene.play(activityName, deps)
		if not ok and why then toast(deps.playerGui, why) end
	end

	local function onTriggered(name, part)
		if name == "Interact_Camera" or name == "Interact_pcMonitor" then
			deps.openPC(part) -- part = จอจริง: UI แปะบน SurfaceGui + กล้อง zoom เข้าหา
		elseif name == "Interact_NotebookPack" then
			deps.fireAction({ type = "PickupNotebook" })
		elseif name == "Interact_Shop" then
			deps.openShop()
		elseif name == "Interact_Bed" then
			openBedMenu(deps.playerGui, deps.fireAction, function() doActivity("Bed") end)
		elseif name == "Interact_Kitchen" or name == "Interact_Exercise" then
			doActivity(name:gsub("Interact_", ""))
		elseif name == "Interact_Door" then
			-- teleport ฝั่ง client พอ (singleplayer) — ปลายทาง/เงื่อนไขอ่านจาก Attribute ของบานประตู
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
			deps.startDialogue(NPC_DIALOGUE[name], part)
		else
			warn("[InteractBinder] ยังไม่ผูก logic:", name)
		end
	end

	-- ป้ายที่จางตามระยะ (ผูกกับ Interact_*) — loop เดียวอัปเดตทั้งหมด
	local labels = {}
	local function trackLabel(inst)
		local bb = inst:FindFirstChildOfClass("BillboardGui")
		if bb then labels[bb] = inst end
	end

	-- ป้ายลอยอื่น (CartHint ฯลฯ) — เก็บแยกไว้บังคับปิดตอนกด "ปิดป้ายลอย" (บังคับ false ตอนเปิดปุ่มอย่างเดียว)
	local otherBillboards = setmetatable({}, { __mode = "k" }) -- weak
	local function trackOther(bb)
		if not labels[bb] then otherBillboards[bb] = true end
	end
	local function bindBillboard(inst)
		if inst:IsA("BillboardGui") then trackOther(inst) end
	end

	local wired = {} -- กัน wire ซ้ำเวลา DescendantAdded ยิงหลายรอบ
	local function bind(inst)
		if not inst:IsA("BasePart") then return end
		if not inst.Name:match("^Interact_") then return end
		trackLabel(inst)
		-- รองรับทั้งวาง ProximityPrompt เองใน Studio และไม่มีก็สร้างให้
		local prompt = inst:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = PROMPT_TEXT[inst.Name]
				or (inst.Name:match("^Interact_NPC") and "คุย")
				or inst.Name:gsub("Interact_", "")
			prompt.ObjectText = ""
			prompt.HoldDuration = 0.3
			prompt.RequiresLineOfSight = false -- part มักฝังในตัว NPC โดนบัง prompt ไม่ขึ้น
			prompt.Parent = inst
		end
		if not wired[prompt] then
			wired[prompt] = true
			prompt.Triggered:Connect(function()
				onTriggered(inst.Name, inst)
			end)
		end
	end

	for _, d in workspace:GetDescendants() do
		bind(d)
		bindBillboard(d)
	end
	workspace.DescendantAdded:Connect(bind)
	workspace.DescendantAdded:Connect(bindBillboard)

	-- จางป้ายตามระยะ
	local player = game:GetService("Players").LocalPlayer
	game:GetService("RunService").Heartbeat:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local st = deps.getState and deps.getState()
		-- ปุ่ม "ปิดป้ายลอย" (state.settings.hideBillboards) — บังคับ false ข้ามลอจิกระยะทั้งหมด
		local hideAll = st and st.settings and st.settings.hideBillboards
		for bb in otherBillboards do
			if bb.Parent and hideAll then bb.Enabled = false end
		end
		for bb, part in labels do
			if not bb.Parent or not part.Parent then
				labels[bb] = nil
			elseif hideAll then
				bb.Enabled = false
			else
				-- ป้ายหัว NPC โผล่เฉพาะหลังคุยจบตัวนั้นแล้ว (seenDialogue มี key) · ป้าย interact อื่นโชว์ปกติ
				local npcName = NPC_DIALOGUE[part.Name]
				if npcName and not (st and st.seenDialogue and st.seenDialogue[npcName] ~= nil) then
					bb.Enabled = false
					continue
				end
				local a = root and InteractBinder.labelAlpha((root.Position - part.Position).Magnitude) or 1
				bb.Enabled = a < 1 -- ไกลสุด = ปิดไปเลย
				for _, g in bb:GetDescendants() do
					if g:IsA("TextLabel") then
						g.TextTransparency = a
						g.TextStrokeTransparency = 1 - (1 - a) * 0.7 -- ขอบจางเร็วกว่าตัวอักษรนิด
					elseif g:IsA("ImageLabel") then
						g.ImageTransparency = a
					end
				end
			end
		end
	end)
end

return InteractBinder
