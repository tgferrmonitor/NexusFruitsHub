-- ============================================================
-- NEXUS PROXY v1.5
-- ============================================================
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/tgferrmonitor/NexusFruitsHub/main/proxy.lua"))()

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LP               = Players.LocalPlayer

local API_BASE      = "https://api.tgferr.com.br"
local DISCORD_LINK  = "https://discord.gg/R6kXnrZ3qn"
local VALIDATE_URL  = API_BASE .. "/api/validate-key"
local HEARTBEAT_URL = API_BASE .. "/api/heartbeat"
local SCRIPT_NAME   = "proxy.lua"
local VERSION       = "v1.5"
local NX_LOGO_IMAGE = ""

local SCRIPTS = {
    {
        id    = "main",
        label = "Nexus Hub",
        sub   = "Complete BloxFruits Script",
        url   = "https://raw.githubusercontent.com/tgferrmonitor/NexusFruitsHub/main/main.lua",
    },
    {
        id    = "bounty",
        label = "Bounty Master",
        sub   = "Bounty PvP",
        url   = "https://raw.githubusercontent.com/tgferrmonitor/NexusFruitsHub/main/bountymaster.lua",
    },
    {
        id    = "onlyautofarm",
        label = "Best AutoFarm",
        sub   = "The Best AutoFarm",
        url   = "https://raw.githubusercontent.com/tgferrmonitor/NexusFruitsHub/main/testing.lua",
    },
    {
        id    = "universal",
        label = "Any Game Script",
        sub   = "Universal Script",
        url   = "https://raw.githubusercontent.com/tgferrmonitor/NexusFruitsHub/main/universal.lua",
    },
}

local Translations = {
    ["BR"] = {
        title = "Português (BR)",
        select_module = "Escolha o módulo desejado:",
        loading = "Carregando",
        success = "Sucesso",
        error = "Erro",
        invalid_key = "Chave incorreta.",
        key_too_short = "Chave muito curta.",
        validating = "VALIDANDO...",
        discord_copied = "Link copiado!",
        language_changed = "Idioma alterado para",
        close = "FECHAR",
        verify_title = "🔑 NEXUS VERIFICATION",
        verify_desc = "Sua chave expirou ou não foi encontrada.\n\nEntre no Discord, use /key e cole abaixo:",
        paste_key = "Cole sua chave aqui...",
        enter_discord = "🌐 ENTRAR NO DISCORD",
        validate_key = "✅ VALIDAR CHAVE",
    },
    ["EN"] = {
        title = "English",
        select_module = "Select desired module:",
        loading = "Loading",
        success = "Success",
        error = "Error",
        invalid_key = "Invalid key.",
        key_too_short = "Key too short.",
        validating = "VALIDATING...",
        discord_copied = "Link copied!",
        language_changed = "Language changed to",
        close = "CLOSE",
        verify_title = "🔑 NEXUS VERIFICATION",
        verify_desc = "Your key has expired or was not found.\n\nJoin our Discord, use /key and paste below:",
        paste_key = "Paste your key here...",
        enter_discord = "🌐 JOIN DISCORD",
        validate_key = "✅ VALIDATE KEY",
    },
    ["VN"] = {
        title = "Tiếng Việt",
        select_module = "Chọn module mong muốn:",
        loading = "Đang tải",
        success = "Thành công",
        error = "Lỗi",
        invalid_key = "Khóa không hợp lệ.",
        key_too_short = "Khóa quá ngắn.",
        validating = "ĐANG XÁC THỰC...",
        discord_copied = "Đã sao chép liên kết!",
        language_changed = "Đã chuyển ngôn ngữ sang",
        close = "ĐÓNG",
        verify_title = "🔑 XÁC THỰC NEXUS",
        verify_desc = "Khóa của bạn đã hết hạn hoặc không tìm thấy.\n\nVào Discord, dùng /key và dán bên dưới:",
        paste_key = "Dán khóa của bạn vào đây...",
        enter_discord = "🌐 THAM GIA DISCORD",
        validate_key = "✅ XÁC THỰC KHÓA",
    },
    ["RU"] = {
        title = "Русский",
        select_module = "Выберите нужный модуль:",
        loading = "Загрузка",
        success = "Успех",
        error = "Ошибка",
        invalid_key = "Неверный ключ.",
        key_too_short = "Ключ слишком короткий.",
        validating = "ПРОВЕРКА...",
        discord_copied = "Ссылка скопирована!",
        language_changed = "Язык изменён на",
        close = "ЗАКРЫТЬ",
        verify_title = "🔑 ВЕРИФИКАЦИЯ NEXUS",
        verify_desc = "Ваш ключ истёк или не найден.\n\nПрисоединяйтесь к Discord, используйте /key и вставьте ниже:",
        paste_key = "Вставьте ваш ключ здесь...",
        enter_discord = "🌐 ПРИСОЕДИНИТЬСЯ К DISCORD",
        validate_key = "✅ ПРОВЕРИТЬ КЛЮЧ",
    },
    ["IN"] = {
        title = "हिन्दी (India)",
        select_module = "वांछित मॉड्यूल चुनें:",
        loading = "लोड हो रहा है",
        success = "सफल",
        error = "त्रुटि",
        invalid_key = "अमान्य कुंजी।",
        key_too_short = "कुंजी बहुत छोटी है।",
        validating = "सत्यापन...",
        discord_copied = "लिंक कॉपी किया गया!",
        language_changed = "भाषा बदल दी गई",
        close = "बंद करें",
        verify_title = "🔑 NEXUS सत्यापन",
        verify_desc = "आपकी कुंजी समाप्त हो गई है या नहीं मिली।\n\nDiscord जॉइन करें, /key इस्तेमाल करें और नीचे पेस्ट करें:",
        paste_key = "अपनी कुंजी यहाँ पेस्ट करें...",
        enter_discord = "🌐 डिस्कॉर्ड जॉइन करें",
        validate_key = "✅ कुंजी सत्यापित करें",
    },
    ["NP"] = {
        title = "नेपाली (Nepal)",
        select_module = "इच्छित मोड्युल छान्नुहोस्:",
        loading = "लोड हुँदैछ",
        success = "सफल",
        error = "त्रुटि",
        invalid_key = "अवैध कुञ्जी।",
        key_too_short = "कुञ्जी धेरै छोटो छ।",
        validating = "प्रमाणीकरण...",
        discord_copied = "लिङ्क कपी गरियो!",
        language_changed = "भाषा परिवर्तन गरियो",
        close = "बन्द गर्नुहोस्",
        verify_title = "🔑 NEXUS प्रमाणीकरण",
        verify_desc = "तपाईंको कुञ्जी समाप्त भयो वा फेला परेन।\n\nDiscord मा जानुहोस्, /key प्रयोग गर्नुहोस् र तल पेस्ट गर्नुहोस्:",
        paste_key = "तपाईंको कुञ्जी यहाँ पेस्ट गर्नुहोस्...",
        enter_discord = "🌐 डिस्कोर्ड ज्वाइन गर्नुहोस्",
        validate_key = "✅ कुञ्जी प्रमाणित गर्नुहोस्",
    },
    ["ET"] = {
        title = "አማርኛ (Ethiopia)",
        select_module = "ሚፈልጉትን ሞጁል ይምረጡ:",
        loading = "በመጫን ላይ",
        success = "ተሳክቷል",
        error = "ስህተት",
        invalid_key = "ልክ ያልሆነ ቁልፍ።",
        key_too_short = "ቁልፉ በጣም አጭር ነው።",
        validating = "በማረጋገጥ ላይ...",
        discord_copied = "ሊንኩ ተቀድቷል!",
        language_changed = "ቋንቋ ተቀይሯል",
        close = "ዝጋ",
        verify_title = "🔑 NEXUS ማረጋገጫ",
        verify_desc = "የእርስዎ ቁልፍ አልቋል ወይም አልተገኘም።\n\nDiscord ይቀላቀሉ፣ /key ይጠቀሙ och ከታች ይለጥፉ:",
        paste_key = "ቁልፍዎን እዚህ ይለጥፉ...",
        enter_discord = "🌐 ዲስኮርድ ይቀላቀሉ",
        validate_key = "✅ ቁልፍ ያረጋግጡ",
    },
}

local CurrentLang = "EN"
local ActiveLabels = {}

local function T(key)
    return Translations[CurrentLang] and Translations[CurrentLang][key] or Translations["BR"][key] or key
end

local function updateAllTexts()
    for obj, translationKey in pairs(ActiveLabels) do
        if obj and obj.Parent then
            if obj:IsA("TextBox") then
                obj.PlaceholderText = T(translationKey)
            else
                obj.Text = T(translationKey)
            end
        else
            ActiveLabels[obj] = nil
        end
    end
end

local LANGUAGE_SCRIPTS = {
    { country = "Brazil",       flag = "rbxassetid://5826570404", code = "BR" },
    { country = "India",        flag = "rbxassetid://8370261668", code = "IN" },
    { country = "Vietnam",      flag = "rbxassetid://11548089657", code = "VN" },
    { country = "Nepal",        flag = "rbxassetid://4652402776", code = "NP" },
    { country = "Ethiopia",     flag = "rbxassetid://11851980287", code = "ET" },
    { country = "United States",flag = "rbxassetid://10992993183", code = "EN" },
    { country = "Russia",       flag = "rbxassetid://849048715", code = "RU" },
}


local C = {
    bg          = Color3.fromRGB(8,  12, 22),
    panel       = Color3.fromRGB(12, 18, 32),
    item        = Color3.fromRGB(15, 25, 45),
    itemHover   = Color3.fromRGB(0,  80, 160),
    accent      = Color3.fromRGB(0, 255, 240),
    border      = Color3.fromRGB(0, 140, 200),
    text        = Color3.fromRGB(220, 245, 255),
    subtext     = Color3.fromRGB(140, 190, 220),
    white       = Color3.fromRGB(255, 255, 255),
    red         = Color3.fromRGB(255, 80, 80),
    orange      = Color3.fromRGB(255, 160, 0),
}

local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

local function tween(obj, t, props)
    TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
end

local function corner(r, p)
    local c = Instance.new("UICorner", p)
    c.CornerRadius = UDim.new(0, r)
    return c
end

local function stroke(color, thickness, p, trans)
    local s = Instance.new("UIStroke", p)
    s.Color = color
    s.Thickness = thickness or 1.5
    s.Transparency = trans or 0
    return s
end

local function gradient(parent)
    local grad = Instance.new("UIGradient", parent)
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 35, 55)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 12, 22))
    }
    grad.Rotation = 90
    return grad
end

local function addAspect(parent, ratio)
    local aspect = Instance.new("UIAspectRatioConstraint", parent)
    aspect.AspectRatio = ratio or 1
    return aspect
end

local function isSmallViewport()
    local camera = workspace.CurrentCamera
    if not camera then return UserInputService.TouchEnabled end
    local viewport = camera.ViewportSize
    return UserInputService.TouchEnabled or viewport.X < 760 or viewport.Y < 520
end

local function addNxWatermark(parent, compact)
    if NX_LOGO_IMAGE ~= "" then
        local image = Instance.new("ImageLabel", parent)
        image.Name = "NXWatermark"
        image.BackgroundTransparency = 1
        image.Image = NX_LOGO_IMAGE
        image.ImageTransparency = 0.84
        image.ScaleType = Enum.ScaleType.Fit
        image.Rotation = -12
        image.Size = compact and UDim2.new(0, 178, 0, 178) or UDim2.new(0, 250, 0, 250)
        image.Position = compact and UDim2.new(1, -205, 1, -195) or UDim2.new(1, -290, 1, -282)
        image.ZIndex = 1
        return image
    end

    local mark = Instance.new("TextLabel", parent)
    mark.Name = "NXWatermark"
    mark.BackgroundTransparency = 1
    mark.Text = "NX"
    mark.Font = Enum.Font.GothamBlack
    mark.TextSize = compact and 100 or 148
    mark.TextColor3 = C.accent
    mark.TextTransparency = 0.88
    mark.TextStrokeColor3 = C.accent
    mark.TextStrokeTransparency = 0.75
    mark.Rotation = -16
    mark.Size = compact and UDim2.new(0, 190, 0, 128) or UDim2.new(0, 280, 0, 180)
    mark.Position = compact and UDim2.new(1, -210, 1, -152) or UDim2.new(1, -310, 1, -205)
    mark.ZIndex = 1
    return mark
end

local function addCircuitLines(parent)
    local lines = {
        {UDim2.new(0, 82, 0, 26), UDim2.new(1, -112, 0, 34)},
        {UDim2.new(0, 82, 1, -38), UDim2.new(1, -132, 0, 2)},
        {UDim2.new(1, -178, 0, 88), UDim2.new(0, 118, 0, 2)},
    }
    for _, data in ipairs(lines) do
        local line = Instance.new("Frame", parent)
        line.BackgroundColor3 = C.border
        line.BackgroundTransparency = 0.62
        line.BorderSizePixel = 0
        line.Position = data[1]
        line.Size = data[2]
        line.ZIndex = 1
        corner(2, line)
    end
end

local function lbl(props, parent)
    local l = Instance.new("TextLabel", parent)
    l.BackgroundTransparency = 1
    l.Font = props.Font or Enum.Font.Gotham
    l.TextSize = props.TextSize or 13
    l.TextColor3 = props.TextColor3 or C.text
    l.Text = props.Text or ""
    l.Size = props.Size or UDim2.new(1, 0, 1, 0)
    l.Position = props.Position or UDim2.new(0, 0, 0, 0)
    l.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    l.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
    l.TextWrapped = props.TextWrapped or false
    l.ZIndex = props.ZIndex or 1
    if props.TranslationKey then ActiveLabels[l] = props.TranslationKey end
    return l
end

local function notify(title, msg, color)
    task.spawn(function()
        local pgui = LP:WaitForChild("PlayerGui")
        if not pgui:FindFirstChild("NexusNotifContainer") then
            local sc = Instance.new("ScreenGui", pgui)
            sc.Name = "NexusNotifContainer"
            sc.ResetOnSpawn = false
            sc.DisplayOrder = 1000
            local f = Instance.new("Frame", sc)
            f.Name = "Container"
            f.Size = UDim2.new(0, 280, 1, -20)
            f.Position = UDim2.new(1, -290, 0, 20)
            f.BackgroundTransparency = 1
            local ul = Instance.new("UIListLayout", f)
            ul.Padding = UDim.new(0, 8)
            ul.SortOrder = Enum.SortOrder.LayoutOrder
        end

        local container = pgui.NexusNotifContainer:FindFirstChild("Container")
        if not container then return end

        local n = Instance.new("Frame", container)
        n.Size = UDim2.new(1, 0, 0, 68)
        n.BackgroundColor3 = C.panel
        n.ClipsDescendants = true
        corner(12, n)
        stroke(C.accent, 1.5, n)
        gradient(n)

        local bar = Instance.new("Frame", n)
        bar.Size = UDim2.new(0, 4, 1, 0)
        bar.BackgroundColor3 = color or C.accent
        corner(2, bar)

        lbl({Text = title, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.white, Size = UDim2.new(1, -70, 0, 22), Position = UDim2.new(0, 16, 0, 8)}, n)
        lbl({Text = msg, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.subtext, Size = UDim2.new(1, -70, 0, 22), Position = UDim2.new(0, 16, 0, 32)}, n)

        n.Position = UDim2.new(1, 20, 0, 0)
        tween(n, 0.4, {Position = UDim2.new(0, 0, 0, 0)})
        task.wait(4.5)
        tween(n, 0.4, {Position = UDim2.new(1, 20, 0, 0)})
        task.wait(0.5)
        pcall(function() n:Destroy() end)
    end)
end

task.spawn(function()
    while true do
        task.wait(19 * 60)
        VirtualInputManager:SendKeyEvent(true, "W", false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, "W", false, game)
    end
end)

local function sendHeartbeat(scriptId)
    pcall(function()
        local level = "?"
        pcall(function()
            if LP:FindFirstChild("Data") and LP.Data:FindFirstChild("Level") then
                level = tostring(LP.Data.Level.Value)
            end
        end)
        requestFunc({
            Url = HEARTBEAT_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                roblox_id = tostring(LP.UserId),
                roblox_name = tostring(LP.Name),
                level = level,
                using_script = scriptId or SCRIPT_NAME,
            })
        })
    end)
end

local function startHeartbeat(scriptId)
    task.spawn(function()
        while true do
            sendHeartbeat(scriptId)
            task.wait(300)
        end
    end)
end

local function launchScript(script)
    local pgui = LP:WaitForChild("PlayerGui")
    for _, name in ipairs({"NexusProxy", "NexusNotifContainer"}) do
        local g = pgui:FindFirstChild(name)
        if g then g:Destroy() end
    end

    startHeartbeat(script.id or "language")
    notify("Nexus", T("loading") .. " " .. (script.label or script.country) .. "...", C.accent)

    task.spawn(function()
        local ok, err = pcall(function()
            loadstring(game:HttpGet(script.url))()
        end)
        if not ok then
            notify(T("error"), "Falha ao carregar: " .. tostring(err), C.red)
        end
    end)
end

-- CHECK ACCESS
local function checkAccess(callback)
    pcall(function()
        local res = requestFunc({
            Url = API_BASE .. "/api/check-access/" .. tostring(LP.UserId),
            Method = "GET",
            Headers = {["accept"] = "application/json"},
        })
        if res and res.StatusCode == 200 then
            local data = HttpService:JSONDecode(res.Body)
            callback(data.has_valid_access == true, data.bypass == true, data.message or "")
            return
        end
        callback(false, false, "Erro ao contatar API")
    end)
end

local function styleFlagButton(button, lang, active)
    button.BackgroundColor3 = active and Color3.fromRGB(0, 75, 110) or C.item
    button.BackgroundTransparency = active and 0.04 or 0.18
    local flagGlow = button:FindFirstChild("FlagGlow")
    if flagGlow then flagGlow.Transparency = active and 0.05 or 0.58 end
    local code = button:FindFirstChild("Code")
    if code then code.TextColor3 = active and C.white or C.subtext end
end

local function createFlagSidebar(parent, compact)
    local sidebar = Instance.new("Frame", parent)
    sidebar.Name = "FlagSidebar"
    sidebar.Size = compact and UDim2.new(0, 58, 1, -26) or UDim2.new(0, 74, 1, -28)
    sidebar.Position = compact and UDim2.new(0, 12, 0, 13) or UDim2.new(0, 16, 0, 14)
    sidebar.BackgroundColor3 = Color3.fromRGB(6, 16, 30)
    sidebar.BorderSizePixel = 0
    sidebar.ZIndex = 20
    corner(compact and 28 or 34, sidebar)
    stroke(C.accent, 1.5, sidebar, 0.25)

    local sideGradient = Instance.new("UIGradient", sidebar)
    sideGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(5, 22, 38)),
        ColorSequenceKeypoint.new(0.52, Color3.fromRGB(10, 30, 54)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 9, 20))
    }
    sideGradient.Rotation = 90

    local brand = Instance.new("TextLabel", sidebar)
    brand.BackgroundTransparency = 1
    brand.Text = "NX"
    brand.Font = Enum.Font.GothamBlack
    brand.TextSize = compact and 18 or 22
    brand.TextColor3 = C.accent
    brand.Size = UDim2.new(1, 0, 0, compact and 34 or 42)
    brand.Position = UDim2.new(0, 0, 0, 8)
    brand.ZIndex = 22

    local scroll = Instance.new("ScrollingFrame", sidebar)
    scroll.Name = "FlagList"
    scroll.Size = UDim2.new(1, -8, 1, compact and -56 or -66)
    scroll.Position = UDim2.new(0, 4, 0, compact and 48 or 58)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 0
    scroll.ZIndex = 21

    local listLayout = Instance.new("UIListLayout", scroll)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Padding = UDim.new(0, compact and 9 or 11)

    local buttons = {}
    local function refresh()
        for _, item in ipairs(buttons) do
            styleFlagButton(item.button, item.lang, CurrentLang == item.lang.code)
        end
    end

    for _, lang in ipairs(LANGUAGE_SCRIPTS) do
        local size = compact and 46 or 52
        local option = Instance.new("TextButton", scroll)
        option.Name = lang.code .. "FlagButton"
        option.Size = UDim2.new(0, size, 0, size)
        option.BackgroundColor3 = C.item
        option.Text = ""
        option.AutoButtonColor = false
        option.ZIndex = 22
        corner(size, option)
        stroke(C.border, CurrentLang == lang.code and 2 or 1, option, 0.08)

        local glow = Instance.new("Frame", option)
        glow.Name = "FlagGlow"
        glow.Size = UDim2.new(1, 6, 1, 6)
        glow.Position = UDim2.new(0, -3, 0, -3)
        glow.BackgroundColor3 = C.accent
        glow.BackgroundTransparency = CurrentLang == lang.code and 0.05 or 0.58
        glow.BorderSizePixel = 0
        glow.ZIndex = 21
        corner(size + 6, glow)

        local flag = Instance.new("ImageLabel", option)
        flag.Name = "Flag"
        flag.Size = UDim2.new(1, -8, 1, -8)
        flag.Position = UDim2.new(0, 4, 0, 4)
        flag.BackgroundTransparency = 1
        flag.Image = lang.flag
        flag.ScaleType = Enum.ScaleType.Crop
        flag.ZIndex = 24
        corner(size, flag)
        addAspect(flag, 1)

        local code = Instance.new("TextLabel", option)
        code.Name = "Code"
        code.Size = UDim2.new(1, 0, 0, 14)
        code.Position = UDim2.new(0, 0, 1, -15)
        code.BackgroundColor3 = Color3.fromRGB(3, 8, 16)
        code.BackgroundTransparency = 0.18
        code.Text = lang.code
        code.TextColor3 = C.subtext
        code.Font = Enum.Font.GothamBlack
        code.TextSize = 9
        code.ZIndex = 25
        corner(7, code)

        option.MouseEnter:Connect(function()
            tween(option, 0.12, {BackgroundColor3 = C.itemHover})
            tween(glow, 0.12, {BackgroundTransparency = 0.12})
        end)
        option.MouseLeave:Connect(function() styleFlagButton(option, lang, CurrentLang == lang.code) end)
        option.MouseButton1Click:Connect(function()
            CurrentLang = lang.code
            updateAllTexts()
            refresh()
            local langTitle = Translations[lang.code] and Translations[lang.code].title or lang.country
            notify("Nexus", (Translations[CurrentLang].language_changed or "Changed to") .. " " .. langTitle, C.accent)
        end)

        table.insert(buttons, {button = option, lang = lang})
    end

    task.defer(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 12)
    end)

    refresh()
    return sidebar
end


-- TELA PRINCIPAL
local function showScriptSelector()
    local pgui = LP:WaitForChild("PlayerGui")
    if pgui:FindFirstChild("NexusProxy") then pgui.NexusProxy:Destroy() end

    local sc = Instance.new("ScreenGui", pgui)
    sc.Name = "NexusProxy"
    sc.ResetOnSpawn = false
    sc.DisplayOrder = 100

    local compact = isSmallViewport()
    local mainWidth = compact and 430 or 560
    local mainHeight = compact and 430 or 500

    local main = Instance.new("Frame", sc)
    main.Size = UDim2.new(0, mainWidth, 0, mainHeight)
    main.Position = UDim2.new(0.5, -mainWidth / 2, 0.5, -mainHeight / 2)
    main.BackgroundColor3 = C.bg
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    corner(compact and 28 or 38, main)
    stroke(C.accent, 2, main)
    gradient(main)
    addCircuitLines(main)
    addNxWatermark(main, compact)
    createFlagSidebar(main, compact)

    local contentX = compact and 82 or 108
    local contentRight = 24

    local header = Instance.new("Frame", main)
    header.Size = UDim2.new(1, -(contentX + contentRight), 0, compact and 104 or 116)
    header.Position = UDim2.new(0, contentX, 0, compact and 16 or 22)
    header.BackgroundTransparency = 1
    header.ZIndex = 5

    local nxBadge = Instance.new("Frame", header)
    nxBadge.Size = UDim2.new(0, compact and 72 or 88, 0, compact and 72 or 88)
    nxBadge.Position = UDim2.new(0, 0, 0, 2)
    nxBadge.BackgroundColor3 = Color3.fromRGB(4, 16, 32)
    nxBadge.BorderSizePixel = 0
    nxBadge.ZIndex = 6
    corner(compact and 22 or 26, nxBadge)
    stroke(C.accent, 1.5, nxBadge, 0.18)

    if NX_LOGO_IMAGE ~= "" then
        local nxImage = Instance.new("ImageLabel", nxBadge)
        nxImage.BackgroundTransparency = 1
        nxImage.Size = UDim2.new(1, -10, 1, -10)
        nxImage.Position = UDim2.new(0, 5, 0, 5)
        nxImage.Image = NX_LOGO_IMAGE
        nxImage.ScaleType = Enum.ScaleType.Fit
        nxImage.ZIndex = 7
    else
        local nxText = Instance.new("TextLabel", nxBadge)
        nxText.BackgroundTransparency = 1
        nxText.Size = UDim2.new(1, 0, 1, 0)
        nxText.Text = "NX"
        nxText.Font = Enum.Font.GothamBlack
        nxText.TextSize = compact and 30 or 38
        nxText.TextColor3 = C.accent
        nxText.TextStrokeColor3 = Color3.fromRGB(0, 40, 70)
        nxText.TextStrokeTransparency = 0.28
        nxText.ZIndex = 7
    end

    lbl({Text = T("title"), TranslationKey = "title", Font = Enum.Font.GothamBlack, TextSize = compact and 19 or 25, TextColor3 = C.accent, Size = UDim2.new(1, compact and -84 or -105, 0, 34), Position = UDim2.new(0, compact and 84 or 104, 0, compact and 10 or 14), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7}, header)
    lbl({Text = "Nexus Hub Launcher", Font = Enum.Font.GothamSemibold, TextSize = compact and 11 or 13, TextColor3 = C.subtext, Size = UDim2.new(1, compact and -84 or -105, 0, 24), Position = UDim2.new(0, compact and 84 or 104, 0, compact and 44 or 52), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7}, header)

    local sep = Instance.new("Frame", main)
    sep.Size = UDim2.new(1, -(contentX + contentRight), 0, 2)
    sep.Position = UDim2.new(0, contentX, 0, compact and 128 or 150)
    sep.BackgroundColor3 = C.accent
    sep.ZIndex = 5
    stroke(C.accent, 1, sep, 0.6)

    lbl({Text = T("select_module"), TranslationKey = "select_module", Font = Enum.Font.Gotham, TextSize = compact and 12 or 14, TextColor3 = C.subtext, Size = UDim2.new(1, -(contentX + contentRight), 0, 30), Position = UDim2.new(0, contentX, 0, compact and 136 or 160), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6}, main)

    local scroll = Instance.new("ScrollingFrame", main)
    scroll.Size = UDim2.new(1, -(contentX + contentRight), 1, compact and -192 or -220)
    scroll.Position = UDim2.new(0, contentX, 0, compact and 172 or 198)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 5
    scroll.ScrollBarImageColor3 = C.accent
    scroll.BorderSizePixel = 0
    scroll.ZIndex = 5

    local listLayout = Instance.new("UIListLayout", scroll)
    listLayout.Padding = UDim.new(0, 12)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    for _, script in ipairs(SCRIPTS) do
        local btn = Instance.new("TextButton", scroll)
        btn.Size = UDim2.new(1, 0, 0, compact and 70 or 78)
        btn.BackgroundColor3 = C.item
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.ZIndex = 6
        corner(compact and 16 or 22, btn)
        stroke(C.border, 1.5, btn)

        local accentBar = Instance.new("Frame", btn)
        accentBar.Size = UDim2.new(0, 6, 1, -20)
        accentBar.Position = UDim2.new(0, 12, 0, 10)
        accentBar.ZIndex = 7
        accentBar.BackgroundColor3 = C.accent
        corner(3, accentBar)

        lbl({Text = script.label, Font = Enum.Font.GothamBold, TextSize = compact and 14 or 16, TextColor3 = C.text, Size = UDim2.new(1, -90, 0, 32), Position = UDim2.new(0, 32, 0, compact and 10 or 12), ZIndex = 7}, btn)
        lbl({Text = script.sub, Font = Enum.Font.Gotham, TextSize = compact and 11 or 12, TextColor3 = C.subtext, Size = UDim2.new(1, -90, 0, 24), Position = UDim2.new(0, 32, 0, compact and 38 or 42), ZIndex = 7}, btn)

        lbl({Text = "→", Font = Enum.Font.GothamBold, TextSize = 24, TextColor3 = C.accent, Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(1, -45, 0, 0), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7}, btn)

        btn.MouseEnter:Connect(function() tween(btn, 0.15, {BackgroundColor3 = C.itemHover}) end)
        btn.MouseLeave:Connect(function() tween(btn, 0.15, {BackgroundColor3 = C.item}) end)
        btn.MouseButton1Click:Connect(function() launchScript(script) end)
    end

    scroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 30)

    -- Close Button
    local closeBtn = Instance.new("TextButton", main)
    closeBtn.Size = UDim2.new(0, 44, 0, 44)
    closeBtn.Position = UDim2.new(1, -58, 0, 14)
    closeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = C.subtext
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 18
    closeBtn.ZIndex = 30
    corner(22, closeBtn)
    stroke(C.red, 1, closeBtn, 0.7)

    closeBtn.MouseEnter:Connect(function() tween(closeBtn, 0.1, {BackgroundColor3 = C.red, TextColor3 = C.white}) end)
    closeBtn.MouseLeave:Connect(function() tween(closeBtn, 0.1, {BackgroundColor3 = Color3.fromRGB(30,30,40), TextColor3 = C.subtext}) end)
    closeBtn.MouseButton1Click:Connect(function() sc:Destroy() end)

    main.BackgroundTransparency = 1
    tween(main, 0.45, {BackgroundTransparency = 0})
end

-- TELA DE VERIFICAÇÃO
local function showKeyPopup()
    local pgui = LP:WaitForChild("PlayerGui")
    if pgui:FindFirstChild("NexusProxy") then pgui.NexusProxy:Destroy() end

    local sc = Instance.new("ScreenGui", pgui)
    sc.Name = "NexusProxy"
    sc.ResetOnSpawn = false
    sc.DisplayOrder = 100
    
    local compact = isSmallViewport()
    local mainWidth = compact and 430 or 520
    local mainHeight = compact and 410 or 440

    local main = Instance.new("Frame", sc)
    main.Size = UDim2.new(0, mainWidth, 0, mainHeight)
    main.Position = UDim2.new(0.5, -mainWidth / 2, 0.5, -mainHeight / 2)
    main.BackgroundColor3 = C.bg
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    corner(compact and 28 or 38, main)
    stroke(C.accent, 2, main)
    gradient(main)
    addCircuitLines(main)
    addNxWatermark(main, compact)
    createFlagSidebar(main, compact)

    local contentX = compact and 82 or 108
    local contentRight = 24

    lbl({Text = T("verify_title"), TranslationKey = "verify_title", Font = Enum.Font.GothamBlack, TextSize = compact and 17 or 21, TextColor3 = C.accent, Size = UDim2.new(1, -(contentX + contentRight), 0, 54), Position = UDim2.new(0, contentX, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6}, main)

    local sep = Instance.new("Frame", main)
    sep.Size = UDim2.new(1, -(contentX + contentRight), 0, 2)
    sep.Position = UDim2.new(0, contentX, 0, 78)
    sep.BackgroundColor3 = C.accent

    lbl({Text = T("verify_desc"), TranslationKey = "verify_desc", Font = Enum.Font.Gotham, TextSize = compact and 12 or 13, TextColor3 = C.subtext, Size = UDim2.new(1, -(contentX + contentRight), 0, 86), Position = UDim2.new(0, contentX, 0, 94), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6}, main)

    local keyBox = Instance.new("TextBox", main)
    keyBox.Text = ""
    keyBox.Size = UDim2.new(1, -(contentX + contentRight), 0, 52)
    keyBox.Position = UDim2.new(0, contentX, 0, 188)
    keyBox.PlaceholderText = T("paste_key")
    keyBox.BackgroundColor3 = C.panel
    keyBox.TextColor3 = C.text
    keyBox.PlaceholderColor3 = C.subtext
    keyBox.TextSize = 15
    keyBox.Font = Enum.Font.Gotham
    keyBox.ClearTextOnFocus = false
    keyBox.ZIndex = 6
    ActiveLabels[keyBox] = "paste_key"
    corner(12, keyBox)
    stroke(C.border, 1.5, keyBox)

    local discordBtn = Instance.new("TextButton", main)
    discordBtn.Size = UDim2.new(1, -(contentX + contentRight), 0, 46)
    discordBtn.Position = UDim2.new(0, contentX, 0, 254)
    discordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    discordBtn.Text = T("enter_discord")
    discordBtn.Font = Enum.Font.GothamBold
    discordBtn.TextSize = 14
    discordBtn.TextColor3 = C.white
    discordBtn.ZIndex = 6
    ActiveLabels[discordBtn] = "enter_discord"
    corner(12, discordBtn)

    local validateBtn = Instance.new("TextButton", main)
    validateBtn.Size = UDim2.new(1, -(contentX + contentRight), 0, 52)
    validateBtn.Position = UDim2.new(0, contentX, 0, 312)
    validateBtn.BackgroundColor3 = C.accent
    validateBtn.Text = T("validate_key")
    validateBtn.Font = Enum.Font.GothamBold
    validateBtn.TextSize = 15
    validateBtn.TextColor3 = Color3.fromRGB(10, 15, 20)
    validateBtn.ZIndex = 6
    ActiveLabels[validateBtn] = "validate_key"
    corner(12, validateBtn)

    local closeBtn = Instance.new("TextButton", main)
    closeBtn.Size = UDim2.new(0, 44, 0, 44)
    closeBtn.Position = UDim2.new(1, -58, 0, 14)
    closeBtn.BackgroundColor3 = C.red
    closeBtn.Text = T("close")
    closeBtn.Font = Enum.Font.GothamBlack
    closeBtn.TextSize = 16
    closeBtn.TextColor3 = C.white
    closeBtn.ZIndex = 30
    ActiveLabels[closeBtn] = "close"
    corner(22, closeBtn)

    discordBtn.MouseButton1Click:Connect(function()
        if setclipboard then setclipboard(DISCORD_LINK) end
        notify("Discord", T("discord_copied"), C.accent)
    end)

    validateBtn.MouseButton1Click:Connect(function()
        local key = keyBox.Text:match("^%s*(.-)%s*$")
        if #key < 8 then 
            notify(T("error"), T("key_too_short"), C.red) 
            return 
        end

        validateBtn.Text = T("validating")
        validateBtn.BackgroundColor3 = C.orange

        task.spawn(function()
            local ok = false
            pcall(function()
                local res = requestFunc({Url = VALIDATE_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({key = key, roblox_id = tostring(LP.UserId)})} )
                if res and res.StatusCode == 200 then
                    local data = HttpService:JSONDecode(res.Body)
                    ok = data.valid == true
                end
            end)

            if ok then
                notify(T("success"), "Chave validada!", C.accent)
                task.wait(1)
                sc:Destroy()
                showScriptSelector()
            else
                notify(T("error"), T("invalid_key"), C.red)
                validateBtn.Text = T("validate_key")
                validateBtn.BackgroundColor3 = C.accent
            end
        end)
    end)

    closeBtn.MouseButton1Click:Connect(function() sc:Destroy() end)

    main.BackgroundTransparency = 1
    tween(main, 0.4, {BackgroundTransparency = 0})
end

-- [14] INICIALIZAÇÃO
print("[NEXUS PROXY] Verificando acesso para", LP.Name)
sendHeartbeat(SCRIPT_NAME)

checkAccess(function(hasAccess, isBypass, msg)
    if hasAccess or isBypass then
        showScriptSelector()
    else
        showKeyPopup()
    end
end)

print("[NEXUS PROXY] " .. VERSION .. " carregado com sucesso")