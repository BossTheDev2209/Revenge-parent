-- RecordService.luau — ระบบอัดคลิป: คลิกเก็บ footage (GB) ตามระดับกล้อง + bonus + โซนถ่าย
-- ตัวเลขทุกตัวมาจาก docs/02 §9.5 ผ่าน Config.Record / Config.StorageLadderGB ห้าม hardcode ที่นี่
-- pure ทั้งไฟล์ (รับ now/rng เป็น arg) — เทสด้วย lune ได้ทั้งหมด ไม่มี Roblox API
-- ไม่เรียก push / ไม่ require service อื่น — Main compose
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")

local RecordService = {}

-- ความจุที่เก็บตามระดับที่ซื้อ (Shop สาย storage)
function RecordService.capacity(state): number
	local lv = state.upgrades and state.upgrades.storage or 1
	return Config.StorageLadderGB[lv] or Config.StorageLadderGB[1]
end

function RecordService.zoneMult(phase: number): number
	return Config.Record.zoneMultByPhase[phase] or 1
end

-- GB ต่อคลิก 1 ครั้ง (docs/02 §9.5): base[กล้อง] × (bonus? ×2.4) × (ในโซน? ×เฟส)
function RecordService.gainFor(cameraLevel: number, bonus: boolean, zoneMult: number): number
	local R = Config.Record
	local base = R.footagePerClickGB[cameraLevel] or R.footagePerClickGB[1]
	local gb = base * (bonus and R.bonusMult or 1) * (zoneMult or 1)
	return math.floor(gb * 100 + 0.5) / 100 -- ปัด 2 ตำแหน่ง กัน float error สะสม (×2.4 ไม่ลงตัวฐาน 2)
end

-- storage เต็มแล้วหรือยัง (HUD โชว์ FULL, อัดต่อไม่ได้)
function RecordService.isFull(state): boolean
	return (state.footageGB or 0) >= RecordService.capacity(state)
end

-- คลิกอัด 1 ครั้ง
-- o = { now = os.clock(), inZone = bool, rng = function }
-- คืน { ok, gained, bonus, full, reason } — reason: "cooldown" | "full"
function RecordService.record(state, o)
	o = o or {}
	local now = o.now or 0
	local R = Config.Record

	-- เผื่อ 1e-6 กันกดพอดีเป๊ะแล้วโดนปัดตกเพราะ float
	if now - (state.lastRecordAt or -math.huge) < R.clickCooldownSeconds - 1e-6 then
		return { ok = false, gained = 0, bonus = false, full = false, reason = "cooldown" }
	end
	if RecordService.isFull(state) then
		return { ok = false, gained = 0, bonus = false, full = true, reason = "full" }
	end

	local rng = o.rng or math.random
	local bonus = rng() < R.bonusChance
	local mult = o.inZone and RecordService.zoneMult(state.phase) or 1
	local gain = RecordService.gainFor(state.upgrades and state.upgrades.camera or 1, bonus, mult)

	-- ล้นความจุ = ตัดให้พอดี (คลิกสุดท้ายไม่หายเปล่า แต่ไม่เกิน cap)
	local cap = RecordService.capacity(state)
	local gained = math.min(gain, cap - (state.footageGB or 0))
	state.footageGB = (state.footageGB or 0) + gained
	state.lastRecordAt = now

	return { ok = true, gained = gained, bonus = bonus, full = RecordService.isFull(state), reason = nil }
end

-- สุ่มจุดถ่ายถัดไป เลี่ยงจุดเดิม (กันโซน spawn ที่เดิมซ้ำ)
function RecordService.pickSpot(spots, rng, current): string?
	if #spots == 0 then return nil end
	if #spots == 1 then return spots[1] end
	local pool = {}
	for _, s in spots do
		if s ~= current then table.insert(pool, s) end
	end
	return pool[math.floor((rng or math.random)() * #pool) + 1]
end

-- เรียกทุก frame/tick: โซนหมดอายุ (120 วิ) → ย้ายจุด คืน true ถ้าย้ายจริง (client ไปวาดวงใหม่)
function RecordService.tickZone(state, now: number, spots, rng): boolean
	local z = state.filmZone
	if z and z.spot and now < (z.expiresAt or 0) then return false end
	local spot = RecordService.pickSpot(spots, rng, z and z.spot)
	if not spot then return false end
	state.filmZone = { spot = spot, expiresAt = now + Config.Record.zoneDurationSeconds }
	return true
end

return RecordService
