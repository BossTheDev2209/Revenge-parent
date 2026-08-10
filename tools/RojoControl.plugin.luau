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
