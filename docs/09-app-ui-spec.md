# 09 — App UI Spec: วิเคราะห์ PDF หน้า 5–9 เทียบของจริง + วิธีทำให้ตรง

อ้างอิง: PDF ต้นฉบับหน้า 5–9 | สถานะโค้ด ณ 20 ก.ค. (เทส 176) | ตัวเลขใหม่ทุกตัวที่ต้องเพิ่ม → ลง `Config` เสมอ
**เครื่องหมาย:** ✅ ตรงแล้ว | 🟡 มีแต่ไม่ตรงร่าง | 🔴 ยังไม่มี | ❓ PDF ไม่ชัด/ไม่มีตัวเลข — **ต้องถาม user ก่อน implement**

---

## 0. ⛔ ของที่โค้ดปัจจุบัน "มโน" ขึ้นมาเอง — ต้องลบ/แก้ (audit 21 ก.ค. หลังอ่าน PDF ครบ 10 หน้า)

> agent รอบก่อนเขียนโค้ดโดยอ่าน doc ไม่ครบ เลยใส่ feature ที่**ไม่มีใน PDF** 4 จุด ทั้งหมดยังอยู่ในโค้ดตอนนี้ — เจ้าของสายที่ถือไฟล์นั้นแก้ได้เลย

| # | ที่อยู่ | ตอนนี้โค้ดทำอะไร (ผิด) | PDF บอกว่าอะไร | สายที่แก้ |
|---|--------|------------------------|-----------------|-----------|
| 1 | `UI/Apps/EditQTE.luau` ปุ่ม **"อัปโหลดเลย!"** ท้าย QTE | ตัดเสร็จกดอัปได้ทันที **ข้ามแอป Upload ทั้งแอป** → ระบบเลือก title/description ตายสนิท | จอ 3 มีแค่ **Edit more / Done** เท่านั้น ต้องไปอัปที่แอป Upload แยก (หน้า 7-8) | **A** |
| 2 | `UI/Apps/CalendarApp.luau` ปุ่ม **"รับ sponsor"** | โผล่ทุกวันที่ว่าง กดรับได้ไม่จำกัด = ปั๊มเงินได้ฟรี | sponsor เป็น **offer สุ่ม 5%/วัน เฟส 2-3** เด้งมาให้เลือกวางในปฏิทิน ไม่ใช่ปุ่มกดเรียกเอง (หน้า 6) | **B** |
| 3 | `Main.client.luau` — **manage เป็น icon บน desktop** | desktop มี 8 icon | ภาพ PDF มี **7 icon** (upgrade/calendar/edit/message/upload/feedback/bank) — **manage เข้าผ่านปุ่มใน Bank เท่านั้น** (user ยืนยัน 21 ก.ค.) | **B** |
| 4 | `UI/HUD.luau` ช่อง storage โชว์ **"🎬 คลิป N"** | โชว์จำนวนคลิปที่ตัดไว้ | ช่องนั้นคือ **ความจุ "790 GB / 1T"** (footage ที่อัดมา) | **A** |

**เพิ่มเติมที่ยืนยันใหม่ 21 ก.ค.:**
- **Progress bar เฟส** = **10% / 40% / 50%** (เดิมร่างไว้ 10/40/45/**5** แต่ 5% ที่กันไว้ให้ BCA ไม่มี purpose — BCA เป็น cutscene หลังบาร์เต็มแล้ว)
- **Edit จอ 2:** UI ทั้งหมดข้างหลัง (grid 4 ช่อง, timeline waveform, ปุ่มเล่น) = **ของตกแต่งล้วน** ไม่ต้องต่อ logic — ของจริงมีแค่ **วง QTE สีแดง** กับ **พื้นหลังที่สุ่มจาก pool**
- **Upload:** เลือก **title 3 ช้อย + description 3 ช้อย แยกกัน 2 ครั้ง** (ไม่ใช่แค่ title)
- **Calendar:** คอลัมน์ซ้ายสุดชื่อ "Event" = **คลัง block ที่ยังไม่ได้วาง** (เลือกจากคลัง → กดวันปลายทาง)
- **PC:** เข้าโดย **นั่งที่ seat แล้วกด E ค้าง** (ตอนนี้เป็น ProximityPrompt ยืนกดเฉยๆ — ต่างกันเล็กน้อย ปรับได้ทีหลัง)

---

## 1. HUD ติดจอ (PDF หน้า 5 บน)

**ร่างใน PDF:** กล่อง follower + delta ("1,024 +300") / กล่องเงิน + delta ("8,374$ +20") / นาฬิกา 15:24 + วันที่ 24 / **แถบ progress เฟสยาวบนจอ แบ่ง 3 ช่วง (10%-40%-45%-5%) จุด milestone** / ซ้าย: storage "790 GB / 1T" + "1080p ×2.5" + ปุ่ม setting/เสียง / ขวา: mental bar แนวตั้ง 100→0 หัวใจบน-ล่าง / ล่างกลาง: **hotbar 3 ช่อง** (tool อัดคลิป)

| ชิ้น | สถานะ | ต้องทำ |
|------|-------|--------|
| follower/เงิน/นาฬิกา/เฟส | ✅ | — |
| **delta popup** (+300 เด้งข้างตัวเลข) | 🔴 | client เทียบ state เก่า-ใหม่ → TextLabel เด้งจางหาย 1.5 วิ |
| **แถบ progress สู่ 1M** | 🔴 | bar ยาวบนจอ: fill = follower/1M, ขีด milestone 1K/10K/100K, สีต่างตามเฟส |
| storage GB | 🔴 | ผูกกับระบบอัดคลิป (§4) — โชว์ `footageGB / capacity` |
| resolution ×mult | 🟡 | โชว์ 1080p แล้ว — เพิ่มตัวคูณข้างๆ. **✅ lock 26 ก.ค.: ตัวคูณนี้คือ GB/คลิกตอนอัด ไม่เกี่ยวกับคุณภาพคลิป (VidQ)** อ่านจาก `Config.Record.footagePerClickGB[ระดับกล้อง]` ที่มีอยู่แล้ว |
| mental bar | ✅ | มีสีโซนแล้ว — เพิ่มหัวใจบน/ล่างเมื่อได้รูปจาก UIAssets |
| hotbar tool 3 ช่อง | 🔴 | ผูกกับ §4 (กล้อง/มือถือ/ไม้เซลฟี่ = Roblox Tool ใน Backpack — hotbar ได้ฟรี) |
| ปุ่ม setting/เสียง | 🔴 | ปุ่มเปิด panel volume (placeholder ได้) |

## 2. Desktop PC (PDF หน้า 5 ล่าง) — ✅ ครบ (เปลี่ยนเป็น SurfaceGui 21 ก.ค.)

**UI อยู่บนหน้าจอ part จริงในโลก (SurfaceGui) ไม่ใช่ overlay เต็มจอ** — ตาม ref ที่ user ส่ง (จอคอมในเกมมี UI อยู่บนจอ + ปุ่ม RETURN ลอยข้างบน)

| ค่า | รายละเอียด |
|-----|------------|
| Part จอ | `Interact_pcMonitor` **ขนาด 4 × 2.6 studs** (ทุกเครื่องเท่ากัน) หน้าจอ = ด้าน **Front** |
| SurfaceGui | อยู่ใน PlayerGui, `Adornee` = part นั้น, `Active = true` (ปุ่มกดได้), `LightInfluence = 0` (จอเรืองแสงเอง) |
| **Canvas** | `PixelsPerStud = 250` → **1000 × 650 px** |
| กล้อง | zoom เข้าหน้าจอ 0.4 วิ (คำนวณระยะจาก FOV) แล้วคืนตำแหน่งเดิมตอนออก |
| ปุ่มออก | **ScreenGui แยก** ลอยกลางบนจอผู้เล่น (ตาม ref ปุ่ม RETURN) |
| icon แอป | คอลัมน์ซ้าย 5 แถว/คอลัมน์ แสดง **80×80** + ชื่อใต้ |

→ ขนาดรูปทุกใบที่อยู่บนจอคอมต้องอิง canvas 1000×650 นี้ (docs/13 §ที่มาของขนาด)

## 3. Calendar app (PDF หน้า 6)

**ร่างใน PDF:** ตาราง**เดือนเต็ม 7 คอลัมน์ (Sat→Fri) × ~5 แถว** ตัวเลขวัน / วันนี้วงกลม "today" / block เป็นการ์ดสีวางในช่อง: "Marathon ตัดต่อ" (ลากวางได้), "คุยกับพ่อแม่", "พักผ่อน" / **block กินหลายวันได้** ("มีเรื่องกับ Hater" คร่อม 3 ช่อง สีแดง = Canon lock) / ท้ายเดือน "จ่ายค่าเช่า เงินเดือน" marker / โน้ต: "ลาก block ได้แต่ Canon ห้าม" + "มีมากกว่า 1 อย่างให้ลูกน้องทำแทน"

| ชิ้น | สถานะ | ต้องทำ |
|------|-------|--------|
| ตารางเดือน 7×5 | 🔴 (ตอนนี้ list 7 วัน) | grid Frame 7 คอลัมน์ เริ่มวันเสาร์ ช่องละวัน เลขมุม |
| block สี + ชนิด | 🔴 UI | **สี 3 ชนิดเท่านั้น (user 21 ก.ค.): Canon=แดง(lock) / Select=ม่วง / Schedule=เขียว — Sponsor ใช้สี Schedule ไม่แยก** |
| block หลายวัน | ✅ service 21 ก.ค. | `{type, id, length=3}` place เช็คชนทั้งช่วง, ผลเกิดวันจบงาน — เหลือวาดบน grid |
| ย้าย block | ✅ service 21 ก.ค. (ทาง ก) | กดเลือก block → กดวันปลายทาง — action `MoveBlock{fromDay,toDay}` มีแล้ว, Canon/วันผ่านแล้ว/ช่องชน = ไม่ให้ — เหลือฝั่ง UI |
| marker วันตัดรอบ | 🔴 | ทุกวันที่ `(day-1)%7==0` แปะป้าย "จ่ายค่าเช่า" |
| sponsor spawn 5%/วัน (เฟส 2-3) | 🔴 | PDF หน้า 6: โอกาสได้ offer 5% — ตอนนี้กดรับได้ตลอด ต้องเปลี่ยนเป็นสุ่ม offer เข้า Message/ปฏิทิน |
| งานให้ลูกน้องทำแทน | ❓ | ผูกระบบ staff (§8) — รอตัวเลข staff ก่อน |

## 4. ระบบอัดคลิป — Record (PDF หน้า 7 บน) 🔴 ยังไม่มีทั้งระบบ

**ร่างใน PDF:** ถือ tool (กล้อง/มือถือ/ไม้เซลฟี่) เดินในแมพ กด click ที่จุดต่างๆ → ได้ footage ทีละ +1 (มีจุด "+2.4 Bonus!") สะสมจนเต็มความจุ [กระเป๋า] / มุมขวา: resolution ladder โชว์ตัวคูณ ×1.5/×2/×3/×4 ตามระดับกล้อง / storage เต็ม = "1T/1T FULL" อัดต่อไม่ได้

**Logic ที่ต้องสร้าง (✅ ตัวเลข lock แล้ว 21 ก.ค. — docs/02 §9.5 + Config.Record):**
1. `state.footageGB` + ความจุจาก `Config.StorageLadderGB = {128, 256, 512, 1024, 4096, 8192}` (6 ระดับ เริ่ม 128GB)
2. Tool 3 ชิ้นใน StarterPack: `Tool_Camera / Tool_Phone / Tool_Selfie` — Activated → ยิง action `RecordFootage`
3. **โซนถ่ายแบบสุ่มย้ายจุด** (แทน FilmSpot ตายตัว): วงพื้นที่ + ตัวคูณกลางวง + เวลา remaining, อยู่ 120 วิ แล้ว spawn จุดใหม่ (กัน AFK) — จุด spawn เป็นได้ = part `FilmSpot_*` ทีมวางไว้หลายจุด service สุ่มเลือกทีละจุด
4. server: footage ต่อ click = `Config.Record.footagePerClickGB[ระดับกล้อง]` = {4,8,16,32,64,128} × ในโซน = `zoneMultByPhase` (เฟส 1 ×1.5 / 2 ×2 / 3 ×2.5) — ตีความ: อัดนอกโซนได้ที่ base rate (ยังไม่ lock)
5. เต็มความจุ = block + popup "FULL"
6. **ตัดคลิปเปลี่ยนเป็นกิน footage** (§5) — วงจรเต็ม: อัด → footage → ตัด → clip → อัป
7. **ตัด dropdown เปลี่ยน resolution ทิ้ง** (user 21 ก.ค.) — ระดับกล้อง = resolution ตายตัว

## 5. Edit app (PDF หน้า 7 ล่าง)

**ร่างใน PDF:** (จอ 1) "How much footage for this video?" **slider 0→1T** + "footage left: 650 GB" + ปุ่ม Let's go / (จอ 2) จอตัดต่อ: พื้นหลังโปรแกรมตัดต่อ static + ภาพสุ่มจาก pool + **QTE โผล่บน timeline ล่าง** (Q, Z, A วงกลมจังหวะแบบ osu) + โชว์ rating การกดล่าสุด "S!" / (จอ 3) สรุป: Score 182/200, Video Quality: B, stats (label เก่า bad/normal/good/awesome — **ใช้ C/B/A/S ตาม design doc**), footage left, ปุ่ม **Edit more / Done**

| ชิ้น | สถานะ | ต้องทำ |
|------|-------|--------|
| slider เลือก footage | 🔴 | จอแรกก่อน QTE: slider GB (ขั้นต่ำ ❓ *เสนอ 50 GB/คลิป*) — `FinishEdit` ส่ง `footageUsed` ไปหักด้วย |
| QTE บน timeline | 🟡 (ตอนนี้โผล่กลางจอ) | ย้ายปุ่มวิ่งซ้าย→ขวาบนแถบ timeline + จุดกดตรงกลาง — logic scoring เดิมใช้ได้ |
| rating ต่อปุ่ม (S!) | 🟡 | มีสีเขียว/เหลือง/แดงแล้ว — เปลี่ยนเป็น text S!/A/B/C ตามคะแนน 10/7/4/อื่น |
| จอสรุป + Edit more | 🟡 | มีสรุป+tier แล้ว — เพิ่มปุ่ม "Edit more" (วน slider ใหม่ถ้า footage เหลือ) |
| ภาพสุ่มใน preview | 🔴 | pool รูปใน UIAssets (ทีมวาด/แคป) — cosmetic |

## 6. Upload app (PDF หน้า 8 บน)

**ร่างใน PDF:** ซ้าย: คลัง storage เป็น thumbnail แถวตั้ง / กลาง: preview ใหญ่ + **title 3 ตัวเลือก + description 3 ตัวเลือก** (เลือกอันเดียว — กรอบแดง = ที่เลือก) + ปุ่ม upload / โน้ต "Select video to upload first!"

| ชิ้น | สถานะ | ต้องทำ |
|------|-------|--------|
| layout 2 ฝั่ง เลือกก่อนอัป | 🟡 (ตอนนี้ list+ปุ่มเดียว) | ซ้าย list → กดเลือก → ขวาโชว์ preview + ปุ่มอัป |
| title/desc 3 ตัวเลือก | 🔴 | pool ข้อความใน `Content/ClipTitles.luau` (ทีมเขียน) สุ่มโชว์ 3 เลือก 1 เก็บลง `clip.title` — **cosmetic ไม่มีผลตัวเลข** (PDF ไม่ระบุผล) |
| กระแสช่องนี้ (trend tag ×4 bonus) | ❓ | หน้า 8 ล่าง: อัดตามสถานที่ trend → bonus การอัด ×4, random 20%/click — ผูกระบบ Record §4 — **เสนอเป็นงานเฟสหลัง core** |

## 7. Feedback app (PDF หน้า 8 ล่าง)

**ร่างใน PDF:** ซ้าย: list คลิป latest upload (views ต่อคลิป) / กลาง: **กราฟเส้น follower + กราฟ Earn (last 7 days)** / ใต้กราฟ: "Comment from [title]" 2 ชุด + **ช้อยตอบ 3 ปุ่มใต้แต่ละชุด** / ขวา: "กระแสช่องนี้" tags (ร้านอาหาร/สยาม/ธรรมชาติ) / โน้ตขวา: **สัดส่วน comment ตาม VidQ ของคลิป** (C: ⊖40% ◎25% ⊕10%... อ่านไม่ครบ ❓) + ตอบ 3 แบบ: กดใจ(+10/-10 mental), เลือกช้อย, ปล่อยผ่าน

| ชิ้น | สถานะ | ต้องทำ |
|------|-------|--------|
| ตอบ comment | ✅ ทำใหม่ครบ 21 ก.ค. | slot ⊖/◎/⊕ ทอยแยกตามเกรด + heart/ช้อย/skip + สุ่มลำดับปุ่ม — docs/02 §9.6 |
| list คลิป + views | 🟡 | มี history text — เปลี่ยนเป็น list กดได้ + เก็บ `clip.views` (สุ่มจาก follower gain ×สัดส่วน ❓ *เสนอ views = gained × 3–8*) |
| **กราฟ 7 วัน** | 🔴 | ต้องมี `state.history[day] = {follower=, earn=}` — MoneyService/FollowerService บันทึกทุก onDay → วาดกราฟเส้นด้วย Frame บางๆต่อจุด |
| comment weight ตาม tier | ✅ lock 21 ก.ค. | ทำแล้ว — ตารางจริงอยู่ docs/02 §9.6, Comments มี field `sentiment` แล้ว |
| trend tags panel | ❓ | รอระบบ trend (§6) |

## 8. Bank + Manage app (PDF หน้า 9 บน)

**ร่างใน PDF:** 3 กล่องบน: ยอดคงเหลือ / income per week / รายจ่ายรวม per week (แดง) / 3 การ์ด: ค่าอาหาร (⊖ 1K ⊕), ค่าพนักงาน (⊖ 10K ⊕), ค่าเช่า (⊖ 2K ⊕) / ปุ่ม "manage" → **หน้าจ้างพนักงาน:** ซ้าย: สรุปทีม "Video per day 10/20" + bar speed 36/100 + quality 100 + salary 40k / ขวา: การ์ดพนักงาน "Bob" (speed 18, quality 50, salary 20k) ปุ่ม hire — จ้างแล้วเป็น Active + ปุ่ม fire

| ชิ้น | สถานะ | ต้องทำ |
|------|-------|--------|
| 3 กล่องสรุป | 🟡 | มี text — จัดเป็น 3 กล่อง + income/week (ต้องมี history §7) |
| ปุ่ม ⊖⊕ ปรับรายจ่าย | ✅ lock+ทำแล้ว 21 ก.ค. | ปรับงบ/สัปดาห์ step ต่อการ์ด + ผลใจตอนตัดรอบ — docs/02 §9.7 |
| **ระบบพนักงานทั้งหมด** | ✅ 21 ก.ค. | ทำครบแล้ว — StaffService + Manage app (สรุปทีม + การ์ด hire/fire) ตัวเลข docs/02 §9.8 |

## 9. Message app (PDF หน้า 9 กลาง)

**ร่างใน PDF:** HSR style — list คนซ้าย (พนักงาน1, sponsor) / แชทขวา bubble สองฝั่ง / **ช่องตอบ 3 ตัวเลือกล่าง** — เลือกได้แต่ไม่มีผล คำตอบ NPC fix ตาม set

| ชิ้น | สถานะ | ต้องทำ |
|------|-------|--------|
| list คน + แชท bubble | 🟡 (ตอนนี้ text ก้อนเดียว) | 2 pane: list ซ้าย → แชทขวา bubble ซ้าย(NPC)/ขวา(เรา) |
| choice ตอบ 3 ช่อง | 🔴 | ขยาย format `Content/DMs.luau`: `{from, exchanges={{npc="...", choices={"ก","ข","ค"}, reply="..."}}}` — เลือกอะไรก็ได้ NPC ตอบ reply เดิม (ตาม design §6 ไม่นับ choice) |

## 10. Shop/Upgrade app (PDF หน้า 9 ล่าง)

**ร่างใน PDF:** 2 หมวด Camera / Storage — แถวละ **4 การ์ด** (รูป + price + quality + ปุ่ม Buy) + ลูกศรเลื่อนขวา

| ชิ้น | สถานะ | ต้องทำ |
|------|-------|--------|
| การ์ด 4 ใบต่อหมวด | 🟡 (ตอนนี้ปุ่มเดียวซื้อระดับถัดไป) | โชว์การ์ดครบ 4: ซื้อแล้ว=✓, ถัดไป=Buy, ไกลกว่า=lock — logic `BuyUpgrade` เดิมใช้ได้ |
| รูปสินค้า | 🔴 | UIAssets เพิ่ม key `shop_camera_1..4`, `shop_storage_1..4` (ทีมวาด 8 รูป 128×128) |

---

## ลำดับลงมือ (เสนอ)

| # | งาน | ติด ❓ ไหม |
|---|------|------------|
| 1 | HUD: progress bar 1M + delta popup | ไม่ติด — ทำได้เลย |
| 2 | Edit: slider footage + timeline + Edit more | ติดเลข GB (มีค่าเสนอ) |
| 3 | **Record system ทั้งก้อน** (tool/FilmSpot/footageGB) + HUD storage + hotbar | ติดเลข GB/click + ตัวคูณ tool (มีค่าเสนอ) |
| 4 | Feedback: history 7 วัน + กราฟ + comment weight | ติดตาราง % comment (มีค่าเสนอ) |
| 5 | Calendar: grid เดือน + block สี + หลายวัน | ลากวาง = รอ user เลือกวิธี |
| 6 | Upload 2-pane + title 3 ช้อย + Message HSR + Shop การ์ด 4 | Content ทีมเขียน (ClipTitles, DMs format ใหม่) |
| 7 | Staff/Manage ทั้งระบบ | **รอ design session** |
| 8 | Trend tag ×4 | เฟสหลัง core |

**คำถามรอ user ตอบ (สรุป ❓ ทั้งหมด):** ① ความจุ storage 5 ระดับ + GB/click + ตัวคูณ tool ② ตาราง % comment ตาม tier ③ ปุ่ม ⊖⊕ ใน Bank คืออะไร ④ ตัวเลขระบบพนักงาน ⑤ วิธีย้าย block ปฏิทิน (กดเลือก vs ลากจริง) ⑥ สูตร resolution → VidQ multiplier
→ **ทั้ง 6 ข้อตอบครบแล้ว 21–26 ก.ค.** (ข้อ ⑥ = ไม่มีสูตร กล้องคูณแค่ GB/คลิก ไม่แตะ VidQ)
