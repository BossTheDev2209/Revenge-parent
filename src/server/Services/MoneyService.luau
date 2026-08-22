-- MoneyService — รายจ่ายราย 7 วัน + ซื้อ upgrade/ของกิน (เงินเข้าอยู่ FollowerService)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../shared/Formulas")

local MoneyService = {}

-- ปรับงบ ⊖⊕ ต่อการ์ด (step/ขอบเขต/ผลใจอยู่ Config.Spending) — เช็ค unlock ซ้ำฝั่ง server
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
end

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

-- ตัดรอบทุก 7 วัน — คืน (จ่ายไม่ไหว, วันนี้ตัดรอบไหม)
function MoneyService.onDay(state): (boolean, boolean)
	if state.day <= 1 or (state.day - 1) % 7 ~= 0 then return false, false end
	local total = MoneyService.weeklyTotal(state)
	if state.money >= total then
		state.money -= total
		return false, true
	end
	state.money = 0
	state.flags.rentMissed = (state.flags.rentMissed or 0) + 1 -- ครบ 2 = Bad End 1 (EndingService)
	return true, true
end

function MoneyService.buyUpgrade(state, item: string): boolean
	local costs = Config.UpgradeCosts[item]
	if not costs then return false end
	local cost = costs[state.upgrades[item]] -- costs[ระดับปัจจุบัน] = ราคาขึ้นระดับถัดไป
	if not cost or state.money < cost then return false end
	state.money -= cost
	state.upgrades[item] += 1
	if state.equipped then state.equipped[item] = state.upgrades[item] end -- สวมของใหม่ทันที
	return true
end

function MoneyService.totalHours(state): number
	return state.day * 24 + state.timeOfDay
end

-- ซื้อ = ดื่มทันที ไม่มีคลังของ · ห้ามซ้อนตอนยังออกฤทธิ์ (กันต่ออายุไม่รู้จบ)
function MoneyService.buyConsumable(state, key: string): boolean
	local item = Formulas.consumableByKey(key)
	if not item then return false end
	state.buffs = state.buffs or {}
	if state.buffs[key] then return false end
	if state.money < item.price then return false end
	state.money -= item.price
	state.buffs[key] = { expireHour = MoneyService.totalHours(state) + item.durationHours }
	return true
end

-- คืน list ของ mental delta แทนที่จะหักเอง — กัน MoneyService ผูกกับ MentalService (เทสได้)
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

-- ย้อนไปใช้ระดับเก่าที่ซื้อไว้แล้ว (ผลลดลงจริง)
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
