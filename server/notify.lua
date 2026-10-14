-- ─────────────────────────────────────────────────────────────────────────────
-- Notices for the people a file is about (suspect / convict), online or not.
--   online  -> Mclaw.Notify now (screen + lb-phone SMS)
--   offline -> stored in mclaw_notifications (is_read = 0) and delivered when they log in
-- dbType must be one of the mclaw_notifications.type enum values.
-- ─────────────────────────────────────────────────────────────────────────────

function Mclaw.NotifyCitizen(citizenid, dbType, title, text)
    if not citizenid then return false end
    local P = Mclaw.GetPlayer(citizenid)
    if P then
        Mclaw.Notify(P.PlayerData.source, { type = 'inform', title = title, description = text, duration = 12000 })
        return true
    end
    MySQL.insert(
        'INSERT INTO mclaw_notifications (citizenid, type, title, message) VALUES (?, ?, ?, ?)',
        { citizenid, dbType, title, text }
    )
    return false
end

-- Deliver queued notices a little after login (the phone needs a moment to load its number).
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local cid = Player and Player.PlayerData and Player.PlayerData.citizenid
    if not cid then return end
    SetTimeout(20000, function()
        local P = Mclaw.GetPlayer(cid)
        if not P then return end
        local rows = MySQL.query.await(
            'SELECT id, title, message FROM mclaw_notifications WHERE citizenid = ? AND is_read = 0 ORDER BY id DESC LIMIT 8',
            { cid }
        )
        for i = #(rows or {}), 1, -1 do
            local r = rows[i]
            Mclaw.Notify(P.PlayerData.source, { type = 'inform', title = r.title, description = r.message, duration = 12000 })
        end
        MySQL.update('UPDATE mclaw_notifications SET is_read = 1, read_at = NOW() WHERE citizenid = ? AND is_read = 0', { cid })
    end)
end)
