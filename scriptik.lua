--[[
    Скрипт для "Создай ИИ" (Create AI)
    Версия: 5.2.1 - TARGET UI FIX
    Основан на предоставленном scriptik.lua.

    ВАЖНО:
    - Для обычного Roblox Studio запускай этот код как LocalScript.
    - Для GUI используется PlayerGui, когда он доступен.
    - Для загрузки с URL требуется среда, в которой разрешены HttpGet/loadstring.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("[AI Target] Этот скрипт должен выполняться в клиентском контексте (LocalScript).")
    return
end

-- Настройки
local Settings = {
    FlySpeed = 50,
    CircleRadius = 8,
    CircleHeight = 3,
    CircleSpeed = 0.5,
    AttackRange = 5,
    AttackCooldown = 1.5,
    AutoTarget = false,
    AutoWeapon = true,
    WeaponSlot = 2,
    Noclip = true,
    Fly = true,
}


-- Предварительные объявления функций
local SwitchTab
local CreateMainTabContent
local CreateCombatTabContent
local CreateMovementTabContent
local StartScript
local StopScript

-- Основные переменные
local Target = nil
local isActive = false
local connection = nil
local circleAngle = 0
local isMinimized = false
local currentTab = "Main"
local lastAttackTime = 0
local noclipParts = {}


local function Round(guiObject, radius)
    if not guiObject or not guiObject:IsA("GuiObject") then return end
    local old = guiObject:FindFirstChildOfClass("UICorner")
    if old then old:Destroy() end
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = guiObject
end

local function AddStroke(guiObject, transparency)
    if not guiObject or not guiObject:IsA("GuiObject") then return end
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(90, 105, 135)
    stroke.Thickness = 1
    stroke.Transparency = transparency or 0.55
    stroke.Parent = guiObject
end

local function MakeDraggable(handle, object)
    local dragging = false
    local dragStart
    local startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        dragging = true
        dragStart = input.Position
        startPos = object.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        object.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end)
end


local function CreateSlider(parent, text, settingName, minValue, maxValue, step)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -20, 0, 52)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 0, 20)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(220, 224, 232)
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = holder

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 55, 0, 20)
    valueLabel.Position = UDim2.new(1, -55, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3 = Color3.fromRGB(125, 190, 255)
    valueLabel.Text = tostring(Settings[settingName])
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 12
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = holder

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 6)
    bar.Position = UDim2.new(0, 0, 0, 32)
    bar.BackgroundColor3 = Color3.fromRGB(47, 54, 68)
    bar.BorderSizePixel = 0
    bar.Active = true
    bar.Parent = holder
    Round(bar, 6)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(90, 150, 235)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Round(fill, 6)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = Color3.fromRGB(240, 244, 250)
    knob.BorderSizePixel = 0
    knob.Active = true
    knob.Parent = bar
    Round(knob, 7)

    local dragging = false

    local function setValueFromX(x)
        local width = math.max(bar.AbsoluteSize.X, 1)
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
        local raw = minValue + (maxValue - minValue) * alpha
        local value = math.floor(raw / step + 0.5) * step
        value = math.clamp(value, minValue, maxValue)
        Settings[settingName] = value

        local normalized = (value - minValue) / (maxValue - minValue)
        fill.Size = UDim2.new(normalized, 0, 1, 0)
        knob.Position = UDim2.new(normalized, 0, 0.5, 0)
        valueLabel.Text = tostring(value)
    end

    local function begin(input)
        dragging = true
        setValueFromX(input.Position.X)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            begin(input)
        end
    end)

    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            begin(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            setValueFromX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    task.defer(function()
        local normalized = (Settings[settingName] - minValue) / (maxValue - minValue)
        fill.Size = UDim2.new(normalized, 0, 1, 0)
        knob.Position = UDim2.new(normalized, 0, 0.5, 0)
    end)

    return holder
end

-- Создаём GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AITargetGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Главное окно
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 410, 0, 560)
MainFrame.Position = UDim2.new(0.5, -205, 0.5, -280)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
MainFrame.BackgroundTransparency = 0.05
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = false
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
Round(MainFrame, 8)
AddStroke(MainFrame)

-- Заголовок
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
MakeDraggable(TitleBar, MainFrame)
Round(TitleBar, 8)
AddStroke(TitleBar)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Text = "🎯 AI Target  •  v5.2"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

-- Кнопка сворачивания
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Size = UDim2.new(0, 30, 0, 30)
MinimizeButton.Position = UDim2.new(1, -35, 0, 5)
MinimizeButton.BackgroundColor3 = Color3.fromRGB(35, 41, 54)
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.Text = "−"
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.TextSize = 20
MinimizeButton.BorderSizePixel = 0
MinimizeButton.Parent = TitleBar
    Round(MinimizeButton, 8)

-- Вкладки
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 35)
TabBar.Position = UDim2.new(0, 0, 0, 40)
TabBar.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame
    Round(TabBar, 8)

-- Контейнер для содержимого
local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, 0, 1, -75)
ContentContainer.Position = UDim2.new(0, 0, 0, 75)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainFrame

-- Функция создания вкладки
local function CreateTab(name, icon, xPos)
    local tabButton = Instance.new("TextButton")
    tabButton.Size = UDim2.new(0, 112, 1, 0)
    tabButton.Position = UDim2.new(0, xPos, 0, 0)
    tabButton.BackgroundColor3 = Color3.fromRGB(30, 35, 47)
    tabButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    tabButton.Text = icon .. " " .. name
    tabButton.Font = Enum.Font.Gotham
    tabButton.TextSize = 13
    tabButton.BorderSizePixel = 0
    tabButton.Parent = TabBar
    
    tabButton.MouseButton1Click:Connect(function()
        SwitchTab(name)
    end)
    
    return tabButton
end

-- Создаём вкладки
local MainTab = CreateTab("Главная", "🏠", 0)
local CombatTab = CreateTab("Бой", "⚔", 112)
local MovementTab = CreateTab("Movement", "🏃", 224)

-- Функция переключения вкладок
-- Функции скрипта

local function GetHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function GetCharacter(player)
    return player and player.Character or nil
end

local function GetTargetRoot(player)
    local character = GetCharacter(player)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function IsAlive(player)
    local character = GetCharacter(player)
    local humanoid = GetHumanoid(character)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return player ~= nil and humanoid ~= nil and humanoid.Health > 0 and root ~= nil
end

local function GetNearestTarget()
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil end

    local nearest = nil
    local nearestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            local root = GetTargetRoot(player)
            if root then
                local distance = (root.Position - localRoot.Position).Magnitude
                if distance < nearestDistance then
                    nearest = player
                    nearestDistance = distance
                end
            end
        end
    end

    return nearest
end

local function RestoreNoclip()
    for part, originalCanCollide in pairs(noclipParts) do
        if part and part.Parent then
            part.CanCollide = originalCanCollide
        end
    end
    table.clear(noclipParts)
end

local function ApplyNoclip()
    local character = LocalPlayer.Character
    if not character then return end

    if not Settings.Noclip then
        RestoreNoclip()
        return
    end

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if noclipParts[part] == nil then
                noclipParts[part] = part.CanCollide
            end
            part.CanCollide = false
        end
    end
end

local function EquipWeapon()
    if not Settings.AutoWeapon then return end

    local character = LocalPlayer.Character
    if not character then return end

    if character:FindFirstChildOfClass("Tool") then
        return
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local humanoid = GetHumanoid(character)
    if not backpack or not humanoid then return end

    local tool = backpack:FindFirstChildOfClass("Tool")
    if tool then
        humanoid:EquipTool(tool)
    end
end

local function Attack(targetCharacter)
    if not targetCharacter then return end

    local humanoid = GetHumanoid(targetCharacter)
    if not humanoid or humanoid.Health <= 0 then return end

    local now = os.clock()
    if now - lastAttackTime < Settings.AttackCooldown then
        return
    end

    EquipWeapon()

    local character = LocalPlayer.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    if not tool then return end

    local ok, err = pcall(function()
        tool:Activate()
    end)

    if ok then
        lastAttackTime = now
    else
        warn("[AI Target] Ошибка атаки:", err)
    end
end

local function GetBestTarget()
    if Settings.AutoTarget then
        return GetNearestTarget()
    end

    if Target and IsAlive(Target) then
        return Target
    end

    return nil
end

local function MoveToTarget()
    if not isActive then return end

    if Settings.AutoTarget then
        local nearest = GetNearestTarget()
        if nearest then Target = nearest end
    end

    if not Target or not IsAlive(Target) then
        StopScript()
        return
    end

    local character = LocalPlayer.Character
    local humanoid = GetHumanoid(character)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local targetRoot = GetTargetRoot(Target)
    if not humanoid or not root or not targetRoot then return end

    ApplyNoclip()

    if not Settings.Fly then
        root.AssemblyLinearVelocity = Vector3.zero
        return
    end

    circleAngle += math.rad(Settings.CircleSpeed)
    if circleAngle >= math.pi * 2 then circleAngle -= math.pi * 2 end

    local desired = targetRoot.Position + Vector3.new(
        math.cos(circleAngle) * Settings.CircleRadius,
        Settings.CircleHeight,
        math.sin(circleAngle) * Settings.CircleRadius
    )

    local offset = desired - root.Position
    local distance = offset.Magnitude

    -- Smooth client-side flight. Uses velocity rather than teleporting every frame.
    if distance > 0.35 then
        local desiredVelocity = offset.Unit * math.clamp(distance * 6, 0, Settings.FlySpeed)
        root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(desiredVelocity, 0.35)
    else
        root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(Vector3.zero, 0.35)
    end

    local targetDistance = (targetRoot.Position-root.Position).Magnitude
    if targetDistance <= Settings.AttackRange then
        Attack(Target.Character)
    end
end

StartScript = function()
    local selected = GetBestTarget()

    if not selected then
        if _G.StatusLabel then
            _G.StatusLabel.Text = "Статус: выбери живую цель"
        end
        return false
    end

    Target = selected

    if connection then
        connection:Disconnect()
        connection = nil
    end

    isActive = true

    if _G.StatusLabel then
        _G.StatusLabel.Text = "Статус: Активен — " .. Target.DisplayName
    end

    connection = RunService.Heartbeat:Connect(MoveToTarget)
    return true
end

StopScript = function()
    isActive = false

    if connection then
        connection:Disconnect()
        connection = nil
    end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
    end

    RestoreNoclip()

    if _G.StatusLabel then
        _G.StatusLabel.Text = "Статус: Остановлен"
    end
end

-- Noclip работает отдельно от target/fly loop.
local noclipConnection = RunService.Stepped:Connect(function()
    if Settings.Noclip then
        ApplyNoclip()
    end
end)


SwitchTab = function(tabName)
    currentTab = tabName
    
    -- Обновляем цвета кнопок
    for _, child in ipairs(TabBar:GetChildren()) do
        if child:IsA("TextButton") then
            if child.Text:find(tabName) then
                child.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
                child.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                child.BackgroundColor3 = Color3.fromRGB(30, 35, 47)
                child.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end
    
    -- Очищаем контейнер
    for _, child in ipairs(ContentContainer:GetChildren()) do
        child:Destroy()
    end
    
    -- Создаём содержимое
    if tabName == "Главная" then
        CreateMainTabContent()
    elseif tabName == "Бой" then
        CreateCombatTabContent()
    elseif tabName == "Movement" then
        CreateMovementTabContent()
    end
end

-- Функция создания главной вкладки
CreateMainTabContent = function()
    local y = 8

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 26)
    title.Position = UDim2.new(0, 10, 0, y)
    title.BackgroundTransparency = 1
    title.Text = "🎯 Цели"
    title.TextColor3 = Color3.fromRGB(245, 247, 250)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = ContentContainer
    y += 30

    local search = Instance.new("TextBox")
    search.Size = UDim2.new(1, -20, 0, 32)
    search.Position = UDim2.new(0, 10, 0, y)
    search.BackgroundColor3 = Color3.fromRGB(30, 36, 48)
    search.TextColor3 = Color3.fromRGB(240, 243, 248)
    search.PlaceholderColor3 = Color3.fromRGB(125, 132, 145)
    search.PlaceholderText = "Поиск игрока..."
    search.Text = ""
    search.ClearTextOnFocus = false
    search.Font = Enum.Font.Gotham
    search.TextSize = 12
    search.TextXAlignment = Enum.TextXAlignment.Left
    search.BorderSizePixel = 0
    search.Parent = ContentContainer
    Round(search, 8)
    AddStroke(search, 0.7)

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, -20, 0, 225)
    list.Position = UDim2.new(0, 10, 0, y + 40)
    list.BackgroundColor3 = Color3.fromRGB(21, 26, 35)
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 4
    list.CanvasSize = UDim2.new()
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.Parent = ContentContainer
    Round(list, 8)
    AddStroke(list, 0.8)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.Name
    layout.Parent = list

    local empty = Instance.new("TextLabel")
    empty.Size = UDim2.new(1, 0, 0, 30)
    empty.BackgroundTransparency = 1
    empty.TextColor3 = Color3.fromRGB(135, 142, 155)
    empty.Text = "Игроки не найдены"
    empty.Font = Enum.Font.Gotham
    empty.TextSize = 12
    empty.Visible = false
    empty.Parent = list

    local function updateList()
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end

        local query = search.Text:lower()
        local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local found = 0

        local players = Players:GetPlayers()
        table.sort(players, function(a,b)
            return a.DisplayName:lower() < b.DisplayName:lower()
        end)

        for _, player in ipairs(players) do
            if player ~= LocalPlayer then
                local haystack = (player.DisplayName .. " " .. player.Name):lower()
                if query == "" or haystack:find(query, 1, true) then
                    local alive = IsAlive(player)
                    local root = GetTargetRoot(player)
                    local distance = root and localRoot and math.floor((root.Position-localRoot.Position).Magnitude) or nil

                    local row = Instance.new("TextButton")
                    row.Name = player.Name
                    row.Size = UDim2.new(1, -8, 0, 38)
                    row.BackgroundColor3 = (Target == player)
                        and Color3.fromRGB(52, 83, 125)
                        or Color3.fromRGB(31, 38, 50)
                    row.TextColor3 = alive and Color3.fromRGB(235, 239, 246) or Color3.fromRGB(135, 140, 150)
                    row.Text = (alive and "●  " or "○  ") .. player.DisplayName
                        .. "  @" .. player.Name
                        .. (distance and ("   " .. distance .. "m") or "")
                    row.Font = Enum.Font.Gotham
                    row.TextSize = 11
                    row.TextXAlignment = Enum.TextXAlignment.Left
                    row.BorderSizePixel = 0
                    row.AutoButtonColor = true
                    row.Parent = list
                    Round(row, 7)

                    row.MouseButton1Click:Connect(function()
                        if not IsAlive(player) then
                            if _G.StatusLabel then _G.StatusLabel.Text = "Статус: игрок недоступен" end
                            return
                        end
                        Target = player
                        if _G.TargetLabel then _G.TargetLabel.Text = "Цель: " .. player.DisplayName end
                        if _G.StatusLabel then _G.StatusLabel.Text = "Статус: цель выбрана" end
                        updateList()
                    end)
                    found += 1
                end
            end
        end

        empty.Visible = found == 0
        if found == 0 then empty.LayoutOrder = 999999 end
    end

    search:GetPropertyChangedSignal("Text"):Connect(updateList)

    Players.PlayerAdded:Connect(function()
        task.defer(updateList)
    end)
    Players.PlayerRemoving:Connect(function(player)
        if Target == player then
            Target = nil
            if _G.TargetLabel then _G.TargetLabel.Text = "Цель: не выбрана" end
        end
        task.defer(updateList)
    end)

    local targetLabel = Instance.new("TextLabel")
    targetLabel.Size = UDim2.new(1, -20, 0, 24)
    targetLabel.Position = UDim2.new(0, 10, 0, y + 270)
    targetLabel.BackgroundTransparency = 1
    targetLabel.TextColor3 = Color3.fromRGB(145, 194, 255)
    targetLabel.Text = "Цель: не выбрана"
    targetLabel.Font = Enum.Font.GothamBold
    targetLabel.TextSize = 12
    targetLabel.TextXAlignment = Enum.TextXAlignment.Left
    targetLabel.Parent = ContentContainer
    _G.TargetLabel = targetLabel

    local nearest = Instance.new("TextButton")
    nearest.Size = UDim2.new(0.5, -15, 0, 34)
    nearest.Position = UDim2.new(0, 10, 0, y + 300)
    nearest.BackgroundColor3 = Color3.fromRGB(47, 62, 82)
    nearest.TextColor3 = Color3.fromRGB(240, 243, 248)
    nearest.Text = "◎ Ближайшая"
    nearest.Font = Enum.Font.GothamBold
    nearest.TextSize = 11
    nearest.BorderSizePixel = 0
    nearest.Parent = ContentContainer
    Round(nearest, 8)

    nearest.MouseButton1Click:Connect(function()
        local p = GetNearestTarget()
        if p then
            Target = p
            targetLabel.Text = "Цель: " .. p.DisplayName
            if _G.StatusLabel then _G.StatusLabel.Text = "Статус: ближайшая цель выбрана" end
            updateList()
        end
    end)

    local auto = Instance.new("TextButton")
    auto.Size = UDim2.new(0.5, -15, 0, 34)
    auto.Position = UDim2.new(0.5, 5, 0, y + 300)
    auto.BackgroundColor3 = Settings.AutoTarget and Color3.fromRGB(48,125,82) or Color3.fromRGB(45,51,64)
    auto.TextColor3 = Color3.fromRGB(240,243,248)
    auto.Text = "Авто-цель: " .. (Settings.AutoTarget and "ON" or "OFF")
    auto.Font = Enum.Font.GothamBold
    auto.TextSize = 11
    auto.BorderSizePixel = 0
    auto.Parent = ContentContainer
    Round(auto, 8)

    auto.MouseButton1Click:Connect(function()
        Settings.AutoTarget = not Settings.AutoTarget
        auto.Text = "Авто-цель: " .. (Settings.AutoTarget and "ON" or "OFF")
        auto.BackgroundColor3 = Settings.AutoTarget and Color3.fromRGB(48,125,82) or Color3.fromRGB(45,51,64)
    end)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -20, 0, 24)
    status.Position = UDim2.new(0, 10, 0, y + 342)
    status.BackgroundTransparency = 1
    status.TextColor3 = Color3.fromRGB(175, 181, 192)
    status.Text = "Статус: ожидание"
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = ContentContainer

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(1, -20, 0, 42)
    toggle.Position = UDim2.new(0, 10, 0, y + 370)
    toggle.BackgroundColor3 = Color3.fromRGB(55, 145, 90)
    toggle.TextColor3 = Color3.fromRGB(255,255,255)
    toggle.Text = "▶  ЗАПУСТИТЬ"
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 14
    toggle.BorderSizePixel = 0
    toggle.Parent = ContentContainer
    Round(toggle, 9)

    toggle.MouseButton1Click:Connect(function()
        if isActive then
            StopScript()
            toggle.Text = "▶  ЗАПУСТИТЬ"
            toggle.BackgroundColor3 = Color3.fromRGB(55,145,90)
        elseif StartScript() then
            toggle.Text = "■  ОСТАНОВИТЬ"
            toggle.BackgroundColor3 = Color3.fromRGB(155,65,65)
        end
    end)

    _G.StatusLabel = status
    _G.ToggleButton = toggle

    updateList()
end

-- Функция создания вкладки боя

CreateCombatTabContent = function()
    local y = 8

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,-20,0,28)
    title.Position = UDim2.new(0,10,0,y)
    title.BackgroundTransparency = 1
    title.Text = "⚔  Бой"
    title.TextColor3 = Color3.fromRGB(245,247,250)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = ContentContainer
    y += 38

    local sliderDefs = {
        {"Радиус атаки", "AttackRange", 1, 30, 1},
        {"Задержка атаки", "AttackCooldown", 0.1, 5, 0.1},
    }

    for _, d in ipairs(sliderDefs) do
        local h = CreateSlider(ContentContainer, d[1], d[2], d[3], d[4], d[5])
        h.Position = UDim2.new(0,10,0,y)
        y += 62
    end

    local weapon = Instance.new("TextButton")
    weapon.Size = UDim2.new(1,-20,0,36)
    weapon.Position = UDim2.new(0,10,0,y)
    weapon.BackgroundColor3 = Settings.AutoWeapon and Color3.fromRGB(48,125,82) or Color3.fromRGB(45,51,64)
    weapon.TextColor3 = Color3.fromRGB(245,247,250)
    weapon.Text = "Автовыбор оружия: " .. (Settings.AutoWeapon and "ON" or "OFF")
    weapon.Font = Enum.Font.GothamBold
    weapon.TextSize = 11
    weapon.BorderSizePixel = 0
    weapon.Parent = ContentContainer
    Round(weapon,8)

    weapon.MouseButton1Click:Connect(function()
        Settings.AutoWeapon = not Settings.AutoWeapon
        weapon.Text = "Автовыбор оружия: " .. (Settings.AutoWeapon and "ON" or "OFF")
        weapon.BackgroundColor3 = Settings.AutoWeapon and Color3.fromRGB(48,125,82) or Color3.fromRGB(45,51,64)
    end)
end

CreateMovementTabContent = function()
    local y = 8

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,-20,0,28)
    title.Position = UDim2.new(0,10,0,y)
    title.BackgroundTransparency = 1
    title.Text = "🏃  Движение"
    title.TextColor3 = Color3.fromRGB(245,247,250)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = ContentContainer
    y += 38

    local defs = {
        {"Скорость полёта", "FlySpeed", 10, 150, 1},
        {"Радиус окружения", "CircleRadius", 2, 40, 1},
        {"Высота", "CircleHeight", -10, 30, 1},
        {"Скорость окружения", "CircleSpeed", 0.05, 3, 0.05},
    }

    for _, d in ipairs(defs) do
        local h = CreateSlider(ContentContainer, d[1], d[2], d[3], d[4], d[5])
        h.Position = UDim2.new(0,10,0,y)
        y += 62
    end

    local function addToggle(text, name)
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(1,-20,0,36)
        b.Position=UDim2.new(0,10,0,y)
        b.BackgroundColor3=Settings[name] and Color3.fromRGB(48,125,82) or Color3.fromRGB(45,51,64)
        b.TextColor3=Color3.fromRGB(245,247,250)
        b.Text=text .. ": " .. (Settings[name] and "ON" or "OFF")
        b.Font=Enum.Font.GothamBold
        b.TextSize=11
        b.BorderSizePixel=0
        b.Parent=ContentContainer
        Round(b,8)
        b.MouseButton1Click:Connect(function()
            Settings[name]=not Settings[name]
            b.Text=text .. ": " .. (Settings[name] and "ON" or "OFF")
            b.BackgroundColor3=Settings[name] and Color3.fromRGB(48,125,82) or Color3.fromRGB(45,51,64)
            if name=="Noclip" and not Settings.Noclip then RestoreNoclip() end
        end)
        y += 44
    end

    addToggle("Fly", "Fly")
    addToggle("Noclip", "Noclip")
end

-- Подключаем кнопку сворачивания
MinimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    MinimizeButton.Text = isMinimized and "+" or "−"

    if isMinimized then
        TabBar.Visible = false
        ContentContainer.Visible = false
        TweenService:Create(
            MainFrame,
            TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 175, 0, 38)}
        ):Play()
    else
        TweenService:Create(
            MainFrame,
            TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 410, 0, 560)}
        ):Play()
        task.delay(0.1, function()
            if not isMinimized then
                TabBar.Visible = true
                ContentContainer.Visible = true
            end
        end)
    end
end)

-- Очистка состояния при респавне
if LocalPlayer then
    LocalPlayer.CharacterAdded:Connect(function()
        if isActive then
            StopScript()
        end
        Target = nil
        circleAngle = 0
    end)
end

-- Показываем главную вкладку
SwitchTab("Главная")

-- Добавляем GUI на экран
local PlayerGui = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui")
if not PlayerGui then
    warn("[AI Target] PlayerGui не найден. Запусти скрипт в клиентском контексте.")
    return
end

ScreenGui.Parent = PlayerGui

print("✅ AI Target • v5.2.1 загружен!")
print("💡 Выбери игрока из списка и нажми 'Запустить'")
