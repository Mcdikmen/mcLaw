-- ─────────────────────────────────────────────────────────────────────────────
-- Hearings panel callbacks
-- ─────────────────────────────────────────────────────────────────────────────

-- mclaw:cb:hearings:getList
-- Returns scheduled/active hearings relevant to the requesting player's job.
--   Judge  → all hearings they preside over
--   Lawyer → hearings for files where they have an active power of attorney
lib.callback.register('mclaw:cb:hearings:getList', function(source)
    local P = exports.qbx_core:GetPlayer(source)
    if not P then return {} end

    local job = P.PlayerData.job.name
    local cid = P.PlayerData.citizenid
    local rows

    if job == Config.Jobs.judge then
        rows = MySQL.query.await(
            [[SELECT h.id, h.file_id, h.type, h.scheduled_at, h.status, h.notes,
                     f.file_number, f.suspect_citizenid, f.prosecutor_citizenid
              FROM mclaw_hearings h
              JOIN mclaw_files f ON f.id = h.file_id
              WHERE h.judge_citizenid = ?
                AND h.status IN ('scheduled','active')
              ORDER BY h.scheduled_at ASC LIMIT 50]],
            { cid }
        )
    elseif job == Config.Jobs.lawyer then
        rows = MySQL.query.await(
            [[SELECT h.id, h.file_id, h.type, h.scheduled_at, h.status, h.notes,
                     f.file_number, f.suspect_citizenid, f.prosecutor_citizenid
              FROM mclaw_hearings h
              JOIN mclaw_files f ON f.id = h.file_id
              JOIN mclaw_attorneys a ON a.file_id = f.id
              WHERE a.attorney_citizenid = ? AND a.is_active = 1
                AND h.status IN ('scheduled','active')
              ORDER BY h.scheduled_at ASC LIMIT 50]],
            { cid }
        )
    else
        return {}
    end

    local list = {}
    for _, row in ipairs(rows or {}) do
        table.insert(list, {
            id             = row.id,
            fileId         = row.file_id,
            fileNumber     = row.file_number,
            suspectCid     = row.suspect_citizenid,
            suspectName    = Mclaw.GetCharName(row.suspect_citizenid),
            prosecutorCid  = row.prosecutor_citizenid,
            prosecutorName = Mclaw.GetCharName(row.prosecutor_citizenid),
            hearingType    = row.type,
            scheduledAt    = Mclaw.FormatTimestamp(row.scheduled_at),
            status         = row.status,
            notes          = row.notes,
        })
    end
    return list
end)
