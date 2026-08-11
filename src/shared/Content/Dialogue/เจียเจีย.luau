-- เจียเจีย — เพื่อนร่วมทางคนสอง (อดีตทีมพี่เปิ้ล อุดมการณ์ตรงกับเรา) เข้าเฟส 3 = อยู่จนจบ — docs/02 §9.4, docs/16 §53
-- ⚠️ [placeholder] — รอบทจริง เขียนแทนข้อความในลิสต์ได้เลย (โครง key ห้ามลบ)
-- p3 = บทเต็มครั้งแรก เล่นตรงหลัง JiajiaJoin cutscene (StoryBeat เรียกตรง ไม่ผ่าน prompt) — Main.client mark seen ให้เอง
-- again = คุยซ้ำทาง prompt ปกติหลังจากนั้น (ห้อง/ที่ไหนก็ได้ที่ไม่ใช่ byLoc.park)
-- byLoc.park = ชวนคุยที่สวนหลังบ้าน (ต้องตั้ง state.npcLoc["เจียเจีย"]="park" ก่อน — ดู docs/engines/dialogue.md §byLoc)
--   ใช้ช้อย { teleport = "ชื่อ Part" } เลือกแมพปลายทาง (มอไซค์ไปส่ง) ตรงนี้ได้ ไม่ใช่ branching (docs/engines/dialogue.md §choices)
-- after = หลังฟ้าใสทรยศ (flags.betrayed — flag เดียวกับที่ฟ้าใสใช้)
return {
	p3 = { "[placeholder] เจียเจีย เฟส 3 — เพิ่งเข้าร่วมทีม หลัง cutscene JiajiaJoin" },
	again = { "[placeholder] เจียเจีย คุยซ้ำ — ทำงานด้วยกันมาสักพักแล้ว" },
	byLoc = {
		park = { "[placeholder] เจียเจีย ชวนคุยที่สวนหลังบ้าน — จะพาไปไหนดี? (ช้อย teleport เลือกแมพ)" },
	},
	after = { "[placeholder] เจียเจีย หลังฟ้าใสทรยศ — ปลอบ/คุยเรื่องที่เกิดขึ้น" },
}
