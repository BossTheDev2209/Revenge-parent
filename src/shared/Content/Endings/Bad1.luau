-- Ending Bad ① — **เกรดย่อ** (docs/02 §5, §9.4) — จ่ายค่าเช่าไม่ไหว 2 รอบ = โดนไล่ที่
-- optional challenge ไม่ใช่ fail state บังคับ | กล้องมุมเดียว: Cam_BadShared_01 (ใช้ร่วม 3 Bad end)
-- ★ Roblox compliance: ความล้มเหลวเชิงสังคม/อาชีพเท่านั้น ห้ามมีเนื้อหาความตาย
return {
	{ type = "camera", cam = "Cam_BadShared_01" }, -- ห้องเช่า ของกองอยู่กลางห้อง
	{ type = "text", text = "ป้าแดง: [slow]ป้าให้โอกาสหนูสองรอบแล้วนะ" },
	{ type = "text", text = "[normal]ของทั้งหมดในห้องนี้ ใส่กระเป๋าใบเดียวก็หมด" },
	{ type = "wait", t = 2 },
	{ type = "text", text = "[slow]กลับถึงบ้าน พ่อไม่ได้ด่าเลยสักคำ" },
	{ type = "text", text = "[normal]แค่พูดว่า 'พรุ่งนี้ไปสมัครงานกับลุงนะ' [slow]แค่นั้น" },
	{ type = "wait", t = 2 },
	{ type = "text", text = "[slow]คลิปสุดท้ายค้างอยู่ในเครื่อง ไม่ได้อัปสักที" },
	{ type = "wait", t = 1 },
	{ type = "text", text = "[slow]— Bad Ending ①: หมดตัวก่อนหมดใจ —" },
}
