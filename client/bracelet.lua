-- ─────────────────────────────────────────────────────────────────────────────
-- Ankle bracelets — client side
--   /kelepcetak      police at the MRPD bracelet site: fit the nearest suspect
--   /kelepcecikar    police at the site: remove the nearest wearer's bracelet
--   /bataryadegistir police within 3 m of the wearer: replace the battery
--   /kelepceler      police: list of wearers (click = GPS waypoint)
-- ─────────────────────────────────────────────────────────────────────────────

local cfg = Config.Bracelet

local function closestTarget(maxDist)
    local playerId = lib.getClosestPlayer(GetEntityCoords(cache.ped), maxDist, false)
    if not playerId then
        lib.notify({ position = Config.NotifyPosition, type = 'error', description = Mclaw.T('err_prison_no_target') })
        return nil
    end
    return GetPlayerServerId(playerId)
end

RegisterCommand(cfg.attachCommand, function()
    local target = closestTarget(4.0)
    if target then TriggerServerEvent('mclaw:server:bracelet:attach', target) end
end, false)

RegisterCommand(cfg.removeCommand, function()
    local target = closestTarget(4.0)
    if target then TriggerServerEvent('mclaw:server:bracelet:remove', target) end
end, false)

RegisterCommand(cfg.batteryCommand, function()
    local target = closestTarget(cfg.batteryDistance + 0.5)
    if target then TriggerServerEvent('mclaw:server:bracelet:battery', target) end
end, false)

-- The suspect's consent screen: long text, then two required confirmations.
RegisterNetEvent('mclaw:client:bracelet:consent', function(fileNumber)
    local proceed = lib.alertDialog({
        header   = Mclaw.T('bracelet_consent_header'),
        content  = Mclaw.T('bracelet_consent_text', fileNumber or '-'),
        centered = true,
        cancel   = true,
        size     = 'lg',
        labels   = { confirm = Mclaw.T('contest_continue'), cancel = Mclaw.T('contest_cancel') },
    })
    if proceed ~= 'confirm' then
        TriggerServerEvent('mclaw:server:bracelet:consent', false)
        return
    end

    local input = lib.inputDialog(Mclaw.T('bracelet_consent_header'), {
        { type = 'checkbox', label = Mclaw.T('bracelet_ack1'), required = true },
        { type = 'checkbox', label = Mclaw.T('bracelet_ack2'), required = true },
    })
    TriggerServerEvent('mclaw:server:bracelet:consent', input ~= nil and input[1] == true and input[2] == true)
end)

-- After the bracelet is fitted the suspect is uncuffed and released at the MRPD front.
RegisterNetEvent('mclaw:client:bracelet:release', function()
    local QBCore = exports['qb-core']:GetCoreObject()
    local ped = cache.ped

    DoScreenFadeOut(600)
    while not IsScreenFadedOut() do Wait(10) end

    local pd = QBCore.Functions.GetPlayerData()
    if pd and pd.metadata and pd.metadata.ishandcuffed then
        TriggerEvent('police:client:GetCuffed', -1) -- -1 = no cuffer, no animation
        Wait(300)
    end

    local r = Config.Sites.release.coords
    SetEntityCoords(ped, r.x, r.y, r.z - 0.98, false, false, false, false)
    SetEntityHeading(ped, r.w)
    Wait(500)
    DoScreenFadeIn(800)
end)

local function formatBattery(minutes)
    local d = math.floor(minutes / 1440)
    local h = math.floor((minutes % 1440) / 60)
    local m = minutes % 60
    return ('%dg %ds %ddk'):format(d, h, m)
end

RegisterCommand(cfg.listCommand, function()
    local list = lib.callback.await('mclaw:cb:bracelet:list', false) or {}
    if #list == 0 then
        lib.notify({ position = Config.NotifyPosition, type = 'inform', description = Mclaw.T('bracelet_menu_empty') })
        return
    end
    local options = {}
    for _, b in ipairs(list) do
        local state = Mclaw.T('bracelet_state_active')
        if b.status == 'removal_due' then
            state = Mclaw.T('bracelet_state_due')
        elseif b.battery <= 0 then
            state = Mclaw.T('bracelet_state_dead')
        end
        options[#options + 1] = {
            title       = b.name,
            description = Mclaw.T('bracelet_menu_row', b.file or '-', b.by, formatBattery(b.battery), state,
                b.online and Mclaw.T('bracelet_online') or Mclaw.T('bracelet_offline')),
            onSelect    = function()
                local loc = lib.callback.await('mclaw:cb:bracelet:locate', false, b.id)
                if loc then
                    SetNewWaypoint(loc.x + 0.0, loc.y + 0.0)
                    lib.notify({ position = Config.NotifyPosition, type = 'success', description = Mclaw.T('bracelet_gps_set', b.name) })
                else
                    lib.notify({ position = Config.NotifyPosition, type = 'error', description = Mclaw.T('bracelet_gps_none') })
                end
            end,
        }
    end
    lib.registerContext({ id = 'mclaw_bracelets', title = Mclaw.T('bracelet_menu_title'), options = options })
    lib.showContext('mclaw_bracelets')
end, false)
