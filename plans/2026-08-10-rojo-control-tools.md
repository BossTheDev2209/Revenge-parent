# Rojo Control Tools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `tools/rojo.ps1` (OS-level control: status/restart/kill-all/instances) and `tools/RojoControl.plugin.luau` (Studio-side status/sync-check buttons) so Rojo sync failures (pattern ⑦ "connected but stale", ⑧ "wrong Studio window") get caught and fixed in one command instead of hours of confused debugging.

**Architecture:** Two independent halves per `C:\Users\khunb\AppData\Local\Temp\handoff-rojo-control-plugin.md` — Studio plugins can't touch OS processes (sandboxed, no shutdown endpoint on Rojo's HTTP API), so process-level fixes live in a PowerShell CLI, and Studio-side inspection lives in a plugin using the existing `Streaming Fix` toolbar.

**Tech Stack:** PowerShell 7 (`Get-Process`, `Get-NetTCPConnection`, `Invoke-WebRequest`), Luau (Studio plugin, `HttpService`, `ChangeHistoryService`), Rojo 7.7.0 HTTP API (`GET /api/rojo`, msgpack body).

**Known-good facts (verified live on this machine before writing this plan — don't re-derive):**
- `rojo` process currently running: PIDs 12924 (`~/.rokit/bin/rojo.exe`, shim) + 32716 (`~/.rokit/tool-storage/.../rojo.exe`, real binary), both `StartTime = 8/10/2026 8:33:58 PM`. **Two processes is normal, not two sessions.**
- Listening port: **34872** only (checked range 34870-34890).
- `default.project.json` `LastWriteTime = 8/10/2026 8:42:26 PM` — **8.5 min after** rojo started → this repo is **currently in the exact pattern ⑦ broken state** described in `docs/08-studio-sync-handoff.md` line 44. This is a live repro — no need to manufacture one for Task 2.
- `GET http://localhost:34872/api/rojo` returns HTTP 200, msgpack body (confirmed NOT JSON — `Content-Type` negotiation doesn't help). Raw bytes decoded as Latin1 look like:
  `sessionId$ad88423d-d3cf-4806-b3aa-254993cc1537 serverVersion 7.7.0 ... projectName getting-1m-follower ...`
  (separators are non-printable msgpack framing bytes, not literal spaces — shown as spaces here for readability)
- Field values are ASCII with no punctuation matching msgpack framing (project name: `[\w.\-]+`, sessionId: 36-char UUID `[0-9a-f\-]{36}`). Regex capture on those char classes skips the framing bytes cleanly — **including the one case where a length-prefix byte happens to render as a printable ASCII char** (`$` = 0x24 = length 36, appears before the sessionId UUID; excluded because `$` isn't in `[0-9a-f\-]`).

---

## Task 1: `tools/rojo.ps1` — script skeleton + `status`

**Files:**
- Create: `tools/rojo.ps1`

- [ ] **Step 1: Write the skeleton with param dispatch**

```powershell
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
        $projectName = if ($raw -match 'projectName([\w.\-]+)') { $matches[1] } else { $null }
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

# Invoke-RojoStatus / Invoke-RojoRestart / Invoke-RojoKillAll / Invoke-RojoInstances
# are added above this line by Tasks 2-3 below. Keep this switch at the bottom of the file.
switch ($Command) {
    'status'    { Invoke-RojoStatus }
    'restart'   { Invoke-RojoRestart }
    'kill-all'  { Invoke-RojoKillAll }
    'instances' { Invoke-RojoInstances }
}
```

- [ ] **Step 2: Add `Invoke-RojoStatus` (process list + port scan + pattern ⑦ check)**

Insert before the `switch` block:

```powershell
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
```

- [ ] **Step 3: Run against the live (currently broken) repo state to verify pattern ⑦ detection**

Run: `pwsh tools/rojo.ps1 status`

Expected output includes:
```
== pattern (7) check: server started before project file last edit? ==
  rojo serve started : 08/10/2026 20:33:58
  default.project.json edited : 08/10/2026 20:42:26
  ❌ STALE — project file edited AFTER server started. Files newly mapped will NOT reach Studio.
     Fix: pwsh tools/rojo.ps1 restart
```

If it doesn't say STALE here, the detection logic is wrong — this repo is a known-bad live fixture (see plan header). Do not proceed to Task 2 until this passes.

- [ ] **Step 4: Commit**

```bash
git add tools/rojo.ps1
git commit -m "feat(tools): rojo.ps1 status — catch pattern 7 (stale server) from OS state"
```

---

## Task 2: `restart` subcommand — actually fixes pattern ⑦

**Files:**
- Modify: `tools/rojo.ps1`

- [ ] **Step 1: Add `Invoke-RojoKillAll` and `Invoke-RojoRestart`**

Insert before the `switch` block (after `Invoke-RojoStatus`):

```powershell
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
```

- [ ] **Step 2: Run restart and confirm the live pattern ⑦ case is now fixed**

Run: `pwsh tools/rojo.ps1 restart`

Expected: prints `killed 2 rojo process(es)`, then `✅ rojo serve up on port 34872 — now click Disconnect then Connect in Studio's Rojo plugin`.

Then run `pwsh tools/rojo.ps1 status` again — expected: `✅ server started after last project file edit — mapping is current`.

- [ ] **Step 3: Hand off to user for the Studio-side half (per CLAUDE.md rule 13 — one click, not worth automating)**

Tell the user: click Disconnect then Connect on the Rojo plugin toolbar button in Studio, then check `StarterGui.UI.HUD` in Explorer for a child/descendant containing `MentalGroup` (per handoff Definition of Done — this confirms the newly-mapped `StarterGui.UI` node actually reached Studio this time). Do not attempt this via MCP/UI automation — the user can verify by eye in 5 seconds.

- [ ] **Step 4: Commit**

```bash
git add tools/rojo.ps1
git commit -m "feat(tools): rojo.ps1 restart/kill-all — fix pattern 7 in one command"
```

---

## Task 3: `instances` subcommand — pattern ⑧ (wrong Studio window)

**Files:**
- Modify: `tools/rojo.ps1`

- [ ] **Step 1: Add `Invoke-RojoInstances`**

Insert before the `switch` block:

```powershell
function Invoke-RojoInstances {
    $studios = Get-Process -Name RobloxStudioBeta -ErrorAction SilentlyContinue
    if (-not $studios) {
        Write-Host "no Roblox Studio window open" -ForegroundColor Yellow
        return
    }
    $studios | Select-Object Id, StartTime, MainWindowTitle | Format-Table -AutoSize | Out-String | Write-Host
    if ($studios.Count -gt 1) {
        Write-Host "⚠️  $($studios.Count) Studio windows open — pattern (8): make sure you're editing/testing in the one connected to rojo serve, close the rest" -ForegroundColor Red
    } else {
        Write-Host "✅ single Studio window" -ForegroundColor Green
    }
}
```

- [ ] **Step 2: Run it against current machine state**

Run: `pwsh tools/rojo.ps1 instances`

Expected: lists whatever `RobloxStudioBeta` processes are currently running (0 or more), with the multi-window warning firing only when count > 1. Confirm the count matches what's actually on screen — this is a real repro check, not a mock.

- [ ] **Step 3: Commit**

```bash
git add tools/rojo.ps1
git commit -m "feat(tools): rojo.ps1 instances — catch pattern 8 (multiple Studio windows)"
```

---

## Task 4: `tools/README.md` — document the new commands

**Files:**
- Modify: `tools/README.md`

- [ ] **Step 1: Add a row to the "สคริปต์หลัก" table and a usage block**

Insert after the existing table row for `mcp_driver.py` (around line 20 of the current file):

```markdown
| **`rojo.ps1`** | คุม `rojo serve` ระดับ process — `status` (จับ pattern ⑦ server ถือ project เก่า) / `restart` (kill+start ใหม่ทีเดียว) / `kill-all` / `instances` (จับ pattern ⑧ เปิด Studio หลายหน้าต่าง) · รายละเอียด pattern → `docs/08-studio-sync-handoff.md` |
```

Add near the bottom of the file, after the "เพิ่ม NPC ใหม่" section:

```markdown
## เจอ Rojo พัง (แก้แล้วไม่เข้า Studio)

```bash
pwsh tools/rojo.ps1 status      # เช็คว่า server ถือ project เก่าไหม (pattern ⑦) + กี่ session
pwsh tools/rojo.ps1 restart     # kill ทุกตัว + start ใหม่ทีเดียว — แล้วกด Disconnect/Connect ใน Studio
pwsh tools/rojo.ps1 instances   # เช็คว่าเปิด Studio ค้างหลายหน้าต่างไหม (pattern ⑧)
```

ปุ่ม `Rojo Status` / `Check Sync` ใน Studio toolbar `Streaming Fix` เสริมฝั่ง Studio (`tools/RojoControl.plugin.luau`) — ใช้คู่กัน: `rojo.ps1 status` บอกว่า process/port โอเคไหม, ปุ่มใน Studio บอกว่า Studio เห็นอะไรอยู่
```

- [ ] **Step 2: Commit**

```bash
git add tools/README.md
git commit -m "docs(tools): document rojo.ps1 usage"
```

---

## Task 5: `tools/RojoControl.plugin.luau` — Studio-side status buttons

**Files:**
- Create: `tools/RojoControl.plugin.luau`

- [ ] **Step 1: Write the plugin — reuses `Streaming Fix` toolbar, three read-only buttons**

```lua
-- RojoControl — ปุ่มดู sync ฝั่ง Studio (อ่านอย่างเดียว ห้ามแก้/ลบ instance เอง — CLAUDE.md rule 7)
--
-- ทำไมแยกจาก tools/rojo.ps1: plugin sandbox แตะ OS process ไม่ได้ ยิง HTTP ได้อย่างเดียว
--   (ยืนยันแล้ว: /api/shutdown ไม่มี, 404) — งาน kill/restart อยู่ฝั่ง rojo.ps1 เท่านั้น
--
-- ติดตั้ง: รัน tools/install_plugin.ps1 แล้วเปิด Studio ใหม่ (ปุ่ม toolbar สร้างตอน Studio เริ่มเท่านั้น)

local HttpService = game:GetService("HttpService")

local ROJO_PORTS = { 34872, 34873, 34874, 34875 } -- ช่วงที่ rojo ใช้จริง (เต็ม 34870-34890 ช้าเกินจำเป็นต่อกด)

-- แกะค่า field จาก msgpack response แบบหยาบ: จับ charset เฉพาะของ field นั้น
-- (ไบต์ length-prefix ของ msgpack ไม่ตกอยู่ใน charset พวกนี้ — ดู plan สำหรับเหตุผลเต็ม)
local function extractField(raw: string, key: string, pattern: string): string?
	local _, keyEnd = raw:find(key, 1, true)
	if not keyEnd then
		return nil
	end
	local value = raw:sub(keyEnd + 1, keyEnd + 60):match(pattern)
	return value
end

local function queryPort(port: number)
	local ok, result = pcall(function()
		return HttpService:GetAsync(("http://localhost:%d/api/rojo"):format(port))
	end)
	if not ok then
		return nil
	end
	return {
		port = port,
		projectName = extractField(result, "projectName", "[%w%.%-]+"),
		sessionId = extractField(result, "sessionId", "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"),
	}
end

local function rojoStatus()
	print("[RojoControl] scanning ports " .. ROJO_PORTS[1] .. "-" .. ROJO_PORTS[#ROJO_PORTS] .. "...")
	local found = 0
	for _, port in ROJO_PORTS do
		local info = queryPort(port)
		if info then
			found += 1
			print(("[RojoControl] port %d -> project=%s session=%s"):format(
				port, info.projectName or "?", info.sessionId or "?"
			))
			if info.projectName and info.projectName ~= "getting-1m-follower" then
				warn("[RojoControl] ⚠️ port " .. port .. " serving a DIFFERENT project — wrong session?")
			end
		end
	end
	if found == 0 then
		warn("[RojoControl] ❌ no rojo serve responding on any scanned port — is it running? (tools/rojo.ps1 status)")
	elseif found > 1 then
		warn("[RojoControl] ⚠️ " .. found .. " ports responding — multiple sessions, use tools/rojo.ps1 status to confirm")
	end
	print(("[RojoControl] this Studio: PlaceId=%d JobId=%s"):format(game.PlaceId, game.JobId))
end

local function findLeftovers()
	print("[RojoControl] scanning for leftover Rojo session locks + duplicate module names...")
	local lockCount = 0
	for _, svc in { game:GetService("ServerStorage"), game:GetService("ReplicatedStorage") } do
		for _, d in svc:GetDescendants() do
			if d.Name:sub(1, 6) == "__Rojo" then
				lockCount += 1
				warn("[RojoControl] leftover lock: " .. d:GetFullName())
			end
		end
	end
	if lockCount == 0 then
		print("[RojoControl] ✅ no leftover __Rojo* locks")
	end

	local seen = {}
	local dupes = 0
	for _, container in { game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService"), game:GetService("StarterPlayer") } do
		for _, d in container:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				seen[d.Name] = seen[d.Name] or {}
				table.insert(seen[d.Name], d:GetFullName())
			end
		end
	end
	for name, paths in seen do
		if #paths > 1 then
			dupes += 1
			warn(("[RojoControl] duplicate module name %q at: %s"):format(name, table.concat(paths, ", ")))
		end
	end
	if dupes == 0 then
		print("[RojoControl] ✅ no duplicate module names")
	end
	print("[RojoControl] report only — nothing deleted (CLAUDE.md rule 7)")
end

local toolbar = plugin:CreateToolbar("Streaming Fix")

local statusBtn = toolbar:CreateButton(
	"Rojo Status",
	"เช็คว่า Studio นี้ต่ออยู่กับ rojo serve ตัวไหน + มีกี่ session ชนกัน",
	"rbxasset://textures/ui/GuiImagePlaceholder.png"
)
statusBtn.Click:Connect(function()
	rojoStatus()
	statusBtn:SetActive(false)
end)

local leftoverBtn = toolbar:CreateButton(
	"Find Leftovers",
	"หา __Rojo_SessionLock ค้าง + โมดูลชื่อซ้ำ — รายงานอย่างเดียว ไม่ลบเอง",
	"rbxasset://textures/ui/GuiImagePlaceholder.png"
)
leftoverBtn.Click:Connect(function()
	findLeftovers()
	leftoverBtn:SetActive(false)
end)
```

- [ ] **Step 2: Register in `install_plugin.ps1`**

Modify `tools/install_plugin.ps1` — change the `$plugins` array:

```powershell
$plugins = @(
    @{ src = 'CutsceneCamTool.plugin.luau'; dst = 'CutsceneCamTool.lua' },
    @{ src = 'LodFix.plugin.luau';          dst = 'LodFix.lua' },
    @{ src = 'RojoControl.plugin.luau';     dst = 'RojoControl.lua' }
)
```

- [ ] **Step 3: Run the installer**

Run: `pwsh tools/install_plugin.ps1`

Expected: prints `copied -> ...\RojoControl.lua` among the other two lines.

- [ ] **Step 4: Hand off to user — restart Studio + click the buttons (one-shot, not automatable per rule 13)**

Tell the user: restart Roblox Studio (plugin only registers new toolbar buttons on load), then click `Rojo Status` and `Find Leftovers` on the `Streaming Fix` toolbar, check the Output window. `Rojo Status` should print this Studio's `PlaceId`/`JobId` and the port(s) it can reach — confirm the port matches whatever `pwsh tools/rojo.ps1 status` reported as listening.

- [ ] **Step 5: Commit**

```bash
git add tools/RojoControl.plugin.luau tools/install_plugin.ps1
git commit -m "feat(tools): RojoControl plugin — Rojo Status + Find Leftovers buttons"
```

---

## Task 6: Update docs cross-reference

**Files:**
- Modify: `docs/08-studio-sync-handoff.md`

- [ ] **Step 1: Add a pointer to the new tools near the pattern table**

After the pattern table (after line 42, before the `>` blockquote about pattern ⑦), insert:

```markdown
**เครื่องมือแก้ (10 ส.ค.):** `tools/rojo.ps1 status|restart|kill-all|instances` (ฝั่ง OS) +
`tools/RojoControl.plugin.luau` ปุ่ม `Rojo Status`/`Find Leftovers` ใน toolbar `Streaming Fix` (ฝั่ง Studio) —
วิธีใช้เต็ม → `tools/README.md`
```

- [ ] **Step 2: Commit**

```bash
git add docs/08-studio-sync-handoff.md
git commit -m "docs(rojo): point sync handoff at rojo.ps1 / RojoControl tools"
```

---

## Task 7: Push

- [ ] **Step 1: Pull rebase, then push (CLAUDE.md rule 12 — repo has concurrent editors)**

```bash
git pull --rebase
git push
```
