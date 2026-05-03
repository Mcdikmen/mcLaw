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

    local payload = {
        action    = 'show',
        job       = job,
        activeTab = activeTab or 'dashboard',
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
        payload.pendingApprovals = lib.callback.await('mclaw:cb:judge:getPendingApprovals', false) or {}
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
