-- TimeService.luau — นาฬิกากลางของเกม: tick รายชั่วโมงเกม
-- ระบบอื่นห้ามนับเวลาเอง — สมัครฟังผ่าน onHour/onDay (wiring ใน Main ที่เดียว)
-- pure ทั้งไฟล์ยกเว้น start() (Roblox loop)
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../shared/Config")

local TimeService = {}
local hourFns, dayFns = {}, {}
local frozen = false

function TimeService.onHour(fn) table.insert(hourFns, fn) end
function TimeService.onDay(fn) table.insert(dayFns, fn) end

function TimeService.setFrozen(b: boolean) frozen = b end -- dialogue/cutscene เรียก
function TimeService.isFrozen(): boolean return frozen end

-- เดินเวลา 1 ชั่วโมงเกม + ยิง callback (no-op ถ้า frozen)
function TimeService.tick(state)
	if frozen then return end
	state.timeOfDay += 1
	if state.timeOfDay >= 24 then
		state.timeOfDay = 0
		state.day += 1
		for _, f in dayFns do f(state) end
	end
	for _, f in hourFns do f(state) end
end

-- PDF หน้า 6: เริ่มนอนช่วง 18:00–5:59 ข้าม 8 ชม. | นอกช่วงข้าม 12 ชม.
function TimeService.sleepHours(hour: number): number
	local s = Config.Time.sleep
	local inWindow = hour >= s.windowStart or hour < s.windowEnd
	return inWindow and s.normalHours or s.outsideHours
end

-- นอน: เดินเวลาทีละชั่วโมงผ่าน tick ปกติ → onDay/onHour ยิงถูกจังหวะเอง
-- state.sleeping = true ระหว่างนี้ ให้ MentalService รู้ว่าเป็นชั่วโมงหลับ (ไม่ drain — fix 29 ก.ค.)
function TimeService.sleep(state)
	state.sleeping = true
	for _ = 1, TimeService.sleepHours(state.timeOfDay) do
		TimeService.tick(state)
	end
	state.sleeping = false
end

-- ===== Roblox glue (Studio เท่านั้น) =====
function TimeService.start(state)
	task.spawn(function()
		while true do
			task.wait(Config.Time.secondsPerGameHour)
			TimeService.tick(state)
		end
	end)
end

return TimeService
