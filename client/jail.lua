local pendingDecision = nil   -- holds panel data while awaiting player input
local panelOpen       = false -- prevents overlapping panel calls

local function submit(jailDecisionId, accepted, acknowledged)
    pendingDecision = nil
    TriggerServerEvent('mclaw:server:jail:submitDecision', {
        jailDecisionId = jailDecisionId,
        accepted       = accepted,
        acknowledged   = acknowledged,
    })
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Contest flow: long process screen → two confirmations + final choice.
-- Returns 'reject' | 'accept' | 'back' (Vazgeç / closed: return to the first screen).
-- ─────────────────────────────────────────────────────────────────────────────
local function runContestFlow()
    local proceed = lib.alertDialog({
        header   = Mclaw.T('contest_process_header'),
        content  = Mclaw.T('contest_process_text'),
        centered = true,
        cancel   = true,
        size     = 'lg',
        labels   = { confirm = Mclaw.T('contest_continue'), cancel = Mclaw.T('contest_cancel') },
    })
    if proceed ~= 'confirm' then return 'back' end

    local input = lib.inputDialog(Mclaw.T('contest_process_header'), {
        { type = 'checkbox', label = Mclaw.T('contest_ack1'), required = true },
        { type = 'checkbox', label = Mclaw.T('contest_ack2'), required = true },
        {
            type = 'select', label = Mclaw.T('contest_final_label'), required = true,
            options = {
                { value = 'reject', label = Mclaw.T('contest_final_reject') },
                { value = 'accept', label = Mclaw.T('contest_final_accept') },
            },
        },
    })
    if not input or not input[1] or not input[2] then return 'back' end
    return input[3]
end

-- ─────────────────────────────────────────────────────────────────────────────
-- openJailPanel
-- First screen: accept the charges right away, or contest them. Contesting leads
-- to the long process screen above, where the final decision is made. If the
-- player closes anything without choosing, pendingDecision stays set.
-- ─────────────────────────────────────────────────────────────────────────────
local function openJailPanel(data)
    if panelOpen then return end
    panelOpen       = true
    pendingDecision = data

    local chargeStr = #(data.charges or {}) > 0
        and ('• ' .. table.concat(data.charges, '\n• '))
        or  'Suç listelenmedi.'

    -- Loops so that "Vazgeç" on the process screen returns to this first screen.
    while true do
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

        if result == 'confirm' then
            submit(data.jailDecisionId, true, false)
            break
        elseif result == 'cancel' then
            local final = runContestFlow()
            if final == 'reject' then
                submit(data.jailDecisionId, false, true)
                break
            elseif final == 'accept' then
                submit(data.jailDecisionId, true, false)
                break
            end
            -- 'back': show the first screen again
        else
            break -- closed with Escape: decision stays pending (police can reopen with /suclamaac)
        end
    end

    panelOpen = false
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

-- Confirmation after the contest was recorded (the officer takes the statement next).
RegisterNetEvent('mclaw:client:jail:contested', function()
    lib.notify({ type = 'inform', duration = 12000, description = Mclaw.T('contest_recorded') })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- On player loaded: ask server if there is a pending jail decision to re-show
-- (only if Config.Jail.reopenOnSpawn is enabled; off by default).
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
