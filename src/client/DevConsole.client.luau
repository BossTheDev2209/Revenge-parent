-- DevConsole — พิมพ์ `/dev <cmd> <ค่า>` ในแชท ตั้ง state ระหว่าง dev (ยิง action DevCmd ให้ server)
-- เปิดใน Studio เสมอ + นอก Studio เฉพาะ UserId ใน Config.DevUserIds · gate นี้แค่ซ่อนปุ่ม จุดบังคับสิทธิ์จริงคือ server
-- (ยกเว้น tp/preview ที่เป็น client-side ล้วน ไม่ผ่าน DevCmd — ต้องกัน register ตั้งแต่ตรงนี้ด้วย)
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
  qte [n]        -- force-trigger RecordQTE · n = บังคับจำนวนครั้งที่ต้องกด (ไม่ใส่ = สุ่ม 1-5)]]

-- เก็บ day ล่าสุดไว้แทน [date] ตอน preview (ไม่พึ่ง Main.client)
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
