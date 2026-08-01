-- Mom — placeholder ที่ใช้ครบทุกฟีเจอร์ของ dialogue engine (ดู docs/engines/dialogue.md)
-- ทีมแก้ได้แค่ข้อความในเครื่องหมายคำพูด ห้ามลบ comma/วงเล็บ

return {
	-- p1: สามรูปแบบของหนึ่งบรรทัด + tag ความเร็ว [slow]/[fast]/[normal]
	p1 = {
		"ห้องนี้มันแคบไปไหมลูก...", -- ข้อความล้วน ไม่มีชื่อคนพูด
		{ speaker = "แม่", text = "กลับมาทำไม ไม่มีเงินใช่ไหมล่ะ" },
		{ speaker = "แม่", text = "แม่ถามจริงๆ [slow]ลูกจะเอายังไงกับชีวิต [normal]กันแน่?" },
	},

	-- p2: ท่าทาง (anim/pose) สีหน้า (face) และ actor
	p2 = {
		{ speaker = "แม่", text = "อ้าว... กลับมาแล้วเหรอ", anim = "Wave", face = "Happy" }, -- anim เล่นครั้งเดียว
		{ speaker = "แม่", text = "มานั่งก่อนสิ แม่มีอะไรจะบอก", pose = "Sit", face = "Normal" }, -- pose ค้าง loop
		{ speaker = "แม่", text = "เดี๋ยวแม่เรียกพ่อมาด้วย", actor = "Dad", anim = "Point" }, -- ให้ตัวอื่นขยับ
		{ speaker = "แม่", text = "ทำไมไม่มองหน้าแม่ล่ะ", actor = "player", anim = "HeadScratch" },
		{ face = "Sad", pose = "Idle" }, -- บรรทัดสั่งท่าล้วน ไม่ขึ้นกล่องข้อความ
	},

	-- p3: ช้อย (ไม่ branching — ทุกช้อยบรรจบบรรทัดถัดไป) tone เป็นแค่ป้ายกำกับ
	p3 = {
		{ speaker = "แม่", text = "ลูกทำได้จริงๆ ด้วย... [slow]แม่ภูมิใจนะ", face = "Happy" },
		{
			choices = {
				{ text = "ขอบคุณที่ไม่ยอมแพ้กับผมนะแม่", tone = "plus",
					reply = { { speaker = "แม่", text = "แม่ต่างหากที่ต้องขอโทษ" } } },
				{ text = "ผมทำเพื่อพิสูจน์ให้แม่เห็น", tone = "minus",
					reply = { { speaker = "แม่", text = "แม่รู้แล้วลูก... แม่คิดผิดเอง" } } },
				{ text = "...(ยิ้ม)", tone = "neutral" }, -- ไม่มี reply = ไปต่อเลย
			},
		},
		{ speaker = "แม่", text = "ไปกินข้าวกันเถอะ แม่ทำกับข้าวไว้" }, -- เล่นเสมอ
	},

	-- after: บทหลังเพื่อนทรยศ (follower >= 500K)
	after = {
		{ speaker = "แม่", text = "ได้ข่าวว่าเพื่อนลูกไปแล้ว... [slow]กลับบ้านมาพักบ้างนะ", face = "Sad" },
	},
}
