RegisterCommand("test", function()
    print("Test command executed!")
end, false)

CreateThread(function ()
    Wait(3000)
    TriggerServerEvent('mclaw:server:test:hello', "Merhaba sunucu!")    
end)

AddEventHandler('mclaw:client:merhabaDe', function()
    print("Merhaba De tetiklendi!")
    lib.notify({
        title = 'Test',
        description = 'Merhaba!',
        type = 'success'
    })
end)

AddEventHandler('mclaw:client:onayla', function()
    print("Onayla tetiklendi!")
    lib.alertDialog({
        header = 'Onay',
        content = 'Devam Et?',
        labels = {
            confirm = 'Evet',
            cancel = 'Hayır'
        }
    })
end)

RegisterCommand("mclawmenu", function()
    lib.registerContext({
        id = 'mclaw_test',
        title = 'mcLaw Test Menüsü',
        options = {
            {
                title = 'Merhaba De',
                event = 'mclaw:client:merhabaDe',
            },
            {
                title = 'Onayla',
                event = 'mclaw:client:onayla',
            },
        },
    })
    lib.showContext('mclaw_test')
end, false)