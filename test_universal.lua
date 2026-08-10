local HttpRequest =
    (type(syn)    == "table" and syn.request)
    or (type(http) == "table" and http.request)
    or rawget(_G, "http_request")
    or rawget(_G, "request")
    or (type(fluxus) == "table" and fluxus.request)
    or nil

local function safeClipboard(text)
    for _, fn in ipairs({
        rawget(_G, "setclipboard"),
        rawget(_G, "toclipboard"),
        syn and syn.clipboard and syn.clipboard.set,
    }) do if type(fn) == "function" then pcall(fn, text); return end end
end

local writefile_ = rawget(_G, "writefile") or function() end
local readfile_  = rawget(_G, "readfile")  or function() return nil end
local function hasFileAPI()
    return type(rawget(_G, "writefile")) == "function"
       and type(rawget(_G, "readfile"))  == "function"
end

local Services = {
    Players   = game:GetService("Players"),
    Run       = game:GetService("RunService"),
    Tween     = game:GetService("TweenService"),
    Input     = game:GetService("UserInputService"),
    Http      = game:GetService("HttpService"),
    Workspace = game:GetService("Workspace"),
    Lighting  = game:GetService("Lighting"),
}
local VIM; pcall(function() VIM = game:GetService("VirtualInputManager") end)
local VU;  pcall(function() VU  = game:GetService("VirtualUser") end)

local LP     = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

local CONFIG = table.freeze({
    VERSION            = "v6.1", -- Versão atualizada
    BRAND              = "NEXUS UNIVERSAL",
    HEARTBEAT_URL      = "https://api.tgferr.com.br/api/heartbeat",
    SCRIPT_ID          = "universalcheat.lua",
    SCAN_TTL           = 2,
    HEARTBEAT_INTERVAL = 300,
    DEFAULT_GRAVITY    = 196.2,
    DEFAULT_JUMP       = 50,

    C = table.freeze({
        bg     = Color3.fromRGB(12, 16, 20),
        nav    = Color3.fromRGB(8,  12, 18),
        item   = Color3.fromRGB(22, 32, 42),
        itemH  = Color3.fromRGB(32, 48, 60),
        border = Color3.fromRGB(0,  80, 120),
        accent = Color3.fromRGB(0, 150, 255),
        acc2   = Color3.fromRGB(0, 130, 220),
        text   = Color3.fromRGB(220,230,255),
        sub    = Color3.fromRGB(140,180,220),
        white  = Color3.fromRGB(255,255,255),
        red    = Color3.fromRGB(220, 50, 50),
        orange = Color3.fromRGB(255,150,  0),
        green  = Color3.fromRGB(0,  220, 80),
        dimred = Color3.fromRGB(50,  10, 10),
        dimgrn = Color3.fromRGB(10,  50, 20),
        dark1  = Color3.fromRGB(14, 22, 28),
        dark2  = Color3.fromRGB(40, 50, 60),
        bdr2   = Color3.fromRGB(30, 50, 70),
        yellow = Color3.fromRGB(255,220,  0),
        purple = Color3.fromRGB(160, 80, 255),
    }),

    NPC_KW = table.freeze({
        "quest","giver","npc","seller","dealer","trainer","mayor","king","captain",
        "shop","vendor","guide","elder","guard","citizen","villager","merchant","blacksmith",
    }),
})
local C = CONFIG.C

local Signal = {}; Signal.__index = Signal
function Signal.new()   return setmetatable({_c={}}, Signal) end
function Signal:add(k,c) if self._c[k] then pcall(function() self._c[k]:Disconnect() end) end; self._c[k]=c end
function Signal:remove(k) if self._c[k] then pcall(function() self._c[k]:Disconnect() end); self._c[k]=nil end end
function Signal:clear() for k,c in pairs(self._c) do pcall(function() c:Disconnect() end); self._c[k]=nil end end

local State = {
    infJump     = false,
    noclip      = false,
    speedOn     = false,
    freecam     = false,
    fly         = false,
    walkSpeed   = 24,
    flySpeed    = 60,
    removeFog   = false,
    
    -- NOVO: TP Walk (Small TPs forward) sugerido no Discord
    tpWalkOn    = false,
    tpWalkSpeed = 30,

    jumpOn      = false,
    jumpPower   = 75,
    gravityOn   = false,
    gravity     = 100,

    kbFly       = Enum.KeyCode.F,
    kbSpeed     = Enum.KeyCode.G,
    kbListening = nil,   

    combatPhase  = "idle",
    targetName   = nil,
    attackRange  = 8,
    retreatRange = 4,

    antiAfk      = false,

    espPlayers   = false,
    espMobs      = false,
    espFillPlayerColor = Color3.fromRGB(0,  120, 255),
    espFillMobColor    = Color3.fromRGB(255, 50,  50),

    fullBright   = false,
    timeControl  = false,
    timeOfDay    = 14,

    chestKeywords = {"chest"},

    _scanCache    = nil,
    forceScanMode = false,

    waypoints     = {},   
    circuitOn     = false,
    circuitLoop   = true,

    savedDests    = {},
    blacklist     = {},

    _flyBV        = nil, 
    _flyBG        = nil,

    _camPos       = Vector3.zero,
    _camRotX      = 0,
    _camRotY      = 0,

    initialized   = false,
}

local _espHL = {}      
local _circuitTask = nil
local PERSIST_FILE = "nexus_v6_data.json"

local function saveData()
    if not hasFileAPI() then return end
    pcall(function()
        writefile_(PERSIST_FILE, Services.Http:JSONEncode({
            savedDests    = State.savedDests,
            blacklist     = State.blacklist,
            chestKeywords = State.chestKeywords,
            waypoints     = (function()
                local out = {}
                for _, wp in ipairs(State.waypoints) do
                    table.insert(out, {name=wp.name, coord=wp.coord})
                end
                return out
            end)(),
            kbFly   = State.kbFly.Name,
            kbSpeed = State.kbSpeed.Name,
        }))
    end)
end

local function loadData()
    if not hasFileAPI() then return end
    local ok, raw = pcall(readfile_, PERSIST_FILE)
    if not (ok and raw) then return end
    local ok2, d = pcall(Services.Http.JSONDecode, Services.Http, raw)
    if not ok2 or type(d) ~= "table" then return end

    if type(d.savedDests) == "table" then
        State.savedDests = {}
        for _, v in ipairs(d.savedDests) do
            if type(v)=="table" and type(v.name)=="string" and type(v.coord)=="string" then
                table.insert(State.savedDests, {name=v.name, coord=v.coord})
            end
        end
    end
    if type(d.blacklist) == "table" then
        State.blacklist = {}
        for _, v in ipairs(d.blacklist) do
            if type(v)=="string" and #v>0 then table.insert(State.blacklist, v) end
        end
    end
    if type(d.chestKeywords) == "table" then
        State.chestKeywords = {}
        for _, v in ipairs(d.chestKeywords) do
            if type(v)=="string" and #v>0 then table.insert(State.chestKeywords, v) end
        end
        if #State.chestKeywords == 0 then State.chestKeywords = {"chest"} end
    end
    if type(d.waypoints) == "table" then
        State.waypoints = {}
        for _, v in ipairs(d.waypoints) do
            if type(v)=="table" and v.name and v.coord then
                local nums = {}
                for n in v.coord:gmatch("[-]?%d+%.?%d*") do
                    table.insert(nums, tonumber(n)); if #nums==3 then break end
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
    pcall(function()
        if d.kbFly   then State.kbFly   = Enum.KeyCode[d.kbFly]   end
        if d.kbSpeed then State.kbSpeed = Enum.KeyCode[d.kbSpeed] end
    end)
end

local function playerCharSet()
    local s = {}
    for _, p in ipairs(Services.Players:GetPlayers()) do
        if p.Character then s[p.Character] = true end
    end
    return s
end

local function isBlockedNPC(name)
    local low = name:lower()
    for _, kw in ipairs(CONFIG.NPC_KW) do
        if low:find(kw, 1, true) then return true end
    end
    for _, b in ipairs(State.blacklist) do
        local bl = b:lower()
        if low == bl or low:find(bl, 1, true) then return true end
    end
    return false
end

local function scanTargets(forceAll)
    local now   = os.clock()
    local cache = State._scanCache
    if cache and not forceAll and (now - cache.ts) < CONFIG.SCAN_TTL then return cache.r end

    local myChar = LP.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local pcs    = playerCharSet()
    local res, seen = {}, {}

    local function tryAdd(obj)
        if seen[obj] or pcs[obj] or not obj:IsA("Model") or isBlockedNPC(obj.Name) then return end
        local hum = obj:FindFirstChildOfClass("Humanoid")
        local hrp = obj:FindFirstChild("HumanoidRootPart")
        if not (hum and hrp and hum.Health > 0) then return end
        seen[obj] = true
        local dist = myHRP and (myHRP.Position - hrp.Position).Magnitude or math.huge
        table.insert(res, {name=obj.Name, model=obj, hrp=hrp, hum=hum,
            dist=dist, hp=math.floor(hum.Health), maxhp=math.floor(hum.MaxHealth)})
    end

    local ef = Services.Workspace:FindFirstChild("Enemies")
    if ef and not forceAll then
        for _, o in ipairs(ef:GetChildren()) do tryAdd(o) end
    else
        for _, o in ipairs(Services.Workspace:GetDescendants()) do tryAdd(o) end
    end
    table.sort(res, function(a,b) return a.dist < b.dist end)
    State._scanCache = {r=res, ts=now}
    return res
end

local function getMobsByName(name)
    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local list  = {}
    local function tryAdd(obj)
        if obj.Name ~= name or not obj:IsA("Model") then return end
        local hum = obj:FindFirstChildOfClass("Humanoid")
        local hrp = obj:FindFirstChild("HumanoidRootPart")
        if not (hum and hrp and hum.Health > 0) then return end
        local dist = myHRP and (myHRP.Position - hrp.Position).Magnitude or math.huge
        table.insert(list, {model=obj, hrp=hrp, hum=hum, dist=dist})
    end
    local ef = Services.Workspace:FindFirstChild("Enemies")
    if ef then for _, o in ipairs(ef:GetChildren()) do tryAdd(o) end end
    if #list == 0 then for _, o in ipairs(Services.Workspace:GetDescendants()) do tryAdd(o) end end
    table.sort(list, function(a,b) return a.dist < b.dist end)
    return list
end

local function scanChests()
    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local pcs   = playerCharSet()
    local res   = {}
    local kws   = State.chestKeywords

    local function matchesKeyword(name)
        local low = name:lower()
        for _, kw in ipairs(kws) do
            if low:find(kw:lower(), 1, true) then return true end
        end
        return false
    end

    for _, obj in ipairs(Services.Workspace:GetDescendants()) do
        if not pcs[obj] and matchesKeyword(obj.Name) then
            local bp, pos
            if obj:IsA("Model") then
                bp = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                if bp then pos = bp.Position end
            elseif obj:IsA("BasePart") then
                pos = obj.Position
            end
            if pos then
                local dist = myHRP and (myHRP.Position - pos).Magnitude or math.huge
                table.insert(res, {
                    obj   = obj,
                    name  = obj.Name,
                    pos   = pos,
                    dist  = dist,
                    coord = string.format("%.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z),
                })
            end
        end
    end
    table.sort(res, function(a,b) return a.dist < b.dist end)
    return res
end

local function nearbyModelNames(radius)
    radius = radius or 100
    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return {} end
    local pcs    = playerCharSet()
    local seen   = {}
    local result = {}
    for _, obj in ipairs(Services.Workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and not pcs[obj] and not seen[obj.Name] then
            local pos
            if obj:IsA("Model") then
                local bp = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                if bp then pos = bp.Position end
            else pos = obj.Position end
            if pos and (myHRP.Position - pos).Magnitude <= radius then
                seen[obj.Name] = true
                table.insert(result, {name=obj.Name, dist=math.floor((myHRP.Position-pos).Magnitude)})
            end
        end
    end
    table.sort(result, function(a,b) return a.dist < b.dist end)
    return result
end

local Movement = {}

function Movement.applySpeed()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum and State.combatPhase == "idle" then
        hum.WalkSpeed = State.speedOn and State.walkSpeed or 16
    end
end

function Movement.applyJump()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function() hum.UseJumpPower = true end)
    hum.JumpPower = State.jumpOn and State.jumpPower or CONFIG.DEFAULT_JUMP
end

function Movement.applyGravity()
    Services.Workspace.Gravity = State.gravityOn and State.gravity or CONFIG.DEFAULT_GRAVITY
end

function Movement.applyNoclip()
    if not State.noclip then return end
    local char = LP.Character; if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

function Movement.setupFly(on)
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if on and root then
        if not State._flyBV then
            local bv = Instance.new("BodyVelocity", root)
            bv.MaxForce = Vector3.one*1e5; bv.Velocity = Vector3.zero
            State._flyBV = bv
        end
        if not State._flyBG then
            local bg = Instance.new("BodyGyro", root)
            bg.MaxTorque = Vector3.one*1e5; bg.P = 10000
            State._flyBG = bg
        end
    else
        if State._flyBV then State._flyBV:Destroy(); State._flyBV=nil end
        if State._flyBG then State._flyBG:Destroy(); State._flyBG=nil end
    end
end

function Movement.applyFog()
    local L = Services.Lighting
    if State.removeFog then
        L.FogEnd=1e6; L.FogStart=0
        pcall(function() local a=L:FindFirstChild("Atmosphere"); if a then a:Destroy() end end)
    else L.FogEnd=1e6 end
end

function Movement.resetAll()
    State.infJump=false; State.noclip=false; State.speedOn=false; State.tpWalkOn=false
    State.freecam=false; State.fly=false; State.removeFog=false
    State.jumpOn=false; State.gravityOn=false
    Services.Workspace.Gravity = CONFIG.DEFAULT_GRAVITY
    if Camera.CameraType==Enum.CameraType.Scriptable then
        Camera.CameraType=Enum.CameraType.Custom
    end
    Services.Input.MouseBehavior=Enum.MouseBehavior.Default
    Movement.setupFly(false)
    local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed=16; hum.JumpPower=CONFIG.DEFAULT_JUMP end
end

local ESP = {}

local function addHL(inst, fill, outline)
    if not inst or not inst.Parent then return end
    if _espHL[inst] then return end
    for _, c in ipairs(inst:GetChildren()) do
        if c:IsA("Highlight") then c:Destroy() end
    end
    local hl = Instance.new("Highlight")
    hl.Adornee            = inst
    hl.FillColor          = fill    or C.accent
    hl.OutlineColor       = outline or C.white
    hl.FillTransparency   = 0.5
    hl.OutlineTransparency= 0
    hl.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent             = inst
    _espHL[inst]          = hl
end

local function removeHL(inst)
    if _espHL[inst] then
        pcall(function() _espHL[inst]:Destroy() end)
        _espHL[inst] = nil
    end
end

function ESP.clearAll()
    for inst in pairs(_espHL) do pcall(function() _espHL[inst]:Destroy() end) end
    _espHL = {}
end

function ESP.update()
    local myChar = LP.Character
    for _, p in ipairs(Services.Players:GetPlayers()) do
        if p ~= LP and p.Character and p.Character ~= myChar then
            if State.espPlayers then
                addHL(p.Character, State.espFillPlayerColor, C.white)
            else
                removeHL(p.Character)
            end
        end
    end
    
    if State.espMobs then
        local mobs = scanTargets(State.forceScanMode)
        for _, mob in ipairs(mobs) do
            addHL(mob.model, State.espFillMobColor, C.yellow)
        end
    else
        for inst in pairs(_espHL) do
            local isPlayer = false
            for _, p in ipairs(Services.Players:GetPlayers()) do
                if p.Character == inst then isPlayer=true; break end
            end
            if not isPlayer then removeHL(inst) end
        end
    end
end

local WP = {}

function WP.add(name, pos)
    local coord = string.format("%.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z)
    table.insert(State.waypoints, {name=name, coord=coord, pos=pos})
    saveData()
end

function WP.remove(idx)
    table.remove(State.waypoints, idx)
    saveData()
end

function WP.clear()
    State.waypoints = {}; saveData()
end

function WP.move(idx, dir) 
    local target = idx + dir
    if target < 1 or target > #State.waypoints then return end
    State.waypoints[idx], State.waypoints[target] = State.waypoints[target], State.waypoints[idx]
    saveData()
end

function WP.start(statusLbl, onStop)
    if _circuitTask then task.cancel(_circuitTask) end
    State.circuitOn = true
    _circuitTask = task.spawn(function()
        local idx = 1
        while State.circuitOn and #State.waypoints > 0 do
            local wp = State.waypoints[idx]
            if not wp then break end

            if statusLbl then
                statusLbl.Text      = "🗺  " .. wp.name .. "  (" .. idx .. "/" .. #State.waypoints .. ")"
                statusLbl.TextColor3 = C.accent
            end

            local char  = LP.Character
            local hum   = char and char:FindFirstChildOfClass("Humanoid")
            local hrp   = char and char:FindFirstChild("HumanoidRootPart")

            if hum and hrp then
                if State.speedOn then hum.WalkSpeed = State.walkSpeed end
                hum:MoveTo(wp.pos)
                local t = os.clock()
                repeat
                    task.wait(0.15)
                    char = LP.Character
                    hrp  = char and char:FindFirstChild("HumanoidRootPart")
                until not State.circuitOn
                    or not hrp
                    or (hrp.Position - wp.pos).Magnitude < 7
                    or (os.clock() - t) > 15
            end

            idx = idx + 1
            if idx > #State.waypoints then
                if State.circuitLoop then idx = 1
                else State.circuitOn = false end
            end
            task.wait(0.1)
        end
        State.circuitOn = false
        if statusLbl then statusLbl.Text="⏹  Circuito finalizado."; statusLbl.TextColor3=C.sub end
        if onStop then onStop() end
    end)
end

function WP.stop()
    State.circuitOn = false
    if _circuitTask then task.cancel(_circuitTask); _circuitTask=nil end
end

local Visuals = {}

function Visuals.applyFullBright()
    local L = Services.Lighting
    if not State.fullBright then return end
    L.Brightness     = 2
    L.Ambient        = Color3.fromRGB(128,128,128)
    L.OutdoorAmbient = Color3.fromRGB(128,128,128)
    L.ShadowSoftness = 0
    pcall(function()
        for _, fx in ipairs(L:GetChildren()) do
            if fx:IsA("BlurEffect") or fx:IsA("SunRaysEffect")
            or fx:IsA("ColorCorrectionEffect") then
                pcall(function() fx.Enabled = false end)
            end
        end
    end)
end

function Visuals.applyTime()
    if State.timeControl then
        Services.Lighting.ClockTime = State.timeOfDay
    end
end

local Combat = {}

local function fireTool(targetHRP)
    local char = LP.Character; if not char then return end
    local tool = char:FindFirstChildOfClass("Tool"); if not tool then return end
    if VIM then pcall(function()
        VIM:SendMouseButtonEvent(0,0,0,true,game,0); task.wait(0.05)
        VIM:SendMouseButtonEvent(0,0,0,false,game,0)
    end) end
    pcall(function()
        for _, re in ipairs(tool:GetDescendants()) do
            if re:IsA("RemoteEvent") then re:FireServer(targetHRP, targetHRP.Position) end
        end
    end)
    pcall(function()
        local ae = tool:FindFirstChild("ActivateEvent") or tool:FindFirstChild("Activate")
        if ae and ae:IsA("RemoteEvent") then ae:FireServer() end
    end)
end

function Combat.startLoop(statusLbl, sigs)
    sigs:remove("combat")
    local acc = 0
    sigs:add("combat", Services.Run.Heartbeat:Connect(function(dt)
        if State.combatPhase=="idle" or not State.targetName then return end
        acc=acc+dt; if acc<0.05 then return end; acc=0
        local char  = LP.Character
        local myHRP = char and char:FindFirstChild("HumanoidRootPart")
        local myHum = char and char:FindFirstChildOfClass("Humanoid")
        if not (myHRP and myHum) then return end
        local mobs = getMobsByName(State.targetName)
        if #mobs==0 then
            if statusLbl then statusLbl.Text="Nenhum mob vivo: "..State.targetName; statusLbl.TextColor3=C.orange end
            return
        end
        local near = mobs[1]
        if statusLbl then
            statusLbl.Text=string.format("⚔  %s  (%d  •  %.0fm)", State.targetName, #mobs, near.dist)
            statusLbl.TextColor3=C.accent
        end
        if near.dist > State.attackRange then
            State.combatPhase="hunting"; myHum.WalkSpeed=State.walkSpeed; myHum:MoveTo(near.hrp.Position)
        elseif near.dist < State.retreatRange then
            State.combatPhase="retreating"; myHum.WalkSpeed=State.walkSpeed
            local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp then myHum:MoveTo(hrp.Position+(hrp.Position-near.hrp.Position).Unit*8) end
        else
            State.combatPhase="attacking"; myHum.WalkSpeed=math.floor(State.walkSpeed*0.5)
            myHum:MoveTo(near.hrp.Position)
            for _,m in ipairs(mobs) do if m.dist<=State.attackRange then fireTool(m.hrp) end end
        end
    end))
end

function Combat.stop(sigs)
    State.combatPhase="idle"; State.targetName=nil; sigs:remove("combat")
    local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed=State.speedOn and State.walkSpeed or 16 end
end

local function parseCoord(str)
    local nums={}
    for n in str:gmatch("[-]?%d+%.?%d*") do table.insert(nums,tonumber(n)); if #nums==3 then break end end
    return #nums>=3 and nums or nil
end

local function teleportTo(coords)
    local n=parseCoord(coords); if not n then return false end
    local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return false end
    hrp.CFrame=CFrame.new(n[1],n[2],n[3]); hrp.Velocity=Vector3.zero; return true
end

local _kbFlyRef   = nil  
local _kbSpeedRef = nil

local function startGameLoops(sigs)
    sigs:add("hb", Services.Run.Heartbeat:Connect(function()
        Movement.applyNoclip()
        if State.combatPhase=="idle" then Movement.applySpeed() end
        if State.removeFog then Movement.applyFog() end
        if State.jumpOn   then Movement.applyJump() end
        if State.fullBright then Visuals.applyFullBright() end
        if State.timeControl then Visuals.applyTime() end
    end))

    sigs:add("rs", Services.Run.RenderStepped:Connect(function(dt)
        -- SISTEMA TP WALK ADICIONADO PARA BYPASS (NO CLIP / ANTI-CHEAT)
        if State.tpWalkOn and LP.Character then
            local hum = LP.Character:FindFirstChildOfClass("Humanoid")
            local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.MoveDirection.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (State.tpWalkSpeed * dt))
            end
        end

        if State.freecam then
            local dir=Vector3.zero
            local rCF=CFrame.Angles(0,State._camRotY,0)*CFrame.Angles(State._camRotX,0,0)
            local ui=Services.Input
            if ui:IsKeyDown(Enum.KeyCode.W) then dir=dir+rCF.LookVector  end
            if ui:IsKeyDown(Enum.KeyCode.S) then dir=dir-rCF.LookVector  end
            if ui:IsKeyDown(Enum.KeyCode.D) then dir=dir+rCF.RightVector end
            if ui:IsKeyDown(Enum.KeyCode.A) then dir=dir-rCF.RightVector end
            if ui:IsKeyDown(Enum.KeyCode.E) then dir=dir+Vector3.yAxis   end
            if ui:IsKeyDown(Enum.KeyCode.Q) then dir=dir-Vector3.yAxis   end
            State._camPos=State._camPos+dir*(80*dt)
            Camera.CFrame=CFrame.new(State._camPos)*rCF
        end
        if State.fly then
            local root=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dir=Vector3.zero; local cCF=Camera.CFrame; local ui=Services.Input
                if ui:IsKeyDown(Enum.KeyCode.W)           then dir=dir+cCF.LookVector   end
                if ui:IsKeyDown(Enum.KeyCode.S)           then dir=dir-cCF.LookVector   end
                if ui:IsKeyDown(Enum.KeyCode.D)           then dir=dir+cCF.RightVector  end
                if ui:IsKeyDown(Enum.KeyCode.A)           then dir=dir-cCF.RightVector  end
                if ui:IsKeyDown(Enum.KeyCode.Space)       then dir=dir+Vector3.yAxis    end
                if ui:IsKeyDown(Enum.KeyCode.LeftControl) then dir=dir-Vector3.yAxis    end
                if State._flyBV then State._flyBV.Velocity=dir*State.flySpeed end
                if State._flyBG then State._flyBG.CFrame=cCF end
            end
        end
    end))

    sigs:add("mouse", Services.Input.InputChanged:Connect(function(inp)
        if State.freecam and inp.UserInputType==Enum.UserInputType.MouseMovement then
            if Services.Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                State._camRotY=State._camRotY-inp.Delta.X*0.004
                State._camRotX=math.clamp(State._camRotX-inp.Delta.Y*0.004,-math.rad(85),math.rad(85))
                Services.Input.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition
            else Services.Input.MouseBehavior=Enum.MouseBehavior.Default end
        end
    end))

    sigs:add("kbd", Services.Input.InputBegan:Connect(function(inp, processed)
        if State.kbListening and inp.UserInputType==Enum.UserInputType.Keyboard
        and inp.KeyCode ~= Enum.KeyCode.Escape then
            local which = State.kbListening
            State["kb"..which] = inp.KeyCode
            State.kbListening  = nil
            if which=="Fly"   and _kbFlyRef   then _kbFlyRef.Text   = "["..inp.KeyCode.Name.."]" end
            if which=="Speed" and _kbSpeedRef  then _kbSpeedRef.Text = "["..inp.KeyCode.Name.."]" end
            saveData()
            return
        end
        if processed then return end
        if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if inp.KeyCode == State.kbFly then
            State.fly = not State.fly; Movement.setupFly(State.fly)
        elseif inp.KeyCode == State.kbSpeed then
            State.speedOn = not State.speedOn; Movement.applySpeed()
        end
        if State.infJump and inp.KeyCode==Enum.KeyCode.Space and LP.Character then
            local hum=LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end))

    sigs:add("char", LP.CharacterAdded:Connect(function(char)
        local hum=char:WaitForChild("Humanoid",5); if not hum then return end
        sigs:add("wspd", hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if State.speedOn and State.combatPhase=="idle" then hum.WalkSpeed=State.walkSpeed end
        end))
        Movement.applySpeed()
        Movement.applyJump()
        Movement.applyGravity()
        if State.fly then Movement.setupFly(true) end
    end))

    sigs:add("esp", Services.Run.Heartbeat:Connect(function()
        if State.espPlayers or State.espMobs then
            ESP.update()
        end
    end))

    task.spawn(function()
        while true do
            task.wait(55)
            if State.antiAfk then
                pcall(function()
                    if VU then VU:CaptureController() end
                end)
                pcall(function()
                    local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                end)
            end
        end
    end)

    task.spawn(function()
        while true do
            if HttpRequest then pcall(function()
                local lv="?"
                pcall(function()
                    local d=LP:FindFirstChild("Data")
                    if d and d:FindFirstChild("Level") then lv=tostring(d.Level.Value) end
                end)
                HttpRequest({Url=CONFIG.HEARTBEAT_URL, Method="POST",
                    Headers={["Content-Type"]="application/json"},
                    Body=Services.Http:JSONEncode({
                        roblox_id=tostring(LP.UserId), roblox_name=LP.Name,
                        level=lv, using_script=CONFIG.SCRIPT_ID, version=CONFIG.VERSION,
                    })})
            end) end
            task.wait(CONFIG.HEARTBEAT_INTERVAL)
        end
    end)
end

local UI = {}

function UI.tw(o,t,p) Services.Tween:Create(o,TweenInfo.new(t,Enum.EasingStyle.Quint),p):Play() end
function UI.corner(r,p) local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r); return c end
function UI.stroke(col,th,p) local s=Instance.new("UIStroke",p); s.Color=col; s.Thickness=th or 1; return s end
function UI.pad(t,l,r,b,p)
    local pd=Instance.new("UIPadding",p)
    pd.PaddingTop=UDim.new(0,t or 0); pd.PaddingLeft=UDim.new(0,l or 0)
    pd.PaddingRight=UDim.new(0,r or 0); pd.PaddingBottom=UDim.new(0,b or 0)
end
function UI.lbl(pr,parent)
    local l=Instance.new("TextLabel",parent); l.BackgroundTransparency=1
    l.Font=pr.Font or Enum.Font.Gotham; l.TextSize=pr.TextSize or 14
    l.TextColor3=pr.TextColor3 or C.text; l.Text=pr.Text or ""
    l.Size=pr.Size or UDim2.new(1,0,1,0); l.Position=pr.Position or UDim2.new(0,0,0,0)
    l.TextXAlignment=pr.TextXAlignment or Enum.TextXAlignment.Left
    l.TextYAlignment=pr.TextYAlignment or Enum.TextYAlignment.Center
    l.TextWrapped=pr.TextWrapped or false; l.TextTruncate=pr.TextTruncate or Enum.TextTruncate.None
    if pr.Name then l.Name=pr.Name end; return l
end

function UI.scrollPage(parent)
    local sf=Instance.new("ScrollingFrame",parent)
    sf.Size=UDim2.new(1,0,1,0); sf.BackgroundTransparency=1
    sf.ScrollBarThickness=3; sf.ScrollBarImageColor3=C.border
    sf.CanvasSize=UDim2.new(0,0,0,0); sf.AutomaticCanvasSize=Enum.AutomaticSize.Y
    sf.BorderSizePixel=0; sf.Visible=false
    local ul=Instance.new("UIListLayout",sf)
    ul.Padding=UDim.new(0,8); ul.SortOrder=Enum.SortOrder.LayoutOrder
    UI.pad(10,10,10,10,sf); return sf
end

function UI.btn(pr,parent)
    local b=Instance.new("TextButton",parent)
    b.Size=pr.Size or UDim2.new(1,0,0,48); b.Position=pr.Position or UDim2.new(0,0,0,0)
    b.BackgroundColor3=pr.Bg or C.item; b.Text=pr.Text or ""
    b.Font=pr.Font or Enum.Font.GothamSemibold; b.TextSize=pr.TextSize or 14
    b.TextColor3=pr.TextColor3 or C.text; b.AutoButtonColor=false
    b.LayoutOrder=pr.Order or 0; b.TextTruncate=pr.TextTruncate or Enum.TextTruncate.None
    UI.corner(pr.Radius or 10,b)
    if pr.Border then UI.stroke(pr.Border,1,b) end
    local hov=pr.Hover or C.itemH
    b.MouseEnter:Connect(function() UI.tw(b,0.1,{BackgroundColor3=hov}) end)
    b.MouseLeave:Connect(function() UI.tw(b,0.1,{BackgroundColor3=pr.Bg or C.item}) end)
    return b
end

function UI.toggle(page,title,sub,order,cb)
    local h=sub and 52 or 48
    local row=Instance.new("Frame",page); row.Size=UDim2.new(1,0,0,h)
    row.BackgroundColor3=C.item; row.LayoutOrder=order
    UI.corner(10,row); UI.stroke(C.bdr2,1,row)
    UI.lbl({Text=title,Font=Enum.Font.GothamSemibold,TextSize=14,TextColor3=C.text,
        Size=UDim2.new(1,-60,0,22),Position=UDim2.new(0,14,0,sub and 6 or 13)},row)
    if sub then UI.lbl({Text=sub,Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.sub,
        Size=UDim2.new(1,-60,0,14),Position=UDim2.new(0,14,0,28)},row) end
    local tog=Instance.new("TextButton",row)
    tog.Size=UDim2.new(0,44,0,24); tog.Position=UDim2.new(1,-52,0.5,-12)
    tog.BackgroundColor3=Color3.fromRGB(50,50,50); tog.Text=""
    UI.corner(12,tog)
    local dot=Instance.new("Frame",tog); dot.Size=UDim2.new(0,18,0,18)
    dot.Position=UDim2.new(0,3,0.5,-9); dot.BackgroundColor3=C.white; UI.corner(9,dot)
    local isOn=false
    local function set(v)
        isOn=v
        UI.tw(tog,0.15,{BackgroundColor3=v and C.accent or Color3.fromRGB(50,50,50)})
        UI.tw(dot,0.15,{Position=v and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)})
        if cb then cb(v) end
    end
    tog.MouseButton1Click:Connect(function() set(not isOn) end)
    row.MouseEnter:Connect(function() UI.tw(row,0.1,{BackgroundColor3=C.itemH}) end)
    row.MouseLeave:Connect(function() UI.tw(row,0.1,{BackgroundColor3=C.item}) end)
    return set,row
end

function UI.slider(page,title,min_,max_,def,fmt,order,cb)
    local row=Instance.new("Frame",page); row.Size=UDim2.new(1,0,0,60)
    row.BackgroundColor3=C.item; row.LayoutOrder=order
    UI.corner(10,row); UI.stroke(C.bdr2,1,row)
    local valL=UI.lbl({Text=string.format(fmt,def),Font=Enum.Font.GothamBold,TextSize=13,
        TextColor3=C.accent,Size=UDim2.new(0,52,0,20),Position=UDim2.new(1,-56,0,6),
        TextXAlignment=Enum.TextXAlignment.Right},row)
    UI.lbl({Text=title,Font=Enum.Font.GothamSemibold,TextSize=14,TextColor3=C.text,
        Size=UDim2.new(1,-70,0,20),Position=UDim2.new(0,14,0,6)},row)
    local track=Instance.new("Frame",row); track.Size=UDim2.new(1,-28,0,6)
    track.Position=UDim2.new(0,14,0,38); track.BackgroundColor3=Color3.fromRGB(40,60,80)
    UI.corner(3,track)
    local fill=Instance.new("Frame",track); fill.BackgroundColor3=C.accent
    fill.BorderSizePixel=0; UI.corner(3,fill)
    local thumb=Instance.new("Frame",track); thumb.Size=UDim2.new(0,16,0,16)
    thumb.BackgroundColor3=C.white; UI.corner(8,thumb); UI.stroke(C.accent,1.5,thumb)
    local curVal=def; local dragging=false
    local function setVal(px)
        local tw_=track.AbsoluteSize.X
        local pct=math.clamp((px-track.AbsolutePosition.X)/tw_,0,1)
        curVal=math.floor(min_+(max_-min_)*pct)
        fill.Size=UDim2.new(pct,0,1,0); thumb.Position=UDim2.new(pct,0,0.5,-8)
        valL.Text=string.format(fmt,curVal); if cb then cb(curVal) end
    end
    local initP=(def-min_)/(max_-min_)
    fill.Size=UDim2.new(initP,0,1,0); thumb.Position=UDim2.new(initP,0,0.5,-8)
    thumb.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then dragging=true end end)
    track.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then dragging=true; setVal(i.Position.X) end end)
    Services.Input.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
    Services.Input.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement
        or i.UserInputType==Enum.UserInputType.Touch) then setVal(i.Position.X) end end)
    row.MouseEnter:Connect(function() UI.tw(row,0.1,{BackgroundColor3=C.itemH}) end)
    row.MouseLeave:Connect(function() UI.tw(row,0.1,{BackgroundColor3=C.item}) end)
    return row
end

function UI.sec(text,parent,order)
    local f=Instance.new("Frame",parent); f.Size=UDim2.new(1,0,0,26)
    f.BackgroundTransparency=1; f.LayoutOrder=order or 0
    UI.lbl({Text=text,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=C.accent,
        Size=UDim2.new(1,0,1,0),TextXAlignment=Enum.TextXAlignment.Left},f)
    return f
end

function UI.notify(title,msg,col)
    task.spawn(function()
        local pgui=LP:WaitForChild("PlayerGui")
        local sc=pgui:FindFirstChild("NxsNotif")
        if not sc then
            sc=Instance.new("ScreenGui",pgui); sc.Name="NxsNotif"
            sc.ResetOnSpawn=false; sc.DisplayOrder=500
            local bag=Instance.new("Frame",sc); bag.Name="Bag"
            bag.Size=UDim2.new(0,270,1,-10); bag.Position=UDim2.new(1,-278,0,5)
            bag.BackgroundTransparency=1
            local ul=Instance.new("UIListLayout",bag); ul.Padding=UDim.new(0,5)
            ul.SortOrder=Enum.SortOrder.LayoutOrder; ul.VerticalAlignment=Enum.VerticalAlignment.Top
        end
        local bag=sc:FindFirstChild("Bag"); if not bag then return end
        local n=Instance.new("Frame",bag); n.Size=UDim2.new(1,0,0,56)
        n.BackgroundColor3=C.dark1; n.ClipsDescendants=true
        UI.corner(10,n); UI.stroke(col or C.accent,1,n)
        local bar=Instance.new("Frame",n); bar.Size=UDim2.new(0,3,1,-8)
        bar.Position=UDim2.new(0,4,0,4); bar.BackgroundColor3=col or C.accent; UI.corner(2,bar)
        UI.lbl({Text=title,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=C.white,
            Size=UDim2.new(1,-18,0,18),Position=UDim2.new(0,14,0,5)},n)
        UI.lbl({Text=msg,Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.sub,
            Size=UDim2.new(1,-18,0,16),Position=UDim2.new(0,14,0,24)},n)
        n.Position=UDim2.new(1,0,0,0); UI.tw(n,0.25,{Position=UDim2.new(0,0,0,0)})
        task.wait(3.5); UI.tw(n,0.25,{Position=UDim2.new(1,0,0,0)})
        task.wait(0.3); pcall(function() n:Destroy() end)
    end)
end

local function makeDraggable(handle,target)
    local dragging,dragStart,startPos=false,nil,nil
    handle.InputBegan:Connect(function(inp)
        local t=inp.UserInputType
        if t~=Enum.UserInputType.MouseButton1 and t~=Enum.UserInputType.Touch then return end
        dragging=true; dragStart=inp.Position; startPos=target.Position
        inp.Changed:Connect(function()
            if inp.UserInputState==Enum.UserInputState.End then dragging=false end
        end)
    end)
    Services.Input.InputChanged:Connect(function(inp)
        if not dragging then return end
        local t=inp.UserInputType
        if t~=Enum.UserInputType.MouseMovement and t~=Enum.UserInputType.Touch then return end
        local d=inp.Position-dragStart
        target.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,
                                   startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end)
end

local function makeScrollList(parent, h)
    local sf=Instance.new("ScrollingFrame",parent)
    sf.Size=UDim2.new(1,0,0,h); sf.BackgroundColor3=C.dark1
    sf.ScrollBarThickness=3; sf.ScrollBarImageColor3=C.border
    sf.CanvasSize=UDim2.new(0,0,0,0); sf.AutomaticCanvasSize=Enum.AutomaticSize.Y
    sf.BorderSizePixel=0
    UI.corner(10,sf); UI.stroke(C.border,1,sf)
    local ul=Instance.new("UIListLayout",sf)
    ul.Padding=UDim.new(0,4); ul.SortOrder=Enum.SortOrder.LayoutOrder
    UI.pad(4,4,4,4,sf)
    return sf,ul
end

local function makeInputRow(parent,order,placeholder,btnText,btnColor)
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,48); row.BackgroundTransparency=1; row.LayoutOrder=order
    local rl=Instance.new("UIListLayout",row)
    rl.FillDirection=Enum.FillDirection.Horizontal; rl.Padding=UDim.new(0,8)
    rl.SortOrder=Enum.SortOrder.LayoutOrder
    local box=Instance.new("TextBox",row)
    box.Size=UDim2.new(0.62,-4,1,0); box.LayoutOrder=1
    box.BackgroundColor3=C.dark2; box.TextColor3=C.white
    box.Font=Enum.Font.Gotham; box.TextSize=13
    box.PlaceholderColor3=C.sub; box.PlaceholderText=placeholder
    box.Text=""; box.ClearTextOnFocus=false
    UI.corner(10,box); UI.stroke(C.bdr2,1,box)
    local btn=UI.btn({Size=UDim2.new(0.36,0,1,0),Text=btnText,
        Bg=btnColor or C.accent,TextColor3=C.white,Hover=C.acc2,Radius=10,Order=2},row)
    btn.Font=Enum.Font.GothamBold
    return row,box,btn
end

local function CreateUI(sigs)
    local pgui=LP:WaitForChild("PlayerGui")
    if pgui:FindFirstChild("NexusUniversal") then pgui.NexusUniversal:Destroy() end

    local sc=Instance.new("ScreenGui",pgui)
    sc.Name="NexusUniversal"; sc.ResetOnSpawn=false
    sc.DisplayOrder=10; sc.ZIndexBehavior=Enum.ZIndexBehavior.Sibling

    local TOP_H=46; local NAV_H=64; local WIN_W=410

    local win=Instance.new("Frame",sc)
    win.Size=UDim2.new(0,WIN_W,0,580); win.Position=UDim2.new(0.5,-WIN_W/2,0.5,-290)
    win.BackgroundColor3=C.bg; win.BorderSizePixel=0; win.ClipsDescendants=true
    UI.corner(14,win); UI.stroke(C.border,1,win)
    win.BackgroundTransparency=1; UI.tw(win,0.25,{BackgroundTransparency=0})

    local topBar=Instance.new("Frame",win)
    topBar.Size=UDim2.new(1,0,0,TOP_H); topBar.BackgroundColor3=C.nav; topBar.BorderSizePixel=0
    makeDraggable(topBar,win)
    UI.lbl({Text="⚡ "..CONFIG.BRAND.."  "..CONFIG.VERSION,
        Font=Enum.Font.GothamBold,TextSize=14,TextColor3=C.accent,
        Size=UDim2.new(1,-90,1,0),Position=UDim2.new(0,12,0,0)},topBar)

    local function hdrBtn(txt,xOff,hCol)
        local b=Instance.new("TextButton",topBar)
        b.Size=UDim2.new(0,38,0,36); b.Position=UDim2.new(1,xOff,0.5,-18)
        b.BackgroundTransparency=1; b.Text=txt
        b.Font=Enum.Font.GothamBold; b.TextSize=16; b.TextColor3=C.sub
        b.MouseEnter:Connect(function() b.TextColor3=hCol end)
        b.MouseLeave:Connect(function() b.TextColor3=C.sub end)
        return b
    end
    local minBtn=hdrBtn("—",-78,C.accent); local closeBtn=hdrBtn("✕",-38,C.red)
    closeBtn.MouseButton1Click:Connect(function()
        Movement.resetAll(); Combat.stop(sigs); WP.stop(); ESP.clearAll(); sigs:clear()
        UI.tw(win,0.2,{BackgroundTransparency=1}); task.wait(0.22); sc:Destroy()
    end)

    local sep=Instance.new("Frame",win)
    sep.Size=UDim2.new(1,0,0,1); sep.Position=UDim2.new(0,0,0,TOP_H)
    sep.BackgroundColor3=C.border; sep.BorderSizePixel=0

    local contentH=580-TOP_H-1-NAV_H
    local contentArea=Instance.new("Frame",win)
    contentArea.Size=UDim2.new(1,0,0,contentH); contentArea.Position=UDim2.new(0,0,0,TOP_H+1)
    contentArea.BackgroundTransparency=1; contentArea.ClipsDescendants=true

    local navSep=Instance.new("Frame",win); navSep.Size=UDim2.new(1,0,0,1)
    navSep.Position=UDim2.new(0,0,1,-(NAV_H+1)); navSep.BackgroundColor3=C.border; navSep.BorderSizePixel=0
    local navBar=Instance.new("Frame",win); navBar.Size=UDim2.new(1,0,0,NAV_H)
    navBar.Position=UDim2.new(0,0,1,-NAV_H); navBar.BackgroundColor3=C.nav; navBar.BorderSizePixel=0

    local TABS={
        {id="movement",icon="🏃",label="Mover"},
        {id="combat",  icon="⚔️", label="Combate"},
        {id="teleport",icon="🌍",label="Teleport"},
        {id="routes",  icon="🗺️", label="Rotas"},
        {id="mobs",    icon="🔍",label="Mobs"},
        {id="chests",  icon="📦",label="Baús"},
        {id="visual",  icon="✨",label="Visual"},
        {id="misc",    icon="⚙️", label="Misc"},
    }

    local navLayout=Instance.new("UIListLayout",navBar)
    navLayout.FillDirection=Enum.FillDirection.Horizontal
    navLayout.SortOrder=Enum.SortOrder.LayoutOrder
    navLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center

    local tabBtns={}; local tabPages={}; local activeTab=nil

    local function selectTab(id)
        if activeTab==id then return end; activeTab=id
        for tid,btn in pairs(tabBtns) do
            local sel=(tid==id)
            local il=btn:FindFirstChild("IL"); if il then il.TextColor3=sel and C.accent or C.sub end
            local nl=btn:FindFirstChild("NL"); if nl then nl.TextColor3=sel and C.accent or C.sub end
            local ab=btn:FindFirstChild("AB"); if ab then ab.BackgroundTransparency=sel and 0 or 1 end
        end
        for tid,page in pairs(tabPages) do page.Visible=(tid==id) end
    end

    for i,tab in ipairs(TABS) do
        local nb=Instance.new("TextButton",navBar)
        nb.Size=UDim2.new(1/#TABS,0,1,0); nb.BackgroundTransparency=1
        nb.Text=""; nb.AutoButtonColor=false; nb.LayoutOrder=i
        local ab=Instance.new("Frame",nb); ab.Name="AB"
        ab.Size=UDim2.new(0.6,0,0,2); ab.Position=UDim2.new(0.2,0,0,0)
        ab.BackgroundColor3=C.accent; ab.BackgroundTransparency=1; ab.BorderSizePixel=0
        local il=UI.lbl({Text=tab.icon,Font=Enum.Font.GothamBold,TextSize=18,TextColor3=C.sub,
            Size=UDim2.new(1,0,0,26),Position=UDim2.new(0,0,0,8),
            TextXAlignment=Enum.TextXAlignment.Center},nb); il.Name="IL"
        local nl=UI.lbl({Text=tab.label,Font=Enum.Font.Gotham,TextSize=9,TextColor3=C.sub,
            Size=UDim2.new(1,0,0,14),Position=UDim2.new(0,0,0,36),
            TextXAlignment=Enum.TextXAlignment.Center},nb); nl.Name="NL"
        nb.MouseButton1Click:Connect(function() selectTab(tab.id) end)
        tabBtns[tab.id]=nb
        local page=UI.scrollPage(contentArea); tabPages[tab.id]=page
    end

    local mvP=tabPages["movement"]
    UI.toggle(mvP,"Pulo Infinito","Pulos ilimitados",1,function(v)
        State.infJump=v; UI.notify("Pulo Infinito",v and "Ativado" or "Desativado",v and C.green or C.red) end)
    UI.toggle(mvP,"No-Clip","Atravessa paredes",2,function(v)
        State.noclip=v; UI.notify("No-Clip",v and "Ativado" or "Desativado",v and C.green or C.red) end)
    
    -- IMPLEMENTAÇÃO DO FEEDBACK DO USUÁRIO NO DISCORD 
    UI.toggle(mvP,"CFrame Walk (TP)","Pequenos TPs pra frente (Bypass/Noclip)",3,function(v)
        State.tpWalkOn=v; UI.notify("CFrame Walk",v and "Ativado" or "Desativado",v and C.green or C.red) end)
    UI.slider(mvP,"Velocidade CFrame",10,150,30,"%d",4,function(v) State.tpWalkSpeed=v end)

    UI.toggle(mvP,"Speed Boost","Velocidade de Humanoid",5,function(v)
        State.speedOn=v; Movement.applySpeed()
        UI.notify("Speed",v and "Ativado ("..State.walkSpeed..")" or "Desativado",v and C.green or C.red) end)
    UI.slider(mvP,"Velocidade de Caminhada",8,100,24,"%d studs/s",6,function(v)
        State.walkSpeed=v; Movement.applySpeed() end)
    UI.toggle(mvP,"Freecam","Câmera livre (RMB+WASD)",7,function(v)
        State.freecam=v
        if v then State._camPos=Camera.CFrame.Position; Camera.CameraType=Enum.CameraType.Scriptable
        else Camera.CameraType=Enum.CameraType.Custom; Services.Input.MouseBehavior=Enum.MouseBehavior.Default end
        UI.notify("Freecam",v and "Ativado" or "Desativado",v and C.green or C.red) end)
    UI.toggle(mvP,"Voar","Voo livre (WASD+Espaço/Ctrl)",8,function(v)
        State.fly=v; Movement.setupFly(v)
        UI.notify("Voar",v and "Ativado" or "Desativado",v and C.green or C.red) end)
    UI.slider(mvP,"Velocidade de Voo",20,300,60,"%d studs/s",9,function(v) State.flySpeed=v end)

    UI.sec("── Salto & Gravidade",mvP,10)
    UI.toggle(mvP,"Jump Power Boost","Altura de salto customizada",11,function(v)
        State.jumpOn=v; Movement.applyJump()
        UI.notify("Jump Power",v and "Ativado" or "Padrão",v and C.green or C.orange) end)
    UI.slider(mvP,"Altura de Salto",50,500,75,"%d power",12,function(v)
        State.jumpPower=v; if State.jumpOn then Movement.applyJump() end end)
    UI.toggle(mvP,"Gravidade Reduzida","Workspace.Gravity personalizado",13,function(v)
        State.gravityOn=v; Movement.applyGravity()
        UI.notify("Gravidade",v and "Reduzida" or "Normal",v and C.green or C.orange) end)
    UI.slider(mvP,"Gravidade",10,196,100,"%d",14,function(v)
        State.gravity=v; if State.gravityOn then Movement.applyGravity() end end)

    UI.sec("── Keybinds",mvP,15)
    local function makeKeybindRow(page,order,label,which,stateKey)
        local row=Instance.new("Frame",page); row.Size=UDim2.new(1,0,0,48)
        row.BackgroundColor3=C.item; row.LayoutOrder=order
        UI.corner(10,row); UI.stroke(C.bdr2,1,row)
        UI.lbl({Text=label,Font=Enum.Font.GothamSemibold,TextSize=14,TextColor3=C.text,
            Size=UDim2.new(1,-110,1,0),Position=UDim2.new(0,14,0,0)},row)
        local keyLbl=UI.lbl({Text="["..State[stateKey].Name.."]",
            Font=Enum.Font.GothamBold,TextSize=13,TextColor3=C.accent,
            Size=UDim2.new(0,60,1,0),Position=UDim2.new(1,-120,0,0),
            TextXAlignment=Enum.TextXAlignment.Right},row)
        if which=="Fly"   then _kbFlyRef   = keyLbl end
        if which=="Speed" then _kbSpeedRef = keyLbl end
        local bindBtn=UI.btn({Size=UDim2.new(0,52,0,32),Text="Bind",
            Bg=C.dark2,TextColor3=C.sub,Hover=C.itemH,Radius=8},row)
        bindBtn.Position=UDim2.new(1,-60,0.5,-16); bindBtn.Font=Enum.Font.GothamBold; bindBtn.TextSize=12
        bindBtn.MouseButton1Click:Connect(function()
            if State.kbListening==which then
                State.kbListening=nil; bindBtn.Text="Bind"; bindBtn.BackgroundColor3=C.dark2
            else
                State.kbListening=which; bindBtn.Text="..."; bindBtn.BackgroundColor3=C.orange
                UI.notify("Keybind","Pressione uma tecla para ["..label.."]",C.orange)
            end
        end)
        row.MouseEnter:Connect(function() UI.tw(row,0.1,{BackgroundColor3=C.itemH}) end)
        row.MouseLeave:Connect(function() UI.tw(row,0.1,{BackgroundColor3=C.item}) end)
        return keyLbl
    end
    makeKeybindRow(mvP,16,"Toggle Voar","Fly","kbFly")
    makeKeybindRow(mvP,17,"Toggle Speed","Speed","kbSpeed")

    local cbP=tabPages["combat"]
    local statusRow=Instance.new("Frame",cbP); statusRow.Size=UDim2.new(1,0,0,36)
    statusRow.BackgroundColor3=C.dark1; statusRow.LayoutOrder=1
    UI.corner(10,statusRow); UI.stroke(C.border,1,statusRow)
    local statusLbl=UI.lbl({Text="Nenhum alvo selecionado",Font=Enum.Font.Gotham,
        TextSize=13,TextColor3=C.sub,Size=UDim2.new(1,-12,1,0),Position=UDim2.new(0,10,0,0)},statusRow)

    local ctrlRow=Instance.new("Frame",cbP); ctrlRow.Size=UDim2.new(1,0,0,48)
    ctrlRow.BackgroundTransparency=1; ctrlRow.LayoutOrder=2
    local ctrlL=Instance.new("UIListLayout",ctrlRow); ctrlL.FillDirection=Enum.FillDirection.Horizontal
    ctrlL.Padding=UDim.new(0,8); ctrlL.SortOrder=Enum.SortOrder.LayoutOrder
    local scanBtn=UI.btn({Size=UDim2.new(0.47,0,1,0),Text="🔍 Escanear",
        Bg=C.item,Border=C.bdr2,Order=1},ctrlRow)
    local atkBtn=UI.btn({Size=UDim2.new(0.47,0,1,0),Text="⚔️ Atacar: OFF",
        Bg=C.dimred,TextColor3=C.sub,Border=Color3.fromRGB(60,30,30),
        Hover=Color3.fromRGB(70,20,20),Order=2},ctrlRow)
    UI.slider(cbP,"Alcance de Ataque",2,40,8,"%d studs",3,function(v) State.attackRange=v end)
    UI.slider(cbP,"Distância de Recuo",1,20,4,"%d studs",4,function(v) State.retreatRange=v end)

    UI.sec("Alvo Manual",cbP,5)
    local _,manBox,setTgtBtn=makeInputRow(cbP,6,"Nome exato do mob","Definir",C.accent)
    setTgtBtn.MouseButton1Click:Connect(function()
        local name=manBox.Text:match("^%s*(.-)%s*$")
        if name~="" then
            State.targetName=name; statusLbl.Text="Alvo manual: "..name
            statusLbl.TextColor3=C.accent; UI.notify("Combate","Alvo: "..name,C.accent)
        end
    end)
    manBox.FocusLost:Connect(function(e)
        if e then local n=manBox.Text:match("^%s*(.-)%s*$")
            if n~="" then State.targetName=n; statusLbl.Text="Alvo manual: "..n; statusLbl.TextColor3=C.accent end
        end
    end)

    UI.sec("Mobs Encontrados",cbP,7)
    local listBg=Instance.new("Frame",cbP); listBg.Size=UDim2.new(1,0,0,185)
    listBg.BackgroundColor3=C.dark1; listBg.LayoutOrder=8
    UI.corner(10,listBg); UI.stroke(C.border,1,listBg)
    local listFrame=Instance.new("ScrollingFrame",listBg)
    listFrame.Size=UDim2.new(1,-4,1,-4); listFrame.Position=UDim2.new(0,2,0,2)
    listFrame.BackgroundTransparency=1; listFrame.ScrollBarThickness=3
    listFrame.ScrollBarImageColor3=C.border; listFrame.CanvasSize=UDim2.new(0,0,0,0)
    listFrame.AutomaticCanvasSize=Enum.AutomaticSize.Y; listFrame.BorderSizePixel=0
    local ll=Instance.new("UIListLayout",listFrame); ll.Padding=UDim.new(0,4); ll.SortOrder=Enum.SortOrder.LayoutOrder
    UI.pad(4,4,4,4,listFrame)
    local emptyLbl=UI.lbl({Text="Nenhum mob. Toque em Escanear.",Font=Enum.Font.Gotham,
        TextSize=13,TextColor3=C.sub,Size=UDim2.new(1,0,0,40),
        TextXAlignment=Enum.TextXAlignment.Center,TextWrapped=true},listFrame)
    local selectedRow=nil

    local function rebuildMobList()
        for _,ch in ipairs(listFrame:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
        State._scanCache=nil; State.targetName=nil
        atkBtn.Text="⚔️ Atacar: OFF"; atkBtn.BackgroundColor3=C.dimred; atkBtn.TextColor3=C.sub
        statusLbl.Text="Nenhum alvo selecionado"; statusLbl.TextColor3=C.sub; selectedRow=nil
        local mobs=scanTargets(State.forceScanMode)
        emptyLbl.Visible=(#mobs==0); if #mobs==0 then return end
        local nameCount,seen2={},{}
        for _,m in ipairs(mobs) do nameCount[m.name]=(nameCount[m.name] or 0)+1 end
        local idx=0
        for _,mob in ipairs(mobs) do
            if not seen2[mob.name] then
                seen2[mob.name]=true; idx=idx+1; local cnt=nameCount[mob.name]
                local row=Instance.new("TextButton",listFrame)
                row.Size=UDim2.new(1,0,0,44); row.BackgroundColor3=C.item
                row.Text=""; row.AutoButtonColor=false; row.LayoutOrder=idx; UI.corner(8,row)
                local selBar=Instance.new("Frame",row); selBar.Name="SB"
                selBar.Size=UDim2.new(0,3,0.7,0); selBar.Position=UDim2.new(0,0,0.15,0)
                selBar.BackgroundColor3=C.accent; selBar.BackgroundTransparency=1; selBar.BorderSizePixel=0
                UI.corner(2,selBar)
                UI.lbl({Text=mob.name..(cnt>1 and "  ×"..cnt or ""),Font=Enum.Font.GothamSemibold,
                    TextSize=13,TextColor3=C.text,Size=UDim2.new(1,-90,0,20),Position=UDim2.new(0,12,0,4),
                    TextTruncate=Enum.TextTruncate.AtEnd},row)
                UI.lbl({Text="❤️ "..mob.hp.."/"..mob.maxhp,Font=Enum.Font.Gotham,TextSize=11,
                    TextColor3=C.sub,Size=UDim2.new(1,-90,0,14),Position=UDim2.new(0,12,0,24)},row)
                local badge=Instance.new("Frame",row); badge.Size=UDim2.new(0,54,0,26)
                badge.Position=UDim2.new(1,-60,0.5,-13); badge.BackgroundColor3=Color3.fromRGB(30,50,70)
                badge.BorderSizePixel=0; UI.corner(8,badge)
                UI.lbl({Text=math.floor(mob.dist).."m",Font=Enum.Font.GothamBold,TextSize=11,
                    TextColor3=C.acc2,Size=UDim2.new(1,0,1,0),TextXAlignment=Enum.TextXAlignment.Center},badge)
                local mn=mob.name
                row.MouseEnter:Connect(function() if selectedRow~=row then UI.tw(row,0.1,{BackgroundColor3=C.itemH}) end end)
                row.MouseLeave:Connect(function() if selectedRow~=row then UI.tw(row,0.1,{BackgroundColor3=C.item}) end end)
                row.MouseButton1Click:Connect(function()
                    if selectedRow and selectedRow~=row then
                        UI.tw(selectedRow,0.1,{BackgroundColor3=C.item})
                        local sb=selectedRow:FindFirstChild("SB"); if sb then sb.BackgroundTransparency=1 end
                    end
                    selectedRow=row; UI.tw(row,0.1,{BackgroundColor3=Color3.fromRGB(28,48,60)})
                    local sb=row:FindFirstChild("SB"); if sb then sb.BackgroundTransparency=0 end
                    State.targetName=mn
                    statusLbl.Text="Alvo: "..mn.." ("..(nameCount[mn] or 1).." vivos)"
                    statusLbl.TextColor3=C.accent; UI.notify("Combate","Alvo: "..mn,C.accent)
                end)
            end
        end
    end

    scanBtn.MouseButton1Click:Connect(function()
        scanBtn.Text="⏳ Escaneando..."
        task.defer(function()
            rebuildMobList()
            local n=scanTargets(State.forceScanMode)
            scanBtn.Text="🔍 Escanear ("..#n..")"
        end)
    end)

    atkBtn.MouseButton1Click:Connect(function()
        if not State.targetName then UI.notify("Combate","Selecione um alvo!",C.red); return end
        local active=State.combatPhase~="idle"
        if active then
            Combat.stop(sigs); atkBtn.Text="⚔️ Atacar: OFF"
            atkBtn.BackgroundColor3=C.dimred; atkBtn.TextColor3=C.sub
            UI.notify("Combate","Ataque parado.",C.orange)
        else
            State.combatPhase="hunting"; atkBtn.Text="⚔️ Atacar: ON"
            atkBtn.BackgroundColor3=C.dimgrn; atkBtn.TextColor3=C.accent
            Combat.startLoop(statusLbl,sigs); UI.notify("Combate","Caçando: "..State.targetName,C.green)
        end
    end)

    local tpP=tabPages["teleport"]
    local tpInputFrame=Instance.new("Frame",tpP); tpInputFrame.Size=UDim2.new(1,0,0,56)
    tpInputFrame.BackgroundColor3=C.item; tpInputFrame.LayoutOrder=1
    UI.corner(10,tpInputFrame); UI.stroke(C.bdr2,1,tpInputFrame)
    local coordInput=Instance.new("TextBox",tpInputFrame)
    coordInput.Size=UDim2.new(1,-120,0,38); coordInput.Position=UDim2.new(0,8,0.5,-19)
    coordInput.BackgroundColor3=C.dark2; coordInput.TextColor3=C.white
    coordInput.Font=Enum.Font.Gotham; coordInput.TextSize=13
    coordInput.PlaceholderColor3=C.sub; coordInput.PlaceholderText="X, Y, Z  (ex: 1040, 16, 4430)"
    coordInput.Text=""; coordInput.ClearTextOnFocus=false; UI.corner(8,coordInput)
    local tpBtn=UI.btn({Size=UDim2.new(0,100,0,38),Text="TELEPORT",
        Bg=C.accent,TextColor3=C.white,Hover=C.acc2,Radius=8},tpInputFrame)
    tpBtn.Position=UDim2.new(1,-108,0.5,-19); tpBtn.Font=Enum.Font.GothamBold; tpBtn.TextSize=12
    tpBtn.MouseButton1Click:Connect(function()
        local ok=teleportTo(coordInput.Text)
        UI.notify("Teleport",ok and "Teletransportado!" or "Coordenadas inválidas",ok and C.accent or C.red)
    end)
    coordInput.FocusLost:Connect(function(e) if e then teleportTo(coordInput.Text) end end)

    local copyBtn=UI.btn({Size=UDim2.new(1,0,0,48),Text="📍 Copiar Minha Posição",
        Bg=C.item,Border=C.bdr2,Order=2},tpP)
    copyBtn.MouseButton1Click:Connect(function()
        local root=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local coord=string.format("%.0f, %.0f, %.0f",root.Position.X,root.Position.Y,root.Position.Z)
            coordInput.Text=coord; safeClipboard(coord)
            UI.notify("Teleport","Copiado: "..coord,C.accent)
        else UI.notify("Teleport","Personagem não encontrado",C.red) end
    end)

    local saveBtn=UI.btn({Size=UDim2.new(1,0,0,48),Text="💾 Salvar Localização Atual",
        Bg=C.item,Border=C.bdr2,Order=3},tpP)
    UI.sec("Localizações Salvas",tpP,4)
    local destSF,_=makeScrollList(tpP,130); destSF.LayoutOrder=5

    local function refreshDests()
        for _,ch in ipairs(destSF:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
        if #State.savedDests==0 then
            local ef=Instance.new("Frame",destSF); ef.Size=UDim2.new(1,0,0,34)
            ef.BackgroundTransparency=1; ef.LayoutOrder=0
            UI.lbl({Text="Nenhuma localização salva.",Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.sub,
                Size=UDim2.new(1,0,1,0),TextXAlignment=Enum.TextXAlignment.Center},ef); return
        end
        for idx,entry in ipairs(State.savedDests) do
            local row=Instance.new("Frame",destSF); row.Size=UDim2.new(1,0,0,44)
            row.BackgroundColor3=C.item; row.LayoutOrder=idx; UI.corner(8,row); UI.stroke(C.bdr2,1,row)
            local go=Instance.new("TextButton",row); go.Size=UDim2.new(1,-44,1,0)
            go.BackgroundTransparency=1; go.Text=""; go.AutoButtonColor=false
            UI.lbl({Text=entry.name,Font=Enum.Font.GothamSemibold,TextSize=13,TextColor3=C.text,
                Size=UDim2.new(1,0,0,20),Position=UDim2.new(0,10,0,3),TextTruncate=Enum.TextTruncate.AtEnd},go)
            UI.lbl({Text=entry.coord,Font=Enum.Font.Gotham,TextSize=10,TextColor3=C.sub,
                Size=UDim2.new(1,0,0,14),Position=UDim2.new(0,10,0,23)},go)
            go.MouseButton1Click:Connect(function() teleportTo(entry.coord); UI.notify("Teleport","→ "..entry.name,C.accent) end)
            go.MouseEnter:Connect(function() UI.tw(row,0.1,{BackgroundColor3=C.itemH}) end)
            go.MouseLeave:Connect(function() UI.tw(row,0.1,{BackgroundColor3=C.item}) end)
            local del=Instance.new("TextButton",row); del.Size=UDim2.new(0,36,0,36)
            del.Position=UDim2.new(1,-40,0.5,-18); del.BackgroundColor3=C.dimred
            del.Text="✕"; del.Font=Enum.Font.GothamBold; del.TextSize=14; del.TextColor3=C.white
            del.AutoButtonColor=false; UI.corner(8,del)
            local ci=idx
            del.MouseButton1Click:Connect(function() table.remove(State.savedDests,ci); saveData(); refreshDests() end)
        end
    end

    local function showSavePopup()
        local root=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not root then UI.notify("Teleport","Personagem não encontrado",C.red); return end
        local coord=string.format("%.0f, %.0f, %.0f",root.Position.X,root.Position.Y,root.Position.Z)
        local overlay=Instance.new("Frame",sc); overlay.Size=UDim2.new(1,0,1,0)
        overlay.BackgroundColor3=Color3.new(0,0,0); overlay.BackgroundTransparency=0.45
        overlay.ZIndex=100; overlay.Active=true
        local dlg=Instance.new("Frame",overlay); dlg.Size=UDim2.new(0,300,0,130)
        dlg.Position=UDim2.new(0.5,-150,0.5,-65); dlg.BackgroundColor3=C.bg; dlg.BorderSizePixel=0; dlg.ZIndex=101
        UI.corner(12,dlg); UI.stroke(C.accent,1.5,dlg)
        UI.lbl({Text="Nome da Localização",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=C.accent,
            Size=UDim2.new(1,-20,0,22),Position=UDim2.new(0,12,0,10),
            TextXAlignment=Enum.TextXAlignment.Left},dlg).ZIndex=101
        local inp=Instance.new("TextBox",dlg); inp.Size=UDim2.new(1,-24,0,38); inp.Position=UDim2.new(0,12,0,38)
        inp.BackgroundColor3=C.dark2; inp.TextColor3=C.white; inp.Font=Enum.Font.Gotham; inp.TextSize=14
        inp.PlaceholderColor3=C.sub; inp.PlaceholderText="ex: Spawn, Farm..."; inp.Text=""; inp.ZIndex=101
        UI.corner(8,inp); task.defer(function() inp:CaptureFocus() end)
        local function closePop() overlay:Destroy() end
        local function confirmSave()
            local name=inp.Text:match("^%s*(.-)%s*$")
            if name=="" then name="Local "..(#State.savedDests+1) end
            table.insert(State.savedDests,{name=name,coord=coord}); saveData(); refreshDests()
            UI.notify("Teleport","Salvo: "..name,C.accent); closePop()
        end
        local cfm=Instance.new("TextButton",dlg); cfm.Size=UDim2.new(0,90,0,34); cfm.Position=UDim2.new(0,12,0,88)
        cfm.BackgroundColor3=C.accent; cfm.Text="Salvar"; cfm.Font=Enum.Font.GothamBold; cfm.TextSize=13
        cfm.TextColor3=C.white; cfm.ZIndex=101; UI.corner(8,cfm); cfm.MouseButton1Click:Connect(confirmSave)
        local can=Instance.new("TextButton",dlg); can.Size=UDim2.new(0,90,0,34); can.Position=UDim2.new(0,110,0,88)
        can.BackgroundColor3=C.dimred; can.Text="Cancelar"; can.Font=Enum.Font.GothamBold; can.TextSize=13
        can.TextColor3=C.white; can.ZIndex=101; UI.corner(8,can); can.MouseButton1Click:Connect(closePop)
        inp.FocusLost:Connect(function(e) if e then confirmSave() end end)
    end
    saveBtn.MouseButton1Click:Connect(showSavePopup)
    UI.btn({Size=UDim2.new(1,0,0,44),Text="🗑️ Limpar Localizações",Bg=C.dimred,TextColor3=C.white,
        Border=Color3.fromRGB(60,30,30),Hover=Color3.fromRGB(70,20,20),Order=6},tpP).MouseButton1Click:Connect(function()
        State.savedDests={}; saveData(); refreshDests(); UI.notify("Teleport","Limpas",C.orange) end)

    local rtP=tabPages["routes"]
    local rtStatusRow=Instance.new("Frame",rtP); rtStatusRow.Size=UDim2.new(1,0,0,36)
    rtStatusRow.BackgroundColor3=C.dark1; rtStatusRow.LayoutOrder=1
    UI.corner(10,rtStatusRow); UI.stroke(C.border,1,rtStatusRow)
    local rtStatusLbl=UI.lbl({Text="⏹  Circuito parado.",Font=Enum.Font.Gotham,
        TextSize=13,TextColor3=C.sub,Size=UDim2.new(1,-12,1,0),Position=UDim2.new(0,10,0,0)},rtStatusRow)

    local rtCtrl=Instance.new("Frame",rtP); rtCtrl.Size=UDim2.new(1,0,0,48)
    rtCtrl.BackgroundTransparency=1; rtCtrl.LayoutOrder=2
    local rtCtrlL=Instance.new("UIListLayout",rtCtrl); rtCtrlL.FillDirection=Enum.FillDirection.Horizontal
    rtCtrlL.Padding=UDim.new(0,8); rtCtrlL.SortOrder=Enum.SortOrder.LayoutOrder
    local startBtn=UI.btn({Size=UDim2.new(0.47,0,1,0),Text="▶ Iniciar",
        Bg=C.dimgrn,TextColor3=C.green,Hover=Color3.fromRGB(20,70,30),Order=1},rtCtrl)
    startBtn.Font=Enum.Font.GothamBold
    local stopBtn=UI.btn({Size=UDim2.new(0.47,0,1,0),Text="⏹ Parar",
        Bg=C.dimred,TextColor3=C.sub,Border=Color3.fromRGB(60,30,30),
        Hover=Color3.fromRGB(70,20,20),Order=2},rtCtrl)
    stopBtn.Font=Enum.Font.GothamBold

    local rtMidRow=Instance.new("Frame",rtP); rtMidRow.Size=UDim2.new(1,0,0,48)
    rtMidRow.BackgroundTransparency=1; rtMidRow.LayoutOrder=3
    local rtMidL=Instance.new("UIListLayout",rtMidRow); rtMidL.FillDirection=Enum.FillDirection.Horizontal
    rtMidL.Padding=UDim.new(0,8); rtMidL.SortOrder=Enum.SortOrder.LayoutOrder

    local loopRow=Instance.new("Frame",rtMidRow); loopRow.Size=UDim2.new(0.47,0,1,0)
    loopRow.BackgroundColor3=C.item; loopRow.LayoutOrder=1; UI.corner(10,loopRow); UI.stroke(C.bdr2,1,loopRow)
    UI.lbl({Text="Loop",Font=Enum.Font.GothamSemibold,TextSize=13,TextColor3=C.text,
        Size=UDim2.new(1,-52,1,0),Position=UDim2.new(0,12,0,0)},loopRow)
    local loopTog=Instance.new("TextButton",loopRow); loopTog.Size=UDim2.new(0,44,0,24)
    loopTog.Position=UDim2.new(1,-50,0.5,-12); loopTog.BackgroundColor3=C.accent; loopTog.Text=""
    UI.corner(12,loopTog)
    local loopDot=Instance.new("Frame",loopTog); loopDot.Size=UDim2.new(0,18,0,18)
    loopDot.Position=UDim2.new(1,-21,0.5,-9); loopDot.BackgroundColor3=C.white; UI.corner(9,loopDot)
    State.circuitLoop=true  
    loopTog.MouseButton1Click:Connect(function()
        State.circuitLoop=not State.circuitLoop
        UI.tw(loopTog,0.15,{BackgroundColor3=State.circuitLoop and C.accent or Color3.fromRGB(50,50,50)})
        UI.tw(loopDot,0.15,{Position=State.circuitLoop and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)})
    end)

    local addWpBtn=UI.btn({Size=UDim2.new(0.47,0,1,0),Text="📍 Adicionar Ponto",
        Bg=C.item,Border=C.bdr2,Order=2},rtMidRow)
    addWpBtn.Font=Enum.Font.GothamSemibold; addWpBtn.TextSize=12

    UI.sec("Pontos do Circuito",rtP,4)
    local wpSF,_=makeScrollList(rtP,210); wpSF.LayoutOrder=5

    local function refreshWP()
        for _,ch in ipairs(wpSF:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
        if #State.waypoints==0 then
            local ef=Instance.new("Frame",wpSF); ef.Size=UDim2.new(1,0,0,36)
            ef.BackgroundTransparency=1; ef.LayoutOrder=0
            UI.lbl({Text="Nenhum ponto. Caminhe até o local e toque em Adicionar Ponto.",
                Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.sub,Size=UDim2.new(1,0,1,0),
                TextXAlignment=Enum.TextXAlignment.Center,TextWrapped=true},ef); return
        end
        for idx,wp in ipairs(State.waypoints) do
            local row=Instance.new("Frame",wpSF); row.Size=UDim2.new(1,0,0,48)
            row.BackgroundColor3=C.item; row.LayoutOrder=idx; UI.corner(8,row); UI.stroke(C.bdr2,1,row)

            local idxBadge=Instance.new("Frame",row); idxBadge.Size=UDim2.new(0,26,0,26)
            idxBadge.Position=UDim2.new(0,8,0.5,-13); idxBadge.BackgroundColor3=C.accent
            idxBadge.BorderSizePixel=0; UI.corner(6,idxBadge)
            UI.lbl({Text=tostring(idx),Font=Enum.Font.GothamBold,TextSize=12,TextColor3=C.white,
                Size=UDim2.new(1,0,1,0),TextXAlignment=Enum.TextXAlignment.Center},idxBadge)

            UI.lbl({Text=wp.name,Font=Enum.Font.GothamSemibold,TextSize=13,TextColor3=C.text,
                Size=UDim2.new(1,-130,0,20),Position=UDim2.new(0,42,0,4),TextTruncate=Enum.TextTruncate.AtEnd},row)
            UI.lbl({Text=wp.coord,Font=Enum.Font.Gotham,TextSize=10,TextColor3=C.sub,
                Size=UDim2.new(1,-130,0,14),Position=UDim2.new(0,42,0,24)},row)

            local function mkMicroBtn(txt,x,bgCol)
                local b=Instance.new("TextButton",row); b.Size=UDim2.new(0,26,0,26)
                b.Position=UDim2.new(1,x,0.5,-13); b.BackgroundColor3=bgCol or C.dark2
                b.Text=txt; b.Font=Enum.Font.GothamBold; b.TextSize=13; b.TextColor3=C.text
                b.AutoButtonColor=false; UI.corner(6,b); return b
            end
            local upBtn   = mkMicroBtn("↑",-90,C.dark2)
            local downBtn = mkMicroBtn("↓",-60,C.dark2)
            local delBtn  = mkMicroBtn("✕",-28,C.dimred)
            delBtn.TextColor3=C.white

            local ci=idx
            upBtn.MouseButton1Click:Connect(function() WP.move(ci,-1); refreshWP() end)
            downBtn.MouseButton1Click:Connect(function() WP.move(ci,1); refreshWP() end)
            delBtn.MouseButton1Click:Connect(function() WP.remove(ci); refreshWP() end)
        end
    end

    addWpBtn.MouseButton1Click:Connect(function()
        local root=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not root then UI.notify("Rotas","Personagem não encontrado",C.red); return end
        local pos=root.Position
        local name="Ponto "..(#State.waypoints+1)
        WP.add(name,pos); refreshWP()
        UI.notify("Rotas","Adicionado: "..name,C.accent)
    end)

    startBtn.MouseButton1Click:Connect(function()
        if #State.waypoints==0 then UI.notify("Rotas","Adicione pontos primeiro!",C.red); return end
        WP.start(rtStatusLbl, function()
            startBtn.BackgroundColor3=C.dimgrn; startBtn.TextColor3=C.green
        end)
        startBtn.BackgroundColor3=C.acc2; startBtn.TextColor3=C.white
        UI.notify("Rotas","Circuito iniciado!",C.green)
    end)
    stopBtn.MouseButton1Click:Connect(function()
        WP.stop()
        rtStatusLbl.Text="⏹  Circuito parado."; rtStatusLbl.TextColor3=C.sub
        startBtn.BackgroundColor3=C.dimgrn; startBtn.TextColor3=C.green
        UI.notify("Rotas","Circuito parado.",C.orange)
    end)
    UI.btn({Size=UDim2.new(1,0,0,44),Text="🗑️ Limpar Todos os Pontos",Bg=C.dimred,TextColor3=C.white,
        Border=Color3.fromRGB(60,30,30),Hover=Color3.fromRGB(70,20,20),Order=6},rtP).MouseButton1Click:Connect(function()
        WP.clear(); refreshWP(); UI.notify("Rotas","Pontos limpos.",C.orange) end)

    local mobP=tabPages["mobs"]
    UI.toggle(mobP,"Escanear Todos os Modelos","Ignora filtros (pode incluir NPCs)",1,function(v)
        State.forceScanMode=v; State._scanCache=nil end)
    UI.sec("Lista de Bloqueio",mobP,2)
    local blSF,_=makeScrollList(mobP,120); blSF.LayoutOrder=3

    local function refreshBL()
        for _,ch in ipairs(blSF:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
        if #State.blacklist==0 then
            local ef=Instance.new("Frame",blSF); ef.Size=UDim2.new(1,0,0,34)
            ef.BackgroundTransparency=1; ef.LayoutOrder=0
            UI.lbl({Text="Nenhum NPC bloqueado.",Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.sub,
                Size=UDim2.new(1,0,1,0),TextXAlignment=Enum.TextXAlignment.Center},ef); return
        end
        for idx,blocked in ipairs(State.blacklist) do
            local row=Instance.new("Frame",blSF); row.Size=UDim2.new(1,0,0,38)
            row.BackgroundColor3=C.item; row.LayoutOrder=idx; UI.corner(8,row); UI.stroke(C.bdr2,1,row)
            UI.lbl({Text=blocked,Font=Enum.Font.Gotham,TextSize=13,TextColor3=C.text,
                Size=UDim2.new(1,-50,1,0),Position=UDim2.new(0,10,0,0)},row)
            local rm=Instance.new("TextButton",row); rm.Size=UDim2.new(0,36,0,28)
            rm.Position=UDim2.new(1,-42,0.5,-14); rm.BackgroundColor3=C.dimred; rm.Text="✕"
            rm.Font=Enum.Font.GothamBold; rm.TextSize=14; rm.TextColor3=C.white; rm.AutoButtonColor=false
            UI.corner(6,rm); local ci=idx
            rm.MouseButton1Click:Connect(function()
                table.remove(State.blacklist,ci); State._scanCache=nil; saveData(); refreshBL()
                UI.notify("Mobs","Removido: "..blocked,C.orange) end)
        end
    end

    local _,blBox,addBlBtn=makeInputRow(mobP,4,"NPC ou palavra-chave","+ Bloquear",C.accent)
    addBlBtn.MouseButton1Click:Connect(function()
        local t=blBox.Text:match("^%s*(.-)%s*$")
        if t~="" then table.insert(State.blacklist,t); State._scanCache=nil; saveData(); refreshBL()
            blBox.Text=""; UI.notify("Mobs","Bloqueado: "..t,C.accent) end end)

    local chP=tabPages["chests"]
    local chStatusRow=Instance.new("Frame",chP); chStatusRow.Size=UDim2.new(1,0,0,36)
    chStatusRow.BackgroundColor3=C.dark1; chStatusRow.LayoutOrder=1
    UI.corner(10,chStatusRow); UI.stroke(C.border,1,chStatusRow)
    local chStatusLbl=UI.lbl({Text="Nenhum baú escaneado.",Font=Enum.Font.Gotham,
        TextSize=13,TextColor3=C.sub,Size=UDim2.new(1,-12,1,0),Position=UDim2.new(0,10,0,0)},chStatusRow)

    UI.sec("Palavras-chave de Baús",chP,2)
    local kwSF,_=makeScrollList(chP,90); kwSF.LayoutOrder=3

    local function refreshKW()
        for _,ch in ipairs(kwSF:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
        for idx,kw in ipairs(State.chestKeywords) do
            local row=Instance.new("Frame",kwSF); row.Size=UDim2.new(1,0,0,32)
            row.BackgroundColor3=C.item; row.LayoutOrder=idx; UI.corner(6,row); UI.stroke(C.bdr2,1,row)
            UI.lbl({Text=kw,Font=Enum.Font.GothamSemibold,TextSize=13,TextColor3=C.accent,
                Size=UDim2.new(1,-50,1,0),Position=UDim2.new(0,10,0,0)},row)
            local rm=Instance.new("TextButton",row); rm.Size=UDim2.new(0,32,0,24)
            rm.Position=UDim2.new(1,-38,0.5,-12); rm.BackgroundColor3=C.dimred; rm.Text="✕"
            rm.Font=Enum.Font.GothamBold; rm.TextSize=13; rm.TextColor3=C.white; rm.AutoButtonColor=false
            UI.corner(6,rm); local ci=idx
            rm.MouseButton1Click:Connect(function()
                if #State.chestKeywords<=1 then UI.notify("Baús","Mantenha ao menos uma keyword",C.red); return end
                table.remove(State.chestKeywords,ci); saveData(); refreshKW()
                UI.notify("Baús","Keyword removida.",C.orange) end)
        end
    end

    local _,kwBox,addKwBtn=makeInputRow(chP,4,"ex: cofre, crate, loot, baú","+ Adicionar",C.accent)
    addKwBtn.MouseButton1Click:Connect(function()
        local t=kwBox.Text:match("^%s*(.-)%s*$"):lower()
        if t~="" then
            for _,k in ipairs(State.chestKeywords) do if k==t then return end end
            table.insert(State.chestKeywords,t); saveData(); refreshKW()
            kwBox.Text=""; UI.notify("Baús","Keyword: "..t,C.accent)
        end end)

    local diagBtn=UI.btn({Size=UDim2.new(1,0,0,44),Text="🔎 Diagnóstico: Modelos Próximos (100m)",
        Bg=C.item,Border=C.bdr2,Order=5},chP)
    local diagSF,_=makeScrollList(chP,100); diagSF.LayoutOrder=6; diagSF.Visible=true

    diagBtn.MouseButton1Click:Connect(function()
        for _,ch in ipairs(diagSF:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
        diagBtn.Text="⏳ Buscando..."; task.defer(function()
            local near=nearbyModelNames(100)
            diagBtn.Text="🔎 Diagnóstico ("..#near.." modelos)"
            if #near==0 then
                local ef=Instance.new("Frame",diagSF); ef.Size=UDim2.new(1,0,0,32); ef.BackgroundTransparency=1; ef.LayoutOrder=0
                UI.lbl({Text="Nenhum modelo próximo.",Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.sub,
                    Size=UDim2.new(1,0,1,0),TextXAlignment=Enum.TextXAlignment.Center},ef); return
            end
            for idx,m in ipairs(near) do
                local row=Instance.new("Frame",diagSF); row.Size=UDim2.new(1,0,0,30)
                row.BackgroundColor3=C.item; row.LayoutOrder=idx; UI.corner(6,row); UI.stroke(C.bdr2,1,row)
                UI.lbl({Text=m.name,Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.text,
                    Size=UDim2.new(1,-50,1,0),Position=UDim2.new(0,8,0,0),TextTruncate=Enum.TextTruncate.AtEnd},row)
                UI.lbl({Text=m.dist.."m",Font=Enum.Font.GothamBold,TextSize=11,TextColor3=C.sub,
                    Size=UDim2.new(0,42,1,0),Position=UDim2.new(1,-46,0,0),TextXAlignment=Enum.TextXAlignment.Right},row)
                
                local rb=Instance.new("TextButton",row); rb.Size=UDim2.new(1,0,1,0)
                rb.BackgroundTransparency=1; rb.Text=""
                rb.MouseButton1Click:Connect(function()
                    local kw=m.name:lower()
                    for _,k in ipairs(State.chestKeywords) do if k==kw then
                        UI.notify("Baús","'"..kw.."' já está na lista",C.orange); return end end
                    table.insert(State.chestKeywords,kw); saveData(); refreshKW()
                    UI.notify("Baús","Adicionado: "..kw,C.accent)
                end)
            end
        end)
    end)

    local chScanBtn=UI.btn({Size=UDim2.new(1,0,0,48),Text="🔍 Escanear Baús",
        Bg=C.item,Border=C.bdr2,Order=7},chP)
    local chListSF,_=makeScrollList(chP,200); chListSF.LayoutOrder=8; chListSF.Visible=true

    local function refreshChests()
        for _,ch in ipairs(chListSF:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
        local chests=scanChests()
        if #chests==0 then
            chStatusLbl.Text="Nenhum baú encontrado. Keywords: {"..table.concat(State.chestKeywords,", ").."}"
            chStatusLbl.TextColor3=C.orange; return
        end
        chStatusLbl.Text="⬤  "..#chests.." baú"..(#chests>1 and "s" or "").." encontrado"..(#chests>1 and "s" or "")
        chStatusLbl.TextColor3=C.accent
        for idx,chest in ipairs(chests) do
            local btn=Instance.new("TextButton",chListSF); btn.Size=UDim2.new(1,0,0,48)
            btn.BackgroundColor3=C.item; btn.Text=""; btn.LayoutOrder=idx
            UI.corner(8,btn); UI.stroke(C.bdr2,1,btn)
            UI.lbl({Text=chest.name.." ("..math.floor(chest.dist).."m)",Font=Enum.Font.GothamSemibold,
                TextSize=13,TextColor3=C.text,Size=UDim2.new(1,-80,0,20),Position=UDim2.new(0,10,0,5),
                TextTruncate=Enum.TextTruncate.AtEnd},btn)
            UI.lbl({Text=chest.coord,Font=Enum.Font.Gotham,TextSize=10,TextColor3=C.sub,
                Size=UDim2.new(1,-80,0,14),Position=UDim2.new(0,10,0,26)},btn)
            local goBtn=UI.btn({Size=UDim2.new(0,62,0,36),Text="Ir",
                Bg=C.accent,TextColor3=C.white,Hover=C.acc2,Radius=8},btn)
            goBtn.Font=Enum.Font.GothamBold; goBtn.TextSize=13; goBtn.Position=UDim2.new(1,-70,0.5,-18)
            local cc=chest.coord
            goBtn.MouseButton1Click:Connect(function()
                teleportTo(cc); btn:Destroy()
                task.delay(3,function()
                    if VIM then pcall(function()
                        VIM:SendKeyEvent(true,Enum.KeyCode.E,false,game); task.wait(0.1)
                        VIM:SendKeyEvent(false,Enum.KeyCode.E,false,game) end) end
                end)
            end)
            btn.MouseEnter:Connect(function() UI.tw(btn,0.1,{BackgroundColor3=C.itemH}) end)
            btn.MouseLeave:Connect(function() UI.tw(btn,0.1,{BackgroundColor3=C.item}) end)
        end
    end

    chScanBtn.MouseButton1Click:Connect(function()
        chScanBtn.Text="⏳ Escaneando..."
        task.defer(function() refreshChests(); chScanBtn.Text="🔍 Escanear Baús" end) end)

    local visP=tabPages["visual"]
    UI.sec("ESP — Highlight",visP,1)
    UI.toggle(visP,"ESP Players","Destaca outros jogadores (azul)",2,function(v)
        State.espPlayers=v
        if not v then
            for _,p in ipairs(Services.Players:GetPlayers()) do
                if p~=LP and p.Character then
                    local hl=_espHL[p.Character]
                    if hl then hl:Destroy(); _espHL[p.Character]=nil end
                end
            end
        end
        UI.notify("ESP Players",v and "Ativado" or "Desativado",v and C.green or C.red)
    end)
    UI.toggle(visP,"ESP Mobs","Destaca inimigos (vermelho/amarelo)",3,function(v)
        State.espMobs=v
        if not v then
            for inst,hl in pairs(_espHL) do
                local isPlayer=false
                for _,p in ipairs(Services.Players:GetPlayers()) do
                    if p.Character==inst then isPlayer=true; break end
                end
                if not isPlayer then hl:Destroy(); _espHL[inst]=nil end
            end
        end
        UI.notify("ESP Mobs",v and "Ativado" or "Desativado",v and C.green or C.red)
    end)
    UI.btn({Size=UDim2.new(1,0,0,44),Text="🧹 Remover Todos os Highlights",
        Bg=C.item,Border=C.bdr2,Order=4},visP).MouseButton1Click:Connect(function()
        State.espPlayers=false; State.espMobs=false; ESP.clearAll()
        UI.notify("ESP","Highlights removidos",C.orange) end)

    UI.sec("── Iluminação",visP,5)
    UI.toggle(visP,"Full Bright","Remove sombras e efeitos de luz",6,function(v)
        State.fullBright=v
        if v then Visuals.applyFullBright()
        else
            for _,fx in ipairs(Services.Lighting:GetChildren()) do
                pcall(function() if fx:IsA("BlurEffect") or fx:IsA("SunRaysEffect")
                    or fx:IsA("ColorCorrectionEffect") then fx.Enabled=true end end)
            end
        end
        UI.notify("Full Bright",v and "Ativado" or "Desativado",v and C.green or C.orange)
    end)
    UI.toggle(visP,"Controle de Tempo","Define o horário do jogo",7,function(v)
        State.timeControl=v; if v then Visuals.applyTime() end
        UI.notify("Tempo",v and "Controlado" or "Liberado",v and C.green or C.orange)
    end)
    UI.slider(visP,"Hora do Dia",0,23,14,"%d:00h",8,function(v)
        State.timeOfDay=v; if State.timeControl then Visuals.applyTime() end
    end)

    UI.sec("── Névoa",visP,9)
    UI.toggle(visP,"Remover Névoa","Limpa névoa e atmosfera",10,function(v)
        State.removeFog=v; Movement.applyFog()
        UI.notify("Névoa",v and "Removida" or "Restaurada",v and C.green or C.orange)
    end)

    local msP=tabPages["misc"]
    UI.toggle(msP,"Anti-AFK","Previne kick por inatividade",1,function(v)
        State.antiAfk=v; UI.notify("Anti-AFK",v and "Ativado" or "Desativado",v and C.green or C.red)
    end)
    UI.btn({Size=UDim2.new(1,0,0,52),Text="🔄 Resetar Tudo",Bg=C.dimred,TextColor3=C.white,
        Border=Color3.fromRGB(60,30,30),Hover=Color3.fromRGB(70,20,20),Order=2},msP).MouseButton1Click:Connect(function()
        Movement.resetAll(); Combat.stop(sigs); WP.stop(); ESP.clearAll()
        UI.notify("Sistema","Tudo resetado.",C.orange) end)

    local infoF=Instance.new("Frame",msP); infoF.Size=UDim2.new(1,0,0,62)
    infoF.BackgroundColor3=C.dark1; infoF.LayoutOrder=3; UI.corner(10,infoF); UI.stroke(C.border,1,infoF)
    UI.lbl({Text="Nexus Universal "..CONFIG.VERSION,Font=Enum.Font.GothamBold,TextSize=14,TextColor3=C.accent,
        Size=UDim2.new(1,0,0,24),Position=UDim2.new(0,12,0,8)},infoF)
    local execName="Desconhecido"
    if type(syn)=="table" and syn.request then execName="Solara / Synapse"
    elseif type(rawget(_G,"request"))=="function" then execName="Xeno / Delta"
    elseif type(http)=="table" and http.request then execName="HTTP Legacy" end
    UI.lbl({Text="Executor: "..execName,Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.sub,
        Size=UDim2.new(1,0,0,16),Position=UDim2.new(0,12,0,34)},infoF)
    UI.lbl({Text="Keybinds: ["..State.kbFly.Name.."] Voar  •  ["..State.kbSpeed.Name.."] Speed",
        Font=Enum.Font.Gotham,TextSize=10,TextColor3=C.sub,
        Size=UDim2.new(1,0,0,14),Position=UDim2.new(0,12,0,48)},infoF)

    local miniBtn=nil
    minBtn.MouseButton1Click:Connect(function()
        win.Visible=false
        if miniBtn then miniBtn:Destroy() end
        miniBtn=Instance.new("TextButton",sc); miniBtn.Size=UDim2.new(0,120,0,36)
        miniBtn.Position=UDim2.new(0,10,0,10); miniBtn.BackgroundColor3=C.nav
        miniBtn.Text="⚡ NEXUS"; miniBtn.Font=Enum.Font.GothamBold; miniBtn.TextSize=13
        miniBtn.TextColor3=C.accent; miniBtn.AutoButtonColor=false
        UI.corner(10,miniBtn); UI.stroke(C.border,1,miniBtn)
        makeDraggable(miniBtn,miniBtn)
        miniBtn.MouseButton1Click:Connect(function() win.Visible=true; miniBtn:Destroy(); miniBtn=nil end)
    end)

    selectTab("movement")
    refreshDests(); refreshBL(); refreshKW(); refreshWP()
    return sc
end

local function Init()
    if State.initialized then return end
    State.initialized=true
    loadData()
    local sigs=Signal.new()
    startGameLoops(sigs)
    local ok,err=pcall(CreateUI,sigs)
    if not ok then warn("[NexusUniversal] Erro UI: "..tostring(err)) end
    UI.notify(CONFIG.BRAND,CONFIG.VERSION.." — ESP · Rotas · Visual carregados!",C.accent)
end

Init()
