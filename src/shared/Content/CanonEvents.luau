-- CanonEvents.luau — event เมื่อ follower ข้าม milestone (1K/10K/100K/1M)
-- key = "milestone_" .. ตัวเลข | dialogue = list บรรทัด (format เดียวกับ Dialogue/*)
-- ⚠️ [placeholder] — ทีมเขียนบท Canon Event จริง (พ่อแม่โทรมา, Hater, CC beef ฯลฯ) แทนได้เลย
return {
	["milestone_1000"] = {
		dialogue = { "[fast]1,000 follower แล้ว! [normal]เริ่มมีคนเห็นเราแล้วสินะ..." },
	},
	["milestone_10000"] = {
		dialogue = { "หนึ่งหมื่น follower... [slow]ถึงเวลาย้ายออกจากข้างถนนสักที" },
	},
	["milestone_100000"] = {
		dialogue = { "แสน follower! [fast]sponsor เริ่มติดต่อมาแล้ว!" },
	},
	["milestone_1000000"] = {
		dialogue = { "[slow]หนึ่งล้าน... [normal]ถึงเวลากลับไปหาพ่อกับแม่แล้ว" },
	},
}
