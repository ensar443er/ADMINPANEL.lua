--[[
╔══════════════════════════════════════════════════════════╗
║           ADMIN PANEL  •  v3.0.0  •  DEV TOOL           ║
║        For private / developer use on own games only     ║
╚══════════════════════════════════════════════════════════╝
    loadstring(game:HttpGet("YOUR_RAW_GITHUB_URL"))()
]]

-- ═══════════════════════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local TeleportService  = game:GetService("TeleportService")
local CoreGui          = game:GetService("CoreGui")
local Lighting         = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ═══════════════════════════════════════════════════
--  VALID KEYS  (never expire)
-- ═══════════════════════════════════════════════════
local VALID_KEYS = {
    ["B7k2xxQ9mL"] = true,
    ["a9T4xxZ1pX"] = true,
    ["M3d8xxR5vK"] = true,
    ["q6W1xxH7sN"] = true,
    ["F2y9xxC4jA"] = true,
    ["L8n3xxX6bP"] = true,
    ["z5G7xxM2uD"] = true,
    ["H1c4xxV9kS"] = true,
    ["R9p6xxJ3tE"] = true,
    ["x2K8xxN5wB"] = true,
}

-- ═══════════════════════════════════════════════════
--  CONFIGURATION  (adjustable at runtime)
-- ═══════════════════════════════════════════════════
local Config = {
    Primary   = Color3.fromRGB(13,  13,  13),
    Secondary = Color3.fromRGB(26,  26,  26),
    Accent    = Color3.fromRGB(110, 185, 255),
    Text      = Color3.fromRGB(220, 220, 220),
    SubText   = Color3.fromRGB(100, 100, 100),
    Danger    = Color3.fromRGB(200, 40,  40),
    Width     = 700,
    Height    = 460,
    MinWidth  = 540,
    MinHeight = 370,
}

-- ═══════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════
local State = {
    ActiveCategory = "Player",
    IsMinimized    = false,
    GuiVisible     = true,
    -- Player
    SpeedEnabled   = false, SpeedValue    = 16,
    FlyEnabled     = false, FlySpeed      = 50,
    JumpEnabled    = false, JumpType      = "Double",
    NoclipEnabled  = false,
    -- Visuals
    BoxESP         = false,
    SkeletonESP    = false,
    Tracer         = false,
    HealthBarESP   = false,
    DistanceESP    = false,
    NameESP        = false,
    Chams          = false,
    Fullbright     = false,
    NoFog          = false,
    XRay           = false,
    -- Combat (melee + bow, no weapon hacks)
    KillAura       = false, KillAuraRange = 20,
    Reach          = false, ReachValue    = 10,
    AutoSwing      = false,
    FastAttack     = false,
    GodMode        = false,
    AntiStun       = false,
    -- Bow
    BowAutoCharge  = false,
    BowNoGravity   = false,
    BowSpeedBoost  = false, BowSpeedValue = 2,
    BowInstantReload = false,
}

-- Keybinds (id → Enum.KeyCode or Enum.UserInputType)
local Keybinds = {
    ToggleMenu    = Enum.KeyCode.Insert,
    ToggleFly     = Enum.KeyCode.F,
    ToggleSpeed   = Enum.KeyCode.X,
    ToggleNoclip  = Enum.KeyCode.N,
    ToggleESP     = Enum.KeyCode.Z,
    ForceRespawn  = Enum.KeyCode.End,
    ToggleGodMode = Enum.KeyCode.G,
}
local KeybindLabels = {
    ToggleMenu   = "Toggle Menu",
    ToggleFly    = "Toggle Fly",
    ToggleSpeed  = "Toggle Speed",
    ToggleNoclip = "Toggle Noclip",
    ToggleESP    = "Toggle All ESP",
    ForceRespawn = "Force Respawn",
    ToggleGodMode= "Toggle God Mode",
}
local KeybindOrder = {"ToggleMenu","ToggleFly","ToggleSpeed","ToggleNoclip","ToggleESP","ForceRespawn","ToggleGodMode"}

-- Save original lighting BEFORE any modifications
local OrigLighting = {}
local function SaveLighting()
    OrigLighting.Brightness     = Lighting.Brightness
    OrigLighting.Ambient        = Lighting.Ambient
    OrigLighting.OutdoorAmbient = Lighting.OutdoorAmbient
    OrigLighting.FogEnd         = Lighting.FogEnd
    OrigLighting.FogStart       = Lighting.FogStart
    OrigLighting.ColorShift_Bottom = Lighting.ColorShift_Bottom
    OrigLighting.ColorShift_Top    = Lighting.ColorShift_Top
    OrigLighting.effects = {}
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("PostEffect") or child:IsA("Sky") or child:IsA("Atmosphere") then
            OrigLighting.effects[child] = {
                Enabled     = child:FindFirstChild("Enabled") and child.Enabled or nil,
                Density     = child:IsA("Atmosphere") and child.Density or nil,
                Offset      = child:IsA("Atmosphere") and child.Offset or nil,
            }
        end
    end
end
SaveLighting()

-- ═══════════════════════════════════════════════════
--  CONNECTION REGISTRY
-- ═══════════════════════════════════════════════════
local Connections = {}
local ESPObjects  = {}   -- Highlight, BillboardGui, etc.
local DrawObjects  = {}  -- ScreenGui 2D drawings
local FlyBody     = nil
local JumpConns   = {}
local NoclipConn  = nil
local SpeedBV     = nil
local noclipState = false -- internal toggle for subtle noclip

local function Track(c)
    if c then table.insert(Connections, c) end
    return c
end

local function ClearJumpConns()
    for _, c in ipairs(JumpConns) do pcall(function() c:Disconnect() end) end
    JumpConns = {}
end

-- ═══════════════════════════════════════════════════
--  CLEANUP (Panic / full shutdown)
-- ═══════════════════════════════════════════════════
local function Cleanup()
    -- Disconnect all connections
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    Connections = {}
    ClearJumpConns()
    if NoclipConn then pcall(function() NoclipConn:Disconnect() end); NoclipConn = nil end

    -- Destroy ESP objects
    for _, obj in pairs(ESPObjects) do
        pcall(function() if obj and obj.Parent then obj:Destroy() end end)
    end
    ESPObjects = {}

    -- Destroy screen drawings
    for _, obj in pairs(DrawObjects) do
        pcall(function() if obj and obj.Parent then obj:Destroy() end end)
    end
    DrawObjects = {}

    -- Remove fly body objects
    if FlyBody then
        pcall(function() FlyBody.bv:Destroy() end)
        pcall(function() FlyBody.bg:Destroy() end)
        FlyBody = nil
    end

    -- Remove speed BodyVelocity
    if SpeedBV then pcall(function() SpeedBV:Destroy() end); SpeedBV = nil end

    -- Restore humanoid
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed     = 16
            hum.JumpPower     = 50
            hum.PlatformStand = false
            hum.MaxHealth     = 100
            hum.Health        = hum.Health  -- don't change health itself
        end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
        -- Remove any lingering body movers we placed
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BodyVelocity") and p.Name == "_AdminBV" then p:Destroy() end
            if p:IsA("BodyGyro")     and p.Name == "_AdminBG" then p:Destroy() end
        end
    end)

    -- Restore lighting
    pcall(function()
        Lighting.Brightness     = OrigLighting.Brightness
        Lighting.Ambient        = OrigLighting.Ambient
        Lighting.OutdoorAmbient = OrigLighting.OutdoorAmbient
        Lighting.FogEnd         = OrigLighting.FogEnd
        Lighting.FogStart       = OrigLighting.FogStart
        Lighting.ColorShift_Bottom = OrigLighting.ColorShift_Bottom
        Lighting.ColorShift_Top    = OrigLighting.ColorShift_Top
        for effect, props in pairs(OrigLighting.effects) do
            if effect and effect.Parent then
                if props.Enabled ~= nil then effect.Enabled = props.Enabled end
                if props.Density  ~= nil then effect.Density  = props.Density  end
                if props.Offset   ~= nil then effect.Offset   = props.Offset   end
            end
        end
    end)

    -- Restore X-Ray
    pcall(function()
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("BasePart") then p.LocalTransparencyModifier = 0 end
        end
    end)

    State.SpeedEnabled   = false
    State.FlyEnabled     = false
    State.JumpEnabled    = false
    State.NoclipEnabled  = false
    State.GodMode        = false
    State.BoxESP         = false
    State.SkeletonESP    = false
    State.Tracer         = false
    State.HealthBarESP   = false
    State.DistanceESP    = false
    State.NameESP        = false
    State.Chams          = false
    State.Fullbright     = false
    State.NoFog          = false
    State.XRay           = false
    State.KillAura       = false
    State.Reach          = false
    State.AutoSwing      = false
    State.FastAttack     = false
    State.AntiStun       = false
    State.BowAutoCharge  = false
    State.BowNoGravity   = false
    State.BowSpeedBoost  = false
    State.BowInstantReload = false
    noclipState = false
end

-- ═══════════════════════════════════════════════════
--  GUI ROOT
-- ═══════════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "AdminPanel_" .. HttpService:GenerateGUID(false):sub(1,8)
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder   = 999

local ok = pcall(function() ScreenGui.Parent = CoreGui end)
if not ok then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Screen-space drawing layer (for ESP lines / boxes)
local DrawLayer = Instance.new("Frame")
DrawLayer.Name                = "DrawLayer"
DrawLayer.Size                = UDim2.new(1, 0, 1, 0)
DrawLayer.BackgroundTransparency = 1
DrawLayer.ZIndex              = 1
DrawLayer.Parent              = ScreenGui

-- ═══════════════════════════════════════════════════
--  UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════
local function N(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props) do i[k] = v end
    if parent then i.Parent = parent end
    return i
end

local function Corner(parent, r)
    return N("UICorner", {CornerRadius = UDim.new(0, r or 8)}, parent)
end

local function Stroke(parent, color, thickness)
    return N("UIStroke", {Color = color or Color3.fromRGB(40,40,40), Thickness = thickness or 1}, parent)
end

local function Hover(btn, on, off)
    off = off or btn.BackgroundColor3
    btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = on}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = off}):Play() end)
end

local function List(parent, dir, pad, ha, va)
    local l = Instance.new("UIListLayout")
    l.SortOrder           = Enum.SortOrder.LayoutOrder
    l.FillDirection       = dir or Enum.FillDirection.Vertical
    l.Padding             = UDim.new(0, pad or 0)
    l.HorizontalAlignment = ha or Enum.HorizontalAlignment.Left
    l.VerticalAlignment   = va or Enum.VerticalAlignment.Top
    l.Parent              = parent
    return l
end

local function Pad(parent, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.PaddingLeft   = UDim.new(0, l or 0)
    p.PaddingRight  = UDim.new(0, r or 0)
    p.Parent        = parent
    return p
end

-- 2D line drawing in DrawLayer
local function DrawLine(from2D, to2D, color, thickness)
    thickness = thickness or 1.5
    local delta  = to2D - from2D
    local length = delta.Magnitude
    if length < 1 then return nil end
    local angle  = math.deg(math.atan2(delta.Y, delta.X))
    local line   = N("Frame", {
        Size             = UDim2.new(0, length, 0, thickness),
        Position         = UDim2.new(0, from2D.X, 0, from2D.Y),
        AnchorPoint      = Vector2.new(0, 0.5),
        Rotation         = angle,
        BackgroundColor3 = color or Color3.fromRGB(255,50,50),
        BorderSizePixel  = 0,
        ZIndex           = 2,
    }, DrawLayer)
    return line
end

-- ═══════════════════════════════════════════════════
--  KEY SYSTEM  (shown first, blocks main GUI)
-- ═══════════════════════════════════════════════════
local KeyOverlay = N("Frame", {
    Size             = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(8, 8, 8),
    BorderSizePixel  = 0,
    ZIndex           = 500,
}, ScreenGui)

N("TextLabel", {
    Size             = UDim2.new(0, 340, 0, 32),
    Position         = UDim2.new(0.5, -170, 0.5, -90),
    BackgroundTransparency = 1,
    Text             = "ADMIN PANEL",
    TextColor3       = Color3.fromRGB(220, 220, 220),
    Font             = Enum.Font.GothamBold,
    TextSize         = 22,
    ZIndex           = 501,
}, KeyOverlay)

N("TextLabel", {
    Size             = UDim2.new(0, 340, 0, 20),
    Position         = UDim2.new(0.5, -170, 0.5, -55),
    BackgroundTransparency = 1,
    Text             = "Enter your access key to continue",
    TextColor3       = Color3.fromRGB(90, 90, 90),
    Font             = Enum.Font.Gotham,
    TextSize         = 12,
    ZIndex           = 501,
}, KeyOverlay)

local KeyBox = N("TextBox", {
    Size             = UDim2.new(0, 300, 0, 40),
    Position         = UDim2.new(0.5, -150, 0.5, -20),
    BackgroundColor3 = Color3.fromRGB(20, 20, 20),
    PlaceholderText  = "Enter key…",
    PlaceholderColor3= Color3.fromRGB(70, 70, 70),
    Text             = "",
    TextColor3       = Color3.fromRGB(220, 220, 220),
    Font             = Enum.Font.GothamSemibold,
    TextSize         = 13,
    BorderSizePixel  = 0,
    ClearTextOnFocus = false,
    ZIndex           = 501,
}, KeyOverlay)
Corner(KeyBox, 8)
Stroke(KeyBox, Color3.fromRGB(40, 40, 40), 1)

local KeySubmit = N("TextButton", {
    Size             = UDim2.new(0, 300, 0, 36),
    Position         = UDim2.new(0.5, -150, 0.5, 30),
    BackgroundColor3 = Color3.fromRGB(30, 90, 170),
    Text             = "SUBMIT",
    TextColor3       = Color3.fromRGB(255, 255, 255),
    Font             = Enum.Font.GothamBold,
    TextSize          = 13,
    BorderSizePixel  = 0,
    ZIndex           = 501,
}, KeyOverlay)
Corner(KeySubmit, 8)
Hover(KeySubmit, Color3.fromRGB(45, 120, 210), Color3.fromRGB(30, 90, 170))

local KeyError = N("TextLabel", {
    Size             = UDim2.new(0, 300, 0, 20),
    Position         = UDim2.new(0.5, -150, 0.5, 72),
    BackgroundTransparency = 1,
    Text             = "",
    TextColor3       = Color3.fromRGB(220, 60, 60),
    Font             = Enum.Font.Gotham,
    TextSize         = 11,
    ZIndex           = 501,
}, KeyOverlay)

local MainGui  -- declared early, built after key verified

local function ShowMainGui()
    TweenService:Create(KeyOverlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    task.delay(0.31, function()
        KeyOverlay:Destroy()
    end)
end

local function TryKey()
    local k = KeyBox.Text:match("^%s*(.-)%s*$")  -- trim whitespace
    if VALID_KEYS[k] then
        ShowMainGui()
    else
        KeyError.Text = "Invalid key. Please try again."
        TweenService:Create(KeyBox, TweenInfo.new(0.07,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,4,true), {Position = UDim2.new(0.5,-146,0.5,-20)}):Play()
    end
end

KeySubmit.MouseButton1Click:Connect(TryKey)
KeyBox.FocusLost:Connect(function(enter) if enter then TryKey() end end)

-- ═══════════════════════════════════════════════════
--  MAIN FRAME  (ClipsDescendants handles ALL corners)
-- ═══════════════════════════════════════════════════
local MainFrame = N("Frame", {
    Name             = "MainFrame",
    Size             = UDim2.new(0, Config.Width, 0, Config.Height),
    Position         = UDim2.new(0.5, -Config.Width/2, 0.5, -Config.Height/2),
    BackgroundColor3 = Config.Primary,
    BorderSizePixel  = 0,
    ClipsDescendants = true,
}, ScreenGui)
Corner(MainFrame, 12)
Stroke(MainFrame, Color3.fromRGB(38, 38, 38), 1)

-- TITLE BAR
local TitleBar = N("Frame", {
    Size             = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = Config.Secondary,
    BorderSizePixel  = 0,
}, MainFrame)

N("TextLabel", {
    Size             = UDim2.new(1, -110, 1, 0),
    Position         = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text             = "  ADMIN PANEL",
    TextColor3       = Config.Text,
    Font             = Enum.Font.GothamBold,
    TextSize         = 13,
    TextXAlignment   = Enum.TextXAlignment.Left,
}, TitleBar)

local function CtrlBtn(xOff, bg, label)
    local b = N("TextButton", {
        Size             = UDim2.new(0, 28, 0, 28),
        Position         = UDim2.new(1, xOff, 0.5, -14),
        BackgroundColor3 = bg,
        Text             = label,
        TextColor3       = Color3.fromRGB(255,255,255),
        Font             = Enum.Font.GothamBold,
        TextSize         = 13,
        BorderSizePixel  = 0,
    }, TitleBar)
    Corner(b, 7)
    return b
end

local MinBtn   = CtrlBtn(-70, Color3.fromRGB(42, 42, 42), "−")
local CloseBtn = CtrlBtn(-36, Color3.fromRGB(160, 36, 36), "X")
Hover(MinBtn,   Color3.fromRGB(62,62,62),         Color3.fromRGB(42,42,42))
Hover(CloseBtn, Color3.fromRGB(210,50,50),         Color3.fromRGB(160,36,36))

-- SIDEBAR (no UICorner needed, clipped by MainFrame)
local Sidebar = N("Frame", {
    Size             = UDim2.new(0, 164, 1, -46),
    Position         = UDim2.new(0, 0, 0, 46),
    BackgroundColor3 = Config.Secondary,
    BorderSizePixel  = 0,
}, MainFrame)

-- Thin divider between sidebar and content
N("Frame", {
    Size             = UDim2.new(0, 1, 1, -46),
    Position         = UDim2.new(0, 164, 0, 46),
    BackgroundColor3 = Color3.fromRGB(35, 35, 35),
    BorderSizePixel  = 0,
}, MainFrame)

-- PROFILE SECTION
local AvatarHolder = N("Frame", {
    Size             = UDim2.new(0, 46, 0, 46),
    Position         = UDim2.new(0.5, -23, 0, 10),
    BackgroundColor3 = Color3.fromRGB(30, 30, 30),
    BorderSizePixel  = 0,
}, Sidebar)
Corner(AvatarHolder, 23)
Stroke(AvatarHolder, Color3.fromRGB(50,50,50), 1.5)

local AvatarImg = N("ImageLabel", {
    Size             = UDim2.new(1,0,1,0),
    BackgroundTransparency = 1,
    Image            = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=420&height=420&format=png",
    ScaleType        = Enum.ScaleType.Crop,
}, AvatarHolder)
Corner(AvatarImg, 23)

N("TextLabel", {
    Size             = UDim2.new(1,-10,0,16),
    Position         = UDim2.new(0,5,0,58),
    BackgroundTransparency = 1,
    Text             = LocalPlayer.DisplayName,
    TextColor3       = Config.Text,
    Font             = Enum.Font.GothamBold,
    TextSize         = 11,
    TextTruncate     = Enum.TextTruncate.AtEnd,
}, Sidebar)

N("TextLabel", {
    Size             = UDim2.new(1,-10,0,14),
    Position         = UDim2.new(0,5,0,74),
    BackgroundTransparency = 1,
    Text             = "@" .. LocalPlayer.Name,
    TextColor3       = Config.SubText,
    Font             = Enum.Font.Gotham,
    TextSize         = 10,
    TextTruncate     = Enum.TextTruncate.AtEnd,
}, Sidebar)

N("Frame", {
    Size             = UDim2.new(1,-24,0,1),
    Position         = UDim2.new(0,12,0,100),
    BackgroundColor3 = Color3.fromRGB(38,38,38),
    BorderSizePixel  = 0,
}, Sidebar)

-- Category list container
local CatList = N("Frame", {
    Size             = UDim2.new(1,0,1,-108),
    Position         = UDim2.new(0,0,0,108),
    BackgroundTransparency = 1,
}, Sidebar)
List(CatList, nil, 3)
Pad(CatList, 4, 0, 8, 8)

-- CONTENT AREA
local ContentArea = N("Frame", {
    Name             = "ContentArea",
    Size             = UDim2.new(1,-165,1,-46),
    Position         = UDim2.new(0,165,0,46),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, MainFrame)

-- ═══════════════════════════════════════════════════
--  PANIC BUTTON  (always visible, bottom-left of screen)
-- ═══════════════════════════════════════════════════
local PanicBtn = N("TextButton", {
    Size             = UDim2.new(0, 50, 0, 50),
    Position         = UDim2.new(0, 14, 1, -64),
    BackgroundColor3 = Color3.fromRGB(170, 28, 28),
    Text             = "!",
    TextColor3       = Color3.fromRGB(255,255,255),
    Font             = Enum.Font.GothamBold,
    TextSize         = 22,
    BorderSizePixel  = 0,
    ZIndex           = 300,
}, ScreenGui)
Corner(PanicBtn, 25)
Stroke(PanicBtn, Color3.fromRGB(220,50,50), 1.5)

local PanicTip = N("Frame", {
    Size             = UDim2.new(0, 270, 0, 72),
    Position         = UDim2.new(0, 68, 1, -76),
    BackgroundColor3 = Color3.fromRGB(28,28,28),
    BorderSizePixel  = 0,
    Visible          = false,
    ZIndex           = 301,
}, ScreenGui)
Corner(PanicTip, 8)
Stroke(PanicTip, Color3.fromRGB(200,40,40), 1)

N("TextLabel", {
    Size             = UDim2.new(1,-16,1,-8),
    Position         = UDim2.new(0,8,0,4),
    BackgroundTransparency = 1,
    Text             = "PANIC BUTTON\nImmediately shuts down all active scripts,\nresets all effects, and closes the panel.",
    TextColor3       = Color3.fromRGB(230,80,80),
    Font             = Enum.Font.Gotham,
    TextSize         = 10,
    TextWrapped      = true,
    TextXAlignment   = Enum.TextXAlignment.Left,
    ZIndex           = 302,
}, PanicTip)

PanicBtn.MouseEnter:Connect(function()
    PanicTip.Visible = true
    TweenService:Create(PanicBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(210,40,40)}):Play()
end)
PanicBtn.MouseLeave:Connect(function()
    PanicTip.Visible = false
    TweenService:Create(PanicBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(170,28,28)}):Play()
end)
PanicBtn.MouseButton1Click:Connect(function()
    Cleanup()
    pcall(function() ScreenGui:Destroy() end)
end)

-- ═══════════════════════════════════════════════════
--  WIDGET FACTORY HELPERS
-- ═══════════════════════════════════════════════════
local function MakePanel(name)
    local scroll = N("ScrollingFrame", {
        Name                  = name .. "Panel",
        Size                  = UDim2.new(1,0,1,0),
        BackgroundTransparency= 1,
        BorderSizePixel       = 0,
        ScrollBarThickness    = 3,
        ScrollBarImageColor3  = Color3.fromRGB(55,55,55),
        CanvasSize            = UDim2.new(0,0,0,0),
        AutomaticCanvasSize   = Enum.AutomaticSize.Y,
        Visible               = false,
    }, ContentArea)
    List(scroll, nil, 6)
    Pad(scroll, 10, 14, 12, 14)
    return scroll
end

local function SectionLbl(parent, text)
    N("TextLabel", {
        Size             = UDim2.new(1,0,0,18),
        BackgroundTransparency = 1,
        Text             = text,
        TextColor3       = Config.SubText,
        Font             = Enum.Font.GothamBold,
        TextSize         = 9,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, parent)
end

local function Card(parent, h)
    local f = N("Frame", {
        Size             = UDim2.new(1,0,0,h or 52),
        BackgroundColor3 = Config.Secondary,
        BorderSizePixel  = 0,
    }, parent)
    Corner(f, 8)
    return f
end

-- Slider builder (reused everywhere)
local SliderDrag = false
local SliderActive = nil

local function BuildSlider(parent, yPos, minV, maxV, defV, onChange)
    local track = N("Frame", {
        Size             = UDim2.new(1,-52,0,4),
        Position         = UDim2.new(0,0,0,yPos),
        BackgroundColor3 = Color3.fromRGB(38,38,38),
        BorderSizePixel  = 0,
    }, parent)
    Corner(track, 2)

    local pct  = math.clamp((defV - minV)/(maxV - minV), 0, 1)
    local fill = N("Frame", {
        Size             = UDim2.new(pct,0,1,0),
        BackgroundColor3 = Config.Accent,
        BorderSizePixel  = 0,
    }, track)
    Corner(fill, 2)

    local knob = N("Frame", {
        Size             = UDim2.new(0,13,0,13),
        AnchorPoint      = Vector2.new(0.5,0.5),
        Position         = UDim2.new(pct,0,0.5,0),
        BackgroundColor3 = Color3.fromRGB(230,230,230),
        BorderSizePixel  = 0,
        ZIndex           = track.ZIndex+1,
    }, track)
    Corner(knob,7)

    local valLbl = N("TextLabel", {
        Size             = UDim2.new(0,46,0,16),
        Position         = UDim2.new(1,4,0,yPos-6),
        BackgroundTransparency = 1,
        Text             = tostring(defV),
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamBold,
        TextSize         = 11,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, parent)

    local function move(x)
        local rel = math.clamp((x - track.AbsolutePosition.X)/track.AbsoluteSize.X, 0, 1)
        local v   = math.round(minV + rel*(maxV-minV))
        fill.Size     = UDim2.new(rel,0,1,0)
        knob.Position = UDim2.new(rel,0,0.5,0)
        valLbl.Text   = tostring(v)
        onChange(v)
    end

    local dragging = false
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; move(i.Position.X) end
    end)
    Track(UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then move(i.Position.X) end
    end))
    Track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))

    return track, valLbl
end

-- Toggle card factory
local function MakeToggle(parent, opts)
    local hasSlider = opts.slider ~= nil
    local baseH     = 52
    local openH     = hasSlider and 84 or baseH
    local card      = Card(parent, baseH)
    local isOn      = opts.default or false
    local sliderRef = nil

    -- Pill
    local pill = N("TextButton", {
        Size             = UDim2.new(0,40,0,22),
        Position         = UDim2.new(1,-48,0,15),
        BackgroundColor3 = isOn and Color3.fromRGB(60,180,100) or Color3.fromRGB(42,42,42),
        Text             = "",
        BorderSizePixel  = 0,
    }, card)
    Corner(pill, 11)
    local dot = N("Frame", {
        Size             = UDim2.new(0,16,0,16),
        Position         = isOn and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel  = 0,
    }, pill)
    Corner(dot, 8)

    N("TextLabel", {
        Size             = UDim2.new(1,-58,0,20),
        Position         = UDim2.new(0,12,0,8),
        BackgroundTransparency = 1,
        Text             = opts.label,
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, card)

    if opts.description then
        N("TextLabel", {
            Size             = UDim2.new(1,-58,0,13),
            Position         = UDim2.new(0,12,0,29),
            BackgroundTransparency = 1,
            Text             = opts.description,
            TextColor3       = Config.SubText,
            Font             = Enum.Font.Gotham,
            TextSize         = 10,
            TextXAlignment   = Enum.TextXAlignment.Left,
        }, card)
    end

    local sliderVal = hasSlider and opts.slider.default or nil

    if hasSlider then
        local s     = opts.slider
        sliderVal   = s.default
        local sf    = N("Frame", {
            Size             = UDim2.new(1,-24,0,22),
            Position         = UDim2.new(0,12,0,57),
            BackgroundTransparency = 1,
            Visible          = isOn,
        }, card)
        sliderRef = sf

        BuildSlider(sf, 4, s.min, s.max, s.default, function(v)
            sliderVal = v
            if s.onChange then s.onChange(v) end
        end)
    end

    local function SetToggle(v)
        isOn = v
        local bg  = isOn and Color3.fromRGB(60,180,100) or Color3.fromRGB(42,42,42)
        local pos = isOn and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
        TweenService:Create(pill, TweenInfo.new(0.13), {BackgroundColor3 = bg}):Play()
        TweenService:Create(dot,  TweenInfo.new(0.13), {Position = pos}):Play()
        if sliderRef then
            sliderRef.Visible = isOn
            card.Size = UDim2.new(1,0,0, isOn and openH or baseH)
        end
        opts.onToggle(isOn, sliderVal)
    end

    pill.MouseButton1Click:Connect(function() SetToggle(not isOn) end)

    -- return a function to externally set state (for keybinds)
    return card, function(v) SetToggle(v) end
end

-- Dropdown
local function MakeDropdown(parent, label, options, default, onChange)
    local card = Card(parent, 52)
    local sel  = default
    local open = false

    N("TextLabel", {
        Size             = UDim2.new(0.5,0,1,0),
        Position         = UDim2.new(0,12,0,0),
        BackgroundTransparency = 1,
        Text             = label,
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, card)

    local btn = N("TextButton", {
        Size             = UDim2.new(0,130,0,28),
        Position         = UDim2.new(1,-140,0.5,-14),
        BackgroundColor3 = Color3.fromRGB(32,32,32),
        Text             = default .. " v",
        TextColor3       = Config.Text,
        Font             = Enum.Font.Gotham,
        TextSize         = 11,
        BorderSizePixel  = 0,
    }, card)
    Corner(btn, 6)

    local list = N("Frame", {
        Size             = UDim2.new(0,130,0,#options*28),
        Position         = UDim2.new(1,-140,1,4),
        BackgroundColor3 = Color3.fromRGB(26,26,26),
        BorderSizePixel  = 0,
        Visible          = false,
        ZIndex           = 20,
    }, card)
    Corner(list, 6)
    Stroke(list, Color3.fromRGB(42,42,42), 1)
    List(list)

    for _, opt in ipairs(options) do
        local ob = N("TextButton", {
            Size             = UDim2.new(1,0,0,28),
            BackgroundTransparency = 1,
            Text             = opt,
            TextColor3       = opt == sel and Config.Accent or Config.Text,
            Font             = Enum.Font.Gotham,
            TextSize         = 11,
            ZIndex           = 21,
        }, list)
        ob.MouseEnter:Connect(function() ob.TextColor3 = Config.Accent end)
        ob.MouseLeave:Connect(function()
            ob.TextColor3 = (ob.Text == sel) and Config.Accent or Config.Text
        end)
        ob.MouseButton1Click:Connect(function()
            sel = opt
            btn.Text = opt .. " v"
            list.Visible = false
            open = false
            for _, c in ipairs(list:GetChildren()) do
                if c:IsA("TextButton") then c.TextColor3 = (c.Text == sel) and Config.Accent or Config.Text end
            end
            onChange(opt)
        end)
    end

    btn.MouseButton1Click:Connect(function() open = not open; list.Visible = open end)
    return card
end

-- Action button
local function MakeButton(parent, label, onClick)
    local card = Card(parent, 40)
    local btn  = N("TextButton", {
        Size             = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1,
        Text             = label,
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 12,
        BorderSizePixel  = 0,
    }, card)
    Hover(card, Color3.fromRGB(32,32,32))
    btn.MouseButton1Click:Connect(onClick)
    return card
end

-- ═══════════════════════════════════════════════════
--  PLAYER PANEL
-- ═══════════════════════════════════════════════════
local PlayerPanel = MakePanel("Player")

SectionLbl(PlayerPanel, "MOVEMENT")

-- Speed (improved anticheat bypass with BodyVelocity)
local function ApplySpeed()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    -- Primary: set WalkSpeed
    pcall(function() hum.WalkSpeed = State.SpeedValue end)

    -- Supplement: BodyVelocity adds boost in move direction (helps when AC resets WalkSpeed)
    if hum.MoveDirection.Magnitude > 0 then
        local bv = hrp:FindFirstChild("_AdminBV")
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name      = "_AdminBV"
            bv.MaxForce  = Vector3.new(1e5, 0, 1e5)
            bv.Velocity  = Vector3.zero
            bv.Parent    = hrp
            SpeedBV = bv
        end
        local boost = math.max(0, State.SpeedValue - 16)
        bv.Velocity = hum.MoveDirection * boost
    else
        local bv = hrp:FindFirstChild("_AdminBV")
        if bv then bv.Velocity = Vector3.zero end
    end
end

local _speedToggle
_, _speedToggle = MakeToggle(PlayerPanel, {
    label       = "Speed",
    description = "Override walk speed (dual-method for AC resistance)",
    default     = false,
    onToggle    = function(on, val)
        State.SpeedEnabled = on
        if val then State.SpeedValue = val end
        if not on then
            pcall(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 16 end
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local bv = hrp:FindFirstChild("_AdminBV")
                    if bv then bv:Destroy(); SpeedBV = nil end
                end
            end)
        end
    end,
    slider = { min = 0, max = 300, default = 16, onChange = function(v) State.SpeedValue = v end },
})

-- Fly
local function EnableFly()
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if FlyBody then
        pcall(function() FlyBody.bv:Destroy() end)
        pcall(function() FlyBody.bg:Destroy() end)
        FlyBody = nil
    end
    local bv = Instance.new("BodyVelocity")
    bv.Name      = "_AdminBV2"
    bv.MaxForce  = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity  = Vector3.zero
    bv.Parent    = hrp
    local bg = Instance.new("BodyGyro")
    bg.Name      = "_AdminBG"
    bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bg.D         = 100
    bg.Parent    = hrp
    FlyBody = {bv=bv, bg=bg}
end

local function DisableFly()
    local char = LocalPlayer.Character
    if FlyBody then
        pcall(function() FlyBody.bv:Destroy() end)
        pcall(function() FlyBody.bg:Destroy() end)
        FlyBody = nil
    end
    pcall(function()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end)
end

local _flyToggle
_, _flyToggle = MakeToggle(PlayerPanel, {
    label       = "Fly",
    description = "Free flight - WASD + Space (up) + Shift (down)",
    default     = false,
    onToggle    = function(on, val)
        State.FlyEnabled = on
        if val then State.FlySpeed = val end
        if on then EnableFly() else DisableFly() end
    end,
    slider = { min = 0, max = 300, default = 50, onChange = function(v) State.FlySpeed = v end },
})

-- Jump (no cooldown - uses direct state change)
do
    local jumpCard = Card(PlayerPanel, 52)
    local isOn = false
    local jumpType = "Double"

    local pill = N("TextButton", {
        Size             = UDim2.new(0,40,0,22),
        Position         = UDim2.new(1,-48,0,15),
        BackgroundColor3 = Color3.fromRGB(42,42,42),
        Text             = "",
        BorderSizePixel  = 0,
    }, jumpCard)
    Corner(pill,11)
    local dot = N("Frame", {
        Size             = UDim2.new(0,16,0,16),
        Position         = UDim2.new(0,3,0.5,-8),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel  = 0,
    }, pill)
    Corner(dot,8)

    N("TextLabel", {
        Size             = UDim2.new(1,-58,0,20),
        Position         = UDim2.new(0,12,0,8),
        BackgroundTransparency = 1,
        Text             = "Jump Override",
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, jumpCard)
    N("TextLabel", {
        Size             = UDim2.new(1,-58,0,13),
        Position         = UDim2.new(0,12,0,29),
        BackgroundTransparency = 1,
        Text             = "Double Jump or Infinite Jump, no cooldown",
        TextColor3       = Config.SubText,
        Font             = Enum.Font.Gotham,
        TextSize         = 10,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, jumpCard)

    local optFrame = N("Frame", {
        Size             = UDim2.new(1,-24,0,30),
        Position         = UDim2.new(0,12,0,52),
        BackgroundTransparency = 1,
        Visible          = false,
    }, jumpCard)
    List(optFrame, Enum.FillDirection.Horizontal, 8)

    local function JBtn(text)
        local b = N("TextButton", {
            Size             = UDim2.new(0.5,-4,1,0),
            BackgroundColor3 = text == jumpType and Color3.fromRGB(42,42,42) or Color3.fromRGB(30,30,30),
            Text             = text,
            TextColor3       = text == jumpType and Config.Accent or Config.Text,
            Font             = Enum.Font.Gotham,
            TextSize         = 11,
            BorderSizePixel  = 0,
        }, optFrame)
        Corner(b, 6)
        return b
    end

    local dblBtn = JBtn("Double Jump")
    local infBtn = JBtn("Infinity Jump")

    local function RefreshJBtns()
        dblBtn.TextColor3       = jumpType == "Double"   and Config.Accent or Config.Text
        dblBtn.BackgroundColor3 = jumpType == "Double"   and Color3.fromRGB(42,42,42) or Color3.fromRGB(30,30,30)
        infBtn.TextColor3       = jumpType == "Infinity" and Config.Accent or Config.Text
        infBtn.BackgroundColor3 = jumpType == "Infinity" and Color3.fromRGB(42,42,42) or Color3.fromRGB(30,30,30)
    end

    dblBtn.MouseButton1Click:Connect(function() jumpType = "Double";   State.JumpType = jumpType; RefreshJBtns() end)
    infBtn.MouseButton1Click:Connect(function() jumpType = "Infinity"; State.JumpType = jumpType; RefreshJBtns() end)

    local jumpCount = 0

    local function ApplyJump()
        ClearJumpConns()
        if not isOn then return end
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end

        -- Track landing to reset jump count
        table.insert(JumpConns, hum.StateChanged:Connect(function(_, new)
            if new == Enum.HumanoidStateType.Landed or
               new == Enum.HumanoidStateType.Running then
                jumpCount = 0
            end
        end))

        -- Direct state-change jump, no cooldown
        table.insert(JumpConns, UserInputService.JumpRequest:Connect(function()
            if not isOn then return end
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if not h then return end
            if jumpType == "Infinity" then
                h:ChangeState(Enum.HumanoidStateType.Jumping)
            elseif jumpType == "Double" then
                if jumpCount < 2 then
                    jumpCount = jumpCount + 1
                    h:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end))
    end

    pill.MouseButton1Click:Connect(function()
        isOn = not isOn
        State.JumpEnabled = isOn
        TweenService:Create(pill, TweenInfo.new(0.13), {BackgroundColor3 = isOn and Color3.fromRGB(60,180,100) or Color3.fromRGB(42,42,42)}):Play()
        TweenService:Create(dot,  TweenInfo.new(0.13), {Position = isOn and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)}):Play()
        optFrame.Visible = isOn
        jumpCard.Size    = UDim2.new(1,0,0, isOn and 88 or 52)
        jumpCount = 0
        ApplyJump()
    end)
end

-- Noclip (improved - uses PreSimulation + staggered approach)
local _, _noclipToggle = MakeToggle(PlayerPanel, {
    label       = "Noclip",
    description = "Disable collision (improved AC resistance)",
    default     = false,
    onToggle    = function(on)
        State.NoclipEnabled = on
        noclipState = on
        if NoclipConn then pcall(function() NoclipConn:Disconnect() end); NoclipConn = nil end
        if on then
            NoclipConn = Track(RunService.PreSimulation:Connect(function()
                if not noclipState then return end
                local char = LocalPlayer.Character
                if not char then return end
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then
                        p.CanCollide = false
                    end
                end
            end))
        else
            pcall(function()
                local char = LocalPlayer.Character
                if char then
                    for _, p in ipairs(char:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = true end
                    end
                end
            end)
        end
    end,
})

-- Force Respawn
MakeButton(PlayerPanel, "Force Respawn", function()
    pcall(function()
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end)
end)

-- Speed heartbeat (dual-method)
Track(RunService.Heartbeat:Connect(function()
    if not State.SpeedEnabled then return end
    pcall(ApplySpeed)
end))

-- Fly RenderStepped
Track(RunService.RenderStepped:Connect(function()
    if not State.FlyEnabled or not FlyBody then return end
    pcall(function()
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = true end
        local dir = Vector3.zero
        local cf  = Camera.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.yAxis end
        FlyBody.bv.Velocity = (dir.Magnitude > 0 and dir.Unit or Vector3.zero) * State.FlySpeed
        FlyBody.bg.CFrame   = cf
    end)
end))

-- ═══════════════════════════════════════════════════
--  ESP SYSTEM
-- ═══════════════════════════════════════════════════
local ESPUpdateTimer = 0
local ESP_RATE = 0.05  -- seconds between ESP rebuilds (performance)

local function WorldToScreen(pos)
    local sp, vis = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), vis, sp.Z
end

local function GetCharBoundingBox(char)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local anyVis = false
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            local cf = part.CFrame
            local sx = part.Size.X/2
            local sy = part.Size.Y/2
            local sz = part.Size.Z/2
            local corners = {
                cf * Vector3.new( sx, sy, sz),
                cf * Vector3.new(-sx, sy, sz),
                cf * Vector3.new( sx,-sy, sz),
                cf * Vector3.new(-sx,-sy, sz),
                cf * Vector3.new( sx, sy,-sz),
                cf * Vector3.new(-sx, sy,-sz),
                cf * Vector3.new( sx,-sy,-sz),
                cf * Vector3.new(-sx,-sy,-sz),
            }
            for _, c in ipairs(corners) do
                local sp2, vis = Camera:WorldToViewportPoint(c)
                if vis then
                    anyVis = true
                    minX = math.min(minX, sp2.X)
                    minY = math.min(minY, sp2.Y)
                    maxX = math.max(maxX, sp2.X)
                    maxY = math.max(maxY, sp2.Y)
                end
            end
        end
    end
    return anyVis, minX, minY, maxX, maxY
end

local SKELETON_JOINTS = {
    {"Head","UpperTorso"},
    {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},
    {"LeftUpperArm","LeftLowerArm"},
    {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},
    {"RightUpperArm","RightLowerArm"},
    {"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"},
    {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},
    {"RightUpperLeg","RightLowerLeg"},
    {"RightLowerLeg","RightFoot"},
    -- R6 fallbacks
    {"Head","Torso"},
    {"Torso","Left Arm"},
    {"Torso","Right Arm"},
    {"Torso","Left Leg"},
    {"Torso","Right Leg"},
}

-- Per-player ESP data
local PlayerESP = {}  -- [Player] = { highlight, billboard, boxLines, skelLines, tracer }

local function ClearPlayerESP(plr)
    if not PlayerESP[plr] then return end
    local d = PlayerESP[plr]
    if d.highlight then pcall(function() d.highlight:Destroy() end) end
    if d.billboard then pcall(function() d.billboard:Destroy() end) end
    for _, ln in ipairs(d.boxLines or {}) do pcall(function() ln:Destroy() end) end
    for _, ln in ipairs(d.skelLines or {}) do pcall(function() ln:Destroy() end) end
    if d.tracer then pcall(function() d.tracer:Destroy() end) end
    PlayerESP[plr] = nil
end

local function ClearAllESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        ClearPlayerESP(plr)
    end
    -- also clear any orphaned draw objects
    for _, c in ipairs(DrawLayer:GetChildren()) do c:Destroy() end
end

local function RebuildHighlights()
    -- Called when toggle state changes
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        ClearPlayerESP(plr)

        local char = plr.Character
        if not char then continue end

        PlayerESP[plr] = { boxLines = {}, skelLines = {} }
        local d = PlayerESP[plr]

        -- CHAMS: Highlight with AlwaysOnTop (shows through walls)
        if State.Chams then
            local hl = Instance.new("Highlight")
            hl.Adornee           = char
            hl.FillColor         = Color3.fromRGB(200, 30, 30)
            hl.FillTransparency  = 0.45
            hl.OutlineColor      = Color3.fromRGB(255, 80, 80)
            hl.OutlineTransparency = 0
            hl.DepthMode         = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent            = workspace
            d.highlight          = hl
        end

        -- NAME / HEALTH / DISTANCE billboard (AlwaysOnTop)
        if State.NameESP or State.HealthBarESP or State.DistanceESP then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local bb = N("BillboardGui", {
                    Size         = UDim2.new(0,120,0,60),
                    StudsOffset  = Vector3.new(0,3.5,0),
                    Adornee      = hrp,
                    AlwaysOnTop  = true,
                    ResetOnSpawn = false,
                    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
                }, workspace)
                d.billboard = bb
                List(bb, nil, 2, Enum.HorizontalAlignment.Center)

                if State.NameESP then
                    -- Show name and equipped tool
                    local tool = char:FindFirstChildOfClass("Tool")
                    local toolName = tool and (" [" .. tool.Name .. "]") or ""
                    local nl = N("TextLabel", {
                        Size             = UDim2.new(1,0,0,16),
                        BackgroundTransparency = 1,
                        Text             = plr.Name .. toolName,
                        TextColor3       = Color3.fromRGB(255,255,255),
                        Font             = Enum.Font.GothamBold,
                        TextSize         = 12,
                        TextStrokeTransparency = 0.3,
                    }, bb)
                    -- Update tool name dynamically
                    Track(char.ChildAdded:Connect(function(c)
                        if c:IsA("Tool") then nl.Text = plr.Name .. " [" .. c.Name .. "]" end
                    end))
                    Track(char.ChildRemoved:Connect(function(c)
                        if c:IsA("Tool") then nl.Text = plr.Name end
                    end))
                end

                if State.HealthBarESP then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local hl2 = N("TextLabel", {
                        Size             = UDim2.new(1,0,0,14),
                        BackgroundTransparency = 1,
                        Text             = hum and math.floor(hum.Health).."/"..math.floor(hum.MaxHealth).." HP" or "? HP",
                        TextColor3       = Color3.fromRGB(100,230,100),
                        Font             = Enum.Font.Gotham,
                        TextSize         = 10,
                        TextStrokeTransparency = 0.3,
                    }, bb)
                    if hum then
                        Track(hum:GetPropertyChangedSignal("Health"):Connect(function()
                            if hl2 and hl2.Parent then
                                hl2.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth) .. " HP"
                                local pct2 = hum.Health / hum.MaxHealth
                                hl2.TextColor3 = Color3.fromRGB(
                                    math.round((1-pct2)*220),
                                    math.round(pct2*220),
                                    50
                                )
                            end
                        end))
                    end
                end

                if State.DistanceESP then
                    local dl = N("TextLabel", {
                        Size             = UDim2.new(1,0,0,13),
                        BackgroundTransparency = 1,
                        Text             = "0 studs",
                        TextColor3       = Color3.fromRGB(180,200,255),
                        Font             = Enum.Font.Gotham,
                        TextSize         = 10,
                        TextStrokeTransparency = 0.3,
                    }, bb)
                    d.distLabel = dl
                end
            end
        end
    end
end

-- Rate-limited ESP render loop
Track(RunService.RenderStepped:Connect(function(dt)
    ESPUpdateTimer = ESPUpdateTimer + dt
    if ESPUpdateTimer < ESP_RATE then return end
    ESPUpdateTimer = 0

    local anyESP = State.BoxESP or State.SkeletonESP or State.Tracer or
                   State.HealthBarESP or State.DistanceESP or State.NameESP or State.Chams

    -- Clear old 2D drawings
    for _, c in ipairs(DrawLayer:GetChildren()) do c:Destroy() end

    if not anyESP then return end

    local viewSize  = Camera.ViewportSize
    local screenCtr = Vector2.new(viewSize.X/2, viewSize.Y)  -- tracer from bottom-center

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        local hrp  = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 then continue end

        local hrpScreen, hrpVis, hrpZ = WorldToScreen(hrp.Position)
        if not hrpVis then continue end

        -- Update distance label
        if State.DistanceESP and PlayerESP[plr] and PlayerESP[plr].distLabel then
            local lhrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if lhrp then
                local dist = math.floor((hrp.Position - lhrp.Position).Magnitude)
                local dl = PlayerESP[plr].distLabel
                if dl and dl.Parent then dl.Text = dist .. " studs" end
            end
        end

        -- BOX ESP (2D bounding box)
        if State.BoxESP then
            local anyV, minX, minY, maxX, maxY = GetCharBoundingBox(char)
            if anyV then
                local pad = 3
                minX = minX - pad; minY = minY - pad
                maxX = maxX + pad; maxY = maxY + pad
                local col = Color3.fromRGB(255, 60, 60)
                local th  = 1.5
                DrawLine(Vector2.new(minX,minY), Vector2.new(maxX,minY), col, th)  -- top
                DrawLine(Vector2.new(maxX,minY), Vector2.new(maxX,maxY), col, th)  -- right
                DrawLine(Vector2.new(maxX,maxY), Vector2.new(minX,maxY), col, th)  -- bottom
                DrawLine(Vector2.new(minX,maxY), Vector2.new(minX,minY), col, th)  -- left
            end
        end

        -- SKELETON ESP
        if State.SkeletonESP then
            for _, joint in ipairs(SKELETON_JOINTS) do
                local partA = char:FindFirstChild(joint[1])
                local partB = char:FindFirstChild(joint[2])
                if partA and partB then
                    local sA, vA = WorldToScreen(partA.Position)
                    local sB, vB = WorldToScreen(partB.Position)
                    if vA and vB then
                        DrawLine(sA, sB, Color3.fromRGB(255, 200, 60), 1.2)
                    end
                end
            end
        end

        -- TRACER
        if State.Tracer then
            DrawLine(screenCtr, hrpScreen, Color3.fromRGB(60, 200, 255), 1.2)
        end
    end
end))

-- ═══════════════════════════════════════════════════
--  VISUALS PANEL
-- ═══════════════════════════════════════════════════
local VisualsPanel = MakePanel("Visuals")

SectionLbl(VisualsPanel, "PLAYER ESP")

local function ESPToggle(label, desc, stateKey)
    return MakeToggle(VisualsPanel, {
        label       = label,
        description = desc,
        default     = false,
        onToggle    = function(on)
            State[stateKey] = on
            ClearAllESP()
            if on then RebuildHighlights() end
        end,
    })
end

ESPToggle("Box ESP",           "Draw a 2D bounding box around each player",                   "BoxESP")
ESPToggle("Skeleton ESP",      "Draw joint lines showing player bone structure",               "SkeletonESP")
ESPToggle("Tracer Lines",      "Draw a line from screen-bottom center to each player",         "Tracer")
ESPToggle("Health Bar & HP",   "Show current HP above the player (updates live)",              "HealthBarESP")
ESPToggle("Distance",          "Show distance in Roblox studs",                               "DistanceESP")
ESPToggle("Name & Tool",       "Show username and currently equipped tool",                    "NameESP")
ESPToggle("Chams / Highlight", "Colour player through walls (AlwaysOnTop Highlight)",          "Chams")

SectionLbl(VisualsPanel, "WORLD")

MakeToggle(VisualsPanel, {
    label       = "Fullbright",
    description = "Remove shadows and post-effects for maximum visibility",
    default     = false,
    onToggle    = function(on)
        State.Fullbright = on
        if on then
            Lighting.Brightness         = 2
            Lighting.Ambient            = Color3.fromRGB(255,255,255)
            Lighting.OutdoorAmbient     = Color3.fromRGB(255,255,255)
            Lighting.ColorShift_Bottom  = Color3.fromRGB(0,0,0)
            Lighting.ColorShift_Top     = Color3.fromRGB(0,0,0)
            for _, child in ipairs(Lighting:GetChildren()) do
                if child:IsA("PostEffect") then
                    pcall(function() child.Enabled = false end)
                end
                if child:IsA("Atmosphere") then
                    child.Density = 0
                end
            end
        else
            -- Restore EXACTLY what was saved at startup
            Lighting.Brightness         = OrigLighting.Brightness
            Lighting.Ambient            = OrigLighting.Ambient
            Lighting.OutdoorAmbient     = OrigLighting.OutdoorAmbient
            Lighting.ColorShift_Bottom  = OrigLighting.ColorShift_Bottom
            Lighting.ColorShift_Top     = OrigLighting.ColorShift_Top
            for effect, props in pairs(OrigLighting.effects) do
                if effect and effect.Parent then
                    if props.Enabled ~= nil then pcall(function() effect.Enabled = props.Enabled end) end
                    if props.Density  ~= nil then pcall(function() effect.Density  = props.Density  end) end
                    if props.Offset   ~= nil then pcall(function() effect.Offset   = props.Offset   end) end
                end
            end
        end
    end,
})

MakeToggle(VisualsPanel, {
    label       = "No Fog",
    description = "Remove atmospheric fog for unlimited view distance",
    default     = false,
    onToggle    = function(on)
        State.NoFog = on
        if on then
            Lighting.FogEnd   = 1e8
            Lighting.FogStart = 1e8
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if atm then atm.Density = 0; atm.Offset = 0 end
        else
            Lighting.FogEnd   = OrigLighting.FogEnd
            Lighting.FogStart = OrigLighting.FogStart
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            local orig = OrigLighting.effects[atm]
            if atm and orig then
                if orig.Density ~= nil then atm.Density = orig.Density end
                if orig.Offset  ~= nil then atm.Offset  = orig.Offset  end
            end
        end
    end,
})

MakeToggle(VisualsPanel, {
    label       = "X-Ray",
    description = "Make world geometry semi-transparent",
    default     = false,
    onToggle    = function(on)
        State.XRay = on
        local char = LocalPlayer.Character
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("BasePart") and (not char or not p:IsDescendantOf(char)) then
                p.LocalTransparencyModifier = on and 0.72 or 0
            end
        end
    end,
})

-- Rebuild ESP when a new player joins or their character respawns
Track(Players.PlayerAdded:Connect(function(plr)
    Track(plr.CharacterAdded:Connect(function()
        task.wait(1)  -- wait for char to load
        if State.BoxESP or State.SkeletonESP or State.Tracer or
           State.HealthBarESP or State.DistanceESP or State.NameESP or State.Chams then
            ClearAllESP()
            RebuildHighlights()
        end
    end))
end))

Track(Players.PlayerRemoving:Connect(function(plr)
    ClearPlayerESP(plr)
end))

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        Track(plr.CharacterAdded:Connect(function()
            task.wait(1)
            if State.BoxESP or State.SkeletonESP or State.Tracer or
               State.HealthBarESP or State.DistanceESP or State.NameESP or State.Chams then
                ClearAllESP()
                RebuildHighlights()
            end
        end))
    end
end

-- ═══════════════════════════════════════════════════
--  COMBAT PANEL  (Melee + Bow — weapon aim removed)
-- ═══════════════════════════════════════════════════
local CombatPanel = MakePanel("Combat")

SectionLbl(CombatPanel, "MELEE")

MakeToggle(CombatPanel, {
    label       = "Kill Aura",
    description = "Auto-damage all players within radius (dev testing)",
    default     = false,
    onToggle    = function(on, val)
        State.KillAura = on
        if val then State.KillAuraRange = val end
    end,
    slider = { min = 0, max = 100, default = 20, onChange = function(v) State.KillAuraRange = v end },
})

MakeToggle(CombatPanel, {
    label       = "Reach / Hitbox Expand",
    description = "Expand weapon hitbox radius",
    default     = false,
    onToggle    = function(on, val)
        State.Reach = on
        if val then State.ReachValue = val end
    end,
    slider = { min = 0, max = 100, default = 10, onChange = function(v) State.ReachValue = v end },
})

MakeToggle(CombatPanel, {
    label       = "Auto Swing",
    description = "Continuously trigger melee attacks",
    default     = false,
    onToggle    = function(on) State.AutoSwing = on end,
})

MakeToggle(CombatPanel, {
    label       = "Fast Attack",
    description = "Speed up attack animations for rapid melee",
    default     = false,
    onToggle    = function(on) State.FastAttack = on end,
})

SectionLbl(CombatPanel, "BOW  (Survival Game style)")

MakeToggle(CombatPanel, {
    label       = "Auto Full Charge",
    description = "Automatically hold bow at maximum charge on aim",
    default     = false,
    onToggle    = function(on) State.BowAutoCharge = on end,
})

MakeToggle(CombatPanel, {
    label       = "No Arrow Gravity",
    description = "Arrows fly in a straight horizontal line (no arc)",
    default     = false,
    onToggle    = function(on) State.BowNoGravity = on end,
})

MakeToggle(CombatPanel, {
    label       = "Arrow Speed Boost",
    description = "Multiply arrow projectile speed",
    default     = false,
    onToggle    = function(on, val)
        State.BowSpeedBoost = on
        if val then State.BowSpeedValue = val end
    end,
    slider = { min = 1, max = 10, default = 2, onChange = function(v) State.BowSpeedValue = v end },
})

MakeToggle(CombatPanel, {
    label       = "Instant Reload",
    description = "Remove reload delay after each arrow shot",
    default     = false,
    onToggle    = function(on) State.BowInstantReload = on end,
})

SectionLbl(CombatPanel, "DEFENSE")

MakeToggle(CombatPanel, {
    label       = "God Mode",
    description = "Continuously restore health to max (multi-method)",
    default     = false,
    onToggle    = function(on) State.GodMode = on end,
})

MakeToggle(CombatPanel, {
    label       = "Anti-Stun / Anti-Knockback",
    description = "Cancel ragdoll and knockback states",
    default     = false,
    onToggle    = function(on) State.AntiStun = on end,
})

-- COMBAT LOOPS
local combatTimer = 0
Track(RunService.Heartbeat:Connect(function(dt)
    combatTimer = combatTimer + dt

    -- Kill Aura (rate limited)
    if State.KillAura and combatTimer > 0.1 then
        pcall(function()
            local lhrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if lhrp then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr == LocalPlayer or not plr.Character then continue end
                    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                    if hrp and hum and (hrp.Position - lhrp.Position).Magnitude <= State.KillAuraRange then
                        hum:TakeDamage(1)
                    end
                end
            end
        end)
    end

    if combatTimer > 0.1 then combatTimer = 0 end

    -- God Mode
    if State.GodMode then
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            if hum.Health < hum.MaxHealth * 0.98 then
                hum.Health = hum.MaxHealth
            end
            -- Secondary: try boosting max health too
            if hum.MaxHealth < 1e5 then
                pcall(function() hum.MaxHealth = 1e5; hum.Health = 1e5 end)
            end
        end)
    end

    -- Anti-Stun
    if State.AntiStun then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                local s = hum:GetState()
                if s == Enum.HumanoidStateType.FallingDown or s == Enum.HumanoidStateType.Ragdoll then
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end
        end)
    end

    -- Fast Attack: speed up playing animation tracks
    if State.FastAttack then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                if track.Speed < 5 then track:AdjustSpeed(5) end
            end
        end)
    end

    -- Auto Swing (simulate click)
    if State.AutoSwing then
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                local remote = tool:FindFirstChildOfClass("RemoteEvent") or
                               tool:FindFirstChild("Attack") or
                               tool:FindFirstChild("Swing")
                if remote then remote:FireServer() end
            end
        end)
    end

    -- Bow: arrow gravity removal
    if State.BowNoGravity then
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name:lower():find("arrow") and
                   not obj:IsDescendantOf(LocalPlayer.Character or game) then
                    if obj.CustomPhysicalProperties then return end
                    pcall(function()
                        obj.Velocity = Vector3.new(obj.Velocity.X, 0, obj.Velocity.Z)
                    end)
                end
            end
        end)
    end

    -- Bow: speed boost
    if State.BowSpeedBoost then
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name:lower():find("arrow") and
                   not obj:IsDescendantOf(LocalPlayer.Character or game) then
                    local vel = obj.Velocity
                    if vel.Magnitude > 0 and vel.Magnitude < 200 then
                        obj.Velocity = vel.Unit * (vel.Magnitude * State.BowSpeedValue)
                    end
                end
            end
        end)
    end
end))

-- ═══════════════════════════════════════════════════
--  GAME PANEL
-- ═══════════════════════════════════════════════════
local GamePanel = MakePanel("Game")

SectionLbl(GamePanel, "SERVER TOOLS")

-- Server hop with player count filter option
do
    local hopCard  = Card(GamePanel, 86)
    N("TextLabel", {
        Size             = UDim2.new(1,-16,0,20),
        Position         = UDim2.new(0,12,0,8),
        BackgroundTransparency = 1,
        Text             = "Server Hop",
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, hopCard)
    N("TextLabel", {
        Size             = UDim2.new(1,-16,0,13),
        Position         = UDim2.new(0,12,0,26),
        BackgroundTransparency = 1,
        Text             = "Leave and join a different server of this game",
        TextColor3       = Config.SubText,
        Font             = Enum.Font.Gotham,
        TextSize         = 10,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, hopCard)

    local hopType = "Normal"
    local function HopTypeBtn(text, xOff)
        local b = N("TextButton", {
            Size             = UDim2.new(0,110,0,26),
            Position         = UDim2.new(0,xOff,1,-36),
            BackgroundColor3 = text == hopType and Color3.fromRGB(42,42,42) or Color3.fromRGB(30,30,30),
            Text             = text,
            TextColor3       = text == hopType and Config.Text or Config.SubText,
            Font             = Enum.Font.Gotham,
            TextSize         = 10,
            BorderSizePixel  = 0,
        }, hopCard)
        Corner(b, 5)
        return b
    end

    local normBtn = HopTypeBtn("Normal Server",  12)
    local smBtn   = HopTypeBtn("Low Population", 130)

    local function RefreshHopBtns()
        normBtn.BackgroundColor3 = hopType == "Normal" and Color3.fromRGB(42,42,42) or Color3.fromRGB(30,30,30)
        smBtn.BackgroundColor3   = hopType == "Small"  and Color3.fromRGB(42,42,42) or Color3.fromRGB(30,30,30)
        normBtn.TextColor3       = hopType == "Normal" and Config.Text or Config.SubText
        smBtn.TextColor3         = hopType == "Small"  and Config.Text or Config.SubText
    end

    normBtn.MouseButton1Click:Connect(function() hopType = "Normal"; RefreshHopBtns() end)
    smBtn.MouseButton1Click:Connect(function()   hopType = "Small";  RefreshHopBtns() end)

    local hopBtn = N("TextButton", {
        Size             = UDim2.new(0,70,0,26),
        Position         = UDim2.new(1,-82,1,-36),
        BackgroundColor3 = Color3.fromRGB(40,90,160),
        Text             = "Hop",
        TextColor3       = Color3.fromRGB(255,255,255),
        Font             = Enum.Font.GothamBold,
        TextSize         = 11,
        BorderSizePixel  = 0,
    }, hopCard)
    Corner(hopBtn, 5)
    Hover(hopBtn, Color3.fromRGB(55,115,195), Color3.fromRGB(40,90,160))

    hopBtn.MouseButton1Click:Connect(function()
        hopBtn.Text = "..."
        task.spawn(function()
            local success = false
            pcall(function()
                local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
                local raw = game:HttpGet(url)
                local data = HttpService:JSONDecode(raw)
                if data and data.data and #data.data > 0 then
                    local servers = {}
                    for _, sv in ipairs(data.data) do
                        if sv.id ~= game.JobId then
                            table.insert(servers, sv)
                        end
                    end
                    if hopType == "Small" then
                        table.sort(servers, function(a,b)
                            return (a.playing or 99) < (b.playing or 99)
                        end)
                    else
                        -- Pick a random normal server from top 20
                        if #servers > 1 then
                            local pick = math.random(1, math.min(20, #servers))
                            servers = {servers[pick]}
                        end
                    end
                    if #servers > 0 then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[1].id, LocalPlayer)
                        success = true
                    end
                end
            end)
            if not success then
                -- Fallback
                pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
            end
            task.wait(1)
            if hopBtn and hopBtn.Parent then hopBtn.Text = "Hop" end
        end)
    end)
end

MakeButton(GamePanel, "Rejoin (Same Game)", function()
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end)

-- ═══════════════════════════════════════════════════
--  SETTINGS PANEL
-- ═══════════════════════════════════════════════════
local SettingsPanel = MakePanel("Settings")

-- ─── THEME / COLOR PICKER ─────────────────────────
SectionLbl(SettingsPanel, "THEME")

do
    local pickerCard = Card(SettingsPanel, 210)
    N("TextLabel", {
        Size             = UDim2.new(1,-16,0,20),
        Position         = UDim2.new(0,12,0,6),
        BackgroundTransparency = 1,
        Text             = "Color Picker",
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamBold,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, pickerCard)

    -- Target selector
    local colorTarget = "Primary"
    local selFrame = N("Frame", {
        Size             = UDim2.new(1,-24,0,26),
        Position         = UDim2.new(0,12,0,28),
        BackgroundTransparency = 1,
    }, pickerCard)
    List(selFrame, Enum.FillDirection.Horizontal, 8)

    local function CSelBtn(text)
        local b = N("TextButton", {
            Size             = UDim2.new(0,120,1,0),
            BackgroundColor3 = text == colorTarget and Color3.fromRGB(42,42,42) or Color3.fromRGB(28,28,28),
            Text             = text .. " Color",
            TextColor3       = text == colorTarget and Config.Text or Config.SubText,
            Font             = Enum.Font.Gotham,
            TextSize         = 11,
            BorderSizePixel  = 0,
        }, selFrame)
        Corner(b, 6)
        return b
    end
    local primBtn2 = CSelBtn("Primary")
    local secBtn2  = CSelBtn("Secondary")

    local function RefreshCSel()
        primBtn2.BackgroundColor3 = colorTarget == "Primary"   and Color3.fromRGB(42,42,42) or Color3.fromRGB(28,28,28)
        secBtn2.BackgroundColor3  = colorTarget == "Secondary" and Color3.fromRGB(42,42,42) or Color3.fromRGB(28,28,28)
        primBtn2.TextColor3 = colorTarget == "Primary"   and Config.Text or Config.SubText
        secBtn2.TextColor3  = colorTarget == "Secondary" and Config.Text or Config.SubText
    end
    primBtn2.MouseButton1Click:Connect(function() colorTarget = "Primary";   RefreshCSel() end)
    secBtn2.MouseButton1Click:Connect(function()  colorTarget = "Secondary"; RefreshCSel() end)

    -- Hue bar
    local hueBar = N("Frame", {
        Size             = UDim2.new(1,-82,0,16),
        Position         = UDim2.new(0,12,0,62),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    }, pickerCard)
    Corner(hueBar, 4)
    Stroke(hueBar, Color3.fromRGB(44,44,44), 1)

    do
        local hg = Instance.new("UIGradient")
        hg.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0/6,  Color3.fromHSV(0/6,  1,1)),
            ColorSequenceKeypoint.new(1/6,  Color3.fromHSV(1/6,  1,1)),
            ColorSequenceKeypoint.new(2/6,  Color3.fromHSV(2/6,  1,1)),
            ColorSequenceKeypoint.new(3/6,  Color3.fromHSV(3/6,  1,1)),
            ColorSequenceKeypoint.new(4/6,  Color3.fromHSV(4/6,  1,1)),
            ColorSequenceKeypoint.new(5/6,  Color3.fromHSV(5/6,  1,1)),
            ColorSequenceKeypoint.new(0.999,Color3.fromHSV(0.999,1,1)),
        })
        hg.Parent = hueBar
    end

    local hueKnob = N("Frame", {
        Size             = UDim2.new(0,10,1,4),
        AnchorPoint      = Vector2.new(0.5,0.5),
        Position         = UDim2.new(0,0,0.5,0),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel  = 0,
        ZIndex           = hueBar.ZIndex+1,
    }, hueBar)
    Corner(hueKnob, 3)
    Stroke(hueKnob, Color3.fromRGB(0,0,0), 1)

    -- SV box  (correct orientation)
    --   background = current hue at full S and V
    --   white overlay  : left=opaque, right=transparent  (decreases S left→right = WRONG)
    --   Actually: left S=0 (white), right S=1 (full color)
    --   So white gradient: left opaque (Transparency=0), right transparent (Transparency=1)
    --   Black overlay: bottom V=0 (black), top V=1 (transparent)
    --   Rotation -90 makes gradient go bottom→top, so pos0=bottom, pos1=top
    local svBox = N("Frame", {
        Size             = UDim2.new(1,-82,0,80),
        Position         = UDim2.new(0,12,0,86),
        BackgroundColor3 = Color3.fromHSV(0,1,1),
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    }, pickerCard)
    Corner(svBox, 4)
    Stroke(svBox, Color3.fromRGB(44,44,44), 1)

    -- White overlay (left = white/opaque, right = transparent)
    local whiteOv = N("Frame", {
        Size             = UDim2.new(1,0,1,0),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel  = 0,
        ZIndex           = svBox.ZIndex+1,
    }, svBox)
    do
        local wg = Instance.new("UIGradient")
        wg.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255))
        wg.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),   -- left: fully opaque white
            NumberSequenceKeypoint.new(1, 1),   -- right: transparent (shows hue beneath)
        })
        wg.Rotation = 0   -- left to right
        wg.Parent = whiteOv
    end

    -- Black overlay (bottom = black/opaque, top = transparent)
    local blackOv = N("Frame", {
        Size             = UDim2.new(1,0,1,0),
        BackgroundColor3 = Color3.fromRGB(0,0,0),
        BorderSizePixel  = 0,
        ZIndex           = svBox.ZIndex+2,
    }, svBox)
    do
        local bg = Instance.new("UIGradient")
        bg.Color = ColorSequence.new(Color3.fromRGB(0,0,0), Color3.fromRGB(0,0,0))
        bg.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),   -- position 0 = bottom (with -90 rotation) = transparent? 
            NumberSequenceKeypoint.new(1, 0),   -- position 1 = top = opaque black
        })
        -- With Rotation = 90: pos 0 is TOP, pos 1 is BOTTOM
        -- We want: TOP = transparent, BOTTOM = opaque
        -- So: pos0 (top) = transparent (1), pos1 (bottom) = opaque (0)  → Rotation = 90
        bg.Rotation = 90
        bg.Parent = blackOv
    end

    local svKnob = N("Frame", {
        Size             = UDim2.new(0,13,0,13),
        AnchorPoint      = Vector2.new(0.5,0.5),
        Position         = UDim2.new(1,0,0,0),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel  = 0,
        ZIndex           = svBox.ZIndex+3,
    }, svBox)
    Corner(svKnob, 7)
    Stroke(svKnob, Color3.fromRGB(0,0,0), 1)

    -- Preview swatch
    local preview = N("Frame", {
        Size             = UDim2.new(0,56,0,56),
        Position         = UDim2.new(1,-68,0,62),
        BackgroundColor3 = Config.Primary,
        BorderSizePixel  = 0,
    }, pickerCard)
    Corner(preview, 8)
    Stroke(preview, Color3.fromRGB(50,50,50), 1)

    -- State
    local H, S, V = 0, 0, 0.05
    local hueDragging = false
    local svDragging  = false

    local function ApplyColor()
        local col = Color3.fromHSV(H, S, V)
        preview.BackgroundColor3 = col
        if colorTarget == "Primary" then
            Config.Primary = col
            MainFrame.BackgroundColor3 = col
        else
            Config.Secondary = col
            TitleBar.BackgroundColor3  = col
            Sidebar.BackgroundColor3   = col
        end
    end

    local function MoveHue(x)
        local rel = math.clamp((x - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
        H = rel
        hueKnob.Position       = UDim2.new(rel, 0, 0.5, 0)
        svBox.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
        ApplyColor()
    end

    local function MoveSV(x, y)
        -- X = saturation (0 left, 1 right)
        -- Y = value inverted (0 top = V=1, 1 bottom = V=0)
        S = math.clamp((x - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
        V = 1 - math.clamp((y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
        svKnob.Position = UDim2.new(S, 0, 1-V, 0)
        ApplyColor()
    end

    hueBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then hueDragging = true; MoveHue(i.Position.X) end
    end)
    svBox.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then svDragging = true; MoveSV(i.Position.X, i.Position.Y) end
    end)
    Track(UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if hueDragging then MoveHue(i.Position.X) end
        if svDragging  then MoveSV(i.Position.X, i.Position.Y) end
    end))
    Track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then hueDragging = false; svDragging = false end
    end))
end

-- ─── KEYBINDS ─────────────────────────────────────
SectionLbl(SettingsPanel, "KEYBINDS")

local keybindButtons = {}
local listeningKB    = nil  -- id currently being rebound

local function KeyName(bind)
    if not bind then return "None" end
    if typeof(bind) == "EnumItem" then
        if bind.EnumType == Enum.KeyCode then return bind.Name end
        if bind.EnumType == Enum.UserInputType then
            local n = bind.Name
            -- friendly names for mouse buttons
            if n == "MouseButton1" then return "Mouse1" end
            if n == "MouseButton2" then return "Mouse2" end
            if n == "MouseButton3" then return "Mouse3" end
            if n:find("MouseButton") then return "Mouse" .. n:match("%d+") end
            return n
        end
    end
    return tostring(bind)
end

local kbCard = Card(SettingsPanel, 14 + #KeybindOrder * 36 + 10)

for i, id in ipairs(KeybindOrder) do
    local lbl = KeybindLabels[id]
    local yOff = 8 + (i-1) * 36

    N("TextLabel", {
        Size             = UDim2.new(0.55,0,0,28),
        Position         = UDim2.new(0,12,0,yOff+4),
        BackgroundTransparency = 1,
        Text             = lbl,
        TextColor3       = Config.Text,
        Font             = Enum.Font.Gotham,
        TextSize         = 11,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, kbCard)

    local kbBtn = N("TextButton", {
        Size             = UDim2.new(0,140,0,26),
        Position         = UDim2.new(1,-152,0,yOff+5),
        BackgroundColor3 = Color3.fromRGB(30,30,30),
        Text             = KeyName(Keybinds[id]),
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 11,
        BorderSizePixel  = 0,
    }, kbCard)
    Corner(kbBtn, 5)
    keybindButtons[id] = kbBtn

    kbBtn.MouseButton1Click:Connect(function()
        if listeningKB then
            -- cancel previous
            if keybindButtons[listeningKB] then
                keybindButtons[listeningKB].Text             = KeyName(Keybinds[listeningKB])
                keybindButtons[listeningKB].TextColor3       = Config.Text
                keybindButtons[listeningKB].BackgroundColor3 = Color3.fromRGB(30,30,30)
            end
        end
        listeningKB = id
        kbBtn.Text             = "Press any key…"
        kbBtn.TextColor3       = Config.Accent
        kbBtn.BackgroundColor3 = Color3.fromRGB(20,40,60)
    end)
end

-- Listen for keybind input (also handles keybind actions)
Track(UserInputService.InputBegan:Connect(function(input, gp)
    -- Rebinding mode
    if listeningKB then
        local bind = nil
        if input.UserInputType == Enum.UserInputType.Keyboard then
            bind = input.KeyCode
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 or
               input.UserInputType == Enum.UserInputType.MouseButton2 or
               input.UserInputType == Enum.UserInputType.MouseButton3 or
               input.UserInputType.Name:find("MouseButton") then
            bind = input.UserInputType
        end
        if bind then
            Keybinds[listeningKB] = bind
            if keybindButtons[listeningKB] then
                keybindButtons[listeningKB].Text             = KeyName(bind)
                keybindButtons[listeningKB].TextColor3       = Config.Text
                keybindButtons[listeningKB].BackgroundColor3 = Color3.fromRGB(30,30,30)
            end
            listeningKB = nil
        end
        return
    end

    if gp then return end

    -- Keybind actions
    local function matches(id)
        local bind = Keybinds[id]
        if not bind then return false end
        if bind.EnumType == Enum.KeyCode         then return input.KeyCode == bind end
        if bind.EnumType == Enum.UserInputType   then return input.UserInputType == bind end
        return false
    end

    if matches("ToggleMenu") then
        if State.IsMinimized then
            -- handled below via BubbleBtn logic
        else
            State.GuiVisible = not State.GuiVisible
            MainFrame.Visible = State.GuiVisible
        end
    elseif matches("ToggleFly") and _flyToggle then
        _flyToggle(not State.FlyEnabled)
    elseif matches("ToggleSpeed") and _speedToggle then
        _speedToggle(not State.SpeedEnabled)
    elseif matches("ToggleNoclip") and _noclipToggle then
        _noclipToggle(not State.NoclipEnabled)
    elseif matches("ToggleESP") then
        local all = not State.BoxESP
        State.BoxESP       = all
        State.Chams        = all
        State.NameESP      = all
        State.HealthBarESP = all
        State.DistanceESP  = all
        ClearAllESP()
        if all then RebuildHighlights() end
    elseif matches("ForceRespawn") then
        pcall(function()
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = 0 end
        end)
    elseif matches("ToggleGodMode") then
        State.GodMode = not State.GodMode
    end
end))

-- ─── WINDOW SIZE ──────────────────────────────────
SectionLbl(SettingsPanel, "WINDOW SIZE")

do
    local wsCard = Card(SettingsPanel, 100)

    -- Manual inputs row
    N("TextLabel", {
        Size             = UDim2.new(0.35,0,0,28),
        Position         = UDim2.new(0,12,0,8),
        BackgroundTransparency = 1,
        Text             = "Window Size",
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, wsCard)

    local function SzInput(x, def)
        local tb = N("TextBox", {
            Size             = UDim2.new(0,58,0,26),
            Position         = UDim2.new(1,x,0,9),
            BackgroundColor3 = Color3.fromRGB(28,28,28),
            Text             = tostring(def),
            TextColor3       = Config.Text,
            Font             = Enum.Font.Gotham,
            TextSize         = 12,
            BorderSizePixel  = 0,
        }, wsCard)
        Corner(tb, 5)
        return tb
    end

    local wIn = SzInput(-140, Config.Width)
    N("TextLabel", {
        Size             = UDim2.new(0,16,0,26),
        Position         = UDim2.new(1,-80,0,9),
        BackgroundTransparency = 1,
        Text             = "x",
        TextColor3       = Config.SubText,
        Font             = Enum.Font.GothamBold,
        TextSize         = 14,
    }, wsCard)
    local hIn = SzInput(-62, Config.Height)

    local function ApplySize(w, h)
        w = math.clamp(math.round(w or Config.Width),  Config.MinWidth,  1400)
        h = math.clamp(math.round(h or Config.Height), Config.MinHeight, 900)
        Config.Width  = w
        Config.Height = h
        wIn.Text = tostring(w)
        hIn.Text = tostring(h)
        TweenService:Create(MainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            Size     = UDim2.new(0, w, 0, h),
            Position = UDim2.new(0.5, -w/2, 0.5, -h/2),
        }):Play()
    end

    wIn.FocusLost:Connect(function() ApplySize(tonumber(wIn.Text), Config.Height) end)
    hIn.FocusLost:Connect(function() ApplySize(Config.Width, tonumber(hIn.Text))  end)

    -- Divider
    N("Frame", {
        Size             = UDim2.new(1,-24,0,1),
        Position         = UDim2.new(0,12,0,44),
        BackgroundColor3 = Color3.fromRGB(36,36,36),
        BorderSizePixel  = 0,
    }, wsCard)

    -- Live size slider (scales both dimensions proportionally)
    N("TextLabel", {
        Size             = UDim2.new(0,80,0,14),
        Position         = UDim2.new(0,12,0,50),
        BackgroundTransparency = 1,
        Text             = "Live Resize",
        TextColor3       = Config.SubText,
        Font             = Enum.Font.Gotham,
        TextSize         = 10,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, wsCard)

    local liveTrack = N("Frame", {
        Size             = UDim2.new(1,-24,0,4),
        Position         = UDim2.new(0,12,0,68),
        BackgroundColor3 = Color3.fromRGB(38,38,38),
        BorderSizePixel  = 0,
    }, wsCard)
    Corner(liveTrack, 2)

    local liveFill = N("Frame", {
        Size             = UDim2.new(0.5,0,1,0),  -- default: middle
        BackgroundColor3 = Config.Accent,
        BorderSizePixel  = 0,
    }, liveTrack)
    Corner(liveFill, 2)

    local liveKnob = N("Frame", {
        Size             = UDim2.new(0,13,0,13),
        AnchorPoint      = Vector2.new(0.5,0.5),
        Position         = UDim2.new(0.5,0,0.5,0),
        BackgroundColor3 = Color3.fromRGB(230,230,230),
        BorderSizePixel  = 0,
        ZIndex           = liveTrack.ZIndex+1,
    }, liveTrack)
    Corner(liveKnob, 7)

    local liveLbl = N("TextLabel", {
        Size             = UDim2.new(0,46,0,14),
        Position         = UDim2.new(1,-4,0,50),
        BackgroundTransparency = 1,
        Text             = "700",
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamBold,
        TextSize         = 10,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, wsCard)

    local liveDrag = false
    -- Scale range: MinWidth→1400, ratio height = width * (Config.Height/Config.Width)
    local function MoveLive(x)
        local rel = math.clamp((x - liveTrack.AbsolutePosition.X) / liveTrack.AbsoluteSize.X, 0, 1)
        local newW = math.round(Config.MinWidth + rel * (1400 - Config.MinWidth))
        local ratio = Config.Height / Config.Width
        local newH = math.clamp(math.round(newW * ratio), Config.MinHeight, 900)
        liveFill.Size     = UDim2.new(rel,0,1,0)
        liveKnob.Position = UDim2.new(rel,0,0.5,0)
        liveLbl.Text      = tostring(newW)
        ApplySize(newW, newH)
    end

    liveTrack.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then liveDrag = true; MoveLive(i.Position.X) end
    end)
    Track(UserInputService.InputChanged:Connect(function(i)
        if liveDrag and i.UserInputType == Enum.UserInputType.MouseMovement then MoveLive(i.Position.X) end
    end))
    Track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then liveDrag = false end
    end))
end

-- ═══════════════════════════════════════════════════
--  CATEGORY NAVIGATION
-- ═══════════════════════════════════════════════════
local Panels = {
    Player   = PlayerPanel,
    Visuals  = VisualsPanel,
    Combat   = CombatPanel,
    Game     = GamePanel,
    Settings = SettingsPanel,
}
local CatIcons = {
    Player  = "P", Visuals = "V", Combat = "C",
    Game    = "G", Settings = "S",
}
local CatOrder = {"Player","Visuals","Combat","Game","Settings"}
local CatBtns  = {}

local function SwitchTo(name)
    for n, p in pairs(Panels) do p.Visible = n == name end
    State.ActiveCategory = name
    for n, btn in pairs(CatBtns) do
        local active = n == name
        TweenService:Create(btn, TweenInfo.new(0.1), {
            BackgroundColor3       = active and Color3.fromRGB(36,36,36) or Color3.fromRGB(0,0,0),
            BackgroundTransparency = active and 0 or 1,
        }):Play()
        local lbl2 = btn:FindFirstChildWhichIsA("TextLabel", true)
        if lbl2 then lbl2.TextColor3 = active and Config.Text or Config.SubText end
    end
end

local catIcons2 = {
    Player  = "👤",
    Visuals = "👁",
    Combat  = "⚔",
    Game    = "🎮",
    Settings= "⚙",
}

for i, name in ipairs(CatOrder) do
    local btn = N("TextButton", {
        Name             = name,
        Size             = UDim2.new(1,0,0,36),
        BackgroundColor3 = name == "Player" and Color3.fromRGB(36,36,36) or Color3.fromRGB(0,0,0),
        BackgroundTransparency = name == "Player" and 0 or 1,
        Text             = "",
        BorderSizePixel  = 0,
        LayoutOrder      = i,
    }, CatList)
    Corner(btn, 6)

    N("TextLabel", {
        Size             = UDim2.new(0,22,1,0),
        Position         = UDim2.new(0,8,0,0),
        BackgroundTransparency = 1,
        Text             = catIcons2[name],
        TextColor3       = Config.Text,
        Font             = Enum.Font.Gotham,
        TextSize         = 14,
    }, btn)
    N("TextLabel", {
        Size             = UDim2.new(1,-34,1,0),
        Position         = UDim2.new(0,33,0,0),
        BackgroundTransparency = 1,
        Text             = name,
        TextColor3       = name == "Player" and Config.Text or Config.SubText,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, btn)

    CatBtns[name] = btn
    btn.MouseButton1Click:Connect(function() SwitchTo(name) end)
    btn.MouseEnter:Connect(function()
        if State.ActiveCategory ~= name then
            TweenService:Create(btn, TweenInfo.new(0.08), {
                BackgroundColor3 = Color3.fromRGB(26,26,26),
                BackgroundTransparency = 0,
            }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if State.ActiveCategory ~= name then
            TweenService:Create(btn, TweenInfo.new(0.08), {BackgroundTransparency = 1}):Play()
        end
    end)
end

SwitchTo("Player")

-- ═══════════════════════════════════════════════════
--  WINDOW DRAGGING
-- ═══════════════════════════════════════════════════
do
    local dragging, dragStart, startPos = false, nil, nil
    TitleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = i.Position
            startPos  = MainFrame.Position
        end
    end)
    Track(UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end))
    Track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
end

-- ═══════════════════════════════════════════════════
--  MINIMIZE → BUBBLE (devil icon)
-- ═══════════════════════════════════════════════════
local BubbleBtn = N("TextButton", {
    Size             = UDim2.new(0, 54, 0, 54),
    Position         = UDim2.new(0, 80, 1, -74),  -- near panic button
    BackgroundColor3 = Color3.fromRGB(14, 14, 14),
    Text             = "👹",
    TextSize         = 24,
    BorderSizePixel  = 0,
    Visible          = false,
    ZIndex           = 200,
}, ScreenGui)
Corner(BubbleBtn, 27)
Stroke(BubbleBtn, Color3.fromRGB(48,48,48), 1.5)

-- Draggable bubble
do
    local d, ds, sp = false, nil, nil
    BubbleBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then d=true; ds=i.Position; sp=BubbleBtn.Position end
    end)
    Track(UserInputService.InputChanged:Connect(function(i)
        if d and i.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = i.Position - ds
            BubbleBtn.Position = UDim2.new(sp.X.Scale, sp.X.Offset+delta.X, sp.Y.Scale, sp.Y.Offset+delta.Y)
        end
    end))
    Track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then d=false end
    end))
end

local function RestoreFromBubble()
    State.IsMinimized = false
    BubbleBtn.Visible  = false
    MainFrame.Visible  = true
    MainFrame.Size     = UDim2.new(0, 0, 0, 0)
    local w, h = Config.Width, Config.Height
    TweenService:Create(MainFrame, TweenInfo.new(0.26, Enum.EasingStyle.Back), {
        Size     = UDim2.new(0, w, 0, h),
        Position = UDim2.new(0.5, -w/2, 0.5, -h/2),
    }):Play()
end

MinBtn.MouseButton1Click:Connect(function()
    State.IsMinimized = true
    local cx = MainFrame.Position.X.Offset + Config.Width/2
    local cy = MainFrame.Position.Y.Offset + Config.Height/2
    local tw = TweenService:Create(MainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size     = UDim2.new(0,0,0,0),
        Position = UDim2.new(0,cx,0,cy),
    })
    tw:Play()
    tw.Completed:Connect(function()
        MainFrame.Visible  = false
        MainFrame.Size     = UDim2.new(0, Config.Width, 0, Config.Height)
        MainFrame.Position = UDim2.new(0.5, -Config.Width/2, 0.5, -Config.Height/2)
        BubbleBtn.Visible  = true
        BubbleBtn.Size     = UDim2.new(0, 0, 0, 0)
        TweenService:Create(BubbleBtn, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
            Size = UDim2.new(0,54,0,54)
        }):Play()
    end)
end)

BubbleBtn.MouseButton1Click:Connect(RestoreFromBubble)

-- CLOSE (hide UI, all scripts continue running)
CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(MainFrame, TweenInfo.new(0.14), {BackgroundTransparency = 1}):Play()
    task.delay(0.15, function()
        MainFrame.Visible = false
        MainFrame.BackgroundTransparency = 0
        State.GuiVisible = false
    end)
end)

-- ═══════════════════════════════════════════════════
--  CHARACTER RESPAWN RECONNECTION
--  Restores active features after respawn
-- ═══════════════════════════════════════════════════
local function OnCharAdded(char)
    char:WaitForChild("HumanoidRootPart", 10)
    task.wait(0.5)
    if State.FlyEnabled     then EnableFly() end
    if State.NoclipEnabled  then noclipState = true end
    if State.JumpEnabled    then
        -- Reconnect jump
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local jc = 0
            table.insert(JumpConns, hum.StateChanged:Connect(function(_, new)
                if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then jc = 0 end
            end))
            table.insert(JumpConns, UserInputService.JumpRequest:Connect(function()
                local h2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if not h2 then return end
                if State.JumpType == "Infinity" then
                    h2:ChangeState(Enum.HumanoidStateType.Jumping)
                elseif State.JumpType == "Double" and jc < 2 then
                    jc = jc + 1
                    h2:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end))
        end
    end
end

Track(LocalPlayer.CharacterAdded:Connect(OnCharAdded))
if LocalPlayer.Character then task.spawn(OnCharAdded, LocalPlayer.Character) end

-- ═══════════════════════════════════════════════════
--  DONE
-- ═══════════════════════════════════════════════════
print("╔══════════════════════════════════════════╗")
print("║  Admin Panel v3.0.0  loaded              ║")
print("║  [INSERT] = toggle menu                  ║")
print("║  [END]    = force respawn                ║")
print("╚══════════════════════════════════════════╝")
