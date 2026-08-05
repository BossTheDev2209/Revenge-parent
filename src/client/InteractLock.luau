-- InteractLock.luau — ระหว่างคุย NPC / ใช้คอม: ปิด ProximityPrompt ทั้งหมด + ล็อกไม่ให้เดิน
-- แก้บัคกด E/WASD ทะลุไปโดน prompt หรือเดินตัวขณะเปิด UI เต็มจอ (เช่น EditQTE ใช้ E เป็นปุ่มเกม)
-- ref-count กันปลดเร็วตอนซ้อน (canon-event dialogue อาจซ้อนบทคุย) — ปลดจริงตอน depth กลับเป็น 0
-- ล็อกเดินใช้ convention MoveLocked เดียวกับ CutscenePlayer (SprintHandler เห็นแล้วหยุดแตะ WalkSpeed)
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
