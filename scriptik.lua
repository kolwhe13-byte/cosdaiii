--[[
    Задрочка типов v5.3
    Исправлен noclip + одна кнопка + килаура + центр настроек
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local VirtualUser      = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 8)
if not PlayerGui then return end

local old = PlayerGui:FindFirstChild("ZadrochkaTipov")
if old then old:Destroy() end

--------------------------------------------------
-- Настройки
--------------------------------------------------
local S = {
	BehindSpeed     = 70,
	BehindDistance  = 3.5,
	BehindHeight    = 1.5,
	JitterAmount    = 1.2,
	JitterSpeed     = 8,

	AttackRange     = 7,
	AttackCooldown  = 0.75,

	AutoWeapon      = true,
	WeaponSlot      = 2,

	Noclip          = false,
	SpeedHack       = false,
	SpeedValue      = 50,

	ESP             = false,
	ESP_Highlight   = true,
	ESP_Name        = true,
	ESP_Distance    = true,
}

local Target       = nil
local isActive     = false
local lastAttack   = 0
local noclipCache  = {}
local isMinimized  = false
local StatusLabel  = nil
local espFolder    = nil
local espData      = {}
local settingsOpen = false

--------------------------------------------------
-- Анти Gameplay Paused / Anti-AFK
--------------------------------------------------
local function RemovePaused()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end

LocalPlayer.Idled:Connect(RemovePaused)

task.spawn(function()
	while task.wait(18) do
		RemovePaused()
	end
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
	return hum ~= nil and hum.Health > 0 and root ~= nil
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
-- Noclip (ИСПРАВЛЕН)
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
			if obj.Name == "HumanoidRootPart" then
				obj.CanCollide = true
			else
				if noclipCache[obj] == nil then
					noclipCache[obj] = obj.CanCollide
				end
				if obj.CanCollide ~= false then
					obj.CanCollide = false
				end
			end
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
	if #tools == 0 then return end
	local slot = math.clamp(S.WeaponSlot, 1, #tools)
	pcall(function()
		hum:EquipTool(tools[slot])
	end)
end

local function Attack()
	if not Target or not Alive(Target) then return end
	if tick() - lastAttack < S.AttackCooldown then return end

	EquipWeapon()

	local char = LocalPlayer.Character
	if not char then return end
	local tool = char:FindFirstChildOfClass("Tool")
	if tool then
		if pcall(function() tool:Activate() end) then
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
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

--------------------------------------------------
-- ESP
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

local function CreateESP(plr)
	if not S.ESP or plr == LocalPlayer or espData[plr] then return end
	local char = plr.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if not espFolder then
		espFolder = Instance.new("Folder")
		espFolder.Name = "ZadrochkaESP"
		espFolder.Parent = PlayerGui
	end

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
		bb.Size = UDim2.fromOffset(110, 34)
		bb.StudsOffset = Vector3.new(0, 3.1, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 30000
		bb.Parent = espFolder

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextStrokeTransparency = 0.25
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 11
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
-- Таргет (КИЛАУРА)
--------------------------------------------------
local function StopTarget()
	isActive = false
	local root = Root(LocalPlayer)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	local h = Hum()
	if h then
		h.PlatformStand = false
	end
	if not S.Noclip then RestoreNoclip() end
	if StatusLabel then StatusLabel.Text = "Статус: остановлена" end
end

local function StartTarget()
	if not Target then
		if StatusLabel then StatusLabel.Text = "Статус: выбери цель" end
		return
	end
	isActive = true
	if StatusLabel then
		StatusLabel.Text = "Статус: килаура активна • " .. (Target.DisplayName or Target.Name)
	end
end

local function ToggleTarget()
	if isActive then
		StopTarget()
	else
		if not Target then
			local n = Nearest()
			if n then
				Target = n
			else
				if StatusLabel then StatusLabel.Text = "Статус: нет целей" end
				return
			end
		end
		StartTarget()
	end
end

--------------------------------------------------
-- Главный цикл
--------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	-- Speedhack
	if S.SpeedHack then
		local h = Hum()
		if h and h.WalkSpeed ~= S.SpeedValue then
			h.WalkSpeed = S.SpeedValue
		end
	end

	-- ESP
	if S.ESP then
		local myRoot = Root(LocalPlayer)
		for plr, data in pairs(espData) do
			if not plr.Parent then
				if data.hl then data.hl:Destroy() end
				if data.bb then data.bb:Destroy() end
				espData[plr] = nil
			else
				local char = plr.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if data.hl and char then data.hl.Adornee = char end
				if data.bb and root then data.bb.Adornee = root end
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

	-- ===== КИЛАУРА =====
	if not isActive or not Target then return end

	-- Автоматический поиск новой цели если текущая мертва
	local tHum = Target.Character and Target.Character:FindFirstChildOfClass("Humanoid")
	if not Target.Parent or (tHum and tHum.Health <= 0) then
		local n = Nearest()
		if n then
			Target = n
		else
			Target = nil
			StopTarget()
			if StatusLabel then StatusLabel.Text = "Статус: нет целей" end
			return
		end
	end

	local myRoot = Root(LocalPlayer)
	local tRoot  = Root(Target)
	local myHum  = Hum()

	-- Временно нет Character — ждём
	if not myRoot or not tRoot then return end

	-- PlatformStand чтобы физика меньше мешала
	if myHum and not myHum.PlatformStand then
		myHum.PlatformStand = true
	end

	-- Смотрим на цель (только горизонталь)
	local lookPos = Vector3.new(tRoot.Position.X, myRoot.Position.Y, tRoot.Position.Z)
	myRoot.CFrame = CFrame.lookAt(myRoot.Position, lookPos)

	-- Позиция ЗА СПИНОЙ
	local behindDir = -tRoot.CFrame.LookVector
	local jitter = math.sin(tick() * S.JitterSpeed) * S.JitterAmount
	local right = tRoot.CFrame.RightVector

	-- Высота: следуем за целью при прыжке, но не улетаем в небо
	local targetY = tRoot.Position.Y + S.BehindHeight
	local currentY = myRoot.Position.Y
	local maxUpSpeed = 40
	local desiredY = targetY

	if desiredY > currentY + 8 then
		desiredY = currentY + 8
	end

	local desired = Vector3.new(
		tRoot.Position.X + behindDir.X * S.BehindDistance + right.X * jitter,
		desiredY,
		tRoot.Position.Z + behindDir.Z * S.BehindDistance + right.Z * jitter
	)

	local delta = desired - myRoot.Position
	local dist = delta.Magnitude

	if dist > 0.4 then
		local speed = math.min(S.BehindSpeed, dist * 11)

		local vel = delta.Unit * speed

		if vel.Y > maxUpSpeed then
			vel = Vector3.new(vel.X, maxUpSpeed, vel.Z)
		elseif vel.Y < -60 then
			vel = Vector3.new(vel.X, -60, vel.Z)
		end

		myRoot.AssemblyLinearVelocity = vel
	else
		myRoot.AssemblyLinearVelocity = Vector3.new(0, math.clamp(desiredY - currentY, -15, 15), 0)
	end

	-- Атака
	local attackDist = (tRoot.Position - myRoot.Position).Magnitude
	if attackDist <= S.AttackRange then
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
Main.Size = UDim2.fromOffset(255, 370)
Main.Position = UDim2.new(0.5, -127, 0.5, -185)
Main.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = Gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke", Main)
stroke.Color = Color3.fromRGB(55, 70, 105)
stroke.Transparency = 0.4

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 32)
Header.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -70, 1, 0)
Title.Position = UDim2.fromOffset(9, 0)
Title.BackgroundTransparency = 1
Title.Text = "Задрочка типов"
Title.TextColor3 = Color3.fromRGB(245, 247, 250)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.fromOffset(24, 22)
MinBtn.Position = UDim2.new(1, -54, 0, 5)
MinBtn.BackgroundColor3 = Color3.fromRGB(42, 46, 60)
MinBtn.Text = "−"
MinBtn.TextColor3 = Color3.new(1, 1, 1)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 5)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(24, 22)
CloseBtn.Position = UDim2.new(1, -26, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(130, 42, 48)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)

local Tabs = Instance.new("Frame")
Tabs.Size = UDim2.new(1, -8, 0, 26)
Tabs.Position = UDim2.fromOffset(4, 36)
Tabs.BackgroundTransparency = 1
Tabs.Parent = Main

local tabLay = Instance.new("UIListLayout")
tabLay.FillDirection = Enum.FillDirection.Horizontal
tabLay.Padding = UDim.new(0, 4)
tabLay.Parent = Tabs

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -8, 1, -125)
Content.Position = UDim2.fromOffset(4, 66)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Bottom = Instance.new("Frame")
Bottom.Size = UDim2.new(1, -8, 0, 88)
Bottom.Position = UDim2.new(0, 4, 1, -92)
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
	b.Size = UDim2.new(1, 0, 0, h or 28)
	b.BackgroundColor3 = Color3.fromRGB(38, 42, 55)
	b.TextColor3 = Color3.fromRGB(235, 238, 245)
	b.Text = text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 11
	b.BorderSizePixel = 0
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Parent = parent
	corner(b, 6)
	return b
end

local function lbl(parent, text, h)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, h or 16)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = Color3.fromRGB(190, 200, 215)
	l.Font = Enum.Font.Gotham
	l.TextSize = 11
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function toggle(parent, text, val, cb)
	local b = btn(parent, text .. ": " .. (val and "ON" or "OFF"), 28)
	b.BackgroundColor3 = val and Color3.fromRGB(38, 120, 70) or Color3.fromRGB(38, 42, 55)
	b.MouseButton1Click:Connect(function()
		val = not val
		b.Text = text .. ": " .. (val and "ON" or "OFF")
		b.BackgroundColor3 = val and Color3.fromRGB(38, 120, 70) or Color3.fromRGB(38, 42, 55)
		cb(val)
	end)
	return b
end

local function slider(parent, text, key, minV, maxV, step)
	local hold = Instance.new("Frame")
	hold.Size = UDim2.new(1, 0, 0, 40)
	hold.BackgroundTransparency = 1
	hold.Parent = parent

	local name = lbl(hold, text, 14)
	name.Size = UDim2.new(1, -42, 0, 14)

	local valT = lbl(hold, tostring(S[key]), 14)
	valT.Size = UDim2.fromOffset(40, 14)
	valT.Position = UDim2.new(1, -40, 0, 0)
	valT.TextXAlignment = Enum.TextXAlignment.Right
	valT.TextColor3 = Color3.fromRGB(100, 165, 255)
	valT.Font = Enum.Font.GothamBold
	valT.TextSize = 11

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.Position = UDim2.fromOffset(0, 22)
	bar.BackgroundColor3 = Color3.fromRGB(42, 48, 62)
	bar.BorderSizePixel = 0
	bar.Active = true
	bar.Parent = hold
	corner(bar, 3)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(80, 140, 225)
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

-- Drag
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
	p.ScrollingDirection = Enum.ScrollingDirection.Y
	p.Visible = false
	p.Parent = Content

	local pad = Instance.new("UIPadding", p)
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 20)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)

	local lay = Instance.new("UIListLayout", p)
	lay.Padding = UDim.new(0, 5)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Pages[name] = p
	return p
end

local function newTab(name)
	local b = btn(Tabs, name, 26)
	b.Size = UDim2.new(0.5, -3, 0, 26)
	TabBtns[name] = b
	return b
end

local function show(name)
	for n, p in pairs(Pages) do p.Visible = (n == name) end
	for n, b in pairs(TabBtns) do
		b.BackgroundColor3 = (n == name) and Color3.fromRGB(48, 65, 105) or Color3.fromRGB(38, 42, 55)
	end
end

--------------------------------------------------
-- Вкладка Таргет (КИЛАУРА)
--------------------------------------------------
local pageT = newPage("Таргет")
newTab("Таргет")

local settingsBtn = btn(pageT, "▼  Настройки таргета", 28)
settingsBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
settingsBtn.Size = UDim2.new(0.9, 0, 0, 28)

local settingsFrame = Instance.new("Frame")
settingsFrame.Size = UDim2.new(1, 0, 0, 0)
settingsFrame.BackgroundTransparency = 1
settingsFrame.ClipsDescendants = true
settingsFrame.Visible = false
settingsFrame.Parent = pageT

local sLay = Instance.new("UIListLayout", settingsFrame)
sLay.Padding = UDim.new(0, 4)
sLay.HorizontalAlignment = Enum.HorizontalAlignment.Center

slider(settingsFrame, "Скорость за спиной", "BehindSpeed", 20, 160, 5)
slider(settingsFrame, "Дистанция за спиной", "BehindDistance", 1, 12, 0.5)
slider(settingsFrame, "Высота", "BehindHeight", -5, 15, 0.5)
slider(settingsFrame, "Сила дрожания", "JitterAmount", 0, 4, 0.1)
slider(settingsFrame, "Скорость дрожания", "JitterSpeed", 1, 20, 1)
slider(settingsFrame, "Дальность удара", "AttackRange", 2, 20, 0.5)
slider(settingsFrame, "Задержка атаки", "AttackCooldown", 0.2, 2.5, 0.05)
slider(settingsFrame, "Слот оружия", "WeaponSlot", 1, 10, 1)
toggle(settingsFrame, "Автооружие", S.AutoWeapon, function(v) S.AutoWeapon = v end)

settingsBtn.MouseButton1Click:Connect(function()
	settingsOpen = not settingsOpen
	settingsFrame.Visible = settingsOpen
	if settingsOpen then
		settingsBtn.Text = "▲  Настройки таргета"
		settingsFrame.Size = UDim2.new(1, 0, 0, 320)
	else
		settingsBtn.Text = "▼  Настройки таргета"
		settingsFrame.Size = UDim2.new(1, 0, 0, 0)
	end
end)

lbl(pageT, "Выбор цели", 15)

local Search = Instance.new("TextBox")
Search.Size = UDim2.new(0.9, 0, 0, 26)
Search.BackgroundColor3 = Color3.fromRGB(26, 30, 40)
Search.TextColor3 = Color3.new(1, 1, 1)
Search.PlaceholderColor3 = Color3.fromRGB(115, 125, 140)
Search.PlaceholderText = "Поиск..."
Search.Text = ""
Search.Font = Enum.Font.Gotham
Search.TextSize = 11
Search.TextXAlignment = Enum.TextXAlignment.Left
Search.BorderSizePixel = 0
Search.Parent = pageT
corner(Search, 5)
Instance.new("UIPadding", Search).PaddingLeft = UDim.new(0, 7)

local TargetInfo = lbl(pageT, "Цель: не выбрана", 15)
TargetInfo.TextColor3 = Color3.fromRGB(110, 175, 255)

local PlayerList = Instance.new("ScrollingFrame")
PlayerList.Size = UDim2.new(0.9, 0, 0, 85)
PlayerList.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
PlayerList.BorderSizePixel = 0
PlayerList.ScrollBarThickness = 3
PlayerList.CanvasSize = UDim2.new()
PlayerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
PlayerList.Parent = pageT
corner(PlayerList, 5)

local lp = Instance.new("UIPadding", PlayerList)
lp.PaddingTop = UDim.new(0, 3)
lp.PaddingBottom = UDim.new(0, 3)
lp.PaddingLeft = UDim.new(0, 3)
lp.PaddingRight = UDim.new(0, 3)
Instance.new("UIListLayout", PlayerList).Padding = UDim.new(0, 3)

local function updInfo()
	if Target and Target.Parent then
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
			local b = btn(PlayerList, (alive and "● " or "○ ") .. p.DisplayName, 26)
			b.Size = UDim2.new(0.95, 0, 0, 26)
			b.BackgroundColor3 = (p == Target) and Color3.fromRGB(48, 75, 120) or (alive and Color3.fromRGB(32, 38, 50) or Color3.fromRGB(42, 35, 38))
			b.TextColor3 = alive and Color3.fromRGB(235, 238, 245) or Color3.fromRGB(125, 130, 140)
			b.MouseButton1Click:Connect(function()
				Target = p
				updInfo()
				refreshList()
			end)
		end
	end
	updInfo()
end

Search:GetPropertyChangedSignal("Text"):Connect(refreshList)

btn(pageT, "Выбрать ближайшую", 28).MouseButton1Click:Connect(function()
	local n = Nearest()
	if n then Target = n refreshList() end
end)

--------------------------------------------------
-- Нижняя кнопка (ОДНА КНОПКА)
--------------------------------------------------
local toggleB = btn(Bottom, "▶  КИЛАУРА", 32)
toggleB.BackgroundColor3 = Color3.fromRGB(38, 120, 70)
toggleB.Position = UDim2.fromOffset(0, 0)

StatusLabel = lbl(Bottom, "Статус: остановлена", 15)
StatusLabel.Position = UDim2.fromOffset(0, 38)
StatusLabel.TextColor3 = Color3.fromRGB(145, 155, 170)

local function updateToggleBtn()
	if isActive then
		toggleB.BackgroundColor3 = Color3.fromRGB(120, 42, 48)
		toggleB.Text = "■  КИЛАУРА"
	else
		toggleB.BackgroundColor3 = Color3.fromRGB(38, 120, 70)
		toggleB.Text = "▶  КИЛАУРА"
	end
end

toggleB.MouseButton1Click:Connect(function()
	ToggleTarget()
	updateToggleBtn()
end)

--------------------------------------------------
-- Вкладка Доп.
--------------------------------------------------
local pageE = newPage("Доп.")
newTab("Доп.")

lbl(pageE, "Движение", 15)
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

lbl(pageE, "ESP", 15)
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
		TweenService:Create(Main, TweenInfo.new(0.13), {Size = UDim2.fromOffset(140, 32)}):Play()
		MinBtn.Text = "+"
	else
		TweenService:Create(Main, TweenInfo.new(0.13), {Size = UDim2.fromOffset(255, 370)}):Play()
		task.delay(0.11, function()
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
		task.wait(0.35)
		task.defer(refreshList)
		if S.ESP then
			if espData[p] then
				local d = espData[p]
				if d.hl then d.hl:Destroy() end
				if d.bb then d.bb:Destroy() end
				espData[p] = nil
			end
			CreateESP(p)
		end
	end)
	if S.ESP then CreateESP(p) end
end)

Players.PlayerRemoving:Connect(function(p)
	if p == Target then
		Target = nil
		StopTarget()
	end
	if espData[p] then
		local d = espData[p]
		if d.hl then d.hl:Destroy() end
		if d.bb then d.bb:Destroy() end
		espData[p] = nil
	end
	task.defer(refreshList)
end)

-- При своём телепорте/респавне
LocalPlayer.CharacterAdded:Connect(function()
	RemovePaused()
	task.delay(0.25, RemovePaused)
	task.delay(0.6, RemovePaused)

	RestoreNoclip()
	task.defer(refreshList)
	if S.ESP then task.defer(RefreshESP) end

	if StatusLabel and not isActive then
		StatusLabel.Text = "Статус: респавн"
	end
end)

RunService.Heartbeat:Connect(updInfo)

print("[Задрочка типов] v5.3 загружена")
