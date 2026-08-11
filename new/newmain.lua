-- Limpeza preventiva para evitar conflitos de UI antiga
pcall(function()
    local player = game.Players.LocalPlayer
    if player then
        local oldGui = player.PlayerGui:FindFirstChild("NexusHubUI")
        if oldGui then oldGui:Destroy() end
    end
end)
_G.NexusHubRunning = true
if _G.NexusHubLoaded then
    _G.NexusHubRunning = true
end

if _G.NexusHubBooting and not _G.NexusHubLoaded then
    _G.NexusHubBooting = nil
end

if _G.NexusHubBooting then
    error("Nexus Hub: Still loading - wait a moment before running again.")
end

_G.NexusHubBooting = true
_G.NexusHubM = _G.NexusHubM or {}
local M = _G.NexusHubM

function _G.NexusHubHttpGet(url)
    local ok, body = pcall(function()
        if game.HttpGet then
            return game:HttpGet(url)
        end
    end)

    if ok and type(body) == "string" and body ~= "" then return body end
    ok, body = pcall(function()
        if syn and syn.request then
            return syn.request({ Url = url, Method = "GET" }).Body
        end
    end)

    if ok and type(body) == "string" and body ~= "" then return body end
    ok, body = pcall(function()
        if http_request then
            return http_request({ Url = url, Method = "GET" }).Body
        end
    end)

    if ok and type(body) == "string" and body ~= "" then return body end
    ok, body = pcall(function()
        if request then
            return request({ Url = url, Method = "GET" }).Body
        end
    end)

    if ok and type(body) == "string" and body ~= "" then return body end
    ok, body = pcall(function()
        if type(Xeno) == "table" and type(Xeno.request) == "function" then
            return Xeno.request({ Url = url, Method = "GET" }).Body
        end
    end)

    if ok and type(body) == "string" and body ~= "" then return body end
    return nil
end

function _G.NexusHubCompile(src, chunkName)
    if not src or src == "" then
        error("Nexus Hub: empty script source")
    end

    local compile = loadstring or load
    if not compile then
        error("Nexus Hub: loadstring/load not available in this executor")
    end

    local fn, err = compile(src, chunkName)
    if not fn then
        error("Nexus Hub: compile failed - " .. tostring(err))
    end

    return fn
end

_G.NexusHubAutofarm = false
_G.NexusHubQuestInfo = nil
_G.NexusHubMoveGoal = nil
_G.NexusHubMoveCF = nil
_G.NexusHubAllowMove = false
_G.NexusHubGlobalNoclip = true
_G.NexusHubTravelSpeed = 240
_G.NexusHubMaxMoveSpeed = 280
_G.NexusHubAutoSecondSea = false
_G.NexusHubCachedMarineTeam = nil
_G.NexusHubTravelLockIsland = nil
_G.NexusHubTravelLockUntil = 0
_G.NexusHubSecondSeaTravel = false
_G.NexusHubSecondSeaTravelSpeed = 300
_G.NexusHubAutoThirdSea = false
_G.NexusHubThirdSeaTravel = false
_G.NexusHubLastMoveNudge = 0
_G.NexusHubAutoV3 = false
_G.NexusHubAutoV4 = false
_G.NexusHubLastQuestInvoke = 0
_G.NexusHubAutoAttack = false
_G.NexusHubLastTravelNudge = 0
_G.NexusHubPhysicsWatchUntil = 0
_G.NexusHubLastNoclipApply = 0
_G.NexusHubLastMoveRaycast = 0
_G.NexusHubQuestGiverWaitSince = 0
local NexusHubVersion = "2.1.0"
local Player            = game.Players.LocalPlayer
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")
local CoreGui           = game:GetService("CoreGui")


-- ========== FUNÇÃO DE REQUISIÇÃO HTTP ROBUSTA ==========
local function HttpRequest(url)
    local success, response = pcall(function()
        if syn and syn.request then
            return syn.request({ Url = url, Method = "GET" }).Body
        end
    end)
    if success and response and response ~= "" then
        return response
    end

    success, response = pcall(function()
        if http_request then
            return http_request({ Url = url, Method = "GET" }).Body
        end
    end)
    if success and response and response ~= "" then
        return response
    end

    success, response = pcall(function()
        if request then
            return request({ Url = url, Method = "GET" }).Body
        end
    end)
    if success and response and response ~= "" then
        return response
    end

    success, response = pcall(function()
        return game:GetService("HttpService"):GetAsync(url)
    end)
    if success and response and response ~= "" then
        return response
    end

    return nil
end

-- ========== VERIFICAÇÃO DE ACESSO ==========
local HttpService = game:GetService("HttpService")
local LP = game.Players.LocalPlayer
local API_BASE = "https://api.tgferr.com.br"
local HEARTBEAT_URL = API_BASE .. "/api/heartbeat"
local SCRIPT_NAME = "New Complex"

repeat task.wait() until game:IsLoaded() and LP and LP.Character

local function checkAccessWithRetry(maxRetries, delay)
    local success, result
    for i = 1, maxRetries do
        local url = API_BASE .. "/api/check-access/" .. tostring(LP.UserId)
        print(string.format("[Complex] Tentativa %d de %d", i, maxRetries))
        local response = HttpRequest(url)
        if response then
            success, result = pcall(function()
                return HttpService:JSONDecode(response)
            end)
            if success and result and result.has_valid_access == true then
                print("[Complex] Acesso confirmado na tentativa " .. i)
                return true, result.discord_id
            elseif success and result then
                print("[Complex] Resposta da API: has_valid_access =", result.has_valid_access)
                print("[Complex] Mensagem:", result.message or "sem mensagem")
                return false, nil
            else
                print("[Complex] Falha ao decodificar JSON na tentativa " .. i)
            end
        else
            print("[Complex] Falha na requisição HTTP na tentativa " .. i)
        end
        if i < maxRetries then
            task.wait(delay)
        end
    end
    print("[Complex] Todas as tentativas falharam.")
    return false, nil
end

_G.StopHeartbeat = false
local function sendHeartbeat(discord_id)
    pcall(function()
        local level = "?"
        pcall(function()
            if LP:FindFirstChild("Data") and LP.Data:FindFirstChild("Level") then
                level = tostring(LP.Data.Level.Value)
            end
        end)
        local payload = {
            roblox_id = tostring(LP.UserId),
            roblox_name = tostring(LP.Name),
            level = level,
            using_script = SCRIPT_NAME,
            discord_id = discord_id or ""
        }
        local ok, body = pcall(HttpService.JSONEncode, HttpService, payload)
        if not ok or body == nil then return end
        pcall(function()
            if syn and syn.request then
                syn.request({ Url = HEARTBEAT_URL, Method = "POST", Body = body, Headers = {["Content-Type"] = "application/json"} })
            elseif http_request then
                http_request({ Url = HEARTBEAT_URL, Method = "POST", Body = body, Headers = {["Content-Type"] = "application/json"} })
            elseif request then
                request({ Url = HEARTBEAT_URL, Method = "POST", Body = body, Headers = {["Content-Type"] = "application/json"} })
            else
                HttpService:PostAsync(HEARTBEAT_URL, body, Enum.HttpContentType.ApplicationJson)
            end
        end)
    end)
end

local function startHeartbeat(discord_id)
    task.spawn(function()
        while not _G.StopHeartbeat do
            sendHeartbeat(discord_id)
            task.wait(300)
        end
    end)
end

-- ========== VALIDAÇÃO ==========
local hasAccess = false
local discord_id = nil

if _G.NEXUS_PROXY_AUTH then
    hasAccess = true
    discord_id = _G.NEXUS_DISCORD_ID or nil
    print("[Complex] Autenticado via proxy, pulando validação.")
else
    print("[Complex] Verificando acesso via API...")
    hasAccess, discord_id = checkAccessWithRetry(5, 2)
    if hasAccess then
        print("[Complex] Acesso confirmado. Iniciando hub.")
    else
        print("[Complex] Sem acesso. Carregando proxy...")
    end
end

if not hasAccess then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/tgferrmonitor/NexusFruitsHub/refs/heads/main/nexusproxy.lua"))()
    return
end

startHeartbeat(discord_id)

local BETA_OWNER = "TaxiAura"
local BETA_ACCOUNTS = {
    [BETA_OWNER] = { devKey = "TaxiAura-DEV-OWNER" },
    ["I_comeoneMen"] = { devKey = "1key" },
    ["willam_021"] = { devKey = "iiijfb887xub" },
    ["sgsgrgsejuiklo"] = { devKey = "KEY" },
}
local MAINTENANCE_MODE = false

function M.getHRP()
    return LP.Character.HumanoidRootPart
end

function M.isBetaTester(name)
    return name and BETA_ACCOUNTS[name] ~= nil
end

function M.addBetaTester(name, devKey)
    if not name or name == "" then return false end
    BETA_ACCOUNTS[name] = { devKey = devKey or (name .. "-DEV-SET-KEY") }
    return true
end

function M.removeBetaTester(name)
    if not name or name == "" then return false end
    BETA_ACCOUNTS[name] = nil
    return true
end

function M.listBetaTesters()
    local out = {}
    for k, _ in pairs(BETA_ACCOUNTS) do table.insert(out, k) end
    return out
end

function M.validateDevKey(key)
    local account = BETA_ACCOUNTS[Player.Name]
    if not account then
        return false, "Your account is not authorized for dev mode"
    end

    key = key and key:match("^%s*(.-)%s*$") or ""
    if key == "" then
        return false, "Enter your dev key"
    end

    if key ~= account.devKey then
        return false, "Invalid key for " .. Player.Name
    end

    return true
end

function M.enableDevMode(key)
    local ok, err = M.validateDevKey(key)
    if not ok then return false, err end
    _G.NexusHubDevMode = true
    return true
end

_G.AddBetaTester    = M.addBetaTester
_G.RemoveBetaTester = M.removeBetaTester
_G.ListBetaTesters  = M.listBetaTesters
_G.IsBetaTester     = M.isBetaTester
_G.BetaOwner        = BETA_OWNER
_G.MAINTENANCE_MODE = MAINTENANCE_MODE
if MAINTENANCE_MODE then
    local playerName = (game.Players and game.Players.LocalPlayer and game.Players.LocalPlayer.Name) or ""
    if playerName ~= BETA_OWNER and not M.isBetaTester(playerName) then
        local Player = game.Players.LocalPlayer
        local parentGui = (Player and Player:FindFirstChild("PlayerGui")) or nil
        local gui = Instance.new("ScreenGui")
        gui.Name = "NexusHub_Maintenance"
        gui.ResetOnSpawn = false
        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(0, 460, 0, 180)
        bg.Position = UDim2.new(0.5, -230, 0.5, -90)
        bg.AnchorPoint = Vector2.new(0.5, 0.5)
        bg.BackgroundColor3 = Color3.fromRGB(9, 12, 18)
        bg.BorderSizePixel = 0
        bg.Name = "MaintenanceRoot"
        bg.Parent = gui
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = bg
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(35, 48, 72)
        stroke.Thickness = 1.5
        stroke.Parent = bg
        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, -28, 0, 44)
        header.Position = UDim2.new(0, 14, 0, 12)
        header.BackgroundTransparency = 1
        header.Text = "Nexus Hub - Maintenance"
        header.TextColor3 = Color3.fromRGB(220, 230, 245)
        header.Font = Enum.Font.GothamBold
        header.TextSize = 20
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = bg
        local msg = Instance.new("TextLabel")
        msg.Size = UDim2.new(1, -28, 0, 76)
        msg.Position = UDim2.new(0, 14, 0, 62)
        msg.BackgroundTransparency = 1
        msg.Text = "This script is currently under maintenance.\nOnly beta testers or the owner can run the full script."
        msg.TextColor3 = Color3.fromRGB(180, 200, 220)
        msg.Font = Enum.Font.Gotham
        msg.TextSize = 15
        msg.TextWrapped = true
        msg.TextXAlignment = Enum.TextXAlignment.Left
        msg.Parent = bg
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 110, 0, 34)
        closeBtn.Position = UDim2.new(1, -124, 1, -48)
        closeBtn.AnchorPoint = Vector2.new(0, 0)
        closeBtn.BackgroundColor3 = Color3.fromRGB(99, 202, 183)
        closeBtn.TextColor3 = Color3.fromRGB(10, 10, 10)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 14
        closeBtn.Text = "Close"
        closeBtn.Parent = bg
        local cbCorner = Instance.new("UICorner")
        cbCorner.CornerRadius = UDim.new(0, 8)
        cbCorner.Parent = closeBtn
        local ownerLabel = Instance.new("TextLabel")
        ownerLabel.Size = UDim2.new(0, 220, 0, 18)
        ownerLabel.Position = UDim2.new(0, 14, 1, -30)
        ownerLabel.BackgroundTransparency = 1
        ownerLabel.Text = "Owner: " .. tostring(BETA_OWNER)
        ownerLabel.TextColor3 = Color3.fromRGB(140, 160, 185)
        ownerLabel.Font = Enum.Font.Gotham
        ownerLabel.TextSize = 12
        ownerLabel.TextXAlignment = Enum.TextXAlignment.Left
        ownerLabel.Parent = bg
        closeBtn.MouseButton1Click:Connect(function()
            pcall(function()
                if M.DisconnectAll then pcall(M.DisconnectAll) end
            end)
            M.onUnloadCleanup()
            M.stopAutofarm()
            -- Desligar todas as flags
            S.autoRaid = false; S.autoAttack = false; _G.NexusHubAutoAttack = false; S.autoSeaFarm = false; S.autoLeviathan = false; S.autoStats = false; S.chestFarmEnabled = false; S.autoBossFarm = false; S.autoFruitRoll = false; S.autoStoreFruit = false; S.autoFruitSniper = false; S.fruitSniperChasing = false; S.autoIndra = false; S.indraCombatTarget = nil; S.autoElite = false; S.eliteCombatTarget = nil; S.autoDarkbeard = false; S.darkbeardCombatTarget = nil; S.autoCursedCaptain = false; S.cursedCaptainCombatTarget = nil; S.cursedCaptainEngaged = false; S.autoDoughPrince = false; S.autoDoughKing = false; S.doughRaidCombatTarget = nil; S.doughBringMobActive = false; S.doughRaidTravel = false; M.resetDoughFarmAnchor(); M.resetDoughPatrol(); S.autoSetHomePoint = false; S.lastHomeAnchorPos = nil; S.autoPirateRaid = false; S.pirateRaidTarget = nil; S.pirateRaidEngaged = false; S.autoFactoryRaid = false; S.factoryRaidTarget = nil; S.factoryRaidEngaged = false; pcall(M.resetFactoryRaidTravel); S.autoMasteryFarm = false; S.masteryPhase = "farm"; S.masteryTargetModel = nil; pcall(function() M.resetMasteryFarmState() end); S.autoPray = false; S.autoTryLuck = false; S.autoRollBones = false; S.autoSoulReaper = false; S.soulReaperTarget = nil; S.autoMaterialFarm = false; S.autoActivateV3 = false; S.autoActivateV4 = false; _G.NexusHubAutoV3 = false; _G.NexusHubAutoV4 = false; M.unanchorFarmTarget(); S.autoBuso = false; S.autoInstinct = false; S.autoBuyHakiColor = false; S.autoBuyRaceGear = false; S.autoSaber = false; S.saberCombatTarget = nil; S.saberForcedAutofarm = false; S.autoSecondSea = false; _G.NexusHubAutoSecondSea = false; _G.NexusHubSecondSeaTravel = false; S.secondSeaCombatTarget = nil; S.autoThirdSea = false; _G.NexusHubAutoThirdSea = false; _G.NexusHubThirdSeaTravel = false; S.thirdSeaCombatTarget = nil; S.thirdSeaSacrificeActive = false; S.thirdSeaRipIndraAnchor = nil; pcall(function() M.setInstinct(false) end); pcall(function() M.setAutoStoreFruitListener(false) end); pcall(function() M.setAntiAfk(false) end); S.fruitEspEnabled = false; pcall(M.clearFruitEsp); M.stopBoatDrive(); if workspace:FindFirstChild("NexusHubWaterWalk") then pcall(function() workspace.NexusHubWaterWalk:Destroy() end) end; _G.NexusHubLoaded = false; _G.NexusHubDevMode = nil; pcall(M.DisconnectAll); pcall(function() screenGui:Destroy() end); M.notify("Nexus Hub", "Unloaded", 4)
            pcall(function() _G.NexusHubLoaded = false end)
            pcall(function()
                local ok, cg = pcall(function() return game:GetService("CoreGui") end)
                if ok and cg then
                    local mainGui = cg:FindFirstChild("NexusHub")
                    if mainGui and mainGui.Destroy then pcall(function() mainGui:Destroy() end) end
                end
            end)

            pcall(function() gui:Destroy() end)
        end)

        if parentGui then
            gui.Parent = parentGui
        else
            pcall(function() gui.Parent = game:GetService("CoreGui") end)
        end

        return
    end
end

local VirtualUser         = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Character        = Player.Character or Player.CharacterAdded:Wait()
local Humanoid         = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Remotes  = ReplicatedStorage:WaitForChild("Remotes")
local Modules  = ReplicatedStorage:WaitForChild("Modules")
local Net      = Modules:WaitForChild("Net")
local CommF_   = Remotes:WaitForChild("CommF_")
local CommE    = Remotes:FindFirstChild("CommE")
_G.NexusHubCommF = CommF_

function M.invokeCommFArgs(args)
    if type(args) ~= "table" then return false end
    local a1, a2, a3 = args[1], args[2], args[3]
    if a1 == nil then return false end
    local remote = _G.NexusHubCommF or CommF_
    if not remote then return false end
    if a3 ~= nil then
        a3 = tonumber(a3) or a3
    end

    return pcall(function()
        if a3 ~= nil then
            remote:InvokeServer(a1, a2, a3)
        elseif a2 ~= nil then
            remote:InvokeServer(a1, a2)
        else
            remote:InvokeServer(a1)
        end
    end)
end

function M.getCommFRemote()
    if _G.NexusHubCommF and _G.NexusHubCommF.Parent then
        return _G.NexusHubCommF
    end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local remote = remotes and remotes:FindFirstChild("CommF_")
    if remote then
        _G.NexusHubCommF = remote
    end

    return remote or CommF_
end

function M.fireStartQuest(args)
    if type(args) ~= "table" or args[1] == nil then return false end
    local remote = M.getCommFRemote()
    if not remote then return false end
    local a1, a2, a3 = args[1], args[2], args[3]
    if a3 ~= nil then
        a3 = tonumber(a3) or a3
    end

    return pcall(function()
        if a3 ~= nil then
            remote:InvokeServer(a1, a2, a3)
        elseif a2 ~= nil then
            remote:InvokeServer(a1, a2)
        else
            remote:InvokeServer(a1)
        end
    end)
end

local Connections = {}

function M.AddConnection(conn)
    table.insert(Connections, conn)
    return conn
end

function M.DisconnectAll()
    for _, conn in ipairs(Connections) do
        if conn and conn.Disconnect then pcall(function() conn:Disconnect() end) end
    end

    M.clearTable(Connections)
end

local S = {
    autoAttack = false,
    autofarm = false,
    autoRaid = false,
    selectedRaid = "Flame",
    chestFarmEnabled = false,
    autoStats = false,
    infJumpEnabled = false,
    holding = false,
    isBuyingChip = false,
    isStartingRaid = false,
    selectedWeapon = "Melee",
    selectedStat = "Melee",
    addAmount = 1,
    SetWalkSpeed = Humanoid.WalkSpeed,
    questInfo = nil,
    lastEquippedType = nil,
    UIHotkey = Enum.KeyCode.RightControl,
    ActiveTween = nil,
    ActiveBoatTween = nil,
    farmMoveGoal = nil,
    farmMoveCFrame = nil,
    farmMoveToken = nil,
    lastAnchoredMobRoot = nil,
    lastNoclipAt = 0,
    lastQuestInvoke = 0,
    lastQuestEnemyMissingSince = 0,
    questAcquirePending = false,
    lastKnownQuestProgress = nil,
    lastQuestSpawnNudge = 0,
    autoAttackForcedByFarm = false,
    lastQuestRefresh = 0,
    lastQuestLoadAttempt = 0,
    autoBossFarm = false,
    farmAllBosses = false,
    selectedBoss = "All",
    currentBossTarget = nil,
    bossFollowGoal = nil,
    bossSpawnPatrolIx = 1,
    lastBossPatrolAt = 0,
    bossRotationIndex = 1,
    lastBossQuestAt = 0,
    lastBossResolveAt = 0,
    cachedBossResolve = nil,
    cachedBossResolveName = nil,
    bossMissingSince = nil,
    BOSS_FAIL_GRACE = 45,
    autoFruitRoll = false,
    autoStoreFruit = false,
    autoFruitSniper = false,
    fruitSniperTarget = nil,
    fruitSniperChasing = false,
    lastFruitSniperNotify = 0,
    autoIndra = false,
    indraCombatTarget = nil,
    lastIndraNotify = 0,
    autoElite = false,
    eliteCombatTarget = nil,
    lastEliteNotify = 0,
    autoDarkbeard = false,
    darkbeardCombatTarget = nil,
    lastDarkbeardNotify = 0,
    autoCursedCaptain = false,
    cursedCaptainCombatTarget = nil,
    cursedCaptainEngaged = false,
    lastCursedCaptainNotify = 0,
    lastCursedCaptainReturnAt = 0,
    cursedCaptainMissingSince = nil,
    lastBossEmptyNotify = 0,
    autoDoughPrince = false,
    autoDoughKing = false,
    doughRaidCombatTarget = nil,
    doughBringMobActive = false,
    doughFarmAnchor = nil,
    doughFarmAnchorGround = false,
    doughFarmTarget = nil,
    doughFarmTypeLock = nil,
    doughPackPos = nil,
    lastDoughFallbackAt = 0,
    lastDoughSimRadiusAt = 0,
    lastDoughHoverSnapAt = 0,
    lastDoughWeaponEquipAt = 0,
    doughRaidTravel = false,
    lastDoughBringAt = 0,
    lastDoughAnchorRefresh = 0,
    lastDoughNotify = 0,
    lastDoughSpawnAt = 0,
    lastDoughStatusAt = 0,
    lastDoughPortalEnterAt = 0,
    lastDoughSpawnerPing = 0,
    doughDimensionActive = false,
    doughDimensionWindowUntil = 0,
    lastCakeLandTravelAt = 0,
    lastCakeLandEntranceAt = 0,
    doughPatrolIx = 0,
    lastDoughPatrolAt = 0,
    doughPatrolArrivedAt = nil,
    doughPatrolGround = nil,
    doughEmptySince = nil,
    doughPackAttackLoopRunning = false,
    backgroundLoopsStarted = false,
    broadcastHooksStarted = false,
    autoSetHomePoint = false,
    lastHomeSetAt = 0,
    lastHomeAnchorPos = nil,
    lastHomeRecoverAt = 0,
    autoPirateRaid = false,
    pirateRaidTarget = nil,
    pirateRaidEngaged = false,
    pirateRaidCommencing = false,
    pirateRaidWindowUntil = 0,
    lastPirateRaidSeen = 0,
    lastPirateRaidTravelAt = 0,
    autoFactoryRaid = false,
    factoryRaidTarget = nil,
    factoryRaidEngaged = false,
    lastFactoryRaidNotify = 0,
    lastFactoryTravelAt = 0,
    factoryRaidPhase = "idle",
    factoryRaidPhaseSince = 0,
    factoryRaidStuckSince = 0,
    lastFactoryPortalAt = 0,
    lastFactoryPhaseAt = 0,
    lastFactoryRaidPos = nil,
    autoMasteryFarm = false,
    masteryFarmType = "Devil Fruit",
    masteryFarmItem = "Auto",
    masteryDamagePercent = 25,
    masterySkillZ = true,
    masterySkillX = true,
    masterySkillC = false,
    masterySkillV = false,
    masterySkillF = false,
    masteryPhase = "farm",
    masteryTargetModel = nil,
    lastMasterySkillAt = 0,
    MASTERY_SKILL_CD = 0.4,
    autoTryLuck = false,
    autoPray = false,
    autoRollBones = false,
    autoSoulReaper = false,
    soulReaperTarget = nil,
    lastHauntedNotify = 0,
    autoActivateV3 = false,
    autoActivateV4 = false,
    autoBuso = false,
    autoInstinct = false,
    autoBuyHakiColor = false,
    autoBuyRaceGear = false,
    autoSaber = false,
    saberCombatTarget = nil,
    saberForcedAutofarm = false,
    lastSaberNotify = 0,
    autoSecondSea = false,
    secondSeaCombatTarget = nil,
    lastSecondSeaNotify = 0,
    autoThirdSea = false,
    thirdSeaCombatTarget = nil,
    lastThirdSeaNotify = 0,
    thirdSeaSacrificeStorageName = nil,
    thirdSeaSacrificeDisplay = nil,
    thirdSeaSacrificeSource = nil,
    thirdSeaSacrificeActive = false,
    thirdSeaStageId = nil,
    thirdSeaDonSwanDone = false,
    thirdSeaCellPuzzleDone = false,
    thirdSeaIndraQuestStarted = false,
    thirdSeaIndraNeedsRetalk = false,
    thirdSeaIndraWasFighting = false,
    thirdSeaRipIndraCutsceneActive = false,
    thirdSeaRipIndraOrbitAngle = 0,
    thirdSeaIndraDeathConn = nil,
    thirdSeaMansionSymbols = nil,
    thirdSeaRipIndraAnchor = nil,
    lastThirdSeaRedHeadTalkAt = 0,
    lastThirdSeaCaptainTalkAt = 0,
    lastThirdSeaCellPuzzleAt = 0,
    lastThirdSeaProgressUiAt = 0,
    lastThirdSeaPuzzleAt = 0,
    antiAfkEnabled = false,
    selectedTeleportDest = nil,
    manualTravelSpeed = 200,
    manualTweenActive = false,
    manualTweenConn = nil,
    unstuckActive = false,
    autoMaterialFarm = false,
    selectedMaterialSea = "Sea 1",
    selectedMaterials = {},
    materialPatrolIx = 0,
    lastMaterialWarn = 0,
    lastFarmAttackSwing = 0,
    lastWeaponEquipAt = 0,
    lastFarmHoverVelAt = 0,
    lastAutoStatsAt = 0,
    walkOnWater = false,
    autoSeaFarm = false,
    autoLeviathan = false,
    seaFarmTargets = {
        ["Sea Beast"] = true,
        ["Terror Shark"] = true,
        ["Piranha"] = true,
        ["Shark"] = true,
        ["Ghost Ship"] = true,
        ["Ship"] = true,
    },
    boatSpeed = 200,
    boatDriveGeneration = 0,
    lastSeaSeaWarn = 0,
    cachedMyBoat = nil,
    cachedSeaTarget = nil,
    lastSeaEnemyScan = 0,
    seaAttackDistance = 38,
    seaSnapOffsets = {
        Vector3.new(26, 16, 0),
        Vector3.new(0, 16, 26),
        Vector3.new(-26, 16, 0),
        Vector3.new(0, 16, -26),
    },
    seaTweenGoal = nil,
    removeFogEnabled = false,
    removeDarknessEnabled = false,
    fruitEspEnabled = false,
    lastFruitEspAt = 0,
    devVerboseNotify = false,
    devPhysicsTrace = false,
    devPhysicsDumpOnStop = false,
    orbitRadius = 10,
    farmHoverY = 18,
    orbitHeight = 18,
    snapTime = 1.2,
    snapIndex = 1,
    lastSwitch = os.clock(),
    lastOrbitAt = 0,
    orbitDistance = 15,
    spawnStandHeight = 3,
    spawnNearHoriz = 14,
    spawnNearMaxY = 18,
    spawnPatrolDelay = 4.5,
    questSpawnPatrolIx = 0,
    questSpawnStuckSince = 0,
    questSpawnTrackEnemy = nil,
    QUEST_TURNIN_GRACE = 4.0,
    QUEST_RESPAWN_WAIT = 30.0,
    FARM_ANCHOR_RADIUS = 280,
    farmAnchorPos = nil,
    farmAnchorKey = nil,
    spawnPointCache = {},
    islandNearCache = {},
    patrolState = "IDLE",
    cachedSeaDanger = 0,
    lastDangerCheck = 0,
    antiAfkGeneration = 0,
    antiAfkConn = nil,
    fogDefaults = nil,
    lastGlobalBossScan = 0,
    GLOBAL_BOSS_SCAN_INTERVAL = 2,
}
S.snapOffsets = {
    Vector3.new(S.orbitRadius, 0, 0),
    Vector3.new(0, 0, S.orbitRadius),
    Vector3.new(-S.orbitRadius, 0, 0),
    Vector3.new(0, 0, -S.orbitRadius),
}

function _G.NexusHubFinishFarmMove()
    S.farmMoveGoal = nil
    S.farmMoveCFrame = nil
    S.farmMoveToken = nil
    S.ActiveTween = nil
    _G.NexusHubAllowMove = false
end

local Settings = { Distance = 50, AttackDelay = 0.2 }
local MIN_ATTACK_DELAY = 0.2

function M.getWindowTitle()
    if _G.NexusHubDevMode then
        return "Nexus Hub [DEV] v" .. NexusHubVersion
    end
    return "Nexus Hub v" .. NexusHubVersion
end

-- ========== SISTEMA DE NOTIFICAÇÃO SUBSTITUÍDO ==========
-- As notificações agora usam a GUI interna
local function createNotification(title, msg, duration)
    pcall(function()
        local sg = game:GetService("CoreGui"):FindFirstChild("NexusHubUI")
        if not sg then return end
        local frame = sg:FindFirstChild("NotificationFrame")
        if not frame then
            frame = Instance.new("Frame")
            frame.Name = "NotificationFrame"
            frame.Size = UDim2.new(0, 350, 0, 60)
            frame.Position = UDim2.new(0.5, -175, 0, 10)
            frame.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
            frame.BorderSizePixel = 0
            frame.Parent = sg
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = frame
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(60, 70, 100)
            stroke.Thickness = 1
            stroke.Parent = frame
            local titleLbl = Instance.new("TextLabel")
            titleLbl.Name = "Title"
            titleLbl.Size = UDim2.new(1, -16, 0, 22)
            titleLbl.Position = UDim2.new(0, 8, 0, 4)
            titleLbl.BackgroundTransparency = 1
            titleLbl.Text = ""
            titleLbl.TextColor3 = Color3.fromRGB(160, 200, 255)
            titleLbl.Font = Enum.Font.GothamBold
            titleLbl.TextSize = 14
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            titleLbl.Parent = frame
            local msgLbl = Instance.new("TextLabel")
            msgLbl.Name = "Message"
            msgLbl.Size = UDim2.new(1, -16, 0, 28)
            msgLbl.Position = UDim2.new(0, 8, 0, 28)
            msgLbl.BackgroundTransparency = 1
            msgLbl.Text = ""
            msgLbl.TextColor3 = Color3.fromRGB(200, 210, 230)
            msgLbl.Font = Enum.Font.Gotham
            msgLbl.TextSize = 12
            msgLbl.TextWrapped = true
            msgLbl.TextXAlignment = Enum.TextXAlignment.Left
            msgLbl.Parent = frame
        end
        frame.Title.Text = tostring(title)
        frame.Message.Text = tostring(msg)
        frame.Visible = true
        frame:TweenPosition(UDim2.new(0.5, -175, 0, 10), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        task.delay(duration or 3, function()
            pcall(function()
                frame:TweenPosition(UDim2.new(0.5, -175, -0.5, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.3, true)
                task.delay(0.35, function() pcall(function() frame.Visible = false end) end)
            end)
        end)
    end)
end

function M.notify(title, msg, duration)
    print(("[Nexus Hub] %s: %s"):format(tostring(title), tostring(msg)))
    createNotification(title, msg, duration or 5)
    if S.devVerboseNotify then
        print(("[Nexus Hub] %s: %s"):format(tostring(title), tostring(msg)))
    end
end

function M.reloadUI()
    pcall(function()
        local sg = game:GetService("CoreGui"):FindFirstChild("NexusHubUI")
        if sg then sg:Destroy() end
    end)
    M.buildUI()
end

function M.debugLog(title, lines)
    local header = "=== Nexus Hub Dev: " .. title .. " ==="
    local out = header .. "\n" .. table.concat(lines, "\n")
    print(out)
    warn(out)
    M.notify("Dev", title .. " printed to F9", 4)
end

function M.devTrace(tag, msg)
    if not _G.NexusHubDevMode then return end
    if not (S.devVerboseNotify or S.devPhysicsTrace) then return end
    print(("[Nexus Hub][%s] %s"):format(tostring(tag), tostring(msg)))
end

_G.NexusHubDevTrace = M.devTrace

function M.getPlayerBeli()
    local data = Player:FindFirstChild("Data")
    local beli = data and data:FindFirstChild("Beli")
    return beli and beli.Value or nil
end

function M.getPlayerLevel()
    local data = Player:FindFirstChild("Data")
    local level = data and data:FindFirstChild("Level")
    return level and level.Value or nil
end

function M.dumpHubState()
    local flags = {
        S.autoAttack, S.autofarm, S.autoRaid, S.chestFarmEnabled, S.autoStats,
        S.autoBossFarm, S.autoSeaFarm, S.autoLeviathan, S.autoMaterialFarm,
        S.autoFruitRoll, S.autoStoreFruit, S.autoFruitSniper, S.autoPirateRaid,
        S.autoIndra, S.autoDarkbeard, S.autoCursedCaptain, S.autoDoughPrince, S.autoDoughKing, S.autoSetHomePoint,
        S.autoPray, S.autoTryLuck, S.autoRollBones, S.autoSoulReaper,
        S.autoBuso, S.autoInstinct, S.autoBuyHakiColor, S.autoBuyRaceGear,
        S.autoActivateV3, S.autoActivateV4, S.devVerboseNotify,
    }
    local names = {
        "autoAttack", "autofarm", "autoRaid", "chestFarmEnabled", "autoStats",
        "autoBossFarm", "autoSeaFarm", "autoLeviathan", "autoMaterialFarm",
        "autoFruitRoll", "autoStoreFruit", "autoFruitSniper", "autoPirateRaid",
        "autoIndra", "autoDarkbeard", "autoCursedCaptain", "autoDoughPrince", "autoDoughKing", "autoSetHomePoint",
        "autoPray", "autoTryLuck", "autoRollBones", "autoSoulReaper",
        "autoBuso", "autoInstinct", "autoBuyHakiColor", "autoBuyRaceGear",
        "autoActivateV3", "autoActivateV4", "devVerboseNotify",
    }
    local lines = { "Player: " .. Player.Name, "DevMode: " .. tostring(_G.NexusHubDevMode == true) }
    for i, name in ipairs(names) do
        table.insert(lines, name .. " = " .. tostring(flags[i]))
    end

    table.insert(lines, "selectedRaid = " .. tostring(S.selectedRaid))
    table.insert(lines, "selectedBoss = " .. tostring(S.selectedBoss))
    table.insert(lines, "selectedWeapon = " .. tostring(S.selectedWeapon))
    table.insert(lines, "questInfo = " .. tostring(S.questInfo and S.questInfo.Name or "nil"))
    table.insert(lines, "_G.NexusHubAutofarm = " .. tostring(_G.NexusHubAutofarm))
    table.insert(lines, "_G.NexusHubAutoAttack = " .. tostring(_G.NexusHubAutoAttack))
    table.insert(lines, "_G.NexusHubAllowMove = " .. tostring(_G.NexusHubAllowMove))
    table.insert(lines, "_G.NexusHubFarmNoclip = " .. tostring(_G.NexusHubFarmNoclip))
    table.insert(lines, "autoAttackForcedByFarm = " .. tostring(S.autoAttackForcedByFarm))
    M.debugLog("Hub State", lines)
end

function M.dumpFarmGlobals()
    local qi = _G.NexusHubQuestInfo
    local moving, questBusy = false, false
    if _G.NexusHubIsMoving then moving = _G.NexusHubIsMoving() == true end
    if _G.NexusHubQuestInProgress then questBusy = _G.NexusHubQuestInProgress() == true end
    local playerLevel = _G.NexusHubGetLevel and _G.NexusHubGetLevel() or 0
    local bestLevelReq = "n/a"
    if playerLevel > 0 and M.findBestQuestForLevel then
        local bestQuest = M.findBestQuestForLevel(playerLevel)
        bestLevelReq = bestQuest and tostring(bestQuest.LevelReq) or "nil"
    end

    local lines = {
        "version = " .. NexusHubVersion,
        "_G.NexusHubAutofarm = " .. tostring(_G.NexusHubAutofarm),
        "_G.NexusHubAutoAttack = " .. tostring(_G.NexusHubAutoAttack),
        "_G.NexusHubAllowMove = " .. tostring(_G.NexusHubAllowMove),
        "_G.NexusHubMoveGoal = " .. tostring(_G.NexusHubMoveGoal),
        "_G.NexusHubIsMoving() = " .. tostring(moving),
        "_G.NexusHubFarmNoclip = " .. tostring(_G.NexusHubFarmNoclip),
        "_G.NexusHubQuestInProgress() = " .. tostring(questBusy),
        "needsNewQuest() = " .. tostring(M.needsNewQuest and M.needsNewQuest() or "n/a"),
        "hasUiQuestInProgress() = " .. tostring(M.hasUiQuestInProgress and M.hasUiQuestInProgress() or "n/a"),
        "hasActiveQuest() = " .. tostring(M.hasActiveQuest and M.hasActiveQuest() or "n/a"),
        "_G.NexusHubPhysicsWatchUntil = " .. tostring(_G.NexusHubPhysicsWatchUntil or 0),
        "player level = " .. tostring(playerLevel),
        "quest cache enemy = " .. tostring(qi and qi.enemy or "nil"),
        "quest cache island = " .. tostring(qi and qi.island or "nil"),
        "quest cache key = " .. tostring(qi and qi.questKey or "nil"),
        "quest cache levelReq = " .. tostring(qi and qi.levelReq or "nil"),
        "best quest levelReq = " .. bestLevelReq,
        "shouldUpgradeQuest = " .. tostring(M.shouldUpgradeQuest and M.shouldUpgradeQuest(playerLevel) or "n/a"),
        "shouldBlockTravel = " .. tostring(qi and qi.enemy and M.shouldBlockQuestTravel(qi.enemy, qi.island) or "n/a"),
        "inside cursed ship = " .. tostring(M.isInsideCursedShip and M.isInsideCursedShip() or "?"),
        "cursed ship noclip = " .. tostring(M.shouldForceCursedShipNoclip and M.shouldForceCursedShipNoclip() or "?"),
        "isMoving = " .. tostring(_G.NexusHubIsMoving and _G.NexusHubIsMoving() or "?"),
        "moveGoal set = " .. tostring(_G.NexusHubMoveGoal ~= nil),
        "farmHoverAP = " .. tostring(M.getHRP and M.getHRP() and M.getHRP():FindFirstChild("FarmHoverAP") ~= nil or "?"),
        "factoryRaidPhase = " .. tostring(S.factoryRaidPhase),
        "dist to FactoryRaidStand = " .. tostring(M.distToFactoryStand and math.floor(M.distToFactoryStand()) or "?"),
        "lastFactoryPortalAt = " .. tostring(S.lastFactoryPortalAt),
        "near factory area = " .. tostring(M.isNearFactoryRaidArea and M.isNearFactoryRaidArea() or "?"),
        "autofarm = " .. tostring(S.autofarm),
        "autoAttackForcedByFarm = " .. tostring(S.autoAttackForcedByFarm),
    }
    M.debugLog("Farm Globals", lines)
end

function M.dumpMovementState()
    local hrp = M.getHRP()
    local lines = {
        "_G.NexusHubMoveGoal = " .. tostring(_G.NexusHubMoveGoal),
        "_G.NexusHubMoveCF = " .. tostring(_G.NexusHubMoveCF),
        "_G.NexusHubAllowMove = " .. tostring(_G.NexusHubAllowMove),
        "_G.NexusHubIsMoving() = " .. tostring(_G.NexusHubIsMoving and _G.NexusHubIsMoving() or "?"),
        "M.isFarmMoving() = " .. tostring(M.isFarmMoving()),
        "ActiveTween playing = " .. tostring(S.ActiveTween and S.ActiveTween.PlaybackState == Enum.PlaybackState.Playing),
        "farmMoveGoal = " .. tostring(S.farmMoveGoal),
        "farmMoveToken set = " .. tostring(S.farmMoveToken ~= nil),
        "_G.NexusHubLastTravelNudge = " .. tostring(_G.NexusHubLastTravelNudge),
        "hrp velocity = " .. tostring(hrp and hrp.AssemblyLinearVelocity or "nil"),
    }
    M.debugLog("Movement", lines)
end

function M.dumpPhysicsState()
    local plr = game.Players.LocalPlayer
    local char = plr and plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local lines = {
        "character = " .. tostring(char and char.Name or "nil"),
        "humanoid state = " .. tostring(hum and hum:GetState().Name or "nil"),
        "PlatformStand = " .. tostring(hum and hum.PlatformStand or "nil"),
        "Sit = " .. tostring(hum and hum.Sit or "nil"),
        "WalkSpeed = " .. tostring(hum and hum.WalkSpeed or "nil"),
        "hrp Anchored = " .. tostring(hrp and hrp.Anchored or "nil"),
        "hrp velocity = " .. tostring(hrp and hrp.AssemblyLinearVelocity or "nil"),
        "FloatBV = " .. tostring(hrp and hrp:FindFirstChild("FloatBV") ~= nil),
        "_G.NexusHubFarmNoclip = " .. tostring(_G.NexusHubFarmNoclip),
        "_G.NexusHubPhysicsWatchUntil = " .. tostring(_G.NexusHubPhysicsWatchUntil or 0),
    }
    if char then
        local noclipParts = 0
        local constraints = {}
        for _, desc in ipairs(char:GetDescendants()) do
            if desc:IsA("BasePart") and desc.CanCollide == false then
                noclipParts = noclipParts + 1
            end

            if desc:IsA("BodyVelocity") or desc:IsA("BodyGyro") or desc:IsA("BodyPosition")
                or desc:IsA("LinearVelocity") or desc:IsA("VectorForce")
                or desc:IsA("AlignPosition") or desc:IsA("AlignOrientation") then
                table.insert(constraints, desc:GetFullName() .. " (" .. desc.ClassName .. ")")
            end
        end

        table.insert(lines, "parts with CanCollide=false: " .. tostring(noclipParts))
        table.insert(lines, "constraints found: " .. tostring(#constraints))
        for i = 1, math.min(#constraints, 12) do
            table.insert(lines, "  " .. constraints[i])
        end
    end

    M.debugLog("Physics", lines)
end

function M.buildDevTab(devTab)
    M.makeSection(devTab.scroll, "Session")
    devTab:AddLabel("Logged in as " .. Player.Name .. " | Sea: " .. tostring(M.getCurrentSea()))
    devTab:AddButton("Dump Hub State (F9)", function()
        M.dumpHubState()
    end)

    devTab:AddToggle("Verbose Notify -> F9", false, function(v)
        S.devVerboseNotify = v
    end)

    devTab:AddToggle("Physics Trace -> F9", false, function(v)
        S.devPhysicsTrace = v
    end)

    devTab:AddToggle("Dump Physics on Farm Off", false, function(v)
        S.devPhysicsDumpOnStop = v
        _G.NexusHubDevPhysicsDumpOnStop = v == true
    end)

    M.makeSection(devTab.scroll, "Player")
    devTab:AddButton("Print Player Info", function()
        local hrp = HumanoidRootPart
        local lines = {
            "UserId: " .. tostring(Player.UserId),
            "Level: " .. tostring(M.getPlayerLevel() or "?"),
            "Beli: " .. tostring(M.getPlayerBeli() or "?"),
            "PlaceId: " .. tostring(game.PlaceId),
            "Sea: " .. tostring(M.getCurrentSea()),
            "Health: " .. tostring(Humanoid and Humanoid.Health or "?"),
            "WalkSpeed: " .. tostring(Humanoid and Humanoid.WalkSpeed or "?"),
            "Position: " .. tostring(hrp and hrp.Position or "?"),
            "HasBuso char tag: " .. tostring(Character and Character:FindFirstChild("HasBuso") ~= nil),
            "Has Ken: " .. tostring(M.hasKen and M.hasKen() or "?"),
            "CommE resolved: " .. tostring(M.getCommE() ~= nil),
        }
        M.debugLog("Player Info", lines)
    end)

    devTab:AddButton("Print Position / CFrame", function()
        local hrp = HumanoidRootPart
        if not hrp then
            M.notify("Dev", "No HumanoidRootPart", 3)
            return
        end

        M.debugLog("Position", {
            "Position: " .. tostring(hrp.Position),
            "CFrame: " .. tostring(hrp.CFrame),
        })
    end)

    M.makeSection(devTab.scroll, "Quest")
    devTab:AddButton("Print Active Quest", function()
        local gui = Player:FindFirstChild("PlayerGui")
        local mainGui = gui and gui:FindFirstChild("Main")
        local questFrame = mainGui and mainGui:FindFirstChild("Quest")
        local hasQuest, enemy, cur, tot = M.readActiveQuest(questFrame)
        local best = M.findBestQuestForLevel(M.getPlayerLevel() or 1)
        local lines = {
            "HasQuestUI: " .. tostring(hasQuest),
            "ActiveEnemy: " .. tostring(enemy or "none"),
            "Progress: " .. tostring(cur) .. " / " .. tostring(tot),
            "BestQuest: " .. tostring(best and best.Name or "none"),
            "Cached S.questInfo: " .. tostring(S.questInfo and S.questInfo.Name or "nil"),
            "_G.NexusHubQuestInProgress: " .. tostring(_G.NexusHubQuestInProgress and _G.NexusHubQuestInProgress() or "?"),
            "_G.NexusHubQuestInfo enemy: " .. tostring(_G.NexusHubQuestInfo and _G.NexusHubQuestInfo.enemy or "nil"),
        }
        M.debugLog("Quest", lines)
    end)

    devTab:AddButton("Refresh Quest Cache", function()
        S.questInfo = M.getQuest({ travel = true })
        M.setQuestInfoCache(S.questInfo)
        M.notify("Dev", "questInfo = " .. tostring(S.questInfo and S.questInfo.Name or "nil"), 4)
    end)

    devTab:AddButton("Abandon Quest", function()
        pcall(function() CommF_:InvokeServer("AbandonQuest") end)
        M.setQuestInfoCache(nil)
        M.notify("Dev", "AbandonQuest sent", 3)
    end)

    devTab:AddButton("Try Accept Quest Now", function()
        _G.NexusHubLastQuestInvoke = 0
        pcall(_G.NexusHubRefreshQuestCache)
        M.ensureAutofarmQuest()
        local qi = M.getQuestInfoCache()
        M.dumpFarmGlobals()
        local args = qi and qi.args
        M.notify("Dev", ("StartQuest %s %s %s"):format(
            tostring(args and args[1]), tostring(args and args[2]), tostring(args and args[3])), 5)
    end)

    devTab:AddButton("Print Quest Globals", function()
        M.dumpFarmGlobals()
    end)

    M.makeSection(devTab.scroll, "Farm / Physics")
    devTab:AddButton("Print Security Notes", function()
        M.debugLog("Security", {
            "High risk when enabled: quest farm move, noclip, combat orbit, island TPToLink",
            "Medium: RegisterHit/RegisterAttack (auto attack)",
            "Anti AFK: Idled VirtualUser + idle sanitizer + 17min VIM heartbeat (no timer spam)",
            "Removed: CommF_:FireServer calls (invalid on RemoteFunction)",
            "Move caps: TravelSpeed=" .. tostring(_G.NexusHubTravelSpeed) .. " Max=" .. tostring(_G.NexusHubMaxMoveSpeed),
        })
    end)

    devTab:AddButton("Print Movement State", function()
        M.dumpMovementState()
    end)

    devTab:AddButton("Print Physics State", function()
        M.dumpPhysicsState()
    end)

    devTab:AddButton("Force Physics Reset", function()
        _G.NexusHubSanitizePhysics()
        M.dumpPhysicsState()
    end)

    devTab:AddButton("Force Stop Autofarm", function()
        _G.NexusHubStopAutofarm()
        M.stopAutofarm()
        M.dumpFarmGlobals()
        M.dumpPhysicsState()
    end)

    devTab:AddButton("Print Farm Globals", function()
        M.dumpFarmGlobals()
    end)

    devTab:AddButton("Print Quest Spawn Points", function()
        local qi = _G.NexusHubQuestInfo or M.getQuestInfoCache()
        local enemy = qi and qi.enemy or "?"
        local island = qi and qi.island or "?"
        local lines = {
            "enemy = " .. tostring(enemy),
            "island = " .. tostring(island),
            "onIsland = " .. tostring(island ~= "?" and M.isOnIsland(island) or false),
            "needsSpawnTravel = " .. tostring(M.needsQuestSpawnTravel(enemy, island)),
        }
        local points = M.getEnemySpawnPoints(enemy, island)
        table.insert(lines, "spawn points: " .. tostring(#points))
        for i = 1, math.min(#points, 8) do
            table.insert(lines, ("  [%d] %s"):format(i, tostring(points[i])))
        end

        local live = M.getLiveEnemySpawnHints(enemy)
        table.insert(lines, "live enemy hints: " .. tostring(#live))
        M.debugLog("Spawn Points", lines)
    end)

    M.makeSection(devTab.scroll, "World")
    devTab:AddButton("Print Nearby Enemies", function()
        local lines = {}
        local enemies = Workspace:FindFirstChild("Enemies")
        local count = enemies and #enemies:GetChildren() or 0
        table.insert(lines, "Total Enemies folder children: " .. tostring(count))
        if enemies and HumanoidRootPart then
            local nearby = {}
            for _, npc in ipairs(enemies:GetChildren()) do
                local hum = npc:FindFirstChildOfClass("Humanoid")
                local hrp = npc:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    local d = (HumanoidRootPart.Position - hrp.Position).Magnitude
                    if d <= 200 then
                        table.insert(nearby, { npc.Name, math.floor(d) })
                    end
                end
            end

            table.sort(nearby, function(a, b) return a[2] < b[2] end)
            for i = 1, math.min(#nearby, 15) do
                table.insert(lines, ("  %s (%dm)"):format(nearby[i][1], nearby[i][2]))
            end
        end

        M.debugLog("Enemies", lines)
    end)

    devTab:AddButton("Print Boat Info", function()
        local lines = {}
        local boatsFolder = Workspace:FindFirstChild("Boats")
        table.insert(lines, "Workspace.Boats: " .. tostring(boatsFolder ~= nil))
        if boatsFolder then
            for _, b in ipairs(boatsFolder:GetChildren()) do
                local owner = b:FindFirstChild("Owner")
                table.insert(lines, ("  %s | Owner=%s"):format(b.Name, owner and tostring(owner.Value) or "?"))
            end
        end

        table.insert(lines, "M.getMyBoat() => " .. tostring(M.getMyBoat() and M.getMyBoat().Name or "nil"))
        M.debugLog("Boats", lines)
    end)

    devTab:AddButton("List Remotes", function()
        local lines = {}
        if Remotes then
            for _, child in ipairs(Remotes:GetChildren()) do
                table.insert(lines, child.Name .. " (" .. child.ClassName .. ")")
            end
        else
            table.insert(lines, "Remotes folder missing")
        end

        M.debugLog("Remotes", lines)
    end)

    M.makeSection(devTab.scroll, "Remote Tests")
    devTab:AddButton("Test CommF_ Ping (Bones Check)", function()
        local ok, res = pcall(function()
            return CommF_:InvokeServer("Bones", "Check")
        end)

        M.debugLog("Bones Check", {
            "ok: " .. tostring(ok),
            "result: " .. tostring(res),
        })
    end)

    devTab:AddButton("Print Sea Danger Level", function()
        M.debugLog("Sea Danger", {
            "getSeaDangerLevel(): " .. tostring(M.getSeaDangerLevel()),
            "cachedSeaDanger: " .. tostring(S.cachedSeaDanger),
        })
    end)

    M.makeSection(devTab.scroll, "UI")
    devTab:AddButton("Reload UI", function()
        M.reloadUI()
    end)

    devTab:AddButton("Exit Dev Mode", function()
        _G.NexusHubDevMode = false
        S.devVerboseNotify = false
        S.devPhysicsTrace = false
        S.devPhysicsDumpOnStop = false
        _G.NexusHubDevPhysicsDumpOnStop = false
        M.reloadUI()
    end)

    if Player.Name == BETA_OWNER then
        M.makeSection(devTab.scroll, "Owner")
        devTab:AddButton("List Beta Accounts (F9)", function()
            local lines = {}
            for name, account in pairs(BETA_ACCOUNTS) do
                table.insert(lines, name .. " | devKey=" .. tostring(account.devKey))
            end

            M.debugLog("Beta Accounts", lines)
        end)
    end
end

_G.NexusHubFarmHoverY = S.farmHoverY
local Bosses = {
    [27539155] = {
        {Name = "The Gorilla King", Island = "Jungle", Level = 20, Args = {"StartQuest", "JungleQuest", 3}},
        {Name = "Bobby", Island = "Pirate", Level = 55, Args = {"StartQuest", "BuggyQuest1", 3}},
        {Name = "The Saw", Island = "Pirate", Level = 100, Args = {"StartQuest", "SharkQuest", 1}},
        {Name = "Yeti", Island = "Ice", Level = 110, Args = {"StartQuest", "SnowQuest", 3}},
        {Name = "Vice Admiral", Island = "MarineBase", Level = 130, Args = {"StartQuest", "MarineQuest2", 2}},
        {Name = "Warden", Island = "Prison", Level = 220, Args = {"StartQuest", "WardenQuest", 1}},
        {Name = "Chief Warden", Island = "Prison", Level = 230, Args = {"StartQuest", "WardenQuest", 2}},
        {Name = "Swan", Island = "Prison", Level = 240, Args = {"StartQuest", "WardenQuest", 3}},
        {Name = "Magma Admiral", Island = "Magma", Level = 350, Args = {"StartQuest", "MagmaQuest", 3}},
        {Name = "Fishman Lord", Island = "Fishmen", Level = 425, Args = {"StartQuest", "FishmanQuest", 3}},
        {Name = "Wysper", Island = "SkyArea1", Level = 500, Args = {"StartQuest", "SkyExp1Quest", 3}},
        {Name = "Thunder God", Island = "SkyArea2", Level = 575, Args = {"StartQuest", "SkyExp2Quest", 3}},
        {Name = "Cyborg", Island = "Fountain", Level = 675, Args = {"StartQuest", "FountainQuest", 3}},
    },
    [4442272183] = {
        {Name = "Diamond", Island = "Kingdom of Rose", Level = 750, Args = {"StartQuest", "Area1Quest", 3}},
        {Name = "Jeremy", Island = "Kingdom of Rose", Level = 850, Args = {"StartQuest", "Area2Quest", 3}},
        {Name = "Fajita", Island = "Green Bit", Level = 925, Args = {"StartQuest", "MarineQuest3", 3}},
        {Name = "Don Swan", Island = "Mansion", Level = 1000, Args = {"StartQuest", "SwanQuest", 1}},
        {Name = "Smoke Admiral", Island = "Hot and Cold", Level = 1150, Args = {"StartQuest", "IceSideQuest", 3}},
        {Name = "Tide Keeper", Island = "Forgotten Island", Level = 1475, Args = {"StartQuest", "ForgottenQuest", 3}},
    },
    [7449925010] = {
        {Name = "Stone", Island = "Port Town", Level = 1550, Args = {"StartQuest", "PiratePortQuest", 3}},
        {Name = "Island Empress", Island = "Hydra Island", Level = 1675, Args = {"StartQuest", "VenomCrewQuest", 3}},
        {Name = "Kilo Admiral", Island = "Great Tree", Level = 1750, Args = {"StartQuest", "MarineTreeIsland", 3}},
        {Name = "Captain Elephant", Island = "Floating Turtle", Level = 1875, Args = {"StartQuest", "DeepForestIsland", 3}},
        {Name = "Beautiful Pirate", Island = "Floating Turtle", Level = 1950, Args = {"StartQuest", "DeepForestIsland2", 3}},
        {Name = "Cake Queen", Island = "Sea of Treats", Level = 2175, Args = {"StartQuest", "IceCreamIslandQuest", 3}},
    }
}
for _, pid in ipairs({2753915549, 85211729168715}) do Bosses[pid] = Bosses[27539155] end
for _, pid in ipairs({79091703265657}) do Bosses[pid] = Bosses[4442272183] end
for _, pid in ipairs({7449423635, 100117331123089}) do Bosses[pid] = Bosses[7449925010] end

function M.getCurrentBosses()
    return Bosses[game.PlaceId] or {}
end

local BOSS_NAME_SET = {}

function M.rebuildBossNameSet()
    BOSS_NAME_SET = {}
    for _, list in pairs(Bosses) do
        if type(list) == "table" and list[1] and type(list[1]) == "table" and list[1].Name then
            for _, b in ipairs(list) do
                BOSS_NAME_SET[b.Name] = true
                BOSS_NAME_SET[b.Name:gsub("%s+", "")] = true
            end
        end
    end
end

M.rebuildBossNameSet()
Player.CharacterAdded:Connect(function(c)
    Character        = c
    Humanoid         = c:WaitForChild("Humanoid")
    HumanoidRootPart = c:WaitForChild("HumanoidRootPart")
    S.cachedMyBoat     = nil
    S.farmMoveGoal     = nil
    S.farmMoveCFrame   = nil
    S.farmMoveToken    = nil
    S.ActiveTween      = nil
    _G.NexusHubClearMoveGoal()
    if _G.NexusHubAutofarm ~= true then
        pcall(M.restoreCharacterPhysics)
    end

    if _G.NexusHubAutofarm == true or S.autoAttack then
        task.defer(function()
            task.wait(0.35)
            if M.equipWeapon then pcall(M.equipWeapon) end
        end)
    end

    if S.autoBuso then
        task.defer(function()
            task.wait(0.5)
            pcall(M.enableBuso)
        end)
    end

    if S.autoInstinct then
        task.defer(function()
            task.wait(0.5)
            pcall(M.tickAutoInstinct)
        end)
    end

    if S.autoThirdSea and S.thirdSeaIndraWasFighting then
        S.thirdSeaIndraWasFighting = false
        task.defer(function()
            task.wait(0.15)
            if M.onThirdSeaRipIndraPlayerDied then
                pcall(M.onThirdSeaRipIndraPlayerDied)
            end
        end)
    end

    local hl = Instance.new("Highlight")
    hl.Name = "NexusHubHighlight"
    hl.Parent    = Character
    hl.FillColor = Color3.fromRGB(130, 80, 220)
    hl.DepthMode = Enum.HighlightDepthMode.Occluded
end)

local Quests = {}
do

    local function compileQuestSource(src)
        if not src or src == "" then return nil end
        local okCompile, fn = pcall(_G.NexusHubCompile, src, "NexusHubQuest")
        if not okCompile or not fn then return nil end
        return fn()
    end

    local ok, data = pcall(function()
        local urls = {
            "https://raw.githubusercontent.com/deexfricking/getquestnewupdate/refs/heads/main/getquest.lua",
            "https://cdn.jsdelivr.net/gh/deexfricking/getquestnewupdate@main/getquest.lua",
        }
        for _, url in ipairs(urls) do
            local src = _G.NexusHubHttpGet(url)
            local parsed = compileQuestSource(src)
            if type(parsed) == "table" then return parsed end
        end

        if readfile then
            for _, path in ipairs({ "getquest.lua", "quests.lua", "NexusHub/getquest.lua" }) do
                local rfOk, src = pcall(readfile, path)
                if rfOk then
                    local parsed = compileQuestSource(src)
                    if type(parsed) == "table" then return parsed end
                end
            end
        end

        return nil
    end)

    if ok and type(data) == "table" then
        if data.LevelReq or data.Task or data.Args or data.Name then
            Quests = { FallbackQuest = { data } }
        else
            Quests = data
        end
    else
        Quests = {
            BanditQuest1 = {{
                LevelReq = 0, Name = "Bandits", Task = { Bandit = 5 },
                Args = { "StartQuest", "BanditQuest1", 1 },
            }},
            MarineQuest = {{
                LevelReq = 0, Name = "Trainees", Task = { Trainee = 5 },
                Args = { "StartQuest", "MarineQuest", 1 },
            }},
            JungleQuest = {
                { LevelReq = 10, Name = "Monkeys", Task = { Monkey = 6 }, Args = { "StartQuest", "JungleQuest", 1 } },
                { LevelReq = 15, Name = "Gorillas", Task = { Gorilla = 8 }, Args = { "StartQuest", "JungleQuest", 2 } },
            },
            BuggyQuest1 = {
                { LevelReq = 30, Name = "Pirates", Task = { Pirate = 8 }, Args = { "StartQuest", "BuggyQuest1", 1 } },
                { LevelReq = 40, Name = "Brute", Task = { Brute = 8 }, Args = { "StartQuest", "BuggyQuest1", 2 } },
            },
            DesertQuest = {
                { LevelReq = 60, Name = "Desert Bandit", Task = { ["Desert Bandit"] = 8 }, Args = { "StartQuest", "DesertQuest", 1 } },
                { LevelReq = 75, Name = "Desert Officer", Task = { ["Desert Officer"] = 6 }, Args = { "StartQuest", "DesertQuest", 2 } },
            },
            SnowQuest = {
                { LevelReq = 90, Name = "Snow Bandit", Task = { ["Snow Bandit"] = 7 }, Args = { "StartQuest", "SnowQuest", 1 } },
                { LevelReq = 100, Name = "Snowman", Task = { Snowman = 8 }, Args = { "StartQuest", "SnowQuest", 2 } },
            },
            MarineQuest2 = {{
                LevelReq = 120, Name = "Chief Petty Officer", Task = { ["Chief Petty Officer"] = 8 },
                Args = { "StartQuest", "MarineQuest2", 1 },
            }},
            SkyQuest = {
                { LevelReq = 150, Name = "Sky Bandit", Task = { ["Sky Bandit"] = 7 }, Args = { "StartQuest", "SkyQuest", 1 } },
                { LevelReq = 175, Name = "Dark Master", Task = { ["Dark Master"] = 8 }, Args = { "StartQuest", "SkyQuest", 2 } },
            },
            PrisonerQuest = {
                { LevelReq = 190, Name = "Prisoner", Task = { Prisoner = 8 }, Args = { "StartQuest", "PrisonerQuest", 1 } },
                { LevelReq = 210, Name = "Dangerous Prisoner", Task = { ["Dangerous Prisoner"] = 8 }, Args = { "StartQuest", "PrisonerQuest", 2 } },
            },
            ColosseumQuest = {
                { LevelReq = 250, Name = "Toga Warrior", Task = { ["Toga Warrior"] = 7 }, Args = { "StartQuest", "ColosseumQuest", 1 } },
                { LevelReq = 275, Name = "Gladiator", Task = { Gladiator = 8 }, Args = { "StartQuest", "ColosseumQuest", 2 } },
            },
            MagmaQuest = {
                { LevelReq = 300, Name = "Mil. Soldier", Task = { ["Military Soldier"] = 7 }, Args = { "StartQuest", "MagmaQuest", 1 } },
                { LevelReq = 325, Name = "Mil. Spy", Task = { ["Military Spy"] = 8 }, Args = { "StartQuest", "MagmaQuest", 2 } },
            },
            FishmanQuest = {
                { LevelReq = 375, Name = "Fishman Warrior", Task = { ["Fishman Warrior"] = 8 }, Args = { "StartQuest", "FishmanQuest", 1 } },
                { LevelReq = 400, Name = "Fishman Commando", Task = { ["Fishman Commando"] = 7 }, Args = { "StartQuest", "FishmanQuest", 2 } },
            },
            Area1Quest = {
                { LevelReq = 700, Name = "Raider", Task = { Raider = 8 }, Args = { "StartQuest", "Area1Quest", 1 } },
                { LevelReq = 725, Name = "Mercenary", Task = { Mercenary = 8 }, Args = { "StartQuest", "Area1Quest", 2 } },
            },
            Area2Quest = {
                { LevelReq = 775, Name = "Swan Pirate", Task = { ["Swan Pirate"] = 8 }, Args = { "StartQuest", "Area2Quest", 1 } },
                { LevelReq = 800, Name = "Factory Staff", Task = { ["Factory Staff"] = 8 }, Args = { "StartQuest", "Area2Quest", 2 } },
            },
            PiratePortQuest = {
                { LevelReq = 1500, Name = "Pirate Millionaire", Task = { ["Pirate Millionaire"] = 8 }, Args = { "StartQuest", "PiratePortQuest", 1 } },
                { LevelReq = 1525, Name = "Pistol Billionaire", Task = { ["Pistol Billionaire"] = 8 }, Args = { "StartQuest", "PiratePortQuest", 2 } },
            },
        }
    end
end

local islandNames = {
    BanditQuest1   = "Windmill",  MarineQuest    = "MarineStart",
    JungleQuest    = "Jungle",    BuggyQuest1    = "Pirate",
    BuggyQuest2    = "Pirate",    DesertQuest    = "Desert",
    SnowQuest      = "Ice",       MarineQuest2   = "MarineBase",
    SkyQuest       = "Sky",       SkyQuest2      = "Sky",
    PrisonerQuest  = "Prison",    ImpelQuest     = "Prison",
    ColosseumQuest = "Colosseum", MagmaQuest     = "Magma",
    FishmanQuest   = "Fishmen",   SkyExp1Quest   = "SkyArea1",
    SkyExp2Quest   = "SkyArea2",  FountainQuest  = "Fountain",
    Area1Quest     = "Kingdom of Rose", Area2Quest = "Kingdom of Rose",
    MarineQuest3   = "Green Bit",       SwanQuest  = "Mansion",
    IceSideQuest   = "Hot and Cold",    FireSideQuest = "Hot and Cold",
    ZombieQuest    = "Graveyard",       ForgottenQuest = "Forgotten Island",
    SnowMountainQuest = "Hot and Cold", ShipQuest1 = "Cursed Ship",
    ShipQuest2     = "Cursed Ship",     FrostQuest = "Hot and Cold",
    PiratePortQuest = "Port Town",      VenomCrewQuest = "Hydra Island",
    DragonCrewQuest = "Hydra Island",   MarineTreeIsland = "Great Tree",
    DeepForestIsland = "Floating Turtle", DeepForestIsland2 = "Floating Turtle",
    DeepForestIsland3 = "Floating Turtle", IceCreamIslandQuest = "Sea of Treats",
    HauntedQuest1  = "Haunted Castle",  HauntedQuest2 = "Haunted Castle",
    NutsIslandQuest = "Peanut Island",  CakeQuest1 = "Sea of Treats",
    CakeQuest2     = "Sea of Treats",   ChocQuest1 = "Sea of Treats",
    ChocQuest2     = "Sea of Treats",  CandyQuest1 = "Sea of Treats",
    TikiQuest1     = "Tiki Outpost",    TikiQuest2 = "Tiki Outpost",
    TikiQuest3     = "Tiki Outpost",    SubmergedQuest1 = "Submerged Island",
    SubmergedQuest2 = "Submerged Island", SubmergedQuest3 = "Submerged Island",
}
_G.NexusHubQuests = Quests
_G.NexusHubIslands = islandNames

function _G.NexusHubLocalPlayer()
    return game:GetService("Players").LocalPlayer
end

function _G.NexusHubIsMarineTeam()
    local plr = _G.NexusHubLocalPlayer()
    if not plr then return false end
    if plr.Team then
        local n = plr.Team.Name:lower()
        if n:find("marine") then
            _G.NexusHubCachedMarineTeam = true
            return true
        end

        if n:find("pirate") then
            _G.NexusHubCachedMarineTeam = false
            return false
        end
    end

    if _G.NexusHubCachedMarineTeam ~= nil then
        return _G.NexusHubCachedMarineTeam
    end

    local data = plr:FindFirstChild("Data")
    if data then
        local teamVal = data:FindFirstChild("Team") or data:FindFirstChild("Faction")
        if teamVal then
            local v = tostring(teamVal.Value):lower()
            if v:find("marine") then
                _G.NexusHubCachedMarineTeam = true
                return true
            end

            if v:find("pirate") then
                _G.NexusHubCachedMarineTeam = false
                return false
            end
        end

        for _, c in ipairs(data:GetChildren()) do
            local cn = c.Name:lower()
            if cn:find("team") or cn:find("faction") then
                local v = tostring(c.Value):lower()
                if v:find("marine") then
                    _G.NexusHubCachedMarineTeam = true
                    return true
                end

                if v:find("pirate") then
                    _G.NexusHubCachedMarineTeam = false
                    return false
                end
            end
        end
    end

    if _G.NexusHubCachedMarineTeam == nil then
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local map = Workspace:FindFirstChild("Map")
        if hrp and map then
            local marine = map:FindFirstChild("MarineStart") or map:FindFirstChild("Marine")
            local windmill = map:FindFirstChild("Windmill") or map:FindFirstChild("Jungle")

            local function nearFolder(folder, dist)
                if not folder then return false end
                local p = folder:FindFirstChildWhichIsA("BasePart", true)
                    or folder:FindFirstChildWhichIsA("MeshPart", true)
                return p and (hrp.Position - p.Position).Magnitude <= (dist or 900)
            end

            if nearFolder(marine, 900) then
                _G.NexusHubCachedMarineTeam = true
                return true
            end

            if nearFolder(windmill, 1200) then
                _G.NexusHubCachedMarineTeam = false
                return false
            end
        end
    end

    return false
end

function _G.NexusHubQuestIslandAvailable(questKey)
    if questKey == "ShipQuest1" or questKey == "ShipQuest2" then
        if M and M.getCurrentSea and M.getCurrentSea() == "Sea 2" then
            return true
        end
    end

    local islands = _G.NexusHubIslands
    if type(islands) ~= "table" then return true end
    local island = islands[questKey]
    if not island or island == "" then return true end
    if M and M.islandInCurrentMap then
        return M.islandInCurrentMap(island)
    end

    return true
end

function _G.NexusHubSkipQuestKey(questKey)
    if questKey == "MarineQuest" and not _G.NexusHubIsMarineTeam() then return true end
    if questKey == "BanditQuest1" and _G.NexusHubIsMarineTeam() then return true end
    return false
end

function _G.NexusHubGetLevel()
    local plr = _G.NexusHubLocalPlayer()
    local data = plr and plr:FindFirstChild("Data")
    local level = data and data:FindFirstChild("Level")
    if level and tonumber(level.Value) and level.Value > 0 then
        return level.Value
    end

    local ls = plr and plr:FindFirstChild("leaderstats")
    if ls then
        local lv = ls:FindFirstChild("Level") or ls:FindFirstChild("level")
        if lv and tonumber(lv.Value) then
            return lv.Value
        end
    end

    return level and level.Value or 0
end

function _G.NexusHubEnemyFromQuest(quest)
    if not quest then return nil end
    if type(quest.Task) == "table" then
        for name, _ in pairs(quest.Task) do
            if type(name) == "string" and name ~= "" then return name end
        end
    end

    return quest.Name
end

function _G.NexusHubGetSeaQuestBounds()
    local sea = "Sea 1"
    if M and M.getCurrentSea then
        sea = M.getCurrentSea()
    end

    if sea == "Sea 2" then
        return 700, 1500
    end

    if sea == "Sea 3" then
        return 1500, math.huge
    end

    return 0, 699
end

function _G.NexusHubForEachQuest(callback)
    if type(callback) ~= "function" then return end
    local quests = _G.NexusHubQuests
    if type(quests) ~= "table" then return end
    for questKey, questList in pairs(quests) do
        if type(questKey) == "string" and type(questList) == "table" then
            local listed = false
            for index, quest in ipairs(questList) do
                if type(quest) == "table" then
                    listed = true
                    callback(questKey, quest, index)
                end
            end

            if not listed and (questList.LevelReq or questList.Task or questList.Args or questList.Name) then
                callback(questKey, questList, 1)
            end
        end
    end
end

function _G.NexusHubBuildQuestArgs(quest, key, index)
    index = index or 1
    key = key or ""
    if type(quest) ~= "table" then
        return { "StartQuest", key, index }
    end

    local args = quest.Args
    if type(args) == "table" then
        local a1, a2, a3 = args[1], args[2], args[3]
        if a1 ~= nil then
            return { a1, a2, a3 }
        end
    end

    return { "StartQuest", key, index }
end

function _G.NexusHubPickQuest(level, opts)
    opts = opts or {}
    local bestQuest, bestKey, bestIndex, bestLevel = nil, nil, 0, -1
    local quests = _G.NexusHubQuests
    if type(quests) ~= "table" then return nil, nil, nil end
    local seaMin, seaMax = 0, math.huge
    if not opts.ignoreSea or opts.sameSeaOnly then
        seaMin, seaMax = _G.NexusHubGetSeaQuestBounds()
    end

    local checkIsland = not opts.ignoreIsland
    _G.NexusHubForEachQuest(function(questKey, quest, index)
        if not _G.NexusHubSkipQuestKey(questKey)
            and (not checkIsland or _G.NexusHubQuestIslandAvailable(questKey))
            and level >= (quest.LevelReq or 0) then
            local req = quest.LevelReq or 0
            if req >= seaMin and req <= seaMax then
                if req > bestLevel or (req == bestLevel and index > bestIndex) then
                    bestQuest = quest
                    bestKey = questKey
                    bestIndex = index
                    bestLevel = req
                end
            end
        end
    end)

    if not bestQuest and not opts.ignoreSea then
        return _G.NexusHubPickQuest(level, {
            ignoreSea = true,
            sameSeaOnly = true,
            ignoreIsland = opts.ignoreIsland,
        })
    end

    if not bestQuest and not opts.ignoreIsland then
        return _G.NexusHubPickQuest(level, {
            ignoreSea = opts.ignoreSea,
            sameSeaOnly = opts.sameSeaOnly or not opts.ignoreSea,
            ignoreIsland = true,
        })
    end

    return bestQuest, bestKey, bestIndex
end

function _G.NexusHubGetActiveQuestLevelReq(level)
    local plr = _G.NexusHubLocalPlayer()
    local gui = plr and plr:FindFirstChild("PlayerGui")
    local main = gui and gui:FindFirstChild("Main")
    local questFrame = main and main:FindFirstChild("Quest")
    if not questFrame or not questFrame.Visible then return nil end
    local title = ""
    pcall(function()
        local container = questFrame:FindFirstChild("Container")
        local titleFrame = container and container:FindFirstChild("QuestTitle")
        local titleLabel = titleFrame and titleFrame:FindFirstChild("Title")
        if titleLabel and titleLabel:IsA("TextLabel") then
            title = titleLabel.Text or ""
        end
    end)

    local activeEnemy = nil
    if title ~= "" then
        local lower = title:lower()
        if lower:find("complete") and not lower:find("incomplete") then
            return nil
        end

        activeEnemy = title:match("Defeat%s+%d+%s+(.+)%s+%(%d+/%d+%)")
            or title:match("Kill%s+%d+%s+(.+)%s+%(%d+/%d+%)")
            or title:match("Defeat%s+(.+)%s+%(%d+/%d+%)")
            or title:match("Kill%s+(.+)%s+%(%d+/%d+%)")
            or title:match("Defeat%s+%d+%s+(.+)")
            or title:match("Kill%s+%d+%s+(.+)")
            or title:match("Defeat%s+(.+)")
            or title:match("Kill%s+(.+)")
        if activeEnemy then
            activeEnemy = activeEnemy:gsub("^%s+", ""):gsub("%s+$", "")
        end
    end

    if not activeEnemy or activeEnemy == "" then
        local container = questFrame:FindFirstChild("Container")
        if container then
            for _, label in ipairs(container:GetDescendants()) do
                if label:IsA("TextLabel") then
                    local text = label.Text or ""
                    if text:find("Defeat") or text:find("Kill") then
                        activeEnemy = text:match("Defeat%s+%d+%s+(.+)%s+%(%d+/%d+%)")
                            or text:match("Kill%s+%d+%s+(.+)%s+%(%d+/%d+%)")
                            or text:match("Defeat%s+(.+)%s+%(%d+/%d+%)")
                            or text:match("Kill%s+(.+)%s+%(%d+/%d+%)")
                            or text:match("Defeat%s+%d+%s+(.+)")
                            or text:match("Kill%s+%d+%s+(.+)")
                        if activeEnemy then
                            activeEnemy = activeEnemy:gsub("^%s+", ""):gsub("%s+$", "")
                            break
                        end
                    end
                end
            end
        end
    end

    if not activeEnemy or activeEnemy == "" then return nil end
    local compact = activeEnemy:lower():gsub("%s+", "")
    if type(_G.NexusHubQuests) ~= "table" then return nil end
    local bestReq = nil
    _G.NexusHubForEachQuest(function(questKey, quest, index)
        if not _G.NexusHubSkipQuestKey(questKey) and level >= (quest.LevelReq or 0) then
            local qEnemy = _G.NexusHubEnemyFromQuest(quest)
            if qEnemy then
                local qCompact = qEnemy:lower():gsub("%s+", "")
                if qCompact == compact or qCompact:find(compact, 1, true) or compact:find(qCompact, 1, true) then
                    local req = quest.LevelReq or 0
                    if not bestReq or req > bestReq then
                        bestReq = req
                    end
                end
            end
        end
    end)

    return bestReq
end

function _G.NexusHubQuestInProgress()
    local plr = _G.NexusHubLocalPlayer()
    local gui = plr and plr:FindFirstChild("PlayerGui")
    local main = gui and gui:FindFirstChild("Main")
    local questFrame = main and main:FindFirstChild("Quest")
    if not questFrame or not questFrame.Visible then
        return false
    end

    local title = ""
    pcall(function()
        local container = questFrame:FindFirstChild("Container")
        local titleFrame = container and container:FindFirstChild("QuestTitle")
        local titleLabel = titleFrame and titleFrame:FindFirstChild("Title")
        if titleLabel and titleLabel:IsA("TextLabel") then
            title = titleLabel.Text or ""
        end
    end)

    if title ~= "" then
        local cur, tot = title:match("%((%d+)/(%d+)%)")
        cur, tot = tonumber(cur), tonumber(tot)
        if cur and tot then
            return cur < tot
        end
    end

    local sawQuest = false
    local progressCur, progressTot
    local container = questFrame:FindFirstChild("Container")
    if container then
        for _, label in ipairs(container:GetDescendants()) do
            if label:IsA("TextLabel") then
                local text = label.Text or ""
                local lower = text:lower()
                if lower:find("complete") and not lower:find("incomplete") then
                    return false
                end

                if text:find("Defeat") or text:find("Kill") then
                    sawQuest = true
                    local cur, tot = text:match("%((%d+)/(%d+)%)")
                    if cur and tot then
                        progressCur = tonumber(cur)
                        progressTot = tonumber(tot)
                    end
                end
            end
        end
    end

    if sawQuest and progressCur and progressTot then
        return progressCur < progressTot
    end

    return false
end

function _G.NexusHubInvokeQuest(args)
    if M and M.fireStartQuest then
        return M.fireStartQuest(args)
    end

    if type(args) ~= "table" then return false end
    local a1, a2, a3 = args[1], args[2], args[3]
    if a1 == nil then return false end
    local remote = M.getCommFRemote and M.getCommFRemote() or _G.NexusHubCommF or CommF_
    if not remote then return false end
    return pcall(function()
        if a3 ~= nil then
            remote:InvokeServer(a1, a2, tonumber(a3) or a3)
        elseif a2 ~= nil then
            remote:InvokeServer(a1, a2)
        else
            remote:InvokeServer(a1)
        end
    end)
end

function _G.NexusHubRefreshQuestCache()
    local level = _G.NexusHubGetLevel()
    if level <= 0 then return nil end
    local existing = M and M.getQuestInfoCache and M.getQuestInfoCache()
    if existing and existing.enemy and M.getQuestFrameVisible and M.getQuestFrameVisible()
        and M.hasActiveQuestProgress and M.hasActiveQuestProgress()
        and not (M.needsNewQuest and M.needsNewQuest()) then
        local staleTier = M.shouldUpgradeQuest and M.shouldUpgradeQuest(level)
        if not staleTier then
            local title = M.getQuestTitleTextDirect and M.getQuestTitleTextDirect() or ""
            local uiEnemy = title ~= "" and select(1, M.parseQuestLabel(title)) or nil
            if not uiEnemy or uiEnemy == "" or M.fuzzyEnemyMatch(uiEnemy, existing.enemy) then
                return existing
            end
        end
    end

    if M and M.getQuest then
        local info = M.getQuest()
        if info and info.enemy and info.args then
            M.applyQuestInfoToCache(info)
            return M.getQuestInfoCache()
        end
    end

    local quest, key, index = _G.NexusHubPickQuest(level, { ignoreIsland = false, ignoreSea = false })
    if type(quest) ~= "table" or not key then return nil end
    local islands = _G.NexusHubIslands or {}
    local args = _G.NexusHubBuildQuestArgs(quest, key, index)
    local cache = {
        quest = quest,
        enemy = _G.NexusHubEnemyFromQuest(quest),
        island = islands[key] or key,
        questKey = key,
        questIndex = index or 1,
        levelReq = quest.LevelReq,
        args = args,
    }
    _G.NexusHubQuestInfo = cache
    pcall(function()
        if M and M.setQuestInfoCache then
            M.setQuestInfoCache(cache)
        end
    end)

    return cache
end

function _G.NexusHubTryAcceptQuest()
    if _G.NexusHubAutofarm ~= true then return end
    if _G.NexusHubAutoSecondSea == true or _G.NexusHubAutoThirdSea == true then return end
    if M.isFactoryRaidEngaged() or M.isCursedCaptainEngaged() or M.isFruitSniperActive() then return end
    pcall(M.ensureAutofarmQuest)
end

function _G.NexusHubRestorePhysics()
    _G.NexusHubCancelMove()
    _G.NexusHubSanitizePhysics()
end

function _G.NexusHubStopAutofarm()
    _G.NexusHubAutofarm = false
    pcall(function() S.autofarm = false end)
    _G.NexusHubQuestInfo = nil
    _G.NexusHubCancelMove()
    pcall(function() M.restoreCharacterPhysics() end)
    if _G.NexusHubDevTrace then
        _G.NexusHubDevTrace("autofarm", "stopped")
    end

    if _G.NexusHubDevPhysicsDumpOnStop and M and M.dumpPhysicsState then
        task.defer(function()
            M.dumpPhysicsState()
            M.dumpMovementState()
        end)
    end
end

function _G.NexusHubSetAutofarm(on)
    if on then
        _G.NexusHubAutofarm = true
        S.autofarm = true
        _G.NexusHubLastQuestInvoke = 0
        _G.NexusHubLastTravelNudge = 0
        _G.NexusHubQuestHiddenSince = nil
        M.clearQuestFarmAnchor()
        pcall(function() M.clearFarmHoverConstraint(M.getHRP()) end)
        _G.NexusHubRefreshQuestCache()
        if M.tickAutofarmQuestLoop then
            pcall(M.tickAutofarmQuestLoop)
        else
            _G.NexusHubTryAcceptQuest()
            task.defer(_G.NexusHubTravelTick)
        end

        task.spawn(function()
            for _ = 1, 12 do
                if _G.NexusHubAutofarm ~= true then break end
                pcall(M.ensureAutofarmQuest)
                task.wait(0.85)
            end
        end)
    else
        S.autofarm = false
        _G.NexusHubStopAutofarm()
    end
end

function _G.NexusHubQuestLoopTick()
    if _G.NexusHubAutofarm ~= true then return end
    if _G.NexusHubAutoSecondSea == true or _G.NexusHubAutoThirdSea == true then return end
    if M.isFruitSniperActive() or M.isCursedCaptainEngaged() or M.isFactoryRaidEngaged() then return end
    if (S.autoDoughPrince or S.autoDoughKing) and S.doughBringMobActive then return end
    local ok, err = pcall(function()
        if M.tickAutofarmQuestLoop then
            M.tickAutofarmQuestLoop()
        else
            _G.NexusHubRefreshQuestCache()
            _G.NexusHubTryAcceptQuest()
            _G.NexusHubTravelTick()
        end
    end)

    if not ok and _G.NexusHubDevTrace then
        _G.NexusHubDevTrace("quest_loop", err)
    end
end

function M.compactEnemyKey(name)
    if not name then return "" end
    return M.normalizeEnemyName(name):lower():gsub("%s+", "")
end

function M.getEnemySpawnAliases(enemyName)
    local aliases = { enemyName }
    if not enemyName then return aliases end
    local compact = enemyName:gsub("%s+", "")
    if compact ~= enemyName then
        table.insert(aliases, compact)
    end

    local lower = enemyName:lower()
    if lower:find("galley captain") then
        table.insert(aliases, "Galley Captain")
        table.insert(aliases, "GalleyCaptain")
        table.insert(aliases, "Galley Pirate")
    elseif lower:find("galley pirate") then
        table.insert(aliases, "Galley Pirate")
        table.insert(aliases, "GalleyPirate")
    end

    return aliases
end

function M.getLiveEnemySpawnHints(enemyName)
    local points = {}
    if not enemyName or enemyName == "" then return points end
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return points end
    for _, model in ipairs(enemies:GetChildren()) do
        if model:IsA("Model") then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local dn = hum.DisplayName
                if dn == nil or dn == "" then dn = model.Name end
                if M.fuzzyEnemyMatch(dn, enemyName) or M.fuzzyEnemyMatch(model.Name, enemyName) then
                    local pos = M.getModelPosition(model)
                    if pos then table.insert(points, pos) end
                end
            end
        end
    end

    return points
end

function M.needsQuestSpawnTravel(enemyName, islandHint)
    if M.shouldBlockQuestTravel(enemyName, islandHint) then return false end
    if M.isNearFarmAnchor() then return false end
    local points = M.getEnemySpawnPoints(enemyName, islandHint)
    if #points == 0 then
        points = M.getLiveEnemySpawnHints(enemyName)
    end

    if #points == 0 then return true end
    local hrp = M.getHRP()
    if not hrp then return true end
    local nearest = math.huge
    for _, p in ipairs(points) do
        local d = M.horizontalDistance(hrp.Position, p)
        if d < nearest then nearest = d end
    end

    return nearest > (S.spawnNearHoriz + 8)
end

local ISLAND_ALIASES = {
    MarineStart = {"MarineStart", "Marine"},
    Sky = {"Sky", "SkyArea1", "SkyArea2"},
    SkyArea1 = {"SkyArea1", "Sky"},
    SkyArea2 = {"SkyArea2", "Sky"},
    Fishmen = {"Fishmen", "Fishman"},
    ["Hot and Cold"] = {"Hot and Cold", "Snow Mountain", "IceCastle"},
    ["Snow Mountain"] = {"Snow Mountain", "SnowMountain", "IceCastle"},
    ["Ice Castle"] = {"Ice Castle", "IceCastle"},
    Cafe = {"Cafe"},
    Graveyard = {"Graveyard"},
    ["Green Bit"] = {"Green Bit", "GreenBit"},
    ["Port Town"] = {"Port Town", "PortTown"},
    ["Hydra Island"] = {"Hydra Island", "Hydra"},
    ["Castle on the Sea"] = {"Castle on the Sea", "Castle"},
    ["Haunted Castle"] = {"Haunted Castle", "HauntedCastle"},
    ["Tiki Outpost"] = {"Tiki Outpost", "TikiOutpost"},
    ["Forgotten Island"] = {"Forgotten Island", "ForgottenIsland"},
    ["Cursed Ship"] = {"Cursed Ship", "CursedShip", "Ship", "Ghost Ship"},
    ["Kingdom of Rose"] = {"Kingdom of Rose", "Dressrosa"},
    ["Floating Turtle"] = {"Floating Turtle", "Mansion"},
    ["Sea of Treats"] = {"Sea of Treats", "Cake Island", "CakeLoaf"},
}

function M.islandInCurrentMap(islandName)
    if not islandName or islandName == "" then return false end
    local map = Workspace:FindFirstChild("Map")
    if not map then return false end
    if map:FindFirstChild(islandName) then return true end
    local aliases = ISLAND_ALIASES[islandName]
    if aliases then
        for _, name in ipairs(aliases) do
            if map:FindFirstChild(name) then return true end
        end
    end

    local cleanName = islandName:lower():gsub("%s+", "")
    if #cleanName < 4 then return false end
    for _, child in ipairs(map:GetChildren()) do
        if child:IsA("Model") or child:IsA("Folder") then
            local childName = child.Name:lower():gsub("%s+", "")
            if childName == cleanName then return true end
        end
    end

    return false
end

function M.findIslandModel(islandName)
    local map = Workspace:FindFirstChild("Map")
    if not map or not islandName then return nil end
    local island = map:FindFirstChild(islandName)
    if island then return island end
    local aliases = ISLAND_ALIASES[islandName]
    if aliases then
        for _, name in ipairs(aliases) do
            local m = map:FindFirstChild(name)
            if m then return m end
        end
    end

    local cleanName = islandName:lower():gsub("%s+", "")
    if #cleanName < 4 then return nil end
    for _, child in ipairs(map:GetChildren()) do
        if child:IsA("Model") or child:IsA("Folder") then
            local childName = child.Name:lower():gsub("%s+", "")
            if childName == cleanName then return child end
        end
    end

    return nil
end

function M.isOnIsland(islandName)
    return M.isNearIsland(islandName, 3200)
end

function M.isNearIsland(islandName, radius)
    radius = radius or 3200
    local hrp = M.getHRP()
    if not hrp or not islandName then return false end
    local now = os.clock()
    local ck = islandName .. ":" .. tostring(radius)
    local cached = S.islandNearCache[ck]
    if cached and now - cached.at < 1.25 then
        return cached.val
    end

    local island = M.findIslandModel(islandName)
    local val = island ~= nil
        and M.horizontalDistance(hrp.Position, island:GetPivot().Position) <= radius
    S.islandNearCache[ck] = { at = now, val = val }
    return val
end

local PLACE_TO_SEA = {
    [27539155]        = "Sea 1", [2753915549]   = "Sea 1", [85211729168715] = "Sea 1",
    [4442272183]      = "Sea 2", [79091703265657] = "Sea 2",
    [7449925010]      = "Sea 3", [7449423635]   = "Sea 3", [100117331123089] = "Sea 3",
}

function M.getCurrentSea()
    return PLACE_TO_SEA[game.PlaceId] or "Sea 1"
end

function M.getFarmOrbitY()
    if M.isUnderwaterFarm() then return 2 end
    return S.farmHoverY
end

function M.getFarmHoverPos(targetPos, index)
    local o = S.snapOffsets[index or S.snapIndex]
    return targetPos + Vector3.new(o.X, M.getFarmOrbitY(), o.Z)
end

function M.getFarmOrbitPos(targetPos, index)
    return M.getFarmHoverPos(targetPos, index)
end

function M.isUnderwaterFarm()
    if not HumanoidRootPart then return false end
    if Humanoid and Humanoid:GetState() == Enum.HumanoidStateType.Swimming then
        return true
    end

    if HumanoidRootPart.Position.Y < 0 then return true end
    if S.questInfo and (S.questInfo.island == "Fishmen" or S.questInfo.island == "Fishman") then
        local inside = Vector3.new(61163.8515625, 11.6796875, 1819.7841796875)
        if (HumanoidRootPart.Position - inside).Magnitude < 3000 then
            return true
        end
    end

    return false
end

function M.horizontalDistance(a, b)
    return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

function M.getSpawnStandPosition(spawnPos)
    if _G.NexusHubAutofarm == true then
        return spawnPos + Vector3.new(0, S.farmHoverY, 0)
    end

    return spawnPos + Vector3.new(0, S.spawnStandHeight, 0)
end

function M.isNearEnemySpawn(spawnPos)
    if not spawnPos or not HumanoidRootPart then return false end
    local hrp = HumanoidRootPart.Position
    return M.horizontalDistance(hrp, spawnPos) <= S.spawnNearHoriz
        and math.abs(hrp.Y - spawnPos.Y) <= S.spawnNearMaxY
end

function M.touchFarmAnchor()
    local hrp = M.getHRP()
    local qi = M.getQuestInfoCache()
    if not hrp or not qi or not qi.enemy then return end
    S.farmAnchorPos = hrp.Position
    S.farmAnchorKey = qi.enemy .. "\0" .. tostring(qi.island)
end

function M.isNearFarmAnchor()
    if not S.farmAnchorPos then return false end
    local hrp = M.getHRP()
    if not hrp then return false end
    return M.horizontalDistance(hrp.Position, S.farmAnchorPos) <= S.FARM_ANCHOR_RADIUS
end

function M.shouldBlockQuestTravel(enemyName, islandHint)
    if os.clock() - (_G.NexusHubLastQuestTurnInAt or 0) < S.QUEST_TURNIN_GRACE then return true end
    local key = tostring(enemyName) .. "\0" .. tostring(islandHint)
    if S.farmAnchorKey == key and M.isNearFarmAnchor() then return true end
    if S.lastQuestEnemyMissingSince > 0
        and os.clock() - S.lastQuestEnemyMissingSince < S.QUEST_RESPAWN_WAIT
        and S.farmAnchorKey == key
        and M.isNearFarmAnchor() then
        return true
    end

    return false
end

function M.isCursedShipIsland(islandHint)
    return islandHint == "Cursed Ship"
end

function M.isCursedShipQuestActive()
    if _G.NexusHubAutofarm ~= true then return false end
    local qi = _G.NexusHubQuestInfo
    if not qi and M.getQuestInfoCache then
        qi = M.getQuestInfoCache()
    end

    return qi and M.isCursedShipIsland(qi.island)
end

function M.shouldForceCursedShipNoclip()
    if M.isCursedShipQuestActive() then return true end
    if S.autoCursedCaptain and (S.cursedCaptainEngaged or M.cursedCaptainSpawned()) then
        return true
    end

    return false
end

function M.isOnQuestFarmIsland(islandHint)
    if M.isCursedShipIsland(islandHint) then
        return M.isInsideCursedShip()
    end

    return not islandHint or islandHint == "" or M.isNearIsland(islandHint, 3200)
end

function M.shouldBlockQuestIslandTravel(islandHint)
    return os.clock() - (_G.NexusHubLastQuestTurnInAt or 0) < S.QUEST_TURNIN_GRACE
end

function M.markQuestTurnIn()
    _G.NexusHubLastQuestTurnInAt = os.clock()
    S.questSpawnStuckSince = 0
    S.lastQuestEnemyMissingSince = os.clock()
    M.cancelFarmMove()
    M.clearFarmHoverConstraint(M.getHRP())
end

function M.shouldDeferQuestSpawnTravel(enemyName, islandHint)
    return M.shouldBlockQuestTravel(enemyName, islandHint)
end

function M.noteQuestEnemyPresence()
    local enemy = M.findQuestEnemy()
    if enemy then
        S.lastQuestEnemyMissingSince = 0
        S.questSpawnStuckSince = 0
        M.touchFarmAnchor()
    elseif S.lastQuestEnemyMissingSince == 0 then
        S.lastQuestEnemyMissingSince = os.clock()
    end

    return enemy
end

function M.getEnemySpawnPoints(enemyName, islandHint)
    if not enemyName then return {} end
    local ck = tostring(enemyName) .. "|" .. tostring(islandHint)
    local now = os.clock()
    local cached = S.spawnPointCache[ck]
    if cached and now - cached.at < 5 then
        return cached.points
    end

    local origin = Workspace:FindFirstChild("_WorldOrigin")
    local spawns = origin and origin:FindFirstChild("EnemySpawns")
    if not spawns then return M.getLiveEnemySpawnHints(enemyName) end
    local points = {}
    local seen = {}
    for _, alias in ipairs(M.getEnemySpawnAliases(enemyName)) do
        for _, spawn in ipairs(spawns:GetChildren()) do
            if M.spawnNameMatches(spawn.Name, alias) then
                local key = math.floor(spawn.Position.X) .. ":" .. math.floor(spawn.Position.Z)
                if not seen[key] then
                    seen[key] = true
                    table.insert(points, spawn.Position)
                end
            end
        end
    end

    if #points == 0 then
        return M.getLiveEnemySpawnHints(enemyName)
    end

    local hrp = M.getHRP()
    local sortFrom = hrp and hrp.Position or points[1]
    if islandHint then
        local island = M.findIslandModel(islandHint)
        if island and (not hrp or not M.isOnIsland(islandHint)) then
            sortFrom = island:GetPivot().Position
        end
    end

    table.sort(points, function(a, b)
        return (a - sortFrom).Magnitude < (b - sortFrom).Magnitude
    end)

    if islandHint then
        local island = M.findIslandModel(islandHint)
        if island then
            local center = island:GetPivot().Position
            local filtered = {}
            for _, pos in ipairs(points) do
                if M.horizontalDistance(pos, center) <= 3500 then
                    table.insert(filtered, pos)
                end
            end

            if #filtered > 0 then
                points = filtered
            end
        end
    end

    S.spawnPointCache[ck] = { at = os.clock(), points = points }
    return points
end

function M.findBestEnemySpawn(enemyName, islandHint)
    local points = M.getEnemySpawnPoints(enemyName, islandHint)
    return points[1]
end

function M.findNearestEnemySpawn(enemyName, islandHint)
    return M.findBestEnemySpawn(enemyName, islandHint)
end

function M.resetQuestSpawnPatrol(enemyName)
    if enemyName ~= S.questSpawnTrackEnemy then
        S.questSpawnTrackEnemy = enemyName
        S.questSpawnPatrolIx = 0
        S.questSpawnStuckSince = 0
    end
end

function M.moveToQuestSpawn(enemyName, islandHint)
    if M.findQuestEnemy() then return nil end
    if M.shouldBlockQuestTravel(enemyName, islandHint) then return nil end
    if M.isNearFarmAnchor() then return nil end
    if _G.NexusHubIsMoving() then return nil end
    M.resetQuestSpawnPatrol(enemyName)
    local points = M.getEnemySpawnPoints(enemyName, islandHint)
    if #points == 0 then return nil end
    local spawnPos = points[1]
    if not M.isNearEnemySpawn(spawnPos) then
        M.moveTo(M.getSpawnStandPosition(spawnPos))
    end

    return spawnPos
end

function M.getSeaDangerLevel()
    if os.clock() - S.lastDangerCheck < 0.25 then
        return S.cachedSeaDanger
    end

    S.lastDangerCheck = os.clock()
    if M.getCurrentSea() ~= "Sea 3" then
        S.cachedSeaDanger = 0
        return 0
    end

    local level = workspace:GetAttribute("SeaDangerLevel")
        or workspace:GetAttribute("DangerLevel")
    if typeof(level) == "number" then
        S.cachedSeaDanger = level
        return level
    end

    local data = Player:FindFirstChild("Data")
    if data then
        for _, child in ipairs(data:GetChildren()) do
            local name = child.Name:lower()
            if name:find("danger") or (name:find("sea") and name:find("level")) then
                if typeof(child.Value) == "number" then
                    S.cachedSeaDanger = child.Value
                    return child.Value
                end
            end
        end
    end

    local dangerLabels = {
        none = 0, low = 1, medium = 2, high = 3, extreme = 4, crazy = 5,
        ["????"] = 6, ["???"] = 6,
    }
    local main = Player.PlayerGui:FindFirstChild("Main")
    if main then
        for _, obj in ipairs(main:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                local text = obj.Text or ""
                local lower = text:lower():gsub("%s+", "")
                if dangerLabels[lower] then
                    S.cachedSeaDanger = dangerLabels[lower]
                    return dangerLabels[lower]
                end

                local parsed = lower:match("level(%d+)") or lower:match("dangerlevel(%d+)")
                if parsed then
                    S.cachedSeaDanger = tonumber(parsed) or 0
                    return S.cachedSeaDanger
                end

                if text:find("%?%?%?%?") or text:find("%?%?%?") then
                    S.cachedSeaDanger = 6
                    return 6
                end
            end
        end
    end

    S.cachedSeaDanger = 0
    return 0
end

function _G.NexusHubClearFloatParts(hrp)
    if not hrp then return end
    local bv = hrp:FindFirstChild("FloatBV")
    if bv then bv:Destroy() end
    local bg = hrp:FindFirstChild("StabilizerBG")
    if bg then bg:Destroy() end
end

function _G.NexusHubSetMoveGoal(pos, cf)
    _G.NexusHubMoveGoal = pos
    _G.NexusHubMoveCF = cf
end

function _G.NexusHubClearMoveGoal()
    _G.NexusHubMoveGoal = nil
    _G.NexusHubMoveCF = nil
end

function _G.NexusHubCancelMove()
    _G.NexusHubAllowMove = false
    _G.NexusHubClearMoveGoal()
    _G.NexusHubMoveDetour = nil
    _G.NexusHubCachedDetour = nil
    _G.NexusHubMoveStuckSince = nil
    _G.NexusHubLastMovePos = nil
    if _G.NexusHubFinishFarmMove then _G.NexusHubFinishFarmMove() end
end

function _G.NexusHubMoveNeedsNoclip()
    if _G.NexusHubGlobalNoclip == true and _G.NexusHubIsMoving() then return true end
    if _G.NexusHubAutoSecondSea == true and _G.NexusHubSecondSeaTravel == true then return true end
    if _G.NexusHubAutoThirdSea == true and _G.NexusHubThirdSeaTravel == true then return true end
    if M.shouldForceCursedShipNoclip and M.shouldForceCursedShipNoclip() then return true end
    if M.shouldForceFactoryRaidNoclip and M.shouldForceFactoryRaidNoclip() then return true end
    if M.isAutoDoughRaidActive and M.isAutoDoughRaidActive() then
        if S.doughBringMobActive or S.doughRaidTravel then return true end
    end

    if S.manualTweenActive then return true end
    if M.isFruitSniperActive and M.isFruitSniperActive() then return true end
    if _G.NexusHubAutofarm == true and _G.NexusHubIsMoving() then return true end
    return false
end

function _G.NexusHubBeginMove(position, cf)
    local plr = _G.NexusHubLocalPlayer()
    local char = plr and plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not position then return false end
    if M.clearFarmHoverConstraint then
        M.clearFarmHoverConstraint(hrp)
    end

    if _G.NexusHubMoveNeedsNoclip() then
        _G.NexusHubSetFarmNoclip(true)
    end

    if not (M.isFruitSniperActive and M.isFruitSniperActive()) then
        _G.NexusHubClearFloatParts(hrp)
    end

    hrp.Anchored = false
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
        hum.Sit = false
    end

    _G.NexusHubAllowMove = true
    _G.NexusHubSetMoveGoal(position, cf)
    _G.NexusHubMoveDetour = nil
    _G.NexusHubCachedDetour = nil
    _G.NexusHubMoveStuckSince = nil
    _G.NexusHubLastMovePos = nil
    return true
end

function _G.NexusHubIsMoving()
    return _G.NexusHubMoveGoal ~= nil and _G.NexusHubAllowMove == true
end

function _G.NexusHubStripFarmConstraints(char, zeroVelocity)
    if not char then return false end
    local removed = false
    for _, desc in ipairs(char:GetDescendants()) do
        if desc.Name == "FloatBV" or desc.Name == "StabilizerBG" then
            pcall(function() desc:Destroy() end)
            removed = true
        end
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        if hrp:FindFirstChild("FloatBV") or hrp:FindFirstChild("StabilizerBG") then
            _G.NexusHubClearFloatParts(hrp)
            removed = true
        end

        hrp.Anchored = false
        if zeroVelocity then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end

    return removed
end

function _G.NexusHubLightPhysicsClean()
    if _G.NexusHubMoveNeedsNoclip and _G.NexusHubMoveNeedsNoclip() then return end
    if _G.NexusHubAutofarm == true then return end
    if _G.NexusHubFarmNoclip then
        _G.NexusHubSetFarmNoclip(false)
    end

    local plr = _G.NexusHubLocalPlayer()
    local char = plr and plr.Character
    if not char then return end
    local removed = _G.NexusHubStripFarmConstraints(char, false)
    if removed and _G.NexusHubDevTrace then
        _G.NexusHubDevTrace("physics", "stripped stray farm constraints")
    end
end

function _G.NexusHubSanitizePhysics()
    local plr = _G.NexusHubLocalPlayer()
    local char = plr and plr.Character
    if not char then return end
    _G.NexusHubStripFarmConstraints(char, false)
    if _G.NexusHubSetFarmNoclip then _G.NexusHubSetFarmNoclip(false) end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
        hum.Sit = false
    end

    for _, bp in ipairs(char:GetDescendants()) do
        if bp:IsA("BasePart") and bp.CanCollide == false then
            bp.CanCollide = true
        end
    end

    _G.NexusHubPhysicsWatchUntil = os.clock() + 3
end

function _G.NexusHubSetFarmNoclip(on)
    on = on == true
    if _G.NexusHubFarmNoclip == on and on and (os.clock() - (_G.NexusHubLastNoclipApply or 0)) < 0.3 then
        return
    end

    _G.NexusHubFarmNoclip = on
    _G.NexusHubLastNoclipApply = os.clock()
    if not on then
        local plr = game:GetService("Players").LocalPlayer
        local char = plr and plr.Character
        if not char then return end
        for _, bp in ipairs(char:GetDescendants()) do
            if bp:IsA("BasePart") then
                bp.CanCollide = true
            end
        end

        return
    end

    if not _G.NexusHubIsMoving() and not _G.NexusHubMoveNeedsNoclip() then
        return
    end

    local plr = game:GetService("Players").LocalPlayer
    local char = plr and plr.Character
    if not char then return end
    for _, bp in ipairs(char:GetDescendants()) do
        if bp:IsA("BasePart") then
            bp.CanCollide = false
        end
    end
end

function M.buildMoveRayParams(char)
    local rayParams = _G.NexusHubMoveRayParams
    if not rayParams then
        rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        _G.NexusHubMoveRayParams = rayParams
    end

    local filter = { char }
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then table.insert(filter, enemies) end
    rayParams.FilterDescendantsInstances = filter
    return rayParams
end

function M.raycastBlocked(origin, direction, dist, rayParams)
    local hit = workspace:Raycast(origin, direction * dist, rayParams)
    return hit and hit.Instance and hit.Instance.CanCollide
end

function M.probeMoveClear(pos, dir, dist, rayParams)
    local rayLen = math.min(24, dist)
    for _, h in ipairs({ 1.5, 3.5, 6 }) do
        if M.raycastBlocked(pos + Vector3.new(0, h, 0), dir, rayLen, rayParams) then
            return false
        end
    end

    return true
end

function M.pickAvoidSidestep(pos, dir, step, rayParams, stuck)
    local up = Vector3.new(0, 1, 0)
    local right = dir:Cross(up)
    if right.Magnitude > 0.01 then
        right = right.Unit
    else
        right = Vector3.new(1, 0, 0)
    end

    local left = -right
    local flip = _G.NexusHubAvoidSide or 1
    local scales = stuck and { 1, 1.6, 2.4, 3.5 } or { 1, 1.8, 2.8 }
    for _, scale in ipairs(scales) do
        for _, side in ipairs({ right * flip, left * flip, right, left }) do
            local blend = (dir * 0.3 + side * 0.7).Unit
            if M.probeMoveClear(pos, blend, step * 10, rayParams) then
                _G.NexusHubAvoidSide = -flip
                return side * step * 6 * scale + dir * step * 0.45, side
            end
        end
    end

    _G.NexusHubAvoidSide = -flip
    return right * step * 6 * flip, right
end

function M.computePathDetour(from, to, char)
    if not to or (to - from).Magnitude < 12 then return nil end
    if os.clock() - (_G.NexusHubLastPathfindAt or 0) < 0.75 then
        return _G.NexusHubCachedDetour
    end

    _G.NexusHubLastPathfindAt = os.clock()
    local waypoint
    local ok = pcall(function()
        local path = PathfindingService:CreatePath({
            AgentRadius = 2.5,
            AgentHeight = 5,
            AgentCanJump = true,
            AgentCanClimb = true,
            Costs = { Water = 20 },
        })
        path:ComputeAsync(from, to)
        if path.Status ~= Enum.PathStatus.Success then return end
        local wps = path:GetWaypoints()
        for i = 2, #wps do
            local wp = wps[i]
            if (wp.Position - from).Magnitude > 8 then
                waypoint = wp.Position + Vector3.new(0, 3, 0)
                break
            end
        end
    end)

    _G.NexusHubCachedDetour = ok and waypoint or nil
    return _G.NexusHubCachedDetour
end

function M.isHrpInsideGeometry(hrp, char)
    if not hrp then return false end
    local rayParams = M.buildMoveRayParams(char)
    local hits = 0
    for _, dir in ipairs({
        Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
        Vector3.new(0, 1, 0),
    }) do
        if M.raycastBlocked(hrp.Position, dir, 2.2, rayParams) then
            hits = hits + 1
        end
    end

    return hits >= 3
end

function M.shouldKeepFarmNoclip(hrp, char)
    if M.isFruitSniperActive and M.isFruitSniperActive() then return true end
    if M.shouldForceCursedShipNoclip and M.shouldForceCursedShipNoclip() then return true end
    if M.shouldForceFactoryRaidNoclip and M.shouldForceFactoryRaidNoclip() then return true end
    if _G.NexusHubIsMoving() and _G.NexusHubMoveStuckSince and os.clock() - _G.NexusHubMoveStuckSince < 2.5 then
        return true
    end

    return M.isHrpInsideGeometry(hrp, char)
end

function _G.NexusHubDoMoveStep(dt)
    local finalGoal = _G.NexusHubMoveGoal
    local goal = _G.NexusHubMoveDetour or finalGoal
    if not goal or _G.NexusHubAllowMove ~= true then return end
    dt = dt or (1 / 60)
    local plr = game:GetService("Players").LocalPlayer
    local char = plr and plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        _G.NexusHubCancelMove()
        return
    end

    if _G.NexusHubMoveNeedsNoclip() then
        if not _G.NexusHubFarmNoclip then
            _G.NexusHubSetFarmNoclip(true)
        end
    elseif _G.NexusHubFarmNoclip and not M.shouldKeepFarmNoclip(hrp, char) then
        _G.NexusHubSetFarmNoclip(false)
    end

    if M.isHrpInsideGeometry(hrp, char) and not _G.NexusHubFarmNoclip then
        _G.NexusHubSetFarmNoclip(true)
        hrp.CFrame = hrp.CFrame + Vector3.new(0, 4, 0)
    end

    if not (M.isFruitSniperActive and M.isFruitSniperActive()) then
        _G.NexusHubClearFloatParts(hrp)
    end

    hrp.Anchored = false
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.Sit = false end
    local pos = hrp.Position
    local delta = goal - pos
    local dist = delta.Magnitude
    if dist < 3 then
        if _G.NexusHubMoveDetour and finalGoal and (finalGoal - pos).Magnitude > 3 then
            _G.NexusHubMoveDetour = nil
            _G.NexusHubMoveStuckSince = nil
            return
        end

        hrp.AssemblyLinearVelocity = Vector3.zero
        if _G.NexusHubMoveCF and not _G.NexusHubMoveDetour then
            hrp.CFrame = _G.NexusHubMoveCF
        else
            hrp.CFrame = CFrame.new(goal)
        end

        _G.NexusHubMoveDetour = nil
        _G.NexusHubCachedDetour = nil
        if finalGoal and (finalGoal - hrp.Position).Magnitude > 3 then
            return
        end

        _G.NexusHubCancelMove()
        return
    end

    local baseSpeed = _G.NexusHubTravelSpeed or 240
    if S.manualTweenActive then
        baseSpeed = S.manualTravelSpeed or 200
    elseif _G.NexusHubSecondSeaTravel == true or _G.NexusHubThirdSeaTravel == true then
        baseSpeed = _G.NexusHubSecondSeaTravelSpeed or 300
    end

    local speed = baseSpeed
    local maxSpeed = S.manualTweenActive
        and (S.manualTravelSpeed or 200)
        or ((_G.NexusHubSecondSeaTravel == true or _G.NexusHubThirdSeaTravel == true)
        and (_G.NexusHubSecondSeaTravelSpeed or 300)
        or (_G.NexusHubMaxMoveSpeed or 280))
    if dist > 1200 then
        speed = math.min(maxSpeed, baseSpeed * 1.08)
    elseif dist > 500 then
        speed = math.min(maxSpeed, baseSpeed * 1.03)
    end

    if hum then
        if not S.manualTweenActive then
            local walkMul = (_G.NexusHubSecondSeaTravel == true or _G.NexusHubThirdSeaTravel == true) and 14 or 10
            local walkCap = (hum.WalkSpeed or 16) * walkMul
            speed = math.min(speed, walkCap, maxSpeed)
        else
            speed = math.min(speed, maxSpeed)
        end
    end

    local step = math.min(dist, speed * dt)
    local dir = dist > 0.001 and delta.Unit or Vector3.zero
    local newPos = pos + dir * step
    local lastPos = _G.NexusHubLastMovePos
    local stuck = lastPos and (pos - lastPos).Magnitude < 0.05 and dist > 5
    _G.NexusHubLastMovePos = pos
    local rayParams = M.buildMoveRayParams(char)
    local skipWallProbe = (M.shouldForceCursedShipNoclip and M.shouldForceCursedShipNoclip())
        or S.manualTweenActive == true
        or _G.NexusHubGlobalNoclip == true
    local blocked = not skipWallProbe
        and _G.NexusHubSecondSeaTravel ~= true
        and _G.NexusHubThirdSeaTravel ~= true
        and not M.probeMoveClear(pos, dir, dist, rayParams)
    if stuck then
        if not _G.NexusHubMoveStuckSince then
            _G.NexusHubMoveStuckSince = os.clock()
        end
    elseif not blocked then
        _G.NexusHubMoveStuckSince = nil
    end

    local stuckFor = _G.NexusHubMoveStuckSince and (os.clock() - _G.NexusHubMoveStuckSince) or 0
    if stuckFor > 0.9 and not _G.NexusHubFarmNoclip then
        _G.NexusHubSetFarmNoclip(true)
    end

    if (stuck or blocked) and finalGoal and not _G.NexusHubMoveDetour and stuckFor > 0.3 then
        local detour = M.computePathDetour(pos, finalGoal, char)
        if detour and (detour - pos).Magnitude > 6 then
            _G.NexusHubMoveDetour = detour
            goal = detour
            delta = goal - pos
            dist = delta.Magnitude
            dir = dist > 0.001 and delta.Unit or dir
            newPos = pos + dir * step
        end
    end

    if stuck or blocked then
        _G.NexusHubSetFarmNoclip(true)
        local sidestep = M.pickAvoidSidestep(pos, dir, step, rayParams, stuck)
        local lift = step * 2
        if stuck then
            lift = lift + math.min(50, speed * dt * (stuckFor > 0.5 and 8 or 4))
        end

        if blocked and not stuck then
            lift = lift + step * 1.5
        end

        if stuckFor > 1.4 and dist > 8 then
            newPos = pos + dir * math.max(step * 2.5, 8) + Vector3.new(0, math.max(lift, 10), 0)
        else
            newPos = pos + Vector3.new(0, lift, 0) + sidestep
        end
    end

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.CFrame = CFrame.new(newPos)
end

function M.setQuestInfoCache(info)
    S.questInfo = info
    _G.NexusHubQuestInfo = info
end

function M.getQuestInfoCache()
    return _G.NexusHubQuestInfo or S.questInfo
end

function M.forceNoclip(on)
    on = on == true
    _G.NexusHubFarmNoclip = on
    _G.NexusHubLastNoclipApply = os.clock()
    local char = Player.Character
    if not char then return end
    for _, bp in ipairs(char:GetDescendants()) do
        if bp:IsA("BasePart") then
            bp.CanCollide = not on
        end
    end
end

function M.doUnstuck()
    if S.unstuckActive then
        M.notify("Unstuck", "Already running...", 2)
        return
    end

    S.unstuckActive = true
    _G.NexusHubMoveStuckSince = nil
    M.cancelFarmMove()
    local hrp = M.getHRP()
    if hrp then
        hrp.Anchored = false
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = hrp.CFrame + Vector3.new(0, 8, 0)
    end

    M.forceNoclip(true)
    M.notify("Unstuck", "Noclip on for a few seconds...", 2)
    task.spawn(function()
        task.wait(4)
        S.unstuckActive = false
        if _G.NexusHubMoveNeedsNoclip and _G.NexusHubMoveNeedsNoclip() then
            M.forceNoclip(true)
        else
            M.forceNoclip(false)
        end

        M.notify("Unstuck", "Noclip off", 2)
    end)
end

function M.setFarmNoclip(on)
    _G.NexusHubSetFarmNoclip(on)
end

function M.restoreCharacterPhysics()
    M.cancelFarmMove()
    M.removeFloat(false)
    M.setFarmNoclip(false)
    M.unanchorFarmTarget()
    local char = Player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
        hum.Sit = false
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        _G.NexusHubClearFloatParts(hrp)
        if M.clearFarmHoverConstraint then
            M.clearFarmHoverConstraint(hrp)
        end

        hrp.Anchored = false
    end

    for _, bp in ipairs(char:GetDescendants()) do
        if bp:IsA("BasePart") and bp.CanCollide == false then
            bp.CanCollide = true
        end
    end
end

function M.onUnloadCleanup()
    _G.NexusHubAutofarm = false
    S.autofarm = false
    S.manualTweenActive = false
    S.unstuckActive = false
    M.endManualTweenDrive()
    _G.NexusHubAutoAttack = false
    S.autoAttack = false
    _G.NexusHubAutoAttackLoopRunning = false
    _G.NexusHubQuestInfo = nil
    _G.NexusHubAllowMove = false
    _G.NexusHubMoveGoal = nil
    _G.NexusHubFarmNoclip = false
    _G.NexusHubPhysicsWatchUntil = 0
    M.cancelFarmMove()
    M.setFarmNoclip(false)
    M.removeFloat(false)
    M.unanchorFarmTarget()
    local char = Player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum.Sit = false
        end

        for _, bp in ipairs(char:GetDescendants()) do
            if bp:IsA("BasePart") then
                bp.CanCollide = true
            end
        end

        local hubHl = char:FindFirstChild("NexusHubHighlight")
        if hubHl then pcall(function() hubHl:Destroy() end) end
    end
end

function M.isAutofarmOn()
    return _G.NexusHubAutofarm == true
end

function M.isMarineTeam()
    return _G.NexusHubIsMarineTeam()
end

function M.shouldSkipQuestKey(questKey)
    return _G.NexusHubSkipQuestKey(questKey)
end

function M.getQuestProgressFromUI()
    local main = Player.PlayerGui:FindFirstChild("Main")
    local questFrame = main and main:FindFirstChild("Quest")
    if not questFrame or not questFrame.Visible then return nil, nil, nil end
    for _, label in ipairs(questFrame:GetDescendants()) do
        if label:IsA("TextLabel") then
            local enemy, cur, tot = M.parseQuestLabel(label.Text or "")
            if cur and tot then return enemy, cur, tot end
        end
    end

    return nil, nil, nil
end

function M.hasActiveQuestProgress()
    if not M.getQuestFrameVisible() then return false end
    local title = M.getQuestTitleTextDirect()
    if not title or title == "" then return false end
    local lower = title:lower()
    if lower:find("complete") and not lower:find("incomplete") then
        return false
    end

    if not (lower:find("defeat") or lower:find("kill")) then
        return false
    end

    local cur, tot = title:match("%((%d+)/(%d+)%)")
    cur, tot = tonumber(cur), tonumber(tot)
    if cur and tot then
        return cur < tot
    end

    return true
end

function M.hasUiQuestInProgress()
    return M.hasActiveQuestProgress()
end

function M.hasActiveQuest()
    return M.hasUiQuestInProgress()
end

function M.isQuestUiComplete()
    local title = M.getQuestTitleTextDirect()
    if title and title ~= "" then
        local lower = title:lower()
        if lower:find("complete") and not lower:find("incomplete") then
            return true
        end

        local cur, tot = title:match("%((%d+)/(%d+)%)")
        cur, tot = tonumber(cur), tonumber(tot)
        if cur and tot and cur >= tot then return true end
    end

    local _, cur, tot = M.getQuestProgressFromUI()
    return cur and tot and cur >= tot
end

function M.nudgeNearQuestGiver()
    return false
end

function M.isNearQuestGiver()
    return false
end

function M.tryActivateQuestGiver()
end

function M.stopAutofarm()
    S.autofarm = false
    S.questSpawnPatrolIx = 0
    S.questSpawnStuckSince = 0
    S.questSpawnTrackEnemy = nil
    S.farmAnchorPos = nil
    S.farmAnchorKey = nil
    S.questAcquirePending = false
    S.lastQuestEnemyMissingSince = 0
    _G.NexusHubQuestHiddenSince = nil
    S.bossFollowGoal = nil
    if S.autoAttackForcedByFarm then
        M.setAutoAttack(false)
        S.autoAttackForcedByFarm = false
    end

    S.questInfo = nil
    M.cancelFarmMove()
    _G.NexusHubStopAutofarm()
end

function M.isQuestInProgress()
    return _G.NexusHubQuestInProgress()
end

function M.ensureAutofarmQuestCache()
    return _G.NexusHubRefreshQuestCache()
end

function M.clearFarmHoverConstraint(hrp)
    if not hrp then return end
    for _, name in ipairs({ "FarmHoverAP", "FarmHoverAO", "FarmHoverAtt" }) do
        local obj = hrp:FindFirstChild(name)
        if obj then
            pcall(function() obj:Destroy() end)
        end
    end
end

function M.applyFarmHover(hrp, targetPos)
    if not hrp or not targetPos then return end
    if M.shouldForceCursedShipNoclip() then
        _G.NexusHubSetFarmNoclip(true)
    end

    M.touchFarmAnchor()
    local pos = hrp.Position
    local hDist = M.horizontalDistance(pos, targetPos)
    local orbitY = M.getFarmOrbitY()
    local centerHover = targetPos + Vector3.new(0, orbitY, 0)
    if hDist > 30 then
        M.clearFarmHoverConstraint(hrp)
        local moving = _G.NexusHubIsMoving()
        if moving and _G.NexusHubMoveGoal and (_G.NexusHubMoveGoal - centerHover).Magnitude < 40 then
            return
        end

        if not moving then
            M.moveTo(centerHover)
        end

        return
    end

    if _G.NexusHubIsMoving() then
        _G.NexusHubCancelMove()
    end

    if os.clock() - S.lastSwitch >= S.snapTime then
        S.snapIndex = (S.snapIndex % #S.snapOffsets) + 1
        S.lastSwitch = os.clock()
    end

    local orbitPos = M.getFarmHoverPos(targetPos, S.snapIndex)
    local ap = hrp:FindFirstChild("FarmHoverAP")
    if not ap then
        ap = Instance.new("AlignPosition")
        ap.Name = "FarmHoverAP"
        ap.Mode = Enum.PositionAlignmentMode.OneAttachment
        ap.MaxForce = 500000
        ap.Responsiveness = 40
        ap.ApplyAtCenterOfMass = true
        ap.RigidityEnabled = false
        local att = Instance.new("Attachment")
        att.Name = "FarmHoverAtt"
        att.Parent = hrp
        ap.Attachment0 = att
        ap.Parent = hrp
    end

    ap.Position = orbitPos
    local ao = hrp:FindFirstChild("FarmHoverAO")
    if not ao then
        local att = hrp:FindFirstChild("FarmHoverAtt")
        if not att then
            att = Instance.new("Attachment")
            att.Name = "FarmHoverAtt"
            att.Parent = hrp
        end

        ao = Instance.new("AlignOrientation")
        ao.Name = "FarmHoverAO"
        ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
        ao.MaxTorque = 500000
        ao.Responsiveness = 40
        ao.Attachment0 = att
        ao.Parent = hrp
    end

    ao.CFrame = CFrame.new(pos, targetPos)
    local vel = hrp.AssemblyLinearVelocity
    if vel.Y < -0.5 then
        hrp.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
    end
end

function M.clearQuestFarmAnchor()
    S.farmAnchorPos = nil
    S.farmAnchorKey = nil
    S.lastQuestEnemyMissingSince = 0
    S.questSpawnStuckSince = 0
    _G.NexusHubTravelLockIsland = nil
    _G.NexusHubTravelLockUntil = 0
end

function M.ensureAutofarmQuest()
    if _G.NexusHubAutofarm ~= true then return end
    if _G.NexusHubAutoSecondSea == true or _G.NexusHubAutoThirdSea == true then return end
    if M.isFactoryRaidEngaged() or M.isCursedCaptainEngaged() or M.isFruitSniperActive() then return end
    local ok, err = pcall(function()
        local now = os.clock()
        if now - (_G.NexusHubLastQuestInvoke or 0) < 0.85 then return end
        local level = _G.NexusHubGetLevel()
        if level <= 0 then return end
        local needsUpgrade = M.shouldUpgradeQuest(level)
        if M.hasActiveQuestProgress() and not needsUpgrade then return end
        _G.NexusHubLastQuestInvoke = now
        if needsUpgrade then
            M.clearQuestFarmAnchor()
            pcall(function()
                local r = M.getCommFRemote()
                if r then r:InvokeServer("AbandonQuest") end
            end)
        elseif M.isQuestUiComplete() then
            M.markQuestTurnIn()
            M.clearQuestFarmAnchor()
            pcall(function()
                local r = M.getCommFRemote()
                if r then r:InvokeServer("AbandonQuest") end
            end)
        elseif M.needsNewQuest() and not M.hasActiveQuestProgress() then
            M.clearQuestFarmAnchor()
            if M.getQuestFrameVisible() then
                pcall(function()
                    local r = M.getCommFRemote()
                    if r then r:InvokeServer("AbandonQuest") end
                end)
            end
        end

        local info = M.getQuest()
        if not info or not info.args then return end
        M.fireStartQuest(info.args)
        M.applyQuestInfoToCache(info)
    end)

    if not ok and _G.NexusHubDevTrace then
        _G.NexusHubDevTrace("ensure_quest", err)
    end
end

function M.tickAutofarmQuest()
    if _G.NexusHubAutofarm ~= true then return end
    local ok, err = pcall(M.syncQuestEnemyFromUI)
    if not ok and _G.NexusHubDevTrace then
        _G.NexusHubDevTrace("sync_quest", err)
    end
end

function M.tryStartQuest()
    M.ensureAutofarmQuest()
end

function M.seedAutofarmQuestCache()
    M.ensureAutofarmQuestCache()
end

function M.getHRP()
    local char = Player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

function M.isFarmMoving()
    return _G.NexusHubIsMoving()
end

function M.cancelFarmMove()
    _G.NexusHubCancelMove()
    local hrp = M.getHRP()
    if hrp then
        hrp.Anchored = false
    end
end

function M.newMoveProxy(token)
    local proxy = {}

    function proxy.Cancel()
        if S.farmMoveToken == token then
            M.cancelFarmMove()
        end
    end

    proxy.PlaybackState = Enum.PlaybackState.Playing
    proxy.Completed = {
        Wait = function()
            while _G.NexusHubIsMoving() and S.farmMoveToken == token do
                RunService.Heartbeat:Wait()
            end
        end,

    }
    return proxy
end

function M.moveTo(position)
    local hrp = M.getHRP()
    if not hrp then return nil end
    M.cancelFarmMove()
    local dist = (hrp.Position - position).Magnitude
    if dist < 3 then
        hrp.CFrame = CFrame.new(position)
        return nil
    end

    if not _G.NexusHubBeginMove(position, nil) then return nil end
    S.farmMoveGoal = position
    S.farmMoveCFrame = nil
    S.farmMoveToken = {}
    S.ActiveTween = M.newMoveProxy(S.farmMoveToken)
    return S.ActiveTween
end

function M.moveToCFrame(targetCFrame)
    local hrp = M.getHRP()
    if not hrp or not targetCFrame then return nil end
    M.cancelFarmMove()
    local dist = (hrp.Position - targetCFrame.Position).Magnitude
    if dist < 3 then
        hrp.CFrame = targetCFrame
        return nil
    end

    if not _G.NexusHubBeginMove(targetCFrame.Position, targetCFrame) then return nil end
    S.farmMoveGoal = targetCFrame.Position
    S.farmMoveCFrame = targetCFrame
    S.farmMoveToken = {}
    S.ActiveTween = M.newMoveProxy(S.farmMoveToken)
    return S.ActiveTween
end

function M.getBossSpawn(boss)
    if not boss then return nil end
    local origin = Workspace:FindFirstChild("_WorldOrigin")
    local spawns = origin and origin:FindFirstChild("EnemySpawns")
    if spawns then
        for _, s in ipairs(spawns:GetChildren()) do
            if M.spawnNameMatches(s.Name, boss.Name) then
                return s.Position
            end
        end
    end

    if boss.Island then
        local map = Workspace:FindFirstChild("Map")
        local island = map and map:FindFirstChild(boss.Island)
        if island then
            return island:GetPivot().Position
        end
    end

    return nil
end

function M.getBossTimer(bossName)
    local clean = bossName:gsub("^The ", ""):gsub(" Admiral$", ""):lower()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BillboardGui") and v.Enabled then
            local textLabel = v:FindFirstChildOfClass("TextLabel")
            if textLabel and (textLabel.Text:find("Respawns in") or textLabel.Text:find("Spawn in")) then
                local parentName = v.Parent.Name:lower()
                if parentName:find(clean, 1, true) or textLabel.Text:lower():find(clean, 1, true) then
                    return textLabel.Text
                end
            end
        end
    end

    return nil
end

function M.getModelPosition(model)
    if not model then return nil end
    local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("Head")
    return part and part.Position
end

function M.normalizeEnemyName(name)
    if not name then return "" end
    return name:gsub("%b[]", "")
        :gsub("%b()", "")
        :gsub("[^%w%s]", "")
        :gsub("^The%s+", "")
        :gsub("%s+Admiral$", "")
        :gsub("%s*Boss%s*$", "")
        :gsub("Quest%d*$", "")
        :gsub("Quest%s*$", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
        :gsub("%s+", " ")
end

function M.fuzzyEnemyMatch(a, b)
    if not a or not b then return false end
    a = M.normalizeEnemyName(a):lower()
    b = M.normalizeEnemyName(b):lower()
    if a == "" or b == "" then return false end
    if a == b then return true end
    if a .. "s" == b or b .. "s" == a then return true end
    if a:sub(-1) == "s" and a:sub(1, -2) == b then return true end
    if b:sub(-1) == "s" and b:sub(1, -2) == a then return true end
    return false
end

function M.getBossSearchKey(name)
    if not name then return nil end
    return M.normalizeEnemyName(name):lower()
end

function M.bossNameMatches(modelName, displayName, searchKey)
    if not searchKey then return false end
    local cleanSearch = M.normalizeEnemyName(searchKey):lower()
    local cleanModel = M.normalizeEnemyName(modelName):lower()
    local cleanDisplay = M.normalizeEnemyName(displayName or ""):lower()
    if cleanSearch == "" then return false end
    if cleanModel == "" and cleanDisplay == "" then return false end
    if cleanModel:find(cleanSearch, 1, true) or cleanDisplay:find(cleanSearch, 1, true) then
        return true
    end

    if cleanSearch:find(cleanModel, 1, true) or (cleanDisplay ~= "" and cleanSearch:find(cleanDisplay, 1, true)) then
        return true
    end

    local matchedWord = false
    for word in cleanSearch:gmatch("%S+") do
        if #word >= 3 then
            if cleanModel:find(word, 1, true) or cleanDisplay:find(word, 1, true) then
                matchedWord = true
            else
                return false
            end
        end
    end

    return matchedWord
end

function M.tryBossModel(obj, searchKey)
    if not obj or obj == Player.Character then return nil end
    local candidate = obj
    if obj:IsA("Humanoid") then
        candidate = obj.Parent
    elseif obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model") then
        candidate = obj.Parent
    end

    if candidate and candidate:IsA("Model") then
        local hum = candidate:FindFirstChildWhichIsA("Humanoid", true)
        if hum and hum.Health > 0 then
            if M.bossNameMatches(candidate.Name, hum.DisplayName, searchKey) then
                return candidate
            end
        end

        if M.bossNameMatches(candidate.Name, "", searchKey) then
            return candidate
        end

        for _, child in ipairs(candidate:GetDescendants()) do
            if child:IsA("BasePart") or child:IsA("Model") then
                if M.bossNameMatches(child.Name, "", searchKey) then
                    return candidate
                end
            end
        end

        local parentModel = candidate.Parent
        while parentModel and parentModel:IsA("Model") and parentModel ~= Player.Character do
            if M.bossNameMatches(parentModel.Name, hum and hum.DisplayName or "", searchKey) then
                return parentModel
            end

            parentModel = parentModel.Parent
        end
    end

    if obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model") then
        local parent = obj.Parent
        if M.bossNameMatches(parent.Name, "", searchKey) then
            return parent
        end
    end

    return nil
end

function M.getBossScanRoots()
    local roots = {}
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then table.insert(roots, enemies) end
    local npcs = Workspace:FindFirstChild("NPCs")
    if npcs then table.insert(roots, npcs) end
    table.insert(roots, ReplicatedStorage)
    local rsEnemies = ReplicatedStorage:FindFirstChild("Enemies")
    if rsEnemies then table.insert(roots, rsEnemies) end
    local rsNpcs = ReplicatedStorage:FindFirstChild("NPCs")
    if rsNpcs then table.insert(roots, rsNpcs) end
    local origin = Workspace:FindFirstChild("_WorldOrigin")
    local originEnemies = origin and origin:FindFirstChild("Enemies")
    if originEnemies then table.insert(roots, originEnemies) end
    return roots
end

function M.isAliveBossModel(model)
    if not model or not model:IsA("Model") then return false end
    local hum = model:FindFirstChild("Humanoid") or model:FindFirstChildWhichIsA("Humanoid", true)
    return not hum or hum.Health > 0
end

function M.strictBossMatchesQuery(queryName, model)
    if not queryName or not model or not model:IsA("Model") then return false end
    if model.Name == queryName then return true end
    local hum = model:FindFirstChild("Humanoid") or model:FindFirstChildWhichIsA("Humanoid", true)
    local display = hum and hum.DisplayName or ""
    if display == queryName then return true end
    local compactQ = queryName:gsub("%s+", ""):lower()
    if model.Name:gsub("%s+", ""):lower() == compactQ then return true end
    if display:gsub("%s+", ""):lower() == compactQ then return true end
    local normQ = M.normalizeEnemyName(queryName):lower()
    if normQ == "" then return false end
    return normQ == M.normalizeEnemyName(model.Name):lower()
        or normQ == M.normalizeEnemyName(display):lower()
end

function M.bossMatchesQuery(queryName, model)
    if M.strictBossMatchesQuery(queryName, model) then return true end
    return M.bossNameMatches(model.Name, model:FindFirstChild("Humanoid") and model.Humanoid.DisplayName or "", M.getBossSearchKey(queryName))
end

function M.clearBossResolveCache()
    S.cachedBossResolve = nil
    S.cachedBossResolveName = nil
    S.lastBossResolveAt = 0
end

function M.resolveBossTarget(bossName)
    if not bossName then return nil end
    local now = os.clock()
    if S.cachedBossResolveName == bossName and S.cachedBossResolve and S.cachedBossResolve.Parent
        and now - S.lastBossResolveAt < 0.4 then
        local hum = S.cachedBossResolve:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then return S.cachedBossResolve end
    end

    local target = M.findBoss(bossName)
    if not target then
        for _, model in ipairs(M.collectLiveBossModels()) do
            if M.bossMatchesQuery(bossName, model) then
                target = model
                break
            end
        end
    end

    S.lastBossResolveAt = now
    S.cachedBossResolveName = bossName
    S.cachedBossResolve = target
    return target
end

function M.getActiveBossQuestEnemy()
    local questGui = Player.PlayerGui:FindFirstChild("Main")
    local questFrame = questGui and questGui:FindFirstChild("Quest")
    if not questFrame or not questFrame.Visible then return nil end
    for _, child in ipairs(questFrame:GetDescendants()) do
        if child:IsA("TextLabel") then
            local text = child.Text
            if text:find("Defeat") or text:find("Kill") then
                local parsed = text:match("Defeat%s+%d+%s+(.+)%s+%(%d+/%d+%)")
                    or text:match("Kill%s+%d+%s+(.+)%s+%(%d+/%d+%)")
                    or text:match("Defeat%s+(.+)%s+%(%d+/%d+%)")
                    or text:match("Kill%s+(.+)%s+%(%d+/%d+%)")
                    or text:match("Defeat%s+%d+%s+(.+)")
                    or text:match("Kill%s+%d+%s+(.+)")
                    or text:match("Defeat%s+(.+)")
                    or text:match("Kill%s+(.+)")
                if parsed then return M.normalizeEnemyName(parsed) end
            end
        end
    end

    return nil
end

function M.isBossQuestFor(boss)
    if not boss then return false end
    local active = M.getActiveBossQuestEnemy()
    if not active or active == "" then return false end
    return M.fuzzyEnemyMatch(active, boss.Name)
end

function M.ensureBossQuest(boss, force)
    if not boss or not boss.Args then return end
    if not force and M.isBossQuestFor(boss) then return end
    if not force and os.clock() - S.lastBossQuestAt < 2.5 then return end
    S.lastBossQuestAt = os.clock()
    pcall(function() M.invokeCommFArgs(boss.Args) end)
end

function M.collectLiveBossModels()
    local models, seen = {}, {}
    for _, root in ipairs(M.getBossScanRoots()) do
        for _, child in ipairs(root:GetChildren()) do
            if child:IsA("Model") and M.isAliveBossModel(child) and not seen[child] then
                seen[child] = true
                table.insert(models, child)
            end
        end
    end

    return models
end

function M.discoverAllLiveBosses()
    local results, seenNames = {}, {}
    for _, model in ipairs(M.collectLiveBossModels()) do
        local hum = model:FindFirstChild("Humanoid") or model:FindFirstChildWhichIsA("Humanoid", true)
        local display = hum and hum.DisplayName or ""
        local label = model.Name
        if display ~= "" and display ~= model.Name then
            label = model.Name .. " [" .. display .. "]"
        end

        if not seenNames[label] then
            seenNames[label] = true
            local loc = model:IsDescendantOf(Workspace) and "Workspace" or "ReplicatedStorage"
            table.insert(results, { name = label, model = model, loc = loc })
        end
    end

    return results
end

function M.isBossAlive(name)
    if not name then return false end
    for _, root in ipairs(M.getBossScanRoots()) do
        local direct = root:FindFirstChild(name)
        if direct and direct:IsA("Model") and M.isAliveBossModel(direct) then return true end
    end

    for _, model in ipairs(M.collectLiveBossModels()) do
        if M.strictBossMatchesQuery(name, model) then return true end
    end

    return false
end

function M.findBoss(name)
    if not name or name == "None" or name == "All" then return nil end
    for _, root in ipairs(M.getBossScanRoots()) do
        local direct = root:FindFirstChild(name)
        if direct and direct:IsA("Model") and M.isAliveBossModel(direct) then
            return direct
        end
    end

    local best, bestDist
    local myPos = HumanoidRootPart and HumanoidRootPart.Position
    for _, model in ipairs(M.collectLiveBossModels()) do
        if M.bossMatchesQuery(name, model) then
            local pos = M.getModelPosition(model)
            if pos and myPos then
                local d = (myPos - pos).Magnitude
                if not bestDist or d < bestDist then best, bestDist = model, d end
            elseif not best then
                best = model
            end
        end
    end

    if best then return best end
    if os.clock() - S.lastGlobalBossScan >= S.GLOBAL_BOSS_SCAN_INTERVAL then
        S.lastGlobalBossScan = os.clock()
        local searchKey = M.getBossSearchKey(name)
        for _, folder in ipairs({ Workspace:FindFirstChild("Enemies"), Workspace:FindFirstChild("NPCs") }) do
            if folder then
                for _, obj in ipairs(folder:GetDescendants()) do
                    if obj:IsA("Model") or obj:IsA("Humanoid") then
                        local found = M.tryBossModel(obj, searchKey)
                        if found and M.isAliveBossModel(found) and M.bossMatchesQuery(name, found) then
                            return found
                        end
                    end
                end
            end
        end
    end

    return nil
end

function M.spawnNameMatches(spawnName, enemyName)
    if not spawnName or not enemyName then return false end
    local clean = spawnName:gsub("%[Lv%.%s*%d+%]%s*", ""):gsub("%s+$", "")
    if M.fuzzyEnemyMatch(clean, enemyName) then return true end
    if M.compactEnemyKey(clean) == M.compactEnemyKey(enemyName) then return true end
    local ck = M.compactEnemyKey(clean)
    local ek = M.compactEnemyKey(enemyName)
    if ck ~= "" and ek ~= "" and (ck:find(ek, 1, true) or ek:find(ck, 1, true)) then
        return true
    end

    return M.bossNameMatches(clean, "", M.getBossSearchKey(enemyName))
end

function M.getBossSpawnPoints(boss)
    local points = {}
    if not boss or not boss.Name then return points end
    local origin = Workspace:FindFirstChild("_WorldOrigin")
    local spawns = origin and origin:FindFirstChild("EnemySpawns")
    if spawns then
        for _, s in ipairs(spawns:GetChildren()) do
            if M.spawnNameMatches(s.Name, boss.Name) then
                table.insert(points, s.Position)
            end
        end
    end

    local fallback = M.getBossSpawn(boss)
    if fallback then
        local dup = false
        for _, p in ipairs(points) do
            if (p - fallback).Magnitude < 5 then dup = true; break end
        end

        if not dup then table.insert(points, fallback) end
    end

    return points
end

function M.loadEnemy(enemyName, islandHint)
    local spawnPos = M.findBestEnemySpawn(enemyName, islandHint)
    if not spawnPos or not HumanoidRootPart then return nil end
    if not M.isNearEnemySpawn(spawnPos) then
        M.moveTo(M.getSpawnStandPosition(spawnPos))
    end

    return spawnPos
end

function M.pickFarmBoss()
    local bosses = M.getCurrentBosses()
    if #bosses == 0 then
        if S.autoBossFarm and os.clock() - (S.lastBossEmptyNotify or 0) >= 30 then
            S.lastBossEmptyNotify = os.clock()
            M.notify("Boss Farm", "No bosses for this sea - check you're in the right place", 5)
        end

        return nil
    end

    local function isSpawned(b)
        return M.resolveBossTarget(b.Name) ~= nil or M.isBossAlive(b.Name)
    end

    if not (S.farmAllBosses or S.selectedBoss == "All") then
        for _, b in ipairs(bosses) do
            if b.Name == S.selectedBoss then
                if isSpawned(b) then return b end
                if _G.NexusHubDevMode then
                    M.devTrace("boss_farm", "Selected boss not spawned: " .. tostring(S.selectedBoss))
                end

                return nil
            end
        end

        if _G.NexusHubDevMode then
            M.devTrace("boss_farm", "Selected boss not in config: " .. tostring(S.selectedBoss))
        end

        return nil
    end

    local count = #bosses
    for _ = 1, count do
        local b = bosses[S.bossRotationIndex]
        S.bossRotationIndex = (S.bossRotationIndex % count) + 1
        if isSpawned(b) then return b end
    end

    return nil
end

function M.nudgeTowardBossSpawn(boss)
    if not boss then return end
    if os.clock() - S.lastBossPatrolAt < 2 then return end
    S.lastBossPatrolAt = os.clock()
    local points = M.getBossSpawnPoints(boss)
    local pos
    if #points > 0 then
        pos = points[S.bossSpawnPatrolIx]
        S.bossSpawnPatrolIx = (S.bossSpawnPatrolIx % #points) + 1
    else
        pos = M.getBossSpawn(boss)
    end

    if pos then
        M.moveTo(M.getSpawnStandPosition(pos))
        M.loadEnemy(boss.Name, boss.Island)
    elseif boss.Island then
        local map = Workspace:FindFirstChild("Map")
        local island = map and map:FindFirstChild(boss.Island)
        if island then
            M.moveTo(island:GetPivot().Position + Vector3.new(0, 50, 0))
        end
    end
end

function M.travelToQuestIsland(island, enemyName)
    if island == "Cursed Ship" then
        return M.tickCursedShipEntry(enemyName)
    end

    if enemyName and enemyName ~= "" then
        local spawn = M.findBestEnemySpawn(enemyName, island)
        if spawn and not M.isNearEnemySpawn(spawn) then
            return M.moveTo(M.getSpawnStandPosition(spawn))
        end
    end

    return M.teleportToIsland(island)
end

function _G.NexusHubTravelTick()
    if _G.NexusHubAutofarm ~= true then return end
    if M.isFactoryRaidEngaged() or M.isCursedCaptainEngaged() or M.isFruitSniperActive() then return end
    if _G.NexusHubAutoSecondSea == true then return end
    if _G.NexusHubAutoThirdSea == true then return end
    if _G.NexusHubIsMoving() then return end
    local hrp = M.getHRP()
    if hrp and hrp:FindFirstChild("FarmHoverAP") then
        if M.findQuestEnemy() then return end
        M.clearFarmHoverConstraint(hrp)
    end

    if os.clock() - (_G.NexusHubLastSpawnTravelAt or 0) < 1.5 then return end
    if os.clock() - (_G.NexusHubLastTravelTickAt or 0) < 2.0 then return end
    _G.NexusHubLastTravelTickAt = os.clock()
    local qi = _G.NexusHubQuestInfo or M.getQuestInfoCache()
    if not qi or not qi.enemy or qi.enemy == "" then
        qi = _G.NexusHubRefreshQuestCache()
    end

    if not qi or not qi.enemy or qi.enemy == "" then return end
    if qi.island and not M.islandInCurrentMap(qi.island) then return end
    if M.isCursedShipIsland(qi.island) and not M.isInsideCursedShip() then
        pcall(function() M.tickCursedShipEntry(qi.enemy) end)
        return
    end

    local onQuestIsland = M.isOnQuestFarmIsland(qi.island)
        or (qi.island == "Cursed Ship" and M.isInsideCursedShip())
    if not onQuestIsland then
        if M.shouldBlockQuestIslandTravel(qi.island) then return end
        local now = os.clock()
        if qi.island == _G.NexusHubTravelLockIsland and now < (_G.NexusHubTravelLockUntil or 0) then
            pcall(function() M.travelToQuestIsland(qi.island, qi.enemy) end)
            return
        end

        _G.NexusHubTravelLockIsland = qi.island
        _G.NexusHubTravelLockUntil = now + 14
        pcall(function() M.travelToQuestIsland(qi.island, qi.enemy) end)
        return
    end

    if M.shouldBlockQuestTravel(qi.enemy, qi.island) then return end
    local enemy = M.noteQuestEnemyPresence()
    if enemy then return end
    _G.NexusHubTravelLockIsland = nil
    _G.NexusHubTravelLockUntil = 0
    if M.needsQuestSpawnTravel(qi.enemy, qi.island) then
        _G.NexusHubLastSpawnTravelAt = os.clock()
        pcall(function() M.moveToQuestSpawn(qi.enemy, qi.island) end)
    end
end

function M.teleportToIsland(island)
    local sea3Portals = {
        ["Hydra Island"] = true, ["Floating Turtle"] = true,
        ["Castle on the Sea"] = true, ["Tiki Outpost"] = true,
        ["Port Town"] = true, ["Haunted Castle"] = true
    }
    if sea3Portals[island] then
        local originPos = HumanoidRootPart and HumanoidRootPart.Position
        local targetLink = (island == "Floating Turtle") and "Mansion" or "Town"
        pcall(function() CommF_:InvokeServer("TPToLink", island, targetLink) end)
        task.wait(2.0)
        if originPos and HumanoidRootPart and (HumanoidRootPart.Position - originPos).Magnitude < 8 then
            local fallbackIsland = M.findIslandModel(island)
            if fallbackIsland then
                return M.moveTo(fallbackIsland:GetPivot().Position + Vector3.new(0, 6, 0))
            end
        end

        return nil
    end

    if island == "Sea of Treats" or island == "Cake Island" or island == "Cake Land" then
        if M.travelToCakeLand then
            M.travelToCakeLand()
        end

        return nil
    end

    local m = M.findIslandModel(island)
    if not m then return nil end
    if island == "SkyArea1" and workspace.Map:FindFirstChild("SkyArea2") then
        return M.moveTo(workspace.Map.SkyArea2.PathwayHouse.EntrancePoint.Position)
    elseif island == "SkyArea2" and workspace.Map:FindFirstChild("SkyArea1") then
        return M.moveTo(workspace.Map.SkyArea1.PathwayTemple.ExitPoint.Position)
    else
        return M.moveTo(m:GetPivot().Position + Vector3.new(0, 6, 0))
    end
end

M.TWEEN_ISLAND_LIST = {
    ["Sea 1"] = {
        {"Windmill", "Windmill"},
        {"Marine Start", "MarineStart"},
        {"Jungle", "Jungle"},
        {"Pirate", "Pirate"},
        {"Desert", "Desert"},
        {"Ice", "Ice"},
        {"Marine Base", "MarineBase"},
        {"Sky", "Sky"},
        {"Prison", "Prison"},
        {"Colosseum", "Colosseum"},
        {"Magma", "Magma"},
        {"Fishmen", "Fishmen"},
        {"Fountain", "Fountain"},
    },
    ["Sea 2"] = {
        {"Kingdom of Rose", "Kingdom of Rose"},
        {"Green Bit", "Green Bit"},
        {"Cafe", "Cafe"},
        {"Graveyard", "Graveyard"},
        {"Snow Mountain", "Snow Mountain"},
        {"Hot and Cold", "Hot and Cold"},
        {"Cursed Ship", "Cursed Ship"},
        {"Ice Castle", "Ice Castle"},
        {"Forgotten Island", "Forgotten Island"},
    },
    ["Sea 3"] = {
        {"Port Town", "Port Town"},
        {"Hydra Island", "Hydra Island"},
        {"Floating Turtle", "Floating Turtle"},
        {"Castle on the Sea", "Castle on the Sea"},
        {"Haunted Castle", "Haunted Castle"},
        {"Sea of Treats", "Sea of Treats"},
        {"Tiki Outpost", "Tiki Outpost"},
    },
}

function M.waitForMoveComplete(maxTime)
    maxTime = maxTime or 180
    local deadline = os.clock() + maxTime
    while os.clock() < deadline do
        if not (_G.NexusHubIsMoving and _G.NexusHubIsMoving()) then
            break
        end

        RunService.Heartbeat:Wait()
    end
end

function M.beginManualTweenDrive()
    if S.manualTweenConn then return end
    S.manualTweenConn = RunService.Heartbeat:Connect(function(dt)
        if not S.manualTweenActive then
            M.endManualTweenDrive()
            return
        end

        if _G.NexusHubLoaded and _G.NexusHubMoveGoal and _G.NexusHubAllowMove == true and _G.NexusHubDoMoveStep then
            _G.NexusHubDoMoveStep(dt)
        end
    end)
end

function M.endManualTweenDrive()
    if S.manualTweenConn then
        S.manualTweenConn:Disconnect()
        S.manualTweenConn = nil
    end
end

function M.getIslandTweenGoal(islandKey)
    if not islandKey then return nil end
    if islandKey == "Cursed Ship" then
        local pos = M.getCursedShipEntryPos and M.getCursedShipEntryPos()
        if pos then return pos end
    end

    local map = Workspace:FindFirstChild("Map")
    if islandKey == "Sky" and map then
        local sky2 = map:FindFirstChild("SkyArea2")
        local entrance = sky2 and sky2:FindFirstChild("PathwayHouse")
        entrance = entrance and entrance:FindFirstChild("EntrancePoint")
        if entrance then return entrance.Position end
        local sky1 = map:FindFirstChild("SkyArea1")
        local exitPt = sky1 and sky1:FindFirstChild("PathwayTemple")
        exitPt = exitPt and exitPt:FindFirstChild("ExitPoint")
        if exitPt then return exitPt.Position end
    end

    local m = M.findIslandModel(islandKey)
    if not m then return nil end
    local target = m:GetPivot().Position + Vector3.new(0, 6, 0)
    local hrp = M.getHRP()
    if not hrp then return target end
    local horiz = M.horizontalDistance(hrp.Position, target)
    local onIsland = M.isNearIsland(islandKey, 2800)
    if horiz > 350 and not onIsland then
        local flyY = math.max(target.Y + 50, hrp.Position.Y + 100, 220)
        return Vector3.new(target.X, flyY, target.Z)
    end

    return target
end

function M.manualMoveTo(goal, maxTime)
    if not goal then return false end
    local hrp = M.getHRP()
    if not hrp then return false end
    if (hrp.Position - goal).Magnitude < 8 then return true end
    M.moveTo(goal)
    if not _G.NexusHubIsMoving() then
        return (M.getHRP().Position - goal).Magnitude < 12
    end

    M.waitForMoveComplete(maxTime or 180)
    hrp = M.getHRP()
    return hrp ~= nil and (hrp.Position - goal).Magnitude < 35
end

function M.manualTweenToPosition(goal)
    if not goal then return false end
    local hrp = M.getHRP()
    if not hrp then return false end
    local horiz = M.horizontalDistance(hrp.Position, goal)
    if horiz > 350 then
        local flyGoal = Vector3.new(
            goal.X,
            math.max(goal.Y, hrp.Position.Y + 100, 220),
            goal.Z
        )
        if not M.manualMoveTo(flyGoal, 150) then
            return false
        end
    end

    return M.manualMoveTo(goal, 150)
end

function M.tweenToIslandOnly(islandName)
    if not islandName then return nil end
    if islandName == "Sea of Treats" or islandName == "Cake Island" or islandName == "Cake Land" then
        local hrp = M.getHRP()
        if hrp and not M.isNearCakeLand(3200) then
            local hubGoal = M.getDoughHoverPos(M.getDoughGroundPosition(M.DoughPos.Hub) or M.DoughPos.Hub)
            M.manualTweenToPosition(hubGoal or M.DoughPos.Hub)
        end

        local farmGoal = M.getDoughHoverPos(M.getDoughGroundPosition(M.DoughPos.Farm) or M.DoughPos.Farm)
        if M.manualTweenToPosition(farmGoal or M.DoughPos.Farm) then
            return true
        end

        return nil
    end

    if islandName == "Cursed Ship" then
        pcall(function() M.tickCursedShipEntry(nil) end)
        M.waitForMoveComplete(120)
        return M.isInsideCursedShip() or nil
    end

    local goal = M.getIslandTweenGoal(islandName)
    if not goal then return nil end
    if M.manualTweenToPosition(goal) then
        return true
    end

    return nil
end

function M.buildTweenDestinations()
    if M.TWEEN_DEST_LOOKUP then return end
    M.TWEEN_DEST_LOOKUP = {}
    M.TWEEN_DEST_BY_SEA = { ["Sea 1"] = {}, ["Sea 2"] = {}, ["Sea 3"] = {} }

    local function addDest(sea, label, entry)
        entry.sea = sea
        entry.display = label
        M.TWEEN_DEST_LOOKUP[sea .. "\0" .. label] = entry
        table.insert(M.TWEEN_DEST_BY_SEA[sea], label)
    end

    for sea, islands in pairs(M.TWEEN_ISLAND_LIST) do
        for _, pair in ipairs(islands) do
            local label, islandKey = pair[1], pair[2]
            addDest(sea, label, {
                island = islandKey,
                resolve = function()
                    return M.tweenToIslandOnly(islandKey)
                end,

            })
        end
    end

    local specials = {
        {label = "Pirate Raid Stand", sea = "Sea 3", pos = function() return M.PirateRaidStand + Vector3.new(0, 6, 0) end},
        {label = "Indra Wait Spot", sea = "Sea 3", pos = function() return M.IndraWaitPos end},
        {label = "Factory Raid Stand", sea = "Sea 2", pos = function() return M.FactoryRaidStand + Vector3.new(0, 6, 0) end},
        {label = "Darkbeard Altar", sea = "Sea 2", pos = function() return M.DarkbeardAltarPos + Vector3.new(0, 6, 0) end},
        {label = "Darkbeard Wait", sea = "Sea 2", pos = function() return M.DarkbeardWaitPos end},
        {label = "Cursed Captain", sea = "Sea 2", pos = function() return M.CursedCaptainPos end},
        {label = "Haunted Gravestone", sea = "Sea 3", pos = function() return M.HauntedPos.Gravestone end},
        {label = "Haunted Death King", sea = "Sea 3", pos = function() return M.HauntedPos.DeathKing end},
        {label = "Haunted Altar", sea = "Sea 3", pos = function() return M.HauntedPos.Altar end},
        {label = "Cake Land Farm", sea = "Sea 3", pos = function()
            return M.getDoughHoverPos(M.getDoughGroundPosition(M.DoughPos.Farm) or M.DoughPos.Farm) or M.DoughPos.Farm
        end},

        {label = "Drip Mama", sea = "Sea 3", pos = function() return M.DoughPos.DripMama + Vector3.new(0, 3, 0) end},
        {label = "Cake Mirror Portal", sea = "Sea 3", pos = function()
            local mirror = M.getCakeMirrorPortalPart and M.getCakeMirrorPortalPart()
            if mirror then return mirror.Position + Vector3.new(0, 3, 0) end
            return M.DoughPos.DripMama + Vector3.new(0, 3, 0)
        end},

        {label = "Cake Land Hub", sea = "Sea 3", pos = function()
            return M.getDoughHoverPos(M.getDoughGroundPosition(M.DoughPos.Hub) or M.DoughPos.Hub) or M.DoughPos.Hub
        end},

        {label = "Bartilo", sea = "Sea 3", pos = function() return M.ThirdSeaPos.Bartilo end},
        {label = "Don Swan", sea = "Sea 3", pos = function() return M.ThirdSeaPos.DonSwan end},
        {label = "King Red Head", sea = "Sea 3", pos = function() return M.ThirdSeaPos.KingRedHead end},
        {label = "Mr Captain Dock", sea = "Sea 3", pos = function() return M.ThirdSeaPos.MrCaptainDock end},
    }
    for _, spec in ipairs(specials) do
        addDest(spec.sea, spec.label, {
            resolve = function()
                return spec.pos()
            end,

        })
    end

    for _, labels in pairs(M.TWEEN_DEST_BY_SEA) do
        table.sort(labels)
    end
end

function M.getTweenDestinationEntry(sea, label)
    M.buildTweenDestinations()
    sea = sea or M.getCurrentSea()
    label = label or S.selectedTeleportDest
    if not label then return nil end
    return M.TWEEN_DEST_LOOKUP[sea .. "\0" .. label]
end

function M.getTweenDestinationLabels(sea)
    M.buildTweenDestinations()
    sea = sea or M.getCurrentSea()
    local labels = M.TWEEN_DEST_BY_SEA[sea]
    if not labels then return {} end
    local copy = {}
    for i, label in ipairs(labels) do
        copy[i] = label
    end

    return copy
end

function M.runManualTweenToGoal(getGoal)
    if type(getGoal) ~= "function" then return false end
    local goal = getGoal()
    if typeof(goal) == "Vector3" then
        return M.manualTweenToPosition(goal)
    end

    if goal == true then return true end
    return false
end

function M.tweenToDestination(label)
    M.buildTweenDestinations()
    local sea = M.getCurrentSea()
    local entry = M.getTweenDestinationEntry(sea, label or S.selectedTeleportDest)
    if not entry then
        M.notify("Teleports", "Unknown destination", 3)
        return
    end

    if S.manualTweenActive then
        M.notify("Teleports", "Already tweening...", 2)
        return
    end

    local destLabel = entry.display or label or S.selectedTeleportDest
    task.spawn(function()
        S.manualTweenActive = true
        _G.NexusHubSetFarmNoclip(true)
        _G.NexusHubCancelMove()
        M.beginManualTweenDrive()
        local ok = false
        if entry.island then
            ok = M.tweenToIslandOnly(entry.island) == true
            if not ok then
                ok = M.isOnQuestFarmIsland(entry.island) or M.isNearIsland(entry.island, 3200)
            end
        elseif entry.resolve then
            ok = M.runManualTweenToGoal(entry.resolve)
        end

        M.endManualTweenDrive()
        S.manualTweenActive = false
        if not (_G.NexusHubMoveNeedsNoclip and _G.NexusHubMoveNeedsNoclip()) then
            _G.NexusHubSetFarmNoclip(false)
        end

        if ok then
            M.notify("Teleports", "Arrived at " .. destLabel, 3)
        else
            M.notify("Teleports", "Could not reach " .. destLabel, 4)
        end
    end)
end

local MaterialFarmData = {
    ["Sea 1"] = {
        ["Leather"] = {
            {Name = "Pirate",   Island = "Pirate"},
            {Name = "Brute",    Island = "Jungle"},
            {Name = "Gladiator",Island = "Colosseum"},
        },
        ["Scrap Metal"] = {
            {Name = "Pirate",   Island = "Pirate"},
            {Name = "Brute",    Island = "Jungle"},
            {Name = "Gladiator",Island = "Colosseum"},
        },
        ["Magma Ore"] = {
            {Name = "Military Soldier", Island = "Magma"},
            {Name = "Military Spy",     Island = "Magma"},
        },
        ["Fish Tail"] = {
            {Name = "Fishman Warrior",  Island = "Fishmen"},
            {Name = "Fishman Commando", Island = "Fishmen"},
        },
        ["Angel Wings"] = {
            {Name = "God's Guard",   Island = "SkyArea1"},
            {Name = "Shanda",        Island = "SkyArea1"},
            {Name = "Royal Squad",   Island = "SkyArea2"},
            {Name = "Royal Soldier", Island = "SkyArea2"},
        },
    },
    ["Sea 2"] = {
        ["Leather"] = {
            {Name = "Mercenary",      Island = "Kingdom of Rose"},
            {Name = "Swan Pirate",    Island = "Kingdom of Rose"},
            {Name = "Marine Captain", Island = "Green Bit"},
        },
        ["Scrap Metal"] = {
            {Name = "Mercenary",      Island = "Kingdom of Rose"},
            {Name = "Swan Pirate",    Island = "Kingdom of Rose"},
            {Name = "Marine Captain", Island = "Green Bit"},
        },
        ["Radioactive Material"] = {
            {Name = "Factory Staff", Island = "Kingdom of Rose"},
        },
        ["Vampire Fang"] = {
            {Name = "Vampire", Island = "Graveyard"},
        },
        ["Ectoplasm"] = {
            {Name = "Ship Deckhand", Island = "Cursed Ship"},
            {Name = "Ship Engineer", Island = "Cursed Ship"},
            {Name = "Ship Steward",  Island = "Cursed Ship"},
            {Name = "Ship Officer",  Island = "Cursed Ship"},
        },
        ["Magma Ore"] = {
            {Name = "Magma Ninja", Island = "Hot and Cold"},
            {Name = "Lava Pirate", Island = "Hot and Cold"},
        },
        ["Mystic Droplet"] = {
            {Name = "Sea Soldier",   Island = "Forgotten Island"},
            {Name = "Water Fighter", Island = "Forgotten Island"},
        },
    },
    ["Sea 3"] = {
        ["Leather"] = {
            {Name = "Pirate Millionaire", Island = "Port Town"},
            {Name = "Forest Pirate",      Island = "Floating Turtle"},
            {Name = "Jungle Pirate",      Island = "Floating Turtle"},
        },
        ["Scrap Metal"] = {
            {Name = "Pirate Millionaire", Island = "Port Town"},
            {Name = "Forest Pirate",      Island = "Floating Turtle"},
            {Name = "Jungle Pirate",      Island = "Floating Turtle"},
        },
        ["Gunpowder"] = {
            {Name = "Pistol Billionaire", Island = "Port Town"},
        },
        ["Fish Tail"] = {
            {Name = "Fishman Raider",  Island = "Floating Turtle"},
            {Name = "Fishman Captain", Island = "Floating Turtle"},
        },
        ["Dragon Scale"] = {
            {Name = "Dragon Crew Warrior", Island = "Hydra Island"},
            {Name = "Dragon Crew Archer",  Island = "Hydra Island"},
        },
        ["Mini Tusk"] = {
            {Name = "Mythological Pirate", Island = "Floating Turtle"},
        },
        ["Demonic Wisp"] = {
            {Name = "Demonic Soul", Island = "Haunted Castle"},
        },
        ["Bones"] = {
            {Name = "Reborn Skeleton", Island = "Haunted Castle"},
            {Name = "Living Zombie",   Island = "Haunted Castle"},
            {Name = "Demonic Soul",    Island = "Haunted Castle"},
            {Name = "Possessed Mummy", Island = "Haunted Castle"},
        },
        ["Conjured Cocoa"] = {
            {Name = "Cocoa Warrior",         Island = "Sea of Treats"},
            {Name = "Chocolate Bar Battler", Island = "Sea of Treats"},
        },
    },
}
local MaterialOrder = {
    ["Sea 1"] = {"Leather", "Scrap Metal", "Magma Ore", "Fish Tail", "Angel Wings"},
    ["Sea 2"] = {"Leather", "Scrap Metal", "Radioactive Material", "Vampire Fang", "Ectoplasm", "Magma Ore", "Mystic Droplet"},
    ["Sea 3"] = {"Leather", "Scrap Metal", "Gunpowder", "Fish Tail", "Dragon Scale", "Mini Tusk", "Demonic Wisp", "Bones", "Conjured Cocoa"},
}
for sea, list in pairs(MaterialOrder) do
    S.selectedMaterials[sea] = list[1]
end

S.selectedMaterialSea = PLACE_TO_SEA[game.PlaceId] or "Sea 1"

function M.getSelectedMaterialEntries()
    local seaTable = MaterialFarmData[S.selectedMaterialSea]
    if not seaTable then return nil end
    local mat = S.selectedMaterials[S.selectedMaterialSea]
    return mat and seaTable[mat] or nil
end

function M.findMaterialEnemy()
    local entries = M.getSelectedMaterialEntries()
    if not entries or not HumanoidRootPart then return nil end
    local enemiesFolder = Workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil end
    local best, bestDist
    for _, model in ipairs(enemiesFolder:GetDescendants()) do
        if model:IsA("Model") then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                for _, entry in ipairs(entries) do
                    if M.fuzzyEnemyMatch(model.Name, entry.Name) or M.fuzzyEnemyMatch(hum.DisplayName, entry.Name) then
                        local pos = M.getModelPosition(model)
                        if pos then
                            local d = (HumanoidRootPart.Position - pos).Magnitude
                            if not bestDist or d < bestDist then
                                best, bestDist = model, d
                            end
                        end

                        break
                    end
                end
            end
        end
    end

    return best
end

function M.patrolMaterialSpawns(entries)
    local origin = Workspace:FindFirstChild("_WorldOrigin")
    local spawns = origin and origin:FindFirstChild("EnemySpawns")
    if not spawns then return false end
    local points = {}
    for _, s in ipairs(spawns:GetChildren()) do
        for _, entry in ipairs(entries) do
            if M.spawnNameMatches(s.Name, entry.Name) then
                table.insert(points, s.Position)
                break
            end
        end
    end

    if #points == 0 then return false end
    S.materialPatrolIx = (S.materialPatrolIx % #points) + 1
    M.moveTo(M.getSpawnStandPosition(points[S.materialPatrolIx]))
    return true
end

function M.isBoatAlive(boat)
    local hum = boat:FindFirstChildWhichIsA("Humanoid", true)
    return not hum or hum.Health > 0
end

function M.isBoatOwnedByPlayer(boat)
    if not boat then return false end
    if boat.Name == Player.Name then return true end
    local owner = boat:FindFirstChild("Owner")
    if owner then
        local val = owner.Value
        if val == Player or val == Player.Name or val == Player.UserId then return true end
        if typeof(val) == "string" and val:lower() == Player.Name:lower() then return true end
        if typeof(val) == "number" and val == Player.UserId then return true end
        if typeof(val) == "Instance" and val:IsA("Player") and val.UserId == Player.UserId then return true end
    end

    if Humanoid and Humanoid.SeatPart and Humanoid.SeatPart:IsDescendantOf(boat) then
        return true
    end

    return false
end

function M.isBoatModel(model)
    if not model or not model:IsA("Model") then return false end
    local boatsFolder = Workspace:FindFirstChild("Boats")
    if boatsFolder and model.Parent == boatsFolder then
        return model:FindFirstChildWhichIsA("VehicleSeat", true) ~= nil
            or model:FindFirstChildWhichIsA("Humanoid", true) ~= nil
    end

    if model:FindFirstChildWhichIsA("VehicleSeat", true) or model:FindFirstChildWhichIsA("Seat", true) then
        local lowerName = model.Name:lower()
        if lowerName:find("dinghy") or lowerName:find("boat") or lowerName:find("brigade")
            or lowerName:find("hunter") or lowerName:find("guardian") or lowerName:find("sloop")
            or model:FindFirstChild("Owner") or model.Name == Player.Name then
            return true
        end
    end

    return false
end

function M.getBoatDrivePart(boat)
    if not boat or not boat:IsA("Model") then return nil end
    local part = boat.PrimaryPart or boat:FindFirstChildOfClass("VehicleSeat") or boat:FindFirstChild("Base")
    if not part then
        for _, descendant in ipairs(boat:GetDescendants()) do
            if descendant:IsA("BasePart") then
                part = descendant
                break
            end
        end
    end

    return part
end

function M.getBoatVehicleSeat(boat)
    if not boat or not boat:IsA("Model") then return nil end
    return boat:FindFirstChildWhichIsA("VehicleSeat", true) or boat:FindFirstChildWhichIsA("Seat", true)
end

function M.stopBoatTween()
    if S.ActiveBoatTween then
        pcall(function() S.ActiveBoatTween:Cancel() end)
        S.ActiveBoatTween = nil
    end
end

function M.getMyBoat()
    if S.cachedMyBoat and S.cachedMyBoat.Parent and M.isBoatModel(S.cachedMyBoat)
        and M.isBoatOwnedByPlayer(S.cachedMyBoat) and M.isBoatAlive(S.cachedMyBoat) then
        return S.cachedMyBoat
    end

    S.cachedMyBoat = nil
    if Humanoid and Humanoid.SeatPart then
        local seat = Humanoid.SeatPart
        if seat:IsA("VehicleSeat") or seat:IsA("Seat") then
            local boatModel = seat:FindFirstAncestorOfClass("Model")
            if boatModel and M.isBoatModel(boatModel) then
                S.cachedMyBoat = boatModel
                return boatModel
            end
        end
    end

    local boatsFolder = Workspace:FindFirstChild("Boats")
    if not boatsFolder then return nil end
    for _, b in ipairs(boatsFolder:GetChildren()) do
        if M.isBoatModel(b) and M.isBoatAlive(b) and M.isBoatOwnedByPlayer(b) then
            S.cachedMyBoat = b
            return b
        end
    end

    if HumanoidRootPart then
        local best, bestDist
        for _, b in ipairs(boatsFolder:GetChildren()) do
            if M.isBoatModel(b) and M.isBoatAlive(b) then
                local owner = b:FindFirstChild("Owner")
                local claimedByOther = owner and owner.Value ~= nil and owner.Value ~= ""
                    and not M.isBoatOwnedByPlayer(b)
                if not claimedByOther then
                    local pos = M.getModelPosition(b)
                    if not pos then
                        local seat = M.getBoatVehicleSeat(b)
                        pos = seat and seat.Position
                    end

                    if pos then
                        local d = (HumanoidRootPart.Position - pos).Magnitude
                        if d <= 250 and (not bestDist or d < bestDist) then
                            best, bestDist = b, d
                        end
                    end
                end
            end
        end

        if best then
            S.cachedMyBoat = best
            return best
        end
    end

    return nil
end

function M.tweenToBoatSeat(seatTarget)
    if not HumanoidRootPart or not seatTarget then return end
    M.cancelFarmMove()
    local dist = (HumanoidRootPart.Position - seatTarget.Position).Magnitude
    if dist <= 5 then
        HumanoidRootPart.CFrame = seatTarget
        return
    end

    if S.ActiveTween then
        S.ActiveTween:Cancel()
        S.ActiveTween = nil
    end

    S.ActiveTween = TweenService:Create(
        HumanoidRootPart,
        TweenInfo.new(math.max(dist / 350, 0.05), Enum.EasingStyle.Linear),
        { CFrame = seatTarget }
    )
    S.ActiveTween:Play()
    S.ActiveTween.Completed:Wait()
end

function M.getBoatDriveDirection(boat, seaTarget)
    local seat = M.getBoatVehicleSeat(boat)
    if not seat then return nil end
    if seaTarget then
        local targetPos = M.getModelPosition(seaTarget)
        if targetPos then
            local currentPos = seat.Position
            local delta = Vector3.new(targetPos.X - currentPos.X, 0, targetPos.Z - currentPos.Z)
            if delta.Magnitude > 20 then
                return delta.Unit
            end
        end
    end

    local currentPos = seat.Position
    local tiki = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Tiki Outpost")
    if tiki then
        local tikiPos = tiki:GetPivot().Position
        local awayDir = (Vector3.new(currentPos.X, 0, currentPos.Z) - Vector3.new(tikiPos.X, 0, tikiPos.Z)).Unit
        if tostring(awayDir) ~= "nan" then return awayDir end
    end

    local look = seat.CFrame.LookVector
    local forward = Vector3.new(look.X, 0, look.Z)
    if forward.Magnitude > 0 then
        return forward.Unit
    end

    return Vector3.new(1, 0, 0)
end

function M.syncBoatEngine(boat)
    if not boat then return end
    local engine = boat:FindFirstChild("Engine")
    local root = engine and engine:FindFirstChild("Root")
    if engine and root then
        pcall(function() engine.CFrame = root.CFrame end)
    end
end

function M.stopBoatDrive()
    S.boatDriveGeneration = S.boatDriveGeneration + 1
    M.stopBoatTween()
    if Humanoid then
        pcall(function() Humanoid.PlatformStand = false end)
    end

    if Humanoid and Humanoid.SeatPart and Humanoid.SeatPart:IsA("VehicleSeat") then
        pcall(function()
            Humanoid.SeatPart.ThrottleFloat = 0
            Humanoid.SeatPart.SteerFloat = 0
        end)
    end
end

function M.driveSeaBoat(boat, seaTarget)
    local seat = M.getBoatVehicleSeat(boat)
    if not seat then return end
    M.syncBoatEngine(boat)
    pcall(function()
        seat.ThrottleFloat = 1
        seat.SteerFloat = 0
    end)

    local direction = M.getBoatDriveDirection(boat, seaTarget)
    if not direction then return end
    local speed = math.max(S.boatSpeed or 200, 200)
    local segment = math.max(speed * 2, 400)
    local y = seat.Position.Y
    local targetPos = Vector3.new(seat.Position.X, y, seat.Position.Z) + direction * segment
    local targetCFrame = CFrame.new(targetPos, targetPos + direction)
    M.stopBoatTween()
    S.ActiveBoatTween = TweenService:Create(
        seat,
        TweenInfo.new(segment / speed, Enum.EasingStyle.Linear),
        { CFrame = targetCFrame }
    )
    S.ActiveBoatTween:Play()
end

function M.findSeaEnemy()

    local function matchesEnemy(model)
        if not model or not model:IsA("Model") then return false end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        local modelName = model.Name:lower()
        local displayName = tostring(hum.DisplayName):lower()
        local fullName = modelName .. " " .. displayName
        local compact = fullName:gsub("%s+", "")

        local function has(...)
            for _, kw in ipairs({...}) do
                if fullName:find(kw, 1, true) or compact:find((kw:gsub("%s+", "")), 1, true) then
                    return true
                end
            end

            return false
        end

        if S.seaFarmTargets["Terror Shark"] and has("terror shark", "terrorshark", "terror") then return true end
        if S.seaFarmTargets["Sea Beast"] and has("sea beast", "seabeast") then return true end
        if S.seaFarmTargets["Piranha"] and has("piranha") then return true end
        if S.seaFarmTargets["Ghost Ship"] and has("ghost ship", "ghostship") then return true end
        if S.seaFarmTargets["Shark"] and has("shark") and not has("terror") then return true end
        if S.seaFarmTargets["Ship"] and has("ship") and not has("ghost") then return true end
        return false
    end

    local folders = {}
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then table.insert(folders, enemies) end
    local origin = Workspace:FindFirstChild("_WorldOrigin")
    if origin then
        local originEnemies = origin:FindFirstChild("Enemies")
        if originEnemies then table.insert(folders, originEnemies) end
    end

    local best, bestDist
    local myPos = HumanoidRootPart and HumanoidRootPart.Position
    for _, folder in ipairs(folders) do
        for _, obj in ipairs(folder:GetDescendants()) do
            if obj:IsA("Model") and matchesEnemy(obj) then
                local pos = M.getModelPosition(obj)
                if pos then
                    local d = myPos and (myPos - pos).Magnitude or 0
                    if not bestDist or d < bestDist then
                        best, bestDist = obj, d
                    end
                end
            end
        end
    end

    return best
end

function M.getQuestTaskEnemies(quest)
    local names = {}
    if not quest then return names end
    if quest.Name and quest.Name ~= "" then
        table.insert(names, quest.Name)
    end

    if quest.Task and type(quest.Task) == "table" then
        for name, _ in pairs(quest.Task) do
            if type(name) == "string" and name ~= "" then
                table.insert(names, name)
            end
        end
    elseif type(quest.Task) == "string" and quest.Task ~= "" then
        table.insert(names, quest.Task)
    end

    return names
end

function M.questEnemyMatches(activeEnemy, quest)
    if not activeEnemy or activeEnemy == "" or not quest then return false end
    for _, name in ipairs(M.getQuestTaskEnemies(quest)) do
        if M.fuzzyEnemyMatch(activeEnemy, name) then
            return true
        end
    end

    return false
end

function M.readQuestTitleText(questFrame)
    if not questFrame then
        local mainGui = Player.PlayerGui:FindFirstChild("Main")
        questFrame = mainGui and mainGui:FindFirstChild("Quest")
    end

    if not questFrame then return "" end
    local container = questFrame:FindFirstChild("Container")
    local titleFrame = container and container:FindFirstChild("QuestTitle")
    local title = titleFrame and titleFrame:FindFirstChild("Title")
    if title and title:IsA("TextLabel") then
        return title.Text or ""
    end

    return ""
end

function M.tryGuideQuestData()
    return nil
end

function M.questTitleMatchesEnemy(titleText, enemyName)
    if not titleText or titleText == "" or not enemyName or enemyName == "" then
        return false
    end

    if titleText:find(enemyName, 1, true) then return true end
    return M.fuzzyEnemyMatch(titleText, enemyName)
end

function M.findLiveEnemyByName(search)
    if not search or search == "" then return nil end

    local function enemyMatches(model)
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        return M.fuzzyEnemyMatch(model.Name, search) or M.fuzzyEnemyMatch(hum.DisplayName, search)
    end

    for _, root in ipairs(M.getBossScanRoots()) do
        if root:IsDescendantOf(Workspace) or root == Workspace then
            for _, child in ipairs(root:GetChildren()) do
                if child:IsA("Model") and enemyMatches(child) then
                    return child
                end
            end
        end
    end

    return nil
end

function M.parseQuestLabel(text)
    if not text or text == "" then return nil, nil, nil end
    local current, total = text:match("%((%d+)/(%d+)%)")
    local enemy = text:match("Defeat%s+%d+%s+(.+)%s+%(%d+/%d+%)")
        or text:match("Kill%s+%d+%s+(.+)%s+%(%d+/%d+%)")
        or text:match("Defeat%s+(.+)%s+%(%d+/%d+%)")
        or text:match("Kill%s+(.+)%s+%(%d+/%d+%)")
        or text:match("Defeat%s+%d+%s+(.+)")
        or text:match("Kill%s+%d+%s+(.+)")
        or text:match("Defeat%s+(.+)")
        or text:match("Kill%s+(.+)")
    if enemy then enemy = M.normalizeEnemyName(enemy) end
    return enemy, tonumber(current), tonumber(total)
end

function M.readActiveQuest(questFrame)
    if not questFrame then
        local mainGui = Player.PlayerGui:FindFirstChild("Main")
        questFrame = mainGui and mainGui:FindFirstChild("Quest")
    end

    if not questFrame or not questFrame.Visible then
        return false, nil, nil, nil
    end

    local titleText = M.readQuestTitleText(questFrame)
    if titleText ~= "" then
        local lower = titleText:lower()
        if lower:find("complete") and not lower:find("incomplete") then
            return true, nil, 1, 1
        end

        local enemy, cur, tot = M.parseQuestLabel(titleText)
        if enemy or cur or tot then
            return true, enemy, cur, tot
        end
    end

    local targets = {}
    local container = questFrame:FindFirstChild("Container")
    if container then
        for _, child in ipairs(container:GetDescendants()) do
            if child:IsA("TextLabel") then table.insert(targets, child) end
        end
    end

    for _, child in ipairs(questFrame:GetDescendants()) do
        if child:IsA("TextLabel") then table.insert(targets, child) end
    end

    local activeEnemy, progressCur, progressTot
    local sawQuestText = false
    for _, label in ipairs(targets) do
        local text = label.Text or ""
        local lower = text:lower()
        if lower:find("complete") and not lower:find("incomplete") then
            return true, nil, 1, 1
        end

        if text:find("Defeat") or text:find("Kill") then
            sawQuestText = true
            local enemy, cur, tot = M.parseQuestLabel(text)
            if enemy then activeEnemy = enemy end
            if cur and tot then
                progressCur = cur
                progressTot = tot
            end
        end

        local cur, tot = text:match("%((%d+)/(%d+)%)") or text:match("(%d+)/(%d+)")
        if cur and tot then
            progressCur = tonumber(cur)
            progressTot = tonumber(tot)
            sawQuestText = true
        end
    end

    if sawQuestText or activeEnemy then
        return true, activeEnemy, progressCur, progressTot
    end

    return false, nil, nil, nil
end

function M.readQuestState()
    local gui = Player.PlayerGui:FindFirstChild("Main")
    local questFrame = gui and gui:FindFirstChild("Quest")
    local visible = questFrame and questFrame.Visible or false
    local hasQuest, activeEnemy, progressCur, progressTot = M.readActiveQuest(questFrame)
    local titleText = M.readQuestTitleText(questFrame)
    local questComplete = M.isQuestProgressComplete(progressCur, progressTot)
    if titleText and titleText ~= "" then
        local lower = titleText:lower()
        if lower:find("complete") and not lower:find("incomplete") then
            questComplete = true
        end
    end

    return {
        visible = visible,
        hasQuest = hasQuest,
        activeEnemy = activeEnemy,
        progressCur = progressCur,
        progressTot = progressTot,
        questComplete = questComplete,
        titleText = titleText,
    }
end

function M.isQuestProgressComplete(cur, tot)
    return cur and tot and cur >= tot
end

function M.acquireQuest(targetQuest, hadQuestFrame, questKey, questIndex)
    if not targetQuest then return false end
    if _G.NexusHubAutofarm ~= true then return false end
    if S.questAcquirePending then return false end
    if M.hasActiveQuestProgress() then
        if not M.shouldUpgradeQuest(_G.NexusHubGetLevel()) then
            return false
        end

        M.clearQuestFarmAnchor()
        pcall(function()
            local r = M.getCommFRemote()
            if r then r:InvokeServer("AbandonQuest") end
        end)

        task.wait(0.15)
    end

    S.questAcquirePending = true
    _G.NexusHubLastQuestInvoke = os.clock()
    local args = _G.NexusHubBuildQuestArgs(targetQuest, questKey, questIndex)
    local ok = M.fireStartQuest(args)
    task.wait(0.1)
    S.questAcquirePending = false
    M.unanchorFarmTarget()
    return ok
end

function M.acceptFarmQuest()
    M.ensureAutofarmQuest()
end

function M.queueQuestAcquire(targetQuest, hadQuestFrame, cooldown, questKey, questIndex)
    if not targetQuest then return end
    if S.questAcquirePending then return end
    cooldown = cooldown or 2.5
    if os.clock() - (_G.NexusHubLastQuestInvoke or 0) < cooldown then return end
    task.spawn(function()
        M.acquireQuest(targetQuest, hadQuestFrame, questKey, questIndex)
    end)
end

function M.needsNewQuest()
    if _G.NexusHubAutofarm ~= true then return false end
    local state = M.readQuestState()
    if state.questComplete then return true end
    if state.progressCur and state.progressTot then
        return state.progressCur >= state.progressTot
    end

    if state.visible and state.titleText and state.titleText ~= "" then
        local lower = state.titleText:lower()
        if lower:find("complete") and not lower:find("incomplete") then
            return true
        end

        if (lower:find("defeat") or lower:find("kill")) and not lower:find("complete") then
            local cur, tot = state.titleText:match("%((%d+)/(%d+)%)")
            cur, tot = tonumber(cur), tonumber(tot)
            if cur and tot then
                return cur >= tot
            end

            return false
        end
    end

    return true
end

function M.shouldAcquireQuest(state, level, bestQuest, bestKey, expectedEnemy)
    if not bestQuest then return false, nil, 2.5 end
    local targetQuest = bestQuest
    local cooldown = 2.5
    if state.questComplete then
        return true, targetQuest, 1.25
    end

    if state.hasQuest and state.activeEnemy then
        local matchingQuest = M.findMatchingQuestForEnemy(level, state.activeEnemy)
        if matchingQuest and bestQuest.LevelReq > matchingQuest.LevelReq then
            return true, bestQuest, cooldown
        end
    end

    if state.visible and state.progressCur and state.progressTot and state.progressCur < state.progressTot then
        return false, targetQuest, cooldown
    end

    if not state.visible and not state.hasQuest then
        return true, targetQuest, 0.85
    end

    if state.questComplete then
        return true, targetQuest, 0.85
    end

    if not state.hasQuest or not state.activeEnemy then
        return true, targetQuest, 0.85
    end

    return false, targetQuest, cooldown
end

function M.findNextQuestInChain(level, activeEnemy)
    if not activeEnemy or activeEnemy == "" then return nil end
    local _, key, index = M.findMatchingQuestForEnemy(level, activeEnemy)
    if not key or not index then return nil end
    local questList = Quests[key]
    if type(questList) ~= "table" then return nil end
    local nextQuest = questList[index + 1]
    if nextQuest and level >= (nextQuest.LevelReq or 0) then
        return nextQuest, key, index + 1
    end

    return nil
end

function M.findNextQuestAfterComplete(level, completedEnemy)
    if not completedEnemy or completedEnemy == "" then return nil end
    local chainQuest, chainKey, chainIndex = M.findNextQuestInChain(level, completedEnemy)
    if chainQuest then
        return chainQuest, chainKey, chainIndex
    end

    local matchingQuest, matchingKey, matchingIndex = M.findMatchingQuestForEnemy(level, completedEnemy)
    if not matchingQuest then return nil end
    local minLevelReq = matchingQuest.LevelReq or 0
    local bestNext, bestKey, bestIndex, bestReq = nil, nil, nil, math.huge
    _G.NexusHubForEachQuest(function(questKey, quest, index)
        if not M.shouldSkipQuestKey(questKey) and _G.NexusHubQuestIslandAvailable(questKey) then
            local req = quest.LevelReq or 0
            if level >= req and req > minLevelReq and req < bestReq then
                bestNext = quest
                bestKey = questKey
                bestIndex = index
                bestReq = req
            end
        end
    end)

    if bestNext then
        return bestNext, bestKey, bestIndex
    end

    return nil
end

function M.findBestQuestForLevel(level)
    return _G.NexusHubPickQuest(level, { ignoreIsland = false, ignoreSea = false })
end

function M.isQuestTierStale(level, currentLevelReq)
    if not level or level <= 0 then return false end
    local bestQuest = M.findBestQuestForLevel(level)
    if not bestQuest then return false end
    return (bestQuest.LevelReq or 0) > (currentLevelReq or 0)
end

function M.shouldUpgradeQuest(level, state)
    state = state or M.readQuestState()
    if not level or level <= 0 then return false end
    if not M.hasActiveQuestProgress() and not (state.hasQuest and state.activeEnemy) then
        return false
    end

    if not state.activeEnemy or state.activeEnemy == "" then return false end
    local matchingQuest = M.findMatchingQuestForEnemy(level, state.activeEnemy)
    if not matchingQuest then return false end
    local bestQuest = M.findBestQuestForLevel(level)
    if not bestQuest then return false end
    return (bestQuest.LevelReq or 0) > (matchingQuest.LevelReq or 0)
end

function M.findMatchingQuestForEnemy(level, activeEnemy)
    local bestMatch, bestKey, bestIndex
    local seaMin, seaMax = _G.NexusHubGetSeaQuestBounds()
    _G.NexusHubForEachQuest(function(questKey, quest, index)
        if not M.shouldSkipQuestKey(questKey) and _G.NexusHubQuestIslandAvailable(questKey) then
            local req = quest.LevelReq or 0
            if level >= req and req >= seaMin and req <= seaMax
                and M.questEnemyMatches(activeEnemy, quest) then
                if not bestMatch
                    or quest.LevelReq > bestMatch.LevelReq
                    or (quest.LevelReq == bestMatch.LevelReq and index > (bestIndex or 0)) then
                    bestMatch = quest
                    bestKey = questKey
                    bestIndex = index
                end
            end
        end
    end)

    return bestMatch, bestKey, bestIndex
end

function M.getQuestEnemyName(quest, activeEnemy)
    if activeEnemy and activeEnemy ~= "" then return activeEnemy end
    if quest and quest.Task and type(quest.Task) == "table" then
        for name, _ in pairs(quest.Task) do
            if type(name) == "string" and name ~= "" then
                return M.normalizeEnemyName(name)
            end
        end
    end

    if quest and quest.Name then
        return M.normalizeEnemyName(quest.Name)
    end

    return nil
end

function M.buildQuestInfo(state, level)
    local bestQuest, bestKey, bestIndex = M.findBestQuestForLevel(level)
    if not bestQuest then return nil end
    local targetQuest, targetKey, targetIndex = bestQuest, bestKey, bestIndex
    if state.questComplete then
        local completedEnemy = state.activeEnemy
        if not completedEnemy or completedEnemy == "" then
            local qi = M.getQuestInfoCache()
            completedEnemy = qi and qi.enemy
        end

        if completedEnemy and completedEnemy ~= "" then
            local nextQuest, nextKey, nextIndex = M.findNextQuestAfterComplete(level, completedEnemy)
            if nextQuest then
                targetQuest, targetKey, targetIndex = nextQuest, nextKey, nextIndex
            end
        end
    elseif state.hasQuest and state.activeEnemy and not state.questComplete then
        local matchingQuest, matchingKey, matchingIndex = M.findMatchingQuestForEnemy(level, state.activeEnemy)
        if matchingQuest and (bestQuest.LevelReq or 0) <= (matchingQuest.LevelReq or 0) then
            targetQuest, targetKey, targetIndex = matchingQuest, matchingKey, matchingIndex
        end
    end

    local titleEnemy = nil
    if state.visible and state.titleText and state.titleText ~= "" then
        titleEnemy = select(1, M.parseQuestLabel(state.titleText))
    end

    local upgrading = M.shouldUpgradeQuest(level, state)
    local matchingQuestForUi = state.activeEnemy
        and M.findMatchingQuestForEnemy(level, state.activeEnemy) or nil
    local useUiEnemy = not upgrading and state.hasQuest and state.activeEnemy and not state.questComplete
        and matchingQuestForUi
        and (targetQuest.LevelReq or 0) <= (matchingQuestForUi.LevelReq or 0)
    local expectedEnemy
    if state.questComplete or not useUiEnemy then
        expectedEnemy = M.getQuestEnemyName(targetQuest, nil)
    else
        expectedEnemy = titleEnemy or M.getQuestEnemyName(targetQuest, state.activeEnemy)
    end

    local shouldAcquire, acquireQuest, cooldown = M.shouldAcquireQuest(
        state, level, targetQuest, bestKey, expectedEnemy
    )
    return {
        quest = targetQuest,
        enemy = expectedEnemy or M.getQuestEnemyName(targetQuest, nil),
        island = islandNames[targetKey] or targetKey,
        questKey = targetKey,
        questIndex = targetIndex or 1,
        levelReq = targetQuest.LevelReq,
        args = _G.NexusHubBuildQuestArgs(targetQuest, targetKey, targetIndex),
        progress = state.progressCur,
        progressTotal = state.progressTot,
        shouldAcquire = shouldAcquire,
        acquireQuest = acquireQuest or targetQuest,
        acquireCooldown = cooldown,
        hadQuestFrame = state.visible or state.hasQuest,
    }
end

function M.getQuest(opts)
    opts = opts or {}
    local levelObj = Player:FindFirstChild("Data") and Player.Data:FindFirstChild("Level")
    if not levelObj or levelObj.Value <= 0 then return nil end
    local level = levelObj.Value
    _G.NexusHubHighestLevelSeen = math.max(_G.NexusHubHighestLevelSeen or 0, level)
    level = _G.NexusHubHighestLevelSeen
    local state = M.readQuestState()
    local info = M.buildQuestInfo(state, level)
    if not info then return nil end
    if opts.acquire and info.shouldAcquire then
        if os.clock() - (_G.NexusHubLastQuestInvoke or 0) >= (info.acquireCooldown or 2.5) then
            M.queueQuestAcquire(info.acquireQuest, info.hadQuestFrame, info.acquireCooldown, info.questKey, info.questIndex)
        end
    end

    if opts.travel then
        if info.island and M.islandInCurrentMap(info.island) and not M.isOnIsland(info.island) then
            M.teleportToIsland(info.island)
        end

        if info.enemy then
            M.loadEnemy(info.enemy, info.island)
        end
    end

    if info.progress and info.progressTotal then
        S.lastKnownQuestProgress = {
            cur = info.progress,
            tot = info.progressTotal,
            enemy = info.enemy,
        }
    end

    return {
        quest = info.quest,
        enemy = info.enemy,
        island = info.island,
        questKey = info.questKey,
        questIndex = info.questIndex,
        levelReq = info.levelReq,
        args = info.args,
        progress = info.progress,
        progressTotal = info.progressTotal,
    }
end

function M.applyQuestInfoToCache(info)
    return M.cacheQuestFromInfo(info)
end

function M.cacheQuestFromInfo(info)
    if not info then return nil end
    local cache = {
        quest = info.quest,
        enemy = info.enemy,
        island = info.island,
        questKey = info.questKey,
        questIndex = info.questIndex or 1,
        levelReq = info.levelReq,
        args = info.args,
        progress = info.progress,
        progressTotal = info.progressTotal,
    }
    M.setQuestInfoCache(cache)
    return cache
end

function M.tickAutofarmQuestLoop()
    if _G.NexusHubAutofarm ~= true then return end
    if _G.NexusHubAutoSecondSea == true or _G.NexusHubAutoThirdSea == true then return end
    if M.isFruitSniperActive() or M.isCursedCaptainEngaged() or M.isFactoryRaidEngaged() then return end
    M.ensureAutofarmQuest()
    local cache = M.getQuestInfoCache()
    if not cache or not cache.enemy then
        cache = _G.NexusHubRefreshQuestCache()
        if cache then M.setQuestInfoCache(cache) end
    end

    pcall(M.syncQuestEnemyFromUI)
    _G.NexusHubTravelTick()
end

function M.syncQuestEnemyFromUIThrottled()
    local now = os.clock()
    if not M.getQuestFrameVisible() and now - (_G.NexusHubLastQuestUiSync or 0) < 0.5 then
        local qi = M.getQuestInfoCache()
        return qi and qi.enemy
    end

    _G.NexusHubLastQuestUiSync = now
    return M.syncQuestEnemyFromUI()
end

function M.findQuestEnemy()
    local ok, result = pcall(function()
        local search = M.syncQuestEnemyFromUIThrottled()
        if not search or search == "" then
            local qi = M.getQuestInfoCache()
            search = qi and qi.enemy
        end

        if not search or search == "" then return nil end

        local function enemyMatches(model)
            local hum = model:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return false end
            return M.fuzzyEnemyMatch(model.Name, search) or M.fuzzyEnemyMatch(hum.DisplayName, search)
        end

        local best, bestDist
        local myPos = HumanoidRootPart and HumanoidRootPart.Position
        local enemies = Workspace:FindFirstChild("Enemies")
        if enemies then
            for _, child in ipairs(enemies:GetChildren()) do
                if child:IsA("Model") and enemyMatches(child) then
                    local pos = M.getModelPosition(child)
                    if pos and myPos then
                        local d = (myPos - pos).Magnitude
                        if not bestDist or d < bestDist then
                            best, bestDist = child, d
                        end
                    elseif not best then
                        best = child
                    end
                end
            end
        end

        if best then return best end
        for _, root in ipairs(M.getBossScanRoots()) do
            if root == enemies then continue end
            for _, child in ipairs(root:GetChildren()) do
                if child:IsA("Model") and enemyMatches(child) then
                    return child
                end
            end
        end

        return nil
    end)

    if not ok and _G.NexusHubDevTrace then
        _G.NexusHubDevTrace("find_enemy", result)
    end

    return ok and result or nil
end

function M.unanchorFarmTarget()
    if S.lastAnchoredMobRoot and S.lastAnchoredMobRoot.Parent then
        pcall(function() S.lastAnchoredMobRoot.Anchored = false end)
    end

    S.lastAnchoredMobRoot = nil
end

function M.syncQuestEnemyFromUI()
    local title = M.getQuestTitleTextDirect()
    if title and title ~= "" then
        local lower = title:lower()
        if lower:find("complete") and not lower:find("incomplete") then
            M.markQuestTurnIn()
            S.farmAnchorPos = nil
            S.farmAnchorKey = nil
            local info = M.getQuest()
            if info then M.applyQuestInfoToCache(info) end
            task.defer(function()
                if not M.isFactoryRaidEngaged() and not M.isCursedCaptainEngaged() then
                    _G.NexusHubTryAcceptQuest()
                end
            end)

            return nil
        end

        local enemy, cur, tot = M.parseQuestLabel(title)
        if enemy and enemy ~= "" then
            local qi = M.getQuestInfoCache()
            local enemyChanged = not qi or not M.fuzzyEnemyMatch(qi.enemy or "", enemy)
            if qi then
                local changed = qi.enemy ~= enemy
                if cur and tot and (qi.progress ~= cur or qi.progressTotal ~= tot) then
                    changed = true
                    qi.progress = cur
                    qi.progressTotal = tot
                    if cur >= tot then
                        M.markQuestTurnIn()
                        S.farmAnchorPos = nil
                        S.farmAnchorKey = nil
                        enemyChanged = true
                    end
                end

                if changed then
                    if enemyChanged then
                        _G.NexusHubCancelMove()
                        if M.shouldUpgradeQuest(_G.NexusHubGetLevel()) then
                            M.clearQuestFarmAnchor()
                            local info = M.getQuest()
                            if info then M.applyQuestInfoToCache(info) end
                        else
                            S.farmAnchorPos = nil
                            S.farmAnchorKey = nil
                            local level = _G.NexusHubGetLevel()
                            local matchingQuest, matchingKey, matchingIndex = M.findMatchingQuestForEnemy(level, enemy)
                            qi.enemy = enemy
                            if matchingQuest then
                                qi.quest = matchingQuest
                                qi.questKey = matchingKey
                                qi.questIndex = matchingIndex or 1
                                qi.levelReq = matchingQuest.LevelReq
                                qi.island = islandNames[matchingKey] or matchingKey
                                qi.args = _G.NexusHubBuildQuestArgs(matchingQuest, matchingKey, matchingIndex)
                            end

                            M.setQuestInfoCache(qi)
                        end
                    else
                        M.setQuestInfoCache(qi)
                    end
                end
            elseif enemyChanged then
                local info = M.getQuest()
                if info then M.applyQuestInfoToCache(info) end
            end

            return enemy
        end
    end

    local qi = M.getQuestInfoCache()
    return qi and qi.enemy
end

function M.getQuestTitleTextDirect()
    local ok, text = pcall(function()
        return Player.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text
    end)

    return ok and text or ""
end

function M.getQuestFrameVisible()
    local ok, vis = pcall(function()
        return Player.PlayerGui.Main.Quest.Visible
    end)

    return ok and vis or false
end

local fruitPrices = {
    ["Rocket"]=5000,["Spin"]=7500,["Chop"]=30000,["Spring"]=60000,
    ["Bomb"]=80000,["Smoke"]=100000,["Spike"]=180000,["Flame"]=250000,
    ["Falcon"]=300000,["Ice"]=350000,["Sand"]=420000,["Dark"]=500000,
    ["Ghost"]=525000,["Diamond"]=600000,["Light"]=650000,["Rubber"]=750000,
    ["Barrier"]=800000,["Magma"]=850000,["Quake"]=1000000,["Buddha"]=1200000,
    ["Love"]=1300000,["Spider"]=1500000,["Sound"]=1700000,["Phoenix"]=1800000,
    ["Portal"]=1900000,["Rumble"]=2100000,["Pain"]=2300000,["Blizzard"]=2400000,
    ["Gravity"]=2500000,["Mammoth"]=2700000,["T-Rex"]=2700000,["Dough"]=2800000,
    ["Shadow"]=2900000,["Venom"]=3000000,["Control"]=3200000,["Spirit"]=3400000,
    ["Dragon"]=3500000,["Leopard"]=5000000,["Kitsune"]=8000000,
}
local FRUIT_STORE_KEYS = {
    ["Rocket Fruit"]="Rocket-Rocket",["Spin Fruit"]="Spin-Spin",["Blade Fruit"]="Blade-Blade",
    ["Spring Fruit"]="Spring-Spring",["Bomb Fruit"]="Bomb-Bomb",["Smoke Fruit"]="Smoke-Smoke",
    ["Spike Fruit"]="Spike-Spike",["Flame Fruit"]="Flame-Flame",["Ice Fruit"]="Ice-Ice",
    ["Sand Fruit"]="Sand-Sand",["Dark Fruit"]="Dark-Dark",["Eagle Fruit"]="Eagle-Eagle",
    ["Diamond Fruit"]="Diamond-Diamond",["Light Fruit"]="Light-Light",["Rubber Fruit"]="Rubber-Rubber",
    ["Ghost Fruit"]="Ghost-Ghost",["Magma Fruit"]="Magma-Magma",["Quake Fruit"]="Quake-Quake",
    ["Buddha Fruit"]="Buddha-Buddha",["Human: Buddha Fruit"]="Buddha-Buddha",
    ["Love Fruit"]="Love-Love",["Creation Fruit"]="Creation-Creation",["Spider Fruit"]="Spider-Spider",
    ["Sound Fruit"]="Sound-Sound",["Phoenix Fruit"]="Phoenix-Phoenix",["Portal Fruit"]="Portal-Portal",
    ["Lightning Fruit"]="Lightning-Lightning",["Pain Fruit"]="Pain-Pain",["Blizzard Fruit"]="Blizzard-Blizzard",
    ["Gravity Fruit"]="Gravity-Gravity",["Mammoth Fruit"]="Mammoth-Mammoth",["T-Rex Fruit"]="TRex-TRex",
    ["Dough Fruit"]="Dough-Dough",["Shadow Fruit"]="Shadow-Shadow",["Venom Fruit"]="Venom-Venom",
    ["Control Fruit"]="Control-Control",["Gas Fruit"]="Gas-Gas",["Spirit Fruit"]="Spirit-Spirit",
    ["Leopard Fruit"]="Leopard-Leopard",["Yeti Fruit"]="Yeti-Yeti",["Kitsune Fruit"]="Kitsune-Kitsune",
    ["Dragon Fruit"]="Dragon-Dragon",
}
local fruitStoreConns = {}

function M.unstoreLowestFruit()
    local ok, inv = pcall(function() return CommF_:InvokeServer("getInventory") end)
    if not ok or not inv then return false end
    local lowestName, lowestPrice = nil, math.huge
    for _, item in pairs(inv) do
        if item.Type == "Blox Fruit" then
            local clean = item.Name:gsub(" Fruit$",""):gsub("%-.*","")
            local price = item.Price or fruitPrices[clean]
            if price and price < lowestPrice then
                lowestPrice = price
                lowestName  = item.Name
            end
        end
    end

    if lowestName then
        pcall(function() CommF_:InvokeServer("LoadFruit", lowestName) end)
        return true
    end

    return false
end

function M.equipFruit()
    for _, tool in ipairs(Character:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:find("Fruit") or tool.ToolTip == "Demon Fruit") then
            return true
        end
    end

    for _, tool in ipairs(Player.Backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:find("Fruit") or tool.ToolTip == "Demon Fruit") then
            tool.Parent = Character
            return true
        end
    end

    return false
end

function M.fruitStorageToDisplay(storageName)
    if not storageName or storageName == "" then return storageName end
    if storageName:find(" Fruit$") then return storageName end
    local short = storageName:match("%-(.+)$") or storageName:gsub("%-.*", "")
    if short == "TRex" then return "T-Rex Fruit" end
    return short .. " Fruit"
end

function M.formatFruitSacrificeLabel(entry)
    if not entry then return "" end
    local value = entry.value or 0
    local formatted = tostring(value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (entry.displayName or entry.storageName) .. " (" .. formatted .. ")"
end

function M.getSacrificeFruitOptions()
    local seen = {}
    local out = {}

    local function addEntry(storageName, value, source)
        if not storageName or storageName == "" then return end
        local price = tonumber(value) or 0
        if price <= 999999 then return end
        if seen[storageName] then return end
        seen[storageName] = true
        table.insert(out, {
            storageName = storageName,
            displayName = M.fruitStorageToDisplay(storageName),
            value = price,
            source = source or "treasure",
        })
    end

    local function priceFromName(name)
        if not name then return nil end
        local clean = name:gsub(" Fruit$", ""):gsub("%-.*", "")
        return fruitPrices[clean]
    end

    local remote = M.getCommFRemote()
    if remote then
        local ok, inv = pcall(function() return remote:InvokeServer("getInventory") end)
        if ok and inv then
            for _, item in pairs(inv) do
                if item.Type == "Blox Fruit" then
                    local clean = item.Name:gsub(" Fruit$", ""):gsub("%-.*", "")
                    local price = item.Value or item.Price or fruitPrices[clean]
                    addEntry(item.Name, price, "treasure")
                end
            end
        end

        local ok2, stored = pcall(function() return remote:InvokeServer("getInventoryFruits") end)
        if ok2 and stored then
            for _, item in pairs(stored) do
                if type(item) == "table" then
                    local name = item.Name
                    local price = item.Price or item.Value or priceFromName(name)
                    if name and price then
                        addEntry(name, price, "treasure")
                    end
                end
            end
        end
    end

    for _, tool in ipairs(M.collectFruitTools()) do
        local key = M.getFruitStoreKey(tool)
        local clean = tool.Name:gsub(" Fruit$", ""):gsub("%-.*", "")
        local price = priceFromName(clean) or priceFromName(key)
        if key and price then
            addEntry(key, price, "held")
        end
    end

    table.sort(out, function(a, b)
        if a.value == b.value then
            return (a.displayName or "") < (b.displayName or "")
        end

        return a.value < b.value
    end)

    return out
end

function M.getTreasureFruitsOver1M()
    return M.getSacrificeFruitOptions()
end

function M.hasSacrificeFruit(storageName)
    if not storageName then return false end
    for _, entry in ipairs(M.getSacrificeFruitOptions()) do
        if entry.storageName == storageName then return true end
    end

    return false
end

function M.hasTreasureFruit(storageName)
    return M.hasSacrificeFruit(storageName)
end

function M.loadSacrificeFruit(storageName)
    if not storageName then return false end
    S.thirdSeaSacrificeActive = true
    local ok = pcall(function() CommF_:InvokeServer("LoadFruit", storageName) end)
    task.wait(0.5)
    return ok
end

function M.equipSacrificeFruit(displayName)
    if displayName and M.equipToolByName(displayName) then return true end
    return M.equipFruit()
end

function M.getEquippedSacrificeFruit()

    local function check(container)
        if not container then return nil end
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name:find("Fruit") or tool.ToolTip == "Demon Fruit") then
                return tool
            end
        end

        return nil
    end

    return check(Character) or check(Player.Backpack)
end

function M.hasChip()
    return Player.Backpack:FindFirstChild("Special Microchip")
        or Character:FindFirstChild("Special Microchip")
end

function M.raidTimerVisible()
    local gui = Player.PlayerGui:FindFirstChild("Main")
    local timer = gui and gui:FindFirstChild("Timer")
    return timer and timer.Visible
end

function M.buyChip()
    if M.hasChip() or S.isBuyingChip then return M.hasChip() end
    S.isBuyingChip = true
    if not M.equipFruit() then
        if M.unstoreLowestFruit() then
            task.wait(2)
            M.equipFruit()
        end
    end

    if M.equipFruit() then
        local wasAttacking = S.autoAttack
        S.autoAttack = false
        task.wait(0.1)
        pcall(function()
            CommF_:InvokeServer("RaidsNpc", "Select", S.selectedRaid)
        end)

        task.wait(2)
        if wasAttacking then S.autoAttack = true end
    end

    S.isBuyingChip = false
    return M.hasChip()
end

function M.startRaid()
    if S.isStartingRaid or M.raidTimerVisible() then return end
    S.isStartingRaid = true
    local map        = workspace:FindFirstChild("Map")
    local boatCastle = map and map:FindFirstChild("Boat Castle")
    local raidSummon = boatCastle and boatCastle:FindFirstChild("RaidSummon2")
    if not raidSummon then
        warn("[Nexus Hub] RaidSummon2 not found under Map.Boat Castle")
        S.isStartingRaid = false
        return
    end

    local detectors = {}
    for _, desc in ipairs(raidSummon:GetDescendants()) do
        if desc:IsA("ClickDetector") then
            table.insert(detectors, desc)
        end
    end

    if #detectors == 0 then
        warn("[Nexus Hub] No ClickDetectors found in RaidSummon2")
        S.isStartingRaid = false
        return
    end

    local prevCF = HumanoidRootPart.CFrame
    for _, cd in ipairs(detectors) do
        if M.raidTimerVisible() then break end
        local part = cd.Parent
        if part:IsA("BasePart") then
            local targetPos = part.Position + Vector3.new(0, part.Size.Y / 2 + 3, 0)
            local dist = (HumanoidRootPart.Position - targetPos).Magnitude
            if dist > 10 then
                local t = TweenService:Create(
                    HumanoidRootPart,
                    TweenInfo.new(math.max(dist / 200, 0.3), Enum.EasingStyle.Linear),
                    { CFrame = CFrame.new(targetPos) }
                )
                t:Play()
                t.Completed:Wait()
                task.wait(0.3)
            end
        end

        for _ = 1, 4 do
            if M.raidTimerVisible() then break end
            pcall(function() fireclickdetector(cd) end)
            task.wait(0.4)
        end
    end

    if not M.raidTimerVisible() then
        warn("[Nexus Hub] Raid failed to start - check ClickDetector MaxActivationDistance")
        HumanoidRootPart.CFrame = prevCF
    else
        print("[Nexus Hub] Raid started!")
    end

    task.wait(3)
    S.isStartingRaid = false
end

function M.attachFloat()
    local hrp = M.getHRP()
    if not hrp then return end
    if M.isFarmMoving() and not M.isFruitSniperActive() then return end
    local hum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
    if not hum or hum:GetState() ~= Enum.HumanoidStateType.Swimming then return end
    local bv = hrp:FindFirstChild("FloatBV")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "FloatBV"
        bv.Velocity = Vector3.zero
        bv.Parent = hrp
    end

    bv.MaxForce = Vector3.new(0, 1e9, 0)
end

function M.removeFloat(clearVelocity)
    local plr = game.Players.LocalPlayer
    local hrp = plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        _G.NexusHubClearFloatParts(hrp)
        if clearVelocity then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

function M.farmWeaponMatches(tool)
    if not tool or not tool:IsA("Tool") then return false end
    if tool.ToolTip == S.selectedWeapon then return true end
    local lw = S.selectedWeapon:lower()
    local tip = tostring(tool.ToolTip):lower()
    local name = tool.Name:lower()
    return name:find(lw, 1, true) ~= nil or tip:find(lw, 1, true) ~= nil
end

function M.findFarmWeapon()
    local char = Player.Character
    if not char then return nil end
    for _, tool in ipairs(char:GetChildren()) do
        if M.farmWeaponMatches(tool) then return tool end
    end

    for _, tool in ipairs(Player.Backpack:GetChildren()) do
        if M.farmWeaponMatches(tool) then return tool end
    end

    return nil
end

function M.isFarmWeaponEquipped()
    local char = Player.Character
    if not char then return false end
    for _, tool in ipairs(char:GetChildren()) do
        if M.farmWeaponMatches(tool) then return true end
    end

    return false
end

function M.isFruitTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    return tool.Name:find("Fruit") ~= nil
        or tool.ToolTip == "Demon Fruit"
        or tool.ToolTip == "Blox Fruit"
end

function M.canFarmAttack()
    local char = Player.Character
    if not char then return false end
    if S.selectedWeapon == "Melee" then
        for _, t in ipairs(char:GetChildren()) do
            if M.isFruitTool(t) then return false end
        end

        return true
    end

    return M.isFarmWeaponEquipped()
end

function M.ensureFarmWeapon()
    if not (_G.NexusHubAutofarm == true or S.autoRaid or S.autoBossFarm or S.autoAttack
        or (S.autoMasteryFarm and S.masteryPhase == "farm")
        or (S.autoFactoryRaid and S.factoryRaidEngaged)
        or (S.autoCursedCaptain and S.cursedCaptainCombatTarget)
        or (S.autoThirdSea and S.thirdSeaCombatTarget)
        or (S.autoSecondSea and S.secondSeaCombatTarget)) then return end
    local now = os.clock()
    if now - S.lastWeaponEquipAt < 2.0 then return end
    local char = Player.Character
    if not char then return end
    if S.selectedWeapon == "Melee" then
        for _, t in ipairs(char:GetChildren()) do
            if M.isFruitTool(t) then
                t.Parent = Player.Backpack
                S.lastWeaponEquipAt = now
            end
        end

        return
    end

    if M.isFarmWeaponEquipped() then return end
    S.lastWeaponEquipAt = now
    M.equipWeapon(true)
end

function M.equipWeapon(force)
    if not (_G.NexusHubAutofarm == true or S.autoRaid or S.autoBossFarm or S.autoAttack
        or (S.autoMasteryFarm and S.masteryPhase == "farm")
        or (S.autoFactoryRaid and S.factoryRaidEngaged)
        or (S.autoThirdSea and S.thirdSeaCombatTarget)
        or (S.autoSecondSea and S.secondSeaCombatTarget)) then return end
    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if not force and M.isFarmWeaponEquipped() then return end
    local foundWeapon = M.findFarmWeapon()
    if foundWeapon and foundWeapon.Parent ~= char then
        pcall(function() hum:EquipTool(foundWeapon) end)
        S.lastEquippedType = S.selectedWeapon
        return
    end

    if foundWeapon then
        S.lastEquippedType = S.selectedWeapon
        return
    end

    if not (_G.NexusHubAutofarm == true or S.autoAttack or S.autoRaid or S.autoBossFarm) then
        if M.hasChip() or M.equipFruit() then
            return
        end
    end
end

function M.unequipWeapon()
    local char = Player.Character
    if not char then return end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and M.farmWeaponMatches(tool) then
            tool.Parent = Player.Backpack
        end
    end
end

function M.toolMatchesMasteryType(tool, mType)
    if not tool or not tool:IsA("Tool") then return false end
    if mType == "Devil Fruit" then
        return M.isFruitTool(tool)
    end

    if mType == "Sword" then
        return tool.ToolTip == "Sword"
    end

    if mType == "Gun" then
        return tool.ToolTip == "Gun"
    end

    if mType == "Melee" then
        if M.isFruitTool(tool) or tool.ToolTip == "Sword" or tool.ToolTip == "Gun" then
            return false
        end

        return tool:FindFirstChild("Level") ~= nil
    end

    return false
end

function M.scanMasteryToolNames()
    local names, seen = { "Auto" }, {}
    for _, parent in ipairs({ Player.Backpack, Player.Character }) do
        for _, tool in ipairs(parent:GetChildren()) do
            if tool:IsA("Tool") and M.toolMatchesMasteryType(tool, S.masteryFarmType) and not seen[tool.Name] then
                seen[tool.Name] = true
                table.insert(names, tool.Name)
            end
        end
    end

    return names
end

function M.findMasteryTool()
    if S.masteryFarmItem and S.masteryFarmItem ~= "" and S.masteryFarmItem ~= "Auto" then
        for _, parent in ipairs({ Player.Character, Player.Backpack }) do
            local tool = parent:FindFirstChild(S.masteryFarmItem)
            if tool and tool:IsA("Tool") and M.toolMatchesMasteryType(tool, S.masteryFarmType) then
                return tool
            end
        end

        return nil
    end

    for _, parent in ipairs({ Player.Character, Player.Backpack }) do
        for _, tool in ipairs(parent:GetChildren()) do
            if tool:IsA("Tool") and M.toolMatchesMasteryType(tool, S.masteryFarmType) then
                return tool
            end
        end
    end

    return nil
end

function M.getMobHpPercent(model)
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.MaxHealth <= 0 then return 100 end
    return (hum.Health / hum.MaxHealth) * 100
end

function M.getMasteryFarmTarget()
    if _G.NexusHubAutofarm == true then
        if M.isFactoryRaidEngaged() or M.isCursedCaptainEngaged() or M.isFruitSniperActive() then
            return nil
        end

        return M.findQuestEnemy()
    end

    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies or not HumanoidRootPart then return nil end
    local best, bestDist
    for _, model in ipairs(enemies:GetChildren()) do
        if model:IsA("Model") and model.Name ~= "Core" then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and hrp then
                local d = (HumanoidRootPart.Position - hrp.Position).Magnitude
                if d <= Settings.Distance and (not bestDist or d < bestDist) then
                    best, bestDist = model, d
                end
            end
        end
    end

    return best
end

function M.stowMasteryTool()
    local char = Player.Character
    if not char then return end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and M.toolMatchesMasteryType(tool, S.masteryFarmType) then
            tool.Parent = Player.Backpack
        end
    end
end

function M.equipMasteryTool()
    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local tool = M.findMasteryTool()
    if not tool then return false end
    if tool.Parent ~= char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and M.farmWeaponMatches(t) then
                t.Parent = Player.Backpack
            end
        end

        pcall(function() hum:EquipTool(tool) end)
    end

    return tool.Parent == char
end

function M.resetMasteryFarmState()
    S.masteryPhase = "farm"
    S.masteryTargetModel = nil
    M.stowMasteryTool()
    if S.autoMasteryFarm or _G.NexusHubAutofarm == true then
        M.equipWeapon(true)
    end
end

function M.pressSkillKey(keyLetter)
    local key = Enum.KeyCode[keyLetter]
    if not key then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, key, false, game)
        task.wait(0.07)
        VirtualInputManager:SendKeyEvent(false, key, false, game)
    end)
end

function M.fireMasterySkill(tool, keyLetter, targetPos, targetPart)
    if not tool or not targetPos then return end
    local mousePos = tool:FindFirstChild("MousePos")
    if mousePos and mousePos:IsA("Vector3Value") then
        mousePos.Value = targetPos
    end

    if S.masteryFarmType == "Devil Fruit" then
        local remote = tool:FindFirstChild("RemoteEvent")
        if remote then
            local ok = pcall(function() remote:FireServer(targetPos) end)
            if not ok then
                pcall(function() remote:FireServer(CFrame.new(targetPos)) end)
            end
        end
    elseif S.masteryFarmType == "Gun" then
        local shoot = tool:FindFirstChild("RemoteFunctionShoot")
        if shoot and targetPart then
            pcall(function() shoot:InvokeServer(targetPos, targetPart) end)
        end
    end

    M.pressSkillKey(keyLetter)
end

function M.masteryPhaseUsesM1()
    return S.masteryFarmType == "Melee" or S.masteryFarmType == "Sword"
end

function M.useMasterySkills(target)
    local now = os.clock()
    if now - S.lastMasterySkillAt < S.MASTERY_SKILL_CD then return end
    local tool = M.findMasteryTool()
    if not tool then return end
    if tool.Parent ~= Player.Character then
        M.equipMasteryTool()
        tool = M.findMasteryTool()
        if not tool or tool.Parent ~= Player.Character then return end
    end

    local targetPart = target:FindFirstChild("HumanoidRootPart")
        or target:FindFirstChild("Head")
        or target.PrimaryPart
    if not targetPart then return end
    local targetPos = targetPart.Position
    local skills = {
        { S.masterySkillZ, "Z" },
        { S.masterySkillX, "X" },
        { S.masterySkillC, "C" },
        { S.masterySkillV, "V" },
        { S.masterySkillF, "F" },
    }
    for _, entry in ipairs(skills) do
        if entry[1] then
            S.lastMasterySkillAt = now
            M.fireMasterySkill(tool, entry[2], targetPos, targetPart)
            return
        end
    end
end

function M.updateMasteryFarm(target)
    if not S.autoMasteryFarm or not target then return end
    local hum = target:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 or not target.Parent then
        if S.masteryTargetModel == target then
            M.resetMasteryFarmState()
        end

        return
    end

    if S.masteryTargetModel ~= target then
        S.masteryTargetModel = target
        S.masteryPhase = "farm"
        M.stowMasteryTool()
        M.equipWeapon(true)
    end

    local hpPct = M.getMobHpPercent(target)
    if hpPct > S.masteryDamagePercent then
        if S.masteryPhase ~= "farm" then
            S.masteryPhase = "farm"
            M.stowMasteryTool()
            M.equipWeapon(true)
        end
    else
        if S.masteryPhase ~= "mastery" then
            S.masteryPhase = "mastery"
            M.equipMasteryTool()
        end

        M.useMasterySkills(target)
    end
end

local RegisterAttack = Net:WaitForChild("RE/RegisterAttack", 15)
local RegisterHit    = Net:WaitForChild("RE/RegisterHit", 15)

function M.collectAttackTarget(model, targets)
    if not model or not model:IsA("Model") then return end
    local hum  = model:FindFirstChildOfClass("Humanoid", true)
    if not hum or hum.Health <= 0 or not HumanoidRootPart then return end
    local targetPart = model:FindFirstChild("Head", true)
        or model:FindFirstChild("HumanoidRootPart", true)
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
    if not targetPart then return end
    local dist = (HumanoidRootPart.Position - targetPart.Position).Magnitude
    if dist <= Settings.Distance then
        table.insert(targets, { model, targetPart })
    end
end

function M.performAttackOnTarget(targetPart)
    if not targetPart then return end
    if RegisterAttack then
        pcall(function()
            RegisterAttack:FireServer(0)
        end)
    end

    if RegisterHit then
        pcall(function()
            RegisterHit:FireServer(targetPart, {})
        end)
    end
end

function M.performDoughPackAttack(targets)
    if not targets or #targets == 0 then return end
    local enemyList = {}
    for i = 1, #targets do
        local model = targets[i][1]
        local part = targets[i][2]
        if not part and model then
            part = model:FindFirstChild("HumanoidRootPart", true)
                or model:FindFirstChild("Head", true)
        end

        if model and part then
            table.insert(enemyList, { model, part })
        end
    end

    if #enemyList == 0 then return end
    if RegisterAttack then
        pcall(function() RegisterAttack:FireServer(0) end)
    end

    if RegisterHit then
        pcall(function() RegisterHit:FireServer(enemyList[1][2], enemyList) end)
    end

    if os.clock() - (S.lastDoughSimRadiusAt or 0) >= 2 then
        S.lastDoughSimRadiusAt = os.clock()
        local sethidden = sethiddenproperty or function() end
        pcall(sethidden, Player, "SimulationRadius", math.huge)
    end
end

function M.startDoughPackAttackLoop()
    if S.doughPackAttackLoopRunning then return end
    S.doughPackAttackLoopRunning = true
    task.spawn(function()
        while _G.NexusHubLoaded do
            if (S.autoDoughPrince or S.autoDoughKing) and S.doughBringMobActive then
                if os.clock() - (S.lastDoughWeaponEquipAt or 0) >= 1.5 then
                    S.lastDoughWeaponEquipAt = os.clock()
                    M.ensureFarmWeapon()
                end

                local targets = {}
                M.collectCakeLandAttackTargets(targets, S.doughPackPos or S.doughFarmAnchor)
                if #targets > 0 then
                    M.performDoughPackAttack(targets)
                end

                task.wait(0.05)
            else
                task.wait(0.25)
            end
        end

        S.doughPackAttackLoopRunning = false
    end)
end

function M.doAutoAttack()
    if _G.NexusHubAutoAttackLoopRunning then return end
    _G.NexusHubAutoAttackLoopRunning = true
    task.spawn(function()
        while _G.NexusHubAutoAttack == true do
            if not HumanoidRootPart then break end
            if (S.autoDoughPrince or S.autoDoughKing) and S.doughBringMobActive then
                task.wait(0.08)
                continue
            end

            if _G.NexusHubAutofarm == true or S.autoRaid or S.autoBossFarm
                or (S.autoElite and S.eliteCombatTarget)
                or (S.autoMasteryFarm and S.masteryPhase == "farm")
                or (S.autoFactoryRaid and S.factoryRaidEngaged) then
                M.ensureFarmWeapon()
            elseif S.autoMasteryFarm and S.masteryPhase == "mastery" and M.masteryPhaseUsesM1() then
                M.equipMasteryTool()
            end

            local targets = {}
            if S.autoFactoryRaid and S.factoryRaidEngaged and S.factoryRaidTarget then
                M.collectAttackTarget(S.factoryRaidTarget, targets)
            elseif S.autoSaber and S.saberCombatTarget then
                M.collectAttackTarget(S.saberCombatTarget, targets)
            elseif S.autoIndra and S.indraCombatTarget then
                M.collectAttackTarget(S.indraCombatTarget, targets)
            elseif S.autoElite and S.eliteCombatTarget then
                M.collectAttackTarget(S.eliteCombatTarget, targets)
            elseif S.autoDarkbeard and S.darkbeardCombatTarget then
                M.collectAttackTarget(S.darkbeardCombatTarget, targets)
            elseif S.autoCursedCaptain and S.cursedCaptainCombatTarget then
                M.collectAttackTarget(S.cursedCaptainCombatTarget, targets)
            elseif M.isAutoDoughRaidActive() and S.doughRaidCombatTarget then
                M.collectAttackTarget(S.doughRaidCombatTarget, targets)
            elseif S.autoBossFarm and S.currentBossTarget then
                local boss = M.resolveBossTarget(S.currentBossTarget.Name)
                if boss then
                    M.collectAttackTarget(boss, targets)
                end
            elseif _G.NexusHubAutofarm == true or S.autoMasteryFarm then
                if not M.isFruitSniperActive() and not M.isCursedCaptainEngaged() and not M.isFactoryRaidEngaged() then
                    local questTarget = M.getMasteryFarmTarget()
                    if S.autoMasteryFarm and S.masteryPhase == "mastery" then
                        questTarget = S.masteryTargetModel or questTarget
                    end

                    if questTarget then
                        M.collectAttackTarget(questTarget, targets)
                    end
                end
            elseif S.autoMaterialFarm then
                local mat = M.findMaterialEnemy()
                if mat then
                    M.collectAttackTarget(mat, targets)
                end
            else
                local enemiesFolder = Workspace:FindFirstChild("Enemies")
                if enemiesFolder then
                    for _, enemy in ipairs(enemiesFolder:GetDescendants()) do
                        if enemy:IsA("Model") then
                            M.collectAttackTarget(enemy, targets)
                        end
                    end
                end

                for _, otherPlayer in ipairs(Players:GetPlayers()) do
                    if otherPlayer ~= Player and otherPlayer.Character then
                        M.collectAttackTarget(otherPlayer.Character, targets)
                    end
                end
            end

            local blockM1InMastery = S.autoMasteryFarm and S.masteryPhase == "mastery"
                and not M.masteryPhaseUsesM1()
            if #targets >= 1 and not blockM1InMastery then
                M.performAttackOnTarget(targets[1][2])
            end

            task.wait(math.max(Settings.AttackDelay, MIN_ATTACK_DELAY))
        end

        _G.NexusHubAutoAttackLoopRunning = false
    end)
end

function M.setAutoAttack(val)
    val = val == true
    if S.autoAttack == val and _G.NexusHubAutoAttack == val then return end
    S.autoAttack = val
    _G.NexusHubAutoAttack = val
    if val then
        M.equipWeapon()
        M.doAutoAttack()
    else
        M.unequipWeapon()
    end
end

local waterWalk = Instance.new("Part", workspace)
waterWalk.Transparency = 1
waterWalk.Name         = "NexusHubWaterWalk"
waterWalk.CanCollide   = false
waterWalk.Size         = Vector3.new(1000, 1, 1000)
waterWalk.Anchored     = true
M.AddConnection(RunService.RenderStepped:Connect(function()
    if HumanoidRootPart then
        waterWalk.CanCollide = S.walkOnWater
        waterWalk.Position = Vector3.new(
            HumanoidRootPart.Position.X,
            -4.5,
            HumanoidRootPart.Position.Z
        )
    end
end))

M.AddConnection(RunService.Heartbeat:Connect(function(dt)
    if S.autoStats then
        local now = os.clock()
        if now - S.lastAutoStatsAt >= 1.0 then
            S.lastAutoStatsAt = now
            pcall(function() CommF_:InvokeServer("AddPoint", S.selectedStat, S.addAmount) end)
        end
    end

    if Humanoid and Humanoid.WalkSpeed ~= S.SetWalkSpeed and _G.NexusHubAutofarm ~= true then
        Humanoid.WalkSpeed = S.SetWalkSpeed
    end

    if not (_G.NexusHubAutofarm == true or S.autoRaid or S.autoBossFarm or S.chestFarmEnabled or S.autoMaterialFarm
        or M.isFruitSniperActive()
        or (S.autoPirateRaid and S.pirateRaidEngaged and S.pirateRaidTarget)
        or (S.autoFactoryRaid and S.factoryRaidEngaged)
        or S.autoMasteryFarm
        or S.autoIndra or S.autoDarkbeard or S.autoCursedCaptain
        or (S.autoElite and S.eliteCombatTarget)
        or S.autoDoughPrince or S.autoDoughKing
        or S.autoPray or S.autoTryLuck or S.autoSoulReaper or S.autoSaber
        or _G.NexusHubAutoSecondSea == true or _G.NexusHubAutoThirdSea == true
        or S.manualTweenActive == true) then
        _G.NexusHubLightPhysicsClean()
        if not (S.autoSeaFarm or S.autoLeviathan or _G.NexusHubAutoSecondSea == true
            or _G.NexusHubAutoThirdSea == true or S.manualTweenActive == true or _G.NexusHubIsMoving()) then
            _G.NexusHubCancelMove()
        end

        return
    end

    if M.isFruitSniperActive() then
        return
    end

    if M.isFactoryRaidEngaged() then
        local hrp = M.getHRP()
        if hrp then
            if not S.autoAttack then M.setAutoAttack(true) end
            M.ensureFarmWeapon()
            local core = M.findFactoryCore()
            if core then S.factoryRaidTarget = core end
            M.tickFactoryRaidMovement(hrp, dt)
        end

        return
    end

    if (S.autoDoughPrince or S.autoDoughKing) and S.doughBringMobActive and not S.doughRaidCombatTarget then
        _G.NexusHubSetFarmNoclip(true)
        local hrp = M.getHRP()
        if hrp then
            M.tickCakeLandMobPull()
            M.tickDoughCakeLandHover(hrp)
        end

        if not S.autoAttack then M.setAutoAttack(true) end
        M.equipWeapon()
        return
    end

    local isRaidActive = S.autoRaid and M.raidTimerVisible()
    local isBossActive = S.autoBossFarm and S.currentBossTarget
    if _G.NexusHubAutofarm == true or isRaidActive or isBossActive or S.chestFarmEnabled or S.autoMaterialFarm
        or (S.autoSoulReaper and S.soulReaperTarget) or (S.autoSaber and S.saberCombatTarget)
        or (S.autoIndra and S.indraCombatTarget) or (S.autoDarkbeard and S.darkbeardCombatTarget)
        or (S.autoCursedCaptain and S.cursedCaptainCombatTarget)
        or (S.autoElite and S.eliteCombatTarget)
        or (M.isAutoDoughRaidActive() and (S.doughRaidCombatTarget or S.doughBringMobActive))
        or (S.autoSecondSea and S.secondSeaCombatTarget)
        or (S.autoThirdSea and S.thirdSeaCombatTarget)
        or (S.autoPirateRaid and S.pirateRaidEngaged and S.pirateRaidTarget)
        or (S.autoFactoryRaid and S.factoryRaidEngaged)
        or S.autoMasteryFarm then
        if not (S.autoAttack or S.chestFarmEnabled) then M.setAutoAttack(true) end
        if S.chestFarmEnabled and not (_G.NexusHubAutofarm == true or isRaidActive or isBossActive or S.autoMaterialFarm) then
            return
        end

        local hrp = M.getHRP()
        if not hrp then return end
        local target
        if M.isCursedCaptainEngaged() and S.cursedCaptainCombatTarget then
            local hum = S.cursedCaptainCombatTarget:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                target = S.cursedCaptainCombatTarget
            else
                S.cursedCaptainCombatTarget = nil
            end
        elseif isBossActive then
            target = M.resolveBossTarget(S.currentBossTarget.Name)
            if not target then
                M.nudgeTowardBossSpawn(S.currentBossTarget)
                local spawnPos = M.getBossSpawn(S.currentBossTarget)
                if spawnPos and not M.isFarmMoving() then
                    M.moveTo(spawnPos + Vector3.new(0, 50, 0))
                end

                return
            end
        elseif isRaidActive then
            for _, enemy in ipairs(Workspace.Enemies:GetChildren()) do
                local hum = enemy:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then target = enemy; break end
            end
        elseif S.autoFactoryRaid and S.factoryRaidEngaged and S.factoryRaidTarget then
            local hum = S.factoryRaidTarget:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                target = S.factoryRaidTarget
            else
                S.factoryRaidTarget = nil
            end
        elseif _G.NexusHubAutofarm == true and _G.NexusHubAutoSecondSea ~= true and _G.NexusHubAutoThirdSea ~= true
            and not M.isCursedCaptainEngaged() and not M.isFactoryRaidEngaged() then
            target = M.noteQuestEnemyPresence()
            if not target then
                M.clearFarmHoverConstraint(hrp)
            end

            local qi = M.getQuestInfoCache()
            if not target and qi and not (_G.NexusHubAutoSecondSea == true or _G.NexusHubAutoThirdSea == true) then
                local onQuestIsland = M.isOnQuestFarmIsland(qi.island)
                    or (qi.island == "Cursed Ship" and M.isInsideCursedShip())
                if not onQuestIsland then
                    if not _G.NexusHubIsMoving() and os.clock() - (_G.NexusHubLastTravelNudge or 0) >= 1.5 then
                        _G.NexusHubLastTravelNudge = os.clock()
                        pcall(function() M.travelToQuestIsland(qi.island, qi.enemy) end)
                    end
                elseif qi.enemy and M.shouldBlockQuestTravel(qi.enemy, qi.island) then
                elseif qi.island and M.islandInCurrentMap(qi.island) and not M.isNearIsland(qi.island, 3200) then
                    if not _G.NexusHubIsMoving() then
                        pcall(function() M.travelToQuestIsland(qi.island, qi.enemy) end)
                    end
                elseif M.needsQuestSpawnTravel(qi.enemy, qi.island) and not _G.NexusHubIsMoving() then
                    pcall(function() M.moveToQuestSpawn(qi.enemy, qi.island) end)
                end
            end
        elseif S.autoMasteryFarm then
            target = M.getMasteryFarmTarget()
        elseif S.autoSecondSea and S.secondSeaCombatTarget then
            local hum = S.secondSeaCombatTarget:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                target = S.secondSeaCombatTarget
            else
                S.secondSeaCombatTarget = nil
            end
        elseif S.autoThirdSea and S.thirdSeaCombatTarget then
            local hum = S.thirdSeaCombatTarget:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                target = S.thirdSeaCombatTarget
            else
                S.thirdSeaCombatTarget = nil
            end
        elseif S.autoMaterialFarm then
            target = M.findMaterialEnemy()
        elseif S.autoSoulReaper and S.soulReaperTarget then
            local hum = S.soulReaperTarget:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                target = S.soulReaperTarget
            else
                S.soulReaperTarget = nil
            end
        elseif S.autoSaber and S.saberCombatTarget then
            local hum = S.saberCombatTarget:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                target = S.saberCombatTarget
            else
                S.saberCombatTarget = nil
            end
        elseif S.autoIndra and S.indraCombatTarget then
            local hum = S.indraCombatTarget:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                target = S.indraCombatTarget
            else
                S.indraCombatTarget = nil
            end
        elseif S.autoElite and S.eliteCombatTarget then
            local hum = S.eliteCombatTarget:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                target = S.eliteCombatTarget
            else
                S.eliteCombatTarget = nil
            end
        elseif S.autoDarkbeard and S.darkbeardCombatTarget then
            local hum = S.darkbeardCombatTarget:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                target = S.darkbeardCombatTarget
            else
                S.darkbeardCombatTarget = nil
            end
        elseif M.isAutoDoughRaidActive() and S.doughRaidCombatTarget then
            local hum = S.doughRaidCombatTarget:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                target = S.doughRaidCombatTarget
            else
                S.doughRaidCombatTarget = nil
            end
        elseif S.autoPirateRaid and S.pirateRaidEngaged and S.pirateRaidTarget then
            local hum = S.pirateRaidTarget:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                target = S.pirateRaidTarget
            else
                S.pirateRaidTarget = nil
            end
        end

        if target and S.autoMasteryFarm and target.Name ~= "Core" then
            M.updateMasteryFarm(target)
        end

        if target then
            local targetPos = M.getModelPosition(target)
            if targetPos then
                local pos = hrp.Position
                if _G.NexusHubAutofarm == true or S.autoMasteryFarm or M.isCursedCaptainEngaged()
                    or (S.autoThirdSea and S.thirdSeaCombatTarget)
                    or (S.autoSecondSea and S.secondSeaCombatTarget)
                    or (M.isAutoDoughRaidActive() and S.doughRaidCombatTarget)
                    or ((S.autoDoughPrince or S.autoDoughKing) and S.doughBringMobActive) then
                    if S.autoThirdSea and S.thirdSeaCombatTarget
                        and M.isThirdSeaRipIndraBoss(S.thirdSeaCombatTarget) then
                        M.applyThirdSeaRipIndraHover(hrp, targetPos, S.thirdSeaCombatTarget, dt)
                    else
                        M.applyFarmHover(hrp, targetPos)
                    end
                else
                local orbitY = M.getFarmOrbitY()
                local horizDist = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
                local heightAbove = pos.Y - targetPos.Y
                local hover = targetPos + Vector3.new(0, orbitY, 0)
                if S.autoDarkbeard and S.darkbeardCombatTarget and target == S.darkbeardCombatTarget then
                    hover = M.getDarkbeardHoverPos(targetPos)
                end

                local needApproach = horizDist > S.orbitRadius + 10 or heightAbove < orbitY - 4
                if needApproach then
                    local needMove = not _G.NexusHubIsMoving()
                    if S.bossFollowGoal and (S.bossFollowGoal - hover).Magnitude > 25 then
                        needMove = true
                    end

                    if needMove then
                        S.bossFollowGoal = hover
                        if S.autoDarkbeard and S.darkbeardCombatTarget and target == S.darkbeardCombatTarget then
                            M.moveToDarkbeard(hover)
                        else
                            M.moveTo(hover)
                        end
                    end
                else
                    M.cancelFarmMove()
                    S.bossFollowGoal = nil
                    M.unanchorFarmTarget()
                    if os.clock() - S.lastSwitch >= S.snapTime then
                        S.snapIndex  = (S.snapIndex % #S.snapOffsets) + 1
                        S.lastSwitch = os.clock()
                    end

                    local orbitPos = M.getFarmOrbitPos(targetPos, S.snapIndex)
                    if S.autoDarkbeard and S.darkbeardCombatTarget and target == S.darkbeardCombatTarget then
                        orbitPos = M.getDarkbeardSafePos(orbitPos)
                    end

                    local orbitAllowed = isBossActive or isRaidActive
                        or S.autoMaterialFarm
                        or (S.autoSoulReaper and S.soulReaperTarget)
                        or (S.autoSaber and S.saberCombatTarget)
                        or (S.autoIndra and S.indraCombatTarget)
                        or (S.autoElite and S.eliteCombatTarget)
                        or (S.autoDarkbeard and S.darkbeardCombatTarget)
                        or (S.autoCursedCaptain and S.cursedCaptainCombatTarget)
                        or (M.isAutoDoughRaidActive() and S.doughRaidCombatTarget)
                        or (S.autoSecondSea and S.secondSeaCombatTarget)
                        or (S.autoThirdSea and S.thirdSeaCombatTarget)
                        or (S.autoPirateRaid and S.pirateRaidEngaged and S.pirateRaidTarget)
                    if orbitAllowed then
                        local tnow = os.clock()
                        if tnow - S.lastOrbitAt >= 0.15 then
                            S.lastOrbitAt = tnow
                            hrp.CFrame = CFrame.new(orbitPos, targetPos)
                        end
                    end
                end
                end
            end
        end
    end
end))

M.AddConnection(RunService.Heartbeat:Connect(function(dt)
    if _G.NexusHubPhysicsWatchUntil and _G.NexusHubPhysicsWatchUntil > 0 then
        if os.clock() < _G.NexusHubPhysicsWatchUntil and _G.NexusHubAutofarm ~= true then
            _G.NexusHubLightPhysicsClean()
        elseif os.clock() >= _G.NexusHubPhysicsWatchUntil then
            _G.NexusHubPhysicsWatchUntil = 0
        end
    end

    if _G.NexusHubAutofarm == true and _G.NexusHubAutoSecondSea ~= true and _G.NexusHubAutoThirdSea ~= true
        and not _G.NexusHubIsMoving()
        and not M.isFactoryRaidEngaged() and not M.isCursedCaptainEngaged() then
        if M.isCursedShipQuestActive() then
            _G.NexusHubSetFarmNoclip(true)
            if not M.isInsideCursedShip() and os.clock() - (_G.NexusHubLastCursedShipTick or 0) >= 0.8 then
                _G.NexusHubLastCursedShipTick = os.clock()
                pcall(function()
                    local qi = M.getQuestInfoCache()
                    M.tickCursedShipEntry(qi and qi.enemy)
                end)
            end
        end

        local qi = M.getQuestInfoCache()
        local onQuestIsland = not qi or not qi.island or M.isOnQuestFarmIsland(qi.island)
            or (qi.island == "Cursed Ship" and M.isInsideCursedShip())
        local blockTravel = qi and qi.enemy and onQuestIsland
            and M.shouldBlockQuestTravel(qi.enemy, qi.island)
        if not blockTravel and os.clock() - (_G.NexusHubLastTravelNudge or 0) >= 2.0 then
            _G.NexusHubLastTravelNudge = os.clock()
            pcall(_G.NexusHubTravelTick)
        end
    end

    if _G.NexusHubLoaded and _G.NexusHubMoveGoal and _G.NexusHubAllowMove == true and not S.manualTweenConn then
        _G.NexusHubDoMoveStep(dt)
    end
end))

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded and task.wait(2) do
        if not S.autoRaid then continue end
        if M.raidTimerVisible() then
            if not S.autoAttack then M.setAutoAttack(true) end
        else
            if S.autoAttack then M.setAutoAttack(false) end
            if not M.hasChip() and not S.isBuyingChip then
                task.spawn(M.buyChip)
            elseif M.hasChip() and not S.isStartingRaid then
                task.spawn(M.startRaid)
            end
        end
    end
end)

function M.farmBossEntry(boss)
    if not boss then return end
    M.clearBossResolveCache()
    S.bossMissingSince = nil
    S.currentBossTarget = boss
    S.bossFollowGoal = nil
    S.patrolState = "MOVING"
    if boss.Island and not M.isOnIsland(boss.Island) then
        M.teleportToIsland(boss.Island)
        task.wait(2)
    end

    M.ensureBossQuest(boss, true)
    M.nudgeTowardBossSpawn(boss)
    task.wait(0.5)
    S.patrolState = "FIGHTING"
    if not S.autoAttack then M.setAutoAttack(true) end
    while S.autoBossFarm and S.currentBossTarget == boss do
        if M.resolveBossTarget(boss.Name) or M.isBossAlive(boss.Name) then
            S.bossMissingSince = nil
            M.ensureBossQuest(boss)
        else
            if not S.bossMissingSince then S.bossMissingSince = os.clock() end
            if os.clock() - S.bossMissingSince >= S.BOSS_FAIL_GRACE then
                break
            end

            M.nudgeTowardBossSpawn(boss)
            M.ensureBossQuest(boss)
        end

        task.wait(0.35)
    end

    if S.currentBossTarget == boss then
        S.currentBossTarget = nil
        S.bossFollowGoal = nil
        M.clearBossResolveCache()
        S.bossMissingSince = nil
    end

    S.patrolState = "IDLE"
end

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded and task.wait(1) do
        if not S.autoBossFarm then
            S.currentBossTarget = nil
            S.bossFollowGoal = nil
            S.bossMissingSince = nil
            M.clearBossResolveCache()
            S.patrolState = "IDLE"
            continue
        end

        if S.currentBossTarget then continue end
        local b = M.pickFarmBoss()
        if not b then continue end
        M.farmBossEntry(b)
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(1)
        if not S.autoMaterialFarm then continue end
        if not Humanoid or not HumanoidRootPart or Humanoid.Health <= 0 then continue end
        local seaHere = PLACE_TO_SEA[game.PlaceId]
        if seaHere and seaHere ~= S.selectedMaterialSea then
            if os.clock() - S.lastMaterialWarn > 10 then
                M.notify("Materials",
                    "You are in " .. seaHere .. " but selected " .. S.selectedMaterialSea ..
                    " - travel to " .. S.selectedMaterialSea .. " first", 5)
                S.lastMaterialWarn = os.clock()
            end

            continue
        end

        local entries = M.getSelectedMaterialEntries()
        if not entries or #entries == 0 then continue end
        if M.findMaterialEnemy() then continue end
        if M.patrolMaterialSpawns(entries) then
            task.wait(2)
            continue
        end

        S.materialPatrolIx = S.materialPatrolIx + 1
        local entry = entries[((S.materialPatrolIx - 1) % #entries) + 1]
        if entry.Island and not M.isOnIsland(entry.Island) then
            M.notify("Materials", "Heading to " .. entry.Island .. " for " .. entry.Name, 4)
            M.teleportToIsland(entry.Island)
            task.wait(3)
        end
    end
end)

function M.rollFruitGacha()
    local remote = M.getCommFRemote()
    if not remote then return nil, "CommF_ missing" end
    local ok, res = pcall(function()
        return remote:InvokeServer("Cousin", "Buy")
    end)

    if ok then return res end
    return nil, res
end

function M.getFruitRollDelay(res)
    if res == nil then return 30 end
    local text = tostring(res):lower()
    if text:find("wait") or text:find("cool") or text:find("later") or text:find("hour")
        or text:find("not enough") or text:find("beli") or text:find("money") then
        return 60
    end

    return 10
end

function M.isFruitTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    if tool.Name == "Special Microchip" or tool:GetAttribute("WeaponType") then return false end
    if tool.Name:lower():find("fruit") then return true end
    local tip = tostring(tool.ToolTip or "")
    return tip == "Demon Fruit" or tip:lower():find("eat to gain") ~= nil
end

function M.getFruitStoreKey(tool)
    local original = tool:GetAttribute("OriginalName")
    if typeof(original) == "string" and original ~= "" then return original end
    if FRUIT_STORE_KEYS[tool.Name] then return FRUIT_STORE_KEYS[tool.Name] end
    local base = tool.Name:gsub(" Fruit$", "")
    if base:find(":") then
        local prefix = base:match("^([^:]+)")
        return prefix and (prefix .. "-" .. base) or (base .. "-" .. base)
    end

    return base .. "-" .. base
end

function M.fruitToolStored(tool)
    return not tool or not tool.Parent
        or (tool.Parent ~= Player.Backpack and tool.Parent ~= Player.Character)
end

function M.storeFruitTool(tool)
    if not tool or not tool.Parent then return false end
    local key = M.getFruitStoreKey(tool)
    if not key then return false end
    local keys = { key }
    if tool.Name ~= key then table.insert(keys, tool.Name) end
    for _, storeKey in ipairs(keys) do
        pcall(function() CommF_:InvokeServer("StoreFruit", storeKey, tool) end)
        task.wait(0.35)
        if M.fruitToolStored(tool) then return true end
    end

    return false
end

function M.collectFruitTools()
    local out, seen = {}, {}

    local function add(tool)
        if M.isFruitTool(tool) and not seen[tool] then
            seen[tool] = true
            table.insert(out, tool)
        end
    end

    if Player.Backpack then
        for _, t in ipairs(Player.Backpack:GetChildren()) do add(t) end
    end

    if Player.Character then
        for _, t in ipairs(Player.Character:GetChildren()) do add(t) end
    end

    return out
end

function M.tryStoreAllFruits()
    if S.thirdSeaSacrificeActive then return 0 end
    local stored = 0
    for _, tool in ipairs(M.collectFruitTools()) do
        local name = tool.Name
        if M.storeFruitTool(tool) then
            stored = stored + 1
            M.notify("Fruit", "Stored " .. name, 3)
        end

        task.wait(0.25)
    end

    return stored
end

function M.onFruitToolAdded(child)
    if S.thirdSeaSacrificeActive then return end
    if not S.autoStoreFruit or not M.isFruitTool(child) then return end
    local name = child.Name
    task.wait(0.15)
    if M.storeFruitTool(child) then M.notify("Fruit", "Stored " .. name, 3) end
end

function M.setAutoStoreFruitListener(enabled)
    for _, conn in ipairs(fruitStoreConns) do pcall(function() conn:Disconnect() end) end
    M.clearTable(fruitStoreConns)
    if not enabled then return end
    local bp = Player.Backpack.ChildAdded:Connect(M.onFruitToolAdded)
    table.insert(fruitStoreConns, bp)
    M.AddConnection(bp)
    if Player.Character then
        local cc = Player.Character.ChildAdded:Connect(M.onFruitToolAdded)
        table.insert(fruitStoreConns, cc)
        M.AddConnection(cc)
    end
end

M.AddConnection(Player.CharacterAdded:Connect(function()
    if S.autoStoreFruit then M.setAutoStoreFruitListener(true) end
end))

function M.isKnownSpawnFruitName(name)
    if not name or name == "" then return false end
    if name:find("Fruit", 1, true) then return true end
    local clean = name:gsub(" Fruit$", ""):gsub("%-.*", "")
    if fruitPrices[clean] then return true end
    for storeName, storeKey in pairs(FRUIT_STORE_KEYS) do
        if name == storeName or name == storeKey then return true end
    end

    local a, b = name:match("^([^%-]+)%-(.+)$")
    if a and b and a == b and fruitPrices[a] then return true end
    return false
end

function M.isSpawnedWorldFruit(obj)
    if not obj or obj.Parent ~= Workspace then return false end
    if obj:GetAttribute("WeaponType") then return false end
    if obj.Name == "Special Microchip" then return false end
    if obj:IsA("Model") then
        local fruitChild = obj:FindFirstChild("Fruit")
        if fruitChild and fruitChild:FindFirstChild("RootPart") then
            return true
        end

        if obj:FindFirstChild("Handle", true) and M.isKnownSpawnFruitName(obj.Name) then
            return true
        end

        return false
    end

    if obj:IsA("Tool") then
        if not obj:FindFirstChild("Handle") then return false end
        if M.isKnownSpawnFruitName(obj.Name) then return true end
        local tip = tostring(obj.ToolTip or "")
        if tip == "Demon Fruit" or tip == "Blox Fruit" or tip:lower():find("eat to gain", 1, true) then
            return true
        end

        return false
    end

    return false
end

function M.getFruitHandlePart(fruit)
    if not fruit then return nil end
    if fruit:IsA("Model") then
        local fruitChild = fruit:FindFirstChild("Fruit")
        if fruitChild and fruitChild:FindFirstChild("RootPart") then
            return fruitChild.RootPart
        end
    end

    return fruit:FindFirstChild("Handle", true)
        or fruit.PrimaryPart
        or fruit:FindFirstChildWhichIsA("BasePart", true)
end

function M.collectSpawnedFruits()
    local out = {}
    for _, obj in ipairs(Workspace:GetChildren()) do
        if M.isSpawnedWorldFruit(obj) then
            table.insert(out, obj)
        end
    end

    return out
end

function M.findNearestSpawnedFruit()
    local hrp = M.getHRP()
    if not hrp then return nil end
    local best, bestDist
    for _, obj in ipairs(M.collectSpawnedFruits()) do
        local handle = M.getFruitHandlePart(obj)
        if handle then
            local d = (hrp.Position - handle.Position).Magnitude
            if not bestDist or d < bestDist then
                best, bestDist = obj, d
            end
        end
    end

    return best
end

function M.clearFruitEspTag(obj)
    if not obj then return end
    local handle = M.getFruitHandlePart(obj)
    if not handle then return end
    local tag = handle:FindFirstChild("NexusHubFruitEsp")
    if tag then pcall(function() tag:Destroy() end) end
end

function M.clearFruitEsp()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Tool") or obj:IsA("Model") then
            M.clearFruitEspTag(obj)
        end
    end
end

function M.updateFruitEsp()
    if not S.fruitEspEnabled then return end
    local hrp = M.getHRP()
    if not hrp then return end
    local seen = {}
    for _, obj in ipairs(M.collectSpawnedFruits()) do
        if obj and obj.Parent then
            seen[obj] = true
            local handle = M.getFruitHandlePart(obj)
            if handle then
                local bill = handle:FindFirstChild("NexusHubFruitEsp")
                if not bill then
                    bill = Instance.new("BillboardGui")
                    bill.Name = "NexusHubFruitEsp"
                    bill.AlwaysOnTop = true
                    bill.Size = UDim2.new(0, 200, 0, 50)
                    bill.StudsOffset = Vector3.new(0, 2.5, 0)
                    bill.Parent = handle
                    local label = Instance.new("TextLabel")
                    label.Name = "Text"
                    label.Size = UDim2.new(1, 0, 1, 0)
                    label.BackgroundTransparency = 1
                    label.Font = Enum.Font.GothamBold
                    label.TextSize = 14
                    label.TextColor3 = Color3.fromRGB(255, 230, 80)
                    label.TextStrokeTransparency = 0.4
                    label.Parent = bill
                end

                local label = bill:FindFirstChild("Text")
                if label then
                    local dist = math.floor((hrp.Position - handle.Position).Magnitude / 3)
                    label.Text = obj.Name .. "\n" .. dist .. "m"
                end
            end
        end
    end

    for _, obj in ipairs(Workspace:GetChildren()) do
        if not seen[obj] then
            M.clearFruitEspTag(obj)
        end
    end
end

M.HauntedPos = {
    Gravestone = Vector3.new(-8654, 140, 6167),
    DeathKing  = Vector3.new(-8934, 142, 6036),
    Altar      = Vector3.new(-8932, 142, 6063),
}

function M.isSea2()
    return PLACE_TO_SEA[game.PlaceId] == "Sea 2"
end

function M.secondSeaNotify(msg)
    if os.clock() - S.lastSecondSeaNotify < 8 then return end
    S.lastSecondSeaNotify = os.clock()
    M.notify("Auto 2nd Sea", msg, 5)
end

function M.getDressrosaProgress(stage)
    local ok, res = pcall(function()
        return CommF_:InvokeServer("DressrosaQuestProgress", stage)
    end)

    if ok then return res end
    return nil
end

function M.findIceAdmiral()
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end
    for _, model in ipairs(enemies:GetChildren()) do
        if model:IsA("Model") and model.Name == "Ice Admiral" then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then return model end
        end
    end

    return nil
end

function M.moveSecondSeaTo(position)
    if not position then return nil end
    _G.NexusHubSecondSeaTravel = true
    local hrp = M.getHRP()
    if not hrp then return nil end
    if (hrp.Position - position).Magnitude < 3 then
        hrp.CFrame = CFrame.new(position)
        return nil
    end

    if _G.NexusHubIsMoving() and _G.NexusHubMoveGoal and (_G.NexusHubMoveGoal - position).Magnitude < 12 then
        return S.ActiveTween
    end

    return M.moveTo(position)
end

function M.ensureSecondSeaNearIce()
    local hrp = M.getHRP()
    if not hrp then return false end
    if M.isOnIsland("Ice") then return true end
    local ice = M.findIslandModel("Ice")
    if not ice then return false end
    local iceCenter = ice:GetPivot().Position
    local horiz = M.horizontalDistance(hrp.Position, iceCenter)
    if horiz < 700 and math.abs(hrp.Position.Y - iceCenter.Y) < 400 then
        return true
    end

    if not _G.NexusHubIsMoving() then
        M.moveSecondSeaTo(iceCenter + Vector3.new(0, 50, 0))
    end

    return false
end

function M.finishSecondSeaUnlock()
    pcall(function() CommF_:InvokeServer("DressrosaQuestProgress", "Ice Admiral") end)
    task.wait(0.4)
    pcall(function() CommF_:InvokeServer("DressrosaQuestProgress", "Detective") end)
    task.wait(0.4)
    pcall(function() CommF_:InvokeServer("DressrosaQuestProgress", "Dressrosa") end)
    task.wait(0.4)
    pcall(function() CommF_:InvokeServer("TravelDressrosa") end)
end

function M.tickAutoSecondSea()
    if not S.autoSecondSea then return end
    if M.isSea2() then
        M.secondSeaNotify("Already in Sea 2")
        S.autoSecondSea = false
        _G.NexusHubAutoSecondSea = false
        _G.NexusHubSecondSeaTravel = false
        S.secondSeaCombatTarget = nil
        return
    end

    if not M.isSea1() then
        M.secondSeaNotify("Sea 1 only")
        _G.NexusHubSecondSeaTravel = false
        return
    end

    local dressrosa = M.getDressrosaProgress("Dressrosa")
    if dressrosa == 0 then
        _G.NexusHubSecondSeaTravel = false
        M.secondSeaNotify("Traveling to Sea 2")
        pcall(function() CommF_:InvokeServer("TravelDressrosa") end)
        task.wait(3)
        if M.isSea2() then
            S.autoSecondSea = false
            _G.NexusHubAutoSecondSea = false
        end

        return
    end

    local iceMap = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Ice")
    local iceDoor = iceMap and iceMap:FindFirstChild("Door")
    local doorClosed = iceDoor and iceDoor:IsA("BasePart") and iceDoor.CanCollide
    if doorClosed then
        S.secondSeaCombatTarget = nil
        if not M.hasToolByName("Key") then
            _G.NexusHubSecondSeaTravel = false
            pcall(function() CommF_:InvokeServer("DressrosaQuestProgress", "Detective") end)
            task.wait(0.5)
            return
        end

        if not M.ensureSecondSeaNearIce() then
            return
        end

        local doorPos = iceDoor.Position + Vector3.new(0, 3, 0)
        local hrp = M.getHRP()
        if hrp and (hrp.Position - doorPos).Magnitude > 8 then
            if not _G.NexusHubIsMoving() then
                M.moveSecondSeaTo(doorPos)
            end

            return
        end

        _G.NexusHubSecondSeaTravel = false
        M.equipToolByName("Key")
        M.touchInteract(iceDoor)
        return
    end

    local admiral = S.secondSeaCombatTarget or M.findIceAdmiral()
    if admiral then
        _G.NexusHubSecondSeaTravel = false
        local hum = admiral:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            S.secondSeaCombatTarget = nil
            M.finishSecondSeaUnlock()
            return
        end

        S.secondSeaCombatTarget = admiral
        M.attachFloat()
        if not S.autoAttack then M.setAutoAttack(true) end
        return
    end

    S.secondSeaCombatTarget = nil
    if not M.ensureSecondSeaNearIce() then
        return
    end

    local roomPos = Vector3.new(1345, 37, -1329)
    local hrp = M.getHRP()
    if hrp and (hrp.Position - roomPos).Magnitude > 8 then
        if not _G.NexusHubIsMoving() then
            M.moveSecondSeaTo(roomPos)
        end

        return
    end

    _G.NexusHubSecondSeaTravel = false
end

M.ThirdSeaPos = {
    Bartilo      = Vector3.new(-456.28952, 73.0200958, 299.895966),
    SwanPirate   = Vector3.new(1057.92761, 137.614319, 1242.08069),
    Jeremy       = Vector3.new(2099.88159, 448.931, 648.997375),
    BartiloRoom  = Vector3.new(-1836.141, 10.458, 1714.492),
    Trevor       = Vector3.new(-337.478, 331.133, 643.445),
    DonSwan      = Vector3.new(2288.802, 15.187, 863.035),
    KingRedHead  = Vector3.new(-1926, 13, 1738),
    ColosseumPrison = Vector3.new(-1836.141, 10.458, 1714.492),
    MansionTable = Vector3.new(2285.5, 15.5, 880),
    RipIndra     = Vector3.new(-26952.289, 21.529, 329.352),
    MrCaptainDock = Vector3.new(-3893.383, 8.254, -3688.504),
}

function M.thirdSeaNotify(msg)
    if os.clock() - S.lastThirdSeaNotify < 8 then return end
    S.lastThirdSeaNotify = os.clock()
    M.notify("Auto 3rd Sea", msg, 5)
end

function M.getBartiloProgress()
    local ok, res = pcall(function()
        return CommF_:InvokeServer("BartiloQuestProgress", "Bartilo")
    end)

    if ok then return res end
    return nil
end

function M.getFlamingoAccess()
    local ok, res = pcall(function() return CommF_:InvokeServer("GetUnlockables") end)
    if ok and type(res) == "table" then return res.FlamingoAccess end
    return nil
end

function M.isThirdSeaCaptainUnlocked(flamingo)
    flamingo = flamingo ~= nil and flamingo or M.getFlamingoAccess()
    if flamingo == true then return true end
    local zou = M.getZQuestProgress("Zou")
    if zou == true or zou == 1 or zou == "1" then return true end
    if type(zou) == "string" and zou:lower():find("done") then return true end
    return false
end

function M.isThirdSeaTravelReady()
    return M.isSea3()
end

function M.getTalkTrevor(step)
    local ok, res = pcall(function() return CommF_:InvokeServer("TalkTrevor", tostring(step or "1")) end)
    if ok then return res end
    return nil
end

function M.getZQuestProgress(action)
    local ok, res = pcall(function() return CommF_:InvokeServer("ZQuestProgress", action or "Check") end)
    if ok then return res end
    return nil
end

function M.normalizeThirdSeaZCheck(val)
    if val == nil or val == false then return nil end
    local n = tonumber(val)
    if n == 0 or n == 1 then return n end
    return nil
end

function M.isDonSwanAlive()
    local swan = M.findDonSwan()
    if not swan then return false end
    local hum = swan:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

function M.getZQuestCheck()
    for _ = 1, 3 do
        local z = M.normalizeThirdSeaZCheck(M.getZQuestProgress("Check"))
        if z ~= nil then return z end
        task.wait(0.15)
    end

    return nil
end

function M.isThirdSeaSacrificeDone(talkTrevor)
    talkTrevor = talkTrevor ~= nil and talkTrevor or M.getTalkTrevor("1")
    return talkTrevor == 0
end

function M.isThirdSeaDonSwanDone(zCheck)
    if S.thirdSeaDonSwanDone then return true end
    zCheck = zCheck ~= nil and zCheck or M.normalizeThirdSeaZCheck(M.getZQuestProgress("Check"))
    return zCheck == 0 or zCheck == 1
end

function M.isThirdSeaRipIndraAlive()
    local boss = M.findThirdSeaRipIndra()
    if not boss then return false end
    local hum = boss:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

function M.syncThirdSeaFlagsFromServer(useRetry)
    local bartilo = M.getBartiloProgress()
    if bartilo == 3 then
        S.thirdSeaCellPuzzleDone = true
    end

    local zCheck
    if useRetry then
        zCheck = M.getZQuestCheck()
    else
        zCheck = M.normalizeThirdSeaZCheck(M.getZQuestProgress("Check"))
    end

    if M.isThirdSeaDonSwanDone(zCheck) then
        S.thirdSeaDonSwanDone = true
        S.thirdSeaCellPuzzleDone = true
    end

    if M.isThirdSeaCaptainUnlocked() and M.isSea3() then
        S.thirdSeaIndraQuestStarted = false
        S.thirdSeaIndraNeedsRetalk = false
        S.thirdSeaIndraWasFighting = false
    end
end

function M.getThirdSeaProgressDetails()
    local details = {
        stageId = "unknown",
        label = "Unknown",
        bartilo = nil,
        level = 0,
        sacrificeDone = false,
        donSwanDone = false,
        talkTrevor = nil,
        zCheck = nil,
        flamingo = nil,
    }
    if M.isSea3() then
        details.stageId = "done"
        details.label = "Complete - already in Sea 3"
        return details
    end

    if not M.isSea2() then
        details.stageId = "wrong_sea"
        details.label = "Wrong sea - need Sea 2"
        return details
    end

    details.bartilo = M.getBartiloProgress()
    details.level = M.getPlayerLevel() or 0
    if details.bartilo == nil or details.bartilo == 0 then
        details.stageId = "bartilo_swan"
        details.label = "Bartilo 1/4 - Kill 50 Swan Pirates"
        return details
    end

    if details.bartilo == 1 then
        details.stageId = "bartilo_jeremy"
        details.label = "Bartilo 2/4 - Kill Jeremy"
        return details
    end

    if details.bartilo == 2 then
        details.stageId = "bartilo_puzzle"
        details.label = "Bartilo 3/4 - Plate puzzle"
        return details
    end

    if details.bartilo ~= 3 then
        details.stageId = "bartilo_unknown"
        details.label = "Bartilo - unknown (" .. tostring(details.bartilo) .. ")"
        return details
    end

    if details.level < 1500 then
        details.stageId = "need_level"
        details.label = "Need level 1500 (" .. details.level .. "/1500)"
        return details
    end

    details.flamingo = M.getFlamingoAccess()
    details.talkTrevor = M.getTalkTrevor("1")
    details.zCheck = M.normalizeThirdSeaZCheck(M.getZQuestProgress("Check"))
    if M.isThirdSeaCaptainUnlocked(details.flamingo) then
        details.stageId = "captain"
        details.label = "Talk to Mr. Captain at Green Zone dock"
        details.sacrificeDone = true
        details.donSwanDone = true
        return details
    end

    if not M.isThirdSeaSacrificeDone(details.talkTrevor) then
        details.stageId = "sacrifice"
        details.label = "Sacrifice 1M+ fruit to Trevor"
        return details
    end

    details.sacrificeDone = true
    if not M.isThirdSeaDonSwanDone(details.zCheck) then
        details.donSwanDone = false
        if M.isDonSwanAlive() then
            details.stageId = "don_swan"
            details.label = "Kill Don Swan (Mansion)"
        else
            details.stageId = "don_swan"
            details.label = "Kill Don Swan - travel to Mansion"
        end

        return details
    end

    details.donSwanDone = true
    if S.thirdSeaIndraNeedsRetalk then
        details.stageId = "king_red_head"
        details.label = "Died on Indra - talk to King Red Head again"
        return details
    end

    if M.isOnIndraIsland() and M.isThirdSeaRipIndraAlive() then
        details.stageId = "rip_indra"
        details.label = "Fight Rip Indra - orbit dodge, kill for Sea 3"
        return details
    end

    if M.isOnIndraIsland() and not M.isThirdSeaRipIndraAlive()
        and (details.zCheck == 0 or details.zCheck == 1) then
        details.stageId = "captain"
        details.label = "Indra defeated - talk to Mr. Captain at Green Zone dock"
        return details
    end

    details.stageId = "king_red_head"
    if details.zCheck == 1 then
        details.label = "Don Swan done - talk to King Red Head"
    else
        details.label = "Talk to King Red Head - then fight Rip Indra"
    end

    return details
end

function M.reportThirdSeaStageChange(prog)
    if not prog or prog.stageId == S.thirdSeaStageId then return end
    S.thirdSeaStageId = prog.stageId
    M.thirdSeaNotify("Stage: " .. prog.label)
    if _G.NexusHubUpdateThirdSeaProgress then
        pcall(_G.NexusHubUpdateThirdSeaProgress)
    end
end

function M.markDonSwanCleared()
    if S.thirdSeaDonSwanDone then return end
    S.thirdSeaDonSwanDone = true
    S.thirdSeaCellPuzzleDone = true
    M.thirdSeaNotify("Don Swan defeated - go to King Red Head")
    if _G.NexusHubUpdateThirdSeaProgress then
        pcall(_G.NexusHubUpdateThirdSeaProgress)
    end
end

function M.isThirdSeaRipIndraBoss(model)
    if not model then return false end
    local name = model.Name
    return name == "rip_indra" or name:find("rip_indra") ~= nil
end

function M.normalizeColosseumSymbol(text)
    if not text or text == "" then return nil end
    text = text:gsub("%s+", "")
    local lower = text:lower()
    if lower == "â" or lower == "inf" or lower == "infinity" or lower == "infinite" then
        return "â"
    end

    return text:sub(1, 1):upper()
end

function M.scanMansionTableSymbols()
    if S.thirdSeaMansionSymbols and #S.thirdSeaMansionSymbols >= 8 then
        return S.thirdSeaMansionSymbols
    end

    local dressrosa = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Dressrosa")
    if not dressrosa then return nil end
    local mansionCenter = M.ThirdSeaPos.MansionTable
    local entries = {}
    for _, desc in ipairs(dressrosa:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local sym = M.normalizeColosseumSymbol(desc.Text)
            if sym then
                local part = desc:FindFirstAncestorWhichIsA("BasePart")
                if part and (part.Position - mansionCenter).Magnitude <= 350 then
                    table.insert(entries, {
                        sym = sym,
                        x = part.Position.X,
                        z = part.Position.Z,
                    })
                end
            end
        end
    end

    if #entries < 8 then return nil end
    table.sort(entries, function(a, b)
        if math.abs(a.z - b.z) > 2 then return a.z < b.z end
        return a.x < b.x
    end)

    local order = {}
    for i = 1, math.min(8, #entries) do
        order[i] = entries[i].sym
    end

    if #order >= 8 then
        S.thirdSeaMansionSymbols = order
    end

    return S.thirdSeaMansionSymbols
end

function M.buildColosseumSymbolButtonMap(center, radius)
    local map = {}
    local dressrosa = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Dressrosa")
    if not dressrosa then return map end
    for _, desc in ipairs(dressrosa:GetDescendants()) do
        if desc:IsA("BasePart") and (desc.Position - center).Magnitude <= radius then
            local symbol = nil
            for _, child in ipairs(desc:GetDescendants()) do
                if child:IsA("TextLabel") or child:IsA("TextButton") then
                    symbol = M.normalizeColosseumSymbol(child.Text)
                    if symbol then break end
                end
            end

            if not symbol then
                local sv = desc:FindFirstChild("Symbol") or desc:FindFirstChild("Text")
                if sv and sv:IsA("StringValue") then
                    symbol = M.normalizeColosseumSymbol(sv.Value)
                end
            end

            if symbol then
                map[symbol] = desc
            end
        end
    end

    return map
end

function M.tickThirdSeaColosseumCell()
    if os.clock() - S.lastThirdSeaCellPuzzleAt < 14 then return false end
    S.lastThirdSeaCellPuzzleAt = os.clock()
    local hrp = M.getHRP()
    if not hrp then return false end
    local symbols = M.scanMansionTableSymbols()
    if not symbols then
        if (hrp.Position - M.ThirdSeaPos.MansionTable).Magnitude > 40 then
            if not _G.NexusHubIsMoving() then
                M.moveThirdSeaTo(M.ThirdSeaPos.MansionTable)
            end

            M.thirdSeaNotify("Reading mansion table symbols")
            return false
        end

        symbols = M.scanMansionTableSymbols()
        if not symbols then
            M.thirdSeaNotify("Could not read mansion table - stand near the table")
            return false
        end
    end

    local prisonCenter = M.ThirdSeaPos.KingRedHead
    if (hrp.Position - prisonCenter).Magnitude > 120 then
        if not _G.NexusHubIsMoving() then
            M.moveThirdSeaTo(M.ThirdSeaPos.ColosseumPrison)
        end

        return false
    end

    local buttonMap = M.buildColosseumSymbolButtonMap(prisonCenter, 160)
    if not next(buttonMap) then
        buttonMap = M.buildColosseumSymbolButtonMap(M.ThirdSeaPos.ColosseumPrison, 200)
    end

    local plates = Workspace:FindFirstChild("Map")
        and Workspace.Map:FindFirstChild("Dressrosa")
        and Workspace.Map.Dressrosa:FindFirstChild("BartiloPlates")
    for i, sym in ipairs(symbols) do
        local part = buttonMap[sym]
        if not part and plates then
            part = plates:FindFirstChild("Plate" .. i)
        end

        if part then
            hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
            M.touchInteract(part)
            task.wait(0.4)
        end
    end

    S.thirdSeaCellPuzzleDone = true
    M.thirdSeaNotify("Cell puzzle done - talk to King Red Head")
    return true
end

function M.clearThirdSeaIndraDeathWatch()
    if S.thirdSeaIndraDeathConn then
        pcall(function() S.thirdSeaIndraDeathConn:Disconnect() end)
        S.thirdSeaIndraDeathConn = nil
    end
end

function M.bindThirdSeaIndraDeathWatch(hum)
    M.clearThirdSeaIndraDeathWatch()
    if not hum then return end
    S.thirdSeaIndraDeathConn = hum.Died:Connect(function()
        M.onThirdSeaRipIndraPlayerDied()
    end)
end

function M.teleportThirdSeaOutOfIndra()
    if not M.isOnIndraIsland() then return false end
    local hrp = M.getHRP()
    if not hrp then return false end
    local exitPos = M.getKingRedHeadPos() + Vector3.new(0, 6, 0)
    hrp.CFrame = CFrame.new(exitPos)
    if _G.NexusHubIsMoving() then
        pcall(_G.NexusHubCancelMove)
    end

    _G.NexusHubThirdSeaTravel = false
    return true
end

function M.onThirdSeaRipIndraPlayerDied()
    if not S.thirdSeaIndraWasFighting and not S.thirdSeaIndraQuestStarted
        and not (S.thirdSeaCombatTarget and M.isThirdSeaRipIndraBoss(S.thirdSeaCombatTarget)) then
        return
    end

    S.thirdSeaIndraWasFighting = false
    S.thirdSeaIndraQuestStarted = false
    S.thirdSeaIndraNeedsRetalk = true
    S.thirdSeaRipIndraCutsceneActive = false
    S.thirdSeaCombatTarget = nil
    S.thirdSeaRipIndraAnchor = nil
    S.thirdSeaRipIndraOrbitAngle = 0
    M.clearThirdSeaIndraDeathWatch()
    if _G.NexusHubIsMoving() then
        pcall(_G.NexusHubCancelMove)
    end

    _G.NexusHubThirdSeaTravel = false
    if S.autoAttack then M.setAutoAttack(false) end
    M.teleportThirdSeaOutOfIndra()
    M.thirdSeaNotify("Died on Indra - talk to King Red Head again (no fight TP)")
end

function M.findKingRedHeadNpc()
    local npcs = Workspace:FindFirstChild("NPCs")
    if npcs then
        local npc = npcs:FindFirstChild("King Red Head")
        if npc then return npc end
    end

    for _, d in ipairs(Workspace:GetDescendants()) do
        if d.Name == "King Red Head" and d:IsA("Model") then
            return d
        end
    end

    return nil
end

function M.getKingRedHeadPos()
    local npc = M.findKingRedHeadNpc()
    if npc then
        local hrp = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
        if hrp then return hrp.Position end
    end

    return M.ThirdSeaPos.KingRedHead
end

function M.tickThirdSeaKingRedHead()
    if M.isOnIndraIsland() and S.thirdSeaIndraQuestStarted and not S.thirdSeaIndraNeedsRetalk then
        return true
    end

    if S.thirdSeaIndraNeedsRetalk and M.isOnIndraIsland() then
        M.teleportThirdSeaOutOfIndra()
        return true
    end

    S.thirdSeaCombatTarget = nil
    local hrp = M.getHRP()
    if not hrp then return false end
    local targetPos = M.getKingRedHeadPos()
    if M.isNearThirdSeaPos(targetPos, 35) then
        _G.NexusHubThirdSeaTravel = false
        if os.clock() - S.lastThirdSeaRedHeadTalkAt < 3 then
            return true
        end

        S.lastThirdSeaRedHeadTalkAt = os.clock()
        M.thirdSeaNotify("Talking to King Red Head...")
        pcall(function() CommF_:InvokeServer("ZQuestProgress", "Check") end)
        task.wait(0.8)
        pcall(function() CommF_:InvokeServer("ZQuestProgress", "Begin") end)
        task.wait(0.5)
        pcall(function() CommF_:InvokeServer("ZQuestProgress", "General") end)
        S.thirdSeaIndraNeedsRetalk = false
        S.thirdSeaIndraQuestStarted = true
        for _ = 1, 30 do
            task.wait(0.5)
            if M.isOnIndraIsland() or M.findThirdSeaRipIndra() then
                M.thirdSeaNotify("Indra quest started - fighting Rip Indra")
                return true
            end
        end

        return true
    end

    if not _G.NexusHubIsMoving() then
        M.moveThirdSeaTo(targetPos)
    end

    return false
end

function M.applyThirdSeaRipIndraHover(hrp, targetPos, boss, dt)
    if not hrp or not targetPos then return end
    if not Humanoid or Humanoid.Health <= 0 then return end
    if S.thirdSeaIndraNeedsRetalk or not M.isOnIndraIsland() then return end
    _G.NexusHubSetFarmNoclip(true)
    M.attachFloat()
    if _G.NexusHubIsMoving() then
        _G.NexusHubCancelMove()
    end

    local step = dt or 0.016
    local orbitRadius = 44
    local spinSpeed = 5.2
    S.thirdSeaRipIndraOrbitAngle = (S.thirdSeaRipIndraOrbitAngle or 0) + spinSpeed * step
    local angle = S.thirdSeaRipIndraOrbitAngle
    local bobY = 46 + math.sin(angle * 2.1) * 10
    local offset = Vector3.new(math.cos(angle) * orbitRadius, bobY, math.sin(angle) * orbitRadius)
    local orbitPos = targetPos + offset
    hrp.CFrame = CFrame.new(orbitPos, targetPos)
    local vel = hrp.AssemblyLinearVelocity
    if vel.Magnitude > 2 then
        hrp.AssemblyLinearVelocity = vel * 0.25
    end

    local bossHrp = boss and boss:FindFirstChild("HumanoidRootPart")
    local bossHum = boss and boss:FindFirstChildOfClass("Humanoid")
    if bossHrp and bossHum and bossHum.Health > 0 and not S.thirdSeaRipIndraCutsceneActive then
        if not S.thirdSeaRipIndraAnchor then
            S.thirdSeaRipIndraAnchor = bossHrp.CFrame
        end

        pcall(function()
            bossHrp.CFrame = S.thirdSeaRipIndraAnchor
            bossHrp.Anchored = true
            bossHrp.CanCollide = false
            bossHum.WalkSpeed = 0
        end)
    end
end

function M.isThirdSeaRipIndraCutsceneReady(hum)
    if not hum then return false end
    local maxH = hum.MaxHealth
    if not maxH or maxH <= 0 then return false end
    return hum.Health <= (maxH * 0.52)
end

function M.moveThirdSeaTo(position)
    if not position then return nil end
    _G.NexusHubThirdSeaTravel = true
    local hrp = M.getHRP()
    if not hrp then return nil end
    if (hrp.Position - position).Magnitude < 3 then
        hrp.CFrame = CFrame.new(position)
        return nil
    end

    if _G.NexusHubIsMoving() and _G.NexusHubMoveGoal and (_G.NexusHubMoveGoal - position).Magnitude < 12 then
        return S.ActiveTween
    end

    return M.moveTo(position)
end

function M.findDonSwan()
    return M.findBoss("Don Swan")
end

function M.findThirdSeaRipIndra()
    return M.findRipIndra()
end

function M.isOnIndraIsland()
    local map = Workspace:FindFirstChild("Map")
    local indra = map and map:FindFirstChild("IndraIsland")
    local part = indra and indra:FindFirstChild("Part")
    local hrp = M.getHRP()
    if not hrp or not part then return false end
    return (hrp.Position - part.Position).Magnitude <= 1000
end

function M.isNearThirdSeaPos(pos, radius)
    local hrp = M.getHRP()
    if not hrp or not pos then return false end
    return (hrp.Position - pos).Magnitude <= (radius or 25)
end

function M.thirdSeaEngageBoss(boss)
    if not boss then return false end
    local hum = boss:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if M.isThirdSeaRipIndraBoss(boss) then
        if S.thirdSeaIndraNeedsRetalk then return false end
        if not M.isOnIndraIsland() then return false end
        if not Humanoid or Humanoid.Health <= 0 then return false end
        S.thirdSeaIndraWasFighting = true
        S.thirdSeaIndraQuestStarted = true
    end

    S.thirdSeaCombatTarget = boss
    _G.NexusHubThirdSeaTravel = false
    _G.NexusHubSetFarmNoclip(true)
    M.attachFloat()
    if not S.autoAttack then M.setAutoAttack(true) end
    M.equipWeapon()
    return true
end

function M.thirdSeaNudgeBoss(bossName, island)
    pcall(function() M.loadEnemy(bossName, island) end)
    for _, b in ipairs(M.getCurrentBosses()) do
        if b.Name == bossName then
            M.nudgeTowardBossSpawn(b)
            break
        end
    end
end

function M.tickThirdSeaRipIndraFight()
    if S.thirdSeaIndraNeedsRetalk then
        M.tickThirdSeaKingRedHead()
        return false
    end

    if not Humanoid or Humanoid.Health <= 0 then
        return false
    end

    if not M.isOnIndraIsland() then
        return false
    end

    local ripIndra = S.thirdSeaCombatTarget or M.findThirdSeaRipIndra()
    if ripIndra then
        local hum = ripIndra:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 then
            S.thirdSeaCombatTarget = nil
            S.thirdSeaRipIndraAnchor = nil
            S.thirdSeaRipIndraCutsceneActive = false
            S.thirdSeaIndraWasFighting = false
            S.thirdSeaIndraQuestStarted = false
            if S.autoAttack then M.setAutoAttack(false) end
            M.thirdSeaNotify("Indra defeated - go to Mr. Captain at Green Zone dock")
            if M.isOnIndraIsland() then
                M.teleportThirdSeaToCaptainDock()
            end

            return true
        end

        if hum and M.isThirdSeaRipIndraCutsceneReady(hum) and not S.thirdSeaRipIndraCutsceneActive then
            S.thirdSeaRipIndraCutsceneActive = true
            S.thirdSeaRipIndraAnchor = nil
            pcall(function()
                local bossHrp = ripIndra:FindFirstChild("HumanoidRootPart")
                if bossHrp then bossHrp.Anchored = false end
            end)

            if S.autoAttack then M.setAutoAttack(false) end
            M.thirdSeaNotify("Rip Indra at 50% - dodging until he dies")
        end

        if S.thirdSeaRipIndraCutsceneActive then
            S.thirdSeaCombatTarget = ripIndra
            S.thirdSeaIndraWasFighting = true
            local playerHum = Humanoid
            if playerHum then
                M.bindThirdSeaIndraDeathWatch(playerHum)
            end

            return true
        end

        if M.thirdSeaEngageBoss(ripIndra) then
            if not S.autoAttack then M.setAutoAttack(true) end
            M.equipWeapon()
            local playerHum = Humanoid
            if playerHum then
                M.bindThirdSeaIndraDeathWatch(playerHum)
            end

            return true
        end
    else
        S.thirdSeaRipIndraAnchor = nil
        if M.isOnIndraIsland() then
            task.wait(1)
            ripIndra = M.findThirdSeaRipIndra()
            if ripIndra then
                S.thirdSeaCombatTarget = ripIndra
                return true
            end
        end
    end

    S.thirdSeaCombatTarget = nil
    return false
end

function M.isSwanPirateQuestActive()
    local ok, vis = pcall(function()
        return Player.PlayerGui.Main.Quest.Visible
    end)

    if not ok or not vis then return false end
    local ok2, text = pcall(function()
        return Player.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text
    end)

    if not ok2 or not text then return false end
    return text:find("Swan Pirate") and text:find("50")
end

function M.tickBartiloPuzzle()
    if os.clock() - S.lastThirdSeaPuzzleAt < 12 then return false end
    S.lastThirdSeaPuzzleAt = os.clock()
    local hrp = M.getHRP()
    if not hrp then return false end
    local room = M.ThirdSeaPos.BartiloRoom
    if (hrp.Position - room).Magnitude > 150 then
        if not _G.NexusHubIsMoving() then
            M.moveThirdSeaTo(room)
        end

        return false
    end

    local plates = Workspace:FindFirstChild("Map")
        and Workspace.Map:FindFirstChild("Dressrosa")
        and Workspace.Map.Dressrosa:FindFirstChild("BartiloPlates")
    if not plates then
        M.thirdSeaNotify("Bartilo puzzle plates not found")
        return false
    end

    for i = 1, 8 do
        local plate = plates:FindFirstChild("Plate" .. i)
        if plate then
            hrp.CFrame = plate.CFrame + Vector3.new(0, 3, 0)
            M.touchInteract(plate)
            task.wait(0.35)
        end
    end

    return true
end

function M.tickThirdSeaSacrifice()
    if not S.thirdSeaSacrificeStorageName then
        M.thirdSeaNotify("Pick a sacrifice fruit (Refresh + dropdown)")
        return
    end

    if not M.hasSacrificeFruit(S.thirdSeaSacrificeStorageName) then
        M.thirdSeaNotify("Selected fruit no longer available - refresh list")
        return
    end

    local hrp = M.getHRP()
    if not hrp then return end
    local trevorPos = M.ThirdSeaPos.Trevor
    local fruitTool = M.getEquippedSacrificeFruit()
    local displayName = S.thirdSeaSacrificeDisplay or M.fruitStorageToDisplay(S.thirdSeaSacrificeStorageName)
    if not fruitTool then
        if S.thirdSeaSacrificeSource == "held" then
            M.equipSacrificeFruit(displayName)
        else
            M.loadSacrificeFruit(S.thirdSeaSacrificeStorageName)
            M.equipSacrificeFruit(displayName)
        end

        fruitTool = M.getEquippedSacrificeFruit()
    end

    if not fruitTool then
        M.thirdSeaNotify("Could not equip sacrifice fruit")
        return
    end

    if (hrp.Position - trevorPos).Magnitude > 15 then
        if not _G.NexusHubIsMoving() then
            M.moveThirdSeaTo(trevorPos)
        end

        return
    end

    _G.NexusHubThirdSeaTravel = false
    M.equipSacrificeFruit(fruitTool.Name)
    for i = 1, 3 do
        pcall(function() CommF_:InvokeServer("TalkTrevor", tostring(i)) end)
        task.wait(0.35)
    end

    S.thirdSeaSacrificeActive = false
end

function M.findMrCaptainNpc()
    local npcs = Workspace:FindFirstChild("NPCs")
    if npcs then
        local npc = npcs:FindFirstChild("Mr. Captain")
        if npc then return npc end
    end

    local rsNpcs = ReplicatedStorage:FindFirstChild("NPCs")
    if rsNpcs then
        local npc = rsNpcs:FindFirstChild("Mr. Captain")
        if npc then return npc end
    end

    for _, d in ipairs(Workspace:GetDescendants()) do
        if d.Name == "Mr. Captain" and d:IsA("Model") then
            return d
        end
    end

    return nil
end

function M.getMrCaptainPos()
    local npc = M.findMrCaptainNpc()
    if npc then
        local hrp = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
        if hrp then return hrp.Position end
    end

    return M.ThirdSeaPos.MrCaptainDock
end

function M.tryThirdSeaDialogYes()
    local ok, vis = pcall(function()
        return Player.PlayerGui.Main.Dialogue.Visible
    end)

    if ok and vis then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button1Down(Vector2.new(0, 0))
            task.wait(0.05)
            VirtualUser:Button1Up(Vector2.new(0, 0))
        end)
    end
end

function M.teleportThirdSeaToCaptainDock()
    local hrp = M.getHRP()
    if not hrp then return false end
    local pos = M.getMrCaptainPos() + Vector3.new(0, 4, 0)
    hrp.CFrame = CFrame.new(pos)
    if _G.NexusHubIsMoving() then
        pcall(_G.NexusHubCancelMove)
    end

    _G.NexusHubThirdSeaTravel = false
    return true
end

function M.tickThirdSeaCaptain()
    if M.isSea3() then
        S.autoThirdSea = false
        _G.NexusHubAutoThirdSea = false
        _G.NexusHubThirdSeaTravel = false
        M.thirdSeaNotify("Sea 3 unlocked!")
        return true
    end

    S.thirdSeaCombatTarget = nil
    if S.autoAttack then M.setAutoAttack(false) end
    if M.isOnIndraIsland() then
        M.teleportThirdSeaToCaptainDock()
        return false
    end

    local targetPos = M.getMrCaptainPos()
    if M.isNearThirdSeaPos(targetPos, 25) then
        _G.NexusHubThirdSeaTravel = false
        if os.clock() - (S.lastThirdSeaCaptainTalkAt or 0) < 4 then
            return true
        end

        S.lastThirdSeaCaptainTalkAt = os.clock()
        M.thirdSeaNotify("Talking to Mr. Captain at Green Zone dock...")
        pcall(function() CommF_:InvokeServer("ZQuestProgress", "Zou") end)
        task.wait(0.5)
        pcall(function() CommF_:InvokeServer("TravelZou") end)
        task.wait(0.3)
        M.tryThirdSeaDialogYes()
        task.wait(0.5)
        M.tryThirdSeaDialogYes()
        task.wait(2)
        if M.isSea3() then
            S.autoThirdSea = false
            _G.NexusHubAutoThirdSea = false
            _G.NexusHubThirdSeaTravel = false
            M.thirdSeaNotify("Sea 3 unlocked!")
        end

        return true
    end

    if not _G.NexusHubIsMoving() then
        M.moveThirdSeaTo(targetPos)
    end

    return false
end

function M.finishThirdSeaUnlock()
    S.thirdSeaIndraWasFighting = false
    S.thirdSeaIndraQuestStarted = false
    S.thirdSeaIndraNeedsRetalk = false
    S.thirdSeaRipIndraCutsceneActive = false
    S.thirdSeaCombatTarget = nil
    S.thirdSeaRipIndraAnchor = nil
    M.clearThirdSeaIndraDeathWatch()
    M.tickThirdSeaCaptain()
end

function M.tickAutoThirdSea()
    if not S.autoThirdSea then return end
    if os.clock() - (S.lastThirdSeaSyncAt or 0) >= 4 then
        S.lastThirdSeaSyncAt = os.clock()
        M.syncThirdSeaFlagsFromServer(false)
    end

    local prog = M.getThirdSeaProgressDetails()
    M.reportThirdSeaStageChange(prog)
    if prog.stageId == "done" then
        M.thirdSeaNotify("Already in Sea 3")
        S.autoThirdSea = false
        _G.NexusHubAutoThirdSea = false
        _G.NexusHubThirdSeaTravel = false
        S.thirdSeaCombatTarget = nil
        return
    end

    if prog.stageId == "wrong_sea" then
        M.thirdSeaNotify("Sea 2 only")
        _G.NexusHubThirdSeaTravel = false
        return
    end

    if prog.stageId == "bartilo_swan" then
        S.thirdSeaCombatTarget = nil
        if not M.isSwanPirateQuestActive() then
            _G.NexusHubThirdSeaTravel = false
            local hrp = M.getHRP()
            if hrp and (hrp.Position - M.ThirdSeaPos.Bartilo).Magnitude > 15 then
                if not _G.NexusHubIsMoving() then
                    M.moveThirdSeaTo(M.ThirdSeaPos.Bartilo)
                end

                return
            end

            pcall(function() CommF_:InvokeServer("StartQuest", "BartiloQuest", 1) end)
            task.wait(0.5)
            return
        end

        local swan = S.thirdSeaCombatTarget or M.findLiveEnemyByName("Swan Pirate") or M.findBoss("Swan Pirate")
        if swan and M.thirdSeaEngageBoss(swan) then
            return
        end

        S.thirdSeaCombatTarget = nil
        if not _G.NexusHubIsMoving() then
            M.moveThirdSeaTo(M.ThirdSeaPos.SwanPirate)
        end

        return
    end

    if prog.stageId == "bartilo_jeremy" then
        local jeremy = S.thirdSeaCombatTarget or M.findLiveEnemyByName("Jeremy") or M.findBoss("Jeremy")
        if jeremy then
            local hum = jeremy:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then
                S.thirdSeaCombatTarget = nil
                pcall(function() CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") end)
            elseif M.thirdSeaEngageBoss(jeremy) then
                return
            end
        end

        S.thirdSeaCombatTarget = nil
        if not _G.NexusHubIsMoving() then
            M.moveThirdSeaTo(M.ThirdSeaPos.Jeremy)
        end

        return
    end

    if prog.stageId == "bartilo_puzzle" then
        S.thirdSeaCombatTarget = nil
        M.tickBartiloPuzzle()
        return
    end

    if prog.stageId == "need_level" then
        M.thirdSeaNotify("Waiting for level 1500 (currently " .. tostring(prog.level) .. ")")
        _G.NexusHubThirdSeaTravel = false
        return
    end

    if prog.stageId == "captain" then
        M.tickThirdSeaCaptain()
        return
    end

    if prog.stageId == "king_red_head" then
        M.tickThirdSeaKingRedHead()
        return
    end

    if prog.stageId == "rip_indra" then
        M.tickThirdSeaRipIndraFight()
        return
    end

    if prog.stageId == "sacrifice" then
        S.thirdSeaCombatTarget = nil
        M.tickThirdSeaSacrifice()
        return
    end

    if prog.stageId == "don_swan" then
        local donSwan = S.thirdSeaCombatTarget or M.findDonSwan()
        if donSwan then
            local hum = donSwan:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then
                S.thirdSeaCombatTarget = nil
                M.markDonSwanCleared()
                return
            end

            if M.thirdSeaEngageBoss(donSwan) then
                return
            end
        else
            local zCheck = M.normalizeThirdSeaZCheck(M.getZQuestProgress("Check"))
            if zCheck == 1 or zCheck == 0 then
                M.markDonSwanCleared()
                return
            end
        end

        S.thirdSeaCombatTarget = nil
        if M.isNearThirdSeaPos(M.ThirdSeaPos.DonSwan, 120) then
            M.thirdSeaNudgeBoss("Don Swan", "Mansion")
        end

        if not _G.NexusHubIsMoving() then
            M.moveThirdSeaTo(M.ThirdSeaPos.DonSwan)
        end

        return
    end

    _G.NexusHubThirdSeaTravel = false
end

function M.isSea3()
    return PLACE_TO_SEA[game.PlaceId] == "Sea 3"
end

function M.isSea1()
    return PLACE_TO_SEA[game.PlaceId] == "Sea 1"
end

function M.saberNotify(msg)
    if os.clock() - S.lastSaberNotify < 8 then return end
    S.lastSaberNotify = os.clock()
    M.notify("Auto Saber", msg, 5)
end

function M.getBountyHonor()
    local ls = Player:FindFirstChild("leaderstats")
    local stat = ls and ls:FindFirstChild("Bounty/Honor")
    if stat then return stat.Value end
    local data = Player:FindFirstChild("Data")
    if not data then return 0 end
    local bounty = data:FindFirstChild("Bounty") or data:FindFirstChild("Honor")
    return bounty and bounty.Value or 0
end

function M.hasSaber()
    return M.hasToolByName("Saber")
end

function M.getSaberTool()
    if Character then
        local equipped = Character:FindFirstChild("Saber")
        if equipped then return equipped end
    end

    return Player.Backpack and Player.Backpack:FindFirstChild("Saber")
end

function M.hasSaberV2()
    local tool = M.getSaberTool()
    if tool then
        for _, key in ipairs({ "Upgrade", "Upgraded", "Version", "SaberVersion" }) do
            local val = tool:GetAttribute(key)
            if val == 2 or val == "2" or val == "V2" or val == "v2" then
                return true
            end
        end
    end

    local data = Player:FindFirstChild("Data")
    if data then
        for _, child in ipairs(data:GetChildren()) do
            local name = child.Name:lower()
            if name:find("saber") and (child.Value == 2 or tostring(child.Value):lower() == "v2") then
                return true
            end
        end
    end

    return false
end

function M.partIsClosed(part)
    if not part then return false end
    if part:IsA("BasePart") then
        return part.CanCollide or part.Transparency < 0.5
    end

    return false
end

function M.touchInteract(part)
    local hrp = HumanoidRootPart
    if not hrp or not part then return end
    pcall(function()
        firetouchinterest(hrp, part, 0)
        firetouchinterest(hrp, part, 1)
    end)
end

function M.touchWithTool(toolName, part)
    if not part then return end
    M.equipToolByName(toolName)
    task.wait(0.15)
    local tool = Character and Character:FindFirstChild(toolName)
    local handle = tool and (tool:FindFirstChild("Handle") or tool)
    if not handle then return end
    pcall(function()
        firetouchinterest(handle, part, 0)
        firetouchinterest(handle, part, 1)
    end)
end

function M.tweenToCFrameSafe(cf, reach)
    if not cf or not HumanoidRootPart then return end
    local pos = cf.Position + Vector3.new(0, 3, 0)
    if (HumanoidRootPart.Position - pos).Magnitude > (reach or 8) then
        M.moveTo(pos)
    end
end

function M.findSaberV2PlayerTarget()
    local myLevel = M.getPlayerLevel() or 0
    local best, bestDist
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                local lvl
                local ls = plr:FindFirstChild("leaderstats")
                local lvlObj = ls and ls:FindFirstChild("Level")
                if lvlObj then
                    lvl = lvlObj.Value
                else
                    local data = plr:FindFirstChild("Data")
                    local dataLvl = data and data:FindFirstChild("Level")
                    lvl = dataLvl and dataLvl.Value
                end

                if lvl and math.abs(lvl - myLevel) <= 150 then
                    local d = HumanoidRootPart and (HumanoidRootPart.Position - hrp.Position).Magnitude
                    if d and d <= 2500 and (not bestDist or d < bestDist) then
                        best, bestDist = plr.Character, d
                    end
                end
            end
        end
    end

    return best
end

function M.tickAutoSaberV2()
    if M.hasSaberV2() then return true end
    if not M.hasSaber() then return false end
    local bounty = M.getBountyHonor()
    if bounty < 1000000 then
        M.saberNotify("Farming bounty/honor for Saber V2 (" .. tostring(bounty) .. " / 1M)")
        if not S.autofarm then
            S.autofarm = true
            _G.NexusHubAutofarm = true
            S.saberForcedAutofarm = true
            if not S.autoAttack then M.setAutoAttack(true) end
        end

        return false
    end

    if S.saberForcedAutofarm then
        S.autofarm = false
        _G.NexusHubAutofarm = false
        S.saberForcedAutofarm = false
    end

    M.equipToolByName("Saber")
    S.selectedWeapon = "Sword"
    if not S.autoAttack then M.setAutoAttack(true) end
    local target = M.findSaberV2PlayerTarget()
    if target then
        S.saberCombatTarget = target
        return false
    end

    M.saberNotify("Need 1M bounty - kill a nearby player near your level for Saber V2")
    S.saberCombatTarget = nil
    return false
end

function M.tickAutoSaberPuzzle()
    local map = Workspace:FindFirstChild("Map")
    if not map then return end
    local jungle = map:FindFirstChild("Jungle")
    local desert = map:FindFirstChild("Desert")
    local final = jungle and jungle:FindFirstChild("Final")
    local finalPart = final and final:FindFirstChild("Part")
    local plates = jungle and jungle:FindFirstChild("QuestPlates")
    local burn = desert and desert:FindFirstChild("Burn")
    local burnPart = burn and burn:FindFirstChild("Part")
    if finalPart and M.partIsClosed(finalPart) then
        local door = plates and plates:FindFirstChild("Door")
        if door and M.partIsClosed(door) then
            M.saberNotify("Solving jungle plate puzzle")
            M.teleportToIsland("Jungle")
            task.wait(1.5)
            if plates then
                for _, plate in ipairs(plates:GetChildren()) do
                    if not S.autoSaber then return end
                    local button = plate:FindFirstChild("Button")
                    if button then
                        M.tweenToCFrameSafe(button.CFrame, 6)
                        task.wait(0.4)
                        M.touchInteract(button)
                        task.wait(0.3)
                    end
                end
            end

            return
        end

        if burnPart and M.partIsClosed(burnPart) then
            M.saberNotify("Lighting desert torch puzzle")
            if not M.hasToolByName("Torch") then
                M.teleportToIsland("Jungle")
                task.wait(1.5)
                local torch = jungle and jungle:FindFirstChild("Torch")
                if torch then
                    M.tweenToCFrameSafe(torch.CFrame, 8)
                    task.wait(0.4)
                    M.touchInteract(torch)
                    task.wait(0.5)
                end
            else
                M.teleportToIsland("Desert")
                task.wait(1.5)
                local fire = burn and burn:FindFirstChild("Fire")
                if fire then
                    M.tweenToCFrameSafe(fire.CFrame, 8)
                    task.wait(0.4)
                    M.touchWithTool("Torch", fire)
                    task.wait(0.5)
                end
            end

            return
        end

        local okRich, richProgress = pcall(function()
            return CommF_:InvokeServer("ProQuestProgress", "RichSon")
        end)

        richProgress = okRich and richProgress or nil
        if richProgress ~= 0 and richProgress ~= 1 then
            M.saberNotify("Sick Man / cup quest")
            if not M.hasToolByName("Cup") then
                pcall(function() CommF_:InvokeServer("ProQuestProgress", "GetCup") end)
                task.wait(0.3)
                if not M.hasToolByName("Cup") then
                    local cupPart = desert and desert:FindFirstChild("Cup")
                    if cupPart then
                        M.teleportToIsland("Desert")
                        task.wait(1)
                        M.tweenToCFrameSafe(cupPart.CFrame, 8)
                        task.wait(0.4)
                        M.touchInteract(cupPart)
                    end

                    return
                end
            end

            M.equipToolByName("Cup")
            task.wait(0.2)
            local cup = Character and Character:FindFirstChild("Cup")
            pcall(function()
                CommF_:InvokeServer("ProQuestProgress", "FillCup", cup)
            end)

            task.wait(0.2)
            pcall(function() CommF_:InvokeServer("ProQuestProgress", "SickMan") end)
            return
        end

        if richProgress == 0 then
            M.saberNotify("Killing Mob Leader")
            local mob = M.findBoss("Mob Leader")
            if mob then
                S.saberCombatTarget = mob
            else
                M.moveToQuestSpawn("Mob Leader", "Pirate")
            end

            return
        end

        if richProgress == 1 then
            if not M.hasToolByName("Relic") then
                pcall(function() CommF_:InvokeServer("ProQuestProgress", "RichSon") end)
                task.wait(0.3)
            end

            if M.hasToolByName("Relic") then
                M.saberNotify("Placing relic")
                M.teleportToIsland("Jungle")
                task.wait(1.5)
                local invis = final and final:FindFirstChild("Invis")
                if invis then
                    M.tweenToCFrameSafe(invis.CFrame, 8)
                    task.wait(0.4)
                    M.touchWithTool("Relic", invis)
                else
                    M.moveTo(Vector3.new(-1404, 30, 4))
                end
            end

            return
        end
    end

    local expert = M.findBoss("Saber Expert")
    if expert then
        S.saberCombatTarget = expert
        return
    end

    M.saberNotify("Waiting for Saber Expert - heading to spawn")
    M.teleportToIsland("Jungle")
    task.wait(1)
    M.moveTo(Vector3.new(-1401, 30, 9))
end

function M.tickAutoSaber()
    if not S.autoSaber then
        S.saberCombatTarget = nil
        return
    end

    if not Humanoid or not HumanoidRootPart or Humanoid.Health <= 0 then return end
    if S.saberCombatTarget then
        local hum = S.saberCombatTarget:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            if S.saberCombatTarget.Name and S.saberCombatTarget.Name:find("Saber Expert") then
                pcall(function() CommF_:InvokeServer("ProQuestProgress", "PlaceRelic") end)
            end

            S.saberCombatTarget = nil
        end
    end

    if M.hasSaberV2() then
        S.saberCombatTarget = nil
        if S.saberForcedAutofarm then
            S.autofarm = false
            _G.NexusHubAutofarm = false
            S.saberForcedAutofarm = false
        end

        M.saberNotify("Saber V2 complete")
        S.autoSaber = false
        return
    end

    if M.hasSaber() then
        M.tickAutoSaberV2()
        return
    end

    if not M.isSea1() then
        M.saberNotify("Traveling to Sea 1 for Saber")
        pcall(function() CommF_:InvokeServer("TravelMain") end)
        task.wait(3)
        return
    end

    local level = M.getPlayerLevel() or 0
    if level < 200 then
        M.saberNotify("Level 200+ required (currently " .. tostring(level) .. ") - auto farming")
        if not S.autofarm then
            S.autofarm = true
            _G.NexusHubAutofarm = true
            S.saberForcedAutofarm = true
            if not S.autoAttack then M.setAutoAttack(true) end
        end

        return
    end

    if S.saberForcedAutofarm and level >= 200 then
        S.autofarm = false
        _G.NexusHubAutofarm = false
        S.saberForcedAutofarm = false
    end

    M.attachFloat()
    if not S.autoAttack then M.setAutoAttack(true) end
    M.tickAutoSaberPuzzle()
end

function M.isNightTime()
    local clock = game:GetService("Lighting").ClockTime
    return clock >= 18 or clock <= 6
end

function M.hauntedNotify(title, msg)
    if os.clock() - S.lastHauntedNotify < 8 then return end
    S.lastHauntedNotify = os.clock()
    M.notify(title, msg, 5)
end

function M.ensureHauntedCastle()
    if not M.isSea3() then return false end
    if M.isOnIsland("Haunted Castle") then return true end
    M.teleportToIsland("Haunted Castle")
    task.wait(2.5)
    return M.isOnIsland("Haunted Castle")
end

function M.hasToolByName(name)
    if Player.Backpack and Player.Backpack:FindFirstChild(name) then return true end
    return Character and Character:FindFirstChild(name) ~= nil
end

function M.equipToolByName(name)
    if Character and Character:FindFirstChild(name) then return true end
    local tool = Player.Backpack and Player.Backpack:FindFirstChild(name)
    if tool and Character then
        tool.Parent = Character
        task.wait(0.2)
        return Character:FindFirstChild(name) ~= nil
    end

    return false
end

function M.getBonesInfo()
    local ok, vals = pcall(function()
        local a, b, c = CommF_:InvokeServer("Bones", "Check")
        return { a, b, c }
    end)

    if not ok or not vals then return 0, 0 end
    return tonumber(vals[1]) or 0, tonumber(vals[3]) or 0
end

function M.rollBonesSurprise()
    local ok, res = pcall(function()
        return CommF_:InvokeServer("Bones", "Buy", 1, 1)
    end)

    return ok, res
end

function M.gravestoneAction(option)
    local ok, res = pcall(function()
        return CommF_:InvokeServer("gravestoneEvent", option)
    end)

    return ok, res
end

function M.findSoulReaper()
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end
    for _, model in ipairs(enemies:GetChildren()) do
        if model:IsA("Model") then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                if M.fuzzyEnemyMatch(model.Name, "Soul Reaper")
                    or M.fuzzyEnemyMatch(tostring(hum.DisplayName), "Soul Reaper") then
                    return model
                end
            end
        end
    end

    return nil
end

M.PirateRaidPos = Vector3.new(-5556, 314, -2988)
M.PirateRaidStand = Vector3.new(-5496, 314, -2841)
M.FactoryApproach = Vector3.new(430.42569, 210.019623, -432.504791)
M.FactoryRaidStand = Vector3.new(448.46756, 199.356781, -441.389252)
M.DressrosaHub = Vector3.new(-394.983521, 118.503128, 1245.8446)
local SEA2_ENTRANCES = {
    { name = "hotColdMagma", pos = Vector3.new(-7859.09814, 5544.19043, -381.476196) },
    { name = "hotColdIce", pos = Vector3.new(-7894.6176757813, 5547.1416015625, -380.29119873047) },
    { name = "cursedShip", pos = Vector3.new(923.21252441406, 126.9760055542, 32852.83203125) },
    { name = "greenBit", pos = Vector3.new(-6508.5581054688, 89.034996032715, -132.83953857422) },
}

function M.resetFactoryRaidTravel()
    S.factoryRaidPhase = "idle"
    S.factoryRaidPhaseSince = 0
    S.factoryRaidStuckSince = 0
    S.lastFactoryPortalAt = 0
    S.lastFactoryPhaseAt = 0
    S.lastFactoryRaidPos = nil
end

function M.setFactoryRaidPhase(phase)
    if S.factoryRaidPhase ~= phase then
        S.factoryRaidPhase = phase
        S.factoryRaidPhaseSince = os.clock()
        S.factoryRaidStuckSince = 0
    end
end

function M.shouldForceFactoryRaidNoclip()
    return S.autoFactoryRaid == true and S.factoryRaidEngaged == true
end

function M.isNearFactoryRaidArea(radius)
    radius = radius or 800
    local hrp = M.getHRP()
    if not hrp then return false end
    local pos = hrp.Position
    return M.horizontalDistance(pos, M.FactoryApproach) <= radius
        or M.horizontalDistance(pos, M.FactoryRaidStand) <= radius
end

function M.distToFactoryStand()
    local hrp = M.getHRP()
    if not hrp then return math.huge end
    return (hrp.Position - M.FactoryRaidStand).Magnitude
end

function M.pickSea2Entrance(targetPos)
    if not targetPos then return nil end
    local hrp = M.getHRP()
    if not hrp then return nil end
    local from = hrp.Position
    if M.horizontalDistance(from, targetPos) <= 4000 then
        return nil
    end

    local best, bestScore
    for _, entry in ipairs(SEA2_ENTRANCES) do
        local portalPos = entry.pos
        local distFromPlayer = (from - portalPos).Magnitude
        if distFromPlayer > 120 then
            local remaining = (portalPos - targetPos).Magnitude
            local score = distFromPlayer + remaining * 0.35
            if not bestScore or score < bestScore then
                best = entry
                bestScore = score
            end
        end
    end

    return best
end

function M.requestSea2Entrance(targetPos)
    local entry = M.pickSea2Entrance(targetPos)
    if not entry then return false end
    if os.clock() - S.lastFactoryPortalAt < 2.0 then return false end
    S.lastFactoryPortalAt = os.clock()
    local ok = pcall(function()
        if CommF_ then
            CommF_:InvokeServer("requestEntrance", entry.pos)
        end
    end)

    return ok
end

function M.phaseToFactoryApproach()
    local hrp = M.getHRP()
    if not hrp then return false end
    _G.NexusHubCancelMove()
    M.clearFarmHoverConstraint(hrp)
    _G.NexusHubSetFarmNoclip(true)
    hrp.CFrame = CFrame.new(M.FactoryApproach + Vector3.new(0, 3, 0))
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return M.horizontalDistance(hrp.Position, M.FactoryApproach) <= 80
end

function M.tweenFactoryRaidGoal(goal)
    if not goal then return nil end
    local hrp = M.getHRP()
    if not hrp then return nil end
    if (hrp.Position - goal).Magnitude <= 3 then
        return nil
    end

    if _G.NexusHubIsMoving() and _G.NexusHubMoveGoal and (_G.NexusHubMoveGoal - goal).Magnitude <= 25 then
        return S.ActiveTween
    end

    return M.moveTo(goal)
end

function M.travelToFactoryRaid(core)
    local hrp = M.getHRP()
    if not hrp then return false end
    _G.NexusHubSetFarmNoclip(true)
    M.clearFarmHoverConstraint(hrp)
    local travelTarget = M.FactoryRaidStand
    local distStand = M.distToFactoryStand()
    local distApproach = M.horizontalDistance(hrp.Position, M.FactoryApproach)
    if M.isNearFactoryRaidArea(800) then
        if distStand <= 60 then
            M.setFactoryRaidPhase("engage")
            return true
        end

        if distApproach > 90 then
            M.setFactoryRaidPhase("approachFactory")
            if not _G.NexusHubIsMoving() then
                M.tweenFactoryRaidGoal(M.FactoryApproach)
            end

            if distApproach <= 120 and S.factoryRaidStuckSince > 0
                and os.clock() - S.factoryRaidStuckSince >= 1.5 then
                M.phaseToFactoryApproach()
            end

            return false
        end

        M.setFactoryRaidPhase("finalStand")
        if not _G.NexusHubIsMoving() then
            M.tweenFactoryRaidGoal(M.FactoryRaidStand)
        end

        if distStand > 40 and distApproach <= 120 and S.factoryRaidStuckSince > 0
            and os.clock() - S.factoryRaidStuckSince >= 2.0 then
            _G.NexusHubCancelMove()
            hrp.CFrame = CFrame.new(M.FactoryRaidStand + Vector3.new(0, 2, 0))
            hrp.AssemblyLinearVelocity = Vector3.zero
        end

        return distStand <= 60
    end

    if M.horizontalDistance(hrp.Position, travelTarget) > 4000 then
        M.setFactoryRaidPhase("portalHop")
        if not _G.NexusHubIsMoving() then
            M.requestSea2Entrance(travelTarget)
        end

        return false
    end

    if M.horizontalDistance(hrp.Position, M.DressrosaHub) > 2500
        and M.horizontalDistance(hrp.Position, travelTarget) > 1800 then
        M.setFactoryRaidPhase("approachHub")
        if not _G.NexusHubIsMoving() then
            M.tweenFactoryRaidGoal(M.DressrosaHub)
        end

        return false
    end

    M.setFactoryRaidPhase("approachFactory")
    if not _G.NexusHubIsMoving() then
        M.tweenFactoryRaidGoal(M.FactoryApproach)
    end

    return false
end

function M.findFactoryCore()
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end
    local core = enemies:FindFirstChild("Core", true)
    if not core then return nil end
    local hum = core:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then return core end
    return nil
end

function M.isFactoryCorePending()
    if M.findFactoryCore() then return false end
    return ReplicatedStorage:FindFirstChild("Core") ~= nil
end

function M.isFactoryRaidPending()
    return false
end

function M.isFactoryRaidActive()
    return M.findFactoryCore() ~= nil
end

function M.isFactoryRaidEngaged()
    return S.autoFactoryRaid == true and S.factoryRaidEngaged == true
end

function M.getFactoryCoreAttackPos(core)
    local corePos = M.getModelPosition(core)
    if not corePos then return M.FactoryRaidStand end
    local hrp = M.getHRP()
    local from = hrp and hrp.Position or M.FactoryRaidStand
    local flat = Vector3.new(from.X - corePos.X, 0, from.Z - corePos.Z)
    if flat.Magnitude < 2 then
        flat = Vector3.new(0, 0, -1)
    else
        flat = flat.Unit
    end

    return corePos + flat * 10 + Vector3.new(0, 2, 0)
end

function M.stepFactoryRaidMove(hrp, goal, facePos, dt)
    if not hrp or not goal then return true end
    dt = dt or (1 / 60)
    local pos = hrp.Position
    local toGoal = goal - pos
    local dist = toGoal.Magnitude
    if dist <= 2.5 then
        if facePos then
            hrp.CFrame = CFrame.new(goal, facePos)
        else
            hrp.CFrame = CFrame.new(goal)
        end

        return true
    end

    local speed = dist > 60 and 320 or 180
    local step = math.min(dist, speed * dt)
    local newPos = pos + toGoal.Unit * step
    if facePos then
        hrp.CFrame = CFrame.new(newPos, facePos)
    else
        hrp.CFrame = CFrame.new(newPos, goal)
    end

    return false
end

function M.tickFactoryRaidMovement(hrp, dt)
    if not hrp then return end
    local core = S.factoryRaidTarget or M.findFactoryCore()
    local pending = not core and M.isFactoryCorePending()
    if not core and not pending then return end
    _G.NexusHubSetFarmNoclip(true)
    for _, bp in ipairs(Character:GetChildren()) do
        if bp:IsA("BasePart") then bp.CanCollide = false end
    end

    if not core then
        M.clearFarmHoverConstraint(hrp)
        if not M.isNearFactoryRaidArea(800) then
            if S.lastFactoryRaidPos then
                if (hrp.Position - S.lastFactoryRaidPos).Magnitude < 2 then
                    if S.factoryRaidStuckSince == 0 then
                        S.factoryRaidStuckSince = os.clock()
                    end
                else
                    S.factoryRaidStuckSince = 0
                end
            end

            S.lastFactoryRaidPos = hrp.Position
            M.travelToFactoryRaid(nil)
        else
            S.factoryRaidStuckSince = 0
            S.lastFactoryRaidPos = nil
            M.setFactoryRaidPhase("finalStand")
            if not _G.NexusHubIsMoving() then
                M.tweenFactoryRaidGoal(M.FactoryRaidStand)
            end
        end

        return
    end

    M.ensureFarmWeapon()
    if S.selectedWeapon ~= "Melee" and not M.isFarmWeaponEquipped() then
        M.equipWeapon(true)
    end

    local corePos = M.getModelPosition(core)
    local goal = M.getFactoryCoreAttackPos(core)
    local facePos = corePos or goal
    local dist = (hrp.Position - goal).Magnitude
    if not M.isNearFactoryRaidArea(800) or dist > 60 then
        if S.lastFactoryRaidPos then
            if (hrp.Position - S.lastFactoryRaidPos).Magnitude < 2 then
                if S.factoryRaidStuckSince == 0 then
                    S.factoryRaidStuckSince = os.clock()
                end
            else
                S.factoryRaidStuckSince = 0
            end
        end

        S.lastFactoryRaidPos = hrp.Position
        M.travelToFactoryRaid(core)
        return
    end

    S.factoryRaidStuckSince = 0
    S.lastFactoryRaidPos = nil
    M.setFactoryRaidPhase("engage")
    M.clearFarmHoverConstraint(hrp)
    if dist > 3 then
        if _G.NexusHubIsMoving() then
            _G.NexusHubCancelMove()
        end

        M.stepFactoryRaidMove(hrp, goal, facePos, dt)
    elseif corePos then
        hrp.CFrame = CFrame.new(hrp.Position, corePos)
    end
end

function M.beginFactoryRaidEngage()
    if S.factoryRaidEngaged and _G.NexusHubFactoryRaidPaused then return end
    if not S.factoryRaidEngaged then return end
    if not _G.NexusHubFactoryRaidPaused then
        _G.NexusHubFactoryRaidPaused = true
        _G.NexusHubTravelLockIsland = nil
        _G.NexusHubTravelLockUntil = 0
        M.pauseFarmMovement()
        if _G.NexusHubAutofarm == true then
            M.setHomePoint()
        end

        if os.clock() - S.lastFactoryRaidNotify > 6 then
            S.lastFactoryRaidNotify = os.clock()
            M.notify("Factory Raid", "Raid active - pausing quest farm", 4)
        end
    end
end

function M.finishFactoryRaidEngage()
    local wasPaused = _G.NexusHubFactoryRaidPaused == true
    _G.NexusHubFactoryRaidPaused = false
    if not wasPaused and not S.factoryRaidEngaged then return end
    M.resetFactoryRaidTravel()
    M.cancelFarmMove()
    if not (S.autofarm or S.autoRaid or S.autoBossFarm or S.chestFarmEnabled or S.autoMaterialFarm
        or (S.autoPirateRaid and S.pirateRaidEngaged) or S.autoPray or S.autoTryLuck
        or S.autoRollBones or S.autoSoulReaper or S.autoFruitSniper) then
        M.removeFloat()
        _G.NexusHubSetFarmNoclip(false)
    end
end

function M.isFruitSniperActive()
    return S.autoFruitSniper == true and S.fruitSniperChasing == true
end

function M.cursedCaptainSpawned()
    if not S.autoCursedCaptain then return false end
    if M.findCursedCaptain() then return true end
    if ReplicatedStorage:FindFirstChild("Cursed Captain", true) then return true end
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc.Name == "Cursed Captain" then return true end
    end

    return false
end

function M.isCursedCaptainEngaged()
    return S.autoCursedCaptain == true and S.cursedCaptainEngaged == true
end

function M.canSetHomePoint()
    if S.autoFactoryRaid and S.factoryRaidEngaged then return false end
    if S.autoCursedCaptain and (S.cursedCaptainEngaged or M.isInsideCursedShip()) then
        return false
    end

    return true
end

function M.pauseFarmMovement()
    M.cancelFarmMove()
    M.unanchorFarmTarget()
    if S.ActiveTween then
        pcall(function() S.ActiveTween:Cancel() end)
        S.ActiveTween = nil
    end

    _G.NexusHubFinishFarmMove()
end

function M.pauseFarmForFruitSniper()
    M.pauseFarmMovement()
end

function M.beginCursedCaptainEngage()
    if S.cursedCaptainEngaged then return end
    S.cursedCaptainEngaged = true
    M.pauseFarmMovement()
    if _G.NexusHubAutofarm == true and not M.isInsideCursedShip() then
        M.setHomePoint()
    end

    if os.clock() - S.lastCursedCaptainNotify > 6 then
        S.lastCursedCaptainNotify = os.clock()
        M.notify("Auto Cursed Captain", "Captain spawned - pausing quest farm", 4)
    end
end

function M.finishCursedCaptainEngage()
    if not S.cursedCaptainEngaged then return end
    S.cursedCaptainEngaged = false
    S.cursedCaptainCombatTarget = nil
    S.cursedCaptainMissingSince = nil
    if M.isInsideCursedShip() then
        M.leaveCursedShip()
        task.wait(0.8)
    end

    if not (S.autofarm or S.autoRaid or S.autoBossFarm or S.chestFarmEnabled or S.autoMaterialFarm
        or (S.autoPirateRaid and S.pirateRaidEngaged) or S.autoPray or S.autoTryLuck
        or S.autoRollBones or S.autoSoulReaper or S.autoFruitSniper) then
        M.removeFloat()
        _G.NexusHubSetFarmNoclip(false)
    end

    if _G.NexusHubAutofarm ~= true then return end
    if os.clock() - S.lastCursedCaptainReturnAt < 3 then return end
    S.lastCursedCaptainReturnAt = os.clock()
    M.teleportHome()
    M.notify("Auto Cursed Captain", "Captain down - teleporting home to resume quest farm", 4)
    task.wait(1.5)
end

M.IndraWaitPos = Vector3.new(-5524.53271, 313.800537, -2918.07422)
M.DarkbeardAltarPos = Vector3.new(3677.08203125, 62.751937866211, -3144.8332519531)
M.DarkbeardMinSafeY = 55
M.DarkbeardWaitPos = Vector3.new(3677.08203125, 68, -3144.8332519531)
M.CursedCaptainEntrance = Vector3.new(923.21252441406, 126.9760055542, 32852.83203125)
M.CursedShipOutsideDoor = Vector3.new(902.059143, 124.752518, 33071.8125)
M.CursedShipInsideDoor = Vector3.new(904.4072265625, 181.05767822266, 33341.38671875)
M.CursedCaptainPos = Vector3.new(916.928589, 181.092773, 33422)
local CURSED_SHIP_INSIDE_RADIUS = 5000
local HOME_SET_INTERVAL = 4.0
local HOME_RECOVER_DIST = 3500
local HOME_RECOVER_COOLDOWN = 8.0

function M.isInsideCursedShip()
    local hrp = M.getHRP()
    if not hrp then return false end
    return (hrp.Position - M.CursedShipInsideDoor).Magnitude <= CURSED_SHIP_INSIDE_RADIUS
end

function M.phaseToCursedShipInterior()
    local hrp = M.getHRP()
    if not hrp then return false end
    _G.NexusHubCancelMove()
    M.clearFarmHoverConstraint(hrp)
    _G.NexusHubSetFarmNoclip(true)
    local insidePos = M.CursedShipInsideDoor + Vector3.new(0, 4, 0)
    hrp.CFrame = CFrame.new(insidePos)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return M.isInsideCursedShip()
end

function M.tickCursedShipEntry(enemyName)
    if not M.isCursedShipQuestActive() then return nil end
    _G.NexusHubSetFarmNoclip(true)
    local hrp = M.getHRP()
    if not hrp then return nil end
    if M.isInsideCursedShip() then
        local spawn = enemyName and M.findBestEnemySpawn(enemyName, "Cursed Ship")
        if spawn and not M.isNearEnemySpawn(spawn) then
            return M.moveTo(M.getSpawnStandPosition(spawn))
        end

        if enemyName and not M.findQuestEnemy() then
            return M.moveTo(M.CursedCaptainPos)
        end

        return nil
    end

    local doorPos = M.CursedShipOutsideDoor + Vector3.new(0, 6, 0)
    local insidePos = M.CursedShipInsideDoor + Vector3.new(0, 4, 0)
    local distDoor = M.horizontalDistance(hrp.Position, doorPos)
    local nearShip = M.isNearIsland("Cursed Ship", 1400)
        or distDoor <= 120
        or M.horizontalDistance(hrp.Position, M.CursedCaptainEntrance) <= 180
    if not nearShip then
        local shipModel = M.findIslandModel("Cursed Ship")
        if shipModel then
            local shipCenter = shipModel:GetPivot().Position + Vector3.new(0, 70, 0)
            if M.horizontalDistance(hrp.Position, shipCenter) > 500 then
                return M.moveTo(shipCenter)
            end
        end

        return M.moveTo(doorPos)
    end

    if distDoor > 40 then
        return M.moveTo(doorPos)
    end

    if os.clock() - (_G.NexusHubLastCursedShipEntry or 0) >= 1.5 then
        _G.NexusHubLastCursedShipEntry = os.clock()
        pcall(function() M.enterCursedShip() end)
    end

    if not M.isInsideCursedShip() then
        if not _G.NexusHubIsMoving() then
            M.moveTo(insidePos)
        end

        if distDoor <= 35 and os.clock() - (_G.NexusHubLastCursedShipPhase or 0) >= 2.0 then
            _G.NexusHubLastCursedShipPhase = os.clock()
            if not M.isInsideCursedShip() then
                M.phaseToCursedShipInterior()
            end
        end
    end

    return nil
end

function M.enterCursedShip()
    if not CommF_ then return false end
    return pcall(function()
        CommF_:InvokeServer("requestEntrance", M.CursedCaptainEntrance)
    end)
end

function M.useCursedShipDoor(fromInside)
    local hrp = M.getHRP()
    if not hrp then return false end
    local doorPos = fromInside and M.CursedShipInsideDoor or M.CursedShipOutsideDoor
    M.tweenNear(doorPos, 12)
    if (hrp.Position - doorPos).Magnitude <= 18 then
        M.enterCursedShip()
        task.wait(0.6)
    end

    return fromInside and not M.isInsideCursedShip() or (not fromInside and M.isInsideCursedShip())
end

function M.goToCursedShipInside()
    if M.isInsideCursedShip() then
        if not M.isFarmMoving() then
            M.moveTo(M.CursedCaptainPos)
        end

        return true
    end

    M.useCursedShipDoor(false)
    return M.isInsideCursedShip()
end

function M.leaveCursedShip()
    if not M.isInsideCursedShip() then return true end
    M.useCursedShipDoor(true)
    return not M.isInsideCursedShip()
end

function M.isHubFarmActive()
    return _G.NexusHubAutofarm == true or S.autoBossFarm or S.autoMaterialFarm or S.autoMasteryFarm
        or S.autoRaid or S.autoIndra or S.autoDarkbeard or S.autoCursedCaptain
        or (S.autoElite and S.eliteCombatTarget)
        or S.autoDoughPrince or S.autoDoughKing
        or (S.autoPirateRaid and S.pirateRaidEngaged) or (S.autoFactoryRaid and S.factoryRaidEngaged)
        or S.autoSoulReaper or S.autoSaber or M.isFruitSniperActive()
end

function M.setHomePoint()
    if not CommF_ then return false, "CommF_ missing" end
    return pcall(function()
        CommF_:InvokeServer("SetSpawnPoint")
    end)
end

function M.teleportHome()
    if not CommF_ then return false, "CommF_ missing" end
    M.pauseFarmForFruitSniper()
    return pcall(function()
        CommF_:InvokeServer("TeleportToSpawn")
    end)
end

function M.tickAutoHomePoint()
    if not S.autoSetHomePoint then
        S.lastHomeAnchorPos = nil
        return
    end

    local hrp = M.getHRP()
    if not hrp or not Humanoid or Humanoid.Health <= 0 then return end
    local now = os.clock()
    local pos = hrp.Position
    local farming = M.isHubFarmActive()
    if farming and M.canSetHomePoint() and now - S.lastHomeSetAt >= HOME_SET_INTERVAL then
        local ok = M.setHomePoint()
        if ok then
            S.lastHomeSetAt = now
            S.lastHomeAnchorPos = pos
        end
    end

    if farming and M.canSetHomePoint() and S.lastHomeAnchorPos and now - S.lastHomeRecoverAt >= HOME_RECOVER_COOLDOWN then
        local drift = (pos - S.lastHomeAnchorPos).Magnitude
        if drift >= HOME_RECOVER_DIST then
            S.lastHomeRecoverAt = now
            if M.teleportHome() then
                M.notify("Home Point", "Teleported home - you were sent far from your farm spot", 4)
                S.lastHomeAnchorPos = nil
                S.lastHomeSetAt = 0
            end
        end
    end
end

function M.getDarkbeardSafePos(pos)
    if not pos then return pos end
    if pos.Y < M.DarkbeardMinSafeY then
        return Vector3.new(pos.X, M.DarkbeardMinSafeY, pos.Z)
    end

    return pos
end

function M.getDarkbeardHoverPos(targetPos)
    if not targetPos then return nil end
    local orbitY = math.max(M.getFarmOrbitY(), 22)
    return M.getDarkbeardSafePos(targetPos + Vector3.new(0, orbitY, 0))
end

function M.moveToDarkbeard(position)
    return M.moveTo(M.getDarkbeardSafePos(position))
end

function M.findRipIndra()
    return M.findBoss("rip_indra True Form") or M.findBoss("rip_indra")
end

M.ELITE_NAMES = {
    ["Diablo"] = true,
    ["Deandre"] = true,
    ["Urban"] = true,
}

function M.isEliteModel(model)
    if not model or not model:IsA("Model") then return false end
    local hum = model:FindFirstChild("Humanoid") or model:FindFirstChildWhichIsA("Humanoid", true)
    if not hum or hum.Health <= 0 then return false end
    if M.ELITE_NAMES[model.Name] then return true end
    local display = hum.DisplayName or ""
    if M.ELITE_NAMES[display] then return true end
    if display:find("Elite") then return true end
    return false
end

function M.findEliteTarget()
    local hrp = M.getHRP()
    local myPos = hrp and hrp.Position
    local best, bestDist
    for _, model in ipairs(M.collectLiveBossModels()) do
        if M.isEliteModel(model) then
            local pos = M.getModelPosition(model)
            if pos and myPos then
                local d = (myPos - pos).Magnitude
                if not bestDist or d < bestDist then
                    best, bestDist = model, d
                end
            elseif not best then
                best = model
            end
        end
    end

    return best
end

function M.findDarkbeard()
    return M.findBoss("Darkbeard")
end

function M.findCursedCaptain()
    return M.findBoss("Cursed Captain")
end

M.CAKE_LAND_MOBS = { "Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker" }
M.DOUGH_BRING = {
    PULL_IN_RADIUS = 160,
    PACK_RADIUS = 12,
    MAX_PER_TICK = 6,
    INTERVAL = 0.22,
    GROUND_LIFT = 2,
    HOVER_Y = 14,
    ATTACK_CAP = 12,
    ATTACK_RADIUS = 80,
    TYPE_CLEAR_RADIUS = 180,
}
M.DoughPos = {
    Entrance = Vector3.new(-902.56817626953, 79.93204498291, -10988.84765625),
    Hub = Vector3.new(-1884.7747802734375, 19.327526092529297, -11666.8974609375),
    Farm = Vector3.new(-1579.9111328125, 329.7358703613281, -12310.365234375),
    FarmAlt = Vector3.new(-2077, 252, -12373),
    DripMama = Vector3.new(-2151.82153, 149.315704, -12404.9053),
    Dimension = Vector3.new(-2009.2802734375, 4532.97216796875, -14937.3076171875),
}

function M.isAutoDoughRaidActive()
    return S.autoDoughPrince == true or S.autoDoughKing == true
end

function M.doughNotify(msg, mode)
    if os.clock() - (S.lastDoughNotify or 0) < 10 then return end
    S.lastDoughNotify = os.clock()
    local title = mode == "king" and "Auto Dough King" or "Auto Dough Prince"
    M.notify(title, msg, 5)
end

function M.isCakeLandMobName(name)
    if not name or name == "" then return false end
    for _, mob in ipairs(M.CAKE_LAND_MOBS) do
        if M.fuzzyEnemyMatch(name, mob) then return true end
    end

    return false
end

function M.getCakeLandMobPriority(name)
    for i, mob in ipairs(M.CAKE_LAND_MOBS) do
        if name == mob or M.fuzzyEnemyMatch(name, mob) then return i end
    end

    return #M.CAKE_LAND_MOBS + 1
end

function M.countCakeLandMobsNamed(mobName, center, radius)
    if not mobName or not center then return 0 end
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return 0 end
    local count = 0
    for _, model in ipairs(enemies:GetChildren()) do
        if not model:IsA("Model") or model.Name ~= mobName then continue end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local mobHrp = model:FindFirstChild("HumanoidRootPart")
        if hum and mobHrp and hum.Health > 0 then
            if radius >= 9999 or M.horizontalDistance(mobHrp.Position, center) <= radius then
                count = count + 1
            end
        end
    end

    return count
end

function M.findNearestCakeLandMob(mobName, center, radius)
    if not mobName or not center then return nil end
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end
    local best, bestDist
    for _, model in ipairs(enemies:GetChildren()) do
        if not model:IsA("Model") or model.Name ~= mobName then continue end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local mobHrp = model:FindFirstChild("HumanoidRootPart")
        if not hum or not mobHrp or hum.Health <= 0 then continue end
        local d = M.horizontalDistance(mobHrp.Position, center)
        if radius >= 9999 or d <= radius then
            if not bestDist or d < bestDist then
                best, bestDist = model, d
            end
        end
    end

    return best
end

function M.getActiveCakeLandFarmType()
    local hrp = M.getHRP()
    local center = (S.doughPackPos or S.doughFarmAnchor or (hrp and hrp.Position))
    if not center then return nil end
    local clearRadius = M.DOUGH_BRING.TYPE_CLEAR_RADIUS or 180
    if S.doughFarmTypeLock then
        if M.countCakeLandMobsNamed(S.doughFarmTypeLock, center, 9999) > 0 then
            return S.doughFarmTypeLock
        end

        S.doughFarmTypeLock = nil
        S.doughPackPos = nil
    end

    for _, mobName in ipairs(M.CAKE_LAND_MOBS) do
        if M.countCakeLandMobsNamed(mobName, center, clearRadius) > 0 then
            S.doughFarmTypeLock = mobName
            return mobName
        end
    end

    if hrp then
        for _, mobName in ipairs(M.CAKE_LAND_MOBS) do
            if M.countCakeLandMobsNamed(mobName, hrp.Position, 9999) > 0 then
                S.doughFarmTypeLock = mobName
                return mobName
            end
        end
    end

    return nil
end

function M.findCakeLandFarmTarget()
    local farmType = M.getActiveCakeLandFarmType()
    if not farmType then return nil end
    local hrp = M.getHRP()
    local center = S.doughPackPos or S.doughFarmAnchor or (hrp and hrp.Position)
    if not center then return nil end
    if S.doughFarmTarget and S.doughFarmTarget.Parent and S.doughFarmTarget.Name == farmType then
        local hum = S.doughFarmTarget:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then return S.doughFarmTarget end
    end

    return M.findNearestCakeLandMob(farmType, center, M.DOUGH_BRING.PULL_IN_RADIUS)
        or M.findNearestCakeLandMob(farmType, center, 9999)
end

function M.ensureDoughPackPosition(mobHrp)
    if not mobHrp then return S.doughPackPos end
    local pos = mobHrp.Position
    if S.doughPackPos and S.doughFarmTypeLock then
        local aliveNearPack = M.countCakeLandMobsNamed(
            S.doughFarmTypeLock, S.doughPackPos, M.DOUGH_BRING.ATTACK_RADIUS) > 0
        if aliveNearPack and M.horizontalDistance(pos, S.doughPackPos) <= M.DOUGH_BRING.PULL_IN_RADIUS then
            return S.doughPackPos
        end
    end

    S.doughPackPos = pos
    return S.doughPackPos
end

function M.getInventoryMaterialCount(materialName)
    local remote = M.getCommFRemote()
    if not remote then return 0 end
    local ok, inv = pcall(function() return remote:InvokeServer("getInventory") end)
    if not ok or type(inv) ~= "table" then return 0 end
    local total = 0
    for _, item in pairs(inv) do
        if type(item) == "table" and item.Name == materialName then
            total = total + (tonumber(item.Count) or tonumber(item.Amount) or 1)
        end
    end

    return total
end

function M.parseCakePrinceSpawnerResponse(res)
    if res == nil then return nil end
    if type(res) == "number" then
        if res >= 500 then
            return { remaining = 0, ready = true, killed = res }
        end

        return { remaining = math.max(0, 500 - res), ready = false, killed = res }
    end

    if type(res) ~= "string" then
        res = tostring(res)
    end

    local len = #res
    if len >= 86 and len <= 88 then
        local endPos = len == 88 and 41 or (len == 87 and 40 or 39)
        local remaining = tonumber(string.sub(res, 39, endPos))
        if remaining then
            return { remaining = remaining, ready = remaining <= 0, raw = res }
        end
    end

    if len > 0 and (len < 86 or len > 88) then
        local lower = res:lower()
        if len > 88
            or lower:find("open the portal", 1, true)
            or lower:find("defeated enough", 1, true)
            or lower:find("enough enemies", 1, true)
            or lower:find("hurry", 1, true)
            or lower:find("portal", 1, true)
            or lower:find("spawn", 1, true) then
            return { remaining = 0, ready = true, raw = res }
        end
    end

    local remainingText = res:match("(%d+)%s+more") or res:match("defeat%s+(%d+)")
    if remainingText then
        local remaining = tonumber(remainingText)
        return { remaining = remaining, ready = remaining <= 0, raw = res }
    end

    local lower = res:lower()
    if lower:find("enough") or lower:find("portal") or lower:find("open the portal") then
        return { remaining = 0, ready = true, raw = res }
    end

    local digits = string.gsub(res, "%D", "")
    if digits ~= "" then
        local num = tonumber(digits)
        if num then
            if num >= 500 then
                return { remaining = 0, ready = true, killed = num, raw = res }
            end

            if len >= 50 then
                return { remaining = num, ready = false, raw = res }
            end

            return { killed = num, remaining = math.max(0, 500 - num), ready = num >= 500, raw = res }
        end
    end

    return { remaining = nil, ready = false, unknown = true, raw = res }
end

function M.getCakePrinceSpawnProgress()
    local remote = M.getCommFRemote()
    if not remote then return nil end
    local ok, res = pcall(function() return remote:InvokeServer("CakePrinceSpawner") end)
    if not ok or res == nil then
        ok, res = pcall(function() return remote:InvokeServer("CakePrinceSpawner", true) end)
        if not ok then return nil end
    end

    return M.parseCakePrinceSpawnerResponse(res)
end

function M.findDripMamaNpc()
    local npcs = Workspace:FindFirstChild("NPCs")
    if not npcs then return nil end
    for _, name in ipairs({ "drip_mama", "Drip Mama", "Jeffery", "Drip_Mama" }) do
        local npc = npcs:FindFirstChild(name)
        if npc then return npc end
    end

    for _, child in ipairs(npcs:GetChildren()) do
        local lower = child.Name:lower()
        if lower:find("drip", 1, true) and lower:find("mama", 1, true) then
            return child
        end
    end

    return nil
end

function M.getDripMamaStandPos()
    local npc = M.findDripMamaNpc()
    if npc then
        local part = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
            or npc:FindFirstChildWhichIsA("BasePart", true)
        if part then
            return part.Position + Vector3.new(0, 3, 0)
        end
    end

    return M.DoughPos.DripMama + Vector3.new(0, 3, 0)
end

function M.trySpawnCakeRaidPortal(mode)
    if M.isCakePortalOpen() then return true end
    local remote = M.getCommFRemote()
    if not remote then return false end
    if os.clock() - (S.lastDoughSpawnAt or 0) < 1.2 then return false end
    local hrp = M.getHRP()
    if not hrp then return false end
    local stand = M.getDripMamaStandPos()
    if (hrp.Position - stand).Magnitude > 15 then
        if not M.isFarmMoving() then
            M.clearFarmHoverConstraint(hrp)
            M.moveTo(stand)
        end

        return false
    end

    S.lastDoughSpawnAt = os.clock()
    M.cancelFarmMove()
    M.clearFarmHoverConstraint(hrp)
    hrp.CFrame = CFrame.new(stand)
    hrp.AssemblyLinearVelocity = Vector3.zero
    if mode == "king" then
        M.equipToolByName("Sweet Chalice")
    else
        local char = Player.Character
        local equipped = char and char:FindFirstChild("Sweet Chalice")
        if equipped and Player.Backpack then
            equipped.Parent = Player.Backpack
        end
    end

    task.wait(0.2)
    local npc = M.findDripMamaNpc()
    if npc then
        local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            pcall(function() fireproximityprompt(prompt, 0) end)
            task.wait(0.1)
            pcall(function() fireproximityprompt(prompt, 0) end)
        end

        local click = npc:FindFirstChildWhichIsA("ClickDetector", true)
        if click then
            pcall(function() fireclickdetector(click) end)
        end
    end

    for _ = 1, 3 do
        pcall(function() remote:InvokeServer("CakePrinceSpawner") end)
        task.wait(0.12)
        if M.isCakePortalOpen() then return true end
    end

    pcall(function() remote:InvokeServer("CakePrinceSpawner", "Open") end)
    task.wait(0.1)
    pcall(function() remote:InvokeServer("CakePrinceSpawner") end)
    task.wait(0.25)
    if M.isCakePortalOpen() then
        M.doughNotify("Portal opened - enter the mirror", mode)
        return true
    end

    return false
end

function M.tryCraftSweetChalice()
    if M.hasToolByName("Sweet Chalice") then return true end
    if not M.hasToolByName("God's Chalice") then return false end
    if M.getInventoryMaterialCount("Conjured Cocoa") < 10 then return false end
    pcall(function() CommF_:InvokeServer("SweetChaliceNpc") end)
    task.wait(0.35)
    return M.hasToolByName("Sweet Chalice")
end

function M.isCakePortalOpen()
    return M.getCakeMirrorPortalPart() ~= nil
end

function M.getCakeMirrorPortalPart()
    local map = Workspace:FindFirstChild("Map")
    local cakeLoaf = map and map:FindFirstChild("CakeLoaf")
    local mirror = cakeLoaf and cakeLoaf:FindFirstChild("BigMirror")
    local other = mirror and mirror:FindFirstChild("Other")
    if other and other:IsA("BasePart") and other.Transparency <= 0.05 then
        return other
    end

    return nil
end

function M.isInDoughDimension()
    local hrp = M.getHRP()
    if not hrp then return false end
    if hrp.Position.Y > 3500 then return true end
    return M.horizontalDistance(hrp.Position, M.DoughPos.Dimension) <= 400
end

function M.isDoughDimensionLive()
    if M.isInDoughDimension() then return true end
    if M.isCakePortalOpen() then return true end
    if S.doughDimensionActive and os.clock() < (S.doughDimensionWindowUntil or 0) then return true end
    return false
end

function M.enterCakeDimensionPortal()
    if M.isInDoughDimension() then return true end
    if os.clock() - (S.lastDoughPortalEnterAt or 0) < 2 then return false end
    local mirror = M.getCakeMirrorPortalPart()
    if not mirror then return false end
    local hrp = M.getHRP()
    if not hrp then return false end
    local stand = mirror.Position + Vector3.new(0, 3, 0)
    if (hrp.Position - stand).Magnitude > 8 then
        if not M.isFarmMoving() then
            M.moveTo(stand)
        end

        return false
    end

    S.lastDoughPortalEnterAt = os.clock()
    M.cancelFarmMove()
    hrp.CFrame = CFrame.new(stand)
    M.touchInteract(mirror)
    task.wait(0.2)
    M.touchInteract(mirror)
    local deadline = os.clock() + 5
    while os.clock() < deadline do
        if M.isInDoughDimension() then return true end
        task.wait(0.15)
    end

    return M.isInDoughDimension()
end

function M.findDoughRaidBoss()
    for _, name in ipairs({ "Dough King", "Cake Prince" }) do
        local boss = M.findBoss(name)
        if boss then return boss end
    end

    for _, name in ipairs({ "Dough King", "Cake Prince" }) do
        local model = ReplicatedStorage:FindFirstChild(name, true)
        if model and model:IsA("Model") then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then return model end
        end
    end

    return nil
end

function M.getDoughGroundPosition(pos)
    if not pos then return nil end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then table.insert(ignore, enemies) end
    if Player.Character then table.insert(ignore, Player.Character) end
    params.FilterDescendantsInstances = ignore
    local refY = pos.Y
    local bestHit, bestScore = nil, math.huge
    for _, above in ipairs({20, 45, 70}) do
        local origin = Vector3.new(pos.X, refY + above, pos.Z)
        local hit = Workspace:Raycast(origin, Vector3.new(0, -(above + 20), 0), params)
        if hit then
            local yDelta = math.abs(hit.Position.Y - refY)
            if yDelta < 40 and yDelta < bestScore then
                bestScore = yDelta
                bestHit = hit
            end
        end
    end

    local y = bestHit and (bestHit.Position.Y + M.DOUGH_BRING.GROUND_LIFT) or refY
    return Vector3.new(pos.X, y, pos.Z)
end

function M.getDoughHoverY()
    return M.DOUGH_BRING.HOVER_Y or 14
end

function M.getDoughHoverPos(groundPos)
    if not groundPos then return nil end
    return Vector3.new(groundPos.X, groundPos.Y + M.getDoughHoverY(), groundPos.Z)
end

function M.getGroundPosition(pos)
    if not pos then return nil end
    local probeY = math.max(pos.Y, 40) + 100
    local origin = Vector3.new(pos.X, probeY, pos.Z)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then table.insert(ignore, enemies) end
    if Player.Character then table.insert(ignore, Player.Character) end
    params.FilterDescendantsInstances = ignore
    local hit = Workspace:Raycast(origin, Vector3.new(0, -600, 0), params)
    local y = hit and (hit.Position.Y + M.DOUGH_BRING.GROUND_LIFT) or pos.Y
    return Vector3.new(pos.X, y, pos.Z)
end

function M.ensureDoughFarmAnchor(forceNew)
    if S.doughFarmAnchorGround and S.doughFarmAnchor and not forceNew then
        return S.doughFarmAnchor
    end

    local hrp = M.getHRP()
    local seed = M.DoughPos.Farm
    if hrp and M.isNearCakeLand(3200) then
        seed = hrp.Position
    end

    S.doughFarmAnchor = M.getDoughGroundPosition(seed)
    S.doughFarmAnchorGround = S.doughFarmAnchor ~= nil
    return S.doughFarmAnchor
end

function M.resetDoughFarmAnchor()
    S.doughFarmAnchor = nil
    S.doughFarmAnchorGround = false
    S.doughFarmTarget = nil
    S.doughFarmTypeLock = nil
    S.doughPackPos = nil
    S.lastDoughAnchorRefresh = 0
end

function M.resetDoughPatrol()
    S.doughPatrolIx = 0
    S.lastDoughPatrolAt = 0
    S.doughPatrolArrivedAt = nil
    S.doughPatrolGround = nil
    S.doughEmptySince = nil
    S.doughFarmTarget = nil
    S.doughFarmTypeLock = nil
    S.doughPackPos = nil
end

function M.tickDoughCakeLandHover(hrp)
    if not hrp or _G.NexusHubIsMoving() then return end
    if os.clock() - (S.lastDoughHoverSnapAt or 0) < 0.12 then return end
    S.lastDoughHoverSnapAt = os.clock()
    local packPos = S.doughPackPos
    local target = S.doughFarmTarget
    local mobHrp = target and target:FindFirstChild("HumanoidRootPart")
    local basePos = packPos or (mobHrp and mobHrp.Position)
    if not basePos then return end
    M.clearFarmHoverConstraint(hrp)
    local hover = basePos + Vector3.new(0, M.getDoughHoverY(), 0)
    hrp.CFrame = CFrame.new(hover)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
end

function M.tickDoughCakeLandFarm()
    local hrp = M.getHRP()
    if not hrp then return end
    local farmType = M.getActiveCakeLandFarmType()
    if not farmType then
        S.doughFarmTarget = nil
        S.doughFarmAnchor = nil
        S.doughFarmAnchorGround = false
        S.doughPackPos = nil
        local fallback = M.getDoughHoverPos(M.getDoughGroundPosition(M.DoughPos.FarmAlt) or M.DoughPos.FarmAlt)
        if fallback and (not M.isFarmMoving() or os.clock() - (S.lastDoughFallbackAt or 0) >= 6) then
            S.lastDoughFallbackAt = os.clock()
            M.clearFarmHoverConstraint(hrp)
            M.moveTo(fallback)
        end

        return
    end

    local target = M.findCakeLandFarmTarget()
    if not target then
        local far = M.findNearestCakeLandMob(farmType, hrp.Position, 9999)
        if far then
            local farHrp = far:FindFirstChild("HumanoidRootPart")
            if farHrp and not M.isFarmMoving() then
                M.clearFarmHoverConstraint(hrp)
                M.moveTo(farHrp.Position + Vector3.new(0, M.getDoughHoverY(), 0))
            end
        end

        return
    end

    S.doughFarmTarget = target
    local mobHrp = target:FindFirstChild("HumanoidRootPart")
    if not mobHrp then return end
    local packPos = M.ensureDoughPackPosition(mobHrp)
    S.doughFarmAnchor = packPos
    S.doughFarmAnchorGround = true
    local hover = packPos + Vector3.new(0, M.getDoughHoverY(), 0)
    if M.horizontalDistance(hrp.Position, packPos) > 40 then
        if not M.isFarmMoving() then
            M.clearFarmHoverConstraint(hrp)
            M.moveTo(hover)
        end
    end
end

function M.collectCakeLandAttackTargets(targets, anchorPos)
    if not targets then return end
    local farmName = S.doughFarmTypeLock or (S.doughFarmTarget and S.doughFarmTarget.Name)
    if not farmName then return end
    local hrp = M.getHRP()
    anchorPos = S.doughPackPos or anchorPos or S.doughFarmAnchor or (hrp and hrp.Position)
    if not anchorPos then return end
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return end
    local cap = M.DOUGH_BRING.ATTACK_CAP
    local maxDist = M.DOUGH_BRING.ATTACK_RADIUS
    for _, model in ipairs(enemies:GetChildren()) do
        if #targets >= cap then break end
        if not model:IsA("Model") or model.Name ~= farmName then continue end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local mobHrp = model:FindFirstChild("HumanoidRootPart")
        if not hum or not mobHrp or hum.Health <= 0 then continue end
        local nearPack = M.horizontalDistance(mobHrp.Position, anchorPos) <= maxDist
        local nearPlayer = hrp and (mobHrp.Position - hrp.Position).Magnitude <= maxDist
        if not nearPack and not nearPlayer then continue end
        table.insert(targets, { model, mobHrp })
    end
end

function M.tickCakeLandMobPull()
    if not S.doughBringMobActive then return end
    local now = os.clock()
    if now - (S.lastDoughBringAt or 0) < M.DOUGH_BRING.INTERVAL then return end
    S.lastDoughBringAt = now
    local farmType = S.doughFarmTypeLock
    if not farmType then return end
    local packPos = S.doughPackPos
    if not packPos then return end
    local hrp = M.getHRP()
    if not hrp then return end
    local bringCFrame = CFrame.new(packPos)
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return end
    local pulled = 0
    for _, model in ipairs(enemies:GetChildren()) do
        if pulled >= M.DOUGH_BRING.MAX_PER_TICK then break end
        if not model:IsA("Model") or model.Name ~= farmType then continue end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local mobHrp = model:FindFirstChild("HumanoidRootPart")
        if not hum or not mobHrp or hum.Health <= 0 then continue end
        local mobPos = mobHrp.Position
        if M.horizontalDistance(mobPos, hrp.Position) > M.DOUGH_BRING.PULL_IN_RADIUS then continue end
        if M.horizontalDistance(mobPos, packPos) <= M.DOUGH_BRING.PACK_RADIUS then continue end
        pcall(function()
            mobHrp.CFrame = bringCFrame
            mobHrp.CanCollide = false
            mobHrp.AssemblyLinearVelocity = Vector3.zero
            mobHrp.AssemblyAngularVelocity = Vector3.zero
        end)

        pulled = pulled + 1
    end
end

function M.findCakeLandMob()
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies or not HumanoidRootPart then return nil end
    local best, bestDist
    local myPos = HumanoidRootPart.Position
    for _, model in ipairs(enemies:GetChildren()) do
        if model:IsA("Model") and M.isCakeLandMobName(model.Name) then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                local dist = (myPos - hrp.Position).Magnitude
                if not bestDist or dist < bestDist then
                    best, bestDist = model, dist
                end
            end
        end
    end

    return best
end

function M.isNearCakeLand(radius)
    radius = radius or 2800
    local hrp = M.getHRP()
    if not hrp then return false end
    local distFarm = (hrp.Position - M.DoughPos.Farm).Magnitude
    local distHub = (hrp.Position - M.DoughPos.Hub).Magnitude
    return distFarm <= radius or distHub <= radius
end

function M.travelToCakeLand()
    if M.isNearCakeLand() then
        S.doughRaidTravel = false
        return true
    end

    local hrp = M.getHRP()
    if not hrp then return false end
    S.doughRaidTravel = true
    _G.NexusHubSetFarmNoclip(true)
    M.attachFloat()
    local distFarm = (hrp.Position - M.DoughPos.Farm).Magnitude
    if distFarm > 5000 and os.clock() - (S.lastCakeLandEntranceAt or 0) >= 3.0 then
        S.lastCakeLandEntranceAt = os.clock()
        pcall(function()
            CommF_:InvokeServer("requestEntrance", M.DoughPos.Entrance)
        end)

        task.wait(1.25)
        if M.isNearCakeLand(3200) then
            S.doughRaidTravel = false
            return true
        end
    end

    local goal = distFarm > 1200 and M.DoughPos.Hub or M.DoughPos.Farm
    local goalGround = M.getDoughGroundPosition(goal) or goal
    local goalHover = M.getDoughHoverPos(goalGround) or (goal + Vector3.new(0, M.getDoughHoverY(), 0))
    if not M.isFarmMoving() or os.clock() - (S.lastCakeLandTravelAt or 0) >= 4.0 then
        S.lastCakeLandTravelAt = os.clock()
        M.moveTo(goalHover)
    end

    if (hrp.Position - goalGround).Magnitude <= 80 then
        hrp.CFrame = CFrame.new(goalHover)
    end

    return M.isNearCakeLand(3200)
end

function M.tickAutoDoughRaid(mode)
    local enabled = mode == "king" and S.autoDoughKing or S.autoDoughPrince
    if not enabled then
        if mode == "king" then
            if not S.autoDoughPrince then
                S.doughRaidCombatTarget = nil
                S.doughBringMobActive = false
            end
        else
            if not S.autoDoughKing then
                S.doughRaidCombatTarget = nil
                S.doughBringMobActive = false
            end
        end

        return
    end

    if not M.isSea3() then
        M.doughNotify("Sea 3 / Cake Land only", mode)
        S.doughRaidCombatTarget = nil
        S.doughBringMobActive = false
        return
    end

    if not Humanoid or not HumanoidRootPart or Humanoid.Health <= 0 then return end
    if mode == "king" and not M.hasToolByName("Sweet Chalice") then
        if M.hasToolByName("God's Chalice") and M.getInventoryMaterialCount("Conjured Cocoa") >= 10 then
            if M.tryCraftSweetChalice() then
                M.doughNotify("Sweet Chalice crafted - hold it when spawning", mode)
            end
        end
    end

    local boss = M.findDoughRaidBoss()
    if boss then
        S.doughRaidCombatTarget = boss
        S.doughBringMobActive = false
        if not M.isInDoughDimension() then
            if M.isCakePortalOpen() or M.isDoughDimensionLive() then
                M.enterCakeDimensionPortal()
            elseif not M.isFarmMoving() then
                M.moveTo(M.DoughPos.DripMama + Vector3.new(0, 3, 0))
            end

            return
        end

        if not S.autoAttack then M.setAutoAttack(true) end
        M.equipWeapon()
        local bossPos = M.getModelPosition(boss)
        if bossPos and (HumanoidRootPart.Position - bossPos).Magnitude > 120 then
            if not _G.NexusHubIsMoving() then
                M.moveTo(bossPos + Vector3.new(0, M.getFarmOrbitY(), 0))
            end
        end

        return
    end

    S.doughRaidCombatTarget = nil
    if M.isCakePortalOpen() then
        S.doughBringMobActive = false
        if not M.isInDoughDimension() then
            if not M.travelToCakeLand() and not M.isFarmMoving() then
                M.moveTo(M.DoughPos.DripMama + Vector3.new(0, 3, 0))
            end

            if M.isNearCakeLand(3200) then
                M.enterCakeDimensionPortal()
            end

            return
        end

        return
    end

    local prog = M.getCakePrinceSpawnProgress()
    if prog and os.clock() - (S.lastDoughStatusAt or 0) >= 8 then
        S.lastDoughStatusAt = os.clock()
        if prog.ready then
            M.doughNotify("500 kills reached - opening portal", mode)
        elseif prog.remaining then
            M.doughNotify(tostring(prog.remaining) .. " Cake Land kills left", mode)
        end
    end

    if prog and prog.ready then
        S.doughBringMobActive = false
        S.doughFarmTarget = nil
        S.doughPackPos = nil
        if M.isCakePortalOpen() then
            if not M.isInDoughDimension() then
                M.enterCakeDimensionPortal()
            end

            return
        end

        if not M.isNearCakeLand(3200) then
            M.travelToCakeLand()
            return
        end

        if mode == "king" then
            if not M.hasToolByName("Sweet Chalice") then
                M.doughNotify("Need Sweet Chalice equipped to spawn Dough King", mode)
                if not M.isFarmMoving() then
                    M.moveTo(M.getDripMamaStandPos())
                end

                return
            end
        end

        M.trySpawnCakeRaidPortal(mode)
        return
    end

    if S.doughBringMobActive and os.clock() - (S.lastDoughSpawnerPing or 0) >= 4 then
        S.lastDoughSpawnerPing = os.clock()
        pcall(function()
            local remote = M.getCommFRemote()
            if remote then remote:InvokeServer("CakePrinceSpawner") end
        end)
    end

    if not M.travelToCakeLand() then
        if not M.isFarmMoving() then
            local farmGround = M.getDoughGroundPosition(M.DoughPos.Farm) or M.DoughPos.Farm
            M.moveTo(M.getDoughHoverPos(farmGround) or farmGround)
        end

        return
    end

    S.doughBringMobActive = true
    _G.NexusHubSetFarmNoclip(true)
    M.startDoughPackAttackLoop()
    M.tickDoughCakeLandFarm()
    if not S.autoAttack then M.setAutoAttack(true) end
    M.equipWeapon()
end

function M.hasFistOfDarkness()
    return M.hasToolByName("Fist of Darkness")
end

function M.markPirateRaidSeen()
    S.lastPirateRaidSeen = os.clock()
end

function M.scanPirateRaidSignal()
    local center = M.PirateRaidPos
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return end
    for _, npc in ipairs(enemies:GetChildren()) do
        if npc.Name ~= "rip_indra True Form" then
            local hrp = npc:FindFirstChild("HumanoidRootPart")
            local hum = npc:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 and (hrp.Position - center).Magnitude < 700 then
                M.markPirateRaidSeen()
                return
            end
        end
    end
end

function M.isPirateRaidActive()
    M.scanPirateRaidSignal()
    return (os.clock() - S.lastPirateRaidSeen) <= 8
end

function M.onPirateRaidBroadcast(text)
    if type(text) ~= "string" then return end
    local lower = text:lower()
    if lower:find("pirates have been spotted", 1, true)
        or lower:find("pirates are raiding", 1, true) then
        S.pirateRaidCommencing = true
        S.pirateRaidWindowUntil = os.clock() + 600
    elseif lower:find("pirates have stopped raiding", 1, true)
        or lower:find("good job! anybody who defeated", 1, true) then
        S.pirateRaidCommencing = false
    end
end

function M.onDoughDimensionBroadcast(text)
    if type(text) ~= "string" then return end
    local lower = text:lower()
    if lower:find("dimension has spawned", 1, true)
        or lower:find("a dimension has spawned", 1, true) then
        S.doughDimensionActive = true
        S.doughDimensionWindowUntil = os.clock() + 480
    elseif lower:find("dimension has disappeared", 1, true)
        or lower:find("the dimension has disappeared", 1, true) then
        S.doughDimensionActive = false
    end
end

function M.onSystemBroadcast(text)
    M.onPirateRaidBroadcast(text)
    M.onDoughDimensionBroadcast(text)
end

function M.isPirateRaidCommencing()
    if M.findPirateRaidEnemy() then return true end
    if S.pirateRaidCommencing and os.clock() < (S.pirateRaidWindowUntil or 0) then
        return true
    end

    return false
end

function M.setupBroadcastHooks()
    if S.broadcastHooksStarted then return end
    S.broadcastHooksStarted = true
    local commE = M.getCommE()
    if commE then
        M.AddConnection(commE.OnClientEvent:Connect(function(...)
            for i = 1, select("#", ...) do
                M.onSystemBroadcast(select(i, ...))
            end
        end))
    end

    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            M.AddConnection(TextChatService.MessageReceived:Connect(function(message)
                if message and message.Text then
                    M.onSystemBroadcast(message.Text)
                end
            end))
        end
    end)
end

function M.getCommE()
    if CommE and CommE.Parent then return CommE end
    local ok, remote = pcall(function()
        return Remotes:WaitForChild("CommE", 10)
    end)

    if ok and remote then
        CommE = remote
        return remote
    end

    CommE = Remotes:FindFirstChild("CommE")
    return CommE
end

function M.hasKen()
    local char = Player.Character
    if not char then return false end
    return CollectionService:HasTag(char, "Ken")
end

function M.enableBuso()
    local char = Player.Character
    if not char or not char:FindFirstChildOfClass("Humanoid") then return false end
    if char:FindFirstChild("HasBuso") then return true end
    local remote = M.getCommFRemote()
    if not remote then return false end
    local ok = pcall(function() remote:InvokeServer("Buso") end)
    return ok
end

function M.setInstinct(enabled)
    if enabled and not M.hasKen() then return false end
    local remote = M.getCommE()
    if not remote then return false end
    local ok = pcall(function() remote:FireServer("Ken", enabled == true) end)
    return ok
end

function M.tickAutoInstinct()
    if not S.autoInstinct then return end
    if not M.hasKen() then return end
    M.setInstinct(true)
    local dodges = Player:GetAttribute("KenDodgesLeft")
    if dodges == 0 then
        M.setInstinct(true)
    end
end

function M.buyHakiAbility(name)
    if not CommF_ then return false, "CommF_ missing" end
    return pcall(function()
        return CommF_:InvokeServer("BuyHaki", name)
    end)
end

function M.buyInstinct()
    if not CommF_ then return false, "CommF_ missing" end
    return pcall(function()
        return CommF_:InvokeServer("KenTalk", "Buy")
    end)
end

function M.buyHakiColor()
    if not CommF_ then return false, "CommF_ missing" end
    return pcall(function()
        return CommF_:InvokeServer("ColorsDealer", "2")
    end)
end

function M.buyRaceGear()
    if not CommF_ then return false, "CommF_ missing" end
    return pcall(function()
        return CommF_:InvokeServer("UpgradeRace", "Buy")
    end)
end

function M.buyAccessory(itemName)
    if not CommF_ then return false, "CommF_ missing" end
    return pcall(function()
        return CommF_:InvokeServer("BuyItem", itemName)
    end)
end

function M.shopPurchase(label, buyFn)
    M.notify("Shop", "Buying " .. label .. "...", 2)
    local ok, res = buyFn()
    if ok then
        M.notify("Shop", label .. ": " .. tostring(res ~= nil and res or "request sent"), 4)
    else
        M.notify("Shop", label .. " failed - " .. tostring(res), 4)
    end

    return ok, res
end

function M.findFruitShopFrame()
    local pg = Player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local main = pg:FindFirstChild("Main")
    if not main then
        local ok, res = pcall(function()
            return pg:WaitForChild("Main", 20)
        end)

        main = ok and res or nil
    end

    if main then
        if main:IsA("ScreenGui") then
            main.Enabled = true
        end

        local shop = main:FindFirstChild("FruitShop", true)
        if shop and shop:IsA("GuiObject") then
            return shop
        end
    end

    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") or gui:IsA("Folder") then
            local shop = gui:FindFirstChild("FruitShop", true)
            if shop and shop:IsA("GuiObject") then
                if gui:IsA("ScreenGui") then
                    gui.Enabled = true
                end

                return shop
            end
        end
    end

    return nil
end

function M.showFruitShopUi()
    pcall(function()
        if CommF_ then CommF_:InvokeServer("GetFruits") end
    end)

    for _ = 1, 8 do
        local shop = M.findFruitShopFrame()
        if shop then
            shop.Visible = true
            return true
        end

        task.wait(0.25)
    end

    return false
end

function M.openFruitShopUi(label)
    task.spawn(function()
        if M.showFruitShopUi() then
            M.notify("Shop", label .. " opened", 2)
        else
            M.notify("Shop", "Could not open fruit shop - wait for game UI to load and retry", 5)
        end
    end)
end

function M.openRegularFruitDealer()
    M.openFruitShopUi("Regular fruit shop")
end

function M.openAdvancedFruitDealer()
    M.openFruitShopUi("Advanced fruit shop")
end

function M.findPirateRaidEnemy()
    local center = M.PirateRaidPos
    local best, bestDist
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end
    for _, npc in ipairs(enemies:GetChildren()) do
        if npc.Name ~= "rip_indra True Form" then
            local hum = npc:FindFirstChildOfClass("Humanoid")
            local hrp = npc:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and hrp and (hrp.Position - center).Magnitude < 700 then
                local d = HumanoidRootPart and (HumanoidRootPart.Position - hrp.Position).Magnitude or 0
                if not bestDist or d < bestDist then best, bestDist = npc, d end
            end
        end
    end

    return best
end

function M.isNearPirateRaidCastle(radius)
    radius = radius or 900
    local hrp = M.getHRP()
    if not hrp then return false end
    if M.isOnIsland("Castle on the Sea") then return true end
    if (hrp.Position - M.PirateRaidStand).Magnitude <= radius then return true end
    if (hrp.Position - M.PirateRaidPos).Magnitude <= radius then return true end
    return false
end

function M.travelToPirateRaidCastle()
    if M.isNearPirateRaidCastle(900) then return false end
    if os.clock() - (S.lastPirateRaidTravelAt or 0) < 4 then return true end
    S.lastPirateRaidTravelAt = os.clock()
    _G.NexusHubSetFarmNoclip(true)
    if not M.isNearPirateRaidCastle(900) and not M.isFarmMoving() then
        if not M.isOnIsland("Castle on the Sea") then
            local castle = M.findIslandModel("Castle on the Sea")
            if castle then
                M.moveTo(castle:GetPivot().Position + Vector3.new(0, 6, 0))
            end
        else
            M.moveTo(M.PirateRaidStand + Vector3.new(0, 6, 0))
        end
    end

    return true
end

function M.tweenNear(pos, reach)
    local hrp = M.getHRP()
    if not hrp then return end
    local goal = pos + Vector3.new(0, 4, 0)
    local dist = (hrp.Position - goal).Magnitude
    if dist > (reach or 20) then
        if not M.isFarmMoving() then M.moveTo(goal) end
    else
        M.cancelFarmMove()
    end
end

function M.pressRaceKey(keyCode)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

function M.isRaceTransformed()
    local char = Player.Character
    if not char then return false end
    local flag = char:FindFirstChild("RaceTransformed")
    return flag and flag:IsA("BoolValue") and flag.Value
end

function M.isFarmOrTravelActive()
    return _G.NexusHubAutofarm == true or S.autoRaid or S.autoBossFarm or S.chestFarmEnabled
        or S.autoMaterialFarm or M.isFruitSniperActive()
        or (S.autoPirateRaid and S.pirateRaidEngaged) or (S.autoFactoryRaid and S.factoryRaidEngaged)
        or S.autoMasteryFarm or S.autoIndra or S.autoDarkbeard or S.autoCursedCaptain
        or (S.autoElite and S.eliteCombatTarget)
        or S.autoPray or S.autoTryLuck or S.autoSoulReaper or S.autoSaber
        or _G.NexusHubAutoSecondSea == true or _G.NexusHubAutoThirdSea == true
        or S.autoSeaFarm or S.autoLeviathan
end

function M.sanitizeIdleState()
    if M.isFarmOrTravelActive() then return end
    if _G.NexusHubMoveNeedsNoclip and _G.NexusHubMoveNeedsNoclip() then return end
    pcall(function() _G.NexusHubLightPhysicsClean() end)
    if _G.NexusHubFarmNoclip then
        pcall(function() _G.NexusHubSetFarmNoclip(false) end)
    end

    if S.ActiveTween then
        pcall(function() S.ActiveTween:Cancel() end)
        S.ActiveTween = nil
    end

    if _G.NexusHubIsMoving and _G.NexusHubIsMoving() then
        pcall(function() _G.NexusHubCancelMove() end)
    end
end

function M.antiAfkPreKickPulse()
    if not S.antiAfkEnabled or M.isFarmOrTravelActive() then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
    end)
end

function M.disableDefaultIdledKicks()
    if type(getconnections) ~= "function" then return end
    pcall(function()
        for _, conn in ipairs(getconnections(Player.Idled)) do
            if conn.Disable then conn:Disable() end
        end
    end)
end

function M.setAntiAfk(enabled)
    S.antiAfkEnabled = enabled
    S.antiAfkGeneration = S.antiAfkGeneration + 1
    local myGen = S.antiAfkGeneration
    if S.antiAfkConn then
        pcall(function() S.antiAfkConn:Disconnect() end)
        S.antiAfkConn = nil
    end

    if not enabled then return end
    M.disableDefaultIdledKicks()
    S.antiAfkConn = M.AddConnection(Player.Idled:Connect(function()
        if not S.antiAfkEnabled then return end
        pcall(function()
            VirtualUser:CaptureController()
            local cam = workspace.CurrentCamera
            local cf = cam and cam.CFrame or CFrame.new()
            VirtualUser:Button2Down(Vector2.new(0, 0), cf)
            task.wait(0.35)
            VirtualUser:Button2Up(Vector2.new(0, 0), cf)
        end)
    end))

    task.spawn(function()
        local lastSanitize = 0
        local lastPreKick = os.clock()
        while _G.NexusHubLoaded and S.antiAfkEnabled and S.antiAfkGeneration == myGen do
            task.wait(5)
            if not S.antiAfkEnabled or S.antiAfkGeneration ~= myGen then break end
            local now = os.clock()
            if now - lastSanitize >= 45 then
                lastSanitize = now
                pcall(M.sanitizeIdleState)
            end

            if now - lastPreKick >= 17 * 60 then
                lastPreKick = now
                pcall(M.antiAfkPreKickPulse)
            end
        end
    end)
end

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(1.5)
        if not S.autoStoreFruit then continue end
        M.tryStoreAllFruits()
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(0.35)
        if not S.autoFruitSniper then
            S.fruitSniperTarget = nil
            if S.fruitSniperChasing then
                S.fruitSniperChasing = false
                if not (S.autofarm or S.autoRaid or S.autoBossFarm or S.chestFarmEnabled or S.autoMaterialFarm
                    or (S.autoPirateRaid and S.pirateRaidEngaged) or S.autoPray or S.autoTryLuck
                    or S.autoRollBones or S.autoSoulReaper) then
                    M.removeFloat()
                    if S.ActiveTween then S.ActiveTween:Cancel(); S.ActiveTween = nil end
                end
            end

            continue
        end

        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp or hum.Health <= 0 then continue end
        local fruit = M.findNearestSpawnedFruit()
        if not fruit then
            S.fruitSniperTarget = nil
            if S.fruitSniperChasing then
                S.fruitSniperChasing = false
                if not (S.autofarm or S.autoRaid or S.autoBossFarm or S.chestFarmEnabled or S.autoMaterialFarm
                    or (S.autoPirateRaid and S.pirateRaidEngaged) or S.autoPray or S.autoTryLuck
                    or S.autoRollBones or S.autoSoulReaper) then
                    M.removeFloat()
                    if S.ActiveTween then S.ActiveTween:Cancel(); S.ActiveTween = nil end
                end
            end

            continue
        end

        local handle = M.getFruitHandlePart(fruit)
        if not handle or not handle.Parent then
            S.fruitSniperTarget = nil
            S.fruitSniperChasing = false
            continue
        end

        local newTarget = fruit ~= S.fruitSniperTarget
        S.fruitSniperChasing = true
        if newTarget then
            S.fruitSniperTarget = fruit
            M.pauseFarmForFruitSniper()
            if os.clock() - S.lastFruitSniperNotify > 6 then
                S.lastFruitSniperNotify = os.clock()
                M.notify("Fruit Sniper", "Going to " .. fruit.Name, 4)
            end
        end

        M.attachFloat()
        _G.NexusHubSetFarmNoclip(true)
        for _, bp in ipairs(char:GetChildren()) do
            if bp:IsA("BasePart") then bp.CanCollide = false end
        end

        local goal = handle.Position + Vector3.new(0, (handle.Size and handle.Size.Y or 2) * 0.5 + 2, 0)
        local dist = (hrp.Position - goal).Magnitude
        if dist > 5 then
            local moving = _G.NexusHubIsMoving()
            if moving and _G.NexusHubMoveGoal and (_G.NexusHubMoveGoal - goal).Magnitude > 15 then
                M.cancelFarmMove()
                S.ActiveTween = nil
                moving = false
            end

            if not moving then M.moveTo(goal) end
        else
            M.cancelFarmMove()
            S.ActiveTween = nil
            hrp.CFrame = CFrame.new(handle.Position + Vector3.new(0, 2, 0))
            pcall(function()
                if handle:IsA("BasePart") then
                    handle.CFrame = hrp.CFrame
                end
            end)
        end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(1.0)
        pcall(M.tickAutoHomePoint)
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    local lastNotify = 0
    while _G.NexusHubLoaded do
        task.wait(0.75)
        if not S.autoIndra then
            S.indraCombatTarget = nil
            continue
        end

        if not M.isSea3() then
            if os.clock() - lastNotify > 20 then
                lastNotify = os.clock()
                M.notify("Auto Indra", "Sea 3 only", 4)
            end

            S.indraCombatTarget = nil
            continue
        end

        if not Humanoid or not HumanoidRootPart or Humanoid.Health <= 0 then continue end
        local boss = M.findRipIndra()
        if boss then
            S.indraCombatTarget = boss
            if os.clock() - lastNotify > 12 then
                lastNotify = os.clock()
                M.notify("Auto Indra", "Fighting " .. boss.Name, 4)
            end

            if not S.autoAttack then M.setAutoAttack(true) end
            M.equipWeapon()
        else
            S.indraCombatTarget = nil
            if (HumanoidRootPart.Position - M.IndraWaitPos).Magnitude > 900
                and not M.isOnIsland("Castle on the Sea") then
                M.teleportToIsland("Castle on the Sea")
                task.wait(2)
            end

            if not M.isFarmMoving() then
                M.moveTo(M.IndraWaitPos)
            end
        end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(0.75)
        if not S.autoElite then
            S.eliteCombatTarget = nil
            continue
        end

        if not Humanoid or not HumanoidRootPart or Humanoid.Health <= 0 then continue end
        local elite = M.findEliteTarget()
        if elite then
            S.eliteCombatTarget = elite
            if os.clock() - S.lastEliteNotify > 12 then
                S.lastEliteNotify = os.clock()
                M.notify("Auto Elites", "Fighting " .. elite.Name, 4)
            end

            if not S.autoAttack then M.setAutoAttack(true) end
            M.equipWeapon()
        else
            S.eliteCombatTarget = nil
            if os.clock() - S.lastEliteNotify > 25 then
                S.lastEliteNotify = os.clock()
                M.notify("Auto Elites", "Waiting for an Elite Pirate to spawn", 4)
            end
        end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    local lastNotify = 0
    while _G.NexusHubLoaded do
        task.wait(0.75)
        if not S.autoDarkbeard then
            S.darkbeardCombatTarget = nil
            continue
        end

        if not M.isSea2() then
            if os.clock() - lastNotify > 20 then
                lastNotify = os.clock()
                M.notify("Auto Darkbeard", "Second Sea only", 4)
            end

            S.darkbeardCombatTarget = nil
            continue
        end

        if not Humanoid or not HumanoidRootPart or Humanoid.Health <= 0 then continue end
        if not M.isOnIsland("Kingdom of Rose") then
            if os.clock() - lastNotify > 12 then
                lastNotify = os.clock()
                M.notify("Auto Darkbeard", "Traveling to Kingdom of Rose...", 4)
            end

            pcall(function() M.teleportToIsland("Kingdom of Rose") end)
            task.wait(2)
            continue
        end

        local safeAltar = M.getDarkbeardSafePos(M.DarkbeardAltarPos + Vector3.new(0, 6, 0))
        local boss = M.findDarkbeard()
        if boss then
            S.darkbeardCombatTarget = boss
            if os.clock() - lastNotify > 12 then
                lastNotify = os.clock()
                M.notify("Auto Darkbeard", "Fighting Darkbeard", 4)
            end

            if not S.autoAttack then M.setAutoAttack(true) end
            M.equipWeapon()
        else
            S.darkbeardCombatTarget = nil
            local darkbeardPending = ReplicatedStorage:FindFirstChild("Darkbeard", true) ~= nil
            if M.hasFistOfDarkness() and not darkbeardPending then
                if not M.isFarmMoving() then
                    M.moveToDarkbeard(safeAltar)
                end

                if (HumanoidRootPart.Position - safeAltar).Magnitude <= 22 then
                    HumanoidRootPart.CFrame = CFrame.new(safeAltar)
                end
            else
                if not M.hasFistOfDarkness() and os.clock() - lastNotify > 15 then
                    lastNotify = os.clock()
                    M.notify("Auto Darkbeard", "Need Fist of Darkness - holding at safe altar spot", 5)
                end

                if not M.isFarmMoving() then
                    M.moveToDarkbeard(safeAltar)
                end

                if (HumanoidRootPart.Position - safeAltar).Magnitude <= 22 then
                    HumanoidRootPart.CFrame = CFrame.new(safeAltar)
                end
            end
        end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    local lastNotify = 0
    while _G.NexusHubLoaded do
        task.wait(0.75)
        if not S.autoCursedCaptain then
            if S.cursedCaptainEngaged then
                M.finishCursedCaptainEngage()
            end

            S.cursedCaptainCombatTarget = nil
            continue
        end

        if not M.isSea2() then
            if os.clock() - lastNotify > 20 then
                lastNotify = os.clock()
                M.notify("Auto Cursed Captain", "Second Sea only", 4)
            end

            if S.cursedCaptainEngaged then
                M.finishCursedCaptainEngage()
            end

            S.cursedCaptainCombatTarget = nil
            continue
        end

        if not Humanoid or not HumanoidRootPart or Humanoid.Health <= 0 then continue end
        if M.cursedCaptainSpawned() then
            S.cursedCaptainMissingSince = nil
            M.beginCursedCaptainEngage()
            local boss = M.findCursedCaptain()
            if boss then
                S.cursedCaptainCombatTarget = boss
                if os.clock() - lastNotify > 12 then
                    lastNotify = os.clock()
                    M.notify("Auto Cursed Captain", "Fighting Cursed Captain", 4)
                end

                if not S.autoAttack then M.setAutoAttack(true) end
                M.equipWeapon()
            else
                S.cursedCaptainCombatTarget = nil
                M.goToCursedShipInside()
            end
        elseif S.cursedCaptainEngaged then
            if not S.cursedCaptainMissingSince then S.cursedCaptainMissingSince = os.clock() end
            if os.clock() - S.cursedCaptainMissingSince >= 20 then
                M.finishCursedCaptainEngage()
            end
        else
            S.cursedCaptainCombatTarget = nil
        end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(0.5)
        if S.autoDoughPrince then
            pcall(function() M.tickAutoDoughRaid("prince") end)
        end

        if S.autoDoughKing then
            pcall(function() M.tickAutoDoughRaid("king") end)
        end

        if not S.autoDoughPrince and not S.autoDoughKing then
            S.doughRaidCombatTarget = nil
            S.doughBringMobActive = false
            S.doughRaidTravel = false
        end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    local lastNotify = 0
    while _G.NexusHubLoaded do
        task.wait(0.75)
        if not S.autoPirateRaid then
            S.pirateRaidTarget = nil
            S.pirateRaidEngaged = false
            continue
        end

        if not M.isSea3() then
            if os.clock() - lastNotify > 20 then
                lastNotify = os.clock()
                M.notify("Pirate Raid", "Sea 3 only", 4)
            end

            S.pirateRaidTarget = nil
            S.pirateRaidEngaged = false
            continue
        end

        if not Humanoid or not HumanoidRootPart or Humanoid.Health <= 0 then continue end
        if not M.isPirateRaidCommencing() then
            S.pirateRaidEngaged = false
            S.pirateRaidTarget = nil
            continue
        end

        S.pirateRaidEngaged = true
        if not M.isNearPirateRaidCastle(900) then
            M.travelToPirateRaidCastle()
            continue
        end

        local enemy = M.findPirateRaidEnemy()
        if enemy then
            S.pirateRaidTarget = enemy
            if os.clock() - lastNotify > 10 then
                lastNotify = os.clock()
                M.notify("Pirate Raid", "Raid active - fighting at Castle on the Sea", 4)
            end

            if not S.autoAttack then M.setAutoAttack(true) end
            M.equipWeapon()
        else
            S.pirateRaidTarget = nil
            if not M.isFarmMoving() then
                M.moveTo(M.PirateRaidStand + Vector3.new(0, 6, 0))
            end
        end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    local lastNotify = 0
    while _G.NexusHubLoaded do
        task.wait(0.75)
        if not S.autoFactoryRaid then
            S.factoryRaidTarget = nil
            S.factoryRaidEngaged = false
            M.finishFactoryRaidEngage()
            continue
        end

        if not M.isSea2() then
            if os.clock() - lastNotify > 20 then
                lastNotify = os.clock()
                M.notify("Factory Raid", "Second Sea only", 4)
            end

            S.factoryRaidTarget = nil
            S.factoryRaidEngaged = false
            M.finishFactoryRaidEngage()
            continue
        end

        if not Humanoid or not HumanoidRootPart or Humanoid.Health <= 0 then continue end
        local core = M.findFactoryCore()
        local pending = M.isFactoryCorePending()
        if core or pending then
            S.factoryRaidEngaged = true
            S.factoryRaidTarget = core
            M.beginFactoryRaidEngage()
            if core and os.clock() - lastNotify > 12 then
                lastNotify = os.clock()
                M.notify("Factory Raid", "Core active - attacking factory", 4)
            elseif pending and os.clock() - lastNotify > 12 then
                lastNotify = os.clock()
                M.notify("Factory Raid", "Core spawning - traveling to factory", 4)
            end

            if core and not S.autoAttack then M.setAutoAttack(true) end
        else
            S.factoryRaidEngaged = false
            S.factoryRaidTarget = nil
            M.finishFactoryRaidEngage()
        end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(1)
        if S.autoBuso then M.enableBuso() end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(2)
        if S.autoInstinct then
            M.tickAutoInstinct()
        end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(3)
        if S.autoBuyHakiColor then M.buyHakiColor() end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(3)
        if S.autoBuyRaceGear then M.buyRaceGear() end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    local lastRollMsg = nil
    while _G.NexusHubLoaded do
        if not S.autoFruitRoll then
            lastRollMsg = nil
            task.wait(2)
            continue
        end

        local res, err = M.rollFruitGacha()
        if res ~= nil then
            local msg = tostring(res)
            if msg ~= lastRollMsg then
                lastRollMsg = msg
                M.notify("Auto Gacha", msg, 5)
            end
        elseif err and lastRollMsg ~= "__fail__" then
            lastRollMsg = "__fail__"
            M.notify("Auto Gacha", "Roll failed - check level/beli", 5)
        end

        local delay = M.getFruitRollDelay(res)
        for _ = 1, delay do
            if not (_G.NexusHubLoaded and S.autoFruitRoll) then break end
            task.wait(1)
        end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    local lastMsg
    while _G.NexusHubLoaded do
        task.wait(1.5)
        if not S.autoPray then lastMsg = nil; continue end
        if not Humanoid or not HumanoidRootPart or Humanoid.Health <= 0 then continue end
        if not M.isSea3() then
            M.hauntedNotify("Auto Pray", "Sea 3 / Haunted Castle only")
            task.wait(20)
            continue
        end

        if not M.isNightTime() then task.wait(8); continue end
        M.attachFloat()
        if not M.ensureHauntedCastle() then continue end
        M.tweenNear(M.HauntedPos.Gravestone, 18)
        if (HumanoidRootPart.Position - M.HauntedPos.Gravestone).Magnitude <= 25 then
            local _, res = M.gravestoneAction(1)
            if res ~= nil then
                local msg = tostring(res)
                if msg ~= lastMsg then
                    lastMsg = msg
                    M.notify("Auto Pray", msg, 5)
                end
            end

            task.wait(15)
        end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    local lastMsg
    while _G.NexusHubLoaded do
        task.wait(1.5)
        if not S.autoTryLuck then lastMsg = nil; continue end
        if not Humanoid or not HumanoidRootPart or Humanoid.Health <= 0 then continue end
        if not M.isSea3() then
            M.hauntedNotify("Auto Try Luck", "Sea 3 / Haunted Castle only")
            task.wait(20)
            continue
        end

        if not M.isNightTime() then task.wait(8); continue end
        M.attachFloat()
        if not M.ensureHauntedCastle() then continue end
        M.tweenNear(M.HauntedPos.Gravestone, 18)
        if (HumanoidRootPart.Position - M.HauntedPos.Gravestone).Magnitude <= 25 then
            local _, res = M.gravestoneAction(2)
            if res ~= nil then
                local msg = tostring(res)
                if msg ~= lastMsg then
                    lastMsg = msg
                    M.notify("Auto Try Luck", msg, 5)
                end
            end

            task.wait(15)
        end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    local lastMsg
    while _G.NexusHubLoaded do
        if not S.autoRollBones then
            lastMsg = nil
            task.wait(0.5)
            continue
        end

        if not M.isSea3() then
            M.hauntedNotify("Auto Roll Bones", "Sea 3 only")
            task.wait(20)
            continue
        end

        local bones, rollsLeft = M.getBonesInfo()
        if bones >= 50 and rollsLeft > 0 then
            local _, res = M.rollBonesSurprise()
            if res ~= nil then
                local msg = tostring(res)
                if msg ~= lastMsg then
                    lastMsg = msg
                    M.notify("Auto Roll Bones", msg, 5)
                end

                local lower = msg:lower()
                if lower:find("wait") or lower:find("cool") or lower:find("not enough") then
                    task.wait(1)
                else
                    task.wait(0.08)
                end
            else
                task.wait(0.08)
            end
        else
            task.wait(0.75)
        end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(0.5)
        if not S.autoSoulReaper then
            S.soulReaperTarget = nil
            continue
        end

        if not Humanoid or not HumanoidRootPart or Humanoid.Health <= 0 then continue end
        if not M.isSea3() then
            M.hauntedNotify("Auto Soul Reaper", "Sea 3 / Haunted Castle only")
            task.wait(20)
            continue
        end

        M.attachFloat()
        if not M.ensureHauntedCastle() then continue end
        local reaper = M.findSoulReaper()
        if reaper then
            S.soulReaperTarget = reaper
            if not S.autoAttack then M.setAutoAttack(true) end
            continue
        end

        S.soulReaperTarget = nil
        if M.hasToolByName("Hallow Essence") then
            M.equipToolByName("Hallow Essence")
            M.tweenNear(M.HauntedPos.Altar, 12)
            if (HumanoidRootPart.Position - M.HauntedPos.Altar).Magnitude <= 20 then
                HumanoidRootPart.CFrame = CFrame.new(M.HauntedPos.Altar + Vector3.new(0, 3, 0))
                task.wait(2)
            end

            continue
        end

        local bones, rollsLeft = M.getBonesInfo()
        if bones >= 50 and rollsLeft > 0 then
            M.rollBonesSurprise()
            task.wait(0.08)
        else
            task.wait(0.75)
        end
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(0.5)
        if not S.autoSaber then continue end
        pcall(M.tickAutoSaber)
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(0.15)
        if not S.autoSecondSea then continue end
        pcall(M.tickAutoSecondSea)
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(0.15)
        if not S.autoThirdSea then continue end
        pcall(M.tickAutoThirdSea)
    end
end)

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(2.5)
        if not (_G.NexusHubAutoV3 or _G.NexusHubAutoV4 or S.autoActivateV3 or S.autoActivateV4) then continue end
        if not Player.Character or not Player.Character:FindFirstChild("Humanoid") then continue end
        if Player.Character.Humanoid.Health <= 0 then continue end
        if (_G.NexusHubAutoV4 or S.autoActivateV4) and not M.isRaceTransformed() then
            M.pressRaceKey(Enum.KeyCode.Y)
        end

        if (_G.NexusHubAutoV3 or S.autoActivateV3) then
            M.pressRaceKey(Enum.KeyCode.T)
        end
    end
end)

function M.isSeatedOn(boat)
    return Humanoid and Humanoid.SeatPart ~= nil and Humanoid.SeatPart:IsDescendantOf(boat)
end

function M.trySitOnBoat(boat)
    if not boat or not Humanoid or not HumanoidRootPart then return false end
    if M.isSeatedOn(boat) then return true end
    local seat = M.getBoatVehicleSeat(boat)
    if not seat then return false end
    pcall(function() Humanoid.Sit = false end)
    for _ = 1, 6 do
        if M.isSeatedOn(boat) then return true end
        if not (S.autoSeaFarm or S.autoLeviathan) then return false end
        local seatCFrame = seat.CFrame * CFrame.new(0, 2.5, 0)
        local t = M.moveToCFrame(seatCFrame)
        if t then t.Completed:Wait() end
        for _ = 1, 3 do
            if M.isSeatedOn(boat) then return true end
            pcall(function() seat:Sit(Humanoid) end)
            RunService.Heartbeat:Wait()
        end

        task.wait(0.05)
    end

    return M.isSeatedOn(boat)
end

function M.findFrozenWatcher()

    local function isWatcher(m)
        return m and m:IsA("Model") and m.Name:lower():find("frozen watcher") and M.getModelPosition(m) ~= nil
    end

    local npcs = Workspace:FindFirstChild("NPCs")
    if npcs then
        for _, c in ipairs(npcs:GetChildren()) do
            if isWatcher(c) then return c end
        end
    end

    local map = Workspace:FindFirstChild("Map")
    local frozen = map and (map:FindFirstChild("FrozenDimension") or map:FindFirstChild("Frozen Dimension"))
    if frozen then
        for _, c in ipairs(frozen:GetDescendants()) do
            if isWatcher(c) then return c end
        end
    end

    return nil
end

function M.seaLoopStep()
    if not (S.autoSeaFarm or S.autoLeviathan) then return end
    if not Humanoid or not HumanoidRootPart then return end
    local boat = M.getMyBoat()
    if not boat then
        if os.clock() - S.lastSeaSeaWarn > 8 then
            M.notify("Sea", "No owned boat found - spawn one first", 3)
            S.lastSeaSeaWarn = os.clock()
        end

        return
    end

    M.syncBoatEngine(boat)
    if S.autoLeviathan then
        local watcher = M.findFrozenWatcher()
        if watcher then
            if S.autoAttack then M.setAutoAttack(false) end
            pcall(function() Humanoid.Sit = false end)
            local t = M.moveTo(watcher:GetPivot().Position + Vector3.new(0, 4, 0))
            if t then t.Completed:Wait() end
            pcall(function() CommF_:InvokeServer("FrozenWatcher", "Very Well") end)
            task.wait(0.5)
            return
        end

        if not M.isSeatedOn(boat) then
            M.trySitOnBoat(boat)
            return
        end

        if S.autoAttack then M.setAutoAttack(false) end
        M.driveSeaBoat(boat, nil)
        return
    end

    if os.clock() - S.lastSeaEnemyScan >= 0.5 then
        S.cachedSeaTarget = M.findSeaEnemy()
        S.lastSeaEnemyScan = os.clock()
    end

    local target = S.cachedSeaTarget
    if target then
        local hum = target:FindFirstChildOfClass("Humanoid")
        if not target.Parent or not hum or hum.Health <= 0 then
            S.cachedSeaTarget = nil
            target = nil
        end
    end

    if target then
        if M.isSeatedOn(boat) then pcall(function() Humanoid.Sit = false end) end
        if not S.autoAttack then M.setAutoAttack(true) end
        M.equipWeapon()
        local troot = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
        local targetPos = (troot and troot.Position) or M.getModelPosition(target)
        if targetPos then
            local dist = (HumanoidRootPart.Position - targetPos).Magnitude
            if dist > S.seaAttackDistance then
                local goal = targetPos + Vector3.new(0, 18, 0)
                local needMove = not M.isFarmMoving()
                if S.seaTweenGoal and (S.seaTweenGoal - goal).Magnitude > 20 then needMove = true end
                if needMove then
                    S.seaTweenGoal = goal
                    M.moveTo(goal)
                end
            else
                M.cancelFarmMove()
                S.seaTweenGoal = nil
                if os.clock() - S.lastSwitch >= S.snapTime then
                    S.snapIndex  = (S.snapIndex % #S.seaSnapOffsets) + 1
                    S.lastSwitch = os.clock()
                end

                local snap = S.seaSnapOffsets[S.snapIndex]
                HumanoidRootPart.CFrame = CFrame.new(
                    HumanoidRootPart.Position:Lerp(targetPos + snap, 0.4)
                )
            end
        end

        return
    end

    S.seaTweenGoal = nil
    if S.autoAttack then M.setAutoAttack(false) end
    if not M.isSeatedOn(boat) then
        M.trySitOnBoat(boat)
        return
    end

    M.driveSeaBoat(boat, nil)
end

task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(0.25)
        if S.autoSeaFarm or S.autoLeviathan then
            local ok, err = pcall(M.seaLoopStep)
            if not ok then
                warn("[Nexus Hub] Sea loop error: " .. tostring(err))
            end
        end
    end
end)

local Lighting = game:GetService("Lighting")
M.AddConnection(RunService.Heartbeat:Connect(function()
    if S.removeFogEnabled then
        if not S.fogDefaults then
            S.fogDefaults = {
                start = Lighting.FogStart,
                fin = Lighting.FogEnd,
                color = Lighting.FogColor,
            }
        end

        if Lighting.FogEnd ~= 9e9 then Lighting.FogEnd = 9e9 end
        if Lighting.FogStart ~= 9e9 then Lighting.FogStart = 9e9 end
        for _, v in ipairs(Lighting:GetDescendants()) do
            if v:IsA("Atmosphere") then
                if v.Density > 0 then v.Density = 0 end
                if v.Haze    > 0 then v.Haze    = 0 end
                if v.Offset  > 0 then v.Offset  = 0 end
            elseif v:IsA("Clouds") then
                if v.Cover > 0 then v.Cover = 0 end
                if v.Density > 0 then v.Density = 0 end
            end
        end
    elseif S.fogDefaults then
        pcall(function()
            Lighting.FogStart = S.fogDefaults.start
            Lighting.FogEnd   = S.fogDefaults.fin
            Lighting.FogColor = S.fogDefaults.color
        end)

        S.fogDefaults = nil
    end

    if S.removeDarknessEnabled and M.getSeaDangerLevel() >= 6 then
        for _, v in ipairs(Lighting:GetDescendants()) do
            if v:IsA("ColorCorrectionEffect") then
                if v.Brightness < 0 then v.Brightness = 0 end
                if v.Contrast  < 0 then v.Contrast  = 0 end
            end
        end
    end

    if S.fruitEspEnabled and os.clock() - S.lastFruitEspAt >= 0.5 then
        S.lastFruitEspAt = os.clock()
        pcall(M.updateFruitEsp)
    end
end))

M.AddConnection(UserInputService.InputBegan:Connect(function(input, gp)
    if not gp then
        if input.KeyCode == Enum.KeyCode.Space then
            S.holding = true
            task.spawn(function()
                while S.holding and S.infJumpEnabled and Player.Character do
                    local hum = Player.Character:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end

                    task.wait(0.55)
                end
            end)
        elseif input.KeyCode == S.UIHotkey then
            local sg = game:GetService("CoreGui"):FindFirstChild("NexusHub") or Player.PlayerGui:FindFirstChild("NexusHub")
            if sg then sg.Enabled = not sg.Enabled end
        end
    end
end))

M.AddConnection(UserInputService.InputEnded:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.Space then S.holding = false end
end))

do
    local old = Character:FindFirstChild("NexusHubHighlight")
    if old then old:Destroy() end
    local hl = Instance.new("Highlight")
    hl.Name = "NexusHubHighlight"
    hl.Parent    = Character
    hl.FillColor = Color3.fromRGB(130, 80, 220)
    hl.DepthMode = Enum.HighlightDepthMode.Occluded
end

function M.getServers(placeId)
    local servers, cursor = {}, nil
    repeat
        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?limit=100%s"):format(
            placeId, cursor and "&cursor=" .. HttpService:UrlEncode(cursor) or "")
        local ok, res = pcall(function() return HttpService:GetAsync(url) end)
        if not ok then break end
        local data = HttpService:JSONDecode(res)
        for _, s in ipairs(data.data or {}) do
            if s.id ~= game.JobId and s.playing < s.maxPlayers then
                table.insert(servers, s.id)
            end
        end

        cursor = data.nextPageCursor
    until not cursor

    return servers
end

-- ========================== NEW UI COLORS & STYLES ==========================
local C = {
    bg        = Color3.fromRGB(9, 12, 18),
    panel     = Color3.fromRGB(14, 19, 28),
    card      = Color3.fromRGB(22, 28, 42),
    border    = Color3.fromRGB(50, 40, 80),
    accent    = Color3.fromRGB(160, 100, 255),   -- purple accent
    accent2   = Color3.fromRGB(100, 200, 255),   -- cyan accent
    text      = Color3.fromRGB(220, 230, 245),
    subtext   = Color3.fromRGB(140, 160, 185),
}

function M.make(class, props)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    return obj
end

function M.corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

function M.stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or C.border
    s.Thickness = thickness or 1
    s.Parent = parent
    return s
end

function M.nextScrollOrder(scroll)
    local maxOrder = 0
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("GuiObject") and child.LayoutOrder > maxOrder then
            maxOrder = child.LayoutOrder
        end
    end
    return maxOrder + 1
end

function M.addTextBox(tab, labelText, default, onChange)
    if tab.AddTextBox then
        return tab:AddTextBox(labelText, default, onChange)
    end

    local scroll = tab.scroll
    local card = M.make("Frame", {
        Parent = scroll,
        Size = UDim2.new(1, 0, 0, 68),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
        LayoutOrder = M.nextScrollOrder(scroll),
    })
    M.corner(card, 8)
    M.stroke(card, C.border, 1)
    M.make("TextLabel", {
        Parent = card,
        Text = labelText,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextColor3 = C.text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -28, 0, 28),
        Position = UDim2.new(0, 14, 0, 4),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local inputFrame = M.make("Frame", {
        Parent = card,
        Size = UDim2.new(1, -28, 0, 30),
        Position = UDim2.new(0, 14, 0, 32),
        BackgroundColor3 = C.bg,
        BorderSizePixel = 0,
    })
    M.corner(inputFrame, 6)
    M.stroke(inputFrame, C.border, 1)
    local textBox = M.make("TextBox", {
        Parent = inputFrame,
        Text = default or "",
        PlaceholderText = "Enter dev key...",
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextColor3 = C.text,
        PlaceholderColor3 = C.subtext,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -10, 1, 0),
        Position = UDim2.new(0, 5, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ClearTextOnFocus = false,
    })
    textBox:GetPropertyChangedSignal("Text"):Connect(function()
        if onChange then onChange(textBox.Text) end
    end)

    return {
        Get = function() return textBox.Text end,
        Set = function(_, val)
            textBox.Text = tostring(val)
            if onChange then onChange(textBox.Text) end
        end,
    }
end

function M.newestCard(tab)
    local best, bestOrder
    for _, child in ipairs(tab.scroll:GetChildren()) do
        if child:IsA("Frame") and (not bestOrder or child.LayoutOrder > bestOrder) then
            best, bestOrder = child, child.LayoutOrder
        end
    end
    return best
end

function M.makeSection(parent, title)
    local sec = M.make("Frame", {
        Parent          = parent,
        Size            = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
    })
    local lbl = M.make("TextLabel", {
        Parent               = sec,
        Text                 = title:upper(),
        TextSize             = 10,
        Font                 = Enum.Font.GothamBold,
        TextColor3           = C.accent2,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 1, 0),
        TextXAlignment       = Enum.TextXAlignment.Left,
    })
    M.make("Frame", {
        Parent          = sec,
        Size            = UDim2.new(1, 0, 0, 1),
        Position        = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    })
    return sec
end
-- GLOBAL
local version = "1.1.0"
local loaderSeconds = 3

-- ========== AUTO HAKI + INSTINTO (MÁXIMA PRIORIDADE) ==========
local function AutoHaki()
    local player = game.Players.LocalPlayer
    if not player then return end

    -- Espera o personagem carregar
    repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

    -- Loop contínuo para manter Buso ativo
    task.spawn(function()
        while true do
            task.wait(2)
            pcall(function()
                local char = player.Character
                if not char then return end
                -- Verifica se o jogador já tem Buso ativo
                if not char:FindFirstChild("HasBuso") then
                    local args = { [1] = "Buso" }
                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                end
            end)
        end
    end)
end
-- Executa imediatamente
AutoHaki()


local userInput = game:GetService("UserInputService")
local isMobile = userInput.TouchEnabled and not userInput.MouseEnabled

-- ===== Função global para coletar NPCs (usada em várias abas) =====
local function GetAllNPCs()
    local npcs = {}
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        for _, child in pairs(enemies:GetChildren()) do
            if child:FindFirstChild("Humanoid") and child:FindFirstChild("HumanoidRootPart") then
                table.insert(npcs, child)
            end
        end
    end
    for _, child in pairs(workspace:GetChildren()) do
        if child:FindFirstChild("Humanoid") and child:FindFirstChild("HumanoidRootPart") then
            local found = false
            for _, npc in pairs(npcs) do
                if npc == child then found = true break end
            end
            if not found then table.insert(npcs, child) end
        end
    end
    return npcs
end

-- ===== Tabela global para armazenar conexões e estados =====
local _GLOBAL_CONNECTIONS = {
    threads = {},
    connections = {},
    instances = {},
    states = {}
}

-- #region ______ CINEMATIC LOADER – RGB RAINBOW PREMIUM ______ 
    local function ShowCinematicLoader(version)
        local player = game.Players.LocalPlayer
        local gui = Instance.new("ScreenGui")
        gui.Name = "NexusCinematicLoader"
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.ResetOnSpawn = false
        gui.Parent = player.PlayerGui
        gui.IgnoreGuiInset = true

        local userInput = game:GetService("UserInputService")
        local platform = userInput:GetPlatform()
        local screenSize = player:GetMouse().ViewSizeX
        local scale = math.min(1, screenSize / 1920) -- referência 1920x1080
        if isMobile then
            scale = math.min(scale, 0.7) -- limita em mobile para não ficar muito grande
        end

        -- Blur effect
        local blurEffect = Instance.new("BlurEffect", game:GetService("Lighting"))
        blurEffect.Name = "NexusLoaderBlur"
        blurEffect.Size = 0

        -- Container principal
        local container = Instance.new("Frame", gui)
        container.Size = UDim2.new(1, 0, 1, 0)
        container.BackgroundTransparency = 1
        container.ZIndex = 100
        container.ClipsDescendants = true

        -- Texto principal
        local title = Instance.new("TextLabel", container)
        title.Size = UDim2.new(1, 0, 0, 120 * scale)
        title.Position = UDim2.new(0, 0, 0.5, 120 * scale)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBlack
        title.TextSize = 130 * scale
        title.Text = "N E X U S  C O M P L E X"
        title.TextStrokeTransparency = 0.2
        title.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
        title.TextTransparency = 1
        title.ZIndex = 52
        title.TextXAlignment = Enum.TextXAlignment.Center
        title.TextYAlignment = Enum.TextYAlignment.Bottom

        -- Gradiente RGB
        local gradient = Instance.new("UIGradient", title)
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        })
        gradient.Rotation = 0

        -- Glow do texto
        local textGlow = Instance.new("UIStroke", title)
        textGlow.Color = Color3.fromRGB(99, 202, 183)
        textGlow.Thickness = 4 * scale
        textGlow.Transparency = 1

        -- Subtítulo
        local subText = Instance.new("TextLabel", container)
        subText.Size = UDim2.new(1, 0, 0, 80 * scale)
        subText.Position = UDim2.new(0, 0, 0.5, 180 * scale)
        subText.BackgroundTransparency = 1
        subText.Font = Enum.Font.GothamBlack
        subText.TextSize = 90 * scale
        subText.Text = "V" .. version
        subText.TextColor3 = Color3.fromRGB(255, 255, 255)
        subText.TextTransparency = 1
        subText.ZIndex = 53
        subText.TextXAlignment = Enum.TextXAlignment.Center
        subText.TextYAlignment = Enum.TextYAlignment.Top

        -- Gradiente da versão
        local subGradient = Instance.new("UIGradient", subText)
        subGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        })
        subGradient.Rotation = 0

        -- Glow da versão
        local subGlow = Instance.new("UIStroke", subText)
        subGlow.Color = Color3.fromRGB(131, 181, 255)
        subGlow.Thickness = 3 * scale
        subGlow.Transparency = 1

        -- Linha de brilho central
        local glowLine = Instance.new("Frame", container)
        glowLine.Size = UDim2.new(0, 0, 0, 3 * scale)
        glowLine.Position = UDim2.new(0.5, 0, 0.5, 0)
        glowLine.AnchorPoint = Vector2.new(0.5, 0.5)
        glowLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        glowLine.BackgroundTransparency = 1
        glowLine.ZIndex = 51
        Instance.new("UICorner", glowLine).CornerRadius = UDim.new(1, 0)
        local lineGlow = Instance.new("UIStroke", glowLine)
        lineGlow.Color = Color3.fromRGB(131, 181, 255)
        lineGlow.Thickness = 4 * scale
        lineGlow.Transparency = 1

        -- ANIMAÇÕES
        local tweenService = game:GetService("TweenService")

        tweenService:Create(blurEffect, TweenInfo.new(1.0, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Size = 40 }):Play()

        local titleStartPos = UDim2.new(0, 0, 0.5, 180 * scale)
        local titleEndPos = UDim2.new(0, 0, 0.5, -60 * scale)
        title.Position = titleStartPos
        tweenService:Create(title, TweenInfo.new(1.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Position = titleEndPos, TextTransparency = 0 }):Play()
        tweenService:Create(textGlow, TweenInfo.new(1.0, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Transparency = 0.15 }):Play()

        task.wait(2)
        local subStartPos = UDim2.new(0, 0, 0.5, 250 * scale)
        local subCollisionPos = UDim2.new(0, 0, 0.5, -10 * scale)
        subText.Position = subStartPos
        subText.TextSize = 110 * scale
        local tweenSub = tweenService:Create(subText, TweenInfo.new(1.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Position = subCollisionPos, TextTransparency = 0 })
        tweenSub:Play()
        tweenService:Create(subGlow, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Transparency = 0.2 }):Play()

        local rotateGradient = true
        task.spawn(function()
            local rotation = 1
            while rotateGradient and gui.Parent do
                rotation = (rotation + 1.5) % 360
                gradient.Rotation = rotation
                subGradient.Rotation = rotation
                task.wait(0.010)
            end
        end)

        local breatheUp = true
        task.spawn(function()
            while rotateGradient and gui.Parent do
                local thickness = breatheUp and (8 * scale) or (4 * scale)
                tweenService:Create(textGlow, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Thickness = thickness }):Play()
                breatheUp = not breatheUp
                task.wait(0.8)
            end
        end)

        task.wait(loaderSeconds)

        rotateGradient = false
        tweenService:Create(title, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
        tweenService:Create(textGlow, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
        tweenService:Create(subText, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
        tweenService:Create(subGlow, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
        tweenService:Create(glowLine, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 0, 1), BackgroundTransparency = 1 }):Play()
        tweenService:Create(lineGlow, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
        tweenService:Create(blurEffect, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = 0 }):Play()

        task.wait(2)
        pcall(function() blurEffect:Destroy() end)
        gui:Destroy()
    end

    ShowCinematicLoader(version)
-- #endregion

-- #region ______ UI Factory (Adaptado Mobile) ______ 
    local function CreateUI(version)
        local tweenService = game:GetService("TweenService")
        local userInput = game:GetService("UserInputService")
        local runService = game:GetService("RunService")
        local player = game.Players.LocalPlayer

        -- ======= CONSTANTES DE ESTILO (adaptadas) =======
        local COR_FUNDO = Color3.fromRGB(14, 19, 28)
        local COR_FUNDO_CARTAO = Color3.fromRGB(14, 19, 28)
        local COR_TEXTO = Color3.fromRGB(220, 230, 245)
        local COR_DESATIVADO = Color3.fromRGB(140, 160, 185)
        local COR_DESTAQUE = Color3.fromRGB(99, 202, 183)
        local COR_SEGUNDARIA = Color3.fromRGB(35, 48, 72)
        local COR_BOTAO = Color3.fromRGB(20, 27, 40)
        local FONTE_TITULO = isMobile and Enum.Font.GothamBold or Enum.Font.GothamBold
        local FONTE_CORPO = isMobile and Enum.Font.GothamMedium or Enum.Font.GothamMedium
        local TAMANHO_TITULO = isMobile and 11 or 13
        local TAMANHO_TEXTO = isMobile and 10 or 12
        local ARREDONDAMENTO = UDim.new(0, isMobile and 6 or 10)
        local SIDEBAR_WIDTH = isMobile and 280 or 360
        local CARD_HEIGHT = isMobile and 40 or 50
        local BUTTON_HEIGHT = isMobile and 38 or 45
        local SLIDER_HEIGHT = isMobile and 50 or 60

        -- ======= GUI BASE =======
        local gui = Instance.new("ScreenGui")
        gui.Name = "NexusHubUI"
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.ResetOnSpawn = false
        gui.Parent = player.PlayerGui

        -- Container de notificações
        local notificationContainer = Instance.new("Frame", gui)
        notificationContainer.AnchorPoint = Vector2.new(0.5, 0)
        notificationContainer.Size = UDim2.new(0, 300, 1, -20)
        notificationContainer.Position = UDim2.new(0.5, 0, 0, 10)
        notificationContainer.BackgroundTransparency = 1
        notificationContainer.ZIndex = 100
        Instance.new("UIListLayout", notificationContainer).Padding = UDim.new(0, 8)

        local function SendNotification(text, color)
            local notif = Instance.new("Frame")
            notif.Size = UDim2.new(1, 0, 0, 45)
            notif.BackgroundColor3 = COR_FUNDO
            notif.BackgroundTransparency = 0.15
            notif.BorderSizePixel = 0
            notif.ZIndex = 101
            Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 8)
            
            local stroke = Instance.new("UIStroke", notif)
            stroke.Color = color or COR_DESTAQUE
            stroke.Thickness = 1.5
            stroke.Transparency = 1
            
            local label = Instance.new("TextLabel", notif)
            label.Text = text
            label.Font = FONTE_CORPO
            label.TextSize = isMobile and 11 or 13
            label.TextColor3 = COR_TEXTO
            label.BackgroundTransparency = 1
            label.Size = UDim2.new(1, -16, 1, 0)
            label.Position = UDim2.new(0, 8, 0, 0)
            label.TextWrapped = true
            label.TextTransparency = 1
            label.TextXAlignment = Enum.TextXAlignment.Left

            notif.Parent = notificationContainer
            tweenService:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency = 0.15}):Play()
            tweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 0}):Play()
            tweenService:Create(label, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
            task.wait(3.5)
            tweenService:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
            tweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
            tweenService:Create(label, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            task.wait(0.3)
            notif:Destroy()
        end

        -- ======= LÓGICA DE ARRASTE =======
        local Dragging = false
        local DragStart = nil
        local StartPos = nil
        local dragObject = nil

        local function MakeDraggable(dragArea, object)
            dragArea.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    Dragging = true
                    DragStart = input.Position
                    StartPos = object.Position
                    dragObject = object
                end
            end)

            userInput.InputChanged:Connect(function(input)
                if Dragging and dragObject == object and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local delta = input.Position - DragStart
                    local newPos = UDim2.new(
                        StartPos.X.Scale,
                        StartPos.X.Offset + delta.X,
                        StartPos.Y.Scale,
                        StartPos.Y.Offset + delta.Y
                    )
                    tweenService:Create(object, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = newPos}):Play()
                end
            end)

            userInput.InputEnded:Connect(function(input)
                if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and dragObject == object then
                    Dragging = false
                    dragObject = nil
                end
            end)
        end

        -- ======= SIDEBAR =======
        local sidebar = Instance.new("Frame")
        sidebar.Visible = false
        sidebar.AnchorPoint = Vector2.new(1, 0)
        sidebar.BackgroundColor3 = Color3.fromRGB(9, 12, 18)
        sidebar.BackgroundTransparency = 0.25
        sidebar.BorderSizePixel = 0
        sidebar.Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0)
        sidebar.Position = UDim2.new(1, 0, 0, 0)
        sidebar.ZIndex = 10
        sidebar.Parent = gui
        Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 16)
        local sidebarStroke = Instance.new("UIStroke", sidebar)
        sidebarStroke.Color = COR_SEGUNDARIA
        sidebarStroke.Thickness = 1.5
        sidebar.Active = true

        local tabBarContainer = Instance.new("ScrollingFrame", sidebar)
        tabBarContainer.BackgroundTransparency = 1
        tabBarContainer.BorderSizePixel = 0
        tabBarContainer.Size = UDim2.new(0, 45, 1, -40)
        tabBarContainer.Position = UDim2.new(0, -55, 0, 20)
        tabBarContainer.ZIndex = 11
        tabBarContainer.ScrollBarThickness = 4
        tabBarContainer.ScrollBarImageColor3 = COR_SEGUNDARIA
        tabBarContainer.CanvasSize = UDim2.new(0, 0, 0, 0)  -- será atualizado
        tabBarContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y  -- ajusta automaticamente
        local tabListLayout = Instance.new("UIListLayout", tabBarContainer)
        tabListLayout.FillDirection = Enum.FillDirection.Vertical
        tabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tabListLayout.Padding = UDim.new(0, 8)

        local tabContainers = {}
        local tabButtons = {}
        local activeTab = nil

        local function SwitchTab(tabIndex)
            for i, container in pairs(tabContainers) do
                container.Visible = (i == tabIndex)
            end
            for i, btn in pairs(tabButtons) do
                tweenService:Create(btn, TweenInfo.new(0.2), {
                    BackgroundColor3 = (i == tabIndex) and COR_SEGUNDARIA or COR_FUNDO
                }):Play()
            end
            activeTab = tabIndex
        end

        local closeBtn = Instance.new("TextButton", sidebar)
        closeBtn.Text = "›"
        closeBtn.Font = FONTE_TITULO
        closeBtn.TextSize = isMobile and 16 or 18
        closeBtn.TextColor3 = COR_DESATIVADO
        closeBtn.BackgroundColor3 = COR_BOTAO
        closeBtn.BackgroundTransparency = 0.2
        closeBtn.Size = UDim2.new(0, 30, 0, 30)
        closeBtn.Position = UDim2.new(1, -45, 0, 20)
        closeBtn.AutoButtonColor = false
        closeBtn.ZIndex = 11
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)
        local closeStroke = Instance.new("UIStroke", closeBtn)
        closeStroke.Color = COR_SEGUNDARIA
        closeStroke.Thickness = 1

        -- ======= VARIÁVEIS E FUNÇÕES DE ABRIR/FECHAR SIDEBAR =======
        local isOpen = false
        local compactBtn = nil
        local openSidebarBtn = nil
        local compactStroke = nil
        local compactBtnPosition = nil

        local function OpenSidebar()
            if isOpen then return end
            isOpen = true
            if compactBtn then
                compactBtnPosition = compactBtn.Position
                compactBtn.Visible = false
            end
            sidebar.Visible = true
            sidebar:TweenPosition(UDim2.new(1, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Exponential, 0.4, true)
        end

        local function CloseSidebar()
            if not isOpen then return end
            isOpen = false
            sidebar:TweenPosition(UDim2.new(1, 420, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Exponential, 0.35, true)
            task.delay(0.1, function()
                if not isOpen then
                    sidebar.Visible = false
                    if compactBtn then
                        if compactBtnPosition then
                            compactBtn.Position = compactBtnPosition
                        end
                        compactBtn.Visible = true
                    end
                end
            end)
        end

        closeBtn.MouseEnter:Connect(function() 
            tweenService:Create(closeStroke, TweenInfo.new(0.15), {Color = COR_DESATIVADO}):Play()
        end)
        closeBtn.MouseLeave:Connect(function() 
            tweenService:Create(closeStroke, TweenInfo.new(0.15), {Color = COR_SEGUNDARIA}):Play()
        end)
        closeBtn.MouseButton1Click:Connect(function()
            CloseSidebar()
        end)

        -- ======= COMPACT BUTTON (tamanho adaptado) =======
        compactBtn = Instance.new("Frame", gui)
        compactBtn.Visible = true
        compactBtn.Name = "CompactButton"
        compactBtn.BackgroundColor3 = COR_FUNDO
        compactBtn.BackgroundTransparency = 0.2
        compactBtn.Size = UDim2.new(0, isMobile and 44 or 52, 0, isMobile and 44 or 52)
        compactBtn.AnchorPoint = Vector2.new(0.5, 0)
        compactBtn.Position = UDim2.new(0.5, 0, 0, isMobile and 10 or 20)
        compactBtn.ZIndex = 20
        compactBtn.Active = true
        local corner = Instance.new("UICorner", compactBtn)
        corner.CornerRadius = UDim.new(1, 0)

        compactStroke = Instance.new("UIStroke", compactBtn)
        compactStroke.Color = Color3.fromRGB(99, 202, 183)
        compactStroke.Thickness = 2.5
        compactStroke.Transparency = 0.2

        openSidebarBtn = Instance.new("TextButton", compactBtn)
        openSidebarBtn.Size = UDim2.new(1, 0, 1, 0)
        openSidebarBtn.BackgroundTransparency = 1
        openSidebarBtn.Text = "NX"
        openSidebarBtn.Font = FONTE_TITULO
        openSidebarBtn.TextSize = isMobile and 16 or 20
        openSidebarBtn.TextColor3 = COR_TEXTO
        openSidebarBtn.ZIndex = 21
        openSidebarBtn.TextXAlignment = Enum.TextXAlignment.Center
        openSidebarBtn.TextYAlignment = Enum.TextYAlignment.Center
        openSidebarBtn.Active = true

        -- Gradiente RGB
        local btnGradient = Instance.new("UIGradient", openSidebarBtn)
        btnGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        })
        btnGradient.Rotation = 0

        local borderGradient = Instance.new("UIGradient", compactStroke)
        borderGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        })
        borderGradient.Rotation = 0

        task.spawn(function()
            local rotation = 0
            while compactBtn and compactBtn.Parent do
                rotation = (rotation + 1.2) % 360
                btnGradient.Rotation = rotation
                borderGradient.Rotation = rotation
                task.wait(0.04)
            end
        end)

        -- ======= DRAG SIMPLES =======
        local isDraggingBtn = false
        local dragStartBtnPos = nil
        local dragStartMousePos = nil

        local function UpdateDrag(input)
            if not dragStartMousePos then return end
            local delta = input.Position - dragStartMousePos
            local newPos = UDim2.new(
                dragStartBtnPos.X.Scale,
                dragStartBtnPos.X.Offset + delta.X,
                dragStartBtnPos.Y.Scale,
                dragStartBtnPos.Y.Offset + delta.Y
            )
            compactBtn.Position = newPos
            compactBtnPosition = newPos
        end

        openSidebarBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                isDraggingBtn = true
                dragStartMousePos = input.Position
                dragStartBtnPos = compactBtn.Position
            end
        end)

        userInput.InputChanged:Connect(function(input)
            if isDraggingBtn and input.UserInputType == Enum.UserInputType.MouseMovement then
                UpdateDrag(input)
            end
        end)

        userInput.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and isDraggingBtn then
                isDraggingBtn = false
                dragStartMousePos = nil
                dragStartBtnPos = nil
            end
        end)

        openSidebarBtn.MouseButton1Click:Connect(function()
            if compactBtn and compactBtn.Visible then
                OpenSidebar()
            end
        end)

        -- ======= FUNÇÕES DE CRIAÇÃO DE ELEMENTOS (com alturas adaptadas) =======
        local function CreateToggle(parent, text, default, callback)
            local card = Instance.new("Frame", parent)
            card.BackgroundColor3 = COR_FUNDO_CARTAO
            card.BackgroundTransparency = 0.3
            card.Size = UDim2.new(1, 0, 0, CARD_HEIGHT)
            card.ZIndex = 12
            Instance.new("UICorner", card).CornerRadius = ARREDONDAMENTO
            local stroke = Instance.new("UIStroke", card)
            stroke.Color = COR_SEGUNDARIA
            stroke.Thickness = 1

            local btn = Instance.new("TextButton", card)
            btn.Text = " " .. text  -- sem "ON"/"OFF"
            btn.Font = FONTE_TITULO
            btn.TextSize = TAMANHO_TITULO
            btn.TextColor3 = default and COR_TEXTO or COR_DESATIVADO
            btn.BackgroundColor3 = default and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(180, 50, 50) -- verde / vermelho
            btn.BackgroundTransparency = default and 0.3 or 0.3
            btn.Size = UDim2.new(1, 0, 1, 0)
            btn.ZIndex = 13
            Instance.new("UICorner", btn).CornerRadius = ARREDONDAMENTO
            local btnStroke = Instance.new("UIStroke", btn)
            btnStroke.Color = default and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(220, 80, 80)
            btnStroke.Thickness = 1

            local state = default or false
            btn.MouseButton1Click:Connect(function()
                state = not state
                btn.Text = " " .. text  -- mantém apenas a label
                tweenService:Create(btn, TweenInfo.new(0.2), {
                    TextColor3 = state and COR_TEXTO or COR_DESATIVADO,
                    BackgroundColor3 = state and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(180, 50, 50),
                    BackgroundTransparency = 0.3,
                }):Play()
                tweenService:Create(btnStroke, TweenInfo.new(0.2), {
                    Color = state and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(220, 80, 80)
                }):Play()
                if callback then callback(state) end
            end)
            return card
        end

        local function CreateButton(parent, text, callback, color)
            local btn = Instance.new("TextButton", parent)
            btn.Text = text
            btn.Font = FONTE_TITULO
            btn.TextSize = TAMANHO_TITULO
            btn.TextColor3 = color or COR_TEXTO
            btn.BackgroundColor3 = COR_BOTAO
            btn.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
            btn.AutoButtonColor = false
            btn.ZIndex = 12
            Instance.new("UICorner", btn).CornerRadius = ARREDONDAMENTO
            local stroke = Instance.new("UIStroke", btn)
            stroke.Color = COR_SEGUNDARIA
            stroke.Thickness = 1
            btn.MouseEnter:Connect(function() tweenService:Create(stroke, TweenInfo.new(0.15), {Color = color or COR_DESTAQUE}):Play() end)
            btn.MouseLeave:Connect(function() tweenService:Create(stroke, TweenInfo.new(0.15), {Color = COR_SEGUNDARIA}):Play() end)
            btn.MouseButton1Click:Connect(callback)
            return btn
        end

        local function CreateDropdown(parent, text, options, default, callback)
            local container = Instance.new("Frame", parent)
            container.BackgroundColor3 = COR_FUNDO_CARTAO
            container.BackgroundTransparency = 0.3
            container.Size = UDim2.new(1, 0, 0, CARD_HEIGHT)
            container.ZIndex = 12
            container.ClipsDescendants = true
            Instance.new("UICorner", container).CornerRadius = ARREDONDAMENTO
            local stroke = Instance.new("UIStroke", container)
            stroke.Color = COR_SEGUNDARIA
            stroke.Thickness = 1

            local headerBtn = Instance.new("TextButton", container)
            headerBtn.Size = UDim2.new(1, 0, 0, CARD_HEIGHT)
            headerBtn.BackgroundTransparency = 1
            headerBtn.Text = ""
            headerBtn.ZIndex = 13

            local titleLbl = Instance.new("TextLabel", headerBtn)
            titleLbl.Text = " " .. text .. ": " .. (default or options[1])
            titleLbl.Font = FONTE_TITULO
            titleLbl.TextSize = TAMANHO_TITULO
            titleLbl.TextColor3 = COR_TEXTO
            titleLbl.BackgroundTransparency = 1
            titleLbl.Size = UDim2.new(1, -30, 1, 0)
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left

            local iconLbl = Instance.new("TextLabel", headerBtn)
            iconLbl.Text = "▼"
            iconLbl.Font = FONTE_TITULO
            iconLbl.TextSize = 14
            iconLbl.TextColor3 = COR_DESATIVADO
            iconLbl.BackgroundTransparency = 1
            iconLbl.Size = UDim2.new(0, 30, 1, 0)
            iconLbl.Position = UDim2.new(1, -30, 0, 0)

            local listFrame = Instance.new("ScrollingFrame", container)
            listFrame.Size = UDim2.new(1, 0, 0, 0)
            listFrame.Position = UDim2.new(0, 0, 0, CARD_HEIGHT)
            listFrame.BackgroundColor3 = COR_BOTAO
            listFrame.BorderSizePixel = 0
            listFrame.ScrollBarThickness = 2
            listFrame.ZIndex = 14
            listFrame.Visible = false
            listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
            listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
            Instance.new("UICorner", listFrame).CornerRadius = ARREDONDAMENTO

            local listLayout = Instance.new("UIListLayout", listFrame)
            listLayout.SortOrder = Enum.SortOrder.LayoutOrder
            listLayout.Padding = UDim.new(0, 2)

            local isOpen = false

            local function populateList(opts)
                for _, child in ipairs(listFrame:GetChildren()) do
                    if child:IsA("TextButton") then
                        child:Destroy()
                    end
                end
                
                for _, opt in ipairs(opts) do
                    local optBtn = Instance.new("TextButton", listFrame)
                    optBtn.Size = UDim2.new(1, 0, 0, 35)
                    optBtn.BackgroundColor3 = COR_BOTAO
                    optBtn.Text = "  " .. opt
                    optBtn.Font = FONTE_CORPO
                    optBtn.TextSize = TAMANHO_TEXTO
                    optBtn.TextColor3 = COR_DESATIVADO
                    optBtn.TextXAlignment = Enum.TextXAlignment.Left
                    optBtn.ZIndex = 15
                    optBtn.BorderSizePixel = 0

                    optBtn.MouseEnter:Connect(function() 
                        optBtn.TextColor3 = COR_TEXTO 
                    end)
                    optBtn.MouseLeave:Connect(function() 
                        optBtn.TextColor3 = COR_DESATIVADO 
                    end)
                    optBtn.MouseButton1Click:Connect(function()
                        titleLbl.Text = " " .. text .. ": " .. opt
                        isOpen = false
                        tweenService:Create(iconLbl, TweenInfo.new(0.2), {Rotation = 0}):Play()
                        tweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, CARD_HEIGHT)}):Play()
                        listFrame.Visible = false
                        if callback then callback(opt) end
                    end)
                end
            end

            populateList(options)

            headerBtn.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                if isOpen then
                    listFrame.Visible = true
                    tweenService:Create(iconLbl, TweenInfo.new(0.2), {Rotation = 180}):Play()
                    local targetHeight = CARD_HEIGHT + math.min(#options * 35, 140)
                    tweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
                    tweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, math.min(#options * 35, 140))}):Play()
                else
                    tweenService:Create(iconLbl, TweenInfo.new(0.2), {Rotation = 0}):Play()
                    tweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, CARD_HEIGHT)}):Play()
                    local tw = tweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 0)})
                    tw:Play()
                    tw.Completed:Connect(function()
                        listFrame.Visible = false
                    end)
                end
            end)

            return container
        end

        local function CreateRadioGroup(parent, text, options, default, callback)
            local container = Instance.new("Frame", parent)
            container.BackgroundColor3 = COR_FUNDO_CARTAO
            container.BackgroundTransparency = 0.3
            container.Size = UDim2.new(1, 0, 0, isMobile and 55 or 65)
            container.ZIndex = 12
            Instance.new("UICorner", container).CornerRadius = ARREDONDAMENTO
            local stroke = Instance.new("UIStroke", container)
            stroke.Color = COR_SEGUNDARIA
            stroke.Thickness = 1

            local titleLbl = Instance.new("TextLabel", container)
            titleLbl.Text = " " .. text
            titleLbl.Font = FONTE_TITULO
            titleLbl.TextSize = TAMANHO_TITULO
            titleLbl.TextColor3 = COR_TEXTO
            titleLbl.BackgroundTransparency = 1
            titleLbl.Size = UDim2.new(1, -20, 0, isMobile and 20 or 25)
            titleLbl.Position = UDim2.new(0, 10, 0, 2)
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left

            local btnContainer = Instance.new("Frame", container)
            btnContainer.BackgroundTransparency = 1
            btnContainer.Size = UDim2.new(1, -20, 0, isMobile and 25 or 30)
            btnContainer.Position = UDim2.new(0, 10, 0, isMobile and 22 or 27)
            local layout = Instance.new("UIListLayout", btnContainer)
            layout.FillDirection = Enum.FillDirection.Horizontal
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Padding = UDim.new(0, 6)

            local activeState = default or options[1]
            local buttons = {}

            local function updateButtons()
                for _, data in ipairs(buttons) do
                    local isActive = (data.name == activeState)
                    tweenService:Create(data.btn, TweenInfo.new(0.2), {
                        BackgroundColor3 = isActive and COR_DESTAQUE or COR_BOTAO,
                        TextColor3 = isActive and COR_FUNDO or COR_DESATIVADO
                    }):Play()
                    tweenService:Create(data.stroke, TweenInfo.new(0.2), {
                        Color = isActive and COR_DESTAQUE or COR_SEGUNDARIA
                    }):Play()
                end
            end

            for _, opt in ipairs(options) do
                local btn = Instance.new("TextButton", btnContainer)
                btn.Size = UDim2.new(1 / #options, 0, 1, 0)
                btn.Text = opt
                btn.Font = FONTE_TITULO
                btn.TextSize = isMobile and 10 or 12
                btn.BackgroundColor3 = (opt == activeState) and COR_DESTAQUE or COR_BOTAO
                btn.TextColor3 = (opt == activeState) and COR_FUNDO or COR_DESATIVADO
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
                local btnStroke = Instance.new("UIStroke", btn)
                btnStroke.Color = (opt == activeState) and COR_DESTAQUE or COR_SEGUNDARIA
                btnStroke.Thickness = 1

                table.insert(buttons, {btn = btn, name = opt, stroke = btnStroke})
                btn.MouseButton1Click:Connect(function()
                    if activeState ~= opt then
                        activeState = opt
                        updateButtons()
                        if callback then callback(opt) end
                    end
                end)
            end
            return container
        end

        local function CreateSlider(parent, text, min, max, default, callback)
            local card = Instance.new("Frame", parent)
            card.BackgroundColor3 = COR_FUNDO_CARTAO
            card.BackgroundTransparency = 0.3
            card.Size = UDim2.new(1, 0, 0, SLIDER_HEIGHT)
            card.ZIndex = 12
            Instance.new("UICorner", card).CornerRadius = ARREDONDAMENTO
            Instance.new("UIStroke", card).Color = COR_SEGUNDARIA

            local titleLbl = Instance.new("TextLabel", card)
            titleLbl.Text = " " .. text .. ": " .. default
            titleLbl.Font = FONTE_TITULO
            titleLbl.TextSize = TAMANHO_TEXTO
            titleLbl.TextColor3 = COR_TEXTO
            titleLbl.BackgroundTransparency = 1
            titleLbl.Size = UDim2.new(1, -20, 0, 30)
            titleLbl.Position = UDim2.new(0, 10, 0, 0)
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left

            local sliderBg = Instance.new("TextButton", card)
            sliderBg.Text = ""
            sliderBg.BackgroundColor3 = COR_SEGUNDARIA
            sliderBg.Size = UDim2.new(1, -20, 0, 6)
            sliderBg.Position = UDim2.new(0, 10, 0, SLIDER_HEIGHT - 20)
            Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(0, 3)

            local fill = Instance.new("Frame", sliderBg)
            fill.BackgroundColor3 = COR_DESTAQUE
            fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
            fill.BorderSizePixel = 0
            Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

            local knob = Instance.new("Frame", sliderBg)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            knob.Size = UDim2.new(0, 14, 0, 14)
            knob.AnchorPoint = Vector2.new(0.5, 0.5)
            knob.Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0)
            Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

            local dragSld = false
            sliderBg.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragSld = true
                    local barW = sliderBg.AbsoluteSize.X
                    local t = math.clamp(input.Position.X - sliderBg.AbsolutePosition.X, 0, barW) / barW
                    local val = math.floor(min + t * (max - min) + 0.5)
                    titleLbl.Text = " " .. text .. ": " .. val
                    tweenService:Create(fill, TweenInfo.new(0.08), {Size = UDim2.new(t, 0, 1, 0)}):Play()
                    tweenService:Create(knob, TweenInfo.new(0.08), {Position = UDim2.new(t, 0, 0.5, 0)}):Play()
                    if callback then callback(val) end
                end
            end)
            userInput.InputChanged:Connect(function(input)
                if dragSld and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local barW = sliderBg.AbsoluteSize.X
                    local t = math.clamp(input.Position.X - sliderBg.AbsolutePosition.X, 0, barW) / barW
                    local val = math.floor(min + t * (max - min) + 0.5)
                    titleLbl.Text = " " .. text .. ": " .. val
                    tweenService:Create(fill, TweenInfo.new(0.08), {Size = UDim2.new(t, 0, 1, 0)}):Play()
                    tweenService:Create(knob, TweenInfo.new(0.08), {Position = UDim2.new(t, 0, 0.5, 0)}):Play()
                    if callback then callback(val) end
                end
            end)
            userInput.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragSld = false end
            end)
            return card
        end

        local function CreateLabel(parent, text, color)
            local lbl = Instance.new("TextLabel", parent)
            lbl.Size = UDim2.new(1, 0, 0, 25)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = color or COR_TEXTO
            lbl.Font = FONTE_TITULO
            lbl.TextSize = TAMANHO_TITULO
            lbl.TextXAlignment = Enum.TextXAlignment.Center
            return lbl
        end

        local function CreateSectionHeader(parent, icon, text)
            local frame = Instance.new("Frame", parent)
            frame.Size = UDim2.new(1, 0, 0, 44)  -- altura maior para padding
            frame.BackgroundTransparency = 1

            local lbl = Instance.new("TextLabel", frame)
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.Position = UDim2.new(0, 0, 0, 6)  -- padding superior
            lbl.BackgroundTransparency = 1
            -- Concatena ícone + texto com um espaço
            lbl.Text = (icon or "•") .. "  " .. (text or "")
            lbl.Font = FONTE_TITULO
            lbl.TextSize = TAMANHO_TITULO + 4
            lbl.TextColor3 = COR_DESTAQUE
            lbl.TextXAlignment = Enum.TextXAlignment.Center
            lbl.TextYAlignment = Enum.TextYAlignment.Center

            -- Linha decorativa
            local line = Instance.new("Frame", frame)
            line.Size = UDim2.new(1, -24, 0, 2)   -- margem lateral maior
            line.Position = UDim2.new(0.5, 0, 1, -8)
            line.AnchorPoint = Vector2.new(0.5, 0)
            line.BackgroundColor3 = COR_SEGUNDARIA
            line.BorderSizePixel = 0
            Instance.new("UICorner", line).CornerRadius = UDim.new(0, 1)

            return frame
        end

        local function CreateSkillGrid(parent, skills, initialStates, callback)
            local container = Instance.new("Frame", parent)
            container.BackgroundTransparency = 1
            container.Size = UDim2.new(1, 0, 0, 45)
            local layout = Instance.new("UIListLayout", container)
            layout.FillDirection = Enum.FillDirection.Horizontal
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            layout.Padding = UDim.new(0, 6)

            local state = initialStates or {}
            for _, skill in ipairs(skills) do
                local btn = Instance.new("TextButton", container)
                btn.Size = UDim2.new(0, 36, 0, 36)
                btn.Text = skill
                btn.Font = FONTE_TITULO
                btn.TextSize = 13
                btn.BackgroundColor3 = state[skill] and COR_DESTAQUE or COR_SEGUNDARIA
                btn.TextColor3 = state[skill] and COR_FUNDO or COR_TEXTO
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
                btn.MouseButton1Click:Connect(function()
                    state[skill] = not state[skill]
                    tweenService:Create(btn, TweenInfo.new(0.2), {
                        BackgroundColor3 = state[skill] and COR_DESTAQUE or COR_SEGUNDARIA,
                        TextColor3 = state[skill] and COR_FUNDO or COR_TEXTO
                    }):Play()
                    if callback then callback(skill, state[skill]) end
                end)
            end
            return container
        end

        -- ======= ADICIONAR ABA =======
        local function AddTab(name, icon)
            local tabIndex = #tabButtons + 1

            local btn = Instance.new("TextButton", tabBarContainer)
            btn.Text = icon or name:sub(1,1)
            btn.Font = FONTE_TITULO
            btn.TextSize = 20
            btn.TextColor3 = (tabIndex == 1) and COR_TEXTO or COR_DESATIVADO
            btn.BackgroundColor3 = (tabIndex == 1) and COR_SEGUNDARIA or COR_FUNDO
            btn.Size = UDim2.new(1, 0, 0, 45)
            btn.LayoutOrder = tabIndex
            btn.AutoButtonColor = false
            btn.ZIndex = 12
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
            local stroke = Instance.new("UIStroke", btn)
            stroke.Color = COR_SEGUNDARIA
            stroke.Thickness = 1
            tabButtons[tabIndex] = btn

            local container = Instance.new("ScrollingFrame", sidebar)
            container.Size = UDim2.new(1, -40, 1, -70)
            container.Position = UDim2.new(0, 20, 0, 60)
            container.BackgroundTransparency = 1
            container.BorderSizePixel = 0
            container.ScrollBarThickness = 2
            container.ScrollBarImageColor3 = COR_SEGUNDARIA
            container.ZIndex = 11
            container.Visible = (tabIndex == 1)
            container.CanvasSize = UDim2.new(0, 0, 0, 0)
            container.AutomaticCanvasSize = Enum.AutomaticSize.Y
            Instance.new("UIListLayout", container).Padding = UDim.new(0, 8)
            tabContainers[tabIndex] = container

            btn.MouseButton1Click:Connect(function() SwitchTab(tabIndex) end)

            if tabIndex == 1 then SwitchTab(1) end

            return {
                CreateToggle = function(self, text, default, callback)
                    return CreateToggle(container, text, default, callback)
                end,
                CreateButton = function(self, text, callback, color)
                    return CreateButton(container, text, callback, color)
                end,
                CreateDropdown = function(self, text, options, default, callback)
                    return CreateDropdown(container, text, options, default, callback)
                end,
                CreateRadioGroup = function(self, text, options, default, callback)
                    return CreateRadioGroup(container, text, options, default, callback)
                end,
                CreateSlider = function(self, text, min, max, default, callback)
                    return CreateSlider(container, text, min, max, default, callback)
                end,
                CreateLabel = function(self, text, color)
                    return CreateLabel(container, text, color)
                end,
                CreateSkillGrid = function(self, skills, initialStates, callback)
                    return CreateSkillGrid(container, skills, initialStates, callback)
                end,
                CreateSectionHeader = function(self, icon, text)
                    return CreateSectionHeader(container, icon, text)
                end,
            }
        end
        task.defer(function()
            local totalHeight = 0
            for _, child in ipairs(tabBarContainer:GetChildren()) do
                if child:IsA("TextButton") then
                    totalHeight = totalHeight + child.Size.Y.Offset + 4
                end
            end
            tabBarContainer.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 10)
        end)
        local UI = {
            AddTab = AddTab,
            SendNotification = SendNotification,
            OpenSidebar = OpenSidebar,
            CloseSidebar = CloseSidebar,
            Destroy = function()
                gui:Destroy()
            end
        }
        return UI
    end
-- #endregion


-- ======= SISTEMA DE VOO (FLY) =======
_G.NexusHubFly = {
    enabled = false,
    speed = 50,
    connection = nil,
    userInput = game:GetService("UserInputService"),
    
    start = function(self)
        if self.enabled then return end
        self.enabled = true
        
        _G.NexusHubSetFarmNoclip(true)
        
        local player = game.Players.LocalPlayer
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.PlatformStand = true
                hum.Sit = false
            end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
        
        if _G.NexusHubCancelMove then
            _G.NexusHubCancelMove()
        end
        
        self.connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
            if not self.enabled then return end
            self:update(dt)
        end)
    end,
    
    stop = function(self)
        if not self.enabled then return end
        self.enabled = false
        
        if self.connection then
            self.connection:Disconnect()
            self.connection = nil
        end
        
        local player = game.Players.LocalPlayer
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.PlatformStand = false
            end
            if not _G.NexusHubIsMoving() and not _G.NexusHubMoveNeedsNoclip() then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end
        
        if not _G.NexusHubIsMoving() and not _G.NexusHubMoveNeedsNoclip() then
            _G.NexusHubSetFarmNoclip(false)
        end
    end,
    
    update = function(self, dt)
        local player = game.Players.LocalPlayer
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local cam = workspace.CurrentCamera
        if not hrp or not cam then return end
        
        _G.NexusHubSetFarmNoclip(true)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
        
        local forward = cam.CFrame.LookVector
        local right = cam.CFrame.RightVector
        local up = Vector3.new(0, 1, 0)
        
        local move = Vector3.new()
        if self.userInput:IsKeyDown(Enum.KeyCode.W) then move = move + forward end
        if self.userInput:IsKeyDown(Enum.KeyCode.S) then move = move - forward end
        if self.userInput:IsKeyDown(Enum.KeyCode.A) then move = move - right end
        if self.userInput:IsKeyDown(Enum.KeyCode.D) then move = move + right end
        if self.userInput:IsKeyDown(Enum.KeyCode.Space) then move = move + up end
        if self.userInput:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - up end
        
        if move.Magnitude > 0 then
            move = move.Unit * self.speed * dt
            hrp.CFrame = hrp.CFrame + move
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        else
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end,
    
    toggle = function(self)
        if self.enabled then
            self:stop()
        else
            self:start()
        end
    end
}

-- ==================== NEW UI MODULAR ====================
function M.buildUI()
    local UI = CreateUI(NexusHubVersion)
    
    M.notify = function(title, msg, duration)
        print(("[Nexus Hub] %s: %s"):format(tostring(title), tostring(msg)))
        UI.SendNotification(title .. ": " .. msg)
    end

    M.reloadUI = function()
        if _G.NexusHubUI then
            pcall(function() _G.NexusHubUI:Destroy() end)
        end
        M.buildUI()
    end
    
    -- ===== FARM TAB =====
    local farmTab = UI.AddTab("Farm", "⚔")
    farmTab:CreateSectionHeader("⚔️", "COMBAT")
    farmTab:CreateToggle("Auto Attack", false, function(v) M.setAutoAttack(v) end)
    farmTab:CreateToggle("Auto Farm (Level)", false, function(v)
        if v then
            S.autoAttackForcedByFarm = not S.autoAttack
            if not S.autoAttack then M.setAutoAttack(true) end
            _G.NexusHubSetAutofarm(true)
        else
            if S.autoAttackForcedByFarm then
                M.setAutoAttack(false)
                S.autoAttackForcedByFarm = false
            end
            _G.NexusHubSetAutofarm(false)
        end
    end)

    farmTab:CreateSectionHeader("📈", "PROGRESS")
    farmTab:CreateToggle("Auto 2nd Sea", false, function(v)
        S.autoSecondSea = v
        _G.NexusHubAutoSecondSea = v
        S.secondSeaCombatTarget = nil
        _G.NexusHubSecondSeaTravel = false
        if not v then _G.NexusHubSetFarmNoclip(false) end
        if v then M.notify("Auto 2nd Sea", "Unlocks Second Sea (assumes level 700+)") end
    end)
    farmTab:CreateToggle("Auto 3rd Sea", false, function(v)
        S.autoThirdSea = v
        _G.NexusHubAutoThirdSea = v
        S.thirdSeaCombatTarget = nil
        _G.NexusHubThirdSeaTravel = false
        S.thirdSeaSacrificeActive = false
        if not v then
            S.thirdSeaStageId = nil
            S.thirdSeaRipIndraAnchor = nil
            S.thirdSeaIndraWasFighting = false
            S.thirdSeaRipIndraCutsceneActive = false
            M.clearThirdSeaIndraDeathWatch()
            _G.NexusHubSetFarmNoclip(false)
        end
        if v then
            _G.NexusHubQuestInfo = nil
            M.setQuestInfoCache(nil)
            M.clearQuestFarmAnchor()
            M.syncThirdSeaFlagsFromServer(true)
            local prog = M.getThirdSeaProgressDetails()
            S.thirdSeaStageId = prog.stageId
            M.notify("Auto 3rd Sea", "Stage: " .. prog.label)
        end
    end)
    farmTab:CreateToggle("Auto Farm Chests", false, function(v)
        S.chestFarmEnabled = v
        if not v then M.cancelFarmMove(); M.restoreCharacterPhysics() end
    end)

    farmTab:CreateSectionHeader("🔧", "WEAPON")
    farmTab:CreateDropdown("Weapon Type", {"Melee","Sword"}, "Melee", function(v)
        S.selectedWeapon = v
        S.lastEquippedType = nil
        M.equipWeapon()
    end)

    farmTab:CreateSectionHeader("⚙️", "SETTINGS")
    farmTab:CreateSlider("Attack Range", 5, 100, 50, function(v) Settings.Distance = v end)
    farmTab:CreateSlider("Attack Delay", 0, 20, 0, function(v)
        Settings.AttackDelay = math.max(v * 0.05, MIN_ATTACK_DELAY)
    end)

    farmTab:CreateSectionHeader("🎯", "MASTERY FARM")
    farmTab:CreateToggle("Auto Mastery Farm", false, function(v)
        S.autoMasteryFarm = v
        if not v then M.resetMasteryFarmState() else M.notify("Mastery Farm", "Pairs with Auto Farm") end
    end)
    farmTab:CreateDropdown("Mastery Type", {"Devil Fruit", "Sword", "Gun", "Melee"}, "Devil Fruit", function(v)
        S.masteryFarmType = v
    end)
    farmTab:CreateDropdown("Mastery Item", {"Auto","Saber","Buddy Sword","Cavander","Dark Blade","Hallow Scythe","Shisui","Rengoku","Pole (1st Form)","Yama","Tushita","Cursed Dual Katana","Skull Guitar","Kabucha","Flintlock","Musket","Slingshot","Bizarre Rifle","Combat","Black Leg","Electro","Fishman Karate","Dragon Claw","Superhuman","Death Step","Electric Claw","Sharkman Karate","Dragon Talon","Godhuman"}, "Auto", function(v)
        S.masteryFarmItem = v
    end)
    farmTab:CreateButton("Scan Mastery Items", function()
        local names = M.scanMasteryToolNames()
        M.debugLog("Mastery Items (" .. S.masteryFarmType .. ")", names)
        M.notify("Mastery Farm", "Found " .. tostring(#names - 1) .. " item(s) - check F9")
    end)
    farmTab:CreateSlider("Farm Weapon Until HP %", 5, 90, 25, function(v) S.masteryDamagePercent = v end)
    farmTab:CreateSkillGrid({"Z","X","C","V","F"}, {Z=true, X=true, C=false, V=false, F=false}, function(skill, state)
        if skill == "Z" then S.masterySkillZ = state
        elseif skill == "X" then S.masterySkillX = state
        elseif skill == "C" then S.masterySkillC = state
        elseif skill == "V" then S.masterySkillV = state
        elseif skill == "F" then S.masterySkillF = state end
    end)

    -- ===== BOSS TAB =====
    local bossTab = UI.AddTab("Boss", "👺")
    local currentBosses = M.getCurrentBosses()
    local bossNames = {"All"}
    for _, b in ipairs(currentBosses) do table.insert(bossNames, b.Name) end
    bossTab:CreateSectionHeader("👹", "BOSS FARM")
    S.selectedBoss = "All"
    bossTab:CreateDropdown("Select Boss", bossNames, "All", function(v) S.selectedBoss = v end)
    bossTab:CreateToggle("Auto Farm Bosses", false, function(v)
        S.autoBossFarm = v
        if not v then S.currentBossTarget = nil; S.bossFollowGoal = nil; S.bossMissingSince = nil; M.clearBossResolveCache() end
    end)
    bossTab:CreateToggle("Farm All Bosses", false, function(v) S.farmAllBosses = v end)
    bossTab:CreateToggle("Auto Elites", false, function(v)
        S.autoElite = v
        S.eliteCombatTarget = nil
        if v then M.notify("Auto Elites", "Hunts Elite Pirates") end
    end)
    bossTab:CreateSectionHeader("🌊", "SECOND SEA")
    bossTab:CreateToggle("Auto Darkbeard", false, function(v)
        S.autoDarkbeard = v
        S.darkbeardCombatTarget = nil
        if v then M.notify("Auto Darkbeard", "Altar summon at safe height") end
    end)
    bossTab:CreateToggle("Auto Cursed Captain", false, function(v)
        S.autoCursedCaptain = v
        S.cursedCaptainCombatTarget = nil
        S.cursedCaptainEngaged = false
        if v then M.notify("Auto Cursed Captain", "Pauses quest farm when captain spawns") end
    end)
    bossTab:CreateSectionHeader("🌋", "THIRD SEA RAIDS")
    bossTab:CreateToggle("Auto Rip Indra", false, function(v)
        S.autoIndra = v
        S.indraCombatTarget = nil
        if v then M.notify("Auto Indra", "Waits at Castle on the Sea") end
    end)
    bossTab:CreateToggle("Auto Dough Prince", false, function(v)
        S.autoDoughPrince = v
        if v then S.autoDoughKing = false; S.doughRaidCombatTarget = nil; M.resetDoughFarmAnchor(); M.resetDoughPatrol(); M.notify("Auto Dough Prince", "Cake Land - farms 500 kills") end
    end)
    bossTab:CreateToggle("Auto Dough King", false, function(v)
        S.autoDoughKing = v
        if v then S.autoDoughPrince = false; S.doughRaidCombatTarget = nil; M.resetDoughFarmAnchor(); M.resetDoughPatrol(); M.notify("Auto Dough King", "Same as Prince but crafts Sweet Chalice") end
    end)
    bossTab:CreateSectionHeader("🛠️", "TOOLS")
    bossTab:CreateButton("Check Dough Raid Progress", function()
        local prog = M.getCakePrinceSpawnProgress()
        if not prog then M.notify("Dough Raid", "Could not read progress") return end
        if prog.ready then M.notify("Dough Raid", "Ready to open portal")
        elseif prog.remaining then M.notify("Dough Raid", tostring(prog.remaining) .. " kills remaining") end
    end)
    bossTab:CreateButton("Check Boss Spawns", function()
        local alive = {}
        local discovered = M.discoverAllLiveBosses()
        for _, entry in ipairs(discovered) do table.insert(alive, entry.name .. " (" .. entry.loc .. ")") end
        local msg = "PlaceId: " .. tostring(game.PlaceId) .. "\n"
        if #alive > 0 then msg = msg .. "🟢 Live: " .. table.concat(alive, ", ") end
        M.notify("Bosses", #alive > 0 and msg or "No bosses found.")
    end)

    -- ===== RAID TAB =====
    local raidTab = UI.AddTab("Raid", "🏴")
    raidTab:CreateSectionHeader("⚙️", "CONFIG")
    raidTab:CreateDropdown("Select Raid", {"Flame","Ice","Quake","Light","Dark","Spider","Rumble","Magma","Buddha","Sand","Dough","Phoenix"}, "Flame", function(v) S.selectedRaid = v end)
    raidTab:CreateToggle("Auto Raid", false, function(v) S.autoRaid = v end)
    raidTab:CreateSectionHeader("🏴‍☠️", "PIRATE RAID")
    raidTab:CreateToggle("Auto Pirate Raid", false, function(v)
        S.autoPirateRaid = v
        S.pirateRaidTarget = nil
        S.pirateRaidEngaged = false
        if not v then S.pirateRaidCommencing = false end
        if v then M.notify("Pirate Raid", "Waits for pirate raid") end
    end)
    raidTab:CreateSectionHeader("🏭", "FACTORY RAID")
    raidTab:CreateToggle("Auto Factory Raid", false, function(v)
        S.autoFactoryRaid = v
        S.factoryRaidTarget = nil
        S.factoryRaidEngaged = false
        M.resetFactoryRaidTravel()
        if not v then M.finishFactoryRaidEngage() end
        if v then M.notify("Factory Raid", "Second Sea - attacks Core") end
    end)
    raidTab:CreateSectionHeader("🛠️", "MANUAL")
    raidTab:CreateButton("Buy Chip Now", function()
        M.notify("Chip", "Buying " .. S.selectedRaid .. " chip...")
        task.spawn(function() M.buyChip() end)
    end)
    raidTab:CreateButton("Start Raid Now", function()
        M.notify("Raid", "Attempting to start raid...")
        task.spawn(function() M.startRaid() end)
    end)

    -- ===== FRUIT TAB =====
    local fruitTab = UI.AddTab("Fruit", "🍎")
    fruitTab:CreateSectionHeader("🎰", "GACHA")
    fruitTab:CreateToggle("Auto Fruit Roll", false, function(v) S.autoFruitRoll = v end)
    fruitTab:CreateToggle("Auto Store Fruit", false, function(v)
        S.autoStoreFruit = v
        M.setAutoStoreFruitListener(v)
        if v then M.tryStoreAllFruits() end
    end)
    fruitTab:CreateSectionHeader("🌍", "WORLD FRUIT")
    fruitTab:CreateToggle("Auto Fruit Sniper", false, function(v)
        S.autoFruitSniper = v
        S.fruitSniperTarget = nil
        S.fruitSniperChasing = false
        if v then M.notify("Fruit Sniper", "Watching - pauses quest farm while chasing fruit") end
    end)
    fruitTab:CreateSectionHeader("🛠️", "ACTIONS")
    fruitTab:CreateButton("Store Fruit Now", function()
        if M.tryStoreAllFruits() == 0 then M.notify("Fruit", "No fruit found") end
    end)
    fruitTab:CreateButton("Roll Fruit Now", function()
        local res = M.rollFruitGacha()
        if res then M.notify("Gacha", tostring(res)) else M.notify("Gacha", "Roll failed") end
    end)

    -- ===== HAUNTED TAB =====
    local hauntedTab = UI.AddTab("Haunted", "👻")
    hauntedTab:CreateSectionHeader("🪦", "GRAVESTONE (NIGHT ONLY)")
    hauntedTab:CreateToggle("Auto Pray", false, function(v) S.autoPray = v; if v then M.notify("Auto Pray", "Tweens at night") end end)
    hauntedTab:CreateToggle("Auto Try Luck", false, function(v) S.autoTryLuck = v; if v then M.notify("Auto Try Luck", "Tweens at night") end end)
    hauntedTab:CreateButton("Pray Now", function()
        if not M.isSea3() then M.notify("Pray", "Sea 3 only") return end
        local _, res = M.gravestoneAction(1)
        M.notify("Pray", res and tostring(res) or "Failed")
    end)
    hauntedTab:CreateButton("Try Luck Now", function()
        if not M.isSea3() then M.notify("Try Luck", "Sea 3 only") return end
        local _, res = M.gravestoneAction(2)
        M.notify("Try Luck", res and tostring(res) or "Failed")
    end)
    hauntedTab:CreateSectionHeader("💀", "DEATH KING")
    hauntedTab:CreateToggle("Auto Roll Bones", false, function(v) S.autoRollBones = v; if v then M.notify("Auto Roll Bones", "Rolling surprise") end end)
    hauntedTab:CreateButton("Roll Bones Now", function()
        if not M.isSea3() then M.notify("Bones", "Sea 3 only") return end
        local _, res = M.rollBonesSurprise()
        M.notify("Bones", res and tostring(res) or "Roll failed")
    end)
    hauntedTab:CreateSectionHeader("🧙", "SOUL REAPER")
    hauntedTab:CreateToggle("Auto Soul Reaper", false, function(v) S.autoSoulReaper = v; S.soulReaperTarget = nil; if v then M.notify("Soul Reaper", "Roll bones -> spawn -> farm") end end)

    -- ===== MATERIALS TAB =====
    local matTab = UI.AddTab("Materials", "⛏")
    matTab:CreateSectionHeader("⛏️", "AUTO FARM MATERIALS")
    local materialSeas = {"Sea 1", "Sea 2", "Sea 3"}
    matTab:CreateDropdown("Sea", materialSeas, S.selectedMaterialSea, function(v)
        S.selectedMaterialSea = v
        S.materialPatrolIx = 0
    end)
    for _, sea in ipairs(materialSeas) do
        matTab:CreateDropdown(sea .. " Material", MaterialOrder[sea] or {}, S.selectedMaterials[sea] or MaterialOrder[sea][1], function(v)
            S.selectedMaterials[sea] = v
            S.materialPatrolIx = 0
        end)
    end
    matTab:CreateToggle("Auto Farm Material", false, function(v)
        S.autoMaterialFarm = v
        S.materialPatrolIx = 0
        if v then M.notify("Materials", "Farming " .. tostring(S.selectedMaterials[S.selectedMaterialSea]) .. " (" .. S.selectedMaterialSea .. ")") end
    end)

    -- ===== PLAYER TAB =====
    local playerTab = UI.AddTab("Player", "👤")
    playerTab:CreateSectionHeader("🏃", "MOVEMENT")
    playerTab:CreateSlider("Walk Speed", 16, 325, 16, function(v) S.SetWalkSpeed = v end)
    playerTab:CreateToggle("Infinite Jump", false, function(v) S.infJumpEnabled = v end)
    playerTab:CreateSectionHeader("🛸", "FLY")
    playerTab:CreateToggle("Fly (WASD + Space/Shift)", false, function(on)
        if on then
            _G.NexusHubFly:start()
        else
            _G.NexusHubFly:stop()
        end
    end)
    playerTab:CreateSlider("Fly Speed", 10, 200, 50, function(val)
        _G.NexusHubFly.speed = val
    end)
    playerTab:CreateSectionHeader("🧬", "RACE")
    playerTab:CreateToggle("Auto Activate V3 (T)", false, function(v) S.autoActivateV3 = v; _G.NexusHubAutoV3 = v end)
    playerTab:CreateToggle("Auto Activate V4 (Y)", false, function(v) S.autoActivateV4 = v; _G.NexusHubAutoV4 = v end)
    playerTab:CreateToggle("Walk on Water", false, function(v) S.walkOnWater = v; waterWalk.CanCollide = v end)
    playerTab:CreateSectionHeader("🛡️", "HAKI")
    playerTab:CreateToggle("Auto Buso", false, function(v) S.autoBuso = v; if v then M.enableBuso() end end)
    playerTab:CreateToggle("Auto Instinct", false, function(v) S.autoInstinct = v; if v then M.setInstinct(true) else M.setInstinct(false) end end)
    playerTab:CreateToggle("Auto Buy Haki Color", false, function(v) S.autoBuyHakiColor = v end)
    playerTab:CreateToggle("Auto Buy Race Gear", false, function(v) S.autoBuyRaceGear = v end)
    playerTab:CreateSectionHeader("📊", "STATS")
    playerTab:CreateDropdown("Stat to Add", {"Melee","Defense","Sword","Gun","Demon Fruit"}, "Melee", function(v) S.selectedStat = v end)
    playerTab:CreateSlider("Stat Amount", 1, 10, 1, function(v) S.addAmount = v end)
    playerTab:CreateToggle("Auto Stats", false, function(v) S.autoStats = v end)

    -- ===== SEA TAB =====
    local seaTab = UI.AddTab("Sea", "🌊")
    seaTab:CreateSectionHeader("🚤", "SEA FARMING")
    seaTab:CreateToggle("Auto Sea Farm", false, function(v) S.autoSeaFarm = v; S.cachedMyBoat = nil; S.cachedSeaTarget = nil; if not v and not S.autoLeviathan then M.stopBoatDrive() end end)
    seaTab:CreateToggle("Auto Leviathan", false, function(v) S.autoLeviathan = v; S.cachedMyBoat = nil; if not v and not S.autoSeaFarm then M.stopBoatDrive() end end)
    seaTab:CreateSectionHeader("🎯", "FARM TARGETS")
    for _, t in ipairs({"Sea Beast","Terror Shark","Piranha","Shark","Ghost Ship","Ship"}) do
        seaTab:CreateToggle("Farm " .. t, true, function(v) S.seaFarmTargets[t] = v end)
    end
    seaTab:CreateSectionHeader("⛵", "BOAT SETTINGS")
    seaTab:CreateSlider("Boat Speed", 50, 350, 200, function(v) S.boatSpeed = v end)
    seaTab:CreateButton("Debug: Boat Info", function()
        local lines = {}
        local boatsFolder = Workspace:FindFirstChild("Boats")
        table.insert(lines, "Boats: " .. (boatsFolder and tostring(#boatsFolder:GetChildren()) or "0"))
        local mine = M.getMyBoat()
        table.insert(lines, "MyBoat: " .. (mine and mine.Name or "nil"))
        M.debugLog("Boat Info", lines)
        M.notify("Boat Debug", "Printed to console (F9)")
    end)

    -- ===== SHOP TAB (opcional – pode ser fundido com Player) =====
    local shopTab = UI.AddTab("Shop", "🛒")
    shopTab:CreateSectionHeader("🍏", "FRUIT DEALERS")
    shopTab:CreateButton("Open Regular Fruit Dealer", function() M.openRegularFruitDealer() end)
    shopTab:CreateButton("Open Advanced Fruit Dealer", function() M.openAdvancedFruitDealer() end)
    shopTab:CreateSectionHeader("🧘", "HAKI ABILITIES")
    local hakiItems = {"Buso (Aura)","Instinct (Ken)","Geppo (Air Jump)","Soru (Flash Step)"}
    local selectedHaki = "Buso (Aura)"
    shopTab:CreateDropdown("Haki Item", hakiItems, selectedHaki, function(v) selectedHaki = v end)
    shopTab:CreateButton("Buy Selected Haki", function()
        if selectedHaki == "Buso (Aura)" then M.shopPurchase("Buso", function() return M.buyHakiAbility("Buso") end)
        elseif selectedHaki == "Instinct (Ken)" then M.shopPurchase("Instinct", function() return M.buyInstinct() end)
        elseif selectedHaki == "Geppo (Air Jump)" then M.shopPurchase("Geppo", function() return M.buyHakiAbility("Geppo") end)
        elseif selectedHaki == "Soru (Flash Step)" then M.shopPurchase("Soru", function() return M.buyHakiAbility("Soru") end)
        end
    end)
    shopTab:CreateButton("Enable Buso Now", function() M.enableBuso(); M.notify("Shop", "Buso toggle sent") end)
    shopTab:CreateButton("Enable Instinct Now", function() M.setInstinct(true); M.notify("Shop", "Instinct enabled") end)
    shopTab:CreateSectionHeader("⚙️", "GEAR")
    local gearItems = {"Haki Color", "Race Gear"}
    local selectedGear = "Haki Color"
    shopTab:CreateDropdown("Gear Item", gearItems, selectedGear, function(v) selectedGear = v end)
    shopTab:CreateButton("Buy Selected Gear", function()
        if selectedGear == "Haki Color" then M.shopPurchase("Haki Color", function() return M.buyHakiColor() end)
        else M.shopPurchase("Race Gear", function() return M.buyRaceGear() end)
        end
    end)
    shopTab:CreateSectionHeader("💍", "ACCESSORIES")
    local accItems = {"Black Cape", "Swordsman Hat", "Tomoe Ring"}
    local selectedAcc = "Black Cape"
    shopTab:CreateDropdown("Accessory", accItems, selectedAcc, function(v) selectedAcc = v end)
    shopTab:CreateButton("Buy Selected Accessory", function()
        if selectedAcc == "Black Cape" then M.shopPurchase("Black Cape", function() return M.buyAccessory("Black Cape") end)
        elseif selectedAcc == "Swordsman Hat" then M.shopPurchase("Swordsman Hat", function() return M.buyAccessory("Swordsman Hat") end)
        else M.shopPurchase("Tomoe Ring", function() return M.buyAccessory("Tomoe Ring") end)
        end
    end)

    -- ===== MISC TAB =====
    local miscTab = UI.AddTab("Misc", "⚙")
    miscTab:CreateSectionHeader("🚀", "MOVEMENT")
    miscTab:CreateToggle("Noclip (go through map)", true, function(v)
        _G.NexusHubGlobalNoclip = v
        if v then M.notify("Noclip", "On") else if not (_G.NexusHubMoveNeedsNoclip and _G.NexusHubMoveNeedsNoclip()) then M.forceNoclip(false) end; M.notify("Noclip", "Off") end
    end)
    miscTab:CreateButton("Unstuck", function() M.doUnstuck() end)
    miscTab:CreateSectionHeader("🎛️", "UI SETTINGS")
    miscTab:CreateLabel("Toggle: RightControl (or click 'NX')")
    miscTab:CreateSectionHeader("🏠", "HOME POINT")
    miscTab:CreateToggle("Auto Set Home Point", false, function(v) S.autoSetHomePoint = v; S.lastHomeAnchorPos = nil; S.lastHomeSetAt = 0; S.lastHomeRecoverAt = 0; if v then M.notify("Home Point", "Updates spawn while farming") end end)
    miscTab:CreateButton("Set Home Point Now", function()
        local ok = M.setHomePoint()
        if ok then local hrp = M.getHRP(); S.lastHomeAnchorPos = hrp and hrp.Position or nil; S.lastHomeSetAt = os.clock(); M.notify("Home Point", "Spawn set") else M.notify("Home Point", "Failed") end
    end)
    miscTab:CreateButton("Teleport Home Now", function()
        local ok = M.teleportHome()
        M.notify("Home Point", ok and "Teleport sent" or "Failed")
    end)
    miscTab:CreateSectionHeader("🎨", "VISUAL")
    miscTab:CreateToggle("Remove Fog", false, function(v) S.removeFogEnabled = v end)
    miscTab:CreateToggle("Remove Darkness (Danger 6)", false, function(v) S.removeDarknessEnabled = v end)
    miscTab:CreateToggle("Fruit ESP", false, function(v) S.fruitEspEnabled = v; if not v then M.clearFruitEsp() end end)
    miscTab:CreateSectionHeader("🔧", "UTILITIES")
    miscTab:CreateButton("Toggle Damage UI", function()
        local dc = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("GUI") and ReplicatedStorage.Assets.GUI:FindFirstChild("DamageCounter")
        if dc then dc.Enabled = not dc.Enabled; M.notify("UI", "Damage counter " .. (dc.Enabled and "enabled" or "disabled")) end
    end)
    miscTab:CreateButton("Toggle Notifications", function()
        local n = Player.PlayerGui:FindFirstChild("Notifications")
        if n then n.Enabled = not n.Enabled; M.notify("UI", "Notifications " .. (n.Enabled and "enabled" or "disabled")) end
    end)
    miscTab:CreateButton("Redeem All Codes", function()
        M.notify("Codes", "Redeeming all codes...")
        task.spawn(function()
            local ok, raw = pcall(function() return game:HttpGet("https://pastebin.com/raw/cLp2LXrs") end)
            if not ok then M.notify("Codes", "Failed to fetch code list") return end
            local redeemRemote = Remotes:FindFirstChild("Redeem")
            if not redeemRemote then M.notify("Codes", "Redeem remote not found") return end
            local count = 0
            for code in raw:gmatch("[^\r\n]+") do pcall(function() redeemRemote:InvokeServer(code) end); count = count + 1 end
            M.notify("Codes", "Redeemed " .. count .. " code(s)!")
        end)
    end)
    miscTab:CreateButton("Fast Mode (Reduce Lag)", function()
        local Lighting = game:GetService("Lighting")
        local Terrain  = workspace:FindFirstChildOfClass("Terrain")
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then obj.Material = Enum.Material.SmoothPlastic; obj.Reflectance = 0; obj.CastShadow = false
            elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then obj:Destroy()
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then obj.Enabled = false end
        end
        Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9; Lighting.Brightness = 1; Lighting.EnvironmentSpecularScale = 0; Lighting.EnvironmentDiffuseScale = 0
        if Terrain then Terrain.WaterWaveSize = 0; Terrain.WaterWaveSpeed = 0; Terrain.WaterTransparency = 1; Terrain.WaterReflectance = 0 end
        M.notify("Fast Mode", "Performance optimised!")
    end)
    miscTab:CreateToggle("Anti AFK", false, function(v) M.setAntiAfk(v); if v then M.notify("Anti AFK", "Prevents idle kick") end end)

    miscTab:CreateSectionHeader("📍", "TELEPORTS")
    local teleportSea = M.getCurrentSea()
    miscTab:CreateLabel(teleportSea .. " - Tween Travel")
    local tweenLabels = M.getTweenDestinationLabels(teleportSea)
    local defaultTween = tweenLabels[1] or "Jungle"
    S.selectedTeleportDest = defaultTween
    miscTab:CreateDropdown("Destination", tweenLabels, defaultTween, function(v) S.selectedTeleportDest = v end)
    miscTab:CreateSlider("Tween Speed", 16, 325, S.manualTravelSpeed, function(v) S.manualTravelSpeed = v end)
    miscTab:CreateButton("Go to Location", function()
        if not S.selectedTeleportDest then M.notify("Teleports", "Select a destination") return end
        M.notify("Teleports", "Tweening to " .. S.selectedTeleportDest .. "...")
        M.tweenToDestination(S.selectedTeleportDest)
    end)

    miscTab:CreateSectionHeader("🔄", "SESSION")
    miscTab:CreateButton("Rejoin", function()
        pcall(function() queue_on_teleport([[loadstring(game:HttpGet('https://pastebin.com/raw/TAxQY7uz'))()]]) end)
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
    end)
    miscTab:CreateButton("Server Hop", function()
        pcall(function() queue_on_teleport([[loadstring(game:HttpGet('https://pastebin.com/raw/TAxQY7uz'))()]]) end)
        local servers = M.getServers(game.PlaceId)
        if #servers > 0 then TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(#servers)], Player) else TeleportService:Teleport(game.PlaceId, Player) end
    end)
    miscTab:CreateButton("UNLOAD", function()
        _G.NexusHubRunning = false
        task.wait(0.5)
        M.onUnloadCleanup()
        M.stopAutofarm()
        S.autoRaid = false; S.autoAttack = false; _G.NexusHubAutoAttack = false
        S.autoSeaFarm = false; S.autoLeviathan = false; S.autoStats = false
        S.chestFarmEnabled = false; S.autoBossFarm = false
        S.autoFruitRoll = false; S.autoStoreFruit = false
        S.autoFruitSniper = false; S.fruitSniperChasing = false
        S.autoIndra = false; S.indraCombatTarget = nil
        S.autoElite = false; S.eliteCombatTarget = nil
        S.autoDarkbeard = false; S.darkbeardCombatTarget = nil
        S.autoCursedCaptain = false; S.cursedCaptainCombatTarget = nil; S.cursedCaptainEngaged = false
        S.autoDoughPrince = false; S.autoDoughKing = false
        S.doughRaidCombatTarget = nil; S.doughBringMobActive = false; S.doughRaidTravel = false
        M.resetDoughFarmAnchor(); M.resetDoughPatrol()
        S.autoSetHomePoint = false; S.lastHomeAnchorPos = nil
        S.autoPirateRaid = false; S.pirateRaidTarget = nil; S.pirateRaidEngaged = false
        S.autoFactoryRaid = false; S.factoryRaidTarget = nil; S.factoryRaidEngaged = false
        pcall(M.resetFactoryRaidTravel)
        S.autoMasteryFarm = false; S.masteryPhase = "farm"; S.masteryTargetModel = nil
        pcall(function() M.resetMasteryFarmState() end)
        S.autoPray = false; S.autoTryLuck = false; S.autoRollBones = false
        S.autoSoulReaper = false; S.soulReaperTarget = nil
        S.autoMaterialFarm = false
        S.autoActivateV3 = false; S.autoActivateV4 = false
        _G.NexusHubAutoV3 = false; _G.NexusHubAutoV4 = false
        M.unanchorFarmTarget()
        S.autoBuso = false; S.autoInstinct = false
        S.autoBuyHakiColor = false; S.autoBuyRaceGear = false
        S.autoSaber = false; S.saberCombatTarget = nil; S.saberForcedAutofarm = false
        S.autoSecondSea = false; _G.NexusHubAutoSecondSea = false; _G.NexusHubSecondSeaTravel = false
        S.secondSeaCombatTarget = nil
        S.autoThirdSea = false; _G.NexusHubAutoThirdSea = false; _G.NexusHubThirdSeaTravel = false
        S.thirdSeaCombatTarget = nil; S.thirdSeaSacrificeActive = false; S.thirdSeaRipIndraAnchor = nil
        pcall(function() M.setInstinct(false) end)
        pcall(function() M.setAutoStoreFruitListener(false) end)
        pcall(function() M.setAntiAfk(false) end)
        S.fruitEspEnabled = false; pcall(M.clearFruitEsp)
        M.stopBoatDrive()
        if workspace:FindFirstChild("NexusHubWaterWalk") then
            pcall(function() workspace.NexusHubWaterWalk:Destroy() end)
        end
        local player = game.Players.LocalPlayer
        if player then
            local gui = player.PlayerGui:FindFirstChild("NexusHubUI")
            if gui then gui:Destroy() end
        end
        _G.NexusHubUI = nil
        pcall(M.DisconnectAll)
        Character = nil
        Humanoid = nil
        HumanoidRootPart = nil
        _G.NexusHubLoaded = false
        _G.NexusHubDevMode = nil
        _G.NexusHubRunning = false
        for i = #Connections, 1, -1 do
            if Connections[i] and Connections[i].Disconnect then
                pcall(Connections[i].Disconnect)
            end
            Connections[i] = nil
        end
        if _G.NexusHubFly and _G.NexusHubFly.enabled then
            _G.NexusHubFly:stop()
        end
        Connections = {}
        _G.StopHeartbeat = true
        M.notify("Nexus Hub", "Unloaded successfully. You can inject again.")
    end)

    _G.NexusHubUI = UI
end

function M.startBackgroundLoops()
    if S.backgroundLoopsStarted then return end
    S.backgroundLoopsStarted = true
    M.setupBroadcastHooks()
end

M.buildUI()
_G.NexusHubLoaded = true
_G.NexusHubBooting = nil
M.startBackgroundLoops()
task.spawn(function()
    repeat task.wait() until _G.NexusHubLoaded
    while _G.NexusHubLoaded do
        task.wait(0.75)
        if _G.NexusHubAutofarm == true and _G.NexusHubAutoSecondSea ~= true and _G.NexusHubAutoThirdSea ~= true
            and not M.isFruitSniperActive() and not M.isCursedCaptainEngaged() and not M.isFactoryRaidEngaged()
            and not ((S.autoDoughPrince or S.autoDoughKing) and S.doughBringMobActive) then
            pcall(_G.NexusHubQuestLoopTick)
        end
    end
end)
