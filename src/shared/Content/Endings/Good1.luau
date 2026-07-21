-- Ending Good ① — **เกรดเต็ม** (docs/02 §5, §9.4) — ใช้โชว์ใน pitch/วิดีโอ
-- ถึง 1M + คลิปคุณภาพสูง + ตอบ comment ทางบวก ≥62.5%
-- step: {type="text"} | {type="wait", t=} | {type="camera", cam="ชื่อ Part ใน Workspace.CutsceneCams"}
-- ★ ต้องมี Part กล้อง 5 ตัวใน Workspace.CutsceneCams: Cam_Good1_01 .. Cam_Good1_05 (docs/10 §3)
return {
	{ type = "camera", cam = "Cam_Good1_01" }, -- ห้องเช่าห้องเดิม ว่างเปล่า ย้ายออกแล้ว
	{ type = "text", text = "[slow]ห้องเช่าห้องนั้นว่างมาสามเดือนแล้ว" },
	{ type = "text", text = "[normal]ป้าแดงบอกว่ายังไม่มีใครมาเช่าต่อ" },
	{ type = "wait", t = 1 },

	{ type = "camera", cam = "Cam_Good1_02" }, -- สตูดิโอใหม่ ปาล์มนั่งตัดคลิป
	{ type = "text", text = "ปาล์ม: คลิปฉลองล้านเรนเดอร์เสร็จแล้วนะ [normal]อยากดูก่อนอัปไหม" },
	{ type = "text", text = "[slow]...ไม่ต้องหรอก ผมเชื่อคุณ" },
	{ type = "wait", t = 1 },

	{ type = "camera", cam = "Cam_Good1_03" }, -- หน้าประตูสตูดิโอ เจยืนอยู่
	{ type = "text", text = "เจ: [slow]พี่..." },
	{ type = "text", text = "เจ: หนูไม่ได้มาขอกลับนะ [normal]หนูมีช่องของหนูแล้ว" },
	{ type = "text", text = "เจ: [slow]หนูแค่อยากบอกว่า... ขอโทษที่ไปแบบนั้น" },
	{ type = "text", text = "[normal]ไม่เป็นไร [slow]พี่ต่างหากที่ไม่เคยถามว่าเธออยากได้อะไร" },
	{ type = "wait", t = 1 },

	{ type = "camera", cam = "Cam_Good1_04" }, -- หน้าบ้านพ่อแม่
	{ type = "text", text = "[slow]กลับบ้านครั้งนี้ไม่ได้เอาอะไรไปพิสูจน์" },
	{ type = "text", text = "[normal]แม่เปิดประตู มองหน้า แล้วถามคำเดียว" },
	{ type = "text", text = "แม่: [slow]กินข้าวมารึยัง" },
	{ type = "wait", t = 2 },

	{ type = "camera", cam = "Cam_Good1_05" }, -- โต๊ะกินข้าวที่บ้าน
	{ type = "text", text = "[slow]หนึ่งล้านคนดูเราทุกวัน" },
	{ type = "text", text = "[normal]แต่คนที่เรารอให้มองมาตลอด มีแค่สองคนนี้" },
	{ type = "text", text = "[slow]แล้ววันนี้เขาก็มองอยู่" },
	{ type = "wait", t = 2 },
	{ type = "text", text = "[slow]— Good Ending: พิสูจน์แล้ว —" },
}
