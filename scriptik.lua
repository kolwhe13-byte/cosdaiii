-- AI Target v6.0
-- Надёжная клиентская версия.
-- Запускать как LocalScript / в клиентском контексте.
-- Если используешь внешний загрузчик, он должен поддерживать loadstring + HttpGet.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("[AI Target] LocalPlayer отсутствует. Нужен клиентский контекст.")
    return
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
if not PlayerGui then
    warn("[AI Target] PlayerGui не найден.")
    return
end

-- Удаляем старую копию, если скрипт запущен повторно.
local oldGui = PlayerGui:FindFirstChild("AITargetGUI")
if oldGui then
    oldGui:Destroy()
end

local Settings = {
    Fly = false,
    Noclip = false,
    AutoTarget = false,

    FlySpeed = 50,
    CircleRadius = 8,
    CircleHeight = 3,
    CircleSpeed = 0.5,

    AttackRange = 5,
    AttackCooldown = 1.0,
    AutoWeapon = true,
}

local Target = nil
local Active = false
local Angle = 0
local LastAttack = 0
local NoclipOriginal = {}

local function Alive(player)
    if not player or player == LocalPlayer then
        return false
    end

    local character = player.Character
    if not character then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    return humanoid ~= nil and humanoid.Health > 0 and root ~= nil
end

local function Root(player)
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function RestoreNoclip()
    for part, oldValue in pairs(NoclipOriginal) do
        if part and part.Parent then
            part.CanCollide = oldValue
        end
    end
    table.clear(NoclipOriginal)
end

local function ApplyNoclip()
    local character = LocalPlayer.Character
    if not character then
        return
    end

    if not Settings.Noclip then
        RestoreNoclip()
        return
    end

    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("BasePart") then
            if NoclipOriginal[object] == nil then
                NoclipOriginal[object] = object.CanCollide
            end
            object.CanCollide = false
        end
    end
end

local function NearestTarget()
    local myRoot = Root(LocalPlayer)
    if not myRoot then
        return nil
    end

    local best = nil
    local bestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if Alive(player) then
            local root = Root(player)
            local distance = (root.Position - myRoot.Position).Magnitude

            if distance < bestDistance then
                best = player
                bestDistance = distance
            end
        end
    end

    return best
end

local function EquipTool()
    if not Settings.AutoWeapon then
        return
    end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

    if not character or not humanoid or not backpack then
        return
    end

    if character:FindFirstChildOfClass("Tool") then
        return
    end

    local tool = backpack:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function()
            humanoid:EquipTool(tool)
        end)
    end
end

local function Attack()
    if not Target or not Alive(Target) then
        return
    end

    if os.clock() - LastAttack < Settings.AttackCooldown then
        return
    end

    EquipTool()

    local character = LocalPlayer.Character
    local tool = character and character:FindFirstChildOfClass("Tool")

    if tool then
        local ok = pcall(function()
            tool:Activate()
        end)

        if ok then
            LastAttack = os.clock()
        end
    end
end

-- =========================
-- GUI
-- =========================

local Gui = Instance.new("ScreenGui")
Gui.Name = "AITargetGUI"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(430, 520)
Main.Position = UDim2.new(0.5, -215, 0.5, -260)
Main.BackgroundColor3 = Color3.fromRGB(17, 20, 27)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = Gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = Main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(75, 90, 120)
stroke.Transparency = 0.35
stroke.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = Color3.fromRGB(25, 29, 39)
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = Main

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Position = UDim2.fromOffset(14, 0)
Title.BackgroundTransparency = 1
Title.Text = "◈  AI Target"
Title.TextColor3 = Color3.fromRGB(245, 247, 250)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Minimize = Instance.new("TextButton")
Minimize.Size = UDim2.fromOffset(34, 30)
Minimize.Position = UDim2.new(1, -42, 0, 7)
Minimize.BackgroundColor3 = Color3.fromRGB(43, 49, 63)
Minimize.Text = "−"
Minimize.TextColor3 = Color3.fromRGB(240, 243, 248)
Minimize.Font = Enum.Font.GothamBold
Minimize.TextSize = 18
Minimize.BorderSizePixel = 0
Minimize.Parent = Header

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 8)
minCorner.Parent = Minimize

local Tabs = Instance.new("Frame")
Tabs.Size = UDim2.new(1, -20, 0, 36)
Tabs.Position = UDim2.fromOffset(10, 52)
Tabs.BackgroundTransparency = 1
Tabs.Parent = Main

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = Tabs

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -20, 1, -100)
Content.Position = UDim2.fromOffset(10, 96)
Content.BackgroundTransparency = 1
Content.Parent = Main

local function Corner(object, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = object
end

local function Button(parent, text, height)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, height or 34)
    b.BackgroundColor3 = Color3.fromRGB(39, 45, 58)
    b.TextColor3 = Color3.fromRGB(235, 238, 245)
    b.Text = text
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.BorderSizePixel = 0
    b.AutoButtonColor = true
    b.Parent = parent
    Corner(b, 8)
    return b
end

local function Label(parent, text, height)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, height or 24)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(205, 211, 222)
    l.Font = Enum.Font.Gotham
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function Toggle(parent, text, value, callback)
    local b = Button(parent, text .. ": " .. (value and "ON" or "OFF"), 34)
    b.BackgroundColor3 = value and Color3.fromRGB(47, 120, 82) or Color3.fromRGB(39, 45, 58)

    b.MouseButton1Click:Connect(function()
        value = not value
        b.Text = text .. ": " .. (value and "ON" or "OFF")
        b.BackgroundColor3 = value and Color3.fromRGB(47, 120, 82) or Color3.fromRGB(39, 45, 58)
        callback(value)
    end)

    return b
end

local function Slider(parent, text, key, minValue, maxValue, step)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 58)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local name = Label(holder, text, 22)
    name.Size = UDim2.new(1, -70, 0, 22)

    local valueText = Label(holder, tostring(Settings[key]), 22)
    valueText.Size = UDim2.fromOffset(65, 22)
    valueText.Position = UDim2.new(1, -65, 0, 0)
    valueText.TextXAlignment = Enum.TextXAlignment.Right
    valueText.TextColor3 = Color3.fromRGB(120, 180, 255)
    valueText.Font = Enum.Font.GothamBold

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 7)
    bar.Position = UDim2.fromOffset(0, 34)
    bar.BackgroundColor3 = Color3.fromRGB(48, 55, 70)
    bar.BorderSizePixel = 0
    bar.Active = true
    bar.Parent = holder
    Corner(bar, 6)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(91, 151, 235)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Corner(fill, 6)

    local dragging = false

    local function setFromX(x)
        local width = math.max(bar.AbsoluteSize.X, 1)
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
        local raw = minValue + (maxValue - minValue) * alpha
        local value = math.floor(raw / step + 0.5) * step
        value = math.clamp(value, minValue, maxValue)

        Settings[key] = value
        local normalized = (value - minValue) / (maxValue - minValue)
        fill.Size = UDim2.new(normalized, 0, 1, 0)
        valueText.Text = string.format("%g", value)
    end

    local function begin(input)
        dragging = true
        setFromX(input.Position.X)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            begin(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            setFromX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    task.defer(function()
        local normalized = (Settings[key] - minValue) / (maxValue - minValue)
        fill.Size = UDim2.new(normalized, 0, 1, 0)
    end)

    return holder
end

-- Drag
do
    local dragging = false
    local dragStart
    local startPosition

    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = Main.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local Pages = {}
local TabButtons = {}
local CurrentPage = nil

local function NewPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.CanvasSize = UDim2.new()
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = Content

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 2)
    padding.PaddingRight = UDim.new(0, 2)
    padding.Parent = page

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 7)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    Pages[name] = page
    return page
end

local function NewTab(name)
    local b = Button(Tabs, name, 36)
    b.Size = UDim2.fromOffset(132, 36)
    TabButtons[name] = b
    return b
end

local function ShowPage(name)
    for pageName, page in pairs(Pages) do
        page.Visible = pageName == name
    end

    for tabName, button in pairs(TabButtons) do
        button.BackgroundColor3 = tabName == name
            and Color3.fromRGB(62, 83, 115)
            or Color3.fromRGB(39, 45, 58)
    end

    CurrentPage = name
end

-- =========================
-- Main / Targets
-- =========================

local MainPage = NewPage("Главная")
NewTab("Главная")

Label(MainPage, "Цели", 24)

local Search = Instance.new("TextBox")
Search.Size = UDim2.new(1, 0, 0, 34)
Search.BackgroundColor3 = Color3.fromRGB(32, 38, 50)
Search.TextColor3 = Color3.fromRGB(240, 243, 248)
Search.PlaceholderColor3 = Color3.fromRGB(130, 138, 152)
Search.PlaceholderText = "Поиск игрока..."
Search.Text = ""
Search.ClearTextOnFocus = false
Search.Font = Enum.Font.Gotham
Search.TextSize = 12
Search.TextXAlignment = Enum.TextXAlignment.Left
Search.BorderSizePixel = 0
Search.Parent = MainPage
Corner(Search, 8)

local searchPadding = Instance.new("UIPadding")
searchPadding.PaddingLeft = UDim.new(0, 10)
searchPadding.Parent = Search

local TargetInfo = Label(MainPage, "Цель: не выбрана", 24)
TargetInfo.TextColor3 = Color3.fromRGB(130, 190, 255)

local PlayerList = Instance.new("ScrollingFrame")
PlayerList.Size = UDim2.new(1, 0, 0, 235)
PlayerList.BackgroundColor3 = Color3.fromRGB(23, 28, 38)
PlayerList.BorderSizePixel = 0
PlayerList.ScrollBarThickness = 4
PlayerList.CanvasSize = UDim2.new()
PlayerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
PlayerList.Parent = MainPage
Corner(PlayerList, 8)

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 6)
listPadding.PaddingBottom = UDim.new(0, 6)
listPadding.PaddingLeft = UDim.new(0, 6)
listPadding.PaddingRight = UDim.new(0, 6)
listPadding.Parent = PlayerList

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.Name
listLayout.Parent = PlayerList

local function UpdateTargetInfo()
    if Target and Alive(Target) then
        local root = Root(Target)
        local myRoot = Root(LocalPlayer)
        local distance = 0

        if root and myRoot then
            distance = math.floor((root.Position - myRoot.Position).Magnitude)
        end

        TargetInfo.Text = string.format(
            "Цель: %s  •  %dm",
            Target.DisplayName,
            distance
        )
    else
        TargetInfo.Text = "Цель: не выбрана"
    end
end

local function RefreshPlayers()
    for _, child in ipairs(PlayerList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local query = string.lower(Search.Text or "")

    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(players, player)
        end
    end

    table.sort(players, function(a, b)
        return string.lower(a.DisplayName) < string.lower(b.DisplayName)
    end)

    for _, player in ipairs(players) do
        local display = string.lower(player.DisplayName)
        local username = string.lower(player.Name)

        if query == "" or string.find(display, query, 1, true) or string.find(username, query, 1, true) then
            local alive = Alive(player)
            local button = Button(
                PlayerList,
                (alive and "● " or "○ ") .. player.DisplayName .. "  @" .. player.Name,
                34
            )

            button.BackgroundColor3 = player == Target
                and Color3.fromRGB(61, 88, 125)
                or (alive and Color3.fromRGB(36, 43, 56) or Color3.fromRGB(45, 40, 43))

            button.TextColor3 = alive
                and Color3.fromRGB(238, 241, 246)
                or Color3.fromRGB(145, 149, 158)

            button.MouseButton1Click:Connect(function()
                if not Alive(player) then
                    Target = nil
                    UpdateTargetInfo()
                    RefreshPlayers()
                    return
                end

                Target = player
                Settings.AutoTarget = false
                UpdateTargetInfo()
                RefreshPlayers()
            end)
        end
    end

    UpdateTargetInfo()
end

Search:GetPropertyChangedSignal("Text"):Connect(RefreshPlayers)

Players.PlayerAdded:Connect(function()
    task.defer(RefreshPlayers)
end)

Players.PlayerRemoving:Connect(function(player)
    if player == Target then
        Target = nil
        Active = false
    end
    task.defer(RefreshPlayers)
end)

local nearestButton = Button(MainPage, "Выбрать ближайшую", 34)
nearestButton.MouseButton1Click:Connect(function()
    local nearest = NearestTarget()
    if nearest then
        Target = nearest
        Settings.AutoTarget = false
        RefreshPlayers()
    end
end)

local autoTargetButton
autoTargetButton = Toggle(MainPage, "Автоцель", Settings.AutoTarget, function(value)
    Settings.AutoTarget = value
    if value then
        Target = NearestTarget()
        RefreshPlayers()
    end
end)

local startButton = Button(MainPage, "▶  ЗАПУСТИТЬ", 40)
startButton.BackgroundColor3 = Color3.fromRGB(47, 120, 82)

local stopButton = Button(MainPage, "■  ОСТАНОВИТЬ", 34)
stopButton.BackgroundColor3 = Color3.fromRGB(105, 51, 57)

local Status = Label(MainPage, "Статус: остановлен", 24)
Status.TextColor3 = Color3.fromRGB(155, 165, 180)

-- =========================
-- Combat
-- =========================

local CombatPage = NewPage("Бой")
NewTab("Бой")

Label(CombatPage, "Настройки боя", 26)
Slider(CombatPage, "Радиус атаки", "AttackRange", 1, 30, 1)
Slider(CombatPage, "Задержка атаки", "AttackCooldown", 0.1, 5, 0.1)
Toggle(CombatPage, "Автовыбор оружия", Settings.AutoWeapon, function(value)
    Settings.AutoWeapon = value
end)

-- =========================
-- Movement
-- =========================

local MovementPage = NewPage("Movement")
NewTab("Movement")

Label(MovementPage, "Движение", 26)
Toggle(MovementPage, "Fly", Settings.Fly, function(value)
    Settings.Fly = value
    if not value then
        local root = Root(LocalPlayer)
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
end)

Toggle(MovementPage, "Noclip", Settings.Noclip, function(value)
    Settings.Noclip = value
    if not value then
        RestoreNoclip()
    end
end)

Slider(MovementPage, "Скорость Fly", "FlySpeed", 5, 150, 5)
Slider(MovementPage, "Радиус кружения", "CircleRadius", 1, 40, 1)
Slider(MovementPage, "Высота кружения", "CircleHeight", -20, 30, 1)
Slider(MovementPage, "Скорость кружения", "CircleSpeed", 0.05, 5, 0.05)

-- =========================
-- Actions
-- =========================

startButton.MouseButton1Click:Connect(function()
    if Settings.AutoTarget then
        Target = NearestTarget()
    end

    if not Target or not Alive(Target) then
        Status.Text = "Статус: выбери живую цель"
        return
    end

    Active = true
    Angle = 0
    Status.Text = "Статус: активен • " .. Target.DisplayName
end)

stopButton.MouseButton1Click:Connect(function()
    Active = false
    local root = Root(LocalPlayer)
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
    end
    Status.Text = "Статус: остановлен"
end)

-- =========================
-- Runtime
-- =========================

RunService.Stepped:Connect(function()
    if Settings.Noclip then
        ApplyNoclip()
    end
end)

RunService.Heartbeat:Connect(function(dt)
    UpdateTargetInfo()

    if not Active then
        return
    end

    if Settings.AutoTarget then
        local nearest = NearestTarget()
        if nearest then
            Target = nearest
        end
    end

    if not Target or not Alive(Target) then
        Active = false
        Status.Text = "Статус: цель потеряна"
        return
    end

    local myRoot = Root(LocalPlayer)
    local targetRoot = Root(Target)

    if not myRoot or not targetRoot then
        return
    end

    if not Settings.Fly then
        myRoot.AssemblyLinearVelocity = Vector3.zero
        return
    end

    Angle += dt * Settings.CircleSpeed

    local desired = targetRoot.Position + Vector3.new(
        math.cos(Angle) * Settings.CircleRadius,
        Settings.CircleHeight,
        math.sin(Angle) * Settings.CircleRadius
    )

    local delta = desired - myRoot.Position
    local distance = delta.Magnitude

    if distance > 0.5 then
        local speed = math.min(Settings.FlySpeed, distance * 6)
        myRoot.AssemblyLinearVelocity = delta.Unit * speed
    else
        myRoot.AssemblyLinearVelocity = Vector3.zero
    end

    if (targetRoot.Position - myRoot.Position).Magnitude <= Settings.AttackRange then
        Attack()
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    Active = false
    Target = nil
    RestoreNoclip()
    task.defer(RefreshPlayers)
    Status.Text = "Статус: респавн"
end)

-- =========================
-- Minimize
-- =========================

local minimized = false

Minimize.MouseButton1Click:Connect(function()
    minimized = not minimized

    if minimized then
        Tabs.Visible = false
        Content.Visible = false

        TweenService:Create(
            Main,
            TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.fromOffset(180, 44)}
        ):Play()

        Minimize.Text = "+"
    else
        TweenService:Create(
            Main,
            TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.fromOffset(430, 520)}
        ):Play()

        task.delay(0.12, function()
            if not minimized then
                Tabs.Visible = true
                Content.Visible = true
            end
        end)

        Minimize.Text = "−"
    end
end)

for name, button in pairs(TabButtons) do
    button.MouseButton1Click:Connect(function()
        ShowPage(name)
    end)
end

ShowPage("Главная")
RefreshPlayers()

print("[AI Target] v6.0 loaded successfully")
