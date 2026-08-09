# Engine: Audio — เสียงทั้งเกม

**ไฟล์โค้ด:** `StarterPlayerScripts.AudioService`
**ที่วางเสียง:** `SoundService` (4 โฟลเดอร์) ← **ทีมทำแค่ตรงนี้**
**โซนเพลง:** Part ชื่อ `Zone_*` ในแมพ ← **ทีมวาง**
**อ้างอิง:** docs/02 §9.9 · แนวคิดแบบ Undertale (เพลงตามโซน + blip ตอนพิมพ์บท)

---

## 1. วางโครงครั้งเดียว

สร้าง **Folder 4 อันใน SoundService** แล้วเอา Sound object ใส่:

```
SoundService/
  BGM/       เพลงพื้นหลัง        ← ตั้ง Looped = true
  Ambient/   บรรยากาศซ้อนเพลง    ← Looped = true (ฝน/เสียงรถ/room tone)
  Voice/     blip ตอนพิมพ์บท     ← คลิปสั้นมาก ~0.05–0.15 วิ
  SFX/       เสียงสั้นครั้งเดียว
```

**Toast แจ้งเตือน (มุมขวาล่าง สไตล์ Win11 — `StarterPlayerScripts.Notify`):** เด้งตอนทีม/เพื่อนร่วมทาง auto ลงคลิป (follower ขึ้นเอง) + ตอน DM ใหม่เข้า · เล่นเสียงเบาๆ เอง (`Audio.sfx(name, nil, volumeScale)` — param 3 คูณ Volume) reuse `upload_done`/`ui_click` · วาง Sound `notify`/`dm` ทับได้ถ้าอยากได้เสียงเฉพาะ

**ชื่อ Sound = ชื่อที่โค้ดเรียก** — ไม่มีไฟล์ชื่อนั้น = warn ครั้งเดียวแล้วเงียบ **เกมไม่พัง** ใส่ทีละอันได้ ไม่ต้องรอครบ

---

## 2. SFX ที่โค้ดเรียกอยู่แล้ว — วางปุ๊บดังทันที

| ชื่อ | ดังตอน |
|---|---|
| `ui_click` | ปุ่มทั่วไป (ค่าเริ่มต้นของทุกปุ่มที่ไม่ได้ตั้งเสียงเฉพาะ) |
| `ui_back` | ปุ่มย้อนกลับ / ปิดหน้าต่าง / ยกเลิก / ข้าม cutscene |
| `dialogue_advance` | คลิกกล่องข้อความไปบรรทัดถัดไป |
| `dialogue_choice` | เลือกช้อยในบทสนทนา |
| `buy` | ซื้อของในร้านสำเร็จ |
| `equip` | ย้อนกลับไปใช้อุปกรณ์ระดับเก่า |
| `denied` | กดของที่ยังซื้อไม่ได้ / เงินไม่พอ |
| `save` | ปุ่มเซฟ |
| `upload_done` | อัปคลิปสำเร็จ |
| `viral` | คลิปนั้นไวรัล |
| `rent_missed` | จ่ายค่าเช่าไม่ทัน/เงินหมดตอนตัดรอบ 7 วัน (ครบ 2 ครั้ง = Bad End 1) |

**ไม่มีไฟล์ชื่อไหน = เงียบเฉพาะอันนั้น** + warn ครั้งเดียวใน Output (ไม่พัง วางเพิ่มทีหลังได้)
เสียงเดินไม่อยู่ตารางนี้แล้ว — ใช้ระบบ material-based ที่ `ServerScriptService.Footsteps` แทน ([src/studio-only](../../src/studio-only/README.md))

### เสียงกดปุ่มทำงานยังไง (ไม่ต้องแตะโค้ดถ้าแค่จะเพิ่มเสียง)

**ผูกที่เดียวใน `Main.client`** — ทุก `GuiButton` ใต้ PlayerGui ได้เสียงคลิกอัตโนมัติ **1 คลิกจริง = 1 เสียง**

อยากให้ปุ่มไหนเสียงต่างจาก `ui_click` → ตั้ง attribute **`Sfx`** บนปุ่มนั้น:

```lua
btn:SetAttribute("Sfx", "buy")    -- ใช้เสียงชื่อ buy ใน SoundService.SFX
btn:SetAttribute("Sfx", "none")   -- ปุ่มนี้ไม่ต้องมีเสียง
```

⚠️ **ห้ามเรียก `Audio.sfx("ui_click")` เองในปุ่ม** — ตัวผูกกลางเล่นให้แล้ว เรียกเองจะดัง 2 ที
(เดิมเล่นเสียงใน `fireAction` = ดังต่อ *action ที่ยิง server* ปุ่มเดียวยิง 2 action ก็ดัง 2 ที — แก้แล้ว 5 ส.ค.)

---

## 3. เสียงพูด NPC (Voice) — แบบ Undertale

- ดังทีละตัวอักษรตอนพิมพ์บท **เว้นวรรคไม่ดัง**
- **ชื่อ Sound = ชื่อไฟล์บท** → `Voice.Friend1`, `Voice.CC1`, `Voice.Hater`, `Voice.Landlord`
- ไม่มีของตัวนั้น → ใช้ `Voice.Default` → ไม่มีทั้งคู่ = เงียบ
- ระบบใส่ให้: สุ่ม pitch ±12% (ไม่ซ้ำเป๊ะ) + เว้นอย่างน้อย 0.045 วิ (กันถี่จนหูแตก)

**เลือกเสียงยังไงให้ตัวละครมีคาแรกเตอร์:** เสียงต่ำ+ช้า = ผู้ใหญ่/จริงจัง · เสียงสูง+สั้น = เด็ก/สดใส · เสียงแตก = เกรียน

---

## 4. เพลงตามโซน

**สร้าง Part ครอบพื้นที่:**

- ชื่อขึ้นต้น **`Zone_`** เช่น `Zone_Street`, `Zone_Apartment`, `Zone_House`
- Transparency 1 · CanCollide ✗ · Anchored ✓ · ครอบพื้นที่ที่อยากให้เพลงนี้ดัง

**ใส่ Attribute** (คลิก Part → Properties → Attributes → +):

| Attribute  | ชนิด   | ความหมาย                                         |
| ---------- | ------ | ------------------------------------------------ |
| `Music`    | string | ชื่อ Sound ใน `BGM` (ไม่ใส่ = เงียบในโซนนี้)     |
| `Ambient`  | string | ชื่อ Sound ใน `Ambient` (ไม่บังคับ — ซ้อนบนเพลง) |
| `Priority` | number | โซนซ้อนกัน **เลขมากกว่าชนะ** (ไม่ใส่ = 0)        |

**ระบบทำให้เอง:** เช็คทุก 0.35 วิ · crossfade 1.2 วิ · เดินออกทุกโซน = กลับเป็น `Config.Audio.defaultBGM`

> **ตัวอย่างใช้ Priority:** `Zone_Apartment` (Priority 0) ครอบทั้งตึก, `Zone_MyRoom` (Priority 5) ครอบเฉพาะห้องเรา → เข้าห้องได้เพลงห้อง ออกมาได้เพลงตึก

**เพลงเมนูหลัก (เปลี่ยนตามความคืบหน้า — Undertale ref):** วาง Sound ชื่อ **`Menu`** ใน `SoundService.BGM` (Looped) เป็นค่าเริ่มต้น · อยากให้เพลงเมนูเปลี่ยนตามเฟสของเซฟล่าสุด → วางเพิ่ม **`Menu2` / `Menu3`** (เฟสไหนไม่มี track เฉพาะ = ตกมาใช้ `Menu`)
`MenuUI` `lockBGM(true)` + `bgm("Menu<เฟส>")` ตอนเปิดเมนู กันโซนในแมพแย่งสั่งเพลง (ตัวละคร spawn ในแมพจริง) · กดเข้าเกม (`launch`) `bgm(nil)` ดับ + continue `lockBGM(false)` คืนสิทธิ์โซน · new game ให้ cutscene จัดการ · **ยังไม่วาง Sound = เมนูเงียบ (ไม่ leak เพลง gameplay)**

**รายละเอียดห้องเมนูเปลี่ยนตามเฟส:** ตั้ง attribute **`ShowPhase = n`** (number) บน instance ไหนก็ได้ใน `Workspace.MenuScreen` → โผล่เฉพาะเมื่อเซฟล่าสุดถึงเฟส `n` ขึ้นไป (ยังไม่ถึง = ซ่อนด้วย `LocalTransparencyModifier`/`Light.Enabled` ไม่แตะค่าจริง) เช่นถ้วยรางวัลโผล่ตอนเฟส 3, โปสเตอร์เปลี่ยนตอนเฟส 2

---

## 5. เสียงใน Cutscene

cutscene สั่งเสียงได้ 2 step (ดู [cutscene.md](cutscene.md)):

```lua
{ type = "bgm",   name = "Ending_Sad" },  -- ไม่ใส่ name = เงียบสนิท (ทรงพลังตอน Bad End)
{ type = "sound", name = "door_slam" },
```

ระหว่าง cutscene **โซนถูกล็อก ไม่แย่งเพลง** จบแล้วคืนสิทธิ์อัตโนมัติ

---

## 6. ปรับความรู้สึก

**ความดัง** — ปรับที่ Sound object ตรงๆ ใน Studio (Volume) ไม่ต้องแตะโค้ด

**จังหวะ** — `ReplicatedStorage.Shared.Config` → `Config.Audio`:

| ค่า                 | ตอนนี้ | คุมอะไร                             |
| ------------------- | ------ | ----------------------------------- |
| `bgmFade`           | 1.2    | วินาที crossfade เปลี่ยนเพลง        |
| `defaultBGM`        | `""`   | เพลงตอนไม่อยู่โซนไหน (ว่าง = เงียบ) |
| `zoneCheckInterval` | 0.35   | เช็คโซนถี่แค่ไหน                    |
| `voiceMinGap`       | 0.045  | blip ห่างกันอย่างน้อยกี่วิ          |
| `voicePitchVary`    | 0.12   | สุ่ม pitch เสียงพูด ±เท่าไหร่       |
| `footstepInterval`  | 0.42   | ระยะห่างก้าวเดิน                    |
| `footstepPitchVary` | 0.08   | สุ่ม pitch ก้าวเดิน                 |

---

## 7. ลิขสิทธิ์ — สำคัญมาก

**ห้ามใช้เพลง/เสียงมีลิขสิทธิ์เด็ดขาด = ผิดกติกาแข่ง ตกรอบ** (ไม่ใช่แค่เสียคะแนน)

ที่ใช้ได้: Roblox Audio Library (ฟรี ในตัว Studio) · เสียงที่ทำเอง · CC0/Public Domain (freesound.org กรองเป็น CC0)

⚠️ เสียงที่อัปโหลดเองต้องรอ Roblox moderate ~นาที–ชั่วโมง เผื่อเวลาก่อนส่ง
