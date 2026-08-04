-- สำเนาของ ServerScriptService.Footsteps.MaterialDetect (Rojo ไม่ sync — ดู ../README.md)
-- ยิง ray ลงล่าง 10 studs อ่าน Material ของพื้น เขียนชื่อลง Materials (StringValue) ให้ Running อ่าน
-- ไม่เจอพื้น/ไม่ตรง Material ไหน = "None" (Running จะไม่เล่นเสียง)

Materials = script.Parent.Materials
Color = script.Parent.Colors

while true do
	local ray = Ray.new(
	                script.Parent.Position,
	                Vector3.new(0, -10, 0)
	            )
	local part, endPoint = workspace:FindPartOnRay(ray, script.Parent.Parent)
	if part then
		if part.Material == Enum.Material.Grass then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Grass"
		elseif part.Name == "Terrain" then
			Color.Value = BrickColor.new("Camo")
			Materials.Value = "Grass"
		elseif part.Name == "Water" then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Water"
		elseif part.Material == Enum.Material.Cobblestone then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Cobblestone"
		elseif part.Material == Enum.Material.WoodPlanks then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "WoodPlanks"
		elseif part.Material == Enum.Material.Ice then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Ice"
		elseif part.Material == Enum.Material.Metal then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Metal"
		elseif part.Material == Enum.Material.Wood then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Wood"
		elseif part.Material == Enum.Material.Plastic then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Plastic"
		elseif part.Material == Enum.Material.Foil then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Foil"
		elseif part.Material == Enum.Material.DiamondPlate then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "DiamondPlate"
		elseif part.Material == Enum.Material.CorrodedMetal then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "CMetal"
		elseif part.Material == Enum.Material.Concrete then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Concrete"
		elseif part.Material == Enum.Material.Slate then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Slate"
		elseif part.Material == Enum.Material.Sand then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Sand"
		elseif part.Material == Enum.Material.Marble then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Marble"
		elseif part.Material == Enum.Material.Granite then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Granite"
		elseif part.Material == Enum.Material.Brick then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Brick"
elseif part.Material == Enum.Material.Pebble then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Pebble"
elseif part.Material == Enum.Material.	Fabric then
			Color.Value = BrickColor.new(part.Color)
			Materials.Value = "Fabric"			end
		else
		Materials.Value = "None"
	end
	wait()
end
