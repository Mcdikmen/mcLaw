Config = {}

-- ─────────────────────────────────────────────
-- MDT INTEGRATION
-- Which MDT resource is active on your server.
-- provider: 'ps-mdt' | 'qbx-mdt' | 'none'
--   'none'  → no MDT integration, charges come from Config.Charges only
-- pullCharges: if true, MDT charge list is merged with Config.Charges
-- writeWarrants: if true, arrest warrants are also inserted into MDT automatically
-- ─────────────────────────────────────────────
Config.MDT = {
    provider      = 'ps-mdt',
    pullCharges   = true,
    writeWarrants = true,
}

-- ─────────────────────────────────────────────
-- JOB NAMES
-- Match these to the exact job names defined on your server.
-- prosecutorCanDecide: allow senior prosecutor to issue verdicts when no judge is online
-- prosecutorMinGrade: minimum grade required for the above
-- auctionApprover: which job can approve state auctions ('judge' | 'prosecutor')
-- auctionMinGrade: minimum grade required to approve auctions
-- ─────────────────────────────────────────────
Config.Jobs = {
    police              = 'police',
    lawyer              = 'lawyer',
    prosecutor          = 'prosecutor',
    judge               = 'judge',
    prosecutorCanDecide = false,
    prosecutorMinGrade  = 2,
    auctionApprover     = 'judge',
    auctionMinGrade     = 2,
}

-- ─────────────────────────────────────────────
-- JAIL PANEL
-- autoAcceptTimeout: seconds before the panel auto-accepts if the player closes it
--   0 = never auto-accept, panel always re-opens on spawn
-- reopenOnSpawn: reopen the jail decision panel every time the player spawns while pending
-- reportWithdrawTime: seconds an officer has to withdraw a submitted report (0 = disabled)
-- ─────────────────────────────────────────────
Config.Jail = {
    autoAcceptTimeout  = 0,
    reopenOnSpawn      = true,
    reportWithdrawTime = 300,
}

-- ─────────────────────────────────────────────
-- COMPENSATION
-- Paid to acquitted players after a not-guilty verdict.
-- enabled: set to false to disable the compensation system entirely
-- calculation: 'time_based' = minutes spent in jail × perMinuteRate
--              'fixed'      = flat amount regardless of time
-- account: which account receives the payment ('bank' | 'cash')
-- ─────────────────────────────────────────────
Config.Compensation = {
    enabled       = true,
    calculation   = 'time_based',
    perMinuteRate = 500,
    fixedAmount   = 50000,
    account       = 'bank',
}

-- ─────────────────────────────────────────────
-- DISCORD WEBHOOKS
-- Sends notifications to Discord for offline staff (prosecutors, judges).
-- url: your Discord webhook URL
-- serverName: displayed in webhook messages
-- roleMentions: Discord role IDs used as fallback when a staff member's personal
--   Discord ID cannot be resolved — leave empty to disable role pings
-- events: toggle each event type on or off individually
-- messages: embed template per event — edit title/body/color freely.
--   Supported placeholders: {serverName} {fileNumber} {suspectName}
--   {prosecutorMention} {judgeMention} {verdictResult} {jailTime} {fine}
--   {hearingDate} {chargeList}
--   color: decimal embed color (convert hex at spycolor.com)
-- ─────────────────────────────────────────────
Config.Webhook = {
    enabled    = true,
    url        = '',
    serverName = 'mcLaw Server',

    roleMentions = {
        prosecutor = '',   -- Discord role ID, e.g. '123456789012345678'
        judge      = '',
    },

    events = {
        fileOpened         = true,   -- new file opened, prosecutor needed
        prosecutorAssigned = true,   -- prosecutor assigned to a file
        verdictIssued      = true,   -- judge issued a verdict
        fileClosed         = true,   -- file closed
        warrantCreated     = true,   -- arrest warrant created
        hearingScheduled   = true,   -- hearing scheduled
        compensationPaid   = false,  -- compensation paid to acquitted player
        auctionOpened      = false,  -- asset listed for state auction
    },

    messages = {
        fileOpened = {
            color = 3447003,
            title = '📁 New File Opened',
            body  = '**{serverName}** — `{fileNumber}`\nSuspect: **{suspectName}**\n\n{prosecutorMention} awaiting assignment.',
        },
        prosecutorAssigned = {
            color = 5763719,
            title = '⚖️ Prosecutor Assigned',
            body  = '**{serverName}** — `{fileNumber}`\n{prosecutorMention} has been assigned to this file.',
        },
        verdictIssued = {
            color = 15548997,
            title = '🔨 Verdict Issued',
            body  = '**{serverName}** — `{fileNumber}`\nVerdict: **{verdictResult}**\nJail: {jailTime} min | Fine: ${fine}',
        },
        fileClosed = {
            color = 9807270,
            title = '🗂️ File Closed',
            body  = '**{serverName}** — `{fileNumber}`\nThis file has been closed.',
        },
        warrantCreated = {
            color = 15105570,
            title = '🚨 Arrest Warrant Issued',
            body  = '**{serverName}** — `{fileNumber}`\nAn arrest warrant has been issued for **{suspectName}**.',
        },
        hearingScheduled = {
            color = 10181046,
            title = '📅 Hearing Scheduled',
            body  = '**{serverName}** — `{fileNumber}`\nHearing Date: **{hearingDate}**\n{judgeMention} {prosecutorMention}',
        },
        compensationPaid = {
            color = 5763719,
            title = '💰 Compensation Paid',
            body  = '**{serverName}** — `{fileNumber}`\n**{suspectName}** received compensation: ${fine}',
        },
        auctionOpened = {
            color = 16776960,
            title = '🏷️ State Auction Opened',
            body  = '**{serverName}** — A new state auction has been listed.',
        },
    },
}

-- ─────────────────────────────────────────────
-- POWER OF ATTORNEY
-- Controls how lawyers grant representation to clients.
-- defaultDuration: how long a power of attorney is valid (seconds) — 604800 = 7 days
-- grantDistance: max distance (metres) between lawyer and client when granting
-- grantCommand / revokeCommand: in-game command names
-- ─────────────────────────────────────────────
Config.Attorney = {
    defaultDuration = 604800,
    grantDistance   = 3.0,
    grantCommand    = 'mclaw_grant',
    revokeCommand   = 'mclaw_revoke',
}

-- ─────────────────────────────────────────────
-- CONFISCATION / SEIZURE
-- warningDuration: seconds the owner has to respond before seizure is executed (600 = 10 min)
-- impoundExport: export function name from qbx_garages used to impound vehicles
-- enforcerJob: which job can initiate confiscations
-- ─────────────────────────────────────────────
Config.Confiscation = {
    warningDuration = 600,
    impoundExport   = 'ImpoundVehicle',
    enforcerJob     = 'lawyer',
}

-- ─────────────────────────────────────────────
-- FILE NUMBER FORMAT
-- Format: {prefix}-{year}-{padded sequence}
-- Example with defaults: MCL-2026-00042
-- padWidth: how many digits the sequence number is padded to
-- ─────────────────────────────────────────────
Config.FileNumber = {
    prefix   = 'MCL',
    padWidth = 5,
}

-- ─────────────────────────────────────────────
-- CHARGES (CRIME LIST)
-- useDatabase: if true, charges are loaded from mclaw_charges_config table instead
--              the list below acts as a fallback when useDatabase is false
-- code:     unique identifier used internally and in DB
-- label:    display name shown in UI (can be any language)
-- category: 'violence' | 'property' | 'drug' | 'traffic' | 'other'
-- jailTime: default sentence in minutes (0 = no jail time)
-- fine:     default fine in $ (0 = no fine)
-- severity: 1 = minor | 2 = moderate | 3 = severe
-- ─────────────────────────────────────────────
Config.Charges = {
    useDatabase = false,
    list = {
        {
            code     = 'armed_assault',
            label    = 'Silahlı Saldırı',
            category = 'violence',
            jailTime = 60,
            fine     = 5000,
            severity = 3,
        },
        {
            code     = 'theft',
            label    = 'Hırsızlık',
            category = 'property',
            jailTime = 20,
            fine     = 2000,
            severity = 1,
        },
        {
            code     = 'drug_possession',
            label    = 'Uyuşturucu Bulundurma',
            category = 'drug',
            jailTime = 30,
            fine     = 3000,
            severity = 2,
        },
        {
            code     = 'speeding',
            label    = 'Hız İhlali',
            category = 'traffic',
            jailTime = 0,
            fine     = 500,
            severity = 1,
        },
    },
}
