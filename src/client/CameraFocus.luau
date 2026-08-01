-- CameraFocus — โฟกัสกล้องไปที่ NPC ตอนคุย + zoom 3 ระดับ (ใกล้/ปกติ/ไกล)
-- ใช้คู่กับ DialogueUI: startDialogue เรียก focus(head) ตอนเริ่ม, release() ตอนจบ
-- zoom: scroll wheel เปลี่ยนระดับ (หรือเรียก setLevel เอง) tween ลื่นระหว่างระดับ
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local CameraFocus = {}

-- ค่าปรับได้ที่ Config.Dialogue (ที่เดียว)
local LEVELS = Config.Dialogue.zoomLevels -- ระยะจากหน้า NPC ใกล้/ปกติ/ไกล
local NORMAL = Config.Dialogue.zoomDefault
local EYE_HEIGHT = Config.Dialogue.camHeight
local TWEEN = TweenInfo.new(Config.Dialogue.camTweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local target: BasePart? = nil
local levelIndex = NORMAL
local saved = nil
local moveTween = nil
local scrollConn = nil

-- pure: CFrame กล้องที่ทำให้ NPC อยู่กลางจอ หันเห็นหน้า (targetCF = CFrame หัว NPC)
function CameraFocus.frameCFrame(targetCF: CFrame, distance: number): CFrame
	local head = targetCF.Position
	local camPos = head + targetCF.LookVector * distance + Vector3.new(0, EYE_HEIGHT, 0)
	return CFrame.lookAt(camPos, head + Vector3.new(0, EYE_HEIGHT * 0.5, 0))
end

local function apply(instant: boolean?)
	if not target then return end
	local cam = workspace.CurrentCamera
	local goal = CameraFocus.frameCFrame(target.CFrame, LEVELS[levelIndex])
	if moveTween then moveTween:Cancel() end
	if instant then
		cam.CFrame = goal
	else
		moveTween = TweenService:Create(cam, TWEEN, { CFrame = goal })
		moveTween:Play()
	end
end

function CameraFocus.setLevel(i: number)
	i = math.clamp(i, 1, #LEVELS)
	if i == levelIndex or not target then return end
	levelIndex = i
	apply(false)
end

function CameraFocus.focus(head: BasePart)
	if not head then return end
	local cam = workspace.CurrentCamera
	target = head
	levelIndex = NORMAL
	saved = { type = cam.CameraType, subject = cam.CameraSubject }
	cam.CameraType = Enum.CameraType.Scriptable
	apply(false) -- tween จากมุมเดิมเข้าหา NPC
	scrollConn = UserInputService.InputChanged:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			-- scroll ขึ้น = เข้าใกล้ (index ลด), scroll ลง = ถอยไกล
			CameraFocus.setLevel(levelIndex - (input.Position.Z > 0 and 1 or -1))
		end
	end)
end

function CameraFocus.release()
	if scrollConn then scrollConn:Disconnect() scrollConn = nil end
	if moveTween then moveTween:Cancel() moveTween = nil end
	target = nil
	if not saved then return end
	local cam = workspace.CurrentCamera
	cam.CameraType = saved.type
	cam.CameraSubject = saved.subject
		or (Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid"))
	saved = nil
end

return CameraFocus
