-- Returns the server source for a citizenid, or nil if offline.
-- (Local helper — referral.lua may also define this; Lua loads all server/*.lua in order,
--  so keep them in separate scopes or extract to a shared server utility later.)
local function findOnlineSource(citizenid)
    for _, playerId in ipairs(GetPlayers()) do
        local P = Mclaw.GetPlayer(tonumber(playerId))
        if P and P.PlayerData.citizenid == citizenid then
            return tonumber(playerId)
        end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:jail:submitDecision
-- Called by the suspect after interacting with the jail panel.
--
-- data.jailDecisionId  (number)   id of the mclaw_jail_decisions row
-- data.accepted        (boolean)  true = accepts charges, false = contests
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:jail:submitDecision', function(data)
    local src    = source
    local Player = Mclaw.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    local decision = MySQL.single.await(
        "SELECT id, file_id, officer_citizenid, proposed_jail_time, proposed_fine FROM mclaw_jail_decisions WHERE id = ? AND suspect_citizenid = ? AND decision = 'pending'",
        { data.jailDecisionId, citizenid }
    )

    if not decision then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Bekleyen karar bulunamadı.' })
        return
    end

    if data.accepted then
        MySQL.update(
            "UPDATE mclaw_jail_decisions SET decision = 'accepted', decided_at = NOW() WHERE id = ?",
            { data.jailDecisionId }
        )
        -- The file is opened now (after the decision) and closed right away: accepted.
        local fileId, fileNumber = Mclaw.CreateReferralFile(decision.id)
        if fileId then
            MySQL.update("UPDATE mclaw_files SET status = 'closed', closed_at = NOW() WHERE id = ?", { fileId })
        end
        Mclaw.CreateSentence(fileId, citizenid, decision.proposed_jail_time, decision.proposed_fine, 'accepted', fileNumber)
        TriggerClientEvent('ox_lib:notify', src, {
            type        = 'success',
            description = Mclaw.T('jail_accepted_notify'),
        })
    else
        -- Contesting requires the explicit acknowledgement screen (both checkboxes + final choice).
        if not data.acknowledged then return end

        MySQL.update(
            "UPDATE mclaw_jail_decisions SET decision = 'rejected', decided_at = NOW() WHERE id = ?",
            { data.jailDecisionId }
        )
        -- The file stays 'opened' with no prosecutor until the officer confirms
        -- the investigation (mclaw:server:referral:startInvestigation).
        local _, fileNumber = Mclaw.CreateReferralFile(decision.id)
        fileNumber = fileNumber or '-'
        local suspectName = Mclaw.GetCharName(citizenid) or citizenid
        TriggerClientEvent('mclaw:client:jail:contested', src, fileNumber)

        -- Tell the referring officer first, then every on-duty police officer
        local told = {}
        local function tell(officerSrc)
            if officerSrc and not told[officerSrc] then
                told[officerSrc] = true
                TriggerClientEvent('ox_lib:notify', officerSrc, {
                    type = 'inform', duration = 15000,
                    title = 'Şüpheli İtiraz Etti',
                    description = Mclaw.T('contest_notify_police', suspectName, fileNumber),
                })
            end
        end
        local openedByP = decision.officer_citizenid and Mclaw.GetPlayer(decision.officer_citizenid)
        if openedByP then tell(openedByP.PlayerData.source) end
        for _, pid in ipairs(GetPlayers()) do
            local P = Mclaw.GetPlayer(tonumber(pid))
            if P and Mclaw.GetRole(P) == Config.Jobs.police and P.PlayerData.job.onduty then tell(tonumber(pid)) end
        end
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Pending plea panel
-- The accept/contest panel is shown to the suspect only when a police officer
-- is with them (referral submitted next to the suspect, or the officer runs
-- /suclamaac after arresting them). Nothing pops up remotely.
-- ─────────────────────────────────────────────────────────────────────────────
local function sendPendingPanel(targetSrc, citizenid)
    local pending = MySQL.single.await(
        [[SELECT jd.id, jd.charges, jd.proposed_jail_time, jd.proposed_fine, f.file_number
          FROM mclaw_jail_decisions jd
          LEFT JOIN mclaw_files f ON f.jail_decision_id = jd.id
          WHERE jd.suspect_citizenid = ? AND jd.decision = 'pending'
          ORDER BY jd.created_at DESC LIMIT 1]],
        { citizenid }
    )
    if not pending then return false end

    local charges = json.decode(pending.charges) or {}
    local chargeLabels = {}
    for _, c in ipairs(charges) do
        local def = Mclaw.GetChargeByCode(c.code)
        table.insert(chargeLabels, def and def.label or c.code)
    end

    TriggerClientEvent('mclaw:client:jail:showPanel', targetSrc, {
        jailDecisionId = pending.id,
        fileNumber     = pending.file_number,
        charges        = chargeLabels,
        proposedJail   = pending.proposed_jail_time,
        proposedFine   = pending.proposed_fine,
    })
    return true
end

-- Re-show on login only if explicitly enabled (off by default).
RegisterNetEvent('mclaw:server:jail:checkPending', function()
    local src    = source
    local Player = Mclaw.GetPlayer(src)
    if not Player or not Config.Jail.reopenOnSpawn then return end
    sendPendingPanel(src, Player.PlayerData.citizenid)
end)

-- Police opens the plea panel for the nearest suspect (/suclamaac).
RegisterNetEvent('mclaw:server:jail:openForTarget', function(targetId)
    local src     = source
    targetId      = tonumber(targetId)
    local officer = Mclaw.GetPlayer(src)
    local target  = targetId and Mclaw.GetPlayer(targetId)
    if not officer or Mclaw.GetRole(officer) ~= Config.Jobs.police then return end
    if not target then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Mclaw.T('err_prison_no_target') })
    end
    if not Mclaw.InPleaZone(GetEntityCoords(GetPlayerPed(src))) then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Mclaw.T('err_plea_not_in_zone') })
    end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetId))) > 4.0 then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Mclaw.T('err_prison_too_far') })
    end
    if not sendPendingPanel(targetId, target.PlayerData.citizenid) then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Mclaw.T('err_jail_no_pending') })
    end
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = Mclaw.T('jail_panel_opened') })
end)

-- Used by referral.lua right after a report is filed.
Mclaw.SendPendingPanel = sendPendingPanel
