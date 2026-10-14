-- =============================================================================
-- mcLaw — Locale (Türkçe)
-- All user-facing strings are defined here.
-- Keep the %s placeholders in the same order as the original English text.
-- =============================================================================

Mclaw = Mclaw or {}

Mclaw.Locale = {

    -- ── Errors — generic ──────────────────────────────────────────────────────
    err_missing_data              = 'Eksik bilgi.',
    err_invalid_suspect_cid       = 'Geçersiz şüpheli vatandaş numarası.',
    err_invalid_client_cid        = 'Geçersiz müvekkil vatandaş numarası.',
    err_invalid_charge_code       = 'Geçersiz suç kodu: %s',
    err_invalid_petition_type     = 'Geçersiz dilekçe türü.',
    err_invalid_hearing_type      = 'Geçersiz duruşma türü.',
    err_no_charges_selected       = 'En az bir suç seçilmelidir.',
    err_criminal_needs_charge     = 'Ceza davası için en az bir suç seçin.',
    err_narrative_too_short       = 'Olay anlatımı en az 10 karakter olmalıdır.',
    err_title_too_short           = 'Başlık çok kısa.',
    err_content_too_short         = 'İçerik çok kısa.',
    err_subject_too_short         = 'Konu çok kısa.',
    err_description_too_short     = 'Açıklama çok kısa.',
    err_hearing_date_required     = 'Duruşma tarihi belirtilmelidir.',

    -- ── Errors — file ─────────────────────────────────────────────────────────
    err_file_not_found_approval   = 'Dosya bulunamadı veya onaya uygun değil.',
    err_file_not_found_rejection  = 'Dosya bulunamadı veya reddedilemez.',
    err_file_not_found_closed     = 'Dosya bulunamadı veya zaten kapalı.',
    err_file_not_found_auth       = 'Dosya bulunamadı veya yetkiniz yok.',
    err_file_not_found_or_closed  = 'Dosya bulunamadı veya kapalı.',
    err_file_not_indictment       = 'Dosya bulunamadı veya iddianame aşamasında değil.',
    err_file_not_eligible         = 'Bu dosya için iddianame düzenlenemez.',

    -- ── Errors — petition ─────────────────────────────────────────────────────
    err_petition_not_found        = 'Dilekçe bulunamadı.',

    -- ── File opening ──────────────────────────────────────────────────────────
    notify_file_created_title          = 'Dosya Oluşturuldu',
    notify_file_pending_note           = 'Hakim onayı bekleniyor.',
    notify_file_opened_note            = 'Dosya açıldı.',
    notify_file_pending_approval_title = 'Onay Bekleyen Dosya',
    notify_file_pending_approval_desc  = '%s onayınızı bekliyor.',

    -- ── File approval ─────────────────────────────────────────────────────────
    notify_file_approved_title         = 'Dosya Onaylandı',
    notify_file_approved_desc          = '%s onaylandı ve açıldı.',
    notify_your_file_approved_title    = 'Dosyanız Onaylandı',
    notify_your_file_approved_desc     = '%s hakim tarafından onaylandı.',

    -- ── File rejection ────────────────────────────────────────────────────────
    notify_file_rejected_title         = 'Dosya Reddedildi',
    notify_file_rejected_desc          = '%s reddedildi.',
    notify_your_file_rejected_title    = 'Dosyanız Reddedildi',
    notify_your_file_rejected_desc     = '%s hakim tarafından reddedildi.',

    -- ── File closed ───────────────────────────────────────────────────────────
    notify_file_closed_title           = 'Dosya Kapatıldı',
    notify_file_closed_desc            = '%s numaralı dosya hakim tarafından kapatıldı.',
    notify_file_closed_reason          = ' Gerekçe: %s',

    -- ── Document ──────────────────────────────────────────────────────────────
    notify_document_added              = 'Belge dosyaya eklendi.',

    -- ── Investigation ─────────────────────────────────────────────────────────
    notify_investigation_opened_title  = 'Soruşturma Açıldı',
    notify_investigation_opened_desc   = '%s soruşturması başlatıldı.',

    -- ── Indictment ────────────────────────────────────────────────────────────
    notify_indictment_prepared_title   = 'İddianame Hazırlandı',
    notify_indictment_prepared_desc    = '%s numaralı dosya iddianame aşamasına geçti.',
    notify_indictment_ready_title      = 'İddianame Hazır',
    notify_indictment_ready_desc       = '%s numaralı dosya duruşmaya hazır.',

    -- ── Hearing ───────────────────────────────────────────────────────────────
    notify_hearing_scheduled_title     = 'Duruşma Planlandı',
    notify_hearing_scheduled_desc      = '%s — %s — %s',
    notify_hearing_scheduled_msg       = '%s numaralı davada (%s) duruşma %s tarihine planlandı.',
    hearing_type_written               = 'Yazılı Yargılama',
    hearing_type_physical              = 'Yüz Yüze Duruşma',

    -- ── Petition ──────────────────────────────────────────────────────────────
    notify_petition_submitted_title    = 'Dilekçe Gönderildi',
    notify_petition_submitted_criminal = 'Ceza davası dilekçesi savcılığa iletildi.',
    notify_petition_submitted_civil    = 'Hukuk davası dilekçesi hakime iletildi.',
    notify_new_petition_title          = 'Yeni Dilekçe',
    notify_new_petition_desc           = 'Bir avukat tarafından yeni bir %s dilekçesi gönderildi.',
    notify_petition_rejected_desc      = 'Dilekçe reddedildi.',
    notify_petition_rejected_reason    = ' Gerekçe: %s',
    notify_your_petition_rejected_title = 'Dilekçe Reddedildi',

    notify_petition_accepted_title     = 'Dilekçe Kabul Edildi',
    notify_prosecution_opened_inv      = 'Savcılık %s soruşturmasını açtı.',
    notify_judge_opened_civil          = 'Hakim %s hukuk davasını açtı.',

    -- ── Civil case ────────────────────────────────────────────────────────────
    notify_civil_opened_title          = 'Hukuk Davası Açıldı',
    notify_civil_opened_desc           = '%s numaralı dava oluşturuldu.',

    -- ── Verdict ───────────────────────────────────────────────────────────────
    notify_verdict_issued_title        = 'Karar Verildi',
    notify_verdict_issued_desc         = 'Dosya %s — Karar: %s | Hapis: %s dk | Para cezası: $%s',
    notify_verdict_suspect_title       = 'Karar Verildi',
    notify_verdict_suspect_desc        = 'Dosya %s — Sonuç: %s',
    notify_verdict_prosecutor_title    = 'Karar Verildi',
    notify_verdict_prosecutor_desc     = 'Dosya %s — %s | Hapis: %s dk | Para cezası: $%s',
    err_file_not_hearing               = 'Dosya bulunamadı veya duruşma aşamasında değil.',
    err_invalid_verdict_result         = 'Geçersiz karar sonucu.',
    verdict_result_guilty              = 'Mahkûm',
    verdict_result_acquitted           = 'Beraat',
    verdict_result_dismissed           = 'Davanın Düşmesi',

    -- ── Warrant ───────────────────────────────────────────────────────────────
    notify_warrant_created_title       = 'Tutuklama Emri Çıkarıldı',
    notify_warrant_created_desc        = '%s numaralı dosya için tutuklama emri çıkarıldı.',

    -- ── Compensation ──────────────────────────────────────────────────────────
    notify_compensation_paid_title     = 'Tazminat Ödendi',
    notify_compensation_paid_desc      = '%s tazminat aldı: $%s',

    -- ── Sentence enforcement (County RP) ──────────────────────────────────────
    sentence_pending_convict           = 'Hükmünüz kesinleşti: %s dk hapis, $%s para cezası. Bir polis memurunun sizi hapishaneye götürmesi bekleniyor.',
    sentence_pending_police            = 'İnfaz bekleyen hüküm (%s): %s dk hapis. Detay için /hukumler.',
    sentence_fine_label                = 'Mahkeme para cezası — %s',
    sentence_served_officer            = 'Hüküm infaz edildi: %s dk hapis, $%s para cezası faturası.',
    sentence_served_convict            = 'Cezanız başladı: %s dk.',
    prison_time_left                  = 'Kalan hapis süresi: %s dk',
    sentence_list_title                = 'İnfaz Bekleyen Hükümler',
    sentence_list_empty                = 'İnfaz bekleyen hüküm yok.',
    sentence_list_row                  = '%s — %s dk hapis, $%s para cezası',
    jail_accepted_notify               = 'Suçlamaları kabul ettiniz. Bir polis memuru sizi hapishaneye götürdüğünde cezanız başlayacak.',
    err_prison_not_police              = 'Bu işlemi yalnızca görevdeki polis memurları yapabilir.',
    err_prison_no_target               = 'Yakında kimse yok.',
    err_prison_too_far                 = 'Hükümlüye yeterince yakın değilsiniz.',
    err_prison_no_sentence             = 'Bu kişi için infaz bekleyen hüküm yok.',
    err_prison_not_at_intake           = 'Hükümlüyü hapishane girişinde teslim etmelisiniz.',
    err_prison_not_cuffed              = 'Hükümlü kelepçeli olmalıdır.',

    -- ── Log messages (stored in DB) ───────────────────────────────────────────
    log_investigation_from_petition    = 'Avukat dilekçesi üzerine soruşturma açıldı.',
    log_civil_from_petition            = 'Avukat dilekçesi üzerine hukuk davası açıldı: %s',
}

-- Mclaw.T(key, ...) — returns the locale string for key, with optional format args.
function Mclaw.T(key, ...)
    local str = Mclaw.Locale[key]
    if not str then return '[MISSING: ' .. tostring(key) .. ']' end
    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end
