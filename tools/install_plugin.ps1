# copy plugin ทั้งหมดเข้าโฟลเดอร์ plugin ของ Studio (plugin ติดตั้งเป็นสำเนา ไม่ auto-update)
# รันหลังแก้ tools/*.plugin.luau ทุกครั้ง แล้ว restart Studio (หรือ Studio รีโหลด plugin เอง)
$dstDir = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'
New-Item -ItemType Directory -Force -Path $dstDir | Out-Null

$plugins = @(
    @{ src = 'CutsceneCamTool.plugin.luau'; dst = 'CutsceneCamTool.lua' },
    @{ src = 'LodFix.plugin.luau';          dst = 'LodFix.lua' },
    @{ src = 'RojoControl.plugin.luau';     dst = 'RojoControl.lua' },
    @{ src = 'NpcAnchorTool.plugin.luau';   dst = 'NpcAnchorTool.lua' }
)
foreach ($p in $plugins) {
    $src = Join-Path $PSScriptRoot $p.src
    $dst = Join-Path $dstDir $p.dst
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "copied -> $dst"
}
