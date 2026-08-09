-- CanonEvents.luau — dialogue popup ต่อ milestone (client drain pendingEvents → DialogueUI)
-- ★ placeholder milestone popup ถูกเอาออกหมดแล้ว (user, 9 ส.ค.) — ไม่มี id ในนี้ = drain ยิง EventSeen เงียบๆ
--   (Main.client: ev == nil → fireAction EventSeen ทันที ไม่ขึ้นกล่องข้อความ)
--   flag/mental drain/betrayed/BCA queue ใน checkMilestones ยังทำงานปกติ — ไม่เกี่ยวกับไฟล์นี้
--
-- story beat จริง (faasai เข้าร่วม / ทรยศ / BCA→พ่อแม่) เล่นผ่าน StoryBeat ไม่ใช่ popup ในนี้
-- อยากได้ dialogue popup กลับต่อ milestone ไหน = ใส่ ["milestone_<n>"] = { dialogue = {..} } ตรงนี้
return {}
