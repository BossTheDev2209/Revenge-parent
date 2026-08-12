-- FaasaiBetray — cutscene ตอนฟ้าใสทรยศ (follower ถึง 500K = Config.BetrayalMilestone · flags.betrayed ตั้งที่ server แล้ว)
-- เล่นผ่าน CutscenePlayer (mode 1) — เจียเจีย + player เล่นคนละ clip (root motion จริง ทำด้วย Moon Animator)
-- trigger: follower ≥ 500K → ไปแมพ 3.1 → กลับเฟส 3 → เล่นครั้งเดียว (Main.client · flag betray_cutscene_done กันซ้ำ)
--
-- animation (ทีม register เป็น Animation object ใน ReplicatedStorage.Animations.<actor> ชื่อ "FaasaiBetray"):
--   เจียเจีย rbxassetid://109403178351149 → Animations.เจียเจีย.FaasaiBetray
--   player   rbxassetid://72190966655600  → Animations.player.FaasaiBetray
--
-- กล้อง (spec user, 60fps · clip ยาว 10 วิ = 600 เฟรม) — cam โผล่ที่ต้นช่วง, wait = ส่วนต่างระหว่าง cam:
--   cam1 0f | cam2 120f=2.0s | cam3 240f=2.0s | cam4 280f=0.667s | cam5 375f=1.583s | cam6 480f=1.75s | จบ 600f=2.0s
--   cam6 tween = In, tweentime = 0.5 (ตัวอื่นตัดภาพ) — ปรับได้ตอน playtest
-- ⚠️⚠️ root motion ไม่ขยับ HumanoidRootPart จริง — จบ clip แล้ววาปกลับตำแหน่งจริง (ดู FaasaiJoin/JiajiaJoin)
--   เจียเจีย clip ยาว → move ไป couch (ที่อยู่ถาวรเฟส 3) ก่อนจบฉาก · player clip สั้น (in-place reaction) ไม่ต้อง move
return {
	{ type = "focus", target = "Spawn_Phase3" },
	-- cam ตัดก่อนสิ่งอื่น (ScreenTransition fade ออกแล้ว letterbar โผล่ทันที ไม่เห็นมุม player เดิม)
	{ type = "camera", cam = "Faasai_betray_01" },
	{ type = "anim", actor = "เจียเจีย", name = "FaasaiBetray", loop = false },
	{ type = "anim", actor = "player", name = "FaasaiBetray", loop = false },
	{ type = "wait", t = 2 }, -- 0 → 120f
	{ type = "camera", cam = "Faasai_betray_02" },
	{ type = "wait", t = 2 }, -- 120 → 240f
	{ type = "camera", cam = "Faasai_betray_03" },
	{ type = "wait", t = 0.667 }, -- 240 → 280f
	{ type = "camera", cam = "Faasai_betray_04" },
	{ type = "wait", t = 1.583 }, -- 280 → 375f
	{ type = "camera", cam = "Faasai_betray_05" },
	{ type = "wait", t = 1.75 }, -- 375 → 480f (cam5 ค้างถึง 480 แล้ว cam6 ตัด)
	{ type = "camera", cam = "Faasai_betray_06", ease = "In", t = 0.5 }, -- cam6 tween In 0.5s (spec user)
	{ type = "wait", t = 2 }, -- 480 → 600f จบ clip
	{ type = "move", actor = "เจียเจีย", to = "NPCHome_เจียเจีย_couch", t = 0 }, -- แก้ root motion snap-back → ที่อยู่ถาวร (couch)
	-- player clip สั้น in-place = ไม่ต้อง move (เหมือน JiajiaJoin) · ถ้า playtest เห็นวาป ค่อยเพิ่ม move player → NPCHome_Player_faasai_betray
}
