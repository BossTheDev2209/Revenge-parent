# Footsteps — manifest ของ Sound + Value (ลูกของ `ServerScriptService.Footsteps`)

ไม่ใช่โค้ด — ตารางนี้ไว้สร้างใหม่ถ้า instance หาย (Volume 0.35 ทุกตัวถ้าไม่ระบุ)

| ชื่อ instance | ClassName | SoundId | PlaybackSpeed |
|---|---|---|---|
| `Brick` | Sound | `http://www.roblox.com/asset/?id=168786259` | 1.00 |
| `Cobblestone` | Sound | `http://www.roblox.com/asset/?id=142548009` | 1.00 |
| `Concrete` | Sound | `rbxassetid://481215525` | 1.00 |
| `Corroded Metal` | Sound | `rbxassetid://379482691` | 1.00 |
| `Diamond` | Sound | `rbxassetid://481216891` | 1.00 |
| `Fabric` | Sound | `http://www.roblox.com/asset/?id=151760062` | 1.00 |
| `Foil` | Sound | `http://www.roblox.com/asset/?id=184795891` | 1.00 |
| `Foil` (ซ้ำชื่อ) | Sound | `rbxassetid://142431247` | 1.00 |
| `Granite` | Sound | `http://www.roblox.com/asset/?id=134464013` | 1.00 |
| `Grass` | Sound | `rbxassetid://379482039` | 1.00 |
| `Ice` | Sound | `http://www.roblox.com/asset/?id=19326880` | 0.70 |
| `Marble` | Sound | `http://www.roblox.com/asset/?id=134464111` | 1.00 |
| `Metal` | Sound | `rbxassetid://379482691` | 1.00 |
| `Pebble` | Sound | `http://www.roblox.com/asset/?id=180239547` | 1.00 |
| `Plastic` | Sound | `rbxassetid://267454199` | 1.00 |
| `Sand` | Sound | `rbxassetid://265653329` | 1.00 |
| `Splash` | Sound | `http://www.roblox.com/asset/?id=28604165` | 3.20 |
| `Tile` | Sound | `rbxassetid://481217914` | 1.00 |
| `Wood` | Sound | `rbxassetid://481218268` | 1.00 |
| `WoodPlanks` | Sound | `rbxassetid://481218268` | 1.00 |
| `Materials` | StringValue | — (Running อ่านค่านี้) | — |
| `Colors` | BrickColorValue | — (MaterialDetect เขียน ยังไม่มีใครใช้) | — |

## จุดที่ไม่ตรงกัน (ยังไม่แก้ — ของเดิมจาก Toolbox)

- **`Foil` ซ้ำ 2 ตัว** คนละ asset — `Running` เรียก `script.Parent.Foil` จะได้ตัวแรกที่เจอ
- **`Corroded Metal`** มีเว้นวรรค แต่ `Running` เช็ค `Materials.Value == "CMetal"` แล้วเล่น `Diamond` แทน → Sound นี้ไม่เคยถูกใช้
- **`Slate`** ไม่มี Sound ของตัวเอง — `Running` เล่น `Concrete` แทน (จงใจ)
- **`Tile`** มี Sound แต่ `MaterialDetect` ไม่เคย set `Materials.Value = "Tile"` → ไม่เคยดัง
