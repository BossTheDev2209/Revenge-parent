-- UIAssets.luau — รูปทุกชิ้นของ UI อยู่ที่นี่ที่เดียว
-- ★ วิธีใช้: วาดรูป → อัปโหลดใน Studio (Asset Manager) → Copy Asset ID → วางแทน "" ในคีย์ที่ตรงกัน
-- ปล่อย "" = โค้ดใช้ตัวหนังสือ/emoji แทนอัตโนมัติ (เกมไม่พังระหว่างรอรูป)
-- รายละเอียดรูปแต่ละชิ้น + ขนาด + priority → docs/13-art-assets.md
-- ⚠️ ห้ามเปลี่ยนชื่อคีย์ (โค้ดหาไม่เจอ) | ทุกคีย์ที่ลงท้าย _fill ต้องเป็นภาพ**ขาวล้วน** โค้ด tint สีเอง
return {
	-- ===== HUD ติดจอ (PDF หน้า 5 บน) =====
	hud_follower = "",         -- คนตัวเล็ก 64×64
	hud_money = "",            -- ธนบัตร/กระเป๋าเงิน 64×64
	hud_storage = "",          -- โฟลเดอร์/ฮาร์ดดิสก์ (ความจุ GB) 64×64
	hud_camera = "",           -- กล้อง (resolution) 64×64
	hud_calendar = "",         -- ปฏิทินฉีก เว้นกลางใส่เลขวัน 64×64
	hud_heart = "",            -- หัวใจ หัว/ท้ายหลอดใจ 64×64
	hud_mentalbar_back = "",   -- รางหลอดใจแนวตั้ง 44×480
	hud_mentalbar_fill = "",   -- fill แนวตั้ง ขาวล้วน 36×460
	hud_progress_back = "",    -- รางแถบ progress แนวนอน แบ่ง 10/40/50% 1024×48
	hud_progress_fill = "",    -- fill แนวนอน ขาวล้วน 1000×36
	hud_hotbar_slot = "",      -- ช่อง hotbar ว่าง 96×96
	hud_panel = "",            -- กรอบกล่อง HUD 9-slice 128×48
	hud_delta_up = "",         -- ลูกศรขึ้นเล็ก (popup +300) 32×32
	btn_setting = "",          -- ฟันเฟือง 64×64
	btn_sound = "",            -- ลำโพง 64×64

	-- ===== Tool อัดคลิป (Tool.TextureId — PDF หน้า 7) =====
	tool_camera = "",          -- 256×256
	tool_phone = "",
	tool_selfie = "",

	-- ===== Desktop PC — icon 7 แอป (ไม่มี manage: เข้าผ่าน Bank) =====
	app_shop = "",             -- = แอป "upgrade" ในภาพ PDF (id ในโค้ดคือ shop) 128×128
	app_calendar = "",
	app_edit = "",
	app_message = "",
	app_upload = "",
	app_feedback = "",
	app_bank = "",
	btn_exit = "",             -- ปุ่ม power 64×64

	-- wallpaper ต่อเฟส — สัดส่วน 1.6:1 ตรงจอในเกม (4×2.6 studs) ห้ามใช้ 16:9
	wallpaper_phase1 = "",     -- โน้ตบุ๊คมือสอง จอหม่น 1024×640
	wallpaper_phase2 = "",     -- desktop ฟ้าสดใส
	wallpaper_phase3 = "",     -- เครื่องเทพ ดาร์ค+neon

	-- ===== Edit app (PDF หน้า 7 ล่าง) =====
	edit_workspace_bg = "",    -- ภาพโปรแกรมตัดต่อทั้งหน้า (ตกแต่งล้วน) 1024×640
	qte_ring_outer = "",       -- วงแหวนหด ขาวล้วน 256×256
	qte_ring_target = "",      -- วงเป้าหมายตรงกลาง 256×256

	-- ภาพพื้นหลังคลิป (สุ่มตอนตัด + ใช้เป็นปกคลิปใน Upload/Feedback) 640×360
	clip_cover_1 = "",
	clip_cover_2 = "",
	clip_cover_3 = "",
	clip_cover_4 = "",
	clip_cover_5 = "",
	clip_cover_6 = "",

	-- ===== Shop: 3 หมวด × 6 ระดับแรก (PDF หน้า 9 ล่าง) 128×128 =====
	-- ระดับ 7-15 **ไม่ต้องวาด** — ไม่มีคีย์ = การ์ดใช้ emoji ของหมวดแทนอัตโนมัติ
	-- (ระดับ 7+ เป็นของ endgame ที่ซื้อไม่ไหวในรอบเดียวอยู่แล้ว — docs/02 §9.5)
	shop_camera_1 = "", shop_camera_2 = "", shop_camera_3 = "",
	shop_camera_4 = "", shop_camera_5 = "", shop_camera_6 = "",
	shop_storage_1 = "", shop_storage_2 = "", shop_storage_3 = "",
	shop_storage_4 = "", shop_storage_5 = "", shop_storage_6 = "",
	shop_pc_1 = "", shop_pc_2 = "", shop_pc_3 = "",
	shop_pc_4 = "", shop_pc_5 = "", shop_pc_6 = "",

	-- ===== Bank + Manage (PDF หน้า 9 บน) =====
	bank_food = "",            -- จานข้าว 128×128
	bank_staff = "",           -- คนสองคน
	bank_rent = "",            -- บ้าน
	btn_minus = "",            -- ปุ่มกลม ⊖ 64×64
	btn_plus = "",             -- ปุ่มกลม ⊕ 64×64
	staff_avatar = "",         -- silhouette ในกรอบ (การ์ดพนักงาน) 128×128
	icon_speed = "",           -- สายฟ้า/นาฬิกา 48×48
	icon_quality = "",         -- ดาว 48×48

	-- ===== Message (PDF หน้า 9 กลาง) =====
	avatar_default = "",       -- โปรไฟล์วงกลม 64×64
	avatar_player = "",
	chat_bubble = "",          -- บับเบิล 9-slice 96×64

	-- ===== Main Menu + Dialogue =====
	-- menu_background ตัดทิ้งแล้ว 27 ก.ค. — เมนูเป็นฉากจริง 3D (docs/05 §3.7)
	menu_logo = "",            -- 1024×256
	book_page = "",            -- texture หน้าสมุด (หน้าโหลดเซฟ) 512×384
	dialogue_box = "",         -- กรอบข้อความ 9-slice 512×160
	cursor = "",               -- เคอร์เซอร์ในจอ (ถ้าอยากมี) 32×32
}
