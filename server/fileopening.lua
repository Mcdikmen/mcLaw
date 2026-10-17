-- ─────────────────────────────────────────────────────────────────────────────
-- Manual file opening — standalone opening is disabled (see openFile below).
-- What remains here is pending_approval approve/reject, now dead in practice
-- since nothing can put a file into pending_approval anymore, but still safe to
-- keep: it only ever acted on files already in that status.
-- ─────────────────────────────────────────────────────────────────────────────

local function findSource(citizenid)
    for _, pid in ipairs(GetPlayers()) do
        local P = Mclaw.GetPlayer(tonumber(pid))
        if P and P.PlayerData.citizenid == citizenid then
            return tonumber(pid)
        end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:fileopening:openFile — DISABLED (2026-10-17, user decision).
-- A judge can no longer open a file standalone, criminal or civil: criminal
-- files only come from a police referral or a prosecutor's own investigation,
-- then an indictment; civil files only from a lawyer's petition, accepted via
-- mclaw:server:judge:acceptCivilPetition (petitions.lua). The NUI nav entry for
-- this ("+ Dosya Aç") was removed; this guard stays in case anything still
-- calls the event directly.
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:fileopening:openFile', function(data)
    local src = source
    local P   = Mclaw.GetPlayer(src)
    if not P then return end
    Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error',
        description = 'Hakim resmi dosyayı kendi başına açamaz: ceza davaları sevk/soruşturma üzerinden, hukuk davaları avukat dilekçesi üzerinden açılır.' })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:judge:getPendingApprovals
-- Returns all files in pending_approval status for judge review.
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:judge:getPendingApprovals', function(source)
    local P = Mclaw.GetPlayer(source)
    if not P or Mclaw.GetRole(P) ~= Config.Jobs.judge then return {} end

    local rows = MySQL.query.await(
        "SELECT id, file_number, suspect_citizenid, opened_by_citizenid, opened_by_job, notes, created_at FROM mclaw_files WHERE status = 'pending_approval' AND deleted_at IS NULL ORDER BY created_at ASC LIMIT 50",
        {}
    )

    local files = {}
    for _, row in ipairs(rows or {}) do
        local charges = MySQL.query.await(
            'SELECT charge_code, jail_override, fine_override FROM mclaw_file_charges WHERE file_id = ?', { row.id }
        )
        local chargeList = {}
        for _, c in ipairs(charges or {}) do
            local def = Mclaw.GetChargeByCode(c.charge_code)
            table.insert(chargeList, {
                code     = c.charge_code,
                label    = def and def.label or c.charge_code,
                category = def and def.category or '?',
                jailTime = c.jail_override or (def and def.jailTime or 0),
                fine     = c.fine_override  or (def and def.fine     or 0),
            })
        end
        -- Fetch opening narrative from log
        local openLog = MySQL.single.await(
            "SELECT notes FROM mclaw_file_open_logs WHERE file_id = ? AND action = 'opened' ORDER BY created_at ASC LIMIT 1",
            { row.id }
        )
        table.insert(files, {
            id           = row.id,
            fileNumber   = row.file_number,
            suspectCid   = row.suspect_citizenid,
            suspectName  = Mclaw.GetCharName(row.suspect_citizenid),
            openedBy     = row.opened_by_citizenid,
            openedByName = Mclaw.GetCharName(row.opened_by_citizenid),
            openedByJob  = row.opened_by_job,
            notes        = row.notes,
            narrative    = openLog and openLog.notes or nil,
            createdAt    = Mclaw.FormatTimestamp(row.created_at),
            charges      = chargeList,
        })
    end
    return files
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:judge:approveFile
--
-- data.fileId  (number)   id of the file to approve
-- data.notes   (string?)  optional judge note
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:judge:approveFile', function(data)
    local src = source
    local P   = Mclaw.GetPlayer(src)
    if not P or Mclaw.GetRole(P) ~= Config.Jobs.judge then return end

    local cid  = P.PlayerData.citizenid
    local file = MySQL.single.await(
        "SELECT id, file_number, opened_by_citizenid, suspect_citizenid FROM mclaw_files WHERE id = ? AND status = 'pending_approval' AND deleted_at IS NULL",
        { data.fileId }
    )
    if not file then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = Mclaw.T('err_file_not_found_approval') })
        return
    end

    MySQL.update(
        "UPDATE mclaw_files SET status = 'opened', judge_citizenid = ?, updated_at = NOW() WHERE id = ?",
        { cid, data.fileId }
    )
    Mclaw.NotifyCitizen(file.suspect_citizenid, 'subpoena', Mclaw.T('start_ok_title'), Mclaw.T('start_ok_suspect', file.file_number))

    MySQL.insert(
        'INSERT INTO mclaw_file_open_logs (file_id, action, actioned_by_citizenid, actioned_by_job, notes) VALUES (?, ?, ?, ?, ?)',
        { data.fileId, 'approved', cid, Config.Jobs.judge, data.notes ~= '' and data.notes or nil }
    )

    Mclaw.Notify(src, { position = Config.NotifyPosition,
        type        = 'success',
        title       = Mclaw.T('notify_file_approved_title'),
        description = Mclaw.T('notify_file_approved_desc', file.file_number),
    })

    if file.opened_by_citizenid then
        local openerSrc = findSource(file.opened_by_citizenid)
        if openerSrc then
            Mclaw.Notify(openerSrc, {
                type        = 'success',
                title       = Mclaw.T('notify_your_file_approved_title'),
                description = Mclaw.T('notify_your_file_approved_desc', file.file_number),
            })
        end
        MySQL.insert(
            'INSERT INTO mclaw_notifications (citizenid, type, title, message, ref_type, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            { file.opened_by_citizenid, 'hearing', Mclaw.T('notify_your_file_approved_title'), Mclaw.T('notify_your_file_approved_desc', file.file_number), 'file', data.fileId }
        )
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:judge:rejectFile
--
-- data.fileId  (number)  id of the file to reject
-- data.reason  (string?) optional rejection reason
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:judge:rejectFile', function(data)
    local src = source
    local P   = Mclaw.GetPlayer(src)
    if not P or Mclaw.GetRole(P) ~= Config.Jobs.judge then return end

    local cid  = P.PlayerData.citizenid
    local file = MySQL.single.await(
        "SELECT id, file_number, opened_by_citizenid FROM mclaw_files WHERE id = ? AND status = 'pending_approval' AND deleted_at IS NULL",
        { data.fileId }
    )
    if not file then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = Mclaw.T('err_file_not_found_rejection') })
        return
    end

    MySQL.update(
        "UPDATE mclaw_files SET status = 'closed', closed_at = NOW(), updated_at = NOW() WHERE id = ?",
        { data.fileId }
    )
    MySQL.insert(
        'INSERT INTO mclaw_file_open_logs (file_id, action, actioned_by_citizenid, actioned_by_job, notes) VALUES (?, ?, ?, ?, ?)',
        { data.fileId, 'rejected', cid, Config.Jobs.judge, data.reason ~= '' and data.reason or nil }
    )

    Mclaw.Notify(src, { position = Config.NotifyPosition,
        type        = 'inform',
        title       = Mclaw.T('notify_file_rejected_title'),
        description = Mclaw.T('notify_file_rejected_desc', file.file_number),
    })

    if file.opened_by_citizenid then
        local reason = (data.reason and data.reason ~= '') and Mclaw.T('notify_file_closed_reason', data.reason) or ''
        local openerSrc = findSource(file.opened_by_citizenid)
        if openerSrc then
            Mclaw.Notify(openerSrc, {
                type        = 'error',
                title       = Mclaw.T('notify_your_file_rejected_title'),
                description = Mclaw.T('notify_your_file_rejected_desc', file.file_number) .. reason,
            })
        end
        MySQL.insert(
            'INSERT INTO mclaw_notifications (citizenid, type, title, message, ref_type, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            { file.opened_by_citizenid, 'hearing', Mclaw.T('notify_your_file_rejected_title'), Mclaw.T('notify_your_file_rejected_desc', file.file_number) .. reason, 'file', data.fileId }
        )
    end
end)
