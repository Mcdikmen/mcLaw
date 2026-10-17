-- ─────────────────────────────────────────────────────────────────────────────
-- Power of attorney NPC (vekalet masası), qb-target + qb-menu just like
-- county-idnpc — no tablet prop, no mcLaw NUI panel. Any citizen can target
-- this ped and grant/revoke a lawyer's power of attorney by picking a lawyer
-- from a list (no citizenid typing required).
-- ─────────────────────────────────────────────────────────────────────────────

local npcCfg = Config.PowerOfAttorney.npc
local npc = nil

local function removeNpc()
    if npc and DoesEntityExist(npc) then
        exports['qb-target']:RemoveTargetEntity(npc)
        DeleteEntity(npc)
    end
    npc = nil
end

local function spawnNpc()
    local model = GetHashKey(npcCfg.model)
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 100 do Wait(50); t = t + 1 end
    if not HasModelLoaded(model) then
        print(('[mcLaw] poa.lua: model "%s" failed to load (bad name or not streamed on this build)'):format(npcCfg.model))
        return
    end

    npc = CreatePed(4, model, npcCfg.coords.x, npcCfg.coords.y, npcCfg.coords.z, npcCfg.coords.w, false, false)
    SetEntityHeading(npc, npcCfg.coords.w)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetPedFleeAttributes(npc, 0, false)
    SetPedCanRagdoll(npc, false)
    TaskStartScenarioInPlace(npc, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    SetModelAsNoLongerNeeded(model)

    exports['qb-target']:AddTargetEntity(npc, {
        options = {
            {
                type  = 'client',
                event = 'mclaw:client:poaMenu',
                icon  = 'fas fa-file-signature',
                label = npcCfg.label or 'Vekalet Masası',
            },
        },
        distance = npcCfg.interactDist or 2.5,
    })
end

CreateThread(function()
    while true do
        local dist = #(GetEntityCoords(PlayerPedId()) - vector3(npcCfg.coords.x, npcCfg.coords.y, npcCfg.coords.z))
        if dist < (npcCfg.viewDistance or 10.0) and not npc then
            spawnNpc()
        elseif dist > (npcCfg.viewDistance or 10.0) + 20.0 and npc then
            removeNpc()
        end
        Wait(1500)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then removeNpc() end
end)

-- qb-target forgets every registered target when it restarts; respawn the NPC so the target is re-added
AddEventHandler('onResourceStart', function(resource)
    if resource == 'qb-target' then removeNpc() end
end)

local function money(amount)
    local s = tostring(amount)
    while true do
        local replaced
        s, replaced = s:gsub('^(-?%d+)(%d%d%d)', '%1.%2')
        if replaced == 0 then break end
    end
    return s
end

RegisterNetEvent('mclaw:client:poaMenu', function()
    exports['qb-menu']:openMenu({
        { header = 'Vekalet Masası', isMenuHeader = true },
        { header = 'Vekalet Ver', txt = 'Bir avukata vekalet verin', params = { event = 'mclaw:client:poaPickLawyer' } },
        { header = 'Vekaletlerim', txt = 'Verdiğiniz vekaletleri görüntüleyin / iptal edin', params = { event = 'mclaw:client:poaMyGrants' } },
        { header = 'Kapat', params = { event = 'qb-menu:client:closeMenu' } },
    })
end)

RegisterNetEvent('mclaw:client:poaPickLawyer', function()
    local lawyers = lib.callback.await('mclaw:cb:poa:getLawyerList', false) or {}
    local menu = { { header = 'Avukat Seçin', isMenuHeader = true } }
    if #lawyers == 0 then
        table.insert(menu, { header = 'Kayıtlı avukat yok', disabled = true })
    else
        for _, l in ipairs(lawyers) do
            table.insert(menu, {
                header = l.name or l.citizenid,
                txt    = l.gradeLabel or '',
                params = { event = 'mclaw:client:poaPickDuration', args = { lawyerCid = l.citizenid, lawyerName = l.name } },
            })
        end
    end
    table.insert(menu, { header = 'Geri', params = { event = 'mclaw:client:poaMenu' } })
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('mclaw:client:poaPickDuration', function(data)
    local menu = { { header = (data.lawyerName or data.lawyerCid) .. ' — Süre Seçin', isMenuHeader = true } }
    for _, d in ipairs(Config.PowerOfAttorney.durations or {}) do
        table.insert(menu, {
            header = d.label,
            txt    = ('Ücret: $%s'):format(money(d.fee or 0)),
            params = { event = 'mclaw:client:poaConfirmGrant', args = {
                lawyerCid = data.lawyerCid, lawyerName = data.lawyerName, days = d.days or 0, label = d.label, fee = d.fee or 0,
            } },
        })
    end
    table.insert(menu, { header = 'Geri', params = { event = 'mclaw:client:poaPickLawyer' } })
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('mclaw:client:poaConfirmGrant', function(data)
    exports['qb-menu']:openMenu({
        { header = 'Vekaleti Onayla', isMenuHeader = true },
        { header = data.lawyerName or data.lawyerCid, txt = data.label or '' },
        { header = ('Ücret: $%s'):format(money(data.fee or 0)), disabled = true },
        { header = 'Vekalet Ver', params = { event = 'mclaw:client:poaDoGrant', args = { lawyerCid = data.lawyerCid, days = data.days } } },
        { header = 'Vazgeç', params = { event = 'mclaw:client:poaMenu' } },
    })
end)

RegisterNetEvent('mclaw:client:poaDoGrant', function(data)
    TriggerServerEvent('mclaw:server:poa:grant', { lawyerCid = data.lawyerCid, days = data.days })
end)

RegisterNetEvent('mclaw:client:poaMyGrants', function()
    local grants = lib.callback.await('mclaw:cb:poa:getMyGrants', false) or {}
    local menu = { { header = 'Vekaletlerim', isMenuHeader = true } }
    if #grants == 0 then
        table.insert(menu, { header = 'Henüz kimseye vekalet vermediniz', disabled = true })
    else
        for _, g in ipairs(grants) do
            local status = g.currentlyActive and 'Aktif' or (g.canRevoke and 'Süresi Doldu' or 'İptal Edildi')
            local row = {
                header = (g.attorneyName or g.attorneyCid) .. ' — ' .. status,
                txt    = 'Süre: ' .. (g.expiresAt or 'Süresiz'),
            }
            if g.canRevoke then
                row.params = { event = 'mclaw:client:poaConfirmRevoke', args = { id = g.id, name = g.attorneyName or g.attorneyCid } }
            else
                row.disabled = true
            end
            table.insert(menu, row)
        end
    end
    table.insert(menu, { header = 'Geri', params = { event = 'mclaw:client:poaMenu' } })
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('mclaw:client:poaConfirmRevoke', function(data)
    exports['qb-menu']:openMenu({
        { header = 'Vekaleti İptal Et', isMenuHeader = true },
        { header = data.name, txt = 'Bu vekaleti iptal etmek istediğinize emin misiniz?' },
        { header = 'Evet, İptal Et', params = { event = 'mclaw:client:poaDoRevoke', args = { id = data.id } } },
        { header = 'Vazgeç', params = { event = 'mclaw:client:poaMyGrants' } },
    })
end)

RegisterNetEvent('mclaw:client:poaDoRevoke', function(data)
    TriggerServerEvent('mclaw:server:poa:revoke', { id = data.id })
end)

-- /mclawpoaground : diagnostic — your current coords vs. the real ground Z the
-- engine finds at that x/y (any player). Use this to get an accurate spawn
-- coordinate instead of a coord-grab tool that may add a standing/eye offset.
RegisterCommand('mclawpoaground', function()
    local coords = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 5.0, false)
    lib.notify({
        position = Config.NotifyPosition, duration = 15000, type = 'inform',
        description = ('Mevcut: %.2f, %.2f, %.2f | Zemin Z: %s | vector4(%.2f, %.2f, %.2f, %.2f)'):format(
            coords.x, coords.y, coords.z,
            found and ('%.2f'):format(groundZ) or 'bulunamadı',
            coords.x, coords.y, found and groundZ or coords.z, heading),
    })
end, false)

-- /mclawpoa : diagnostic — distance to the NPC and whether it has spawned (any player)
RegisterCommand('mclawpoa', function()
    local dist = #(GetEntityCoords(PlayerPedId()) - vector3(npcCfg.coords.x, npcCfg.coords.y, npcCfg.coords.z))
    lib.notify({
        position = Config.NotifyPosition, duration = 10000, type = 'inform',
        description = ('Vekalet NPC mesafe: %.1f m | Spawn oldu mu: %s | viewDistance: %s m'):format(
            dist, tostring(npc ~= nil and DoesEntityExist(npc)), tostring(npcCfg.viewDistance or 10.0)),
    })
end, false)
