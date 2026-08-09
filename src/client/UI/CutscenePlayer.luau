-- CutscenePlayer.luau — **cutscene โหมด 1 "หนัง"** (design doc §8, Genshin ref)
-- player กดอะไรไม่ได้ · กล้องเปลี่ยนบ่อย/เลื่อนได้ · ซับไตเติลล่างจอ **ไม่มีกรอบข้อความ** · เดินตามเวลาเอง
-- step: camera / text / wait / bgm / sound / anim (ท่าทาง) / face (สีหน้า) — ดู VALID ข้างล่าง
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
local AnimPlayer = if isStudio
	then require(script.Parent.Parent.AnimPlayer)
	else require("../AnimPlayer")

local CutscenePlayer = {}
CutscenePlayer.running = false

-- easing ต่อกล้อง: attribute Ease บน Part (ตั้งด้วย CutsceneCamTool) หรือ field ease ใน step
-- "Cut" = ตัดภาพทันที (ไม่ tween จัดการที่ t=0) · แต่ละแบบเก็บ {style, direction}
local EASE = {
	In = { Enum.EasingStyle.Quad, Enum.EasingDirection.In },
	Out = { Enum.EasingStyle.Quad, Enum.EasingDirection.Out },
	InOut = { Enum.EasingStyle.Quad, Enum.EasingDirection.InOut },
	Linear = { Enum.EasingStyle.Linear, Enum.EasingDirection.InOut },
}

-- ปลายทางของ step move: ยืนที่ targetPos หันหน้าไปทางที่เดินมา (ถ้าเกือบไม่ขยับ = คงหันเดิม)
-- pure — เทสได้ ไม่แตะ Roblox instance
function CutscenePlayer.moveGoal(startCf: CFrame, targetPos: Vector3): CFrame
	local flat = (targetPos - startCf.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.1 then
		return CFrame.new(targetPos) * (startCf - startCf.Position) -- คงมุมหันเดิม
	end
	return CFrame.lookAt(targetPos, targetPos + flat)
end

local VALID = {
	-- t = ค้าง text กี่วิ ก่อนไป step ถัดไป (ไม่ใส่ = ไม่รอ ค้างจนสั่ง text ใหม่/wait เอง)
	text = function(s) return type(s.text) == "string" and (s.t == nil or type(s.t) == "number") end,
	wait = function(s) return type(s.t) == "number" end,
	camera = function(s)
		if s.t ~= nil and type(s.t) ~= "number" then return false end
		if s.ease ~= nil and not EASE[s.ease] and s.ease ~= "Cut" then return false end
		if type(s.cam) == "string" then return true end
		return type(s.pos) == "table" and #s.pos == 3 and type(s.look) == "table" and #s.look == 3
	end,
	bgm = function(s) return s.name == nil or type(s.name) == "string" end,
	sound = function(s) return type(s.name) == "string" end,
	-- ท่าทางตัวละคร: actor = ชื่อไฟล์บท/ชื่อโมเดล ("player" = ตัวผู้เล่น), name = ชื่อท่าใน ReplicatedStorage.Animations
	anim = function(s)
		return type(s.actor) == "string" and type(s.name) == "string"
			and (s.loop == nil or type(s.loop) == "boolean")
	end,
	-- สีหน้า: name = ชื่อใน ReplicatedStorage.Faces (ค้างจนสั่งใหม่ · จบฉากคืนหน้าเดิม)
	face = function(s) return type(s.actor) == "string" and type(s.name) == "string" end,
	-- preload แมพไกล: target = ชื่อ Part ที่อยากให้ stream โหลด (ย้ายศูนย์ streaming ไปที่นั่นชั่วคราว)
	-- วางก่อน cam ที่ส่องแมพนั้น ~2-3 วิ ให้แมพโหลดทัน · จบฉากคืน focus ให้ตัวละครอัตโนมัติ
	focus = function(s) return type(s.target) == "string" end,
	-- เดินตัวละคร: actor ไป Part ชื่อ to ใน t วิ (ไม่ใส่ t/0 = วาปทันที) — หยุดรอจนถึง
	-- ใส่ anim "Walk" ก่อน + Idle/SitDown หลังเองในบท (move แค่ย้ายตำแหน่ง) · PivotTo lerp กัน physics
	move = function(s)
		return type(s.actor) == "string" and type(s.to) == "string"
			and (s.t == nil or type(s.t) == "number")
	end,
	-- เล่น animation บน prop ไม่มีชีวิต (โล่รางวัล/กล่อง ฯลฯ) — ต้องมี AnimationController ในตัว prop (docs/engines/story-beat.md)
	objAnim = function(s)
		return type(s.object) == "string" and type(s.name) == "string"
			and (s.loop == nil or type(s.loop) == "boolean")
	end,
	-- ผูก prop ติดมือ actor (Weld) — ใช้ตอน "ถือของ" ระหว่างท่าทาง เช่น รับโล่รางวัล
	hold = function(s)
		return type(s.actor) == "string" and type(s.prop) == "string"
			and (s.limb == nil or type(s.limb) == "string")
	end,
	unhold = function(s) return type(s.prop) == "string" end,
	-- โชว์/ซ่อน Part หรือ Model (ทุก BasePart ข้างใน) — ใช้สลับของจริงกับ duplicate สำหรับ animate
	-- (เช่น ประตูจริงที่มี script ควบคุมอยู่แล้ว vs duplicate ที่ตัด script ออกไว้ animate เฉยๆ)
	visible = function(s) return type(s.target) == "string" and type(s.show) == "boolean" end,
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
	-- cutscene = เงียบ ไม่มีเพลงโซน (ฉากคุย NPC ยังมีเพลงปกติ) — บทสั่ง { type="bgm" } เองได้ถ้าอยากมี
	-- lockBGM กันโซนสั่งเพลงใหม่ · bgm(nil) ดับเพลงที่ค้างมาจากเมนู/โซนก่อนหน้า (lock อย่างเดียวไม่ดับของเดิม)
	Audio.lockBGM(true)
	Audio.bgm(nil)
	-- หยุดนาฬิกาเกมตลอด cutscene — การันตีทุก trigger ไม่พึ่ง caller · caller เป็นคน unfreeze ตอนจบ/ต่อ transition
	game:GetService("ReplicatedStorage").Shared.Remotes.Action:FireServer({ type = "FreezeTime", on = true })

	-- ล็อกไม่ให้ player เดินระหว่าง cutscene — จำค่าเดิมไว้คืนตอนจบ
	-- attribute MoveLocked = สัญญาณให้ script อื่นที่แตะ WalkSpeed (SprintHandler) หยุดยุ่ง
	-- ไม่งั้นมันวน set ทับทุก 0.1 วิ แล้วเดินได้ระหว่างฉาก (docs/05 §gotchas)
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

	-- ย้ายกล้องไป cf (+fov ถ้ามี) — t>0 = เลื่อนนุ่มๆ, ไม่รอให้จบ บทเดินต่อได้
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
	gui.IgnoreGuiInset = true -- ให้แถบหนังคลุมเต็มจอ (ไม่โดน topbar inset ดันลง)
	gui.DisplayOrder = 10
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

	-- ปุ่มข้ามฉาก มุมขวาล่าง — กดแล้วเลิกเล่น step ที่เหลือ แล้วเข้า cleanup/onDone ตามปกติ
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
	skipBtn:SetAttribute("Sfx", "ui_back") -- ปุ่มข้าม = เสียงกลุ่มยกเลิก/ย้อน ไม่ใช่คลิกยืนยัน
	skipBtn.Parent = gui
	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 6)
	skipCorner.Parent = skipBtn
	skipBtn.Activated:Connect(function()
		skipped = true
		skipBtn.Text = "กำลังข้าม..."
		skipBtn.Active = false
	end)

	gui.Parent = playerGui

	-- รอแบบขัดจังหวะได้ — กดข้ามแล้วไม่ต้องรอ wait ที่ค้างอยู่ให้ครบ · คืน true ถ้าโดนข้าม
	local function waitOrSkip(t: number): boolean
		local t0 = os.clock()
		while os.clock() - t0 < t do
			if skipped then return true end
			task.wait(0.05)
		end
		return skipped
	end

	local movedActors = {} -- ตัวที่ถูกสั่งท่า — จบฉากแล้วหยุดให้หมด
	local heldProps = {} -- prop ที่ hold() ไว้ — จบฉากแล้ว unhold ให้หมด (เว้น step ระบุ persist=true)
	local actionRemote = game:GetService("ReplicatedStorage").Shared.Remotes.Action
	-- ไม่คืน focus ตอนจบฉาก — ปล่อยให้ค้างที่เป้าจน TeleportTo (server) ย้ายตัวเข้าโซนนั้นแล้วค่อย clear
	-- (clear ก่อน teleport = โซนที่ preload ไว้ unload ทันที แล้วต้องโหลดใหม่ตอนวาป = gameplay paused)
	task.spawn(function()
		for idx, step in steps do
			if skipped then
				-- กดข้าม: ยิง focus/preload ที่ยังไม่ถึงให้หมดก่อนออก ไม่งั้นแมพปลายทางไม่เริ่ม stream
				-- (caller เล่น waitStreamedAround ใต้จอดำต่อ = รอโหลดเสร็จก่อน fade กลับ)
				for j = idx, #steps do
					if steps[j].type == "focus" then
						actionRemote:FireServer({ type = "SetFocus", target = steps[j].target })
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
				actionRemote:FireServer({ type = "SetFocus", target = step.target }) -- preload แมพจุดนั้น
			elseif step.type == "objAnim" then
				AnimPlayer.playObject(step.object, step.name, step.loop)
			elseif step.type == "hold" then
				if AnimPlayer.hold(step.actor, step.prop, step.limb) and not step.persist then
					heldProps[step.prop] = true -- auto-unhold ตอนจบฉาก เว้นแต่สั่ง persist=true (อยากให้ถือค้างต่อหลัง cutscene)
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
				-- subtitle ค้างจนสั่ง text ใหม่ · ใส่ t = ค้างกี่วิก่อนไปต่อ (ไม่ใส่ = ไม่รอ ใช้ wait เอง)
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
						-- easing/เวลา: step ทับ attribute ทับ default · "Cut"/t=0 = ตัดภาพทันที
						local ease = step.ease or part:GetAttribute("Ease") or "InOut"
						local t = step.t or part:GetAttribute("TweenTime") or 0
						if ease == "Cut" then t = 0 end
						local e = EASE[ease]
						-- ด้าน Front ของ Part = ทิศกล้อง (LookVector) ตรงกันพอดี ไม่ต้องแปลงอะไร
						moveCam(part.CFrame, part:GetAttribute("FOV"), t, e and e[1], e and e[2])
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
			end
		end
		for actor in movedActors do AnimPlayer.stop(actor) end
		for propName in heldProps do AnimPlayer.unhold(propName) end
		if hum and hum.Parent then
			hum.WalkSpeed, hum.JumpPower = savedWalk, savedJump
			hum:SetAttribute("MoveLocked", nil) -- ปลดล็อก — SprintHandler คืนความเร็วตามปุ่ม Shift เอง
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
