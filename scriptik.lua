--[[
    AI Target Mobile v4.2
    Таргет + Noclip + Speedhack + ESP (отдельные переключатели)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	warn("[Дрочка типов] Нужен клиентский контекст")
	return
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
if not PlayerGui then
	warn("[Дрочка типов] PlayerGui не найден")
	return
end

local old = PlayerGui:FindFirstChild("Дрочка типовGUI")
if old then old:Destroy() end

--------------------------------------------------
-- Настройки
--------------------------------------------------
local Settings = {
	FlySpeed = 60,
	CircleRadius = 8,
	CircleHeight = 4,
	CircleSpeed = 0.65,

	AttackRange = 6,
	AttackCooldown = 0.9,

	AutoWeapon = true,
	WeaponSlot = 2,

	Noclip = false,

	SpeedHack = false,
	SpeedValue = 50,

	-- ESP раздельно
	ESP_Enabled = false,
	ESP_Highlight = true,
	ESP_Name = true,
	ESP_Distance = true,
}

local Target = nil
local isActive = false
local connection = nil
local circleAngle = 0
local lastAttackTime = 0
local noclipOriginal = {}
local isMinimized = false
local espFolder = nil
local StatusLabel = nil
local espConnections = {}

--------------------------------------------------
-- Вспомогательные
--------------------------------------------------
local function Alive(player)
	if not player or player == LocalPlayer then return false end
	local char = player.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	return hum and hum.Health > 0 and root
end

local function Root(player)
	local char = player and player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function RestoreNoclip()
	for part, oldVal in pairs(noclipOriginal) do
		if part and part.Parent then
			part.CanCollide = oldVal
		end
	end
	table.clear(noclipOriginal)
end

local function ApplyNoclip()
	local char = LocalPlayer.Character
	if not char then return end
	if not Settings.Noclip then
		RestoreNoclip()
		return
	end
	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("BasePart") then
			if noclipOriginal[obj] == nil then
				noclipOriginal[obj] = obj.CanCollide
			end
			obj.CanCollide = false
		end
	end
end

local function EquipWeapon()
	if not Settings.AutoWeapon then return end
	local char = LocalPlayer.Character
	local hum = GetHumanoid()
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not char or not hum or not backpack then return end
	if char:FindFirstChildOfClass("Tool") then return end

	local tools = {}
	for _, item in ipairs(backpack:GetChildren()) do
		if item:IsA("Tool") then
			table.insert(tools, item)
		end
	end
	local slot = math.clamp(Settings.WeaponSlot or 2, 1, math.max(#tools, 1))
	local weapon = tools[slot]
	if weapon then
		pcall(function()
			hum:EquipTool(weapon)
		end)
	end
end

local function Attack()
	if not Target or not Alive(Target) then return end
	if tick() - lastAttackTime < Settings.AttackCooldown then return end

	EquipWeapon()
	local char = LocalPlayer.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if tool then
		local ok = pcall(function()
			tool:Activate()
		end)
		if ok then
			lastAttackTime = tick()
		end
	end
end

local function NearestTarget()
	local myRoot = Root(LocalPlayer)
	if not myRoot then return nil end
	local best, bestDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		if Alive(plr) then
			local r = Root(plr)
			local dist = (r.Position - myRoot.Position).Magnitude
			if dist < bestDist then
				best = plr
				bestDist = dist
			end
		end
	end
	return best
end

--------------------------------------------------
-- ESP (с отдельными переключателями)
--------------------------------------------------
local function ClearESP()
	if espFolder then
		espFolder:Destroy()
		espFolder = nil
	end
	for _, conn in pairs(espConnections) do
		if conn then conn:Disconnect() end
	end
	table.clear(espConnections)
end

local function CreateESP(player)
	if not Settings.ESP_Enabled or not Alive(player) then return end
	if not espFolder then
		espFolder = Instance.new("Folder")
		espFolder.Name = "AITargetESP"
		espFolder.Parent = PlayerGui
	end

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end

	-- Подсветка
	local highlight = nil
	if Settings.ESP_Highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = player.Name .. "_HL"
		highlight.Adornee = char
		highlight.FillColor = Color3.fromRGB(255, 60, 60)
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.FillTransparency = 0.55
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = espFolder
	end

	-- Имя + дистанция
	local billboard = nil
	local label = nil
	if Settings.ESP_Name or Settings.ESP_Distance then
		billboard = Instance.new("BillboardGui")
		billboard.Name = player.Name .. "_BB"
		billboard.Adornee = root
		billboard.Size = UDim2.fromOffset(140, 45)
		billboard.StudsOffset = Vector3.new(0, 3.2, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = espFolder

		label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.35
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.Text = ""
		label.Parent = billboard
	end

	-- Обновление текста
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not Settings.ESP_Enabled or not Alive(player) or not root.Parent then
			if highlight then highlight:Destroy() end
			if billboard then billboard:Destroy() end
			if conn then conn:Disconnect() end
			espConnections[player] = nil
			return
		end

		if label then
			local parts = {}
			if Settings.ESP_Name then
				table.insert(parts, player.DisplayName)
			end
			if Settings.ESP_Distance then
				local myRoot = Root(LocalPlayer)
				local dist = myRoot and math.floor((root.Position - myRoot.Position).Magnitude) or 0
				table.insert(parts, dist .. "m")
			end
			label.Text = table.concat(parts, "\n")
			label.Visible = #parts > 0
		end
	end)

	espConnections[player] = conn
end

local function RefreshESP()
	ClearESP()
	if not Settings.ESP_Enabled then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			CreateESP(plr)
		end
	end
end

--------------------------------------------------
-- Основной цикл таргета
--------------------------------------------------
local function MoveToTarget()
	if not isActive or not Target then return end
	if not Alive(Target) then
		isActive = false
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if StatusLabel then StatusLabel.Text = "Статус: цель потеряна" end
		return
	end

	local myRoot = Root(LocalPlayer)
	local tRoot = Root(Target)
	if not myRoot or not tRoot then return end

	if Settings.Noclip then
		ApplyNoclip()
	end

	circleAngle = circleAngle + Settings.CircleSpeed * 0.05
	if circleAngle > math.pi * 2 then
		circleAngle = circleAngle - math.pi * 2
	end

	local desired = tRoot.Position + Vector3.new(
		math.cos(circleAngle) * Settings.CircleRadius,
		Settings.CircleHeight,
		math.sin(circleAngle) * Settings.CircleRadius
	)

	local delta = desired - myRoot.Position
	local dist = delta.Magnitude

	if dist > 0.7 then
		local speed = math.min(Settings.FlySpeed, dist * 7)
		myRoot.AssemblyLinearVelocity = delta.Unit * speed
	else
		myRoot.AssemblyLinearVelocity = Vector3.zero
	end

	if (tRoot.Position - myRoot.Position).Magnitude <= Settings.AttackRange then
		Attack()
	end
end

local function StartTarget()
	if not Target or not Alive(Target) then
		if StatusLabel then StatusLabel.Text = "Статус: выбери живую цель" end
		return false
	end

	if connection then connection:Disconnect() end
	isActive = true
	circleAngle = 0
	if StatusLabel then
		StatusLabel.Text = "Статус: активен • " .. Target.DisplayName
	end
	connection = RunService.Heartbeat:Connect(MoveToTarget)
	return true
end

local function StopTarget()
	isActive = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
	local root = Root(LocalPlayer)
	if root then root.AssemblyLinearVelocity = Vector3.zero end
	RestoreNoclip()
	if StatusLabel then StatusLabel.Text = "Статус: остановлен" end
end

--------------------------------------------------
-- GUI
--------------------------------------------------
local Gui = Instance.new("ScreenGui")
Gui.Name = "Дрочка типовGUI"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(300, 460)
Main.Position = UDim2.new(0.5, -150, 0.5, -230)
Main.BackgroundColor3 = Color3.fromRGB(17, 19, 26)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = Gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(65, 80, 115)
stroke.Transparency = 0.35
stroke.Parent = Main

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(25, 27, 36)
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Position = UDim2.fromOffset(12, 0)
Title.BackgroundTransparency = 1
Title.Text = "◈ Дрочка типов"
Title.TextColor3 = Color3.fromRGB(245, 247, 250)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.fromOffset(30, 28)
MinimizeBtn.Position = UDim2.new(1, -68, 0, 6)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(48, 52, 68)
MinimizeBtn.Text = "−"
MinimizeBtn.TextColor3 = Color3.fromRGB(240, 243, 248)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 18
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Parent = Header
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 7)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(30, 28)
CloseBtn.Position = UDim2.new(1, -34, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(140, 48, 55)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 7)

-- Tabs
local Tabs = Instance.new("Frame")
Tabs.Size = UDim2.new(1, -14, 0, 34)
Tabs.Position = UDim2.fromOffset(7, 46)
Tabs.BackgroundTransparency = 1
Tabs.Parent = Main

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = Tabs

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -14, 1, -160)
Content.Position = UDim2.fromOffset(7, 86)
Content.BackgroundTransparency = 1
Content.Parent = Main

-- Нижняя панель
local BottomBar = Instance.new("Frame")
BottomBar.Size = UDim2.new(1, -14, 0, 110)
BottomBar.Position = UDim2.new(0, 7, 1, -118)
BottomBar.BackgroundTransparency = 1
BottomBar.Parent = Main

--------------------------------------------------
-- UI Helpers
--------------------------------------------------
local function Corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = obj
end

local function MakeButton(parent, text, height)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, height or 36)
	b.BackgroundColor3 = Color3.fromRGB(42, 46, 60)
	b.TextColor3 = Color3.fromRGB(235, 238, 245)
	b.Text = text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 14
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Parent = parent
	Corner(b, 8)
	return b
end

local function MakeLabel(parent, text, height)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, height or 22)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = Color3.fromRGB(200, 208, 220)
	l.Font = Enum.Font.Gotham
	l.TextSize = 13
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function MakeToggle(parent, text, value, callback)
	local b = MakeButton(parent, text .. ": " .. (value and "ON" or "OFF"), 34)
	b.BackgroundColor3 = value and Color3.fromRGB(45, 130, 80) or Color3.fromRGB(42, 46, 60)
	b.MouseButton1Click:Connect(function()
		value = not value
		b.Text = text .. ": " .. (value and "ON" or "OFF")
		b.BackgroundColor3 = value and Color3.fromRGB(45, 130, 80) or Color3.fromRGB(42, 46, 60)
		callback(value)
	end)
	return b
end

local function MakeSlider(parent, text, key, minV, maxV, step)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, 52)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local name = MakeLabel(holder, text, 18)
	name.Size = UDim2.new(1, -55, 0, 18)

	local valueText = MakeLabel(holder, tostring(Settings[key]), 18)
	valueText.Size = UDim2.fromOffset(50, 18)
	valueText.Position = UDim2.new(1, -50, 0, 0)
	valueText.TextXAlignment = Enum.TextXAlignment.Right
	valueText.TextColor3 = Color3.fromRGB(120, 180, 255)
	valueText.Font = Enum.Font.GothamBold

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 8)
	bar.Position = UDim2.fromOffset(0, 28)
	bar.BackgroundColor3 = Color3.fromRGB(48, 54, 68)
	bar.BorderSizePixel = 0
	bar.Active = true
	bar.Parent = holder
	Corner(bar, 5)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(90, 150, 235)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Corner(fill, 5)

	local dragging = false
	local function setFromX(x)
		local w = math.max(bar.AbsoluteSize.X, 1)
		local alpha = math.clamp((x - bar.AbsolutePosition.X) / w, 0, 1)
		local raw = minV + (maxV - minV) * alpha
		local value = math.floor(raw / step + 0.5) * step
		value = math.clamp(value, minV, maxV)
		Settings[key] = value
		fill.Size = UDim2.new((value - minV) / (maxV - minV), 0, 1, 0)
		valueText.Text = string.format("%g", value)

		-- Мгновенно применяем Speedhack если он включен
		if key == "SpeedValue" and Settings.SpeedHack then
			local hum = GetHumanoid()
			if hum then hum.WalkSpeed = value end
		end
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	task.defer(function()
		fill.Size = UDim2.new((Settings[key] - minV) / (maxV - minV), 0, 1, 0)
	end)
	return holder
end

-- Drag
-- =========================
-- Перетаскивание за любую часть GUI
-- =========================
do
	local dragging = false
	local dragStart = nil
	local startPos = nil

	local function beginDrag(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = Main.Position
		end
	end

	local function updateDrag(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			Main.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end

	local function endDrag(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end

	-- Тащим за всё окно
	Main.InputBegan:Connect(beginDrag)
	Header.InputBegan:Connect(beginDrag)

	UserInputService.InputChanged:Connect(updateDrag)
	UserInputService.InputEnded:Connect(endDrag)
end

--------------------------------------------------
-- Страницы
--------------------------------------------------
local Pages, TabButtons = {}, {}

local function NewPage(name)
	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = Content

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = page

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = page

	Pages[name] = page
	return page
end

local function NewTab(name)
	local b = MakeButton(Tabs, name, 34)
	b.Size = UDim2.new(0.5, -4, 0, 34)
	TabButtons[name] = b
	return b
end

local function ShowPage(name)
	for n, p in pairs(Pages) do p.Visible = (n == name) end
	for n, b in pairs(TabButtons) do
		b.BackgroundColor3 = (n == name) and Color3.fromRGB(55, 75, 115) or Color3.fromRGB(42, 46, 60)
	end
end

--------------------------------------------------
-- Главная
--------------------------------------------------
local MainPage = NewPage("Главная")
NewTab("Главная")

MakeLabel(MainPage, "Выбор цели", 20)

local Search = Instance.new("TextBox")
Search.Size = UDim2.new(1, 0, 0, 34)
Search.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
Search.TextColor3 = Color3.fromRGB(240, 243, 248)
Search.PlaceholderColor3 = Color3.fromRGB(130, 138, 152)
Search.PlaceholderText = "Поиск..."
Search.Text = ""
Search.ClearTextOnFocus = false
Search.Font = Enum.Font.Gotham
Search.TextSize = 13
Search.TextXAlignment = Enum.TextXAlignment.Left
Search.BorderSizePixel = 0
Search.Parent = MainPage
Corner(Search, 8)

local searchPad = Instance.new("UIPadding")
searchPad.PaddingLeft = UDim.new(0, 10)
searchPad.Parent = Search

local TargetInfo = MakeLabel(MainPage, "Цель: не выбрана", 20)
TargetInfo.TextColor3 = Color3.fromRGB(130, 190, 255)

local PlayerList = Instance.new("ScrollingFrame")
PlayerList.Size = UDim2.new(1, 0, 0, 155)
PlayerList.BackgroundColor3 = Color3.fromRGB(23, 27, 35)
PlayerList.BorderSizePixel = 0
PlayerList.ScrollBarThickness = 3
PlayerList.CanvasSize = UDim2.new()
PlayerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
PlayerList.Parent = MainPage
Corner(PlayerList, 8)

local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, 5)
listPad.PaddingBottom = UDim.new(0, 5)
listPad.PaddingLeft = UDim.new(0, 5)
listPad.PaddingRight = UDim.new(0, 5)
listPad.Parent = PlayerList

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.Name
listLayout.Parent = PlayerList

local function UpdateTargetInfo()
	if Target and Alive(Target) then
		local r = Root(Target)
		local my = Root(LocalPlayer)
		local dist = (r and my) and math.floor((r.Position - my.Position).Magnitude) or 0
		TargetInfo.Text = string.format("Цель: %s  •  %dm", Target.DisplayName, dist)
	else
		TargetInfo.Text = "Цель: не выбрана"
	end
end

local function RefreshPlayers()
	for _, c in ipairs(PlayerList:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	local query = string.lower(Search.Text or "")
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then table.insert(list, p) end
	end
	table.sort(list, function(a, b) return string.lower(a.DisplayName) < string.lower(b.DisplayName) end)

	for _, p in ipairs(list) do
		local d, u = string.lower(p.DisplayName), string.lower(p.Name)
		if query == "" or string.find(d, query, 1, true) or string.find(u, query, 1, true) then
			local alive = Alive(p)
			local btn = MakeButton(PlayerList, (alive and "● " or "○ ") .. p.DisplayName, 34)
			btn.BackgroundColor3 = (p == Target) and Color3.fromRGB(55, 85, 130) or (alive and Color3.fromRGB(36, 42, 55) or Color3.fromRGB(48, 40, 42))
			btn.TextColor3 = alive and Color3.fromRGB(235, 238, 245) or Color3.fromRGB(140, 145, 155)
			btn.MouseButton1Click:Connect(function()
				Target = Alive(p) and p or nil
				UpdateTargetInfo()
				RefreshPlayers()
			end)
		end
	end
	UpdateTargetInfo()
end

Search:GetPropertyChangedSignal("Text"):Connect(RefreshPlayers)
Players.PlayerAdded:Connect(function() task.defer(RefreshPlayers) end)
Players.PlayerRemoving:Connect(function(p)
	if p == Target then Target = nil StopTarget() end
	task.defer(RefreshPlayers)
	if Settings.ESP_Enabled then task.defer(RefreshESP) end
end)

MakeButton(MainPage, "Выбрать ближайшую", 36).MouseButton1Click:Connect(function()
	local n = NearestTarget()
	if n then Target = n RefreshPlayers() end
end)

--------------------------------------------------
-- Нижние кнопки
--------------------------------------------------
local startBtn = MakeButton(BottomBar, "▶  ЗАПУСТИТЬ", 40)
startBtn.BackgroundColor3 = Color3.fromRGB(45, 130, 80)
startBtn.Position = UDim2.fromOffset(0, 0)

local stopBtn = MakeButton(BottomBar, "■  ОСТАНОВИТЬ", 36)
stopBtn.BackgroundColor3 = Color3.fromRGB(130, 50, 55)
stopBtn.Position = UDim2.fromOffset(0, 46)

StatusLabel = MakeLabel(BottomBar, "Статус: остановлен", 20)
StatusLabel.Position = UDim2.fromOffset(0, 88)
StatusLabel.TextColor3 = Color3.fromRGB(160, 170, 185)

startBtn.MouseButton1Click:Connect(StartTarget)
stopBtn.MouseButton1Click:Connect(StopTarget)

--------------------------------------------------
-- Настройки
--------------------------------------------------
local SettingsPage = NewPage("Настройки")
NewTab("Настройки")

MakeLabel(SettingsPage, "Таргет", 22)
MakeSlider(SettingsPage, "Скорость полёта", "FlySpeed", 20, 150, 5)
MakeSlider(SettingsPage, "Радиус кружения", "CircleRadius", 2, 30, 1)
MakeSlider(SettingsPage, "Высота", "CircleHeight", -10, 25, 1)
MakeSlider(SettingsPage, "Скорость кружения", "CircleSpeed", 0.1, 3, 0.05)
MakeSlider(SettingsPage, "Радиус атаки", "AttackRange", 2, 20, 1)
MakeSlider(SettingsPage, "Задержка атаки", "AttackCooldown", 0.3, 3, 0.1)
MakeSlider(SettingsPage, "Слот оружия", "WeaponSlot", 1, 10, 1)
MakeToggle(SettingsPage, "Автооружие", Settings.AutoWeapon, function(v) Settings.AutoWeapon = v end)

MakeLabel(SettingsPage, "Движение", 22)
MakeToggle(SettingsPage, "Noclip", Settings.Noclip, function(v)
	Settings.Noclip = v
	if not v then RestoreNoclip() end
end)

MakeToggle(SettingsPage, "Speedhack", Settings.SpeedHack, function(v)
	Settings.SpeedHack = v
	local hum = GetHumanoid()
	if hum then
		hum.WalkSpeed = v and Settings.SpeedValue or 16
	end
end)
MakeSlider(SettingsPage, "Скорость Speedhack", "SpeedValue", 16, 150, 1)

MakeLabel(SettingsPage, "ESP", 22)
MakeToggle(SettingsPage, "ESP Вкл", Settings.ESP_Enabled, function(v)
	Settings.ESP_Enabled = v
	if v then RefreshESP() else ClearESP() end
end)
MakeToggle(SettingsPage, "Подсветка", Settings.ESP_Highlight, function(v)
	Settings.ESP_Highlight = v
	if Settings.ESP_Enabled then RefreshESP() end
end)
MakeToggle(SettingsPage, "Имя", Settings.ESP_Name, function(v)
	Settings.ESP_Name = v
	if Settings.ESP_Enabled then RefreshESP() end
end)
MakeToggle(SettingsPage, "Дистанция", Settings.ESP_Distance, function(v)
	Settings.ESP_Distance = v
	if Settings.ESP_Enabled then RefreshESP() end
end)

--------------------------------------------------
-- Сворачивание / закрытие
--------------------------------------------------
MinimizeBtn.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	if isMinimized then
		Tabs.Visible = false
		Content.Visible = false
		BottomBar.Visible = false
		TweenService:Create(Main, TweenInfo.new(0.15), {Size = UDim2.fromOffset(160, 40)}):Play()
		MinimizeBtn.Text = "+"
	else
		TweenService:Create(Main, TweenInfo.new(0.15), {Size = UDim2.fromOffset(300, 460)}):Play()
		task.delay(0.12, function()
			if not isMinimized then
				Tabs.Visible = true
				Content.Visible = true
				BottomBar.Visible = true
			end
		end)
		MinimizeBtn.Text = "−"
	end
end)

CloseBtn.MouseButton1Click:Connect(function()
	StopTarget()
	RestoreNoclip()
	ClearESP()
	local hum = GetHumanoid()
	if hum then hum.WalkSpeed = 16 end
	Gui:Destroy()
end)

--------------------------------------------------
-- Финал
--------------------------------------------------
for name, btn in pairs(TabButtons) do
	btn.MouseButton1Click:Connect(function() ShowPage(name) end)
end

ShowPage("Главная")
RefreshPlayers()

RunService.Heartbeat:Connect(function()
	UpdateTargetInfo()
	if Settings.SpeedHack then
		local hum = GetHumanoid()
		if hum and hum.WalkSpeed ~= Settings.SpeedValue then
			hum.WalkSpeed = Settings.SpeedValue
		end
	end
end)

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function()
		if Settings.ESP_Enabled then
			task.wait(0.6)
			CreateESP(plr)
		end
	end)
end)

LocalPlayer.CharacterAdded:Connect(function()
	StopTarget()
	Target = nil
	RestoreNoclip()
	task.defer(RefreshPlayers)
	if Settings.ESP_Enabled then task.defer(RefreshESP) end
	if StatusLabel then StatusLabel.Text = "Статус: респавн" end
end)

print("[Дрочка типов] v4.2 — ESP раздельный + Speedhack ползунок")
