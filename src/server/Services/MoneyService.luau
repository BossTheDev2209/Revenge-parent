-- MoneyService.luau — หักค่าใช้จ่ายราย 7 วันเกม (design doc §4)
-- เงินเข้าจากคลิปอยู่ FollowerService.uploadClip — ไฟล์นี้ดูแลรายจ่ายอย่างเดียว
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")

local MoneyService = {}

-- ปรับงบ ⊖⊕ ต่อการ์ด (PDF หน้า 9 — user lock 21 ก.ค.) step/ขอบเขต/ผลใจอยู่ Config.Spending
function MoneyService.adjustSpending(state, card: string, dir: number): boolean
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
	return true
end

return MoneyService
