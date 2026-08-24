--[[
    Скрипт для "Создай ИИ" (Create AI)
    Версия: 3.2 - ИСПРАВЛЕННАЯ
    Основан на предоставленном scriptik.lua.

    ВАЖНО:
    - Для обычного Roblox Studio запускай этот код как LocalScript.
    - Для GUI используется PlayerGui, когда он доступен.
    - Для загрузки с URL требуется среда, в которой разрешены HttpGet/loadstring.
]]
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
    RetreatDistance = 15,
    RetreatSpeed = 80,
    Noclip = true,
    Fly = true,
    AntiAim = {
        Enabled = false,
        Type = "Jitter",
        Speed = 10,
        Range = 30
    }
}

-- Anti-Aim переменные
local AntiAim = {
    jitterAngle = 0,
    spinAngle = 0,
    lastUpdate = 0,
    randomLastUpdate = 0,
    isRetreating = false,
    retreatTimer = 0
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

-- Создаём GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AITargetGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Главное окно
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 450, 0, 550)
MainFrame.Position = UDim2.new(0.5, -225, 0.5, -275)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
MainFrame.BackgroundTransparency = 0.05
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

-- Заголовок
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Text = "🎯 AI Target System v3.1"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

-- Кнопка сворачивания
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Size = UDim2.new(0, 30, 0, 30)
MinimizeButton.Position = UDim2.new(1, -35, 0, 5)
MinimizeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.Text = "−"
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.TextSize = 20
MinimizeButton.BorderSizePixel = 0
MinimizeButton.Parent = TitleBar

-- Вкладки
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 35)
TabBar.Position = UDim2.new(0, 0, 0, 40)
TabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame

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
    tabButton.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
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
SwitchTab = function(tabName)
    currentTab = tabName
    
    -- Обновляем цвета кнопок
    for _, child in ipairs(TabBar:GetChildren()) do
        if child:IsA("TextButton") then
            if child.Text:find(tabName) then
                child.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
                child.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                child.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
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
    local yOffset = 10
    
    -- Выбор игрока
    local PlayerLabel = Instance.new("TextLabel")
    PlayerLabel.Size = UDim2.new(1, -20, 0, 25)
    PlayerLabel.Position = UDim2.new(0, 10, 0, yOffset)
    PlayerLabel.BackgroundTransparency = 1
    PlayerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    PlayerLabel.Text = "👤 Выбор цели:"
    PlayerLabel.Font = Enum.Font.Gotham
    PlayerLabel.TextSize = 14
    PlayerLabel.TextXAlignment = Enum.TextXAlignment.Left
    PlayerLabel.Parent = ContentContainer
    
    yOffset = yOffset + 30
    
    -- Дропдаун
    local DropdownFrame = Instance.new("Frame")
    DropdownFrame.Size = UDim2.new(1, -20, 0, 30)
    DropdownFrame.Position = UDim2.new(0, 10, 0, yOffset)
    DropdownFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    DropdownFrame.BorderSizePixel = 0
    DropdownFrame.Parent = ContentContainer
    
    local DropdownButton = Instance.new("TextButton")
    DropdownButton.Size = UDim2.new(1, 0, 1, 0)
    DropdownButton.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    DropdownButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    DropdownButton.Text = "Выбери игрока..."
    DropdownButton.Font = Enum.Font.Gotham
    DropdownButton.TextSize = 14
    DropdownButton.Parent = DropdownFrame
    
    local DropdownList = Instance.new("ScrollingFrame")
    DropdownList.Size = UDim2.new(1, 0, 0, 120)
    DropdownList.Position = UDim2.new(0, 0, 1, 0)
    DropdownList.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    DropdownList.BorderSizePixel = 0
    DropdownList.Visible = false
    DropdownList.CanvasSize = UDim2.new(0, 0, 0, 0)
    DropdownList.ScrollBarThickness = 5
    DropdownList.Parent = DropdownFrame
    
    -- Кнопка обновления
    local RefreshButton = Instance.new("TextButton")
    RefreshButton.Size = UDim2.new(0, 30, 0, 30)
    RefreshButton.Position = UDim2.new(1, -35, 0, 0)
    RefreshButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    RefreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    RefreshButton.Text = "🔄"
    RefreshButton.Font = Enum.Font.Gotham
    RefreshButton.TextSize = 16
    RefreshButton.BorderSizePixel = 0
    RefreshButton.Parent = DropdownFrame
    
    -- Функция обновления списка
    local function UpdatePlayerList()
        for _, child in ipairs(DropdownList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        local players = game:GetService("Players"):GetPlayers()
        local yOffset = 0
        
        for _, player in ipairs(players) do
            if player ~= game:GetService("Players").LocalPlayer then
                local playerButton = Instance.new("TextButton")
                playerButton.Size = UDim2.new(1, 0, 0, 25)
                playerButton.Position = UDim2.new(0, 0, 0, yOffset)
                playerButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
                playerButton.TextColor3 = Color3.fromRGB(200, 200, 200)
                playerButton.Text = player.Name
                playerButton.Font = Enum.Font.Gotham
                playerButton.TextSize = 13
                playerButton.Parent = DropdownList
                
                playerButton.MouseButton1Click:Connect(function()
                    Target = player
                    DropdownButton.Text = "Цель: " .. player.Name
                    DropdownList.Visible = false
                    if _G.StatusLabel then
                        _G.StatusLabel.Text = "Статус: Цель выбрана - " .. player.Name
                    end
                end)
                
                yOffset = yOffset + 25
            end
        end
        
        DropdownList.CanvasSize = UDim2.new(0, 0, 0, yOffset)
    end
    
    DropdownButton.MouseButton1Click:Connect(function()
        DropdownList.Visible = not DropdownList.Visible
        if DropdownList.Visible then
            UpdatePlayerList()
        end
    end)
    
    RefreshButton.MouseButton1Click:Connect(UpdatePlayerList)
    
    yOffset = yOffset + 40
    
    -- Статус
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, -20, 0, 25)
    StatusLabel.Position = UDim2.new(0, 10, 0, yOffset)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    StatusLabel.Text = "Статус: Ожидание"
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextSize = 13
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = ContentContainer
    
    yOffset = yOffset + 35
    
    -- Кнопка старт/стоп
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(1, -20, 0, 45)
    ToggleButton.Position = UDim2.new(0, 10, 0, yOffset)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.Text = "▶ Запустить"
    ToggleButton.Font = Enum.Font.GothamBold
    ToggleButton.TextSize = 18
    ToggleButton.BorderSizePixel = 0
    ToggleButton.Parent = ContentContainer
    
    ToggleButton.MouseButton1Click:Connect(function()
        if isActive then
            StopScript()
            ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
            ToggleButton.Text = "▶ Запустить"
        else
            if StartScript() then
                ToggleButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
                ToggleButton.Text = "⏹ Стоп"
            end
        end
    end)
    
    -- Сохраняем ссылки для других функций
    _G.StatusLabel = StatusLabel
    _G.ToggleButton = ToggleButton
end

-- Функция создания вкладки боя
CreateCombatTabContent = function()
    local yOffset = 10
    
    -- Заголовок
    local TargetSettingsLabel = Instance.new("TextLabel")
    TargetSettingsLabel.Size = UDim2.new(1, -20, 0, 25)
    TargetSettingsLabel.Position = UDim2.new(0, 10, 0, yOffset)
    TargetSettingsLabel.BackgroundTransparency = 1
    TargetSettingsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TargetSettingsLabel.Text = "⚙️ Настройки таргета"
    TargetSettingsLabel.Font = Enum.Font.GothamBold
    TargetSettingsLabel.TextSize = 16
    TargetSettingsLabel.TextXAlignment = Enum.TextXAlignment.Left
    TargetSettingsLabel.Parent = ContentContainer
    
    yOffset = yOffset + 30
    
    -- Скорость полёта
    local SpeedLabel = Instance.new("TextLabel")
    SpeedLabel.Size = UDim2.new(1, -20, 0, 20)
    SpeedLabel.Position = UDim2.new(0, 10, 0, yOffset)
    SpeedLabel.BackgroundTransparency = 1
    SpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    SpeedLabel.Text = "Скорость полёта: " .. Settings.FlySpeed
    SpeedLabel.Font = Enum.Font.Gotham
    SpeedLabel.TextSize = 12
    SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
    SpeedLabel.Parent = ContentContainer
    
    local SpeedInput = Instance.new("TextBox")
    SpeedInput.Size = UDim2.new(1, -20, 0, 20)
    SpeedInput.Position = UDim2.new(0, 10, 0, yOffset + 20)
    SpeedInput.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    SpeedInput.Text = tostring(Settings.FlySpeed)
    SpeedInput.Font = Enum.Font.Gotham
    SpeedInput.TextSize = 12
    SpeedInput.BorderSizePixel = 0
    SpeedInput.Parent = ContentContainer
    
    SpeedInput.FocusLost:Connect(function()
        local value = tonumber(SpeedInput.Text)
        if value and value > 0 then
            Settings.FlySpeed = value
            SpeedLabel.Text = "Скорость полёта: " .. value
        end
    end)
    
    yOffset = yOffset + 50
    
    -- Радиус кружения
    local RadiusLabel = Instance.new("TextLabel")
    RadiusLabel.Size = UDim2.new(1, -20, 0, 20)
    RadiusLabel.Position = UDim2.new(0, 10, 0, yOffset)
    RadiusLabel.BackgroundTransparency = 1
    RadiusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    RadiusLabel.Text = "Радиус кружения: " .. Settings.CircleRadius
    RadiusLabel.Font = Enum.Font.Gotham
    RadiusLabel.TextSize = 12
    RadiusLabel.TextXAlignment = Enum.TextXAlignment.Left
    RadiusLabel.Parent = ContentContainer
    
    local RadiusInput = Instance.new("TextBox")
    RadiusInput.Size = UDim2.new(1, -20, 0, 20)
    RadiusInput.Position = UDim2.new(0, 10, 0, yOffset + 20)
    RadiusInput.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    RadiusInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    RadiusInput.Text = tostring(Settings.CircleRadius)
    RadiusInput.Font = Enum.Font.Gotham
    RadiusInput.TextSize = 12
    RadiusInput.BorderSizePixel = 0
    RadiusInput.Parent = ContentContainer
    
    RadiusInput.FocusLost:Connect(function()
        local value = tonumber(RadiusInput.Text)
        if value and value > 0 then
            Settings.CircleRadius = value
            RadiusLabel.Text = "Радиус кружения: " .. value
        end
    end)
    
    yOffset = yOffset + 50
    
    -- Дистанция отлёта
    local RetreatLabel = Instance.new("TextLabel")
    RetreatLabel.Size = UDim2.new(1, -20, 0, 20)
    RetreatLabel.Position = UDim2.new(0, 10, 0, yOffset)
    RetreatLabel.BackgroundTransparency = 1
    RetreatLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    RetreatLabel.Text = "Дистанция отлёта: " .. Settings.RetreatDistance
    RetreatLabel.Font = Enum.Font.Gotham
    RetreatLabel.TextSize = 12
    RetreatLabel.TextXAlignment = Enum.TextXAlignment.Left
    RetreatLabel.Parent = ContentContainer
    
    local RetreatInput = Instance.new("TextBox")
    RetreatInput.Size = UDim2.new(1, -20, 0, 20)
    RetreatInput.Position = UDim2.new(0, 10, 0, yOffset + 20)
    RetreatInput.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    RetreatInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    RetreatInput.Text = tostring(Settings.RetreatDistance)
    RetreatInput.Font = Enum.Font.Gotham
    RetreatInput.TextSize = 12
    RetreatInput.BorderSizePixel = 0
    RetreatInput.Parent = ContentContainer
    
    RetreatInput.FocusLost:Connect(function()
        local value = tonumber(RetreatInput.Text)
        if value and value > 0 then
            Settings.RetreatDistance = value
            RetreatLabel.Text = "Дистанция отлёта: " .. value
        end
    end)
    
    yOffset = yOffset + 50
    
    -- Автовыбор оружия
    local AutoWeaponLabel = Instance.new("TextLabel")
    AutoWeaponLabel.Size = UDim2.new(1, -20, 0, 20)
    AutoWeaponLabel.Position = UDim2.new(0, 10, 0, yOffset)
    AutoWeaponLabel.BackgroundTransparency = 1
    AutoWeaponLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    AutoWeaponLabel.Text = "Автовыбор оружия"
    AutoWeaponLabel.Font = Enum.Font.Gotham
    AutoWeaponLabel.TextSize = 12
    AutoWeaponLabel.TextXAlignment = Enum.TextXAlignment.Left
    AutoWeaponLabel.Parent = ContentContainer
    
    local AutoWeaponToggle = Instance.new("TextButton")
    AutoWeaponToggle.Size = UDim2.new(0, 40, 0, 20)
    AutoWeaponToggle.Position = UDim2.new(1, -50, 0, yOffset)
    AutoWeaponToggle.BackgroundColor3 = Settings.AutoWeapon and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(100, 100, 100)
    AutoWeaponToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    AutoWeaponToggle.Text = Settings.AutoWeapon and "Вкл" or "Выкл"
    AutoWeaponToggle.Font = Enum.Font.Gotham
    AutoWeaponToggle.TextSize = 10
    AutoWeaponToggle.BorderSizePixel = 0
    AutoWeaponToggle.Parent = ContentContainer
    
    AutoWeaponToggle.MouseButton1Click:Connect(function()
        Settings.AutoWeapon = not Settings.AutoWeapon
        AutoWeaponToggle.BackgroundColor3 = Settings.AutoWeapon and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(100, 100, 100)
        AutoWeaponToggle.Text = Settings.AutoWeapon and "Вкл" or "Выкл"
    end)
    
    yOffset = yOffset + 30
    
    -- Слот оружия
    local WeaponSlotLabel = Instance.new("TextLabel")
    WeaponSlotLabel.Size = UDim2.new(1, -20, 0, 20)
    WeaponSlotLabel.Position = UDim2.new(0, 10, 0, yOffset)
    WeaponSlotLabel.BackgroundTransparency = 1
    WeaponSlotLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    WeaponSlotLabel.Text = "Слот оружия: " .. Settings.WeaponSlot
    WeaponSlotLabel.Font = Enum.Font.Gotham
    WeaponSlotLabel.TextSize = 12
    WeaponSlotLabel.TextXAlignment = Enum.TextXAlignment.Left
    WeaponSlotLabel.Parent = ContentContainer
    
    local WeaponSlotInput = Instance.new("TextBox")
    WeaponSlotInput.Size = UDim2.new(1, -20, 0, 20)
    WeaponSlotInput.Position = UDim2.new(0, 10, 0, yOffset + 20)
    WeaponSlotInput.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    WeaponSlotInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    WeaponSlotInput.Text = tostring(Settings.WeaponSlot)
    WeaponSlotInput.Font = Enum.Font.Gotham
    WeaponSlotInput.TextSize = 12
    WeaponSlotInput.BorderSizePixel = 0
    WeaponSlotInput.Parent = ContentContainer
    
    WeaponSlotInput.FocusLost:Connect(function()
        local value = tonumber(WeaponSlotInput.Text)
        if value and value > 0 and value <= 10 then
            Settings.WeaponSlot = value
            WeaponSlotLabel.Text = "Слот оружия: " .. value
        end
    end)
    
    yOffset = yOffset + 50
    
    -- Разделитель
    local Separator = Instance.new("Frame")
    Separator.Size = UDim2.new(1, -20, 0, 2)
    Separator.Position = UDim2.new(0, 10, 0, yOffset)
    Separator.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    Separator.BorderSizePixel = 0
    Separator.Parent = ContentContainer
    
    yOffset = yOffset + 15
    
    -- Anti-Aim секция
    local AntiAimLabel = Instance.new("TextLabel")
    AntiAimLabel.Size = UDim2.new(1, -20, 0, 25)
    AntiAimLabel.Position = UDim2.new(0, 10, 0, yOffset)
    AntiAimLabel.BackgroundTransparency = 1
    AntiAimLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    AntiAimLabel.Text = "🔄 Anti-Aim"
    AntiAimLabel.Font = Enum.Font.GothamBold
    AntiAimLabel.TextSize = 16
    AntiAimLabel.TextXAlignment = Enum.TextXAlignment.Left
    AntiAimLabel.Parent = ContentContainer
    
    yOffset = yOffset + 30
    
    -- Включение Anti-Aim
    local EnableLabel = Instance.new("TextLabel")
    EnableLabel.Size = UDim2.new(1, -20, 0, 20)
    EnableLabel.Position = UDim2.new(0, 10, 0, yOffset)
    EnableLabel.BackgroundTransparency = 1
    EnableLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    EnableLabel.Text = "Включить Anti-Aim"
    EnableLabel.Font = Enum.Font.Gotham
    EnableLabel.TextSize = 12
    EnableLabel.TextXAlignment = Enum.TextXAlignment.Left
    EnableLabel.Parent = ContentContainer
    
    local EnableToggle = Instance.new("TextButton")
    EnableToggle.Size = UDim2.new(0, 40, 0, 20)
    EnableToggle.Position = UDim2.new(1, -50, 0, yOffset)
    EnableToggle.BackgroundColor3 = Settings.AntiAim.Enabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(100, 100, 100)
    EnableToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    EnableToggle.Text = Settings.AntiAim.Enabled and "Вкл" or "Выкл"
    EnableToggle.Font = Enum.Font.Gotham
    EnableToggle.TextSize = 10
    EnableToggle.BorderSizePixel = 0
    EnableToggle.Parent = ContentContainer
    
    EnableToggle.MouseButton1Click:Connect(function()
        Settings.AntiAim.Enabled = not Settings.AntiAim.Enabled
        EnableToggle.BackgroundColor3 = Settings.AntiAim.Enabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(100, 100, 100)
        EnableToggle.Text = Settings.AntiAim.Enabled and "Вкл" or "Выкл"
    end)
    
    yOffset = yOffset + 30
    
    -- Тип Anti-Aim
    local TypeLabel = Instance.new("TextLabel")
    TypeLabel.Size = UDim2.new(1, -20, 0, 20)
    TypeLabel.Position = UDim2.new(0, 10, 0, yOffset)
    TypeLabel.BackgroundTransparency = 1
    TypeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    TypeLabel.Text = "Тип: " .. Settings.AntiAim.Type
    TypeLabel.Font = Enum.Font.Gotham
    TypeLabel.TextSize = 12
    TypeLabel.TextXAlignment = Enum.TextXAlignment.Left
    TypeLabel.Parent = ContentContainer
    
    local TypeDropdown = Instance.new("TextButton")
    TypeDropdown.Size = UDim2.new(1, -20, 0, 25)
    TypeDropdown.Position = UDim2.new(0, 10, 0, yOffset + 20)
    TypeDropdown.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    TypeDropdown.TextColor3 = Color3.fromRGB(200, 200, 200)
    TypeDropdown.Text = Settings.AntiAim.Type
    TypeDropdown.Font = Enum.Font.Gotham
    TypeDropdown.TextSize = 12
    TypeDropdown.BorderSizePixel = 0
    TypeDropdown.Parent = ContentContainer
    
    local types = {"Jitter", "Random", "Spin"}
    local typeIndex = table.find(types, Settings.AntiAim.Type) or 1
    
    TypeDropdown.MouseButton1Click:Connect(function()
        typeIndex = typeIndex % #types + 1
        Settings.AntiAim.Type = types[typeIndex]
        TypeDropdown.Text = Settings.AntiAim.Type
        TypeLabel.Text = "Тип: " .. Settings.AntiAim.Type
    end)
    
    yOffset = yOffset + 60
    
    -- Скорость Anti-Aim
    local SpeedLabel = Instance.new("TextLabel")
    SpeedLabel.Size = UDim2.new(1, -20, 0, 20)
    SpeedLabel.Position = UDim2.new(0, 10, 0, yOffset)
    SpeedLabel.BackgroundTransparency = 1
    SpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    SpeedLabel.Text = "Скорость: " .. Settings.AntiAim.Speed
    SpeedLabel.Font = Enum.Font.Gotham
    SpeedLabel.TextSize = 12
    SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
    SpeedLabel.Parent = ContentContainer
    
    local SpeedInput = Instance.new("TextBox")
    SpeedInput.Size = UDim2.new(1, -20, 0, 20)
    SpeedInput.Position = UDim2.new(0, 10, 0, yOffset + 20)
    SpeedInput.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    SpeedInput.Text = tostring(Settings.AntiAim.Speed)
    SpeedInput.Font = Enum.Font.Gotham
    SpeedInput.TextSize = 12
    SpeedInput.BorderSizePixel = 0
    SpeedInput.Parent = ContentContainer
    
    SpeedInput.FocusLost:Connect(function()
        local value = tonumber(SpeedInput.Text)
        if value and value > 0 then
            Settings.AntiAim.Speed = value
            SpeedLabel.Text = "Скорость: " .. value
        end
    end)
    
    yOffset = yOffset + 50
    
    -- Диапазон
    local RangeLabel = Instance.new("TextLabel")
    RangeLabel.Size = UDim2.new(1, -20, 0, 20)
    RangeLabel.Position = UDim2.new(0, 10, 0, yOffset)
    RangeLabel.BackgroundTransparency = 1
    RangeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    RangeLabel.Text = "Диапазон: " .. Settings.AntiAim.Range
    RangeLabel.Font = Enum.Font.Gotham
    RangeLabel.TextSize = 12
    RangeLabel.TextXAlignment = Enum.TextXAlignment.Left
    RangeLabel.Parent = ContentContainer
    
    local RangeInput = Instance.new("TextBox")
    RangeInput.Size = UDim2.new(1, -20, 0, 20)
    RangeInput.Position = UDim2.new(0, 10, 0, yOffset + 20)
    RangeInput.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    RangeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    RangeInput.Text = tostring(Settings.AntiAim.Range)
    RangeInput.Font = Enum.Font.Gotham
    RangeInput.TextSize = 12
    RangeInput.BorderSizePixel = 0
    RangeInput.Parent = ContentContainer
    
    RangeInput.FocusLost:Connect(function()
        local value = tonumber(RangeInput.Text)
        if value and value > 0 then
            Settings.AntiAim.Range = value
            RangeLabel.Text = "Диапазон: " .. value
        end
    end)
end

-- Функция создания вкладки Movement
CreateMovementTabContent = function()
    local yOffset = 10
    
    -- Заголовок
    local MovementLabel = Instance.new("TextLabel")
    MovementLabel.Size = UDim2.new(1, -20, 0, 25)
    MovementLabel.Position = UDim2.new(0, 10, 0, yOffset)
    MovementLabel.BackgroundTransparency = 1
    MovementLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    MovementLabel.Text = "🏃 Настройки движения"
    MovementLabel.Font = Enum.Font.GothamBold
    MovementLabel.TextSize = 16
    MovementLabel.TextXAlignment = Enum.TextXAlignment.Left
    MovementLabel.Parent = ContentContainer
    
    yOffset = yOffset + 35
    
    -- Noclip
    local NoclipLabel = Instance.new("TextLabel")
    NoclipLabel.Size = UDim2.new(1, -20, 0, 25)
    NoclipLabel.Position = UDim2.new(0, 10, 0, yOffset)
    NoclipLabel.BackgroundTransparency = 1
    NoclipLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    NoclipLabel.Text = "Noclip (проход сквозь стены)"
    NoclipLabel.Font = Enum.Font.Gotham
    NoclipLabel.TextSize = 14
    NoclipLabel.TextXAlignment = Enum.TextXAlignment.Left
    NoclipLabel.Parent = ContentContainer
    
    local NoclipToggle = Instance.new("TextButton")
    NoclipToggle.Size = UDim2.new(0, 50, 0, 25)
    NoclipToggle.Position = UDim2.new(1, -60, 0, yOffset)
    NoclipToggle.BackgroundColor3 = Settings.Noclip and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(100, 100, 100)
    NoclipToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    NoclipToggle.Text = Settings.Noclip and "Вкл" or "Выкл"
    NoclipToggle.Font = Enum.Font.Gotham
    NoclipToggle.TextSize = 12
    NoclipToggle.BorderSizePixel = 0
    NoclipToggle.Parent = ContentContainer
    
    NoclipToggle.MouseButton1Click:Connect(function()
        Settings.Noclip = not Settings.Noclip
        NoclipToggle.BackgroundColor3 = Settings.Noclip and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(100, 100, 100)
        NoclipToggle.Text = Settings.Noclip and "Вкл" or "Выкл"
    end)
    
    yOffset = yOffset + 40
    
    -- Fly
    local FlyLabel = Instance.new("TextLabel")
    FlyLabel.Size = UDim2.new(1, -20, 0, 25)
    FlyLabel.Position = UDim2.new(0, 10, 0, yOffset)
    FlyLabel.BackgroundTransparency = 1
    FlyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    FlyLabel.Text = "Fly (полёт)"
    FlyLabel.Font = Enum.Font.Gotham
    FlyLabel.TextSize = 14
    FlyLabel.TextXAlignment = Enum.TextXAlignment.Left
    FlyLabel.Parent = ContentContainer
    
    local FlyToggle = Instance.new("TextButton")
    FlyToggle.Size = UDim2.new(0, 50, 0, 25)
    FlyToggle.Position = UDim2.new(1, -60, 0, yOffset)
    FlyToggle.BackgroundColor3 = Settings.Fly and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(100, 100, 100)
    FlyToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    FlyToggle.Text = Settings.Fly and "Вкл" or "Выкл"
    FlyToggle.Font = Enum.Font.Gotham
    FlyToggle.TextSize = 12
    FlyToggle.BorderSizePixel = 0
    FlyToggle.Parent = ContentContainer
    
    FlyToggle.MouseButton1Click:Connect(function()
        Settings.Fly = not Settings.Fly
        FlyToggle.BackgroundColor3 = Settings.Fly and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(100, 100, 100)
        FlyToggle.Text = Settings.Fly and "Вкл" or "Выкл"
    end)
    
    yOffset = yOffset + 40
    
    -- Скорость отлёта
    local RetreatSpeedLabel = Instance.new("TextLabel")
    RetreatSpeedLabel.Size = UDim2.new(1, -20, 0, 20)
    RetreatSpeedLabel.Position = UDim2.new(0, 10, 0, yOffset)
    RetreatSpeedLabel.BackgroundTransparency = 1
    RetreatSpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    RetreatSpeedLabel.Text = "Скорость отлёта: " .. Settings.RetreatSpeed
    RetreatSpeedLabel.Font = Enum.Font.Gotham
    RetreatSpeedLabel.TextSize = 12
    RetreatSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
    RetreatSpeedLabel.Parent = ContentContainer
    
    local RetreatSpeedInput = Instance.new("TextBox")
    RetreatSpeedInput.Size = UDim2.new(1, -20, 0, 20)
    RetreatSpeedInput.Position = UDim2.new(0, 10, 0, yOffset + 20)
    RetreatSpeedInput.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    RetreatSpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    RetreatSpeedInput.Text = tostring(Settings.RetreatSpeed)
    RetreatSpeedInput.Font = Enum.Font.Gotham
    RetreatSpeedInput.TextSize = 12
    RetreatSpeedInput.BorderSizePixel = 0
    RetreatSpeedInput.Parent = ContentContainer
    
    RetreatSpeedInput.FocusLost:Connect(function()
        local value = tonumber(RetreatSpeedInput.Text)
        if value and value > 0 then
            Settings.RetreatSpeed = value
            RetreatSpeedLabel.Text = "Скорость отлёта: " .. value
        end
    end)
    
    yOffset = yOffset + 50
    
    -- Высота полёта
    local HeightLabel = Instance.new("TextLabel")
    HeightLabel.Size = UDim2.new(1, -20, 0, 20)
    HeightLabel.Position = UDim2.new(0, 10, 0, yOffset)
    HeightLabel.BackgroundTransparency = 1
    HeightLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    HeightLabel.Text = "Высота над целью: " .. Settings.CircleHeight
    HeightLabel.Font = Enum.Font.Gotham
    HeightLabel.TextSize = 12
    HeightLabel.TextXAlignment = Enum.TextXAlignment.Left
    HeightLabel.Parent = ContentContainer
    
    local HeightInput = Instance.new("TextBox")
    HeightInput.Size = UDim2.new(1, -20, 0, 20)
    HeightInput.Position = UDim2.new(0, 10, 0, yOffset + 20)
    HeightInput.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    HeightInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    HeightInput.Text = tostring(Settings.CircleHeight)
    HeightInput.Font = Enum.Font.Gotham
    HeightInput.TextSize = 12
    HeightInput.BorderSizePixel = 0
    HeightInput.Parent = ContentContainer
    
    HeightInput.FocusLost:Connect(function()
        local value = tonumber(HeightInput.Text)
        if value then
            Settings.CircleHeight = value
            HeightLabel.Text = "Высота над целью: " .. value
        end
    end)
end

-- Функции скрипта
local function GetCharacter(player)
    if player and player.Character then
        return player.Character
    end
    return nil
end

local function EquipWeapon()
    if not Settings.AutoWeapon then return end
    
    local localPlayer = game:GetService("Players").LocalPlayer
    local localChar = localPlayer.Character
    if not localChar then return end
    
    -- Проверяем, есть ли уже оружие
    local currentTool = localChar:FindFirstChildOfClass("Tool")
    if currentTool then return end
    
    -- Ищем оружие в рюкзаке
    local backpack = localPlayer:FindFirstChild("Backpack")
    if not backpack then return end
    
    local weapon = backpack:FindFirstChildOfClass("Tool")
    if not weapon then return end
    
    -- Экипируем
    local humanoid = localChar:FindFirstChild("Humanoid")
    if humanoid then
        humanoid:EquipTool(weapon)
    end
end

local function Attack(targetChar)
    if not targetChar then return end
    
    local humanoid = targetChar:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    local currentTime = tick()
    if currentTime - lastAttackTime < Settings.AttackCooldown then
        return
    end
    
    -- Автовыбор оружия
    EquipWeapon()
    
    -- Атака
    local success, err = pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local character = player and player.Character
        local tool = character and character:FindFirstChildOfClass("Tool")

        if tool then
            tool:Activate()
            lastAttackTime = currentTime
            AntiAim.isRetreating = true
            AntiAim.retreatTimer = currentTime + 0.5
        end
    end)

    if not success then
        warn("[AI Target] Ошибка атаки:", err)
    end
end

local function ApplyAntiAim()
    if not Settings.AntiAim.Enabled then return end
    
    local localPlayer = game:GetService("Players").LocalPlayer
    local localChar = localPlayer.Character
    if not localChar then return end
    
    local humanoidRootPart = localChar:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local currentTime = tick()
    local deltaTime = currentTime - AntiAim.lastUpdate
    AntiAim.lastUpdate = currentTime
    
    if Settings.AntiAim.Type == "Jitter" then
        AntiAim.jitterAngle = AntiAim.jitterAngle + (Settings.AntiAim.Speed * deltaTime * 50)
        local jitterOffset = math.sin(AntiAim.jitterAngle) * Settings.AntiAim.Range
        humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.Angles(0, math.rad(jitterOffset), 0)
        
    elseif Settings.AntiAim.Type == "Random" then
        if currentTime - AntiAim.randomLastUpdate > 0.1 then
            AntiAim.randomLastUpdate = currentTime
            local randomAngle = math.random(-Settings.AntiAim.Range, Settings.AntiAim.Range)
            humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.Angles(0, math.rad(randomAngle), 0)
        end
        
    elseif Settings.AntiAim.Type == "Spin" then
        AntiAim.spinAngle = AntiAim.spinAngle + (Settings.AntiAim.Speed * deltaTime * 10)
        humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.Angles(0, math.rad(AntiAim.spinAngle), 0)
    end
end

local function MoveToTarget()
    if not isActive or not Target then return end
    
    local targetChar = GetCharacter(Target)
    if not targetChar then return end
    
    local localPlayer = game:GetService("Players").LocalPlayer
    local localChar = localPlayer.Character
    if not localChar then return end
    
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    
    if not targetRoot or not localRoot then return end
    
    local currentTime = tick()
    local targetPos = targetRoot.Position
    
    -- Проверяем отлёт
    if AntiAim.isRetreating and currentTime < AntiAim.retreatTimer then
        local retreatDirection = (localRoot.Position - targetPos).Unit
        localRoot.AssemblyLinearVelocity = retreatDirection * Settings.RetreatSpeed
        ApplyAntiAim()
        return
    else
        AntiAim.isRetreating = false
    end
    
    -- Кружение
    circleAngle = circleAngle + math.rad(Settings.CircleSpeed)
    if circleAngle > math.pi * 2 then
        circleAngle = circleAngle - math.pi * 2
    end
    
    local circlePos = Vector3.new(
        targetPos.X + math.cos(circleAngle) * Settings.CircleRadius,
        targetPos.Y + Settings.CircleHeight,
        targetPos.Z + math.sin(circleAngle) * Settings.CircleRadius
    )
    
    local direction = (circlePos - localRoot.Position).Unit
    local distance = (circlePos - localRoot.Position).Magnitude
    
    if distance > 1 then
        localRoot.AssemblyLinearVelocity = direction * Settings.FlySpeed
    else
        localRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end
    
    -- Атака
    if distance < Settings.AttackRange then
        Attack(targetChar)
    end
    
    -- Noclip
    if Settings.Noclip then
        for _, part in ipairs(localChar:GetDescendants()) do
            if part:IsA("BasePart") then
                if noclipParts[part] == nil then
                    noclipParts[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    end
    
    -- Anti-Aim
    ApplyAntiAim()
end

StartScript = function()
    if not Target and not Settings.AutoTarget then
        if _G.StatusLabel then
            _G.StatusLabel.Text = "Статус: Выбери цель!"
        end
        return false
    end
    
    if Settings.AutoTarget then
        local players = game:GetService("Players"):GetPlayers()
        for _, player in ipairs(players) do
            if player ~= game:GetService("Players").LocalPlayer then
                Target = player
                break
            end
        end
    end
    
    if not Target then
        if _G.StatusLabel then
            _G.StatusLabel.Text = "Статус: Нет игроков на сервере!"
        end
        return false
    end
    
    if connection then
        connection:Disconnect()
        connection = nil
    end

    isActive = true
    if _G.StatusLabel then
        _G.StatusLabel.Text = "Статус: Активен - " .. Target.Name
    end
    
    -- Запускаем цикл
    connection = game:GetService("RunService").Heartbeat:Connect(MoveToTarget)
    return true
end

StopScript = function()
    isActive = false
    if connection then
        connection:Disconnect()
        connection = nil
    end
    
    local localPlayer = game:GetService("Players").LocalPlayer
    local localChar = localPlayer.Character
    if localChar then
        local localRoot = localChar:FindFirstChild("HumanoidRootPart")
        if localRoot then
            localRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end
    
    if _G.StatusLabel then
        _G.StatusLabel.Text = "Статус: Остановлен"
    end
end

-- Подключаем кнопку сворачивания
MinimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    MainFrame.Size = isMinimized and UDim2.new(0, 450, 0, 40) or UDim2.new(0, 450, 0, 550)
    MinimizeButton.Text = isMinimized and "+" or "−"
    TabBar.Visible = not isMinimized
    ContentContainer.Visible = not isMinimized
end)

-- Очистка состояния при респавне
if LocalPlayer then
    LocalPlayer.CharacterAdded:Connect(function()
        if isActive then
            StopScript()
        end
        Target = nil
        circleAngle = 0
        AntiAim.isRetreating = false
        AntiAim.retreatTimer = 0
        AntiAim.lastUpdate = 0
        AntiAim.randomLastUpdate = 0
    end)
end

-- Показываем главную вкладку
SwitchTab("Главная")

-- Добавляем GUI на экран
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")

if PlayerGui then
    ScreenGui.Parent = PlayerGui
else
    ScreenGui.Parent = game:GetService("CoreGui")
end

print("✅ AI Target System v3.1 загружен!")
print("💡 Выбери игрока из списка и нажми 'Запустить'")
