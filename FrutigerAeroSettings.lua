--[[
    FRUTIGER AERO SETTINGS MENU
    Single-file Roblox LocalScript
    Place in StarterPlayer > StarterPlayerScripts.
    Client-side UI only. No server scripts or RemoteEvents.
]]

--==================================================
-- Defaults
--==================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FILE_NAME = "FrutigerAeroConfig.json"

local Defaults = {
    MenuKey = "RightShift",
    Theme = "Aqua",
    Accent = Color3.fromRGB(55, 210, 210),
    Background = Color3.fromRGB(175, 235, 240),
    Text = Color3.fromRGB(35, 85, 100),
    Transparency = 0.18,
    Radius = 16,
    Blur = 12,
    Scale = 1,
    AnimationSpeed = 1,
    Font = "Gotham",
    Bubbles = true,
    Shadows = true,
    Gloss = true,
    Sound = false,
    Volume = 0.5,
    PerformanceMode = false,
    AutoPerformance = false,
    FPSCounter = false,
    PingCounter = false,
    WindowPosition = {0.5, 0, 0.5, 0},
    WindowSize = {650, 450},
    LastTab = "Home",
    ButtonStyle = "Glossy Aqua",
    ButtonNormal = Color3.fromRGB(75, 205, 210),
    ButtonHover = Color3.fromRGB(110, 235, 235),
    ButtonPressed = Color3.fromRGB(35, 165, 175),
    ButtonDisabled = Color3.fromRGB(140, 160, 165),
    ButtonBorder = Color3.fromRGB(220, 255, 255),
    ButtonBorderThickness = 1.5,
    ButtonGloss = 0.7,
    ButtonRadius = 14,
    ButtonGradient = 90,
    ButtonPadding = 8,
    ButtonWidth = 150,
    ButtonHeight = 42,
    ButtonLayout = "Grid",
    ButtonSpacing = 8,
    ButtonGlow = true,
    ButtonLift = true,
    ButtonScale = true,
    ButtonShine = true,
    ButtonSquish = true,
    ButtonRipple = true,
    ButtonSink = false,
    ButtonIconOnly = false,
    ButtonTextStroke = false,
    ButtonFont = "GothamBold",
    JumpReplace = false,
    JumpHideDefault = false,
    JumpSize = 70,
    JumpX = 0.87,
    JumpY = 0.76,
    JumpOpacity = 0.15,
    JumpShape = "Circle",
    JumpColor = Color3.fromRGB(60, 200, 205),
    JumpIcon = "⬆️",
    JumpPressEffect = true,
    JumpSound = false,
    JumpHold = false,
    JumpEdit = false,
    JumpLocked = true,
    JumpGrid = true,
    Anchor = "Center",
}

local Themes = {
    Aqua = {
        Accent = Color3.fromRGB(55, 210, 210),
        Background = Color3.fromRGB(175, 235, 240),
        Text = Color3.fromRGB(35, 85, 100),
    },
    Sky = {
        Accent = Color3.fromRGB(75, 165, 245),
        Background = Color3.fromRGB(180, 220, 255),
        Text = Color3.fromRGB(35, 70, 120),
    },
    Meadow = {
        Accent = Color3.fromRGB(100, 205, 130),
        Background = Color3.fromRGB(195, 240, 205),
        Text = Color3.fromRGB(40, 95, 60),
    },
    Sunset = {
        Accent = Color3.fromRGB(255, 160, 115),
        Background = Color3.fromRGB(255, 220, 195),
        Text = Color3.fromRGB(125, 70, 65),
    },
    ["Dark Glass"] = {
        Accent = Color3.fromRGB(65, 195, 200),
        Background = Color3.fromRGB(35, 65, 80),
        Text = Color3.fromRGB(230, 250, 255),
    },
}

local Config = {}
for key, value in pairs(Defaults) do
    Config[key] = typeof(value) == "table" and table.clone(value) or value
end

local Profiles = {Default = table.clone(Config)}
local CurrentProfile = "Default"
local History, Future = {}, {}
local Connections = {}
local Destroyed = false
local MenuOpen = true
local CurrentTab = "Home"
local ButtonObjects = {}
local Menu = {}

--==================================================
-- Theme
--==================================================

local function palette()
    return {
        Accent = Config.Accent,
        Background = Config.Background,
        Text = Config.Text,
        White = Color3.new(1, 1, 1),
    }
end

--==================================================
-- Utils
--==================================================

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Connections, connection)
    return connection
end

local function make(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function round(parent, radius)
    return make("UICorner", {
        CornerRadius = UDim.new(0, radius or Config.Radius),
    }, parent)
end

local function outline(parent, color, thickness, transparency)
    return make("UIStroke", {
        Color = color or Color3.new(1, 1, 1),
        Thickness = thickness or 1,
        Transparency = transparency or 0.3,
    }, parent)
end

local function paint(parent, first, last, rotation)
    return make("UIGradient", {
        Color = ColorSequence.new(first, last),
        Rotation = rotation or 90,
    }, parent)
end

local function animate(object, properties, duration)
    if not object or not object.Parent then return end
    local speed = math.max(Config.AnimationSpeed, 0.1)
    local info = TweenInfo.new(
        duration or 0.2 / speed,
        Enum.EasingStyle.Quint,
        Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(object, info, properties)
    tween:Play()
    return tween
end

local function label(parent, text, size, position, font, color)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        Size = size,
        Position = position,
        Font = font or Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = color or Config.Text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

local function snapshot()
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(Config)
    end)
    if ok then
        table.insert(History, encoded)
        if #History > 30 then table.remove(History, 1) end
        Future = {}
    end
end

local function save()
    Profiles[CurrentProfile] = table.clone(Config)
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode({
            Config = Config,
            Profiles = Profiles,
            CurrentProfile = CurrentProfile,
        })
    end)
    if not ok then return false end

    local success = pcall(function()
        if type(writefile) == "function" then
            writefile(FILE_NAME, encoded)
        end
    end)
    return success
end

local function load()
    local ok, contents = pcall(function()
        if type(isfile) == "function"
            and type(readfile) == "function"
            and isfile(FILE_NAME) then
            return readfile(FILE_NAME)
        end
    end)
    if not ok or not contents then return false end

    local decodedOK, data = pcall(function()
        return HttpService:JSONDecode(contents)
    end)
    if not decodedOK or type(data) ~= "table" then return false end

    if type(data.Config) == "table" then
        for key, value in pairs(data.Config) do
            if Defaults[key] ~= nil then Config[key] = value end
        end
    end
    if type(data.Profiles) == "table" then Profiles = data.Profiles end
    if type(data.CurrentProfile) == "string" then CurrentProfile = data.CurrentProfile end
    return true
end

local function hasFileAccess()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
end

local function toast(message)
    local item = make("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 12),
        Size = UDim2.fromOffset(300, 42),
        BackgroundColor3 = Config.Accent,
        BackgroundTransparency = 0.08,
        Text = tostring(message),
        TextColor3 = Config.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        ZIndex = 100,
    }, Screen)
    round(item, 14)
    outline(item, Color3.new(1, 1, 1), 1, 0.2)
    item.TextTransparency = 1
    animate(item, {TextTransparency = 0}, 0.2)
    task.delay(2.5, function()
        if item.Parent then
            animate(item, {
                TextTransparency = 1,
                BackgroundTransparency = 1,
            }, 0.25)
            task.wait(0.3)
            if item.Parent then item:Destroy() end
        end
    end)
end

local function setSetting(key, value)
    if Defaults[key] == nil then return end
    snapshot()
    Config[key] = value
    save()
    if applyTheme then applyTheme() end
end

local function resetSetting(key)
    if Defaults[key] == nil then return end
    local value = Defaults[key]
    setSetting(key, typeof(value) == "table" and table.clone(value) or value)
    toast(key .. " reset")
end

--==================================================
-- Icons
--==================================================

local Icons = {
    Home = "🏠",
    Settings = "⚙️",
    Themes = "🎨",
    Buttons = "⭐",
    Jump = "⬆️",
    Performance = "🚀",
    Credits = "✨",
    Search = "🔍",
    Close = "✖",
    Minimize = "－",
    Reset = "↺",
    Save = "💾",
    Export = "📋",
    Import = "⬆️",
    Bubble = "🫧",
    Favorite = "⭐",
}

local function drawIcon(parent, name, position, size)
    local text = Icons[name] or "●"
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        TextSize = size or 18,
        Size = UDim2.fromOffset(size or 18, size or 18),
        Position = position or UDim2.new(),
        TextColor3 = Config.Text,
        Font = Enum.Font.GothamBold,
    }, parent)
end

--==================================================
-- Components
--==================================================

local Screen = make("ScreenGui", {
    Name = "FrutigerAeroMenu",
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local Root = make("Frame", {
    Name = "Window",
    Size = UDim2.fromOffset(Config.WindowSize[1], Config.WindowSize[2]),
    Position = UDim2.new(
        Config.WindowPosition[1],
        Config.WindowPosition[2],
        Config.WindowPosition[3],
        Config.WindowPosition[4]
    ),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Config.Background,
    BackgroundTransparency = Config.Transparency,
    BorderSizePixel = 0,
    ClipsDescendants = false,
}, Screen)
round(Root, Config.Radius)
outline(Root, Color3.new(1, 1, 1), 2, 0.12)
paint(Root, Color3.fromRGB(230, 255, 255), Config.Background, 135)

local Shadow = make("Frame", {
    Name = "Shadow",
    Position = UDim2.fromOffset(5, 8),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(30, 100, 120),
    BackgroundTransparency = 0.75,
    ZIndex = 0,
}, Root)
round(Shadow, Config.Radius + 4)
Root.ZIndex = 2

local Header = make("Frame", {
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundTransparency = 1,
}, Root)

local Logo = label(
    Header, "🫧 FRUTIGER AERO",
    UDim2.new(0, 220, 1, 0),
    UDim2.fromOffset(16, 0),
    Enum.Font.GothamBold
)
Logo.TextSize = 16

local Sidebar = make("Frame", {
    Position = UDim2.fromOffset(8, 55),
    Size = UDim2.new(0, 145, 1, -65),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.7,
}, Root)
round(Sidebar, 12)
outline(Sidebar, Color3.new(1, 1, 1), 1, 0.5)

local Content = make("ScrollingFrame", {
    Position = UDim2.fromOffset(162, 55),
    Size = UDim2.new(1, -172, 1, -65),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.72,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Config.Accent,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, Root)
round(Content, 12)
outline(Content, Color3.new(1, 1, 1), 1, 0.5)

make("UIListLayout", {
    Padding = UDim.new(0, 9),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Content)
make("UIPadding", {
    PaddingTop = UDim.new(0, 12),
    PaddingBottom = UDim.new(0, 12),
    PaddingLeft = UDim.new(0, 12),
    PaddingRight = UDim.new(0, 12),
}, Content)

local function card(parent, height)
    local frame = make("Frame", {
        Size = UDim2.new(1, -4, 0, height or 60),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
    }, parent)
    round(frame, 12)
    outline(frame, Color3.new(1, 1, 1), 1, 0.45)
    return frame
end

local function makeButton(parent, text, size, position, callback)
    local b = make("TextButton", {
        Size = size,
        Position = position,
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Config.Text,
        BackgroundColor3 = Config.Accent,
        BackgroundTransparency = 0.12,
        AutoButtonColor = false,
    }, parent)
    round(b, Config.ButtonRadius)
    outline(b, Color3.new(1, 1, 1), 1, 0.35)
    paint(b, Color3.new(1, 1, 1), Config.Accent, Config.ButtonGradient)

    local shine = make("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.8,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -8, 0, 8),
        Position = UDim2.fromOffset(4, 3),
    }, b)
    round(shine, 20)

    connect(b.MouseEnter, function()
        animate(b, {
            BackgroundColor3 = Config.ButtonHover,
            Size = size + UDim2.fromOffset(2, 2),
        }, 0.15)
    end)
    connect(b.MouseLeave, function()
        animate(b, {
            BackgroundColor3 = Config.ButtonNormal,
            Size = size,
        }, 0.15)
    end)
    connect(b.MouseButton1Down, function()
        animate(b, {Size = size - UDim2.fromOffset(3, 3)}, 0.08)
    end)
    connect(b.MouseButton1Up, function()
        animate(b, {Size = size}, 0.12)
    end)
    connect(b.Activated, function()
        if callback then
            local ok, err = pcall(callback)
            if not ok then warn("[Aero] Button error:", err) end
        end
    end)
    return b
end

local closeButton = makeButton(
    Header, "✕",
    UDim2.fromOffset(34, 32),
    UDim2.new(1, -42, 0, 8),
    function()
        MenuOpen = false
        Root.Visible = false
    end
)

local Content -- forward reference is already assigned above

local minimizeButton = makeButton(
    Header, "－",
    UDim2.fromOffset(34, 32),
    UDim2.new(1, -82, 0, 8),
    function()
        local minimized = Root:GetAttribute("Minimized")
        Root:SetAttribute("Minimized", not minimized)
        Root.ClipsDescendants = not minimized
        animate(Root, {
            Size = minimized
                and UDim2.fromOffset(Config.WindowSize[1], Config.WindowSize[2])
                or UDim2.fromOffset(Config.WindowSize[1], 48),
        }, 0.25)
        Content.Visible = not minimized
        Sidebar.Visible = not minimized
    end
)

local function section(parent, text)
    local l = label(parent, text, UDim2.new(1, -10, 0, 28), UDim2.fromOffset(4, 0), Enum.Font.GothamBold)
    l.TextSize = 16
    return l
end

local function resetButton(parent, key)
    return makeButton(parent, "↺", UDim2.fromOffset(30, 28), UDim2.new(1, -38, 0, 15), function()
        resetSetting(key)
    end)
end

-- One registry row adds a setting to the generated settings UI.
local Registry = {
    {key = "Transparency", name = "Panel transparency", type = "slider", min = 0, max = 0.8},
    {key = "Radius", name = "Corner radius", type = "slider", min = 0, max = 35},
    {key = "Blur", name = "Background blur", type = "slider", min = 0, max = 30},
    {key = "Scale", name = "UI scale", type = "slider", min = 0.65, max = 1.4},
    {key = "AnimationSpeed", name = "Animation speed", type = "slider", min = 0.2, max = 3},
    {key = "Bubbles", name = "Floating bubbles", type = "toggle"},
    {key = "Shadows", name = "Soft shadows", type = "toggle"},
    {key = "Gloss", name = "Gloss effects", type = "toggle"},
    {key = "Sound", name = "Interface sounds", type = "toggle"},
    {key = "Volume", name = "Sound volume", type = "slider", min = 0, max = 1},
    {key = "FPSCounter", name = "FPS counter", type = "toggle"},
    {key = "PingCounter", name = "Ping counter", type = "toggle"},
    {key = "PerformanceMode", name = "Performance mode", type = "toggle"},
    {key = "AutoPerformance", name = "Automatic low FPS mode", type = "toggle"},
}

local function makeToggle(parent, item)
    local f = card(parent, 54)
    label(f, item.name, UDim2.new(0.7, 0, 1, 0), UDim2.fromOffset(12, 0))
    local toggle = make("TextButton", {
        Size = UDim2.fromOffset(42, 23),
        Position = UDim2.new(1, -55, 0.5, -11),
        BackgroundColor3 = Config[item.key] and Config.Accent or Color3.fromRGB(150, 170, 175),
        Text = "",
        AutoButtonColor = false,
    }, f)
    round(toggle, 20)
    local knob = make("Frame", {
        Size = UDim2.fromOffset(17, 17),
        Position = UDim2.new(Config[item.key] and 1 or 0, Config[item.key] and -20 or 3, 0.5, -8),
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, toggle)
    round(knob, 20)
    connect(toggle.Activated, function()
        setSetting(item.key, not Config[item.key])
        animate(toggle, {
            BackgroundColor3 = Config[item.key] and Config.Accent or Color3.fromRGB(150, 170, 175),
        })
        animate(knob, {
            Position = UDim2.new(Config[item.key] and 1 or 0, Config[item.key] and -20 or 3, 0.5, -8),
        })
    end)
    resetButton(f, item.key)
end

local function makeSlider(parent, item)
    local f = card(parent, 72)
    label(f, item.name, UDim2.new(0.65, 0, 0, 25), UDim2.fromOffset(12, 4))
    local valueLabel = label(f, "", UDim2.new(0, 90, 0, 22), UDim2.new(1, -100, 0, 4), Enum.Font.GothamBold)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right

    local track = make("Frame", {
        Position = UDim2.fromOffset(12, 43),
        Size = UDim2.new(1, -65, 0, 8),
        BackgroundColor3 = Color3.fromRGB(170, 200, 205),
    }, f)
    round(track, 10)
    local fill = make("Frame", {
        BackgroundColor3 = Config.Accent,
        Size = UDim2.new(0, 0, 1, 0),
    }, track)
    round(fill, 10)
    local knob = make("Frame", {
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Color3.new(1, 1, 1),
        Position = UDim2.new(0, -8, 0.5, -8),
    }, track)
    round(knob, 20)
    outline(knob, Config.Accent, 2)

    local dragging = false
    local function update(x, commit)
        local pct = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local value = item.min + pct * (item.max - item.min)
        if item.max - item.min > 5 then
            value = math.floor(value + 0.5)
        else
            value = math.floor(value * 100 + 0.5) / 100
        end
        Config[item.key] = value
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, -8, 0.5, -8)
        valueLabel.Text = tostring(value)
        if commit then
            snapshot()
            save()
            applyTheme()
        end
    end

    local initial = math.clamp((Config[item.key] - item.min) / (item.max - item.min), 0, 1)
    update(track.AbsolutePosition.X + track.AbsoluteSize.X * initial, false)

    connect(track.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input.Position.X, false)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X, false)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            update(input.Position.X, true)
        end
    end)
    resetButton(f, item.key)
end

local function makeDropdown(parent, title, key, options)
    local f = card(parent, 58)
    label(f, title, UDim2.new(0.45, 0, 1, 0), UDim2.fromOffset(12, 0))
    local b
    b = makeButton(f, tostring(Config[key]), UDim2.fromOffset(130, 32), UDim2.new(1, -145, 0.5, -16), function()
        local index = table.find(options, Config[key]) or 0
        index = index % #options + 1
        setSetting(key, options[index])
        b.Text = tostring(Config[key])
    end)
    resetButton(f, key)
    return b
end

local function makeColor(parent, title, key)
    local f = card(parent, 54)
    label(f, title, UDim2.new(0.65, 0, 1, 0), UDim2.fromOffset(12, 0))
    local choices = {
        Color3.fromRGB(55, 210, 210),
        Color3.fromRGB(75, 165, 245),
        Color3.fromRGB(100, 205, 130),
        Color3.fromRGB(255, 160, 115),
        Color3.new(1, 1, 1),
        Color3.fromRGB(35, 65, 80),
        Color3.fromRGB(190, 130, 240),
    }
    local swatch = make("TextButton", {
        Size = UDim2.fromOffset(55, 28),
        Position = UDim2.new(1, -70, 0.5, -14),
        BackgroundColor3 = Config[key],
        Text = "",
    }, f)
    round(swatch, 8)
    outline(swatch, Color3.new(1, 1, 1), 1)
    connect(swatch.Activated, function()
        local index = 1
        for i, c in ipairs(choices) do
            if Config[key] == c then index = i break end
        end
        index = index % #choices + 1
        setSetting(key, choices[index])
        swatch.BackgroundColor3 = Config[key]
    end)
    resetButton(f, key)
end

local function makeTextInput(parent, title, key)
    local f = card(parent, 62)
    label(f, title, UDim2.new(0.4, 0, 1, 0), UDim2.fromOffset(12, 0))
    local input = make("TextBox", {
        Size = UDim2.new(0.48, 0, 0, 32),
        Position = UDim2.new(0.44, 0, 0.5, -16),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.5,
        Text = tostring(Config[key]),
        TextColor3 = Config.Text,
        PlaceholderText = "Enter value",
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ClearTextOnFocus = false,
    }, f)
    round(input, 8)
    connect(input.FocusLost, function()
        local number = tonumber(input.Text)
        if number then
            setSetting(key, number)
        else
            input.Text = tostring(Config[key])
        end
    end)
    resetButton(f, key)
end

--==================================================
-- Tabs
--==================================================

local TabNames = {"Home", "Settings", "Themes", "Buttons", "Jump Button", "Performance", "Credits"}
local TabButtons = {}
local TabBuilders = {}

local function clearContent()
    for _, child in ipairs(Content:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
end

local function addTitle(text)
    local l = label(Content, text, UDim2.new(1, -10, 0, 32), UDim2.new(), Enum.Font.GothamBold)
    l.TextSize = 20
    return l
end

local function buildHome()
    addTitle("Welcome to Aero 🌊")
    local welcome = card(Content, 110)
    local heading = label(welcome, "A breath of fresh air.", UDim2.new(1, -24, 0, 35), UDim2.fromOffset(12, 8), Enum.Font.GothamBold)
    heading.TextSize = 20
    label(welcome, "Your personal glossy settings experience.\nCustomize your interface and make it yours!", UDim2.new(1, -24, 0, 50), UDim2.fromOffset(12, 47))
    local info = card(Content, 65)
    label(info, "Current profile: " .. CurrentProfile .. "\nTheme: " .. Config.Theme, UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0))
    makeButton(Content, "⚙️ Open Settings", UDim2.new(1, -4, 0, 40), UDim2.new(), function() openTab("Settings") end)
    makeButton(Content, "🎨 Explore Themes", UDim2.new(1, -4, 0, 40), UDim2.new(), function() openTab("Themes") end)
    makeButton(Content, "↺ Undo", UDim2.new(1, -4, 0, 40), UDim2.new(), function() Menu:Undo() end)
    makeButton(Content, "↪ Redo", UDim2.new(1, -4, 0, 40), UDim2.new(), function() Menu:Redo() end)
end

local function buildSettings()
    addTitle("General Settings")
    for _, item in ipairs(Registry) do
        if item.type == "toggle" then
            makeToggle(Content, item)
        elseif item.type == "slider" then
            makeSlider(Content, item)
        end
    end
    section(Content, "Appearance")
    makeDropdown(Content, "Font", "Font", {"Gotham", "GothamBold", "SourceSans", "Arial", "ArialBold", "Code", "Cartoon"})
    makeDropdown(Content, "Menu anchor", "Anchor", {"Center", "TopLeft", "TopRight", "BottomLeft", "BottomRight"})
    makeDropdown(Content, "Menu key", "MenuKey", {"RightShift", "LeftControl", "F4", "F6", "F8"})
    makeColor(Content, "Accent color", "Accent")
    makeColor(Content, "Background color", "Background")
    makeColor(Content, "Text color", "Text")

    makeButton(Content, "Reset all settings", UDim2.new(1, -4, 0, 40), UDim2.new(), function()
        local confirmation = card(Content, 65)
        label(confirmation, "Reset everything?", UDim2.new(0.55, 0, 1, 0), UDim2.fromOffset(10, 0))
        makeButton(confirmation, "YES", UDim2.fromOffset(65, 32), UDim2.new(1, -145, 0.5, -16), function()
            snapshot()
            for key, value in pairs(Defaults) do
                Config[key] = typeof(value) == "table" and table.clone(value) or value
            end
            save()
            applyTheme()
            openTab("Settings")
            toast("All settings reset!")
        end)
        makeButton(confirmation, "NO", UDim2.fromOffset(65, 32), UDim2.new(1, -75, 0.5, -16), function()
            confirmation:Destroy()
        end)
    end)
end

local function buildThemes()
    addTitle("Choose your atmosphere")
    for name, colors in pairs(Themes) do
        local f = card(Content, 68)
        label(f, name, UDim2.new(0.5, 0, 1, 0), UDim2.fromOffset(12, 0), Enum.Font.GothamBold)
        local preview = make("Frame", {
            Position = UDim2.new(0.55, 0, 0.5, -15),
            Size = UDim2.fromOffset(65, 30),
            BackgroundColor3 = colors.Accent,
        }, f)
        round(preview, 10)
        paint(preview, Color3.new(1, 1, 1), colors.Background)
        makeButton(f, "APPLY", UDim2.fromOffset(65, 32), UDim2.new(1, -78, 0.5, -16), function()
            snapshot()
            Config.Theme = name
            Config.Accent = colors.Accent
            Config.Background = colors.Background
            Config.Text = colors.Text
            save()
            applyTheme()
            toast(name .. " theme applied")
        end)
    end
    section(Content, "Custom colors")
    makeColor(Content, "Accent", "Accent")
    makeColor(Content, "Background", "Background")
    makeColor(Content, "Text", "Text")
end

--==================================================
-- Systems: Button customization
--==================================================

local function buildButtons()
    addTitle("Button Studio ⭐")
    makeDropdown(Content, "Button style", "ButtonStyle", {"Glossy Aqua", "Flat Glass", "Pill", "Square", "Round Orb"})
    makeColor(Content, "Normal", "ButtonNormal")
    makeColor(Content, "Hover", "ButtonHover")
    makeColor(Content, "Pressed", "ButtonPressed")
    makeColor(Content, "Disabled", "ButtonDisabled")
    makeColor(Content, "Border", "ButtonBorder")
    makeSlider(Content, {key = "ButtonGloss", name = "Gloss intensity", min = 0, max = 1})
    makeSlider(Content, {key = "ButtonRadius", name = "Button radius", min = 0, max = 40})
    makeSlider(Content, {key = "ButtonBorderThickness", name = "Border thickness", min = 0, max = 5})
    makeSlider(Content, {key = "ButtonGradient", name = "Gradient direction", min = 0, max = 360})
    makeSlider(Content, {key = "ButtonWidth", name = "Button width", min = 70, max = 300})
    makeSlider(Content, {key = "ButtonHeight", name = "Button height", min = 25, max = 100})
    makeSlider(Content, {key = "ButtonPadding", name = "Button padding", min = 0, max = 25})
    makeSlider(Content, {key = "ButtonSpacing", name = "Button spacing", min = 0, max = 30})
    makeDropdown(Content, "Layout", "ButtonLayout", {"Grid", "List"})
    makeDropdown(Content, "Button font", "ButtonFont", {"Gotham", "GothamBold", "SourceSans", "Arial"})
    for _, item in ipairs({
        {"ButtonGlow", "Hover glow"},
        {"ButtonLift", "Hover lift"},
        {"ButtonScale", "Hover scale"},
        {"ButtonShine", "Shine sweep"},
        {"ButtonSquish", "Press squish"},
        {"ButtonRipple", "Press ripple"},
        {"ButtonSink", "Press sink"},
        {"ButtonIconOnly", "Icon only"},
        {"ButtonTextStroke", "Text stroke"},
    }) do
        makeToggle(Content, {key = item[1], name = item[2]})
    end
    section(Content, "Live preview")
    local preview = makeButton(Content, "✨ Aero Preview", UDim2.fromOffset(Config.ButtonWidth, Config.ButtonHeight), UDim2.new(), function()
        toast("Button preview clicked!")
    end)
    preview.BackgroundColor3 = Config.ButtonNormal
end

--==================================================
-- Systems: Jump button
--==================================================

local JumpGui, JumpButton, JumpOutline, JumpRepeatConnection
local JumpDragging = false
local JumpDragStart, JumpStartPosition

local function getDefaultJump()
    local touch = playerGui:FindFirstChild("TouchGui")
    local frame = touch and touch:FindFirstChild("TouchControlFrame")
    return frame and frame:FindFirstChild("JumpButton")
end

local function adjustDefaultJump()
    local ok, button = pcall(getDefaultJump)
    if not ok or not button then return end
    pcall(function()
        button.Size = UDim2.fromOffset(Config.JumpSize, Config.JumpSize)
        button.Position = UDim2.new(Config.JumpX, 0, Config.JumpY, 0)
        button.ImageTransparency = Config.JumpOpacity
        button.Visible = not (Config.JumpHideDefault or Config.JumpReplace)
    end)
end

local function canJump()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    return humanoid.Health > 0 and humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
end

local function doJump()
    if not canJump() then return end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.Jump = true
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end

local function createJump()
    if JumpGui then JumpGui:Destroy() end
    JumpGui = make("ScreenGui", {
        Name = "AeroCustomJump",
        ResetOnSpawn = false,
        DisplayOrder = 50,
    }, playerGui)

    JumpButton = make("TextButton", {
        Name = "Jump",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(Config.JumpX, 0, Config.JumpY, 0),
        Size = UDim2.fromOffset(Config.JumpSize, Config.JumpSize),
        BackgroundColor3 = Config.JumpColor,
        BackgroundTransparency = Config.JumpOpacity,
        Text = Config.JumpIcon == "none" and "" or Config.JumpIcon,
        TextSize = 30,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        Visible = Config.JumpReplace or Config.JumpHideDefault,
    }, JumpGui)

    round(JumpButton, Config.JumpShape == "Circle" and 100 or Config.JumpShape == "Pill" and 40 or 14)
    outline(JumpButton, Color3.new(1, 1, 1), 2, 0.25)
    paint(JumpButton, Color3.new(1, 1, 1), Config.JumpColor, 90)
    JumpOutline = make("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 3, Transparency = 1}, JumpButton)

    local function jumpDown()
        if not canJump() then
            JumpButton.BackgroundColor3 = Config.ButtonDisabled
            return
        end
        if Config.JumpPressEffect then
            animate(JumpButton, {Size = UDim2.fromOffset(Config.JumpSize * 0.9, Config.JumpSize * 0.9)}, 0.08)
        end
        doJump()
        if Config.JumpHold then
            if JumpRepeatConnection then JumpRepeatConnection:Disconnect() end
            local elapsed = 0
            JumpRepeatConnection = RunService.Heartbeat:Connect(function(dt)
                elapsed += dt
                if elapsed >= 0.35 then
                    elapsed = 0
                    doJump()
                end
            end)
        end
    end

    local function jumpUp()
        if JumpRepeatConnection then
            JumpRepeatConnection:Disconnect()
            JumpRepeatConnection = nil
        end
        animate(JumpButton, {Size = UDim2.fromOffset(Config.JumpSize, Config.JumpSize)}, 0.12)
    end

    connect(JumpButton.InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if Config.JumpEdit and not Config.JumpLocked then
            JumpDragging = true
            JumpDragStart = input.Position
            JumpStartPosition = JumpButton.Position
            JumpOutline.Transparency = 0
        else
            jumpDown()
        end
    end)

    connect(JumpButton.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            JumpDragging = false
            jumpUp()
            JumpOutline.Transparency = 1
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if not JumpDragging or (input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch) then return end
        local camera = workspace.CurrentCamera
        if not camera then return end
        local delta = input.Position - JumpDragStart
        local viewport = camera.ViewportSize
        local x = math.clamp((JumpStartPosition.X.Scale * viewport.X + JumpStartPosition.X.Offset + delta.X) / viewport.X, 0.1, 0.95)
        local y = math.clamp((JumpStartPosition.Y.Scale * viewport.Y + JumpStartPosition.Y.Offset + delta.Y) / viewport.Y, 0.15, 0.9)
        if Config.JumpGrid then
            x = math.floor(x * 20 + 0.5) / 20
            y = math.floor(y * 20 + 0.5) / 20
        end
        Config.JumpX, Config.JumpY = x, y
        JumpButton.Position = UDim2.new(x, 0, y, 0)
    end)

    connect(JumpButton.Activated, function()
        if not Config.JumpEdit then doJump() end
    end)

    adjustDefaultJump()
end

local function buildJump()
    addTitle("Jump Button Studio ⬆️")
    makeToggle(Content, {key = "JumpReplace", name = "Replace default jump"})
    makeToggle(Content, {key = "JumpHideDefault", name = "Hide default jump"})
    makeSlider(Content, {key = "JumpSize", name = "Button size", min = 35, max = 150})
    makeSlider(Content, {key = "JumpX", name = "Horizontal position", min = 0.1, max = 0.95})
    makeSlider(Content, {key = "JumpY", name = "Vertical position", min = 0.15, max = 0.9})
    makeSlider(Content, {key = "JumpOpacity", name = "Transparency", min = 0, max = 0.8})
    makeDropdown(Content, "Shape", "JumpShape", {"Circle", "Rounded", "Pill"})
    makeDropdown(Content, "Icon", "JumpIcon", {"⬆️", "🦘", "🚀", "none"})
    makeColor(Content, "Button color", "JumpColor")
    makeToggle(Content, {key = "JumpPressEffect", name = "Press animation"})
    makeToggle(Content, {key = "JumpHold", name = "Hold to repeat jump"})
    makeToggle(Content, {key = "JumpEdit", name = "Edit position"})
    makeToggle(Content, {key = "JumpLocked", name = "Lock position"})
    makeToggle(Content, {key = "JumpGrid", name = "Grid snapping"})

    makeButton(Content, "Apply jump settings", UDim2.new(1, -4, 0, 42), UDim2.new(), function()
        createJump()
        save()
        toast("Jump settings applied")
    end)
    makeButton(Content, "Reset jump position", UDim2.new(1, -4, 0, 42), UDim2.new(), function()
        snapshot()
        Config.JumpX = Defaults.JumpX
        Config.JumpY = Defaults.JumpY
        Config.JumpSize = Defaults.JumpSize
        createJump()
        save()
    end)
    makeButton(Content, "Toggle jump edit lock", UDim2.new(1, -4, 0, 42), UDim2.new(), function()
        Config.JumpLocked = not Config.JumpLocked
        toast(Config.JumpLocked and "Position locked" or "Position unlocked")
    end)
end

--==================================================
-- Systems: Performance, profiles, export/import
--==================================================

local StatsLabel
local FPSValue, FrameCount, LastFPS = 60, 0, os.clock()

local function buildPerformance()
    addTitle("Performance Center 🚀")
    makeToggle(Content, {key = "PerformanceMode", name = "Performance mode"})
    makeToggle(Content, {key = "AutoPerformance", name = "Automatic low FPS mode"})
    makeToggle(Content, {key = "FPSCounter", name = "Show FPS"})
    makeToggle(Content, {key = "PingCounter", name = "Show ping"})
    StatsLabel = label(Content, "FPS: -- | Ping: --", UDim2.new(1, -4, 0, 45), UDim2.new(), Enum.Font.GothamBold)
    makeButton(Content, "Optimize interface", UDim2.new(1, -4, 0, 42), UDim2.new(), function()
        Config.PerformanceMode = true
        applyTheme()
        toast("Performance mode enabled")
    end)
end

local function buildCredits()
    addTitle("Aero Information ✨")
    local credits = card(Content, 90)
    label(credits, "FRUTIGER AERO SETTINGS\nA client-side customization experience.\nMade with Roblox native UI components.", UDim2.new(1, -24, 1, -10), UDim2.fromOffset(12, 5), Enum.Font.GothamBold)
    section(Content, "Profiles")

    makeButton(Content, "Save current profile", UDim2.new(1, -4, 0, 40), UDim2.new(), function()
        Profiles[CurrentProfile] = table.clone(Config)
        save()
        toast("Profile saved!")
    end)

    makeButton(Content, "Create new profile", UDim2.new(1, -4, 0, 40), UDim2.new(), function()
        local name = "Profile" .. tostring(#History + 1)
        Profiles[name] = table.clone(Config)
        CurrentProfile = name
        save()
        toast("Created " .. name)
    end)

    makeButton(Content, "Next profile", UDim2.new(1, -4, 0, 40), UDim2.new(), function()
        local names = {}
        for name in pairs(Profiles) do table.insert(names, name) end
        table.sort(names)
        local index = table.find(names, CurrentProfile) or 0
        CurrentProfile = names[index % #names + 1]
        snapshot()
        for key, value in pairs(Profiles[CurrentProfile]) do Config[key] = value end
        save()
        applyTheme()
        openTab("Home")
        toast("Loaded " .. CurrentProfile)
    end)

    section(Content, "Configuration transfer")
    local exportBox = make("TextBox", {
        Size = UDim2.new(1, -4, 0, 90),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.3,
        TextColor3 = Config.Text,
        Text = "",
        PlaceholderText = "Export/import configuration string...",
        TextWrapped = true,
        ClearTextOnFocus = false,
        MultiLine = true,
        Font = Enum.Font.Code,
        TextSize = 11,
    }, Content)
    round(exportBox, 10)

    makeButton(Content, "📋 Export configuration", UDim2.new(1, -4, 0, 40), UDim2.new(), function()
        exportBox.Text = HttpService:JSONEncode({
            Config = Config,
            Profiles = Profiles,
            CurrentProfile = CurrentProfile,
        })
        exportBox:CaptureFocus()
        exportBox.CursorPosition = 1
        toast("Copy the configuration text!")
    end)

    makeButton(Content, "⬆️ Import configuration", UDim2.new(1, -4, 0, 40), UDim2.new(), function()
        local ok, data = pcall(function() return HttpService:JSONDecode(exportBox.Text) end)
        if not ok or type(data) ~= "table" or type(data.Config) ~= "table" then
            toast("Invalid configuration!")
            return
        end
        snapshot()
        for key, value in pairs(data.Config) do
            if Defaults[key] ~= nil then Config[key] = value end
        end
        if type(data.Profiles) == "table" then Profiles = data.Profiles end
        if type(data.CurrentProfile) == "string" then CurrentProfile = data.CurrentProfile end
        save()
        applyTheme()
        openTab("Home")
        toast("Configuration imported!")
    end)
end

--==================================================
-- Tabs and search
--==================================================

TabBuilders.Home = buildHome
TabBuilders.Settings = buildSettings
TabBuilders.Themes = buildThemes
TabBuilders.Buttons = buildButtons
TabBuilders["Jump Button"] = buildJump
TabBuilders.Performance = buildPerformance
TabBuilders.Credits = buildCredits

function openTab(name)
    if not TabBuilders[name] then return end
    CurrentTab = name
    Config.LastTab = name
    for _, child in ipairs(Content:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    for tab, b in pairs(TabButtons) do
        b.BackgroundColor3 = tab == name and Config.Accent or Color3.new(1, 1, 1)
    end
    TabBuilders[name]()
    save()
end

local yOffset = 8
for _, name in ipairs(TabNames) do
    local tabName = name
    local b = makeButton(
        Sidebar,
        (Icons[tabName] or "●") .. "  " .. tabName,
        UDim2.new(1, -12, 0, 38),
        UDim2.fromOffset(6, yOffset),
        function() openTab(tabName) end
    )
    b.TextSize = 11
    TabButtons[tabName] = b
    yOffset += 43
end

local SearchBox = make("TextBox", {
    Size = UDim2.new(1, -4, 0, 36),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.45,
    TextColor3 = Config.Text,
    PlaceholderText = "🔍 Search settings...",
    Font = Enum.Font.Gotham,
    TextSize = 13,
    ClearTextOnFocus = false,
}, Content)
round(SearchBox, 10)

local function searchSettings(query)
    clearContent()
    addTitle("Search Results")
    query = string.lower(query)
    local count = 0
    for _, item in ipairs(Registry) do
        if string.find(string.lower(item.name), query, 1, true)
            or string.find(string.lower(item.key), query, 1, true) then
            count += 1
            if item.type == "toggle" then makeToggle(Content, item)
            elseif item.type == "slider" then makeSlider(Content, item) end
        end
    end
    for key, value in pairs(Config) do
        if string.find(string.lower(key), query, 1, true)
            and Defaults[key] ~= nil and typeof(value) == "Color3" then
            count += 1
            makeColor(Content, key, key)
        end
    end
    if count == 0 then
        local empty = card(Content, 55)
        label(empty, "No matching settings found.", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0))
    end
end

connect(SearchBox:GetPropertyChangedSignal("Text"), function()
    if SearchBox:IsFocused() then searchSettings(SearchBox.Text) end
end)
connect(SearchBox.FocusLost, function()
    if SearchBox.Text == "" then openTab(CurrentTab) end
end)

--==================================================
-- Systems: window movement and resize
--==================================================

local dragging, dragStart, startPos = false, nil, nil

connect(Header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Root.Position
    end
end)

connect(UserInputService.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Root.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

connect(UserInputService.InputEnded, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch) then
        dragging = false
        local camera = workspace.CurrentCamera
        if camera then
            local viewport = camera.ViewportSize
            local centerX = math.clamp(Root.AbsolutePosition.X + Root.AbsoluteSize.X / 2, Root.AbsoluteSize.X / 2, viewport.X - Root.AbsoluteSize.X / 2)
            local centerY = math.clamp(Root.AbsolutePosition.Y + Root.AbsoluteSize.Y / 2, Root.AbsoluteSize.Y / 2, viewport.Y - Root.AbsoluteSize.Y / 2)
            animate(Root, {Position = UDim2.fromOffset(centerX, centerY)}, 0.15)
        end
        Config.WindowPosition = {Root.Position.X.Scale, Root.Position.X.Offset, Root.Position.Y.Scale, Root.Position.Y.Offset}
        save()
    end
end)

local ResizeHandle = make("TextButton", {
    Size = UDim2.fromOffset(25, 25),
    Position = UDim2.new(1, -25, 1, -25),
    BackgroundTransparency = 1,
    Text = "◢",
    TextColor3 = Config.Text,
    TextSize = 16,
    ZIndex = 10,
}, Root)

local resizing, resizeStart, resizeSize = false, nil, nil
connect(ResizeHandle.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = input.Position
        resizeSize = Root.AbsoluteSize
    end
end)
connect(UserInputService.InputChanged, function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - resizeStart
        local width = math.clamp(resizeSize.X + delta.X, 420, 950)
        local height = math.clamp(resizeSize.Y + delta.Y, 300, 750)
        Root.Size = UDim2.fromOffset(width, height)
        Config.WindowSize = {width, height}
    end
end)
connect(UserInputService.InputEnded, function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch) then
        resizing = false
        save()
    end
end)

--==================================================
-- Systems: effects, keyboard, responsive layout
--==================================================

local BlurEffect
local function applyTheme()
    if not Root or not Root.Parent then return end
    Root.BackgroundColor3 = Config.Background
    Root.BackgroundTransparency = Config.Transparency
    local rootCorner = Root:FindFirstChildOfClass("UICorner")
    if rootCorner then rootCorner.CornerRadius = UDim.new(0, Config.Radius) end
    Shadow.Visible = Config.Shadows and not Config.PerformanceMode

    if Config.Blur > 0 and not Config.PerformanceMode then
        if not BlurEffect then
            BlurEffect = Instance.new("BlurEffect")
            BlurEffect.Name = "AeroBlur"
            BlurEffect.Parent = Lighting
        end
        BlurEffect.Size = Config.Blur
    elseif BlurEffect then
        BlurEffect.Size = 0
    end

    if JumpButton then
        JumpButton.BackgroundColor3 = Config.JumpColor
        JumpButton.Size = UDim2.fromOffset(Config.JumpSize, Config.JumpSize)
        JumpButton.Position = UDim2.new(Config.JumpX, 0, Config.JumpY, 0)
        JumpButton.BackgroundTransparency = Config.JumpOpacity
    end
end

local BubbleFolder = make("Frame", {
    Name = "BubbleLayer",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 1,
}, Root)

local BubblePool = {}
for i = 1, 12 do
    local size = math.random(8, 23)
    local bubble = make("Frame", {
        Size = UDim2.fromOffset(size, size),
        Position = UDim2.fromScale(math.random(), math.random()),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.8,
        BorderSizePixel = 0,
        ZIndex = 1,
    }, BubbleFolder)
    round(bubble, 100)
    outline(bubble, Color3.new(1, 1, 1), 1, 0.45)
    table.insert(BubblePool, {
        Object = bubble,
        X = math.random(),
        Y = math.random(),
        Speed = 0.00003 + math.random() * 0.00006,
    })
end

connect(RunService.RenderStepped, function(dt)
    if Destroyed then return end
    FrameCount += 1
    local now = os.clock()
    if now - LastFPS >= 1 then
        FPSValue = FrameCount
        FrameCount = 0
        LastFPS = now
    end

    if MenuOpen and Root.Visible then
        for _, bubble in ipairs(BubblePool) do
            local object = bubble.Object
            if object and object.Parent then
                if Config.Bubbles and not Config.PerformanceMode then
                    bubble.Y -= bubble.Speed * dt * 60
                    if bubble.Y < -0.05 then
                        bubble.Y = 1.05
                        bubble.X = math.random()
                    end
                    object.Position = UDim2.fromScale(bubble.X, bubble.Y)
                    object.Visible = true
                else
                    object.Visible = false
                end
            end
        end
    end

    if StatsLabel then
        StatsLabel.Visible = Config.FPSCounter or Config.PingCounter
        local ping = "--"
        if Config.PingCounter then
            pcall(function()
                ping = tostring(math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())) .. " ms"
            end)
        end
        StatsLabel.Text = "FPS: " .. (Config.FPSCounter and tostring(FPSValue) or "--") .. " | Ping: " .. ping
    end
end)

task.spawn(function()
    while not Destroyed do
        task.wait(4)
        if Config.AutoPerformance and FPSValue < 25 and not Config.PerformanceMode then
            Config.PerformanceMode = true
            applyTheme()
            toast("Low FPS detected. Optimized!")
        end
    end
end)

local function isTyping()
    if UserInputService:GetFocusedTextBox() then return true end
    local ok, result = pcall(function() return GuiService.MenuIsOpen end)
    return ok and result
end

local function menuKey()
    local ok, key = pcall(function() return Enum.KeyCode[Config.MenuKey] end)
    return ok and key or Enum.KeyCode.RightShift
end

connect(UserInputService.InputBegan, function(input, processed)
    if processed or isTyping() then return end
    if input.KeyCode == menuKey() then
        MenuOpen = not MenuOpen
        Root.Visible = MenuOpen
    elseif input.KeyCode == Enum.KeyCode.Tab then
        local index = table.find(TabNames, CurrentTab) or 1
        openTab(TabNames[index % #TabNames + 1])
    elseif input.KeyCode == Enum.KeyCode.Right then
        local index = table.find(TabNames, CurrentTab) or 1
        openTab(TabNames[index % #TabNames + 1])
    elseif input.KeyCode == Enum.KeyCode.Left then
        local index = table.find(TabNames, CurrentTab) or 1
        openTab(TabNames[(index - 2) % #TabNames + 1])
    end
end)

local function updateScale()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local scale = Config.Scale
    if viewport.X < 650 then scale = math.min(scale, 0.85) end
    local uiScale = Root:FindFirstChildOfClass("UIScale")
    if not uiScale then
        uiScale = Instance.new("UIScale")
        uiScale.Parent = Root
    end
    uiScale.Scale = scale
end

if workspace.CurrentCamera then
    connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale)
end

connect(player.CharacterAdded, function()
    task.wait(1)
    if Destroyed then return end
    adjustDefaultJump()
    if Config.JumpReplace or Config.JumpHideDefault then createJump() end
end)

--==================================================
-- API
--==================================================

function Menu:AddButton(name, iconName, callback)
    local text = Config.ButtonIconOnly and (iconName or "⭐") or ((iconName or "⭐") .. " " .. name)
    local b = makeButton(Content, text, UDim2.fromOffset(Config.ButtonWidth, Config.ButtonHeight), UDim2.new(), callback)
    b.BackgroundColor3 = Config.ButtonNormal
    b.TextColor3 = Config.Text
    b.TextStrokeTransparency = Config.ButtonTextStroke and 0.5 or 1

    if Config.ButtonStyle == "Pill" then
        round(b, 100)
    elseif Config.ButtonStyle == "Square" then
        round(b, 0)
    elseif Config.ButtonStyle == "Round Orb" then
        round(b, 100)
        b.Size = UDim2.fromOffset(Config.ButtonHeight, Config.ButtonHeight)
    else
        round(b, Config.ButtonRadius)
    end

    local originalSize = b.Size
    connect(b.MouseEnter, function()
        animate(b, {
            BackgroundColor3 = Config.ButtonHover,
            Position = b.Position - UDim2.fromOffset(0, Config.ButtonLift and 3 or 0),
            Size = Config.ButtonScale and originalSize + UDim2.fromOffset(3, 3) or originalSize,
        })
    end)
    connect(b.MouseLeave, function()
        animate(b, {BackgroundColor3 = Config.ButtonNormal, Size = originalSize})
    end)
    connect(b.MouseButton1Down, function()
        animate(b, {
            BackgroundColor3 = Config.ButtonPressed,
            Size = Config.ButtonSquish and originalSize - UDim2.fromOffset(4, 4) or originalSize,
        }, 0.08)
    end)
    connect(b.MouseButton1Up, function()
        animate(b, {BackgroundColor3 = Config.ButtonHover, Size = originalSize})
    end)

    table.insert(ButtonObjects, {Name = name, Object = b, Visible = true})
    return b
end

function Menu:HideButton(name, hidden)
    for _, item in ipairs(ButtonObjects) do
        if item.Name == name then
            item.Visible = not hidden
            item.Object.Visible = not hidden
        end
    end
end

function Menu:Set(key, value)
    setSetting(key, value)
end

function Menu:Get(key)
    return Config[key]
end

function Menu:Open()
    MenuOpen = true
    Root.Visible = true
end

function Menu:Close()
    MenuOpen = false
    Root.Visible = false
end

function Menu:Notify(message)
    toast(tostring(message))
end

function Menu:Undo()
    if #History == 0 then
        toast("Nothing to undo")
        return
    end
    local okCurrent, current = pcall(function() return HttpService:JSONEncode(Config) end)
    if okCurrent then table.insert(Future, current) end
    local data = table.remove(History)
    local ok, result = pcall(function() return HttpService:JSONDecode(data) end)
    if ok and type(result) == "table" then
        for key, value in pairs(result) do Config[key] = value end
        save()
        applyTheme()
        openTab(CurrentTab)
        toast("Undo successful")
    end
end

function Menu:Redo()
    if #Future == 0 then
        toast("Nothing to redo")
        return
    end
    local okCurrent, current = pcall(function() return HttpService:JSONEncode(Config) end)
    if okCurrent then table.insert(History, current) end
    local data = table.remove(Future)
    local ok, result = pcall(function() return HttpService:JSONDecode(data) end)
    if ok and type(result) == "table" then
        for key, value in pairs(result) do Config[key] = value end
        save()
        applyTheme()
        openTab(CurrentTab)
        toast("Redo successful")
    end
end

function Menu:Destroy()
    if Destroyed then return end
    Destroyed = true
    for _, connection in ipairs(Connections) do
        pcall(function() connection:Disconnect() end)
    end
    if JumpRepeatConnection then JumpRepeatConnection:Disconnect() end
    if BlurEffect then BlurEffect:Destroy() end
    if JumpGui then JumpGui:Destroy() end
    if Screen then Screen:Destroy() end
    if _G.FrutigerAeroMenu == Menu then _G.FrutigerAeroMenu = nil end
end

--==================================================
-- Init
--==================================================

local loaded = load()
_G.FrutigerAeroMenu = Menu

if not hasFileAccess() then
    toast("Session-only saving. Export config to keep it!")
elseif loaded then
    toast("Configuration loaded!")
else
    toast("Aero menu ready!")
end

applyTheme()
updateScale()
createJump()
openTab(TabBuilders[Config.LastTab] and Config.LastTab or "Home")

task.spawn(function()
    while not Destroyed do
        task.wait(5)
        if Root and Root.Parent then
            Config.WindowSize = {Root.AbsoluteSize.X, Root.AbsoluteSize.Y}
            Config.WindowPosition = {
                Root.Position.X.Scale,
                Root.Position.X.Offset,
                Root.Position.Y.Scale,
                Root.Position.Y.Offset,
            }
            Config.LastTab = CurrentTab
        end
    end
end)

save()

print("Frutiger Aero Settings Menu loaded.")
print("API: _G.FrutigerAeroMenu")
print("_G.FrutigerAeroMenu:AddButton('Hello', '⭐', function() print('Hi!') end)")
