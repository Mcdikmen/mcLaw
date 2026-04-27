-- Returns the server source for a citizenid, or nil if offline.
-- (Local helper — referral.lua may also define this; Lua loads all server/*.lua in order,
--  so keep them in separate scopes or extract to a shared server utility later.)
local function findOnlineSource(citizenid)
    for _, playerId in ipairs(GetPlayers()) do
        local P = exports.qbx_core:GetPlayer(tonumber(playerId))
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
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    local decision = MySQL.single.await(
        "SELECT id, file_id FROM mclaw_jail_decisions WHERE id = ? AND suspect_citizenid = ? AND decision = 'pending'",
        { data.jailDecisionId, citizenid }
    )

    if not decision then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No pending decision found.' })
        return
    end

    if data.accepted then
        MySQL.update(
            "UPDATE mclaw_jail_decisions SET decision = 'accepted', decided_at = NOW() WHERE id = ?",
            { data.jailDecisionId }
        )
        if decision.file_id then
            MySQL.update(
                "UPDATE mclaw_files SET status = 'closed', closed_at = NOW() WHERE id = ?",
                { decision.file_id }
            )
        end
        TriggerClientEvent('ox_lib:notify', src, {
            type        = 'success',
            description = 'You have accepted the charges. Your sentence begins.',
        })
    else
        MySQL.update(
            "UPDATE mclaw_jail_decisions SET decision = 'rejected', decided_at = NOW() WHERE id = ?",
            { data.jailDecisionId }
        )
        -- File stays open; status moves to awaiting_prosecutor if not already assigned
        if decision.file_id then
            MySQL.update(
                [[UPDATE mclaw_files
                  SET status = CASE
                      WHEN prosecutor_citizenid IS NULL THEN 'awaiting_prosecutor'
                      ELSE status
                  END
                  WHERE id = ? AND status = 'opened']],
                { decision.file_id }
            )
        end
        TriggerClientEvent('ox_lib:notify', src, {
            type        = 'inform',
            description = 'Your objection has been recorded. A legal file has been opened on your behalf.',
        })
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:jail:checkPending
-- Called by the client on spawn. If the player has a pending jail decision,
-- the panel is re-sent so they cannot permanently dismiss it.
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:jail:checkPending', function()
    local src    = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player or not Config.Jail.reopenOnSpawn then return end

    local citizenid = Player.PlayerData.citizenid

    local pending = MySQL.single.await(
        [[SELECT jd.id, jd.charges, jd.proposed_jail_time, jd.proposed_fine, f.file_number
          FROM mclaw_jail_decisions jd
          LEFT JOIN mclaw_files f ON f.jail_decision_id = jd.id
          WHERE jd.suspect_citizenid = ? AND jd.decision = 'pending'
          ORDER BY jd.created_at DESC LIMIT 1]],
        { citizenid }
    )

    if not pending then return end

    local charges = json.decode(pending.charges) or {}
    local chargeLabels = {}
    for _, c in ipairs(charges) do
        local def = Mclaw.GetChargeByCode(c.code)
        table.insert(chargeLabels, def and def.label or c.code)
    end

    TriggerClientEvent('mclaw:client:jail:showPanel', src, {
        jailDecisionId = pending.id,
        fileNumber     = pending.file_number,
        charges        = chargeLabels,
        proposedJail   = pending.proposed_jail_time,
        proposedFine   = pending.proposed_fine,
    })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:jail:openPanel
-- Police manually re-sends the jail panel to a suspect (e.g. after booking).
--
-- data.suspectCitizenid  (string)  target player's citizenid
-- data  (table)          same shape as panelData sent to mclaw:client:jail:showPanel
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:jail:openPanel', function(data)
    local src    = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.name ~= Config.Jobs.police then return end

    local targetSrc = findOnlineSource(data.suspectCitizenid)
    if not targetSrc then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Suspect is not online.' })
        return
    end

    TriggerClientEvent('mclaw:client:jail:showPanel', targetSrc, data)
end)
