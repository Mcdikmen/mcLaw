-- ─────────────────────────────────────────────────────────────────────────────
-- Charge list = static Turkish list from Config.Charges.list
--             + codem-mdt penal entries (table mmdt_fines) when
--               Config.MDT.provider == 'codem-mdt' and pullCharges is on.
-- The MDT stays the master of its own entries: edit them in the MDT "fines"
-- page and mcLaw picks them up (codes are 'mdt_<id>').
-- Everything server-side resolves charges through Config.Charges.list, so the
-- merged list is written back into it.
-- ─────────────────────────────────────────────────────────────────────────────

local staticList  = nil
local lastRefresh = 0

function Mclaw.RefreshCharges(force)
    if not staticList then staticList = Config.Charges.list end
    if not force and (GetGameTimer() - lastRefresh) < 60000 then return end
    lastRefresh = GetGameTimer()

    local merged = {}
    for _, c in ipairs(staticList) do merged[#merged + 1] = c end

    if Config.MDT and Config.MDT.provider == 'codem-mdt' and Config.MDT.pullCharges then
        local ok, rows = pcall(function()
            return MySQL.query.await('SELECT id, name, money, jail, prison FROM mmdt_fines')
        end)
        if ok and rows then
            for _, r in ipairs(rows) do
                local jail = tonumber(r.prison) or 0
                if jail <= 0 then jail = tonumber(r.jail) or 0 end
                merged[#merged + 1] = {
                    code     = 'mdt_' .. r.id,
                    label    = tostring(r.name),
                    category = 'other',
                    jailTime = jail,
                    fine     = tonumber(r.money) or 0,
                    severity = 1,
                }
            end
        end
    end

    Config.Charges.list = merged
end

CreateThread(function()
    Wait(2000)
    Mclaw.RefreshCharges(true)
end)
