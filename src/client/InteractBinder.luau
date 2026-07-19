-- InteractBinder.luau — หา Interact_* ทุกตัวใน Workspace แล้วแปะ ProximityPrompt (runtime ฝั่ง client)
-- ทีมวางแค่ Part ชื่อถูกตาม docs/05 §3 — prompt กับ logic มาจากไฟล์นี้
-- deps = { fireAction = fn(actionTable), startQTE = fn() } ส่งมาจาก Main.client (ไม่ require กันเอง)
local InteractBinder = {}

local PROMPT_TEXT = {
	Interact_Camera = "ตัดคลิป",
	Interact_Bed = "พักผ่อน",
	Interact_Kitchen = "กินข้าว",
	Interact_Exercise = "ออกกำลังกาย",
	Interact_NPC_Mom = "คุยกับแม่",
}

-- Interact_NPC_* → ไฟล์บทใน Content/Dialogue (ทีมวาง NPC ตามเลขนี้ — docs/05 §3)
local NPC_DIALOGUE = {
	Interact_NPC_Mom = "Mom",
	Interact_NPC_01 = "Dad",
	Interact_NPC_02 = "Friend1",
	Interact_NPC_03 = "Friend2",
	Interact_NPC_04 = "CC1",
	Interact_NPC_05 = "Hater",
}

function InteractBinder.init(deps)
	local function onTriggered(name)
		if name == "Interact_Camera" then
			deps.startQTE()
		elseif name == "Interact_Bed" or name == "Interact_Kitchen" or name == "Interact_Exercise" then
			deps.fireAction({ type = "DoActivity", activity = name:gsub("Interact_", "") })
		elseif NPC_DIALOGUE[name] then
			deps.startDialogue(NPC_DIALOGUE[name])
		else
			warn("[InteractBinder] ยังไม่ผูก logic:", name)
		end
	end

	local function bind(inst)
		if not inst:IsA("BasePart") then return end
		if not inst.Name:match("^Interact_") then return end
		if inst:FindFirstChildOfClass("ProximityPrompt") then return end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = PROMPT_TEXT[inst.Name] or inst.Name:gsub("Interact_", "")
		prompt.ObjectText = ""
		prompt.HoldDuration = 0.3
		prompt.Triggered:Connect(function()
			onTriggered(inst.Name)
		end)
		prompt.Parent = inst
	end

	for _, d in workspace:GetDescendants() do
		bind(d)
	end
	workspace.DescendantAdded:Connect(bind)
end

return InteractBinder
