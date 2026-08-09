-- DevConsole — พิมพ์ในแชท `/dev <cmd> <ค่า>` ตั้งค่า state ระหว่าง dev (Studio เท่านั้น ปิดใน published)
-- ยิง action DevCmd ให้ server เปลี่ยน state จริง แล้ว push (server คือเจ้าของ state)
--
-- คำสั่ง (พิมพ์ /dev help ในเกมก็เห็น):
--   /dev follower <n>    ตั้ง follower (+ อัปเฟส/เพื่อน/milestone event ตามยอด)
--   /dev phase <1-3>     กระโดดเฟส (ตั้ง follower = gate ของเฟสนั้น)
--   /dev money <n>       ตั้งเงิน
--   /dev time <0-23>     ตั้งเวลาในเกม (ฟ้าเปลี่ยนตาม)
--   /dev mental <0-100>  ตั้งใจ
--   /dev day <n>         ตั้งวันในเกม
--   /dev flag <ชื่อ> [true|false]   ตั้ง state.flags[ชื่อ] (ไม่ใส่ค่า = true)
--   /dev ending <id>     ตั้ง ending (Good1/Neutral1/.. เล่น cutscene จบ)
--   /dev npcloc <actor> <loc>       ตั้งที่อยู่ StoryNPC (StoryNPCPlacer ย้ายตาม)
--   /dev staffsplit      ยิง event พนักงานตีกัน
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end -- dev เท่านั้น — published ไม่โหลด

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local remote = game:GetService("ReplicatedStorage").Shared.Remotes.Action

local HELP = [[[DevConsole] /dev <cmd> <ค่า>
  follower <n> · phase <1-3> · money <n> · time <0-23> · mental <0-100> · day <n>
  flag <ชื่อ> [true|false] · ending <id> · npcloc <actor> <loc> · staffsplit]]

local cmd = Instance.new("TextChatCommand")
cmd.Name = "DevCmd"
cmd.PrimaryAlias = "/dev"
cmd.SecondaryAlias = "/d"
cmd.Parent = TextChatService

cmd.Triggered:Connect(function(_, text)
	-- text = "/dev money 50000" — ตัด token
	local parts = string.split(text, " ")
	local sub = parts[2]
	if not sub or sub:lower() == "help" then
		print(HELP)
		return
	end
	remote:FireServer({ type = "DevCmd", cmd = sub, value = parts[3], value2 = parts[4] })
	print(("[DevConsole] ส่ง %s %s %s"):format(sub, tostring(parts[3]), tostring(parts[4] or "")))
end)
