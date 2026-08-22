-- RecordService — อัดคลิป: คลิกเก็บ footage (GB) ตามระดับกล้อง + bonus + โซนถ่าย
-- pure ทั้งไฟล์ (รับ now/rng เป็น arg) · ตัวเลขมาจาก Config.Record / Config.StorageLadderGB
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../shared/Formulas")

local RecordService = {}

function RecordService.capacity(state): number
	local lv = Formulas.activeLevel(state, "storage")
	return Config.StorageLadderGB[lv] or Config.StorageLadderGB[1]
end

function RecordService.zoneMult(phase: number): number
	return Config.Record.zoneMultByPhase[phase] or 1
end

-- GB ต่อคลิก: base[กล้อง] × (bonus? ×2.4) × (ในโซน? ×เฟส)
function RecordService.gainFor(cameraLevel: number, bonus: boolean, zoneMult: number): number
	local R = Config.Record
	local base = R.footagePerClickGB[cameraLevel] or R.footagePerClickGB[1]
	local gb = base * (bonus and R.bonusMult or 1) * (zoneMult or 1)
	return math.floor(gb * 100 + 0.5) / 100 -- ปัด 2 ตำแหน่ง กัน float error สะสม
end

function RecordService.isFull(state): boolean
	return (state.footageGB or 0) >= RecordService.capacity(state)
end

-- คลิกอัด 1 ครั้ง · o = { now, inZone, rng } · คืน { ok, gained, bonus, full, qte, reason }
function RecordService.record(state, o)
	o = o or {}
	local now = o.now or 0
	local R = Config.Record

	if now - (state.lastRecordAt or -math.huge) < R.clickCooldownSeconds - 1e-6 then
		return { ok = false, gained = 0, bonus = false, full = false, reason = "cooldown" }
	end
	if RecordService.isFull(state) then
		return { ok = false, gained = 0, bonus = false, full = true, reason = "full" }
	end

	local rng = o.rng or math.random
	local bonus = rng() < R.bonusChance
	local mult = o.inZone and RecordService.zoneMult(state.phase) or 1
	local gain = RecordService.gainFor(Formulas.activeLevel(state, "camera"), bonus, mult)

	local cap = RecordService.capacity(state)
	local gained = math.min(gain, cap - (state.footageGB or 0)) -- ตัดให้พอดี cap
	state.footageGB = (state.footageGB or 0) + gained
	state.lastRecordAt = now

	-- QTE เฉพาะคลิกที่ยังไม่เต็ม (ไม่งั้น reward footage โดน cap เป็น 0 เปล่าประโยชน์)
	local qte = not RecordService.isFull(state) and rng() < Config.RecordQTE.chance

	return { ok = true, gained = gained, bonus = bonus, full = RecordService.isFull(state), qte = qte, reason = nil }
end

-- จำนวนครั้งที่ต้องกดของ RecordQTE ครั้งหนึ่ง — สุ่ม min..max uniform
function RecordService.pickHitsRequired(min: number, max: number, rng): number
	rng = rng or math.random
	return min + math.floor(rng() * (max - min + 1))
end

-- reward QTE — grades = { "perfect"|"good"|"miss", ... } (1 ค่าต่อครั้งที่กด)
-- Perfect ครบทุกรอบ = ได้ rewardMultMax เป๊ะ ไม่ว่า N เท่าไหร่ (เพดานคงที่)
function RecordService.qteReward(cameraLevel: number, grades: { string }): number
	local R, Q = Config.Record, Config.RecordQTE
	local base = R.footagePerClickGB[cameraLevel] or R.footagePerClickGB[1]
	local n = #grades
	if n == 0 then return 0 end
	local perRound = Q.rewardMultMax / n
	local totalMult = 0
	for _, g in grades do
		if g == "perfect" then
			totalMult += perRound
		elseif g == "good" then
			totalMult += perRound * Q.goodRewardRatio
		end
	end
	return base * totalMult
end

-- ให้ reward QTE จริง — cap ด้วย storage เหมือน record()
function RecordService.grantQTE(state, grades: { string })
	local lv = Formulas.activeLevel(state, "camera")
	local reward = RecordService.qteReward(lv, grades)
	local cap = RecordService.capacity(state)
	local gained = math.min(reward, math.max(0, cap - (state.footageGB or 0)))
	state.footageGB = (state.footageGB or 0) + gained
	return { gained = gained, grades = grades }
end

-- ขนาดเล็กสุดที่ตัดคลิปได้ (gate เปิดหน้าตัดต่อ)
function RecordService.minClipGB(): number
	local sizes = Config.ClipSizes
	return (sizes and sizes[1] and sizes[1].gb) or Config.Record.footagePerClipGB
end

function RecordService.canEdit(state, footageGB): boolean
	local cost = tonumber(footageGB) or Config.Record.footagePerClipGB
	return (state.footageGB or 0) >= cost
end

-- หัก footage เพื่อตัด 1 คลิป — ไม่พอ = false (Main ไม่สร้างคลิป ไม่หักใจ)
function RecordService.spendForClip(state, footageGB): boolean
	local cost = tonumber(footageGB) or Config.Record.footagePerClipGB
	if (state.footageGB or 0) < cost then return false end
	state.footageGB -= cost
	return true
end

-- สุ่มจุดถ่ายถัดไป เลี่ยงจุดเดิม
function RecordService.pickSpot(spots, rng, current): string?
	if #spots == 0 then return nil end
	if #spots == 1 then return spots[1] end
	local pool = {}
	for _, s in spots do
		if s ~= current then table.insert(pool, s) end
	end
	return pool[math.floor((rng or math.random)() * #pool) + 1]
end

-- โซนหมดอายุ (120 วิ) → ย้ายจุด · คืน true ถ้าย้ายจริง
function RecordService.tickZone(state, now: number, spots, rng): boolean
	local z = state.filmZone
	if z and z.spot and now < (z.expiresAt or 0) then return false end
	local spot = RecordService.pickSpot(spots, rng, z and z.spot)
	if not spot then return false end
	state.filmZone = { spot = spot, expiresAt = now + Config.Record.zoneDurationSeconds }
	return true
end

return RecordService
