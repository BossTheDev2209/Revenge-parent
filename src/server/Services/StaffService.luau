-- StaffService — พนักงานจ้าง + เพื่อนร่วมทาง (docs/02 §9.8)
-- พนักงานผลิตคลิป auto: ได้ follower/เงินเลย ไม่กิน footage ไม่มี viral ไม่คูณ mental
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../shared/Formulas")

local StaffService = {}

function StaffService.clipsPerDay(speed: number): number
	return speed / Config.Staff.clipsPerDayPerSpeed
end

-- quality → tier (สุ่มตามตารางน้ำหนัก)
function StaffService.rollTier(quality: number, rng): string
	rng = rng or math.random
	local row
	for _, r in Config.Staff.tierChanceByQuality do
		if quality <= r.maxQuality then
			row = r
			break
		end
	end
	row = row or Config.Staff.tierChanceByQuality[#Config.Staff.tierChanceByQuality]
	local roll = rng()
	local acc = 0
	for _, tier in { "C", "B", "A", "S" } do -- ลำดับตายตัว เทสอิงลำดับนี้
		acc += row[tier]
		if roll < acc then return tier end
	end
	return "S"
end

-- roster ที่ปลดล็อกแล้ว: ครบทั้ง phase และ follower (+ flag ถ้ามี)
function StaffService.availableHires(state)
	local out = {}
	for _, r in Config.Staff.roster do
		if state.phase >= r.phase and state.follower >= r.follower
			and (not r.flag or state.flags[r.flag]) then
			table.insert(out, r)
		end
	end
	return out
end

local function findRoster(id: string)
	for _, r in Config.Staff.roster do
		if r.id == id then return r end
	end
	return nil
end

function StaffService.isHired(state, id: string): boolean
	for _, s in state.staff do
		if s.id == id then return true end
	end
	return false
end

-- จ้าง: ปลดล็อกแล้ว + ยังไม่จ้าง + ไม่เกิน cap
function StaffService.hire(state, id: string): boolean
	local r = findRoster(id)
	if not r then return false end
	if state.phase < r.phase or state.follower < r.follower then return false end
	if r.flag and not state.flags[r.flag] then return false end
	if StaffService.isHired(state, id) then return false end
	if #state.staff >= Config.Staff.hireCap then return false end
	table.insert(state.staff, { id = r.id, speed = r.speed, quality = r.quality, salary = r.salary })
	return true
end

-- event "พนักงานตีกัน": hire ที่ tag leavesOnSplit ออก + worldNPC ผู้ภักดี auto เข้าแทน
-- คืน { left = {ids ที่ออก}, joined = id ผู้ภักดี or nil } · เรียกซ้ำปลอดภัย
function StaffService.splitStaff(state)
	local left = {}
	for i = #state.staff, 1, -1 do
		local r = findRoster(state.staff[i].id)
		if r and r.leavesOnSplit then
			table.insert(left, state.staff[i].id)
			table.remove(state.staff, i)
		end
	end
	local loyal = Config.Staff.loyalAfterSplit
	local joined = nil
	if loyal and not StaffService.isHired(state, loyal.id) then
		table.insert(state.staff, { id = loyal.id, speed = loyal.speed, quality = loyal.quality, salary = loyal.salary })
		joined = loyal.id
	end
	return { left = left, joined = joined }
end

function StaffService.fire(state, id: string): boolean
	for i, s in state.staff do
		if s.id == id then
			table.remove(state.staff, i)
			return true
		end
	end
	return false
end

-- เพื่อนร่วมทาง (auto ตามเนื้อเรื่อง): เข้าเอง, โตตามเฟส, ออกตอนทรยศ
function StaffService.syncCompanions(state)
	for _, c in Config.Staff.companions do
		local idx
		for i, x in state.companions do
			if x.id == c.id then idx = i end
		end
		local gone = c.leavesOnBetrayal and state.flags.betrayed
		if gone then
			if idx then table.remove(state.companions, idx) end
		elseif state.follower >= c.joinFollower then
			local grown = c.growAtPhase and state.phase >= c.growAtPhase
			local speed = if grown then c.grownSpeed else c.speed
			local quality = if grown then c.grownQuality else c.quality
			if idx then
				state.companions[idx].speed = speed
				state.companions[idx].quality = quality
			else
				table.insert(state.companions, { id = c.id, speed = speed, quality = quality })
			end
		end
	end
end

-- ทีมทั้งหมด (จ้าง + เพื่อน)
function StaffService.team(state)
	local all = {}
	for _, s in state.staff do table.insert(all, s) end
	for _, c in state.companions do table.insert(all, c) end
	return all
end

function StaffService.summary(state)
	local speed, quality, salary, n = 0, 0, 0, 0
	for _, m in StaffService.team(state) do
		speed += m.speed
		quality += m.quality
		salary += m.salary or 0
		n += 1
	end
	return {
		count = n,
		speed = speed,
		avgQuality = n > 0 and (quality / n) or 0,
		salary = salary,
		clipsPerDay = StaffService.clipsPerDay(speed),
	}
end

-- ผลิตรายวัน (TimeService.onDay) — เศษคลิปสะสมข้ามวันใน staffClipCarry
-- คืน list { tier, gained, money } ต่อคลิป ให้ Main สร้าง comment ต่อ
function StaffService.produceDaily(state, rng)
	rng = rng or math.random
	local team = StaffService.team(state)
	if #team == 0 then return {} end

	local results = {}
	local phase = Formulas.phaseFor(state.follower)
	local base = Config.FollowerBase[phase]
	local mid = (base.min + base.max) / 2

	for _, m in team do
		local carry = (state.staffClipCarry[m.id] or 0) + StaffService.clipsPerDay(m.speed)
		local count = math.floor(carry)
		state.staffClipCarry[m.id] = carry - count
		for _ = 1, count do
			local tier = StaffService.rollTier(m.quality, rng)
			local gained = math.floor(mid * Formulas.vidqMultiplier(tier)) -- ไม่มี viral/mental
			local money = Formulas.moneyGain(gained, phase)
			state.follower += gained
			state.money += money
			table.insert(state.staffClips, { tier = tier, by = m.id })
			table.insert(results, { tier = tier, gained = gained, money = money })
		end
	end
	state.phase = Formulas.phaseFor(state.follower)
	return results
end

function StaffService.weeklySalary(state): number
	local total = 0
	for _, s in state.staff do
		total += s.salary or 0
	end
	return total
end

-- จ่ายไม่ไหว → ไล่คนแพงสุดออกทีละคนจนจ่ายไหว · คืน list id ที่ลาออก
function StaffService.resign(state, affordable: number)
	local left = {}
	while StaffService.weeklySalary(state) > affordable and #state.staff > 0 do
		local worstIdx, worstSalary = 1, -1
		for i, s in state.staff do
			if (s.salary or 0) > worstSalary then
				worstIdx, worstSalary = i, s.salary or 0
			end
		end
		table.insert(left, state.staff[worstIdx].id)
		table.remove(state.staff, worstIdx)
	end
	return left
end

return StaffService
