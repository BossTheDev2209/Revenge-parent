-- ActionRouter.luau — ประตูรับทุกการกระทำจาก client เส้นเดียว
-- service ลงทะเบียน handler ด้วย register(type, fn) ตอน boot (ใน Main)
-- เพิ่มฟีเจอร์ใหม่ = register type ใหม่ — ห้ามสร้าง RemoteEvent เพิ่ม (docs/06 §3)
local ActionRouter = {}
local handlers = {}

function ActionRouter.register(actionType: string, fn)
	assert(handlers[actionType] == nil, "handler ซ้ำ: " .. actionType)
	handlers[actionType] = fn
end

-- คืน true ถ้ามี handler รับ, false ถ้า action เพี้ยน/ไม่รู้จัก (ไม่ crash — client ส่งมั่วได้)
function ActionRouter.route(state, action): boolean
	local h = type(action) == "table" and action.type and handlers[action.type]
	if not h then
		warn("[ActionRouter] action ไม่รู้จัก:", action and tostring(action.type) or "nil")
		return false
	end
	h(state, action)
	return true
end

return ActionRouter
