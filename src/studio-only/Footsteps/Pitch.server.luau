-- สำเนาของ ServerScriptService.Footsteps.Pitch (Rojo ไม่ sync — ดู ../README.md)
-- ขยับ Pitch ของเสียงเดินขึ้นลงเล็กน้อยเป็นรอบ ให้เสียงก้าวไม่ซ้ำเป๊ะ (รวมทั้งรอบ = 0 ไม่เพี้ยนสะสม)

while wait(.3) do
	x = script.Parent:GetChildren()
	for i = 1,#x do
		if x[i]:IsA("Sound") then
			x[i].Pitch = x[i].Pitch - 0.1
		end
	end

	wait(.3)

	x = script.Parent:GetChildren()
	for i = 1,#x do
		if x[i]:IsA("Sound") then
			x[i].Pitch = x[i].Pitch - 0.1
		end
	end

	wait(.3)

	x = script.Parent:GetChildren()
	for i = 1,#x do
		if x[i]:IsA("Sound") then
			x[i].Pitch = x[i].Pitch + 0.2
		end
	end

	wait(.3)

	x = script.Parent:GetChildren()
	for i = 1,#x do
		if x[i]:IsA("Sound") then
			x[i].Pitch = x[i].Pitch - 0.1
		end
	end

	wait(.3)

	x = script.Parent:GetChildren()
	for i = 1,#x do
		if x[i]:IsA("Sound") then
			x[i].Pitch = x[i].Pitch + 0.1
		end
	end
end
