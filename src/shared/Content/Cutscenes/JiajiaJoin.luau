-- JiajiaJoin — cutscene ตอนเจียเจียเข้าร่วม (cutscene #3 ตาม docs/16-story-bible.md §3)
-- เล่นผ่าน CutscenePlayer (mode 1) — ท่าทางทั้ง 3 ตัวเป็น clip เดียวยาว 11 วิ ทำด้วย Moon Animator (root motion จริง)
-- ยิงตอน follower ถึง Config.Staff.companions[2].joinFollower (100K = เข้าเฟส 3) — ครั้งเดียว (flag jiajia_joined)
--
-- animation (ยืนยันแล้ว โหลดได้ มี keyframe จริง):
--   เจียเจีย rbxassetid://101374364283300 (192 keyframe, ยืด 11.0s → 12.4s) → Animations.เจียเจีย.JiajiaJoin
--   player   rbxassetid://80954849724703  (3 keyframe)   → Animations.player.JiajiaJoin
--   ฟ้าใส    rbxassetid://82563101690942  (3 keyframe)   → Animations.ฟ้าใส.JiajiaJoin
--
-- กล้อง: spec จาก user เป็นเฟรมที่ 60fps (คลิปยาว 11 วิ = 660 เฟรม) แปลงเป็นวินาทีแล้ว
--   cam1 30f=0.5s | cam2 120f=2.0s | cam3 330f=5.5s | cam4 345f=5.75s (ครึ่งหลังของช่วง 330-360)
--   cam5 360f=6.0s | cam6 440f=7.333s | cam7 485f=8.083s | cam8 570f=9.5s | จบ 660f=11.0s
--   wait แต่ละอันคือ "ส่วนต่าง" ระหว่าง cam ไม่ใช่เวลาสัมบูรณ์ (step เดินต่อกันเป็นลำดับ)
-- ⚠️ cam3/cam4 อยู่ในช่วง 330-360f รวมกันแค่ 0.5 วิ — spec ไม่ได้บอกจุดตัดตรงกลาง แบ่งครึ่งไว้ก่อน ปรับได้ตอน playtest
-- ⚠️⚠️ root motion ไม่ขยับ HumanoidRootPart จริง (แค่ offset ให้ดูเหมือนเดิน) — พอ CutscenePlayer จบฉากแล้ว
--   AnimPlayer.stop() หยุด track, offset หาย, วาปกลับตำแหน่งจริง (เหมือนที่แก้ FaasaiJoin.luau ไปแล้ว)
--   แก้ด้วย step "move" (t=0 = สแนปทันที) ไปที่อยู่ถาวรเฟส 3 ก่อนจบฉาก 1 step เสมอ
return {
	{ type = "focus", target = "Spawn_Phase3" },
	-- cam ตัดก่อนสิ่งอื่นทั้งหมด — ScreenTransition fade ออกแล้ว CutscenePlayer โผล่ letterpbar ทันที
	-- ถ้า cam อยู่หลัง anim/wait จะเห็นมุมมอง player เดิมโผล่ใต้ bar ก่อนตัดกล้อง (ช่องว่างไม่มี fade คลุม)
	{ type = "camera", cam = "JiajiaJoin_01" },
	{ type = "anim", actor = "เจียเจีย", name = "JiajiaJoin", loop = false },
	{ type = "anim", actor = "player", name = "JiajiaJoin", loop = false },
	{ type = "anim", actor = "ฟ้าใส", name = "JiajiaJoin", loop = false },
	-- คลิปฟ้าใสสั้นแค่ 3 keyframe จบเร็วกว่าฉากทั้งหมดมาก — จบแล้ว pose รีเซ็ตกลับตำแหน่งจริงกลางฉาก (เห็นวาป)
	-- ต่างจาก เจียเจีย/ฟ้าใสตอนจบฉาก (root motion snap-back คอมเมนต์บนสุด) เพราะอันนี้ pop ก่อนฉากจบ ไม่ใช่ตอนจบ
	-- แก้จุดเดียวกัน (move t=0) แต่วางตรงนี้ทันทีหลัง anim ของฟ้าใส ไม่ใช่ท้ายไฟล์ — เธอควรยืนอยู่ที่ประตูต่อไปจนฉากจบ
	{ type = "move", actor = "ฟ้าใส", to = "NPCHome_ฟ้าใส_jiajiajoin", t = 0 },
	{ type = "wait", t = 0.5 }, -- 0 → 30f
	{ type = "wait", t = 1.5 }, -- 30 → 120f
	{ type = "camera", cam = "JiajiaJoin_02" },
	{ type = "wait", t = 3.5 }, -- 120 → 330f
	{ type = "camera", cam = "JiajiaJoin_03" },
	{ type = "wait", t = 0.25 }, -- 330 → 345f
	{ type = "camera", cam = "JiajiaJoin_04" },
	{ type = "wait", t = 0.25 }, -- 345 → 360f
	{ type = "camera", cam = "JiajiaJoin_05" },
	{ type = "wait", t = 1.3333 }, -- 360 → 440f
	{ type = "camera", cam = "JiajiaJoin_06" },
	{ type = "wait", t = 0.75 }, -- 440 → 485f
	{ type = "camera", cam = "JiajiaJoin_07" },
	{ type = "wait", t = 1.4167 }, -- 485 → 570f
	{ type = "camera", cam = "JiajiaJoin_08" },
	{ type = "wait", t = 2.9 }, -- 570f → ค้างจนจบคลิป (ยืด 11.0s → 12.4s เฉพาะช่วงท้าย, cam ก่อนหน้าไม่แตะ)
	{ type = "move", actor = "เจียเจีย", to = "NPCHome_เจียเจีย_couch", t = 0 }, -- แก้ root motion snap-back (ดูคอมเมนต์บนสุดไฟล์)
	{ type = "move", actor = "ฟ้าใส", to = "NPCHome_ฟ้าใส_chair", t = 0 },
	-- MacbookCouch/MacbookChair โผล่/หายตาม flags (Main.client.luau) ไม่ต้องสั่ง visible ในคัตซีนนี้
}
