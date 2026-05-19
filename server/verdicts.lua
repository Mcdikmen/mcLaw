-- ─────────────────────────────────────────────────────────────────────────────
-- Verdict system
-- Judge issues a verdict on a hearing_scheduled file.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Helper: notify a player by citizenid if online ───────────────────────────
local function notifyByCid(cid, payload)
    for _, pid in ipairs(GetPlayers()) do
        local P = exports.qbx_core:GetPlayer(tonumber(pid))
        if P and P.PlayerData.citizenid == cid then
            TriggerClientEvent('mclaw:client:notification:push', tonumber(pid), payload)
            return
        end
    end
end

-- ── mclaw:cb:verdict:getEligibleFiles ────────────────────────────────────────
-- Returns hearing_scheduled files assigned to the requesting judge.
lib.callback.register('mclaw:cb:verdict:getEligibleFiles', function(source)
    local P = exports.qbx_core:GetPlayer(source)
    if not P or P.PlayerData.job.name ~= Config.Jobs.judge then return {} end

    local cid  = P.PlayerData.citizenid
    local rows = MySQL.query.await(
        [[SELECT f.id, f.file_number, f.suspect_citizenid, f.prosecutor_citizenid,
                 f.status, f.notes, f.created_at,
                 h.id AS hearing_id, h.type AS hearing_type, h.scheduled_at
          FROM mclaw_files f
          LEFT JOIN mclaw_hearings h ON h.file_id = f.id AND h.status = 'scheduled'
          WHERE f.status = 'hearing_scheduled'
            AND f.judge_citizenid = ?
            AND f.deleted_at IS NULL
          ORDER BY h.scheduled_at ASC
          LIMIT 50]],
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
                label    = def and def.label    or c.charge_code,
                jailTime = c.jail_override      or (def and def.jailTime or 0),
                fine     = c.fine_override       or (def and def.fine     or 0),
            })
        end
        table.insert(list, {
            id              = row.id,
            fileNumber      = row.file_number,
            suspectCid      = row.suspect_citizenid,
            suspectName     = Mclaw.GetCharName(row.suspect_citizenid),
            prosecutorCid   = row.prosecutor_citizenid,
            status          = row.status,
            notes           = row.notes,
            createdAt       = Mclaw.FormatTimestamp(row.created_at),
            hearingId       = row.hearing_id,
            hearingType     = row.hearing_type,
            scheduledAt     = row.scheduled_at and tostring(row.scheduled_at) or nil,
            charges         = chargeList,
        })
    end
    return list
end)

-- ── mclaw:server:judge:issueVerdict ──────────────────────────────────────────
-- data.fileId        (number)   id of the file
-- data.result        (string)   'guilty' | 'acquitted' | 'dismissed'
-- data.charges       (table)    [{ code, jailOverride, fineOverride }]
-- data.totalJail     (number)   total jail time in minutes
-- data.totalFine     (number)   total fine in $
-- data.reasoning     (string?)  optional reasoning text
RegisterNetEvent('mclaw:server:judge:issueVerdict', function(data)
    local src = source
    local P   = exports.qbx_core:GetPlayer(src)
    if not P or P.PlayerData.job.name ~= Config.Jobs.judge then return end

    local validResults = { guilty = true, acquitted = true, dismissed = true }
    if not data.fileId or not data.result or not validResults[data.result] then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Mclaw.T('err_missing_data') })
        return
    end

    local cid  = P.PlayerData.citizenid
    local file = MySQL.single.await(
        [[SELECT id, file_number, suspect_citizenid, prosecutor_citizenid, judge_citizenid
          FROM mclaw_files
          WHERE id = ? AND status = 'hearing_scheduled' AND judge_citizenid = ? AND deleted_at IS NULL]],
        { data.fileId, cid }
    )
    if not file then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Mclaw.T('err_file_not_hearing') })
        return
    end

    local totalJail = tonumber(data.totalJail) or 0
    local totalFine = tonumber(data.totalFine) or 0

    -- Insert verdict record
    local hearing = MySQL.single.await(
        "SELECT id FROM mclaw_hearings WHERE file_id = ? AND status = 'scheduled' LIMIT 1",
        { data.fileId }
    )
    MySQL.insert.await(
        [[INSERT INTO mclaw_verdicts (file_id, hearing_id, judge_citizenid, result, total_jail_time, total_fine, reasoning)
          VALUES (?, ?, ?, ?, ?, ?, ?)]],
        { data.fileId, hearing and hearing.id or nil, cid, data.result, totalJail, totalFine, (data.reasoning ~= '' and data.reasoning or nil) }
    )

    -- Apply per-charge overrides
    if data.charges then
        for _, c in ipairs(data.charges) do
            if c.code then
                MySQL.update(
                    'UPDATE mclaw_file_charges SET jail_override = ?, fine_override = ? WHERE file_id = ? AND charge_code = ?',
                    { tonumber(c.jailOverride) or nil, tonumber(c.fineOverride) or nil, data.fileId, c.code }
                )
            end
        end
    end

    -- Close the hearing
    if hearing then
        MySQL.update(
            "UPDATE mclaw_hearings SET status = 'completed', ended_at = NOW() WHERE id = ?",
            { hearing.id }
        )
    end

    -- Update file status
    MySQL.update(
        "UPDATE mclaw_files SET status = 'verdict_issued', updated_at = NOW() WHERE id = ?",
        { data.fileId }
    )

    -- Log to file_open_logs
    local resultLabel = Mclaw.T('verdict_result_' .. data.result)
    MySQL.insert(
        "INSERT INTO mclaw_file_open_logs (file_id, action, actioned_by_citizenid, actioned_by_job, notes) VALUES (?, 'verdict', ?, ?, ?)",
        { data.fileId, cid, Config.Jobs.judge, resultLabel .. (data.reasoning ~= '' and (' — ' .. data.reasoning) or '') }
    )

    -- Notify judge (self)
    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        title       = Mclaw.T('notify_verdict_issued_title'),
        description = Mclaw.T('notify_verdict_issued_desc', file.file_number, resultLabel, tostring(totalJail), tostring(totalFine)),
    })

    local notifPayload = {
        type        = 'inform',
        title       = Mclaw.T('notify_verdict_prosecutor_title'),
        description = Mclaw.T('notify_verdict_prosecutor_desc', file.file_number, resultLabel, tostring(totalJail), tostring(totalFine)),
    }

    -- Notify prosecutor
    if file.prosecutor_citizenid then
        MySQL.insert(
            'INSERT INTO mclaw_notifications (citizenid, type, title, message, ref_type, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            { file.prosecutor_citizenid, 'verdict', notifPayload.title, notifPayload.description, 'file', data.fileId }
        )
        notifyByCid(file.prosecutor_citizenid, notifPayload)
    end

    -- Notify suspect
    if file.suspect_citizenid then
        local suspectMsg = Mclaw.T('notify_verdict_suspect_desc', file.file_number, resultLabel)
        MySQL.insert(
            'INSERT INTO mclaw_notifications (citizenid, type, title, message, ref_type, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            { file.suspect_citizenid, 'verdict', Mclaw.T('notify_verdict_suspect_title'), suspectMsg, 'file', data.fileId }
        )
        notifyByCid(file.suspect_citizenid, {
            type        = 'inform',
            title       = Mclaw.T('notify_verdict_suspect_title'),
            description = suspectMsg,
        })
    end

    -- Compensation for acquitted players
    if data.result == 'acquitted' and Config.Compensation and Config.Compensation.enabled then
        local amount = 0
        if Config.Compensation.calculation == 'fixed' then
            amount = Config.Compensation.fixedAmount or 0
        else
            amount = totalJail * (Config.Compensation.perMinuteRate or 500)
        end
        if amount > 0 then
            MySQL.insert(
                'INSERT INTO mclaw_compensation (verdict_id, citizenid, amount, reason, paid) VALUES ((SELECT id FROM mclaw_verdicts WHERE file_id = ? ORDER BY id DESC LIMIT 1), ?, ?, ?, 0)',
                { data.fileId, file.suspect_citizenid, amount, 'Acquittal compensation — ' .. file.file_number }
            )
            local suspectPlayer = exports.qbx_core:GetPlayer(file.suspect_citizenid)
            if suspectPlayer then
                local account = Config.Compensation.account or 'bank'
                suspectPlayer.Functions.AddMoney(account, amount, 'mclaw-acquittal-compensation')
                notifyByCid(file.suspect_citizenid, {
                    type        = 'success',
                    title       = Mclaw.T('notify_compensation_paid_title'),
                    description = Mclaw.T('notify_compensation_paid_desc', Mclaw.GetCharName(file.suspect_citizenid), tostring(amount)),
                })
            end
        end
    end
end)
