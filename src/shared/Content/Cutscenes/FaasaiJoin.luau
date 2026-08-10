-- FaasaiJoin — cutscene ตอนฟ้าใสมาขอฝึกงาน (เคาะประตู→คุย→เดินเข้า→นั่งเตียง)
-- เล่นผ่าน CutscenePlayer (mode 1) — step: camera / text / wait / anim / face / bgm / sound
-- ท่าทางทั้งหมด (เคาะ/คุย/เดิน/นั่ง) เป็น animation clip เดียวยาว ทำด้วย Moon Animator (root motion จริง)
--   ความรู้สึก "cutscene" มาจากมุมกล้องตัด/แพนระหว่างเล่น ไม่ใช่ตัด step แยก
--   { type = "anim", actor = "ฟ้าใส", name = "ชื่อ clip", loop = false } เล่นครั้งเดียวยาว
--   วาง cam ใน CutsceneCams/FaasaiJoin/ ตัดสลับช่วง clip กำลังเล่น (ใส่ t ให้ตรงจังหวะ)
-- ยิงตอน follower ถึง Config.FaasaiJoinFollower ในเฟส 2 (Main.client) — ครั้งเดียว (flag faasai_joined)
-- animation clip ยืนยันแล้ว (rbxassetid://76365653201923, re-export 10 ส.ค.) + cam anchor มีในแมพแล้ว
-- ⚠️ t ของ wait ท้ายสุด = ประมาณความยาว clip เดา — ยัง**ไม่ได้วัดจริง** ปรับตามที่เห็นตอน playtest
return {
	{ type = "text", text = "[placeholder] มีเสียงเคาะประตู..." },
	{ type = "wait", t = 2 },
	{ type = "text", text = "[placeholder] ฟ้าใส — คนที่เคยให้อาหารตอนเฟส 1 มาขอฝึกงานฟรีๆ" },
	{ type = "wait", t = 3 },
	{ type = "camera", cam = "FaasaiJoin_01" },
	{ type = "anim", actor = "ฟ้าใส", name = "KnockTalkWalkSit", loop = false },
	{ type = "camera", cam = "FaasaiJoin_02", t = 2 },
	{ type = "wait", t = 8 },
}
