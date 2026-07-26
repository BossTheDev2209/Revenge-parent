"""gen_sync.py — สร้างไฟล์ .luau ก้อนเดียวที่ยัด src/ ทั้งโปรเจกต์เข้า Studio

    python tools/gen_sync.py <scratchpad>/sync_all.luau
    python tools/mcp_driver.py <steps.json ที่มี step luau_file ชี้ไฟล์นั้น>

ไม่ต้อง inline โค้ดในแชท และไม่ต้องยิงทีละไฟล์
ไฟล์ถูก **สแกนจากดิสก์อัตโนมัติ** — เพิ่มไฟล์ใหม่ใน src/ แล้วรันซ้ำได้เลย ไม่ต้องแก้ list
"""
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "sync_all.luau")

# แผนที่ src/ -> ที่อยู่ใน Studio (ตาม docs/06-architecture.md)
#   ("prefix ใน repo", "root ใน Studio", class ปกติของไฟล์ในนั้น)
ROOTS = [
    ("src/shared", "RS.Shared", "ModuleScript"),
    ("src/server/Services", "SSS.Services", "ModuleScript"),
    ("src/client", "SPS", "ModuleScript"),
]
# ไฟล์พิเศษที่ไม่ใช่ ModuleScript / ไม่อยู่ใต้ root ข้างบน
SPECIAL = {
    "src/server/Main.server.luau": ("SSS", "Main", "Script"),
    "src/client/Main.client.luau": ("SPS", "Main", "LocalScript"),
    "tests/RunTests.luau": ("SSS.Tests", "RunTests", "Script"),
}


def discover():
    """คืน list ของ (repo path, studio parent, ชื่อ instance, class)"""
    out = []
    for rel, (parent, name, cls) in SPECIAL.items():
        if os.path.exists(os.path.join(REPO, rel.replace("/", os.sep))):
            out.append((rel, parent, name, cls))

    for prefix, studio_root, cls in ROOTS:
        base = os.path.join(REPO, prefix.replace("/", os.sep))
        if not os.path.isdir(base):
            continue
        for dirpath, _, filenames in os.walk(base):
            for fn in sorted(filenames):
                if not fn.endswith(".luau"):
                    continue
                rel = os.path.relpath(os.path.join(dirpath, fn), REPO).replace(os.sep, "/")
                if rel in SPECIAL:
                    continue
                sub = os.path.relpath(dirpath, base).replace(os.sep, ".")
                parent = studio_root if sub == "." else f"{studio_root}.{sub}"
                out.append((rel, parent, fn[: -len(".luau")], cls))
    return out


def bracket(src):
    """เลือกระดับ long bracket ที่ไม่ชนกับเนื้อไฟล์"""
    for n in range(5, 12):
        eq = "=" * n
        if f"]{eq}]" not in src and f"[{eq}[" not in src:
            return f"[{eq}[", f"]{eq}]"
    raise RuntimeError("no safe bracket level")


FILES = discover()

parts = [
    "local RS = game:GetService('ReplicatedStorage')",
    "local SSS = game:GetService('ServerScriptService')",
    "local SPS = game:GetService('StarterPlayer').StarterPlayerScripts",
    "local done, made = {}, {}",
    """local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new('Folder')
		f.Name = name
		f.Parent = parent
		table.insert(made, f:GetFullName())
	end
	return f
end""",
    """local function put(parent, name, class, src)
	local m = parent:FindFirstChild(name)
	if m and not m:IsA('LuaSourceContainer') then m:Destroy(); m = nil end
	if not m then
		m = Instance.new(class)
		m.Name = name
		m.Parent = parent
		table.insert(made, parent:GetFullName() .. '.' .. name)
	end
	m.Source = src
	table.insert(done, name)
end""",
]

# สร้าง Folder กลางที่อาจยังไม่มี (RS.Shared.Content.Dialogue ฯลฯ) ก่อน put
seen = set()
for _, parent, _, _ in FILES:
    root, *subs = parent.split(".")
    chain = root
    for s in subs:
        expr = f"folder({chain}, '{s}')"
        var = f"_{root}_{'_'.join(parent.split('.')[1:parent.split('.').index(s) + 1])}"
        if var not in seen:
            parts.append(f"local {var} = {expr}")
            seen.add(var)
        chain = var

def var_of(parent):
    root, *subs = parent.split(".")
    if not subs:
        return root
    return f"_{root}_{'_'.join(subs)}"

for rel, parent, name, cls in FILES:
    with open(os.path.join(REPO, rel.replace("/", os.sep)), "r", encoding="utf-8") as f:
        src = f.read()
    ob, cb = bracket(src)
    # ขึ้นบรรทัดใหม่ทันทีหลังวงเล็บเปิด — Lua กินบรรทัดแรกทิ้งให้อยู่แล้ว
    parts.append(f"put({var_of(parent)}, '{name}', '{cls}', {ob}\n{src}{cb})")

parts.append(
    "return ('sync %d ไฟล์ | สร้างใหม่: %s'):format(#done, #made > 0 and table.concat(made, ', ') or 'ไม่มี')"
)

with open(OUT, "w", encoding="utf-8") as f:
    f.write("\n".join(parts))
print(f"generated {OUT} ({os.path.getsize(OUT)} bytes, {len(FILES)} files)")
for rel, parent, name, cls in FILES:
    print(f"  {rel} -> {parent}.{name} ({cls})")
