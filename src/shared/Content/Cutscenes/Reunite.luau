-- Reunite — cutscene ตอนคืนเงิน + ตัวต่อ BCA (เข้าหาพ่อแม่) (Good Ending)
-- เล่นผ่าน CutscenePlayer (mode 1) — step: camera / text / wait / anim / move
-- ⚠️ **Team must place these Parts before scene plays:**
--   1. Camera anchors: Workspace.CutsceneCams.Reunite.Reunite_01 through Reunite_06
--      naming = <Scene>_<NN> where NN = zero-padded two digits (01, 02, 03, ...) ascending
--      (typically wrapped in Persistent Model: Workspace.CutsceneCams.Reunite folder)
--   2. NPC settle anchors: NPCHome_พ่อ_reunite, NPCHome_แม่_reunite, NPCHome_Player_reunite
--      (follow established convention from FaasaiJoin/JiajiaJoin: NPCHome_<actor>_<scene-location>)
-- ⚠️ animation clips สำหรับพ่อแม่ + player ยังไม่มี — ไม่เขียน anim step จนกว่า animation assets จะเตรียมพร้อม
--   สำหรับตอนนี้: ใช้ text + wait + move + camera cutscene เล่าเรื่องผ่าน ยังไม่ต้องเล่นท่าทาง
-- Trigger: หลัง cutscene BCA พร้อม BCA award ceremony ไปถึงผู้เล่นแล้ว
--   (Phase 3 → 1M follower → BCA ceremony → Reunite cutscene → ต่อ ending flow)
return {
	-- เริ่มด้วยการ focus ไปยัง spawn location หรือบ้านที่พ่อแม่อยู่
	{ type = "focus", target = "Spawn_Phase3" },

	-- ===== Cam 1: Wide shot home/meetup point =====
	{ type = "camera", cam = "Reunite_01" },
	{ type = "text", text = "[placeholder] ผู้เล่นกลับมาถึง..." },
	{ type = "wait", t = 2 },

	-- ===== Cam 2: Parents' introduction/reaction =====
	{ type = "camera", cam = "Reunite_02", t = 1.5 },
	{ type = "text", text = "[placeholder พ่อแม่มีเรื่องบอก]" },
	{ type = "wait", t = 2 },

	-- ===== Cam 3: Player's arrival moment =====
	{ type = "camera", cam = "Reunite_03", t = 1.5 },
	{ type = "text", text = "[placeholder ผู้เล่น: สายหลังเนื้องาน]" },
	{ type = "wait", t = 2 },

	-- ===== Cam 4: Emotional moment between player + father =====
	{ type = "camera", cam = "Reunite_04", t = 1.5 },
	{ type = "text", text = "[placeholder พ่อพูด — ประเมิน/พูดเรื่องความสำเร็จ]" },
	{ type = "wait", t = 2.5 },

	-- ===== Cam 5: Mother's perspective/response =====
	{ type = "camera", cam = "Reunite_05", t = 1.5 },
	{ type = "text", text = "[placeholder แม่พูด — ดีใจ/อยากให้ลูกรู้คุณค่า]" },
	{ type = "wait", t = 2.5 },

	-- ===== Cam 6: Final reconciliation — family together =====
	{ type = "camera", cam = "Reunite_06", t = 1.5 },
	{ type = "text", text = "[placeholder moment เข้าใจกัน — ผู้เล่น ได้ยินพ่อแม่]" },
	{ type = "wait", t = 3 },

	-- ===== Epilogue: settle positions after cutscene =====
	-- root motion ไม่ขยับ HumanoidRootPart จริง — snap คนกลับตำแหน่งที่ควรจะเป็นเมื่อจบฉาก
	{ type = "move", actor = "player", to = "NPCHome_Player_reunite", t = 0 },
	{ type = "move", actor = "พ่อ", to = "NPCHome_พ่อ_reunite", t = 0 },
	{ type = "move", actor = "แม่", to = "NPCHome_แม่_reunite", t = 0 },
}
