-- arc: เฟส 1 อ่อนปวกเปียก → เฟส 2 เก่งจนเป็นกำลังผลิตคุณภาพสูงสุด → ทรยศที่ 500K
-- ⚠️ [placeholder] — รอบทจริง เขียนแทนข้อความในลิสต์ได้เลย (โครง key ห้ามลบ)
-- p2 = ฟ้าใสAfterCutscene — สร้างจาก tools/dialogue-editor.html (ดู docs/engines/dialogue.md)
return {
	p1 = { "[placeholder] เจ เฟส 1 — มาขอช่วยงาน ยังทำอะไรไม่เป็น" },
	p2 = {
		{ speaker = "???", text = "[fast]สวัสดีค่ะ [fast]เราเจอกันอีกแล้วนะคะ", pose = "Female_idle" },
		{
			choices = {
				{ text = "อันนี้น้องเป็นใครอะ", tone = "neutral",
					reply = {
						{ speaker = "???", text = "[fast]พี่ไม่รู้จักหนูก็ไม่แปลกหรอกค่ะ!\n[normal]แต่หนูเคยให้อาหารพี่น่ะ", pose = "คันหัว" },
						{ speaker = "???", text = "แต่เหมือนจำได้ว่าตอนนั้นพี่หลับอยู่มั้ง 55" },
						"(จบแล้วชีวิตนี้ T^T)",
					} },
				{ text = "น้องสตอล์คตามพี่มาหรอ", tone = "neutral",
					reply = {
						{ speaker = "???", text = "[slow]อ.อ..[normal]อะ [fast]เอ๋ ปะ..[normal]เปล่านี่คะ เหหห~~", pose = "Female_shy_idle" },
						{ speaker = "???", text = "[fast]หนูก็แค่บังเอิญ[normal][b]รู้ชื่อพี่[/b] [normal][b]รู้ที่อยู่พี่[/b] [normal][b]รู้อายุพี่[/b] [normal][b]รู้ชื่อช่อง[/b]พี่เท่านั้นเอง!" },
					} },
				{ text = "เจอกัน..?", tone = "neutral",
					reply = {
						{ speaker = "???", text = "[fast]ใช่แล้วค่ะ!" },
						{ speaker = "???", text = "[fast]ตอนนั้นพี่นอนอยู่บนสะพานลอย\n[fast]หนูเห็นแล้วสงสาร[slow]เลย[fast]วางอาหารไว้ให้น่ะค่ะ!", pose = "Head_down" },
						"(จบแล้วชีวิตนี้ T^T)",
					} },
			},
		},
		{ speaker = "ฟ้าใส", text = "[fast]งั้นขอแนะนำตัวอย่างเป็นทางการนะคะ!", pose = "Female_idle" },
		{ speaker = "ฟ้าใส", text = "[fast]หนูชื่อ \"ฟ้าใส\" อายุ 20 ปี!\n[fast]เป็นนักศึกษาปีที่ 2 ของมหาวิทยาลัยเกษตรศาสตร์ วิทยาเขตบางเขนค่ะ!" },
		{ speaker = "ฟ้าใส", text = "[fast]ปัจจุบันหนูอยู่ที่คอนโดแถวลาดพร้าว ซอยลาดพร้าว 71 \n[fast]ห้องหนูอยู่ชั้น 12 ขนาดประมาณ 28 ตารางเมตร\n[fast]ระเบียงหันไปทางทิศตะวันออก!" },
		{
			choices = {
				{ text = "อะ..เอ่อ", tone = "neutral" },
			},
		},
		{ speaker = "ฟ้าใส", text = "[fast]พ่อของหนูน่ะนะเป็นคนนครปฐม\n[fast]ส่วนแม่เป็นคนลำปาง" },
		{ speaker = "ฟ้าใส", text = "[fast]สถานะยังโสด และไม่มีคนคุย\n[fast]สิ่งที่ชอบก็คงเป็นแมวกับการถ่ายรูปค่ะ!" },
		{
			choices = {
				{ text = "อะ..อ.เอ่อ ฟ้าใสลูก", tone = "neutral" },
			},
		},
		{ speaker = "ฟ้าใส", text = "[fast]ที่คอนโดหนูมีแมวส้มที่เจอบ่อยตรง lobby\n[fast]หนูตั้งชื่อให้มันว่า “ไอตูด” ค่ะ! \n[fast]ถึงเจ้าของมันจะเรียกว่าโมจิก็เถอะ" },
		{
			choices = {
				{ text = "พอออออ!!!!", tone = "neutral" },
			},
		},
		{ speaker = "ฟ้าใส", text = "[slow]โอ๊ะ.. ขอโทษทีค่ะได้ใจไปหน่อย bleh", anim = "Head_down_transition" },
		{ speaker = "ฟ้าใส", text = "[fast]งั้นเข้าประเด็นเลยนะคะ!" },
		{
			choices = {
				{ text = "ค่อยๆนะหนู พี่ขอล่ะ🙏", tone = "neutral" },
			},
		},
		{ speaker = "ฟ้าใส", text = "[slow]คือว่า...", anim = "Female_shy_idle" },
		{ speaker = "ฟ้าใส", text = "[slow]หนู..." },
		{ speaker = "ฟ้าใส", text = "[slow]ชอบ..." },
		{
			choices = {
				{ text = "ชอบพี่?????", tone = "neutral" },
			},
		},
		{ speaker = "ฟ้าใส", text = "[fast]สไตล์การทำคลิปของพี่มากเลยค่ะ!", anim = "Pointing_transition" },
		{
			choices = {
				{ text = "จบละน้องงง", tone = "neutral" },
			},
		},
		{ speaker = "ฟ้าใส", text = "[fast]คลิปพี่มันให้ฟีลเหมือนพวกคลิปต่างชาติเลยอะ\n[fast]แบบ.." },
		{ speaker = "ฟ้าใส", text = "[fast]หนูไม่ค่อยชอบคลิปคนไทยสมัยนี้เลยอ่ะ", anim = "Head_down_transition" },
		{ speaker = "ฟ้าใส", text = "[fast]มันเหมือนทำเพราะเงินอย่างเดียวอ่ะ\n[fast]แต่คลิปพี่[slow]..." },
		{ speaker = "ฟ้าใส", text = "[fast]หนูสัมผัสได้ถึง [b]passion[/b] ค่ะ!" },
		{ speaker = "ฟ้าใส", text = "[fast]เพราะฉะนั้นให้หนูฝึกงานกับพี่ได้ไหมคะ[slow]..." },
		{ speaker = "ฟ้าใส", text = "[fast]ไม่ต้องห่วงเรื่องค่าจ้างเลยนะคะ!" },
		{ speaker = "ฟ้าใส", text = "[fast]หนูจะทำให้ฟรีๆเลยถือว่าฝึกมือหนูไปด้วย" },
		{
			choices = {
				{ text = "เอาสิคนหัวคิดแบบเดียวกัน รวมกันมันส์กว่า!", tone = "neutral" },
			},
		},
	},
	p3 = { "[placeholder] เจ เฟส 3 — ก่อนทรยศ (ใช้ได้จนกว่า flags.betrayed ติด)" },
	after = { "[placeholder] เจ หลังทรยศ — เจอกันหลังไปอยู่กับคู่แข่ง" },
	-- byLoc: คุยตอน state.npcLoc["ฟ้าใส"] ตรง key นี้พอดี (ดู docs/engines/dialogue.md §byLoc)
	byLoc = {
		-- คุยตอนนั่งเตียงในห้อง (npcLoc="bed" ตั้งตอน StoryBeat.settle หลัง FaasaiJoin จบ)
		bed = {
			p = { "[placeholder] ฟ้าใสบนเตียง ครั้งแรก" },
			again = { "[placeholder] ฟ้าใสบนเตียง คุยซ้ำ" },
		},
		-- คุยที่สวนสาธารณะ (npcLoc="park" — ยังไม่มี trigger ตั้งค่านี้ ต้องเพิ่มทีหลัง)
		-- ⚠️ spicy ตามที่ขอ — เขียนแทนบรรทัด [placeholder] ได้เลย ห้ามลบ field cam (กล้องพัง ตกกลับไป zoom-หน้าเดิม)
		-- ตั้งชื่อ Part กล้องใน Workspace.CutsceneCams ผ่าน tools/CutsceneCamTool.plugin.luau (ปุ่ม Place Cam)
		-- แล้วใส่ชื่อ Part ที่ cam ตรงนี้ — ตัวอย่างเดาไว้ 2 ชื่อ ปรับตามที่วางจริง
		park = {
			p = {
				{ speaker = "ฟ้าใส", text = "[placeholder] ฟ้าใสชวนคุยที่สวนสาธารณะ ครั้งแรก", cam = "FaasaiPark_01" },
				{ speaker = "ฟ้าใส", text = "[placeholder] บรรทัดต่อไป — ตัดกล้องมุมอื่น", cam = "FaasaiPark_02" },
			},
			again = {
				{ speaker = "ฟ้าใส", text = "[placeholder] ฟ้าใสที่สวนสาธารณะ คุยซ้ำ", cam = "FaasaiPark_01" },
			},
		},
	},
}

