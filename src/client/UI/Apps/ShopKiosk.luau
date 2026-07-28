-- ShopKiosk.luau — ร้านค้าในแมพ: เดินไปกด `Interact_Shop` แล้วเปิดหน้าซื้อของ
-- คนละตัวกับ UI/Apps/Shop.luau (แอปบนจอคอม) — อันนั้นเข้าผ่าน PC อันนี้เดินไปที่ร้าน
--
-- ★ หน้าตาตามภาพร่าง PDF หน้า 9 ล่าง (docs/09 §10 · docs/12):
--   หมวดละ 1 แถว · แถวละ 4 การ์ด · ลูกศร ◀ ▶ เลื่อนดูระดับถัดไป
--   การ์ด = รูป + ชื่อ + quality(สเปค) + price/ปุ่ม Buy
--   สถานะการ์ด: ซื้อแล้ว ✓ / ใช้อยู่ ⭐ / ซื้อได้ Buy / ไกลกว่านั้น 🔒
--
-- ของที่ขายมาจาก `Config.ShopCatalog` · ราคามาจาก `Config.UpgradeCosts` · สเปคคำนวณจาก ladder
-- → เพิ่ม/แก้ของ = แก้ Config อย่างเดียว ไม่ต้องแตะไฟล์นี้
--
-- ซื้อจริงเกิดที่ server (`MoneyService.buyUpgrade` ผ่าน action BuyUpgrade) — ไฟล์นี้แค่โชว์+ยิง
-- pure ส่วนบนสุด (เทสด้วย lune) — ที่เหลือเป็น Roblox UI
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../shared/Config")
local UIAssets = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.UIAssets)
	else require("../../../shared/UIAssets")
-- ยืมแค่ HUD.comma (pure) — เลขเงินต้องคั่นหลักแบบเดียวกับ HUD ทั้งเกม
local HUD = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.UI.HUD)
	else require("../HUD")

local ShopKiosk = {}

ShopKiosk.CARDS_PER_ROW = 4 -- ★ PDF หน้า 9: แถวละ 4 ใบ แล้วกดลูกศรเลื่อน

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

-- คีย์รูปใน UIAssets — วาดไว้แค่ระดับ 1-6 ที่เหลือคืน nil (การ์ดใช้ emoji ของหมวดแทน)
function ShopKiosk.imageFor(key: string, tier: number): string?
	local id = UIAssets["shop_" .. key .. "_" .. tier]
	return (id ~= nil and id ~= "") and id or nil
end

-- สเปค ("quality" ในภาพร่าง) ของระดับนี้ — อ่านจาก ladder ที่ล็อกไว้ ไม่ก๊อปเลขมาเขียนซ้ำ
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
--   owned = ผ่านมาแล้ว | current = ใช้อยู่ | next = ซื้อได้ขั้นถัดไป | locked = ต้องไล่ซื้อก่อน
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
			image = ShopKiosk.imageFor(entry.key, tier),
			price = costs[tier - 1], -- ระดับ 1 ไม่มีราคา (ของเริ่มต้น)
			status = status,
		})
	end
	return out
end

-- ===== เลื่อนหน้าในแถว (ลูกศร ◀ ▶ ใน PDF) =====

function ShopKiosk.pageCount(total: number, perPage: number): number
	return math.max(1, math.ceil(total / perPage))
end

-- หน้าที่มีระดับนี้อยู่ — ใช้เปิดร้านมาแล้วเห็นของที่ซื้อได้เลย ไม่ต้องกดลูกศรหา
function ShopKiosk.pageOf(tier: number, perPage: number): number
	return math.max(1, math.ceil(tier / perPage))
end

function ShopKiosk.clampPage(page: number, total: number, perPage: number): number
	return math.clamp(page, 1, ShopKiosk.pageCount(total, perPage))
end

-- ===== Roblox UI =====

local COLORS = {
	bg = Color3.fromRGB(24, 24, 34),
	rowBg = Color3.fromRGB(31, 31, 43),
	card = Color3.fromRGB(44, 44, 60),
	cardNext = Color3.fromRGB(46, 62, 48),
	cardDim = Color3.fromRGB(33, 33, 44),
	buy = Color3.fromRGB(70, 175, 95),
	broke = Color3.fromRGB(122, 68, 68),
	current = Color3.fromRGB(70, 130, 200),
	arrow = Color3.fromRGB(56, 56, 76),
	text = Color3.fromRGB(240, 240, 245),
	dim = Color3.fromRGB(152, 152, 170),
	faint = Color3.fromRGB(104, 104, 122),
}

local CARD_W, CARD_H, GAP = 156, 176, 10

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

	local perPage = ShopKiosk.CARDS_PER_ROW
	local rowInner = CARD_W * perPage + GAP * (perPage - 1)
	local panelW = 40 + 34 + 8 + rowInner + 8 + 34 -- margin + ลูกศรซ้าย + การ์ด + ลูกศรขวา
	local rowH = 24 + CARD_H
	local panelH = 56 + (#Config.ShopCatalog * (rowH + 12)) + 12

	local gui = mk("ScreenGui", nil, { Name = "Gui_ShopKiosk", ResetOnSpawn = false, DisplayOrder = 5 })
	local panel = mk("Frame", gui, {
		Size = UDim2.new(0, panelW, 0, panelH),
		Position = UDim2.new(0.5, -panelW / 2, 0.5, -panelH / 2),
		BackgroundColor3 = COLORS.bg,
	})
	mk("UICorner", panel, {})

	mk("TextLabel", panel, {
		Size = UDim2.new(0, 300, 0, 34), Position = UDim2.new(0, 20, 0, 12),
		BackgroundTransparency = 1, Text = "🛒 Shop", TextColor3 = COLORS.text,
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
	})
	local moneyLabel = mk("TextLabel", panel, {
		Size = UDim2.new(0, 280, 0, 28), Position = UDim2.new(1, -330, 0, 15),
		BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.dim,
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right,
	})
	local close = mk("TextButton", panel, {
		Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(1, -44, 0, 13),
		BackgroundColor3 = Color3.fromRGB(160, 60, 60), TextColor3 = COLORS.text,
		TextScaled = true, Text = "✕",
	})
	mk("UICorner", close, {})

	local page = {} -- [key] = หน้าที่กำลังดูของแถวนั้น
	local rows = {}

	for i, entry in Config.ShopCatalog do
		page[entry.key] = 1

		local row = mk("Frame", panel, {
			Size = UDim2.new(1, -40, 0, rowH),
			Position = UDim2.new(0, 20, 0, 56 + (i - 1) * (rowH + 12)),
			BackgroundColor3 = COLORS.rowBg,
		})
		mk("UICorner", row, {})

		mk("TextLabel", row, {
			Size = UDim2.new(0, 320, 0, 22), Position = UDim2.new(0, 10, 0, 2),
			BackgroundTransparency = 1, Text = entry.label, TextColor3 = COLORS.text,
			TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
		})
		local rowInfo = mk("TextLabel", row, {
			Size = UDim2.new(0, 300, 0, 20), Position = UDim2.new(1, -310, 0, 3),
			BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.dim,
			TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right,
		})

		local function arrow(text, xPos)
			local b = mk("TextButton", row, {
				Size = UDim2.new(0, 34, 0, CARD_H - 20), Position = UDim2.new(0, xPos, 0, 24 + 10),
				BackgroundColor3 = COLORS.arrow, TextColor3 = COLORS.text, TextSize = 22, Text = text,
			})
			mk("UICorner", b, {})
			return b
		end
		local left = arrow("◀", 4)
		local right = arrow("▶", 4 + 34 + 8 + rowInner + 8)

		-- การ์ด 4 ใบ (คงที่) — เปลี่ยนเนื้อในตามหน้าที่เลื่อน ไม่สร้างใหม่
		local cards = {}
		for c = 1, perPage do
			local card = mk("Frame", row, {
				Size = UDim2.new(0, CARD_W, 0, CARD_H - 8),
				Position = UDim2.new(0, 4 + 34 + 8 + (c - 1) * (CARD_W + GAP), 0, 26),
				BackgroundColor3 = COLORS.card,
			})
			mk("UICorner", card, {})

			local badge = mk("TextLabel", card, {
				Size = UDim2.new(0, 34, 0, 18), Position = UDim2.new(0, 6, 0, 5),
				BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.faint,
				TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
			})
			-- รูปสินค้า: มี asset ใช้รูป / ไม่มีใช้ emoji ของหมวด (โชว์ทีละอัน)
			local img = mk("ImageLabel", card, {
				Size = UDim2.new(0, 52, 0, 52), Position = UDim2.new(0.5, -26, 0, 24),
				BackgroundTransparency = 1, Image = "", Visible = false,
			})
			local emoji = mk("TextLabel", card, {
				Size = UDim2.new(0, 52, 0, 52), Position = UDim2.new(0.5, -26, 0, 24),
				BackgroundTransparency = 1, Text = entry.icon or "📦",
				TextColor3 = COLORS.text, TextScaled = true,
			})
			local name = mk("TextLabel", card, {
				Size = UDim2.new(1, -12, 0, 32), Position = UDim2.new(0, 6, 0, 80),
				BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.text,
				TextSize = 13, TextWrapped = true,
			})
			local spec = mk("TextLabel", card, {
				Size = UDim2.new(1, -12, 0, 16), Position = UDim2.new(0, 6, 0, 112),
				BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.dim, TextSize = 11,
			})
			local btn = mk("TextButton", card, {
				Size = UDim2.new(1, -12, 0, 30), Position = UDim2.new(0, 6, 1, -36),
				BackgroundColor3 = COLORS.buy, TextColor3 = COLORS.text, TextSize = 14, Text = "",
			})
			mk("UICorner", btn, {})
			btn.Activated:Connect(function()
				-- ปุ่มเปิดเฉพาะการ์ด "ซื้อได้ขั้นถัดไป" — server ตัดสินเงิน/ระดับอีกชั้น
				deps.fireAction({ type = "BuyUpgrade", item = entry.key })
			end)

			cards[c] = { card = card, badge = badge, img = img, emoji = emoji,
				name = name, spec = spec, btn = btn }
		end

		local function turn(dir)
			local total = ShopKiosk.tierCount(entry)
			page[entry.key] = ShopKiosk.clampPage(page[entry.key] + dir, total, perPage)
			if ShopKiosk.refresh then ShopKiosk.refresh(deps.getState()) end
		end
		left.Activated:Connect(function() turn(-1) end)
		right.Activated:Connect(function() turn(1) end)

		rows[i] = { entry = entry, cards = cards, info = rowInfo, left = left, right = right }
	end

	local primed = false

	function ShopKiosk.refresh(state)
		if not state then return end
		moneyLabel.Text = ("💰 ฿%s"):format(HUD.comma(state.money))

		for _, r in rows do
			local entry = r.entry
			local tiers = ShopKiosk.tiersFor(entry, state)
			local level = state.upgrades and state.upgrades[entry.key] or 1

			-- เปิดร้านครั้งแรก: เด้งไปหน้าที่มีของซื้อได้เลย ไม่ต้องกดลูกศรหา
			if not primed then
				page[entry.key] = ShopKiosk.pageOf(math.min(level + 1, #tiers), perPage)
			end
			local pg = ShopKiosk.clampPage(page[entry.key], #tiers, perPage)
			page[entry.key] = pg
			local pages = ShopKiosk.pageCount(#tiers, perPage)

			r.info.Text = ("ระดับ %d / %d    ·    หน้า %d/%d"):format(level, #tiers, pg, pages)
			r.left.Visible = pg > 1
			r.right.Visible = pg < pages

			for c, ui in r.cards do
				local t = tiers[(pg - 1) * perPage + c]
				if not t then
					ui.card.Visible = false
				else
					ui.card.Visible = true
					ui.badge.Text = ("L%d"):format(t.tier)
					ui.name.Text = t.name or "?"
					ui.spec.Text = t.spec or ""
					if t.image then
						ui.img.Image, ui.img.Visible, ui.emoji.Visible = t.image, true, false
					else
						ui.img.Visible, ui.emoji.Visible = false, true
					end

					local dim = t.status == "owned" or t.status == "locked"
					ui.card.BackgroundColor3 = if t.status == "next" then COLORS.cardNext
						elseif dim then COLORS.cardDim
						else COLORS.card
					ui.name.TextColor3 = dim and COLORS.faint or COLORS.text
					ui.emoji.TextTransparency = dim and 0.55 or 0
					ui.img.ImageTransparency = dim and 0.55 or 0

					if t.status == "owned" then
						ui.btn.Text, ui.btn.BackgroundColor3, ui.btn.Active = "✓ มีแล้ว", COLORS.cardDim, false
					elseif t.status == "current" then
						ui.btn.Text, ui.btn.BackgroundColor3, ui.btn.Active = "⭐ ใช้อยู่", COLORS.current, false
					elseif t.status == "next" then
						local can = state.money >= t.price
						ui.btn.Text = ("Buy ฿%s"):format(HUD.comma(t.price))
						ui.btn.BackgroundColor3 = can and COLORS.buy or COLORS.broke
						ui.btn.Active = can
					else
						ui.btn.Text = ("🔒 ฿%s"):format(HUD.comma(t.price))
						ui.btn.BackgroundColor3, ui.btn.Active = COLORS.cardDim, false
					end
				end
			end
		end
		primed = true
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
