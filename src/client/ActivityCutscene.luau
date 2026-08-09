-- ActivityCutscene.luau — ฉากสั้นตอนทำ activity ฟื้นใจ (พักผ่อน / กินข้าว / ออกกำลังกาย)
-- docs/02 §3 + §9: "Activity system → cutscene สั้น 5–10 วิ + ฟื้น mental"
--
-- ★ โครงรอเสียบฉาก (9 ส.ค. user): `Config.Mental.activityCutscenes` ยังว่างทุกตัว
--   ว่าง = กด E แล้วได้ผลใจทันที ไม่มีฉากคั่น (เกมเล่นได้ครบ ไม่ต้องรอ animation/storyboard)
--   ทีมใส่ steps ใน Config เมื่อไหร่ = เล่นฉากทันที **ไม่ต้องแก้ไฟล์นี้เลย**
--
-- ลำดับจงใจ: เช็ค cooldown ฝั่ง client ก่อน → เล่นฉาก → จบฉากค่อยยิง DoActivity
--   ยิงก่อนเล่น = ใจเด้งขึ้นตั้งแต่ฉากยังไม่จบ (เห็นเลขวิ่งใต้ฉาก ดูพัง)
--   ไม่เช็ค cooldown ก่อน = ผู้เล่นนั่งดูฉาก 10 วิ แล้ว server ปฏิเสธ เสียเวลาฟรี
--   server ยังเป็นคนตัดสินจริงเสมอ (MentalService.doActivity) — เช็คฝั่งนี้แค่กัน UX เสีย
--
-- pure: canDo / stepsFor (เทสได้) — glue: play() ใช้ CutscenePlayer
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../shared/Config")

local ActivityCutscene = {}

-- ชื่อ activity ที่รองรับ — ต้องตรงกับ ACTIVITY_REASON ใน MentalService (server เป็นคนคิดผลจริง)
-- มีเทสคุมว่าสองฝั่งรู้จักชื่อชุดเดียวกัน (สะกดผิดข้างเดียว = กดแล้วเงียบ หาสาเหตุยาก)
ActivityCutscene.NAMES = { Bed = true, Kitchen = true, Exercise = true }

function ActivityCutscene.isActivity(name: string): boolean
	return ActivityCutscene.NAMES[name] == true
end

-- cooldown เดียวกับ server (MentalService.doActivity): ทำติดกันครบ maxStreak → พักข้ามวัน
-- ⚠️ ถ้าแก้กติกาฝั่ง server ต้องแก้ที่นี่ด้วย — มีเทสคุมว่าสองฝั่งตอบตรงกัน
--    (แพทเทิร์นเดียวกับ EditQTE.canEdit ↔ RecordService.canEdit)
function ActivityCutscene.canDo(state): (boolean, string?)
	if not state then return false, "ยังโหลดเกมไม่เสร็จ" end
	if state.day < (state.activity and state.activity.cooldownUntilDay or 0) then
		return false, "วันนี้พักมาพอแล้ว — ไว้พรุ่งนี้ค่อยมาใหม่"
	end
	return true, nil
end

-- steps ของฉาก activity นั้น — คืน nil ถ้ายังไม่มีเนื้อฉาก (ตารางว่าง = ข้ามฉาก)
function ActivityCutscene.stepsFor(name: string)
	local all = Config.Mental.activityCutscenes
	local steps = all and all[name]
	if not steps or #steps == 0 then return nil end
	return steps
end

-- ===== glue =====

-- กดทำ activity: เช็คได้ไหม → เล่นฉาก (ถ้ามี) → ยิง DoActivity ให้ server คิดผลจริง
-- deps = { playerGui, fireAction, getState }
-- คืน (เริ่มไหม, เหตุผลถ้าไม่ได้) — caller เอาเหตุผลไปโชว์ toast เอง (UI เป็นของ InteractBinder)
function ActivityCutscene.play(name: string, deps): (boolean, string?)
	local state = deps.getState and deps.getState() or nil
	local ok, why = ActivityCutscene.canDo(state)
	if not ok then return false, why end

	local function finish()
		deps.fireAction({ type = "DoActivity", activity = name })
	end

	local steps = ActivityCutscene.stepsFor(name)
	if not steps then
		finish() -- ยังไม่มีฉาก = ได้ผลทันที
		return true, nil
	end

	-- CutscenePlayer freeze เวลาให้เอง แต่ **caller ต้อง unfreeze ตอนจบ** (ดูหัวไฟล์ CutscenePlayer)
	local CutscenePlayer = require(script.Parent.UI.CutscenePlayer)
	CutscenePlayer.play(deps.playerGui, steps, function()
		deps.fireAction({ type = "FreezeTime", on = false })
		finish()
	end)
	return true, nil
end

return ActivityCutscene
