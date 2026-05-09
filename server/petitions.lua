-- ─────────────────────────────────────────────────────────────────────────────
-- Dilekçe sistemi
-- Ceza davası: Avukat → Savcı → Soruşturma → İddianame → Hakim → Yargı
-- Hukuk davası: Avukat → Hakim → Hakim davayı açar → Yargı
-- ─────────────────────────────────────────────────────────────────────────────

local function findSource(citizenid)
    for _, pid in ipairs(GetPlayers()) do
        local P = exports.qbx_core:GetPlayer(tonumber(pid))
        if P and P.PlayerData.citizenid == citizenid then
            return tonumber(pid)
        end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:lawyer:sendPetition
-- Avukat → Savcıya (ceza) veya Hakime (hukuk) dilekçe gönderir.
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:lawyer:sendPetition', function(data)
    local src = source
    local P   = exports.qbx_core:GetPlayer(src)
    if not P or P.PlayerData.job.name ~= Config.Jobs.lawyer then return end

    if not data.petitionType or not data.plaintiffCid or not data.subject or not data.description then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Eksik veri.' })
        return
    end
    if #data.subject < 3 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Konu çok kısa.' })
        return
    end
    if #data.description < 10 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Açıklama çok kısa.' })
        return
    end

    local plaintiffExists = MySQL.scalar.await('SELECT COUNT(*) FROM players WHERE citizenid = ?', { data.plaintiffCid })
    if not plaintiffExists or plaintiffExists == 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Geçersiz müvekkil kimlik numarası.' })
        return
    end

    local recipientJob
    if data.petitionType == 'criminal' then
        recipientJob = Config.Jobs.prosecutor
    elseif data.petitionType == 'civil' then
        recipientJob = Config.Jobs.judge
    else
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Geçersiz dilekçe türü.' })
        return
    end

    -- Ceza davası için en az bir suç gerekli
    local chargesJson = nil
    if data.petitionType == 'criminal' then
        if not data.charges or #data.charges == 0 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Ceza davası için en az bir suç seçin.' })
            return
        end
        chargesJson = json.encode(data.charges)
    end

    -- Ekleri doğrula ve JSON'a çevir
    local attachmentsJson = nil
    if data.attachments and #data.attachments > 0 then
        local cleaned = {}
        for _, att in ipairs(data.attachments) do
            if att.label and att.url and #att.url > 5 then
                table.insert(cleaned, { label = att.label, url = att.url })
            end
        end
        if #cleaned > 0 then attachmentsJson = json.encode(cleaned) end
    end

    local cid = P.PlayerData.citizenid
    MySQL.insert(
        'INSERT INTO mclaw_petitions (type, attorney_citizenid, plaintiff_citizenid, recipient_job, charges, subject, description, attachments) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { data.petitionType, cid, data.plaintiffCid, recipientJob, chargesJson, data.subject, data.description, attachmentsJson }
    )

    local typeLabel = data.petitionType == 'criminal' and 'Ceza davası' or 'Hukuk davası'
    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        title       = 'Dilekçe Gönderildi',
        description = typeLabel .. ' dilekçesi ' .. (data.petitionType == 'criminal' and 'Savcılığa' or 'Hakime') .. ' iletildi.',
    })

    -- Online alıcılara bildirim
    for _, pid in ipairs(GetPlayers()) do
        local RP = exports.qbx_core:GetPlayer(tonumber(pid))
        if RP and RP.PlayerData.job.name == recipientJob then
            TriggerClientEvent('mclaw:client:notification:push', tonumber(pid), {
                type        = 'inform',
                title       = 'Yeni Dilekçe',
                description = 'Avukat tarafından yeni bir ' .. typeLabel:lower() .. ' dilekçesi gönderildi.',
            })
        end
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:lawyer:getMyPetitions
-- Avukatın gönderdiği dilekçeleri listeler.
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:lawyer:getMyPetitions', function(source)
    local P = exports.qbx_core:GetPlayer(source)
    if not P or P.PlayerData.job.name ~= Config.Jobs.lawyer then return {} end

    local cid  = P.PlayerData.citizenid
    local rows = MySQL.query.await(
        'SELECT id, type, plaintiff_citizenid, recipient_job, subject, description, status, file_id, reject_reason, attachments, created_at FROM mclaw_petitions WHERE attorney_citizenid = ? ORDER BY created_at DESC LIMIT 50',
        { cid }
    )

    local list = {}
    for _, row in ipairs(rows or {}) do
        local atts = {}
        if row.attachments then
            local ok, decoded = pcall(json.decode, row.attachments)
            if ok and decoded then atts = decoded end
        end
        table.insert(list, {
            id             = row.id,
            petitionType   = row.type,
            plaintiffCid   = row.plaintiff_citizenid,
            plaintiffName  = Mclaw.GetCharName(row.plaintiff_citizenid),
            recipientJob   = row.recipient_job,
            subject        = row.subject,
            description    = row.description,
            status         = row.status,
            fileId         = row.file_id,
            rejectReason   = row.reject_reason,
            attachments    = atts,
            createdAt      = Mclaw.FormatTimestamp(row.created_at),
        })
    end
    return list
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:prosecutor:getIncomingPetitions
-- Savcıya gelen ceza dilekçeleri.
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:prosecutor:getIncomingPetitions', function(source)
    local P = exports.qbx_core:GetPlayer(source)
    if not P or P.PlayerData.job.name ~= Config.Jobs.prosecutor then return {} end

    local rows = MySQL.query.await(
        "SELECT id, type, attorney_citizenid, plaintiff_citizenid, charges, subject, description, status, reject_reason, attachments, created_at FROM mclaw_petitions WHERE recipient_job = 'prosecutor' AND status = 'pending' ORDER BY created_at ASC LIMIT 50",
        {}
    )

    local list = {}
    for _, row in ipairs(rows or {}) do
        local charges = {}
        if row.charges then
            local ok, decoded = pcall(json.decode, row.charges)
            if ok and decoded then
                for _, c in ipairs(decoded) do
                    local def = Mclaw.GetChargeByCode(c.code)
                    table.insert(charges, {
                        code     = c.code,
                        label    = def and def.label    or c.code,
                        category = def and def.category or '?',
                        jailTime = def and def.jailTime or 0,
                        fine     = def and def.fine     or 0,
                    })
                end
            end
        end
        local atts = {}
        if row.attachments then
            local ok, decoded = pcall(json.decode, row.attachments)
            if ok and decoded then atts = decoded end
        end
        table.insert(list, {
            id            = row.id,
            petitionType  = row.type,
            attorneyCid   = row.attorney_citizenid,
            attorneyName  = Mclaw.GetCharName(row.attorney_citizenid),
            plaintiffCid  = row.plaintiff_citizenid,
            plaintiffName = Mclaw.GetCharName(row.plaintiff_citizenid),
            charges       = charges,
            subject       = row.subject,
            description   = row.description,
            attachments   = atts,
            status        = row.status,
            createdAt     = Mclaw.FormatTimestamp(row.created_at),
        })
    end
    return list
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:cb:judge:getIncomingPetitions
-- Hakime gelen hukuk dilekçeleri.
-- ─────────────────────────────────────────────────────────────────────────────
lib.callback.register('mclaw:cb:judge:getIncomingPetitions', function(source)
    local P = exports.qbx_core:GetPlayer(source)
    if not P or P.PlayerData.job.name ~= Config.Jobs.judge then return {} end

    local rows = MySQL.query.await(
        "SELECT id, type, attorney_citizenid, plaintiff_citizenid, subject, description, status, reject_reason, attachments, created_at FROM mclaw_petitions WHERE recipient_job = 'judge' AND status = 'pending' ORDER BY created_at ASC LIMIT 50",
        {}
    )

    local list = {}
    for _, row in ipairs(rows or {}) do
        local atts = {}
        if row.attachments then
            local ok, decoded = pcall(json.decode, row.attachments)
            if ok and decoded then atts = decoded end
        end
        table.insert(list, {
            id            = row.id,
            petitionType  = row.type,
            attorneyCid   = row.attorney_citizenid,
            attorneyName  = Mclaw.GetCharName(row.attorney_citizenid),
            plaintiffCid  = row.plaintiff_citizenid,
            plaintiffName = Mclaw.GetCharName(row.plaintiff_citizenid),
            subject       = row.subject,
            description   = row.description,
            attachments   = atts,
            status        = row.status,
            createdAt     = Mclaw.FormatTimestamp(row.created_at),
        })
    end
    return list
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:prosecutor:acceptPetition
-- Savcı ceza dilekçesini kabul eder → soruşturma açar.
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:prosecutor:acceptPetition', function(data)
    local src = source
    local P   = exports.qbx_core:GetPlayer(src)
    if not P or P.PlayerData.job.name ~= Config.Jobs.prosecutor then return end

    local cid = P.PlayerData.citizenid
    local petition = MySQL.single.await(
        "SELECT id, attorney_citizenid, plaintiff_citizenid, charges FROM mclaw_petitions WHERE id = ? AND status = 'pending' AND recipient_job = 'prosecutor'",
        { data.petitionId }
    )
    if not petition then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Dilekçe bulunamadı.' })
        return
    end

    -- Dosya numarası üret
    local year = tonumber(os.date('%Y'))
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM mclaw_files WHERE YEAR(created_at) = ?', { year }) or 0
    local fileNumber = Mclaw.FormatFileNumber(year, count + 1)

    -- Dosyayı oluştur
    local fileId = MySQL.insert.await(
        "INSERT INTO mclaw_files (file_number, suspect_citizenid, prosecutor_citizenid, opened_by_citizenid, opened_by_job, status, type) VALUES (?, ?, ?, ?, ?, 'opened', 'investigation')",
        { fileNumber, petition.plaintiff_citizenid, cid, cid, Config.Jobs.prosecutor }
    )

    -- Suçları ekle
    if petition.charges then
        local ok, charges = pcall(json.decode, petition.charges)
        if ok and charges then
            for _, c in ipairs(charges) do
                MySQL.insert('INSERT INTO mclaw_file_charges (file_id, charge_code) VALUES (?, ?)', { fileId, c.code })
            end
        end
    end

    -- Açılış logu
    MySQL.insert(
        "INSERT INTO mclaw_file_open_logs (file_id, action, actioned_by_citizenid, actioned_by_job, notes) VALUES (?, 'opened', ?, ?, ?)",
        { fileId, cid, Config.Jobs.prosecutor, 'Avukat dilekçesinden soruşturma açıldı.' }
    )

    -- Dilekçeyi güncelle
    MySQL.update(
        "UPDATE mclaw_petitions SET status = 'accepted', file_id = ?, updated_at = NOW() WHERE id = ?",
        { fileId, petition.id }
    )

    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        title       = 'Soruşturma Açıldı',
        description = fileNumber .. ' numaralı soruşturma başlatıldı.',
    })

    -- Avukata bildir
    local attorneySrc = findSource(petition.attorney_citizenid)
    if attorneySrc then
        TriggerClientEvent('mclaw:client:notification:push', attorneySrc, {
            type        = 'success',
            title       = 'Dilekçeniz Kabul Edildi',
            description = 'Savcılık ' .. fileNumber .. ' numaralı soruşturmayı açtı.',
        })
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:prosecutor:rejectPetition
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:prosecutor:rejectPetition', function(data)
    local src = source
    local P   = exports.qbx_core:GetPlayer(src)
    if not P or P.PlayerData.job.name ~= Config.Jobs.prosecutor then return end

    local petition = MySQL.single.await(
        "SELECT id, attorney_citizenid FROM mclaw_petitions WHERE id = ? AND status = 'pending' AND recipient_job = 'prosecutor'",
        { data.petitionId }
    )
    if not petition then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Dilekçe bulunamadı.' })
        return
    end

    MySQL.update(
        "UPDATE mclaw_petitions SET status = 'rejected', reject_reason = ?, updated_at = NOW() WHERE id = ?",
        { data.reason or nil, petition.id }
    )

    TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = 'Dilekçe reddedildi.' })

    local attorneySrc = findSource(petition.attorney_citizenid)
    if attorneySrc then
        local reason = (data.reason and data.reason ~= '') and (' Gerekçe: ' .. data.reason) or ''
        TriggerClientEvent('mclaw:client:notification:push', attorneySrc, {
            type        = 'error',
            title       = 'Dilekçeniz Reddedildi',
            description = 'Savcılık dilekçenizi reddetti.' .. reason,
        })
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:judge:acceptCivilPetition
-- Hakim hukuk dilekçesini kabul eder → hukuk davası açar.
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:judge:acceptCivilPetition', function(data)
    local src = source
    local P   = exports.qbx_core:GetPlayer(src)
    if not P or P.PlayerData.job.name ~= Config.Jobs.judge then return end

    local cid = P.PlayerData.citizenid
    local petition = MySQL.single.await(
        "SELECT id, attorney_citizenid, plaintiff_citizenid, subject FROM mclaw_petitions WHERE id = ? AND status = 'pending' AND recipient_job = 'judge'",
        { data.petitionId }
    )
    if not petition then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Dilekçe bulunamadı.' })
        return
    end

    local year = tonumber(os.date('%Y'))
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM mclaw_files WHERE YEAR(created_at) = ?', { year }) or 0
    local fileNumber = Mclaw.FormatFileNumber(year, count + 1)

    local fileId = MySQL.insert.await(
        "INSERT INTO mclaw_files (file_number, suspect_citizenid, judge_citizenid, opened_by_citizenid, opened_by_job, status, type) VALUES (?, ?, ?, ?, ?, 'opened', 'civil')",
        { fileNumber, petition.plaintiff_citizenid, cid, cid, Config.Jobs.judge }
    )

    MySQL.insert(
        "INSERT INTO mclaw_file_open_logs (file_id, action, actioned_by_citizenid, actioned_by_job, notes) VALUES (?, 'opened', ?, ?, ?)",
        { fileId, cid, Config.Jobs.judge, 'Avukat hukuk dilekçesinden dava açıldı: ' .. petition.subject }
    )

    MySQL.update(
        "UPDATE mclaw_petitions SET status = 'accepted', file_id = ?, updated_at = NOW() WHERE id = ?",
        { fileId, petition.id }
    )

    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        title       = 'Hukuk Davası Açıldı',
        description = fileNumber .. ' numaralı dava oluşturuldu.',
    })

    local attorneySrc = findSource(petition.attorney_citizenid)
    if attorneySrc then
        TriggerClientEvent('mclaw:client:notification:push', attorneySrc, {
            type        = 'success',
            title       = 'Dilekçeniz Kabul Edildi',
            description = 'Hakim ' .. fileNumber .. ' numaralı hukuk davasını açtı.',
        })
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- mclaw:server:judge:rejectCivilPetition
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('mclaw:server:judge:rejectCivilPetition', function(data)
    local src = source
    local P   = exports.qbx_core:GetPlayer(src)
    if not P or P.PlayerData.job.name ~= Config.Jobs.judge then return end

    local petition = MySQL.single.await(
        "SELECT id, attorney_citizenid FROM mclaw_petitions WHERE id = ? AND status = 'pending' AND recipient_job = 'judge'",
        { data.petitionId }
    )
    if not petition then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Dilekçe bulunamadı.' })
        return
    end

    MySQL.update(
        "UPDATE mclaw_petitions SET status = 'rejected', reject_reason = ?, updated_at = NOW() WHERE id = ?",
        { data.reason or nil, petition.id }
    )

    TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = 'Dilekçe reddedildi.' })

    local attorneySrc = findSource(petition.attorney_citizenid)
    if attorneySrc then
        local reason = (data.reason and data.reason ~= '') and (' Gerekçe: ' .. data.reason) or ''
        TriggerClientEvent('mclaw:client:notification:push', attorneySrc, {
            type        = 'error',
            title       = 'Dilekçeniz Reddedildi',
            description = 'Hakim dilekçenizi reddetti.' .. reason,
        })
    end
end)
