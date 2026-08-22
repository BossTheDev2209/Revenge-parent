-- Formulas — สมองคณิตทั้งเกม: pure function ล้วน ห้ามแตะ state / Roblox API
-- ตัวเลขอ่านจาก Config (ห้าม hardcode) · จุดสุ่มรับ rng()->[0,1) เป็น arg เพื่อให้เทส fix ค่าได้
local isStudio = script ~= nil
local Config = if isStudio then require(script.Parent.Config) else require("./Config")

local Formulas = {}

-- เฟสตัดจาก follower ปัจจุบันเท่านั้น
function Formulas.phaseFor(followers: number): number
	for _, g in Config.PhaseGates do
		if followers < g.max then return g.phase end
	end
	return Config.PhaseGates[#Config.PhaseGates].phase
end

-- accuracy 0–200 → tier C/B/A/S
function Formulas.vidqTier(score: number): string
	score = math.clamp(score, 0, Config.MaxClipAccuracy)
	for _, t in Config.VidQTiers do
		if score <= t.maxAcc then return t.tier end
	end
	return Config.VidQTiers[#Config.VidQTiers].tier
end

function Formulas.vidqMultiplier(tier: string): number
	for _, t in Config.VidQTiers do
		if t.tier == tier then return t.mult end
	end
	error("unknown tier: " .. tostring(tier))
end

-- 3 โซน: 70-100 ×1.0-1.25 (cap จงใจ), 40-69 ×1.0, 1-39 ×0.6-1.0
function Formulas.mentalMultiplier(pct: number, rng)
	rng = rng or math.random
	for _, z in Config.Mental.zones do
		if pct >= z.min then
			return z.multMin + (z.multMax - z.multMin) * rng()
		end
	end
	return 0 -- mental 0: MentalService ยิง Bad End 2
end

-- follower ต่อคลิป = base(สุ่ม) × VidQ × mental แล้วลุ้น viral
-- ลำดับเรียก rng (เทสอิงลำดับนี้ ห้ามสลับ): base → mentalZone → viralChance → viralMult
function Formulas.followerGain(phase: number, tier: string, mentalPct: number, rng)
	rng = rng or math.random
	local b = Config.FollowerBase[phase]
	local base = b.min + (b.max - b.min) * rng()
	local n = base * Formulas.vidqMultiplier(tier) * Formulas.mentalMultiplier(mentalPct, rng)
	local isViral = rng() < Config.Viral.chance
	if isViral then
		n = n * (Config.Viral.multMin + (Config.Viral.multMax - Config.Viral.multMin) * rng())
	end
	return math.floor(n), isViral
end

-- ตัวคูณ reward ตามขนาดคลิป = gb / baseline (8→×0.25 … 128→×4)
function Formulas.clipSizeMult(footageGB: number): number
	local base = Config.Record.footagePerClipGB
	if not footageGB or footageGB <= 0 or base <= 0 then return 1 end
	return footageGB / base
end

-- เงิน = follower ที่ได้ × rate ของเฟส
function Formulas.moneyGain(followers: number, phase: number): number
	return math.floor(followers * Config.MoneyRatePerFollower[phase])
end

-- ตัวคูณเงินจาก buff sponsor — คูณเฉพาะเงิน ไม่แตะ follower · save เก่าไม่มี field = คืน 1
function Formulas.sponsorMult(state): number
	local untilDay = state and state.sponsorBuffUntilDay or 0
	local day = state and state.day or 0
	if day < untilDay then return Config.SponsorBuffMult end
	return 1
end

-- เงื่อนไขไหนไม่ระบุใน Config = ไม่เช็ค
local function vidqPass(c, v): boolean
	if not c then return false end
	if c.cMin and v.C < c.cMin then return false end
	if c.cMax and v.C > c.cMax then return false end
	if c.bMax and v.B > c.bMax then return false end
	if c.aMin and v.A < c.aMin then return false end
	if c.sMax and v.S > c.sMax then return false end
	return true
end

local function choicePass(c, ch): boolean
	if not c then return false end
	if c.spreadMax then return math.abs(ch.neg - ch.pos) + ch.neu < c.spreadMax end
	if c.posMin and ch.pos < c.posMin then return false end
	if c.negMin and ch.neg < c.negMin then return false end
	if c.negMax and ch.neg > c.negMax then return false end
	if c.neuMin and ch.neu < c.neuMin then return false end
	if c.neuMax and ch.neu > c.neuMax then return false end
	return true
end

-- stats = { vidq = {C,B,A,S}, choice = {pos,neu,neg} } % · ไล่ตาม EndingPriority คืนตัวแรกที่เข้า
-- Bad1/Bad2 ไม่มี threshold — trigger สดกลางเกม (EndingService) ข้ามในลูปนี้
function Formulas.resolveEnding(stats): string
	for _, name in Config.EndingPriority do
		local e = Config.EndingThresholds[name]
		if e then
			local v = vidqPass(e.vidq, stats.vidq)
			local c = choicePass(e.choice, stats.choice)
			local hit = if name == "Good1" then (v and c) else (v or c) -- Good1 = AND, ที่เหลือ OR
			if hit then return name end
		end
	end
	return "Neutral2" -- ถึง 1M แต่ไม่เข้าเงื่อนไขไหน — ตาข่ายสุดท้าย
end

-- ระดับอุปกรณ์ที่ใช้อยู่จริง — ทุกจุดต้องเรียกฟังก์ชันนี้ ห้ามอ่าน state.upgrades ตรงๆ
--   upgrades[key] = ระดับสูงสุดที่ซื้อ · equipped[key] = ระดับที่เลือกใช้ (ย้อนของเก่าได้)
--   equipped nil = ใช้ตัวสูงสุด · clamp ที่ owned เสมอ = save เพี้ยนก็ใช้เกินที่ซื้อไม่ได้
function Formulas.activeLevel(state, key: string): number
	local owned = state.upgrades and state.upgrades[key] or 1
	local picked = state.equipped and state.equipped[key]
	if not picked then return owned end
	return math.clamp(picked, 1, owned)
end

-- ของกิน (Config.Consumables) — shared เพราะ server (ตัดเงิน) + client (วาดโซน QTE) ใช้สูตรเดียวกัน
function Formulas.consumableByKey(key: string)
	for _, c in Config.Consumables do
		if c.key == key then return c end
	end
	return nil
end

-- ตัวคูณความกว้างโซน QTE จากของที่ออกฤทธิ์ — คืน (perfect, good) · คูณสะสมถ้ามีหลายชิ้น
function Formulas.qteZoneMult(state): (number, number)
	local perfect, good = 1, 1
	for key in (state and state.buffs) or {} do
		local item = Formulas.consumableByKey(key)
		if item then
			perfect *= item.qtePerfectMult or 1
			good *= item.qteGoodMult or 1
		end
	end
	return perfect, good
end

-- แอปบนจอคอม unlock ตามเฟสไหม — ไม่มีชื่อในตาราง = unlock เสมอ
function Formulas.appUnlocked(phase: number, appId: string): boolean
	local minPhase = Config.AppMinPhase[appId]
	return not minPhase or phase >= minPhase
end

return Formulas
