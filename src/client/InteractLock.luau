-- InteractLock — ระหว่างคุย NPC / ใช้คอม: ปิด ProximityPrompt + ล็อกเดิน (กัน E/WASD ทะลุ UI)
-- ref-count กันปลดเร็วตอนบทซ้อน — ปลดจริงตอน depth = 0 · ล็อกเดินใช้ MoveLocked เดียวกับ CutscenePlayer
local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")

local InteractLock = {}
local depth = 0
local savedJump = nil

local function hum()
	local char = Players.LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

function InteractLock.lock()
	depth += 1
	if depth > 1 then return end
	PPS.Enabled = false
	local h = hum()
	if h then
		savedJump = h.JumpPower
		h:SetAttribute("MoveLocked", true)
		h.WalkSpeed, h.JumpPower = 0, 0
	end
end

function InteractLock.unlock()
	depth = math.max(0, depth - 1)
	if depth > 0 then return end
	PPS.Enabled = true
	local h = hum()
	if h then
		h:SetAttribute("MoveLocked", nil) -- SprintHandler คืน WalkSpeed ตามปุ่มที่กดค้าง
		if savedJump then h.JumpPower = savedJump end
	end
end

return InteractLock
