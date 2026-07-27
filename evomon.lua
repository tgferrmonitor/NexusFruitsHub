--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║              NEXUS EVO ROUTES  —  MOBILE UI                  ║
    ║  F1 / círculo central = Start / Stop Circuit                 ║
    ║  - Battle Detection (auto-pausa movimento)                   ║
    ║  - Auto Skill 1 durante batalha (intervalo configurável)     ║
    ║  - Farm toggle (círculo verde = ON, vermelho = OFF)          ║
    ║  - Loop, Speed Boost, Camera Zoom override                   ║
    ║  - Waypoints persistentes salvos em arquivo                  ║
    ║  UI: minimalista, ícones circulares, compacta, mobile-first  ║
    ║  NOVO: Farm automático de mobs por distância configurável    ║
    ║  + Fallback de movimento (MoveTo) quando VIM indisponível    ║
    ║  + Limite máximo de distância de alvos (150m)                ║
    ║  + Logs extensivos no console (F9) para debug                ║
    ║  + Lista de mobs removida da UI (apenas farm automático)     ║
    ╚══════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════════════
-- [0]  SINGLETON GUARD
-- ═══════════════════════════════════════════════════════════════════
if _G.NexusRoutesActive then
    warn("[NexusRoutes] Already running — destroying previous instance")
    pcall(function() _G.NexusRoutesActive() end)
end

-- ═══════════════════════════════════════════════════════════════════
-- [1]  EXECUTOR CAPABILITIES
-- ═══════════════════════════════════════════════════════════════════
local exec = {}

exec.request = (type(syn)    == "table" and syn.request)
            or (type(http)   == "table" and http.request)
            or rawget(_G, "http_request")
            or rawget(_G, "request")
            or nil

exec.writefile = rawget(_G, "writefile") or nil
exec.readfile  = rawget(_G, "readfile")  or nil

function exec.hasFileIO()
    return type(exec.writefile) == "function"
       and type(exec.readfile)  == "function"
end

-- ═══════════════════════════════════════════════════════════════════
-- [2]  SERVICES
-- ═══════════════════════════════════════════════════════════════════
local Svc = {
    Players   = game:GetService("Players"),
    Run       = game:GetService("RunService"),
    Tween     = game:GetService("TweenService"),
    Input     = game:GetService("UserInputService"),
    Http      = game:GetService("HttpService"),
    Workspace = game:GetService("Workspace"),
    Camera    = game:GetService("Workspace").CurrentCamera,
}

local VIM; pcall(function() VIM = game:GetService("VirtualInputManager") end)
local LP = game.Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════════
-- [2b]  LOGGER  —  logs para o console (F9) com correção para booleanos
-- ═══════════════════════════════════════════════════════════════════
local Log = {}

function Log.info(...)
    local args = {...}
    for i, v in ipairs(args) do
        args[i] = tostring(v)
    end
    local msg = table.concat(args, " ")
    print("[MOB HUNT] " .. msg)
end

function Log.warn(...)
    local args = {...}
    for i, v in ipairs(args) do
        args[i] = tostring(v)
    end
    local msg = table.concat(args, " ")
    warn("[MOB HUNT] " .. msg)
end

function Log.debug(...)
    -- Descomente a linha abaixo para logs ainda mais detalhados
    -- local args = {...}; for i,v in ipairs(args) do args[i] = tostring(v) end; print("[MOB HUNT DEBUG] " .. table.concat(args, " "))
end

-- Log de diagnóstico: VIM disponível?
Log.info("VIM available:", VIM ~= nil)

-- ═══════════════════════════════════════════════════════════════════
-- [3]  PALETTE
-- ═══════════════════════════════════════════════════════════════════
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
    togOff  = Color3.fromRGB(50,  50,  50),
}

-- ═══════════════════════════════════════════════════════════════════
-- [4]  STATE
-- ═══════════════════════════════════════════════════════════════════
local State = {
    mode            = "route",
    waypoints       = {},
    circuitOn       = false,
    circuitLoop     = true,
    _circuitTask    = nil,

    -- Mob hunt
    huntOn          = false,
    _huntTask       = nil,

    currentTarget   = nil,
    huntRange       = 30,
    maxHuntDistance = 150,

    -- movement
    walkSpeed       = 24,
    speedOn         = false,
    _keysActive     = { W=false, A=false, S=false, D=false },

    -- battle
    inBattle        = false,
    battleDetection = true,
    useSkill1       = true,
    skill1Interval  = 2.0,
    _battleTask     = nil,
    _skillTask      = nil,

    inCatch         = false,
    _catchTask      = nil,

    farmOn          = false,

    zoomOn          = false,
    zoomValue       = 60,

    statusLbl       = nil,
    startBtn        = nil,
}

-- ═══════════════════════════════════════════════════════════════════
-- ACCESS VERIFICATION (inalterado)
-- ═══════════════════════════════════════════════════════════════════
local function HttpRequest(url)
    local success, response = pcall(function()
        if syn and syn.request then
            return syn.request({ Url = url, Method = "GET" }).Body
        end
    end)
    if success and response and response ~= "" then return response end
    success, response = pcall(function()
        if http_request then
            return http_request({ Url = url, Method = "GET" }).Body
        end
    end)
    if success and response and response ~= "" then return response end
    success, response = pcall(function()
        if request then
            return request({ Url = url, Method = "GET" }).Body
        end
    end)
    if success and response and response ~= "" then return response end
    success, response = pcall(function()
        return game:GetService("HttpService"):GetAsync(url)
    end)
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
                if result.has_valid_access == true then
                    return true, result.discord_id
                else
                    return false, nil
                end
            end
        end
        if i < maxRetries then task.wait(delay) end
    end
    return false, nil
end

local function sendHeartbeat(discord_id)
    pcall(function()
        local level = "?"
        pcall(function()
            if LP:FindFirstChild("Data") and LP.Data:FindFirstChild("Level") then
                level = tostring(LP.Data.Level.Value)
            end
        end)
        local payload = {
            roblox_id   = tostring(LP.UserId),
            roblox_name = tostring(LP.Name),
            level       = level,
            using_script = SCRIPT_NAME,
            discord_id  = discord_id or "",
        }
        local ok, body = pcall(HttpService.JSONEncode, HttpService, payload)
        if not ok or not body then return end
        pcall(function()
            local req = (syn and syn.request) or http_request or request
            if req then
                req({ Url = API_BASE .. "/api/heartbeat", Method = "POST", Body = body,
                      Headers = {["Content-Type"] = "application/json"} })
            else
                HttpService:PostAsync(API_BASE .. "/api/heartbeat", body, Enum.HttpContentType.ApplicationJson)
            end
        end)
    end)
end

_G.StopHeartbeat = false
local function startHeartbeat(discord_id)
    task.spawn(function()
        while not _G.StopHeartbeat do
            sendHeartbeat(discord_id)
            task.wait(300)
        end
    end)
end

local hasAccess, discord_id = false, nil
hasAccess, discord_id = checkAccess(5, 2)
if not hasAccess then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/tgferrmonitor/NexusFruitsHub/refs/heads/main/nexusproxy.lua"))()
    return
end
startHeartbeat(discord_id)

-- ═══════════════════════════════════════════════════════════════════
-- [5]  PERSISTENCE
-- ═══════════════════════════════════════════════════════════════════
local PERSIST_FILE = "nexus_evo_routes_v7.json"
local function hasFileFunctions()
    return type(writefile) == "function" and type(readfile) == "function"
end

local Persist = {}

function Persist.save()
    if not hasFileFunctions() then return end
    local wps = {}
    for _, wp in ipairs(State.waypoints) do
        table.insert(wps, { name = wp.name, coord = wp.coord })
    end
    local ok, err = pcall(function()
        writefile(PERSIST_FILE, game:GetService("HttpService"):JSONEncode({
            waypoints   = wps,
            circuitLoop = State.circuitLoop,
            walkSpeed   = State.walkSpeed,
            huntRange   = State.huntRange,
        }))
    end)
    if not ok then warn("[NexusRoutes] Save failed:", err) end
end

function Persist.load()
    if not hasFileFunctions() then return end
    local ok, raw = pcall(readfile, PERSIST_FILE)
    if not (ok and raw and #raw > 0) then return end
    local ok2, d = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), raw)
    if not ok2 or type(d) ~= "table" then return end

    if type(d.waypoints) == "table" then
        State.waypoints = {}
        for _, v in ipairs(d.waypoints) do
            if type(v) == "table" and type(v.name) == "string" and type(v.coord) == "string" then
                local nums = {}
                for n in v.coord:gmatch("[-]?%d+%.?%d*") do
                    nums[#nums + 1] = tonumber(n)
                    if #nums == 3 then break end
                end
                if #nums == 3 then
                    table.insert(State.waypoints, {
                        name  = v.name,
                        coord = v.coord,
                        pos   = Vector3.new(nums[1], nums[2], nums[3]),
                    })
                end
            end
        end
    end
    if d.circuitLoop ~= nil          then State.circuitLoop = d.circuitLoop end
    if type(d.walkSpeed) == "number" then State.walkSpeed   = d.walkSpeed   end
    if type(d.huntRange) == "number" then State.huntRange   = d.huntRange   end
end

-- ═══════════════════════════════════════════════════════════════════
-- [6]  INPUT HELPERS  (com fallback para MoveTo)
-- ═══════════════════════════════════════════════════════════════════
local Input = {}

function Input.pressKey(kcode)
    if not VIM then return false end
    local ok, err = pcall(function()
        VIM:SendKeyEvent(true,  kcode, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, kcode, false, game)
    end)
    if not ok then
        Log.warn("pressKey failed:", err)
        return false
    end
    return true
end

function Input.holdKey(key, active)
    if not VIM then return false end
    local kcode = Enum.KeyCode[key]
    if not kcode then return false end
    if active and not State._keysActive[key] then
        pcall(function() VIM:SendKeyEvent(true, kcode, false, game) end)
        State._keysActive[key] = true
    elseif not active and State._keysActive[key] then
        pcall(function() VIM:SendKeyEvent(false, kcode, false, game) end)
        State._keysActive[key] = false
    end
    return true
end

function Input.releaseAll()
    for key in pairs(State._keysActive) do
        Input.holdKey(key, false)
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- [ZOOM]  CAMERA ZOOM OVERRIDE
-- ═══════════════════════════════════════════════════════════════════
local Zoom = {}
local _zoomConn = nil

function Zoom.apply(studs)
    pcall(function() LP.CameraMaxZoomDistance = studs end)
end

function Zoom.setEnabled(on, studs)
    if _zoomConn then _zoomConn:Disconnect(); _zoomConn = nil end
    if on then
        _G.InfZoom = true
        Zoom.apply(studs or State.zoomValue)
        _zoomConn = LP.CharacterAdded:Connect(function()
            task.wait(0.5)
            if _G.InfZoom then Zoom.apply(State.zoomValue) end
        end)
    else
        _G.InfZoom = false
        pcall(function() LP.CameraMaxZoomDistance = 400 end)
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- [8]  BATTLE DETECTION
-- ═══════════════════════════════════════════════════════════════════
local Battle = {}

function Battle.detect()
    if not State.battleDetection then return false end
    local pgui = LP:FindFirstChild("PlayerGui")
    if pgui then
        for _, obj in ipairs(pgui:GetDescendants()) do
            local name = obj.Name or ""
            if obj:IsA("ScreenGui") then
                if obj.Enabled and (name:find("Battle") or name:find("Fight") or name:find("Combat")) then
                    return true
                end
            end
            if (obj:IsA("TextLabel") or obj:IsA("TextButton")) then
                local text = obj.Text or ""
                if text:find("AUTOM") or text:find("AUTO") or text:find("Autom") then
                    local vis = false
                    pcall(function()
                        if obj:IsA("ScreenGui") then vis = obj.Enabled else vis = obj.Visible end
                    end)
                    if vis then
                        local parent = obj.Parent
                        if parent and parent:IsA("Frame") then
                            local parentVis = false
                            pcall(function() parentVis = parent.Visible end)
                            if parentVis then
                                for _, child in ipairs(parent:GetChildren()) do
                                    if child:IsA("TextLabel") then
                                        local pvis = false
                                        pcall(function() pvis = child.Visible end)
                                        if pvis then
                                            local t2 = child.Text or ""
                                            if t2:find("Golpe") or t2:find("Ataque")
                                            or t2:find("Skill")  or t2:find("Poder") then
                                                return true
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed < 1 then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, obj in ipairs(Svc.Workspace:GetDescendants()) do
                if obj:IsA("Model") and obj ~= char then
                    local eHum = obj:FindFirstChildOfClass("Humanoid")
                    local eHrp = obj:FindFirstChild("HumanoidRootPart")
                    if eHum and eHrp then
                        if (hrp.Position - eHrp.Position).Magnitude < 50 then return true end
                    end
                end
            end
        end
    end
    return false
end

function Battle.disableAutoUI()
    local pgui = LP:FindFirstChild("PlayerGui")
    if not pgui then return end
    for _, obj in ipairs(pgui:GetDescendants()) do
        if obj:IsA("TextButton") then
            local vis = false
            pcall(function() vis = obj.Visible end)
            if vis then
                local text = obj.Text or ""
                if text:find("AUTOM") or text:find("AUTO") or text:find("Autom") then
                    pcall(function()
                        obj:FireMouseButtonClick()
                        task.wait(0.1)
                        if VIM then
                            local pos = obj.AbsolutePosition + obj.AbsoluteSize / 2
                            VIM:SendMouseButtonEvent(Enum.UserInputType.MouseButton1, pos.X, pos.Y, true,  game)
                            task.wait(0.05)
                            VIM:SendMouseButtonEvent(Enum.UserInputType.MouseButton1, pos.X, pos.Y, false, game)
                        end
                    end)
                    return
                end
            end
        end
    end
end

function Battle.isCatchScreen()
    local pgui = LP:FindFirstChild("PlayerGui")
    if not pgui then return false end
    for _, obj in ipairs(pgui:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local text = obj.Text or ""
            if text:find("Catch%(") then
                local vis = false
                pcall(function() vis = obj.Visible end)
                if vis then return true end
            end
        end
    end
    return false
end

function Battle.startSkillLoop()
    if State._skillTask then task.cancel(State._skillTask); State._skillTask = nil end
    if not State.useSkill1 then return end
    State._skillTask = task.spawn(function()
        while State.inBattle and State.battleDetection and State.useSkill1 do
            if not Battle.isCatchScreen() then Input.pressKey(Enum.KeyCode.One) end
            task.wait(State.skill1Interval)
        end
    end)
end

function Battle.stopSkillLoop()
    if State._skillTask then task.cancel(State._skillTask); State._skillTask = nil end
end

function Battle.startCatchLoop()
    if State._catchTask then task.cancel(State._catchTask); State._catchTask = nil end
    State._catchTask = task.spawn(function()
        while State.inCatch do
            Input.pressKey(Enum.KeyCode.E)
            task.wait(1)
        end
    end)
end

function Battle.stopCatchLoop()
    if State._catchTask then task.cancel(State._catchTask); State._catchTask = nil end
end

function Battle.startMonitor()
    if State._battleTask then task.cancel(State._battleTask); State._battleTask = nil end
    State._battleTask = task.spawn(function()
        while true do
            task.wait(0.5)
            local nowCatch = Battle.isCatchScreen()
            if nowCatch and not State.inCatch then
                State.inCatch = true; Battle.startCatchLoop()
            elseif not nowCatch and State.inCatch then
                State.inCatch = false; Battle.stopCatchLoop()
            end
            if not State.battleDetection then
                if State.inBattle then
                    State.inBattle = false
                    Battle.stopSkillLoop()
                    Input.releaseAll()
                    Battle._updateStatus()
                end
                continue
            end
            local nowInBattle = Battle.detect()
            if nowInBattle and not State.inBattle then
                State.inBattle = true
                Input.releaseAll()
                Battle.disableAutoUI()
                Battle.startSkillLoop()
                Battle._updateStatus()
                UI.notify("Battle", "Entered battle", C.red)
            elseif not nowInBattle and State.inBattle then
                State.inBattle = false
                Battle.stopSkillLoop()
                Input.releaseAll()
                task.wait(0.8)
                Battle._updateStatus()
                UI.notify("Battle", "Resuming circuit", C.green)
            end
        end
    end)
end

function Battle.stopMonitor()
    if State._battleTask then task.cancel(State._battleTask); State._battleTask = nil end
    Battle.stopSkillLoop()
    Battle.stopCatchLoop()
    State.inBattle = false
    State.inCatch  = false
end

function Battle._updateStatus()
    if not State.statusLbl then return end
    if State.inBattle then
        State.statusLbl.Text        = "Battle"
        State.statusLbl.TextColor3  = C.red
        if State.statusDot then State.statusDot.BackgroundColor3 = C.red end
    elseif State.circuitOn then
        State.statusLbl.Text        = "Active"
        State.statusLbl.TextColor3  = C.green
        if State.statusDot then State.statusDot.BackgroundColor3 = C.green end
    else
        State.statusLbl.Text        = "Stopped"
        State.statusLbl.TextColor3  = C.sub
        if State.statusDot then State.statusDot.BackgroundColor3 = C.sub end
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- [9]  MOVEMENT ENGINE  (com fallback para MoveTo)
-- ═══════════════════════════════════════════════════════════════════
local Move = {}

function Move.towards(targetPos)
    if State.inBattle and State.battleDetection then
        Input.releaseAll()
        return false
    end

    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return false end

    local delta = targetPos - hrp.Position
    local dist  = delta.Magnitude
    if dist < 4 then
        Input.releaseAll()
        return true
    end

    if VIM then
        local cam       = Svc.Workspace.CurrentCamera
        local fwd       = cam.CFrame.LookVector
        local right     = cam.CFrame.RightVector
        local unit      = delta.Unit
        local fwdDot    = unit.X * fwd.X   + unit.Z * fwd.Z
        local rightDot  = unit.X * right.X + unit.Z * right.Z
        local want = { W=false, A=false, S=false, D=false }
        if fwdDot   >  0.2 then want.W = true
        elseif fwdDot < -0.2 then want.S = true end
        if rightDot >  0.2 then want.D = true
        elseif rightDot < -0.2 then want.A = true end
        for k in pairs(want) do Input.holdKey(k, want[k]) end
        return false
    end

    -- Fallback: Humanoid:MoveTo
    Log.debug("Using MoveTo fallback (VIM unavailable)")
    hum:MoveTo(targetPos)
    if State.speedOn then hum.WalkSpeed = State.walkSpeed end
    return false
end

-- ═══════════════════════════════════════════════════════════════════
-- [10] CIRCUIT ENGINE
-- ═══════════════════════════════════════════════════════════════════
local Circuit = {}

function Circuit.start()
    Circuit.stop()
    if #State.waypoints == 0 then return end
    State.circuitOn = true
    State._circuitTask = task.spawn(function()
        local ok, err = pcall(function()
            local idx = 1
            while State.circuitOn and #State.waypoints > 0 do
                while State.inBattle and State.battleDetection and State.circuitOn do task.wait(0.5) end
                if not State.circuitOn then break end
                task.wait(0.3)
                local wp = State.waypoints[idx]
                if not wp then break end
                if State.statusLbl then
                    State.statusLbl.Text = "WP " .. idx .. "/" .. #State.waypoints
                    State.statusLbl.TextColor3 = C.accent
                    if State.statusDot then State.statusDot.BackgroundColor3 = C.accent end
                end
                if State.speedOn then
                    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum.WalkSpeed = State.walkSpeed end
                end
                local arrived = false
                local deadline = os.clock() + 30
                local stuckCount = 0
                local lastDist = math.huge
                local jumpAttempts = 0
                while State.circuitOn and not arrived do
                    task.wait(0.05)
                    if State.inBattle and State.battleDetection then
                        Input.releaseAll()
                        while State.inBattle and State.battleDetection and State.circuitOn do task.wait(0.5) end
                        if not State.circuitOn then break end
                        task.wait(0.4)
                        lastDist = math.huge; stuckCount = 0; jumpAttempts = 0
                    end
                    local char = LP.Character
                    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                    if not hrp then break end
                    local dist = (hrp.Position - wp.pos).Magnitude
                    if dist < 4 then arrived = true; break end
                    if dist >= lastDist - 0.4 then stuckCount = stuckCount + 1 else stuckCount = 0; jumpAttempts = 0 end
                    lastDist = dist
                    if stuckCount > 30 then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then hum.Jump = true; hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                        stuckCount = 0; lastDist = math.huge; jumpAttempts = jumpAttempts + 1
                        if jumpAttempts >= 5 then arrived = true; break end
                    end
                    arrived = Move.towards(wp.pos)
                    if os.clock() > deadline then arrived = true; break end
                end
                Input.releaseAll()
                task.wait(0.25)
                idx = idx + 1
                if idx > #State.waypoints then
                    if State.circuitLoop then idx = 1 else State.circuitOn = false end
                end
            end
        end)
        Input.releaseAll()
        if not ok and State.farmOn then
            task.wait(0.5); Circuit.start(); return
        end
        State.circuitOn = false
        Battle._updateStatus()
        if State.onFarmAutoStop then State.onFarmAutoStop() end
    end)
end

function Circuit.stop()
    State.circuitOn = false
    Input.releaseAll()
    if State._circuitTask then task.cancel(State._circuitTask); State._circuitTask = nil end
end

-- ═══════════════════════════════════════════════════════════════════
-- [10b] MOB HUNT ENGINE  —  AUTO FARM POR DISTÂNCIA COM LOGS E FALLBACK
-- ═══════════════════════════════════════════════════════════════════
local MobHunt = {}

local WILD_NAME_PATTERNS = { "^Wild_", "^WildEvomon" }

local function extractLevelFromText(text)
    if type(text) ~= "string" then return nil end
    local lv = text:match("Lv%.%s*(%d+)")
    return lv and tonumber(lv) or nil
end

local function getMobLevel(model)
    if not model or not model:IsA("Model") then return nil end
    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("BillboardGui") then
            for _, guiChild in ipairs(child:GetDescendants()) do
                if guiChild:IsA("TextLabel") or guiChild:IsA("TextButton") then
                    local lv = extractLevelFromText(guiChild.Text or "")
                    if lv then return lv end
                end
            end
        end
    end
    return nil
end

function MobHunt.isPlayerCharacter(model)
    for _, plr in ipairs(Svc.Players:GetPlayers()) do
        if plr.Character == model then return true end
    end
    return false
end

function MobHunt.isWildMob(model)
    if not model:IsA("Model") then return false end
    if model == LP.Character then return false end
    if MobHunt.isPlayerCharacter(model) then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then return false end
    if hum.Health <= 0 then return false end

    if getMobLevel(model) then return true end

    local anc = model.Parent
    while anc and anc ~= Svc.Workspace do
        local n = anc.Name
        if n == "Wilds" or n == "Wild" or n == "Mobs" or n == "Enemies"
        or n == "NPCs" or n == "Monsters" then return true end
        anc = anc.Parent
    end

    for _, pat in ipairs(WILD_NAME_PATTERNS) do
        if model.Name:match(pat) then return true end
    end
    return true
end

function MobHunt.scan(radius)
    radius = radius or 200
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    local results = {}
    for _, obj in ipairs(Svc.Workspace:GetDescendants()) do
        if obj:IsA("Model") and MobHunt.isWildMob(obj) then
            local mHrp = obj:FindFirstChild("HumanoidRootPart")
            if mHrp then
                local dist = (hrp.Position - mHrp.Position).Magnitude
                if dist <= radius then
                    local level = getMobLevel(obj)
                    local baseName = obj.Name:match("%.(.+)$") or obj.Name
                    table.insert(results, {
                        model = obj,
                        name = baseName,
                        fullName = obj.Name,
                        distance = dist,
                        level = level,
                    })
                end
            end
        end
    end
    table.sort(results, function(a, b) return a.distance < b.distance end)
    return results
end

function MobHunt.getClosestInRange(radius)
    radius = radius or State.huntRange
    local list = MobHunt.scan(radius)
    if #list > 0 then
        return list[1]
    end
    return nil
end

function MobHunt.start()
    MobHunt.stop()
    State.huntOn = true
    Log.info("Started!")
    Log.info("VIM available:", VIM ~= nil)

    State._huntTask = task.spawn(function()
        local loopCount = 0
        local ok, err = pcall(function()
            local lastPos = Vector3.new(0,0,0)
            local idleTimer = 0
            local idleThreshold = 10
            local checkInterval = 2
            local lastCheckTime = os.clock()

            while State.huntOn do
                loopCount = loopCount + 1
                Log.info(string.format("Loop #%d | inBattle: %s | huntOn: %s", loopCount, tostring(State.inBattle), tostring(State.huntOn)))

                while State.inBattle and State.battleDetection and State.huntOn do
                    task.wait(0.5)
                    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then lastPos = hrp.Position end
                end
                if not State.huntOn then break end

                Log.info(string.format("Scanning for mobs within %dm...", State.huntRange))
                local closest = MobHunt.getClosestInRange()

                if not closest then
                    Log.info("No mobs within range, expanding search to " .. State.maxHuntDistance .. "m...")
                    local fallback = MobHunt.getClosestInRange(State.maxHuntDistance)
                    if fallback then
                        closest = fallback
                        Log.info(string.format("Found mob at %dm", math.floor(closest.distance)))
                    else
                        Log.warn("No mobs within " .. State.maxHuntDistance .. "m! Moving randomly...")
                        UI.notify("Idle", "No mobs nearby, moving randomly", C.orange)
                        local char = LP.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local dir = Vector3.new(math.random(-10,10), 0, math.random(-10,10)).Unit
                            local targetPos = hrp.Position + dir * 30
                            local startTime = os.clock()
                            while State.huntOn and (os.clock() - startTime) < 5 do
                                if Move.towards(targetPos) then break end
                                task.wait(0.1)
                            end
                        end
                        Input.releaseAll()
                        task.wait(0.5)
                        continue
                    end
                end

                if closest and closest.distance > State.maxHuntDistance then
                    Log.warn(string.format("Closest mob at %dm exceeds max distance (%dm), moving randomly...", math.floor(closest.distance), State.maxHuntDistance))
                    local char = LP.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local dir = Vector3.new(math.random(-10,10), 0, math.random(-10,10)).Unit
                        local targetPos = hrp.Position + dir * 30
                        local startTime = os.clock()
                        while State.huntOn and (os.clock() - startTime) < 5 do
                            if Move.towards(targetPos) then break end
                            task.wait(0.1)
                        end
                    end
                    Input.releaseAll()
                    task.wait(0.5)
                    continue
                end

                local target = closest.model
                State.currentTarget = target
                local targetName = closest.name or target.Name
                Log.info(string.format("Target set: %s at %dm", targetName, math.floor(closest.distance)))

                local stuckCount, lastDist, jumpAttempts = 0, math.huge, 0
                local arrived = false
                idleTimer = 0
                local hrpStart = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                lastPos = hrpStart and hrpStart.Position or Vector3.new(0,0,0)
                lastCheckTime = os.clock()

                while State.huntOn and not arrived do
                    task.wait(0.05)

                    if State.inBattle and State.battleDetection then
                        Input.releaseAll()
                        while State.inBattle and State.battleDetection and State.huntOn do
                            task.wait(0.5)
                            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                            if hrp then lastPos = hrp.Position end
                        end
                        if not State.huntOn then break end
                        task.wait(0.4)
                        lastDist, stuckCount, jumpAttempts = math.huge, 0, 0
                        idleTimer = 0
                        if not target or not target.Parent then
                            arrived = true
                            break
                        end
                    end

                    if not target or not target.Parent then
                        Log.info("Target lost (destroyed/despawned)")
                        arrived = true
                        break
                    end

                    local mHrp = target:FindFirstChild("HumanoidRootPart")
                    if not mHrp then
                        Log.info("Target has no HumanoidRootPart")
                        arrived = true
                        break
                    end

                    local char = LP.Character
                    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                    if not hrp then
                        Log.warn("Player character not found")
                        break
                    end

                    local dist = (hrp.Position - mHrp.Position).Magnitude

                    if dist < 3 then
                        Log.info(string.format("Arrived at target (dist: %.1fm)", dist))
                        arrived = true
                        Input.releaseAll()
                        idleTimer = 0
                        while State.huntOn and target and target.Parent and not State.inBattle do
                            task.wait(0.3)
                            if not target.Parent then
                                Log.info("Target disappeared while waiting for battle")
                                arrived = false
                                break
                            end
                            local newDist = (hrp.Position - mHrp.Position).Magnitude
                            if newDist > 5 then
                                Log.info("Target moved away, chasing again")
                                arrived = false
                                break
                            end
                        end
                        if not arrived then
                            continue
                        end
                        break
                    end

                    if dist > State.maxHuntDistance then
                        Log.info(string.format("Target too far (%.0fm), searching for closer one...", dist))
                        local newClosest = MobHunt.getClosestInRange()
                        if newClosest and newClosest.model ~= target and newClosest.distance < dist then
                            target = newClosest.model
                            State.currentTarget = target
                            local newName = newClosest.name or target.Name
                            Log.info(string.format("Switched to %s at %dm", newName, math.floor(newClosest.distance)))
                            lastDist, stuckCount, jumpAttempts = math.huge, 0, 0
                            idleTimer = 0
                            continue
                        end
                    end

                    if dist >= lastDist - 0.4 then
                        stuckCount = stuckCount + 1
                    else
                        stuckCount, jumpAttempts = 0, 0
                    end
                    lastDist = dist

                    if stuckCount > 30 then
                        Log.info("Stuck detected, jumping...")
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then
                            hum.Jump = true
                            hum:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                        stuckCount, lastDist = 0, math.huge
                        jumpAttempts = jumpAttempts + 1
                        if jumpAttempts >= 5 then
                            Log.info("Too many jump attempts, switching target...")
                            local newClosest = MobHunt.getClosestInRange()
                            if newClosest and newClosest.model ~= target and newClosest.distance < dist then
                                target = newClosest.model
                                State.currentTarget = target
                                local newName = newClosest.name or target.Name
                                Log.info(string.format("Switched to %s at %dm after stuck", newName, math.floor(newClosest.distance)))
                                lastDist, stuckCount, jumpAttempts = math.huge, 0, 0
                                idleTimer = 0
                                continue
                            else
                                Log.info("No alternative target, breaking stuck loop")
                                arrived = true
                                break
                            end
                        end
                    end

                    Move.towards(mHrp.Position)

                    local now = os.clock()
                    if now - lastCheckTime >= checkInterval then
                        local currentPos = hrp.Position
                        local moved = (currentPos - lastPos).Magnitude
                        Log.info(string.format("Idle timer: %ds (moved: %.1fm)", math.floor(idleTimer + checkInterval), moved))
                        if moved < 1 then
                            idleTimer = idleTimer + checkInterval
                        else
                            idleTimer = 0
                            lastPos = currentPos
                        end
                        lastCheckTime = now

                        if idleTimer >= idleThreshold then
                            Log.warn(string.format("IDLE for %ds! Forcing movement...", idleTimer))
                            UI.notify("Idle", "Stuck! Forcing movement", C.orange)
                            local hum = char:FindFirstChildOfClass("Humanoid")
                            if hum then
                                hum.Jump = true
                                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                            end
                            if VIM then
                                local dir = Vector3.new(math.random(-10,10), 0, math.random(-10,10)).Unit
                                local randomTarget = hrp.Position + dir * 20
                                Move.towards(randomTarget)
                            else
                                local dir = Vector3.new(math.random(-10,10), 0, math.random(-10,10)).Unit
                                hum:MoveTo(hrp.Position + dir * 20)
                            end
                            task.wait(0.5)
                            Input.releaseAll()
                            idleTimer = 0
                            local newTarget = MobHunt.getClosestInRange()
                            if newTarget and newTarget.model ~= target then
                                target = newTarget.model
                                State.currentTarget = target
                                local newName = newTarget.name or target.Name
                                Log.info(string.format("Switched to %s at %dm after idle", newName, math.floor(newTarget.distance)))
                                lastDist, stuckCount, jumpAttempts = math.huge, 0, 0
                            end
                        end
                    end
                end

                Input.releaseAll()
                Log.info(string.format("Inner loop ended. arrived: %s, target: %s", tostring(arrived), target and target.Name or "nil"))

                if not target or not target.Parent then
                    Log.info("Target lost, waiting a moment before next scan...")
                    task.wait(0.3)
                end
            end
        end)

        Input.releaseAll()
        if not ok then
            Log.warn("Task errored: " .. tostring(err))
        end
        if not ok and State.huntOn then
            Log.info("Restarting task after error...")
            task.wait(0.5)
            MobHunt.start()
            return
        end
        State.huntOn = false
        Log.info("Stopped")
        if State.onFarmAutoStop then State.onFarmAutoStop() end
    end)

    return true
end

function MobHunt.stop()
    Log.info("Stop requested")
    State.huntOn = false
    State.currentTarget = nil
    Input.releaseAll()
    if State._huntTask then
        task.cancel(State._huntTask)
        State._huntTask = nil
        Log.info("Task cancelled")
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- [11] UI LIBRARY
-- ═══════════════════════════════════════════════════════════════════
UI = {}

function UI.tween(obj, t, props)
    Svc.Tween:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quint), props):Play()
end

function UI.corner(r, parent)
    local c = Instance.new("UICorner", parent); c.CornerRadius = UDim.new(0, r); return c
end

function UI.round(parent)
    local c = Instance.new("UICorner", parent); c.CornerRadius = UDim.new(1, 0); return c
end

function UI.stroke(col, th, parent)
    local s = Instance.new("UIStroke", parent); s.Color = col; s.Thickness = th or 1; return s
end

function UI.pulse(objs, tMin, tMax, dur, prop)
    if typeof(objs) ~= "table" then objs = { objs } end
    tMin, tMax, dur = tMin or 0.35, tMax or 0.85, dur or 1.1
    prop = prop or "BackgroundTransparency"
    local alive = true
    task.spawn(function()
        local up = true
        while alive do
            for _, o in ipairs(objs) do
                if o and o.Parent then UI.tween(o, dur, { [prop] = up and tMin or tMax }) end
            end
            task.wait(dur)
            up = not up
        end
    end)
    return function() alive = false end
end

function UI.gradient(parent, c1, c2, rotation)
    local g = Instance.new("UIGradient", parent); g.Color = ColorSequence.new(c1, c2); g.Rotation = rotation or 90; return g
end

function UI.pressFeedback(btn)
    btn.MouseButton1Down:Connect(function()
        UI.tween(btn, 0.08, { Size = btn.Size - UDim2.new(0,3,0,3) })
    end)
    btn.MouseButton1Up:Connect(function()
        UI.tween(btn, 0.12, { Size = btn.Size + UDim2.new(0,3,0,3) })
    end)
end

function UI.pad(t, l, r, b, parent)
    local p = Instance.new("UIPadding", parent)
    p.PaddingTop = UDim.new(0, t or 0); p.PaddingLeft = UDim.new(0, l or 0)
    p.PaddingRight = UDim.new(0, r or 0); p.PaddingBottom = UDim.new(0, b or 0)
end

function UI.listLayout(parent, dir, pad, sort, alignX, alignY)
    local ul = Instance.new("UIListLayout", parent)
    ul.FillDirection = dir or Enum.FillDirection.Vertical
    ul.Padding = UDim.new(0, pad or 0)
    ul.SortOrder = sort or Enum.SortOrder.LayoutOrder
    if alignX then ul.HorizontalAlignment = alignX end
    if alignY then ul.VerticalAlignment = alignY end
    return ul
end

function UI.label(props, parent)
    local l = Instance.new("TextLabel", parent)
    l.BackgroundTransparency = 1
    l.Font = props.Font or Enum.Font.GothamMedium
    l.TextSize = props.TextSize or 13
    l.TextColor3 = props.TextColor3 or C.text
    l.Text = props.Text or ""
    l.Size = props.Size or UDim2.new(1,0,1,0)
    l.Position = props.Position or UDim2.new(0,0,0,0)
    l.TextXAlignment = props.AlignX or Enum.TextXAlignment.Left
    l.TextYAlignment = props.AlignY or Enum.TextYAlignment.Center
    l.TextWrapped = props.Wrap or false
    l.TextTruncate = props.Truncate or Enum.TextTruncate.None
    if props.Name then l.Name = props.Name end
    return l
end

function UI.circleBtn(props, parent)
    local d = props.d or 40
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(0, d, 0, d)
    b.BackgroundColor3 = props.bg or C.item
    b.Text = props.icon or ""
    b.Font = Enum.Font.GothamBold
    b.TextSize = props.textSize or math.floor(d * 0.42)
    b.TextColor3 = props.iconColor or C.text
    b.AutoButtonColor = false
    b.LayoutOrder = props.order or 0
    UI.round(b)
    UI.stroke(props.border or C.bdr2, 1, b)
    local baseBg = props.bg or C.item
    local hoverBg = props.hover or C.itemH
    b.MouseEnter:Connect(function() UI.tween(b, 0.1, { BackgroundColor3 = hoverBg }) end)
    b.MouseLeave:Connect(function() UI.tween(b, 0.1, { BackgroundColor3 = baseBg }) end)
    if props.onClick then b.MouseButton1Click:Connect(props.onClick) end
    return b
end

local function UI_lighten(col, amt)
    return Color3.new(col.R + (1 - col.R) * amt, col.G + (1 - col.G) * amt, col.B + (1 - col.B) * amt)
end

function UI.toggleDot(parent, props)
    local d = props.d or 40
    local w = props.w or (d + 10)
    local onCol = props.onColor or C.accent
    local offCol = props.offColor or C.togOff
    local wrap = Instance.new("Frame", parent)
    wrap.Size = UDim2.new(0, w, 0, d + 16)
    wrap.BackgroundTransparency = 1
    wrap.LayoutOrder = props.order or 0
    local isOn = props.default or false
    local function baseColor() return isOn and onCol or offCol end
    local btn = Instance.new("TextButton", wrap)
    btn.Size = UDim2.new(0, d, 0, d)
    btn.Position = UDim2.new(0.5, -d/2, 0, 0)
    btn.BackgroundColor3 = baseColor()
    btn.Text = props.icon or ""
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = math.floor(d * 0.42)
    btn.TextColor3 = C.white
    btn.AutoButtonColor = false
    btn.ZIndex = 2
    UI.round(btn)
    local neonStroke = UI.stroke(onCol, 1.3, btn)
    neonStroke.Transparency = isOn and 0.1 or 0.8
    local stopPulse = nil
    local function syncGlow()
        neonStroke.Thickness = isOn and 2 or 1.3
        if isOn then
            if not stopPulse then stopPulse = UI.pulse({ neonStroke }, 0.1, 0.55, 1.0, "Transparency") end
        else
            if stopPulse then stopPulse(); stopPulse = nil end
            neonStroke.Transparency = 0.8
        end
    end
    syncGlow()
    UI.pressFeedback(btn)
    local stateLbl = UI.label({
        Text = props.label or "",
        Font = Enum.Font.GothamMedium,
        TextSize = 9,
        TextColor3 = isOn and onCol or C.sub,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, d + 1),
        AlignX = Enum.TextXAlignment.Center,
    }, wrap)
    local function set(v, silent)
        isOn = v
        UI.tween(btn, 0.15, { BackgroundColor3 = baseColor() })
        stateLbl.TextColor3 = isOn and onCol or C.sub
        syncGlow()
        if not silent and props.onChange then props.onChange(v) end
    end
    btn.MouseEnter:Connect(function()
        UI.tween(btn, 0.1, { BackgroundColor3 = UI_lighten(baseColor(), 0.28) })
    end)
    btn.MouseLeave:Connect(function()
        UI.tween(btn, 0.1, { BackgroundColor3 = baseColor() })
    end)
    btn.MouseButton1Click:Connect(function() set(not isOn) end)
    return set, btn
end

function UI.miniSlider(parent, props)
    local w = props.w or 150
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(0, w, 0, 26)
    row.BackgroundTransparency = 1
    row.LayoutOrder = props.order or 0
    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(1, -14, 0, 4)
    track.Position = UDim2.new(0, 0, 0.5, -2)
    track.BackgroundColor3 = Color3.fromRGB(30,38,50)
    UI.round(track)
    UI.stroke(C.bdr2, 1, track).Transparency = 0.5
    local fill = Instance.new("Frame", track)
    fill.BackgroundColor3 = C.accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 2
    UI.round(fill)
    UI.gradient(fill, C.acc2, C.accent, 0)
    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0,14,0,14)
    thumb.BackgroundColor3 = C.white
    thumb.ZIndex = 3
    UI.round(thumb)
    UI.stroke(C.accent, 1.5, thumb)
    local valL = props.valueLabel
    if not valL then
        valL = UI.label({
            Text = tostring(props.default),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = C.accent,
            Size = UDim2.new(0, 30, 1, 0),
            Position = UDim2.new(1, -30, 0, -8),
            AlignX = Enum.TextXAlignment.Right,
        }, row)
    else
        valL.Text = tostring(props.default)
    end
    local curVal, dragging = props.default or props.min, false
    local function applyPct(pct)
        pct = math.clamp(pct, 0, 1)
        curVal = math.floor(props.min + (props.max - props.min) * pct)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        thumb.Position = UDim2.new(pct, -7, 0.5, -7)
        valL.Text = tostring(curVal)
        if props.onChange then props.onChange(curVal) end
    end
    local function setFromX(px)
        local tw = track.AbsoluteSize.X
        if tw == 0 then return end
        applyPct((px - track.AbsolutePosition.X) / tw)
    end
    local initPct = (curVal - props.min) / (props.max - props.min)
    fill.Size = UDim2.new(initPct,0,1,0)
    thumb.Position = UDim2.new(initPct,-7,0.5,-7)
    thumb.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true end
    end)
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; setFromX(i.Position.X)
        end
    end)
    Svc.Input.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    Svc.Input.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            setFromX(i.Position.X)
        end
    end)
    return row
end

function UI.scrollList(parent, h, w)
    local sf = Instance.new("ScrollingFrame", parent)
    sf.Size = UDim2.new(0, w or 1, 0, h)
    if not w then sf.Size = UDim2.new(1,0,0,h) end
    sf.BackgroundColor3 = C.dark1
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = C.border
    sf.CanvasSize = UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.BorderSizePixel = 0
    UI.corner(10, sf); UI.stroke(C.border, 1, sf)
    UI.listLayout(sf, nil, 4); UI.pad(4,4,4,4, sf)
    return sf
end

function UI.notify(title, msg, col)
    task.spawn(function()
        local pgui = LP:WaitForChild("PlayerGui")
        local sc = pgui:FindFirstChild("NxsNotif")
        if not sc then
            sc = Instance.new("ScreenGui", pgui)
            sc.Name = "NxsNotif"
            sc.ResetOnSpawn = false
            sc.DisplayOrder = 500
            local bag = Instance.new("Frame", sc)
            bag.Name = "Bag"
            bag.Size = UDim2.new(0, 210, 0, 300)
            bag.Position = UDim2.new(0.5, -105, 1, -140)
            bag.BackgroundTransparency = 1
            local ul = Instance.new("UIListLayout", bag)
            ul.Padding = UDim.new(0, 5); ul.SortOrder = Enum.SortOrder.LayoutOrder
            ul.VerticalAlignment = Enum.VerticalAlignment.Bottom
            ul.HorizontalAlignment = Enum.HorizontalAlignment.Center
        end
        local bag = sc:FindFirstChild("Bag"); if not bag then return end
        local n = Instance.new("Frame", bag)
        n.Size = UDim2.new(1, 0, 0, 34)
        n.BackgroundColor3 = C.dark1
        n.ClipsDescendants = true
        UI.corner(17, n)
        local nStroke = UI.stroke(col or C.accent, 1.2, n); nStroke.Transparency = 0.2
        local dot = Instance.new("Frame", n)
        dot.Size = UDim2.new(0,8,0,8); dot.Position = UDim2.new(0,10,0.5,-4)
        dot.BackgroundColor3 = col or C.accent; dot.ZIndex = 2; UI.round(dot)
        UI.label({ Text = msg, Font = Enum.Font.GothamMedium, TextSize = 11,
            TextColor3 = C.text, Size = UDim2.new(1,-30,1,0), Position = UDim2.new(0,24,0,0),
            Truncate = Enum.TextTruncate.AtEnd }, n)
        n.Position = UDim2.new(0.5, 0, 1, 20); n.BackgroundTransparency = 1
        UI.tween(n, 0.2, { Position = UDim2.new(0,0,0,0), BackgroundTransparency = 0 })
        task.wait(2.2)
        UI.tween(n, 0.2, { BackgroundTransparency = 1 })
        task.wait(0.2); pcall(function() n:Destroy() end)
    end)
end

local function makeDraggable(handle, target)
    local dragging, dragStart, startPos = false, nil, nil
    local function onBegin(inp)
        local t = inp.UserInputType
        if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
        dragging = true; dragStart = inp.Position; startPos = target.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
    handle.InputBegan:Connect(onBegin)
    Svc.Input.InputChanged:Connect(function(inp)
        if not dragging then return end
        local t = inp.UserInputType
        if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
        local d = inp.Position - dragStart
        target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end)
end

-- ═══════════════════════════════════════════════════════════════════
-- [12] MAIN UI BUILDER  (sem lista de mobs)
-- ═══════════════════════════════════════════════════════════════════
local function BuildUI()
    local pgui = LP:WaitForChild("PlayerGui")
    if pgui:FindFirstChild("NexusRoutes") then pgui.NexusRoutes:Destroy() end

    local sc = Instance.new("ScreenGui", pgui)
    sc.Name = "NexusRoutes"
    sc.ResetOnSpawn = false
    sc.DisplayOrder = 10
    sc.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sc.IgnoreGuiInset = true

    local isTouch = Svc.Input.TouchEnabled
    local W = isTouch and 400 or 340

    local win = Instance.new("Frame", sc)
    win.Size = UDim2.new(0, W, 0, 0)
    win.AutomaticSize = Enum.AutomaticSize.Y
    win.AnchorPoint = Vector2.new(0.5, isTouch and 0 or 0.5)
    win.Position = isTouch and UDim2.new(0.5, 0, 0.05, 0) or UDim2.new(0.5, 0, 0.5, 0)
    win.BackgroundColor3 = C.bg
    win.BorderSizePixel = 0
    win.ClipsDescendants = true
    UI.corner(16, win)
    UI.gradient(win, Color3.fromRGB(9, 13, 20), Color3.fromRGB(15, 20, 32), 80)
    local winStroke = UI.stroke(C.accent, 1.4, win)
    winStroke.Transparency = 0.45
    UI.pulse({ winStroke }, 0.3, 0.65, 1.6, "Transparency")
    win.BackgroundTransparency = 1
    UI.tween(win, 0.25, { BackgroundTransparency = 0 })
    if not isTouch then
        local scale = Instance.new("UIScale", win); scale.Scale = 1.3
    end

    UI.listLayout(win, Enum.FillDirection.Vertical, 6, nil, Enum.HorizontalAlignment.Center)
    UI.pad(8,8,8,8, win)

    -- Top bar
    local topBar = Instance.new("Frame", win)
    topBar.Size = UDim2.new(1,0,0,20)
    topBar.BackgroundTransparency = 1
    topBar.LayoutOrder = 0
    makeDraggable(topBar, win)

    local statusDot = Instance.new("Frame", topBar)
    statusDot.Size = UDim2.new(0,8,0,8)
    statusDot.Position = UDim2.new(0,2,0.5,-4)
    statusDot.BackgroundColor3 = C.sub
    statusDot.ZIndex = 2
    UI.round(statusDot)
    UI.stroke(C.sub, 1, statusDot).Transparency = 0.4
    State.statusDot = statusDot

    local statusLbl = UI.label({
        Text = "Stopped",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = C.sub,
        Size = UDim2.new(0,110,1,0),
        Position = UDim2.new(0,16,0,0),
    }, topBar)
    State.statusLbl = statusLbl

    local titleLbl = UI.label({
        Text = "NX EVO",
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = C.accent,
        Size = UDim2.new(0,100,1,0),
        Position = UDim2.new(0,128,0,0),
        AlignX = Enum.TextXAlignment.Center,
    }, topBar)
    titleLbl.TextStrokeColor3 = C.accent
    titleLbl.TextStrokeTransparency = 0.75

    local minBtn = UI.circleBtn({ d = 20, icon = "–", bg = C.nav, iconColor = C.sub, hover = C.item }, topBar)
    minBtn.Position = UDim2.new(1,-44,0.5,-10)
    UI.pressFeedback(minBtn)

    local closeBtn = UI.circleBtn({ d = 20, icon = "×", bg = C.nav, iconColor = C.red, hover = C.item }, topBar)
    closeBtn.Position = UDim2.new(1,-20,0.5,-10)
    UI.pressFeedback(closeBtn)

    -- Main row: FARM button + toggles
    local mainRow = Instance.new("Frame", win)
    mainRow.Size = UDim2.new(1,0,0,72)
    mainRow.BackgroundTransparency = 1
    mainRow.LayoutOrder = 1

    local farmBtn = Instance.new("TextButton", mainRow)
    farmBtn.Size = UDim2.new(0,58,0,58)
    farmBtn.Position = UDim2.new(0,0,0,0)
    farmBtn.BackgroundColor3 = C.dimred
    farmBtn.Text = "▶"
    farmBtn.Font = Enum.Font.GothamBold
    farmBtn.TextSize = 22
    farmBtn.TextColor3 = C.red
    farmBtn.AutoButtonColor = false
    farmBtn.ZIndex = 2
    UI.round(farmBtn)
    local farmStroke = UI.stroke(C.red, 1.8, farmBtn)
    farmStroke.Transparency = 0.2
    local farmStopPulse = nil
    State.startBtn = farmBtn
    UI.pressFeedback(farmBtn)

    UI.label({
        Text = "FARM",
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextColor3 = C.sub,
        Size = UDim2.new(0,58,0,12),
        Position = UDim2.new(0,0,0,60),
        AlignX = Enum.TextXAlignment.Center,
    }, mainRow)

    local divider = Instance.new("Frame", mainRow)
    divider.Size = UDim2.new(0,1,0,58)
    divider.Position = UDim2.new(0,70,0,0)
    divider.BackgroundColor3 = C.bdr2

    local togRow = Instance.new("Frame", mainRow)
    togRow.Size = UDim2.new(1,-82,0,72)
    togRow.Position = UDim2.new(0,82,0,0)
    togRow.BackgroundTransparency = 1
    UI.listLayout(togRow, Enum.FillDirection.Horizontal, 6, nil, Enum.HorizontalAlignment.Left)

    local setFarmOn

    UI.toggleDot(togRow, {
        icon = "⚔", label = "Battle", order = 1, default = true, d = 32,
        onColor = C.accent,
        onChange = function(v)
            State.battleDetection = v
            if not v then
                State.inBattle = false
                Battle.stopSkillLoop()
                Input.releaseAll()
                Battle._updateStatus()
                UI.notify("Battle Detection", "OFF", C.orange)
            else
                UI.notify("Battle Detection", "ON", C.green)
            end
        end,
    })

    UI.toggleDot(togRow, {
        icon = "⚡", label = "Skill", order = 2, default = true, d = 32,
        onColor = C.accent,
        onChange = function(v)
            State.useSkill1 = v
            if not v then
                Battle.stopSkillLoop()
                UI.notify("Skill 1", "OFF", C.orange)
            else
                UI.notify("Skill 1", "ON", C.green)
            end
        end,
    })

    UI.toggleDot(togRow, {
        icon = "🔁", label = "Loop", order = 3, default = true, d = 32,
        onColor = C.accent,
        onChange = function(v)
            State.circuitLoop = v
            Persist.save()
            UI.notify("Loop", v and "ON" or "OFF", v and C.green or C.orange)
        end,
    })

    UI.toggleDot(togRow, {
        icon = "🚀", label = "Speed", order = 4, default = false, d = 32,
        onColor = C.accent,
        onChange = function(v)
            State.speedOn = v
            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = v and State.walkSpeed or 16 end
            UI.notify("Speed", v and "ON" or "OFF", v and C.green or C.orange)
        end,
    })

    UI.toggleDot(togRow, {
        icon = "🔍", label = "Zoom", order = 5, default = false, d = 32,
        onColor = C.accent,
        onChange = function(v)
            State.zoomOn = v
            Zoom.setEnabled(v, State.zoomValue)
            UI.notify("Zoom", v and "ON" or "OFF", v and C.green or C.orange)
        end,
    })

    -- Sliders: Skill interval, Speed, Zoom, RANGE
    local slidersWrap = Instance.new("Frame", win)
    slidersWrap.Size = UDim2.new(1,0,0,44)
    slidersWrap.BackgroundColor3 = C.dark1
    slidersWrap.LayoutOrder = 2
    UI.corner(10, slidersWrap); UI.stroke(C.border, 1, slidersWrap)
    UI.pad(6,8,8,6, slidersWrap)
    UI.listLayout(slidersWrap, Enum.FillDirection.Horizontal, 10)

    local function sliderCol(icon, order, w)
        local col = Instance.new("Frame", slidersWrap)
        col.Size = UDim2.new(0, w, 1, 0)
        col.BackgroundTransparency = 1
        col.LayoutOrder = order
        local header = Instance.new("Frame", col)
        header.Size = UDim2.new(1, 0, 0, 16)
        header.BackgroundTransparency = 1
        UI.listLayout(header, Enum.FillDirection.Horizontal, 4)
        UI.label({
            Text = icon,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = C.sub,
            Size = UDim2.new(0,14,1,0),
        }, header)
        local valueLbl = UI.label({
            Text = "",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = C.accent,
            Size = UDim2.new(0,40,1,0),
        }, header)
        return col, valueLbl
    end

    local skillCol, skillVal = sliderCol("⚡", 1, 80)
    UI.miniSlider(skillCol, {
        min = 1, max = 10, default = 2, w = 80,
        valueLabel = skillVal,
        onChange = function(v) State.skill1Interval = v end,
    }).Position = UDim2.new(0,0,0,18)

    local speedCol, speedVal = sliderCol("🚀", 2, 80)
    UI.miniSlider(speedCol, {
        min = 8, max = 120, default = 24, w = 80,
        valueLabel = speedVal,
        onChange = function(v)
            State.walkSpeed = v
            if State.speedOn then
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = v end
            end
        end,
    }).Position = UDim2.new(0,0,0,18)

    local zoomCol, zoomVal = sliderCol("🔍", 3, 80)
    UI.miniSlider(zoomCol, {
        min = 20, max = 800, default = 60, w = 80,
        valueLabel = zoomVal,
        onChange = function(v)
            State.zoomValue = v
            if State.zoomOn then Zoom.apply(v) end
        end,
    }).Position = UDim2.new(0,0,0,18)

    local rangeCol, rangeVal = sliderCol("📏", 4, 80)
    UI.miniSlider(rangeCol, {
        min = 10, max = 200, default = State.huntRange, w = 80,
        valueLabel = rangeVal,
        onChange = function(v)
            State.huntRange = v
            Persist.save()
            UI.notify("Range", v .. "m", C.accent)
        end,
    }).Position = UDim2.new(0,0,0,18)

    -- Mode switch (Route / Mobs) — sem lista de mobs
    local modeRow = Instance.new("Frame", win)
    modeRow.Size = UDim2.new(1,0,0,26)
    modeRow.BackgroundColor3 = C.dark1
    modeRow.LayoutOrder = 3
    UI.corner(9, modeRow)
    UI.stroke(C.border, 1, modeRow).Transparency = 0.5
    UI.pad(3,3,3,3, modeRow)
    UI.listLayout(modeRow, Enum.FillDirection.Horizontal, 4)

    local function modeBtn(label)
        local b = Instance.new("TextButton", modeRow)
        b.Size = UDim2.new(0.5, -2, 1, 0)
        b.Text = label
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.AutoButtonColor = false
        UI.corner(7, b)
        return b
    end
    local routeModeBtn = modeBtn("Route")
    local mobsModeBtn = modeBtn("Mobs")

    -- Waypoints (mantido)
    local wpHeader = Instance.new("Frame", win)
    wpHeader.Size = UDim2.new(1,0,0,30)
    wpHeader.BackgroundTransparency = 1
    wpHeader.LayoutOrder = 4

    local wpCountLbl = UI.label({
        Text = "Waypoints (0)",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = C.sub,
        Size = UDim2.new(1,-70,1,0),
        Position = UDim2.new(0,0,0,0),
    }, wpHeader)

    local addBtn = UI.circleBtn({ d = 26, icon = "+", bg = C.accent, iconColor = C.white, hover = C.acc2 }, wpHeader)
    addBtn.Position = UDim2.new(1,-58,0.5,-13)

    local clearBtn = UI.circleBtn({ d = 26, icon = "🗑", bg = C.dimred, iconColor = C.white, hover = Color3.fromRGB(70,20,20) }, wpHeader)
    clearBtn.Position = UDim2.new(1,-26,0.5,-13)

    local wpList = UI.scrollList(win, 140)
    wpList.LayoutOrder = 5

    local function refreshWP()
        wpCountLbl.Text = "Waypoints (" .. #State.waypoints .. ")"
        for _, ch in ipairs(wpList:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
        if #State.waypoints == 0 then
            local ef = Instance.new("Frame", wpList)
            ef.Size = UDim2.new(1,0,0,32)
            ef.BackgroundTransparency = 1
            ef.LayoutOrder = 0
            UI.label({
                Text = "No waypoints — tap +",
                Font = Enum.Font.Gotham,
                TextSize = 10,
                TextColor3 = C.sub,
                Size = UDim2.new(1,0,1,0),
                AlignX = Enum.TextXAlignment.Center,
                Wrap = true,
            }, ef)
            return
        end
        for i, wp in ipairs(State.waypoints) do
            local row = Instance.new("Frame", wpList)
            row.Size = UDim2.new(1,0,0,38)
            row.BackgroundColor3 = C.item
            row.LayoutOrder = i
            row.ClipsDescendants = true
            UI.corner(10, row)
            UI.stroke(C.bdr2, 1, row).Transparency = 0.35
            local accentBar = Instance.new("Frame", row)
            accentBar.Size = UDim2.new(0,3,1,0)
            accentBar.Position = UDim2.new(0,0,0,0)
            accentBar.BackgroundColor3 = C.accent
            accentBar.BorderSizePixel = 0
            local badge = Instance.new("Frame", row)
            badge.Size = UDim2.new(0,20,0,20)
            badge.Position = UDim2.new(0,10,0.5,-10)
            badge.BackgroundColor3 = C.accent
            badge.ZIndex = 2
            UI.round(badge)
            UI.stroke(C.white, 1, badge).Transparency = 0.55
            UI.label({
                Text = tostring(i),
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextColor3 = C.white,
                AlignX = Enum.TextXAlignment.Center,
            }, badge)
            UI.label({
                Text = wp.name,
                Font = Enum.Font.GothamSemibold,
                TextSize = 11,
                TextColor3 = C.text,
                Size = UDim2.new(1,-190,0,16),
                Position = UDim2.new(0,32,0,3),
                Truncate = Enum.TextTruncate.AtEnd,
            }, row)
            UI.label({
                Text = wp.coord,
                Font = Enum.Font.Gotham,
                TextSize = 9,
                TextColor3 = C.sub,
                Size = UDim2.new(1,-190,0,12),
                Position = UDim2.new(0,32,0,19),
            }, row)
            local function microCircle(bgCol, txt, iconCol)
                return UI.circleBtn({ d = 22, icon = txt, bg = bgCol or C.dark2, iconColor = iconCol or C.text, hover = C.itemH }, row)
            end
            local upBtn = microCircle(C.dark2, "↑")
            upBtn.Position = UDim2.new(1,-72,0.5,-11)
            local downBtn = microCircle(C.dark2, "↓")
            downBtn.Position = UDim2.new(1,-48,0.5,-11)
            local delBtn = microCircle(C.dimred, "×", C.white)
            delBtn.Position = UDim2.new(1,-24,0.5,-11)
            local ci = i
            upBtn.MouseButton1Click:Connect(function()
                if ci <= 1 then return end
                State.waypoints[ci], State.waypoints[ci-1] = State.waypoints[ci-1], State.waypoints[ci]
                Persist.save(); refreshWP()
            end)
            downBtn.MouseButton1Click:Connect(function()
                if ci >= #State.waypoints then return end
                State.waypoints[ci], State.waypoints[ci+1] = State.waypoints[ci+1], State.waypoints[ci]
                Persist.save(); refreshWP()
            end)
            delBtn.MouseButton1Click:Connect(function()
                table.remove(State.waypoints, ci)
                Persist.save(); refreshWP()
            end)
        end
    end

    addBtn.MouseButton1Click:Connect(function()
        local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not root then UI.notify("Error", "Character not found", C.red); return end
        local pos = root.Position
        local name = "WP " .. (#State.waypoints + 1)
        local coord = string.format("%.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z)
        table.insert(State.waypoints, { name = name, coord = coord, pos = pos })
        Persist.save(); refreshWP()
        UI.notify("Waypoint", "Added: " .. name, C.accent)
    end)

    clearBtn.MouseButton1Click:Connect(function()
        if #State.waypoints == 0 then return end
        State.waypoints = {}; Persist.save(); refreshWP()
        UI.notify("Waypoints", "Cleared", C.orange)
    end)

    local function setMode(key)
        if State.mode == key then return end
        if State.farmOn then setFarmOn(false) end
        State.mode = key
        local onRoute = (key == "route")
        routeModeBtn.BackgroundColor3 = onRoute and C.accent or C.item
        routeModeBtn.TextColor3 = onRoute and C.white or C.sub
        mobsModeBtn.BackgroundColor3 = onRoute and C.item or C.accent
        mobsModeBtn.TextColor3 = onRoute and C.sub or C.white
        wpHeader.Visible = onRoute
        wpList.Visible = onRoute
        -- Não há mais lista de mobs, apenas o modo ativo
    end

    routeModeBtn.MouseButton1Click:Connect(function() setMode("route") end)
    mobsModeBtn.MouseButton1Click:Connect(function() setMode("mobs") end)
    setMode("route")

    -- Farm button logic
    local function syncFarmGlow()
        local col = State.farmOn and C.green or C.red
        farmStroke.Color = col
        farmStroke.Thickness = State.farmOn and 2.2 or 1.8
        if farmStopPulse then farmStopPulse(); farmStopPulse = nil end
        if State.farmOn then
            farmStopPulse = UI.pulse({ farmStroke }, 0.05, 0.5, 0.85, "Transparency")
        else
            farmStroke.Transparency = 0.2
        end
    end

    local function resetFarmUI()
        State.farmOn = false
        farmBtn.BackgroundColor3 = C.dimred
        farmBtn.TextColor3 = C.red
        farmBtn.Text = "▶"
        Battle._updateStatus()
        syncFarmGlow()
    end
    State.onFarmAutoStop = resetFarmUI

    setFarmOn = function(on)
        if on then
            if State.mode == "mobs" then
                local closest = MobHunt.getClosestInRange()
                if not closest then
                    UI.notify("FARM", "No mobs within " .. State.huntRange .. "m", C.red)
                    return
                end
            elseif #State.waypoints == 0 then
                UI.notify("FARM", "No waypoints", C.red)
                return
            end

            State.farmOn = true
            farmBtn.BackgroundColor3 = C.dimgrn
            farmBtn.TextColor3 = C.green
            farmBtn.Text = "■"
            statusLbl.Text = "Active"
            statusLbl.TextColor3 = C.green
            statusDot.BackgroundColor3 = C.green
            syncFarmGlow()

            if State.mode == "mobs" then
                MobHunt.start()
                UI.notify("FARM", "Auto-hunt started (range: " .. State.huntRange .. "m)", C.green)
            else
                Circuit.start()
                UI.notify("FARM", "Circuit started", C.green)
            end
        else
            if State.mode == "mobs" then MobHunt.stop() else Circuit.stop() end
            resetFarmUI()
            UI.notify("FARM", "Stopped", C.orange)
        end
    end

    farmBtn.MouseButton1Click:Connect(function() setFarmOn(not State.farmOn) end)
    farmBtn.MouseEnter:Connect(function()
        UI.tween(farmBtn, 0.1, { BackgroundColor3 = State.farmOn and Color3.fromRGB(20,70,30) or Color3.fromRGB(70,20,20) })
    end)
    farmBtn.MouseLeave:Connect(function()
        UI.tween(farmBtn, 0.1, { BackgroundColor3 = State.farmOn and C.dimgrn or C.dimred })
    end)

    -- F1 Keybind
    local f1Conn = Svc.Input.InputBegan:Connect(function(inp, processed)
        if processed then return end
        if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == Enum.KeyCode.F1 then
            setFarmOn(not State.farmOn)
        end
    end)

    local function fullCleanup()
        f1Conn:Disconnect()
        Circuit.stop()
        MobHunt.stop()
        Input.releaseAll()
        Battle.stopMonitor()
        Zoom.setEnabled(false)
        _G.NexusRoutesActive = nil
    end

    closeBtn.MouseButton1Click:Connect(function()
        fullCleanup()
        UI.tween(win, 0.2, { BackgroundTransparency = 1 })
        task.wait(0.22)
        sc:Destroy()
    end)

    local miniBtn
    minBtn.MouseButton1Click:Connect(function()
        win.Visible = false
        if miniBtn then miniBtn:Destroy() end
        miniBtn = UI.circleBtn({ d = 46, icon = "●", bg = C.nav, iconColor = C.accent, hover = C.item }, sc)
        miniBtn.Position = UDim2.new(0,14,0,60)
        UI.stroke(C.border, 1, miniBtn)
        makeDraggable(miniBtn, miniBtn)
        miniBtn.MouseButton1Click:Connect(function()
            win.Visible = true
            miniBtn:Destroy()
            miniBtn = nil
        end)
    end)

    Battle.startMonitor()
    refreshWP()
    _G.NexusRoutesActive = fullCleanup
    return sc
end

-- ═══════════════════════════════════════════════════════════════════
-- [13] INIT
-- ═══════════════════════════════════════════════════════════════════
local function ShowLoader(onDone)
    local pgui = LP:WaitForChild("PlayerGui")
    if pgui:FindFirstChild("NxsLoader") then pgui.NxsLoader:Destroy() end
    local sc = Instance.new("ScreenGui", pgui)
    sc.Name = "NxsLoader"
    sc.ResetOnSpawn = false
    sc.DisplayOrder = 50
    sc.IgnoreGuiInset = true
    sc.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local wrap = Instance.new("Frame", sc)
    wrap.Size = UDim2.new(0,140,0,110)
    wrap.Position = UDim2.new(0.5,-70,0.5,-55)
    wrap.BackgroundTransparency = 1
    local ring = Instance.new("Frame", wrap)
    ring.Size = UDim2.new(0,54,0,54)
    ring.Position = UDim2.new(0.5,-27,0,4)
    ring.BackgroundTransparency = 1
    ring.ZIndex = 2
    UI.round(ring)
    local ringStroke = UI.stroke(C.accent, 3, ring)
    local ringGrad = Instance.new("UIGradient", ring)
    ringGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.7, 0.55),
        NumberSequenceKeypoint.new(1, 1),
    })
    task.spawn(function()
        while ring.Parent do
            ringGrad.Rotation = (ringGrad.Rotation + 8) % 360
            task.wait(0.02)
        end
    end)
    local titleLbl = UI.label({
        Text = "NX EVO",
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = C.accent,
        Size = UDim2.new(1,0,0,18),
        Position = UDim2.new(0,0,0,66),
        AlignX = Enum.TextXAlignment.Center,
    }, wrap)
    titleLbl.TextStrokeColor3 = C.accent
    titleLbl.TextStrokeTransparency = 0.7
    local subLbl = UI.label({
        Text = "Loading",
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextColor3 = C.sub,
        Size = UDim2.new(1,0,0,14),
        Position = UDim2.new(0,0,0,86),
        AlignX = Enum.TextXAlignment.Center,
    }, wrap)
    task.spawn(function()
        local dots, i = {"", ".", "..", "..."}, 1
        while subLbl.Parent do
            subLbl.Text = "Loading" .. dots[i]
            i = (i % #dots) + 1
            task.wait(0.28)
        end
    end)
    task.delay(0.9, function()
        for _, d in ipairs(sc:GetDescendants()) do
            if d:IsA("Frame") then UI.tween(d, 0.25, { BackgroundTransparency = 1 }) end
            if d:IsA("TextLabel") then UI.tween(d, 0.25, { TextTransparency = 1, TextStrokeTransparency = 1 }) end
            if d:IsA("UIStroke") then UI.tween(d, 0.25, { Transparency = 1 }) end
        end
        task.wait(0.27)
        sc:Destroy()
        onDone()
    end)
end

Persist.load()
ShowLoader(function()
    BuildUI()
    UI.notify("NX EVO", "Loaded", C.accent)
end)