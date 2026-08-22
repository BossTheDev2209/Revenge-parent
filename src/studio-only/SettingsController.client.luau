-- Settings panel logic — ยืมหน้าตา/สไลเดอร์จาก toolbox "Cafe Settings System" แต่ต่อกับระบบเกมเรา
-- คุม: เสียงรวม + เพลง/เอฟเฟกต์/บรรยากาศ (SoundGroup ใต้ Master) · เงา · คุณภาพกราฟิก · ป้ายลอย
-- ตัวจริงอยู่ Studio: StarterGui.SettingsGUI.SettingsController (LocalScript · Rojo ไม่ sync — copy กลับมาที่นี่)
-- ⚠️ thread นี้ sandboxed require ไม่ได้ — ยุ่งกับ SoundGroup/Attribute ตรงๆ (AudioService route เสียงมากลุ่มเดียวกัน)
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local TOGGLE = { On = Color3.fromRGB(110, 184, 0), Off = Color3.fromRGB(184, 51, 53) }

local screenGui = script.Parent
local settingsMain = screenGui:WaitForChild("SettingsMain")
local scrollingFrame = settingsMain:WaitForChild("SecondFrame"):WaitForChild("HolderFrame"):WaitForChild("ScrollingFrame")
local closeButton = settingsMain:WaitForChild("CloseButton")

local Action = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Action")
local function persist(key, value) Action:FireServer({ type = "SetSetting", key = key, value = value }) end

-- SoundGroup: Master > Music/SFX/Ambient — สร้างเผื่อยังไม่มี
local function grp(name)
	local m = SoundService:FindFirstChild("Master")
	if not m then m = Instance.new("SoundGroup"); m.Name = "Master"; m.Parent = SoundService end
	if name == "Master" then return m end
	local g = m:FindFirstChild(name)
	if not g then g = Instance.new("SoundGroup"); g.Name = name; g.Parent = m end
	return g
end
local function volGetter(name) return function() return grp(name).Volume end end
local function volSetter(name) return function(v) grp(name).Volume = v end end

local refreshers = {}

-- สไลเดอร์: คลิกบนแถบ = ตั้งค่า + เริ่มลาก · ปล่อยเมาส์ = หยุด+เซฟ (คุมเฉพาะแกน X)
local function initSlider(rowName, getV, setV, persistKey)
	local frame = scrollingFrame:FindFirstChild(rowName)
	if not frame then return end
	local bar = frame:FindFirstChild("VolumeBar")
	local knob = bar and bar:FindFirstChild("holdButton")
	local percentLabel = frame:FindFirstChild("%")
	if not (bar and knob and percentLabel) then return end

	local dragging = false
	local function render(v)
		percentLabel.Text = math.floor(v * 100 + 0.5) .. "%"
		local barW, knobW = bar.AbsoluteSize.X, knob.AbsoluteSize.X
		local x = math.clamp(v * barW - knobW * knob.AnchorPoint.X, 0, math.max(0, barW - knobW))
		knob.Position = UDim2.new(0, x, knob.Position.Y.Scale, knob.Position.Y.Offset)
	end
	local function setFromX(px)
		local barX, barW = bar.AbsolutePosition.X, bar.AbsoluteSize.X
		local v = barW > 0 and math.clamp((px - barX) / barW, 0, 1) or 0
		setV(v)
		render(v)
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if persistKey then persist(persistKey, getV()) end
		end
	end)

	table.insert(refreshers, function() render(getV()) end)
end

-- toggle (เงา / คุณภาพกราฟิก / ป้ายลอย)
local function initToggle(rowName, getOn, onClick, labelOn, labelOff)
	local row = scrollingFrame:FindFirstChild(rowName)
	local btn = row and row:FindFirstChild("Toggle")
	if not btn then return end
	local function refresh()
		local on = getOn()
		btn.Text = on and labelOn or labelOff
		btn.BackgroundColor3 = on and TOGGLE.On or TOGGLE.Off
	end
	btn.MouseButton1Click:Connect(function()
		onClick()
		TweenService:Create(btn, TWEEN_INFO, { BackgroundColor3 = getOn() and TOGGLE.On or TOGGLE.Off }):Play()
		btn.Text = getOn() and labelOn or labelOff
	end)
	table.insert(refreshers, refresh)
end

-- เสียง
initSlider("MusicVolume", volGetter("Master"), volSetter("Master"), "volume")
initSlider("BgmVolume", volGetter("Music"), volSetter("Music"), "bgmVol")
initSlider("SfxVolume", volGetter("SFX"), volSetter("SFX"), "sfxVol")
initSlider("AmbientVolume", volGetter("Ambient"), volSetter("Ambient"), "ambientVol")

-- ภาพ
initToggle("Overheads", function() return Lighting.GlobalShadows end, function()
	Lighting.GlobalShadows = not Lighting.GlobalShadows
	persist("shadow", Lighting.GlobalShadows)
end, "เปิด", "ปิด")

local LOW, HIGH = Enum.SavedQualitySetting.QualityLevel1, Enum.SavedQualitySetting.Automatic
initToggle("HidePlayers", function() return UserGameSettings.SavedQualityLevel ~= LOW end, function()
	UserGameSettings.SavedQualityLevel = (UserGameSettings.SavedQualityLevel ~= LOW) and LOW or HIGH
end, "สูง", "ต่ำ")

-- ป้ายลอย (ตัวคูณโซน + ชื่อ NPC) — key เดียวกับปุ่มในเมนูหลัก · thread นี้อ่าน state ไม่ได้ (sandboxed)
-- Main.client mirror ค่าลง workspace Attribute HideBillboards ให้ (แบบเดียวกับ toggle เงาอ่าน GlobalShadows)
-- getOn() = "ป้ายกำลังโชว์ไหม" (ตรงข้าม hideBillboards) ให้ตรงความหมายกับ toggle อื่น
initToggle("FloatingLabels", function() return workspace:GetAttribute("HideBillboards") ~= true end, function()
	local hidden = workspace:GetAttribute("HideBillboards") == true
	workspace:SetAttribute("HideBillboards", not hidden)
	persist("hideBillboards", not hidden)
end, "เปิด", "ปิด")

closeButton.MouseButton1Click:Connect(function() settingsMain.Visible = false end)

-- ⚠️ AutomaticCanvasSize bug ของ Roblox: ไม่ recompute ตอนเพิ่ม/ลบแถวขณะแผง Visible=false
-- → คำนวณ CanvasSize เองจาก UIListLayout.AbsoluteContentSize ทุกครั้งที่เปิดแผง
local listLayout = scrollingFrame:FindFirstChildOfClass("UIListLayout")
local function refreshAll()
	for _, f in refreshers do f() end
	if listLayout then
		scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
	end
end
settingsMain:GetPropertyChangedSignal("Visible"):Connect(function()
	if settingsMain.Visible then refreshAll() end
end)
refreshAll()
