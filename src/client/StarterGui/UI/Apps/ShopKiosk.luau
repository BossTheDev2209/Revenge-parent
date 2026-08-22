-- ShopKiosk — ร้านค้าในแมพ: เดินไปกด Interact_Shop เปิดหน้าซื้อ (คนละตัวกับแอป Shop บนจอคอม)
-- หมวดละ 1 แถว · แถวละ 4 การ์ด · ลูกศร ◀▶ เลื่อนระดับ · สถานะ: ซื้อแล้ว✓/ใช้อยู่⭐/Buy/🔒
-- ของจาก Config.ShopCatalog · ราคาจาก UpgradeCosts · สเปคจาก ladder → เพิ่ม/แก้ = แก้ Config อย่างเดียว
-- ซื้อจริงที่ server (BuyUpgrade) · pure ส่วนบน (เทส lune) · ที่เหลือเป็น Roblox UI
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../../shared/Config")
local UIAssets = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.UIAssets)
	else require("../../../../shared/UIAssets")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../../../shared/Formulas")
-- ยืมแค่ HUD.comma (pure) — เลขเงินต้องคั่นหลักแบบเดียวกับ HUD ทั้งเกม
local HUD = if isStudio
	then require(game:GetService("StarterGui").UI.HUD)
	else require("../HUD")
-- โมเดล 3 มิติจริงบนการ์ด — nil ตอนเทส lune (การ์ดตกไปใช้ emoji)
local ModelViewport = if isStudio
	then require(game:GetService("StarterPlayer").StarterPlayerScripts.ModelViewport)
	else nil

local ShopKiosk = {}

ShopKiosk.CARDS_PER_ROW = 4

-- จำนวนระดับทั้งหมด = ของเริ่มต้น 1 + ที่ซื้อได้ #names
function ShopKiosk.tierCount(entry: { names: { string } }): number
	return #entry.names + 1
end

-- ชื่อของที่ระดับนี้ (ระดับ 1 = ของติดตัวตอนเริ่ม)
function ShopKiosk.nameAt(entry, level: number): string?
	if level == 1 then return entry.startName end
	return entry.names[level - 1]
end

-- คีย์รูปใน UIAssets — วาดไว้แค่ 1-6 ที่เหลือ nil (การ์ดใช้ emoji)
function ShopKiosk.imageFor(key: string, tier: number): string?
	local id = UIAssets["shop_" .. key .. "_" .. tier]
	return (id ~= nil and id ~= "") and id or nil
end

-- ชื่อโมเดลใน ToolModels ที่ render บนการ์ด · กล้อง = Camera_N (clamp ที่ CameraModelCount) · อื่น = nil
function ShopKiosk.modelFor(key: string, tier: number): string?
	if key ~= "camera" then return nil end
	return "Camera_" .. math.clamp(tier, 1, Config.CameraModelCount)
end

-- สเปค ("quality") ของระดับนี้ — อ่านจาก ladder ไม่ก๊อปเลขซ้ำ · nil = หมวดนี้ยังไม่มี ladder
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

-- ของชิ้นถัดไปตาม state — nil = ซื้อครบทุกระดับ
function ShopKiosk.offerFor(entry, state)
	local level = state.upgrades and state.upgrades[entry.key] or 1
	local name = entry.names[level]
	local costs = Config.UpgradeCosts[entry.key]
	local price = costs and costs[level]
	if not name or not price then return nil end
	return {
		name = name,
		price = price,
		level = level + 1,
		spec = ShopKiosk.specFor(entry.key, level + 1),
	}
end

-- บันไดทั้งหมด + สถานะแต่ละขั้น: owned (ผ่านแล้ว) / current (ใช้อยู่) / next (ซื้อได้) / locked
function ShopKiosk.tiersFor(entry, state)
	local owned = state.upgrades and state.upgrades[entry.key] or 1
	local equipped = Formulas.activeLevel(state, entry.key) -- ใช้ระดับไหนอยู่
	local costs = Config.UpgradeCosts[entry.key] or {}
	local out = {}
	for tier = 1, ShopKiosk.tierCount(entry) do
		-- เช็ค equipped ก่อน owned เสมอ (ไม่งั้นตัวที่ถืออยู่โดนนับเป็น "ซื้อแล้ว")
		local status = if tier == equipped then "current"
			elseif tier <= owned then "owned" -- ซื้อแล้วแต่ไม่ได้ใช้ → กดย้อนกลับได้
			elseif tier == owned + 1 then "next"
			else "locked"
		table.insert(out, {
			tier = tier,
			name = ShopKiosk.nameAt(entry, tier),
			spec = ShopKiosk.specFor(entry.key, tier),
			image = ShopKiosk.imageFor(entry.key, tier),
			price = costs[tier - 1], -- ระดับ 1 ไม่มีราคา
			status = status,
		})
	end
	return out
end

function ShopKiosk.pageCount(total: number, perPage: number): number
	return math.max(1, math.ceil(total / perPage))
end

-- หน้าที่มีระดับนี้ — เปิดร้านมาเห็นของที่ซื้อได้เลย ไม่ต้องกดลูกศรหา
function ShopKiosk.pageOf(tier: number, perPage: number): number
	return math.max(1, math.ceil(tier / perPage))
end

function ShopKiosk.clampPage(page: number, total: number, perPage: number): number
	return math.clamp(page, 1, ShopKiosk.pageCount(total, perPage))
end

-- ย่อแผงให้พอดีจอ: layout เป็น px ตายตัวตามภาพร่าง ย่อทั้งแผงด้วย UIScale (สัดส่วนตรงภาพร่างทุกจอ)
ShopKiosk.SCREEN_MARGIN = 24
ShopKiosk.MIN_SCALE = 0.35 -- ย่อต่ำกว่านี้อ่านไม่ออก ยอมล้นดีกว่า

-- ตัวคูณขนาด ≤1 (จอใหญ่ใช้ขนาดออกแบบเป๊ะ ไม่ขยายจนเบลอ) · viewH ต้องหัก GuiInset มาแล้ว
function ShopKiosk.fitScale(panelW: number, panelH: number, viewW: number, viewH: number, margin: number?): number
	local m = margin or ShopKiosk.SCREEN_MARGIN
	local fit = math.min((viewW - m * 2) / panelW, (viewH - m * 2) / panelH)
	return math.clamp(fit, ShopKiosk.MIN_SCALE, 1)
end

local COLORS = {
	bg = Color3.fromRGB(24, 24, 34),
	rowBg = Color3.fromRGB(31, 31, 43),
	card = Color3.fromRGB(44, 44, 60),
	cardNext = Color3.fromRGB(46, 62, 48),
	cardDim = Color3.fromRGB(33, 33, 44),
	buy = Color3.fromRGB(70, 175, 95),
	broke = Color3.fromRGB(122, 68, 68),
	current = Color3.fromRGB(70, 130, 200),
	equip = Color3.fromRGB(96, 84, 150), -- ม่วง = กดย้อนกลับไปใช้ของเก่า (คนละสีกับ Buy เขียว)
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

	local toolModels = game:GetService("ReplicatedStorage"):FindFirstChild("ToolModels")
	local perPage = ShopKiosk.CARDS_PER_ROW
	local rowInner = CARD_W * perPage + GAP * (perPage - 1)
	local panelW = 40 + 34 + 8 + rowInner + 8 + 34 -- margin + ลูกศรซ้าย + การ์ด + ลูกศรขวา
	local rowH = 24 + CARD_H
	-- แถวของกิน (Config.Consumables) ต่อท้าย — ไม่มีของ = ไม่กินที่
	local CONSUMABLE_ROW_H = 24 + CARD_H
	local hasConsumables = #Config.Consumables > 0
	local panelH = 56 + (#Config.ShopCatalog * (rowH + 12)) + 12
		+ (hasConsumables and (CONSUMABLE_ROW_H + 12) or 0)

	local gui = mk("ScreenGui", nil, { Name = "Gui_ShopKiosk", ResetOnSpawn = false, DisplayOrder = 5 })
	local panel = mk("Frame", gui, {
		Size = UDim2.new(0, panelW, 0, panelH),
		AnchorPoint = Vector2.new(0.5, 0.5), -- UIScale ย่อจากกึ่งกลาง แผงอยู่กลางจอเสมอ
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundColor3 = COLORS.bg,
	})
	mk("UICorner", panel, {})

	-- ย่อให้พอดีจอ + ตามขนาดหน้าต่างที่เปลี่ยน (ย่อหน้าต่าง/หมุนจอ)
	local uiScale = mk("UIScale", panel, {})
	local cam = workspace.CurrentCamera
	local GuiService = game:GetService("GuiService")
	local function fitToScreen()
		local vp = cam.ViewportSize
		local inset = GuiService:GetGuiInset() -- แถบบนของ Roblox กินพื้นที่จริง
		uiScale.Scale = ShopKiosk.fitScale(panelW, panelH, vp.X, vp.Y - inset.Y)
	end
	fitToScreen()
	local fitConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

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
	close:SetAttribute("Sfx", "ui_back")

	local page = {} -- [key] = หน้าที่กำลังดู
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
			-- รูปสินค้า: โมเดล 3 มิติ > รูป asset > emoji (โชว์ทีละอัน)
			local vpHost = mk("Frame", card, {
				Size = UDim2.new(0, 52, 0, 52), Position = UDim2.new(0.5, -26, 0, 24),
				BackgroundTransparency = 1, Visible = false,
			})
			local vp = ModelViewport and ModelViewport.new(vpHost) or nil
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
			local ui -- ประกาศก่อน handler อ่าน status/tier ล่าสุดที่ refresh เขียน
			btn.Activated:Connect(function()
				-- next = ซื้อขั้นถัดไป · owned = ย้อนกลับไปใช้ระดับนั้น · server ตัดสินซ้ำเสมอ
				if ui.status == "next" then
					deps.fireAction({ type = "BuyUpgrade", item = entry.key })
				elseif ui.status == "owned" then
					deps.fireAction({ type = "EquipLevel", item = entry.key, level = ui.tier })
				end
			end)

			-- status/tier อัปทุก refresh — handler อ่านค่าล่าสุด ไม่ผูกตายตอนสร้างปุ่ม
			ui = { card = card, badge = badge, img = img, emoji = emoji, vpHost = vpHost, vp = vp,
				name = name, spec = spec, btn = btn, status = nil, tier = nil, vpTier = nil, vpOk = false }
			cards[c] = ui
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

	-- แถวของกิน — ไม่มีระดับ/หน้า/locked: ซื้อได้ตลอดถ้าเงินพอและยังไม่ออกฤทธิ์ (ซื้อ = ดื่มทันที)
	local consumableCards = {}
	if hasConsumables then
		local cRow = mk("Frame", panel, {
			Size = UDim2.new(1, -40, 0, CONSUMABLE_ROW_H),
			Position = UDim2.new(0, 20, 0, 56 + #Config.ShopCatalog * (rowH + 12)),
			BackgroundColor3 = COLORS.rowBg,
		})
		mk("UICorner", cRow, {})
		mk("TextLabel", cRow, {
			Size = UDim2.new(0, 320, 0, 22), Position = UDim2.new(0, 10, 0, 2),
			BackgroundTransparency = 1, Text = "🥤 ของกิน (ใช้แล้วหมด)", TextColor3 = COLORS.text,
			TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
		})
		local cInfo = mk("TextLabel", cRow, {
			Size = UDim2.new(0, 300, 0, 20), Position = UDim2.new(1, -310, 0, 3),
			BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.dim,
			TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right,
		})

		for idx, item in Config.Consumables do
			local card = mk("Frame", cRow, {
				Size = UDim2.new(0, CARD_W, 0, CARD_H - 8),
				Position = UDim2.new(0, 4 + 34 + 8 + (idx - 1) * (CARD_W + GAP), 0, 26),
				BackgroundColor3 = COLORS.card,
			})
			mk("UICorner", card, {})
			mk("TextLabel", card, { -- emoji ของชิ้นนั้น
				Size = UDim2.new(0, 52, 0, 52), Position = UDim2.new(0.5, -26, 0, 24),
				BackgroundTransparency = 1, Text = item.icon or "🥤",
				TextColor3 = COLORS.text, TextScaled = true,
			})
			mk("TextLabel", card, {
				Size = UDim2.new(1, -12, 0, 32), Position = UDim2.new(0, 6, 0, 80),
				BackgroundTransparency = 1, Text = item.label, TextColor3 = COLORS.text,
				TextSize = 13, TextWrapped = true,
			})
			mk("TextLabel", card, {
				Size = UDim2.new(1, -12, 0, 28), Position = UDim2.new(0, 6, 0, 108),
				BackgroundTransparency = 1, Text = item.desc or "", TextColor3 = COLORS.dim,
				TextSize = 11, TextWrapped = true,
			})
			local btn = mk("TextButton", card, {
				Size = UDim2.new(1, -12, 0, 30), Position = UDim2.new(0, 6, 1, -36),
				BackgroundColor3 = COLORS.buy, TextColor3 = COLORS.text, TextSize = 14, Text = "",
			})
			mk("UICorner", btn, {})
			btn.Activated:Connect(function()
				deps.fireAction({ type = "BuyConsumable", item = item.key }) -- server เช็คซ้ำ (เงิน/ออกฤทธิ์ซ้อน)
			end)
			consumableCards[idx] = { item = item, btn = btn, card = card }
		end
		consumableCards.info = cInfo
	end

	local primed = false

	function ShopKiosk.refresh(state)
		if not state then return end
		moneyLabel.Text = ("💰 ฿%s"):format(HUD.comma(state.money))

		for _, r in rows do
			local entry = r.entry
			local tiers = ShopKiosk.tiersFor(entry, state)
			local level = state.upgrades and state.upgrades[entry.key] or 1

			if not primed then -- เปิดร้านครั้งแรก: เด้งไปหน้าที่มีของซื้อได้
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
					ui.status, ui.tier = t.status, t.tier -- handler ปุ่มอ่านค่านี้
					ui.badge.Text = ("L%d"):format(t.tier)
					ui.name.Text = t.name or "?"
					ui.spec.Text = t.spec or ""
					-- โมเดล > รูป > emoji · re-render เฉพาะตอนระดับของช่องนี้เปลี่ยน (clone ทุก refresh = แลค)
					local modelName = ShopKiosk.modelFor(entry.key, t.tier)
					if ui.vp and modelName then
						if ui.vpTier ~= t.tier then
							ui.vpTier = t.tier
							ui.vpOk = ui.vp.showModel(toolModels and toolModels:FindFirstChild(modelName))
						end
					elseif ui.vp and ui.vpTier ~= nil then
						ui.vpTier, ui.vpOk = nil, false
						ui.vp.clear()
					end
					ui.vpHost.Visible = ui.vpOk
					if ui.vpOk then
						ui.img.Visible, ui.emoji.Visible = false, false
					elseif t.image then
						ui.img.Image, ui.img.Visible, ui.emoji.Visible = t.image, true, false
					else
						ui.img.Visible, ui.emoji.Visible = false, true
					end

					local dim = t.status == "locked" -- "owned" กดย้อนได้ ต้องเห็นชัด
					ui.card.BackgroundColor3 = if t.status == "next" then COLORS.cardNext
						elseif dim then COLORS.cardDim
						else COLORS.card
					ui.name.TextColor3 = dim and COLORS.faint or COLORS.text
					ui.emoji.TextTransparency = dim and 0.55 or 0
					ui.img.ImageTransparency = dim and 0.55 or 0

					-- เสียงตามสถานะปุ่ม (Main.client อ่าน attribute Sfx ตอนกด)
					if t.status == "owned" then
						ui.btn.Text, ui.btn.BackgroundColor3, ui.btn.Active = "↩ ใช้อันนี้", COLORS.equip, true
						ui.btn:SetAttribute("Sfx", "equip")
					elseif t.status == "current" then
						ui.btn.Text, ui.btn.BackgroundColor3, ui.btn.Active = "⭐ ใช้อยู่", COLORS.current, false
						ui.btn:SetAttribute("Sfx", "none")
					elseif t.status == "next" then
						local can = state.money >= t.price
						ui.btn.Text = ("Buy ฿%s"):format(HUD.comma(t.price))
						ui.btn.BackgroundColor3 = can and COLORS.buy or COLORS.broke
						ui.btn.Active = can
						ui.btn:SetAttribute("Sfx", can and "buy" or "denied") -- เงินไม่พอ = เสียงปฏิเสธ
					else
						ui.btn.Text = ("🔒 ฿%s"):format(HUD.comma(t.price))
						ui.btn.BackgroundColor3, ui.btn.Active = COLORS.cardDim, false
						ui.btn:SetAttribute("Sfx", "denied")
					end
				end
			end
		end

		-- ของกิน: ออกฤทธิ์อยู่ (ซื้อซ้ำไม่ได้) / ซื้อได้ / เงินไม่พอ
		local activeBuff = nil
		for _, ui in consumableCards do
			if type(ui) == "table" and ui.item then
				local buff = state.buffs and state.buffs[ui.item.key]
				if buff then
					activeBuff = ui.item
					ui.btn.Text, ui.btn.BackgroundColor3, ui.btn.Active = "⏳ ออกฤทธิ์อยู่", COLORS.current, false
					ui.btn:SetAttribute("Sfx", "none")
					ui.card.BackgroundColor3 = COLORS.cardNext
				else
					local can = state.money >= ui.item.price
					ui.btn.Text = ("Buy ฿%s"):format(HUD.comma(ui.item.price))
					ui.btn.BackgroundColor3 = can and COLORS.buy or COLORS.broke
					ui.btn.Active = can
					ui.btn:SetAttribute("Sfx", can and "buy" or "denied")
					ui.card.BackgroundColor3 = COLORS.card
				end
			end
		end
		if consumableCards.info then
			if activeBuff then -- เวลาที่เหลือเป็นชั่วโมงเกม (หน่วยเดียวกับ expireHour)
				local buff = state.buffs[activeBuff.key]
				local left = math.max(0, (buff.expireHour or 0) - (state.day * 24 + state.timeOfDay))
				consumableCards.info.Text = ("ออกฤทธิ์อยู่ · เหลือ %d ชม.ในเกม"):format(left)
			else
				consumableCards.info.Text = "ซื้อแล้วดื่มทันที · ครั้งละ 1 ขวด"
			end
		end
		primed = true
	end

	local function shut()
		ShopKiosk.running = false
		ShopKiosk.refresh = nil
		fitConn:Disconnect() -- ไม่ตัด = ยิงหา uiScale ที่ถูกทำลายทุกครั้งที่ย่อจอ
		gui:Destroy()
	end
	close.Activated:Connect(shut)
	ShopKiosk.close = shut

	ShopKiosk.refresh(deps.getState())
	gui.Parent = playerGui
end

return ShopKiosk
