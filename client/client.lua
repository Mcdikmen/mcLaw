-- ─────────────────────────────────────────────────────────────────────────────
-- /mclaw — tek giriş noktası. Job bilgisi + gerekli verileri NUI'ye gönderir.
-- ─────────────────────────────────────────────────────────────────────────────

local function getJob()
    local Player = exports.qbx_core:GetPlayerData()
    return Player and Player.job and Player.job.name or 'civilian'
end

-- Yakındaki oyuncuları döner (10 m). Police sevk formu için kullanılır.
local function getNearbyPlayerOptions()
    local options  = {}
    local myPed    = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local ped    = GetPlayerPed(playerId)
            local coords = GetEntityCoords(ped)
            if #(myCoords - coords) <= 10.0 then
                table.insert(options, {
                    label = GetPlayerName(playerId) .. ' [' .. GetPlayerServerId(playerId) .. ']',
                    value = tostring(GetPlayerServerId(playerId)),
                })
            end
        end
    end

    return options
end

local function openPanel(activeTab)
    local job = getJob()

    local stats    = lib.callback.await('mclaw:cb:dashboard:getStats', false) or {}
    local docTypes = Config.DocTypes or {}

    local payload = {
        action      = 'show',
        job         = job,
        activeTab   = activeTab or 'dashboard',
        dashStats   = stats,
        docTypeList = docTypes,
    }

    if job == Config.Jobs.police then
        payload.nearbyPlayers = getNearbyPlayerOptions()
        payload.chargeList    = lib.callback.await('mclaw:cb:referral:getChargeList', false) or {}
    elseif job == Config.Jobs.prosecutor or job == Config.Jobs.judge then
        payload.prosecutorFiles = lib.callback.await('mclaw:cb:prosecutor:getFiles', false) or {}
    end

    local fileOpenJobs = {
        [Config.Jobs.prosecutor] = true,
        [Config.Jobs.judge]      = true,
        [Config.Jobs.lawyer]     = true,
    }
    if fileOpenJobs[job] then
        payload.fileOpenChargeList = lib.callback.await('mclaw:cb:referral:getChargeList', false) or {}
    end
    if job == Config.Jobs.judge then
        payload.pendingApprovals    = lib.callback.await('mclaw:cb:judge:getPendingApprovals', false) or {}
        payload.hearingList         = lib.callback.await('mclaw:cb:hearings:getList', false) or {}
        payload.incomingPetitions   = lib.callback.await('mclaw:cb:judge:getIncomingPetitions', false) or {}
    elseif job == Config.Jobs.lawyer then
        payload.hearingList = lib.callback.await('mclaw:cb:hearings:getList', false) or {}
        payload.myPetitions = lib.callback.await('mclaw:cb:lawyer:getMyPetitions', false) or {}
    elseif job == Config.Jobs.prosecutor then
        payload.incomingPetitions = lib.callback.await('mclaw:cb:prosecutor:getIncomingPetitions', false) or {}
    end

    SetNuiFocus(true, true)
    SendNUIMessage(payload)
end

RegisterCommand('mclaw', function()
    openPanel()
end, false)

AddEventHandler('mclaw:client:openPanel', function(activeTab)
    openPanel(activeTab)
end)

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb({})
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Referral form submit (NUI → client → server)
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNUICallback('referral:submit', function(data, cb)
    if not data.suspectSource or not data.charges or not data.narrative then
        cb({ ok = false, error = 'Eksik veri.' })
        return
    end

    TriggerServerEvent('mclaw:server:referral:submit', {
        suspectSource = data.suspectSource,
        charges       = data.charges,
        narrative     = data.narrative,
    })

    cb({ ok = true })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Prosecutor: indictment submit (NUI → client → server)
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNUICallback('prosecutor:submitIndictment', function(data, cb)
    if not data.fileId or not data.hearingType then
        cb({ ok = false, error = 'Eksik veri.' })
        return
    end

    TriggerServerEvent('mclaw:server:prosecutor:submitIndictment', {
        fileId      = data.fileId,
        hearingType = data.hearingType,
        notes       = data.notes or '',
    })

    cb({ ok = true })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Manual file opening: prosecutor / judge / lawyer
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNUICallback('fileopening:openFile', function(data, cb)
    if not data.suspectCid or not data.charges or not data.narrative then
        cb({ ok = false, error = 'Eksik veri.' })
        return
    end
    TriggerServerEvent('mclaw:server:fileopening:openFile', {
        suspectCid = data.suspectCid,
        charges    = data.charges,
        narrative  = data.narrative,
        notes      = data.notes or '',
    })
    cb({ ok = true })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Judge: approve / reject pending file
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNUICallback('judge:approveFile', function(data, cb)
    if not data.fileId then cb({ ok = false, error = 'Eksik veri.' }); return end
    TriggerServerEvent('mclaw:server:judge:approveFile', {
        fileId = data.fileId,
        notes  = data.notes or '',
    })
    cb({ ok = true })
end)

RegisterNUICallback('judge:rejectFile', function(data, cb)
    if not data.fileId then cb({ ok = false, error = 'Eksik veri.' }); return end
    TriggerServerEvent('mclaw:server:judge:rejectFile', {
        fileId = data.fileId,
        reason = data.reason or '',
    })
    cb({ ok = true })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Judge: accept indictment_ready file → hearing_scheduled (dava aç)
-- ─────────────────────────────────────────────────────────────────────────────
-- ─────────────────────────────────────────────────────────────────────────────
-- File detail view
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNUICallback('file:getDetail', function(data, cb)
    if not data.fileId then cb({ ok = false }); return end
    local detail = lib.callback.await('mclaw:cb:file:getDetail', false, data.fileId)
    if detail then
        cb({ ok = true, data = detail })
    else
        cb({ ok = false })
    end
end)

RegisterNUICallback('file:addDocument', function(data, cb)
    if not data.fileId or not data.docType or not data.title or not data.content then
        cb({ ok = false, error = 'Eksik veri.' }); return
    end
    TriggerServerEvent('mclaw:server:file:addDocument', {
        fileId  = data.fileId,
        docType = data.docType,
        title   = data.title,
        content = data.content,
    })
    cb({ ok = true })
end)

RegisterNUICallback('judge:closeFile', function(data, cb)
    if not data.fileId then cb({ ok = false, error = 'Eksik veri.' }); return end
    TriggerServerEvent('mclaw:server:judge:closeFile', {
        fileId = data.fileId,
        reason = data.reason or '',
    })
    cb({ ok = true })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Judge: accept indictment_ready file → hearing_scheduled (dava aç)
-- ─────────────────────────────────────────────────────────────────────────────
-- ─────────────────────────────────────────────────────────────────────────────
-- Tab refresh: NUI sekme geçişinde taze veri çeker
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNUICallback('tab:refresh', function(data, cb)
    local job = getJob()
    local tab = data.tab
    local update = { action = 'tabUpdate' }

    if tab == 'dashboard' then
        update.dashStats = lib.callback.await('mclaw:cb:dashboard:getStats', false) or {}

    elseif tab == 'files' then
        if job == Config.Jobs.prosecutor or job == Config.Jobs.judge then
            update.prosecutorFiles = lib.callback.await('mclaw:cb:prosecutor:getFiles', false) or {}
        end

    elseif tab == 'approvals' then
        if job == Config.Jobs.judge then
            update.pendingApprovals = lib.callback.await('mclaw:cb:judge:getPendingApprovals', false) or {}
        end

    elseif tab == 'hearings' then
        if job == Config.Jobs.judge or job == Config.Jobs.lawyer then
            update.hearingList = lib.callback.await('mclaw:cb:hearings:getList', false) or {}
        end

    elseif tab == 'referral' then
        if job == Config.Jobs.police then
            update.nearbyPlayers = getNearbyPlayerOptions()
            update.chargeList    = lib.callback.await('mclaw:cb:referral:getChargeList', false) or {}
        end

    elseif tab == 'mypetitions' then
        if job == Config.Jobs.lawyer then
            update.myPetitions = lib.callback.await('mclaw:cb:lawyer:getMyPetitions', false) or {}
        end

    elseif tab == 'inpetitions' then
        if job == Config.Jobs.prosecutor then
            update.incomingPetitions = lib.callback.await('mclaw:cb:prosecutor:getIncomingPetitions', false) or {}
        elseif job == Config.Jobs.judge then
            update.incomingPetitions = lib.callback.await('mclaw:cb:judge:getIncomingPetitions', false) or {}
        end
    end

    SendNUIMessage(update)
    cb({})
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Judge: accept indictment_ready file → hearing_scheduled (dava aç)
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNUICallback('judge:acceptCase', function(data, cb)
    if not data.fileId or not data.scheduledAt then cb({ ok = false, error = 'Eksik veri.' }); return end
    TriggerServerEvent('mclaw:server:judge:acceptCase', {
        fileId      = data.fileId,
        scheduledAt = data.scheduledAt,
        hearingType = data.hearingType or 'physical',
        notes       = data.notes or '',
    })
    cb({ ok = true })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Dilekçe sistemi NUI callbacks
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNUICallback('lawyer:sendPetition', function(data, cb)
    if not data.petitionType or not data.plaintiffCid or not data.subject or not data.description then
        cb({ ok = false, error = 'Eksik veri.' }); return
    end
    TriggerServerEvent('mclaw:server:lawyer:sendPetition', {
        petitionType  = data.petitionType,
        plaintiffCid  = data.plaintiffCid,
        charges       = data.charges or {},
        subject       = data.subject,
        description   = data.description,
        attachments   = data.attachments or {},
    })
    cb({ ok = true })
end)

RegisterNUICallback('prosecutor:acceptPetition', function(data, cb)
    if not data.petitionId then cb({ ok = false, error = 'Eksik veri.' }); return end
    TriggerServerEvent('mclaw:server:prosecutor:acceptPetition', { petitionId = data.petitionId })
    cb({ ok = true })
end)

RegisterNUICallback('prosecutor:rejectPetition', function(data, cb)
    if not data.petitionId then cb({ ok = false, error = 'Eksik veri.' }); return end
    TriggerServerEvent('mclaw:server:prosecutor:rejectPetition', {
        petitionId = data.petitionId,
        reason     = data.reason or '',
    })
    cb({ ok = true })
end)

RegisterNUICallback('judge:acceptCivilPetition', function(data, cb)
    if not data.petitionId then cb({ ok = false, error = 'Eksik veri.' }); return end
    TriggerServerEvent('mclaw:server:judge:acceptCivilPetition', { petitionId = data.petitionId })
    cb({ ok = true })
end)

RegisterNUICallback('judge:rejectCivilPetition', function(data, cb)
    if not data.petitionId then cb({ ok = false, error = 'Eksik veri.' }); return end
    TriggerServerEvent('mclaw:server:judge:rejectCivilPetition', {
        petitionId = data.petitionId,
        reason     = data.reason or '',
    })
    cb({ ok = true })
end)
