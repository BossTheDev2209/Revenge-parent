-- StoryNPCPlacer.luau — วาง/ย้าย StoryNPC ตาม state.npcLoc (client render · server เป็นเจ้าของ npcLoc)
-- ที่อยู่ NPC = อนุพันธ์ของ state ไม่ใช่วางตายในแมพ — instance เดียวย้ายไปมา ไม่ duplicate/ไม่ Destroy
-- anchor = Part ชื่อ NPCHome_<actor>_<loc> ใน workspace · loc "away" = ซ่อนตัวละคร (ไม่ต้องมี anchor — ย้ายใต้แมพให้เอง)
-- วาง anchor ตรงไหนก็ได้ตรงจุด X/Z ที่อยากได้ (สูง/ต่ำ/หนาแค่ไหนไม่สำคัญ) — โค้ด raycast หาพื้นจริงข้างล่างเอง
-- แล้วยืนบนพื้นจริง (ไม่ใช่ยืนบนตัว anchor) กันทั้งจมพื้นและลอยเหนือ anchor
-- ย้ายเฉพาะตอน loc เปลี่ยน (ไม่ restart idle ทุก push) · reuse AnimPlayer.findRig (หาใน Workspace.NPC)
local isStudio = script ~= nil
local AnimPlayer = if isStudio
	then require(script.Parent.AnimPlayer)
	else require("./AnimPlayer")

local StoryNPCPlacer = {}

-- ชื่อ anchor สำหรับ actor+loc (pure)
function StoryNPCPlacer.anchorName(actor: string, loc: string): string
	return ("NPCHome_%s_%s"):format(actor, loc)
end

local applied = {} -- [actor] = loc ล่าสุด — กัน PivotTo/idle ซ้ำทุก push

-- loc ท่านั่ง/นอน → เรียก anim "Idle<Loc>" (bed→IdleBed) · ต้องมี Animation ชื่อนั้นในโฟลเดอร์ actor
local SEATED_LOC = { bed = true, couch = true, chair = true, park = true }

-- loc ที่เชื่อ anchor.Position ตรงๆ ไม่ raycast (user วางเทียบเบาะจริงด้วยตา)
-- ⚠️ บ้านหลายชั้น ray เจอพื้น/พรมชั้นบนก่อนของจริง — ท่านั่งทุกตัวเลยตัดมาไม่ raycast
local NO_RAYCAST_LOC = { jiajiajoin = true, bed = true, couch = true, chair = true, park = true, faasai_betray = true }

-- ⚠️ offset จูนด้วยมือ (weld C0 บน Torso.PropHold_NotebookBed) ตอน playtest แล้วเอาค่าสุดท้ายมาใส่
local BED_NOTEBOOK_OFFSET = CFrame.new(0.02288818359375, -1, -1.293975830078125)

-- วางทุก NPC ตาม state.npcLoc — idempotent (ทำจริงเฉพาะตัวที่ loc เปลี่ยน)
function StoryNPCPlacer.apply(state)
	if not state or type(state.npcLoc) ~= "table" then return end
	for actor, loc in state.npcLoc do
		if applied[actor] ~= loc then
			local rig = AnimPlayer.findRig(actor)
			if rig and loc == "away" then
				-- ★ "away" = ซ่อนตัวละคร ไม่ต้องมี anchor (แก้ 12 ส.ค. — ฟ้าใสหลังเดทสวนต้องหายไป รอโผล่เฟส 3)
				--   ย้ายไปไกลใต้แมพ (HRP anchored อยู่แล้วเลยค้างที่นั่น มองไม่เห็น) + ปล่อย prop ที่ถืออยู่
				rig:PivotTo(CFrame.new(0, -10000, 0))
				AnimPlayer.unhold("NotebookBed")
				applied[actor] = loc
			elseif rig then -- rig ยังไม่ spawn/stream = ข้ามไว้ก่อน ไม่ mark → push หน้าลองใหม่
				local anchor = workspace:FindFirstChild(StoryNPCPlacer.anchorName(actor, loc), true)
				if anchor and anchor:IsA("BasePart") then
					local facing = anchor.CFrame - anchor.CFrame.Position -- ทิศหันอย่างเดียว
					if NO_RAYCAST_LOC[loc] then
						rig:PivotTo(CFrame.new(anchor.Position) * facing)
					else
						-- หาพื้นจริงใต้ anchor (เชื่อ X/Z ไม่เชื่อ Y) แล้วยืนเหนือพื้น 3 stud
						-- ข้าม Interact_* (hitbox ของ prompt ไม่ใช่ geometry จริง มักลอยเหนือของจริง)
						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Exclude
						local ignore = { rig, anchor }
						local surfaceY, hit
						for _ = 1, 4 do
							params.FilterDescendantsInstances = ignore
							hit = workspace:Raycast(anchor.Position + Vector3.new(0, 10, 0), Vector3.new(0, -50, 0), params)
							if not hit then break end
							if hit.Instance.Name:sub(1, 9) ~= "Interact_" then
								surfaceY = hit.Position.Y
								break
							end
							table.insert(ignore, hit.Instance)
						end
						surfaceY = surfaceY or anchor.Position.Y -- ไม่เจอพื้น = ใช้ตำแหน่ง anchor เดิม
						rig:PivotTo(CFrame.new(anchor.Position.X, surfaceY + 3, anchor.Position.Z) * facing)
					end
					local seatedAnim = SEATED_LOC[loc] and ("Idle" .. loc:sub(1, 1):upper() .. loc:sub(2))
					AnimPlayer.play(actor, seatedAnim or "Idle", true)
					-- notebook weld เองตอน bed (Moon Animator export ได้แค่ joint ไม่ใช่ prop แยก)
					if actor == "ฟ้าใส" then
						local torso = rig:FindFirstChild("Torso")
						if loc == "bed" and torso then
							local notebook = workspace:FindFirstChild("NotebookBed")
							if notebook then
								notebook:PivotTo(torso.CFrame * BED_NOTEBOOK_OFFSET)
								AnimPlayer.hold("ฟ้าใส", "NotebookBed", "Torso")
							end
						else
							AnimPlayer.unhold("NotebookBed")
						end
					end
					applied[actor] = loc
				else
					warn("[StoryNPCPlacer] ไม่เจอ anchor " .. StoryNPCPlacer.anchorName(actor, loc))
				end
			end
		end
	end
end

return StoryNPCPlacer
