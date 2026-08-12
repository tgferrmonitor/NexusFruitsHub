task.spawn(function()
    local sucesso, erro = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/tgferrmonitor/NexusFruitsHub/main/new/newmain.lua"))()
    end)
    if not sucesso then
        warn("Erro ao redirecionar para o NexusProxy")
    end
end)
