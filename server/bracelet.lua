-- ─────────────────────────────────────────────────────────────────────────────
-- Ankle bracelets (County RP)
--
-- A suspect who contests the charges is fitted with a bracelet at the MRPD
-- bracelet site by an on-duty officer (/kelepcetak). The suspect must confirm
-- two statements on their own screen first. There is no time limit: the bracelet
-- stays on until the investigation ends (non-prosecution, closed file, acquittal /
-- dismissal) and the wearer is marked 'removal_due'. /kelepceler lists wearers and
-- can set a GPS waypoint. /kelepcecikar removes it at the MRPD site, and the wearer
-- can also have it removed at the MRPD ID desk NPC once it is 'removal_due'.
-- ─────────────────────────────────────────────────────────────────────────────

local cfg = Config.Bracelet

local function notify(src, kind, text, title)
    Mclaw.Notify(src, { position = Config.NotifyPosition, type = kind, description = text, title = title })
end

local function isDutyPolice(P)
    return P and Mclaw.GetRole(P) == Config.Jobs.police and P.PlayerData.job.onduty
end

local function notifyDutyPolice(kind, text)
    for _, pid in ipairs(GetPlayers()) do
        local P = Mclaw.GetPlayer(tonumber(pid))
        if isDutyPolice(P) then notify(tonumber(pid), kind, text) end
    end
end

local function officerName(P)
    local ci = P.PlayerData.charinfo or {}
    return ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):match('^%s*(.-)%s*$')
end

local function nearSite(src)
    local pos = GetEntityCoords(GetPlayerPed(src))
    local c = cfg.site.coords
    return #(pos - vector3(c.x, c.y, c.z)) <= cfg.site.radius
end

local function activeBracelet(citizenid)
    return MySQL.single.await(
        "SELECT * FROM mclaw_bracelets WHERE citizenid = ? AND status IN ('active','removal_due') ORDER BY id DESC LIMIT 1",
        { citizenid }
    )
end

-- ── Fit: officer starts, suspect confirms ────────────────────────────────────
local pendingAttach = {}   -- [suspectSrc] = { officer, fileId, fileNumber, expires }

RegisterNetEvent('mclaw:server:bracelet:attach', function(targetId)
    local src = source
    targetId  = tonumber(targetId)
    local officer = Mclaw.GetPlayer(src)
    local target  = targetId and Mclaw.GetPlayer(targetId)

    if not isDutyPolice(officer) then return notify(src, 'error', Mclaw.T('err_bracelet_not_police')) end
    if not nearSite(src)         then return notify(src, 'error', Mclaw.T('err_bracelet_not_at_site')) end
    if not target                then return notify(src, 'error', Mclaw.T('err_prison_no_target')) end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetId))) > 4.0 then
        return notify(src, 'error', Mclaw.T('err_prison_too_far'))
    end

    local cid = target.PlayerData.citizenid
    if activeBracelet(cid) then return notify(src, 'error', Mclaw.T('err_bracelet_already')) end
    if pendingAttach[targetId] and pendingAttach[targetId].expires > os.time() then
        return notify(src, 'error', Mclaw.T('err_bracelet_busy'))
    end

    -- the contested file whose investigation has been started by the officer
    local file = MySQL.single.await(
        [[SELECT f.id, f.file_number
          FROM mclaw_files f
          JOIN mclaw_jail_decisions jd ON jd.id = f.jail_decision_id
          WHERE f.suspect_citizenid = ? AND jd.decision = 'rejected'
            AND f.status NOT IN ('opened','closed','archived','verdict_issued')
            AND f.deleted_at IS NULL
          ORDER BY f.id DESC LIMIT 1]],
        { cid }
    )
    if not file then return notify(src, 'error', Mclaw.T('err_bracelet_no_file')) end

    pendingAttach[targetId] = { officer = src, fileId = file.id, fileNumber = file.file_number, expires = os.time() + 180 }
    TriggerClientEvent('mclaw:client:bracelet:consent', targetId, file.file_number)
end)

RegisterNetEvent('mclaw:server:bracelet:consent', function(accepted)
    local src = source
    local req = pendingAttach[src]
    pendingAttach[src] = nil
    if not req or req.expires < os.time() then return end

    local officer = Mclaw.GetPlayer(req.officer)
    local suspect = Mclaw.GetPlayer(src)
    if not suspect then return end

    if not accepted then
        if officer then notify(req.officer, 'error', Mclaw.T('bracelet_declined_officer')) end
        return
    end
    if activeBracelet(suspect.PlayerData.citizenid) then return end

    MySQL.insert.await(
        'INSERT INTO mclaw_bracelets (citizenid, file_id, file_number, attached_by_citizenid, attached_by_name) VALUES (?, ?, ?, ?, ?)',
        { suspect.PlayerData.citizenid, req.fileId, req.fileNumber,
          officer and officer.PlayerData.citizenid or nil, officer and officerName(officer) or nil }
    )

    local name = Mclaw.GetCharName(suspect.PlayerData.citizenid) or suspect.PlayerData.citizenid
    if officer then notify(req.officer, 'success', Mclaw.T('bracelet_attached_officer', name, req.fileNumber)) end
    notify(src, 'inform', Mclaw.T('bracelet_attached_suspect', req.fileNumber))
    TriggerClientEvent('mclaw:client:bracelet:release', src)
end)

-- ── Removal at the site ──────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:bracelet:remove', function(targetId)
    local src = source
    targetId  = tonumber(targetId)
    local officer = Mclaw.GetPlayer(src)
    local target  = targetId and Mclaw.GetPlayer(targetId)
    if not isDutyPolice(officer) then return notify(src, 'error', Mclaw.T('err_bracelet_not_police')) end
    if not nearSite(src)         then return notify(src, 'error', Mclaw.T('err_bracelet_not_at_site')) end
    if not target                then return notify(src, 'error', Mclaw.T('err_prison_no_target')) end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetId))) > 4.0 then
        return notify(src, 'error', Mclaw.T('err_prison_too_far'))
    end

    local b = activeBracelet(target.PlayerData.citizenid)
    if not b then return notify(src, 'error', Mclaw.T('err_bracelet_none')) end

    MySQL.update.await(
        "UPDATE mclaw_bracelets SET status = 'removed', removed_at = NOW(), removed_by = ? WHERE id = ?",
        { officerName(officer), b.id }
    )
    local name = Mclaw.GetCharName(target.PlayerData.citizenid) or target.PlayerData.citizenid
    notify(src, 'success', Mclaw.T('bracelet_removed_officer', name))
    notify(targetId, 'inform', Mclaw.T('bracelet_removed_suspect'))
end)

-- ── Self-removal at the MRPD ID desk NPC (county-idnpc) ──────────────────────
-- State of the wearer's bracelet: nil (none) | 'active' | 'removal_due'.
exports('GetBraceletState', function(src)
    local P = Mclaw.GetPlayer(src)
    if not P then return nil end
    local b = activeBracelet(P.PlayerData.citizenid)
    return b and b.status or nil, b and b.file_number or nil
end)

-- Removes the bracelet only when the investigation has ended ('removal_due').
-- Returns true on success, or false + reason ('none' | 'active').
exports('RemoveOwnBracelet', function(src)
    local P = Mclaw.GetPlayer(src)
    if not P then return false, 'none' end
    local b = activeBracelet(P.PlayerData.citizenid)
    if not b then return false, 'none' end
    if b.status ~= 'removal_due' then return false, 'active' end
    MySQL.update.await(
        "UPDATE mclaw_bracelets SET status = 'removed', removed_at = NOW(), removed_by = ? WHERE id = ?",
        { 'MRPD ID desk', b.id }
    )
    return true
end)

-- ── Hooks used by other modules ──────────────────────────────────────────────
-- Mark the bracelet as due for removal (case ended); officers are told.
function Mclaw.BraceletDueFor(citizenid, reason)
    local b = activeBracelet(citizenid)
    if not b or b.status ~= 'active' then return end
    MySQL.update.await("UPDATE mclaw_bracelets SET status = 'removal_due', removal_reason = ? WHERE id = ?", { reason, b.id })
    local name = Mclaw.GetCharName(citizenid) or citizenid
    notifyDutyPolice('inform', Mclaw.T('bracelet_removal_due', name, b.file_number or '-', reason))
    Mclaw.NotifyCitizen(citizenid, 'subpoena', Mclaw.T('suspect_bracelet_title'), Mclaw.T('suspect_bracelet_due', b.file_number or '-'))
end

-- Remove outright (the wearer goes to prison, the bracelet is no longer relevant).
function Mclaw.BraceletRemoveFor(citizenid, reason)
    local b = activeBracelet(citizenid)
    if not b then return end
    MySQL.update.await(
        "UPDATE mclaw_bracelets SET status = 'removed', removed_at = NOW(), removed_by = ?, removal_reason = ? WHERE id = ?",
        { reason, reason, b.id }
    )
end

-- ── /kelepceler data ─────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:bracelet:list', function(source)
    local P = Mclaw.GetPlayer(source)
    if Mclaw.GetRole(P) ~= Config.Jobs.police then return {} end
    local rows = MySQL.query.await(
        "SELECT id, citizenid, file_number, attached_by_name, status, attached_at FROM mclaw_bracelets WHERE status IN ('active','removal_due') ORDER BY id DESC LIMIT 50"
    )
    local list = {}
    for _, r in ipairs(rows or {}) do
        list[#list + 1] = {
            id        = r.id,
            name      = Mclaw.GetCharName(r.citizenid) or r.citizenid,
            file      = r.file_number,
            by        = r.attached_by_name or '-',
            status    = r.status,
            online    = Mclaw.GetPlayer(r.citizenid) ~= nil,
        }
    end
    return list
end)

lib.callback.register('mclaw:cb:bracelet:locate', function(source, braceletId)
    local P = Mclaw.GetPlayer(source)
    if Mclaw.GetRole(P) ~= Config.Jobs.police then return nil end
    local b = MySQL.single.await('SELECT citizenid, last_x, last_y, last_z FROM mclaw_bracelets WHERE id = ?', { braceletId })
    if not b then return nil end
    local target = Mclaw.GetPlayer(b.citizenid)
    if target then
        local c = GetEntityCoords(GetPlayerPed(target.PlayerData.source))
        return { x = c.x, y = c.y, z = c.z, online = true }
    end
    if b.last_x then return { x = b.last_x, y = b.last_y, z = b.last_z, online = false } end
    return nil
end)

-- ── Location tracking: last known position, once per ONLINE minute ──────────
CreateThread(function()
    while true do
        Wait(60000)
        local rows = MySQL.query.await(
            "SELECT id, citizenid FROM mclaw_bracelets WHERE status IN ('active','removal_due')"
        )
        for _, b in ipairs(rows or {}) do
            local P = Mclaw.GetPlayer(b.citizenid)
            if P then
                local c = GetEntityCoords(GetPlayerPed(P.PlayerData.source))
                MySQL.update(
                    'UPDATE mclaw_bracelets SET last_x = ?, last_y = ?, last_z = ?, last_seen = NOW() WHERE id = ?',
                    { c.x, c.y, c.z, b.id }
                )
            end
        end
    end
end)
