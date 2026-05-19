-- ─────────────────────────────────────────────────────────────────────────────
-- Prosecutor panel callbacks and events
-- ─────────────────────────────────────────────────────────────────────────────

-- mclaw:cb:prosecutor:getFiles
-- Returns up to 50 most recent files assigned to the requesting prosecutor or judge.
lib.callback.register('mclaw:cb:prosecutor:getFiles', function(source)
    local P = exports.qbx_core:GetPlayer(source)
    if not P then return {} end

    local job = P.PlayerData.job.name
    local cid = P.PlayerData.citizenid

    local rows
    if job == Config.Jobs.prosecutor then
        -- Sadece dava dosyaları (iddianame aşamasına geçmiş)
        rows = MySQL.query.await(
            "SELECT id, file_number, suspect_citizenid, status, type, notes, created_at FROM mclaw_files WHERE prosecutor_citizenid = ? AND type != 'investigation' AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 50",
            { cid }
        )
    elseif job == Config.Jobs.judge then
        rows = MySQL.query.await(
            "SELECT id, file_number, suspect_citizenid, status, type, notes, prosecutor_citizenid, created_at FROM mclaw_files WHERE deleted_at IS NULL AND (judge_citizenid = ? OR (status IN ('indictment_ready','written_trial_active') AND judge_citizenid IS NULL)) ORDER BY created_at DESC LIMIT 50",
            { cid }
        )
    else
        return {}
    end

    local files = {}
    for _, row in ipairs(rows or {}) do
        local charges = MySQL.query.await(
            'SELECT fc.charge_code, fc.jail_override, fc.fine_override FROM mclaw_file_charges fc WHERE fc.file_id = ?',
            { row.id }
        )
        local chargeList = {}
        for _, c in ipairs(charges or {}) do
            local def = Mclaw.GetChargeByCode(c.charge_code)
            table.insert(chargeList, {
                code     = c.charge_code,
                label    = def and def.label or c.charge_code,
                jailTime = c.jail_override or (def and def.jailTime or 0),
                fine     = c.fine_override  or (def and def.fine     or 0),
            })
        end
        table.insert(files, {
            id             = row.id,
            fileNumber     = row.file_number,
            suspectCid     = row.suspect_citizenid,
            suspectName    = Mclaw.GetCharName(row.suspect_citizenid),
            status         = row.status,
            type           = row.type,
            notes          = row.notes,
            prosecutorCid  = row.prosecutor_citizenid,
            createdAt      = Mclaw.FormatTimestamp(row.created_at),
            charges        = chargeList,
        })
    end
    return files
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:prosecutor:openInvestigation
-- Savcı re'sen soruşturma açar (SRS numaralı, type=investigation).
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:prosecutor:openInvestigation', function(data)
    local src = source
    local P   = exports.qbx_core:GetPlayer(src)
    if not P or P.PlayerData.job.name ~= Config.Jobs.prosecutor then return end

    if not data.suspectCid or not data.charges or #data.charges == 0 or not data.narrative or #data.narrative < 10 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Mclaw.T('err_missing_data') })
        return
    end

    local suspectExists = MySQL.scalar.await('SELECT COUNT(*) FROM players WHERE citizenid = ?', { data.suspectCid })
    if not suspectExists or suspectExists == 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Mclaw.T('err_invalid_suspect_cid') })
        return
    end

    for _, c in ipairs(data.charges) do
        if not Mclaw.GetChargeByCode(c.code) then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Mclaw.T('err_invalid_charge_code', tostring(c.code)) })
            return
        end
    end

    local cid  = P.PlayerData.citizenid
    local year = tonumber(os.date('%Y'))
    local invCount = MySQL.scalar.await(
        "SELECT COUNT(*) FROM mclaw_files WHERE type = 'investigation' AND YEAR(created_at) = ?", { year }
    ) or 0
    local fileNumber = Mclaw.FormatInvestigationNumber(year, invCount + 1)

    local fileId = MySQL.insert.await(
        "INSERT INTO mclaw_files (file_number, suspect_citizenid, prosecutor_citizenid, opened_by_citizenid, opened_by_job, status, type, notes) VALUES (?, ?, ?, ?, ?, 'opened', 'investigation', ?)",
        { fileNumber, data.suspectCid, cid, cid, Config.Jobs.prosecutor, (data.notes ~= '' and data.notes or nil) }
    )

    for _, c in ipairs(data.charges) do
        MySQL.insert('INSERT INTO mclaw_file_charges (file_id, charge_code) VALUES (?, ?)', { fileId, c.code })
    end

    MySQL.insert(
        "INSERT INTO mclaw_file_open_logs (file_id, action, actioned_by_citizenid, actioned_by_job, notes) VALUES (?, 'opened', ?, ?, ?)",
        { fileId, cid, Config.Jobs.prosecutor, data.narrative }
    )

    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        title       = Mclaw.T('notify_investigation_opened_title'),
        description = Mclaw.T('notify_investigation_opened_desc', fileNumber),
    })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:prosecutor:getInvestigations
-- Savcının kendi soruşturmalarını listeler (type = 'investigation').
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:prosecutor:getInvestigations', function(source)
    local P = exports.qbx_core:GetPlayer(source)
    if not P or P.PlayerData.job.name ~= Config.Jobs.prosecutor then return {} end

    local cid  = P.PlayerData.citizenid
    local rows = MySQL.query.await(
        "SELECT id, file_number, suspect_citizenid, status, notes, created_at FROM mclaw_files WHERE prosecutor_citizenid = ? AND type = 'investigation' AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 50",
        { cid }
    )

    local list = {}
    for _, row in ipairs(rows or {}) do
        local charges = MySQL.query.await(
            'SELECT fc.charge_code, fc.jail_override, fc.fine_override FROM mclaw_file_charges fc WHERE fc.file_id = ?',
            { row.id }
        )
        local chargeList = {}
        for _, c in ipairs(charges or {}) do
            local def = Mclaw.GetChargeByCode(c.charge_code)
            table.insert(chargeList, {
                code     = c.charge_code,
                label    = def and def.label or c.charge_code,
                jailTime = c.jail_override or (def and def.jailTime or 0),
                fine     = c.fine_override  or (def and def.fine     or 0),
            })
        end
        table.insert(list, {
            id           = row.id,
            fileNumber   = row.file_number,
            suspectCid   = row.suspect_citizenid,
            suspectName  = Mclaw.GetCharName(row.suspect_citizenid),
            status       = row.status,
            notes        = row.notes,
            createdAt    = Mclaw.FormatTimestamp(row.created_at),
            charges      = chargeList,
        })
    end
    return list
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:prosecutor:submitIndictment
-- Moves a file to indictment_ready (physical) or written_trial_active (written).
--
-- data.fileId      (number)   id of the file
-- data.hearingType (string)   'physical' | 'written'
-- data.notes       (string?)  optional notes
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:prosecutor:submitIndictment', function(data)
    local src = source
    local P   = exports.qbx_core:GetPlayer(src)
    if not P then return end
    if P.PlayerData.job.name ~= Config.Jobs.prosecutor then return end

    local cid  = P.PlayerData.citizenid
    local file = MySQL.single.await(
        'SELECT id, file_number, status, judge_citizenid FROM mclaw_files WHERE id = ? AND prosecutor_citizenid = ? AND deleted_at IS NULL',
        { data.fileId, cid }
    )

    if not file then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Mclaw.T('err_file_not_found_auth') })
        return
    end

    local eligible = {
        opened               = true,
        awaiting_prosecutor  = true,
        prosecutor_review    = true,
    }
    if not eligible[file.status] then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Mclaw.T('err_file_not_eligible') })
        return
    end

    if data.hearingType ~= 'physical' and data.hearingType ~= 'written' then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Mclaw.T('err_invalid_hearing_type') })
        return
    end

    local newStatus = data.hearingType == 'written' and 'written_trial_active' or 'indictment_ready'
    local newType   = data.hearingType == 'written' and 'written_trial'        or 'case'

    MySQL.update(
        'UPDATE mclaw_files SET status = ?, type = ?, notes = COALESCE(?, notes), updated_at = NOW() WHERE id = ?',
        { newStatus, newType, data.notes ~= '' and data.notes or nil, data.fileId }
    )

    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        title       = Mclaw.T('notify_indictment_prepared_title'),
        description = Mclaw.T('notify_indictment_prepared_desc', file.file_number),
    })

    if file.judge_citizenid then
        MySQL.insert(
            'INSERT INTO mclaw_notifications (citizenid, type, title, message, ref_type, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            { file.judge_citizenid, 'hearing', Mclaw.T('notify_indictment_ready_title'), Mclaw.T('notify_indictment_prepared_desc', file.file_number), 'file', data.fileId }
        )
        for _, pid in ipairs(GetPlayers()) do
            local JP = exports.qbx_core:GetPlayer(tonumber(pid))
            if JP and JP.PlayerData.citizenid == file.judge_citizenid then
                TriggerClientEvent('mclaw:client:notification:push', tonumber(pid), {
                    type        = 'inform',
                    title       = Mclaw.T('notify_indictment_ready_title'),
                    description = Mclaw.T('notify_indictment_ready_desc', file.file_number),
                })
                break
            end
        end
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:judge:acceptCase
-- Judge accepts an indictment_ready file → hearing_scheduled.
-- Creates a mclaw_hearings record with scheduled_at and type.
--
-- data.fileId       (number)   id of the file
-- data.scheduledAt  (string)   datetime-local value, e.g. "2026-05-10T14:30"
-- data.hearingType  (string)   'physical' | 'written'
-- data.notes        (string?)  optional judge note
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:judge:acceptCase', function(data)
    local src = source
    local P   = exports.qbx_core:GetPlayer(src)
    if not P or P.PlayerData.job.name ~= Config.Jobs.judge then return end

    if not data.scheduledAt or data.scheduledAt == '' then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Mclaw.T('err_hearing_date_required') })
        return
    end

    local hearingType = (data.hearingType == 'written') and 'written' or 'physical'

    local cid  = P.PlayerData.citizenid
    local file = MySQL.single.await(
        "SELECT id, file_number, prosecutor_citizenid FROM mclaw_files WHERE id = ? AND status = 'indictment_ready' AND deleted_at IS NULL",
        { data.fileId }
    )
    if not file then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Mclaw.T('err_file_not_indictment') })
        return
    end

    -- Normalize datetime: "2026-05-10T14:30" → "2026-05-10 14:30:00"
    local scheduledAt = string.gsub(data.scheduledAt, 'T', ' ')
    if #scheduledAt == 16 then scheduledAt = scheduledAt .. ':00' end

    MySQL.insert(
        'INSERT INTO mclaw_hearings (file_id, judge_citizenid, type, scheduled_at, notes) VALUES (?, ?, ?, ?, ?)',
        { data.fileId, cid, hearingType, scheduledAt, (data.notes ~= '' and data.notes or nil) }
    )

    MySQL.update(
        "UPDATE mclaw_files SET status = 'hearing_scheduled', judge_citizenid = ?, updated_at = NOW() WHERE id = ?",
        { cid, data.fileId }
    )

    local typeLabel = hearingType == 'written' and Mclaw.T('hearing_type_written') or Mclaw.T('hearing_type_physical')
    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        title       = Mclaw.T('notify_hearing_scheduled_title'),
        description = Mclaw.T('notify_hearing_scheduled_desc', file.file_number, typeLabel, scheduledAt),
    })

    if file.prosecutor_citizenid then
        local msg = Mclaw.T('notify_hearing_scheduled_msg', file.file_number, typeLabel, scheduledAt)
        MySQL.insert(
            'INSERT INTO mclaw_notifications (citizenid, type, title, message, ref_type, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            { file.prosecutor_citizenid, 'hearing', Mclaw.T('notify_hearing_scheduled_title'), msg, 'file', data.fileId }
        )
        for _, pid in ipairs(GetPlayers()) do
            local PP = exports.qbx_core:GetPlayer(tonumber(pid))
            if PP and PP.PlayerData.citizenid == file.prosecutor_citizenid then
                TriggerClientEvent('mclaw:client:notification:push', tonumber(pid), {
                    type        = 'success',
                    title       = Mclaw.T('notify_hearing_scheduled_title'),
                    description = Mclaw.T('notify_hearing_scheduled_desc', file.file_number, typeLabel, scheduledAt),
                })
                break
            end
        end
    end
end)
