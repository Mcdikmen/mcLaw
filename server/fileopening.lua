-- ─────────────────────────────────────────────────────────────────────────────
-- Manual file opening: prosecutor / judge / lawyer
-- Judge-opened files are immediately active; prosecutor & lawyer submissions
-- enter pending_approval and must be approved or rejected by a judge.
-- All open/approve/reject actions are logged in mclaw_file_open_logs.
-- ─────────────────────────────────────────────────────────────────────────────

local function findSource(citizenid)
    for _, pid in ipairs(GetPlayers()) do
        local P = exports.qbx_core:GetPlayer(tonumber(pid))
        if P and P.PlayerData.citizenid == citizenid then
            return tonumber(pid)
        end
    end
    return nil
end

local function getNextFileSequence(year)
    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM mclaw_files WHERE YEAR(created_at) = ?', { year }
    )
    return (count or 0) + 1
end

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:fileopening:openFile
--
-- data.suspectCid  (string)  citizenid of the suspect
-- data.charges     (table)   array of { code = 'charge_code' }
-- data.narrative   (string)  reason/description (min 10 chars)
-- data.notes       (string?) optional internal note
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:fileopening:openFile', function(data)
    local src = source
    local P   = exports.qbx_core:GetPlayer(src)
    if not P then return end

    local job = P.PlayerData.job.name
    local allowedJobs = {
        [Config.Jobs.prosecutor] = true,
        [Config.Jobs.judge]      = true,
        [Config.Jobs.lawyer]     = true,
    }
    if not allowedJobs[job] then return end

    local cid = P.PlayerData.citizenid

    -- Validate suspect exists
    local suspectExists = MySQL.scalar.await(
        'SELECT COUNT(*) FROM players WHERE citizenid = ?', { data.suspectCid }
    )
    if not suspectExists or suspectExists == 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Geçersiz şüpheli kimlik numarası.' })
        return
    end

    if not data.charges or #data.charges == 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'En az bir suç seçilmelidir.' })
        return
    end

    for _, c in ipairs(data.charges) do
        if not Mclaw.GetChargeByCode(c.code) then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Geçersiz suç kodu: ' .. tostring(c.code) })
            return
        end
    end

    if not data.narrative or #data.narrative < 10 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Anlatı en az 10 karakter olmalıdır.' })
        return
    end

    -- Determine status and pre-assigned roles
    local fileStatus, prosecutorCid, judgeCid
    if job == Config.Jobs.judge then
        fileStatus   = 'opened'
        judgeCid     = cid
    elseif job == Config.Jobs.prosecutor then
        fileStatus   = 'pending_approval'
        prosecutorCid = cid
    else -- lawyer
        fileStatus = 'pending_approval'
    end

    local year = tonumber(os.date('%Y'))
    local seq  = getNextFileSequence(year)
    local fileNumber = Mclaw.FormatFileNumber(year, seq)

    local fileId = MySQL.insert.await(
        'INSERT INTO mclaw_files (file_number, suspect_citizenid, prosecutor_citizenid, judge_citizenid, status, opened_by_citizenid, opened_by_job, notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { fileNumber, data.suspectCid, prosecutorCid, judgeCid, fileStatus, cid, job, (data.notes ~= '' and data.notes or nil) }
    )

    for _, c in ipairs(data.charges) do
        MySQL.insert('INSERT INTO mclaw_file_charges (file_id, charge_code) VALUES (?, ?)', { fileId, c.code })
    end

    MySQL.insert(
        'INSERT INTO mclaw_file_open_logs (file_id, action, actioned_by_citizenid, actioned_by_job, notes) VALUES (?, ?, ?, ?, ?)',
        { fileId, 'opened', cid, job, data.narrative }
    )

    local statusNote = fileStatus == 'pending_approval' and ' — Hakim onayı bekleniyor.' or ' — Dosya açıldı.'
    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        title       = 'Dosya Oluşturuldu',
        description = fileNumber .. statusNote,
    })

    -- Notify online judges when pending
    if fileStatus == 'pending_approval' then
        for _, pid in ipairs(GetPlayers()) do
            local JP = exports.qbx_core:GetPlayer(tonumber(pid))
            if JP and JP.PlayerData.job.name == Config.Jobs.judge then
                TriggerClientEvent('mclaw:client:notification:push', tonumber(pid), {
                    type        = 'inform',
                    title       = 'Dosya Onay Bekliyor',
                    description = fileNumber .. ' numaralı dosya onayınızı bekliyor.',
                })
                MySQL.insert(
                    'INSERT INTO mclaw_notifications (citizenid, type, title, message, ref_type, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
                    { JP.PlayerData.citizenid, 'hearing', 'Dosya Onay Bekliyor', fileNumber .. ' numaralı dosya onayınızı bekliyor.', 'file', fileId }
                )
            end
        end
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:judge:getPendingApprovals
-- Returns all files in pending_approval status for judge review.
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:judge:getPendingApprovals', function(source)
    local P = exports.qbx_core:GetPlayer(source)
    if not P or P.PlayerData.job.name ~= Config.Jobs.judge then return {} end

    local rows = MySQL.query.await(
        "SELECT id, file_number, suspect_citizenid, opened_by_citizenid, opened_by_job, notes, created_at FROM mclaw_files WHERE status = 'pending_approval' AND deleted_at IS NULL ORDER BY created_at ASC LIMIT 50",
        {}
    )

    local files = {}
    for _, row in ipairs(rows or {}) do
        local charges = MySQL.query.await(
            'SELECT charge_code FROM mclaw_file_charges WHERE file_id = ?', { row.id }
        )
        local chargeList = {}
        for _, c in ipairs(charges or {}) do
            local def = Mclaw.GetChargeByCode(c.charge_code)
            table.insert(chargeList, { code = c.charge_code, label = def and def.label or c.charge_code })
        end
        table.insert(files, {
            id          = row.id,
            fileNumber  = row.file_number,
            suspectCid  = row.suspect_citizenid,
            openedBy    = row.opened_by_citizenid,
            openedByJob = row.opened_by_job,
            notes       = row.notes,
            createdAt   = tostring(row.created_at),
            charges     = chargeList,
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
    local P   = exports.qbx_core:GetPlayer(src)
    if not P or P.PlayerData.job.name ~= Config.Jobs.judge then return end

    local cid  = P.PlayerData.citizenid
    local file = MySQL.single.await(
        "SELECT id, file_number, opened_by_citizenid FROM mclaw_files WHERE id = ? AND status = 'pending_approval' AND deleted_at IS NULL",
        { data.fileId }
    )
    if not file then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Dosya bulunamadı veya onay için uygun değil.' })
        return
    end

    MySQL.update(
        "UPDATE mclaw_files SET status = 'opened', judge_citizenid = ?, updated_at = NOW() WHERE id = ?",
        { cid, data.fileId }
    )
    MySQL.insert(
        'INSERT INTO mclaw_file_open_logs (file_id, action, actioned_by_citizenid, actioned_by_job, notes) VALUES (?, ?, ?, ?, ?)',
        { data.fileId, 'approved', cid, Config.Jobs.judge, data.notes ~= '' and data.notes or nil }
    )

    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        title       = 'Dosya Onaylandı',
        description = file.file_number .. ' numaralı dosya onaylandı ve açıldı.',
    })

    -- Notify opener
    if file.opened_by_citizenid then
        local openerSrc = findSource(file.opened_by_citizenid)
        if openerSrc then
            TriggerClientEvent('mclaw:client:notification:push', openerSrc, {
                type        = 'success',
                title       = 'Dosyanız Onaylandı',
                description = file.file_number .. ' numaralı dosyanız hakim tarafından onaylandı.',
            })
        end
        MySQL.insert(
            'INSERT INTO mclaw_notifications (citizenid, type, title, message, ref_type, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            { file.opened_by_citizenid, 'hearing', 'Dosyanız Onaylandı', file.file_number .. ' numaralı dosyanız hakim tarafından onaylandı.', 'file', data.fileId }
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
    local P   = exports.qbx_core:GetPlayer(src)
    if not P or P.PlayerData.job.name ~= Config.Jobs.judge then return end

    local cid  = P.PlayerData.citizenid
    local file = MySQL.single.await(
        "SELECT id, file_number, opened_by_citizenid FROM mclaw_files WHERE id = ? AND status = 'pending_approval' AND deleted_at IS NULL",
        { data.fileId }
    )
    if not file then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Dosya bulunamadı veya onay için uygun değil.' })
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

    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'inform',
        title       = 'Dosya Reddedildi',
        description = file.file_number .. ' numaralı dosya reddedildi.',
    })

    if file.opened_by_citizenid then
        local reason = (data.reason and data.reason ~= '') and (' Gerekçe: ' .. data.reason) or ''
        local openerSrc = findSource(file.opened_by_citizenid)
        if openerSrc then
            TriggerClientEvent('mclaw:client:notification:push', openerSrc, {
                type        = 'error',
                title       = 'Dosyanız Reddedildi',
                description = file.file_number .. ' numaralı dosyanız hakim tarafından reddedildi.' .. reason,
            })
        end
        MySQL.insert(
            'INSERT INTO mclaw_notifications (citizenid, type, title, message, ref_type, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            { file.opened_by_citizenid, 'hearing', 'Dosyanız Reddedildi', file.file_number .. ' numaralı dosyanız hakim tarafından reddedildi.' .. reason, 'file', data.fileId }
        )
    end
end)
