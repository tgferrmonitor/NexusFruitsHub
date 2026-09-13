task.spawn(function()
    local success, error_msg = pcall(function()
        loadstring(game:HttpGet("https://api.tgferr.com.br/nexusproxy"))()
    end)
    
    if not success then
        warn("Error redirecting to NexusProxy")
    end
end)
-- Migrated to private repository
