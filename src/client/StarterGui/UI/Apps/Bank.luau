-- Bank.luau — **layout ตามภาพร่าง `ui screenshot/PC-Bank-1 ui.png`** (PDF หน้า 9 — user lock 21 ก.ค.)
--   แถวบน  : 3 ตัวเลขสรุป — ยอดคงเหลือ | income per week | All รายจ่ายต่อ week (แดง)
--   แถวกลาง: การ์ด 3 ใบ — ค่าอาหาร / ค่าพนักงาน / ค่าเช่า · ครึ่งบนเว้นว่างไว้ใส่รูป ครึ่งล่าง ⊖ ตัวเลข ⊕
--   ล่างกลาง: ปุ่ม manage
-- ⊖⊕ ปรับงบ/สัปดาห์เป็น step ต่อการ์ด (Config.Spending) — server ตัดสิน ขอบเขต client แค่ยิง action
--
-- ★ baked เป็น instance จริงแล้ว (9 ส.ค.) — โครงคงที่ทั้งไฟล์ ไม่มีส่วนไหนยาวไม่แน่นอน
--   template จริงอยู่ Gui_PC.Screen.AppTemplates.Bank (แต่งใน Studio ได้เลย) — :Clone() ใส่ AppFrame ตอนเปิด
--   ชื่อลูกที่โค้ดอ้าง ห้ามเปลี่ยน: Head1-3.{Caption,Value} · CardFood/CardStaff/CardRent.{Name,ArtSlot,Amount,Minus,Plus}
--   CardXHint (ลูกตรงของ frame ไม่ใช่ของการ์ด) · ManageBtn · Footer
local isStudio = script ~= nil
local Config = if isStudio
	then require(game:GetService("ReplicatedStorage").Shared.Config)
	else require("../../../../shared/Config")

local Bank = {}

-- เรียงตามภาพร่าง: อาหาร | พนักงาน | เช่า — ชื่อ instance ต้องตรงกับที่ bake ไว้ใน template
local CARDS = {
	{ key = "food", cardName = "CardFood" },
	{ key = "staff", cardName = "CardStaff" },
	{ key = "rent", cardName = "CardRent" },
}

function Bank.create(frame, deps)
	local guiPC = frame:FindFirstAncestorOfClass("ScreenGui")
	local template = guiPC and guiPC:FindFirstChild("Screen") and guiPC.Screen.AppTemplates:FindFirstChild("Bank")
	if not template then
		warn("[Bank] ไม่มี template Gui_PC.Screen.AppTemplates.Bank — แต่งใน Studio ให้ครบก่อน")
		return {}
	end
	local content = template:Clone()
	content.Name = "BankContent"
	content.Visible = true -- template ซ่อนไว้ (Visible=false) กัน render ทับกันตอนพักเป็นแม่แบบ — clone ต้องเปิดเอง
	content.Parent = frame

	local heads = {}
	for i = 1, 3 do
		local col = content:FindFirstChild("Head" .. i)
		heads[i] = col and col:FindFirstChild("Value")
	end

	-- ★ 12 ส.ค. 2569 (user) "ตัดความไม่ makesense ออก":
	--   ปรับได้เฉพาะ "ค่าอาหาร" — ค่าเช่า fixed ตามเฟส · ค่าพนักงานเลิกเป็น "งบโบนัส" ที่ไม่เคยมีผลจริง
	--   การ์ดที่ปรับไม่ได้ = ซ่อนปุ่ม ⊖⊕ ไปเลย (โชว์ปุ่มที่กดแล้วไม่เกิดอะไร = ความไม่ makesense ที่ถูกสั่งให้ตัด)
	local ADJUSTABLE = { food = true }
	local rows = {}
	for _, def in CARDS do
		local card = content:FindFirstChild(def.cardName)
		if card then
			local amount = card:FindFirstChild("Amount")
			local hint = content:FindFirstChild(def.cardName .. "Hint")
			rows[def.key] = { amount = amount, hint = hint, card = card }
			local minus, plus = card:FindFirstChild("Minus"), card:FindFirstChild("Plus")
			if minus then
				minus.Visible = ADJUSTABLE[def.key] == true
				minus.Activated:Connect(function()
					deps.fireAction({ type = "AdjustSpending", card = def.key, dir = -1 })
				end)
			end
			if plus then
				plus.Visible = ADJUSTABLE[def.key] == true
				plus.Activated:Connect(function()
					deps.fireAction({ type = "AdjustSpending", card = def.key, dir = 1 })
				end)
			end
		end
	end

	-- ★ รวมหน้าจัดการพนักงาน: กด "การ์ดค่าพนักงาน" (ใบใหญ่) = เปิดหน้า Manage ที่เดิมต้องกดปุ่มเล็ก
	--   ปุ่มเล็ก ManageBtn เลยถูกซ่อน — ทางเข้าเหลือทางเดียว ไม่มีปุ่มซ้ำหน้าที่กัน
	local function openManage()
		if deps.openApp then deps.openApp("manage") end
	end
	local staffCard = rows.staff and rows.staff.card
	if staffCard then
		local hit = Instance.new("TextButton") -- การ์ดเป็น Frame กดไม่ได้ — วางปุ่มใสทับทั้งใบ
		hit.Name = "OpenManage"
		hit.Size = UDim2.fromScale(1, 1)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.ZIndex = 5
		hit.Parent = staffCard
		hit.Activated:Connect(openManage)
	end
	local manageBtn = content:FindFirstChild("ManageBtn")
	if manageBtn then
		manageBtn.Visible = false -- หน้าที่ย้ายไปอยู่บนการ์ดใบใหญ่แล้ว
		manageBtn.Activated:Connect(openManage)
	end
	local footer = content:FindFirstChild("Footer")

	local app = {}
	function app.refresh(state)
		local w = Config.WeeklyExpenses[state.phase]
		local sp = state.spending or {}
		local S = Config.Spending
		-- ค่าพนักงาน = เงินเดือนจริงของคนที่จ้างอยู่ (ตรงกับ StaffService.weeklySalary ที่ server หักจริง)
		-- ไม่ใช่ "งบโบนัส" แบบเดิมที่ปรับเองแล้วไม่มีผลกับอะไรเลย
		local staffSalary = 0
		for _, s in state.staff or {} do
			staffSalary += s.salary or 0
		end
		local base = { food = w.food, rent = w.rent, staff = staffSalary }
		local total = w.internet
		for _, def in CARDS do
			local row = rows[def.key]
			if row then
				local off = sp[def.key] or 0
				-- ค่าเช่า/ค่าพนักงานปรับไม่ได้แล้ว (Config.Spending min=max=0) → off เป็น 0 เสมอ
				local actual = math.max(0, base[def.key] + off * S[def.key].step)
				total += actual
				if row.amount then row.amount.Text = ("฿%d"):format(actual) end
				if row.hint then
					if def.key == "staff" then
						local n = #(state.staff or {})
						row.hint.Text = n > 0
							and ("%d คน · กดเพื่อจัดการทีม"):format(n)
							or "ยังไม่มีพนักงาน · กดเพื่อจ้าง"
					elseif def.key == "rent" then
						row.hint.Text = ("คงที่ตามเฟส %d"):format(state.phase)
					elseif off == 0 then
						row.hint.Text = "มาตรฐาน"
					else
						local cfg = S[def.key]
						local delta = off > 0 and off * cfg.mentalUp or -off * cfg.mentalDown
						row.hint.Text = ("ใจ %+d ต่อสัปดาห์"):format(delta)
					end
				end
			end
		end

		-- income/สัปดาห์ = เงินจากคลิปที่อัปใน 7 วันหลังสุด (clip.day ใส่ตอน uploadClip)
		local income = 0
		for _, c in state.clips do
			if c.uploaded and c.day and (state.day - c.day) < 7 then
				income += math.floor((c.gained or 0) * (Config.MoneyRatePerFollower[state.phase] or 1))
			end
		end

		if heads[1] then heads[1].Text = ("฿%d"):format(state.money) end
		if heads[2] then heads[2].Text = ("฿%d"):format(income) end
		if heads[3] then heads[3].Text = ("฿%d"):format(total) end

		local nextBill = state.day + (7 - (state.day - 1) % 7)
		if nextBill <= state.day then nextBill += 7 end
		if footer then
			footer.Text = ("🌐 เน็ต ฿%d (คงที่) · ตัดรอบวัน %d · ค้างค่าเช่า %d ครั้ง%s"):format(
				w.internet, nextBill, state.flags.rentMissed or 0,
				(state.flags.rentMissed or 0) > 0 and " ⚠️ (2 ครั้ง = โดนไล่ที่!)" or "")
		end
	end
	return app
end

return Bank
