-- CanonEvents.luau — event บังคับเมื่อ follower ข้าม milestone (Config.StoryMilestones)
-- key = "milestone_" .. ตัวเลข | dialogue = list บรรทัด (format เดียวกับ Dialogue/*)
-- ทุก event หัก mental ผ่าน drain modifier 24 ชม. อัตโนมัติ (docs/02 §3)
-- milestone_500000 = event ทรยศ (docs/02 §9.4) — Main ตั้ง flags.betrayed + mental −25 เพิ่ม
-- ⚠️ [placeholder] — รอบทจริง เขียนแทนข้อความในลิสต์ได้เลย (key ห้ามลบ ต้องครบทุก milestone)
return {
	["milestone_1000"] = { dialogue = { "[placeholder] ถึง 1,000 follower" } },
	["milestone_10000"] = { dialogue = { "[placeholder] ถึง 10,000 follower" } },
	["milestone_100000"] = { dialogue = { "[placeholder] ถึง 100,000 follower" } },
	["milestone_500000"] = { dialogue = { "[placeholder] ★ event ทรยศ — เพื่อนคนแรกไปอยู่กับคู่แข่ง" } },
	["milestone_1000000"] = { dialogue = { "[placeholder] ถึง 1,000,000 follower" } },
}
