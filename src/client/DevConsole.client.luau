-- DevConsole — พิมพ์ในแชท `/dev <cmd> <ค่า>` ตั้งค่า state ระหว่าง dev
-- ยิง action DevCmd ให้ server เปลี่ยน state จริง แล้ว push (server คือเจ้าของ state)
-- เปิดใน Studio เสมอ + นอก Studio (published จริง) เฉพาะ UserId ใน Config.DevUserIds (docs/15)
-- ★ gate ที่นี่แค่ซ่อนปุ่มจากคนอื่น — จุดบังคับสิทธิ์จริงคือ server (Main.server DevCmd handler)
--   ยกเว้น tp/preview ที่เป็น client-side ล้วน (ไม่ผ่าน DevCmd) เลยต้องกัน register ตั้งแต่ตรงนี้ด้วย
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
--   /dev preview <2|3|4|...>   เล่น Content.Cutscenes.PhaseTransitions[key] ตรงๆ ฝั่ง client
--                              (ไม่ผ่าน server/phase จริง — ทดสอบ [3]/[4] ได้ทันทีไม่ต้องไล่ follower)
--   /dev tp <1|2|3|baseplate>   วาปไป Spawn_Phase<n> หรือ Baseplate ตรงๆ (ยิง TeleportTo — ไม่แตะ follower/phase)
--   /dev qte [n]          force-trigger RecordQTE ทันที · n = บังคับจำนวนรอบ (ไม่ใส่ = สุ่ม 1-5 เหมือน proc จริง)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local allowed = RunService:IsStudio() or table.find(Config.DevUserIds, Players.LocalPlayer.UserId) ~= nil
if not allowed then return end -- ไม่ใช่ dev — ไม่ register command เลย

local TextChatService = game:GetService("TextChatService")
local remote = RS.Shared.Remotes.Action
local ScreenTransition = require(script.Parent.ScreenTransition)

local HELP = [[[DevConsole] /dev <cmd> <ค่า>
  follower <n> · phase <1-3> · money <n> · time <0-23> · mental <0-100> · day <n>
  flag <ชื่อ> [true|false] · ending <id> · npcloc <actor> <loc> · staffsplit
  preview <key>  -- เล่น PhaseTransitions[key] ตรงๆ (client-only ไม่แตะ state)
  tp <1-3|baseplate>  -- วาปไป Spawn_Phase<n> หรือ Baseplate ตรงๆ (ไม่แตะ follower/phase)
  qte [n]        -- force-trigger RecordQTE · n = บังคับจำนวนรอบ (ไม่ใส่ = สุ่ม 1-5)]]

-- เก็บ day ล่าสุดไว้แทน [date] ตอน preview (ไม่พึ่ง Main.client) — เบาสุด ฟังรีโมทเดียวกัน
local lastDay = 1
RS.Shared.Remotes.StateChanged.OnClientEvent:Connect(function(s)
	if s and s.day then lastDay = s.day end
end)

local function preview(key)
	local PhaseText = require(RS.Shared.Content.Cutscenes.PhaseTransitions)
	local steps = PhaseText[tonumber(key) or key]
	if not steps then
		warn("[DevConsole] preview: ไม่มี PhaseTransitions[" .. tostring(key) .. "]")
		return
	end
	local subbed = {}
	for _, st in steps do
		if st.text and st.text:find("%[date%]") then
			local c = table.clone(st)
			c.text = st.text:gsub("%[date%]", tostring(lastDay))
			table.insert(subbed, c)
		else
			table.insert(subbed, st)
		end
	end
	ScreenTransition.play({ steps = subbed })
end

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
	if sub:lower() == "preview" then
		preview(parts[3])
		return
	end
	if sub:lower() == "tp" then
		local dest = parts[3] and parts[3]:lower() == "baseplate" and "Baseplate" or ("Spawn_Phase" .. tostring(parts[3]))
		remote:FireServer({ type = "TeleportTo", target = dest })
		return
	end
	remote:FireServer({ type = "DevCmd", cmd = sub, value = parts[3], value2 = parts[4] })
	print(("[DevConsole] ส่ง %s %s %s"):format(sub, tostring(parts[3]), tostring(parts[4] or "")))
end)
