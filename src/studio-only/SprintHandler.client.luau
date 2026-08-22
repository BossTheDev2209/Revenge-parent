-- สำเนาของ StarterPlayer.StarterCharacterScripts.SprintHandler (Rojo ไม่ sync — ดู README.md)
-- SprintHandler — กด Shift ค้าง = วิ่ง, ปล่อย = เดินปกติ
-- เคารพ attribute MoveLocked บน Humanoid: ระบบอื่นล็อกการเดินอยู่ (cutscene/เมนู) = ไม่แตะ WalkSpeed
local UIS = game:GetService("UserInputService")
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

local WALK_SPEED = 16
local SPRINT_SPEED = 50

local sprinting = false

local function apply()
	if humanoid:GetAttribute("MoveLocked") then return end -- ระบบอื่นคุมอยู่ อย่าทับ
	humanoid.WalkSpeed = sprinting and SPRINT_SPEED or WALK_SPEED
end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end -- พิมพ์ในช่องข้อความอยู่ ไม่นับ
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = true
		apply()
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = false
		apply()
	end
end)

-- ปลดล็อกเมื่อไหร่ = คืนความเร็วตามปุ่มที่กดค้างจริง (ไม่ต้อง poll ถี่ๆ)
humanoid:GetAttributeChangedSignal("MoveLocked"):Connect(apply)
apply()
