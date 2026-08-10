# tools/rojo.ps1 — คุม rojo serve ระดับ process (plugin แตะ OS ไม่ได้ — ดู handoff 10 ส.ค.)
# ใช้: pwsh tools/rojo.ps1 <status|restart|kill-all|instances>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('status', 'restart', 'kill-all', 'instances')]
    [string]$Command
)

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ProjectFile = Join-Path $RepoRoot 'default.project.json'
$PortRangeStart = 34870
$PortRangeEnd = 34890

function Get-RojoApiInfo {
    param([int]$Port)
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:$Port/api/rojo" -UseBasicParsing -TimeoutSec 3
        $raw = [System.Text.Encoding]::GetEncoding('ISO-8859-1').GetString($r.Content)
        $projectName = if ($raw -match 'projectName.{1,2}?([\w.\-]+)') { $matches[1] } else { $null }
        $sessionId = if ($raw -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') { $matches[1] } else { $null }
        return [PSCustomObject]@{ Port = $Port; ProjectName = $projectName; SessionId = $sessionId; Ok = $true }
    } catch {
        return [PSCustomObject]@{ Port = $Port; ProjectName = $null; SessionId = $null; Ok = $false }
    }
}

function Get-ListeningRojoPorts {
    $ports = @()
    for ($p = $PortRangeStart; $p -le $PortRangeEnd; $p++) {
        $conn = Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue
        if ($conn) { $ports += $p }
    }
    return $ports
}

function Invoke-RojoStatus {
    Write-Host "== rojo processes ==" -ForegroundColor Cyan
    $procs = Get-Process -Name rojo -ErrorAction SilentlyContinue
    if (-not $procs) {
        Write-Host "  (none running)" -ForegroundColor Yellow
    } else {
        $procs | Select-Object Id, StartTime, Path | Format-Table -AutoSize | Out-String | Write-Host
        Write-Host "  ($($procs.Count) process(es) is normal — rokit shim + real binary)" -ForegroundColor DarkGray
    }

    Write-Host "== listening ports ($PortRangeStart-$PortRangeEnd) ==" -ForegroundColor Cyan
    $ports = Get-ListeningRojoPorts
    if ($ports.Count -eq 0) {
        Write-Host "  (none — rojo serve not running or not reachable)" -ForegroundColor Yellow
    } elseif ($ports.Count -gt 1) {
        Write-Host "  WARNING: $($ports.Count) ports listening — likely multiple sessions colliding" -ForegroundColor Red
    }
    foreach ($port in $ports) {
        $info = Get-RojoApiInfo -Port $port
        if ($info.Ok) {
            Write-Host "  port $port -> project=$($info.ProjectName) session=$($info.SessionId)"
        } else {
            Write-Host "  port $port -> listening but /api/rojo did not respond" -ForegroundColor Yellow
        }
    }

    if ($procs -and (Test-Path $ProjectFile)) {
        Write-Host "== pattern (7) check: server started before project file last edit? ==" -ForegroundColor Cyan
        $serverStart = ($procs | Measure-Object -Property StartTime -Minimum).Minimum
        $fileWrite = (Get-Item $ProjectFile).LastWriteTime
        Write-Host "  rojo serve started : $serverStart"
        Write-Host "  default.project.json edited : $fileWrite"
        if ($fileWrite -gt $serverStart) {
            Write-Host "  ❌ STALE — project file edited AFTER server started. Files newly mapped will NOT reach Studio." -ForegroundColor Red
            Write-Host "     Fix: pwsh tools/rojo.ps1 restart" -ForegroundColor Red
        } else {
            Write-Host "  ✅ server started after last project file edit — mapping is current" -ForegroundColor Green
        }
    }
}

function Invoke-RojoKillAll {
    $procs = Get-Process -Name rojo -ErrorAction SilentlyContinue
    if (-not $procs) {
        Write-Host "no rojo process running" -ForegroundColor Yellow
        return
    }
    $procs | Stop-Process -Force
    Write-Host "killed $($procs.Count) rojo process(es) (shim + real binary — normal to see 2)" -ForegroundColor Green
}

function Invoke-RojoRestart {
    Invoke-RojoKillAll
    Start-Sleep -Milliseconds 500

    Write-Host "starting: rojo serve (in $RepoRoot)" -ForegroundColor Cyan
    Start-Process -FilePath 'rojo' -ArgumentList 'serve' -WorkingDirectory $RepoRoot -WindowStyle Normal

    $deadline = (Get-Date).AddSeconds(15)
    $port = $null
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        foreach ($p in Get-ListeningRojoPorts) {
            $info = Get-RojoApiInfo -Port $p
            if ($info.Ok) { $port = $p; break }
        }
        if ($port) { break }
    }

    if ($port) {
        Write-Host "✅ rojo serve up on port $port — now click Disconnect then Connect in Studio's Rojo plugin" -ForegroundColor Green
    } else {
        Write-Host "❌ rojo serve did not come up within 15s — check the new terminal window it opened" -ForegroundColor Red
    }
}

# Invoke-RojoInstances is added above this line by Task 3 below. Keep this switch at the bottom of the file.
switch ($Command) {
    'status'    { Invoke-RojoStatus }
    'restart'   { Invoke-RojoRestart }
    'kill-all'  { Invoke-RojoKillAll }
    'instances' { Invoke-RojoInstances }
}
