-- CommentService — comment หลังอัปคลิป + การตอบ = ช่องทางเดียวที่นับ choice % (design doc §6)
-- slot ⊖/◎/⊕ อย่างละใบ ทอยแยกอิสระตามเกรดคลิป · pool ข้อความอยู่ Content/Comments
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Comments = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.Comments)
	else require("../../shared/Content/Comments")

local CommentService = {}

-- แยก pool ตาม sentiment ครั้งเดียวตอนโหลด
local poolBy = { neg = {}, neu = {}, pos = {} }
for id, c in Comments do
	if poolBy[c.sentiment] then
		table.insert(poolBy[c.sentiment], id)
	end
end

local SLOT_ORDER = { "neg", "neu", "pos" } -- ลำดับทอยตายตัว (เทส deterministic)

-- ทอยแยก slot ละ sentiment ตามเกรดคลิป
function CommentService.generate(state, tier, rng)
	rng = rng or math.random
	local chances = Config.Comments.chanceByTier[tier]
	if not chances then return end
	for _, sentiment in SLOT_ORDER do
		if rng() < chances[sentiment] and #poolBy[sentiment] > 0 then
			local pick = poolBy[sentiment][math.floor(rng() * #poolBy[sentiment]) + 1]
			table.insert(state.pendingComments, { id = pick, sentiment = sentiment })
		end
	end
end

-- response ที่อนุญาตต่อ sentiment (server ตัดสิน client โกงไม่ได้)
local ALLOWED = {
	pos = { heart = "heartPos" },
	neg = { heart = "heartNeg", accept = "accept", sarcasm = "sarcasm", insult = "insult" },
	neu = { accept = "accept", sarcasm = "sarcasm" },
}

-- ตอบใบแรกในคิว · คืน (handled, countTag|nil, mentalReason|nil) — skip = handled แต่ไม่นับ
function CommentService.answer(state, action)
	local pending = state.pendingComments[1]
	if not pending then return false end
	if action.response == "skip" then
		table.remove(state.pendingComments, 1)
		return true, nil, nil
	end
	local kind = ALLOWED[pending.sentiment] and ALLOWED[pending.sentiment][action.response]
	if not kind then return false end
	table.remove(state.pendingComments, 1)
	local tag = Config.Comments.countAs[kind]
	if tag then state.choices[tag] += 1 end
	local reason = "comment" .. kind:sub(1, 1):upper() .. kind:sub(2) -- heartPos → commentHeartPos
	return true, tag, reason
end

return CommentService
