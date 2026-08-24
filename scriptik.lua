-- AI Target v6.4 Mobile + Free Fly + Auto Fly on Target
-- Fly работает и отдельно, и автоматически включается при запуске таргета

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	warn("[AI Target] LocalPlayer отсутствует")
	return
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
if not PlayerGui then
	warn("[AI Target] PlayerGui не найден")
	return
end

local oldGui = PlayerGui:FindFirstChild("AITargetGUI")
if oldGui then
	oldGui:Destroy()
end

local Settings = {
	Fly = false,
	Noclip = false,
	AutoTarget = false,

	FlySpeed = 60,

	AttackRange = 6,
	AttackCooldown = 0.85,
	AutoWeapon = true,
}

local Target = nil
local Active = false
local LastAttack = 0
local NoclipOriginal = {}
local OriginalPlatformStand = false

-- Ссылка на кнопку Fly, чтобы обновлять её при авто-включении
local FlyButton = nil

--------------------------------------------------
-- Вспомогательные функции
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
	for part, old in pairs(NoclipOriginal) do
		if part and part.Parent then
			part.CanCollide = old
		end
	end
	table.clear(NoclipOriginal)
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
			if NoclipOriginal[obj] == nil then
				NoclipOriginal[obj] = obj.CanCollide
			end
			obj.CanCollide = false
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

local function EquipTool()
	if not Settings.AutoWeapon then return end
	local char = LocalPlayer.Character
	local hum = GetHumanoid()
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not char or not hum or not backpack then return end
	if char:FindFirstChildOfClass("Tool") then return end

	local tool = backpack:FindFirstChildOfClass("Tool")
	if tool then
		pcall(function()
			hum:EquipTool(tool)
		end)
	end
end

local function Attack()
	if not Target or not Alive(Target) then return end
	if os.clock() - LastAttack < Settings.AttackCooldown then return end

	EquipTool()

	local char = LocalPlayer.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if tool then
		local ok = pcall(function()
			tool:Activate()
		end)
		if ok then
			LastAttack = os.clock()
		end
	end
end

--------------------------------------------------
-- Свободный Fly
--------------------------------------------------

local function UpdateFlyButton()
	if not FlyButton then return end
	FlyButton.Text = "Fly: " .. (Settings.Fly and "ON" or "OFF")
	FlyButton.BackgroundColor3 = Settings.Fly and Color3.fromRGB(45, 125, 80) or Color3.fromRGB(40, 45, 58)
end

local function SetFly(state)
	Settings.Fly = state
	local hum = GetHumanoid()
	local root = Root(LocalPlayer)

	if state then
		if hum then
			OriginalPlatformStand = hum.PlatformStand
			hum.PlatformStand = true
		end
	else
		if hum then
			hum.PlatformStand = OriginalPlatformStand
		end
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end

	UpdateFlyButton()
end

local function GetFlyDirection()
	local cam = workspace.CurrentCamera
	if not cam then return Vector3.zero end

	local direction = Vector3.zero
	local camCF = cam.CFrame

	-- Клавиатура
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		direction += camCF.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		direction -= camCF.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		direction -= camCF.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		direction += camCF.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		direction += Vector3.yAxis
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then
		direction -= Vector3.yAxis
	end

	-- Мобилка / геймпад
	local hum = GetHumanoid()
	if hum and hum.MoveDirection.Magnitude > 0.05 then
		direction = hum.MoveDirection
	end

	return direction
end

--------------------------------------------------
-- GUI
--------------------------------------------------

local Gui = Instance.new("ScreenGui")
Gui.Name = "AITargetGUI"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(300, 400)
Main.Position = UDim2.new(0.5, -150, 0.5, -200)
Main.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = Gui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 85, 115)
stroke.Transparency = 0.4
stroke.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -70, 1, 0)
Title.Position = UDim2.fromOffset(12, 0)
Title.BackgroundTransparency = 1
Title.Text = "◈ AI Target"
Title.TextColor3 = Color3.fromRGB(245, 247, 250)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Minimize = Instance.new("TextButton")
Minimize.Size = UDim2.fromOffset(32, 28)
Minimize.Position = UDim2.new(1, -38, 0, 6)
Minimize.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
Minimize.Text = "−"
Minimize.TextColor3 = Color3.fromRGB(240, 243, 248)
Minimize.Font = Enum.Font.GothamBold
Minimize.TextSize = 18
Minimize.BorderSizePixel = 0
Minimize.Parent = Header
Instance.new("UICorner", Minimize).CornerRadius = UDim.new(0, 7)

local Tabs = Instance.new("Frame")
Tabs.Size = UDim2.new(1, -14, 0, 32)
Tabs.Position = UDim2.fromOffset(7, 46)
Tabs.BackgroundTransparency = 1
Tabs.Parent = Main

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 5)
tabLayout.Parent = Tabs

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -14, 1, -90)
Content.Position = UDim2.fromOffset(7, 84)
Content.BackgroundTransparency = 1
Content.Parent = Main

--------------------------------------------------
-- UI Helpers
--------------------------------------------------

local function Corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = obj
end

local function Button(parent, text, height)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, height or 34)
	b.BackgroundColor3 = Color3.fromRGB(40, 45, 58)
	b.TextColor3 = Color3.fromRGB(235, 238, 245)
	b.Text = text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 13
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Parent = parent
	Corner(b, 8)
	return b
end

local function Label(parent, text, height)
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

local function Toggle(parent, text, value, callback)
	local b = Button(parent, text .. ": " .. (value and "ON" or "OFF"), 34)
	b.BackgroundColor3 = value and Color3.fromRGB(45, 125, 80) or Color3.fromRGB(40, 45, 58)

	b.MouseButton1Click:Connect(function()
		value = not value
		b.Text = text .. ": " .. (value and "ON" or "OFF")
		b.BackgroundColor3 = value and Color3.fromRGB(45, 125, 80) or Color3.fromRGB(40, 45, 58)
		callback(value)
	end)
	return b
end

local function Slider(parent, text, key, minV, maxV, step)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, 52)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local name = Label(holder, text, 20)
	name.Size = UDim2.new(1, -60, 0, 20)

	local valueText = Label(holder, tostring(Settings[key]), 20)
	valueText.Size = UDim2.fromOffset(55, 20)
	valueText.Position = UDim2.new(1, -55, 0, 0)
	valueText.TextXAlignment = Enum.TextXAlignment.Right
	valueText.TextColor3 = Color3.fromRGB(120, 180, 255)
	valueText.Font = Enum.Font.GothamBold
	valueText.TextSize = 13

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 8)
	bar.Position = UDim2.fromOffset(0, 30)
	bar.BackgroundColor3 = Color3.fromRGB(48, 54, 68)
	bar.BorderSizePixel = 0
	bar.Active = true
	bar.Parent = holder
	Corner(bar, 6)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(90, 150, 235)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Corner(fill, 6)

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
do
	local dragging, dragStart, startPos = false, nil, nil

	Header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = Main.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			Main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
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
	local b = Button(Tabs, name, 32)
	b.Size = UDim2.new(0.333, -4, 0, 32)
	TabButtons[name] = b
	return b
end

local function ShowPage(name)
	for n, p in pairs(Pages) do
		p.Visible = (n == name)
	end
	for n, b in pairs(TabButtons) do
		b.BackgroundColor3 = (n == name) and Color3.fromRGB(60, 80, 115) or Color3.fromRGB(40, 45, 58)
	end
end

--------------------------------------------------
-- Главная
--------------------------------------------------

local MainPage = NewPage("Главная")
NewTab("Главная")

Label(MainPage, "Цели", 22)

local Search = Instance.new("TextBox")
Search.Size = UDim2.new(1, 0, 0, 34)
Search.BackgroundColor3 = Color3.fromRGB(30, 35, 46)
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

local TargetInfo = Label(MainPage, "Цель: не выбрана", 22)
TargetInfo.TextColor3 = Color3.fromRGB(130, 190, 255)

local PlayerList = Instance.new("ScrollingFrame")
PlayerList.Size = UDim2.new(1, 0, 0, 140)
PlayerList.BackgroundColor3 = Color3.fromRGB(22, 26, 34)
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
listLayout.Padding = UDim.new(0, 4)
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
	table.sort(list, function(a, b)
		return string.lower(a.DisplayName) < string.lower(b.DisplayName)
	end)

	for _, p in ipairs(list) do
		local d, u = string.lower(p.DisplayName), string.lower(p.Name)
		if query == "" or string.find(d, query, 1, true) or string.find(u, query, 1, true) then
			local alive = Alive(p)
			local btn = Button(PlayerList, (alive and "● " or "○ ") .. p.DisplayName, 32)
			btn.BackgroundColor3 = (p == Target) and Color3.fromRGB(58, 85, 125)
				or (alive and Color3.fromRGB(35, 42, 55) or Color3.fromRGB(48, 42, 45))
			btn.TextColor3 = alive and Color3.fromRGB(235, 238, 245) or Color3.fromRGB(140, 145, 155)

			btn.MouseButton1Click:Connect(function()
				if not Alive(p) then
					Target = nil
				else
					Target = p
					Settings.AutoTarget = false
				end
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
	if p == Target then Target = nil Active = false end
	task.defer(RefreshPlayers)
end)

Button(MainPage, "Выбрать ближайшую", 34).MouseButton1Click:Connect(function()
	local n = NearestTarget()
	if n then
		Target = n
		Settings.AutoTarget = false
		RefreshPlayers()
	end
end)

Toggle(MainPage, "Автоцель", Settings.AutoTarget, function(v)
	Settings.AutoTarget = v
	if v then
		Target = NearestTarget()
		RefreshPlayers()
	end
end)

local startBtn = Button(MainPage, "▶  ЗАПУСТИТЬ", 38)
startBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 80)

local stopBtn = Button(MainPage, "■  ОСТАНОВИТЬ", 34)
stopBtn.BackgroundColor3 = Color3.fromRGB(110, 50, 55)

local Status = Label(MainPage, "Статус: остановлен", 22)
Status.TextColor3 = Color3.fromRGB(150, 160, 175)

--------------------------------------------------
-- Бой
--------------------------------------------------

local CombatPage = NewPage("Бой")
NewTab("Бой")

Label(CombatPage, "Настройки боя", 24)
Slider(CombatPage, "Радиус атаки", "AttackRange", 2, 25, 1)
Slider(CombatPage, "Задержка атаки", "AttackCooldown", 0.2, 3, 0.05)
Toggle(CombatPage, "Автовыбор оружия", Settings.AutoWeapon, function(v)
	Settings.AutoWeapon = v
end)

--------------------------------------------------
-- Movement
--------------------------------------------------

local MovementPage = NewPage("Movement")
NewTab("Movement")

Label(MovementPage, "Движение", 24)

-- Fly кнопка (сохраняем ссылку)
FlyButton = Toggle(MovementPage, "Fly", Settings.Fly, function(v)
	SetFly(v)
end)

Toggle(MovementPage, "Noclip", Settings.Noclip, function(v)
	Settings.Noclip = v
	if not v then RestoreNoclip() end
end)

Slider(MovementPage, "Скорость Fly", "FlySpeed", 15, 150, 5)

--------------------------------------------------
-- Кнопки управления
--------------------------------------------------

startBtn.MouseButton1Click:Connect(function()
	if Settings.AutoTarget then
		Target = NearestTarget()
	end
	if not Target or not Alive(Target) then
		Status.Text = "Статус: выбери живую цель"
		return
	end

	Active = true
	SetFly(true) -- автоматически включаем полёт
	Status.Text = "Статус: активен • " .. Target.DisplayName
end)

stopBtn.MouseButton1Click:Connect(function()
	Active = false
	-- Fly НЕ выключаем — можешь продолжать летать
	Status.Text = "Статус: остановлен"
end)

--------------------------------------------------
-- Runtime
--------------------------------------------------

RunService.Stepped:Connect(function()
	if Settings.Noclip then
		ApplyNoclip()
	end
end)

RunService.Heartbeat:Connect(function()
	UpdateTargetInfo()

	-- Свободный полёт (работает всегда, когда Fly = true)
	if Settings.Fly then
		local root = Root(LocalPlayer)
		if root then
			local dir = GetFlyDirection()
			if dir.Magnitude > 0.05 then
				root.AssemblyLinearVelocity = dir.Unit * Settings.FlySpeed
			else
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end

	-- Таргет (только атака)
	if not Active then return end

	if Settings.AutoTarget then
		local n = NearestTarget()
		if n then Target = n end
	end

	if not Target or not Alive(Target) then
		Active = false
		Status.Text = "Статус: цель потеряна"
		return
	end

	local myRoot = Root(LocalPlayer)
	local tRoot = Root(Target)
	if not myRoot or not tRoot then return end

	if (tRoot.Position - myRoot.Position).Magnitude <= Settings.AttackRange then
		Attack()
	end
end)

LocalPlayer.CharacterAdded:Connect(function()
	Active = false
	Target = nil
	RestoreNoclip()
	SetFly(false)
	task.defer(RefreshPlayers)
	Status.Text = "Статус: респавн"
end)

--------------------------------------------------
-- Minimize
--------------------------------------------------

local minimized = false

Minimize.MouseButton1Click:Connect(function()
	minimized = not minimized
	if minimized then
		Tabs.Visible = false
		Content.Visible = false
		TweenService:Create(Main, TweenInfo.new(0.15), {Size = UDim2.fromOffset(150, 40)}):Play()
		Minimize.Text = "+"
	else
		TweenService:Create(Main, TweenInfo.new(0.15), {Size = UDim2.fromOffset(300, 400)}):Play()
		task.delay(0.12, function()
			if not minimized then
				Tabs.Visible = true
				Content.Visible = true
			end
		end)
		Minimize.Text = "−"
	end
end)

for name, btn in pairs(TabButtons) do
	btn.MouseButton1Click:Connect(function()
		ShowPage(name)
	end)
end

ShowPage("Главная")
RefreshPlayers()

print("[AI Target] v6.4 loaded — Auto Fly on Target")
