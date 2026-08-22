-- ActionRouter — client action ทุกอันวิ่งผ่านที่นี่เส้นเดียว
-- เพิ่มฟีเจอร์ = register(type, fn) ตอน boot ใน Main · ห้ามสร้าง RemoteEvent เพิ่ม
local ActionRouter = {}
local handlers = {}

function ActionRouter.register(actionType: string, fn)
	assert(handlers[actionType] == nil, "handler ซ้ำ: " .. actionType)
	handlers[actionType] = fn
end

-- คืน true ถ้ามี handler รับ · action เพี้ยน/ไม่รู้จัก = false (ไม่ crash — client ส่งมั่วได้)
function ActionRouter.route(state, action, player): boolean
	local h = type(action) == "table" and action.type and handlers[action.type]
	if not h then
		warn("[ActionRouter] action ไม่รู้จัก:", action and tostring(action.type) or "nil")
		return false
	end
	h(state, action, player)
	return true
end

return ActionRouter
