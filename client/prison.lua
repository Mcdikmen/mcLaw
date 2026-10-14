-- /hukumler    : police — list sentences waiting to be carried out
-- /hapisteslim : police — deliver the nearest handcuffed convict at the prison intake

RegisterCommand(Config.Prison.listCommand, function()
    local list = lib.callback.await('mclaw:cb:prison:getPending', false) or {}
    if #list == 0 then
        lib.notify({ type = 'inform', description = Mclaw.T('sentence_list_empty') })
        return
    end
    local options = {}
    for _, s in ipairs(list) do
        options[#options + 1] = {
            title       = s.name,
            description = Mclaw.T('sentence_list_row', s.reason or '-', s.minutes, s.fine),
            readOnly    = true,
        }
    end
    lib.registerContext({ id = 'mclaw_pending_sentences', title = Mclaw.T('sentence_list_title'), options = options })
    lib.showContext('mclaw_pending_sentences')
end, false)

RegisterCommand(Config.Prison.deliverCommand, function()
    local playerId = lib.getClosestPlayer(GetEntityCoords(cache.ped), 3.0, false)
    if not playerId then
        lib.notify({ type = 'error', description = Mclaw.T('err_prison_no_target') })
        return
    end
    TriggerServerEvent('mclaw:server:prison:deliver', GetPlayerServerId(playerId))
end, false)

-- Remaining prison time: persistent text at the bottom of the screen while the
-- player is jailed. qb-prison keeps `metadata.injail` (minutes) up to date.
CreateThread(function()
    local QBCore = exports['qb-core']:GetCoreObject()
    local shown = nil
    while true do
        local pd   = QBCore.Functions.GetPlayerData()
        local left = pd and pd.metadata and tonumber(pd.metadata.injail) or 0
        if left > 0 then
            if shown ~= left then
                lib.showTextUI(Mclaw.T('prison_time_left', left), { position = 'bottom-center' })
                shown = left
            end
            Wait(2000)
        else
            if shown then
                lib.hideTextUI()
                shown = nil
            end
            Wait(5000)
        end
    end
end)
