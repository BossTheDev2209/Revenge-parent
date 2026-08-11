-- NpcAnchorTool — Studio plugin ช่วยวาง NPCHome_<actor>_<loc> anchor (docs/engines/story-beat.md, StoryNPCPlacer.luau)
-- ติดตั้ง: copy ไฟล์นี้ไป %LOCALAPPDATA%\Roblox\Plugins\NpcAnchorTool.lua แล้วเปิด Studio ใหม่
--          (แก้ไฟล์ใน repo แล้วต้อง copy ทับใหม่ทุกครั้ง — plugin ที่ติดตั้งเป็นสำเนา ไม่ auto-update)
--
-- toolbar:
--   Show Front — เลือก Part กี่ตัวก็ได้ กดปุ่ม → โผล่ลูกศรเขียวชี้ทิศ Front (-Z) ของแต่ละตัว 5 วิแล้วหายเอง
--   Anchor Panel — เลือกโมเดล/Part ท่าอ้างอิง (เช่น rig ที่ authoring ไว้) → ใส่ actor/loc → กด Create
--     ก๊อป CFrame (ตำแหน่ง+ทิศ) จากของที่เลือกตรงๆ ลง Part ชื่อ "NPCHome_<actor>_<loc>" ใน Workspace.cutscene_start_part
--     (ชื่อ/ folder ต้องตรงกับ StoryNPCPlacer.anchorName ห้ามเพี้ยน) — มีอยู่แล้ว = อัปเดตตำแหน่งอันเดิม ไม่สร้างซ้ำ

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Debris = game:GetService("Debris")

local ANCHOR_FOLDER = "cutscene_start_part"

-- ===== Show Front =====
-- ลูกศรชี้ -Z ของ part (ธรรมเนียมโปรเจกต์: ด้าน Front ของ Part = ทิศที่ตัวละคร/กล้องหันจริง — CutscenePlayer.luau §comment)
local function spawnFrontArrow(part: BasePart)
	local arrow = Instance.new("Part")
	arrow.Name = "FrontArrowPreview"
	arrow.Shape = Enum.PartType.Block
	arrow.Size = Vector3.new(0.3, 0.3, 2)
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CanQuery = false
	arrow.CanTouch = false
	arrow.CastShadow = false
	arrow.Material = Enum.Material.Neon
	arrow.Color = Color3.fromRGB(60, 255, 90)
	-- ปลายลูกศรอยู่ที่ -Z (Front) ของ part ต้นทาง ยื่นออกมาครึ่งความยาวลูกศร
	arrow.CFrame = part.CFrame * CFrame.new(0, 0, -(part.Size.Z / 2 + 1))
	arrow.Parent = workspace
	Debris:AddItem(arrow, 5)
end

-- ===== Anchor folder/part =====
local function anchorFolder(): Folder
	local f = workspace:FindFirstChild(ANCHOR_FOLDER)
	if not f then
		f = Instance.new("Folder")
		f.Name = ANCHOR_FOLDER
		f.Parent = workspace
	end
	return f
end

-- ต้องตรงกับ StoryNPCPlacer.anchorName เป๊ะ — ชื่อเพี้ยน = โค้ด runtime หาไม่เจอ
local function anchorName(actor: string, loc: string): string
	return ("NPCHome_%s_%s"):format(actor, loc)
end

-- CFrame ของสิ่งที่เลือก: Model ใช้ PrimaryPart (ไม่มีก็ GetPivot) · BasePart ใช้ตัวเอง
local function selectionCFrame(inst: Instance): CFrame?
	if inst:IsA("Model") then
		if inst.PrimaryPart then
			return inst.PrimaryPart.CFrame
		end
		return inst:GetPivot()
	elseif inst:IsA("BasePart") then
		return inst.CFrame
	end
	return nil
end

local function createOrUpdateAnchor(actor: string, loc: string): (boolean, string)
	if actor == "" or loc == "" then
		return false, "ใส่ actor กับ loc ให้ครบก่อน"
	end
	local sel = Selection:Get()[1]
	if not sel then
		return false, "ยังไม่ได้เลือกอะไร (เลือก rig/Part ท่าอ้างอิงก่อน)"
	end
	local srcCf = selectionCFrame(sel)
	if not srcCf then
		return false, "เลือก Model หรือ Part เท่านั้น (" .. sel.ClassName .. " ใช้ไม่ได้)"
	end
	local name = anchorName(actor, loc)
	local folder = anchorFolder()
	local rec = ChangeHistoryService:TryBeginRecording("NPC anchor " .. name)
	local part = folder:FindFirstChild(name)
	local created = false
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Size = Vector3.new(1, 0.63, 2) -- ขนาดเดียวกับ anchor เดิมในโปรเจกต์ (ไม่มีผลต่อ logic แค่ให้เห็นในจอ)
		part.Transparency = 0.5
		part.CanCollide = false
		part.CanQuery = false
		part.Anchored = true
		part.Parent = folder
		created = true
	end
	part.CFrame = srcCf
	Selection:Set({ part })
	if rec then
		ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end
	return true, (created and "สร้างใหม่ " or "อัปเดต ") .. name
end

-- ===== toolbar =====
local toolbar = plugin:CreateToolbar("NPC Anchors")
local frontBtn = toolbar:CreateButton("Show Front", "โผล่ลูกศรชี้ทิศ Front ของ Part ที่เลือก (5 วิ)", "rbxasset://textures/ui/GuiImagePlaceholder.png")
local panelBtn = toolbar:CreateButton("Anchor Panel", "เปิด/ปิด panel สร้าง NPCHome anchor จากของที่เลือก", "rbxasset://textures/ui/GuiImagePlaceholder.png")

frontBtn.Click:Connect(function()
	local any = false
	for _, inst in Selection:Get() do
		if inst:IsA("BasePart") then
			spawnFrontArrow(inst)
			any = true
		end
	end
	if not any then
		warn("[NpcAnchorTool] เลือก Part อย่างน้อย 1 ตัวก่อน")
	end
end)

-- ===== panel UI =====
local widget = plugin:CreateDockWidgetPluginGui(
	"NpcAnchorPanel",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 260, 190, 220, 170)
)
widget.Title = "NPC Anchor"

local root = Instance.new("Frame")
root.Size = UDim2.new(1, 0, 1, 0)
root.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
root.BorderSizePixel = 0
root.Parent = widget
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = root
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = root

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function makeLabel(text: string, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 18)
	l.BackgroundTransparency = 1
	l.TextColor3 = color or Color3.fromRGB(220, 220, 220)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextScaled = true
	l.Text = text
	l.LayoutOrder = nextOrder()
	l.Parent = root
	return l
end

local function makeBox(placeholder: string, default: string): TextBox
	local b = Instance.new("TextBox")
	b.Size = UDim2.new(1, 0, 0, 28)
	b.PlaceholderText = placeholder
	b.Text = default
	b.ClearTextOnFocus = false
	b.TextScaled = true
	b.LayoutOrder = nextOrder()
	b.Parent = root
	return b
end

makeLabel("actor (เช่น เจียเจีย, ฟ้าใส, Player)")
local actorBox = makeBox("actor", plugin:GetSetting("lastActor") or "")
makeLabel("loc (เช่น room, bed, jiajiajoin)")
local locBox = makeBox("loc", plugin:GetSetting("lastLoc") or "")

local createBtn = Instance.new("TextButton")
createBtn.Size = UDim2.new(1, 0, 0, 32)
createBtn.BackgroundColor3 = Color3.fromRGB(70, 120, 70)
createBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
createBtn.TextScaled = true
createBtn.Text = "Create/Update จากของที่เลือก"
createBtn.LayoutOrder = nextOrder()
createBtn.Parent = root

local statusLabel = makeLabel("เลือก rig/Part ท่าอ้างอิงในจอ 3D ก่อนกด", Color3.fromRGB(150, 200, 150))

createBtn.Activated:Connect(function()
	local actor = actorBox.Text
	local loc = locBox.Text
	plugin:SetSetting("lastActor", actor)
	plugin:SetSetting("lastLoc", loc)
	local ok, msg = createOrUpdateAnchor(actor, loc)
	statusLabel.Text = msg
	statusLabel.TextColor3 = ok and Color3.fromRGB(150, 200, 150) or Color3.fromRGB(230, 120, 120)
	if ok then
		print("[NpcAnchorTool] " .. msg)
	else
		warn("[NpcAnchorTool] " .. msg)
	end
end)

panelBtn.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)
