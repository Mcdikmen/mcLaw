local pendingDecision = nil   -- holds panel data while awaiting player input
local panelOpen       = false -- prevents overlapping panel calls

-- ─────────────────────────────────────────────────────────────────────────────
-- openJailPanel
-- Shows the jail decision dialog. If the player closes it without choosing,
-- pendingDecision stays set so it can be re-shown on the next spawn.
-- ─────────────────────────────────────────────────────────────────────────────
local function openJailPanel(data)
    if panelOpen then return end
    panelOpen       = true
    pendingDecision = data

    local chargeStr = #(data.charges or {}) > 0
        and ('• ' .. table.concat(data.charges, '\n• '))
        or  'Suç listelenmedi.'

    local result = lib.alertDialog({
        header  = 'Hapis — ' .. (data.fileNumber or 'Bilinmeyen Dosya'),
        content = '**Suçlamalar:**\n' .. chargeStr
            .. '\n\n**Önerilen ceza:** '
            .. (data.proposedJail or 0) .. ' dk hapis'
            .. (data.proposedFine  > 0 and (', $' .. data.proposedFine .. ' para cezası') or '')
            .. '\n\nBu suçlamaları kabul ediyor musunuz?',
        cancel = true,
        labels = { confirm = 'Suçlamaları kabul ediyorum', cancel = 'İtiraz ediyorum (masumum)' },
    })

    panelOpen = false

    if result == 'confirm' then
        pendingDecision = nil
        TriggerServerEvent('mclaw:server:jail:submitDecision', {
            jailDecisionId = data.jailDecisionId,
            accepted       = true,
        })
    elseif result == 'cancel' then
        pendingDecision = nil
        TriggerServerEvent('mclaw:server:jail:submitDecision', {
            jailDecisionId = data.jailDecisionId,
            accepted       = false,
        })
    end
    -- nil result = dismissed with Escape → pendingDecision stays, panel reopens on spawn
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Event: mclaw:client:jail:showPanel
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:client:jail:showPanel', function(data)
    openJailPanel(data)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Event: mclaw:client:jail:panelTimeout
-- Server-enforced auto-accept after Config.Jail.autoAcceptTimeout seconds.
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:client:jail:panelTimeout', function(data)
    if pendingDecision and pendingDecision.jailDecisionId == data.jailDecisionId then
        pendingDecision = nil
        panelOpen       = false
    end
    lib.notify({ type = 'inform', description = 'Süre doldu: suçlamalar otomatik olarak kabul edildi.' })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- On player loaded: ask server if there is a pending jail decision to re-show.
-- ─────────────────────────────────────────────────────────────────────────────
local function checkPendingOnSpawn()
    if Config.Jail.reopenOnSpawn then
        TriggerServerEvent('mclaw:server:jail:checkPending')
    end
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', checkPendingOnSpawn)


-- /suclamaac : police — open the accept/contest panel for the nearest arrested suspect
RegisterCommand(Config.Jail.openCommand, function()
    local playerId = lib.getClosestPlayer(GetEntityCoords(cache.ped), 4.0, false)
    if not playerId then
        lib.notify({ type = 'error', description = Mclaw.T('err_prison_no_target') })
        return
    end
    TriggerServerEvent('mclaw:server:jail:openForTarget', GetPlayerServerId(playerId))
end, false)
