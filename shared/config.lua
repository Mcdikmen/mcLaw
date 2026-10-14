Config = {}

-- ─────────────────────────────────────────────
-- DOJ ROLE MAPPING (County RP, QBCore)
-- One QBCore job ('doj'); its grade decides which mcLaw role the player has.
-- Grades come from qb-core/shared/jobs.lua:
--   10 Stajyer Avukat, 11 Avukat, 12 Aday Savcı, 13 Savcı,
--   14 Aday Hakim, 15 Hakim, 16 Başsavcı (boss, prosecutor role)
-- ─────────────────────────────────────────────
Config.Doj = {
    job   = 'doj',
    roles = {
        [10] = 'lawyer',     [11] = 'lawyer',
        [12] = 'prosecutor', [13] = 'prosecutor',
        [14] = 'judge',      [15] = 'judge',
        [16] = 'prosecutor',
    },
}

-- ─────────────────────────────────────────────
-- MDT INTEGRATION
-- Which MDT resource is active on your server.
-- provider: 'codem-mdt' | 'none'
--   'none'  → no MDT integration, charges come from Config.Charges only
-- pullCharges: if true, MDT charge list is merged with Config.Charges
-- writeWarrants: if true, arrest warrants are also inserted into MDT automatically
-- ─────────────────────────────────────────────
Config.MDT = {
    provider      = 'codem-mdt',
    pullCharges   = true,
    writeWarrants = false, -- mcLaw does not create warrants yet; codem-mdt has no warrant export
}

-- ─────────────────────────────────────────────
-- PRISON / SENTENCE ENFORCEMENT (County RP)
-- A guilty verdict (or accepted charges) never teleports anyone. It creates a
-- pending sentence; an on-duty police officer must bring the convict to the
-- prison intake and run /hapisteslim next to them.
-- intake:       prison entrance (qb-prison Config.Locations.outside)
-- intakeRadius: max distance (m) between officer and intake point
-- requireCuffs: convict must be handcuffed when delivered
-- fineSociety:  society that receives the court fine invoice (codem-billing)
-- ─────────────────────────────────────────────
Config.Prison = {
    intake       = vector3(1848.13, 2586.05, 44.67),
    intakeRadius = 60.0,
    requireCuffs = true,
    deliverCommand = 'hapisteslim',
    listCommand    = 'hukumler',
    fineSociety  = 'police',
}

-- ─────────────────────────────────────────────
-- SITES (County RP, MRPD)
-- referral:  the hologram spot (mugshot area). Police can open /mclaw (referral
--            report panel) only within `radius` m of it.
-- plea:      zones where a police officer can open the accept/contest panel
--            for an arrested suspect with /suclamaac (distance measured from
--            the officer). Radius is per zone.
-- release:   a suspect who contests the charges is uncuffed and sent here.
-- Coordinates are vector4 (x, y, z, heading); z is the ped position.
-- ─────────────────────────────────────────────
Config.Sites = {
    referral = { coords = vector4(473.08, -1011.52, 26.27, 181.89), radius = 5.0, viewDistance = 7.0, label = 'Sevk Raporu — /mclaw' },
    plea = {
        { coords = vector4(486.74, -1006.10, 26.27, 90.39), radius = 20.0 },  -- MRPD cells / mugshot side
    },
    -- where a suspect who CONTESTS the charges is released (MRPD front)
    release = { coords = vector4(425.54, -982.22, 30.71, 87.39) },
}

-- ─────────────────────────────────────────────
-- BRACELET (County RP)
-- A suspect who contests the charges gets an ankle bracelet at the `site`
-- (police only, /kelepcetak). Battery lasts `batteryMinutes` ONLINE minutes
-- (4320 = 3 days); police replace it with /bataryadegistir within
-- `batteryDistance` m of the wearer. Removal: /kelepcecikar at the same site.
-- ─────────────────────────────────────────────
Config.Bracelet = {
    site            = { coords = vector4(472.03, -1002.58, 26.27, 269.21), radius = 6.0 },
    batteryMinutes  = 4320,
    batteryDistance = 3.0,
    attachCommand   = 'kelepcetak',
    removeCommand   = 'kelepcecikar',
    listCommand     = 'kelepceler',
    batteryCommand  = 'bataryadegistir',
}

Mclaw = Mclaw or {}

-- IsNear(pos, site) — true if `pos` (vector3) is within site.radius of site.coords
function Mclaw.IsNear(pos, site)
    return #(vector3(pos.x, pos.y, pos.z) - vector3(site.coords.x, site.coords.y, site.coords.z)) <= site.radius
end

function Mclaw.InPleaZone(pos)
    for _, z in ipairs(Config.Sites.plea) do
        if Mclaw.IsNear(pos, z) then return true end
    end
    return false
end

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
    reopenOnSpawn      = false, -- plea panel is opened by police (nearby or /suclamaac), not on login
    panelDistance      = 10.0,  -- max distance (m) officer-suspect for the panel to open right after the report
    openCommand        = 'suclamaac',
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
    serverName = 'County RP',

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
            title = '📁 Yeni Dosya Açıldı',
            body  = '**{serverName}** — `{fileNumber}`\nŞüpheli: **{suspectName}**\n\n{prosecutorMention} atama bekleniyor.',
        },
        prosecutorAssigned = {
            color = 5763719,
            title = '⚖️ Savcı Atandı',
            body  = '**{serverName}** — `{fileNumber}`\n{prosecutorMention} bu dosyaya atandı.',
        },
        verdictIssued = {
            color = 15548997,
            title = '🔨 Karar Verildi',
            body  = '**{serverName}** — `{fileNumber}`\nKarar: **{verdictResult}**\nHapis: {jailTime} dk | Para cezası: ${fine}',
        },
        fileClosed = {
            color = 9807270,
            title = '🗂️ Dosya Kapatıldı',
            body  = '**{serverName}** — `{fileNumber}`\nBu dosya kapatıldı.',
        },
        warrantCreated = {
            color = 15105570,
            title = '🚨 Tutuklama Emri Çıkarıldı',
            body  = '**{serverName}** — `{fileNumber}`\n**{suspectName}** için tutuklama emri çıkarıldı.',
        },
        hearingScheduled = {
            color = 10181046,
            title = '📅 Duruşma Planlandı',
            body  = '**{serverName}** — `{fileNumber}`\nDuruşma Tarihi: **{hearingDate}**\n{judgeMention} {prosecutorMention}',
        },
        compensationPaid = {
            color = 5763719,
            title = '💰 Tazminat Ödendi',
            body  = '**{serverName}** — `{fileNumber}`\n**{suspectName}** tazminat aldı: ${fine}',
        },
        auctionOpened = {
            color = 16776960,
            title = '🏷️ Devlet İhalesi Açıldı',
            body  = '**{serverName}** — Yeni bir devlet ihalesi listelendi.',
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
    prefix   = 'DOS',
    padWidth = 5,
}

-- Soruşturma dosyası numara formatı (savcı soruşturmaları)
Config.InvestigationNumber = {
    prefix   = 'SRS',
    padWidth = 5,
}

-- ─────────────────────────────────────────────
-- DOCUMENT TYPES
-- Defines what document categories exist and which jobs can create them.
-- value: stored in DB (VARCHAR, can be any unique string)
-- label: displayed in the UI
-- jobs:  list of job names that can create this document type
-- Add as many entries as you need — no code changes required.
-- ─────────────────────────────────────────────
Config.DocTypes = {
    { value = 'petition',          label = 'Dilekçe',               jobs = { 'lawyer' } },
    { value = 'motion',            label = 'Talep',                   jobs = { 'lawyer' } },
    { value = 'defense_brief',     label = 'Savunma Dilekçesi',      jobs = { 'lawyer' } },
    { value = 'prosecution_note',  label = 'Savcılık Notu',   jobs = { 'prosecutor' } },
    { value = 'indictment_detail', label = 'İddianame Eki',jobs = { 'prosecutor' } },
    { value = 'evidence_summary',  label = 'Delil Özeti',   jobs = { 'prosecutor' } },
    { value = 'judge_order',       label = 'Hakim Emri',        jobs = { 'judge' } },
    { value = 'court_note',        label = 'Mahkeme Notu',         jobs = { 'judge' } },
    { value = 'interim_ruling',    label = 'Ara Karar',     jobs = { 'judge' } },
    { value = 'police_report',     label = 'Polis Raporu',      jobs = { 'police' } },
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
-- Fines are placeholders: they must be calibrated with the server economy
-- (starting capital is $500). jailTime is in minutes (real prison time).
-- Entries from codem-mdt's penal list (mmdt_fines) are appended automatically
-- on the server (see server/charges.lua).
Config.Charges = {
    useDatabase = false,
    list = {
        -- Şiddet
        { code = 'assault',           label = 'Darp',                              category = 'violence', jailTime = 15, fine = 500,  severity = 1 },
        { code = 'armed_assault',     label = 'Silahlı Saldırı',                   category = 'violence', jailTime = 60, fine = 2500, severity = 3 },
        { code = 'attempted_murder',  label = 'Kasten Öldürmeye Teşebbüs',         category = 'violence', jailTime = 120, fine = 5000, severity = 3 },
        { code = 'murder',            label = 'Kasten Öldürme',                    category = 'violence', jailTime = 180, fine = 10000, severity = 3 },
        { code = 'kidnapping',        label = 'Kişiyi Hürriyetinden Yoksun Kılma', category = 'violence', jailTime = 90, fine = 3500, severity = 3 },
        { code = 'threat',            label = 'Tehdit',                            category = 'violence', jailTime = 10, fine = 400,  severity = 1 },
        { code = 'resisting_arrest',  label = 'Gözaltına Direnme',                 category = 'violence', jailTime = 20, fine = 600,  severity = 1 },
        { code = 'assault_officer',   label = 'Kamu Görevlisine Saldırı',          category = 'violence', jailTime = 60, fine = 2000, severity = 3 },
        -- Mülkiyet
        { code = 'theft',             label = 'Hırsızlık',                         category = 'property', jailTime = 20, fine = 600,  severity = 1 },
        { code = 'vehicle_theft',     label = 'Araç Hırsızlığı',                   category = 'property', jailTime = 40, fine = 1500, severity = 2 },
        { code = 'robbery',           label = 'Gasp',                              category = 'property', jailTime = 60, fine = 2500, severity = 3 },
        { code = 'armed_robbery',     label = 'Silahlı Soygun',                    category = 'property', jailTime = 120, fine = 5000, severity = 3 },
        { code = 'burglary',          label = 'Konuta Hırsızlık / Hırsız Girişi',  category = 'property', jailTime = 45, fine = 1500, severity = 2 },
        { code = 'vandalism',         label = 'Mala Zarar Verme',                  category = 'property', jailTime = 10, fine = 400,  severity = 1 },
        { code = 'fraud',             label = 'Dolandırıcılık',                    category = 'property', jailTime = 30, fine = 2000, severity = 2 },
        -- Uyuşturucu
        { code = 'drug_possession',   label = 'Uyuşturucu Bulundurma',             category = 'drug',     jailTime = 30, fine = 1000, severity = 2 },
        { code = 'drug_dealing',      label = 'Uyuşturucu Satışı',                 category = 'drug',     jailTime = 90, fine = 3500, severity = 3 },
        { code = 'drug_trafficking',  label = 'Uyuşturucu Kaçakçılığı',            category = 'drug',     jailTime = 150, fine = 6000, severity = 3 },
        -- Trafik
        { code = 'speeding',          label = 'Hız İhlali',                        category = 'traffic',  jailTime = 0,  fine = 250,  severity = 1 },
        { code = 'reckless_driving',  label = 'Tehlikeli Sürüş',                   category = 'traffic',  jailTime = 10, fine = 500,  severity = 1 },
        { code = 'evading_police',    label = 'Polisten Kaçma',                    category = 'traffic',  jailTime = 30, fine = 1500, severity = 2 },
        { code = 'hit_and_run',       label = 'Kazaya Karışıp Kaçma',              category = 'traffic',  jailTime = 20, fine = 1000, severity = 2 },
        { code = 'no_license',        label = 'Ehliyetsiz Araç Kullanma',          category = 'traffic',  jailTime = 0,  fine = 500,  severity = 1 },
        -- Diğer
        { code = 'illegal_weapon',    label = 'Ruhsatsız Silah Bulundurma',        category = 'other',    jailTime = 40, fine = 2000, severity = 2 },
        { code = 'false_report',      label = 'Asılsız İhbar',                     category = 'other',    jailTime = 10, fine = 400,  severity = 1 },
        { code = 'bribery',           label = 'Rüşvet',                            category = 'other',    jailTime = 60, fine = 3000, severity = 3 },
        { code = 'obstruction',       label = 'Adaletin Yerine Gelmesini Engelleme', category = 'other',  jailTime = 30, fine = 1000, severity = 2 },
        { code = 'trespassing',       label = 'Mülke İzinsiz Girme',               category = 'other',    jailTime = 5,  fine = 300,  severity = 1 },
    },
}
