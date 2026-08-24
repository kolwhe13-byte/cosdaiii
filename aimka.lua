-- Cb Ro | Private Cheat (Mobile / Delta) – FINAL FIX (все вкладки работают)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")

-- ==================== НАСТРОЙКИ ====================
local AimbotSettings = {
    Enabled = false,
    FOV = 120,
    Smoothness = 1,
    HitPart = "Head",
    AutoFire = false,
    Wallbang = false
}

local VisualsSettings = {
    ChamsEnabled = false,
    ChamColor = Color3.fromRGB(255, 0, 0),
    ChamsTransparency = 0.3,
    ESPEnabled = false
}

local MiscSettings = {
    BHopEnabled = false,
    BHopSpeed = 16,
    ThirdPersonEnabled = false,
    ThirdPersonDistance = 8
}

local AntiAimSettings = {
    Enabled = false,
    Pitch = 0,
    Yaw = 180,
    SpinSpeed = 10,
    Jitter = false,
    JitterRange = 45
}

local autoFireCooldown = 0
local thirdPersonActive = false
local thirdPersonConnection = nil
local jitterOffset = 0
local jitterDirection = 1
local isMinimized = false
local originalSize = UDim2.new(0, 520, 0, 380)

-- ==================== УТИЛИТЫ ====================
local function IsTeammate(player)
    if not player or not LocalPlayer then return false end
    if player == LocalPlayer then return true end
    if player.TeamColor == LocalPlayer.TeamColor then return true end
    if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then return true end
    return false
end

local function IsAlive(player)
    if not player or not player.Character then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then return true end
    return false
end

local function IsVisible(targetPosition)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then return false end
    local origin = LocalPlayer.Character.Head.Position
    local direction = (targetPosition - origin).Unit
    local distance = (targetPosition - origin).Magnitude
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    local rayResult = Workspace:Raycast(origin, direction * distance, rayParams)
    if rayResult then
        local hitCharacter = rayResult.Instance:FindFirstAncestorOfClass("Model")
        if hitCharacter then
            local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
            if hitPlayer and hitPlayer ~= LocalPlayer and not IsTeammate(hitPlayer) then
                return true
            end
        end
        return false
    end
    return true
end

-- ==================== АВТОФАЕР ====================
local function FireWeapon()
    local character = LocalPlayer.Character
    if not character then return end

    local tool = nil
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then
            tool = child
            break
        end
    end
    if not tool then return end

    pcall(function() if tool.Activate then tool:Activate() end end)
    pcall(function()
        for _, remote in ipairs(tool:GetDescendants()) do
            if remote:IsA("RemoteEvent") then remote:FireServer() break end
        end
    end)
    pcall(function()
        local touchPos = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        VirtualInputManager:SendTouchEvent(1, touchPos.X, touchPos.Y, true, 1, game, 0)
        wait(0.05)
        VirtualInputManager:SendTouchEvent(1, touchPos.X, touchPos.Y, false, 1, game, 0)
    end)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
end

-- ==================== CHAMS ====================
local function ApplyChamToPart(part, color, transparency)
    if not part or not part:IsA("BasePart") then return end
    local hl = part:FindFirstChild("VillageCham")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "VillageCham"
        hl.FillColor = color
        hl.OutlineColor = Color3.fromRGB(255,255,255)
        hl.FillTransparency = transparency
        hl.OutlineTransparency = 1
        hl.Parent = part
    else
        hl.FillColor = color
        hl.FillTransparency = transparency
        hl.OutlineColor = Color3.fromRGB(255,255,255)
    end
end

local function ApplyChamToCharacter(character, state, color, transparency)
    if not character then return end
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            if state then ApplyChamToPart(part, color, transparency)
            else
                local hl = part:FindFirstChild("VillageCham")
                if hl then hl:Destroy() end
            end
        end
    end
    if state then
        if not character:FindFirstChild("ChamListener") then
            local listener = Instance.new("Folder")
            listener.Name = "ChamListener"
            listener.Parent = character
            character.ChildAdded:Connect(function(child)
                if child:IsA("BasePart") then ApplyChamToPart(child, color, transparency) end
            end)
        end
    else
        local listener = character:FindFirstChild("ChamListener")
        if listener then listener:Destroy() end
    end
end

local function UpdateAllChams()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            ApplyChamToCharacter(player.Character, VisualsSettings.ChamsEnabled, VisualsSettings.ChamColor, VisualsSettings.ChamsTransparency)
        end
    end
end

-- ==================== ESP ====================
local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = "ESP_Gui"
ESPGui.Parent = game.CoreGui
ESPGui.Enabled = false

local espFrames = {}

local function CreateESPFrame(player)
    if espFrames[player] then return end
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 100, 0, 150)
    frame.BackgroundTransparency = 0.5
    frame.BackgroundColor3 = Color3.fromRGB(255,0,0)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(255,255,255)
    frame.Visible = false
    frame.Parent = ESPGui

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1,0,0,20)
    nameLabel.Position = UDim2.new(0,0,1,0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.fromRGB(255,255,255)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 12
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.Parent = frame
    espFrames[player] = {frame = frame, nameLabel = nameLabel}
end

local function RemoveESPFrame(player)
    local data = espFrames[player]
    if data then data.frame:Destroy(); espFrames[player] = nil end
end

local function UpdateESP()
    if not VisualsSettings.ESPEnabled then ESPGui.Enabled = false return end
    ESPGui.Enabled = true
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then
            if espFrames[player] then RemoveESPFrame(player) end
            continue
        end
        if not IsAlive(player) or IsTeammate(player) then
            if espFrames[player] then espFrames[player].frame.Visible = false end
            continue
        end
        if not espFrames[player] then CreateESPFrame(player) end
        local data = espFrames[player]
        local character = player.Character
        local head = character:FindFirstChild("Head")
        local root = character:FindFirstChild("HumanoidRootPart")
        if not head or not root then data.frame.Visible = false continue end
        local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
        if not onScreen then data.frame.Visible = false continue end
        local dist = (head.Position - Camera.CFrame.Position).Magnitude
        local height = math.clamp(3000/dist, 30, 300)
        local width = height * 0.5
        data.frame.Size = UDim2.new(0, width, 0, height)
        data.frame.Position = UDim2.new(0, headPos.X - width/2, 0, headPos.Y - height/2)
        data.frame.BackgroundColor3 = Color3.fromRGB(255,40,40)
        data.frame.Visible = true
        data.nameLabel.Text = player.Name
    end
    for player, _ in pairs(espFrames) do
        if not Players:FindFirstChild(player.Name) then RemoveESPFrame(player) end
    end
end

-- ==================== 3-е ЛИЦО ====================
local function EnableThirdPerson()
    thirdPersonActive = true
    local distance = MiscSettings.ThirdPersonDistance
    if thirdPersonConnection then thirdPersonConnection:Disconnect() end
    thirdPersonConnection = RunService.RenderStepped:Connect(function()
        if thirdPersonActive then
            pcall(function()
                if LocalPlayer.CameraMode ~= Enum.CameraMode.Classic then LocalPlayer.CameraMode = Enum.CameraMode.Classic end
                if LocalPlayer.CameraMaxZoomDistance ~= distance then LocalPlayer.CameraMaxZoomDistance = distance end
                if LocalPlayer.CameraMinZoomDistance ~= distance then LocalPlayer.CameraMinZoomDistance = distance end
                if Camera.CameraType ~= Enum.CameraType.Custom then Camera.CameraType = Enum.CameraType.Custom end
            end)
        end
    end)
    if LocalPlayer.Character then
        LocalPlayer.Character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") and thirdPersonActive then
                wait(0.05)
                pcall(function()
                    LocalPlayer.CameraMode = Enum.CameraMode.Classic
                    LocalPlayer.CameraMaxZoomDistance = distance
                    LocalPlayer.CameraMinZoomDistance = distance
                    Camera.CameraType = Enum.CameraType.Custom
                end)
            end
        end)
    end
end

local function DisableThirdPerson()
    thirdPersonActive = false
    if thirdPersonConnection then thirdPersonConnection:Disconnect(); thirdPersonConnection = nil end
    pcall(function()
        LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
        LocalPlayer.CameraMinZoomDistance = 0
        LocalPlayer.CameraMaxZoomDistance = 0
        Camera.CameraType = Enum.CameraType.Custom
    end)
end

-- ==================== ПОСТРОЕНИЕ МЕНЮ ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = game.CoreGui
ScreenGui.Name = "CbRo_Cheat"

local MainFrame = Instance.new("Frame")
MainFrame.Size = originalSize
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(18,18,18)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0,8)
Corner.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1,0,0,40)
TitleBar.BackgroundColor3 = Color3.fromRGB(12,12,12)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1,-90,1,0)
TitleText.Position = UDim2.new(0,15,0,0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "Cb Ro | Private Cheat [Mobile]"
TitleText.TextColor3 = Color3.fromRGB(200,200,200)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 14
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0,30,0,30)
MinBtn.Position = UDim2.new(1,-80,0,5)
MinBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(220,220,220)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.BorderSizePixel = 0
local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0,4)
MinCorner.Parent = MinBtn
MinBtn.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,30,0,30)
CloseBtn.Position = UDim2.new(1,-40,0,5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(220,220,220)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.BorderSizePixel = 0
local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0,4)
CloseCorner.Parent = CloseBtn
CloseBtn.Parent = TitleBar

local function ToggleMinimize()
    isMinimized = not isMinimized
    if isMinimized then
        MainFrame.Size = UDim2.new(0,200,0,40)
        MainFrame.Position = UDim2.new(1,-210,1,-50)
        for _, child in ipairs(MainFrame:GetChildren()) do
            if child ~= TitleBar then child.Visible = false end
        end
        MinBtn.Text = "+"
    else
        MainFrame.Size = originalSize
        MainFrame.Position = UDim2.new(0.5,-260,0.5,-190)
        for _, child in ipairs(MainFrame:GetChildren()) do
            child.Visible = true
        end
        MinBtn.Text = "—"
    end
end

MinBtn.MouseButton1Click:Connect(ToggleMinimize)
CloseBtn.MouseButton1Click:Connect(ToggleMinimize)

local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(0,130,1,-40)
TabContainer.Position = UDim2.new(0,0,0,40)
TabContainer.BackgroundColor3 = Color3.fromRGB(14,14,14)
TabContainer.BorderSizePixel = 0
TabContainer.Parent = MainFrame

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1,-130,1,-40)
ContentFrame.Position = UDim2.new(0,130,0,40)
ContentFrame.BackgroundColor3 = Color3.fromRGB(22,22,22)
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame

local Tabs = {"Aimbot", "Visuals", "Misc", "Anti-Aim"}
local tabContents = {}

-- ==================== ФУНКЦИЯ СОЗДАНИЯ ВКЛАДКИ ====================
local function CreateTab(name, index)
    local YOffset = 10 + (index - 1) * 50
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1,-20,0,40)
    TabBtn.Position = UDim2.new(0,10,0,YOffset)
    TabBtn.BackgroundColor3 = Color3.fromRGB(25,25,25)
    TabBtn.Text = name
    TabBtn.TextColor3 = Color3.fromRGB(180,180,180)
    TabBtn.Font = Enum.Font.GothamSemibold
    TabBtn.TextSize = 13
    TabBtn.BorderSizePixel = 0
    local TabCorner = Instance.new("UICorner")
    TabCorner.CornerRadius = UDim.new(0,4)
    TabCorner.Parent = TabBtn
    TabBtn.Parent = TabContainer

    local TabContent = Instance.new("ScrollingFrame")
    TabContent.Size = UDim2.new(1,-20,1,-20)
    TabContent.Position = UDim2.new(0,10,0,10)
    TabContent.BackgroundTransparency = 1
    TabContent.ScrollBarThickness = 4
    TabContent.ScrollBarImageColor3 = Color3.fromRGB(80,80,80)
    TabContent.CanvasSize = UDim2.new(0,0,0,0)
    TabContent.Visible = true  -- изначально все видимы, потом скроем лишние
    TabContent.Parent = ContentFrame

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0,8)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = TabContent

    local function RefreshCanvas()
        TabContent.CanvasSize = UDim2.new(0,0,0, UIListLayout.AbsoluteContentSize.Y + 20)
    end
    UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(RefreshCanvas)
    TabContent.ChildAdded:Connect(RefreshCanvas)

    TabBtn.MouseButton1Click:Connect(function()
        for _, tab in ipairs(TabContainer:GetChildren()) do
            if tab:IsA("TextButton") then
                tab.BackgroundColor3 = Color3.fromRGB(25,25,25)
                tab.TextColor3 = Color3.fromRGB(180,180,180)
            end
        end
        for _, content in ipairs(ContentFrame:GetChildren()) do
            if content:IsA("ScrollingFrame") then
                content.Visible = false
            end
        end
        TabBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
        TabBtn.TextColor3 = Color3.fromRGB(255,255,255)
        TabContent.Visible = true
        RefreshCanvas()
    end)

    if index == 1 then
        TabBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
        TabBtn.TextColor3 = Color3.fromRGB(255,255,255)
    end

    tabContents[name] = TabContent
    return TabContent
end

-- Создаём все вкладки
for i, name in ipairs(Tabs) do
    CreateTab(name, i)
end

-- Теперь скрываем все вкладки кроме первой
for name, content in pairs(tabContents) do
    if name ~= "Aimbot" then
        content.Visible = false
    end
end

-- ==================== ЭЛЕМЕНТЫ GUI ====================
local function CreateToggle(name, parent, default, callback)
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(1,0,0,45)
    ToggleFrame.BackgroundColor3 = Color3.fromRGB(28,28,28)
    ToggleFrame.BorderSizePixel = 0
    local TCorner = Instance.new("UICorner")
    TCorner.CornerRadius = UDim.new(0,4)
    TCorner.Parent = ToggleFrame
    ToggleFrame.Parent = parent

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0,200,1,0)
    Label.Position = UDim2.new(0,12,0,0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(220,220,220)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = ToggleFrame

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0,44,0,24)
    ToggleBtn.Position = UDim2.new(1,-56,0.5,-12)
    ToggleBtn.BackgroundColor3 = default and Color3.fromRGB(60,60,60) or Color3.fromRGB(35,35,35)
    ToggleBtn.Text = ""
    ToggleBtn.BorderSizePixel = 0
    local TBtnCorner = Instance.new("UICorner")
    TBtnCorner.CornerRadius = UDim.new(1,0)
    TBtnCorner.Parent = ToggleBtn
    ToggleBtn.Parent = ToggleFrame

    local state = default
    local function updateVisual()
        ToggleBtn.BackgroundColor3 = state and Color3.fromRGB(60,60,60) or Color3.fromRGB(35,35,35)
    end

    ToggleBtn.MouseButton1Click:Connect(function()
        state = not state
        updateVisual()
        if callback then callback(state) end
    end)
    return { Set = function(val) state = val; updateVisual() end, Get = function() return state end }
end

local function CreateSlider(name, parent, min, max, default, callback)
    local SliderFrame = Instance.new("Frame")
    SliderFrame.Size = UDim2.new(1,0,0,65)
    SliderFrame.BackgroundColor3 = Color3.fromRGB(28,28,28)
    SliderFrame.BorderSizePixel = 0
    local SCorner = Instance.new("UICorner")
    SCorner.CornerRadius = UDim.new(0,4)
    SCorner.Parent = SliderFrame
    SliderFrame.Parent = parent

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1,-24,0,20)
    Label.Position = UDim2.new(0,12,0,6)
    Label.BackgroundTransparency = 1
    Label.Text = name .. ": " .. default
    Label.TextColor3 = Color3.fromRGB(200,200,200)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = SliderFrame

    local SliderBackground = Instance.new("TextButton")
    SliderBackground.Size = UDim2.new(1,-24,0,14)
    SliderBackground.Position = UDim2.new(0,12,0,34)
    SliderBackground.BackgroundColor3 = Color3.fromRGB(40,40,40)
    SliderBackground.BorderSizePixel = 0
    SliderBackground.Text = ""
    SliderBackground.AutoButtonColor = false
    local SBGCorner = Instance.new("UICorner")
    SBGCorner.CornerRadius = UDim.new(0,6)
    SBGCorner.Parent = SliderBackground
    SliderBackground.Parent = SliderFrame

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((default-min)/(max-min),0,1,0)
    Fill.Position = UDim2.new(0,0,0,0)
    Fill.BackgroundColor3 = Color3.fromRGB(80,80,80)
    Fill.BorderSizePixel = 0
    local FillCorner = Instance.new("UICorner")
    FillCorner.CornerRadius = UDim.new(0,6)
    FillCorner.Parent = Fill
    Fill.Parent = SliderBackground

    local Thumb = Instance.new("Frame")
    Thumb.Size = UDim2.new(0,18,0,18)
    Thumb.Position = UDim2.new((default-min)/(max-min),-9,0.5,-9)
    Thumb.BackgroundColor3 = Color3.fromRGB(180,180,180)
    Thumb.BorderSizePixel = 0
    local ThumbCorner = Instance.new("UICorner")
    ThumbCorner.CornerRadius = UDim.new(1,0)
    ThumbCorner.Parent = Thumb
    Thumb.Parent = SliderBackground

    local dragging = false
    local currentValue = default

    local function startDrag()
        dragging = true
        MainFrame.Active = false
    end
    local function stopDrag()
        dragging = false
        MainFrame.Active = true
    end
    local function updateSlider(inputPos)
        local barPos = SliderBackground.AbsolutePosition
        local barSize = SliderBackground.AbsoluteSize
        local relativeX = math.clamp(inputPos.X - barPos.X, 0, barSize.X)
        local alpha = relativeX / barSize.X
        currentValue = min + (max - min) * alpha
        currentValue = math.floor(currentValue * 100 + 0.5) / 100
        Fill.Size = UDim2.new(alpha,0,1,0)
        Thumb.Position = UDim2.new(alpha,-9,0.5,-9)
        Label.Text = name .. ": " .. currentValue
        if callback then callback(currentValue) end
    end

    SliderBackground.MouseButton1Down:Connect(function()
        startDrag()
        local mousePos = UserInputService:GetMouseLocation()
        updateSlider(mousePos)
    end)
    SliderBackground.TouchTap:Connect(function()
        startDrag()
        local touchPos = UserInputService:GetMouseLocation()
        updateSlider(touchPos)
    end)
    SliderBackground.TouchMoved:Connect(function(touch)
        if dragging then updateSlider(touch.Position) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and dragging then stopDrag() end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local pos = UserInputService:GetMouseLocation()
            updateSlider(pos)
        end
    end)

    return {
        Set = function(val)
            currentValue = val
            local alpha = (val-min)/(max-min)
            Fill.Size = UDim2.new(alpha,0,1,0)
            Thumb.Position = UDim2.new(alpha,-9,0.5,-9)
            Label.Text = name .. ": " .. val
        end,
        Get = function() return currentValue end
    }
end

local function CreateColorPicker(name, parent, defaultColor, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1,0,0,50)
    Frame.BackgroundColor3 = Color3.fromRGB(28,28,28)
    Frame.BorderSizePixel = 0
    local FCorner = Instance.new("UICorner")
    FCorner.CornerRadius = UDim.new(0,4)
    FCorner.Parent = Frame
    Frame.Parent = parent

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0,120,1,0)
    Label.Position = UDim2.new(0,12,0,0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(220,220,220)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local ColorPreview = Instance.new("Frame")
    ColorPreview.Size = UDim2.new(0,30,0,30)
    ColorPreview.Position = UDim2.new(1,-42,0.5,-15)
    ColorPreview.BackgroundColor3 = defaultColor
    ColorPreview.BorderSizePixel = 0
    local CPCorner = Instance.new("UICorner")
    CPCorner.CornerRadius = UDim.new(0,4)
    CPCorner.Parent = ColorPreview
    ColorPreview.Parent = Frame

    local currentColor = defaultColor

    CreateSlider("R", parent, 0, 255, defaultColor.R * 255, function(val)
        currentColor = Color3.fromRGB(val, currentColor.G*255, currentColor.B*255)
        ColorPreview.BackgroundColor3 = currentColor
        VisualsSettings.ChamColor = currentColor
        if callback then callback(currentColor) end
        UpdateAllChams()
    end)
    CreateSlider("G", parent, 0, 255, defaultColor.G * 255, function(val)
        currentColor = Color3.fromRGB(currentColor.R*255, val, currentColor.B*255)
        ColorPreview.BackgroundColor3 = currentColor
        VisualsSettings.ChamColor = currentColor
        if callback then callback(currentColor) end
        UpdateAllChams()
    end)
    CreateSlider("B", parent, 0, 255, defaultColor.B * 255, function(val)
        currentColor = Color3.fromRGB(currentColor.R*255, currentColor.G*255, val)
        ColorPreview.BackgroundColor3 = currentColor
        VisualsSettings.ChamColor = currentColor
        if callback then callback(currentColor) end
        UpdateAllChams()
    end)

    return { Set = function(col) currentColor = col; ColorPreview.BackgroundColor3 = col end, Get = function() return currentColor end }
end

-- ==================== ЗАПОЛНЕНИЕ ВСЕХ ВКЛАДОК ====================
-- Aimbot
CreateToggle("Enable Aimbot", tabContents["Aimbot"], false, function(val) AimbotSettings.Enabled = val end)
CreateSlider("FOV", tabContents["Aimbot"], 30, 600, 120, function(val) AimbotSettings.FOV = val end)
CreateSlider("Smoothness", tabContents["Aimbot"], 1, 20, 1, function(val) AimbotSettings.Smoothness = val end)
CreateToggle("Auto Fire", tabContents["Aimbot"], false, function(val) AimbotSettings.AutoFire = val end)
CreateToggle("Wallbang", tabContents["Aimbot"], false, function(val) AimbotSettings.Wallbang = val end)

-- Visuals
CreateToggle("Enable ESP", tabContents["Visuals"], false, function(val)
    VisualsSettings.ESPEnabled = val
    if not val then for player, _ in pairs(espFrames) do RemoveESPFrame(player) end end
end)
CreateToggle("Enable Chams", tabContents["Visuals"], false, function(val)
    VisualsSettings.ChamsEnabled = val
    UpdateAllChams()
end)
CreateColorPicker("Cham Color", tabContents["Visuals"], Color3.fromRGB(255,0,0), function(col)
    VisualsSettings.ChamColor = col
    UpdateAllChams()
end)
CreateSlider("Chams Transparency", tabContents["Visuals"], 0, 1, 0.3, function(val)
    VisualsSettings.ChamsTransparency = val
    UpdateAllChams()
end)

-- Misc
CreateToggle("Bunny Hop", tabContents["Misc"], false, function(val) MiscSettings.BHopEnabled = val end)
CreateSlider("BHop Speed", tabContents["Misc"], 16, 50, 16, function(val) MiscSettings.BHopSpeed = val end)
CreateToggle("Third Person", tabContents["Misc"], false, function(val)
    MiscSettings.ThirdPersonEnabled = val
    if val then EnableThirdPerson() else DisableThirdPerson() end
end)
CreateSlider("TP Distance", tabContents["Misc"], 2, 20, 8, function(val)
    MiscSettings.ThirdPersonDistance = val
    if MiscSettings.ThirdPersonEnabled then
        pcall(function()
            LocalPlayer.CameraMaxZoomDistance = val
            LocalPlayer.CameraMinZoomDistance = val
        end)
    end
end)

-- Anti-Aim
CreateToggle("Enable Anti-Aim", tabContents["Anti-Aim"], false, function(val) AntiAimSettings.Enabled = val end)
CreateToggle("Jitter", tabContents["Anti-Aim"], false, function(val) AntiAimSettings.Jitter = val end)
CreateSlider("Jitter Range", tabContents["Anti-Aim"], 5, 90, 45, function(val) AntiAimSettings.JitterRange = val end)
CreateSlider("Pitch", tabContents["Anti-Aim"], -89, 89, 0, function(val) AntiAimSettings.Pitch = val end)
CreateSlider("Yaw", tabContents["Anti-Aim"], -180, 180, 180, function(val) AntiAimSettings.Yaw = val end)
CreateSlider("Spin Speed", tabContents["Anti-Aim"], 0, 50, 10, function(val) AntiAimSettings.SpinSpeed = val end)

-- ==================== ПРИНУДИТЕЛЬНОЕ ОБНОВЛЕНИЕ CANVAS ====================
-- Даём время на создание элементов
task.wait(0.1)
for name, content in pairs(tabContents) do
    local layout = content:FindFirstChildOfClass("UIListLayout")
    if layout then
        content.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y + 20)
    end
end

-- ==================== ОТКРЫТИЕ/ЗАКРЫТИЕ МЕНЮ ====================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.Delete and not gameProcessed then
        ToggleMinimize()
    end
end)

-- ==================== ГЛАВНЫЙ ЦИКЛ ====================
RunService.RenderStepped:Connect(function(delta)
    UpdateESP()

    -- Aimbot
    if AimbotSettings.Enabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
        local viewportSize = Camera.ViewportSize
        local center = Vector2.new(viewportSize.X/2, viewportSize.Y/2)
        local closestDist = AimbotSettings.FOV
        local bestTarget = nil

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            if not IsAlive(player) then continue end
            if IsTeammate(player) then continue end

            local targetPart = player.Character:FindFirstChild(AimbotSettings.HitPart) or player.Character:FindFirstChild("Head")
            if not targetPart then continue end
            if not AimbotSettings.Wallbang and not IsVisible(targetPart.Position) then continue end

            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    bestTarget = targetPart
                end
            end
        end

        if bestTarget then
            local targetPos = bestTarget.Position
            local newCF = CFrame.new(Camera.CFrame.Position, targetPos)
            Camera.CFrame = Camera.CFrame:Lerp(newCF, 1/AimbotSettings.Smoothness)

            if AimbotSettings.AutoFire and tick() - autoFireCooldown > 0.3 then
                autoFireCooldown = tick()
                FireWeapon()
            end
        end
    end

    -- BHop
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        local humanoid = LocalPlayer.Character.Humanoid
        if MiscSettings.BHopEnabled then
            humanoid.WalkSpeed = MiscSettings.BHopSpeed
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) and humanoid.MoveDirection.Magnitude > 0 and humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid.JumpPower = MiscSettings.BHopSpeed * 3
                humanoid.Jump = true
            end
        else
            if humanoid.WalkSpeed ~= 16 then humanoid.WalkSpeed = 16 end
            if humanoid.JumpPower ~= 50 then humanoid.JumpPower = 50 end
        end
    end

    -- Anti-Aim
    if AntiAimSettings.Enabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local root = LocalPlayer.Character.HumanoidRootPart
        if AntiAimSettings.Jitter then
            jitterOffset = jitterOffset + (5 * jitterDirection)
            if math.abs(jitterOffset) >= AntiAimSettings.JitterRange then
                jitterDirection = jitterDirection * -1
            end
        else
            jitterOffset = 0
        end
        local pitch = math.rad(AntiAimSettings.Pitch)
        local yaw = math.rad(AntiAimSettings.Yaw + (tick() * AntiAimSettings.SpinSpeed * 10 % 360) + jitterOffset)
        local cf = CFrame.new(root.Position) * CFrame.Angles(pitch, yaw, 0)
        root.CFrame = cf
    end
end)

-- ==================== ОБРАБОТЧИКИ ====================
local function OnCharacterAdded(character)
    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end
    if player == LocalPlayer then
        if MiscSettings.BHopEnabled and character:FindFirstChild("Humanoid") then
            character.Humanoid.WalkSpeed = MiscSettings.BHopSpeed
        end
        if MiscSettings.ThirdPersonEnabled then
            wait(0.2)
            EnableThirdPerson()
        end
    else
        if VisualsSettings.ChamsEnabled then
            wait(0.1)
            ApplyChamToCharacter(character, true, VisualsSettings.ChamColor, VisualsSettings.ChamsTransparency)
        end
        if espFrames[player] then RemoveESPFrame(player) end
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    player.CharacterAdded:Connect(OnCharacterAdded)
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(OnCharacterAdded)
end)

Players.PlayerRemoving:Connect(function(player)
    if espFrames[player] then RemoveESPFrame(player) end
end)

print("Cb Ro Cheat Loaded – все вкладки работают! DEL для меню.")
