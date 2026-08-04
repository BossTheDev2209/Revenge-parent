-- สำเนาของ ServerScriptService.Footsteps.Running (Rojo ไม่ sync — ดู ../README.md)
-- ตอนรันจริงถูกโคลนเข้า HumanoidRootPart: script.Parent = HumanoidRootPart, script.Parent.Parent = ตัวละคร
-- แก้ 5 ส.ค. 2569: จังหวะก้าวแปรตามความเร็ว (เดิม wait(0.351) คงที่ — วิ่งกับเดินเสียงถี่เท่ากัน)

local running = true;
local Connection = nil;
local Humanoid = script.Parent.Parent.Humanoid

function WhileRunning()
	if script.Parent.Materials.Value == "Grass" then
		script.Parent.Grass:Play()
	elseif script.Parent.Materials.Value == "Water" then
		script.Parent.Splash:Play()
	elseif script.Parent.Materials.Value == "Wood" then
		script.Parent.Wood:Play()
	elseif script.Parent.Materials.Value == "Ice" then
		script.Parent.Ice:Play()
	elseif script.Parent.Materials.Value == "Plastic" then
		script.Parent.Plastic:Play()
	elseif script.Parent.Materials.Value == "WoodPlanks" then
		script.Parent.WoodPlanks:Play()
	elseif script.Parent.Materials.Value == "Cobblestone" then
		script.Parent.Cobblestone:Play()
	elseif script.Parent.Materials.Value == "Fabric" then
		script.Parent.Fabric:Play()
	elseif script.Parent.Materials.Value == "CMetal" then
		script.Parent.Diamond:Play()
	elseif script.Parent.Materials.Value == "Metal" then
		script.Parent.Metal:Play()
	elseif script.Parent.Materials.Value == "DiamondPlate" then
		script.Parent.Diamond:Play()
	elseif script.Parent.Materials.Value == "Concrete" then
		script.Parent.Concrete:Play()
	elseif script.Parent.Materials.Value == "Slate" then
		script.Parent.Concrete:Play()
	elseif script.Parent.Materials.Value == "Foil" then
		script.Parent.Foil:Play()
	elseif script.Parent.Materials.Value == "Brick" then
		script.Parent.Brick:Play()
	elseif script.Parent.Materials.Value == "Granite" then
		script.Parent.Granite:Play()
	elseif script.Parent.Materials.Value == "Marble" then
		script.Parent.Marble:Play()
	elseif script.Parent.Materials.Value == "Sand" then
		script.Parent.Sand:Play()
elseif script.Parent.Materials.Value == "Pebble" then
		script.Parent.Pebble:Play()
elseif script.Parent.Materials.Value == "Pebble" then
	script.Parent.Pebble:Play()   end
	end

-- ความเร็วแนวราบ (ไม่นับขึ้น-ลง) — ใช้ทั้งเช็คว่าเดินอยู่ไหม และคำนวณจังหวะก้าว
local BASE_SPEED = 16    -- WalkSpeed ปกติ
local BASE_STEP = 0.351  -- จังหวะก้าวที่ความเร็วปกติ (วิ)

function flatSpeed()
	local v = Humanoid.Parent.HumanoidRootPart.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

function isRunning()
    if running and flatSpeed() > 1 then
        return true
    end
end


Humanoid.Jumping:connect(function()
    running = false;
end)


function doWhileRunning()
    Connection:disconnect();
    running = true;
    while (isRunning()) do
        WhileRunning()
        -- ยิ่งเร็วยิ่งถี่: step = จังหวะปกติ x (ความเร็วปกติ / ความเร็วจริง) · clamp กันถี่/ห่างเกิน
        wait(math.clamp(BASE_STEP * BASE_SPEED / math.max(flatSpeed(), 1), 0.12, 0.6))
    end
    running = false;
    Connection = Humanoid.Running:connect(doWhileRunning);
end

Connection = Humanoid.Running:connect(doWhileRunning)
