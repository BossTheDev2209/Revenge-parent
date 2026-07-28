-- MentalService.luau — หลอดใจ: drain + delta จาก action (design doc §3)
-- option ข: ยังไม่มี drain modifiers — รอ user ตัดสินอายุ (flag ใน docs/08 §4)
-- bar เข้าระบบตอน phase 2 (Config.Mental.introducedInPhase) — ก่อนนั้น no-op ทั้งไฟล์
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")

local MentalService = {}

-- 1%/4.5 วิจริง แปลงเป็นต่อชั่วโมงเกม (7.5 วิจริง)
MentalService.drainPerHour = Config.Mental.drainPercent
	* (Config.Time.secondsPerGameHour / Config.Mental.drainEverySeconds)

-- ค่า mental ที่สูตรควรใช้: ก่อน phase 2 คืน 50 (โซนกลาง ×1.0 — ไม่มีโบนัส/โทษ)
function MentalService.effective(state): number
	if state.phase < Config.Mental.introducedInPhase then return 50 end
	return state.mental
end

function MentalService.applyDelta(state, delta: number)
	if state.phase < Config.Mental.introducedInPhase then return end
	if delta > 0 then
		delta *= MentalService.recoverMultiplier(state) -- ฝั่งดี = ฟื้นแรงขึ้น (docs/02 §3)
	end
	state.mental = math.clamp(state.mental + delta, 0, 100)
	if state.mental <= 0 then
		state.flags.mentalZero = true -- EndingService อ่านทีหลัง (Bad End 2)
	end
end

-- reason = key ใน Config.Mental.deltas (clipEdit / viralClip / rentMissed / ...)
function MentalService.apply(state, reason: string)
	local d = Config.Mental.deltas[reason]
	assert(d, "ไม่รู้จัก mental reason: " .. tostring(reason))
	MentalService.applyDelta(state, d)
end

-- ชั่วโมงที่หลับอยู่ **ไม่ drain และไม่นับชั่วโมงตื่น** (fix 29 ก.ค.)
-- เดิม: TimeService.sleep เดินเวลาทีละชั่วโมงผ่าน tick → นอน 8 ชม. เสียใจ −13% ทั้งที่ไม่ได้ทำอะไร
-- = นอนกลายเป็นการกระทำที่ "แย่กว่าไม่นอน" ซึ่งขัดกับ modifier "อดนอน" (docs/02 §3) ที่ลงโทษการไม่นอน
-- mod ยังหมดอายุตามเวลาปกติ (Canon event/streak) — แค่ตัว drain กับ awakeHours ที่หยุด
function MentalService.onHour(state)
	MentalService.expireMods(state)
	if state.sleeping then return end
	MentalService.onHourAwake(state)
	MentalService.applyDelta(state, -MentalService.drainPerHour * MentalService.drainMultiplier(state))
end

-- ===== Drain/Recovery Modifiers (docs/02 §3 lock 19 ก.ค.) =====

local function totalHours(state): number
	return state.day * 24 + state.timeOfDay
end

-- เพิ่ม mod ตามชื่อใน Config.Mental.mods — ติดซ้ำ = refresh อายุ ไม่เบิ้ล
function MentalService.addMod(state, id: string)
	local spec = Config.Mental.mods[id]
	assert(spec, "ไม่รู้จัก mod: " .. tostring(id))
	local expireHour = spec.hours and (totalHours(state) + spec.hours) or nil
	for _, m in state.mentalMods do
		if m.id == id then
			m.expireHour = expireHour
			return
		end
	end
	table.insert(state.mentalMods, { id = id, expireHour = expireHour })
end

local function removeMods(state, predicate)
	for i = #state.mentalMods, 1, -1 do
		if predicate(state.mentalMods[i]) then
			table.remove(state.mentalMods, i)
		end
	end
end

-- ลบ mod ที่หมดอายุตามชั่วโมงเกม (เรียกทุก onHour)
function MentalService.expireMods(state)
	local now = totalHours(state)
	removeMods(state, function(m) return m.expireHour and now >= m.expireHour end)
end

local function multiplier(state, kind): number
	local mult = 1
	for _, m in state.mentalMods do
		local spec = Config.Mental.mods[m.id]
		if spec and spec.kind == kind then
			mult *= spec.mult
		end
	end
	return math.min(mult, Config.Mental.modCap)
end

function MentalService.drainMultiplier(state): number
	return multiplier(state, "drain")
end

function MentalService.recoverMultiplier(state): number
	return multiplier(state, "recover")
end

-- ===== Event hooks (Main เรียกจาก handler — logic streak อยู่ที่นี่ทั้งหมด) =====

-- ตัดคลิปโดยไม่ทำ activity คั่น ครบ 5 → EditStreak5
function MentalService.onEdit(state)
	state.streaks.edit += 1
	if state.streaks.edit >= Config.Mental.mods.EditStreak5.streak then
		MentalService.addMod(state, "EditStreak5")
	end
end

-- activity ล้าง: edit streak + mod ที่หายด้วย activity
function MentalService.onActivityDone(state)
	state.streaks.edit = 0
	removeMods(state, function(m)
		local u = Config.Mental.mods[m.id].untilEvent
		return u == "activity" or u == "activityOrGood"
	end)
end

-- ตอบ comment: นับ streak สองฝั่ง — ตอบดีล้าง CommentBadStreak3 ทันที (ตาม PDF)
function MentalService.onCommentAnswered(state, tag: string)
	if tag == "neg" then
		state.streaks.commentBad += 1
		state.streaks.commentGood = 0
		if state.streaks.commentBad >= Config.Mental.mods.CommentBadStreak3.streak then
			MentalService.addMod(state, "CommentBadStreak3")
		end
	elseif tag == "pos" then
		state.streaks.commentGood += 1
		state.streaks.commentBad = 0
		removeMods(state, function(m) return m.id == "CommentBadStreak3" end)
		if state.streaks.commentGood >= Config.Mental.mods.CommentGoodStreak3.streak then
			MentalService.addMod(state, "CommentGoodStreak3")
		end
	end
end

-- viral สองวันติดกัน → ViralStreak2
function MentalService.onViral(state)
	if state.day == state.lastViralDay + 1 then
		MentalService.addMod(state, "ViralStreak2")
	end
	state.lastViralDay = state.day
end

-- นับชั่วโมงตื่น (เรียกทุก onHour) — ครบ 20 → NoSleep จนกว่าจะนอน
function MentalService.onHourAwake(state)
	state.awakeHours += 1
	if state.awakeHours >= Config.Mental.awakeHoursForNoSleep then
		MentalService.addMod(state, "NoSleep")
	end
end

function MentalService.onSleep(state)
	state.awakeHours = 0
	removeMods(state, function(m) return Config.Mental.mods[m.id].untilEvent == "sleep" end)
end

-- Canon event trigger → drain แรงขึ้น 1 วัน
function MentalService.onCanonEvent(state)
	MentalService.addMod(state, "CanonEvent")
end

-- Activity system (แทน Thai mini-games — design doc §9): Interact_Bed/Kitchen/Exercise
local ACTIVITY_REASON = { Bed = "activityRest", Kitchen = "activityEat", Exercise = "activityExercise" }

-- คืน true ถ้าทำได้ (client ค่อยเล่น cutscene 5-10 วิ) — ติดกันเกิน maxStreak = cooldown ข้ามวัน
function MentalService.doActivity(state, name): boolean
	local reason = ACTIVITY_REASON[name]
	if not reason then return false end
	if state.day < state.activity.cooldownUntilDay then return false end
	state.activity.streak += 1
	if state.activity.streak >= Config.Mental.activity.maxStreak then
		state.activity.cooldownUntilDay = state.day + Config.Mental.activity.cooldownDays
		state.activity.streak = 0
	end
	MentalService.apply(state, reason)
	return true
end

return MentalService
