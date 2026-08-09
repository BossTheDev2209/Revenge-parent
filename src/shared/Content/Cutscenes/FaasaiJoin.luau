-- FaasaiJoin — cutscene ตอนฟ้าใสมาขอฝึกงาน (เคาะประตู→เดินเข้า→นั่งเตียง)
-- เล่นผ่าน CutscenePlayer (mode 1) — step: camera / text / wait / anim / move / face / bgm / sound
--   move = เดิน actor ไป Part (ฟ้าใส: หน้าประตู→ข้างเตียง) · ต้องมี Part เป้า + cam ใน CutsceneCams/FaasaiJoin/
-- ยิงตอน follower ถึง Config.FaasaiJoinFollower ในเฟส 2 (Main.client) — ครั้งเดียว (flag faasai_joined)
-- ⚠️ [placeholder] — Boss เขียน step จริง + วาง cam/anchor ในแมพ (ดู docs/engines/cutscene.md)
return {
	{ type = "text", text = "[placeholder] มีเสียงเคาะประตู..." },
	{ type = "wait", t = 2 },
	{ type = "text", text = "[placeholder] ฟ้าใส — คนที่เคยให้อาหารตอนเฟส 1 มาขอฝึกงานฟรีๆ" },
	{ type = "wait", t = 3 },
	-- ตัวอย่าง move (ปลดคอมเมนต์เมื่อวาง Part `FaasaiBedSpot` + rig ฟ้าใสในแมพแล้ว):
	-- { type = "move", actor = "ฟ้าใส", to = "FaasaiBedSpot", t = 2.5 },
	-- { type = "anim", actor = "ฟ้าใส", name = "SitDown", loop = true },
}
