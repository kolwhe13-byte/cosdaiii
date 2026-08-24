--[[
    Скрипт для "Создай ИИ" (Create AI)
    Версия: 4.0 - CLEAN UI
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
MainFrame.Draggable = true
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
    Round(TitleBar, 8)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Text = "🎯 AI Target • v5.1"
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
    local y = 10

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -20, 0, 28)
    header.Position = UDim2.new(0, 10, 0, y)
    header.BackgroundTransparency = 1
    header.Text = "⚔ Бой"
    header.TextColor3 = Color3.fromRGB(245, 247, 250)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 16
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = ContentContainer
    y += 38

    local function addNumberSetting(labelText, settingName, minValue, maxValue)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -20, 0, 20)
        label.Position = UDim2.new(0, 10, 0, y)
        label.BackgroundTransparency = 1
        label.Text = labelText .. ": " .. tostring(Settings[settingName])
        label.TextColor3 = Color3.fromRGB(205, 210, 220)
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = ContentContainer

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, -20, 0, 28)
        box.Position = UDim2.new(0, 10, 0, y + 22)
        box.BackgroundColor3 = Color3.fromRGB(35, 41, 54)
        box.TextColor3 = Color3.fromRGB(245, 247, 250)
        box.Text = tostring(Settings[settingName])
        box.ClearTextOnFocus = false
        box.Font = Enum.Font.Gotham
        box.TextSize = 12
        box.BorderSizePixel = 0
        box.Parent = ContentContainer
        Round(box, 8)

        box.FocusLost:Connect(function()
            local value = tonumber(box.Text)
            if value then
                value = math.clamp(value, minValue, maxValue)
                Settings[settingName] = value
                box.Text = tostring(value)
                label.Text = labelText .. ": " .. tostring(value)
            else
                box.Text = tostring(Settings[settingName])
            end
        end)

        y += 62
    end

    addNumberSetting("Скорость полёта", "FlySpeed", 1, 250)
    addNumberSetting("Радиус кружения", "CircleRadius", 1, 100)
    addNumberSetting("Высота", "CircleHeight", -50, 100)
    addNumberSetting("Скорость кружения", "CircleSpeed", 0.05, 20)
    addNumberSetting("Радиус атаки", "AttackRange", 1, 50)
    addNumberSetting("Задержка атаки", "AttackCooldown", 0.05, 10)

    local autoWeapon = Instance.new("TextButton")
    autoWeapon.Size = UDim2.new(1, -20, 0, 34)
    autoWeapon.Position = UDim2.new(0, 10, 0, y)
    autoWeapon.BackgroundColor3 = Settings.AutoWeapon and Color3.fromRGB(48, 125, 82) or Color3.fromRGB(45, 51, 64)
    autoWeapon.TextColor3 = Color3.fromRGB(245, 247, 250)
    autoWeapon.Text = "Автовыбор оружия: " .. (Settings.AutoWeapon and "ON" or "OFF")
    autoWeapon.Font = Enum.Font.GothamBold
    autoWeapon.TextSize = 12
    autoWeapon.BorderSizePixel = 0
    autoWeapon.Parent = ContentContainer
    Round(autoWeapon, 8)

    autoWeapon.MouseButton1Click:Connect(function()
        Settings.AutoWeapon = not Settings.AutoWeapon
        autoWeapon.Text = "Автовыбор оружия: " .. (Settings.AutoWeapon and "ON" or "OFF")
        autoWeapon.BackgroundColor3 = Settings.AutoWeapon and Color3.fromRGB(48, 125, 82) or Color3.fromRGB(45, 51, 64)
    end)
end

CreateMovementTabContent = function()
    local y = 10

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -20, 0, 28)
    header.Position = UDim2.new(0, 10, 0, y)
    header.BackgroundTransparency = 1
    header.Text = "🏃 Movement"
    header.TextColor3 = Color3.fromRGB(245, 247, 250)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 16
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = ContentContainer
    y += 40

    local function addToggle(text, settingName)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -20, 0, 36)
        button.Position = UDim2.new(0, 10, 0, y)
        button.BackgroundColor3 = Settings[settingName] and Color3.fromRGB(48, 125, 82) or Color3.fromRGB(45, 51, 64)
        button.TextColor3 = Color3.fromRGB(245, 247, 250)
        button.Text = text .. ": " .. (Settings[settingName] and "ON" or "OFF")
        button.Font = Enum.Font.GothamBold
        button.TextSize = 12
        button.BorderSizePixel = 0
        button.Parent = ContentContainer
        Round(button, 8)

        button.MouseButton1Click:Connect(function()
            Settings[settingName] = not Settings[settingName]
            button.Text = text .. ": " .. (Settings[settingName] and "ON" or "OFF")
            button.BackgroundColor3 = Settings[settingName] and Color3.fromRGB(48, 125, 82) or Color3.fromRGB(45, 51, 64)
            if settingName == "Noclip" and not Settings.Noclip then
                RestoreNoclip()
            end
        end)

        y += 45
    end

    addToggle("Fly", "Fly")
    addToggle("Noclip", "Noclip")

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -20, 0, 55)
    hint.Position = UDim2.new(0, 10, 0, y + 5)
    hint.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
    hint.TextColor3 = Color3.fromRGB(175, 182, 195)
    hint.Text = "Noclip работает независимо от движения и восстанавливает CanCollide после отключения."
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextWrapped = true
    hint.BorderSizePixel = 0
    hint.Parent = ContentContainer
    Round(hint, 8)
end

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
        if nearest then
            Target = nearest
        end
    end

    if not Target or not IsAlive(Target) then
        StopScript()
        return
    end

    local character = LocalPlayer.Character
    local localRoot = character and character:FindFirstChild("HumanoidRootPart")
    local targetRoot = GetTargetRoot(Target)

    if not localRoot or not targetRoot then
        return
    end

    if not Settings.Fly then
        localRoot.AssemblyLinearVelocity = Vector3.zero
        ApplyNoclip()
        return
    end

    circleAngle += math.rad(Settings.CircleSpeed)
    if circleAngle >= math.pi * 2 then
        circleAngle -= math.pi * 2
    end

    local targetPosition = targetRoot.Position
    local desiredPosition = targetPosition + Vector3.new(
        math.cos(circleAngle) * Settings.CircleRadius,
        Settings.CircleHeight,
        math.sin(circleAngle) * Settings.CircleRadius
    )

    local offset = desiredPosition - localRoot.Position
    local distance = offset.Magnitude

    if distance > 0.5 then
        local speed = math.clamp(distance * 5, 0, Settings.FlySpeed)
        localRoot.AssemblyLinearVelocity = offset.Unit * speed
    else
        localRoot.AssemblyLinearVelocity = Vector3.zero
    end

    if (targetRoot.Position - localRoot.Position).Magnitude <= Settings.AttackRange then
        Attack(Target.Character)
    end

    ApplyNoclip()
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
            {Size = UDim2.new(0, 400, 0, 500)}
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
local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")

if PlayerGui then
    ScreenGui.Parent = PlayerGui
else
    ScreenGui.Parent = game:GetService("CoreGui")
end

print("✅ AI Target • v5.1 загружен!")
print("💡 Выбери игрока из списка и нажми 'Запустить'")
