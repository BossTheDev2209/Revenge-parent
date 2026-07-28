-- CutsceneCamTool — Studio plugin ช่วยวาง/ส่อง/พรีวิวมุมกล้อง cutscene
-- ติดตั้ง: copy ไฟล์นี้ไป  %LOCALAPPDATA%\Roblox\Plugins\CutsceneCamTool.lua  แล้วเปิด Studio ใหม่
--          (หรือใน Studio: คลิกขวาไฟล์ใน Explorer > Save as Local Plugin)
--
-- 4 ปุ่ม:
--   Place Cam   — สร้าง Part กล้องตรงมุมมอง Studio ปัจจุบัน (หันถูกทางอัตโนมัติ + จำ FOV)
--   Aim Cam     — เอา Part ที่เลือก มาตั้งตามมุมมอง Studio ปัจจุบัน (แก้ช็อตเดิม)
--   Look Thru   — ย้ายมุมมอง Studio ไปยืนที่ Part ที่เลือก = เห็นภาพจริงที่ player จะเห็น
--   Tour        — ไล่กล้องผ่าน Part ที่เลือกทีละตัวตามลำดับชื่อ (พรีวิวทั้งฉาก)

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "CutsceneCams"
local DEFAULT_FOV = 70
local TOUR_SECONDS = 2 -- เวลาเดินทางต่อ 1 ช็อตตอน Tour

local toolbar = plugin:CreateToolbar("Cutscene Cams")
local placeBtn = toolbar:CreateButton("Place Cam", "สร้าง Part กล้องตรงมุมมองตอนนี้", "rbxasset://textures/ui/GuiImagePlaceholder.png")
local aimBtn = toolbar:CreateButton("Aim Cam", "ตั้ง Part ที่เลือก ให้ตรงมุมมองตอนนี้", "rbxasset://textures/ui/GuiImagePlaceholder.png")
local lookBtn = toolbar:CreateButton("Look Thru", "ส่องผ่าน Part ที่เลือก", "rbxasset://textures/ui/GuiImagePlaceholder.png")
local tourBtn = toolbar:CreateButton("Tour", "ไล่ดูทุก Part ที่เลือกตามลำดับชื่อ", "rbxasset://textures/ui/GuiImagePlaceholder.png")

local function camFolder(): Folder
	local f = workspace:FindFirstChild(FOLDER_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = workspace
	end
	return f
end

-- Cam_01, Cam_02, ... ทีมค่อยเปลี่ยนเป็น Cam_<ending>_<เลข> ทีหลัง
local function nextName(folder: Instance): string
	local n = 1
	while folder:FindFirstChild(("Cam_%02d"):format(n)) do
		n += 1
	end
	return ("Cam_%02d"):format(n)
end

local function selectedParts(): { BasePart }
	local out = {}
	for _, inst in Selection:Get() do
		if inst:IsA("BasePart") then
			table.insert(out, inst)
		end
	end
	return out
end

-- Part หันหน้าทางไหน = ด้าน Front (-Z) ซึ่งตรงกับ LookVector ของกล้องพอดี
-- ตั้ง part.CFrame = camera.CFrame แล้วตอนเล่นจริง camera.CFrame = part.CFrame จะได้ภาพเป๊ะเดิม
placeBtn.Click:Connect(function()
	local cam = workspace.CurrentCamera
	local rec = ChangeHistoryService:TryBeginRecording("Place cutscene cam")
	local folder = camFolder()
	local p = Instance.new("Part")
	p.Name = nextName(folder)
	p.Size = Vector3.new(1, 1, 1)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.CFrame = cam.CFrame
	p:SetAttribute("FOV", cam.FieldOfView)
	p.Parent = folder
	Selection:Set({ p })
	if rec then
		ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end
	print(("[CamTool] สร้าง %s แล้ว — เปลี่ยนชื่อเป็น Cam_<ending>_<เลข> ได้เลย"):format(p.Name))
end)

aimBtn.Click:Connect(function()
	local parts = selectedParts()
	if #parts == 0 then
		warn("[CamTool] เลือก Part กล้องก่อน")
		return
	end
	local cam = workspace.CurrentCamera
	local rec = ChangeHistoryService:TryBeginRecording("Aim cutscene cam")
	for _, p in parts do
		p.CFrame = cam.CFrame
		p:SetAttribute("FOV", cam.FieldOfView)
	end
	if rec then
		ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end
end)

lookBtn.Click:Connect(function()
	local p = selectedParts()[1]
	if not p then
		warn("[CamTool] เลือก Part กล้องก่อน")
		return
	end
	local cam = workspace.CurrentCamera
	cam.CFrame = p.CFrame
	cam.FieldOfView = p:GetAttribute("FOV") or DEFAULT_FOV
end)

local touring = false
tourBtn.Click:Connect(function()
	if touring then
		touring = false
		return
	end
	local parts = selectedParts()
	if #parts < 2 then
		warn("[CamTool] เลือกอย่างน้อย 2 Part (Tour ไล่ตามลำดับชื่อ)")
		return
	end
	table.sort(parts, function(a, b)
		return a.Name < b.Name
	end)

	touring = true
	task.spawn(function()
		local cam = workspace.CurrentCamera
		for i = 1, #parts - 1 do
			local from, to = parts[i], parts[i + 1]
			local fromFov = from:GetAttribute("FOV") or DEFAULT_FOV
			local toFov = to:GetAttribute("FOV") or DEFAULT_FOV
			cam.CFrame, cam.FieldOfView = from.CFrame, fromFov
			print(("[CamTool] %s -> %s"):format(from.Name, to.Name))
			local t = 0
			while t < TOUR_SECONDS and touring do
				t += RunService.Heartbeat:Wait()
				local a = math.clamp(t / TOUR_SECONDS, 0, 1)
				cam.CFrame = from.CFrame:Lerp(to.CFrame, a)
				cam.FieldOfView = fromFov + (toFov - fromFov) * a
			end
			if not touring then
				return
			end
		end
		touring = false
		print("[CamTool] Tour จบ")
	end)
end)
