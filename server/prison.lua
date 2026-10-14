-- ─────────────────────────────────────────────────────────────────────────────
-- Sentence enforcement (County RP)
--
-- A guilty verdict / accepted charges only creates a PENDING sentence
-- (mclaw_sentences). Nobody is teleported. An on-duty police officer has to
-- bring the convict to the prison intake and run /hapisteslim next to them;
-- only then the convict is jailed through qb-prison (same hand-off qb-policejob
-- uses), the court fine is invoiced, and codem-mdt shows the prison status.
-- ─────────────────────────────────────────────────────────────────────────────

local function notify(src, kind, text)
    TriggerClientEvent('ox_lib:notify', src, { type = kind, description = text })
end

local function isOnDutyPolice(P)
    return P and Mclaw.GetRole(P) == Config.Jobs.police and P.PlayerData.job.onduty
end

-- CreateSentence(fileId, citizenid, minutes, fine, origin, reason) -> id | nil
function Mclaw.CreateSentence(fileId, citizenid, minutes, fine, origin, reason)
    minutes = tonumber(minutes) or 0
    fine    = tonumber(fine) or 0
    if minutes <= 0 and fine <= 0 then return nil end

    local id = MySQL.insert.await(
        'INSERT INTO mclaw_sentences (file_id, citizenid, jail_minutes, fine, origin, reason) VALUES (?, ?, ?, ?, ?, ?)',
        { fileId, citizenid, minutes, fine, origin or 'verdict', reason }
    )

    local convict = Mclaw.GetPlayer(citizenid)
    if convict then
        notify(convict.PlayerData.source, 'inform', Mclaw.T('sentence_pending_convict', minutes, fine))
    end
    for _, pid in ipairs(GetPlayers()) do
        local P = Mclaw.GetPlayer(tonumber(pid))
        if isOnDutyPolice(P) then
            notify(tonumber(pid), 'inform', Mclaw.T('sentence_pending_police', reason or '-', minutes))
        end
    end
    return id
end

local function pendingFor(cid)
    return MySQL.single.await(
        "SELECT id, file_id, jail_minutes, fine, reason FROM mclaw_sentences WHERE citizenid = ? AND status = 'pending' ORDER BY id ASC LIMIT 1",
        { cid }
    )
end

-- ── /hukumler : pending sentences list (police) ─────────────────────────────
lib.callback.register('mclaw:cb:prison:getPending', function(source)
    local P = Mclaw.GetPlayer(source)
    if Mclaw.GetRole(P) ~= Config.Jobs.police then return {} end
    local rows = MySQL.query.await(
        "SELECT id, citizenid, jail_minutes, fine, reason FROM mclaw_sentences WHERE status = 'pending' ORDER BY id ASC LIMIT 50"
    )
    local list = {}
    for _, r in ipairs(rows or {}) do
        list[#list + 1] = {
            id      = r.id,
            name    = Mclaw.GetCharName(r.citizenid) or r.citizenid,
            minutes = r.jail_minutes,
            fine    = r.fine,
            reason  = r.reason,
        }
    end
    return list
end)

-- ── /hapisteslim : deliver the convict at the prison intake ─────────────────
RegisterNetEvent('mclaw:server:prison:deliver', function(targetId)
    local src = source
    targetId  = tonumber(targetId)
    local officer = Mclaw.GetPlayer(src)
    local target  = targetId and Mclaw.GetPlayer(targetId)

    if not isOnDutyPolice(officer) then
        return notify(src, 'error', Mclaw.T('err_prison_not_police'))
    end
    if not target then
        return notify(src, 'error', Mclaw.T('err_prison_no_target'))
    end

    local officerCoords = GetEntityCoords(GetPlayerPed(src))
    local targetCoords  = GetEntityCoords(GetPlayerPed(targetId))
    if #(officerCoords - targetCoords) > 3.0 then
        return notify(src, 'error', Mclaw.T('err_prison_too_far'))
    end

    local sentence = pendingFor(target.PlayerData.citizenid)
    if not sentence then
        return notify(src, 'error', Mclaw.T('err_prison_no_sentence'))
    end

    local minutes = tonumber(sentence.jail_minutes) or 0
    if minutes > 0 then
        if #(officerCoords - Config.Prison.intake) > Config.Prison.intakeRadius then
            return notify(src, 'error', Mclaw.T('err_prison_not_at_intake'))
        end
        if Config.Prison.requireCuffs and not target.PlayerData.metadata.ishandcuffed then
            return notify(src, 'error', Mclaw.T('err_prison_not_cuffed'))
        end
    end

    -- Claim the sentence first so a double command cannot serve it twice.
    local claimed = MySQL.update.await(
        "UPDATE mclaw_sentences SET status = 'served', served_at = NOW(), served_by_citizenid = ? WHERE id = ? AND status = 'pending'",
        { officer.PlayerData.citizenid, sentence.id }
    )
    if not claimed or claimed < 1 then return end

    local fine = tonumber(sentence.fine) or 0
    if fine > 0 then
        local label = Mclaw.T('sentence_fine_label', sentence.reason or '-')
        local ok = pcall(function()
            exports['codem-billing']:createBilling(src, targetId, fine, label, Config.Prison.fineSociety)
        end)
        if not ok then
            print('[mcLaw] court fine invoice failed for sentence #' .. sentence.id)
        end
    end

    if minutes > 0 then
        Mclaw.BraceletRemoveFor(target.PlayerData.citizenid, 'hapis')
        local now = os.date('*t')
        if now.day == 31 then now.day = 30 end
        target.Functions.SetMetaData('injail', minutes)
        target.Functions.SetMetaData('criminalrecord', { hasRecord = true, date = now })
        -- Same hand-off qb-policejob uses: uncuffs, then prison:client:Enter.
        TriggerClientEvent('police:client:SendToJail', targetId, minutes)
        pcall(function()
            exports['codem-mdt']:sendToPrison(targetId, minutes, sentence.reason or 'mcLaw')
        end)
    end

    notify(src, 'success', Mclaw.T('sentence_served_officer', minutes, fine))
    notify(targetId, 'inform', Mclaw.T('sentence_served_convict', minutes))
end)

-- Release in the MDT when qb-prison reports the sentence is over.
RegisterNetEvent('prison:server:SetJailStatus', function(jailTime)
    local src = source
    if tonumber(jailTime) == 0 then
        pcall(function() exports['codem-mdt']:releaseFromPrison(src) end)
    end
end)
