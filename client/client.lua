RegisterCommand("mclaw", function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'show' })
end, false)

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb({})
end)