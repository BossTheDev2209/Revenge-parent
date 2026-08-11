-- FaasaiJoin — cutscene ตอนฟ้าใสมาขอฝึกงาน (เคาะประตู→คุย→เดินเข้า→นั่งเตียง)
-- เล่นผ่าน CutscenePlayer (mode 1) — step: camera / text / wait / anim / face / bgm / sound
-- ท่าทางทั้งหมด (เคาะ/คุย/เดิน/นั่ง) เป็น animation clip เดียวยาว ทำด้วย Moon Animator (root motion จริง)
--   ความรู้สึก "cutscene" มาจากมุมกล้องตัด/แพนระหว่างเล่น ไม่ใช่ตัด step แยก
--   { type = "anim", actor = "ฟ้าใส", name = "ชื่อ clip", loop = false } เล่นครั้งเดียวยาว
--   วาง cam ใน CutsceneCams/FaasaiJoin/ ตัดสลับช่วง clip กำลังเล่น (ใส่ t ให้ตรงจังหวะ)
-- ยิงตอน follower ถึง Config.FaasaiJoinFollower ในเฟส 2 (Main.client) — ครั้งเดียว (flag faasai_joined)
-- animation clip ยืนยันแล้ว (rbxassetid://81531260316285, export 11 ส.ค. ผ่าน Moon Animator AnimSaves > Save to Roblox
--   เจาะจงตัว Faasai_door_anim — export ผิดวิธีมาก่อน (ปุ่ม Export ทั้งฉากรวมหลาย rig) ทำ clip พังมาหลายรอบ) + cam anchor มีในแมพแล้ว
-- ท่าฝั่ง player (rbxassetid://80474483950776) อยู่ ReplicatedStorage.Animations.player.KnockTalkWalkSit — export คู่กับของฟ้าใสจาก scene เดียวกัน (Player_door_anim rig)
-- ประตู: objAnim ผ่าน "Door Rig" (rbxassetid://114525290542149, ReplicatedStorage.Animations."Door Rig".Open)
--   ⚠️ pivot ยังไม่ยืนยัน 100% ว่าหมุนถูกจุด (บาน ไม่ใช่กลางบาน) — เช็คจริงตอน playtest ก่อนเชื่อ
-- ⚠️ t ของ wait ท้ายสุด = ประมาณความยาว clip เดา — ยัง**ไม่ได้วัดจริง** ปรับตามที่เห็นตอน playtest
return {
	{ type = "text", text = "[placeholder] มีเสียงเคาะประตู..." },
	{ type = "wait", t = 2 },
	{ type = "text", text = "[placeholder] ฟ้าใส — คนที่เคยให้อาหารตอนเฟส 1 มาขอฝึกงานฟรีๆ" },
	{ type = "wait", t = 3 },
	{ type = "camera", cam = "FaasaiJoin_01" },
	{ type = "anim", actor = "ฟ้าใส", name = "KnockTalkWalkSit", loop = false },
	{ type = "anim", actor = "player", name = "KnockTalkWalkSit", loop = false }, -- คลิปเดียวกันชื่อ ท่าคนละไฟล์ (export แยก rig)
	{ type = "objAnim", object = "Door Rig", name = "Open", loop = false },
	{ type = "wait", t = 1.8 }, -- ถือกล้อง 01 ไว้ให้เห็นเคาะประตู+เริ่มคุยก่อนตัด (ไม่มี wait คั่น = cam ไม่หยุดรอ ข้าม 01 ไปเลย — ปรับเวลาได้ตามที่เห็นจริงตอน playtest)
	{ type = "camera", cam = "FaasaiJoin_02", t = 2 },
	{ type = "wait", t = 8 },
}
