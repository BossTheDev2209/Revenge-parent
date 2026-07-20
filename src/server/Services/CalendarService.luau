-- CalendarService.luau — block ปฏิทิน 3 ประเภท (Canon lock / Select / Schedule) + Sponsor (PDF หน้า 6)
-- calendar = state.calendar[day] = { type=, id=, locked= } — TimeService.onDay ปลุกผ่าน Main
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../shared/Formulas")

local CalendarService = {}

-- วาง block: ได้เฉพาะวันอนาคต + ทุกช่องในช่วงว่าง/ทับ block เดี่ยวที่ไม่ lock ได้ (Canon/block ยาว = ห้ามทับ)
-- block.length = จำนวนวัน (1 unit = 1 ช่องปฏิทิน, PDF หน้า 6) — วางแล้วทุกช่องชี้ block เดียวกัน + startDay
function CalendarService.place(state, day: number, block): boolean
	local len = block.length or 1
	if day <= state.day then return false end
	for d = day, day + len - 1 do
		local ex = state.calendar[d]
		if ex and (ex.locked or ex.type == "Canon" or (ex.length or 1) > 1) then return false end
	end
	block.startDay = day
	for d = day, day + len - 1 do
		state.calendar[d] = block
	end
	return true
end

-- ย้าย block (UX ทาง ก — กดเลือกแล้วกดวันปลายทาง, user lock 21 ก.ค.)
-- fromDay = ช่องไหนของ block ก็ได้ ย้ายทั้งก้อน | Canon/lock ห้าม | ปลายทางต้องวางได้ทั้งช่วง
function CalendarService.moveBlock(state, fromDay: number, toDay: number): boolean
	local block = state.calendar[fromDay]
	if not block or block.locked or block.type == "Canon" then return false end
	local len = block.length or 1
	local start = block.startDay or fromDay
	-- ถอดออกชั่วคราวกันชนตัวเอง แล้วลองวางใหม่
	for d = start, start + len - 1 do
		state.calendar[d] = nil
	end
	if CalendarService.place(state, toDay, block) then return true end
	for d = start, start + len - 1 do -- วางไม่ได้ = คืนที่เดิม
		state.calendar[d] = block
	end
	block.startDay = start
	return false
end

-- รับงาน sponsor: ปลดล็อคที่ 10K follower (design doc §4)
function CalendarService.acceptSponsor(state, day: number): boolean
	if state.follower < Config.SponsorUnlockFollowers then return false end
	return CalendarService.place(state, day, { type = "Sponsor" })
end

-- ถึงวันที่มี block: Sponsor = เงินเข้า (คลิปวันนั้นไม่ได้ follower — trade-off ตาม design)
-- block ยาวหลายวัน: ผลเกิดวันสุดท้ายของงาน (วันระหว่างทางเคลียร์ช่องเฉยๆ)
-- คืน block เฉพาะวันจบงาน ให้ Main ตัดสินใจต่อ (Canon → ยิง event ฝั่ง client)
function CalendarService.onDay(state, rng)
	local block = state.calendar[state.day]
	if not block then return nil end
	local len = block.length or 1
	local lastDay = (block.startDay or state.day) + len - 1
	state.calendar[state.day] = nil
	if state.day < lastDay then return nil end -- งานยังไม่จบ
	if block.type == "Sponsor" then
		state.money += Formulas.sponsorPay(state.phase, rng)
	end
	return block
end

return CalendarService
