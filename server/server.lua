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
