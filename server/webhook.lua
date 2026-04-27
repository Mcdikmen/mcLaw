Mclaw = Mclaw or {}
Mclaw.Webhook = {}

-- Maps dot-notation event type strings to Config.Webhook.events toggle keys
local eventKeyMap = {
    ['file.opened']              = 'fileOpened',
    ['file.prosecutor_assigned'] = 'prosecutorAssigned',
    ['file.verdict_issued']      = 'verdictIssued',
    ['file.closed']              = 'fileClosed',
    ['warrant.created']          = 'warrantCreated',
    ['hearing.scheduled']        = 'hearingScheduled',
    ['compensation.paid']        = 'compensationPaid',
    ['auction.opened']           = 'auctionOpened',
}

-- Fetches the Discord ID for a citizenid via the Qbox users table.
-- Returns a "<@ID>" mention string, or "" if not found.
local function resolveDiscordMention(citizenid)
    if not citizenid or citizenid == '' then return '' end
    local result = MySQL.scalar.await(
        'SELECT u.discord FROM players p JOIN users u ON u.userId = p.userId WHERE p.citizenid = ? LIMIT 1',
        { citizenid }
    )
    if result and result ~= '' then
        return '<@' .. result .. '>'
    end
    return ''
end

-- Returns a Discord role mention "<@&ID>" from Config.Webhook.roleMentions, or "".
local function resolveRoleMention(role)
    local id = Config.Webhook.roleMentions and Config.Webhook.roleMentions[role]
    if id and id ~= '' then
        return '<@&' .. id .. '>'
    end
    return ''
end

-- Replaces {placeholder} tokens in a template string with values from the vars table.
local function fillTemplate(template, vars)
    return (template:gsub('{(%w+)}', function(key)
        return tostring(vars[key] or '')
    end))
end

-- Inserts a delivery record into mclaw_webhook_log.
local function logWebhook(notificationId, citizenid, eventType, payload, success, responseCode)
    MySQL.insert(
        'INSERT INTO mclaw_webhook_log (notification_id, citizenid, event_type, payload, success, response_code) VALUES (?, ?, ?, ?, ?, ?)',
        {
            notificationId,
            citizenid,
            eventType,
            json.encode(payload),
            success and 1 or 0,
            responseCode,
        }
    )
end

-- Builds a Discord embed payload table.
local function buildEmbed(filledTitle, filledBody, color)
    return {
        embeds = {
            {
                title       = filledTitle,
                description = filledBody,
                color       = color,
                footer      = { text = (Config.Webhook.serverName or 'mcLaw') .. ' • mcLaw' },
                timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            }
        }
    }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Mclaw.Webhook.Send
--
-- Sends a Discord webhook notification for a given event type.
--
-- Parameters:
--   eventType (string) : dot-notation event key, e.g. 'file.opened'
--   vars      (table)  : placeholder values for the message template.
--     fileNumber          (string)  e.g. 'MCL-2026-00042'
--     suspectName         (string)
--     suspectCitizenid    (string)  resolved to Discord mention
--     prosecutorCitizenid (string)  resolved to Discord mention
--     judgeCitizenid      (string)  resolved to Discord mention
--     verdictResult       (string)  'guilty' | 'acquitted' | 'dismissed'
--     jailTime            (number)  minutes
--     fine                (number)  dollar amount
--     hearingDate         (string)  formatted date/time string
--     chargeList          (string)  formatted charge summary
--     notificationId      (number)  mclaw_notifications.id for FK in log (optional)
-- ─────────────────────────────────────────────────────────────────────────────
function Mclaw.Webhook.Send(eventType, vars)
    if not Config.Webhook.enabled then return end
    if not Config.Webhook.url or Config.Webhook.url == '' then return end

    local toggleKey = eventKeyMap[eventType]
    if not toggleKey then
        print('[mcLaw] Webhook: unknown eventType → ' .. tostring(eventType))
        return
    end

    if not Config.Webhook.events[toggleKey] then return end

    local msgCfg = Config.Webhook.messages and Config.Webhook.messages[toggleKey]
    if not msgCfg then
        print('[mcLaw] Webhook: no message template for → ' .. toggleKey)
        return
    end

    vars = vars or {}

    -- Resolve staff Discord mentions; fall back to role mention if personal ID is missing
    local prosecutorMention = ''
    local judgeMention      = ''

    if vars.prosecutorCitizenid and vars.prosecutorCitizenid ~= '' then
        prosecutorMention = resolveDiscordMention(vars.prosecutorCitizenid)
        if prosecutorMention == '' then
            prosecutorMention = resolveRoleMention('prosecutor')
        end
    end

    if vars.judgeCitizenid and vars.judgeCitizenid ~= '' then
        judgeMention = resolveDiscordMention(vars.judgeCitizenid)
        if judgeMention == '' then
            judgeMention = resolveRoleMention('judge')
        end
    end

    local templateVars = {
        serverName        = Config.Webhook.serverName or 'mcLaw',
        fileNumber        = vars.fileNumber    or '',
        suspectName       = vars.suspectName   or '',
        prosecutorMention = prosecutorMention,
        judgeMention      = judgeMention,
        verdictResult     = vars.verdictResult or '',
        jailTime          = tostring(vars.jailTime or 0),
        fine              = tostring(vars.fine  or 0),
        hearingDate       = vars.hearingDate   or '',
        chargeList        = vars.chargeList    or '',
    }

    local filledTitle = fillTemplate(msgCfg.title or '', templateVars)
    local filledBody  = fillTemplate(msgCfg.body  or '', templateVars)
    local payload     = buildEmbed(filledTitle, filledBody, msgCfg.color or 7506394)

    PerformHttpRequest(
        Config.Webhook.url,
        function(statusCode)
            local success = statusCode >= 200 and statusCode < 300
            logWebhook(vars.notificationId, vars.suspectCitizenid, eventType, payload, success, statusCode)
            if not success then
                print(('[mcLaw] Webhook delivery failed — event: %s | status: %d'):format(eventType, statusCode))
            end
        end,
        'POST',
        json.encode(payload),
        { ['Content-Type'] = 'application/json' }
    )
end
