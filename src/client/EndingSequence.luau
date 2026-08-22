-- EndingSequence — True Ending (Good1): BCA cutscene → เดินเข้าโพเดียมเอง → self-talk ในชุดสูท
-- → phase-transition → cutscene เจอพ่อแม่ → "จบ" → กลับ main menu · ประกอบ engine เดิม ไม่สร้างใหม่
local isStudio = script ~= nil

local EndingSequence = {}
-- flag กันยิงซ้ำระหว่างช่วง waitReachPoint (ตอนนั้น sub-engine ทุกตัว .running=false พร้อมกัน)
EndingSequence.running = false

-- ผู้เล่นเดินถึง walkTarget รึยัง — เทียบระยะตรงๆ (พื้นราบตรงทางพรมแดง)
function EndingSequence.reachedTarget(playerPos: Vector3, targetPos: Vector3, threshold: number): boolean
	return (playerPos - targetPos).Magnitude <= threshold
end

if not isStudio then return EndingSequence end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Content = RS.Shared.Content
local Config = require(RS.Shared.Config)

local CutscenePlayer = require(script.Parent.UI.CutscenePlayer)
local ScreenTransition = require(script.Parent.ScreenTransition)
local DialogueUI = require(script.Parent.UI.DialogueUI)
local MenuUI = require(script.Parent.UI.MenuUI)

local WALK_REACH_THRESHOLD = 5 -- studs — ระยะถือว่า "เดินถึง" walkTarget

-- ใส่ชุดสูทก่อน BCA cutscene · Shirt/Pants ไม่มี = สร้างให้ · คืนค่าเดิม (per-call ไม่เก็บ module state
-- กัน playTrueEnding สองรอบซ้อนแล้ว capture ชุดสูทเป็น "ของเดิม" ผิด)
local function applySuit(): (string?, string?)
	local char = Players.LocalPlayer.Character
	if not char then return nil, nil end
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
	local savedShirt, savedPants = shirt.ShirtTemplate, pants.PantsTemplate
	-- ⏳ suitShirtId/suitPantsId ยังว่างใน Config (รอ user ให้ rbxassetid)
	shirt.ShirtTemplate = Config.TrueEnding.suitShirtId
	pants.PantsTemplate = Config.TrueEnding.suitPantsId
	return savedShirt, savedPants
end

local function restoreSuit(savedShirt: string?, savedPants: string?)
	local char = Players.LocalPlayer.Character
	if not char then return end
	local shirt = char:FindFirstChildOfClass("Shirt")
	local pants = char:FindFirstChildOfClass("Pants")
	if shirt then shirt.ShirtTemplate = savedShirt or "" end
	if pants then pants.PantsTemplate = savedPants or "" end
end

-- รอผู้เล่นเดิน (คุมเองหลังปลด FreezeTime) ไปถึง Part targetName · หา target ใหม่ทุกรอบ (เผื่อ stream ช้า)
local function waitReachPoint(targetName: string, timeout: number?): boolean
	local limit = timeout or Config.TrueEnding.walkTimeout
	local t0 = os.clock()
	repeat
		local target = workspace:FindFirstChild(targetName, true)
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and target and target:IsA("BasePart")
			and EndingSequence.reachedTarget(root.Position, target.Position, WALK_REACH_THRESHOLD) then
			return true
		end
		task.wait(0.1)
	until os.clock() - t0 > limit
	warn("[EndingSequence] waitReachPoint timeout: หา/เดินไม่ถึง", targetName)
	return false
end

-- ลำดับเต็ม True Ending · deps = { fireAction, getState, menuDeps } จาก Main.client
function EndingSequence.playTrueEnding(playerGui, deps)
	if EndingSequence.running then return end
	EndingSequence.running = true

	local savedShirt, savedPants = applySuit()

	deps.fireAction({ type = "FreezeTime", on = true })
	CutscenePlayer.play(playerGui, require(Content.Cutscenes.BCAWalk), function()
		-- ปลดล็อกให้เดินพรมแดงเอง (ยังใส่สูท) จนถึง walkTarget
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
								restoreSuit(savedShirt, savedPants)
								ScreenTransition.play({
									lines = { "[slow]— จบ — [normal](Good1)" },
									onDone = function()
										EndingSequence.running = false
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
