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

## สคริปต์เฉพาะงาน (รันครั้งเดียว/เมื่อจำเป็น)

| ไฟล์ | ทำอะไร | สถานะ |
|---|---|---|
| **`CutsceneCamTool.plugin.luau`** | **Studio plugin** วาง/ส่อง/พรีวิวมุมกล้อง cutscene (Place/Aim/Look Thru/Tour) · ติดตั้ง: copy ไป `%LOCALAPPDATA%\Roblox\Plugins\` (docs/engines/cutscene.md §3) | ✅ ใช้อยู่ |
| **`build_npc_template.luau`** | ก๊อป `Workspace.NPC.R6` เป็น NPC_Template + ตัวจริง — ใส่ Animator/Shirt/Pants/attachment/face/Interact/ป้ายชื่อ ครบ (docs/05 §4) | ✅ ใช้อยู่ |
| **`rename_npc_interacts.luau`** | เปลี่ยนชื่อ Part `Interact_NPC_01` ในโมเดล NPC → `Interact_NPC_<ชื่อ>` unique (ผูกบทได้) · รันหลังเพิ่ม NPC ใหม่ | ✅ ใช้อยู่ |

## สคริปต์ที่เลิกใช้แล้ว (accessory — user จัดการหน้าตา NPC เอง 29 ก.ค.)

`attach_accessory.luau` · `clean_accessories.luau` · `normalize_accessories.luau`
→ ระบบ accessory ถูกถอดออกหมดแล้ว (ทั้งคลัง `ReplicatedStorage.Accessories` และของบน NPC)
→ เก็บไฟล์ไว้เผื่อกลับมาใช้ · **ถ้าไม่คิดจะแต่งตัว NPC ด้วยสคริปต์อีก ลบทิ้งได้**

---

## เพิ่ม NPC ใหม่ (ลำดับที่ใช้จริง)

1. ก๊อป `NPC_Template` ใน `Workspace.NPC.WorldNPC` (หรือ StoryNPC) → ตั้งชื่อ `NPC_<NN>_<ชื่อ>`
2. แต่งหน้าตา (เสื้อ/ผม/หน้า) — งาน user
3. รัน `rename_npc_interacts.luau` → Part interact ได้ชื่อ unique
4. เพิ่ม 1 บรรทัดใน `NPC_DIALOGUE` (`src/client/InteractBinder.luau`) : `Interact_NPC_<ชื่อ> = "<ไฟล์บท>"`
5. สร้างไฟล์บท `src/shared/Content/Dialogue/<ไฟล์บท>.luau` (format → docs/engines/dialogue.md)
6. `gen_sync.py` + `mcp_driver.py` → เข้า Studio
