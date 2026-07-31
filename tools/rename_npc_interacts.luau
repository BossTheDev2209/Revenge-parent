-- rename_npc_interacts.luau — เปลี่ยนชื่อ Part Interact ในโมเดล NPC ให้ unique
-- เดิมทุกตัวชื่อ Interact_NPC_01 เหมือนกันหมด → ระบบผูกบทไม่ได้
-- ตั้งใหม่ = Interact_NPC_<suffix> โดย suffix = ชื่อโมเดลตัด prefix ออก (NPC_NN_ / NPC_special_)
local out = {}
local function suffixOf(name)
	return name:match("^NPC_%d+_(.+)$") or name:match("^NPC_special_(.+)$")
end
for _, folderName in { "WorldNPC", "StoryNPC" } do
	local folder = workspace.NPC:FindFirstChild(folderName)
	if folder then
		for _, model in folder:GetChildren() do
			if model:IsA("Model") then
				local sfx = suffixOf(model.Name)
				if sfx then
					for _, d in model:GetDescendants() do
						if d.Name:match("^Interact_NPC") then
							d.Name = "Interact_NPC_" .. sfx
							table.insert(out, ("%s → %s"):format(model.Name, d.Name))
						end
					end
				else
					table.insert(out, "ข้าม (ชื่อไม่เข้ารูปแบบ): " .. model.Name)
				end
			end
		end
	end
end
return table.concat(out, "\n")
