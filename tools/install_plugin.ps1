# copy CutsceneCamTool เข้าโฟลเดอร์ plugin ของ Studio (plugin ติดตั้งเป็นสำเนา ไม่ auto-update)
# รันหลังแก้ tools/CutsceneCamTool.plugin.luau ทุกครั้ง แล้ว restart Studio (หรือ Studio รีโหลด plugin เอง)
$src = Join-Path $PSScriptRoot 'CutsceneCamTool.plugin.luau'
$dstDir = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'
$dst = Join-Path $dstDir 'CutsceneCamTool.lua'
New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
Copy-Item -Path $src -Destination $dst -Force
Write-Host "copied -> $dst"
