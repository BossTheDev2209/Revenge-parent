-- ShopKiosk.luau — ร้านค้าในแมพ: เดินไปกด `Interact_Shop` แล้วเปิดหน้าซื้อของ 3 หมวด
-- คนละตัวกับ UI/Apps/Shop.luau (แอปบนจอคอม PDF หน้า 9) — อันนั้นเข้าผ่าน PC อันนี้เดินไปที่ร้าน
--
-- ของที่ขายมาจาก `Config.ShopCatalog` · ราคามาจาก `Config.UpgradeCosts` · สเปคคำนวณจาก ladder
-- → เพิ่มของ = แก้ Config อย่างเดียว ไม่ต้องแตะไฟล์นี้
--
-- ซื้อจริงเกิดที่ server (`MoneyService.buyUpgrade` ผ่าน action BuyUpgrade) — ไฟล์นี้แค่โชว์+ยิง
-- pure ส่วน specFor/offerFor (เทสด้วย lune) — ที่เหลือเป็น Roblox UI
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

-- สเปคที่จะได้ถ้าซื้อขั้นนี้ — อ่านจาก ladder ที่ล็อกไว้แล้ว ไม่ก๊อปตัวเลขมาเขียนซ้ำ
-- nil = หมวดนี้ยังไม่มี ladder (pc) → การ์ดโชว์แค่ชื่อของ
function ShopKiosk.specFor(key: string, level: number): string?
	if key == "storage" then
		local gb = Config.StorageLadderGB[level]
		if not gb then return nil end
		return gb >= 1024 and ("%g TB"):format(gb / 1024) or ("%d GB"):format(gb)
	elseif key == "camera" then
		local res = Config.ResolutionLadder[level]
		if not res then return nil end
		local perClick = Config.Record.footagePerClickGB[level]
		return perClick and ("%s · %d GB/คลิก"):format(res, perClick) or res
	end
	return nil
end

-- ของชิ้นถัดไปของหมวดนี้ตาม state ปัจจุบัน — nil = ซื้อครบแล้ว
-- จำนวนที่ขายจำกัดด้วย #names (เวอร์ชันเทส 2 ชิ้น) ต่อให้ UpgradeCosts มียาวกว่า
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

-- ===== Roblox UI =====

local COLORS = {
	bg = Color3.fromRGB(24, 24, 34),
	card = Color3.fromRGB(38, 38, 52),
	buy = Color3.fromRGB(70, 175, 95),
	broke = Color3.fromRGB(95, 95, 110),
	sold = Color3.fromRGB(60, 60, 75),
	text = Color3.fromRGB(240, 240, 245),
	dim = Color3.fromRGB(165, 165, 180),
}

local function label(parent, text, size, pos, color, scaled)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Text = text
	l.TextColor3 = color or COLORS.text
	l.TextScaled = scaled ~= false
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

ShopKiosk.running = false

function ShopKiosk.open(playerGui, deps)
	if ShopKiosk.running then return end
	ShopKiosk.running = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gui_ShopKiosk"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 760, 0, 420)
	panel.Position = UDim2.new(0.5, -380, 0.5, -210)
	panel.BackgroundColor3 = COLORS.bg
	panel.Parent = gui
	Instance.new("UICorner").Parent = panel

	label(panel, "🛒 ร้านอุปกรณ์", UDim2.new(0, 300, 0, 40), UDim2.new(0, 18, 0, 10))
	local moneyLabel = label(panel, "", UDim2.new(0, 220, 0, 32), UDim2.new(1, -240, 0, 14), COLORS.dim)
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Right

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 34, 0, 34)
	close.Position = UDim2.new(1, -42, 0, 8)
	close.BackgroundColor3 = Color3.fromRGB(160, 60, 60)
	close.TextColor3 = COLORS.text
	close.TextScaled = true
	close.Text = "✕"
	close.Parent = panel
	Instance.new("UICorner").Parent = close

	-- 3 คอลัมน์ = 3 หมวดใน Config.ShopCatalog (เพิ่มหมวด = คอลัมน์แคบลงเอง)
	local cols = #Config.ShopCatalog
	local gap, margin = 12, 18
	local colW = (760 - margin * 2 - gap * (cols - 1)) / cols

	local cards = {}
	for i, entry in Config.ShopCatalog do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(0, colW, 0, 300)
		card.Position = UDim2.new(0, margin + (i - 1) * (colW + gap), 0, 62)
		card.BackgroundColor3 = COLORS.card
		card.Parent = panel
		Instance.new("UICorner").Parent = card

		label(card, entry.label, UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 0, 8))
		label(card, entry.note, UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 38), COLORS.dim)

		local owned = label(card, "", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 66), COLORS.dim)
		local name = label(card, "", UDim2.new(1, -16, 0, 34), UDim2.new(0, 8, 0, 110))
		name.TextScaled = false
		name.TextSize = 20
		name.TextWrapped = true
		local spec = label(card, "", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 150), COLORS.dim)
		spec.TextScaled = false
		spec.TextSize = 16

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -16, 0, 46)
		btn.Position = UDim2.new(0, 8, 1, -54)
		btn.BackgroundColor3 = COLORS.buy
		btn.TextColor3 = COLORS.text
		btn.TextScaled = true
		btn.Parent = card
		Instance.new("UICorner").Parent = btn
		btn.Activated:Connect(function()
			-- server ตัดสินอีกชั้น (เงินไม่พอ/ระดับสูงสุด = ไม่เกิดอะไร) — ที่นี่แค่ยิง
			deps.fireAction({ type = "BuyUpgrade", item = entry.key })
		end)

		cards[i] = { entry = entry, owned = owned, name = name, spec = spec, btn = btn }
	end

	function ShopKiosk.refresh(state)
		if not state then return end
		moneyLabel.Text = ("💰 ฿%s"):format(HUD.comma(state.money))
		for _, c in cards do
			local level = state.upgrades and state.upgrades[c.entry.key] or 1
			c.owned.Text = ("ตอนนี้: ระดับ %d%s"):format(level,
				ShopKiosk.specFor(c.entry.key, level) and (" · " .. ShopKiosk.specFor(c.entry.key, level)) or "")
			local offer = ShopKiosk.offerFor(c.entry, state)
			if offer then
				c.name.Text = offer.name
				c.spec.Text = offer.spec or ""
				c.btn.Text = ("ซื้อ ฿%d"):format(offer.price)
				c.btn.BackgroundColor3 = state.money >= offer.price and COLORS.buy or COLORS.broke
			else
				c.name.Text = "ซื้อครบแล้ว ✨"
				c.spec.Text = ""
				c.btn.Text = "—"
				c.btn.BackgroundColor3 = COLORS.sold
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
