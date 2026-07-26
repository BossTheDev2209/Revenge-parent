-- EditQTE.luau — มินิเกมตัดคลิป (docs/07 §3.4 + PDF หน้า 7): 20 ปุ่ม 1.5 วิ/ปุ่ม เต็ม 200
-- pure: scoreFor / pickKeys (lune เทส) | UI glue: start() overlay สร้างเอง (รอทีมทำ Gui_Computer จริง)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../../shared/Formulas")

local QTE_KEYS = { "Q", "W", "E", "A", "S", "D", "Z", "X", "C" }
local QTE_COUNT = 20
local QTE_WINDOW = 1.5

local EditQTE = {}
EditQTE.running = false

-- คะแนนต่อปุ่ม: กดตรงกลาง window เป๊ะ = 10, ขอบ = 0 (ปัดลง)
function EditQTE.scoreFor(t: number, window: number): number
	local half = window / 2
	return math.max(0, math.floor(10 * (1 - math.abs(t - half) / half)))
end

function EditQTE.pickKeys(count: number, keys, rng)
	rng = rng or math.random
	local out = {}
	for i = 1, count do
		out[i] = keys[math.floor(rng() * #keys) + 1]
	end
	return out
end

-- ===== UI glue (Studio เท่านั้น) =====
-- fireAction = function(actionTable) ยิงเข้า Remotes.Action (Main.client ส่งมา)
function EditQTE.start(playerGui, fireAction)
	if EditQTE.running then return end
	EditQTE.running = true

	local UIS = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_EditQTE"
	gui.ResetOnSpawn = false
	local dim = Instance.new("Frame")
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.Parent = gui
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Size = UDim2.new(0, 200, 0, 200)
	keyLabel.Position = UDim2.new(0.5, -100, 0.4, -100)
	keyLabel.TextScaled = true
	keyLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	keyLabel.TextColor3 = Color3.new(1, 1, 1)
	keyLabel.Parent = dim
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0.4, 0, 0, 12)
	bar.Position = UDim2.new(0.3, 0, 0.62, 0)
	bar.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
	bar.Parent = dim
	local info = Instance.new("TextLabel")
	info.Size = UDim2.new(0.6, 0, 0, 30)
	info.Position = UDim2.new(0.2, 0, 0.68, 0)
	info.BackgroundTransparency = 1
	info.TextColor3 = Color3.new(1, 1, 1)
	info.TextScaled = true
	info.Text = "กดปุ่มตามจังหวะ! ตรงกลางแถบ = คะแนนเต็ม"
	info.Parent = dim
	gui.Parent = playerGui

	task.spawn(function()
		local seq = EditQTE.pickKeys(QTE_COUNT, QTE_KEYS)
		local total = 0
		for i, key in seq do
			keyLabel.Text = key
			info.Text = ("ปุ่มที่ %d/%d | คะแนน %d"):format(i, QTE_COUNT, total)
			local t0 = os.clock()
			local pressed = nil
			local conn = UIS.InputBegan:Connect(function(input, gp)
				if gp or pressed then return end
				if input.UserInputType == Enum.UserInputType.Keyboard then
					pressed = { key = input.KeyCode.Name, t = os.clock() - t0 }
				end
			end)
			while os.clock() - t0 < QTE_WINDOW and not pressed do
				bar.Size = UDim2.new(0.4 * (1 - (os.clock() - t0) / QTE_WINDOW), 0, 0, 12)
				RunService.Heartbeat:Wait()
			end
			conn:Disconnect()
			if pressed and pressed.key == key then
				local got = EditQTE.scoreFor(pressed.t, QTE_WINDOW)
				total += got
				keyLabel.TextColor3 = got >= 7 and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 220, 80)
			else
				keyLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
			end
			task.wait(0.15)
			keyLabel.TextColor3 = Color3.new(1, 1, 1)
		end

		fireAction({ type = "FinishEdit", score = total })

		-- จอสรุป (PDF จอ 3) — ไม่มีปุ่มอัปโหลดที่นี่ ต้องไปอัปที่แอป Upload
		keyLabel.Text = Formulas.vidqTier(total)
		bar.Visible = false
		info.Text = ("เสร็จ! คะแนน %d/200 = tier %s — ไปอัปที่แอป Upload"):format(total, Formulas.vidqTier(total))
		local close = Instance.new("TextButton")
		close.Size = UDim2.new(0, 200, 0, 44)
		close.Position = UDim2.new(0.5, -100, 0.78, 0)
		close.Text = "Done"
		close.TextScaled = true
		close.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
		close.Parent = dim
		close.Activated:Connect(function()
			gui:Destroy()
			EditQTE.running = false
		end)
	end)
end

return EditQTE
