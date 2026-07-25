-- CanonEvents.luau — event บังคับตาม timeline (docs/02 §9.4, PDF หน้า 4)
-- key = "milestone_" .. ตัวเลขใน Config.StoryMilestones | "bca" = event พิเศษหลัง 1M
-- dialogue = list บรรทัด (format เดียวกับ Dialogue/*) — tag [slow] [fast] [normal] ใช้ได้
-- ทุก event หัก mental ผ่าน drain modifier ×1.25 24 ชม. อัตโนมัติ (docs/02 §3)
-- ⚠️ [placeholder] — รอบทจริง เขียนแทนข้อความในลิสต์ได้เลย (key ห้ามลบ ต้องครบทุก milestone)
return {
	["milestone_1000"] = {
		dialogue = { "[placeholder] ถึง 1,000 follower — ยังไร้บ้าน อยู่ข้างถนน" },
	},
	["milestone_10000"] = {
		dialogue = { "[placeholder] ถึง 10,000 → เข้าเฟส 2 ย้ายเข้าห้องเช่า + เพื่อนร่วมทาง 1 เข้าร่วม" },
	},
	["milestone_30000"] = {
		dialogue = { "[placeholder] มีเรื่องกับ Hater (เจอตัวจริงนอกจอ)" },
	},
	["milestone_100000"] = {
		dialogue = { "[placeholder] ถึง 100,000 → เข้าเฟส 3 ย้ายเข้าบ้าน + เพื่อนร่วมทาง 2 เข้าร่วม" },
	},
	["milestone_500000"] = {
		dialogue = { "[placeholder] ★ เพื่อนร่วมทาง Issue — เพื่อนคนแรกไปอยู่กับ CC คู่แข่ง" },
	},
	["milestone_700000"] = {
		dialogue = { "[placeholder] มีเรื่องกับ CC (beef หลังโดนดึงคนไป)" },
	},
	["milestone_1000000"] = {
		dialogue = { "[placeholder] ถึง 1,000,000 follower — เป้าหมายสำเร็จ" },
	},
	["bca"] = {
		dialogue = { "[placeholder] ★ ร่วมงาน BCA (Bangkok Creator Award) — ได้รางวัลทั้งที่เพิ่งมี beef" },
	},
}
