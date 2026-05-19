-- ─────────────────────────────────────────────────────────────────────────────
-- Dashboard stats callback
-- Returns counts relevant to the requesting player's job.
-- ─────────────────────────────────────────────────────────────────────────────

lib.callback.register('mclaw:cb:dashboard:getStats', function(source)
    local P = exports.qbx_core:GetPlayer(source)
    if not P then return {} end

    local job = P.PlayerData.job.name
    local cid = P.PlayerData.citizenid

    local activeFiles   = 0
    local pendingCount  = 0

    if job == Config.Jobs.prosecutor then
        activeFiles = MySQL.scalar.await(
            "SELECT COUNT(*) FROM mclaw_files WHERE prosecutor_citizenid = ? AND status NOT IN ('closed','archived','verdict_issued') AND deleted_at IS NULL",
            { cid }
        ) or 0
        pendingCount = MySQL.scalar.await(
            "SELECT COUNT(*) FROM mclaw_files WHERE prosecutor_citizenid = ? AND status = 'indictment_ready' AND deleted_at IS NULL",
            { cid }
        ) or 0
    elseif job == Config.Jobs.judge then
        activeFiles = MySQL.scalar.await(
            "SELECT COUNT(*) FROM mclaw_files WHERE status NOT IN ('closed','archived','verdict_issued') AND deleted_at IS NULL",
            {}
        ) or 0
        pendingCount = MySQL.scalar.await(
            "SELECT COUNT(*) FROM mclaw_files WHERE status = 'pending_approval' AND deleted_at IS NULL",
            {}
        ) or 0
    elseif job == Config.Jobs.police then
        activeFiles = MySQL.scalar.await(
            "SELECT COUNT(*) FROM mclaw_files WHERE status NOT IN ('closed','archived','verdict_issued') AND deleted_at IS NULL",
            {}
        ) or 0
        pendingCount = MySQL.scalar.await(
            "SELECT COUNT(*) FROM mclaw_referral_reports WHERE status = 'pending'",
            {}
        ) or 0
    elseif job == Config.Jobs.lawyer then
        activeFiles = MySQL.scalar.await(
            [[SELECT COUNT(DISTINCT f.id) FROM mclaw_files f
              JOIN mclaw_attorneys a ON a.file_id = f.id
              WHERE a.attorney_citizenid = ? AND a.is_active = 1
                AND f.status NOT IN ('closed','archived','verdict_issued') AND f.deleted_at IS NULL]],
            { cid }
        ) or 0
        pendingCount = MySQL.scalar.await(
            [[SELECT COUNT(*) FROM mclaw_hearings h
              JOIN mclaw_attorneys a ON a.file_id = h.file_id
              WHERE a.attorney_citizenid = ? AND a.is_active = 1 AND h.status = 'scheduled']],
            { cid }
        ) or 0
    end

    return { activeFiles = activeFiles, pendingCount = pendingCount }
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:citizens:search
-- Searches players by first name, last name, or full name (case-insensitive).
-- Accessible to all legal job holders.
-- Returns up to 20 matches: { citizenid, name }
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:citizens:search', function(source, query)
    local P = exports.qbx_core:GetPlayer(source)
    if not P then return {} end

    local allowed = {
        [Config.Jobs.lawyer]     = true,
        [Config.Jobs.prosecutor] = true,
        [Config.Jobs.judge]      = true,
        [Config.Jobs.police]     = true,
    }
    if not allowed[P.PlayerData.job.name] then return {} end

    if not query or #query < 2 then return {} end

    local rows = MySQL.query.await(
        "SELECT citizenid, charinfo FROM players WHERE charinfo IS NOT NULL LIMIT 500",
        {}
    )

    local q = query:lower()
    local results = {}
    for _, row in ipairs(rows or {}) do
        local ok, info = pcall(json.decode, row.charinfo)
        if ok and info then
            local first = (info.firstname or ''):lower()
            local last  = (info.lastname  or ''):lower()
            local full  = (first .. ' ' .. last):match('^%s*(.-)%s*$')
            if first:find(q, 1, true) or last:find(q, 1, true) or full:find(q, 1, true) then
                table.insert(results, {
                    citizenid = row.citizenid,
                    name      = ((info.firstname or '') .. ' ' .. (info.lastname or '')):match('^%s*(.-)%s*$'),
                })
                if #results >= 20 then break end
            end
        end
    end
    return results
end)
