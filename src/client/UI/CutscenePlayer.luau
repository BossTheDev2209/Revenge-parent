-- CutscenePlayer.luau — เล่น cutscene จาก script data (design doc §8, Genshin ref)
-- step: {type="text",text=} | {type="wait",t=} | {type="camera",cam="ชื่อPart"} | {type="camera",pos={x,y,z},look={x,y,z}}
-- cam = ชื่อ Part ใน Workspace.CutsceneCams (ทีมวาง Part หันหน้าไปทางที่อยากให้กล้องมอง — docs/10)
-- pure: validate | glue: play() — content อยู่ Content/Endings/* ทีมแก้ได้ไม่แตะไฟล์นี้
local CutscenePlayer = {}
CutscenePlayer.running = false

local VALID = {
	text = function(s) return type(s.text) == "string" end,
	wait = function(s) return type(s.t) == "number" end,
	camera = function(s)
		if type(s.cam) == "string" then return true end
		return type(s.pos) == "table" and #s.pos == 3 and type(s.look) == "table" and #s.look == 3
	end,
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

	local camera = workspace.CurrentCamera
	local savedType = camera.CameraType

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
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.8, 0, 0.14, 0)
	label.Position = UDim2.new(0.1, 0, 0.72, 0)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = ""
	label.Visible = false
	label.Parent = gui
	gui.Parent = playerGui

	task.spawn(function()
		for _, step in steps do
			if step.type == "text" then
				label.Visible = true
				label.Text = step.text:gsub("%[%a+%]", "") -- tag ความเร็วยังไม่ใช้ใน cutscene
				task.wait(math.max(1.5, #step.text * 0.03))
			elseif step.type == "wait" then
				task.wait(step.t)
			elseif step.type == "camera" then
				if step.cam then
					local folder = workspace:FindFirstChild("CutsceneCams")
					local part = folder and folder:FindFirstChild(step.cam, true)
						or workspace:FindFirstChild(step.cam, true)
					if part and part:IsA("BasePart") then
						camera.CameraType = Enum.CameraType.Scriptable
						camera.CFrame = part.CFrame
					else
						warn("[CutscenePlayer] ไม่เจอ Part กล้อง:", step.cam)
					end
				else
					camera.CameraType = Enum.CameraType.Scriptable
					camera.CFrame = CFrame.lookAt(
						Vector3.new(step.pos[1], step.pos[2], step.pos[3]),
						Vector3.new(step.look[1], step.look[2], step.look[3])
					)
				end
			end
		end
		camera.CameraType = savedType
		gui:Destroy()
		CutscenePlayer.running = false
		if onDone then onDone() end
	end)
end

return CutscenePlayer
