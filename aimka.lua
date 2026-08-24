-- Cb Ro | Mobile Fixed Version
-- ESP, Aimbot, AutoFire, Chams, BHop, 3P, Anti-Aim
-- Работает на мобильных эксплойтерах (Delta, Codex, Hydrogen и т.д.)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")

-- ==================== НАСТРОЙКИ ====================
local AimbotSettings = {
    Enabled = false,
    FOV = 180,          -- на мобиле лучше больше
    Smoothness = 3,     -- 1 = очень резко, 5-8 = плавнее
    HitPart = "Head",
    AutoFire = false,
    Wallbang = true,    -- по умолчанию включен wallbang (удобнее на мобиле)
    AutoFireDelay = 0.12
}

local VisualsSettings = {
    ChamsEnabled = false,
    ChamColor = Color3.fromRGB(255, 50, 50),
    ChamsTransparency = 0.4,
    ESPEnabled = false,
    ESPShowName = true,
    ESPShowDistance = true
}

local MiscSettings = {
    BHopEnabled = false,
    BHopSpeed = 22,
    ThirdPersonEnabled = false,
    ThirdPersonDistance = 10
}

local AntiAimSettings = {
    Enabled = false,
    Pitch = 0,
    Yaw = 180,
    SpinSpeed = 12,
    Jitter = false,
    JitterRange = 40
}

local PlayerESP = {}          -- BillboardGui + Highlight
local autoFireCooldown = 0
local thirdPersonActive = false
local thirdPersonConnection = nil
local jitterOffset = 0
local jitterDirection = 1

-- ==================== УТИЛИТЫ ====================
local function IsTeammate(player)
    if not player or not LocalPlayer then return false end
    if player == LocalPlayer then return true end
    if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then return true end
    if player.TeamColor and LocalPlayer.TeamColor and player.TeamColor == LocalPlayer.TeamColor then return true end
    return false
end

local function IsAlive(player)
    if not player or not player.Character then return false end
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function IsVisible(targetPos)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then return true end
    local origin = LocalPlayer.Character.Head.Position
    local dir = (targetPos - origin)
    local dist = dir.Magnitude
    if dist < 1 then return true end
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local result = Workspace:Raycast(origin, dir.Unit * dist, params)
    if not result then return true end
    
    local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
    if hitModel then
        local hitPlr = Players:GetPlayerFromCharacter(hitModel)
        if hitPlr and hitPlr ~= LocalPlayer and not IsTeammate(hitPlr) then
            return true
        end
    end
    return false
end

-- ==================== АВТОФАЕР (мобильный) ====================
local function FireWeapon()
    local char = LocalPlayer.Character
    if not char then return end

    -- 1. Активация инструмента
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function()
            tool:Activate()
        end)
        
        -- 2. Ищем RemoteEvent внутри оружия
        pcall(function()
            for _, v in ipairs(tool:GetDescendants()) do
                if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                    pcall(function()
                        if v:IsA("RemoteEvent") then
                            v:FireServer()
                        end
                    end)
                end
            end
        end)
    end

    -- 3. VirtualInputManager (работает на многих мобильных эксплойтерах)
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local vp = Camera.ViewportSize
        local cx, cy = vp.X / 2, vp.Y / 2
        vim:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
        task.wait(0.03)
        vim:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
    end)
end

-- ==================== CHAMS ====================
local function ApplyCham(character, state, color, transparency)
    if not character then return end
    color = color or Color3.fromRGB(255, 50, 50)
    transparency = transparency or 0.4

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local hl = part:FindFirstChild("CbRoCham")
            if state then
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "CbRoCham"
                    hl.Parent = part
                end
                hl.FillColor = color
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.FillTransparency = transparency
                hl.OutlineTransparency = 0.3
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            else
                if hl then hl:Destroy() end
            end
        end
    end
end

-- ==================== ESP (работает на мобиле) ====================
local function CreateESP(player)
    if PlayerESP[player] then return end
    if not player.Character then return end

    local char = player.Character
    local head = char:FindFirstChild("Head")
    if not head then return end

    -- Highlight (видно сквозь стены)
    local highlight = Instance.new("Highlight")
    highlight.Name = "CbRoESP"
    highlight.FillColor = IsTeammate(player) and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(255, 40, 40)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.65
    highlight.OutlineTransparency = 0.2
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = char

    -- BillboardGui с именем и дистанцией
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CbRoBillboard"
    billboard.Adornee = head
    billboard.Size = UDim2.new(0, 120, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2.2, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 1200
    billboard.Parent = head

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.DisplayName or player.Name
    nameLabel.TextColor3 = IsTeammate(player) and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 80, 80)
    nameLabel.TextStrokeTransparency = 0.4
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.Parent = billboard

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "Dist"
    distLabel.Size = UDim2.new(1, 0, 0.45, 0)
    distLabel.Position = UDim2.new(0, 0, 0.55, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = ""
    distLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    distLabel.TextStrokeTransparency = 0.5
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 11
    distLabel.Parent = billboard

    PlayerESP[player] = {
        Highlight = highlight,
        Billboard = billboard,
        NameLabel = nameLabel,
        DistLabel = distLabel
    }
end

local function RemoveESP(player)
    local data = PlayerESP[player]
    if data then
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
        PlayerESP[player] = nil
    end
end

local function UpdateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        if not VisualsSettings.ESPEnabled then
            RemoveESP(player)
            continue
        end

        if not IsAlive(player) then
            RemoveESP(player)
            continue
        end

        if not PlayerESP[player] then
            CreateESP(player)
        end

        local data = PlayerESP[player]
        if data and data.DistLabel and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                data.DistLabel.Text = math.floor(dist) .. "m"
                data.DistLabel.Visible = VisualsSettings.ESPShowDistance
            end
            if data.NameLabel then
                data.NameLabel.Visible = VisualsSettings.ESPShowName
            end
        end
    end
end

-- ==================== 3-Е ЛИЦО ====================
local function EnableThirdPerson()
    thirdPersonActive = true
    local dist = MiscSettings.ThirdPersonDistance

    if thirdPersonConnection then
        thirdPersonConnection:Disconnect()
    end

    thirdPersonConnection = RunService.RenderStepped:Connect(function()
        if not thirdPersonActive then return end
        pcall(function()
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
            LocalPlayer.CameraMaxZoomDistance = dist
            LocalPlayer.CameraMinZoomDistance = dist
            Camera.CameraType = Enum.CameraType.Custom
        end)
    end)
end

local function DisableThirdPerson()
    thirdPersonActive = false
    if thirdPersonConnection then
        thirdPersonConnection:Disconnect()
        thirdPersonConnection = nil
    end
    pcall(function()
        LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
        LocalPlayer.CameraMinZoomDistance = 0
        LocalPlayer.CameraMaxZoomDistance = 0
    end)
end

-- ==================== GUI ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CbRo_Mobile"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

-- Плавающая кнопка открытия (для мобилы)
local OpenBtn = Instance.new("TextButton")
OpenBtn.Name = "OpenBtn"
OpenBtn.Size = UDim2.new(0, 52, 0, 52)
OpenBtn.Position = UDim2.new(1, -70, 0.5, -26)
OpenBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
OpenBtn.Text = "Cb"
OpenBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
OpenBtn.Font = Enum.Font.GothamBold
OpenBtn.TextSize = 16
OpenBtn.BorderSizePixel = 0
OpenBtn.Parent = ScreenGui

local OpenCorner = Instance.new("UICorner")
OpenCorner.CornerRadius = UDim.new(1, 0)
OpenCorner.Parent = OpenBtn

local OpenStroke = Instance.new("UIStroke")
OpenStroke.Color = Color3.fromRGB(255, 60, 60)
OpenStroke.Thickness = 1.5
OpenStroke.Parent = OpenBtn

-- Главное окно
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 340, 0, 420)
MainFrame.Position = UDim2.new(0.5, -170, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

-- Заголовок
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -90, 1, 0)
TitleText.Position = UDim2.new(0, 14, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "Cb Ro Mobile"
TitleText.TextColor3 = Color3.fromRGB(220, 220, 220)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 15
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

-- Кнопка сворачивания
local isMinimized = false
local originalSize = UDim2.new(0, 340, 0, 420)
local minimizedSize = UDim2.new(0, 340, 0, 40)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 32, 0, 28)
MinBtn.Position = UDim2.new(1, -74, 0, 6)
MinBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
MinBtn.Text = "−"
MinBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 5)

-- Кнопка закрытия
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 28)
CloseBtn.Position = UDim2.new(1, -38, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)

-- Контейнеры
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(0, 95, 1, -40)
TabContainer.Position = UDim2.new(0, 0, 0, 40)
TabContainer.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
TabContainer.BorderSizePixel = 0
TabContainer.Parent = MainFrame

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -95, 1, -40)
ContentFrame.Position = UDim2.new(0, 95, 0, 40)
ContentFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame

-- Сворачивание
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        TabContainer.Visible = false
        ContentFrame.Visible = false
        MainFrame.Size = minimizedSize
        MinBtn.Text = "+"
    else
        TabContainer.Visible = true
        ContentFrame.Visible = true
        MainFrame.Size = originalSize
        MinBtn.Text = "−"
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

OpenBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
    if MainFrame.Visible and isMinimized then
        isMinimized = false
        TabContainer.Visible = true
        ContentFrame.Visible = true
        MainFrame.Size = originalSize
        MinBtn.Text = "−"
    end
end)

-- Перетаскивание главного окна (touch-friendly)
do
    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Перетаскивание кнопки открытия
do
    local dragging, dragStart, startPos
    OpenBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = OpenBtn.Position
        end
    end)
    OpenBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            OpenBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Вкладки
local Tabs = {"Aimbot", "Visuals", "Misc", "AntiAim"}
local tabContents = {}

local function CreateTab(name, index)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -12, 0, 38)
    btn.Position = UDim2.new(0, 6, 0, 8 + (index - 1) * 46)
    btn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(170, 170, 170)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.Parent = TabContainer
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -12, 1, -12)
    content.Position = UDim2.new(0, 6, 0, 6)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 3
    content.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70)
    content.CanvasSize = UDim2.new(0, 0, 0, 600)
    content.Visible = false
    content.Parent = ContentFrame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 7)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)

    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(TabContainer:GetChildren()) do
            if t:IsA("TextButton") then
                t.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
                t.TextColor3 = Color3.fromRGB(170, 170, 170)
            end
        end
        for _, c in ipairs(ContentFrame:GetChildren()) do
            if c:IsA("ScrollingFrame") then c.Visible = false end
        end
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        content.Visible = true
    end)

    if index == 1 then
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        content.Visible = true
    end

    return content
end

for i, name in ipairs(Tabs) do
    tabContents[name] = CreateTab(name, i)
end

-- ==================== UI ЭЛЕМЕНТЫ ====================
local function CreateToggle(name, parent, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 46, 0, 26)
    btn.Position = UDim2.new(1, -56, 0.5, -13)
    btn.BackgroundColor3 = default and Color3.fromRGB(60, 140, 60) or Color3.fromRGB(50, 50, 50)
    btn.Text = default and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.BorderSizePixel = 0
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(60, 140, 60) or Color3.fromRGB(50, 50, 50)
        btn.Text = state and "ON" or "OFF"
        if callback then callback(state) end
    end)

    return {
        Set = function(v)
            state = v
            btn.BackgroundColor3 = state and Color3.fromRGB(60, 140, 60) or Color3.fromRGB(50, 50, 50)
            btn.Text = state and "ON" or "OFF"
        end,
        Get = function() return state end
    }
end

local function CreateSlider(name, parent, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 62)
    frame.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 12, 0, 6)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. default
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1, -24, 0, 14)
    bar.Position = UDim2.new(0, 12, 0, 34)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    bar.Text = ""
    bar.AutoButtonColor = false
    bar.BorderSizePixel = 0
    bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 7)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 7)

    local current = default
    local dragging = false

    local function update(posX)
        local rel = math.clamp((posX - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        current = math.floor((min + (max - min) * rel) * 10 + 0.5) / 10
        fill.Size = UDim2.new(rel, 0, 1, 0)
        label.Text = name .. ": " .. current
        if callback then callback(current) end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input.Position.X)
        end
    end)
    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end)

    return {
        Set = function(v)
            current = v
            local rel = (v - min) / (max - min)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            label.Text = name .. ": " .. v
        end,
        Get = function() return current end
    }
end

-- ==================== НАПОЛНЕНИЕ ====================
-- AIMBOT
CreateToggle("Enable Aimbot", tabContents["Aimbot"], false, function(v) AimbotSettings.Enabled = v end)
CreateSlider("FOV", tabContents["Aimbot"], 40, 400, 180, function(v) AimbotSettings.FOV = v end)
CreateSlider("Smoothness", tabContents["Aimbot"], 1, 15, 3, function(v) AimbotSettings.Smoothness = v end)
CreateToggle("Auto Fire", tabContents["Aimbot"], false, function(v) AimbotSettings.AutoFire = v end)
CreateToggle("Wallbang", tabContents["Aimbot"], true, function(v) AimbotSettings.Wallbang = v end)
CreateSlider("Fire Delay", tabContents["Aimbot"], 0.05, 0.5, 0.12, function(v) AimbotSettings.AutoFireDelay = v end)

-- VISUALS
CreateToggle("Enable ESP", tabContents["Visuals"], false, function(v)
    VisualsSettings.ESPEnabled = v
    if not v then
        for plr, _ in pairs(PlayerESP) do
            RemoveESP(plr)
        end
    end
end)
CreateToggle("Show Name", tabContents["Visuals"], true, function(v) VisualsSettings.ESPShowName = v end)
CreateToggle("Show Distance", tabContents["Visuals"], true, function(v) VisualsSettings.ESPShowDistance = v end)
CreateToggle("Enable Chams", tabContents["Visuals"], false, function(v)
    VisualsSettings.ChamsEnabled = v
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            ApplyCham(p.Character, v, VisualsSettings.ChamColor, VisualsSettings.ChamsTransparency)
        end
    end
end)
CreateSlider("Chams Transparency", tabContents["Visuals"], 0, 1, 0.4, function(v)
    VisualsSettings.ChamsTransparency = v
    if VisualsSettings.ChamsEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                ApplyCham(p.Character, true, VisualsSettings.ChamColor, v)
            end
        end
    end
end)

-- MISC
CreateToggle("Bunny Hop", tabContents["Misc"], false, function(v) MiscSettings.BHopEnabled = v end)
CreateSlider("BHop Speed", tabContents["Misc"], 16, 45, 22, function(v) MiscSettings.BHopSpeed = v end)
CreateToggle("Third Person", tabContents["Misc"], false, function(v)
    MiscSettings.ThirdPersonEnabled = v
    if v then EnableThirdPerson() else DisableThirdPerson() end
end)
CreateSlider("TP Distance", tabContents["Misc"], 3, 20, 10, function(v)
    MiscSettings.ThirdPersonDistance = v
    if MiscSettings.ThirdPersonEnabled then
        pcall(function()
            LocalPlayer.CameraMaxZoomDistance = v
            LocalPlayer.CameraMinZoomDistance = v
        end)
    end
end)

-- ANTI-AIM
CreateToggle("Enable Anti-Aim", tabContents["AntiAim"], false, function(v) AntiAimSettings.Enabled = v end)
CreateToggle("Jitter", tabContents["AntiAim"], false, function(v) AntiAimSettings.Jitter = v end)
CreateSlider("Jitter Range", tabContents["AntiAim"], 5, 90, 40, function(v) AntiAimSettings.JitterRange = v end)
CreateSlider("Pitch", tabContents["AntiAim"], -89, 89, 0, function(v) AntiAimSettings.Pitch = v end)
CreateSlider("Yaw", tabContents["AntiAim"], -180, 180, 180, function(v) AntiAimSettings.Yaw = v end)
CreateSlider("Spin Speed", tabContents["AntiAim"], 0, 40, 12, function(v) AntiAimSettings.SpinSpeed = v end)

-- ==================== ОСНОВНОЙ ЦИКЛ ====================
RunService.RenderStepped:Connect(function()
    -- ESP
    if VisualsSettings.ESPEnabled then
        UpdateESP()
    end

    -- AIMBOT (мобильный — от центра экрана)
    if AimbotSettings.Enabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
        local closest = AimbotSettings.FOV
        local bestHead = nil
        local center = Camera.ViewportSize / 2

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            if IsTeammate(player) then continue end
            if not IsAlive(player) then continue end

            local head = player.Character and player.Character:FindFirstChild("Head")
            if not head then continue end

            if not AimbotSettings.Wallbang and not IsVisible(head.Position) then continue end

            local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
            if onScreen and screenPos.Z > 0 then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                if dist < closest then
                    closest = dist
                    bestHead = head
                end
            end
        end

        if bestHead then
            local targetCF = CFrame.new(Camera.CFrame.Position, bestHead.Position)
            local smooth = math.clamp(1 / AimbotSettings.Smoothness, 0.05, 1)
            Camera.CFrame = Camera.CFrame:Lerp(targetCF, smooth)

            if AimbotSettings.AutoFire and (tick() - autoFireCooldown) > AimbotSettings.AutoFireDelay then
                autoFireCooldown = tick()
                FireWeapon()
            end
        end
    end

    -- BHop
    if LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            if MiscSettings.BHopEnabled then
                hum.WalkSpeed = MiscSettings.BHopSpeed
                if hum.MoveDirection.Magnitude > 0 and hum.FloorMaterial ~= Enum.Material.Air then
                    hum.Jump = true
                end
            else
                if hum.WalkSpeed ~= 16 then hum.WalkSpeed = 16 end
            end
        end
    end

    -- Anti-Aim
    if AntiAimSettings.Enabled and LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            if AntiAimSettings.Jitter then
                jitterOffset = jitterOffset + (6 * jitterDirection)
                if math.abs(jitterOffset) >= AntiAimSettings.JitterRange then
                    jitterDirection = -jitterDirection
                end
            else
                jitterOffset = 0
            end

            local pitch = math.rad(AntiAimSettings.Pitch)
            local yaw = math.rad(AntiAimSettings.Yaw + (tick() * AntiAimSettings.SpinSpeed * 8 % 360) + jitterOffset)
            root.CFrame = CFrame.new(root.Position) * CFrame.Angles(pitch, yaw, 0)
        end
    end
end)

-- ==================== ОБРАБОТЧИКИ ====================
local function OnCharacterAdded(character)
    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    RemoveESP(player)

    task.wait(0.3)

    if VisualsSettings.ESPEnabled and player ~= LocalPlayer and IsAlive(player) then
        CreateESP(player)
    end

    if VisualsSettings.ChamsEnabled and player ~= LocalPlayer then
        ApplyCham(character, true, VisualsSettings.ChamColor, VisualsSettings.ChamsTransparency)
    end

    if player == LocalPlayer and MiscSettings.ThirdPersonEnabled then
        EnableThirdPerson()
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    player.CharacterAdded:Connect(OnCharacterAdded)
    if player.Character then
        task.spawn(OnCharacterAdded, player.Character)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(OnCharacterAdded)
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
end)

print("Cb Ro Mobile Fixed | ESP + Aimbot + AutoFire работают")
