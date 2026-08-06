-- ป้าไหม — NPC ประจำเฟส 1 (WorldNPC) · docs/05 §4
-- บททางเดียว หรือใส่ช้อยได้ (บางตัวมีช้อย — docs/engines/dialogue.md §2.5)
-- ⚠️ [placeholder] — รอเขียนบทจริง
return {
 p1 = {
  { speaker = "???", text = "[normal]น้องเสื้อเขียวตรงนั้น [fast]เส้นเล็กกลับบ้านได้แล้วนะ" },
  { speaker = "???", text = "[normal]ส่วนหนู" },
  { speaker = "???", text = "[fast]หนูอะแหละที่อยู่ตรงหน้าพี่ หนูจะเอาอะไร?" },
  { speaker = "Player", text = "[normal](ไหนๆก็เริ่มหิวพอดี สั่งอะไรกินสักหน่อยดีกว่า)" },
  {
   choices = {
    { text = "เส้นเล็กน้ำ", tone = "neutral" },
    { text = "ข้าวมันไก่", tone = "neutral",
     reply = {
      { speaker = "???", text = "[fast]ตอนนี้ข้าวยังไม่สุกอะลูก เอาอย่างอื่นก่อนได้ไหม" },
      { speaker = "Player", text = "[slow]อืมมมมม" },
      { speaker = "Player", text = "[normal]ถ้างั้นเอาเป็นเส้นเล็กน้ำก็ได้ครับ" },
     } },
    { text = "ข้าวหน้าเนื้อวัวกาวิว เอ้ยวากิว", tone = "neutral",
     reply = {
      { speaker = "???", text = "[fast]บักห่านี่ เห็นร้านนี้เป็นร้านอาหารญี่ปุ่นหรือไง?" },
      { speaker = "Player", text = "[normal]แต่ผมอยากกินจริงๆนะครับ" },
      { speaker = "???", text = "[fast]เอาเป็นอย่างอื่นได้ไหม ถ้าไม่งั้นหนูอาจจะต้องไปร้านอื่น" },
      { speaker = "Player", text = "[normal]เส้นเล็กน้ำก็ได้ครับ" },
     } },
   },
  },
  { speaker = "???", text = "[fast]ข้นใส?" },
  {
   choices = {
    { text = "ข้นอีสาน", tone = "neutral",
     reply = {
      { speaker = "???", text = "[fast]ฮ่วย!", bold = true },
      { speaker = "???", text = "[fast]ป้าบ่หมายถึงคนที่ไหน" },
      { speaker = "???", text = "[fast]ป้าหมายถึงเราจะเอาน้ำข้น หรือน้ำใส" },
     } },
    { text = "น้ำใส", tone = "neutral" },
    { text = "น้ำข้น", tone = "neutral" },
   },
  },
  { speaker = "Player", text = "[normal]ผมกินผักได้นะครับ ใส่มาได้เลย" },
  { speaker = "???", text = "[fast]รอแปปนะลูก" },
  "[fast](ป้าคนนี้รังสรรค์เมนูเส้นเล็กของคุณด้วยความรวดเร็วและเชี่ยวชาญ)",
  { speaker = "???", text = "[fast]ป้าไหมทำเสร็จแล้วนะลูก กลับบ้านหรือทานนี้นะลืมถามเลย" },
  { speaker = "Player", text = "[normal]ทานที่นี้ก็ได้ครับ" },
  { speaker = "ป้าไหม", text = "" },
 },
}
