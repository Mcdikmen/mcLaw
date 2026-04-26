RegisterCommand("test", function()
    print("Test command executed!")
end, false)

CreateThread(function ()
    Wait(3000)
    TriggerServerEvent('mclaw:server:test:hello', "Merhaba sunucu!")    
end)

RegisterCommand("mclawmenu", function()
    lib.registerContext({
        id = 'mclaw_test',
        title = 'mcLaw Test Menüsü',
        options = {
            {
                title = 'Merhaba De',
                onselect = function()
                    lib.notify({
                        title = 'Test',
                        description = 'Merhaba!',
                        type = 'success'
                    })
                end,
                event = 'mclaw:client:option1'
            },
            {
                title = 'Onayla',
                onselect = function()
                    local result = lib.alertDialog({
                        header = 'Onay',
                        content = 'Devam Et?',
                        labels = {
                            confirm = 'Evet',
                            cancel = 'Hayır'
                        }
                    })
                    print("Cevap:", result)
                end,                
            },
        },
    })
    lib.showContext('mclaw_test')
end, false)