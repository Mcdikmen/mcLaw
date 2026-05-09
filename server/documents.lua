-- ─────────────────────────────────────────────────────────────────────────────
-- File detail view + document management
-- ─────────────────────────────────────────────────────────────────────────────

-- mclaw:cb:file:getDetail
-- Returns the full content of a file: charges, hearing, documents, open log.
-- Source must hold a legal job.
lib.callback.register('mclaw:cb:file:getDetail', function(source, fileId)
    local P = exports.qbx_core:GetPlayer(source)
    if not P then return nil end

    local job = P.PlayerData.job.name
    local allowed = {
        [Config.Jobs.prosecutor] = true,
        [Config.Jobs.judge]      = true,
        [Config.Jobs.lawyer]     = true,
        [Config.Jobs.police]     = true,
    }
    if not allowed[job] then return nil end

    local file = MySQL.single.await(
        [[SELECT id, file_number, suspect_citizenid, prosecutor_citizenid, judge_citizenid,
                 opened_by_citizenid, opened_by_job, status, type, notes,
                 petition_id, created_at, updated_at, closed_at
          FROM mclaw_files WHERE id = ? AND deleted_at IS NULL]],
        { fileId }
    )
    if not file then return nil end

    -- Charges
    local chargeRows = MySQL.query.await(
        'SELECT charge_code, jail_override, fine_override, note FROM mclaw_file_charges WHERE file_id = ?',
        { fileId }
    )
    local charges = {}
    for _, c in ipairs(chargeRows or {}) do
        local def = Mclaw.GetChargeByCode(c.charge_code)
        table.insert(charges, {
            code     = c.charge_code,
            label    = def and def.label    or c.charge_code,
            category = def and def.category or '?',
            jailTime = c.jail_override or (def and def.jailTime or 0),
            fine     = c.fine_override  or (def and def.fine     or 0),
            note     = c.note,
        })
    end

    -- Nearest scheduled/active hearing
    local hearingRow = MySQL.single.await(
        "SELECT type, scheduled_at, status, notes FROM mclaw_hearings WHERE file_id = ? AND status IN ('scheduled','active') ORDER BY scheduled_at ASC LIMIT 1",
        { fileId }
    )

    -- Documents (chronological)
    local docRows = MySQL.query.await(
        'SELECT id, author_citizenid, author_job, doc_type, title, content, created_at FROM mclaw_documents WHERE file_id = ? ORDER BY created_at ASC',
        { fileId }
    )
    local documents = {}
    for _, d in ipairs(docRows or {}) do
        table.insert(documents, {
            id         = d.id,
            authorCid  = d.author_citizenid,
            authorName = Mclaw.GetCharName(d.author_citizenid),
            authorJob  = d.author_job,
            docType    = d.doc_type,
            title      = d.title,
            content    = d.content,
            createdAt  = Mclaw.FormatTimestamp(d.created_at),
        })
    end

    -- Opening narrative from log
    local openLog = MySQL.single.await(
        "SELECT notes, actioned_by_citizenid, actioned_by_job, created_at FROM mclaw_file_open_logs WHERE file_id = ? AND action = 'opened' ORDER BY created_at ASC LIMIT 1",
        { fileId }
    )

    -- ── Dosya geçmişi (sahafat) ──────────────────────────────────────────────
    local histItems = {}

    local openLogRows = MySQL.query.await(
        'SELECT action, actioned_by_citizenid, actioned_by_job, notes, created_at FROM mclaw_file_open_logs WHERE file_id = ? ORDER BY created_at ASC',
        { fileId }
    )
    for _, row in ipairs(openLogRows or {}) do
        table.insert(histItems, {
            ts        = tonumber(row.created_at) or 0,
            eventType = row.action,
            actor     = row.actioned_by_citizenid,
            actorName = Mclaw.GetCharName(row.actioned_by_citizenid),
            actorJob  = row.actioned_by_job,
            note      = row.notes,
            createdAt = Mclaw.FormatTimestamp(row.created_at),
        })
    end

    for _, d in ipairs(docRows or {}) do
        table.insert(histItems, {
            ts        = tonumber(d.created_at) or 0,
            eventType = 'document',
            actor     = d.author_citizenid,
            actorName = Mclaw.GetCharName(d.author_citizenid),
            actorJob  = d.author_job,
            docType   = d.doc_type,
            title     = d.title,
            createdAt = Mclaw.FormatTimestamp(d.created_at),
        })
    end

    local hearingHist = MySQL.query.await(
        'SELECT judge_citizenid, type, scheduled_at, created_at FROM mclaw_hearings WHERE file_id = ? ORDER BY created_at ASC',
        { fileId }
    )
    for _, h in ipairs(hearingHist or {}) do
        table.insert(histItems, {
            ts          = tonumber(h.created_at) or 0,
            eventType   = 'hearing_created',
            actor       = h.judge_citizenid,
            actorName   = Mclaw.GetCharName(h.judge_citizenid),
            actorJob    = Config.Jobs.judge,
            hearingType = h.type,
            scheduledAt = Mclaw.FormatTimestamp(h.scheduled_at),
            createdAt   = Mclaw.FormatTimestamp(h.created_at),
        })
    end

    table.sort(histItems, function(a, b) return a.ts < b.ts end)
    for _, item in ipairs(histItems) do item.ts = nil end

    -- Kaynak dilekçe (soruşturma avukat dilekçesinden açıldıysa)
    local sourcePetition = nil
    if file.petition_id then
        local pet = MySQL.single.await(
            'SELECT id, type, attorney_citizenid, plaintiff_citizenid, subject, description, charges, attachments, created_at FROM mclaw_petitions WHERE id = ?',
            { file.petition_id }
        )
        if pet then
            local petCharges = {}
            if pet.charges then
                local ok, decoded = pcall(json.decode, pet.charges)
                if ok and decoded then
                    for _, c in ipairs(decoded) do
                        local def = Mclaw.GetChargeByCode(c.code)
                        table.insert(petCharges, {
                            code     = c.code,
                            label    = def and def.label    or c.code,
                            category = def and def.category or '?',
                            jailTime = def and def.jailTime or 0,
                            fine     = def and def.fine     or 0,
                        })
                    end
                end
            end
            local petAtts = {}
            if pet.attachments then
                local ok2, decoded2 = pcall(json.decode, pet.attachments)
                if ok2 and decoded2 then petAtts = decoded2 end
            end
            sourcePetition = {
                id            = pet.id,
                petitionType  = pet.type,
                attorneyCid   = pet.attorney_citizenid,
                attorneyName  = Mclaw.GetCharName(pet.attorney_citizenid),
                plaintiffCid  = pet.plaintiff_citizenid,
                plaintiffName = Mclaw.GetCharName(pet.plaintiff_citizenid),
                subject       = pet.subject,
                description   = pet.description,
                charges       = petCharges,
                attachments   = petAtts,
                createdAt     = Mclaw.FormatTimestamp(pet.created_at),
            }
        end
    end

    return {
        id             = file.id,
        fileNumber     = file.file_number,
        suspectCid     = file.suspect_citizenid,
        suspectName    = Mclaw.GetCharName(file.suspect_citizenid),
        prosecutorCid  = file.prosecutor_citizenid,
        prosecutorName = Mclaw.GetCharName(file.prosecutor_citizenid),
        judgeCid       = file.judge_citizenid,
        judgeName      = Mclaw.GetCharName(file.judge_citizenid),
        openedBy       = file.opened_by_citizenid,
        openedByName   = Mclaw.GetCharName(file.opened_by_citizenid),
        openedByJob    = file.opened_by_job,
        status        = file.status,
        fileType      = file.type,
        notes         = file.notes,
        createdAt     = Mclaw.FormatTimestamp(file.created_at),
        updatedAt     = Mclaw.FormatTimestamp(file.updated_at),
        closedAt      = file.closed_at and Mclaw.FormatTimestamp(file.closed_at) or nil,
        charges       = charges,
        hearing       = hearingRow and {
            hearingType = hearingRow.type,
            scheduledAt = Mclaw.FormatTimestamp(hearingRow.scheduled_at),
            status      = hearingRow.status,
            notes       = hearingRow.notes,
        } or nil,
        documents     = documents,
        narrative       = openLog and openLog.notes                 or nil,
        narrativeBy     = openLog and openLog.actioned_by_citizenid or nil,
        narrativeByName = openLog and Mclaw.GetCharName(openLog.actioned_by_citizenid) or nil,
        narrativeJob    = openLog and openLog.actioned_by_job       or nil,
        narrativeAt     = openLog and Mclaw.FormatTimestamp(openLog.created_at) or nil,
        history         = histItems,
        sourcePetition  = sourcePetition,
    }
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:file:addDocument
-- Adds a document (petition, note, order, etc.) to a file.
--
-- data.fileId   (number)  target file id
-- data.docType  (string)  enum value
-- data.title    (string)  short title (min 2)
-- data.content  (string)  full text (min 5)
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:file:addDocument', function(data)
    local src = source
    local P   = exports.qbx_core:GetPlayer(src)
    if not P then return end

    local job = P.PlayerData.job.name
    local allowed = {
        [Config.Jobs.prosecutor] = true,
        [Config.Jobs.judge]      = true,
        [Config.Jobs.lawyer]     = true,
    }
    if not allowed[job] then return end

    if not data.fileId or not data.title or not data.content or not data.docType then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Eksik veri.' })
        return
    end
    if #data.title < 2 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Başlık çok kısa.' })
        return
    end
    if #data.content < 5 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'İçerik çok kısa.' })
        return
    end

    local file = MySQL.single.await(
        "SELECT id FROM mclaw_files WHERE id = ? AND status NOT IN ('closed','archived') AND deleted_at IS NULL",
        { data.fileId }
    )
    if not file then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Dosya bulunamadı veya kapalı.' })
        return
    end

    local cid = P.PlayerData.citizenid
    MySQL.insert(
        'INSERT INTO mclaw_documents (file_id, author_citizenid, author_job, doc_type, title, content) VALUES (?, ?, ?, ?, ?, ?)',
        { data.fileId, cid, job, data.docType, data.title, data.content }
    )

    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        description = 'Evrak dosyaya eklendi.',
    })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:judge:closeFile
-- Judge closes a file (moves to 'closed' status).
--
-- data.fileId  (number)   id of the file
-- data.reason  (string?)  optional closure reason
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:judge:closeFile', function(data)
    local src = source
    local P   = exports.qbx_core:GetPlayer(src)
    if not P or P.PlayerData.job.name ~= Config.Jobs.judge then return end

    local file = MySQL.single.await(
        "SELECT id, file_number, prosecutor_citizenid FROM mclaw_files WHERE id = ? AND status NOT IN ('closed','archived','verdict_issued') AND deleted_at IS NULL",
        { data.fileId }
    )
    if not file then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Dosya bulunamadı veya zaten kapalı.' })
        return
    end

    MySQL.update(
        "UPDATE mclaw_files SET status = 'closed', closed_at = NOW(), updated_at = NOW() WHERE id = ?",
        { data.fileId }
    )

    local reason = (data.reason and data.reason ~= '') and data.reason or nil
    local msg    = file.file_number .. ' numaralı dosya hakim tarafından kapatıldı.' .. (reason and (' Gerekçe: ' .. reason) or '')

    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = msg })

    if file.prosecutor_citizenid then
        MySQL.insert(
            'INSERT INTO mclaw_notifications (citizenid, type, title, message, ref_type, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            { file.prosecutor_citizenid, 'verdict', 'Dosya Kapatıldı', msg, 'file', data.fileId }
        )
        for _, pid in ipairs(GetPlayers()) do
            local PP = exports.qbx_core:GetPlayer(tonumber(pid))
            if PP and PP.PlayerData.citizenid == file.prosecutor_citizenid then
                TriggerClientEvent('mclaw:client:notification:push', tonumber(pid), {
                    type = 'inform', title = 'Dosya Kapatıldı', description = msg,
                })
                break
            end
        end
    end
end)
