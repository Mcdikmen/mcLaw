RegisterCommand("servertest", function()
    print("Server side hello world!")
end, false)

RegisterCommand("bilgiyaz",function (source, args, row)
    print("Gelen Args:" ..table.concat(args, " "))
    print("Ham Komut", row)
end)

RegisterNetEvent('mclaw:server:test:hello' , function (message)
    local source = source
    print("[mcLaw] Oyuncu " .. source .. " şunu gönderdi: ".. message)
end)


RegisterCommand("mclawtest", function(source)
    local player = exports['qbx_core']:GetPlayer(source)
    if not player then return end

    local job = player.PlayerData.job.name
    local grade = player.PlayerData.job.grade.level

    print(string.format("[mcLaw] Oyuncu %d | Job: %s | Grade: %d", source, job, grade))
    
end,false)