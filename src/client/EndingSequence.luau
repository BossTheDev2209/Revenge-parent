-- EndingSequence.luau — True Ending (Good1) orchestration: BCA award cutscene → เดินเข้าโพเดียมเอง (คุมตัวเอง)
-- → self-talk ในชุดสูท → phase-transition fade → cutscene เจอพ่อแม่ → "จบ" → กลับ main menu
-- เรียกจาก Main.client.luau ตอนดัก pendingEvent BCA (task แยก — ไฟล์นี้แค่ประกอบ engine เดิม ไม่สร้างใหม่)
local isStudio = script ~= nil

local EndingSequence = {}

-- ===== pure (เทสด้วย lune) =====

-- ผู้เล่นเดินถึง walkTarget รึยัง — เทียบระยะตรงๆ ไม่ต้อง raycast (พื้นราบตรงทางเดินพรมแดง)
function EndingSequence.reachedTarget(playerPos: Vector3, targetPos: Vector3, threshold: number): boolean
	return (playerPos - targetPos).Magnitude <= threshold
end

-- ===== Roblox glue =====

if not isStudio then return EndingSequence end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Content = RS.Shared.Content
local Config = require(RS.Shared.Config)

local CutscenePlayer = require(script.Parent.UI.CutscenePlayer)
local ScreenTransition = require(script.Parent.ScreenTransition)
local DialogueUI = require(script.Parent.UI.DialogueUI)
local MenuUI = require(script.Parent.UI.MenuUI)

local WALK_REACH_THRESHOLD = 5 -- studs — ระยะถือว่า "เดินถึง" walkTarget แล้ว

local savedShirtTemplate, savedPantsTemplate = nil, nil

-- ใส่ชุดสูทก่อน cutscene BCA เริ่ม — ใส่ค้างตลอด BCA cutscene + เดิน + self-talk จนกว่า restoreSuit()
-- Shirt/Pants ไม่มีอยู่แล้ว (rig บางตัวไม่ใส่ default) = สร้างให้ (มาตรฐาน R6/R15 accessory)
local function applySuit()
	local char = Players.LocalPlayer.Character
	if not char then return end
	local shirt = char:FindFirstChildOfClass("Shirt")
	if not shirt then
		shirt = Instance.new("Shirt")
		shirt.Parent = char
	end
	local pants = char:FindFirstChildOfClass("Pants")
	if not pants then
		pants = Instance.new("Pants")
		pants.Parent = char
	end
	savedShirtTemplate = shirt.ShirtTemplate
	savedPantsTemplate = pants.PantsTemplate
	-- ⏳ suitShirtId/suitPantsId ยังว่างใน Config (รอ user ให้ rbxassetid) — assign ตรงๆ ไม่ guard เคสว่าง
	shirt.ShirtTemplate = Config.TrueEnding.suitShirtId
	pants.PantsTemplate = Config.TrueEnding.suitPantsId
end

-- คืนชุดเดิมหลัง cutscene เจอพ่อแม่จบ
local function restoreSuit()
	local char = Players.LocalPlayer.Character
	if not char then return end
	local shirt = char:FindFirstChildOfClass("Shirt")
	local pants = char:FindFirstChildOfClass("Pants")
	if shirt then shirt.ShirtTemplate = savedShirtTemplate or "" end
	if pants then pants.PantsTemplate = savedPantsTemplate or "" end
end

-- รอผู้เล่นเดิน (คุมเองหลังปลด FreezeTime) ไปถึง Part ชื่อ targetName ใน Workspace
-- ไม่ anchor HumanoidRootPart (ต่างจาก waitStreamedAround) — ต้องเดินได้ระหว่างรอ
local function waitReachPoint(targetName: string, timeout: number?): boolean
	local target = workspace:FindFirstChild(targetName, true)
	local limit = timeout or Config.TrueEnding.walkTimeout
	local t0 = os.clock()
	repeat
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and target and target:IsA("BasePart")
			and EndingSequence.reachedTarget(root.Position, target.Position, WALK_REACH_THRESHOLD) then
			return true
		end
		task.wait(0.1)
	until os.clock() - t0 > limit
	return false
end

-- ลำดับเต็ม True Ending (Good1) — deps = { fireAction, getState, menuDeps } จาก Main.client.luau
function EndingSequence.playTrueEnding(playerGui, deps)
	applySuit()

	deps.fireAction({ type = "FreezeTime", on = true })
	CutscenePlayer.play(playerGui, require(Content.Cutscenes.BCAWalk), function()
		-- ปลดล็อกให้ผู้เล่นเดินพรมแดงเอง (ยังใส่สูทอยู่) จนถึง walkTarget
		deps.fireAction({ type = "FreezeTime", on = false })
		waitReachPoint(Config.TrueEnding.walkTarget)

		deps.fireAction({ type = "FreezeTime", on = true })
		ScreenTransition.play({
			onBlack = function() end,
			onDone = function()
				DialogueUI.show(playerGui, require(Content.Dialogue.SelfTalkBCA), function()
					ScreenTransition.play({
						steps = require(Content.Cutscenes.PhaseTransitions)[4],
						onBlack = function() end,
						onDone = function()
							CutscenePlayer.play(playerGui, require(Content.Cutscenes.Reunite), function()
								restoreSuit()
								ScreenTransition.play({
									lines = { "[slow]— จบ — [normal](Good1)" },
									onDone = function()
										deps.fireAction({ type = "FreezeTime", on = false })
										MenuUI.open(playerGui, deps.menuDeps)
									end,
								})
							end)
						end,
					})
				end)
			end,
		})
	end)
end

return EndingSequence
