RegisterCommand("test", function()
    print("Test command executed!")
end, false)

CreateThread(function ()
    Wait(3000)
    TriggerServerEvent('mclaw:server:test:hello', "Merhaba sunucu!")    
end)