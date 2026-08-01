-- Opening — ฉากเปิดเกม (cutscene mode 1 "หนัง") เล่นตอนกด New Game
-- [placeholder] Boss เขียนบท/ท่าทาง/มุมกล้องจริงเอง แก้แค่ list นี้
--
-- step ที่ใช้ได้ (ดู docs/engines/cutscene.md):
--   { type="camera", cam="Opening_1" [, t=วิ] }   มุมกล้อง (Part ใน CutsceneCams/Opening) t = เลื่อนนุ่ม
--   { type="text",   text="..." }                  ซับล่างจอ (letterbox ไม่มีกล่อง)
--   { type="wait",   t=วิ }                         หยุดค้าง
--   { type="anim",   actor="Mom", name="Angry" [, loop=true] }   ตัวละครขยับ
--   { type="face",   actor="Mom", name="Angry" }   สีหน้า
--   { type="bgm",    name="..." } / { type="sound", name="..." }  เสียง
-- actor = ชื่อไฟล์บท/โมเดล ("player" = ตัวผู้เล่น) · cam วางด้วย plugin CutsceneCamTool
return {
	{ type = "camera", cam = "Opening_1" },
	{ type = "text", text = "[placeholder] ฉากพ่อแม่ในบ้าน — เขียนบทจริงแทน" },
	{ type = "wait", t = 1 },
	-- ตัวอย่าง beat ถัดไป (ปลดคอมเมนต์ + วาง Cam/anim จริง):
	-- { type = "camera", cam = "Opening_2", t = 1.5 },
	-- { type = "anim", actor = "Mom", name = "Angry" },
	-- { type = "face", actor = "Mom", name = "Angry" },
	-- { type = "text", text = "..." },
}
