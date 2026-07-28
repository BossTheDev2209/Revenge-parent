-- ToolService.luau — Tool ในมือผู้เล่นต้องตรงกับ state เสมอ (docs/02 §9.5)
-- กล้อง 6 ระดับ = 6 โมเดล (ระดับ 1 คือ "มือถือ" 480p — ไม่มี Tool_Phone แยก)
-- โน้ตบุ๊ค = Tool เฉพาะเฟส 1 วางลงพื้นแล้วใช้เป็นคอมได้ เก็บกลับได้
-- โมเดลต้นฉบับอยู่ใน ReplicatedStorage.ToolModels (ทีมเปลี่ยนโมเดลได้ ห้ามเปลี่ยนชื่อ)
-- pure ส่วน desiredTools — glue sync/place/pickup ใช้ Roblox API
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")

local ToolService = {}

-- Tool ที่ควรอยู่ในมือ ณ state นี้ (ชื่อ = ชื่อโมเดลใน ToolModels)
-- อุปกรณ์ถ่ายมีสายเดียว: Camera_1..6 (ระดับ 1 = มือถือ) — ไม่มี Tool มือถือ/ไม้เซลฟี่แยก
function ToolService.desiredTools(state)
	local lv = math.clamp(state.upgrades and state.upgrades.camera or 1, 1, #Config.ResolutionLadder)
	-- ระดับกล้องมี 15 แต่โมเดลใน ToolModels มีถึง Camera_6 — เกินนั้นใช้โมเดลตัวท้ายสุด
	-- (ไม่ clamp = หาโมเดลไม่เจอ = มือเปล่า อัดคลิปไม่ได้ทั้งเกม)
	local modelLv = math.min(lv, Config.CameraModelCount)
	local out = { "Camera_" .. modelLv }
	-- โน้ตบุ๊คมีเฉพาะเฟส 1 และเฉพาะตอนยังไม่ได้วางลงพื้น
	if state.phase == 1 and not state.notebookPlaced then
		table.insert(out, "Notebook")
	end
	return out
end

-- ชื่อที่โชว์บน hotbar (ชื่อโมเดลเป็น key ภายใน ผู้เล่นไม่ต้องเห็น "Camera_3")
function ToolService.displayName(source: string): string
	if source:match("^Camera_") then
		local lv = tonumber(source:match("%d+")) or 1
		return ("กล้อง (%s)"):format(Config.ResolutionLadder[lv] or "?")
	end
	return source == "Notebook" and "โน้ตบุ๊ค" or source
end

-- ===== Roblox glue =====

-- ให้ Backpack ตรงกับ desiredTools (ของเกินลบ ของขาดโคลนมา) — เรียกได้บ่อย ไม่เปลือง
function ToolService.sync(player, state)
	local templates = game:GetService("ReplicatedStorage"):FindFirstChild("ToolModels")
	if not templates then
		warn("[ToolService] ไม่มี ReplicatedStorage.ToolModels — ไม่มี Tool ให้ถือ")
		return
	end
	local want = {}
	for _, n in ToolService.desiredTools(state) do want[n] = true end

	local function scan(container)
		if not container then return end
		for _, t in container:GetChildren() do
			if t:IsA("Tool") then
				local src = t:GetAttribute("ToolSource")
				if src and want[src] then
					want[src] = nil -- มีแล้ว
				elseif src then
					t:Destroy() -- ไม่ควรมี (อัปเกรดแล้ว / ข้ามเฟส / วางไปแล้ว)
				end
			end
		end
	end
	scan(player:FindFirstChild("Backpack"))
	scan(player.Character)

	for name in want do
		local tpl = templates:FindFirstChild(name)
		if tpl then
			local t = tpl:Clone()
			t:SetAttribute("ToolSource", name)
			t.Name = ToolService.displayName(name)
			t.Parent = player.Backpack
		else
			warn("[ToolService] ไม่มีโมเดล ToolModels." .. name)
		end
	end
end

-- วางโน้ตบุ๊คลงพื้น: โคลน NotebookPlaced (มี Part Interact_pcMonitor ข้างใน) ไปที่ cf
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

return ToolService
