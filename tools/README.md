# tools/ — สคริปต์ช่วยงาน (รันผ่าน Studio MCP หรือ command bar)

**วิธีรันไฟล์ `.luau` ส่วนใหญ่:** ผ่าน `mcp_driver.py` (steps.json ชี้ `luau_file` + `datamodel_type: "Edit"`)
หรือก๊อปโค้ดวางใน Studio command bar ตรงๆ ก็ได้ · **ต้องอยู่ Edit mode** (ไม่ใช่ Play)

```bash
# ท่ามาตรฐาน (ดู docs/08 §0)
python tools/gen_sync.py <scratchpad>/sync_all.luau
python tools/mcp_driver.py <steps.json>
```

---

## สคริปต์หลัก (ใช้ประจำ)

| ไฟล์ | ทำอะไร |
|---|---|
| **`gen_sync.py`** | สแกน `src/` + `tests/` จากดิสก์ → gen luau ก้อนเดียวยัดเข้า Studio · **รันทุกครั้งหลังแก้โค้ด** (docs/08 §0) |
| **`mcp_driver.py`** | ยิง step ไป Studio MCP (execute_luau / start_stop_play) · หา path Studio อัตโนมัติ |
| **`rojo.ps1`** | คุม `rojo serve` ระดับ process — `status` (จับ pattern ⑦ server ถือ project เก่า) / `restart` (kill+start ใหม่ทีเดียว) / `kill-all` / `instances` (จับ pattern ⑧ เปิด Studio หลายหน้าต่าง) · รายละเอียด pattern → `docs/08-studio-sync-handoff.md` |

## สคริปต์เฉพาะงาน (รันครั้งเดียว/เมื่อจำเป็น)

| ไฟล์ | ทำอะไร | สถานะ |
|---|---|---|
| **`CutsceneCamTool.plugin.luau`** | **Studio plugin** วาง/ส่อง/พรีวิวมุมกล้อง cutscene (Place/Aim/Look Thru/Tour) · ติดตั้ง: copy ไป `%LOCALAPPDATA%\Roblox\Plugins\` (docs/engines/cutscene.md §3) | ✅ ใช้อยู่ |
| **`build_npc_template.luau`** | ก๊อป `Workspace.NPC.R6` เป็น NPC_Template + ตัวจริง — ใส่ Animator/Shirt/Pants/attachment/face/Interact/ป้ายชื่อ ครบ (docs/05 §4) | ✅ ใช้อยู่ |
| **`rename_npc_interacts.luau`** | เปลี่ยนชื่อ Part `Interact_NPC_01` ในโมเดล NPC → `Interact_NPC_<ชื่อ>` unique (ผูกบทได้) · รันหลังเพิ่ม NPC ใหม่ | ✅ ใช้อยู่ |

## เพิ่ม NPC ใหม่ (ลำดับที่ใช้จริง)

1. ก๊อป `NPC_Template` ใน `Workspace.NPC.WorldNPC` (หรือ StoryNPC) → ตั้งชื่อ `NPC_<NN>_<ชื่อ>`
2. แต่งหน้าตา (เสื้อ/ผม/หน้า) — งาน user
3. รัน `rename_npc_interacts.luau` → Part interact ได้ชื่อ unique
4. เพิ่ม 1 บรรทัดใน `NPC_DIALOGUE` (`src/client/InteractBinder.luau`) : `Interact_NPC_<ชื่อ> = "<ไฟล์บท>"`
5. สร้างไฟล์บท `src/shared/Content/Dialogue/<ไฟล์บท>.luau` (format → docs/engines/dialogue.md)
6. `gen_sync.py` + `mcp_driver.py` → เข้า Studio

## เจอ Rojo พัง (แก้แล้วไม่เข้า Studio)

```bash
pwsh tools/rojo.ps1 status      # เช็คว่า server ถือ project เก่าไหม (pattern ⑦) + กี่ session
pwsh tools/rojo.ps1 restart     # kill ทุกตัว + start ใหม่ทีเดียว — แล้วกด Disconnect/Connect ใน Studio
pwsh tools/rojo.ps1 instances   # เช็คว่าเปิด Studio ค้างหลายหน้าต่างไหม (pattern ⑧)
```

ปุ่ม `Rojo Status` / `Find Leftovers` ใน Studio toolbar `Streaming Fix` เสริมฝั่ง Studio (`tools/RojoControl.plugin.luau`) — ใช้คู่กัน: `rojo.ps1 status` บอกว่า process/port โอเคไหม, ปุ่มใน Studio บอกว่า Studio เห็นอะไรอยู่
