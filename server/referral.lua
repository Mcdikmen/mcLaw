Mclaw = Mclaw or {}

-- Returns the next sequence number for a given year by counting existing files.
local function getNextFileSequence(year)
    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM mclaw_files WHERE YEAR(created_at) = ?',
        { year }
    )
    return (count or 0) + 1
end

-- Finds the online prosecutor with the fewest active files.
-- Returns citizenid (string|nil), source (number|nil).
local function pickProsecutor()
    local candidates = {}
    for _, playerId in ipairs(GetPlayers()) do
        local P = Mclaw.GetPlayer(tonumber(playerId))
        if P and Mclaw.GetRole(P) == Config.Jobs.prosecutor then
            local cid      = P.PlayerData.citizenid
            local active   = MySQL.scalar.await(
                "SELECT COUNT(*) FROM mclaw_files WHERE prosecutor_citizenid = ? AND status NOT IN ('closed','archived','verdict_issued')",
                { cid }
            )
            table.insert(candidates, { source = tonumber(playerId), citizenid = cid, active = active or 0 })
        end
    end
    if #candidates == 0 then return nil, nil end
    table.sort(candidates, function(a, b) return a.active < b.active end)
    return candidates[1].citizenid, candidates[1].source
end

-- Fallback when no prosecutor is online at the moment of a referral: picks a
-- random aday savcı or savcı (DOJ grade 12/13) from the whole roster, online or
-- not. Başsavcı (grade 16) is excluded from this pool — their role here is to
-- reassign afterwards (mclaw:server:prosecutor:reassign), not to receive random
-- cases. Returns citizenid (string|nil).
local function pickRandomProsecutor()
    local row = MySQL.single.await(
        [[SELECT citizenid FROM players
          WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?
            AND JSON_UNQUOTE(JSON_EXTRACT(job, '$.grade.level')) IN ('12', '13')
          ORDER BY RAND() LIMIT 1]],
        { Config.Doj.job }
    )
    return row and row.citizenid or nil
end

-- Returns the server source for a citizenid, or nil if offline.
local function findSource(citizenid)
    for _, playerId in ipairs(GetPlayers()) do
        local P = Mclaw.GetPlayer(tonumber(playerId))
        if P and P.PlayerData.citizenid == citizenid then
            return tonumber(playerId)
        end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Mclaw.AssignProsecutor(fileId, fileNumber, prosecutorCid)
-- The ONLY notification a prosecutor/aday savcı's phone should ever receive from
-- mcLaw: a file has been assigned to them (auto round-robin at file open, or a
-- manual reassignment by the Başsavcı — see mclaw:server:prosecutor:reassign
-- below). Every other case-update toast (hearing scheduled, verdict, closed) is
-- sent on-screen only (noSms = true) since the assigned prosecutor already knows
-- about actions taken on their own file.
-- ─────────────────────────────────────────────────────────────────────────────
function Mclaw.AssignProsecutor(fileId, fileNumber, prosecutorCid)
    if not prosecutorCid then return end
    local title = 'Yeni Dosya Atandı'
    local msg   = fileNumber .. ' numaralı dosya size atandı.'
    MySQL.insert(
        'INSERT INTO mclaw_notifications (citizenid, type, title, message, ref_type, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
        { prosecutorCid, 'subpoena', title, msg, 'file', fileId }
    )
    local prosecutorSrc = findSource(prosecutorCid)
    if prosecutorSrc then
        Mclaw.Notify(prosecutorSrc, { type = 'inform', title = title, description = msg })
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:prosecutor:getAssignable
-- Başsavcı only. Returns online prosecutors/aday savcı (DOJ grade 12/13/16,
-- excluding the caller) with their active file count, so the chief can pick who
-- to (re)assign a file to.
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:prosecutor:getAssignable', function(source)
    local P = Mclaw.GetPlayer(source)
    if not P or not Mclaw.IsChief(P) then return {} end
    local selfCid = P.PlayerData.citizenid
    local list = {}
    for _, playerId in ipairs(GetPlayers()) do
        local PP = Mclaw.GetPlayer(tonumber(playerId))
        if PP and Mclaw.GetRole(PP) == Config.Jobs.prosecutor and PP.PlayerData.citizenid ~= selfCid then
            local cid    = PP.PlayerData.citizenid
            local active = MySQL.scalar.await(
                "SELECT COUNT(*) FROM mclaw_files WHERE prosecutor_citizenid = ? AND status NOT IN ('closed','archived','verdict_issued')",
                { cid }
            )
            table.insert(list, {
                citizenid  = cid,
                name       = Mclaw.GetCharName(cid) or cid,
                gradeLabel = PP.PlayerData.job.grade.name,
                active     = active or 0,
            })
        end
    end
    return list
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:prosecutor:getAllOpenFiles
-- Başsavcı only. Every open file across every prosecutor, for the reassignment list.
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:prosecutor:getAllOpenFiles', function(source)
    local P = Mclaw.GetPlayer(source)
    if not P or not Mclaw.IsChief(P) then return {} end
    local rows = MySQL.query.await(
        [[SELECT id, file_number, suspect_citizenid, prosecutor_citizenid, status
          FROM mclaw_files
          WHERE status NOT IN ('closed','archived','verdict_issued') AND deleted_at IS NULL
          ORDER BY created_at DESC LIMIT 100]]
    )
    local out = {}
    for _, row in ipairs(rows or {}) do
        table.insert(out, {
            id             = row.id,
            fileNumber     = row.file_number,
            status         = row.status,
            suspectCid     = row.suspect_citizenid,
            suspectName    = Mclaw.GetCharName(row.suspect_citizenid),
            prosecutorCid  = row.prosecutor_citizenid,
            prosecutorName = row.prosecutor_citizenid and Mclaw.GetCharName(row.prosecutor_citizenid) or nil,
        })
    end
    return out
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:prosecutor:reassign
-- Başsavcı only. Moves an open file to a different online prosecutor/aday savcı.
-- Only the new assignee gets notified ("Dosya size atandı"); the previous
-- assignee gets nothing — this is a management action, not a case update.
--
-- data.fileId        (number)
-- data.newCitizenid  (string)
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:prosecutor:reassign', function(data)
    local src = source
    local P   = Mclaw.GetPlayer(src)
    if not P or not Mclaw.IsChief(P) then return end

    local newCid = data.newCitizenid and tostring(data.newCitizenid):match('^%s*(.-)%s*$')
    if not newCid or newCid == '' then return end

    local newSrc = findSource(newCid)
    local NP = newSrc and Mclaw.GetPlayer(newSrc)
    if not NP or Mclaw.GetRole(NP) ~= Config.Jobs.prosecutor then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = 'Seçilen kişi çevrimdışı veya savcı değil.' })
        return
    end

    local file = MySQL.single.await(
        "SELECT id, file_number FROM mclaw_files WHERE id = ? AND status NOT IN ('closed','archived','verdict_issued') AND deleted_at IS NULL",
        { data.fileId }
    )
    if not file then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = Mclaw.T('err_file_not_found_closed') })
        return
    end

    MySQL.update('UPDATE mclaw_files SET prosecutor_citizenid = ?, updated_at = NOW() WHERE id = ?', { newCid, file.id })
    Mclaw.AssignProsecutor(file.id, file.file_number, newCid)
    Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'success',
        description = file.file_number .. ' numaralı dosya ' .. (Mclaw.GetCharName(newCid) or newCid) .. "'e devredildi.",
        noSms = true,
    })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:referral:submit
-- Submitted by a police officer. Creates referral report, opens a file,
-- assigns a prosecutor, and triggers the suspect's jail decision panel.
--
-- data.suspectCid        (string)  citizenid of the suspect
-- data.charges           (table)   array of { code = 'charge_code' }
-- data.narrative         (string)  officer's written narrative
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:referral:submit', function(data)
    local src    = source
    local Player = Mclaw.GetPlayer(src)
    if not Player then return end
    if Mclaw.GetRole(Player) ~= Config.Jobs.police then return end

    local officerCid = Player.PlayerData.citizenid
    local suspectCid = data.suspectCid and tostring(data.suspectCid):match('^%s*(.-)%s*$')

    if not suspectCid or suspectCid == '' then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = 'Geçersiz şüpheli vatandaş numarası.' })
        return
    end

    -- Verify the citizenid exists in the database
    local suspectExists = MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ? LIMIT 1', { suspectCid })
    if not suspectExists then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = 'Bu vatandaş numarasına ait oyuncu bulunamadı.' })
        return
    end

    if not data.charges or #data.charges == 0 then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = 'En az bir suç gereklidir.' })
        return
    end

    if not data.narrative or #data.narrative < 5 then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = 'Olay anlatımı çok kısa.' })
        return
    end

    -- Validate every charge code exists
    for _, c in ipairs(data.charges) do
        if not Mclaw.GetChargeByCode(c.code) then
            Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = 'Bilinmeyen suç kodu: ' .. tostring(c.code) })
            return
        end
    end

    local sentence = Mclaw.CalculateSentence(data.charges)

    -- Insert referral report
    -- The file is NOT created yet: it is opened only after the suspect's decision
    -- (Mclaw.CreateReferralFile, called from jail.lua). Until then the report keeps
    -- the evidence payload in evidence_ids (JSON).
    local VALID_EVIDENCE_TYPES = { text = true, coordinate = true, item = true, screenshot = true }
    local evidence = {}
    if data.evidence and type(data.evidence) == 'table' then
        for _, ev in ipairs(data.evidence) do
            if VALID_EVIDENCE_TYPES[ev.type] and ev.content and #tostring(ev.content) > 0 then
                evidence[#evidence + 1] = {
                    type    = ev.type,
                    content = tostring(ev.content):sub(1, 512),
                    label   = ev.label and tostring(ev.label):sub(1, 128) or nil,
                }
            end
        end
    end
    local reportId = MySQL.insert.await(
        'INSERT INTO mclaw_referral_reports (suspect_citizenid, officer_citizenid, narrative, charges, evidence_ids) VALUES (?, ?, ?, ?, ?)',
        { suspectCid, officerCid, data.narrative, json.encode(data.charges), json.encode(evidence) }
    )

    -- Create jail decision (pending), linked to the report
    local jailDecisionId = MySQL.insert.await(
        'INSERT INTO mclaw_jail_decisions (suspect_citizenid, officer_citizenid, charges, proposed_jail_time, proposed_fine, referral_report_id) VALUES (?, ?, ?, ?, ?, ?)',
        { suspectCid, officerCid, json.encode(data.charges), sentence.jailTime, sentence.fine, reportId }
    )

    -- Notify officer
    Mclaw.Notify(src, { position = Config.NotifyPosition,
        type        = 'success',
        title       = 'Rapor Gönderildi',
        description = "Rapor kaydedildi. Dosya, şüphelinin kararından sonra açılacak. Şüpheli yanınızdaysa penceresi açıldı; değilse gözaltı alanına getirilince kendiliğinden açılır.",
    })

    -- Build charge label list for jail panel
    local chargeLabels = {}
    for _, c in ipairs(data.charges) do
        local def = Mclaw.GetChargeByCode(c.code)
        table.insert(chargeLabels, def and def.label or c.code)
    end

    local panelData = {
        jailDecisionId = jailDecisionId,
        fileNumber     = nil, -- the file does not exist yet
        charges        = chargeLabels,
        proposedJail   = sentence.jailTime,
        proposedFine   = sentence.fine,
    }

    -- Plea panel only when the suspect is right next to the officer. Otherwise the
    -- otherwise it opens when they are brought into the cells zone.
    local suspectSrc = findSource(suspectCid)
    if suspectSrc then
        local near = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(suspectSrc))) <= (Config.Jail.panelDistance or 10.0)
        if near then
            TriggerClientEvent('mclaw:client:jail:showPanel', suspectSrc, panelData)
        end
    end

    -- Auto-accept timeout (server-side enforcement)
    if Config.Jail.autoAcceptTimeout and Config.Jail.autoAcceptTimeout > 0 then
        SetTimeout(Config.Jail.autoAcceptTimeout * 1000, function()
            local current = MySQL.scalar.await(
                'SELECT decision FROM mclaw_jail_decisions WHERE id = ?',
                { jailDecisionId }
            )
            if current == 'pending' then
                MySQL.update(
                    'UPDATE mclaw_jail_decisions SET decision = "accepted", decided_at = NOW() WHERE id = ?',
                    { jailDecisionId }
                )
                local timeoutFileId, timeoutFileNumber = Mclaw.CreateReferralFile(jailDecisionId)
                if timeoutFileId then
                    MySQL.update("UPDATE mclaw_files SET status = 'closed', closed_at = NOW() WHERE id = ?", { timeoutFileId })
                end
                Mclaw.CreateSentence(timeoutFileId, suspectCid, sentence.jailTime, sentence.fine, 'accepted', timeoutFileNumber)
                local sSource = findSource(suspectCid)
                if sSource then
                    TriggerClientEvent('mclaw:client:jail:panelTimeout', sSource, { jailDecisionId = jailDecisionId })
                end
            end
        end)
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Mclaw.CreateReferralFile(jailDecisionId) -> fileId, fileNumber
-- Opens the file for a referral report AFTER the suspect has decided. The referring
-- officer is recorded as the opener; no prosecutor is assigned here.
-- ─────────────────────────────────────────────────────────────────────────────
function Mclaw.CreateReferralFile(jailDecisionId)
    local jd = MySQL.single.await(
        'SELECT id, suspect_citizenid, officer_citizenid, referral_report_id, file_id FROM mclaw_jail_decisions WHERE id = ?',
        { jailDecisionId }
    )
    if not jd then return nil, nil end
    if jd.file_id then
        return jd.file_id, MySQL.scalar.await('SELECT file_number FROM mclaw_files WHERE id = ?', { jd.file_id })
    end

    local report = jd.referral_report_id and MySQL.single.await(
        'SELECT id, charges, evidence_ids FROM mclaw_referral_reports WHERE id = ?', { jd.referral_report_id }
    )

    local year = tonumber(os.date('%Y'))
    local fileNumber = Mclaw.FormatFileNumber(year, getNextFileSequence(year))
    local fileId = MySQL.insert.await(
        'INSERT INTO mclaw_files (file_number, suspect_citizenid, opened_by_citizenid, opened_by_job, referral_report_id, jail_decision_id, status) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { fileNumber, jd.suspect_citizenid, jd.officer_citizenid, Config.Jobs.police, jd.referral_report_id, jd.id, Mclaw.FileStatus.OPENED }
    )

    local charges = report and json.decode(report.charges) or {}
    for _, c in ipairs(charges) do
        MySQL.insert('INSERT INTO mclaw_file_charges (file_id, charge_code) VALUES (?, ?)', { fileId, c.code })
    end
    local evidence = report and report.evidence_ids and json.decode(report.evidence_ids) or {}
    for _, ev in ipairs(evidence) do
        MySQL.insert(
            'INSERT INTO mclaw_evidence (file_id, added_by, type, content, label) VALUES (?, ?, ?, ?, ?)',
            { fileId, jd.officer_citizenid, ev.type, ev.content, ev.label }
        )
    end

    MySQL.update('UPDATE mclaw_jail_decisions SET file_id = ? WHERE id = ?', { fileId, jd.id })
    if jd.referral_report_id then
        MySQL.update('UPDATE mclaw_referral_reports SET file_id = ?, status = "processed", processed_at = NOW() WHERE id = ?', { fileId, jd.referral_report_id })
    end
    return fileId, fileNumber
end

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:referral:startInvestigation
-- The officer, after taking the contesting suspect's statement and filling the MDT
-- report, starts the investigation: a prosecutor is assigned and notified; the
-- officer and the suspect are told the file number.
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:referral:startInvestigation', function(reportId)
    local src    = source
    local Player = Mclaw.GetPlayer(src)
    if not Player or Mclaw.GetRole(Player) ~= Config.Jobs.police then return end

    local file = MySQL.single.await(
        [[SELECT f.id, f.file_number, f.suspect_citizenid, f.status, jd.decision
          FROM mclaw_referral_reports r
          JOIN mclaw_files f ON f.id = r.file_id
          LEFT JOIN mclaw_jail_decisions jd ON jd.id = f.jail_decision_id
          WHERE r.id = ? AND r.officer_citizenid = ?]],
        { reportId, Player.PlayerData.citizenid }
    )
    if not file or file.status ~= 'opened' or file.decision ~= 'rejected' then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = Mclaw.T('err_start_not_ready') })
        return
    end

    local prosecutorCid = pickProsecutor()
    if not prosecutorCid then
        -- No one online: assign randomly instead of leaving the file unassigned.
        -- The Başsavcı can move it with mclaw:server:prosecutor:reassign.
        prosecutorCid = pickRandomProsecutor()
    end
    local newStatus = prosecutorCid and Mclaw.FileStatus.PROSECUTOR_REVIEW or Mclaw.FileStatus.AWAITING_PROSECUTOR
    local claimed = MySQL.update.await(
        "UPDATE mclaw_files SET prosecutor_citizenid = ?, status = ?, updated_at = NOW() WHERE id = ? AND status = 'opened'",
        { prosecutorCid, newStatus, file.id }
    )
    if not claimed or claimed < 1 then return end

    Mclaw.Notify(src, { position = Config.NotifyPosition,
        type = 'success', title = Mclaw.T('start_ok_title'),
        description = Mclaw.T('start_ok_officer', file.file_number),
    })
    Mclaw.NotifyCitizen(file.suspect_citizenid, 'subpoena', Mclaw.T('start_ok_title'), Mclaw.T('start_ok_suspect', file.file_number))

    Mclaw.AssignProsecutor(file.id, file.file_number, prosecutorCid)
    pcall(Mclaw.Webhook.Send, 'file.opened', {
        fileNumber          = file.file_number,
        suspectName         = Mclaw.GetCharName(file.suspect_citizenid) or file.suspect_citizenid,
        prosecutorCitizenid = prosecutorCid,
    })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:referral:withdraw
-- Allows the submitting officer to retract a report within the configured time window.
--
-- data.reportId  (number)  id of the report to withdraw
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:referral:withdraw', function(data)
    local src    = source
    local Player = Mclaw.GetPlayer(src)
    if not Player then return end
    if Mclaw.GetRole(Player) ~= Config.Jobs.police then return end

    if not Config.Jail.reportWithdrawTime or Config.Jail.reportWithdrawTime <= 0 then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = 'Rapor geri çekme kapalı.' })
        return
    end

    local officerCid = Player.PlayerData.citizenid
    local report     = MySQL.single.await(
        "SELECT id, suspect_citizenid FROM mclaw_referral_reports WHERE id = ? AND officer_citizenid = ? AND status = 'pending'",
        { data.reportId, officerCid }
    )

    if not report then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = 'Rapor bulunamadı veya zaten işlendi.' })
        return
    end

    local inWindow = MySQL.scalar.await(
        'SELECT TIMESTAMPDIFF(SECOND, created_at, NOW()) <= ? FROM mclaw_referral_reports WHERE id = ?',
        { Config.Jail.reportWithdrawTime, data.reportId }
    )

    if not inWindow or inWindow == 0 then
        Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'error', description = 'Geri çekme süresi doldu.' })
        return
    end

    MySQL.update("UPDATE mclaw_referral_reports SET status = 'rejected' WHERE id = ?", { data.reportId })
    MySQL.update("DELETE FROM mclaw_jail_decisions WHERE referral_report_id = ? AND decision = 'pending'", { data.reportId })
    Mclaw.Notify(src, { position = Config.NotifyPosition, type = 'success', description = 'Rapor geri çekildi.' })
    Mclaw.NotifyCitizen(report.suspect_citizenid, 'subpoena', Mclaw.T('suspect_withdrawn_title'), Mclaw.T('suspect_withdrawn_desc'))
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:referral:getChargeList
-- Returns the merged charge list (Config + MDT if pullCharges is enabled).
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:referral:getChargeList', function(source)
    Mclaw.RefreshCharges()
    if Config.Charges.useDatabase then
        local rows = MySQL.query.await('SELECT code, label, category, jail_time, fine_amount, severity FROM mclaw_charges_config WHERE is_active = 1 ORDER BY category, label', {})
        local list = {}
        for _, row in ipairs(rows or {}) do
            table.insert(list, {
                code     = row.code,
                label    = row.label,
                category = row.category,
                jailTime = row.jail_time,
                fine     = row.fine_amount,
                severity = row.severity,
            })
        end
        return list
    end
    return Config.Charges.list
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:referral:getMyReports
-- Returns referral reports submitted by this officer, newest first.
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:referral:getMyReports', function(source)
    local Player = Mclaw.GetPlayer(source)
    if not Player then return {} end
    if Mclaw.GetRole(Player) ~= Config.Jobs.police then return {} end

    local cid  = Player.PlayerData.citizenid
    local rows = MySQL.query.await(
        [[SELECT r.id, r.suspect_citizenid, r.narrative, r.status, r.created_at,
                 f.id AS file_id, f.file_number, f.status AS file_status, f.prosecutor_citizenid,
                 jd.decision
          FROM mclaw_referral_reports r
          LEFT JOIN mclaw_files f ON f.id = r.file_id
          LEFT JOIN mclaw_jail_decisions jd ON jd.referral_report_id = r.id
          WHERE r.officer_citizenid = ?
          ORDER BY r.created_at DESC
          LIMIT 50]],
        { cid }
    )
    return rows or {}
end)
