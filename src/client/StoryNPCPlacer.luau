-- StoryNPCPlacer.luau — วาง/ย้าย StoryNPC ตาม state.npcLoc (client render · server เป็นเจ้าของ npcLoc)
-- ที่อยู่ NPC = อนุพันธ์ของ state ไม่ใช่วางตายในแมพ — instance เดียวย้ายไปมา ไม่ duplicate/ไม่ Destroy
-- anchor = Part ชื่อ NPCHome_<actor>_<loc> ใน workspace · "away" = วาง anchor ไว้นอกจอ/ใต้แมพเอา
-- วาง anchor ตรงไหนก็ได้ตรงจุด X/Z ที่อยากได้ (สูง/ต่ำ/หนาแค่ไหนไม่สำคัญ) — โค้ด raycast หาพื้นจริงข้างล่างเอง
-- แล้วยืนบนพื้นจริง (ไม่ใช่ยืนบนตัว anchor) กันทั้งจมพื้นและลอยเหนือ anchor
-- ย้ายเฉพาะตอน loc เปลี่ยน (ไม่ restart idle ทุก push) · reuse AnimPlayer.findRig (หาใน Workspace.NPC)
local isStudio = script ~= nil
local AnimPlayer = if isStudio
	then require(script.Parent.AnimPlayer)
	else require("./AnimPlayer")

local StoryNPCPlacer = {}

-- ชื่อ anchor สำหรับ actor+loc (pure — เทสได้)
function StoryNPCPlacer.anchorName(actor: string, loc: string): string
	return ("NPCHome_%s_%s"):format(actor, loc)
end

-- loc ล่าสุดที่วางไปแล้ว [actor] = loc — กัน PivotTo/idle ซ้ำทุก state push
local applied = {}

-- วางทุก NPC ตาม state.npcLoc — idempotent เรียกทุก push ได้ (ทำจริงเฉพาะตัวที่ loc เปลี่ยน)
function StoryNPCPlacer.apply(state)
	if not state or type(state.npcLoc) ~= "table" then return end
	for actor, loc in state.npcLoc do
		if applied[actor] ~= loc then
			local rig = AnimPlayer.findRig(actor)
			if rig then -- rig ยังไม่ spawn/stream = ข้ามไว้ก่อน ไม่ mark → push หน้าลองใหม่
				local anchor = workspace:FindFirstChild(StoryNPCPlacer.anchorName(actor, loc), true)
				if anchor and anchor:IsA("BasePart") then
					-- raycast หาพื้นจริงใต้ anchor (เชื่อ X/Z + การหันของ anchor แต่ไม่เชื่อ Y — anchor อาจวางแบบก้นแนบพื้น
					-- จุดศูนย์กลางเลยลอยสูงกว่าพื้นจริง) แล้วยืนเหนือพื้นจริง 3 studs (ตรงกับ TeleportTo — pattern เดียวกับ ToolService.summonCart)
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { rig, anchor }
					local hit = workspace:Raycast(anchor.Position + Vector3.new(0, 10, 0), Vector3.new(0, -50, 0), params)
					local groundY = hit and hit.Position.Y or anchor.Position.Y -- ไม่เจอพื้น (เช่นลอยกลางอากาศจริง) = ใช้ตำแหน่ง anchor เดิม
					local facing = anchor.CFrame - anchor.CFrame.Position -- ทิศหันอย่างเดียว ตัดตำแหน่งทิ้ง
					rig:PivotTo(CFrame.new(anchor.Position.X, groundY + 3, anchor.Position.Z) * facing)
					AnimPlayer.play(actor, "Idle", true) -- ยืน idle loop นอกบทคุย
					applied[actor] = loc
				else
					warn("[StoryNPCPlacer] ไม่เจอ anchor " .. StoryNPCPlacer.anchorName(actor, loc))
				end
			end
		end
	end
end

return StoryNPCPlacer
