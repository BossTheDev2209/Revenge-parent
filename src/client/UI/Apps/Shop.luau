-- Shop.luau — อัปเกรดกล้อง/storage 4 ครั้ง (design doc §4) → action BuyUpgrade
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../shared/Config")

local Shop = {}

local ITEMS = {
	{ key = "camera", label = "📷 กล้อง", desc = Config.ResolutionLadder },
	{ key = "storage", label = "💾 Storage", desc = nil },
}

function Shop.create(frame, deps)
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Text = "🛒 Shop"
	title.Parent = frame

	local rows = {}
	for i, item in ITEMS do
		local row = Instance.new("Frame")
		row.Position = UDim2.new(0, 8, 0, 40 + (i - 1) * 90)
		row.Size = UDim2.new(1, -16, 0, 82)
		row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		row.Parent = frame
		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(1, -12, 0, 40)
		info.Position = UDim2.new(0, 6, 0, 4)
		info.BackgroundTransparency = 1
		info.TextScaled = true
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.Parent = row
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -12, 0, 32)
		btn.Position = UDim2.new(0, 6, 0, 46)
		btn.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.TextScaled = true
		btn.Parent = row
		btn.Activated:Connect(function()
			deps.fireAction({ type = "BuyUpgrade", item = item.key })
		end)
		rows[item.key] = { info = info, btn = btn, item = item }
	end

	local app = {}
	function app.refresh(state)
		for key, r in rows do
			local level = state.upgrades[key]
			local cost = Config.UpgradeCosts[key][level]
			local desc = r.item.desc and (" (" .. (r.item.desc[level] or "?") .. ")") or ""
			r.info.Text = ("%s ระดับ %d%s"):format(r.item.label, level, desc)
			if cost then
				local nextDesc = r.item.desc and (" → " .. (r.item.desc[level + 1] or "")) or ""
				r.btn.Text = ("อัปเกรด ฿%d%s"):format(cost, nextDesc)
				r.btn.BackgroundColor3 = state.money >= cost and Color3.fromRGB(80, 180, 100)
					or Color3.fromRGB(150, 150, 150)
			else
				r.btn.Text = "สูงสุดแล้ว ✨"
				r.btn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
			end
		end
	end
	return app
end

return Shop
