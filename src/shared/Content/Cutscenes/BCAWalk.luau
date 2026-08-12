-- BCAWalk — cutscene ตอนรับรางวัล Bangkok Creator Award (BCA) บนเวที (Part of True Ending/Good1 flow)
-- เล่นผ่าน CutscenePlayer (mode 1) — step: camera / text / wait
-- ตัวละครเดินขึ้นเวที รับโล่ + emcee (host) ปิดงาน
-- กล้องวางแล้ว CutsceneCams/BCA/ ตั้งแต่ BCA_11 ถึง BCA_21 (11 กล้องรวม)
-- ⚠️ [placeholder] — รอไทยของจริง หัวข้อสุนทรพจน์ + ข้อความเนื้อเรื่อง แก้ได้เลย

return {
	{ type = "focus", target = "BCA_Stage" },
	{ type = "camera", cam = "BCA_11" },
	{ type = "text", text = "[placeholder BCA stage intro]" },
	{ type = "wait", t = 2 },

	{ type = "camera", cam = "BCA_12", t = 1.5 },
	{ type = "wait", t = 1.5 },

	{ type = "camera", cam = "BCA_13", t = 2 },
	{ type = "text", text = "[placeholder player approaching stage]" },
	{ type = "wait", t = 3 },

	{ type = "camera", cam = "BCA_14", t = 1.5 },
	{ type = "wait", t = 1.5 },

	{ type = "camera", cam = "BCA_15", t = 2 },
	{ type = "text", text = "[placeholder player receiving trophy]" },
	{ type = "wait", t = 2.5 },

	{ type = "camera", cam = "BCA_16", t = 1.5 },
	{ type = "wait", t = 1 },

	{ type = "camera", cam = "BCA_17", t = 2 },
	{ type = "text", text = "[placeholder emcee closing remarks 1]" },
	{ type = "wait", t = 3 },

	{ type = "camera", cam = "BCA_18", t = 1.5 },
	{ type = "wait", t = 1.5 },

	{ type = "camera", cam = "BCA_19", t = 2 },
	{ type = "text", text = "[placeholder emcee closing remarks 2]" },
	{ type = "wait", t = 2.5 },

	{ type = "camera", cam = "BCA_20", t = 2 },
	{ type = "wait", t = 2 },

	{ type = "camera", cam = "BCA_21", t = 2 },
	{ type = "text", text = "[placeholder celebration/finale]" },
	{ type = "wait", t = 3 },
}
