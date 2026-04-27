Mclaw = Mclaw or {}

-- Returns the next sequence number for a given year by counting existing files.
local function getNextFileSequence(year)
    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM mclaw_files WHERE YEAR(created_at) = ?',
        { year }
    )
    return (count or 0) + 1
end

-- Finds the online prosecutor with the fewest active files.
-- Returns citizenid (string|nil), source (number|nil).
local function pickProsecutor()
    local candidates = {}
    for _, playerId in ipairs(GetPlayers()) do
        local P = exports.qbx_core:GetPlayer(tonumber(playerId))
        if P and P.PlayerData.job.name == Config.Jobs.prosecutor then
            local cid      = P.PlayerData.citizenid
            local active   = MySQL.scalar.await(
                "SELECT COUNT(*) FROM mclaw_files WHERE prosecutor_citizenid = ? AND status NOT IN ('closed','archived','verdict_issued')",
                { cid }
            )
            table.insert(candidates, { source = tonumber(playerId), citizenid = cid, active = active or 0 })
        end
    end
    if #candidates == 0 then return nil, nil end
    table.sort(candidates, function(a, b) return a.active < b.active end)
    return candidates[1].citizenid, candidates[1].source
end

-- Resolves a server source to its citizenid; returns nil if player not found.
local function getCitizenid(src)
    local P = exports.qbx_core:GetPlayer(src)
    return P and P.PlayerData.citizenid or nil
end

-- Returns the server source for a citizenid, or nil if offline.
local function findSource(citizenid)
    for _, playerId in ipairs(GetPlayers()) do
        local P = exports.qbx_core:GetPlayer(tonumber(playerId))
        if P and P.PlayerData.citizenid == citizenid then
            return tonumber(playerId)
        end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:referral:submit
-- Submitted by a police officer. Creates referral report, opens a file,
-- assigns a prosecutor, and triggers the suspect's jail decision panel.
--
-- data.suspectSource     (number)  server source of the suspect
-- data.charges           (table)   array of { code = 'charge_code' }
-- data.narrative         (string)  officer's written narrative
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:referral:submit', function(data)
    local src    = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.name ~= Config.Jobs.police then return end

    local officerCid  = Player.PlayerData.citizenid
    local suspectCid  = getCitizenid(tonumber(data.suspectSource))

    if not suspectCid then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Suspect is not online.' })
        return
    end

    if not data.charges or #data.charges == 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'At least one charge is required.' })
        return
    end

    if not data.narrative or #data.narrative < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Narrative is too short.' })
        return
    end

    -- Validate every charge code exists
    for _, c in ipairs(data.charges) do
        if not Mclaw.GetChargeByCode(c.code) then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Unknown charge code: ' .. tostring(c.code) })
            return
        end
    end

    local sentence = Mclaw.CalculateSentence(data.charges)

    -- Insert referral report
    local reportId = MySQL.insert.await(
        'INSERT INTO mclaw_referral_reports (suspect_citizenid, officer_citizenid, narrative, charges) VALUES (?, ?, ?, ?)',
        { suspectCid, officerCid, data.narrative, json.encode(data.charges) }
    )

    -- Generate file number
    local year = tonumber(os.date('%Y'))
    local seq  = getNextFileSequence(year)
    local fileNumber = Mclaw.FormatFileNumber(year, seq)

    -- Pick prosecutor
    local prosecutorCid, prosecutorSrc = pickProsecutor()
    local fileStatus = prosecutorCid
        and Mclaw.FileStatus.PROSECUTOR_REVIEW
        or  Mclaw.FileStatus.AWAITING_PROSECUTOR

    -- Insert file
    local fileId = MySQL.insert.await(
        'INSERT INTO mclaw_files (file_number, suspect_citizenid, prosecutor_citizenid, referral_report_id, status) VALUES (?, ?, ?, ?, ?)',
        { fileNumber, suspectCid, prosecutorCid, reportId, fileStatus }
    )

    -- Mark report processed
    MySQL.update(
        'UPDATE mclaw_referral_reports SET file_id = ?, status = "processed", processed_at = NOW() WHERE id = ?',
        { fileId, reportId }
    )

    -- Insert file charges
    for _, c in ipairs(data.charges) do
        MySQL.insert('INSERT INTO mclaw_file_charges (file_id, charge_code) VALUES (?, ?)', { fileId, c.code })
    end

    -- Create jail decision (pending)
    local jailDecisionId = MySQL.insert.await(
        'INSERT INTO mclaw_jail_decisions (suspect_citizenid, officer_citizenid, charges, proposed_jail_time, proposed_fine, file_id) VALUES (?, ?, ?, ?, ?, ?)',
        { suspectCid, officerCid, json.encode(data.charges), sentence.jailTime, sentence.fine, fileId }
    )

    -- Link jail decision back to file
    MySQL.update('UPDATE mclaw_files SET jail_decision_id = ? WHERE id = ?', { jailDecisionId, fileId })

    -- Notify officer
    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        title       = 'Report Submitted',
        description = 'File opened: ' .. fileNumber,
    })

    -- Build charge label list for jail panel
    local chargeLabels = {}
    for _, c in ipairs(data.charges) do
        local def = Mclaw.GetChargeByCode(c.code)
        table.insert(chargeLabels, def and def.label or c.code)
    end

    local panelData = {
        jailDecisionId = jailDecisionId,
        fileNumber     = fileNumber,
        charges        = chargeLabels,
        proposedJail   = sentence.jailTime,
        proposedFine   = sentence.fine,
    }

    -- Send jail panel to suspect if online
    local suspectSrc = findSource(suspectCid)
    if suspectSrc then
        TriggerClientEvent('mclaw:client:jail:showPanel', suspectSrc, panelData)
    end

    -- Auto-accept timeout (server-side enforcement)
    if Config.Jail.autoAcceptTimeout and Config.Jail.autoAcceptTimeout > 0 then
        SetTimeout(Config.Jail.autoAcceptTimeout * 1000, function()
            local current = MySQL.scalar.await(
                'SELECT decision FROM mclaw_jail_decisions WHERE id = ?',
                { jailDecisionId }
            )
            if current == 'pending' then
                MySQL.update(
                    'UPDATE mclaw_jail_decisions SET decision = "accepted", decided_at = NOW() WHERE id = ?',
                    { jailDecisionId }
                )
                MySQL.update(
                    "UPDATE mclaw_files SET status = 'closed', closed_at = NOW() WHERE id = ?",
                    { fileId }
                )
                local sSource = findSource(suspectCid)
                if sSource then
                    TriggerClientEvent('mclaw:client:jail:panelTimeout', sSource, { jailDecisionId = jailDecisionId })
                end
            end
        end)
    end

    -- Notify prosecutor
    if prosecutorCid then
        MySQL.insert(
            'INSERT INTO mclaw_notifications (citizenid, type, title, message, ref_type, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            { prosecutorCid, 'subpoena', 'New File Assigned', 'You have been assigned to file ' .. fileNumber .. '.', 'file', fileId }
        )
        if prosecutorSrc then
            TriggerClientEvent('mclaw:client:notification:push', prosecutorSrc, {
                type        = 'inform',
                title       = 'New File Assigned',
                description = 'File ' .. fileNumber .. ' has been assigned to you.',
            })
        else
            Mclaw.Webhook.Send('file.opened', {
                fileNumber          = fileNumber,
                suspectName         = suspectCid,
                prosecutorCitizenid = prosecutorCid,
            })
        end
    else
        Mclaw.Webhook.Send('file.opened', {
            fileNumber  = fileNumber,
            suspectName = suspectCid,
        })
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:referral:withdraw
-- Allows the submitting officer to retract a report within the configured time window.
--
-- data.reportId  (number)  id of the report to withdraw
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:referral:withdraw', function(data)
    local src    = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.name ~= Config.Jobs.police then return end

    if not Config.Jail.reportWithdrawTime or Config.Jail.reportWithdrawTime <= 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Report withdrawal is disabled.' })
        return
    end

    local officerCid = Player.PlayerData.citizenid
    local report     = MySQL.single.await(
        "SELECT id FROM mclaw_referral_reports WHERE id = ? AND officer_citizenid = ? AND status = 'pending'",
        { data.reportId, officerCid }
    )

    if not report then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Report not found or already processed.' })
        return
    end

    local inWindow = MySQL.scalar.await(
        'SELECT TIMESTAMPDIFF(SECOND, created_at, NOW()) <= ? FROM mclaw_referral_reports WHERE id = ?',
        { Config.Jail.reportWithdrawTime, data.reportId }
    )

    if not inWindow or inWindow == 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Withdrawal window has expired.' })
        return
    end

    MySQL.update("UPDATE mclaw_referral_reports SET status = 'rejected' WHERE id = ?", { data.reportId })
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Report withdrawn successfully.' })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:referral:getChargeList
-- Returns the merged charge list (Config + MDT if pullCharges is enabled).
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:referral:getChargeList', function(source)
    if Config.Charges.useDatabase then
        local rows = MySQL.query.await('SELECT code, label, category, jail_time, fine_amount, severity FROM mclaw_charges_config WHERE is_active = 1 ORDER BY category, label', {})
        local list = {}
        for _, row in ipairs(rows or {}) do
            table.insert(list, {
                code     = row.code,
                label    = row.label,
                category = row.category,
                jailTime = row.jail_time,
                fine     = row.fine_amount,
                severity = row.severity,
            })
        end
        return list
    end
    return Config.Charges.list
end)
