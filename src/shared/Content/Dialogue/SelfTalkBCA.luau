-- SelfTalkBCA — ฉากคิดสำคัญของผู้เล่นหลังได้รางวัล BCA (True Ending: Good1)
-- เรียกโดย EndingSequence.luau แบบตรงๆ (ไม่ผ่าน NPC-prompt system)
-- บรรทัดพูดทุกบรรทัดใช้ speaker="คุณ" เพื่อให้หน้าผู้เล่นขึ้นเป็นตัวพูด (ฉากคิดสำคัญ ไม่ใช่คิดในใจแบบวงเล็บ) — บรรทัด narration/stage-direction ใช้ plain string โดยไม่มี speaker ตามปกติ

return {
	{ speaker = "คุณ", text = "[placeholder] ความกังวล — ตอนเริ่มต้นจาก 0 followers" },
	{ speaker = "คุณ", text = "[placeholder] ความสำเร็จ — ถึงวันนี้" },
	{ speaker = "คุณ", text = "[placeholder] ขอบคุณทีมงาน/เพื่อนที่ช่วยมาตลอด" },
	{ speaker = "คุณ", text = "[placeholder] แรงบันดาลใจจากครอบครัว" },
	"[placeholder] (หยุดคิด รับความรู้สึกที่เพิ่งเกิดขึ้น)",
	{ speaker = "คุณ", text = "[placeholder] ได้รางวัล BCA เป็นหลักฐานความสำเร็จ" },
	{ speaker = "คุณ", text = "[placeholder] หน้าที่ที่ต้องเผชิญพ่อแม่ต่อจากนี้" },
	{ speaker = "คุณ", text = "[placeholder] ความหมายของชีวิต — ฝันที่แท้จริง" },
}
