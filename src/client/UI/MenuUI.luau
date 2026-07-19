-- MenuUI.luau — Main Menu ตาม PDF หน้า 1: Continue / Save file ×4 / Setting / Credit
-- placeholder หน้าตา — ทีมทำสวยทีหลังได้ logic อยู่ครบแล้ว
local MenuUI = {}

local CREDIT_TEXT = "ทีมหอยทากเทอร์โบ28\nรณกร ขันสำรอง | วรกร วิรามวิทวัส | ฉันทัช อัศวชนานนท์\nMUICT-AST Tech Competition 2569"

local function button(parent, text, y, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 320, 0, 48)
	b.Position = UDim2.new(0.5, -160, 0, y)
	b.BackgroundColor3 = color or Color3.fromRGB(50, 50, 70)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.Text = text
	b.Parent = parent
	return b
end

-- deps = { fireAction = fn } — เปิดค้างจนกดเริ่มเล่น (freeze เวลาไว้)
function MenuUI.open(playerGui, deps)
	deps.fireAction({ type = "FreezeTime", on = true })
	deps.fireAction({ type = "RequestSlots" })

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_MainMenu"
	gui.ResetOnSpawn = false
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	bg.Parent = gui
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 80)
	title.Position = UDim2.new(0, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Text = "Getting 1M Follower\nto Prove Parent Wrong"
	title.Parent = bg
	gui.Parent = playerGui

	local slotButtons = {}
	local latestSlot = nil

	local function startGame()
		deps.fireAction({ type = "FreezeTime", on = false })
		gui:Destroy()
		MenuUI.onClosed = nil
	end

	local continueBtn = button(bg, "เล่นต่อ (ยังไม่มี save)", 130, Color3.fromRGB(80, 160, 255))
	continueBtn.Activated:Connect(function()
		if latestSlot then
			deps.fireAction({ type = "LoadSlot", slot = latestSlot })
		end
		startGame()
	end)

	for i = 1, 4 do
		local b = button(bg, ("ช่อง %d — ว่าง (เริ่มใหม่)"):format(i), 130 + i * 56)
		b.Activated:Connect(function()
			if slotButtons[i].hasSave then
				deps.fireAction({ type = "LoadSlot", slot = i })
			else
				deps.fireAction({ type = "NewGame", slot = i })
			end
			startGame()
		end)
		slotButtons[i] = { btn = b, hasSave = false }
	end

	local creditBtn = button(bg, "เครดิต", 130 + 5 * 56)
	local creditLabel = Instance.new("TextLabel")
	creditLabel.Size = UDim2.new(0, 500, 0, 90)
	creditLabel.Position = UDim2.new(0.5, -250, 1, -110)
	creditLabel.BackgroundTransparency = 0.4
	creditLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	creditLabel.TextColor3 = Color3.new(1, 1, 1)
	creditLabel.TextScaled = true
	creditLabel.Text = CREDIT_TEXT
	creditLabel.Visible = false
	creditLabel.Parent = bg
	creditBtn.Activated:Connect(function()
		creditLabel.Visible = not creditLabel.Visible
	end)
	-- Setting (graphic/language/audio) — ยังไม่ทำ แสดงเฉยๆ ให้รู้ว่ามีตาม design
	local settingBtn = button(bg, "ตั้งค่า (เร็วๆนี้)", 130 + 6 * 56, Color3.fromRGB(70, 70, 80))
	settingBtn.AutoButtonColor = false

	-- state มาใหม่ (หลัง RequestSlots) → เติม summary ลงปุ่ม
	function MenuUI.updateSlots(state)
		if not gui.Parent then return end
		local slots = state.slotList
		if not slots then return end
		latestSlot = nil
		local bestAt = -1
		for i = 1, 4 do
			local sum = slots[i]
			slotButtons[i].hasSave = sum ~= nil
			slotButtons[i].btn.Text = sum
					and ("ช่อง %d — วัน %d | %d follower | เฟส %d"):format(i, sum.day, sum.follower, sum.phase)
				or ("ช่อง %d — ว่าง (เริ่มใหม่)"):format(i)
			if sum and sum.savedAt > bestAt then
				bestAt = sum.savedAt
				latestSlot = i
			end
		end
		continueBtn.Text = latestSlot and ("เล่นต่อ (ช่อง %d)"):format(latestSlot) or "เล่นต่อ (ยังไม่มี save)"
	end
end

return MenuUI
