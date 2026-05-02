-- ─────────────────────────────────────────────────────────────────────────────
-- Referral shortcuts — NUI panelini doğrudan "Sevk Raporu" sekmesinde açar.
-- Artık ayrı lib.inputDialog yok; form NUI içinde yönetilir.
-- ─────────────────────────────────────────────────────────────────────────────

RegisterCommand('mclaw_report', function()
    TriggerEvent('mclaw:client:openPanel', 'referral')
end, false)

RegisterCommand('referral', function()
    TriggerEvent('mclaw:client:openPanel', 'referral')
end, false)
