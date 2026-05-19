-- =============================================================================
-- mcLaw — Locale
-- All user-facing strings are defined here.
-- To translate the resource, edit only this file.
-- =============================================================================

Mclaw = Mclaw or {}

Mclaw.Locale = {

    -- ── Errors — generic ──────────────────────────────────────────────────────
    err_missing_data              = 'Missing data.',
    err_invalid_suspect_cid       = 'Invalid suspect citizen ID.',
    err_invalid_client_cid        = 'Invalid client citizen ID.',
    err_invalid_charge_code       = 'Invalid charge code: %s',
    err_invalid_petition_type     = 'Invalid petition type.',
    err_invalid_hearing_type      = 'Invalid hearing type.',
    err_no_charges_selected       = 'At least one charge must be selected.',
    err_criminal_needs_charge     = 'Select at least one charge for a criminal case.',
    err_narrative_too_short       = 'Narrative must be at least 10 characters.',
    err_title_too_short           = 'Title too short.',
    err_content_too_short         = 'Content too short.',
    err_subject_too_short         = 'Subject too short.',
    err_description_too_short     = 'Description too short.',
    err_hearing_date_required     = 'Hearing date must be specified.',

    -- ── Errors — file ─────────────────────────────────────────────────────────
    err_file_not_found_approval   = 'File not found or not eligible for approval.',
    err_file_not_found_rejection  = 'File not found or not eligible for rejection.',
    err_file_not_found_closed     = 'File not found or already closed.',
    err_file_not_found_auth       = 'File not found or unauthorized.',
    err_file_not_found_or_closed  = 'File not found or closed.',
    err_file_not_indictment       = 'File not found or not at indictment stage.',
    err_file_not_eligible         = 'This file is not eligible for indictment.',

    -- ── Errors — petition ─────────────────────────────────────────────────────
    err_petition_not_found        = 'Petition not found.',

    -- ── File opening ──────────────────────────────────────────────────────────
    notify_file_created_title          = 'File Created',
    notify_file_pending_note           = 'Pending judge approval.',
    notify_file_opened_note            = 'File opened.',
    notify_file_pending_approval_title = 'File Pending Approval',
    notify_file_pending_approval_desc  = '%s is pending your approval.',

    -- ── File approval ─────────────────────────────────────────────────────────
    notify_file_approved_title         = 'File Approved',
    notify_file_approved_desc          = '%s has been approved and opened.',
    notify_your_file_approved_title    = 'Your File Was Approved',
    notify_your_file_approved_desc     = '%s has been approved by the judge.',

    -- ── File rejection ────────────────────────────────────────────────────────
    notify_file_rejected_title         = 'File Rejected',
    notify_file_rejected_desc          = '%s has been rejected.',
    notify_your_file_rejected_title    = 'Your File Was Rejected',
    notify_your_file_rejected_desc     = '%s has been rejected by the judge.',

    -- ── File closed ───────────────────────────────────────────────────────────
    notify_file_closed_title           = 'File Closed',
    notify_file_closed_desc            = 'File %s closed by judge.',
    notify_file_closed_reason          = ' Reason: %s',

    -- ── Document ──────────────────────────────────────────────────────────────
    notify_document_added              = 'Document added to file.',

    -- ── Investigation ─────────────────────────────────────────────────────────
    notify_investigation_opened_title  = 'Investigation Opened',
    notify_investigation_opened_desc   = '%s investigation has been started.',

    -- ── Indictment ────────────────────────────────────────────────────────────
    notify_indictment_prepared_title   = 'Indictment Prepared',
    notify_indictment_prepared_desc    = 'File %s has moved to indictment stage.',
    notify_indictment_ready_title      = 'Indictment Ready',
    notify_indictment_ready_desc       = 'File %s is ready for hearing.',

    -- ── Hearing ───────────────────────────────────────────────────────────────
    notify_hearing_scheduled_title     = 'Hearing Scheduled',
    notify_hearing_scheduled_desc      = '%s — %s — %s',
    notify_hearing_scheduled_msg       = 'Hearing in case %s (%s) scheduled for %s.',
    hearing_type_written               = 'Written Trial',
    hearing_type_physical              = 'Physical Hearing',

    -- ── Petition ──────────────────────────────────────────────────────────────
    notify_petition_submitted_title    = 'Petition Submitted',
    notify_petition_submitted_criminal = 'Criminal case petition forwarded to Prosecution.',
    notify_petition_submitted_civil    = 'Civil case petition forwarded to Judge.',
    notify_new_petition_title          = 'New Petition',
    notify_new_petition_desc           = 'A new %s petition has been submitted by a lawyer.',
    notify_petition_rejected_desc      = 'Petition rejected.',
    notify_petition_rejected_reason    = ' Reason: %s',
    notify_your_petition_rejected_title = 'Petition Rejected',

    notify_petition_accepted_title     = 'Petition Accepted',
    notify_prosecution_opened_inv      = 'Prosecution has opened investigation %s.',
    notify_judge_opened_civil          = 'Judge has opened civil case %s.',

    -- ── Civil case ────────────────────────────────────────────────────────────
    notify_civil_opened_title          = 'Civil Case Opened',
    notify_civil_opened_desc           = 'Case %s has been created.',

    -- ── Verdict ───────────────────────────────────────────────────────────────
    notify_verdict_issued_title        = 'Verdict Issued',
    notify_verdict_issued_desc         = 'File %s — Verdict: %s | Jail: %s min | Fine: $%s',

    -- ── Warrant ───────────────────────────────────────────────────────────────
    notify_warrant_created_title       = 'Arrest Warrant Issued',
    notify_warrant_created_desc        = 'An arrest warrant has been issued for file %s.',

    -- ── Compensation ──────────────────────────────────────────────────────────
    notify_compensation_paid_title     = 'Compensation Paid',
    notify_compensation_paid_desc      = '%s received compensation: $%s',

    -- ── Log messages (stored in DB) ───────────────────────────────────────────
    log_investigation_from_petition    = 'Investigation opened from lawyer petition.',
    log_civil_from_petition            = 'Civil case opened from lawyer petition: %s',
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
