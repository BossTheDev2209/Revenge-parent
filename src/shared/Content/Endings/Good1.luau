-- Ending Good1 (True Ending) — ⚠️ ไฟล์นี้ "ไม่ได้ถูกอ่าน" อีกต่อไปสำหรับ ending นี้ (12 ส.ค. 2569)
-- เดิม: Main.client.luau's generic ending block เรียก require(Content.Endings[endId]) ตรงๆ
-- ตอนนี้: Good1 ถูก intercept ที่ event "bca" ก่อนถึงจุดนั้น (Main.client.luau, เช็ค Config.BCAEventId +
--   state.flags.ending=="Good1") แล้วเรียก EndingSequence.playTrueEnding(...) แทน (src/client/EndingSequence.luau)
--   ซึ่งเล่นเนื้อหาจริงจาก src/shared/Content/Cutscenes/BCAWalk.luau + Reunite.luau + Content/Dialogue/SelfTalkBCA.luau
--   (endingPlayed ถูก set=true ตอน intercept กัน generic block ข้างล่างเรียกไฟล์นี้ซ้ำ)
-- ไฟล์นี้เหลือไว้เป็น fallback เปล่าๆ เผื่อโค้ดอื่นยัง require() ตรงๆ — ห้ามลบทิ้ง (ยังมี type ที่ CutscenePlayer อ่านได้ถ้าเผลอถูกเรียกจริง)
return {
	{ type = "text", text = "[ไม่ควรเห็นข้อความนี้ — ถ้าเห็น แปลว่า Main.client.luau bypass Good1 ไม่ทำงาน เช็ค Config.BCAEventId/state.flags.ending intercept]" },
	{ type = "wait", t = 2 },
}
