-- CutscenePlayer.luau — **cutscene โหมด 1 "หนัง"** (design doc §8, Genshin ref)
-- player กดอะไรไม่ได้ · กล้องเปลี่ยนบ่อย/เลื่อนได้ · ซับไตเติลล่างจอ **ไม่มีกรอบข้อความ** · เดินตามเวลาเอง
-- โหมด 2 "ฉากคุย" (กล้องนิ่ง + กล่องข้อความ + ช้อย) อยู่ที่ DialogueUI — เทียบตาราง docs/engines/README.md
-- step: {type="text",text=} | {type="wait",t=} | {type="camera",cam="ชื่อPart"[,t=วินาที]} | {type="camera",pos={x,y,z},look={x,y,z}[,t=]}
--       | {type="bgm",name="ชื่อใน SoundService.BGM"}  (""/nil = เงียบ)
--       | {type="sound",name="ชื่อใน SoundService.SFX"} (เสียงประกอบครั้งเดียว)
-- cam = ชื่อ Part ใน Workspace.CutsceneCams — ตำแหน่ง Part = ตำแหน่งกล้อง, ด้าน Front ของ Part = ทิศที่กล้องมอง
--       ใช้ plugin tools/CutsceneCamTool.plugin.luau วาง/ส่อง/พรีวิว ไม่ต้องหมุนมือ (docs/engines/cutscene.md §3)
-- camera step ที่ใส่ t = เลื่อนกล้องนุ่มๆ t วินาที (ไม่ใส่ = ตัดภาพทันที) และ **ไม่หยุดรอ** — บทเดินต่อทันที ใส่ wait เองถ้าอยากรอ
-- pure: validate | glue: play() — content อยู่ Content/Endings/* ทีมแก้ได้ไม่แตะไฟล์นี้
local isStudio = script ~= nil
local Audio = if isStudio
	then require(script.Parent.Parent.AudioService)
	else require("../AudioService")

local CutscenePlayer = {}
CutscenePlayer.running = false

local VALID = {
	text = function(s) return type(s.text) == "string" end,
	wait = function(s) return type(s.t) == "number" end,
	camera = function(s)
		if s.t ~= nil and type(s.t) ~= "number" then return false end
		if type(s.cam) == "string" then return true end
		return type(s.pos) == "table" and #s.pos == 3 and type(s.look) == "table" and #s.look == 3
	end,
	bgm = function(s) return s.name == nil or type(s.name) == "string" end,
	sound = function(s) return type(s.name) == "string" end,
}

-- เช็ค script ก่อนเล่น — คืน (ผ่านไหม, ข้อความ error)
function CutscenePlayer.validate(steps)
	if type(steps) ~= "table" then return false, "ไม่ใช่ตาราง" end
	for i, s in steps do
		local v = VALID[s.type]
		if not v then return false, ("step %d: type ไม่รู้จัก %s"):format(i, tostring(s.type)) end
		if not v(s) then return false, ("step %d: field ไม่ครบ (%s)"):format(i, s.type) end
	end
	return true
end

-- ===== UI glue (Studio เท่านั้น) =====
function CutscenePlayer.play(playerGui, steps, onDone)
	if CutscenePlayer.running then return end
	local ok, err = CutscenePlayer.validate(steps)
	if not ok then
		warn("[CutscenePlayer] script พัง:", err)
		return
	end
	CutscenePlayer.running = true
	Audio.lockBGM(true) -- โซนหยุดสั่งเพลงระหว่าง cutscene

	local camera = workspace.CurrentCamera
	local savedType = camera.CameraType
	local savedFov = camera.FieldOfView
	local TweenService = game:GetService("TweenService")

	-- ย้ายกล้องไป cf (+fov ถ้ามี) — t>0 = เลื่อนนุ่มๆ, ไม่รอให้จบ บทเดินต่อได้
	local function moveCam(cf: CFrame, fov: number?, t: number?)
		camera.CameraType = Enum.CameraType.Scriptable
		local goalFov = fov or savedFov
		if t and t > 0 then
			TweenService:Create(
				camera,
				TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ CFrame = cf, FieldOfView = goalFov }
			):Play()
		else
			camera.CFrame = cf
			camera.FieldOfView = goalFov
		end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_Cutscene"
	gui.ResetOnSpawn = false
	local bar1 = Instance.new("Frame") -- แถบหนังบน-ล่าง
	bar1.Size = UDim2.new(1, 0, 0.12, 0)
	bar1.BackgroundColor3 = Color3.new(0, 0, 0)
	bar1.Parent = gui
	local bar2 = bar1:Clone()
	bar2.Position = UDim2.new(0, 0, 0.88, 0)
	bar2.Parent = gui
	-- ซับไตเติลแบบหนัง — **ไม่มีกรอบพื้นหลัง** (โหมด 1) อ่านออกด้วยขอบดำรอบตัวอักษรแทน
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.8, 0, 0.1, 0)
	label.Position = UDim2.new(0.1, 0, 0.78, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Text = ""
	label.Visible = false
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.35
	stroke.Parent = label
	gui.Parent = playerGui

	task.spawn(function()
		for _, step in steps do
			if step.type == "text" then
				label.Visible = true
				label.Text = step.text:gsub("%[%a+%]", "") -- tag ความเร็วยังไม่ใช้ใน cutscene
				task.wait(math.max(1.5, #step.text * 0.03))
			elseif step.type == "wait" then
				task.wait(step.t)
			elseif step.type == "bgm" then
				Audio.bgm(step.name)
			elseif step.type == "sound" then
				Audio.sfx(step.name)
			elseif step.type == "camera" then
				if step.cam then
					local folder = workspace:FindFirstChild("CutsceneCams")
					local part = folder and folder:FindFirstChild(step.cam, true)
						or workspace:FindFirstChild(step.cam, true)
					if part and part:IsA("BasePart") then
						-- ด้าน Front ของ Part = ทิศกล้อง (LookVector) ตรงกันพอดี ไม่ต้องแปลงอะไร
						moveCam(part.CFrame, part:GetAttribute("FOV"), step.t)
					else
						warn("[CutscenePlayer] ไม่เจอ Part กล้อง:", step.cam)
					end
				else
					moveCam(CFrame.lookAt(
						Vector3.new(step.pos[1], step.pos[2], step.pos[3]),
						Vector3.new(step.look[1], step.look[2], step.look[3])
					), nil, step.t)
				end
			end
		end
		camera.CameraType = savedType
		camera.FieldOfView = savedFov
		gui:Destroy()
		CutscenePlayer.running = false
		Audio.lockBGM(false) -- คืนสิทธิ์ให้โซนคุมเพลงต่อ
		if onDone then onDone() end
	end)
end

return CutscenePlayer
