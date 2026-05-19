-- ─────────────────────────────────────────────────────────────────────────────
-- Version check — runs once on resource start.
-- Fetches the latest GitHub release tag and compares with fxmanifest version.
-- ─────────────────────────────────────────────────────────────────────────────

local GITHUB_API = 'https://api.github.com/repos/Mcdikmen/mcLaw/releases/latest'

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    local current = GetResourceMetadata(resource, 'version', 0) or 'unknown'

    PerformHttpRequest(GITHUB_API, function(status, body)
        if status == 404 then
            print('^3[mcLaw] v' .. current .. ' — no releases found on GitHub yet.^7')
            return
        end
        if status ~= 200 or not body then
            print('^3[mcLaw] Version check failed (HTTP ' .. tostring(status) .. ').^7')
            return
        end

        local ok, data = pcall(json.decode, body)
        if not ok or not data or not data.tag_name then
            print('^3[mcLaw] Version check failed (could not parse response).^7')
            return
        end

        -- Strip leading 'v' from tag if present (e.g. "v1.2.0" → "1.2.0")
        local latest = data.tag_name:gsub('^v', '')

        if latest == current then
            print('^2[mcLaw] Up to date — v' .. current .. '^7')
        else
            print('^1[mcLaw] Update available!^7')
            print('^3  Current : v' .. current .. '^7')
            print('^3  Latest  : v' .. latest  .. '^7')
            print('^3  https://github.com/Mcdikmen/mcLaw/releases/latest^7')
        end
    end, 'GET', '', { ['User-Agent'] = 'mcLaw-version-check' })
end)
