-- ─────────────────────────────────────────────────────────────────────────────
-- Power of attorney NPC (vekalet masası), qb-target just like county-idnpc.
-- Any citizen can target this ped and grant/revoke a lawyer's power of
-- attorney. This is the only entry point into the 'poa' NUI tab — there is no
-- nav button for it, so a plain /mclaw run never exposes it (client.lua).
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
    if not HasModelLoaded(model) then return end

    npc = CreatePed(4, model, npcCfg.coords.x, npcCfg.coords.y, npcCfg.coords.z, npcCfg.coords.w, false, false)
    PlaceObjectOnGroundProperly(npc)
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

RegisterNetEvent('mclaw:client:poaMenu', function()
    TriggerEvent('mclaw:client:openPanel', 'poa')
end)

-- /mclawpoa : diagnostic — distance to the NPC and whether it has spawned (any player)
RegisterCommand('mclawpoa', function()
    local dist = #(GetEntityCoords(PlayerPedId()) - vector3(npcCfg.coords.x, npcCfg.coords.y, npcCfg.coords.z))
    lib.notify({
        position = Config.NotifyPosition, duration = 10000, type = 'inform',
        description = ('Vekalet NPC mesafe: %.1f m | Spawn oldu mu: %s | viewDistance: %s m'):format(
            dist, tostring(npc ~= nil and DoesEntityExist(npc)), tostring(npcCfg.viewDistance or 10.0)),
    })
end, false)
