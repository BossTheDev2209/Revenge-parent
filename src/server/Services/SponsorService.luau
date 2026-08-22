-- SponsorService.luau — งาน sponsor แบบ notification (แก้ดีไซน์ 9 ส.ค. user)
--
-- ดีไซน์เดิม (PDF หน้า 6): offer เด้ง → เปิดแอปปฏิทิน → เลือกวางลงวันว่าง → ถึงวันนั้นเงินก้อนเข้า
-- ดีไซน์ใหม่: offer เด้งเป็น toast มุมขวาล่าง → **กดรับปุ๊บได้ buff ทันที** ไม่ต้องเลือกวันอะไรทั้งนั้น
--   buff = เงินจากคลิปที่อัปโหลด ×Config.SponsorBuffMult นาน Config.SponsorBuffDays วัน
--   (คูณเฉพาะเงิน ไม่แตะ follower — สูตร follower ล็อกอยู่ใน docs/02 §2 ห้ามขยับ)
--
-- ★ ระบบปฏิทินเดิม (วางงานลงวัน) ถอดออกแล้ว 22 ส.ค. 2569 — เหลือ toast กดรับทันที
--
-- เงื่อนไขสุ่ม offer ยังเป็นของเดิมทุกตัว (Config.SponsorOffer*) — ไม่ได้ขยับ balance ฝั่งนั้น
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
-- DM content — server ต้องอ่านเองเพื่อรู้ว่า payoutId แต่ละตัวผูกกับ milestone เท่าไหร่
-- (ห้ามให้ client ส่ง milestone/จำนวนเงินมาเอง — นี่คือ action แรกของ DM ที่จ่ายเงินจริง)
local DMs = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.DMs)
	else require("../../shared/Content/DMs")

local SponsorService = {}

-- สุ่ม offer รายวัน: เฟส 2-3 + ปลดล็อค 10K → 5%/วัน · มีค้างได้ทีละใบ
function SponsorService.rollOffer(state, rng): boolean
	if state.sponsorOffer then return false end
	if state.phase < Config.SponsorOfferMinPhase then return false end
	if state.follower < Config.SponsorUnlockFollowers then return false end
	if rng() >= Config.SponsorOfferChance then return false end
	state.sponsorOffer = true
	return true
end

-- กดรับงานจาก toast → buff เริ่มทันที ไม่ต้องเลือกวัน
-- ไม่มี offer ค้าง = กดไม่ได้ (กันปั๊มเงินจาก client ปลอม action — server ตัดสิน ไม่เชื่อ client)
-- กดทับตอน buff ยังไม่หมด = ต่ออายุจากวันปัจจุบัน (ไม่สะสมทบ กันยิงรัวแล้วบวฟยาวข้ามสัปดาห์)
function SponsorService.accept(state): boolean
	if not state.sponsorOffer then return false end
	if state.follower < Config.SponsorUnlockFollowers then return false end
	state.sponsorOffer = false
	state.sponsorBuffUntilDay = state.day + Config.SponsorBuffDays
	return true
end

-- ขึ้นวันใหม่: offer ที่ไม่กดรับหมดอายุ แล้วค่อยสุ่มใบใหม่
-- ★ ต้องล้างก่อนสุ่ม ไม่งั้น offer ค้างตลอดกาล = สุ่มใบใหม่ไม่ได้อีกเลย
--   (ระบบเดิมมีแอปปฏิทินให้เปิดไปกดทีหลังได้ ระบบใหม่มีแค่ toast — พลาดแล้วพลาดเลย ต้องปล่อยหมดอายุ)
-- คืน true ถ้าได้ offer ใบใหม่ (Main เอาไป push ให้ client เด้ง toast)
function SponsorService.onDay(state, rng): boolean
	state.sponsorOffer = false
	return SponsorService.rollOffer(state, rng)
end

-- buff ยังทำงานอยู่ไหม (ให้ HUD/UI ถามได้ — ตัวคูณจริงอยู่ที่ Formulas.sponsorMult)
function SponsorService.buffActive(state): boolean
	return state.day < (state.sponsorBuffUntilDay or 0)
end

-- ===== เงินก้อน sponsor ตาม milestone (12 ส.ค. 2569, user) =====
-- ต่างจาก buff ด้านบน: buff = สุ่มรายวัน ×2 ชั่วคราว · อันนี้ = ก้อนเดียว ครั้งเดียวถาวรต่อ payoutId
--
-- ⚠️ นี่คือ action แรกที่ให้เงินจาก DM (DM เป็น cosmetic ล้วนมาตลอด) → ตรวจฝั่ง server ทุกชั้น
--    ห้ามเชื่อ client เลยแม้แต่ตัวเดียว: client ส่งมาแค่ `id` เท่านั้น จำนวนเงิน/milestone อ่านจากของเราเอง
--    1) id ต้องเป็น string และมีอยู่จริงใน Config.DMPayouts (ยิง id มั่ว = ไม่ได้เงิน)
--    2) ต้องมีก้อน DM ที่ผูก payoutId นั้นจริง (กัน Config กับ content หลุดจากกัน)
--    3) follower ต้องถึง milestone ของ DM ก้อนนั้นจริง (กดก่อนถึงยอด = ไม่ได้)
--    4) ยังไม่เคยรับ (state.dmClaimed) — กันกดรัวซ้ำ
-- คืน (สำเร็จไหม, จำนวนเงินที่จ่าย)
function SponsorService.claimDM(state, id): (boolean, number)
	if type(id) ~= "string" then return false, 0 end
	local amount = Config.DMPayouts[id]
	if type(amount) ~= "number" or amount <= 0 then return false, 0 end

	state.dmClaimed = state.dmClaimed or {} -- save เก่าไม่มี field นี้ (mergeDefaults เติมให้อยู่แล้ว แต่กันไว้)
	if state.dmClaimed[id] then return false, 0 end

	local need = nil
	for _, dm in DMs do
		if dm.payoutId == id then
			need = dm.unlockFollower or 0
			break
		end
	end
	if need == nil then return false, 0 end -- Config มี แต่ไม่มี DM ผูก = ของเสีย ไม่จ่าย
	if (state.follower or 0) < need then return false, 0 end

	state.dmClaimed[id] = true
	state.money += amount
	return true, amount
end

-- DM ก้อนนี้กดรับเงินได้ไหมตอนนี้ (client ใช้ตัดสินว่าจะโชว์ปุ่มไหม — server ตัดสินซ้ำตอนกดอยู่ดี)
function SponsorService.canClaimDM(state, id): boolean
	if type(id) ~= "string" or not Config.DMPayouts[id] then return false end
	if state.dmClaimed and state.dmClaimed[id] then return false end
	for _, dm in DMs do
		if dm.payoutId == id then return (state.follower or 0) >= (dm.unlockFollower or 0) end
	end
	return false
end

return SponsorService
