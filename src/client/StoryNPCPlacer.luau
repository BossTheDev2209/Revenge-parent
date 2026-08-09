-- StoryNPCPlacer.luau — วาง/ย้าย StoryNPC ตาม state.npcLoc (client render · server เป็นเจ้าของ npcLoc)
-- ที่อยู่ NPC = อนุพันธ์ของ state ไม่ใช่วางตายในแมพ — instance เดียวย้ายไปมา ไม่ duplicate/ไม่ Destroy
-- anchor = Part ชื่อ NPCHome_<actor>_<loc> ใน workspace · "away" = วาง anchor ไว้นอกจอ/ใต้แมพเอา
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
					rig:PivotTo(anchor.CFrame)
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
