-- ลุงฮาซาน — NPC ประจำเฟส 2 (WorldNPC) · docs/05 §4
-- บททางเดียว หรือใส่ช้อยได้ (บางตัวมีช้อย — docs/engines/dialogue.md §2.5)
-- ⚠️ [placeholder] — รอเขียนบทจริง
return {
	p2 = {
		speaker = "???" , text = "[fast]อ้าวหนุ่มทำอะไรอยู่ล่ะ",
		{choices = {text = "ผมกำลังทำตามความฝันอยู่ลุง", tone="plus", reply={"[fast]โฮ่ๆๆ รุ่นเรานี่ออกไปล่าฝันกันแล้วหรอนิ"}},
		{text = "ลุงชื่ออะไรอ่ะ",tone = "neutral"},
		{text = "คุณเป็นใครเนี่ย", tone="minus" , reply={"[slow]ใจเย็นๆก่อนน้องบ่าว"}},
		},
	},

}

