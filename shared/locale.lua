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
    err_invalid_defendant_cid     = 'Geçersiz şikayet edilen/davalı vatandaş numarası.',
    err_plaintiff_defendant_same  = 'Şikayet eden ile şikayet edilen aynı kişi olamaz.',
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
    err_jail_no_pending                = 'Bu kişi için bekleyen suçlama kararı yok.',
    err_panel_not_at_site              = 'Sevk raporu paneli yalnızca MRPD mugshot alanındaki hologramın yanında açılır.',
    err_plea_not_in_zone               = 'Suçlama penceresi yalnızca MRPD gözaltı alanında açılabilir.',
    jail_contested_header              = 'Fast RP',
    jail_contested_body                = '**Fast RP geçildi ve bileğinize takip cihazı takıldı.**\n\nSoruşturma dosya numaranız: **%s**\n\nSoruşturmanız bitene kadar bileğinizden sizi sürekli devlet yetkilileri takip edecek; gerektiği zaman size ulaşıp mahkemeye veya yazılı bilgi vermeye davet edecektir.',
    jail_contested_button              = 'Anladım',
    jail_panel_opened                  = 'Suçlama penceresi şüpheliye açıldı.',

    -- ── Referral / contest / investigation start (County RP) ──────────────────
    err_start_not_ready                = 'Bu rapor için soruşturma başlatılamaz: şüpheli henüz itiraz etmedi ya da soruşturma zaten başlatıldı.',
    start_ok_title                     = 'Soruşturma Başlatıldı',
    start_ok_officer                   = '%s numaralı soruşturma başlatıldı ve savcılığa iletildi.',
    start_ok_suspect                   = 'Hakkınızdaki soruşturma başlatıldı. Soruşturma dosya numaranız: %s',
    contest_notify_police              = "%s suçlamaları REDDETTİ. Dosya: %s. İfadeyi alıp MDT raporunu doldurun, sonra /mclaw > Raporlarım > Soruşturmayı Başlat.",
    contest_recorded                   = 'İtirazınız kaydedildi. Polis ifadenizi alacak; soruşturma başlatılınca dosya numaranız size bildirilecek.',
    contest_process_header             = 'Soruşturma ve Kovuşturma Süreci',
    contest_process_text               = "**Suçlamaları reddettiniz. Bundan sonra süreç şöyle işleyecek:**\n\n1. Polis ifadenizi alır ve MDT'den raporu doldurur.\n2. Rapor tamamlanınca soruşturma başlatılır; dosya numaranız size ve polise bildirilir.\n3. Savcılık soruşturmayı yürütür; gerekirse sizi mahkemeye ya da yazılı bilgi vermeye çağırır.\n4. Soruşturma sürerken **bileğinize 3 gün bataryası olan bir bileklik** takılır. Polisler gelip bataryayı değiştirerek süreyi 3 gün daha uzatabilir.\n5. Soruşturma sonunda iddianame hazırlanırsa hakim duruşma açar ve karar verir; takipsizlik ya da beraat halinde bileklik çıkarılır.\n\nBu süreç boyunca DOJ birimiyle (mahkeme, soruşturma ve kovuşturma) rol yapmanız ve rolün devamlılığını sağlamanız beklenir.",
    contest_ack1                       = 'DOJ birimiyle mahkeme, soruşturma ve kovuşturma rolleri yapacağımı biliyorum ve onaylıyorum.',
    contest_ack2                       = 'Bileğime 3 gün bataryası olan bir bileklik takılacağını (polisler gelip bataryayı değiştirip 3 gün daha uzatabilir) ve rolün devamlılığını sağlayacağımı biliyorum ve onaylıyorum.',
    contest_final_label                = 'Son karar',
    contest_final_reject               = 'Suçlamayı reddet',
    contest_final_accept               = 'Suçlamaları kabul et',
    contest_continue                   = 'Devam',
    contest_cancel                     = 'Vazgeç',

    -- ── Bracelet ──────────────────────────────────────────────────────────────
    err_bracelet_not_police            = 'Bu işlemi yalnızca görevdeki polis memurları yapabilir.',
    err_bracelet_not_at_site           = 'Bu işlem yalnızca MRPD bileklik noktasında yapılabilir.',
    err_bracelet_no_file               = 'Bu kişi için bileklik takılabilecek bir soruşturma yok (itiraz etmemiş ya da soruşturma henüz başlatılmamış).',
    err_bracelet_already               = 'Bu kişide zaten aktif bir bileklik var.',
    err_bracelet_none                  = 'Bu kişide bileklik yok.',
    err_bracelet_busy                  = 'Şüpheli başka bir onayda.',
    bracelet_consent_header            = 'Elektronik Takip Bilekliği',
    bracelet_consent_text              = "**Soruşturma dosyanız: %s**\n\nBileğinize elektronik takip bilekliği takılacak.\n\n- Bileklik **soruşturmanız sona erene kadar** takılı kalır ve devlet yetkilileri sizi sürekli takip eder.\n- Soruşturma sona erdiğinde (takipsizlik, dosyanın kapanması, beraat) bilgilendirilirsiniz; Mission Row PD'deki kimlik bürosu görevlisine başvurarak bilekliğinizi çıkarttırabilirsiniz.\n- Bileklik takılıyken **polisten kaçmaya yönelik her hareket Refuse RP sayılır** (gerçek hayatta ayağında bileklik varken polisten kaçman mantıklı değildir).\n- Gerektiğinde sizinle iletişime geçilip mahkemeye ya da yazılı bilgi vermeye davet edileceksiniz.",
    bracelet_ack1                      = 'Bileklikle soruşturmam sona erene kadar izleneceğimi anladım ve onaylıyorum.',
    bracelet_ack2                      = 'Bileklik süresince polisten kaçmaya yönelik hareketlerin Refuse RP sayılacağını kabul ediyorum ve onaylıyorum.',
    bracelet_declined_officer          = 'Şüpheli bileklik onayını vermedi, bileklik takılmadı.',
    bracelet_attached_officer          = 'Bileklik takıldı: %s — dosya %s.',
    bracelet_attached_suspect          = 'Bilekliğiniz takıldı. Soruşturma dosya numaranız: %s',
    bracelet_removed_officer           = 'Bileklik çıkarıldı: %s.',
    bracelet_removed_suspect           = 'Bilekliğiniz çıkarıldı.',
    bracelet_removal_due               = 'Bileklik çıkarılacak: %s (dosya %s) — %s. MRPD bileklik noktasında /kelepcecikar.',
    bracelet_menu_title                = 'Takipteki Bileklikler',
    bracelet_menu_empty                = 'Takipte bileklik yok.',
    bracelet_menu_row                  = 'Dosya %s | Takan: %s | %s | %s',
    bracelet_state_active              = 'Aktif',
    bracelet_state_due                 = 'ÇIKARILACAK',
    bracelet_online                    = 'Çevrimiçi',
    bracelet_offline                   = 'Çevrimdışı (son konum)',
    bracelet_gps_set                   = 'Konum haritada işaretlendi: %s',
    bracelet_gps_none                  = 'Bu bileklik için konum bilgisi yok.',
    drop_ok                            = 'Takipsizlik kararı verildi ve dosya kapatıldı.',
    drop_notify_suspect                = '%s numaralı soruşturmada takipsizlik kararı verildi. Bilekliğiniz varsa çıkarılacaktır.',

    -- ── Notices to the suspect / convict ──────────────────────────────────────
    suspect_indictment_title           = 'İddianame Düzenlendi',
    suspect_indictment_desc            = '%s numaralı soruşturmanızda iddianame düzenlendi. Hakim duruşma tarihini belirleyecek.',
    suspect_hearing_title              = 'Duruşma Planlandı',
    suspect_hearing_desc               = '%s numaralı dosyanız için duruşma planlandı: %s — %s',
    suspect_drop_title                 = 'Takipsizlik Kararı',
    suspect_sentence_title             = 'Hüküm Kesinleşti',
    suspect_withdrawn_title            = 'Sevk Raporu Geri Çekildi',
    suspect_withdrawn_desc             = 'Hakkınızda düzenlenen sevk raporu polis tarafından geri çekildi; işlem yapılmayacak.',
    suspect_bracelet_title             = 'Bileklik',
    suspect_bracelet_due               = '%s numaralı soruşturmanız sona erdi. Bilekliğinizi çıkarttırmak için Mission Row PD girişindeki kimlik bürosu görevlisine (NPC) başvurun.',

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
