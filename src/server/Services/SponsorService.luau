-- SponsorService.luau — งาน sponsor แบบ notification (แก้ดีไซน์ 9 ส.ค. user)
--
-- ดีไซน์เดิม (PDF หน้า 6): offer เด้ง → เปิดแอปปฏิทิน → เลือกวางลงวันว่าง → ถึงวันนั้นเงินก้อนเข้า
-- ดีไซน์ใหม่: offer เด้งเป็น toast มุมขวาล่าง → **กดรับปุ๊บได้ buff ทันที** ไม่ต้องเลือกวันอะไรทั้งนั้น
--   buff = เงินจากคลิปที่อัปโหลด ×Config.SponsorBuffMult นาน Config.SponsorBuffDays วัน
--   (คูณเฉพาะเงิน ไม่แตะ follower — สูตร follower ล็อกอยู่ใน docs/02 §2 ห้ามขยับ)
--
-- ★ ปฏิทินถูก "พับ" ไม่ใช่ลบ: `CalendarService.luau` + `CalendarApp.luau` ยังอยู่ครบ
--   แค่ถอด wiring ออกจาก Main.server/Main.client — จะรื้อกลับมาต่อ wire 4 บรรทัดเดิม
--
-- เงื่อนไขสุ่ม offer ยังเป็นของเดิมทุกตัว (Config.SponsorOffer*) — ไม่ได้ขยับ balance ฝั่งนั้น
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")

local SponsorService = {}

-- สุ่ม offer รายวัน: เฟส 2-3 + ปลดล็อค 10K → 5%/วัน · มีค้างได้ทีละใบ
-- (ย้ายมาจาก CalendarService.rollSponsorOffer ตอนพับปฏิทิน — เงื่อนไขเหมือนเดิมเป๊ะ)
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

return SponsorService
