-- CommentService.luau — comment หลังอัปคลิป + การตอบ = **ช่องทางเดียวที่นับ choice %** (design doc §6)
-- pool ข้อความอยู่ Content/Comments.luau — ทีมเติมได้ไม่แตะไฟล์นี้
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")
local Comments = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Content.Comments)
	else require("../../shared/Content/Comments")

local CommentService = {}

-- เรียกหลัง uploadClip สำเร็จ (wiring ใน Main) — สุ่ม comment จาก pool เข้าคิวรอตอบ
function CommentService.generate(state, rng)
	rng = rng or math.random
	for _ = 1, Config.CommentsPerClip do
		table.insert(state.pendingComments, { id = math.floor(rng() * #Comments) + 1 })
	end
end

-- ตอบใบแรกในคิว: tag อ่านจาก Content ฝั่ง server (client โกง tag ไม่ได้)
-- คืน tag ("pos"|"neu"|"neg") หรือ nil ถ้าคิวว่าง/reply มั่ว — Main เอา tag ไปหัก/บวก mental ต่อ
function CommentService.answer(state, action)
	local pending = state.pendingComments[1]
	if not pending then return nil end
	local comment = Comments[pending.id]
	local reply = comment and comment.replies[tonumber(action.reply) or 0]
	if not reply then return nil end
	table.remove(state.pendingComments, 1)
	state.choices[reply.tag] += 1
	return reply.tag
end

return CommentService
