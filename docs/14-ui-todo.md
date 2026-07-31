# 14 — UI ที่คุยกันไว้แต่ยังไม่ได้ทำ (เช็กลิสต์ของบอส)

**อัปเดต:** 28 ก.ค. 2569 · **เจ้าของงานทั้งหมด: บอส (รณกร)** — งานวาดรวมศูนย์แล้ว (docs/10 §1.4, docs/13 หัวไฟล์)
**ไฟล์นี้คืออะไร:** รวมทุกอย่างที่ **เคยคุย/ตกลงกันแล้วว่าต้องมี UI แต่ยังไม่ได้ลงมือ** — ทั้งรูปที่ต้องวาด, layout ที่ยังไม่ตรงภาพร่าง, และ decision ที่ค้างจนทำ UI ต่อไม่ได้
**อ่านคู่กับ:** `docs/13-art-assets.md` (สเปกขนาดรูป) · `docs/09-app-ui-spec.md` (spec ต่อแอป) · `docs/12` (ถอด PDF)

---

## 0. สรุปสั้น — ถ้ามีเวลาแค่วันเดียวทำอะไร

1. วาด 🅿️0 27 ชิ้นใน docs/13 (เกมดูครบทันที ที่เหลือ emoji fallback ไม่พัง)
2. เคลียร์ §2 "decision ค้าง" 3 ข้อ — ไม่เคลียร์ = 3 แอปนี้ทำต่อไม่ได้จริงสักที
3. §3 map/ฉาก 3 จุดที่ UI ผูกอยู่ (ร้าน / เตียง / จอคอมเฟส 2-3)

---

## 0.5 ⭐ HUD ย้ายมาอยู่ `StarterGui` แล้ว (29 ก.ค.) — แต่งใน Studio ได้เลย

**`StarterGui.Gui_HUD`** = ของจริงที่เกมใช้ ไม่ใช่ภาพตัวอย่าง — คลิกดู/ลากย้าย/เปลี่ยนสี/ใส่ `UICorner`/`UIStroke`/`UIGradient`/`CanvasGroup` ได้เต็มที่แบบในคลิป ตอน Play มันจะเด้งเข้า PlayerGui เอง แล้วโค้ดค่อยเติมตัวเลขลงไป

**ชื่อที่โค้ดอ้างถึง — ห้ามเปลี่ยน/ห้ามลบ** (ที่เหลือทำอะไรก็ได้):

| ชื่อ instance | โค้ดเขียนอะไรลงไป |
|---|---|
| `FollowerLabel` / `MoneyLabel` | ตัวเลข follower / เงิน |
| `StorageLabel` / `CameraLabel` | GB ที่อัดไว้ / ความชัดกล้อง |
| `ClockLabel` / `DayLabel` / `PhaseLabel` | เวลา / วันที่ / เฟส |
| `ProgressFill` | ความกว้างแถบ progress สู่ 1M |
| `MentalFill` | ความสูง + สีหลอดใจ |

- **ย้ายไปไว้ที่ไหนก็ได้** โค้ดหาแบบ recursive (ซ้อนกี่ชั้นก็เจอ)
- ลบชิ้นไหนทิ้ง = ช่องนั้นไม่อัปเดต **เกมไม่พัง** ขึ้น warn บอกชื่อใน Output
- ลบ `Gui_HUD` ทั้งอันทิ้ง = โค้ดสร้างเวอร์ชันเดิมจาก `HUD.build()` ให้อัตโนมัติ (กลับไปตั้งต้นได้)
- อยากรีเซ็ตกลับเป็นของ default: ลบ `StarterGui.Gui_HUD` แล้วรัน `require(StarterPlayerScripts.UI.HUD).build(game.StarterGui)` ใน command bar

⏳ **จอที่ยังสร้างจากโค้ดล้วน** (ยังแต่งใน Studio ไม่ได้): จอคอม + 7 แอป, กล่องบทสนทนา, จอ QTE, ร้านค้า, เมนูหลัก — แปลงแบบเดียวกับ HUD ได้ บอกได้ว่าจะเอาอันไหนก่อน

---

## 1. layout ที่ทำตามภาพร่างแล้ว 28 ก.ค. (เหลือแค่ "ใส่รูป")

โค้ดวาง**โครง + พื้นหลัง**ตาม `assets/reference/ui screenshot/*` ครบแล้ว ทุกกล่องที่ต้องมีรูปตั้งชื่อ `ArtSlot*`
เอารูปใส่ = แก้ `Shared.UIAssets` คีย์เดียว ไม่ต้องแตะโค้ด UI

| จอ | ไฟล์ | ภาพร่าง | ช่องรอรูป |
|---|---|---|---|
| HUD | `UI/HUD` | `All ui.png` | ไอคอน follower/money/storage/กล้อง/ปฏิทิน · ราง+fill mental · ราง progress · ช่อง hotbar · ปุ่มกลม ⚙️🔊 |
| Desktop PC | `UI/PCScreen` | `PC ui.png` | ไอคอนแอป 7 ตัว · wallpaper 3 เฟส · ปุ่ม Exit |
| Bank | `UI/Apps/Bank` | `PC-Bank-1 ui.png` | รูปกลางการ์ด 3 ใบ (จาน / คน / บ้าน) |
| Manage | `UI/Apps/Manage` | `PC-Bank-2 ui.png` | รูปหน้าพนักงานในการ์ด |
| Calendar | `UI/Apps/CalendarApp` | `PC-Calendar ui.png` | — (ตารางล้วน ไม่ต้องวาด) |
| Upload | `UI/Apps/Upload` | `PC-Upload ui.png` | ปกคลิป `clip_cover_1..6` (ใช้ทั้ง thumbnail และ preview) |
| Edit (QTE + สรุป) | `UI/Apps/EditQTE` | `PC-Edit-2/3 ui.png` | `edit_workspace_bg` · วง QTE `qte_ring_outer/target` |
| Message (DM) | `UI/Apps/Message` | `PC-DM ui.png` | รูปโปรไฟล์คนในลิสต์ (ยังไม่มีคีย์ใน UIAssets — ต้องเพิ่ม) |
| Shop | `UI/Apps/ShopKiosk` | `PC-Shop ui.png` | `shop_camera/storage/pc_1..6` (18 ใบ) |

> 🗑️ **ลบแล้ว: `UI/Apps/Shop.luau`** — ซ้ำกับ `ShopKiosk` ที่ทำตามภาพร่างแล้ว ไอคอน upgrade บนคอมเปิดตัวเดียวกัน
> ⚠️ **ใน Studio ยังมี ModuleScript ชื่อ `Shop` ค้างอยู่** (agent ห้ามลบเอง) — บอสลบเองใน `StarterPlayerScripts.UI.Apps.Shop`

---

## 2. decision ที่ค้าง — ยังตัดสินไม่ได้ = ทำ UI ต่อไม่ได้

| # | เรื่อง | ติดตรงไหน | ผลถ้าไม่ตัดสิน |
|---|---|---|---|
| 1 | **จอ Edit ที่ 1 "How much footage for this video?"** (สไลเดอร์เลือก GB ต่อคลิป — ภาพร่าง `PC-Edit-1 ui.png`) | ตอนนี้ 1 คลิป = กิน footage คงที่ `Config.Record.footagePerClipGB` ถ้าให้เลือกได้ ต้องมีสูตรว่า GB มากขึ้นแล้วได้อะไร (คุณภาพ? ความยาว? โบนัส?) → **แตะ balance ที่ล็อกไว้** | จอ 1 ไม่มีในเกม เข้า QTE ตรงๆ (ตอนนี้ทำแบบนี้อยู่) |
| 2 | **title / description ตอนอัปคลิป** — ช้อยละ 3 อัน | โครง UI มีแล้ว แต่ยังไม่มีไฟล์ `Content.ClipTitles` (สาย B) + ยังไม่ล็อกว่าเลือกแล้วมีผลอะไร | ช้อยโชว์ "1. / 2. / 3." เปล่าๆ กดได้แต่ไม่มีผล |
| 3 | **กราฟ Feedback 7 วันจริง** | `state` ยังไม่เก็บ history รายวัน (docs/10 สาย B: `state.history[day]`) | กราฟใช้ 7 คลิปล่าสุดแทนวัน — ไม่ตรง PDF |
| 4 | **สาย upgrade "คอมพิวเตอร์" ซื้อได้แต่ไม่มีผล** (unwired ตั้งใจ) | ยังไม่ล็อกว่าคอมให้อะไร | การ์ดโชว์ชื่อของอย่างเดียว ไม่มีบรรทัด spec |
| 5 | **ระดับ 7-15 ของทุกสาย ไม่มีรูป** | docs/13 §5 วาดแค่ 1-6 | ระดับ 7+ ใช้ emoji หมวดแทน (ตั้งใจ ไม่ต้องแก้ถ้าเวลาไม่พอ) |

---

## 3. UI ที่ผูกกับของในแมพ — ยังไม่มีของให้ผูก

| ของ | ใครใช้ | สถานะ |
|---|---|---|
| `Interact_pcMonitor` เฟส 2 / 3 (จอ 4×2.6 studs) | PCScreen (เครื่องเปลี่ยนหน้าตาตามเฟส) | 🔴 มีแค่เครื่องเฟส 1 |
| `Interact_Shop` | ShopKiosk | 🟡 เป็นกล่องส้ม placeholder ที่ (8,2,8) |
| `Interact_Bed` / `Kitchen` / `Exercise` | เมนูเตียง + Activity | 🟡 placeholder |
| `Interact_NPC_01..05` + โมเดล NPC | DialogueUI | 🔴 ยังไม่มีโมเดล |
| `CutsceneCams` (`Cam_*`) | CutscenePlayer | 🔴 ยังไม่วางสักตัว — ใช้ plugin `tools/CutsceneCamTool.plugin.luau` |
| `Zone_*` (โซนเพลง) | AudioService | 🔴 ยังไม่วาง |

---

## 4. UI ที่คุยกันแล้วแต่ยัง "ไม่มีในเกมเลย"

| อัน | คุยไว้ที่ | หมายเหตุ |
|---|---|---|
| **หน้า Setting จริง** (graphic / language / audio) | docs/10 §1.2 · PDF หน้า 1 | ตอนนี้มีแค่แผงเสียง ⊖⊕ ใน HUD + ปุ่มใน Main Menu |
| **จอโหลดเซฟแบบสมุด** (`book_page`) | docs/13 #62 | MenuUI ใช้กล่องธรรมดา |
| **cutscene โหมด 2 — ป้ายชื่อ + ปุ่มช้อยแบบมีรูป** | 28 ก.ค. (docs/engines/dialogue.md) | โค้ดใช้กล่องสีทึบ · คีย์ `dialogue_name` / `dialogue_choice` / `_hover` (docs/13 #63-65) |
| **trend tags "กระแสช่องนี้"** ในแอป Feedback | PDF หน้า 8 · docs/12 | mechanic ยังไม่ทำ (โบนัสอัด +20% ตาม tag) |
| **delta popup ใช้ลูกศร `hud_delta_up`** | docs/13 #15 | ตอนนี้เป็นตัวเลขเปล่า |
| **hotbar ช่องตามรูปที่วาด** (`hud_hotbar_slot`) | docs/13 #11 | ตอนนี้ใช้ backpack ของ Roblox (ล่างกลาง 3 ช่อง ตรงภาพร่างอยู่แล้ว) — จะใช้รูปเองต้องปิด CoreGui backpack แล้วเขียน hotbar เอง = งานแยก ~2 ชม. |

---

## 5. กติกาเวลาเอารูปใส่ (ย้ำจาก docs/13)

1. วาดใหญ่ตามคอลัมน์ "วาดที่" → ย่อเป็น "ส่งออก" → PNG พื้นหลังใส
2. Studio → Asset Manager → Import → Copy Asset ID → วางใน `Shared.UIAssets` คีย์เดิม **ห้ามเปลี่ยนชื่อคีย์**
3. คีย์ที่ยังว่าง `""` = โค้ดใช้ emoji/กล่องสีแทน **เกมไม่พัง** → วาดทีละใบได้ ไม่ต้องรอครบ
4. ตัวเลข/ตัวหนังสือ **ห้ามวาดลงในรูป** โค้ดพิมพ์ทับเอง
