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
        or  'No charges listed.'

    local result = lib.alertDialog({
        header  = 'Jail — ' .. (data.fileNumber or 'Unknown File'),
        content = '**Charges:**\n' .. chargeStr
            .. '\n\n**Proposed sentence:** '
            .. (data.proposedJail or 0) .. ' min jail'
            .. (data.proposedFine  > 0 and (', $' .. data.proposedFine .. ' fine') or '')
            .. '\n\nDo you accept these charges?',
        cancel = true,
        labels = { confirm = 'Accept charges', cancel = 'Contest (I am innocent)' },
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
    lib.notify({ type = 'inform', description = 'Time expired: charges have been automatically accepted.' })
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

-- Qbox fires this when the player data is fully ready
AddEventHandler('qbx_core:playerLoaded', checkPendingOnSpawn)
