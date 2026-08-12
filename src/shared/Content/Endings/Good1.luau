-- Ending Good1 — คัตซีนจบเกม (ครอบครัวคืนดีหลัง BCA) · เพื่อน prompt timing มา 12 ส.ค.
-- เล่นผ่าน CutscenePlayer (Main.client: flags.ending → require ไฟล์นี้ → play → fade "— จบ —" → กลับ main menu)
--
-- ★ timing เพื่อนให้มาเป็น "เฟรม" ของ animation (Moon Animator) — แปลงเป็นวินาทีด้วย FPS ด้านล่าง
--   ถ้ากล้องตัดไม่ตรงจังหวะ anim → ปรับ FPS ค่าเดียว (วัดจริง: player.BCAEnding.Length ควร ≈ 2034/FPS วินาที)
--   Moon Animator ปกติ export 30fps — ตั้ง 30 ไว้ก่อน ยืนยันตอน playtest แล้วปรับ
--
-- animation id (ยืนยัน permission แล้วสร้าง Animation instance ให้แล้ว):
--   player → ReplicatedStorage.Animations.player.BCAEnding (95019193422512)
--   พ่อ    → ReplicatedStorage.Animations.พ่อ.BCAEnding    (124773821855617)
--   แม่    → ReplicatedStorage.Animations.แม่.BCAEnding    (114106993887648)
--
-- ⚠️⚠️ เพื่อนต้องเซ็ตในซีนก่อนใช้จริง (ตอนนี้ยังไม่มี — คัตซีนจะเล่นแต่กล้องหาไม่เจอ):
--   1. วาง Part กล้อง cam1..cam13 ใน Workspace.CutsceneCams (ใช้ tools/CutsceneCamTool วาง/ส่อง/พรีวิว)
--      ด้าน Front ของ Part = ทิศกล้องมอง (docs/engines/cutscene.md §3)
--   2. จัด rig player + NPC_special_พ่อ + NPC_special_แม่ ให้อยู่จุดฉากจบ ตรงกับที่กล้องเล็ง
--      (ending ไม่ teleport ให้ — เล่นตรงที่ player ยืนตอนจบ · ถ้าฉากจบอยู่คนละที่ ต้องเพิ่ม step ย้าย
--       หรือให้ BCA canon event พาไปจุดนั้นก่อน — บอกผมถ้าต้องการ ผมเติม move/focus ให้)
--   3. เฟรมกล้องที่เพื่อนกำหนด (ช่วงที่ไม่ระบุ = ค้างช็อตเดิม): cam3 ค้าง 550-900, cam6 ค้าง 1215-1230
local FPS = 30
local function f(frames)
	return frames / FPS
end

return {
	-- เล่น animation ทั้ง 3 ตัวพร้อมกันตั้งแต่ต้น (วิ่งไปตาม timeline เดียวกับกล้องที่ตัดด้านล่าง)
	{ type = "anim", actor = "player", name = "BCAEnding", loop = false },
	{ type = "anim", actor = "พ่อ", name = "BCAEnding", loop = false },
	{ type = "anim", actor = "แม่", name = "BCAEnding", loop = false },

	-- กล้องตัด (cut) ตามช่วงเฟรม — cut ที่ต้นช่วง ค้างจนถึง cut ถัดไป (ช่วง gap = ค้างช็อตเดิมเอง)
	{ type = "camera", cam = "cam1" }, -- 0
	{ type = "wait", t = f(180) },
	{ type = "camera", cam = "cam2" }, -- 180
	{ type = "wait", t = f(210) },
	{ type = "camera", cam = "cam3" }, -- 390 (ค้างยาวคลุม gap 550-900 ด้วย)
	{ type = "wait", t = f(510) },
	{ type = "camera", cam = "cam4" }, -- 900
	{ type = "wait", t = f(70) },
	{ type = "camera", cam = "cam5" }, -- 970
	{ type = "wait", t = f(122) },
	{ type = "camera", cam = "cam6" }, -- 1092 (ค้างคลุม gap 1215-1230)
	{ type = "wait", t = f(138) },
	{ type = "camera", cam = "cam7" }, -- 1230
	{ type = "wait", t = f(65) },
	{ type = "camera", cam = "cam8" }, -- 1295
	{ type = "wait", t = f(105) },
	{ type = "camera", cam = "cam9" }, -- 1400
	{ type = "wait", t = f(235) },
	{ type = "camera", cam = "cam10" }, -- 1635
	{ type = "wait", t = f(265) },
	{ type = "camera", cam = "cam11" }, -- 1900
	{ type = "wait", t = f(134) }, -- ค้าง cam11 จนจบ anim (2034)

	-- outro: ตัดไป cam12 แล้วเลื่อนนุ่มไป cam13 3 วิ → จบ → Main.client fade "— จบ —" → main menu
	{ type = "camera", cam = "cam12" },
	{ type = "camera", cam = "cam13", t = 3, ease = "InOut" },
	{ type = "wait", t = 3 },
}
