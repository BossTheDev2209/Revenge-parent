-- CutscenePlayer — cutscene โหมด 1 "หนัง": player คุมไม่ได้ · กล้องเปลี่ยนบ่อย · ซับไตเติลไม่มีกรอบ · เดินตามเวลาเอง
-- step: text/wait/camera/bgm/sound/anim/face/focus/move/objAnim/swing/hold/unhold/visible/time (ดู VALID)
-- โหมด 2 "ฉากคุย" (กล่องข้อความ + ช้อย) อยู่ที่ DialogueUI · content อยู่ Content/Endings/* ทีมแก้ได้ไม่แตะไฟล์นี้
-- cam = ชื่อ Part ใน Workspace.CutsceneCams (ด้าน Front = ทิศกล้อง) · วางด้วย CutsceneCamTool plugin
-- pure: validate/moveGoal | glue: play()
local isStudio = script ~= nil
local Audio = if isStudio
	then require(script.Parent.Parent.AudioService)
	else require("../AudioService")
local AnimPlayer = if isStudio
	then require(script.Parent.Parent.AnimPlayer)
	else require("../AnimPlayer")
local PreloadService = if isStudio
	then require(script.Parent.Parent.PreloadService)
	else require("../PreloadService")

local CutscenePlayer = {}
CutscenePlayer.running = false

-- easing: attribute Ease บน Part (CutsceneCamTool) หรือ field ease ใน step · "Cut" = ตัดภาพทันที
local EASE = {
	In = { Enum.EasingStyle.Quad, Enum.EasingDirection.In },
	Out = { Enum.EasingStyle.Quad, Enum.EasingDirection.Out },
	InOut = { Enum.EasingStyle.Quad, Enum.EasingDirection.InOut },
	Linear = { Enum.EasingStyle.Linear, Enum.EasingDirection.InOut },
}

-- ปลายทาง step move: ยืนที่ targetPos หันหน้าไปทางที่เดินมา (เกือบไม่ขยับ = คงหันเดิม) · pure
function CutscenePlayer.moveGoal(startCf: CFrame, targetPos: Vector3): CFrame
	local flat = (targetPos - startCf.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.1 then
		return CFrame.new(targetPos) * (startCf - startCf.Position)
	end
	return CFrame.lookAt(targetPos, targetPos + flat)
end

-- field ของแต่ละ step type · t = ค้าง/เลื่อนกี่วิ (ไม่ใส่ = ไม่รอ ใช้ wait เอง)
local VALID = {
	text = function(s) return type(s.text) == "string" and (s.t == nil or type(s.t) == "number") end,
	wait = function(s) return type(s.t) == "number" end,
	camera = function(s) -- cam = ชื่อ Part | หรือ pos+look = {x,y,z}
		if s.t ~= nil and type(s.t) ~= "number" then return false end
		if s.ease ~= nil and not EASE[s.ease] and s.ease ~= "Cut" then return false end
		if type(s.cam) == "string" then return true end
		return type(s.pos) == "table" and #s.pos == 3 and type(s.look) == "table" and #s.look == 3
	end,
	bgm = function(s) return s.name == nil or type(s.name) == "string" end,
	sound = function(s) return type(s.name) == "string" end,
	anim = function(s) -- actor = ชื่อบท/โมเดล ("player") · name = ท่าใน ReplicatedStorage.Animations
		return type(s.actor) == "string" and type(s.name) == "string"
			and (s.loop == nil or type(s.loop) == "boolean")
	end,
	face = function(s) return type(s.actor) == "string" and type(s.name) == "string" end, -- ชื่อใน Faces
	focus = function(s) return type(s.target) == "string" end, -- preload แมพไกล (วางก่อน cam ~2-3 วิ)
	move = function(s) -- เดิน actor ไป Part ชื่อ to ใน t วิ (หยุดรอ) · ใส่ anim Walk/Idle เองในบท
		return type(s.actor) == "string" and type(s.to) == "string"
			and (s.t == nil or type(s.t) == "number")
	end,
	objAnim = function(s) -- animation บน prop (ต้องมี AnimationController ในตัว)
		return type(s.object) == "string" and type(s.name) == "string"
			and (s.loop == nil or type(s.loop) == "boolean")
	end,
	swing = function(s) -- หมุนโมเดลรอบ PrimaryPart (ประตู/ฝากล่อง) · deg = องศารวม, t = วิ (ไม่ใส่ = 0.6)
		return type(s.target) == "string" and type(s.deg) == "number"
			and (s.t == nil or type(s.t) == "number")
	end,
	hold = function(s) -- ผูก prop ติดมือ actor (Weld)
		return type(s.actor) == "string" and type(s.prop) == "string"
			and (s.limb == nil or type(s.limb) == "string")
	end,
	unhold = function(s) return type(s.prop) == "string" end,
	visible = function(s) return type(s.target) == "string" and type(s.show) == "boolean" end, -- สลับของจริง↔duplicate
	time = function(s) return type(s.hour) == "number" end, -- ล็อกดวงอาทิตย์ของฉาก (ไม่เดินเวลาจริง)
}

-- เช็ค script ก่อนเล่น — คืน (ผ่านไหม, error)
function CutscenePlayer.validate(steps)
	if type(steps) ~= "table" then return false, "ไม่ใช่ตาราง" end
	for i, s in steps do
		local v = VALID[s.type]
		if not v then return false, ("step %d: type ไม่รู้จัก %s"):format(i, tostring(s.type)) end
		if not v(s) then return false, ("step %d: field ไม่ครบ (%s)"):format(i, s.type) end
	end
	return true
end

function CutscenePlayer.play(playerGui, steps, onDone)
	if CutscenePlayer.running then return end
	local ok, err = CutscenePlayer.validate(steps)
	if not ok then
		warn("[CutscenePlayer] script พัง:", err)
		return
	end
	CutscenePlayer.running = true
	-- ★ แก้ 12 ส.ค. (user: "แมพโหลดไม่ทัน") — ยิง preload animation ที่ steps นี้จะเรียกไว้ตั้งแต่ต้นฉาก
	--   ขนานไปกับ freeze/lock ด้านล่าง (fire-and-forget ไม่บล็อก) ทัน step "anim" จริงส่วนใหญ่เพราะ
	--   ก่อนหน้ามักมี camera/text/wait step คั่นให้เวลาโหลดอยู่แล้ว (ดู PreloadService.luau)
	PreloadService.preloadCutscene(steps)
	-- cutscene = เงียบ ไม่มีเพลงโซน (ฉากคุย NPC ยังมีเพลงปกติ) — บทสั่ง { type="bgm" } เองได้ถ้าอยากมี
	-- lockBGM กันโซนสั่งเพลงใหม่ · bgm(nil) ดับเพลงที่ค้างมาจากเมนู/โซนก่อนหน้า (lock อย่างเดียวไม่ดับของเดิม)
	Audio.lockBGM(true)
	Audio.bgm(nil)
	-- หยุดนาฬิกาเกมตลอด cutscene · caller เป็นคน unfreeze ตอนจบ/ต่อ transition
	game:GetService("ReplicatedStorage").Shared.Remotes.Action:FireServer({ type = "FreezeTime", on = true })

	-- ล็อกไม่ให้ player เดิน · MoveLocked = สัญญาณให้ SprintHandler หยุดยุ่ง WalkSpeed (ไม่งั้นมัน set ทับทุก 0.1 วิ)
	local char = game:GetService("Players").LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local savedWalk, savedJump
	if hum then
		savedWalk, savedJump = hum.WalkSpeed, hum.JumpPower
		hum:SetAttribute("MoveLocked", true)
		hum.WalkSpeed, hum.JumpPower = 0, 0
	end

	local camera = workspace.CurrentCamera
	local savedType = camera.CameraType
	local savedFov = camera.FieldOfView
	local TweenService = game:GetService("TweenService")

	-- ย้ายกล้องไป cf (+fov) — t>0 = เลื่อนนุ่มๆ ไม่รอให้จบ
	local function moveCam(cf: CFrame, fov: number?, t: number?, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
		camera.CameraType = Enum.CameraType.Scriptable
		local goalFov = fov or savedFov
		if t and t > 0 then
			TweenService:Create(
				camera,
				TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.InOut),
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
	gui.IgnoreGuiInset = true -- แถบหนังคลุมเต็มจอ
	gui.DisplayOrder = 10
	local bar1 = Instance.new("Frame") -- แถบหนังบน-ล่าง
	bar1.Size = UDim2.new(1, 0, 0.12, 0)
	bar1.BackgroundColor3 = Color3.new(0, 0, 0)
	bar1.Parent = gui
	local bar2 = bar1:Clone()
	bar2.Position = UDim2.new(0, 0, 0.88, 0)
	bar2.Parent = gui
	-- ซับไตเติลแบบหนัง ไม่มีกรอบพื้นหลัง — อ่านออกด้วยขอบดำรอบตัวอักษร
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

	-- ปุ่มข้ามฉาก มุมขวาล่าง — กดแล้วเลิกเล่น step ที่เหลือ แล้วเข้า cleanup/onDone ปกติ
	local skipped = false
	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipButton"
	skipBtn.Size = UDim2.new(0, 120, 0, 34)
	skipBtn.Position = UDim2.new(1, -136, 1, -48)
	skipBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	skipBtn.BackgroundTransparency = 0.35
	skipBtn.TextColor3 = Color3.new(1, 1, 1)
	skipBtn.TextScaled = true
	skipBtn.Text = "ข้าม ⏭"
	skipBtn:SetAttribute("Sfx", "ui_back")
	skipBtn.Parent = gui
	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 6)
	skipCorner.Parent = skipBtn
	skipBtn.Activated:Connect(function()
		skipped = true
		skipBtn.Text = "กำลังข้าม..."
		skipBtn.Active = false
	end)

	-- ซ่อน GUI อื่นที่เปิดอยู่ระหว่างฉาก (HUD/ปุ่มเซฟ บังภาพ) — จำไว้คืนตอนจบ
	local hiddenGuis = {}
	for _, g in playerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(hiddenGuis, g)
		end
	end

	gui.Parent = playerGui

	-- รอแบบขัดจังหวะได้ — กดข้ามแล้วไม่ต้องรอ wait ให้ครบ · คืน true ถ้าโดนข้าม
	local function waitOrSkip(t: number): boolean
		local t0 = os.clock()
		while os.clock() - t0 < t do
			if skipped then return true end
			task.wait(0.05)
		end
		return skipped
	end

	local movedActors = {} -- ตัวที่ถูกสั่งท่า — จบฉากหยุดให้หมด
	local heldProps = {} -- prop ที่ hold() ไว้ — จบฉาก unhold (เว้น persist=true)
	local actionRemote = game:GetService("ReplicatedStorage").Shared.Remotes.Action
	-- ไม่คืน focus ตอนจบฉาก — ปล่อยค้างจน TeleportTo ย้ายตัวเข้าโซนแล้วค่อย clear
	-- (clear ก่อน teleport = โซนที่ preload unload ทันที ต้องโหลดใหม่ตอนวาป = gameplay paused)
	task.spawn(function()
		for idx, step in steps do
			if skipped then
				-- กดข้าม = กระโดดไปสถานะ "จบฉาก": apply ผลถาวรของทุก step ที่เหลือทันที (ไม่ tween/wait)
				-- ★ แก้ 12 ส.ค. (user: กดข้ามคัตซีนฟ้าใสแล้วประตูกั้น) — เดิม fire แค่ focus step
				--   step อื่นที่ยังไม่ถึงเลยค้างสถานะกลางฉาก: swing (ประตู) ไม่เปิด → Door Rig ค้างปิดบังกล้อง
				--   ตอน dialogue ต่อมา · move (ตัวละครเข้าที่) ไม่ snap · visible (prop) ไม่อัปเดต
				for j = idx, #steps do
					local s = steps[j]
					if s.type == "focus" then
						actionRemote:FireServer({ type = "SetFocus", target = s.target }) -- preload แมพปลายทาง (caller รอ stream ใต้จอดำ)
					elseif s.type == "move" then
						local rig = AnimPlayer.findRig(s.actor)
						local target = workspace:FindFirstChild(s.to, true)
						if rig and target and target:IsA("BasePart") then
							rig:PivotTo(CutscenePlayer.moveGoal(rig:GetPivot(), target.Position)) -- snap ถึงปลายทางเลย
						end
					elseif s.type == "swing" then
						-- เปิดประตูให้ครบองศาทันที (บานที่ยังไม่ถึง swing step) — กันค้างปิดบังฉากคุย
						local model = workspace:FindFirstChild(s.target, true)
						local hinge = model and model:IsA("Model") and model.PrimaryPart
						if hinge then
							local d = (hinge.CFrame * CFrame.Angles(0, math.rad(s.deg), 0)) * hinge.CFrame:Inverse()
							model:PivotTo(d * model:GetPivot())
						end
					elseif s.type == "visible" then
						local target = workspace:FindFirstChild(s.target, true)
						if target then
							local parts = target:IsA("BasePart") and { target } or target:GetDescendants()
							for _, p in parts do
								if p:IsA("BasePart") then p.Transparency = s.show and 0 or 1; p.CanCollide = s.show end
							end
						end
					end
				end
				break
			end
			if step.type == "anim" then
				AnimPlayer.play(step.actor, step.name, step.loop)
				movedActors[step.actor] = true
			elseif step.type == "move" then
				local rig = AnimPlayer.findRig(step.actor)
				local target = workspace:FindFirstChild(step.to, true)
				if rig and target and target:IsA("BasePart") then
					local hrp = rig:FindFirstChild("HumanoidRootPart")
					local startCf = rig:GetPivot()
					local goalCf = CutscenePlayer.moveGoal(startCf, target.Position)
					local wasAnchored = hrp and hrp.Anchored
					if hrp then hrp.Anchored = true end -- กัน physics ดึงระหว่าง PivotTo
					local t = step.t or 0
					if t > 0 then
						local t0 = os.clock()
						while os.clock() - t0 < t and not skipped do
							rig:PivotTo(startCf:Lerp(goalCf, (os.clock() - t0) / t))
							task.wait()
						end
					end
					rig:PivotTo(goalCf) -- snap ให้ถึงเป๊ะ (รวมกรณีโดนข้าม)
					if hrp then hrp.Anchored = wasAnchored end
				else
					warn("[CutscenePlayer] move: หาไม่เจอ actor/target", step.actor, step.to)
				end
			elseif step.type == "focus" then
				actionRemote:FireServer({ type = "SetFocus", target = step.target })
			elseif step.type == "objAnim" then
				AnimPlayer.playObject(step.object, step.name, step.loop)
			elseif step.type == "swing" then
				local model = workspace:FindFirstChild(step.target, true)
				local hinge = model and model:IsA("Model") and model.PrimaryPart
				if hinge then
					-- หมุนรอบบานพับ: คิด delta ในพิกัดโลกจาก hinge แล้วคูณเข้า pivot ปัจจุบัน (ยกทั้งโมเดลแบบแข็ง)
					-- ไม่ใช้ hinge.CFrame เป็น pivot ตรงๆ เพราะ WorldPivot อาจไม่ได้อยู่ที่ hinge
					local steps_ = 24
					local per = CFrame.Angles(0, math.rad(step.deg / steps_), 0)
					local dt = (step.t or 0.6) / steps_
					task.spawn(function()
						local applied = 0
						for _ = 1, steps_ do
							if skipped then break end
							local delta = (hinge.CFrame * per) * hinge.CFrame:Inverse()
							model:PivotTo(delta * model:GetPivot())
							applied += step.deg / steps_
							task.wait(dt)
						end
						-- โดนข้ามกลางหมุน = เปิดส่วนที่เหลือให้ครบทันที (ไม่ค้างครึ่งบาน — user เจอ 12 ส.ค.)
						if skipped and applied < step.deg then
							local d = (hinge.CFrame * CFrame.Angles(0, math.rad(step.deg - applied), 0)) * hinge.CFrame:Inverse()
							model:PivotTo(d * model:GetPivot())
						end
					end)
				else
					warn("[CutscenePlayer] swing: หาไม่เจอ/ไม่มี PrimaryPart", step.target)
				end
			elseif step.type == "hold" then
				if AnimPlayer.hold(step.actor, step.prop, step.limb) and not step.persist then
					heldProps[step.prop] = true -- auto-unhold ตอนจบ เว้น persist=true
				end
			elseif step.type == "unhold" then
				AnimPlayer.unhold(step.prop)
				heldProps[step.prop] = nil
			elseif step.type == "visible" then
				local target = workspace:FindFirstChild(step.target, true)
				if target then
					local parts = target:IsA("BasePart") and { target } or target:GetDescendants()
					for _, p in parts do
						if p:IsA("BasePart") then
							p.Transparency = step.show and 0 or 1
							p.CanCollide = step.show
						end
					end
				else
					warn("[CutscenePlayer] visible: หาไม่เจอ", step.target)
				end
			elseif step.type == "face" then
				AnimPlayer.setFace(step.actor, step.name)
				movedActors[step.actor] = true
			elseif step.type == "text" then
				label.Visible = true
				label.Text = step.text:gsub("%[%a+%]", "") -- tag ความเร็วยังไม่ใช้ใน cutscene
				if step.t then waitOrSkip(step.t) end
			elseif step.type == "wait" then
				waitOrSkip(step.t)
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
						local ease = step.ease or part:GetAttribute("Ease") or "InOut" -- step ทับ attribute ทับ default
						local t = step.t or part:GetAttribute("TweenTime") or 0
						if ease == "Cut" then t = 0 end
						local e = EASE[ease]
						moveCam(part.CFrame, part:GetAttribute("FOV"), t, e and e[1], e and e[2]) -- Front = ทิศกล้อง
					else
						warn("[CutscenePlayer] ไม่เจอ Part กล้อง:", step.cam)
					end
				else
					local ease = step.ease or "InOut"
					local t = if ease == "Cut" then 0 else step.t
					local e = EASE[ease]
					moveCam(CFrame.lookAt(
						Vector3.new(step.pos[1], step.pos[2], step.pos[3]),
						Vector3.new(step.look[1], step.look[2], step.look[3])
					), nil, t, e and e[1], e and e[2])
				end
			elseif step.type == "time" then
				game:GetService("Lighting"):SetAttribute("SceneClock", step.hour) -- HUD อ่านทับ ClockTime
			end
		end
		game:GetService("Lighting"):SetAttribute("SceneClock", nil) -- จบฉากคืนเวลาจริง
		for actor in movedActors do AnimPlayer.stop(actor) end
		for propName in heldProps do AnimPlayer.unhold(propName) end
		if hum and hum.Parent then
			hum.WalkSpeed, hum.JumpPower = savedWalk, savedJump
			hum:SetAttribute("MoveLocked", nil)
		end
		camera.CameraType = savedType
		camera.FieldOfView = savedFov
		gui:Destroy()
		for _, g in hiddenGuis do if g.Parent then g.Enabled = true end end
		CutscenePlayer.running = false
		Audio.lockBGM(false)
		if onDone then onDone() end
	end)
end

return CutscenePlayer
