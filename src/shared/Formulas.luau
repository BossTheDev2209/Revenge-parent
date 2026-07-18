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

return Formulas
