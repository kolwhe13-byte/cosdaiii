--[[
    Задрочка типов v5.0
    Оптимизированная мобильная версия
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local VirtualUser       = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 8)
if not PlayerGui then return end

-- Удаляем старую копию
local old = PlayerGui:FindFirstChild("ZadrochkaTipov")
if old then old:Destroy() end

--------------------------------------------------
-- Настройки
--------------------------------------------------
local S = {
	FlySpeed       = 60,
	CircleRadius   = 8,
	CircleHeight   = 4,
	CircleSpeed    = 0.65,
	AttackRange    = 6,
	AttackCooldown = 0.9,
	AutoWeapon     = true,
	WeaponSlot     = 2,
	Noclip         = false,
	SpeedHack      = false,
	SpeedValue     = 50,
	ESP            = false,
	ESP_Highlight  = true,
	ESP_Name       = true,
	ESP_Distance   = true,
}

local Target          = nil
local isActive        = false
local circleAngle     = 0
local lastAttack      = 0
local noclipCache     = {}
local isMinimized     = false
local StatusLabel     = nil
local espFolder       = nil
local espData         = {} -- [player] = {hl, bb, label}

--------------------------------------------------
-- Анти-AFK / Gameplay Paused
--------------------------------------------------
LocalPlayer.Idled:Connect(function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

--------------------------------------------------
-- Вспомогательные
--------------------------------------------------
local function Alive(plr)
	if not plr or plr == LocalPlayer then return false end
	local char = plr.Character
	if not char then return false end
	local hum  = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	return hum and hum.Health > 0 and root
end

local function Root(plr)
	local char = plr and plr.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function Hum()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

--------------------------------------------------
-- Noclip
--------------------------------------------------
local function RestoreNoclip()
	for part, old in pairs(noclipCache) do
		if part and part.Parent then
			part.CanCollide = old
		end
	end
	table.clear(noclipCache)
end

RunService.Stepped:Connect(function()
	if not S.Noclip then return end
	local char = LocalPlayer.Character
	if not char then return end
	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("BasePart") then
			if noclipCache[obj] == nil then
				noclipCache[obj] = obj.CanCollide
			end
			obj.CanCollide = false
		end
	end
end)

--------------------------------------------------
-- Оружие + Атака
--------------------------------------------------
local function EquipWeapon()
	if not S.AutoWeapon then return end
	local char = LocalPlayer.Character
	local hum  = Hum()
	local bag  = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not char or not hum or not bag then return end
	if char:FindFirstChildOfClass("Tool") then return end

	local tools = {}
	for _, item in ipairs(bag:GetChildren()) do
		if item:IsA("Tool") then
			table.insert(tools, item)
		end
	end
	local slot = math.clamp(S.WeaponSlot, 1, math.max(#tools, 1))
	local tool = tools[slot]
	if tool then
		pcall(hum.EquipTool, hum, tool)
	end
end

local function Attack()
	if not Target or not Alive(Target) then return end
	if tick() - lastAttack < S.AttackCooldown then return end
	EquipWeapon()
	local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
	if tool then
		if pcall(tool.Activate, tool) then
			lastAttack = tick()
		end
	end
end

local function Nearest()
	local my = Root(LocalPlayer)
	if not my then return nil end
	local best, bestD = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if Alive(p) then
			local r = Root(p)
			local d = (r.Position - my.Position).Magnitude
			if d < bestD then best, bestD = p, d end
		end
	end
	return best
end

--------------------------------------------------
-- ESP (оптимизированный)
--------------------------------------------------
local function ClearESP()
	for _, d in pairs(espData) do
		if d.hl then d.hl:Destroy() end
		if d.bb then d.bb:Destroy() end
	end
	table.clear(espData)
	if espFolder then
		espFolder:Destroy()
		espFolder = nil
	end
end

local function EnsureESPFolder()
	if not espFolder then
		espFolder = Instance.new("Folder")
		espFolder.Name = "ZadrochkaESP"
		espFolder.Parent = PlayerGui
	end
end

local function CreateESP(plr)
	if not S.ESP or plr == LocalPlayer or espData[plr] then return end
	local char = plr.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	EnsureESPFolder()
	local data = {}

	if S.ESP_Highlight then
		local hl = Instance.new("Highlight")
		hl.Adornee = char
		hl.FillColor = Color3.fromRGB(255, 50, 50)
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.FillTransparency = 0.55
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = espFolder
		data.hl = hl
	end

	if S.ESP_Name or S.ESP_Distance then
		local bb = Instance.new("BillboardGui")
		bb.Adornee = root
		bb.Size = UDim2.fromOffset(120, 36)
		bb.StudsOffset = Vector3.new(0, 3.2, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 20000
		bb.Parent = espFolder

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextStrokeTransparency = 0.3
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 12
		lbl.Parent = bb

		data.bb = bb
		data.lbl = lbl
	end

	espData[plr] = data
end

local function RefreshESP()
	ClearESP()
	if not S.ESP then return end
	for _, p in ipairs(Players:GetPlayers()) do
		CreateESP(p)
	end
end

--------------------------------------------------
-- Таргет логика
--------------------------------------------------
local function StopTarget()
	isActive = false
	local root = Root(LocalPlayer)
	if root then root.AssemblyLinearVelocity = Vector3.zero end
	RestoreNoclip()
	if StatusLabel then StatusLabel.Text = "Статус: остановлен" end
end

local function StartTarget()
	if not Target or not Alive(Target) then
		if StatusLabel then StatusLabel.Text = "Статус: выбери цель" end
		return
	end
	isActive = true
	circleAngle = 0
	if StatusLabel then
		StatusLabel.Text = "Статус: активен • " .. Target.DisplayName
	end
end

--------------------------------------------------
-- Главный цикл (всё в одном Heartbeat)
--------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	-- Speedhack
	if S.SpeedHack then
		local h = Hum()
		if h and h.WalkSpeed ~= S.SpeedValue then
			h.WalkSpeed = S.SpeedValue
		end
	end

	-- ESP текст
	if S.ESP then
		local myRoot = Root(LocalPlayer)
		for plr, data in pairs(espData) do
			if not Alive(plr) then
				if data.hl then data.hl:Destroy() end
				if data.bb then data.bb:Destroy() end
				espData[plr] = nil
			else
				-- обновляем adornee если нужно
				local char = plr.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if data.hl and char and data.hl.Adornee ~= char then
					data.hl.Adornee = char
				end
				if data.bb and root then
					data.bb.Adornee = root
				end
				if data.lbl then
					local parts = {}
					if S.ESP_Name then table.insert(parts, plr.DisplayName) end
					if S.ESP_Distance and myRoot and root then
						table.insert(parts, math.floor((root.Position - myRoot.Position).Magnitude) .. "m")
					end
					data.lbl.Text = table.concat(parts, "\n")
				end
			end
		end
	end

	-- Таргет
	if not isActive or not Target then return end
	if not Alive(Target) then
		StopTarget()
		if StatusLabel then StatusLabel.Text = "Статус: цель потеряна" end
		return
	end

	local myRoot = Root(LocalPlayer)
	local tRoot  = Root(Target)
	if not myRoot or not tRoot then return end

	-- Смотрим на цель
	local look = Vector3.new(tRoot.Position.X, myRoot.Position.Y, tRoot.Position.Z)
	myRoot.CFrame = CFrame.lookAt(myRoot.Position, look)

	-- Кружение
	circleAngle += S.CircleSpeed * dt * 3.5
	local desired = tRoot.Position + Vector3.new(
		math.cos(circleAngle) * S.CircleRadius,
		S.CircleHeight,
		math.sin(circleAngle) * S.CircleRadius
	)

	local delta = desired - myRoot.Position
	local dist  = delta.Magnitude
	if dist > 0.6 then
		myRoot.AssemblyLinearVelocity = delta.Unit * math.min(S.FlySpeed, dist * 8)
	else
		myRoot.AssemblyLinearVelocity = Vector3.zero
	end

	if (tRoot.Position - myRoot.Position).Magnitude <= S.AttackRange then
		Attack()
	end
end)

--------------------------------------------------
-- GUI
--------------------------------------------------
local Gui = Instance.new("ScreenGui")
Gui.Name = "ZadrochkaTipov"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(270, 390)
Main.Position = UDim2.new(0.5, -135, 0.5, -195)
Main.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = Gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

Instance.new("UIStroke", Main).Color = Color3.fromRGB(60, 75, 110)
Main:FindFirstChildOfClass("UIStroke").Transparency = 0.4

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 34)
Header.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -75, 1, 0)
Title.Position = UDim2.fromOffset(10, 0)
Title.BackgroundTransparency = 1
Title.Text = "Задрочка типов"
Title.TextColor3 = Color3.fromRGB(245, 247, 250)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.fromOffset(26, 24)
MinBtn.Position = UDim2.new(1, -58, 0, 5)
MinBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
MinBtn.Text = "−"
MinBtn.TextColor3 = Color3.new(1, 1, 1)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 15
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 5)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(26, 24)
CloseBtn.Position = UDim2.new(1, -28, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(135, 45, 50)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 15
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)

local Tabs = Instance.new("Frame")
Tabs.Size = UDim2.new(1, -10, 0, 28)
Tabs.Position = UDim2.fromOffset(5, 38)
Tabs.BackgroundTransparency = 1
Tabs.Parent = Main

local tabLay = Instance.new("UIListLayout")
tabLay.FillDirection = Enum.FillDirection.Horizontal
tabLay.Padding = UDim.new(0, 4)
tabLay.Parent = Tabs

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -10, 1, -135)
Content.Position = UDim2.fromOffset(5, 70)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Bottom = Instance.new("Frame")
Bottom.Size = UDim2.new(1, -10, 0, 95)
Bottom.Position = UDim2.new(0, 5, 1, -100)
Bottom.BackgroundTransparency = 1
Bottom.Parent = Main

--------------------------------------------------
-- UI helpers
--------------------------------------------------
local function corner(o, r)
	Instance.new("UICorner", o).CornerRadius = UDim.new(0, r or 6)
end

local function btn(parent, text, h)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, h or 30)
	b.BackgroundColor3 = Color3.fromRGB(40, 44, 58)
	b.TextColor3 = Color3.fromRGB(235, 238, 245)
	b.Text = text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 12
	b.BorderSizePixel = 0
	b.Parent = parent
	corner(b, 6)
	return b
end

local function lbl(parent, text, h)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, h or 18)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = Color3.fromRGB(195, 205, 220)
	l.Font = Enum.Font.Gotham
	l.TextSize = 12
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function toggle(parent, text, val, cb)
	local b = btn(parent, text .. ": " .. (val and "ON" or "OFF"), 30)
	b.BackgroundColor3 = val and Color3.fromRGB(40, 125, 75) or Color3.fromRGB(40, 44, 58)
	b.MouseButton1Click:Connect(function()
		val = not val
		b.Text = text .. ": " .. (val and "ON" or "OFF")
		b.BackgroundColor3 = val and Color3.fromRGB(40, 125, 75) or Color3.fromRGB(40, 44, 58)
		cb(val)
	end)
	return b
end

local function slider(parent, text, key, minV, maxV, step)
	local hold = Instance.new("Frame")
	hold.Size = UDim2.new(1, 0, 0, 44)
	hold.BackgroundTransparency = 1
	hold.Parent = parent

	local name = lbl(hold, text, 15)
	name.Size = UDim2.new(1, -45, 0, 15)

	local valT = lbl(hold, tostring(S[key]), 15)
	valT.Size = UDim2.fromOffset(42, 15)
	valT.Position = UDim2.new(1, -42, 0, 0)
	valT.TextXAlignment = Enum.TextXAlignment.Right
	valT.TextColor3 = Color3.fromRGB(110, 170, 255)
	valT.Font = Enum.Font.GothamBold

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.Position = UDim2.fromOffset(0, 24)
	bar.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
	bar.BorderSizePixel = 0
	bar.Active = true
	bar.Parent = hold
	corner(bar, 3)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(85, 145, 230)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	corner(fill, 3)

	local drag = false
	local function set(x)
		local w = math.max(bar.AbsoluteSize.X, 1)
		local a = math.clamp((x - bar.AbsolutePosition.X) / w, 0, 1)
		local v = math.clamp(math.floor((minV + (maxV - minV) * a) / step + 0.5) * step, minV, maxV)
		S[key] = v
		fill.Size = UDim2.new((v - minV) / (maxV - minV), 0, 1, 0)
		valT.Text = string.format("%g", v)
		if key == "SpeedValue" and S.SpeedHack then
			local h = Hum()
			if h then h.WalkSpeed = v end
		end
	end

	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			drag = true
			set(i.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			set(i.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			drag = false
		end
	end)

	task.defer(function()
		fill.Size = UDim2.new((S[key] - minV) / (maxV - minV), 0, 1, 0)
	end)
	return hold
end

-- Drag за любую часть
do
	local dragging, start, pos = false, nil, nil
	local function begin(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			start = i.Position
			pos = Main.Position
		end
	end
	Main.InputBegan:Connect(begin)
	Header.InputBegan:Connect(begin)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - start
			Main.Position = UDim2.new(pos.X.Scale, pos.X.Offset + d.X, pos.Y.Scale, pos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

--------------------------------------------------
-- Страницы
--------------------------------------------------
local Pages, TabBtns = {}, {}

local function newPage(name)
	local p = Instance.new("ScrollingFrame")
	p.Size = UDim2.new(1, 0, 1, 0)
	p.BackgroundTransparency = 1
	p.BorderSizePixel = 0
	p.ScrollBarThickness = 3
	p.CanvasSize = UDim2.new()
	p.AutomaticCanvasSize = Enum.AutomaticSize.Y
	p.Visible = false
	p.Parent = Content
	Instance.new("UIPadding", p).PaddingBottom = UDim.new(0, 6)
	local lay = Instance.new("UIListLayout", p)
	lay.Padding = UDim.new(0, 5)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	Pages[name] = p
	return p
end

local function newTab(name)
	local b = btn(Tabs, name, 28)
	b.Size = UDim2.new(0.5, -3, 0, 28)
	TabBtns[name] = b
	return b
end

local function show(name)
	for n, p in pairs(Pages) do p.Visible = (n == name) end
	for n, b in pairs(TabBtns) do
		b.BackgroundColor3 = (n == name) and Color3.fromRGB(50, 70, 110) or Color3.fromRGB(40, 44, 58)
	end
end

--------------------------------------------------
-- Вкладка Таргет
--------------------------------------------------
local pageT = newPage("Таргет")
newTab("Таргет")

lbl(pageT, "Настройки таргета", 16)
slider(pageT, "Скорость полёта", "FlySpeed", 20, 150, 5)
slider(pageT, "Радиус кружения", "CircleRadius", 2, 30, 1)
slider(pageT, "Высота", "CircleHeight", -10, 25, 1)
slider(pageT, "Скорость кружения", "CircleSpeed", 0.1, 3, 0.05)
slider(pageT, "Радиус атаки", "AttackRange", 2, 20, 1)
slider(pageT, "Задержка атаки", "AttackCooldown", 0.3, 3, 0.1)
slider(pageT, "Слот оружия", "WeaponSlot", 1, 10, 1)
toggle(pageT, "Автооружие", S.AutoWeapon, function(v) S.AutoWeapon = v end)

lbl(pageT, "Выбор цели", 16)

local Search = Instance.new("TextBox")
Search.Size = UDim2.new(1, 0, 0, 28)
Search.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
Search.TextColor3 = Color3.new(1, 1, 1)
Search.PlaceholderColor3 = Color3.fromRGB(120, 130, 145)
Search.PlaceholderText = "Поиск..."
Search.Text = ""
Search.Font = Enum.Font.Gotham
Search.TextSize = 12
Search.TextXAlignment = Enum.TextXAlignment.Left
Search.BorderSizePixel = 0
Search.Parent = pageT
corner(Search, 6)
Instance.new("UIPadding", Search).PaddingLeft = UDim.new(0, 8)

local TargetInfo = lbl(pageT, "Цель: не выбрана", 16)
TargetInfo.TextColor3 = Color3.fromRGB(120, 180, 255)

local PlayerList = Instance.new("ScrollingFrame")
PlayerList.Size = UDim2.new(1, 0, 0, 95)
PlayerList.BackgroundColor3 = Color3.fromRGB(22, 25, 33)
PlayerList.BorderSizePixel = 0
PlayerList.ScrollBarThickness = 3
PlayerList.CanvasSize = UDim2.new()
PlayerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
PlayerList.Parent = pageT
corner(PlayerList, 6)

local lp = Instance.new("UIPadding", PlayerList)
lp.PaddingTop = UDim.new(0, 3)
lp.PaddingBottom = UDim.new(0, 3)
lp.PaddingLeft = UDim.new(0, 3)
lp.PaddingRight = UDim.new(0, 3)

Instance.new("UIListLayout", PlayerList).Padding = UDim.new(0, 3)

local function updInfo()
	if Target and Alive(Target) then
		local r, my = Root(Target), Root(LocalPlayer)
		local d = (r and my) and math.floor((r.Position - my.Position).Magnitude) or 0
		TargetInfo.Text = string.format("Цель: %s  •  %dm", Target.DisplayName, d)
	else
		TargetInfo.Text = "Цель: не выбрана"
	end
end

local function refreshList()
	for _, c in ipairs(PlayerList:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	local q = string.lower(Search.Text or "")
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then table.insert(list, p) end
	end
	table.sort(list, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)

	for _, p in ipairs(list) do
		if q == "" or p.DisplayName:lower():find(q, 1, true) or p.Name:lower():find(q, 1, true) then
			local alive = Alive(p)
			local b = btn(PlayerList, (alive and "● " or "○ ") .. p.DisplayName, 28)
			b.BackgroundColor3 = (p == Target) and Color3.fromRGB(50, 80, 125) or (alive and Color3.fromRGB(34, 40, 52) or Color3.fromRGB(45, 38, 40))
			b.TextColor3 = alive and Color3.fromRGB(235, 238, 245) or Color3.fromRGB(130, 135, 145)
			b.MouseButton1Click:Connect(function()
				Target = alive and p or nil
				updInfo()
				refreshList()
			end)
		end
	end
	updInfo()
end

Search:GetPropertyChangedSignal("Text"):Connect(refreshList)

btn(pageT, "Выбрать ближайшую", 30).MouseButton1Click:Connect(function()
	local n = Nearest()
	if n then Target = n refreshList() end
end)

btn(pageT, "⚔ Атаковать ближайшего", 32).MouseButton1Click:Connect(function()
	local n = Nearest()
	if n then
		Target = n
		refreshList()
		StartTarget()
	else
		if StatusLabel then StatusLabel.Text = "Статус: нет целей" end
	end
end)

--------------------------------------------------
-- Нижние кнопки
--------------------------------------------------
local startB = btn(Bottom, "▶  ЗАПУСТИТЬ", 34)
startB.BackgroundColor3 = Color3.fromRGB(40, 125, 75)
startB.Position = UDim2.fromOffset(0, 0)

local stopB = btn(Bottom, "■  ОСТАНОВИТЬ", 30)
stopB.BackgroundColor3 = Color3.fromRGB(125, 45, 50)
stopB.Position = UDim2.fromOffset(0, 38)

StatusLabel = lbl(Bottom, "Статус: остановлен", 16)
StatusLabel.Position = UDim2.fromOffset(0, 74)
StatusLabel.TextColor3 = Color3.fromRGB(150, 160, 175)

startB.MouseButton1Click:Connect(StartTarget)
stopB.MouseButton1Click:Connect(StopTarget)

--------------------------------------------------
-- Вкладка Доп.
--------------------------------------------------
local pageE = newPage("Доп.")
newTab("Доп.")

lbl(pageE, "Движение", 16)
toggle(pageE, "Noclip", S.Noclip, function(v)
	S.Noclip = v
	if not v then RestoreNoclip() end
end)
toggle(pageE, "Speedhack", S.SpeedHack, function(v)
	S.SpeedHack = v
	local h = Hum()
	if h then h.WalkSpeed = v and S.SpeedValue or 16 end
end)
slider(pageE, "Скорость Speedhack", "SpeedValue", 16, 150, 1)

lbl(pageE, "ESP", 16)
toggle(pageE, "ESP Вкл", S.ESP, function(v)
	S.ESP = v
	if v then RefreshESP() else ClearESP() end
end)
toggle(pageE, "Подсветка", S.ESP_Highlight, function(v)
	S.ESP_Highlight = v
	if S.ESP then RefreshESP() end
end)
toggle(pageE, "Имя", S.ESP_Name, function(v)
	S.ESP_Name = v
	if S.ESP then RefreshESP() end
end)
toggle(pageE, "Дистанция", S.ESP_Distance, function(v)
	S.ESP_Distance = v
	if S.ESP then RefreshESP() end
end)

--------------------------------------------------
-- Свернуть / Закрыть
--------------------------------------------------
MinBtn.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	if isMinimized then
		Tabs.Visible = false
		Content.Visible = false
		Bottom.Visible = false
		TweenService:Create(Main, TweenInfo.new(0.14), {Size = UDim2.fromOffset(145, 34)}):Play()
		MinBtn.Text = "+"
	else
		TweenService:Create(Main, TweenInfo.new(0.14), {Size = UDim2.fromOffset(270, 390)}):Play()
		task.delay(0.12, function()
			if not isMinimized then
				Tabs.Visible = true
				Content.Visible = true
				Bottom.Visible = true
			end
		end)
		MinBtn.Text = "−"
	end
end)

CloseBtn.MouseButton1Click:Connect(function()
	StopTarget()
	RestoreNoclip()
	ClearESP()
	local h = Hum()
	if h then h.WalkSpeed = 16 end
	Gui:Destroy()
end)

--------------------------------------------------
-- События
--------------------------------------------------
for n, b in pairs(TabBtns) do
	b.MouseButton1Click:Connect(function() show(n) end)
end
show("Таргет")
refreshList()

Players.PlayerAdded:Connect(function(p)
	task.defer(refreshList)
	p.CharacterAdded:Connect(function()
		task.wait(0.4)
		task.defer(refreshList)
		if S.ESP then CreateESP(p) end
	end)
	if S.ESP then CreateESP(p) end
end)

Players.PlayerRemoving:Connect(function(p)
	if p == Target then Target = nil StopTarget() end
	if espData[p] then
		local d = espData[p]
		if d.hl then d.hl:Destroy() end
		if d.bb then d.bb:Destroy() end
		espData[p] = nil
	end
	task.defer(refreshList)
end)

LocalPlayer.CharacterAdded:Connect(function()
	StopTarget()
	Target = nil
	RestoreNoclip()
	task.defer(refreshList)
	if S.ESP then task.defer(RefreshESP) end
	if StatusLabel then StatusLabel.Text = "Статус: респавн" end
end)

-- Обновление инфо о цели
RunService.Heartbeat:Connect(updInfo)

print("[Задрочка типов] v5.0 загружена")
