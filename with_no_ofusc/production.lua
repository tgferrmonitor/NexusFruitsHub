-- PROD - linhas: 1214
--#region CORE
task.wait(2)
if not game:IsLoaded() then game.Loaded:Wait() end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- 0. TELA DE LOADING (NEON AZUL FLUTUANTE)
-- ==========================================
local LoadGui = Instance.new("ScreenGui")
LoadGui.Name = "NexusLoading"
LoadGui.ResetOnSpawn = false
pcall(function() LoadGui.Parent = CoreGui end)
if not LoadGui.Parent then LoadGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local LoadBG = Instance.new("Frame", LoadGui)
LoadBG.Size = UDim2.new(1, 0, 1, 0)
LoadBG.BackgroundTransparency = 1
LoadBG.BorderSizePixel = 0

local LoadTitle = Instance.new("TextLabel", LoadBG)
LoadTitle.Size = UDim2.new(0, 400, 0, 50); LoadTitle.Position = UDim2.new(0.5, -200, 0.5, -40)
LoadTitle.BackgroundTransparency = 1; LoadTitle.Text = "NexusFruitsHub"
LoadTitle.Font = Enum.Font.GothamBlack; LoadTitle.TextSize = 36; LoadTitle.TextColor3 = Color3.fromRGB(255, 255, 255)

local NeonGlow = Instance.new("UIStroke", LoadTitle)
NeonGlow.Color = Color3.fromRGB(0, 170, 255); NeonGlow.Thickness = 2.5; NeonGlow.Transparency = 0.3

local BarBG = Instance.new("Frame", LoadBG)
BarBG.Size = UDim2.new(0, 250, 0, 4); BarBG.Position = UDim2.new(0.5, -125, 0.5, 20)
BarBG.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Instance.new("UICorner", BarBG).CornerRadius = UDim.new(1, 0)

local BarFill = Instance.new("Frame", BarBG)
BarFill.Size = UDim2.new(0, 0, 1, 0); BarFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
Instance.new("UICorner", BarFill).CornerRadius = UDim.new(1, 0)

local loadTween = TweenService:Create(BarFill, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)})
loadTween:Play(); loadTween.Completed:Wait()

-- ==========================================
-- 1. TELEMETRIA E ANTI-AFK
-- ==========================================
local DEBUG_LOGS = { Quests = true, Movimento = true, Frutas = true, Codigos = true }
local function rLog(category, msg)
    if not DEBUG_LOGS[category] then return end
    local finalMsg = string.format("[%s] [Hub %s]: %s\n", os.date("%H:%M:%S"), category, msg)
    if rconsoleprint then pcall(function() rconsoleprint(finalMsg) end) else print(finalMsg) end
end

local lastLogAction = ""
local function logActionOnce(category, actionStr)
    if lastLogAction ~= actionStr then lastLogAction = actionStr; rLog(category, actionStr) end
end

LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame); task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    logActionOnce("Movimento", "Sinal de inatividade detectado pelo Roblox. Anti-AFK ativado com sucesso.")
end)

-- ==========================================
-- 2. NEXUS DB E CORDENADAS
-- ==========================================
local UniversalQuestDB = {
    -- SEA 1
    {Level = 1, Name = "Bandit", QuestName = "BanditQuest1", QuestNum = 1}, {Level = 10, Name = "Monkey", QuestName = "JungleQuest", QuestNum = 1},
    {Level = 15, Name = "Gorilla", QuestName = "JungleQuest", QuestNum = 2}, {Level = 30, Name = "Pirate", QuestName = "BuggyQuest1", QuestNum = 1},
    {Level = 40, Name = "Brute", QuestName = "BuggyQuest1", QuestNum = 2}, {Level = 60, Name = "Desert Bandit", QuestName = "DesertQuest", QuestNum = 1},
    {Level = 75, Name = "Desert Officer", QuestName = "DesertQuest", QuestNum = 2}, {Level = 90, Name = "Snow Bandit", QuestName = "SnowQuest", QuestNum = 1},
    {Level = 100, Name = "Snowman", QuestName = "SnowQuest", QuestNum = 2}, {Level = 120, Name = "Chief Petty Officer", QuestName = "MarineQuest2", QuestNum = 1},
    {Level = 150, Name = "Sky Bandit", QuestName = "SkyQuest", QuestNum = 1}, {Level = 175, Name = "Dark Master", QuestName = "SkyQuest", QuestNum = 2},
    {Level = 190, Name = "Prisoner", QuestName = "PrisonerQuest", QuestNum = 1}, {Level = 210, Name = "Dangerous Prisoner", QuestName = "PrisonerQuest", QuestNum = 2},
    {Level = 250, Name = "Toga Warrior", QuestName = "ColosseumQuest", QuestNum = 1}, {Level = 275, Name = "Gladiator", QuestName = "ColosseumQuest", QuestNum = 2},
    {Level = 300, Name = "Military Soldier", QuestName = "MagmaQuest", QuestNum = 1}, {Level = 330, Name = "Military Spy", QuestName = "MagmaQuest", QuestNum = 2},
    {Level = 450, Name = "God's Guard", QuestName = "SkyExp1Quest", QuestNum = 1}, {Level = 475, Name = "Shanda", QuestName = "SkyExp1Quest", QuestNum = 2},
    {Level = 525, Name = "Royal Squad", QuestName = "SkyExp2Quest", QuestNum = 1}, {Level = 550, Name = "Royal Soldier", QuestName = "SkyExp2Quest", QuestNum = 2},
    {Level = 625, Name = "Galley Pirate", QuestName = "FountainQuest", QuestNum = 1}, {Level = 650, Name = "Galley Captain", QuestName = "FountainQuest", QuestNum = 2},
    -- SEA 2
    {Level = 700, Name = "Raider", QuestName = "Area1Quest", QuestNum = 1}, {Level = 725, Name = "Mercenary", QuestName = "Area1Quest", QuestNum = 2},
    {Level = 775, Name = "Swan Pirate", QuestName = "Area2Quest", QuestNum = 1}, {Level = 800, Name = "Factory Staff", QuestName = "Area2Quest", QuestNum = 2},
    {Level = 875, Name = "Marine Lieutenant", QuestName = "MarineQuest3", QuestNum = 1}, {Level = 950, Name = "Zombie", QuestName = "ZombieQuest", QuestNum = 1},
    {Level = 1000, Name = "Snow Trooper", QuestName = "SnowMountainQuest", QuestNum = 1}, {Level = 1050, Name = "Winter Warrior", QuestName = "SnowMountainQuest", QuestNum = 2},
    {Level = 1125, Name = "Magma Ninja", QuestName = "FireQuest", QuestNum = 1}, {Level = 1175, Name = "Lava Pirate", QuestName = "FireQuest", QuestNum = 2},
    {Level = 1250, Name = "Ship Deckhand", QuestName = "ShipQuest1", QuestNum = 1}, {Level = 1275, Name = "Ship Engineer", QuestName = "ShipQuest1", QuestNum = 2},
    {Level = 1350, Name = "Arctic Warrior", QuestName = "FrostQuest", QuestNum = 1}, {Level = 1425, Name = "Sea Soldier", QuestName = "ForgottenQuest", QuestNum = 1},
    -- SEA 3
    {Level = 1500, Name = "Pirate Millionaire", QuestName = "PiratePortQuest", QuestNum = 1}, {Level = 1525, Name = "Pistol Billionaire", QuestName = "PiratePortQuest", QuestNum = 2},
    {Level = 1575, Name = "Dragon Crew Warrior", QuestName = "AmazonQuest", QuestNum = 1}, {Level = 1600, Name = "Dragon Crew Archer", QuestName = "AmazonQuest", QuestNum = 2},
    {Level = 1700, Name = "Marine Commodore", QuestName = "MarineTreeQuest", QuestNum = 1}, {Level = 1725, Name = "Marine Rear Admiral", QuestName = "MarineTreeQuest", QuestNum = 2},
    {Level = 1775, Name = "Fishman Raider", QuestName = "DeepForestQuest1", QuestNum = 1}, {Level = 1800, Name = "Fishman Captain", QuestName = "DeepForestQuest1", QuestNum = 2},
    {Level = 1850, Name = "Forest Pirate", QuestName = "DeepForestQuest2", QuestNum = 1}, {Level = 1900, Name = "Jungle Pirate", QuestName = "DeepForestQuest3", QuestNum = 1},
    {Level = 1975, Name = "Reborn Skeleton", QuestName = "HauntedQuest1", QuestNum = 1}, {Level = 2000, Name = "Living Zombie", QuestName = "HauntedQuest1", QuestNum = 2},
    {Level = 2075, Name = "Peanut Scout", QuestName = "NutsQuest1", QuestNum = 1}, {Level = 2100, Name = "Peanut President", QuestName = "NutsQuest1", QuestNum = 2},
    {Level = 2125, Name = "Ice Cream Chef", QuestName = "IceCreamQuest", QuestNum = 1}, {Level = 2150, Name = "Ice Cream Commander", QuestName = "IceCreamQuest", QuestNum = 2},
    {Level = 2200, Name = "Cookie Crafter", QuestName = "CakeQuest1", QuestNum = 1}, {Level = 2225, Name = "Cake Guard", QuestName = "CakeQuest1", QuestNum = 2},
    {Level = 2300, Name = "Cocoa Warrior", QuestName = "ChocoQuest1", QuestNum = 1}, {Level = 2325, Name = "Chocolate Bar Battler", QuestName = "ChocoQuest1", QuestNum = 2},
    {Level = 2375, Name = "Candy Rebel", QuestName = "CandyQuest1", QuestNum = 1}, {Level = 2400, Name = "Candy Pirate", QuestName = "CandyQuest1", QuestNum = 1},
    {Level = 2425, Name = "Snow Demon", QuestName = "CandyQuest1", QuestNum = 2}
}

local SeaIslands = {
    [1] = {
        ["Starter Pirate"] = CFrame.new(974, 16, 1419), ["Starter Marine"] = CFrame.new(-2566, 6, 3156),
        ["Jungle"] = CFrame.new(-1612, 36, 149), ["Pirate Village"] = CFrame.new(-1184, 4, 3802),
        ["Desert"] = CFrame.new(944, 6, 4344), ["Middle Town"] = CFrame.new(-690, 15, 1582),
        ["Frozen Village"] = CFrame.new(1347, 104, -1319), ["Marine Fortress"] = CFrame.new(-4607, 21, 4280),
        ["Skypiea"] = CFrame.new(-4869, 717, -2667), ["Prison"] = CFrame.new(4875, 5, 734),
        ["Colosseum"] = CFrame.new(-3148, 313, -1690), ["Magma Village"] = CFrame.new(-5294, 8, 8503),
        ["Fountain City"] = CFrame.new(5127, 38, 4105)
    },
    [2] = {
        ["Café (Safe Zone)"] = CFrame.new(-380, 73, 297),
        ["Kingdom of Rose"] = CFrame.new(855, 25, 1157), ["Green Zone"] = CFrame.new(-2448, 73, -3206),
        ["Graveyard"] = CFrame.new(-5467, 49, -710), ["Snow Mountain"] = CFrame.new(944, 400, -3271),
        ["Hot and Cold"] = CFrame.new(-5834, 18, -5088), ["Cursed Ship"] = CFrame.new(923, 125, 32853),
        ["Ice Castle"] = CFrame.new(5451, 28, -6226), ["Forgotten Island"] = CFrame.new(-3055, 240, -10143)
    },
    [3] = {
        ["Port Town"] = CFrame.new(-290, 7, 5324), ["Hydra Island"] = CFrame.new(5749, 610, -253),
        ["Great Tree"] = CFrame.new(2681, 73, -7015), ["Floating Turtle"] = CFrame.new(-13274, 332, -6763),
        ["Castle on the Sea"] = CFrame.new(-5036, 315, -3179), ["Haunted Castle"] = CFrame.new(-9494, 142, 5506),
        ["Peanut Island"] = CFrame.new(-2070, 38, -10232), ["Ice Cream Island"] = CFrame.new(-820, 66, -10965),
        ["Cake Island"] = CFrame.new(-1880, 38, -12028), ["Chocolate Island"] = CFrame.new(202, 24, -12111),
        ["Candy Cane Land"] = CFrame.new(-1147, 13, -14216), ["Tiki Outpost"] = CFrame.new(-16234, 9, 401)
    }
}

-- ==========================================
-- 3. FUNÇÕES GERAIS, VOO E HAKI (DRY + V3 PATCH)
-- ==========================================
local function GetBestQuest()
    local myLvl = LocalPlayer.Data.Level.Value; local best = nil
    for _, q in ipairs(UniversalQuestDB) do if myLvl >= q.Level then best = q end end
    return best
end

local function GetTargetInfo(enemyName)
    local target, targetCFrame = nil, nil
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myRoot and myRoot.Position or Vector3.zero
    local minDist = math.huge

    for _, v in pairs(workspace.Enemies:GetChildren()) do
        if v.Name == enemyName and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 and v:FindFirstChild("HumanoidRootPart") then 
            local dist = (v.HumanoidRootPart.Position - myPos).Magnitude
            if dist < minDist then
                minDist = dist
                target = v
                targetCFrame = v.HumanoidRootPart.CFrame
            end
        end
    end

    if targetCFrame then return target, targetCFrame end

    if workspace:FindFirstChild("_WorldOrigin") and workspace._WorldOrigin:FindFirstChild("EnemySpawns") then
        for _, spawnPart in pairs(workspace._WorldOrigin.EnemySpawns:GetChildren()) do 
            if string.find(spawnPart.Name, enemyName) then 
                if enemyName == "Prisoner" and string.find(spawnPart.Name, "Dangerous") then
                    continue
                end
                return nil, spawnPart.CFrame 
            end 
        end
    end

    return nil, nil
end

local function GetSessionID()
    pcall(function()
        local SendHitsToServer = getrenv()._G.SendHitsToServer
        if SendHitsToServer then return tostring(LocalPlayer.UserId):sub(2, 4) .. tostring(getupvalues(SendHitsToServer)[1]):sub(11, 15) end
    end)
    return "0000000"
end

-- PATCH V3: ATTACK MANAGER (COOLDOWN PARA EVITAR NETWORK SPIKE)
local LastAttackTick = 0
local AttackCooldown = 0.15 -- Margem super segura para o Xeno

local function RemoteAttack(target)
    if tick() - LastAttackTick < AttackCooldown then return end
    local Net = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net")
    if not Net:FindFirstChild("RE/RegisterAttack") then return end
    pcall(function()
        LastAttackTick = tick()
        Net["RE/RegisterAttack"]:FireServer(0.5)
        Net["RE/RegisterHit"]:FireServer(target:WaitForChild("HumanoidRootPart", 1) or target.PrimaryPart, {}, nil, GetSessionID())
    end)
end

local function DirectHit(target)
    if tick() - LastAttackTick < AttackCooldown then return end
    local Net = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net")
    pcall(function()
        LastAttackTick = tick()
        Net["RE/RegisterAttack"]:FireServer(0.5)
        Net["RE/RegisterHit"]:FireServer(target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart, {}, nil, GetSessionID())
    end)
end

-- PATCH V3: VOO LERP (SEM TREMEDEIRA NO XENO)
local function FlyToCFrame(targetCFrame, deltaTime)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return math.huge end

    for _, v in pairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end

    local currentPos = root.Position
    local targetPos = targetCFrame.Position

    local flatCurrent = Vector3.new(currentPos.X, 0, currentPos.Z)
    local flatTarget = Vector3.new(targetPos.X, 0, targetPos.Z)
    local horizontalDist = (flatCurrent - flatTarget).Magnitude

    local wayPoint = targetPos

    if horizontalDist > 300 then
        wayPoint = Vector3.new(targetPos.X, math.max(currentPos.Y, 400), targetPos.Z)
    end

    local totalDist = (currentPos - wayPoint).Magnitude
    local speed = 175

    if totalDist > 5 then
        -- Interpolação suave para evitar "jitter"
        root.CFrame = root.CFrame:Lerp(CFrame.new(currentPos, wayPoint) * CFrame.new(0, 0, -(speed * deltaTime)), 1)
        root.Velocity = Vector3.zero
        root.RotVelocity = Vector3.zero
    else
        root.CFrame = targetCFrame
    end

    return (currentPos - targetPos).Magnitude
end

local function AutoHaki()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
    end)
end

local function SetPlatformStand(char, state)
    local hum = char and char:FindFirstChild("Humanoid")
    if hum then
        hum.PlatformStand = state 
    end
end

-- ==========================================
-- 4. NEXUS UI LIBRARY
-- ==========================================
local Theme = {
    Background = Color3.fromRGB(18, 18, 22), Sidebar = Color3.fromRGB(12, 12, 15), TopBar = Color3.fromRGB(8, 8, 10),
    Section = Color3.fromRGB(24, 24, 30), Element = Color3.fromRGB(35, 35, 45), ElementHover = Color3.fromRGB(45, 45, 55),
    Accent = Color3.fromRGB(0, 170, 255), Text = Color3.fromRGB(250, 250, 250), SubText = Color3.fromRGB(150, 150, 160),
    Off = Color3.fromRGB(60, 60, 70)
}

local NexusUI = {}

function NexusUI:CreateSection(parent, title)
    local sec = Instance.new("Frame", parent)
    sec.Size = UDim2.new(0.95, 0, 0, 0); sec.BackgroundColor3 = Theme.Section
    Instance.new("UICorner", sec).CornerRadius = UDim.new(0, 8)
    local titleLbl = Instance.new("TextLabel", sec)
    titleLbl.Size = UDim2.new(1, -20, 0, 30); titleLbl.Position = UDim2.new(0, 12, 0, 0); titleLbl.BackgroundTransparency = 1; titleLbl.TextColor3 = Theme.Text; titleLbl.Text = title; titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextSize = 13; titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    local inner = Instance.new("Frame", sec)
    inner.Size = UDim2.new(1, 0, 1, -30); inner.Position = UDim2.new(0, 0, 0, 30); inner.BackgroundTransparency = 1
    local layout = Instance.new("UIListLayout", inner)
    layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0, 8); layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Instance.new("UIPadding", inner).PaddingBottom = UDim.new(0, 12)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() sec.Size = UDim2.new(0.95, 0, 0, layout.AbsoluteContentSize.Y + 42) end)
    return inner
end

function NexusUI:CreateButton(parent, text, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0.95, 0, 0, 35); btn.BackgroundColor3 = Theme.Element; btn.TextColor3 = Theme.Text; btn.Text = text; btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

function NexusUI:CreateToggle(parent, text, defaultState, callback)
    local state = defaultState or false
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(0.95, 0, 0, 35); container.BackgroundColor3 = Theme.Element
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)
    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(1, -60, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0); lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.TextColor3 = Theme.Text; lbl.Font = Enum.Font.GothamSemibold; lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left
    local switchBG = Instance.new("Frame", container)
    switchBG.Size = UDim2.new(0, 36, 0, 18); switchBG.Position = UDim2.new(1, -46, 0.5, -9); switchBG.BackgroundColor3 = state and Theme.Accent or Theme.Off
    Instance.new("UICorner", switchBG).CornerRadius = UDim.new(1, 0)
    local circle = Instance.new("Frame", switchBG)
    circle.Size = UDim2.new(0, 14, 0, 14); circle.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7); circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
    local btn = Instance.new("TextButton", container)
    btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""

    local toggleAPI = {}
    function toggleAPI.SetState(newState, silent)
        state = newState
        TweenService:Create(switchBG, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = state and Theme.Accent or Theme.Off}):Play()
        TweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
        if not silent then callback(state) end
    end
    btn.MouseButton1Click:Connect(function() toggleAPI.SetState(not state, false) end)
    return toggleAPI
end

function NexusUI:CreateDropdown(parent, text, options, callback)
    local isOpen = false; local currentSel = options[1] or "Nenhum"
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(0.95, 0, 0, 35); container.BackgroundColor3 = Theme.Element; container.ClipsDescendants = true
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)
    local header = Instance.new("TextButton", container)
    header.Size = UDim2.new(1, 0, 0, 35); header.BackgroundTransparency = 1; header.Text = "  " .. text .. ": " .. currentSel; header.TextColor3 = Theme.Text; header.Font = Enum.Font.GothamSemibold; header.TextSize = 12; header.TextXAlignment = Enum.TextXAlignment.Left
    local chevron = Instance.new("TextLabel", header)
    chevron.Size = UDim2.new(0, 30, 1, 0); chevron.Position = UDim2.new(1, -30, 0, 0); chevron.BackgroundTransparency = 1; chevron.Text = "▼"; chevron.TextColor3 = Theme.SubText; chevron.Font = Enum.Font.GothamBold; chevron.TextSize = 12
    local layout = Instance.new("UIListLayout", container); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0, 2)
    local tInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local currentOptionsCount = #options; local optionButtons = {}

    local function Toggle()
        isOpen = not isOpen
        TweenService:Create(container, tInfo, {Size = UDim2.new(0.95, 0, 0, isOpen and (35 + (currentOptionsCount * 30) + 5) or 35)}):Play()
        TweenService:Create(chevron, tInfo, {Rotation = isOpen and 180 or 0}):Play()
    end
    header.MouseButton1Click:Connect(Toggle)

    local function BuildOptions(optList)
        for _, btn in pairs(optionButtons) do btn:Destroy() end
        optionButtons = {}; currentOptionsCount = #optList
        for _, opt in ipairs(optList) do
            local optBtn = Instance.new("TextButton", container)
            optBtn.Size = UDim2.new(1, -10, 0, 30); optBtn.BackgroundColor3 = Theme.ElementHover; optBtn.TextColor3 = Theme.SubText; optBtn.Text = opt; optBtn.Font = Enum.Font.Gotham; optBtn.TextSize = 12
            Instance.new("UICorner", optBtn).CornerRadius = UDim.new(0, 4)
            table.insert(optionButtons, optBtn)
            optBtn.MouseButton1Click:Connect(function() currentSel = opt; header.Text = "  " .. text .. ": " .. currentSel; Toggle(); callback(currentSel) end)
        end
    end
    BuildOptions(options)

    local dropAPI = {}
    function dropAPI.UpdateOptions(newOptions) currentSel = newOptions[1] or "Nenhum"; header.Text = "  " .. text .. ": " .. currentSel; BuildOptions(newOptions); if isOpen then Toggle() end; callback(currentSel) end
    function dropAPI.GetValue() return currentSel end
    return dropAPI
end

function NexusUI:CreateLabel(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(0.95, 0, 0, 0); lbl.BackgroundTransparency = 1; lbl.TextColor3 = Theme.SubText; lbl.Text = text; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextYAlignment = Enum.TextYAlignment.Top; lbl.TextWrapped = true; lbl.AutomaticSize = Enum.AutomaticSize.Y
    return lbl
end

-- ==========================================
-- 5. VARIÁVEIS GLOBAIS DE CONTROLE
-- ==========================================
local API_AutoFarm = nil
local API_KillAura = nil
local API_Skills = {}
local DoFruitSniper = nil
local GlobalFruitOnGround = nil
local isFarming = false
local isKillAuraActive = false
local activeSkills = {Z = false, X = false, C = false, V = false, F = false}
local isCastingSkill = false 

-- ==========================================
-- 6. CONSTRUÇÃO DA JANELA PRINCIPAL
-- ==========================================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "NexusFruitsHub_UX"
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 620, 0, 420); MainFrame.Position = UDim2.new(0.5, -310, 0.5, -210)
MainFrame.BackgroundColor3 = Theme.Background; MainFrame.ClipsDescendants = true; MainFrame.Visible = false
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local TopBar = Instance.new("TextLabel", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 35); TopBar.BackgroundColor3 = Theme.TopBar; TopBar.Text = "   NexusFruitsHub Free - V2.0.0 (Xeno-Optimized)"; TopBar.TextColor3 = Theme.Text; TopBar.Font = Enum.Font.GothamBold; TopBar.TextSize = 14; TopBar.TextXAlignment = Enum.TextXAlignment.Left; TopBar.Active = true

local MinButton = Instance.new("TextButton", TopBar)
MinButton.Size = UDim2.new(0, 35, 0, 35); MinButton.Position = UDim2.new(1, -35, 0, 0); MinButton.BackgroundTransparency = 1; MinButton.TextColor3 = Theme.SubText; MinButton.Text = "—"; MinButton.Font = Enum.Font.GothamBold; MinButton.TextSize = 14

local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size = UDim2.new(0, 150, 1, -35); Sidebar.Position = UDim2.new(0, 0, 0, 35); Sidebar.BackgroundColor3 = Theme.Sidebar; Sidebar.BorderSizePixel = 0
local SidebarLayout = Instance.new("UIListLayout", Sidebar); SidebarLayout.Padding = UDim.new(0, 8)
local SidebarPad = Instance.new("UIPadding", Sidebar); SidebarPad.PaddingTop = UDim.new(0, 15); SidebarPad.PaddingLeft = UDim.new(0, 10)

local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -150, 1, -35); ContentArea.Position = UDim2.new(0, 150, 0, 35); ContentArea.BackgroundTransparency = 1

local Tabs, Buttons = {}, {}
local function CreateTab(name, icon)
    local btn = Instance.new("TextButton", Sidebar)
    btn.Size = UDim2.new(0.95, 0, 0, 35); btn.BackgroundColor3 = Theme.Element; btn.TextColor3 = Theme.SubText; btn.Text = "  " .. icon .. " " .. name; btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 13; btn.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local page = Instance.new("ScrollingFrame", ContentArea)
    page.Size = UDim2.new(1, 0, 1, 0); page.BackgroundTransparency = 1; page.ScrollBarThickness = 3; page.Visible = false
    local layout = Instance.new("UIListLayout", page); layout.Padding = UDim.new(0, 12); layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Instance.new("UIPadding", page).PaddingTop = UDim.new(0, 15)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 30) end)

    table.insert(Tabs, page); table.insert(Buttons, btn)
    btn.MouseButton1Click:Connect(function()
        for i, t in ipairs(Tabs) do t.Visible = (t == page); Buttons[i].TextColor3 = (t == page) and Theme.Text or Theme.SubText; Buttons[i].BackgroundColor3 = (t == page) and Theme.ElementHover or Theme.Element end
    end)
    return page
end
--#endregion CORE

-- ==========================================
-- PÁGINAS E LÓGICAS DO HUB
-- ==========================================

--#region A. PÁGINA INÍCIO
local PageHome = CreateTab("Início", "🏠")
local SecStatus = NexusUI:CreateSection(PageHome, "Status Global")
local LblPlayer = NexusUI:CreateLabel(SecStatus, "Carregando informacoes...")
local LblServer = NexusUI:CreateLabel(SecStatus, "Carregando informacoes...")

task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local lvl = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Level")
            local money = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Beli")
            LblPlayer.Text = "Nome: " .. LocalPlayer.Name .. "\nNível: " .. (lvl and lvl.Value or "N/A") .. "   |   Beli: $" .. (money and money.Value or "N/A")
            local eventStatus = "Nenhum"
            if workspace.Enemies:FindFirstChild("Factory Staff") or workspace:FindFirstChild("Factory") then eventStatus = "Factory / Raid" end
            LblServer.Text = "\nJogadores Ativos: " .. #Players:GetPlayers() .. "/12\nEventos no Mapa: " .. eventStatus
        end)
    end
end)

local SecCodes = NexusUI:CreateSection(PageHome, "Auto-Redeem Códigos")
local CodesLog = NexusUI:CreateLabel(SecCodes, "Pronto para injetar na rede...")
CodesLog.TextColor3 = Theme.Accent

local activeCodes = {"Sub2Fer999", "Sub2CaptainMaui", "KittGaming", "Axiore", "Sub2Daigrock", "Sub2OfficialNoobie", "Fudd10", "fudd10_v2", "Bignews", "Magicbus", "Starcodeheo", "JCWK", "StrawHatMaine", "Bluxxy", "Sub2GamerRobot_Exp1", "Sub2GamerRobot_Reset1", "Sub2NoobMaster123", "Sub2UncleKizaru", "TantaiGaming", "TheGreatAce", "LIGHTNINGABUSE", "KITT_RESET", "CHANDLER", "ENYU_IS_PRO"}
NexusUI:CreateButton(SecCodes, "Injetar Todos os Códigos Ativos", function()
    task.spawn(function()
        local RedeemEvent = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Redeem")
        if not RedeemEvent then CodesLog.Text = "> ❌ Erro: Remote 'Redeem' ausente!" return end
        local count = 0
        for i, code in ipairs(activeCodes) do
            CodesLog.Text = "> ⏳ Enviando [" .. i .. "/" .. #activeCodes .. "]: " .. code
            local s, r = pcall(function() return RedeemEvent:InvokeServer(code) end)
            if s then
                local strR = string.lower(tostring(r))
                if strR == "1" or string.find(strR, "success") then count = count + 1; CodesLog.Text = "> ✅ SUCESSO: [" .. code .. "] ativado!"
                elseif strR == "-1" or string.find(strR, "already") then CodesLog.Text = "> ⚠️ JA USADO: [" .. code .. "]"
                else CodesLog.Text = "> ❌ EXPIRADO: [" .. code .. "]" end
            end
            task.wait(2.5) 
        end
        CodesLog.Text = "> 🏁 Varredura concluida! Codigos SUCESSO: " .. count
    end)
end)
--#endregion A. PÁGINA INÍCIO

--#region B. PÁGINA FRUTAS E BERRIES
local PageFruits = CreateTab("Frutas e Berries", "🍎")
local SecGacha = NexusUI:CreateSection(PageFruits, "Gacha e Armazenamento")
local GachaLog = NexusUI:CreateLabel(SecGacha, "Pronto para girar.")
GachaLog.TextColor3 = Theme.Accent

local function AutoStoreFruit(CommF)
    local function findPhysicalFruit(parent)
        if not parent then return nil end
        for _, obj in pairs(parent:GetChildren()) do if obj:IsA("Tool") and obj:FindFirstChild("Handle") and not obj:FindFirstChild("Level") then if obj:GetAttribute("OriginalName") or string.find(obj.Name, "Fruit") then return obj end end end return nil
    end
    local fruitTool = findPhysicalFruit(LocalPlayer.Character) or findPhysicalFruit(LocalPlayer:FindFirstChild("Backpack"))
    if fruitTool then
        local fruitName = fruitTool:GetAttribute("OriginalName") or fruitTool.Name
        GachaLog.Text = "> Fruta encontrada: " .. fruitName .. "\n> Armazenando..."
        local s, r = pcall(function() return CommF:InvokeServer("StoreFruit", fruitName, fruitTool) end)
        task.wait(0.5); GachaLog.Text = (s and fruitTool.Parent == nil) and ("> ✅ Sucesso! " .. fruitName .. " armazenada.") or ("> ❌ Falha: Inventario cheio.")
    else GachaLog.Text = "> ❓ Está sem beli?" end
end

NexusUI:CreateButton(SecGacha, "Girar Fruta", function()
    local CommF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
    if CommF then
        GachaLog.Text = "> Contatando NPC Zioles..."
        local s, r = pcall(function() return CommF:InvokeServer("Cousin", "Buy") end)
        if s then if type(r) == "string" and (string.find(r, "wait") or string.find(r, "money")) then GachaLog.Text = "> Erro: \n" .. r else task.wait(1.5) AutoStoreFruit(CommF) end end
    end
end)

local SecCollect = NexusUI:CreateSection(PageFruits, "Radar e Coletor de Frutas")
local ESPLbl = NexusUI:CreateLabel(SecCollect, "Escaneando...")
ESPLbl.TextColor3 = Color3.fromRGB(200, 200, 50)

task.spawn(function() 
    while task.wait(3) do 
        local foundNames = {}
        GlobalFruitOnGround = nil
        for _, obj in pairs(workspace:GetChildren()) do 
            if obj:IsA("Tool") and string.find(obj.Name, "Fruit") then 
                table.insert(foundNames, obj.Name)
                if not GlobalFruitOnGround then GlobalFruitOnGround = obj end 
            end 
        end
        if #foundNames > 0 then
            ESPLbl.Text = "Frutas no chão:\n- " .. table.concat(foundNames, "\n- ")
        else
            ESPLbl.Text = "Frutas no chão: Nenhuma."
        end
    end 
end)

DoFruitSniper = function()
    local fruitToCollect = GlobalFruitOnGround
    if fruitToCollect and fruitToCollect:FindFirstChild("Handle") then
        ESPLbl.Text = "> 🚀 Voando ate a fruta..."
        local flyConn
        flyConn = RunService.Stepped:Connect(function(_, dt)
            if not fruitToCollect or not fruitToCollect.Parent then flyConn:Disconnect() return end
            if FlyToCFrame(fruitToCollect.Handle.CFrame, dt) <= 2 then
                flyConn:Disconnect()
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root then firetouchinterest(root, fruitToCollect.Handle, 0); firetouchinterest(root, fruitToCollect.Handle, 1) end
                task.wait(1)
                local CommF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
                if CommF then AutoStoreFruit(CommF) end
            end
        end)
    end
end

NexusUI:CreateButton(SecCollect, "Voar e Coletar", DoFruitSniper)

local SecBerries = NexusUI:CreateSection(PageFruits, "Radar e Coleta de Berries (Drops)")
local BerriesLbl = NexusUI:CreateLabel(SecBerries, "Escaneando Berries (Drops)...")
BerriesLbl.TextColor3 = Color3.fromRGB(85, 255, 127) 

task.spawn(function()
    while task.wait(2) do
        local found = 0
        for _, obj in pairs(workspace:GetChildren()) do
            local nomeLocal = string.lower(obj.Name)
            if string.find(nomeLocal, "coin") or string.find(nomeLocal, "beli") or string.find(nomeLocal, "money") or string.find(nomeLocal, "drop") or string.find(nomeLocal, "berry") then
                found = found + 1
            end
        end
        if found > 0 then
            BerriesLbl.Text = "Berries/Drops no chão: " .. found
        else
            BerriesLbl.Text = "Nenhuma Berry detectada."
        end
    end
end)

NexusUI:CreateButton(SecBerries, "Voar e Coletar Berries", function()
    task.spawn(function()
        for _, obj in pairs(workspace:GetChildren()) do
            local nomeLocal = string.lower(obj.Name)
            if string.find(nomeLocal, "coin") or string.find(nomeLocal, "beli") or string.find(nomeLocal, "money") or string.find(nomeLocal, "drop") or string.find(nomeLocal, "berry") then
                local targetPart = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if targetPart then
                    BerriesLbl.Text = "> 🚀 Coletando Berry/Drop..."
                    local flyConn
                    flyConn = RunService.Stepped:Connect(function(_, dt)
                        if not obj or not obj.Parent then flyConn:Disconnect(); return end
                        if FlyToCFrame(targetPart.CFrame, dt) <= 3 then
                            flyConn:Disconnect()
                            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if root then 
                                firetouchinterest(root, targetPart, 0)
                                firetouchinterest(root, targetPart, 1) 
                            end
                        end
                    end)
                    while flyConn.Connected do task.wait(0.1) end
                    task.wait(0.5) 
                end
            end
        end
        BerriesLbl.Text = "> 🏁 Coleta Finalizada."
    end)
end)
--#endregion B. PÁGINA FRUTAS E BERRIES

--#region C. AUTO FARM
local PageFarm = CreateTab("Auto Farm", "⚔️")
local SecFarmConfig = NexusUI:CreateSection(PageFarm, "Configurações de Combate")

local selectedWeapon = "Melee"
NexusUI:CreateDropdown(SecFarmConfig, "Arma", {"Melee", "Sword"}, function(sel)
    selectedWeapon = sel
    local char = LocalPlayer.Character
    if char then 
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then tool.Parent = LocalPlayer.Backpack end 
    end
end)

local selectedStat = "Melee"
NexusUI:CreateDropdown(SecFarmConfig, "Auto Status", {"Melee", "Defense", "Sword", "Gun", "Blox Fruit"}, function(sel) selectedStat = sel end)

local autoStatEnabled = false
NexusUI:CreateToggle(SecFarmConfig, "Auto Distribuir Status", false, function(state) autoStatEnabled = state end)

local SecFarmMain = NexusUI:CreateSection(PageFarm, "Controle Geral")
local FarmStatusLbl = NexusUI:CreateLabel(SecFarmMain, "Aguardando ativacao...")
FarmStatusLbl.TextColor3 = Color3.fromRGB(0, 200, 255)

local FarmConnection
local activeQuestInfo = nil

API_AutoFarm = NexusUI:CreateToggle(SecFarmMain, "Auto Farm Completo", false, function(state)
    isFarming = state
    if isFarming then
        AutoHaki() 
        FarmStatusLbl.Text = "> Iniciando rotina Global..."

        FarmConnection = RunService.Stepped:Connect(function(_, dt)
            if not isFarming then return end
            pcall(function()
                if activeQuestInfo then
                    local targetEnemy, targetCFrame = GetTargetInfo(activeQuestInfo.Name)
                    if targetCFrame then
                        local safePos = targetCFrame * CFrame.new(0, 57, 0)
                        FlyToCFrame(safePos, dt)
                    end
                end
            end)
        end)

        task.spawn(function()
            local CommF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
            while isFarming do
                pcall(function()
                    if autoStatEnabled then
                        local points = LocalPlayer.Data.Points.Value
                        if points > 0 then 
                            CommF:InvokeServer("AddPoint", selectedStat, points) 
                        end
                    end

                    local questGui = LocalPlayer.PlayerGui:FindFirstChild("Main") and LocalPlayer.PlayerGui.Main:FindFirstChild("Quest")
                    if CommF and (not questGui or not questGui.Visible or activeQuestInfo == nil) then
                        local best = GetBestQuest()
                        if best then 
                            activeQuestInfo = best
                            FarmStatusLbl.Text = "> Extraindo Quest: " .. best.Name
                            CommF:InvokeServer("StartQuest", best.QuestName, best.QuestNum)
                            task.wait(1) 
                        end
                    end

                    if activeQuestInfo then
                        local targetEnemy, _ = GetTargetInfo(activeQuestInfo.Name)
                        if targetEnemy and targetEnemy:FindFirstChild("Humanoid") and targetEnemy.Humanoid.Health > 0 then
                            local char = LocalPlayer.Character
                            local activeTool = nil
                            if char then
                                local tool = char:FindFirstChildOfClass("Tool")
                                if tool and tool.ToolTip ~= selectedWeapon then 
                                    tool.Parent = LocalPlayer.Backpack
                                    tool = nil 
                                end
                                if not tool then
                                    for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do 
                                        if t:IsA("Tool") and t.ToolTip == selectedWeapon then 
                                            t.Parent = char
                                            tool = t
                                            break 
                                        end 
                                    end
                                end
                                activeTool = tool

                                -- Força a animação da espada para o anti-cheat não pegar "Ghost hitting"
                                if activeTool then
                                    activeTool:Activate()
                                end
                            end
                            RemoteAttack(targetEnemy)
                        end
                    end
                end)
                task.wait(0.1)
            end
        end)
    else
        FarmStatusLbl.Text = "> Farm Pausado."
        if FarmConnection then FarmConnection:Disconnect(); FarmConnection = nil end
        activeQuestInfo = nil

        task.spawn(function()
            pcall(function()
                local CommF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
                if CommF then CommF:InvokeServer("AbandonQuest") end
            end)
        end)
    end
end)
--#endregion C. AUTO FARM

--#region D. AUTO ATAQUE PVE
local PageAura = CreateTab("Auto Ataque PvE", "⚡")

local SecKillAura = NexusUI:CreateSection(PageAura, "Kill Aura PVE (Ataque M1 Básico)")

local auraWeapon = "Melee"
NexusUI:CreateDropdown(SecKillAura, "Arma do Ataque Básico", {"Melee", "Sword", "Blox Fruit"}, function(sel)
    auraWeapon = sel
    local char = LocalPlayer.Character
    if char then 
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then tool.Parent = LocalPlayer.Backpack end 
    end
end)

local KillAuraStatus = NexusUI:CreateLabel(SecKillAura, "Aura Desativada.")
KillAuraStatus.TextColor3 = Theme.SubText

local auraRadius = 60
local auraConnection

API_KillAura = NexusUI:CreateToggle(SecKillAura, "Ligar Kill Aura", false, function(state)
    isKillAuraActive = state
    if isKillAuraActive then
        AutoHaki() 
        KillAuraStatus.Text = "> ⚡ Aura Ativa (Raio: " .. auraRadius .. " studs)"
        KillAuraStatus.TextColor3 = Theme.Accent

        auraConnection = RunService.Heartbeat:Connect(function()
            if isCastingSkill then return end

            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then return end

            pcall(function()
                for _, enemy in pairs(workspace.Enemies:GetChildren()) do
                    if enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 and enemy:FindFirstChild("HumanoidRootPart") then
                        local dist = (root.Position - enemy.HumanoidRootPart.Position).Magnitude
                        if dist <= auraRadius then
                            local tool = char:FindFirstChildOfClass("Tool")
                            if tool and tool.ToolTip ~= auraWeapon then tool.Parent = LocalPlayer.Backpack; tool = nil end
                            if not tool then
                                for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do 
                                    if t:IsA("Tool") and t.ToolTip == auraWeapon then t.Parent = char; break end 
                                end
                            end
                            if tool and tool.ToolTip == auraWeapon then
                                tool:Activate()
                                DirectHit(enemy)
                            end
                        end
                    end
                end
            end)
        end)
    else
        KillAuraStatus.Text = "> Aura Desativada."
        KillAuraStatus.TextColor3 = Theme.SubText
        if auraConnection then auraConnection:Disconnect(); auraConnection = nil end
    end
end)
--#endregion D. AUTO ATAQUE PVE

--#region E. TELEPORTE E VISUAL
local PageTeleport = CreateTab("Teleporte & Visual", "🗺️")

local SecIslands = NexusUI:CreateSection(PageTeleport, "Teleporte Inteligente")
local selectedSeaIndex = 1
local targetIslandCFrame = nil
local DropDestino

NexusUI:CreateDropdown(SecIslands, "Selecione o Mar", {"Sea 1", "Sea 2", "Sea 3"}, function(sel)
    selectedSeaIndex = (sel == "Sea 1" and 1) or (sel == "Sea 2" and 2) or 3
    local newIslandList = {}
    for name, _ in pairs(SeaIslands[selectedSeaIndex]) do table.insert(newIslandList, name) end
    table.sort(newIslandList)
    if DropDestino then DropDestino.UpdateOptions(newIslandList) end
end)

local initialIslandList = {}
for name, _ in pairs(SeaIslands[1]) do table.insert(initialIslandList, name) end
table.sort(initialIslandList)

DropDestino = NexusUI:CreateDropdown(SecIslands, "Destino", initialIslandList, function(sel) 
    if sel ~= "Nenhum" and SeaIslands[selectedSeaIndex][sel] then targetIslandCFrame = SeaIslands[selectedSeaIndex][sel] else targetIslandCFrame = nil end
end)
targetIslandCFrame = SeaIslands[1][initialIslandList[1]]

local TeleportConnection
local TeleportToggle
TeleportToggle = NexusUI:CreateToggle(SecIslands, "Auto Teleport (Seguro)", false, function(state)
    if state then
        if not targetIslandCFrame then TeleportToggle.SetState(false, true); return end
        if TeleportConnection then TeleportConnection:Disconnect() end
        TeleportConnection = RunService.Stepped:Connect(function(_, dt)
            if FlyToCFrame(targetIslandCFrame, dt) <= 5 then
                TeleportConnection:Disconnect(); TeleportConnection = nil; TeleportToggle.SetState(false, true)
            end
        end)
    else
        if TeleportConnection then TeleportConnection:Disconnect(); TeleportConnection = nil end
    end
end)

local SecWorld = NexusUI:CreateSection(PageTeleport, "Modificações no mapa")
local cachedLighting = {}
local noFogConnection

NexusUI:CreateToggle(SecWorld, "Remover Neblina (Visão de Águia)", false, function(state)
    local Lighting = game:GetService("Lighting")
    if state then
        for _, v in pairs(Lighting:GetChildren()) do
            if v:IsA("Atmosphere") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then
                table.insert(cachedLighting, {efeito = v, parenteOriginal = v.Parent}); v.Parent = nil
            end
        end
        if noFogConnection then noFogConnection:Disconnect() end
        noFogConnection = RunService.RenderStepped:Connect(function()
            Lighting.Ambient = Color3.fromRGB(255, 255, 255); Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255); Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0); Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0); Lighting.Brightness = 2; Lighting.FogEnd = 9e9; Lighting.FogStart = 9e9; Lighting.GlobalShadows = false
        end)
    else
        if noFogConnection then noFogConnection:Disconnect(); noFogConnection = nil end
        for _, data in ipairs(cachedLighting) do if data.efeito then data.efeito.Parent = data.parenteOriginal end end
        cachedLighting = {}; Lighting.GlobalShadows = true
    end
end)

local timeConnection
NexusUI:CreateDropdown(SecWorld, "Controle de Clima", {"Padrão do Jogo", "Sempre Dia", "Sempre Noite"}, function(sel)
    local Lighting = game:GetService("Lighting")
    if timeConnection then timeConnection:Disconnect(); timeConnection = nil end
    if sel == "Sempre Dia" then timeConnection = RunService.RenderStepped:Connect(function() Lighting.ClockTime = 12 end)
    elseif sel == "Sempre Noite" then timeConnection = RunService.RenderStepped:Connect(function() Lighting.ClockTime = 0 end) end
end)

NexusUI:CreateToggle(SecWorld, "Zoom Infinito da Câmera", false, function(state)
    if state then LocalPlayer.CameraMaxZoomDistance = 100000 else LocalPlayer.CameraMaxZoomDistance = 400 end
end)
--#endregion E. TELEPORTE E VISUAL

--#region F. PÁGINA RADAR (ESP)
local PageESP = CreateTab("Radar (ESP)", "👁️")
local SecPlayerESP = NexusUI:CreateSection(PageESP, "Rastreamento de Jogadores")
local SecWorldESP = NexusUI:CreateSection(PageESP, "Rastreamento de Mundo")

local espFolder = Instance.new("Folder")
espFolder.Name = "NexusESP_Master"
pcall(function() espFolder.Parent = CoreGui end)
if not espFolder.Parent then espFolder.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local function CreateESPLabel(name, adornee, color)
    local espGui = Instance.new("BillboardGui"); espGui.Name = name; espGui.Adornee = adornee; espGui.Size = UDim2.new(0, 150, 0, 40); espGui.StudsOffset = Vector3.new(0, 2.5, 0); espGui.AlwaysOnTop = true
    local textLbl = Instance.new("TextLabel", espGui); textLbl.Name = "Label"; textLbl.Size = UDim2.new(1, 0, 1, 0); textLbl.BackgroundTransparency = 1; textLbl.Font = Enum.Font.GothamBold; textLbl.TextSize = 13; textLbl.TextColor3 = color; textLbl.TextStrokeTransparency = 0; textLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    espGui.Parent = espFolder; return espGui
end

local espPlayerToggle, espPlayerConn = false, nil
NexusUI:CreateToggle(SecPlayerESP, "ESP Jogadores (Nome, Lvl e Distância)", false, function(state)
    espPlayerToggle = state
    if espPlayerToggle then
        espPlayerConn = RunService.RenderStepped:Connect(function()
            local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not myRoot then return end
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local char = player.Character; local root = char and char:FindFirstChild("HumanoidRootPart"); local head = char and char:FindFirstChild("Head")
                    if char and root and head and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                        local espName = "ESP_Player_" .. player.Name
                        local espGui = espFolder:FindFirstChild(espName) or CreateESPLabel(espName, head, Color3.fromRGB(255, 255, 255))
                        if player.Team and player.Team.Name == "Marines" then espGui.Label.TextColor3 = Color3.fromRGB(0, 170, 255) else espGui.Label.TextColor3 = Color3.fromRGB(255, 60, 60) end
                        local lvlData = player:FindFirstChild("Data") and player.Data:FindFirstChild("Level")
                        local dist = math.floor((myRoot.Position - root.Position).Magnitude)
                        espGui.Label.Text = string.format("%s - Lvl %s - %dm", player.DisplayName, tostring(lvlData and lvlData.Value or "N/A"), dist)
                    else
                        local espGui = espFolder:FindFirstChild("ESP_Player_" .. player.Name)
                        if espGui then espGui:Destroy() end
                    end
                end
            end
        end)
    else
        if espPlayerConn then espPlayerConn:Disconnect(); espPlayerConn = nil end
        for _, v in pairs(espFolder:GetChildren()) do if string.find(v.Name, "ESP_Player_") then v:Destroy() end end
    end
end)

local espChestToggle = false
local espChestConn = nil
local activeChestsCache = {}

task.spawn(function()
    while task.wait(1) do
        if espChestToggle then
            local foundChests = {}
            for _, obj in pairs(workspace:GetDescendants()) do
                if string.find(obj.Name, "Chest") and (obj:IsA("Part") or obj:IsA("Model")) then
                    if not (obj.Parent and string.find(obj.Parent.Name, "Chest")) then table.insert(foundChests, obj) end
                end
            end
            activeChestsCache = foundChests
        end
    end
end)

NexusUI:CreateToggle(SecWorldESP, "ESP Baús (Dinheiro)", false, function(state)
    espChestToggle = state
    if espChestToggle then
        espChestConn = RunService.RenderStepped:Connect(function()
            local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not myRoot then return end
            local updatedESPs = {}
            for _, obj in ipairs(activeChestsCache) do
                if obj and obj.Parent then
                    local corePart = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                    if corePart then
                        local chestType = "N"; local chestColor = Color3.fromRGB(180, 180, 180) 
                        if string.find(obj.Name, "2") then chestType = "O"; chestColor = Color3.fromRGB(255, 215, 0) elseif string.find(obj.Name, "3") then chestType = "D"; chestColor = Color3.fromRGB(0, 255, 255) end
                        local uniqueId = tostring(corePart:GetDebugId(10))
                        local espName = "ESP_Chest_" .. uniqueId
                        updatedESPs[espName] = true
                        local espGui = espFolder:FindFirstChild(espName) 
                        if not espGui then espGui = CreateESPLabel(espName, corePart, chestColor) end
                        local dist = math.floor((myRoot.Position - corePart.Position).Magnitude)
                        espGui.Label.Text = string.format("%s - %dm", chestType, dist); espGui.Label.TextColor3 = chestColor
                    end
                end
            end
            for _, v in pairs(espFolder:GetChildren()) do if string.find(v.Name, "ESP_Chest_") and not updatedESPs[v.Name] then v:Destroy() end end
        end)
    else
        if espChestConn then espChestConn:Disconnect(); espChestConn = nil end
        for _, v in pairs(espFolder:GetChildren()) do if string.find(v.Name, "ESP_Chest_") then v:Destroy() end end
    end
end)
--#endregion F. PÁGINA RADAR (ESP)

--#region G. PÁGINA SERVIDOR (HOPPER)
local PageServers = CreateTab("Servidores", "🌐")
local SecHopper = NexusUI:CreateSection(PageServers, "Server Hopper Avançado")
local HopperInfo = NexusUI:CreateLabel(SecHopper, "A API do Roblox oculta a Região exata, mas filtramos os servidores mais saudáveis e com vagas disponíveis.")
HopperInfo.TextColor3 = Theme.SubText

local ServerListContainer = Instance.new("Frame", SecHopper)
ServerListContainer.Size = UDim2.new(1, 0, 0, 0); ServerListContainer.BackgroundTransparency = 1
local SL_Layout = Instance.new("UIListLayout", ServerListContainer); SL_Layout.Padding = UDim.new(0, 8); SL_Layout.SortOrder = Enum.SortOrder.LayoutOrder
SL_Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() ServerListContainer.Size = UDim2.new(1, 0, 0, SL_Layout.AbsoluteContentSize.Y) end)

local function ClearServerList()
    for _, v in pairs(ServerListContainer:GetChildren()) do if v:IsA("Frame") or v:IsA("TextButton") or v:IsA("TextLabel") then v:Destroy() end end
end

NexusUI:CreateButton(SecHopper, "🔍 Buscar Melhores Servidores (API)", function()
    ClearServerList()
    local loadingLbl = NexusUI:CreateLabel(ServerListContainer, "Raspando dados da API do Roblox... Aguarde.")
    loadingLbl.TextColor3 = Theme.Accent
    task.spawn(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local success, result = pcall(function() return game:HttpGet(url) end)
        loadingLbl:Destroy()
        if success and result then
            local decoded = HttpService:JSONDecode(result)
            if decoded and decoded.data then
                local validServers = {}
                for _, svr in ipairs(decoded.data) do
                    if svr.playing and svr.maxPlayers and svr.playing < svr.maxPlayers and svr.id ~= game.JobId then table.insert(validServers, svr) end
                end
                table.sort(validServers, function(a, b) return (a.ping or 999) < (b.ping or 999) end)
                if #validServers == 0 then NexusUI:CreateLabel(ServerListContainer, "Nenhum servidor com vaga encontrado."); return end
                for i = 1, math.min(3, #validServers) do
                    local svr = validServers[i]
                    local btnText = string.format("Ping: %dms  |  Jogadores: %d/%d   [ ENTRAR ]", svr.ping or 0, svr.playing, svr.maxPlayers)
                    NexusUI:CreateButton(ServerListContainer, btnText, function()
                        ClearServerList()
                        local teleLbl = NexusUI:CreateLabel(ServerListContainer, "🚀 Conectando ao novo servidor...")
                        teleLbl.TextColor3 = Color3.fromRGB(85, 255, 127)
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, svr.id, LocalPlayer)
                    end)
                end
            else NexusUI:CreateLabel(ServerListContainer, "A estrutura da API de servers mudou, aguarde 10 segundos...") end
        else NexusUI:CreateLabel(ServerListContainer, "Erro fatal: O seu Executor não suporta requisições HTTP.") end
    end)
end)
--#endregion G. PÁGINA SERVIDOR (HOPPER)

--#region Window/UI & MINI-DASHBOARD
Buttons[1].BackgroundColor3 = Theme.ElementHover; Buttons[1].TextColor3 = Theme.Text; Tabs[1].Visible = true

local fadeBG = TweenService:Create(LoadBG, TweenInfo.new(0.5), {BackgroundTransparency = 1}); fadeBG:Play()
local fadeTitle = TweenService:Create(LoadTitle, TweenInfo.new(0.5), {TextTransparency = 1}); fadeTitle:Play()
local fadeNeon = TweenService:Create(NeonGlow, TweenInfo.new(0.5), {Transparency = 1}); fadeNeon:Play()
local fadeBarBG = TweenService:Create(BarBG, TweenInfo.new(0.5), {BackgroundTransparency = 1}); fadeBarBG:Play()
local fadeBarFill = TweenService:Create(BarFill, TweenInfo.new(0.5), {BackgroundTransparency = 1}); fadeBarFill:Play()
fadeBG.Completed:Wait(); LoadGui:Destroy(); 

-- ==========================================
-- 7. POPUP DE AVISO (DISCORD/ATUALIZAÇÕES)
-- ==========================================
local PopupGui = Instance.new("ScreenGui")
PopupGui.Name = "NexusPopupUX"
pcall(function() PopupGui.Parent = CoreGui end)
if not PopupGui.Parent then PopupGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local PopupFrame = Instance.new("Frame", PopupGui)
PopupFrame.Size = UDim2.new(0, 350, 0, 200)
PopupFrame.Position = UDim2.new(0.5, -175, 0.5, -100)
PopupFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35) -- Fundo cinza escuro
Instance.new("UICorner", PopupFrame).CornerRadius = UDim.new(0, 10)

-- Contorno Azul (UIStroke)
local PopupStroke = Instance.new("UIStroke", PopupFrame)
PopupStroke.Color = Color3.fromRGB(60, 150, 255)
PopupStroke.Thickness = 2
PopupStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Título
local PopupTitle = Instance.new("TextLabel", PopupFrame)
PopupTitle.Size = UDim2.new(1, 0, 0, 50)
PopupTitle.BackgroundTransparency = 1
PopupTitle.Text = "NexusFruitsHub"
PopupTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PopupTitle.Font = Enum.Font.GothamBlack
PopupTitle.TextSize = 18

-- Linha Divisória
local Divider = Instance.new("Frame", PopupFrame)
Divider.Size = UDim2.new(1, 0, 0, 1)
Divider.Position = UDim2.new(0, 0, 0, 50)
Divider.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
Divider.BorderSizePixel = 0

-- Texto Central
local PopupText = Instance.new("TextLabel", PopupFrame)
PopupText.Size = UDim2.new(1, -20, 0, 30)
PopupText.Position = UDim2.new(0, 10, 0, 70)
PopupText.BackgroundTransparency = 1
PopupText.Text = "Notícias sobre atualizações no script aqui:"
PopupText.TextColor3 = Color3.fromRGB(240, 240, 240)
PopupText.Font = Enum.Font.GothamBold
PopupText.TextSize = 13

-- Botão/Link do Discord
local DiscordLink = Instance.new("TextButton", PopupFrame)
DiscordLink.Size = UDim2.new(1, 0, 0, 25)
DiscordLink.Position = UDim2.new(0, 0, 0, 100)
DiscordLink.BackgroundTransparency = 1
DiscordLink.Text = "Link do discord"
DiscordLink.TextColor3 = Color3.fromRGB(80, 160, 255)
DiscordLink.Font = Enum.Font.Gotham
DiscordLink.TextSize = 14

-- Lógica para copiar o link e efeito visual
DiscordLink.MouseEnter:Connect(function() DiscordLink.TextColor3 = Color3.fromRGB(120, 190, 255) end)
DiscordLink.MouseLeave:Connect(function() DiscordLink.TextColor3 = Color3.fromRGB(80, 160, 255) end)
DiscordLink.MouseButton1Click:Connect(function()
    -- Coloque seu link real do Discord aqui em baixo:
    local meuDiscord = "https://discord.gg/PYgNZzDd"
    if setclipboard then 
        setclipboard(meuDiscord) 
        DiscordLink.Text = "Copiado!"
        task.wait(1.5)
        DiscordLink.Text = "Link do discord"
    end
end)

-- Botão OK
local OkBtn = Instance.new("TextButton", PopupFrame)
OkBtn.Size = UDim2.new(0, 90, 0, 35)
OkBtn.Position = UDim2.new(0.5, -45, 1, -50)
OkBtn.BackgroundColor3 = Color3.fromRGB(60, 150, 255)
OkBtn.Text = "OK"
OkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
OkBtn.Font = Enum.Font.GothamBold
OkBtn.TextSize = 14
Instance.new("UICorner", OkBtn).CornerRadius = UDim.new(0, 8)

-- Lógica para fechar o Popup e abrir o Hub principal
OkBtn.MouseButton1Click:Connect(function()
    PopupGui:Destroy()
    MainFrame.Visible = true -- Aqui é onde a interface principal finalmente aparece!
end)

local isMinimized = false
local originalSize = MainFrame.Size

local TopBarNeon = Instance.new("UIStroke", TopBar)
TopBarNeon.Color = Color3.fromRGB(0, 170, 255); TopBarNeon.Thickness = 2; TopBarNeon.Transparency = 1 

-- ==========================================
-- ESTRUTURA DO MINI-DASHBOARD DINÂMICO
-- ==========================================
local MiniDashboard = Instance.new("Frame", MainFrame)
MiniDashboard.Size = UDim2.new(1, 0, 1, -35); MiniDashboard.Position = UDim2.new(0, 0, 0, 35)
MiniDashboard.BackgroundTransparency = 1; MiniDashboard.Visible = false; MiniDashboard.ClipsDescendants = true

local MiniLayout = Instance.new("UIListLayout", MiniDashboard)
MiniLayout.SortOrder = Enum.SortOrder.LayoutOrder; MiniLayout.Padding = UDim.new(0, 5)
Instance.new("UIPadding", MiniDashboard).PaddingTop = UDim.new(0, 5)

local function CreateMiniRow(text, isFruitMode)
    local row = Instance.new("Frame", MiniDashboard)
    row.Size = UDim2.new(1, -10, 0, 30); row.Position = UDim2.new(0, 5, 0, 0)
    row.BackgroundColor3 = Theme.Element; row.Visible = false
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -65, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = Theme.Text; lbl.Text = text
    lbl.Font = Enum.Font.GothamSemibold; lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0, 60, 0, 20); btn.Position = UDim2.new(1, -65, 0.5, -10)
    btn.BackgroundColor3 = isFruitMode and Theme.Accent or Theme.Off
    btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.Text = isFruitMode and "PEGAR" or "DESLIGAR"
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 10
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    return row, lbl, btn
end

local rowFarm, lblFarm, btnFarm = CreateMiniRow("⚔️ Auto Farm", false)
local rowAura, lblAura, btnAura = CreateMiniRow("⚡ Auto Ataque", false)
local rowFruit, lblFruit, btnFruit = CreateMiniRow("🍎 Nenhuma Fruta no chão", true)

-- Integrações do Botão
btnFarm.MouseButton1Click:Connect(function() if API_AutoFarm then API_AutoFarm.SetState(false, false) end end)
btnAura.MouseButton1Click:Connect(function() 
    if API_KillAura then API_KillAura.SetState(false, false) end
    if API_Skills then for _, api in pairs(API_Skills) do api.SetState(false, false) end end
end)
btnFruit.MouseButton1Click:Connect(function()
    if API_AutoFarm then API_AutoFarm.SetState(false, true) end
    if API_KillAura then API_KillAura.SetState(false, true) end
    if API_Skills then for _, api in pairs(API_Skills) do api.SetState(false, true) end end
    if DoFruitSniper then DoFruitSniper() end
end)

local function UpdateMiniMenu()
    if isMinimized then
        rowFarm.Visible = isFarming
        rowFruit.Visible = true

        local hasSkills = activeSkills.Z or activeSkills.X or activeSkills.C or activeSkills.V or activeSkills.F
        rowAura.Visible = isKillAuraActive or hasSkills

        if GlobalFruitOnGround then
            lblFruit.Text = "🍎 " .. (GlobalFruitOnGround:GetAttribute("OriginalName") or GlobalFruitOnGround.Name)
        else
            lblFruit.Text = "🍎 Nenhuma Fruta no chão"
        end

        local activeRows = 0
        if rowFarm.Visible then activeRows = activeRows + 1 end
        if rowAura.Visible then activeRows = activeRows + 1 end
        if rowFruit.Visible then activeRows = activeRows + 1 end

        MainFrame.Size = UDim2.new(0, 250, 0, 35 + (activeRows * 35) + 10)
    end
end

task.spawn(function() while task.wait(1) do UpdateMiniMenu() end end)

MinButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then 
        Sidebar.Visible = false; ContentArea.Visible = false; MiniDashboard.Visible = true
        TopBar.Text = "  Nexus (Mini)"
        TopBar.Font = Enum.Font.GothamBlack
        TopBarNeon.Transparency = 0.2 
        MinButton.Text = "+"
        UpdateMiniMenu()
    else 
        Sidebar.Visible = true; ContentArea.Visible = true; MiniDashboard.Visible = false
        MainFrame.Size = originalSize
        TopBar.Text = "   Nexus Fruits Hub Premium - V2.3 (Xeno-Optimized)"
        TopBar.Font = Enum.Font.GothamBold
        TopBarNeon.Transparency = 1 
        MinButton.Text = "—" 
    end
end)

local dragging, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
--#endregion Window/UI & MINI-DASHBOARD