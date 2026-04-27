-- ─────────────────────────────────────────────────────────────────────────────
-- Referral report form — accessible only to police officers.
-- Command: /mclaw_report   (alias: /sevk)
-- ─────────────────────────────────────────────────────────────────────────────

-- Builds a list of nearby players (within 10 m) for the suspect dropdown.
local function getNearbyPlayerOptions()
    local options   = {}
    local myPed     = PlayerPedId()
    local myCoords  = GetEntityCoords(myPed)

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

-- Builds the charge multi-select options from the server charge list.
local function buildChargeOptions(chargeList)
    local options = {}
    for _, charge in ipairs(chargeList) do
        table.insert(options, {
            label = '[' .. (charge.category or '?') .. '] ' .. charge.label
                .. '  (' .. (charge.jailTime or 0) .. ' min / $' .. (charge.fine or 0) .. ')',
            value = charge.code,
        })
    end
    return options
end

local function openReferralForm()
    -- Nearby players
    local nearbyOptions = getNearbyPlayerOptions()
    if #nearbyOptions == 0 then
        lib.notify({ type = 'error', description = 'No players within range (10 m).' })
        return
    end

    -- Fetch charge list from server
    local chargeList = lib.callback.await('mclaw:cb:referral:getChargeList', false)
    if not chargeList or #chargeList == 0 then
        lib.notify({ type = 'error', description = 'Charge list unavailable.' })
        return
    end

    local chargeOptions = buildChargeOptions(chargeList)

    -- Input dialog
    local input = lib.inputDialog('Referral Report', {
        {
            type     = 'select',
            label    = 'Suspect',
            id       = 'suspectSource',
            options  = nearbyOptions,
            required = true,
        },
        {
            type     = 'select',
            label    = 'Charges',
            id       = 'charges',
            options  = chargeOptions,
            multi    = true,
            required = true,
        },
        {
            type        = 'textarea',
            label       = 'Narrative',
            id          = 'narrative',
            placeholder = 'Describe the incident…',
            required    = true,
            min         = 10,
            max         = 1000,
        },
    })

    if not input then return end

    local suspectSource = tonumber(input[1])
    local selectedCodes = input[2]   -- array of code strings (multi-select)
    local narrative     = input[3]

    -- ox_lib returns a string for single selection, table for multiple
    if type(selectedCodes) == 'string' then
        selectedCodes = { selectedCodes }
    end

    if not selectedCodes or #selectedCodes == 0 then
        lib.notify({ type = 'error', description = 'Select at least one charge.' })
        return
    end

    local chargesPayload = {}
    for _, code in ipairs(selectedCodes) do
        table.insert(chargesPayload, { code = code })
    end

    TriggerServerEvent('mclaw:server:referral:submit', {
        suspectSource = suspectSource,
        charges       = chargesPayload,
        narrative     = narrative,
    })
end

RegisterCommand('mclaw_report', function()
    openReferralForm()
end, false)

RegisterCommand('referral', function()
    openReferralForm()
end, false)

