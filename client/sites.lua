-- ─────────────────────────────────────────────────────────────────────────────
-- MRPD referral hologram (police only) + the /mclaw gate for police.
-- Ring on the ground and a floating label at Config.Sites.referral.
-- ─────────────────────────────────────────────────────────────────────────────

local QBCore = exports['qb-core']:GetCoreObject()

local function myRole()
    local pd = QBCore.Functions.GetPlayerData()
    local job = pd and pd.job
    if not job then return nil end
    return Mclaw.RoleOf(job.name, job.grade and job.grade.level)
end

-- True if the local player may open the panel: only police are restricted to the hologram.
function Mclaw.CanOpenPanel()
    if myRole() ~= Config.Jobs.police then return true end
    return Mclaw.IsNear(GetEntityCoords(cache.ped), Config.Sites.referral)
end

local function drawLabel(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextFont(4)
    SetTextScale(0.0, 0.42)
    SetTextColour(255, 255, 255, 235)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

-- Holograms (police only, visible only up close): referral spot + bracelet spot
local holograms = { Config.Sites.referral, Config.Bracelet.site }

CreateThread(function()
    while true do
        local wait = 1000
        if myRole() == Config.Jobs.police then
            local pos = GetEntityCoords(cache.ped)
            for _, site in ipairs(holograms) do
                local c = site.coords
                if #(pos - vector3(c.x, c.y, c.z)) < (site.viewDistance or 7.0) then
                    wait = 0
                    -- ring on the ground (ped z is ~1.0 above the floor)
                    DrawMarker(1, c.x, c.y, c.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        1.6, 1.6, 0.25, 212, 175, 55, 140, false, false, 2, false, nil, nil, false)
                    drawLabel(c.x, c.y, c.z + 0.6, site.label or '')
                end
            end
        end
        Wait(wait)
    end
end)

-- /mclawsites : diagnostic — role and distance to each hologram (any player)
RegisterCommand('mclawsites', function()
    local pos = GetEntityCoords(cache.ped)
    local function d(site) local c = site.coords; return ('%.1f m'):format(#(pos - vector3(c.x, c.y, c.z))) end
    lib.notify({
        position = Config.NotifyPosition, duration = 12000, type = 'inform',
        description = ('Rol: %s | Sevk: %s | Bileklik: %s | Görünür mesafe: %s m'):format(
            tostring(myRole()), d(Config.Sites.referral), d(Config.Bracelet.site), tostring(Config.Bracelet.site.viewDistance)),
    })
end, false)
