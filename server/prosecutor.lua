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
        rows = MySQL.query.await(
            'SELECT id, file_number, suspect_citizenid, status, type, created_at FROM mclaw_files WHERE prosecutor_citizenid = ? AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 50',
            { cid }
        )
    elseif job == Config.Jobs.judge then
        rows = MySQL.query.await(
            "SELECT id, file_number, suspect_citizenid, status, type, created_at FROM mclaw_files WHERE judge_citizenid = ? AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 50",
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
            id         = row.id,
            fileNumber = row.file_number,
            suspectCid = row.suspect_citizenid,
            status     = row.status,
            type       = row.type,
            createdAt  = tostring(row.created_at),
            charges    = chargeList,
        })
    end
    return files
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
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Dosya bulunamadı veya yetkiniz yok.' })
        return
    end

    local eligible = {
        opened               = true,
        awaiting_prosecutor  = true,
        prosecutor_review    = true,
    }
    if not eligible[file.status] then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Bu dosya iddianame için uygun değil.' })
        return
    end

    if data.hearingType ~= 'physical' and data.hearingType ~= 'written' then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Geçersiz duruşma türü.' })
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
        title       = 'İddianame Hazırlandı',
        description = 'Dosya ' .. file.file_number .. ' iddianame aşamasına geçti.',
    })

    -- Notify assigned judge if any
    if file.judge_citizenid then
        MySQL.insert(
            'INSERT INTO mclaw_notifications (citizenid, type, title, message, ref_type, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            { file.judge_citizenid, 'hearing', 'İddianame Hazır', 'Dosya ' .. file.file_number .. ' iddianame aşamasına geçti.', 'file', data.fileId }
        )
        for _, pid in ipairs(GetPlayers()) do
            local JP = exports.qbx_core:GetPlayer(tonumber(pid))
            if JP and JP.PlayerData.citizenid == file.judge_citizenid then
                TriggerClientEvent('mclaw:client:notification:push', tonumber(pid), {
                    type        = 'inform',
                    title       = 'İddianame Hazır',
                    description = 'Dosya ' .. file.file_number .. ' duruşmaya hazır.',
                })
                break
            end
        end
    end
end)
