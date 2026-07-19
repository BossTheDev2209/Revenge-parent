-- Formulas.luau — สมองคณิตทั้งเกม: pure function ล้วน ห้ามแตะ state / Roblox API
--
-- ตัวเลขทุกตัวอ่านจาก Config.luau (ห้าม hardcode)
-- จุดสุ่มทุกจุดรับ rng() -> [0,1) เป็น parameter (default math.random) เพื่อให้เทส fix ค่าได้
-- เทส: tests/RunTests.luau (รันด้วย lune หรือใน Studio)
local isStudio = script ~= nil
local Config = if isStudio then require(script.Parent.Config) else require("./Config")

local Formulas = {}

-- design doc §1: เฟสตัดจาก follower ปัจจุบันเท่านั้น
function Formulas.phaseFor(followers: number): number
	for _, g in Config.PhaseGates do
		if followers < g.max then return g.phase end
	end
	return Config.PhaseGates[#Config.PhaseGates].phase -- ถึง/เกิน 1M ค้างเฟสสุดท้าย
end

-- design doc §2: accuracy 0–200 → tier C/B/A/S
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

-- design doc §3: 3 โซน — 70-100 ×1.0-1.25 (cap จงใจ), 40-69 ×1.0, 1-39 ×0.6-1.0
function Formulas.mentalMultiplier(pct: number, rng)
	rng = rng or math.random
	for _, z in Config.Mental.zones do
		if pct >= z.min then
			return z.multMin + (z.multMax - z.multMin) * rng()
		end
	end
	return 0 -- mental 0: MentalService ยิง Bad End 2 — สูตรแค่คืน 0
end

-- design doc §2: follower ต่อคลิป = base(สุ่มตามเฟส) × VidQ × mental แล้วลุ้น viral
-- ลำดับเรียก rng (เทสอิงลำดับนี้ ห้ามสลับ): ① base ② mentalZone ③ viralChance ④ viralMult
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

-- design doc §4: เงิน = follower ที่ได้จากคลิป × rate ของเฟส
function Formulas.moneyGain(followers: number, phase: number): number
	return math.floor(followers * Config.MoneyRatePerFollower[phase])
end

-- PDF หน้า 6: sponsor จ่าย = เงินคลิปเฉลี่ย (base กลางเฟส, tier B) × 2–4 (สุ่ม)
function Formulas.sponsorPay(phase: number, rng): number
	rng = rng or math.random
	local b = Config.FollowerBase[phase]
	local avgClipMoney = (b.min + b.max) / 2 * Config.MoneyRatePerFollower[phase]
	return math.floor(avgClipMoney * (2 + 2 * rng()))
end

-- เช็คเงื่อนไขฝั่ง VidQ % ของ ending หนึ่งตัว (เงื่อนไขไหนไม่ระบุใน Config = ไม่เช็ค)
local function vidqPass(c, v): boolean
	if not c then return false end
	if c.cMin and v.C < c.cMin then return false end
	if c.cMax and v.C > c.cMax then return false end
	if c.bMax and v.B > c.bMax then return false end
	if c.aMin and v.A < c.aMin then return false end
	if c.sMax and v.S > c.sMax then return false end
	return true
end

-- เช็คเงื่อนไขฝั่ง choice % (pos + neu + neg = 100)
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

-- design doc §5: stats = { vidq = {C,B,A,S}, choice = {pos,neu,neg} } หน่วย % (0–100)
-- ไล่ตาม Config.EndingPriority คืนตัวแรกที่เข้าเงื่อนไข
-- Bad1 (เงิน) / Bad2 (mental) ไม่มี threshold ในตาราง — trigger สดกลางเกม ข้ามในลูปนี้
function Formulas.resolveEnding(stats): string
	for _, name in Config.EndingPriority do
		local e = Config.EndingThresholds[name]
		if e then
			local v = vidqPass(e.vidq, stats.vidq)
			local c = choicePass(e.choice, stats.choice)
			-- Good1 ต้องผ่านทั้งสองฝั่ง (AND) — ที่เหลือฝั่งเดียวพอ (OR) ตาม design doc §5
			local hit = if name == "Good1" then (v and c) else (v or c)
			if hit then return name end
		end
	end
	return "Neutral2" -- ถึง 1M แต่ไม่เข้าเงื่อนไขไหน — ending กลางสุดคือตาข่ายสุดท้าย
end

return Formulas
