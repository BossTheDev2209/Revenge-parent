-- สำเนาของ ServerScriptService.Footsteps (Rojo ไม่ sync — ดู ../README.md)
-- โคลนตัวเอง + ลูกทั้งหมด (Script/Sound/Value) เข้า HumanoidRootPart ตอนตัวละครเกิด
-- แล้วลบเสียงเดิน default ของ Roblox ทิ้ง (c.Sound + Sound ใน Head)
-- ที่มา: Toolbox — CREDITOS: iiMAYK / Xx_andresXx

game.Players.PlayerAdded:connect(function(p)
	p.CharacterAdded:connect(function(c)
		local x = script:GetChildren()
		if c:FindFirstChild('Sound') then
			c.Sound:Destroy()
		end
		for i = 1, #x do
			if x[i]:IsA('Script') then
				local e = x[i]:Clone()
				e.Parent = c.HumanoidRootPart
				e.Disabled = false
			else
				x[i]:Clone().Parent = c.HumanoidRootPart
			end
		end
		local r = c.Head:GetChildren()
		for i = 1,#r do
			if r[i]:IsA('Sound') then
				r[i]:Destroy()
			end
		end
	end)
end)
