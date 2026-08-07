local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

--================================
-- Serviços do Roblox
--================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--================================
-- Variáveis de Configuração
--================================
local autoAimEnabled = false
local aimDistance = 50

local autoAttackEnabled = false
local attackInterval = 0.5
local lastAttackTime = 0

local speedValue = 16

--================================
-- Função: Pegar o Mob mais próximo
--================================
local function getClosestMob()
    local closestTarget = nil
    local shortestDist = aimDistance
    
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    
    local myPos = char.HumanoidRootPart.Position

    -- Varre todos os modelos do mapa
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= char then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            
            -- Verifica se tem vida, se tem raiz e se NÃO é um jogador (garante que é um Mob/NPC)
            if hum and hum.Health > 0 and hrp and not Players:GetPlayerFromCharacter(obj) then
                local dist = (hrp.Position - myPos).Magnitude
                
                if dist <= shortestDist then
                    shortestDist = dist
                    closestTarget = hrp
                end
            end
        end
    end

    return closestTarget
end

--================================
-- Loop Principal (Roda a cada frame)
--================================
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    
    -- 1. Aplicar Speed
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            -- Força a velocidade se for diferente do padrão (16)
            if speedValue ~= 16 then
                hum.WalkSpeed = speedValue
            end
        end
    end

    -- 2. Auto Aim e Auto Attack
    if autoAimEnabled then
        local target = getClosestMob()
        
        if target then
            -- Trava a câmera no alvo (sem mexer na posição do mob)
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
            
            -- Se o auto ataque estiver ligado, clica com o intervalo definido
            if autoAttackEnabled then
                if tick() - lastAttackTime >= attackInterval then
                    lastAttackTime = tick()
                    
                    -- Simula o clique do mouse (Requer executor compatível)
                    if mouse1click then
                        mouse1click()
                    else
                        -- Alternativa caso mouse1click falhe
                        game:GetService("VirtualUser"):ClickButton1(Vector2.new(0,0))
                    end
                end
            end
        end
    end
end)

--================================
-- Interface Gráfica (Rayfield)
--================================
local Window = Rayfield:CreateWindow({
    Name = "Script Focado",
    LoadingTitle = "Carregando Funções...",
    LoadingSubtitle = "Auto Aim & Auto Attack",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local MainTab = Window:CreateTab("Principal", 4483362458)

MainTab:CreateSection("Mira e Ataque")

MainTab:CreateToggle({
    Name = "1. Auto Aim (Mira Automática)",
    CurrentValue = false,
    Callback = function(Value)
        autoAimEnabled = Value
    end
})

MainTab:CreateSlider({
    Name = "Distância Máxima do Auto Aim",
    Range = {10, 500},
    Increment = 10,
    Suffix = " studs",
    CurrentValue = 50,
    Callback = function(Value)
        aimDistance = Value
    end
})

MainTab:CreateToggle({
    Name = "2. Auto Attack (M1 Click)",
    CurrentValue = false,
    Callback = function(Value)
        autoAttackEnabled = Value
    end
})

MainTab:CreateSlider({
    Name = "Intervalo do Clique (M1)",
    Range = {0.01, 2},
    Increment = 0.05,
    Suffix = " seg",
    CurrentValue = 0.5,
    Callback = function(Value)
        attackInterval = Value
    end
})

MainTab:CreateSection("Movimentação e Visuais")

MainTab:CreateSlider({
    Name = "3. Speed (Velocidade)",
    Range = {16, 200},
    Increment = 1,
    Suffix = " walkspeed",
    CurrentValue = 16,
    Callback = function(Value)
        speedValue = Value
        -- Restaura velocidade normal se o slider voltar para 16
        local char = LocalPlayer.Character
        if char and Value == 16 then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end
})

MainTab:CreateButton({
    Name = "4. Remove Fog (Tirar Névoa)",
    Callback = function()
        Lighting.FogStart = 1000000
        Lighting.FogEnd = 1000000
        Lighting.Brightness = 3
        Lighting.GlobalShadows = false
        
        -- Remove as atmosferas que causam névoa visual
        for _, v in pairs(Lighting:GetChildren()) do
            if v:IsA("Atmosphere") or v:IsA("FogEnd") then
                v:Destroy()
            end
        end
        
        Rayfield:Notify({
            Title = "Remove Fog",
            Content = "Névoa removida com sucesso!",
            Duration = 3
        })
    end
})