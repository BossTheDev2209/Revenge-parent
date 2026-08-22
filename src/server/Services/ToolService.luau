-- ToolService — Tool ในมือให้ตรงกับ state · โมเดลอยู่ ReplicatedStorage.ToolModels
-- กล้อง 6 ระดับ = Camera_1..6 (ระดับ 1 = มือถือ) · โน้ตบุ๊ค = Tool เฉพาะเฟส 1
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../shared/Formulas")

local ToolService = {}

-- Tool ที่ควรอยู่ในมือ ณ state นี้ (ชื่อ = ชื่อโมเดลใน ToolModels)
function ToolService.desiredTools(state)
	local lv = math.clamp(Formulas.activeLevel(state, "camera"), 1, #Config.ResolutionLadder)
	local modelLv = math.min(lv, Config.CameraModelCount) -- เกินจำนวนโมเดล = ใช้ตัวท้ายสุด
	local out = { "Camera_" .. modelLv }
	if state.phase == 1 and not state.notebookPlaced then
		table.insert(out, "Notebook")
	end
	return out
end

-- ชื่อบน hotbar (ชื่อโมเดลเป็น key ภายใน ผู้เล่นไม่ต้องเห็น "Camera_3")
function ToolService.displayName(source: string): string
	if source:match("^Camera_") then
		local lv = tonumber(source:match("%d+")) or 1
		return ("กล้อง (%s)"):format(Config.ResolutionLadder[lv] or "?")
	end
	return source == "Notebook" and "โน้ตบุ๊ค" or source
end

-- ให้ Backpack ตรงกับ desiredTools (ของเกินลบ ของขาดโคลนมา)
function ToolService.sync(player, state)
	local templates = game:GetService("ReplicatedStorage"):FindFirstChild("ToolModels")
	if not templates then
		warn("[ToolService] ไม่มี ReplicatedStorage.ToolModels")
		return
	end
	local want = {}    -- ของที่ยังขาด — ลบทีละตัวตอน scan เจอ
	local desired = {} -- ของที่ควรมี — ใช้ตัดสินหลัง scan
	for _, n in ToolService.desiredTools(state) do
		want[n] = true
		desired[n] = true
	end

	-- จำกล้องที่ถือในมืออยู่ก่อน scan ลบทิ้ง — ถ้าโดนอัปเกรดสลับตัว ต้อง equip ตัวใหม่ให้ทันที
	local equippedSrc
	if player.Character then
		for _, t in player.Character:GetChildren() do
			if t:IsA("Tool") and t:GetAttribute("ToolSource") then
				equippedSrc = t:GetAttribute("ToolSource")
				break
			end
		end
	end

	local function scan(container)
		if not container then return end
		for _, t in container:GetChildren() do
			if t:IsA("Tool") then
				local src = t:GetAttribute("ToolSource")
				if src and want[src] then
					want[src] = nil
				elseif src then
					t:Destroy() -- ไม่ควรมี (อัปเกรด/ข้ามเฟส/วางไปแล้ว)
				end
			end
		end
	end
	scan(player:FindFirstChild("Backpack"))
	scan(player.Character)

	-- downgrade ต่ำกว่าระดับรถเข็น = รถที่เสกค้างต้องหายด้วย (ไม่งั้น downgrade ไม่เสียอะไร)
	if not desired[Config.CameraCartToolSource] then
		local old = workspace:FindFirstChild(Config.CameraCartTemplate)
		if old then old:Destroy() end
	end

	for name in want do
		local tpl = templates:FindFirstChild(name)
		if tpl then
			local t = tpl:Clone()
			t:SetAttribute("ToolSource", name)
			t.Name = ToolService.displayName(name)
			t.Parent = player.Backpack
			-- ถือกล้องอยู่แล้วอัปเกรดเป็นกล้องตัวใหม่ → equip กลับเข้ามือทันที ไม่ให้มือว่าง
			if equippedSrc and equippedSrc:match("^Camera_") and name:match("^Camera_") then
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum then hum:EquipTool(t) end
			end
		else
			warn("[ToolService] ไม่มีโมเดล ToolModels." .. name)
		end
	end
end

-- วางโน้ตบุ๊คลงพื้น: โคลน NotebookPlaced (มี Interact_pcMonitor ข้างใน) ไปที่ cf
function ToolService.placeNotebook(state, cf: CFrame): boolean
	if state.phase ~= 1 or state.notebookPlaced then return false end
	local templates = game:GetService("ReplicatedStorage"):FindFirstChild("ToolModels")
	local tpl = templates and templates:FindFirstChild("NotebookPlaced")
	if not tpl then
		warn("[ToolService] ไม่มี ToolModels.NotebookPlaced")
		return false
	end
	local m = tpl:Clone()
	m.Name = "PlacedNotebook"
	m:PivotTo(cf)
	m.Parent = workspace
	state.notebookPlaced = true
	return true
end

function ToolService.pickupNotebook(state): boolean
	local m = workspace:FindFirstChild("PlacedNotebook")
	if m then m:Destroy() end
	if not state.notebookPlaced then return false end
	state.notebookPlaced = false
	return true
end

-- เสกรถเข็นกล้องหน้าผู้เล่น (Tool Camera_6 กดเรียก) — ทำที่ server เพราะ Seat ต้องเป็นของจริง
function ToolService.summonCart(player)
	local templates = game:GetService("ReplicatedStorage"):FindFirstChild("ToolModels")
	local tpl = templates and templates:FindFirstChild(Config.CameraCartTemplate)
	if not tpl then
		warn("[ToolService] ไม่มีโมเดล ToolModels." .. Config.CameraCartTemplate)
		return nil
	end
	local char = player and player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local old = workspace:FindFirstChild(Config.CameraCartTemplate)
	if old then old:Destroy() end -- ลบคันเก่าก่อน (ไม่งั้นรถกองเต็มแมพ)

	local m = tpl:Clone()
	local drop = root.CFrame * CFrame.new(0, 0, -Config.CameraCartSpawnStuds)
	m:PivotTo(CFrame.lookAt(drop.Position, drop.Position + root.CFrame.LookVector))
	m.Parent = workspace

	-- ยกฐานให้แตะพื้น (pivot วางที่ระดับ HRP แต่ฐานรถอยู่ต่ำกว่า → จมดิน ~1.3 studs)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { m, char }
	local cf, size = m:GetBoundingBox()
	local hit = workspace:Raycast(cf.Position + Vector3.new(0, size.Y, 0), Vector3.new(0, -size.Y * 6, 0), params)
	if hit then
		local lowestY = cf.Position.Y - size.Y / 2
		m:PivotTo(m:GetPivot() + Vector3.new(0, hit.Position.Y - lowestY, 0))
	end
	return m
end

return ToolService
