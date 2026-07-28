-- ShopKiosk.luau — ร้านค้าในแมพ: เดินไปกด `Interact_Shop` แล้วเปิดหน้าซื้อของ
-- คนละตัวกับ UI/Apps/Shop.luau (แอปบนจอคอม PDF หน้า 9) — อันนั้นเข้าผ่าน PC อันนี้เดินไปที่ร้าน
--
-- หน้าตา: เลือกหมวดทางซ้าย → เห็นบันได 15 ระดับของหมวดนั้นทางขวา (ซื้อไล่ทีละขั้น ข้ามไม่ได้)
-- ของที่ขายมาจาก `Config.ShopCatalog` · ราคามาจาก `Config.UpgradeCosts` · สเปคคำนวณจาก ladder
-- → เพิ่ม/แก้ของ = แก้ Config อย่างเดียว ไม่ต้องแตะไฟล์นี้
--
-- ซื้อจริงเกิดที่ server (`MoneyService.buyUpgrade` ผ่าน action BuyUpgrade) — ไฟล์นี้แค่โชว์+ยิง
-- pure ส่วน specFor/offerFor/tiersFor (เทสด้วย lune) — ที่เหลือเป็น Roblox UI
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../shared/Config")
-- ยืมแค่ HUD.comma (pure) — เลขเงินต้องคั่นหลักแบบเดียวกับ HUD ทั้งเกม
local HUD = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.UI.HUD)
	else require("../HUD")

local ShopKiosk = {}

-- ===== pure =====

-- จำนวนระดับทั้งหมดของหมวด = ของเริ่มต้น 1 + ที่ซื้อได้อีก #names
function ShopKiosk.tierCount(entry: { names: { string } }): number
	return #entry.names + 1
end

-- ชื่อของที่ระดับนี้ (ระดับ 1 = ของติดตัวตอนเริ่มเกม ไม่ได้ซื้อ)
function ShopKiosk.nameAt(entry, level: number): string?
	if level == 1 then return entry.startName end
	return entry.names[level - 1]
end

-- สเปคของระดับนี้ — อ่านจาก ladder ที่ล็อกไว้แล้ว ไม่ก๊อปตัวเลขมาเขียนซ้ำใน catalog
-- nil = หมวดนี้ยังไม่มี ladder (pc — ผลยัง unwired) → การ์ดโชว์แค่ชื่อของ
function ShopKiosk.specFor(key: string, level: number): string?
	if key == "storage" then
		local gb = Config.StorageLadderGB[level]
		if not gb then return nil end
		if gb >= 1_048_576 then return ("%g PB"):format(gb / 1_048_576) end
		return gb >= 1024 and ("%g TB"):format(gb / 1024) or ("%d GB"):format(gb)
	elseif key == "camera" then
		local res = Config.ResolutionLadder[level]
		if not res then return nil end
		local perClick = Config.Record.footagePerClickGB[level]
		return perClick and ("%s · %s GB/คลิก"):format(res, HUD.comma(perClick)) or res
	end
	return nil
end

-- ของชิ้นถัดไปของหมวดนี้ตาม state ปัจจุบัน — nil = ซื้อครบทุกระดับแล้ว
function ShopKiosk.offerFor(entry, state)
	local level = state.upgrades and state.upgrades[entry.key] or 1
	local name = entry.names[level]
	local costs = Config.UpgradeCosts[entry.key]
	local price = costs and costs[level]
	if not name or not price then return nil end
	return {
		name = name,
		price = price,
		level = level + 1, -- ระดับที่จะได้หลังซื้อ
		spec = ShopKiosk.specFor(entry.key, level + 1),
	}
end

-- บันไดทั้งหมดของหมวด พร้อมสถานะแต่ละขั้น — UI วาดตามนี้ตรงๆ
--   owned   = ผ่านมาแล้ว | current = ใช้อยู่ตอนนี้ | next = ซื้อได้ขั้นถัดไป | locked = ต้องไล่ซื้อก่อน
function ShopKiosk.tiersFor(entry, state)
	local level = state.upgrades and state.upgrades[entry.key] or 1
	local costs = Config.UpgradeCosts[entry.key] or {}
	local out = {}
	for tier = 1, ShopKiosk.tierCount(entry) do
		local status = if tier < level then "owned"
			elseif tier == level then "current"
			elseif tier == level + 1 then "next"
			else "locked"
		table.insert(out, {
			tier = tier,
			name = ShopKiosk.nameAt(entry, tier),
			spec = ShopKiosk.specFor(entry.key, tier),
			price = costs[tier - 1], -- ระดับ 1 ไม่มีราคา (ของเริ่มต้น)
			status = status,
		})
	end
	return out
end

-- ===== Roblox UI =====

local COLORS = {
	bg = Color3.fromRGB(22, 22, 32),
	side = Color3.fromRGB(30, 30, 42),
	tab = Color3.fromRGB(45, 45, 62),
	tabOn = Color3.fromRGB(70, 130, 200),
	row = Color3.fromRGB(38, 38, 52),
	rowNext = Color3.fromRGB(44, 58, 46),
	rowOwned = Color3.fromRGB(30, 30, 40),
	buy = Color3.fromRGB(70, 175, 95),
	broke = Color3.fromRGB(120, 70, 70),
	text = Color3.fromRGB(240, 240, 245),
	dim = Color3.fromRGB(150, 150, 168),
	faint = Color3.fromRGB(105, 105, 122),
}

local function mk(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end

ShopKiosk.running = false

function ShopKiosk.open(playerGui, deps)
	if ShopKiosk.running then return end
	ShopKiosk.running = true

	local gui = mk("ScreenGui", nil, { Name = "Gui_ShopKiosk", ResetOnSpawn = false, DisplayOrder = 5 })

	local panel = mk("Frame", gui, {
		Size = UDim2.new(0, 880, 0, 520),
		Position = UDim2.new(0.5, -440, 0.5, -260),
		BackgroundColor3 = COLORS.bg,
	})
	mk("UICorner", panel, {})

	mk("TextLabel", panel, {
		Size = UDim2.new(0, 320, 0, 38), Position = UDim2.new(0, 18, 0, 12),
		BackgroundTransparency = 1, Text = "🛒 ร้านอุปกรณ์", TextColor3 = COLORS.text,
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
	})
	local moneyLabel = mk("TextLabel", panel, {
		Size = UDim2.new(0, 260, 0, 30), Position = UDim2.new(1, -310, 0, 16),
		BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.dim,
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right,
	})
	local close = mk("TextButton", panel, {
		Size = UDim2.new(0, 34, 0, 34), Position = UDim2.new(1, -44, 0, 12),
		BackgroundColor3 = Color3.fromRGB(160, 60, 60), TextColor3 = COLORS.text,
		TextScaled = true, Text = "✕",
	})
	mk("UICorner", close, {})

	-- ===== ซ้าย: เลือกหมวด =====
	local side = mk("Frame", panel, {
		Size = UDim2.new(0, 210, 1, -74), Position = UDim2.new(0, 18, 0, 60),
		BackgroundColor3 = COLORS.side,
	})
	mk("UICorner", side, {})
	mk("UIListLayout", side, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	mk("UIPadding", side, { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })

	-- ===== ขวา: บันไดของหมวดที่เลือก =====
	local listHead = mk("TextLabel", panel, {
		Size = UDim2.new(1, -262, 0, 26), Position = UDim2.new(0, 244, 0, 62),
		BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.dim,
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
	})
	local list = mk("ScrollingFrame", panel, {
		Size = UDim2.new(1, -262, 1, -108), Position = UDim2.new(0, 244, 0, 94),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	mk("UIListLayout", list, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })

	local selected = Config.ShopCatalog[1].key
	local tabs, rows = {}, {}

	for i, entry in Config.ShopCatalog do
		local tab = mk("TextButton", side, {
			Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = COLORS.tab,
			TextColor3 = COLORS.text, Text = "", LayoutOrder = i, AutoButtonColor = true,
		})
		mk("UICorner", tab, {})
		mk("TextLabel", tab, {
			Size = UDim2.new(1, -14, 0, 26), Position = UDim2.new(0, 10, 0, 6),
			BackgroundTransparency = 1, Text = entry.label, TextColor3 = COLORS.text,
			TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
		})
		local sub = mk("TextLabel", tab, {
			Size = UDim2.new(1, -14, 0, 20), Position = UDim2.new(0, 10, 0, 34),
			BackgroundTransparency = 1, Text = entry.note, TextColor3 = COLORS.dim,
			TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		})
		tab.Activated:Connect(function()
			selected = entry.key
			if ShopKiosk.refresh then ShopKiosk.refresh(deps.getState()) end
		end)
		tabs[i] = { entry = entry, btn = tab, sub = sub }
	end

	-- แถว 1 ขั้นในบันได — สร้างครั้งเดียวเท่าจำนวนระดับที่มากสุด แล้วซ่อน/โชว์ตามหมวด
	local maxTiers = 0
	for _, e in Config.ShopCatalog do
		maxTiers = math.max(maxTiers, ShopKiosk.tierCount(e))
	end
	for i = 1, maxTiers do
		local row = mk("Frame", list, {
			Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = COLORS.row, LayoutOrder = i,
		})
		mk("UICorner", row, {})
		local badge = mk("TextLabel", row, {
			Size = UDim2.new(0, 44, 1, 0), Position = UDim2.new(0, 4, 0, 0),
			BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.faint, TextScaled = true,
		})
		local name = mk("TextLabel", row, {
			Size = UDim2.new(1, -230, 0, 24), Position = UDim2.new(0, 52, 0, 6),
			BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.text,
			TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local spec = mk("TextLabel", row, {
			Size = UDim2.new(1, -230, 0, 20), Position = UDim2.new(0, 52, 0, 29),
			BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.dim,
			TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		})
		local action = mk("TextButton", row, {
			Size = UDim2.new(0, 160, 0, 38), Position = UDim2.new(1, -168, 0, 8),
			BackgroundColor3 = COLORS.buy, TextColor3 = COLORS.text, TextSize = 16, Text = "",
		})
		mk("UICorner", action, {})
		action.Activated:Connect(function()
			-- ซื้อได้เฉพาะขั้นถัดไป (ปุ่มขั้นอื่นถูกปิด) — server ตัดสินเงิน/ระดับอีกชั้น
			deps.fireAction({ type = "BuyUpgrade", item = selected })
		end)
		rows[i] = { row = row, badge = badge, name = name, spec = spec, action = action }
	end

	function ShopKiosk.refresh(state)
		if not state then return end
		moneyLabel.Text = ("💰 ฿%s"):format(HUD.comma(state.money))

		local entry
		for _, t in tabs do
			local on = t.entry.key == selected
			t.btn.BackgroundColor3 = on and COLORS.tabOn or COLORS.tab
			t.sub.TextColor3 = on and COLORS.text or COLORS.dim
			if on then entry = t.entry end
		end
		if not entry then return end

		local tiers = ShopKiosk.tiersFor(entry, state)
		local level = state.upgrades and state.upgrades[entry.key] or 1
		listHead.Text = ("%s — ระดับ %d / %d"):format(entry.label, level, #tiers)

		for i, r in rows do
			local t = tiers[i]
			if not t then
				r.row.Visible = false
			else
				r.row.Visible = true
				r.badge.Text = ("L%d"):format(t.tier)
				r.name.Text = t.name or "?"
				r.spec.Text = t.spec or ""

				if t.status == "owned" then
					r.row.BackgroundColor3 = COLORS.rowOwned
					r.name.TextColor3, r.badge.TextColor3 = COLORS.faint, COLORS.faint
					r.action.Text, r.action.BackgroundColor3, r.action.Active = "✓ มีแล้ว", COLORS.rowOwned, false
				elseif t.status == "current" then
					r.row.BackgroundColor3 = COLORS.row
					r.name.TextColor3, r.badge.TextColor3 = COLORS.text, COLORS.text
					r.action.Text, r.action.BackgroundColor3, r.action.Active = "⭐ ใช้อยู่", COLORS.tabOn, false
				elseif t.status == "next" then
					local can = state.money >= t.price
					r.row.BackgroundColor3 = COLORS.rowNext
					r.name.TextColor3, r.badge.TextColor3 = COLORS.text, COLORS.text
					r.action.Text = ("ซื้อ ฿%s"):format(HUD.comma(t.price))
					r.action.BackgroundColor3 = can and COLORS.buy or COLORS.broke
					r.action.Active = can
				else
					r.row.BackgroundColor3 = COLORS.rowOwned
					r.name.TextColor3, r.badge.TextColor3 = COLORS.faint, COLORS.faint
					r.action.Text = ("🔒 ฿%s"):format(HUD.comma(t.price))
					r.action.BackgroundColor3, r.action.Active = COLORS.rowOwned, false
				end
			end
		end
	end

	local function shut()
		ShopKiosk.running = false
		ShopKiosk.refresh = nil
		gui:Destroy()
	end
	close.Activated:Connect(shut)
	ShopKiosk.close = shut

	ShopKiosk.refresh(deps.getState())
	gui.Parent = playerGui
end

return ShopKiosk
