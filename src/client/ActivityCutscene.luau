-- ActivityCutscene — ฉากสั้นตอนทำ activity ฟื้นใจ (พักผ่อน / กินข้าว / ออกกำลังกาย)
-- Config.Mental.activityCutscenes ว่าง = กดแล้วได้ผลทันทีไม่มีฉาก · ใส่ steps เมื่อไหร่ = เล่นฉาก ไม่ต้องแก้ไฟล์นี้
-- ลำดับ: เช็ค cooldown client ก่อน → เล่นฉาก → จบค่อยยิง DoActivity (ยิงก่อน = ใจเด้งตั้งแต่ฉากยังไม่จบ)
-- server ตัดสินจริงเสมอ (MentalService.doActivity) — เช็คฝั่งนี้แค่กัน UX เสีย
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../shared/Config")

local ActivityCutscene = {}

-- ต้องตรงกับ ACTIVITY_REASON ใน MentalService (มีเทสคุมว่าสองฝั่งรู้จักชื่อชุดเดียวกัน)
ActivityCutscene.NAMES = { Bed = true, Kitchen = true, Exercise = true }

function ActivityCutscene.isActivity(name: string): boolean
	return ActivityCutscene.NAMES[name] == true
end

-- cooldown เดียวกับ server · ⚠️ แก้กติกา server ต้องแก้ที่นี่ด้วย (มีเทสคุมว่าตอบตรงกัน)
function ActivityCutscene.canDo(state): (boolean, string?)
	if not state then return false, "ยังโหลดเกมไม่เสร็จ" end
	if state.day < (state.activity and state.activity.cooldownUntilDay or 0) then
		return false, "วันนี้พักมาพอแล้ว — ไว้พรุ่งนี้ค่อยมาใหม่"
	end
	return true, nil
end

-- steps ของฉาก activity — nil ถ้ายังไม่มีเนื้อฉาก (ตารางว่าง = ข้ามฉาก)
function ActivityCutscene.stepsFor(name: string)
	local all = Config.Mental.activityCutscenes
	local steps = all and all[name]
	if not steps or #steps == 0 then return nil end
	return steps
end

-- กดทำ activity: เช็คได้ไหม → เล่นฉาก (ถ้ามี) → ยิง DoActivity · deps = { playerGui, fireAction, getState }
-- คืน (เริ่มไหม, เหตุผลถ้าไม่ได้) — caller เอาเหตุผลไปโชว์ toast เอง
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

	-- CutscenePlayer freeze เวลาให้เอง แต่ caller ต้อง unfreeze ตอนจบ
	local CutscenePlayer = require(script.Parent.UI.CutscenePlayer)
	CutscenePlayer.play(deps.playerGui, steps, function()
		deps.fireAction({ type = "FreezeTime", on = false })
		finish()
	end)
	return true, nil
end

return ActivityCutscene
