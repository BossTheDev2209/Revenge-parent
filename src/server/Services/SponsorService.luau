-- SponsorService — งาน sponsor แบบ notification (toast กดรับ → buff เงิน ×Mult ทันที)
-- buff คูณเฉพาะเงิน ไม่แตะ follower (สูตร follower ล็อก docs/02 §2)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
-- server อ่าน DM เองเพื่อรู้ว่า payoutId ผูกกับ milestone เท่าไหร่ (ห้ามเชื่อ client)
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

-- กดรับ → buff เริ่มทันที · กดทับตอนยังไม่หมด = ต่ออายุจากวันนี้ (ไม่สะสมทบ)
function SponsorService.accept(state): boolean
	if not state.sponsorOffer then return false end
	if state.follower < Config.SponsorUnlockFollowers then return false end
	state.sponsorOffer = false
	state.sponsorBuffUntilDay = state.day + Config.SponsorBuffDays
	return true
end

-- ขึ้นวันใหม่: offer ที่ไม่กดรับหมดอายุก่อน แล้วค่อยสุ่มใบใหม่
-- (มีแค่ toast ไม่มีปฏิทินให้เปิดทีหลัง — ค้างไว้ = สุ่มใบใหม่ไม่ได้ตลอดกาล)
function SponsorService.onDay(state, rng): boolean
	state.sponsorOffer = false
	return SponsorService.rollOffer(state, rng)
end

function SponsorService.buffActive(state): boolean
	return state.day < (state.sponsorBuffUntilDay or 0)
end

-- เงินก้อน sponsor ตาม milestone — ก้อนเดียว ครั้งเดียวต่อ payoutId
-- client ส่งมาแค่ id · ตรวจครบ: id ใน DMPayouts, มี DM ผูกจริง, follower ถึง, ยังไม่เคยรับ
-- คืน (สำเร็จ, จำนวนเงิน)
function SponsorService.claimDM(state, id): (boolean, number)
	if type(id) ~= "string" then return false, 0 end
	local amount = Config.DMPayouts[id]
	if type(amount) ~= "number" or amount <= 0 then return false, 0 end

	state.dmClaimed = state.dmClaimed or {}
	if state.dmClaimed[id] then return false, 0 end

	local need = nil
	for _, dm in DMs do
		if dm.payoutId == id then
			need = dm.unlockFollower or 0
			break
		end
	end
	if need == nil then return false, 0 end -- Config มี แต่ไม่มี DM ผูก = ของเสีย
	if (state.follower or 0) < need then return false, 0 end

	state.dmClaimed[id] = true
	state.money += amount
	return true, amount
end

-- DM ก้อนนี้กดรับเงินได้ไหมตอนนี้ (client โชว์ปุ่ม · server ตัดสินซ้ำตอนกดอยู่ดี)
function SponsorService.canClaimDM(state, id): boolean
	if type(id) ~= "string" or not Config.DMPayouts[id] then return false end
	if state.dmClaimed and state.dmClaimed[id] then return false end
	for _, dm in DMs do
		if dm.payoutId == id then return (state.follower or 0) >= (dm.unlockFollower or 0) end
	end
	return false
end

return SponsorService
