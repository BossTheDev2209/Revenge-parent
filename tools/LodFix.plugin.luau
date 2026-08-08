-- LodFix — Studio plugin ปุ่มเดียว: ปิด LOD imposter บนโมเดล union/mesh ใหญ่ทั้งแมพ
--
-- ทำไมต้องเป็น plugin: Model.LevelOfDetail เป็น property ที่ **script ในเกมแตะไม่ได้** (plugin เท่านั้น)
--   → runtime fix ทำไม่ได้ · ต้องแก้ที่ edit-time แล้ว save place · ปุ่มนี้ให้กดเองก่อน save ทุกครั้ง
--
-- ติดตั้ง: รัน tools/install_plugin.ps1 (copy เข้า %LOCALAPPDATA%\Roblox\Plugins) แล้วเปิด Studio ใหม่
--   แก้ไฟล์นี้ใน repo แล้วต้อง copy ทับใหม่ทุกครั้ง (plugin ติดตั้งเป็นสำเนา ไม่ auto-update)
--
-- อาการที่แก้: StreamingEnabled + LevelOfDetail=Automatic → กล้องไกล Roblox แทนโมเดลด้วย mesh imposter
--   union/mesh ซับซ้อน bake เข้า imposter ไม่ครบ → บาง part หายไปเลย · ปิด LOD = เรนเดอร์ของจริงเสมอ

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local PART_MIN = 6 -- studs — union/mesh ชิ้นที่ด้านยาวสุดถึงเท่านี้ = ปิด LOD ทุกโมเดลแม่ (ชิ้นเล็กปล่อย ประหยัดเฟรม)

-- ปิด LOD ทุกโมเดลแม่ของชิ้นนี้ (imposter สร้างที่ระดับโมเดลไหนก็ได้ → ปิดทั้งสาย) · คืนจำนวนโมเดลที่เพิ่งปิด
local function disableAncestors(part): number
	local n = 0
	local m = part.Parent
	while m and m ~= workspace do
		if m:IsA("Model") and m.LevelOfDetail == Enum.ModelLevelOfDetail.Automatic then
			m.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled
			n += 1
		end
		m = m.Parent
	end
	return n
end

local function fixAll(): number
	local models = 0
	for _, d in workspace:GetDescendants() do
		if d:IsA("UnionOperation") or d:IsA("MeshPart") then
			local s = d.Size
			if math.max(s.X, s.Y, s.Z) >= PART_MIN then
				models += disableAncestors(d)
			end
		end
	end
	return models
end

local toolbar = plugin:CreateToolbar("Streaming Fix")
local btn = toolbar:CreateButton(
	"Fix LOD",
	"ปิด LOD imposter โมเดล union/mesh ใหญ่ (กัน part หายตอนกล้องไกล) — กดแล้ว Ctrl+S ด้วย",
	"rbxasset://textures/ui/GuiImagePlaceholder.png"
)

btn.Click:Connect(function()
	local rec = ChangeHistoryService:TryBeginRecording("Fix LOD (disable imposter)")
	local n = fixAll()
	if rec then
		ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end
	print(("[LodFix] ปิด LOD imposter %d โมเดล — อย่าลืม Ctrl+S save"):format(n))
	btn:SetActive(false)
end)
