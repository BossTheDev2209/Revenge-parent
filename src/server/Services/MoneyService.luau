-- MoneyService.luau — หักค่าใช้จ่ายราย 7 วันเกม (design doc §4)
-- เงินเข้าจากคลิปอยู่ FollowerService.uploadClip — ไฟล์นี้ดูแลรายจ่ายอย่างเดียว
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../shared/Formulas")

local MoneyService = {}

-- ปรับงบ ⊖⊕ ต่อการ์ด (PDF หน้า 9 — user lock 21 ก.ค.) step/ขอบเขต/ผลใจอยู่ Config.Spending
-- Bank ทั้งแอปรอเฟส 2 (Config.AppMinPhase — 12 ส.ค. 2569, user) — เช็คซ้ำฝั่ง server กัน client ข้ามหัว icon ที่ซ่อนไว้
function MoneyService.adjustSpending(state, card: string, dir: number): boolean
	if not Formulas.appUnlocked(state.phase, "bank") then return false end
	local cfg = Config.Spending[card]
	if not cfg or (dir ~= 1 and dir ~= -1) then return false end
	local new = (state.spending[card] or 0) + dir
	if new < cfg.minOffset or new > cfg.maxOffset then return false end
	state.spending[card] = new
	return true
end

function MoneyService.weeklyTotal(state): number
	local w = Config.WeeklyExpenses[state.phase]
	local sp = state.spending or {}
	local S = Config.Spending
	return math.max(0, w.rent + (sp.rent or 0) * S.rent.step)
		+ w.internet
		+ math.max(0, w.food + (sp.food or 0) * S.food.step)
		+ math.max(0, (sp.staff or 0) * S.staff.step)
end

-- ผลใจจากไลฟ์สไตล์ (กิน/เช่า) ตอนตัดรอบ — Main เอาไป applyDelta
function MoneyService.lifestyleMental(state): number
	local sp = state.spending or {}
	local total = 0
	for _, card in { "food", "rent" } do
		local off = sp[card] or 0
		local cfg = Config.Spending[card]
		total += if off > 0 then off * cfg.mentalUp elseif off < 0 then -off * cfg.mentalDown else 0
	end
	return total
end

-- เรียกจาก TimeService.onDay (wiring ใน Main) — คืน (จ่ายไม่ไหว, วันนี้ตัดรอบไหม)
function MoneyService.onDay(state): (boolean, boolean)
	if state.day <= 1 or (state.day - 1) % 7 ~= 0 then return false, false end
	local total = MoneyService.weeklyTotal(state)
	-- จ่ายเช่าต่ำกว่าสัญญา (offset ≤ missedAtOffset) = นับค้างเช่าแม้มีเงิน
	if (state.spending and state.spending.rent or 0) <= Config.Spending.rent.missedAtOffset then
		state.flags.rentMissed = (state.flags.rentMissed or 0) + 1
	end
	if state.money >= total then
		state.money -= total
		return false, true
	end
	state.money = 0
	state.flags.rentMissed = (state.flags.rentMissed or 0) + 1 -- Bad End 1 = ครบ 2 (EndingService)
	return true, true
end

-- ซื้อ upgrade กล้อง/storage 4 ระดับ (design doc §4) — ผลต่อ VidQ ยัง unwired (รอ fix สูตร resolution)
function MoneyService.buyUpgrade(state, item: string): boolean
	local costs = Config.UpgradeCosts[item]
	if not costs then return false end
	-- ราคา 4 ขั้น = ซื้อ 4 ครั้ง (ระดับ 1→5 ตาม ResolutionLadder): จ่าย costs[ระดับปัจจุบัน]
	local cost = costs[state.upgrades[item]]
	if not cost or state.money < cost then return false end
	state.money -= cost
	state.upgrades[item] += 1
	-- ซื้อของใหม่ = สวมให้ทันที (ไม่งั้นจ่ายเงินแล้วยังถือของเก่าอยู่ งง)
	if state.equipped then state.equipped[item] = state.upgrades[item] end
	return true
end

-- ===== ของกินใช้แล้วหมด (Config.Consumables) — ซื้อ = ดื่มทันที ไม่มีคลังของ =====

-- ชั่วโมงสะสมของเกม (ตรงกับ MentalService.totalHours — ใช้หน่วยเดียวกันทั้งเกม)
function MoneyService.totalHours(state): number
	return state.day * 24 + state.timeOfDay
end

-- ⚠️ ตัว lookup + สูตรโซนอยู่ Formulas (shared) — client ต้องใช้ชุดเดียวกันตอนวาด/ตัดเกรด QTE
--    ห้าม copy สูตรมาไว้ที่นี่ซ้ำ ไม่งั้นโซนที่เห็นกับที่ตัดเกรดจะหลุดจากกัน

-- ซื้อ+ดื่มทันที — คืน false ถ้าไม่รู้จัก/เงินไม่พอ/ยังออกฤทธิ์อยู่ (ห้ามซ้อนเพื่อกันต่ออายุไม่รู้จบ)
-- server ตัดสินเงินและเวลาหมดฤทธิ์เอง ไม่เชื่อ client
function MoneyService.buyConsumable(state, key: string): boolean
	local item = Formulas.consumableByKey(key)
	if not item then return false end
	state.buffs = state.buffs or {}
	if state.buffs[key] then return false end -- ออกฤทธิ์อยู่แล้ว ซื้อซ้ำไม่ได้
	if state.money < item.price then return false end
	state.money -= item.price
	state.buffs[key] = { expireHour = MoneyService.totalHours(state) + item.durationHours }
	return true
end

-- เรียกทุกชั่วโมงเกม — คืน list ของ mental delta ที่ต้องหัก (Main เอาไป applyDelta ผ่าน MentalService)
-- แยกคืนค่าแทนที่จะหักเอง = pure พอที่จะเทสได้ + ไม่ผูก MoneyService เข้ากับ MentalService
function MoneyService.expireBuffs(state): { { key: string, mental: number } }
	local out = {}
	if not state.buffs then return out end
	local now = MoneyService.totalHours(state)
	for key, b in state.buffs do
		if b.expireHour and now >= b.expireHour then
			local item = Formulas.consumableByKey(key)
			state.buffs[key] = nil
			if item and item.mentalOnExpire and item.mentalOnExpire ~= 0 then
				table.insert(out, { key = key, mental = item.mentalOnExpire })
			end
		end
	end
	return out
end

-- ตัวคูณโซน QTE = Formulas.qteZoneMult (shared) — ทั้ง client/server ใช้ตัวเดียวกัน ไม่มีสำเนาที่นี่

-- เลือกย้อนกลับไปใช้ของที่ซื้อไว้แล้ว (ระดับเก่า) — ผลลดลงจริงตามตัวที่ถือ
-- คืน false ถ้าสายมั่ว/ระดับยังไม่ได้ซื้อ/ระดับต่ำกว่า 1 — server เป็นคนตัดสิน ไม่เชื่อ client
function MoneyService.equipLevel(state, item: string, level: number): boolean
	if not Config.UpgradeCosts[item] then return false end
	local owned = state.upgrades and state.upgrades[item]
	if not owned then return false end
	if type(level) ~= "number" or level ~= math.floor(level) then return false end
	if level < 1 or level > owned then return false end
	state.equipped = state.equipped or {}
	state.equipped[item] = level
	return true
end

return MoneyService
