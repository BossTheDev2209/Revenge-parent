# studio-only — สำเนาสคริปต์ที่อยู่ใน Studio เท่านั้น (Rojo ไม่ sync)

โฟลเดอร์นี้ **ไม่ได้ map ใน `default.project.json`** → Rojo ไม่แตะ ไม่ push เข้า Studio

**มีไว้ทำไม:** ของพวกนี้อยู่ใน `.rbxl` อย่างเดียว ถ้าไฟล์เสีย/หาย = หายถาวร
เก็บสำเนาไว้ที่นี่เพื่อให้ git มีประวัติ + กู้คืนได้ (CLAUDE.md ข้อ 7)

**ทำไมไม่ให้ Rojo คุม:** สคริปต์พวกนี้มีลูกเป็น instance ที่ไม่ใช่ไฟล์โค้ด (Sound 20 ตัว, StringValue,
BrickColorValue) — map เป็น `.luau` ไฟล์เดียวไม่ได้ เสี่ยง Rojo ลบลูกทิ้ง

## แก้ยังไง

แก้ **ใน Studio** แล้ว **copy กลับมาที่นี่** ทุกครั้ง (ไม่ใช่แก้ที่นี่แล้วหวังว่าจะ sync — มันไม่ sync)

## รายการ

| ที่อยู่ใน Studio | สำเนาที่นี่ | ทำอะไร |
|---|---|---|
| `ServerScriptService.Footsteps` | `Footsteps/init.server.luau` | โคลนตัวเอง+ลูกเข้า HumanoidRootPart ตอนเกิดตัวละคร |
| `└ MaterialDetect` (Script) | `Footsteps/MaterialDetect.server.luau` | ยิง ray ลงล่าง อ่าน Material พื้น เขียนลง `Materials` (StringValue) |
| `└ Running` (Script) | `Footsteps/Running.server.luau` | เล่นเสียงตาม `Materials.Value` · **จังหวะก้าวแปรตามความเร็ว** (แก้ 5 ส.ค.) |
| `└ Pitch` (Script) | `Footsteps/Pitch.server.luau` | ขยับ pitch ขึ้นลงเล็กน้อย ให้เสียงไม่ซ้ำเป๊ะ |
| `└ Sound ×20 + Materials + Colors` | `Footsteps/sounds.md` | manifest asset id (ไม่ใช่โค้ด สร้างใหม่จากตารางได้) |
| `StarterCharacterScripts.SprintHandler` | `SprintHandler.client.luau` | กด Shift = WalkSpeed 50, ปล่อย = 16 · เคารพ `MoveLocked` |

ที่มา: Footsteps = Toolbox (เครดิตในหัวไฟล์ iiMAYK / Xx_andresXx) · สแกนแล้วไม่มี backdoor
(ไม่มี `require(assetId)`, HttpService, loadstring, getfenv)

## `MoveLocked` — กติกาการล็อกการเดิน

ใครจะล็อกไม่ให้ player เดิน **ต้องตั้ง `Humanoid:SetAttribute("MoveLocked", true)`** ด้วย ไม่ใช่แค่ set
`WalkSpeed = 0` เฉยๆ — ไม่งั้น script ที่คุมความเร็ว (SprintHandler) จะ set ทับกลับ

- ตั้ง: `CutscenePlayer` (ตอนเล่นฉาก) · `MenuUI.freezeCharacter` (ตอนอยู่เมนู)
- อ่าน: `SprintHandler` — ล็อกอยู่ = ไม่แตะ WalkSpeed · ปลดล็อกเมื่อไหร่คืนความเร็วให้เองผ่าน
  `GetAttributeChangedSignal`
