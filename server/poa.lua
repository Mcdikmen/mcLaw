-- ─────────────────────────────────────────────────────────────────────────────
-- Power of attorney (vekalet)
-- Any citizen (not just DOJ) can grant or revoke a lawyer's power of attorney
-- here. Granting is only reachable through the NPC at Config.PowerOfAttorney.npc
-- (client/poa.lua opens the NUI straight to the 'poa' tab from there — there is
-- no nav button, so a plain /mclaw run never exposes it). A flat fee is billed
-- to the DOJ society (codem-billing) on every grant.
-- ─────────────────────────────────────────────────────────────────────────────

local function findSourceForCid(citizenid)
    for _, pid in ipairs(GetPlayers()) do
        local P = Mclaw.GetPlayer(tonumber(pid))
        if P and P.PlayerData.citizenid == citizenid then
            return tonumber(pid)
        end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:poa:getMyGrants
-- The requesting player's own power-of-attorney grants (as the client).
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:poa:getMyGrants', function(source)
    local P = Mclaw.GetPlayer(source)
    if not P then return {} end
    local cid = P.PlayerData.citizenid

    local rows = MySQL.query.await(
        [[SELECT id, attorney_citizenid, scope, expires_at, granted_at, is_active,
                 (is_active = 1 AND (expires_at IS NULL OR expires_at > NOW())) AS currently_active
          FROM mclaw_attorneys WHERE client_citizenid = ? ORDER BY granted_at DESC LIMIT 50]],
        { cid }
    )

    local list = {}
    for _, row in ipairs(rows or {}) do
        table.insert(list, {
            id           = row.id,
            attorneyCid  = row.attorney_citizenid,
            attorneyName = Mclaw.GetCharName(row.attorney_citizenid),
            scope        = row.scope,
            expiresAt    = row.expires_at and Mclaw.FormatTimestamp(row.expires_at) or nil,
            grantedAt    = Mclaw.FormatTimestamp(row.granted_at),
            canRevoke    = row.is_active == 1,
            currentlyActive = row.currently_active == 1,
        })
    end
    return list
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:poa:getLawyerList
-- Every registered DOJ lawyer (grade 10 Stajyer Avukat / 11 Avukat), online or
-- not — a citizen picks from this list instead of typing a citizenid.
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:poa:getLawyerList', function(source)
    local rows = MySQL.query.await(
        [[SELECT citizenid,
                 JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS firstname,
                 JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))  AS lastname,
                 JSON_UNQUOTE(JSON_EXTRACT(job, '$.grade.name'))     AS grade_name
          FROM players
          WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?
            AND JSON_UNQUOTE(JSON_EXTRACT(job, '$.grade.level')) IN ('10', '11')
          ORDER BY firstname, lastname]],
        { Config.Doj.job }
    )

    local list = {}
    for _, row in ipairs(rows or {}) do
        local name = ((row.firstname or '') .. ' ' .. (row.lastname or '')):match('^%s*(.-)%s*$')
        table.insert(list, {
            citizenid  = row.citizenid,
            name       = name ~= '' and name or row.citizenid,
            gradeLabel = row.grade_name,
        })
    end
    return list
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:poa:getMyClients
-- The requesting lawyer's own power-of-attorney grants (as the attorney).
-- Read-only on this side — only the client can revoke (mclaw:server:poa:revoke).
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:poa:getMyClients', function(source)
    local P = Mclaw.GetPlayer(source)
    if not P or Mclaw.GetRole(P) ~= Config.Jobs.lawyer then return {} end
    local cid = P.PlayerData.citizenid

    local rows = MySQL.query.await(
        [[SELECT id, client_citizenid, scope, expires_at, granted_at,
                 (is_active = 1 AND (expires_at IS NULL OR expires_at > NOW())) AS currently_active
          FROM mclaw_attorneys WHERE attorney_citizenid = ? ORDER BY granted_at DESC LIMIT 50]],
        { cid }
    )

    local list = {}
    for _, row in ipairs(rows or {}) do
        table.insert(list, {
            id              = row.id,
            clientCid       = row.client_citizenid,
            clientName      = Mclaw.GetCharName(row.client_citizenid),
            scope           = row.scope,
            expiresAt       = row.expires_at and Mclaw.FormatTimestamp(row.expires_at) or nil,
            grantedAt       = Mclaw.FormatTimestamp(row.granted_at),
            currentlyActive = row.currently_active == 1,
        })
    end
    return list
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:poa:grant
-- data.lawyerCid (string) — DOJ lawyer (grade 10/11) citizenid
-- data.days      (number) — 0/nil = süresiz (unlimited)
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:poa:grant', function(data)
    local src = source
    local P   = Mclaw.GetPlayer(src)
    if not P then return end
    local cid = P.PlayerData.citizenid

    if not data or not data.lawyerCid or data.lawyerCid == '' then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = Mclaw.T('err_missing_data') })
        return
    end
    if data.lawyerCid == cid then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = Mclaw.T('err_poa_self') })
        return
    end

    local lawyerRow = MySQL.single.await(
        [[SELECT citizenid,
                 JSON_UNQUOTE(JSON_EXTRACT(job, '$.name'))         AS job_name,
                 JSON_UNQUOTE(JSON_EXTRACT(job, '$.grade.level'))  AS grade_level
          FROM players WHERE citizenid = ?]],
        { data.lawyerCid }
    )
    local role = lawyerRow and Mclaw.RoleOf(lawyerRow.job_name, tonumber(lawyerRow.grade_level))
    if not lawyerRow or role ~= Config.Jobs.lawyer then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = Mclaw.T('err_invalid_lawyer_cid') })
        return
    end

    local existing = MySQL.scalar.await(
        "SELECT COUNT(*) FROM mclaw_attorneys WHERE attorney_citizenid = ? AND client_citizenid = ? AND is_active = 1 AND (expires_at IS NULL OR expires_at > NOW())",
        { data.lawyerCid, cid }
    )
    if existing and existing > 0 then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = Mclaw.T('err_poa_already_active') })
        return
    end

    local days = tonumber(data.days) or 0
    if days > 0 then
        MySQL.insert.await(
            "INSERT INTO mclaw_attorneys (attorney_citizenid, client_citizenid, scope, expires_at, is_active) VALUES (?, ?, 'general', DATE_ADD(NOW(), INTERVAL ? DAY), 1)",
            { data.lawyerCid, cid, days }
        )
    else
        MySQL.insert.await(
            "INSERT INTO mclaw_attorneys (attorney_citizenid, client_citizenid, scope, expires_at, is_active) VALUES (?, ?, 'general', NULL, 1)",
            { data.lawyerCid, cid }
        )
    end

    local fee = Config.PowerOfAttorney.fee or 0
    if fee > 0 then
        exports['codem-billing']:createBilling(src, src, fee, Mclaw.T('poa_invoice_label'), Config.PowerOfAttorney.society)
    end

    Mclaw.Notify(src, { position = Config.NotifyPosition,
        type        = 'success',
        title       = Mclaw.T('notify_poa_granted_title'),
        description = Mclaw.T('notify_poa_granted_desc', Mclaw.GetCharName(data.lawyerCid) or data.lawyerCid),
    })

    local lawyerSrc = findSourceForCid(data.lawyerCid)
    if lawyerSrc then
        Mclaw.Notify(lawyerSrc, {
            type        = 'inform',
            title       = Mclaw.T('notify_poa_received_title'),
            description = Mclaw.T('notify_poa_received_desc', Mclaw.GetCharName(cid) or cid),
        })
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:poa:revoke
-- data.id (number) — mclaw_attorneys.id, must belong to the requesting client
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:poa:revoke', function(data)
    local src = source
    local P   = Mclaw.GetPlayer(src)
    if not P then return end
    local cid = P.PlayerData.citizenid

    local row = MySQL.single.await(
        "SELECT id, attorney_citizenid FROM mclaw_attorneys WHERE id = ? AND client_citizenid = ? AND is_active = 1",
        { data and data.id, cid }
    )
    if not row then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = Mclaw.T('err_poa_not_found') })
        return
    end

    MySQL.update('UPDATE mclaw_attorneys SET is_active = 0, revoked_at = NOW() WHERE id = ?', { row.id })

    Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'success', description = Mclaw.T('notify_poa_revoked_desc') })

    local lawyerSrc = findSourceForCid(row.attorney_citizenid)
    if lawyerSrc then
        Mclaw.Notify(lawyerSrc, {
            type        = 'error',
            title       = Mclaw.T('notify_poa_revoked_by_client_title'),
            description = Mclaw.T('notify_poa_revoked_by_client_desc', Mclaw.GetCharName(cid) or cid),
        })
    end
end)
