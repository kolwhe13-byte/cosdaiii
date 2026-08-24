--[[
    Скрипт для "Создай ИИ" (Create AI)
    Версия: 5.0 - CLEAN UI
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
    TargetMode = "Manual",
    AutoWeapon = true,
    WeaponSlot = 2,
    RetreatDistance = 15,
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

-- Создаём GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AITargetGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function Round(guiObject, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = guiObject
end

local function AddPadding(guiObject, left, right, top, bottom)
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, left or 0)
    padding.PaddingRight = UDim.new(0, right or 0)
    padding.PaddingTop = UDim.new(0, top or 0)
    padding.PaddingBottom = UDim.new(0, bottom or 0)
    padding.Parent = guiObject
end

-- Главное окно
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 400, 0, 500)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
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
Title.Text = "🎯 AI Target • v5.0"
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
    DropdownFrame.BackgroundColor3 = Color3.fromRGB(27, 32, 43)
    DropdownFrame.BorderSizePixel = 0
    DropdownFrame.Parent = ContentContainer
    Round(DropdownFrame, 8)
    
    local DropdownButton = Instance.new("TextButton")
    DropdownButton.Size = UDim2.new(1, 0, 1, 0)
    DropdownButton.BackgroundColor3 = Color3.fromRGB(27, 32, 43)
    DropdownButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    DropdownButton.Text = "Выбери игрока..."
    DropdownButton.Font = Enum.Font.Gotham
    DropdownButton.TextSize = 14
    DropdownButton.Parent = DropdownFrame
    Round(DropdownButton, 8)
    
    local DropdownList = Instance.new("ScrollingFrame")
    DropdownList.Size = UDim2.new(1, 0, 0, 120)
    DropdownList.Position = UDim2.new(0, 0, 1, 0)
    DropdownList.BackgroundColor3 = Color3.fromRGB(35, 41, 54)
    DropdownList.BorderSizePixel = 0
    DropdownList.Visible = false
    DropdownList.CanvasSize = UDim2.new(0, 0, 0, 0)
    DropdownList.ScrollBarThickness = 5
    DropdownList.Parent = DropdownFrame
    
    -- Кнопка обновления
    local RefreshButton = Instance.new("TextButton")
    RefreshButton.Size = UDim2.new(0, 30, 0, 30)
    RefreshButton.Position = UDim2.new(1, -35, 0, 0)
    RefreshButton.BackgroundColor3 = Color3.fromRGB(48, 56, 72)
    RefreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    RefreshButton.Text = "🔄"
    RefreshButton.Font = Enum.Font.Gotham
    RefreshButton.TextSize = 16
    RefreshButton.BorderSizePixel = 0
    RefreshButton.Parent = DropdownFrame
    Round(RefreshButton, 8)
    
    -- Функция обновления списка
    local function UpdatePlayerList()
        for _, child in ipairs(DropdownList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        local localPlayer = Players.LocalPlayer
        local localChar = localPlayer and localPlayer.Character
        local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
        local yOffset = 0
        local count = 0

        local players = Players:GetPlayers()
        table.sort(players, function(a, b)
            return a.DisplayName:lower() < b.DisplayName:lower()
        end)

        for _, player in ipairs(players) do
            if player ~= localPlayer then
                local alive = IsAlive(player)
                local distanceText = ""
                local root = GetTargetRoot(player)

                if localRoot and root then
                    distanceText = string.format("  •  %dm", math.floor((root.Position - localRoot.Position).Magnitude))
                end

                local playerButton = Instance.new("TextButton")
                playerButton.Size = UDim2.new(1, -6, 0, 30)
                playerButton.Position = UDim2.new(0, 3, 0, yOffset)
                playerButton.BackgroundColor3 = alive and Color3.fromRGB(42, 47, 58) or Color3.fromRGB(55, 40, 40)
                playerButton.TextColor3 = alive and Color3.fromRGB(235, 238, 245) or Color3.fromRGB(150, 150, 150)
                playerButton.Text = (alive and "● " or "○ ") .. player.DisplayName .. "  @" .. player.Name .. distanceText
                playerButton.Font = Enum.Font.Gotham
                playerButton.TextSize = 11
                playerButton.TextXAlignment = Enum.TextXAlignment.Left
                playerButton.BorderSizePixel = 0
                playerButton.Parent = DropdownList

                playerButton.MouseButton1Click:Connect(function()
                    if not IsAlive(player) then
                        if _G.StatusLabel then
                            _G.StatusLabel.Text = "Статус: Цель недоступна"
                        end
                        return
                    end

                    Target = player
                    DropdownButton.Text = "Цель: " .. player.DisplayName
                    DropdownList.Visible = false

                    if _G.StatusLabel then
                        _G.StatusLabel.Text = "Статус: Цель выбрана — " .. player.DisplayName
                    end
                end)

                yOffset = yOffset + 32
                count = count + 1
            end
        end

        if count == 0 then
            DropdownButton.Text = "Нет игроков"
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
    Round(ToggleButton, 8)
    
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
    SpeedInput.BackgroundColor3 = Color3.fromRGB(35, 41, 54)
    SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    SpeedInput.Text = tostring(Settings.FlySpeed)
    SpeedInput.Font = Enum.Font.Gotham
    SpeedInput.TextSize = 12
    SpeedInput.BorderSizePixel = 0
    SpeedInput.Parent = ContentContainer
    Round(SpeedInput, 8)
    
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
    RadiusInput.BackgroundColor3 = Color3.fromRGB(35, 41, 54)
    RadiusInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    RadiusInput.Text = tostring(Settings.CircleRadius)
    RadiusInput.Font = Enum.Font.Gotham
    RadiusInput.TextSize = 12
    RadiusInput.BorderSizePixel = 0
    RadiusInput.Parent = ContentContainer
    Round(RadiusInput, 8)
    
    RadiusInput.FocusLost:Connect(function()
        local value = tonumber(RadiusInput.Text)
        if value and value > 0 then
            Settings.CircleRadius = value
            RadiusLabel.Text = "Радиус кружения: " .. value
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
    WeaponSlotInput.BackgroundColor3 = Color3.fromRGB(35, 41, 54)
    WeaponSlotInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    WeaponSlotInput.Text = tostring(Settings.WeaponSlot)
    WeaponSlotInput.Font = Enum.Font.Gotham
    WeaponSlotInput.TextSize = 12
    WeaponSlotInput.BorderSizePixel = 0
    WeaponSlotInput.Parent = ContentContainer
    Round(WeaponSlotInput, 8)
    
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
    Separator.BackgroundColor3 = Color3.fromRGB(48, 56, 72)
    Separator.BorderSizePixel = 0
    Separator.Parent = ContentContainer
    
    yOffset = yOffset + 15
    
    local AntiAimLabel = Instance.new("TextLabel") -20, 0, 25) 10, 0, yOffset) 255, 255)
    
    yOffset = yOffset + 30
    
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
    TypeDropdown.BackgroundColor3 = Color3.fromRGB(35, 41, 54)
    TypeDropdown.TextColor3 = Color3.fromRGB(200, 200, 200)
    TypeDropdown.Text = Settings.AntiAim.Type
    TypeDropdown.Font = Enum.Font.Gotham
    TypeDropdown.TextSize = 12
    TypeDropdown.BorderSizePixel = 0
    TypeDropdown.Parent = ContentContainer
    Round(TypeDropdown, 8)
    
    local types = {"Jitter", "Random", "Spin"}
    local typeIndex = table.find(types, Settings.AntiAim.Type) or 1
    
    TypeDropdown.MouseButton1Click:Connect(function()
        typeIndex = typeIndex % #types + 1
        Settings.AntiAim.Type = types[typeIndex]
        TypeDropdown.Text = Settings.AntiAim.Type
        TypeLabel.Text = "Тип: " .. Settings.AntiAim.Type
    end)
    
    yOffset = yOffset + 60
    
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
    SpeedInput.BackgroundColor3 = Color3.fromRGB(35, 41, 54)
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
    RangeInput.BackgroundColor3 = Color3.fromRGB(35, 41, 54)
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
    Round(NoclipToggle, 8)
    
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
    Round(FlyToggle, 8)
    
    FlyToggle.MouseButton1Click:Connect(function()
        Settings.Fly = not Settings.Fly
        FlyToggle.BackgroundColor3 = Settings.Fly and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(100, 100, 100)
        FlyToggle.Text = Settings.Fly and "Вкл" or "Выкл"
    end)
    
    yOffset = yOffset + 40
    
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
    HeightInput.BackgroundColor3 = Color3.fromRGB(35, 41, 54)
    HeightInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    HeightInput.Text = tostring(Settings.CircleHeight)
    HeightInput.Font = Enum.Font.Gotham
    HeightInput.TextSize = 12
    HeightInput.BorderSizePixel = 0
    HeightInput.Parent = ContentContainer
    Round(HeightInput, 8)
    
    HeightInput.FocusLost:Connect(function()
        local value = tonumber(HeightInput.Text)
        if value then
            Settings.CircleHeight = value
            HeightLabel.Text = "Высота над целью: " .. value
        end
    end)
end

-- Функции скрипта

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local function MakeDraggable(handle, object)
    local dragging, dragStart, startPos, dragInput = false, nil, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, object.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local d = input.Position - dragStart
            object.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
end

local function AddStroke(obj)
    local s=Instance.new("UIStroke")
    s.Color=Color3.fromRGB(85,100,130); s.Thickness=1; s.Transparency=.45; s.Parent=obj
end


local function ApplyNoclip()
    local plr=Players.LocalPlayer; local char=plr and plr.Character
    if not char then return end
    if Settings.Noclip then
        for _,part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if noclipParts[part]==nil then noclipParts[part]=part.CanCollide end
                part.CanCollide=false
            end
        end
    else
        for part,old in pairs(noclipParts) do
            if part and part.Parent then part.CanCollide=old end
            noclipParts[part]=nil
        end
    end
end

local function GetHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function IsAlive(player)
    local character = player and player.Character
    local humanoid = GetHumanoid(character)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return humanoid ~= nil and humanoid.Health > 0 and root ~= nil
end

local function GetTargetRoot(player)
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function GetBestTarget()
    if Settings.TargetMode == "Nearest" then return GetNearestTarget() end
    if Target and IsAlive(Target) then return Target end
    return nil
end

local function GetNearestTarget()
    local localPlayer = Players.LocalPlayer
    local localCharacter = localPlayer and localPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil end

    local nearest, nearestDistance
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and IsAlive(player) then
            local root = GetTargetRoot(player)
            local distance = (root.Position - localRoot.Position).Magnitude
            if not nearestDistance or distance < nearestDistance then
                nearest = player
                nearestDistance = distance
            end
        end
    end
    return nearest
end

local function GetCharacter(player)
    return player and player.Character or nil
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
    
    if Settings.AntiAim.Type == "Jitter" then
        local jitterOffset = math.sin(AntiAim.jitterAngle) * Settings.AntiAim.Range
        humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.Angles(0, math.rad(jitterOffset), 0)
        
    elseif Settings.AntiAim.Type == "Random" then
        if currentTime - AntiAim.randomLastUpdate > 0.1 then
            local randomAngle = math.random(-Settings.AntiAim.Range, Settings.AntiAim.Range)
            humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.Angles(0, math.rad(randomAngle), 0)
        end
        
    elseif Settings.AntiAim.Type == "Spin" then
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
    ApplyNoclip()
end

StartScript = function()
    local selected = GetBestTarget()
    if not selected or not IsAlive(selected) then
        if _G.StatusLabel then _G.StatusLabel.Text="Статус: подходящей цели нет" end
        return false
    end
    Target=selected
    if connection then connection:Disconnect(); connection=nil end
    isActive=true
    if _G.StatusLabel then _G.StatusLabel.Text="Статус: Активен — "..Target.DisplayName end
    connection=RunService.Heartbeat:Connect(function()
        if Settings.TargetMode=="Nearest" then
            local nearest=GetNearestTarget()
            if nearest then Target=nearest end
        elseif not IsAlive(Target) then
            StopScript(); return
        end
        MoveToTarget()
    end)
    return true
end

StopScript = function()
    isActive = false

    if connection then
        connection:Disconnect()
        connection = nil
    end

    local localPlayer = Players.LocalPlayer
    local localChar = localPlayer and localPlayer.Character
    if localChar then
        localRoot = localChar:FindFirstChild("HumanoidRootPart")
        if localRoot then
            localRoot.AssemblyLinearVelocity = Vector3.zero
        end
    end

    for part, originalCanCollide in pairs(noclipParts) do
        if part and part.Parent then
            part.CanCollide = originalCanCollide
        end
    end
    table.clear(noclipParts)

    if _G.StatusLabel then
        _G.StatusLabel.Text = "Статус: Остановлен"
    end
end

local noclipConnection = RunService.Stepped:Connect(function()
    if Settings.Noclip then ApplyNoclip() end
end)

-- Подключаем кнопку сворачивания
MinimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    MinimizeButton.Text = isMinimized and "+" or "−"
    if isMinimized then
        TabBar.Visible=false; ContentContainer.Visible=false
        TweenService:Create(MainFrame,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,175,0,38)}):Play()
    else
        TweenService:Create(MainFrame,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,400,0,500)}):Play()
        task.delay(.08,function() if not isMinimized then TabBar.Visible=true; ContentContainer.Visible=true end end)
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
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")

if PlayerGui then
    ScreenGui.Parent = PlayerGui
else
    ScreenGui.Parent = game:GetService("CoreGui")
end

print("✅ AI Target • v5.0 загружен!")
print("💡 Выбери игрока из списка и нажми 'Запустить'")
