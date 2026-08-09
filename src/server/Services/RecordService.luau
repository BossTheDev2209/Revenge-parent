-- RecordService.luau — ระบบอัดคลิป: คลิกเก็บ footage (GB) ตามระดับกล้อง + bonus + โซนถ่าย
-- ตัวเลขทุกตัวมาจาก docs/02 §9.5 ผ่าน Config.Record / Config.StorageLadderGB ห้าม hardcode ที่นี่
-- pure ทั้งไฟล์ (รับ now/rng เป็น arg) — เทสด้วย lune ได้ทั้งหมด ไม่มี Roblox API
-- ไม่เรียก push / ไม่ require service อื่น — Main compose
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Formulas = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Formulas)
	else require("../../shared/Formulas")

local RecordService = {}

-- ความจุที่เก็บตามระดับที่ซื้อ (Shop สาย storage)
function RecordService.capacity(state): number
	local lv = Formulas.activeLevel(state, "storage")
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
	local gain = RecordService.gainFor(Formulas.activeLevel(state, "camera"), bonus, mult)

	-- ล้นความจุ = ตัดให้พอดี (คลิกสุดท้ายไม่หายเปล่า แต่ไม่เกิน cap)
	local cap = RecordService.capacity(state)
	local gained = math.min(gain, cap - (state.footageGB or 0))
	state.footageGB = (state.footageGB or 0) + gained
	state.lastRecordAt = now

	-- สุ่มเจอ QTE skill-check (docs/02 §9.5) — เฉพาะคลิกที่ยังไม่เต็ม (ไม่งั้น reward footage โดน cap เป็น 0 เปล่าประโยชน์)
	local qte = not RecordService.isFull(state) and rng() < Config.RecordQTE.chance

	return { ok = true, gained = gained, bonus = bonus, full = RecordService.isFull(state), qte = qte, reason = nil }
end

-- จำนวนรอบ (bounce) ของ RecordQTE หนึ่งครั้ง — สุ่ม min..max แบบ uniform (pure, เทสได้)
function RecordService.pickRounds(min: number, max: number, rng): number
	rng = rng or math.random
	return min + math.floor(rng() * (max - min + 1))
end

-- ===== RecordQTE reward (docs/02 §9.5 v2) — footage bonus สะสมจากหลายรอบ เพดานรวม rewardMultMax =====
-- grades = { "perfect"|"good"|"miss", ... } (1 ค่าต่อรอบ ยาว = จำนวนรอบที่เล่นจริง)
--   ต่อรอบ Perfect = rewardMultMax/N · Good = ×goodRewardRatio ของนั้น · Miss = 0 (ไม่ลงโทษ)
--   ผลรวม: ทำ Perfect ครบทุกรอบ = ได้ rewardMultMax เป๊ะ ไม่ว่า N จะเป็นเท่าไหร่ (เพดานคงที่)
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

-- ให้ reward QTE จริง — cap ด้วย storage เหมือน record() (footage ไม่ล้นถัง) · คืน { gained, grades }
function RecordService.grantQTE(state, grades: { string })
	local lv = Formulas.activeLevel(state, "camera")
	local reward = RecordService.qteReward(lv, grades)
	local cap = RecordService.capacity(state)
	local gained = math.min(reward, math.max(0, cap - (state.footageGB or 0)))
	state.footageGB = (state.footageGB or 0) + gained
	return { gained = gained, grades = grades }
end

-- ===== วงจรปิด: footage → คลิป (unlock 8 ส.ค. — ขนาดแปรผัน docs/02 §9.5) =====
-- ขนาดเล็กสุดที่ตัดได้ (gate เปิดหน้าตัดต่อ) = แถวแรกของ ClipSizes
function RecordService.minClipGB(): number
	local sizes = Config.ClipSizes
	return (sizes and sizes[1] and sizes[1].gb) or Config.Record.footagePerClipGB
end

-- footage พอตัดคลิปขนาด footageGB ไหม (default = 32 baseline, backward-compat)
function RecordService.canEdit(state, footageGB): boolean
	local cost = tonumber(footageGB) or Config.Record.footagePerClipGB
	return (state.footageGB or 0) >= cost
end

-- หัก footage เพื่อตัด 1 คลิปขนาด footageGB — ไม่พอ = false (Main ไม่สร้างคลิป ไม่หักใจ)
-- footageGB ไม่ส่ง = 32 (backward-compat) · client ส่งขนาดที่ผู้เล่นเลือก
function RecordService.spendForClip(state, footageGB): boolean
	local cost = tonumber(footageGB) or Config.Record.footagePerClipGB
	if (state.footageGB or 0) < cost then return false end
	state.footageGB -= cost
	return true
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
