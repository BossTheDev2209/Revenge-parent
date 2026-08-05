-- Opening — ฉากเปิดเกม (cutscene mode 1 "หนัง") เล่นตอนกด New Game
-- [placeholder] Boss เขียนบท/ท่าทาง/มุมกล้องจริงเอง แก้แค่ list นี้
--
-- step ที่ใช้ได้ (ดู docs/engines/cutscene.md):
--   { type="camera", cam="Opening_1" [, t=วิ] }   มุมกล้อง (Part ใน CutsceneCams/Opening) t = เลื่อนนุ่ม
--   { type="text",   text="..." }                  ซับล่างจอ (letterbox ไม่มีกล่อง)
--   { type="wait",   t=วิ }                         หยุดค้าง
--   { type="anim",   actor="Mom", name="Angry" [, loop=true] }   ตัวละครขยับ
--   { type="face",   actor="Mom", name="Angry" }   สีหน้า
--   { type="bgm",    name="..." } / { type="sound", name="..." }  เสียง
-- actor = ชื่อไฟล์บท/โมเดล ("player" = ตัวผู้เล่น) · cam วางด้วย plugin CutsceneCamTool
-- cam ที่วางไว้ในแมพตอนนี้: Opening_01..Opening_05 (อยู่ใน CutsceneCams/Opening — Persistent Model)
-- easing/เวลา มาจาก attribute Ease/TweenTime บน Part (ตั้งด้วย CutsceneCamTool) — ไม่ต้องใส่ t เอง
-- ใส่ t=/ease= ในสเต็ปได้ถ้าอยาก override
return {
	{type = "focus", target = "Spawn_Phase1" },
	{type = "camera", cam = "Opening_01" },
	{type = "wait", t = 4 },
	{type = "camera", cam = "Opening_02" },--show player sleepin
	{type = "wait", t = 3 },
	{type = "camera", cam = "Opening_03"},--mum open door
	{type = "camera", cam = "Opening_04"},--mum say smth
	{type = "text", text = "ตื่นได้แล้วลูก! บ่ายโมงกว่าแล้วเนี่ย พ่อเขามีเรื่องจะคุยด้วย"},
	{type = "wait", t = 5},
	{type = "camera", cam = "Opening_05"}, --dad furiously waiting
	{type = "wait" , t = 4},
	{type = "camera", cam = "Opening_06"}, --we speak to dad
	{type = "text", text = "โทษทีพ่อเมื่อคืนสตรีมดึกไปหน่อย ว่าแต่พ่อมีเรื่องอะไรจะคุยหรอ?"},
	{type = "wait", t = 5},
	{type = "camera", cam = "Opening_07"},
	{type = "text", text = "ออกไปจากบ้านของฉันสะ แล้วไม่ต้องเสนอหน้ากลับมาอีก"},--dad kick us out of the home
	{type = "wait", t = 3},
	{type = "camera", cam = "Opening_08"}, --we shock
	{type = "wait", t = 1},
	{type = "camera", cam = "Opening_09"}, --mum shocked too
	{type = "wait", t = 2},
	{type = "camera", cam = "Opening_10"},
	{type = "text", text = "ผมบอกกี่รอบแล้ว ว่าไอที่ผมทำอยู่นี่มันทำเงินได้จริงๆ! แค่..ขอเวลาให้ผมอีกไม่ได้หรอ"},
	{type = "wait", t = 4},
	{type = "camera", cam = "Opening_11"},
	{type = "text", text = "ขอเวลา? ฉันให้โอกาสแกมาทั้งปีแล้ว ถ้าอยากแดกเงินพ่อแม่ไปวันๆอย่างงี้มึงก็ไปทำงาน \"สตรีม\" ของมึงที่อื่นเถอะ"},
	{type = "wait", t = 5},
	{type = "camera", cam = "Opening_12"},
	{type = "text", text = "ได้! จะเอางี้ใช่ไหม"},
	{type = "wait", t = 2},
	{type = "camera", cam = "Opening_13"},
	{type = "text", text = "งั้นผมไม่อยู่แม่งแล้ว! เดี๋ยวผมจะทำให้ดูเองว่าไองาน \"สตรีม\" ที่พ่อว่าเนี่ย.. มันหากินได้จริงๆ!"},
	{type = "wait", t = 4},
	{type = "camera", cam = "Opening_14"},
	{type = "text", text = "ใจเย็นๆกันก่อนนะทั้งสองคน แม่ว่าเราค่อยๆคุยปรับความเข้าใจกันก่อนดีกว่านะ-"},
	{type = "wait", t = 2},
	{type = "camera", cam = "Opening_15"},
	{type = "text", text = "แม่ไม่ต้องมายุ่งเลย! เรื่องนี้ผมจัดการเองได้"},
	{type = "wait", t = 3},
	{type = "camera", cam = "Opening_16"},
	{type = "text", text = "นั่นแหละ! มึงไปทำงานที่มึงชอบให้หนำใจเลย-"},
	{type = "wait", t = 3},
	{type = "camera", cam = "Opening_17"},
	{type = "text", text = "-แล้วไม่ต้องมาเกาะพวกกูแดกอีก.. หึ"},
	{type = "wait", t = 3},
	{type = "camera", cam = "Opening_18"},
	{type = "text", text = "คุณคะ คุณพูดแรงเกินไปแล้วนะ! พูดแบบนี้-"},
	{type = "wait", t = 3},
	{type = "camera", cam = "Opening_19"},
	{type = "text", text = "-เดี๋ยวมันไม่กลับบ้านมาจะทำยังไงล่ะ"},
	{type = "wait", t = 5},
	{type = "camera", cam = "Opening_20"},
	{type = "text", text = "แล้วทีนี้ฉันจะเอายังไงต่อดีละเนี่ย..."},
	{type = "wait", t = 2},
	{type = "camera", cam = "Opening_22"},
	{type = "wait", t = 2},
	{type = "camera", cam = "Opening_21"},
	{type = "text", text = "-ฉันกลายเป็นคนไร้บ้านไปสะแล้ว ;-;"},
	{type = "wait", t = 5},
	-- เพิ่ม beat: สลับ cam Opening_03..05 + ใส่ text/anim/face จริง
	-- { type = "anim", actor = "Mom", name = "Angry" },  -- ต้องมี rig Humanoid + Animation object (ดู Q2)
	-- { type = "face", actor = "Mom", name = "Angry" },
}
