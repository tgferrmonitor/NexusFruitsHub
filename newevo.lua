--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║              NEXUS EVO DISTANCE  —  MODERN                   ║
    ║  F1 / FARM = Initiator (Starts everything)                   ║
    ║  - Automatic Speed (60) and Zoom (100)                       ║
    ║  - Automatic Battle and Loop detection                       ║
    ║  - Skill Slot 1 ONLY                                         ║
    ║  - Catch action (E, C or OFF) dynamically verified           ║
    ║  - Target Distance with 3-step range (30m, 50m, 90m)         ║
    ║  - Minimized Mode (Draggable) & Notification System          ║
    ║  - FPS Boost toggle (mini UI) with full restore on OFF       ║
    ╚══════════════════════════════════════════════════════════════╝
]]

if _G.NexusRoutesActive then
    warn("[NexusRoutes] Already running — destroying previous instance")
    pcall(function() _G.NexusRoutesActive() end)
end

local exec = {}
exec.request = (type(syn) == "table" and syn.request) or (type(http) == "table" and http.request) or rawget(_G, "http_request") or rawget(_G, "request") or nil
exec.writefile = rawget(_G, "writefile") or nil
exec.readfile  = rawget(_G, "readfile")  or nil
function exec.hasFileIO() return type(exec.writefile) == "function" and type(exec.readfile) == "function" end

local Svc = {
    Players   = game:GetService("Players"),
    Run       = game:GetService("RunService"),
    Tween     = game:GetService("TweenService"),
    Input     = game:GetService("UserInputService"),
    Http      = game:GetService("HttpService"),
    Workspace = game:GetService("Workspace"),
    CoreGui   = game:GetService("CoreGui")
}
local VIM; pcall(function() VIM = game:GetService("VirtualInputManager") end)
local LP = game.Players.LocalPlayer

local C = {
    bg      = Color3.fromRGB(10,  14,  20),
    nav     = Color3.fromRGB( 8,  11,  17),
    item    = Color3.fromRGB(20,  30,  42),
    itemH   = Color3.fromRGB(30,  46,  60),
    border  = Color3.fromRGB( 0,  80, 120),
    accent  = Color3.fromRGB( 0, 150, 255),
    acc2    = Color3.fromRGB( 0, 120, 220),
    text    = Color3.fromRGB(220,230,255),
    sub     = Color3.fromRGB(140,180,220),
    white   = Color3.fromRGB(255,255,255),
    red     = Color3.fromRGB(220,  50,  50),
    orange  = Color3.fromRGB(255, 150,   0),
    green   = Color3.fromRGB(  0, 210,  80),
    dimred  = Color3.fromRGB( 50,  10,  10),
    dimgrn  = Color3.fromRGB( 10,  50,  20),
    dark1   = Color3.fromRGB(12,  20,  28),
    dark2   = Color3.fromRGB(38,  50,  62),
    bdr2    = Color3.fromRGB(28,  48,  68),
    neonBlue= Color3.fromRGB(50, 220, 255),
    fpsOn   = Color3.fromRGB( 30, 160,  90),
    fpsOff  = Color3.fromRGB( 40,  55,  70),
}

local State = {
    huntOn          = false,
    _huntTask       = nil,
    currentTarget   = nil,
    huntRange       = 30,
    maxHuntDistance = 150,
    walkSpeed       = 60,
    speedOn         = false,
    _keysActive     = { W=false, A=false, S=false, D=false },
    inBattle        = false,
    battleDetection = false,
    skillInterval   = 1.0,
    _battleTask     = nil,
    _skillTask      = nil,
    inCatch         = false,
    catchKey        = "E",
    catchInterval   = 1.0,
    _catchTask      = nil,
    farmOn          = false,
    zoomOn          = false,
    zoomValue       = 100,
    statusLbl       = nil,
    statusDot       = nil,
    fpsBoostOn      = false,
}

local function HttpRequest(url)
    local success, response = pcall(function() if syn and syn.request then return syn.request({ Url = url, Method = "GET" }).Body end end)
    if success and response and response ~= "" then return response end
    success, response = pcall(function() if http_request then return http_request({ Url = url, Method = "GET" }).Body end end)
    if success and response and response ~= "" then return response end
    success, response = pcall(function() if request then return request({ Url = url, Method = "GET" }).Body end end)
    if success and response and response ~= "" then return response end
    success, response = pcall(function() return game:GetService("HttpService"):GetAsync(url) end)
    if success and response and response ~= "" then return response end
    return nil
end

local API_BASE    = "https://api.tgferr.com.br"
local SCRIPT_NAME = "Evomon AutoFarm"

repeat task.wait() until game:IsLoaded() and LP and LP.Character
local HttpService = game:GetService("HttpService")

local function checkAccess(maxRetries, delay)
    for i = 1, maxRetries do
        local url = API_BASE .. "/api/check-access/" .. tostring(LP.UserId)
        local response = HttpRequest(url)
        if response then
            local ok, result = pcall(HttpService.JSONDecode, HttpService, response)
            if ok and result then
                if result.has_valid_access == true then return true, result.discord_id else return false, nil end
            end
        end
        if i < maxRetries then task.wait(delay) end
    end
    return false, nil
end

local function sendHeartbeat(discord_id)
    pcall(function()
        local level = "?"
        pcall(function() if LP:FindFirstChild("Data") and LP.Data:FindFirstChild("Level") then level = tostring(LP.Data.Level.Value) end end)
        local payload = { roblox_id = tostring(LP.UserId), roblox_name = tostring(LP.Name), level = level, using_script = SCRIPT_NAME, discord_id = discord_id or "" }
        local ok, body = pcall(HttpService.JSONEncode, HttpService, payload)
        if not ok or body == nil then return end
        pcall(function()
            local req = (syn and syn.request) or http_request or request
            if req then req({ Url = API_BASE .. "/api/heartbeat", Method = "POST", Body = body, Headers = {["Content-Type"] = "application/json"} })
            else HttpService:PostAsync(API_BASE .. "/api/heartbeat", body, Enum.HttpContentType.ApplicationJson) end
        end)
    end)
end

_G.StopHeartbeat = false
local function startHeartbeat(discord_id)
    task.spawn(function() while not _G.StopHeartbeat do sendHeartbeat(discord_id); task.wait(300) end end)
end

local hasAccess, discord_id = checkAccess(5, 2)
if not hasAccess then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/tgferrmonitor/NexusFruitsHub/refs/heads/main/nexusproxy.lua"))()
    return
end
startHeartbeat(discord_id)

if _G.NexusAntiAfkTask then pcall(task.cancel, _G.NexusAntiAfkTask); _G.NexusAntiAfkTask = nil end
_G.NexusAntiAfkTask = task.spawn(function()
    while true do
        task.wait(19 * 60)
        if VIM then pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.W, false, game); task.wait(0.05); VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game) end) end
    end
end)

local PERSIST_FILE = "nexus_evo_routes_v8.json"
local Persist = {}
function Persist.save()
    if not exec.hasFileIO() then return end
    pcall(function() writefile(PERSIST_FILE, HttpService:JSONEncode({ huntRange = State.huntRange })) end)
end
function Persist.load()
    if not exec.hasFileIO() then return end
    local ok, raw = pcall(readfile, PERSIST_FILE)
    if not (ok and raw and #raw > 0) then return end
    local ok2, d = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 or type(d) ~= "table" then return end
    if type(d.huntRange) == "number" then State.huntRange = d.huntRange end
end

local UI = {}
local mainScreenGui = nil

function UI.tween(obj, t, props, style) Svc.Tween:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint), props):Play() end
function UI.corner(r, p) local c = Instance.new("UICorner", p); c.CornerRadius = UDim.new(0, r); return c end
function UI.round(p) local c = Instance.new("UICorner", p); c.CornerRadius = UDim.new(1, 0); return c end
function UI.stroke(col, th, p) local s = Instance.new("UIStroke", p); s.Color = col; s.Thickness = th or 1; return s end
function UI.pulse(objs, tMin, tMax, dur, prop)
    if typeof(objs) ~= "table" then objs = { objs } end; tMin, tMax, dur, prop = tMin or 0.35, tMax or 0.85, dur or 1.1, prop or "BackgroundTransparency"; local alive = true
    task.spawn(function() local up = true; while alive do for _, o in ipairs(objs) do if o and o.Parent then UI.tween(o, dur, { [prop] = up and tMin or tMax }, Enum.EasingStyle.Sine) end end; task.wait(dur); up = not up end end)
    return function() alive = false end
end
function UI.gradient(p, c1, c2, rot) local g = Instance.new("UIGradient", p); g.Color = ColorSequence.new(c1, c2); g.Rotation = rot or 90; return g end
function UI.pressFeedback(btn)
    btn.MouseButton1Down:Connect(function() UI.tween(btn, 0.08, { Size = UDim2.new(btn.Size.X.Scale, btn.Size.X.Offset - 4, btn.Size.Y.Scale, btn.Size.Y.Offset - 4) }) end)
    btn.MouseButton1Up:Connect(function() UI.tween(btn, 0.12, { Size = UDim2.new(btn.Size.X.Scale, btn.Size.X.Offset + 4, btn.Size.Y.Scale, btn.Size.Y.Offset + 4) }) end)
end
function UI.pad(t, l, r, b, p) local pd = Instance.new("UIPadding", p); pd.PaddingTop = UDim.new(0, t or 0); pd.PaddingLeft = UDim.new(0, l or 0); pd.PaddingRight = UDim.new(0, r or 0); pd.PaddingBottom = UDim.new(0, b or 0) end
function UI.listLayout(p, dir, pad, sort, alignX, alignY)
    local ul = Instance.new("UIListLayout", p); ul.FillDirection = dir or Enum.FillDirection.Vertical; ul.Padding = UDim.new(0, pad or 0); ul.SortOrder = sort or Enum.SortOrder.LayoutOrder; if alignX then ul.HorizontalAlignment = alignX end; if alignY then ul.VerticalAlignment = alignY end
    return ul
end
function UI.label(props, p)
    local l = Instance.new("TextLabel", p); l.BackgroundTransparency = 1; l.Font = props.Font or Enum.Font.GothamMedium; l.TextSize = props.TextSize or 13; l.TextColor3 = props.TextColor3 or C.text; l.Text = props.Text or ""; l.Size = props.Size or UDim2.new(1,0,1,0); l.Position = props.Position or UDim2.new(0,0,0,0); l.TextXAlignment = props.AlignX or Enum.TextXAlignment.Left; l.TextYAlignment = props.AlignY or Enum.TextYAlignment.Center; l.TextWrapped = props.Wrap or false; l.TextTruncate = props.Truncate or Enum.TextTruncate.None; if props.Name then l.Name = props.Name end
    return l
end
function UI.circleBtn(props, p)
    local d = props.d or 40; local b = Instance.new("TextButton", p); b.Size = UDim2.new(0, d, 0, d); b.BackgroundColor3 = props.bg or C.item; b.Text = props.icon or ""; b.Font = Enum.Font.GothamBold; b.TextSize = props.textSize or math.floor(d * 0.42); b.TextColor3 = props.iconColor or C.text; b.AutoButtonColor = false; b.LayoutOrder = props.order or 0; UI.round(b); UI.stroke(props.border or C.bdr2, 1, b); local baseBg, hoverBg = props.bg or C.item, props.hover or C.itemH
    b.MouseEnter:Connect(function() UI.tween(b, 0.15, { BackgroundColor3 = hoverBg }) end); b.MouseLeave:Connect(function() UI.tween(b, 0.15, { BackgroundColor3 = baseBg }) end); if props.onClick then b.MouseButton1Click:Connect(props.onClick) end
    return b
end

function UI.notify(msg, isError)
    if not mainScreenGui then return end
    local notif = Instance.new("Frame", mainScreenGui)
    notif.Size = UDim2.new(0, 260, 0, 44)
    notif.Position = UDim2.new(0.5, 0, 0, -60)
    notif.AnchorPoint = Vector2.new(0.5, 0)
    notif.BackgroundColor3 = C.dark1
    notif.ZIndex = 50
    UI.corner(8, notif)
    UI.stroke(isError and C.red or C.accent, 1.5, notif)
    UI.gradient(notif, isError and Color3.fromRGB(40, 15, 15) or Color3.fromRGB(15, 25, 40), 90)

    local icon = UI.label({ Text = isError and "⚠️" or "✅", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.white, Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(0, 10, 0, 0), AlignX = Enum.TextXAlignment.Center }, notif)
    local lbl = UI.label({ Text = msg, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = isError and C.orange or C.text, Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 45, 0, 0), Wrap = true }, notif)

    UI.tween(notif, 0.4, { Position = UDim2.new(0.5, 0, 0, 20) }, Enum.EasingStyle.Back)
    
    task.delay(3.5, function()
        local tw = Svc.Tween:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -60), BackgroundTransparency = 1 })
        tw:Play()
        tw.Completed:Connect(function() notif:Destroy() end)
    end)
end

function UI.miniSliderSnap(parent, props)
    local track = Instance.new("Frame", parent); track.Size = UDim2.new(1, 0, 0, 6); track.AnchorPoint = Vector2.new(0, 0.5); track.Position = UDim2.new(0, 0, 0.5, 0); track.BackgroundColor3 = Color3.fromRGB(20,28,40); UI.round(track); UI.stroke(C.bdr2, 1, track).Transparency = 0.5
    local fill = Instance.new("Frame", track); fill.BackgroundColor3 = C.accent; fill.BorderSizePixel = 0; fill.ZIndex = 2; UI.round(fill); UI.gradient(fill, C.acc2, C.accent, 0)
    local thumb = Instance.new("Frame", track); thumb.Size = UDim2.new(0,16,0,16); thumb.BackgroundColor3 = C.white; thumb.ZIndex = 3; UI.round(thumb); UI.stroke(C.accent, 2, thumb)
    local valL = props.valueLabel
    local vals = props.snapValues; local curIdx = 1; for i,v in ipairs(vals) do if v == props.default then curIdx = i; break end end
    local dragging = false
    local function applyIdx(idx)
        idx = math.clamp(idx, 1, #vals)
        curIdx = idx; local pct = (idx - 1) / (#vals - 1)
        fill.Size = UDim2.new(pct, 0, 1, 0); thumb.Position = UDim2.new(pct, -8, 0.5, -8)
        if valL then valL.Text = tostring(vals[idx]) .. (props.suffix or "") end
        if props.onChange then props.onChange(vals[idx]) end
    end
    local function setFromX(px)
        local tw = track.AbsoluteSize.X; if tw == 0 then return end
        local rawPct = math.clamp((px - track.AbsolutePosition.X) / tw, 0, 1)
        applyIdx(math.floor(rawPct * (#vals - 1) + 0.5) + 1)
    end
    applyIdx(curIdx)
    thumb.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true end end)
    track.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; setFromX(i.Position.X) end end)
    Svc.Input.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
    Svc.Input.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then setFromX(i.Position.X) end end)
    return track
end

local Input = {}
function Input.pressKey(kcode)
    if not VIM then return false end
    pcall(function() VIM:SendKeyEvent(true, kcode, false, game); task.wait(0.05); VIM:SendKeyEvent(false, kcode, false, game) end)
    return true
end
function Input.holdKey(key, active)
    if not VIM then return false end
    local kcode = Enum.KeyCode[key]
    if not kcode then return false end
    if active and not State._keysActive[key] then pcall(function() VIM:SendKeyEvent(true, kcode, false, game) end); State._keysActive[key] = true
    elseif not active and State._keysActive[key] then pcall(function() VIM:SendKeyEvent(false, kcode, false, game) end); State._keysActive[key] = false end
    return true
end
function Input.releaseAll() for key in pairs(State._keysActive) do Input.holdKey(key, false) end end

local Zoom = {}
local _zoomConn = nil
function Zoom.apply(studs) pcall(function() LP.CameraMaxZoomDistance = studs end) end
function Zoom.setEnabled(on, studs)
    if _zoomConn then _zoomConn:Disconnect(); _zoomConn = nil end
    if on then
        _G.InfZoom = true; Zoom.apply(studs)
        _zoomConn = LP.CharacterAdded:Connect(function() task.wait(0.5); if _G.InfZoom then Zoom.apply(studs) end end)
    else _G.InfZoom = false; pcall(function() LP.CameraMaxZoomDistance = 400 end) end
end

-- ══════════════════════════════════════════════════════════════
-- FPS BOOST (Agora com Tela Preta e Desativação de Render 3D)
-- ══════════════════════════════════════════════════════════════
local FpsBoost = {
    originals   = setmetatable({}, { __mode = "k" }),
    watches     = {},
    descConn    = nil,
    lightingConn= nil,
    globalOrig  = nil,
    applying    = false,
    blackScreen = nil,
}

local function fpsStore(obj, prop)
    if not obj or not prop then return end
    if not FpsBoost.originals[obj] then FpsBoost.originals[obj] = {} end
    if FpsBoost.originals[obj][prop] == nil then
        local ok, val = pcall(function() return obj[prop] end)
        if ok then FpsBoost.originals[obj][prop] = val end
    end
end

local function fpsWatch(obj, prop, value)
    local guard = false
    local conn = obj:GetPropertyChangedSignal(prop):Connect(function()
        if guard or not State.fpsBoostOn then return end
        pcall(function() if obj[prop] ~= value then guard = true; obj[prop] = value; guard = false end end)
    end)
    table.insert(FpsBoost.watches, conn)
end

local function fpsSet(obj, prop, value, watch)
    fpsStore(obj, prop)
    pcall(function() obj[prop] = value end)
    if watch then fpsWatch(obj, prop, value) end
end

local function optimizeInstance(v)
    if not State.fpsBoostOn then return end
    pcall(function()
        if v:IsA("MeshPart") then
            fpsSet(v, "CastShadow", false); fpsSet(v, "Material", Enum.Material.Plastic); fpsSet(v, "Reflectance", 0); fpsSet(v, "TextureID", "")
        elseif v:IsA("BasePart") then
            fpsSet(v, "CastShadow", false); fpsSet(v, "Material", Enum.Material.Plastic); fpsSet(v, "Reflectance", 0)
        elseif v:IsA("SurfaceAppearance") then
            fpsSet(v, "ColorMap", ""); fpsSet(v, "MetalnessMap", ""); fpsSet(v, "NormalMap", ""); fpsSet(v, "RoughnessMap", "")
        elseif v:IsA("SpecialMesh") then
            fpsSet(v, "TextureId", "")
        elseif v:IsA("Decal") or v:IsA("Texture") then
            fpsSet(v, "Transparency", 1, true)
        elseif v:IsA("Beam") or v:IsA("Highlight") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("SpotLight") or v:IsA("PointLight") or v:IsA("SurfaceLight") then
            fpsSet(v, "Enabled", false, true)
        elseif v:IsA("SelectionBox") or v:IsA("SelectionSphere") then
            fpsSet(v, "Visible", false)
        elseif v:IsA("ParticleEmitter") then
            fpsSet(v, "Enabled", false, true); fpsSet(v, "Lifetime", NumberRange.new(0))
        elseif v:IsA("Trail") then
            fpsSet(v, "Enabled", false, true); fpsSet(v, "Lifetime", 0)
        elseif v:IsA("Explosion") then
            fpsSet(v, "BlastPressure", 1); fpsSet(v, "BlastRadius", 1)
        end
    end)
end

local function optimizeLightingEffect(e)
    if not State.fpsBoostOn then return end
    if e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect") or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") then
        fpsSet(e, "Enabled", false, true)
    end
end

function FpsBoost.apply()
    if State.fpsBoostOn or FpsBoost.applying then return end
    FpsBoost.applying = true
    State.fpsBoostOn = true

    -- 1. Cria a Tela Preta Total no PLAYERGUI para não ficar acima do MainUI
    if not FpsBoost.blackScreen then
        local pgui = LP:WaitForChild("PlayerGui")
        local bs = Instance.new("ScreenGui")
        bs.Name = "NexusBlackScreen"
        bs.DisplayOrder = 99998 -- Fica atrás da nossa UI (que terá 99999) mas acima do jogo
        bs.IgnoreGuiInset = true
        
        local frame = Instance.new("Frame", bs)
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = Color3.new(0, 0, 0)
        frame.BorderSizePixel = 0
        
        local lbl = Instance.new("TextLabel", frame)
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "NEXUS FPS BOOST ON\n3D RENDERING PAUSED"
        lbl.TextColor3 = Color3.fromRGB(30, 30, 30)
        lbl.Font = Enum.Font.GothamBlack
        lbl.TextSize = 20
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.TextYAlignment = Enum.TextYAlignment.Center

        bs.Parent = pgui -- Colocado intencionalmente no mesmo local que a interface principal
        FpsBoost.blackScreen = bs
    end

    -- 2. Desliga a renderização 3D do jogo (Economia GIGANTE se o executor suportar)
    pcall(function() Svc.Run:Set3dRenderingEnabled(false) end)
    pcall(function() Svc.Run:set3dRenderingEnabled(false) end)

    local g = game; local l = g.Lighting; local t = g.Workspace.Terrain

    FpsBoost.globalOrig = {
        WaterWaveSize = t.WaterWaveSize, WaterWaveSpeed = t.WaterWaveSpeed, WaterReflectance = t.WaterReflectance, WaterTransparency = t.WaterTransparency,
        GlobalShadows = l.GlobalShadows, FogEnd = l.FogEnd, Brightness = l.Brightness, EnvironmentDiffuseScale = l.EnvironmentDiffuseScale, EnvironmentSpecularScale = l.EnvironmentSpecularScale,
        QualityLevel = nil,
    }
    pcall(function() FpsBoost.globalOrig.QualityLevel = settings().Rendering.QualityLevel end)

    pcall(function() t.WaterWaveSize = 0; t.WaterWaveSpeed = 0; t.WaterReflectance = 0; t.WaterTransparency = 0 end)

    fpsSet(l, "GlobalShadows", false, true); fpsSet(l, "FogEnd", 9e9, true); fpsSet(l, "Brightness", 0, true); fpsSet(l, "EnvironmentDiffuseScale", 0, true); fpsSet(l, "EnvironmentSpecularScale", 0, true)
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)

    for _, e in pairs(l:GetChildren()) do optimizeLightingEffect(e) end
    if FpsBoost.lightingConn then FpsBoost.lightingConn:Disconnect() end
    FpsBoost.lightingConn = l.ChildAdded:Connect(optimizeLightingEffect)

    local BATCH_SIZE = 150
    local descendants = g.Workspace:GetDescendants()
    
    task.spawn(function()
        for i, v in ipairs(descendants) do
            if not State.fpsBoostOn then break end
            optimizeInstance(v)
            if i % BATCH_SIZE == 0 then task.wait() end
        end

        if FpsBoost.descConn then FpsBoost.descConn:Disconnect() end
        FpsBoost.descConn = g.Workspace.DescendantAdded:Connect(function(v)
            if State.fpsBoostOn then task.defer(function() optimizeInstance(v) end) end
        end)

        FpsBoost.applying = false
        UI.notify("FPS Boost ON — Tela apagada e Otimizado", false)
    end)
end

function FpsBoost.restore()
    if not State.fpsBoostOn and not FpsBoost.applying then return end
    State.fpsBoostOn = false
    FpsBoost.applying = false

    -- 1. Remove a tela preta
    if FpsBoost.blackScreen then
        FpsBoost.blackScreen:Destroy()
        FpsBoost.blackScreen = nil
    end

    -- 2. Restaura a renderização 3D
    pcall(function() Svc.Run:Set3dRenderingEnabled(true) end)
    pcall(function() Svc.Run:set3dRenderingEnabled(true) end)

    if FpsBoost.descConn then FpsBoost.descConn:Disconnect(); FpsBoost.descConn = nil end
    if FpsBoost.lightingConn then FpsBoost.lightingConn:Disconnect(); FpsBoost.lightingConn = nil end
    for _, conn in ipairs(FpsBoost.watches) do pcall(function() conn:Disconnect() end) end
    FpsBoost.watches = {}

    local go = FpsBoost.globalOrig
    if go then
        local t = game.Workspace.Terrain; local l = game.Lighting
        pcall(function() t.WaterWaveSize = go.WaterWaveSize; t.WaterWaveSpeed = go.WaterWaveSpeed; t.WaterReflectance = go.WaterReflectance; t.WaterTransparency = go.WaterTransparency end)
        pcall(function() l.GlobalShadows = go.GlobalShadows; l.FogEnd = go.FogEnd; l.Brightness = go.Brightness; l.EnvironmentDiffuseScale = go.EnvironmentDiffuseScale; l.EnvironmentSpecularScale = go.EnvironmentSpecularScale end)
        if go.QualityLevel ~= nil then pcall(function() settings().Rendering.QualityLevel = go.QualityLevel end) end
        FpsBoost.globalOrig = nil
    end

    local BATCH = 200; local count = 0
    for obj, props in pairs(FpsBoost.originals) do
        if obj and obj.Parent then for prop, val in pairs(props) do pcall(function() obj[prop] = val end) end end
        count = count + 1; if count % BATCH == 0 then task.wait() end
    end
    FpsBoost.originals = setmetatable({}, { __mode = "k" })

    UI.notify("FPS Boost OFF — Configurações restauradas", false)
end

function FpsBoost.toggle()
    if State.fpsBoostOn then FpsBoost.restore() else FpsBoost.apply() end
end

local Battle = {}
function Battle.detect()
    if not State.battleDetection then return false end
    local pgui = LP:FindFirstChild("PlayerGui")
    if pgui then
        for _, obj in ipairs(pgui:GetDescendants()) do
            local name = obj.Name or ""
            if obj:IsA("ScreenGui") and obj.Enabled and (name:find("Battle") or name:find("Fight") or name:find("Combat")) then return true end
        end
    end
    local char = LP.Character; local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed < 1 then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, obj in ipairs(Svc.Workspace:GetDescendants()) do
                if obj:IsA("Model") and obj ~= char then
                    local eHum = obj:FindFirstChildOfClass("Humanoid"); local eHrp = obj:FindFirstChild("HumanoidRootPart")
                    if eHum and eHrp and (hrp.Position - eHrp.Position).Magnitude < 50 then return true end
                end
            end
        end
    end
    return false
end

function Battle.disableAutoUI()
    local pgui = LP:FindFirstChild("PlayerGui"); if not pgui then return end
    for _, obj in ipairs(pgui:GetDescendants()) do
        if obj:IsA("TextButton") then
            local vis = false; pcall(function() vis = obj.Visible end)
            if vis and (obj.Text:find("AUTOM") or obj.Text:find("AUTO")) then
                pcall(function()
                    obj:FireMouseButtonClick(); task.wait(0.1)
                    if VIM then local pos = obj.AbsolutePosition + obj.AbsoluteSize / 2; VIM:SendMouseButtonEvent(Enum.UserInputType.MouseButton1, pos.X, pos.Y, true, game); task.wait(0.05); VIM:SendMouseButtonEvent(Enum.UserInputType.MouseButton1, pos.X, pos.Y, false, game) end
                end)
                return
            end
        end
    end
end

function Battle.isCatchScreen()
    local pgui = LP:FindFirstChild("PlayerGui"); if not pgui then return false end
    for _, obj in ipairs(pgui:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text:find("Catch%(") then
            local vis = false; pcall(function() vis = obj.Visible end)
            if vis then return true end
        end
    end
    return false
end

function Battle.startSkillLoop()
    if State._skillTask then task.cancel(State._skillTask); State._skillTask = nil end
    State._skillTask = task.spawn(function()
        while State.inBattle and State.battleDetection do
            if not Battle.isCatchScreen() then Input.pressKey(Enum.KeyCode.One) end
            task.wait(State.skillInterval)
        end
    end)
end
function Battle.stopSkillLoop() if State._skillTask then task.cancel(State._skillTask); State._skillTask = nil end end

function Battle.startCatchLoop()
    if State._catchTask then task.cancel(State._catchTask); State._catchTask = nil end
    State._catchTask = task.spawn(function()
        while State.inCatch and State.battleDetection do
            if State.catchKey ~= "OFF" then
                local kcode = (State.catchKey == "E") and Enum.KeyCode.E or Enum.KeyCode.C
                Input.pressKey(kcode)
            end
            task.wait(State.catchInterval)
        end
    end)
end
function Battle.stopCatchLoop() if State._catchTask then task.cancel(State._catchTask); State._catchTask = nil end end

function Battle._updateStatus()
    if not State.statusLbl then return end
    if State.inCatch then
        State.statusLbl.Text = "CATCHING"; State.statusLbl.TextColor3 = C.orange
        if State.statusDot then State.statusDot.BackgroundColor3 = C.orange end
    elseif State.inBattle then 
        State.statusLbl.Text = "BATTLE"; State.statusLbl.TextColor3 = C.orange
        if State.statusDot then State.statusDot.BackgroundColor3 = C.orange end
    elseif State.huntOn then 
        State.statusLbl.Text = "ACTIVE"; State.statusLbl.TextColor3 = C.green
        if State.statusDot then State.statusDot.BackgroundColor3 = C.green end
    else 
        State.statusLbl.Text = "STOPPED"; State.statusLbl.TextColor3 = C.sub
        if State.statusDot then State.statusDot.BackgroundColor3 = C.sub end 
    end
end

function Battle.startMonitor()
    if State._battleTask then task.cancel(State._battleTask); State._battleTask = nil end
    State._battleTask = task.spawn(function()
        while State.farmOn do
            task.wait(0.5)
            local nowCatch = Battle.isCatchScreen()
            
            if nowCatch and not State.inCatch then 
                State.inCatch = true; Battle.startCatchLoop(); Battle._updateStatus()
            elseif not nowCatch and State.inCatch then 
                State.inCatch = false; Battle.stopCatchLoop(); Battle._updateStatus()
            end
            
            if not State.battleDetection then
                if State.inBattle then State.inBattle = false; Battle.stopSkillLoop(); Input.releaseAll(); Battle._updateStatus() end
                continue
            end
            
            local nowInBattle = Battle.detect()
            if nowInBattle and not State.inBattle then
                State.inBattle = true; Input.releaseAll(); Battle.disableAutoUI(); Battle.startSkillLoop(); Battle._updateStatus()
            elseif not nowInBattle and State.inBattle then
                State.inBattle = false; Battle.stopSkillLoop(); Input.releaseAll(); task.wait(0.8); Battle._updateStatus()
            end
        end
    end)
end

function Battle.stopMonitor()
    if State._battleTask then task.cancel(State._battleTask); State._battleTask = nil end
    Battle.stopSkillLoop(); Battle.stopCatchLoop()
    State.inBattle = false; State.inCatch = false
    Battle._updateStatus()
end

local Move = {}
function Move.towards(targetPos)
    if (State.inBattle or State.inCatch) and State.battleDetection then Input.releaseAll(); return false end
    local char = LP.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart"); local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return false end
    local delta = targetPos - hrp.Position; local dist = delta.Magnitude
    if dist < 4 then Input.releaseAll(); return true end
    if VIM then
        local cam = Svc.Workspace.CurrentCamera; local fwd = cam.CFrame.LookVector; local right = cam.CFrame.RightVector; local unit = delta.Unit
        local fwdDot = unit.X * fwd.X + unit.Z * fwd.Z; local rightDot = unit.X * right.X + unit.Z * right.Z
        local want = { W=false, A=false, S=false, D=false }
        if fwdDot > 0.2 then want.W = true elseif fwdDot < -0.2 then want.S = true end
        if rightDot > 0.2 then want.D = true elseif rightDot < -0.2 then want.A = true end
        for k in pairs(want) do Input.holdKey(k, want[k]) end
        return false
    end
    hum:MoveTo(targetPos)
    if State.speedOn then hum.WalkSpeed = State.walkSpeed end
    return false
end

local MobHunt = {}
local WILD_NAME_PATTERNS = { "^Wild_", "^WildEvomon" }
local function extractLevelFromText(text) if type(text) ~= "string" then return nil end; local lv = text:match("Lv%.%s*(%d+)"); return lv and tonumber(lv) or nil end
local function getMobLevel(model)
    if not model or not model:IsA("Model") then return nil end
    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("BillboardGui") then
            for _, guiChild in ipairs(child:GetDescendants()) do if guiChild:IsA("TextLabel") or guiChild:IsA("TextButton") then local lv = extractLevelFromText(guiChild.Text or ""); if lv then return lv end end end
        end
    end
    return nil
end
function MobHunt.isPlayerCharacter(model) for _, plr in ipairs(Svc.Players:GetPlayers()) do if plr.Character == model then return true end end; return false end
function MobHunt.isWildMob(model)
    if not model:IsA("Model") or model == LP.Character or MobHunt.isPlayerCharacter(model) then return false end
    local hum = model:FindFirstChildOfClass("Humanoid"); local hrp = model:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) or hum.Health <= 0 then return false end
    if getMobLevel(model) then return true end
    local anc = model.Parent
    while anc and anc ~= Svc.Workspace do local n = anc.Name; if n == "Wilds" or n == "Wild" or n == "Mobs" or n == "Enemies" or n == "NPCs" or n == "Monsters" then return true end; anc = anc.Parent end
    for _, pat in ipairs(WILD_NAME_PATTERNS) do if model.Name:match(pat) then return true end end
    return true
end
function MobHunt.scan(radius)
    local char = LP.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return {} end
    local results = {}
    for _, obj in ipairs(Svc.Workspace:GetDescendants()) do
        if obj:IsA("Model") and MobHunt.isWildMob(obj) then
            local mHrp = obj:FindFirstChild("HumanoidRootPart")
            if mHrp then
                local dist = (hrp.Position - mHrp.Position).Magnitude
                if dist <= radius then table.insert(results, { model = obj, name = obj.Name:match("%.(.+)$") or obj.Name, distance = dist }) end
            end
        end
    end
    table.sort(results, function(a, b) return a.distance < b.distance end)
    return results
end
function MobHunt.getClosestInRange(radius) local list = MobHunt.scan(radius or State.huntRange); if #list > 0 then return list[1] end; return nil end

function MobHunt.start()
    MobHunt.stop(); State.huntOn = true
    State._huntTask = task.spawn(function()
        local function runHuntLoop()
            local idleTimer, checkInterval, lastCheckTime, lastPos = 0, 2, os.clock(), Vector3.new(0,0,0)
            while State.huntOn do
                while (State.inBattle or State.inCatch) and State.battleDetection and State.huntOn do task.wait(0.5) end
                if not State.huntOn then break end
                
                local closest = MobHunt.getClosestInRange()
                if not closest then
                    closest = MobHunt.getClosestInRange(State.maxHuntDistance)
                    if not closest then
                        local char = LP.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local targetPos = hrp.Position + Vector3.new(math.random(-10,10), 0, math.random(-10,10)).Unit * 30
                            local startTime = os.clock()
                            while State.huntOn and (os.clock() - startTime) < 5 do if Move.towards(targetPos) then break end; task.wait(0.1) end
                        end
                        Input.releaseAll(); task.wait(0.5); continue
                    end
                end
                
                local target = closest.model; State.currentTarget = target
                local stuckCount, lastDist, jumpAttempts, arrived = 0, math.huge, 0, false
                local hrpStart = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                lastPos = hrpStart and hrpStart.Position or Vector3.new(0,0,0); lastCheckTime = os.clock(); idleTimer = 0
                
                while State.huntOn and not arrived do
                    task.wait(0.05)
                    if (State.inBattle or State.inCatch) and State.battleDetection then 
                        Input.releaseAll()
                        while (State.inBattle or State.inCatch) and State.battleDetection and State.huntOn do task.wait(0.5) end
                        if not State.huntOn then break end
                        task.wait(0.4); lastDist, stuckCount, jumpAttempts, idleTimer = math.huge, 0, 0, 0
                        if not target or not target.Parent then arrived = true; break end 
                    end
                    
                    if not target or not target.Parent then arrived = true; break end
                    local mHrp = target:FindFirstChild("HumanoidRootPart"); if not mHrp then arrived = true; break end
                    local char = LP.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart"); if not hrp then break end 
                    
                    local dist = (hrp.Position - mHrp.Position).Magnitude
                    if dist < 3 then
                        arrived = true; Input.releaseAll(); idleTimer = 0
                        while State.huntOn and target and target.Parent and not (State.inBattle or State.inCatch) do
                            task.wait(0.3); if not target.Parent or (hrp.Position - mHrp.Position).Magnitude > 5 then arrived = false; break end
                        end
                        if not arrived then continue end
                        break
                    end
                    
                    if dist > State.maxHuntDistance then 
                        local newClosest = MobHunt.getClosestInRange()
                        if newClosest and newClosest.model ~= target and newClosest.distance < dist then 
                            target = newClosest.model; State.currentTarget = target; lastDist, stuckCount, jumpAttempts, idleTimer = math.huge, 0, 0, 0; continue 
                        end 
                    end
                    
                    if dist >= lastDist - 0.4 then stuckCount = stuckCount + 1 else stuckCount, jumpAttempts = 0, 0 end
                    lastDist = dist
                    
                    if stuckCount > 30 then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then hum.Jump = true; hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                        stuckCount, lastDist = 0, math.huge; jumpAttempts = jumpAttempts + 1
                        if jumpAttempts >= 5 then 
                            local newClosest = MobHunt.getClosestInRange()
                            if newClosest and newClosest.model ~= target and newClosest.distance < dist then 
                                target = newClosest.model; State.currentTarget = target; lastDist, stuckCount, jumpAttempts, idleTimer = math.huge, 0, 0, 0; continue 
                            else arrived = true; break end 
                        end
                    end
                    
                    Move.towards(mHrp.Position)
                    
                    local now = os.clock()
                    if now - lastCheckTime >= checkInterval then
                        local moved = (hrp.Position - lastPos).Magnitude
                        if moved < 1 then idleTimer = idleTimer + checkInterval else idleTimer = 0; lastPos = hrp.Position end
                        lastCheckTime = now
                        if idleTimer >= 10 then
                            local hum = char:FindFirstChildOfClass("Humanoid")
                            if hum then hum.Jump = true; hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                            local rndTarget = hrp.Position + Vector3.new(math.random(-10,10), 0, math.random(-10,10)).Unit * 20
                            if VIM then Move.towards(rndTarget) else hum:MoveTo(rndTarget) end
                            task.wait(0.5); Input.releaseAll(); idleTimer = 0
                            local newTarget = MobHunt.getClosestInRange()
                            if newTarget and newTarget.model ~= target then 
                                target = newTarget.model; State.currentTarget = target; lastDist, stuckCount, jumpAttempts = math.huge, 0, 0 
                            end
                        end
                    end
                end
                Input.releaseAll()
                if not target or not target.Parent then task.wait(0.3) end
            end
        end

        while State.huntOn do
            local ok, err = pcall(runHuntLoop)
            if not ok then warn("[MobHunt] Inner loop error: ", tostring(err)); Input.releaseAll(); task.wait(1) end
        end
    end)
end

function MobHunt.stop() 
    State.huntOn = false; State.currentTarget = nil; Input.releaseAll()
    if State._huntTask then task.cancel(State._huntTask); State._huntTask = nil end 
end

local function makeDraggable(handle, target)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(inp) local t = inp.UserInputType; if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end; dragging = true; dragStart = inp.Position; startPos = target.Position; inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then dragging = false end end) end)
    Svc.Input.InputChanged:Connect(function(inp) if not dragging then return end; local t = inp.UserInputType; if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end; local d = inp.Position - dragStart; target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end)
end

local function BuildUI()
    local pgui = LP:WaitForChild("PlayerGui"); if pgui:FindFirstChild("NexusRoutes") then pgui.NexusRoutes:Destroy() end
    local sc = Instance.new("ScreenGui", pgui); sc.Name = "NexusRoutes"; sc.ResetOnSpawn = false; 
    sc.DisplayOrder = 99999 -- PRIORIDADE MAXIMA PARA APARECER ACIMA DA TELA PRETA
    sc.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sc.IgnoreGuiInset = true
    mainScreenGui = sc
    
    local isTouch = Svc.Input.TouchEnabled
    
    local win = Instance.new("Frame", sc); win.Size = UDim2.new(0, 520, 0, 0); win.AutomaticSize = Enum.AutomaticSize.Y; win.AnchorPoint = Vector2.new(0.5, 0.5); win.Position = isTouch and UDim2.new(0.5, 0, 0.3, 0) or UDim2.new(0.5, 0, 0.5, 0); win.BackgroundColor3 = C.bg; win.BorderSizePixel = 0; UI.corner(16, win); UI.gradient(win, Color3.fromRGB(12, 18, 26), Color3.fromRGB(18, 24, 36), 80)
    local winStroke = UI.stroke(C.accent, 1.5, win); winStroke.Transparency = 0.45; UI.pulse({ winStroke }, 0.3, 0.65, 1.6, "Transparency"); win.BackgroundTransparency = 1; UI.tween(win, 0.25, { BackgroundTransparency = 0 })
    if not isTouch then local scale = Instance.new("UIScale", win); scale.Scale = 1.05 end

    UI.listLayout(win, Enum.FillDirection.Vertical, 8, nil, Enum.HorizontalAlignment.Center); UI.pad(10,10,10,10, win)

    local topBar = Instance.new("Frame", win); topBar.Size = UDim2.new(1,0,0,24); topBar.BackgroundTransparency = 1; topBar.LayoutOrder = 0; makeDraggable(topBar, win)
    local titleLbl = UI.label({ Text = "NEXUS EVO DISTANCE", Font = Enum.Font.GothamBlack, TextSize = 11, TextColor3 = C.accent, Size = UDim2.new(1,0,1,0), AlignX = Enum.TextXAlignment.Center }, topBar)
    
    local minBtn = UI.circleBtn({ d = 22, icon = "−", bg = C.dark1, iconColor = C.sub, hover = C.itemH }, topBar); minBtn.Position = UDim2.new(1,-48,0.5,-11); UI.pressFeedback(minBtn)
    local closeBtn = UI.circleBtn({ d = 22, icon = "×", bg = C.dark1, iconColor = C.red, hover = C.dimred }, topBar); closeBtn.Position = UDim2.new(1,-22,0.5,-11); UI.pressFeedback(closeBtn)

    local split = Instance.new("Frame", win); split.Size = UDim2.new(1,0,0,180); split.BackgroundTransparency = 1; split.LayoutOrder = 1
    UI.listLayout(split, Enum.FillDirection.Horizontal, 12, nil, Enum.HorizontalAlignment.Left)

    local leftCol = Instance.new("Frame", split); leftCol.Size = UDim2.new(0, 160, 1, 0); leftCol.BackgroundColor3 = C.dark1; UI.corner(12, leftCol); UI.stroke(C.bdr2, 1, leftCol); UI.pad(10,10,10,10, leftCol)
    UI.listLayout(leftCol, Enum.FillDirection.Vertical, 12, nil, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

    local statusWrap = Instance.new("Frame", leftCol); statusWrap.Size = UDim2.new(1,0,0,20); statusWrap.BackgroundTransparency = 1
    UI.listLayout(statusWrap, Enum.FillDirection.Horizontal, 6, nil, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
    local statusDot = Instance.new("Frame", statusWrap); statusDot.Size = UDim2.new(0,10,0,10); statusDot.BackgroundColor3 = C.sub; UI.round(statusDot); UI.stroke(C.dark2, 2, statusDot); State.statusDot = statusDot
    local statusLbl = UI.label({ Text = "STOPPED", Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = C.sub, Size = UDim2.new(0,65,1,0) }, statusWrap); State.statusLbl = statusLbl

    local farmBtn = Instance.new("TextButton", leftCol); farmBtn.Size = UDim2.new(0,72,0,72); farmBtn.BackgroundColor3 = C.dimred; farmBtn.Text = "▶"; farmBtn.Font = Enum.Font.GothamBlack; farmBtn.TextSize = 28; farmBtn.TextColor3 = C.red; farmBtn.AutoButtonColor = false; UI.round(farmBtn); local farmStroke = UI.stroke(C.red, 2, farmBtn); farmStroke.Transparency = 0.2; local farmStopPulse = nil; State.startBtn = farmBtn; UI.pressFeedback(farmBtn)
    
    local warnBox = Instance.new("Frame", leftCol); warnBox.Size = UDim2.new(1,0,0,40); warnBox.BackgroundColor3 = Color3.fromRGB(30, 20, 15); UI.corner(8, warnBox); UI.stroke(C.orange, 1, warnBox).Transparency = 0.6; UI.pad(4,4,4,4, warnBox)
    UI.label({ Text = "⚠️ AUTO SKILL:\nPut your damage skill in SLOT 1.", Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = C.orange, Size = UDim2.new(1,0,1,0), AlignX = Enum.TextXAlignment.Center, Wrap = true }, warnBox)

    local rightCol = Instance.new("Frame", split); rightCol.Size = UDim2.new(1, -172, 1, 0); rightCol.BackgroundColor3 = C.dark1; UI.corner(12, rightCol); UI.stroke(C.bdr2, 1, rightCol); UI.pad(12,12,12,12, rightCol)
    UI.listLayout(rightCol, Enum.FillDirection.Vertical, 14, nil, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

    local function createSliderRow(icon, title, suffix, vals, def, onChangeFunc)
        local row = Instance.new("Frame", rightCol); row.Size = UDim2.new(1, 0, 0, 34); row.BackgroundTransparency = 1
        local textContainer = Instance.new("Frame", row); textContainer.Size = UDim2.new(0.6, 0, 1, 0); textContainer.BackgroundTransparency = 1
        UI.listLayout(textContainer, Enum.FillDirection.Horizontal, 6, nil, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
        UI.label({ Text = icon, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.sub, Size = UDim2.new(0,20,1,0) }, textContainer)
        UI.label({ Text = title, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.text, Size = UDim2.new(1,-26,1,0) }, textContainer)
        
        local controlContainer = Instance.new("Frame", row); controlContainer.Size = UDim2.new(0.4, 0, 1, 0); controlContainer.Position = UDim2.new(0.6, 0, 0, 0); controlContainer.BackgroundTransparency = 1
        local valL = UI.label({ Text = "", Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = C.accent, Size = UDim2.new(0,30,1,0), Position = UDim2.new(1,-30,0,0), AlignX = Enum.TextXAlignment.Right }, controlContainer)
        
        local sliderWrap = Instance.new("Frame", controlContainer); sliderWrap.Size = UDim2.new(1, -38, 1, 0); sliderWrap.BackgroundTransparency = 1
        UI.miniSliderSnap(sliderWrap, { snapValues = vals, default = def, suffix = suffix, valueLabel = valL, onChange = onChangeFunc })
        return row
    end

    createSliderRow("⚡", "KEY SKILL INTERVAL", "s", {1, 2, 3}, 1, function(v) State.skillInterval = v end)
    createSliderRow("📏", "DISTANCE FINDER", "m", {30, 50, 90}, State.huntRange, function(v) State.huntRange = v; Persist.save() end)
    createSliderRow("🎯", "CATCH SCREEN KEY", "s", {1, 2, 3}, 1, function(v) State.catchInterval = v end)

    local catchRow = Instance.new("Frame", rightCol); catchRow.Size = UDim2.new(1,0,0,30); catchRow.BackgroundColor3 = Color3.fromRGB(20,28,40); UI.corner(8, catchRow); UI.pad(4,8,4,8, catchRow)
    UI.listLayout(catchRow, Enum.FillDirection.Horizontal, 8, nil, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    UI.label({ Text = "CATCH ACTION:", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = C.sub, Size = UDim2.new(1,-110,1,0) }, catchRow)
    
    local toggleGroup = Instance.new("Frame", catchRow); toggleGroup.Size = UDim2.new(0,110,1,0); toggleGroup.BackgroundTransparency = 1
    UI.listLayout(toggleGroup, Enum.FillDirection.Horizontal, 4, nil, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
    local btnE = Instance.new("TextButton", toggleGroup); btnE.Size = UDim2.new(0,32,1,0); btnE.Font = Enum.Font.GothamBlack; btnE.TextSize = 12; btnE.Text = "E"; UI.corner(6, btnE); btnE.AutoButtonColor = false
    local btnC = Instance.new("TextButton", toggleGroup); btnC.Size = UDim2.new(0,32,1,0); btnC.Font = Enum.Font.GothamBlack; btnC.TextSize = 12; btnC.Text = "C"; UI.corner(6, btnC); btnC.AutoButtonColor = false
    local btnOFF = Instance.new("TextButton", toggleGroup); btnOFF.Size = UDim2.new(0,38,1,0); btnOFF.Font = Enum.Font.GothamBlack; btnOFF.TextSize = 10; btnOFF.Text = "OFF"; UI.corner(6, btnOFF); btnOFF.AutoButtonColor = false
    
    local minWin = Instance.new("Frame", sc)
    minWin.Size = UDim2.new(0, 310, 0, 50); minWin.Position = UDim2.new(0.5, 0, 0.5, 0); minWin.AnchorPoint = Vector2.new(0.5, 0.5); minWin.BackgroundTransparency = 1; minWin.Visible = false
    UI.listLayout(minWin, Enum.FillDirection.Horizontal, 10, Enum.SortOrder.LayoutOrder, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

    local minNameBtn = Instance.new("TextButton", minWin); minNameBtn.Size = UDim2.new(0, 140, 0, 44); minNameBtn.BackgroundColor3 = C.dark1; UI.corner(22, minNameBtn)
    local minStroke = UI.stroke(C.neonBlue, 1.5, minNameBtn); minStroke.Transparency = 0.2; UI.pulse({minStroke}, 0.2, 0.6, 1.5, "Transparency")
    minNameBtn.Text = "NXHUB EVOMON"; minNameBtn.Font = Enum.Font.GothamBlack; minNameBtn.TextSize = 12; minNameBtn.TextColor3 = C.neonBlue; minNameBtn.AutoButtonColor = false
    makeDraggable(minNameBtn, minWin)

    local minFarmBtn = UI.circleBtn({d=44, icon="▶", bg=C.dimred, iconColor=C.red}, minWin)
    local minCatchBtn = UI.circleBtn({d=44, icon="E", bg=C.item, iconColor=C.accent}, minWin)

    local minFpsBtn = UI.circleBtn({ d = 44, icon = "FPS", bg = C.fpsOff, iconColor = C.sub, textSize = 11, border = C.bdr2, }, minWin)
    minFpsBtn.TextSize = 11

    local function updateFpsUI()
        if State.fpsBoostOn then minFpsBtn.BackgroundColor3 = C.fpsOn; minFpsBtn.TextColor3 = C.green; minFpsBtn.Text = "FPS ON"
        else minFpsBtn.BackgroundColor3 = C.fpsOff; minFpsBtn.TextColor3 = C.red; minFpsBtn.Text = "FPS OFF" end
    end
    updateFpsUI()

    minFpsBtn.MouseButton1Click:Connect(function() FpsBoost.toggle(); updateFpsUI() end)
    
    local function updateCatchUI()
        local k = State.catchKey
        btnE.BackgroundColor3 = (k == "E") and C.accent or C.dark2; btnE.TextColor3 = (k == "E") and C.white or C.sub
        btnC.BackgroundColor3 = (k == "C") and C.accent or C.dark2; btnC.TextColor3 = (k == "C") and C.white or C.sub
        btnOFF.BackgroundColor3 = (k == "OFF") and C.dimred or C.dark2; btnOFF.TextColor3 = (k == "OFF") and C.red or C.sub
        
        minCatchBtn.Text = k
        if k == "OFF" then minCatchBtn.BackgroundColor3 = C.dimred; minCatchBtn.TextColor3 = C.red; minCatchBtn.TextSize = 12
        elseif k == "E" then minCatchBtn.BackgroundColor3 = C.item; minCatchBtn.TextColor3 = C.accent; minCatchBtn.TextSize = 16
        else minCatchBtn.BackgroundColor3 = C.item; minCatchBtn.TextColor3 = C.white; minCatchBtn.TextSize = 16 end
    end
    
    btnE.MouseButton1Click:Connect(function() State.catchKey = "E"; updateCatchUI() end)
    btnC.MouseButton1Click:Connect(function() State.catchKey = "C"; updateCatchUI() end)
    btnOFF.MouseButton1Click:Connect(function() State.catchKey = "OFF"; updateCatchUI() end)
    minCatchBtn.MouseButton1Click:Connect(function() 
        if State.catchKey == "E" then State.catchKey = "C" elseif State.catchKey == "C" then State.catchKey = "OFF" else State.catchKey = "E" end
        updateCatchUI() 
    end)
    updateCatchUI()

    local setFarmOn
    local function syncFarmGlow()
        local col = State.farmOn and C.green or C.red; local th = State.farmOn and 2.5 or 2.0
        farmStroke.Color = col; farmStroke.Thickness = th
        farmBtn.BackgroundColor3 = State.farmOn and C.dimgrn or C.dimred
        farmBtn.TextColor3 = col; farmBtn.Text = State.farmOn and "■" or "▶"
        minFarmBtn.BackgroundColor3 = State.farmOn and C.dimgrn or C.dimred
        minFarmBtn.TextColor3 = col; minFarmBtn.Text = State.farmOn and "■" or "▶"
        if farmStopPulse then farmStopPulse(); farmStopPulse = nil end
        if State.farmOn then farmStopPulse = UI.pulse({ farmStroke }, 0.05, 0.5, 0.85, "Transparency") else farmStroke.Transparency = 0.2 end
    end

    setFarmOn = function(on)
        if on then
            if not MobHunt.getClosestInRange() then UI.notify("No mobs found within " .. State.huntRange .. "m range!", true); return end
            State.farmOn = true; State.battleDetection = true; State.speedOn = true; State.walkSpeed = 60; State.zoomOn = true; Zoom.apply(State.zoomValue)
            Battle._updateStatus(); syncFarmGlow(); Battle.startMonitor(); MobHunt.start()
        else
            State.farmOn = false; State.battleDetection = false; State.speedOn = false; State.zoomOn = false; Zoom.setEnabled(false)
            MobHunt.stop(); Battle.stopMonitor(); syncFarmGlow()
        end
    end

    farmBtn.MouseButton1Click:Connect(function() setFarmOn(not State.farmOn) end)
    minFarmBtn.MouseButton1Click:Connect(function() setFarmOn(not State.farmOn) end)
    local f1Conn = Svc.Input.InputBegan:Connect(function(inp, processed) if not processed and inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == Enum.KeyCode.F1 then setFarmOn(not State.farmOn) end end)

    minBtn.MouseButton1Click:Connect(function() win.Visible = false; minWin.Visible = true end)
    minNameBtn.MouseButton1Click:Connect(function() minWin.Visible = false; win.Visible = true end)

    local function fullCleanup()
        if _G.NexusAntiAfkTask then pcall(task.cancel, _G.NexusAntiAfkTask); _G.NexusAntiAfkTask = nil end
        f1Conn:Disconnect(); MobHunt.stop(); Input.releaseAll(); Battle.stopMonitor(); Zoom.setEnabled(false)
        if State.fpsBoostOn then FpsBoost.restore() end
        _G.NexusRoutesActive = nil
    end

    closeBtn.MouseButton1Click:Connect(function() fullCleanup(); UI.tween(win, 0.2, { BackgroundTransparency = 1 }); task.wait(0.22); sc:Destroy() end)
    _G.NexusRoutesActive = fullCleanup; return sc
end

Persist.load()
BuildUI()