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

-- วาง block: ได้เฉพาะวันอนาคต + ช่องว่างหรือ block ที่ไม่ lock (Canon = ห้ามทับเสมอ)
function CalendarService.place(state, day: number, block): boolean
	if day <= state.day then return false end
	local ex = state.calendar[day]
	if ex and (ex.locked or ex.type == "Canon") then return false end
	state.calendar[day] = block
	return true
end

-- รับงาน sponsor: ปลดล็อคที่ 10K follower (design doc §4)
function CalendarService.acceptSponsor(state, day: number): boolean
	if state.follower < Config.SponsorUnlockFollowers then return false end
	return CalendarService.place(state, day, { type = "Sponsor" })
end

-- ถึงวันที่มี block: Sponsor = เงินเข้า (คลิปวันนั้นไม่ได้ follower — trade-off ตาม design)
-- คืน block ให้ Main ตัดสินใจต่อ (Canon → ยิง event ฝั่ง client)
function CalendarService.onDay(state, rng)
	local block = state.calendar[state.day]
	if not block then return nil end
	if block.type == "Sponsor" then
		state.money += Formulas.sponsorPay(state.phase, rng)
	end
	state.calendar[state.day] = nil
	return block
end

return CalendarService
