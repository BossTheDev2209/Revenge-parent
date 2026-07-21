-- Comments.luau — pool comment ที่สุ่มขึ้นหลังอัปคลิป (PDF หน้า 8 — docs/02 §9.6)
-- **ช่องทางเดียวที่นับ choice % เข้า ending** (design doc §6)
--
-- format:
--   sentiment = "neg" (⊖ ติ/ด่า) | "neu" (◎ เฉยๆ) | "pos" (⊕ ชม/ให้กำลังใจ)
--   neg → replies ครบ 3: accept (ยอมรับปัญหา +10 ใจ นับ pos) / sarcasm (ประชด −5 นับ neu) / insult (ด่ากลับ −10 นับ neg)
--   neu → replies 2: accept + sarcasm
--   pos → ไม่มี replies (กดใจอย่างเดียว +10 ใจ นับ pos)
--   ทุกใบปล่อยผ่านได้ ไม่มีผล | ลำดับปุ่มบนจอสุ่มทุกครั้ง
-- ⚠️ [placeholder] — เขียน comment จริงแทน 3 ใบนี้ + เพิ่มต่อท้ายให้เยอะ (ยิ่งเยอะยิ่งไม่ซ้ำ)
return {
	{
		sentiment = "neg",
		text = "[placeholder] comment ด่า",
		replies = {
			accept = "[placeholder] ยอมรับปัญหา",
			sarcasm = "[placeholder] ประชด",
			insult = "[placeholder] ด่ากลับ",
		},
	},
	{
		sentiment = "neu",
		text = "[placeholder] comment เฉยๆ",
		replies = {
			accept = "[placeholder] ยอมรับปัญหา",
			sarcasm = "[placeholder] ประชด",
		},
	},
	{
		sentiment = "pos",
		text = "[placeholder] comment ชม",
	},
}
