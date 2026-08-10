# 17 — Animation Export Gotcha: เคสฟ้าใส `KnockTalkWalkSit` (11 ส.ค. 2569)

**สรุปสั้น: ไม่เกี่ยวกับ ownership/permission/transfer group เลยสักนิด — สาเหตุจริงคือกด export ผิดปุ่มใน Moon Animator ตอนฉากมีหลาย rig**
เสียเวลาไปทั้งวันโทษผิดที่ (group transfer, asset permission, Experience grant) ก่อนจะเจอของจริง บันทึกไว้กันเหยียบซ้ำ

## อาการ

```
Failed to load animation with sanitized ID rbxassetid://76365653201923: AnimationClip loaded is not valid.
```

ขึ้นซ้ำๆ ตอนเล่น cutscene `FaasaiJoin` (`src/shared/Content/Cutscenes/FaasaiJoin.luau`) — animation โหลดไม่ผ่าน ไม่มี error ตอน `pcall(LoadAnimation)` (ฟังก์ชันคืนค่า ok=true) แต่ `AnimationTrack.Length` ออกมา **0** เสมอ และ log โผล่ error async แยกต่างหาก (จับได้ผ่าน `LogService.MessageOut` เท่านั้น ไม่ใช่ pcall ตรงๆ)

## เส้นทางที่เดาผิด (เรียงตามลำดับที่ลองจริง)

| ลำดับ | ทฤษฎี | ทำอะไรไป | ผล |
|---|---|---|---|
| 1 | asset เป็นของ personal account แต่ game เป็นของ group → permission ไม่ตรง | โอนเจ้าของ experience จาก personal ไป **group** (Transfer ownership เต็มรูปแบบ ผ่านหน้า Creator Dashboard) | animation ยัง error เหมือนเดิมเป๊ะ — แต่พิสูจน์ได้ว่า transfer สำเร็จจริง (PlaceId เดิม, CreatorType เปลี่ยนเป็น Group, thumbnail/save ไม่หาย เพราะเป็น**เจ้าของเปลี่ยน**ไม่ใช่ copy) |
| 2 | asset ยังไม่ได้ grant ให้ group ใช้ | เข้า Creator Dashboard → asset → Permissions → **Collaborators** → เพิ่ม group | ผิด tab! Collaborators = สิทธิ์แก้ asset ผ่าน Studio ไม่ใช่สิทธิ์ให้ experience โหลดใช้ตอนรัน — ต้องเป็น tab **Experiences** ต่างหาก |
| 3 | re-export คลิปใหม่ (id `131462395059984`) เผื่อไฟล์เก่าเสีย | export จาก Moon Animator ใหม่ แต่ยังกดปุ่ม export แบบเดิม | error เหมือนเดิมเป๊ะ — พิสูจน์ว่าไม่ใช่ไฟล์เก่าเสีย |
| 4 | export ใหม่ล่าสุดเข้า **group โดยตรง** (ตัด permission ทิ้งไปเลย เจ้าของ asset = เจ้าของ game) | Moon Animator → Creator เลือก group (id `126583242885219`) | **error เหมือนเดิมเป๊ะอีก** — ตอนนี้ตัดทฤษฎี ownership/permission ทิ้งได้ 100% เพราะ asset กับ game เป็นเจ้าของเดียวกันแท้ๆ แล้วยังพัง |

**บทเรียน:** error message `"AnimationClip loaded is not valid"` **คนละแบบ**กับ permission ปฏิเสธจริง (ที่เห็นในเกมเดียวกัน: `"Asset is not approved for the requester"` กับ `"not authorized to grant asset permissions"`) — ถ้าเจอข้อความ "not valid" ให้สงสัยตัว**เนื้อไฟล์**ก่อน ไม่ใช่สิทธิ์

## ต้นตอจริง

ฉากนี้ใน Moon Animator มี **rig มากกว่า 1 ตัว** อยู่ในโปรเจกต์เดียวกัน (`Faasai_door_anim` ตัว NPC + `Player_door_anim` ตัวผู้เล่น อยู่ใต้กลุ่ม `DoorCutscene`)

กด **ปุ่ม "Export" ทั่วไป** (คีย์ลัด `5`) ตอนฉากมีหลาย rig → export ออกมาเป็น**อะไรบางอย่างที่ไม่ใช่ KeyframeSequence ล้วน** (คาดว่าเป็น bundle/Model ผสมข้อมูลหลาย rig) → Roblox validator ปัดตกตอน sanitize เพราะโครงสร้างไม่ตรงกับที่ animation format คาดหวัง

ตรงกับที่เจอใน Roblox DevForum (thread ที่มีคนแก้ได้จริง): คนอื่นเจอ error เดียวกันเพราะ "ไม่ได้ upload keyframe sequence จริงๆ" — อัป bundle/Model แทน

## วิธีที่ถูกต้อง (ใช้แล้วผ่านจริง)

1. **`File > Export Rig`** ใน Moon Animator (ไม่ใช่ปุ่ม Export ทั่วไป/คีย์ 5)
2. จะได้ folder ชื่อ **`AnimSaves`** โผล่ในตัว rig ที่เลือก
3. **right-click ที่คลิปเฉพาะตัวข้างใน `AnimSaves`** (ต้องเป็น rig เดียวที่ต้องการจริงๆ เช่น `Faasai_door_anim` — ไม่ใช่ทั้งฉาก) → **"Save to Roblox"**
4. Creator เลือกเป็น **group** ที่เป็นเจ้าของ game (ตัด permission step ทิ้งได้เลย ไม่ต้องไปยุ่ง Experiences tab)
5. เทสจริง: id ใหม่บางทีต้อง**รอ 30-60 วิ** ให้ Roblox process เนื้อไฟล์ก่อน — เทสครั้งแรกหลัง export อาจเจอ `Length = 0` ทั้งที่ไม่ error เลย (ไม่ใช่พัง แค่ยังไม่มา) รอแล้วเทสซ้ำก่อนตัดสินว่าพัง

id สุดท้ายที่ผ่าน: `rbxassetid://81531260316285` (`ReplicatedStorage.Animations.ฟ้าใส.KnockTalkWalkSit`)

## วิธีเทสแบบไม่ต้องรอ playtest มือ (ใช้ผ่าน Studio MCP)

`pcall(Animator:LoadAnimation(anim))` **คืนค่า ok=true เสมอแม้ clip พัง** — เช็คแค่ pcall ไม่พอ ต้องดู `Length` (0 = สงสัย) และดักด้วย `LogService.MessageOut` เพราะ error จริงมาแบบ async ไม่ผ่าน pcall:

```lua
local LogService = game:GetService("LogService")
local captured = {}
local conn = LogService.MessageOut:Connect(function(msg, msgType)
    if msg:find("nimat", 1, true) then table.insert(captured, msg) end
end)

local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://<id>"
local track = Animator:LoadAnimation(anim)
task.wait(2)
print(track.Length, captured) -- Length > 0 และ captured ว่าง = ผ่านจริง
conn:Disconnect()
```

**ต้องเทสใน Play mode จริง (`start_stop_play`) ไม่ใช่ Edit mode เฉยๆ** — Edit mode บางทีให้ผลไม่ตรงกับตอนรันจริงในเกม (client datamodel ต้องมี character จริง)

## เช็คลิสต์ก่อนเชื่อว่า animation พัง (เรียงตามที่ควรเช็คจริง ไม่ใช่ตามที่เราทำจริง)

1. เทียบ error message กับ pattern permission จริงก่อน (ดูตารางด้านบน) — "not valid" ≠ permission
2. เช็คว่า Moon Animator export ผ่าน `File > Export Rig` → `AnimSaves` → `Save to Roblox` **ต่อ rig เดียว** ไม่ใช่ปุ่ม Export รวมทั้งฉาก
3. รอ 30-60 วิหลัง export ใหม่ก่อนเทส (asset ใหม่ยังไม่ propagate)
4. เทสด้วย `LogService` capture ใน Play mode จริง ไม่เชื่อแค่ `pcall` ที่ `ok=true`
5. ค่อยสงสัยเรื่อง ownership/permission เป็นลำดับท้ายสุด

## อ้างอิง

- [Failed to load animation with sanitized ID... AnimationClip loaded is not valid — DevForum](https://devforum.roblox.com/t/failed-to-load-animation-with-sanitized-id-rbxassetid000000000-animationclip-loaded-is-not-valid/3100099)
- [How to export moon animator animation to roblox animation? — DevForum](https://devforum.roblox.com/t/how-to-export-moon-animator-animation-to-roblox-animation/1996677)
- `docs/08-studio-sync-handoff.md` — pattern Rojo sync แยกเรื่องกัน (อย่าสับสนกับ gotcha นี้ คนละสาเหตุ)
