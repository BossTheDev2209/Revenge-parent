-- Ending Neutral ② — **เกรดเต็ม** (docs/02 §5, §9.4) — ending ที่คนส่วนใหญ่จะได้ ใช้โชว์คู่ Good1
-- ถึง 1M แต่คุณภาพ/การตอบกลางๆ — สำเร็จจริง แต่ไม่มีใครฉลองด้วย
-- ★ ต้องมี Part กล้อง 4 ตัวใน Workspace.CutsceneCams: Cam_Neutral2_01 .. Cam_Neutral2_04
return {
	{ type = "camera", cam = "Cam_Neutral2_01" }, -- จอคอม เลข 1,000,000 ขึ้น
	{ type = "text", text = "[fast]1,000,000" },
	{ type = "text", text = "[slow]ตัวเลขที่ไล่ตามมาสามปี ขึ้นบนจอตอนตีสองครึ่ง" },
	{ type = "wait", t = 1 },

	{ type = "camera", cam = "Cam_Neutral2_02" }, -- ห้องสตูดิโอ กลางดึก ไม่มีใคร
	{ type = "text", text = "[normal]ไม่มีใครอยู่ในห้อง" },
	{ type = "text", text = "[normal]ปาล์มกลับไปแล้ว [slow]เจไม่ได้ทักมาตั้งแต่วันนั้น" },
	{ type = "text", text = "[slow]ในกล่องข้อความมีแต่ sponsor กับคนที่ไม่รู้จัก" },
	{ type = "wait", t = 1 },

	{ type = "camera", cam = "Cam_Neutral2_03" }, -- มือถือ หน้าจอแชทครอบครัว
	{ type = "text", text = "[normal]พิมพ์หาแม่อยู่สิบนาที [slow]แล้วก็ลบทิ้ง" },
	{ type = "text", text = "[slow]จะบอกว่าอะไรล่ะ 'ถึงล้านแล้วนะ' เหรอ" },
	{ type = "text", text = "[normal]เขาไม่เคยถามถึงตัวเลขนี้สักครั้ง" },
	{ type = "wait", t = 2 },

	{ type = "camera", cam = "Cam_Neutral2_04" }, -- เปิดหน้าต่าง แสงเช้า
	{ type = "text", text = "[slow]พรุ่งนี้ก็ต้องอัดคลิปใหม่อยู่ดี" },
	{ type = "text", text = "[normal]ล้านนึงมันแค่ตัวเลข [slow]ที่พรุ่งนี้ก็ต้องรักษาไว้อีก" },
	{ type = "wait", t = 2 },
	{ type = "text", text = "[slow]— Neutral Ending: ถึงแล้ว... แล้วไงต่อ —" },
}
