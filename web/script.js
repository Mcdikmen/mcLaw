'use strict';

// -- State

var currentJob          = null;
var chargeList          = [];
var myReports           = [];
var prosecutorFiles     = [];
var fileOpenChargeList  = [];
var pendingApprovals    = [];
var hearingList         = [];
var docTypeList         = [];
var myPetitions         = [];
var incomingPetitions   = [];
var investigationList   = [];
var verdictFiles        = [];

// -- Tab navigation

var navButtons = document.querySelectorAll('.nav-btn');
var pages      = document.querySelectorAll('.page');

function activateTab(pageName) {
    navButtons.forEach(function(b) { b.classList.remove('active'); });
    pages.forEach(function(p) { p.classList.remove('active'); });
    var btn  = document.querySelector('.nav-btn[data-page="' + pageName + '"]');
    var page = document.getElementById('page-' + pageName);
    if (btn && !btn.classList.contains('nav-hidden')) { btn.classList.add('active'); }
    if (page) { page.classList.add('active'); }
}

var REFRESHABLE_TABS = { dashboard: 1, files: 1, investigations: 1, approvals: 1, hearings: 1, referral: 1, myreports: 1, mypetitions: 1, inpetitions: 1, verdict: 1 };

navButtons.forEach(function(btn) {
    btn.addEventListener('click', function() {
        var tab = btn.getAttribute('data-page');
        activateTab(tab);
        if (REFRESHABLE_TABS[tab]) {
            fetch('https://mclaw/tab:refresh', {
                method: 'POST',
                body: JSON.stringify({ tab: tab }),
            });
        }
    });
});

// -- Job-based tab filtering

function filterTabsForJob(job) {
    navButtons.forEach(function(btn) {
        var allowed = btn.getAttribute('data-jobs');
        if (allowed === 'all') { btn.classList.remove('nav-hidden'); return; }
        var jobs = allowed.split(',');
        if (jobs.indexOf(job) !== -1) {
            btn.classList.remove('nav-hidden');
        } else {
            btn.classList.add('nav-hidden');
            btn.classList.remove('active');
        }
    });
}

var style = document.createElement('style');
style.textContent = '.nav-hidden { display: none !important; }';
document.head.appendChild(style);

// -- Helpers

function escHtml(str) {
    return String(str || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function Mclaw_FormatDate(val) {
    if (!val) return '—';
    var d = new Date(val);
    if (isNaN(d.getTime())) return String(val);
    return d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

// -- Referral form

function populateReferralForm() {
    var chargeContainer = document.getElementById('referral-charges');
    chargeContainer.innerHTML = '';
    chargeList.forEach(function(charge) {
        var item = document.createElement('label');
        item.className = 'charge-item';
        var cb = document.createElement('input');
        cb.type = 'checkbox';
        cb.value = charge.code;
        cb.addEventListener('change', function() { item.classList.toggle('checked', cb.checked); });
        var labelSpan = document.createElement('span');
        labelSpan.className = 'charge-label';
        labelSpan.textContent = '[' + (charge.category || '?') + '] ' + charge.label;
        var meta = document.createElement('span');
        meta.className = 'charge-meta';
        meta.textContent = (charge.jailTime || 0) + ' dk / $' + (charge.fine || 0);
        item.appendChild(cb);
        item.appendChild(labelSpan);
        item.appendChild(meta);
        chargeContainer.appendChild(item);
    });
}

document.getElementById('referral-narrative').addEventListener('input', function() {
    document.getElementById('narrative-count').textContent = this.value.length;
});

document.getElementById('referral-reset').addEventListener('click', function() {
    document.getElementById('referral-form').reset();
    document.getElementById('narrative-count').textContent = '0';
    document.querySelectorAll('.charge-item').forEach(function(item) { item.classList.remove('checked'); });
    document.getElementById('referral-evidence-list').innerHTML = '';
    hideReferralError();
});

var EVIDENCE_TYPES = [
    { value: 'text',       label: 'Text Note' },
    { value: 'coordinate', label: 'Location' },
    { value: 'item',       label: 'Item' },
    { value: 'screenshot', label: 'Screenshot URL' },
];

document.getElementById('referral-add-evidence').addEventListener('click', function() {
    var list = document.getElementById('referral-evidence-list');
    var row = document.createElement('div');
    row.className = 'evidence-row';
    row.style.cssText = 'display:flex;gap:6px;margin-bottom:6px;align-items:flex-start;';

    var typeSelect = document.createElement('select');
    typeSelect.className = 'evidence-type';
    typeSelect.style.cssText = 'width:130px;flex-shrink:0;';
    EVIDENCE_TYPES.forEach(function(t) {
        var opt = document.createElement('option');
        opt.value = t.value;
        opt.textContent = t.label;
        typeSelect.appendChild(opt);
    });

    var labelInput = document.createElement('input');
    labelInput.type = 'text';
    labelInput.placeholder = 'Label (e.g. Knife)';
    labelInput.className = 'evidence-label';
    labelInput.style.cssText = 'width:120px;flex-shrink:0;';

    var contentInput = document.createElement('input');
    contentInput.type = 'text';
    contentInput.placeholder = 'Description / content';
    contentInput.className = 'evidence-content';
    contentInput.style.flex = '1';

    var removeBtn = document.createElement('button');
    removeBtn.type = 'button';
    removeBtn.textContent = '✕';
    removeBtn.className = 'btn-secondary';
    removeBtn.style.cssText = 'padding:4px 8px;flex-shrink:0;';
    removeBtn.addEventListener('click', function() { list.removeChild(row); });

    row.appendChild(typeSelect);
    row.appendChild(labelInput);
    row.appendChild(contentInput);
    row.appendChild(removeBtn);
    list.appendChild(row);
});

function showReferralError(msg) {
    var el = document.getElementById('referral-error');
    el.textContent = msg;
    el.classList.remove('hidden');
}

function hideReferralError() {
    document.getElementById('referral-error').classList.add('hidden');
}

document.getElementById('referral-form').addEventListener('submit', function(e) {
    e.preventDefault();
    hideReferralError();
    var suspectCid = document.getElementById('referral-suspect-cid').value.trim();
    if (!suspectCid) { showReferralError('Please enter the suspect\'s Citizen ID.'); return; }
    var selectedCodes = [];
    document.querySelectorAll('#referral-charges input[type="checkbox"]:checked').forEach(function(cb) {
        selectedCodes.push({ code: cb.value });
    });
    if (selectedCodes.length === 0) { showReferralError('Select at least one charge.'); return; }
    var narrative = document.getElementById('referral-narrative').value.trim();
    if (narrative.length < 10) { showReferralError('Incident narrative must be at least 10 characters.'); return; }
    var evidenceList = [];
    document.querySelectorAll('#referral-evidence-list .evidence-row').forEach(function(row) {
        var type    = row.querySelector('.evidence-type').value;
        var label   = row.querySelector('.evidence-label').value.trim();
        var content = row.querySelector('.evidence-content').value.trim();
        if (content) { evidenceList.push({ type: type, label: label, content: content }); }
    });
    var submitBtn = document.querySelector('#referral-form .btn-primary');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Submitting…';
    fetch('https://mclaw/referral:submit', {
        method: 'POST',
        body: JSON.stringify({ suspectCid: suspectCid, charges: selectedCodes, narrative: narrative, evidence: evidenceList }),
    }).then(function(res) { return res.json(); }).then(function(result) {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Submit Report';
        if (result && result.ok) {
            document.getElementById('referral-form').reset();
            document.getElementById('narrative-count').textContent = '0';
            document.querySelectorAll('.charge-item').forEach(function(item) { item.classList.remove('checked'); });
            document.getElementById('referral-evidence-list').innerHTML = '';
        } else {
            showReferralError(result && result.error ? result.error : 'Submission failed.');
        }
    }).catch(function() {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Submit Report';
    });
});

// -- Files tab (prosecutor / judge)

var STATUS_LABELS = {
    'opened':               'Opened',
    'awaiting_prosecutor':  'Awaiting Prosecutor',
    'prosecutor_review':    'Prosecutor Review',
    'indictment_ready':     'Indictment Ready',
    'hearing_scheduled':    'Hearing Scheduled',
    'written_trial_active': 'Written Trial',
    'verdict_issued':       'Verdict Issued',
    'enforcement_active':   'Enforcement Active',
    'closed':               'Closed',
    'archived':             'Archived',
    'pending_approval':     'Pending Approval',
};

var STATUS_COLORS = {
    'opened':               'status-blue',
    'awaiting_prosecutor':  'status-yellow',
    'prosecutor_review':    'status-yellow',
    'indictment_ready':     'status-green',
    'hearing_scheduled':    'status-green',
    'written_trial_active': 'status-green',
    'verdict_issued':       'status-gray',
    'enforcement_active':   'status-red',
    'closed':               'status-gray',
    'archived':             'status-gray',
    'pending_approval':     'status-yellow',
};

function renderInvestigationList() {
    var listEl  = document.getElementById('investigations-list');
    var emptyEl = document.getElementById('investigations-empty');
    if (!listEl) return;
    listEl.innerHTML = '';
    if (investigationList.length === 0) { if (emptyEl) emptyEl.style.display = ''; return; }
    if (emptyEl) emptyEl.style.display = 'none';
    investigationList.forEach(function(file) {
        var card = document.createElement('div');
        card.className = 'file-card';
        var statusClass = STATUS_COLORS[file.status] || 'status-gray';
        var statusLabel = STATUS_LABELS[file.status]  || file.status;
        var chargeNames = (file.charges || []).map(function(c) { return c.label; }).join(', ') || '-';
        card.innerHTML =
            '<div class="file-card-header">' +
                '<span class="file-number">' + file.fileNumber + '</span>' +
                '<span class="file-status ' + statusClass + '">' + statusLabel + '</span>' +
            '</div>' +
            '<div class="file-card-body">' +
                '<div class="file-meta"><span class="file-meta-key">Suspect</span><span>' + displayName(file.suspectName, file.suspectCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Charges</span><span class="file-charges-text">' + chargeNames + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Opened</span><span>' + (file.createdAt || '-') + '</span></div>' +
            '</div>';
        var viewBtn = document.createElement('button');
        viewBtn.type = 'button';
        viewBtn.className = 'btn-secondary file-indictment-btn';
        viewBtn.textContent = 'View File →';
        (function(fid) {
            viewBtn.addEventListener('click', function() { openFileDetail(fid, 'investigations'); });
        }(file.id));
        card.appendChild(viewBtn);

        var eligible = ['opened', 'awaiting_prosecutor', 'prosecutor_review'];
        if (eligible.indexOf(file.status) !== -1) {
            var indBtn = document.createElement('button');
            indBtn.type = 'button';
            indBtn.className = 'btn-secondary file-indictment-btn';
            indBtn.textContent = 'Prepare Indictment →';
            (function(fid) {
                indBtn.addEventListener('click', function() {
                    prefillIndictmentForm(fid);
                    activateTab('indictment');
                });
            }(file.id));
            card.appendChild(indBtn);
        }
        listEl.appendChild(card);
    });
}

function renderFilesList() {
    var listEl  = document.getElementById('files-list');
    var emptyEl = document.getElementById('files-empty');
    listEl.innerHTML = '';
    if (prosecutorFiles.length === 0) { emptyEl.style.display = ''; return; }
    emptyEl.style.display = 'none';
    prosecutorFiles.forEach(function(file) {
        var card = document.createElement('div');
        card.className = 'file-card';
        var statusClass = STATUS_COLORS[file.status] || 'status-gray';
        var statusLabel = STATUS_LABELS[file.status] || file.status;
        var chargeNames = (file.charges || []).map(function(c) { return c.label; }).join(', ') || '-';
        var notesRow = file.notes ? '<div class="file-meta"><span class="file-meta-key">Note</span><span class="file-charges-text">' + file.notes + '</span></div>' : '';
        var pendingRow = (file.status === 'pending_approval')
            ? '<div class="file-meta" style="margin-top:6px;padding-top:6px;border-top:1px solid #2e3650;">' +
                  '<span class="file-meta-key" style="color:#fbbc04;">Approval</span>' +
                  '<span style="color:#fbbc04;font-size:12px;">Awaiting judge approval</span>' +
              '</div>'
            : '';
        card.innerHTML =
            '<div class="file-card-header">' +
                '<span class="file-number">' + file.fileNumber + '</span>' +
                '<span class="file-status ' + statusClass + '">' + statusLabel + '</span>' +
            '</div>' +
            '<div class="file-card-body">' +
                '<div class="file-meta"><span class="file-meta-key">Suspect</span><span>' + displayName(file.suspectName, file.suspectCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Charges</span><span class="file-charges-text">' + chargeNames + '</span></div>' +
                notesRow +
                '<div class="file-meta"><span class="file-meta-key">Opened</span><span>' + (file.createdAt || '-') + '</span></div>' +
                pendingRow +
            '</div>';
        // View detail button — all cards
        var viewBtn = document.createElement('button');
        viewBtn.type = 'button';
        viewBtn.className = 'btn-secondary file-indictment-btn';
        viewBtn.textContent = 'View File →';
        (function(fid) {
            viewBtn.addEventListener('click', function() { openFileDetail(fid, 'files'); });
        }(file.id));
        card.appendChild(viewBtn);

        var eligibleIndictment = ['opened', 'awaiting_prosecutor', 'prosecutor_review'];
        if (currentJob === 'prosecutor' && eligibleIndictment.indexOf(file.status) !== -1) {
            var btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'btn-secondary file-indictment-btn';
            btn.textContent = 'Prepare Indictment →';
            (function(fid) {
                btn.addEventListener('click', function() {
                    prefillIndictmentForm(fid);
                    activateTab('indictment');
                });
            }(file.id));
            card.appendChild(btn);
        }
        if (currentJob === 'judge' && file.status === 'indictment_ready') {
            // Trigger button
            var acceptTrigger = document.createElement('div');
            acceptTrigger.className = 'approval-actions';
            acceptTrigger.id = 'accept-trigger-' + file.id;
            acceptTrigger.innerHTML = '<button class="btn-primary accept-case-open-btn" data-id="' + file.id + '">Schedule Hearing →</button>';
            card.appendChild(acceptTrigger);
            // Inline scheduling form (hidden)
            var acceptPanel = document.createElement('div');
            acceptPanel.className = 'approval-reject-panel hidden';
            acceptPanel.id = 'accept-panel-' + file.id;
            acceptPanel.innerHTML =
                '<div class="form-group" style="margin-bottom:10px;">' +
                    '<label style="font-size:12px;color:#a8b0c8;text-transform:uppercase;letter-spacing:.4px;display:block;margin-bottom:6px;">Hearing Date & Time</label>' +
                    '<input type="datetime-local" class="reject-reason-input accept-datetime" id="accept-dt-' + file.id + '" style="width:100%;padding:8px 10px;">' +
                '</div>' +
                '<div class="form-group" style="margin-bottom:10px;">' +
                    '<label style="font-size:12px;color:#a8b0c8;text-transform:uppercase;letter-spacing:.4px;display:block;margin-bottom:6px;">Type</label>' +
                    '<select class="reject-reason-input accept-type" id="accept-type-' + file.id + '" style="width:100%;padding:8px 10px;">' +
                        '<option value="physical">Physical Hearing</option>' +
                        '<option value="written">Written Trial</option>' +
                    '</select>' +
                '</div>' +
                '<div class="form-group" style="margin-bottom:10px;">' +
                    '<textarea class="reject-reason-input accept-notes" id="accept-notes-' + file.id + '" rows="2" maxlength="300" placeholder="Judge note (optional)…"></textarea>' +
                '</div>' +
                '<div class="form-actions" style="margin-top:8px;">' +
                    '<button class="btn-primary accept-case-confirm-btn" data-id="' + file.id + '">Save Hearing</button>' +
                    '<button class="btn-secondary accept-case-cancel-btn" data-id="' + file.id + '">Cancel</button>' +
                '</div>';
            card.appendChild(acceptPanel);
        }
        listEl.appendChild(card);
    });

    // Judge: open scheduling form
    listEl.querySelectorAll('.accept-case-open-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var fid = btn.getAttribute('data-id');
            document.getElementById('accept-trigger-' + fid).classList.add('hidden');
            document.getElementById('accept-panel-' + fid).classList.remove('hidden');
        });
    });

    // Judge: cancel scheduling
    listEl.querySelectorAll('.accept-case-cancel-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var fid = btn.getAttribute('data-id');
            document.getElementById('accept-panel-' + fid).classList.add('hidden');
            document.getElementById('accept-trigger-' + fid).classList.remove('hidden');
        });
    });

    // Judge: confirm scheduling
    listEl.querySelectorAll('.accept-case-confirm-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var fid = parseInt(btn.getAttribute('data-id'), 10);
            var dtVal   = document.getElementById('accept-dt-' + fid).value;
            var typeVal = document.getElementById('accept-type-' + fid).value;
            var notes   = document.getElementById('accept-notes-' + fid).value.trim();
            if (!dtVal) { alert('Please select a hearing date.'); return; }
            btn.disabled = true; btn.textContent = 'Saving…';
            fetch('https://mclaw/judge:acceptCase', {
                method: 'POST',
                body: JSON.stringify({ fileId: fid, scheduledAt: dtVal, hearingType: typeVal, notes: notes }),
            }).then(function(res) { return res.json(); }).then(function(result) {
                if (result && result.ok) {
                    var card = btn.closest('.file-card');
                    var badge = card && card.querySelector('.file-status');
                    if (badge) { badge.className = 'file-status status-green'; badge.textContent = 'Hearing Scheduled'; }
                    var panel = document.getElementById('accept-panel-' + fid);
                    if (panel) { panel.remove(); }
                    var trigger = document.getElementById('accept-trigger-' + fid);
                    if (trigger) { trigger.remove(); }
                } else {
                    btn.disabled = false; btn.textContent = 'Save Hearing';
                }
            }).catch(function() { btn.disabled = false; btn.textContent = 'Save Hearing'; });
        });
    });
}

// -- Indictment form

function populateIndictmentFileSelect() {
    var sel = document.getElementById('indictment-file');
    sel.innerHTML = '<option value="">— Select a file —</option>';
    var eligible = ['opened', 'awaiting_prosecutor', 'prosecutor_review'];
    // Investigations + case files
    var allFiles = investigationList.concat(prosecutorFiles);
    allFiles.forEach(function(file) {
        if (eligible.indexOf(file.status) !== -1) {
            var opt = document.createElement('option');
            opt.value = file.id;
            opt.textContent = file.fileNumber + ' — ' + (file.suspectName || file.suspectCid);
            sel.appendChild(opt);
        }
    });
}

function prefillIndictmentForm(fileId) {
    document.getElementById('indictment-file').value = fileId;
}

document.getElementById('indictment-reset').addEventListener('click', function() {
    document.getElementById('indictment-form').reset();
    hideIndictmentError();
});

function showIndictmentError(msg) {
    var el = document.getElementById('indictment-error');
    el.textContent = msg;
    el.classList.remove('hidden');
}

function hideIndictmentError() {
    document.getElementById('indictment-error').classList.add('hidden');
}

document.getElementById('indictment-form').addEventListener('submit', function(e) {
    e.preventDefault();
    hideIndictmentError();
    var fileId = document.getElementById('indictment-file').value;
    if (!fileId) { showIndictmentError('Please select a file.'); return; }
    var hearingTypeEl = document.querySelector('input[name="hearing-type"]:checked');
    if (!hearingTypeEl) { showIndictmentError('Please select a trial type.'); return; }
    var notes = document.getElementById('indictment-notes').value.trim();
    var submitBtn = document.querySelector('#indictment-form .btn-primary');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Submitting…';
    fetch('https://mclaw/prosecutor:submitIndictment', {
        method: 'POST',
        body: JSON.stringify({ fileId: parseInt(fileId, 10), hearingType: hearingTypeEl.value, notes: notes }),
    }).then(function(res) { return res.json(); }).then(function(result) {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Submit Indictment';
        if (result && result.ok) {
            document.getElementById('indictment-form').reset();
            hideIndictmentError();
        } else {
            showIndictmentError(result && result.error ? result.error : 'Submission failed.');
        }
    }).catch(function() {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Submit Indictment';
    });
});

// -- File opening form

function populateFileOpenCharges() {
    var container = document.getElementById('fileopening-charges');
    container.innerHTML = '';
    fileOpenChargeList.forEach(function(charge) {
        var item = document.createElement('label');
        item.className = 'charge-item';
        var cb = document.createElement('input');
        cb.type = 'checkbox';
        cb.value = charge.code;
        cb.addEventListener('change', function() { item.classList.toggle('checked', cb.checked); });
        var labelSpan = document.createElement('span');
        labelSpan.className = 'charge-label';
        labelSpan.textContent = '[' + (charge.category || '?') + '] ' + charge.label;
        var meta = document.createElement('span');
        meta.className = 'charge-meta';
        meta.textContent = (charge.jailTime || 0) + ' dk / $' + (charge.fine || 0);
        item.appendChild(cb); item.appendChild(labelSpan); item.appendChild(meta);
        container.appendChild(item);
    });
}

document.getElementById('fileopening-narrative').addEventListener('input', function() {
    document.getElementById('fileopening-narrative-count').textContent = this.value.length;
});

document.getElementById('fileopening-reset').addEventListener('click', function() {
    document.getElementById('fileopening-form').reset();
    document.getElementById('fileopening-narrative-count').textContent = '0';
    document.querySelectorAll('#fileopening-charges .charge-item').forEach(function(i) { i.classList.remove('checked'); });
    document.getElementById('fileopening-error').classList.add('hidden');
});

function showFileOpeningNote(job) {
    var note = document.getElementById('fileopening-pending-note');
    if (note) note.style.display = job === 'prosecutor' ? '' : 'none';
}

document.getElementById('fileopening-form').addEventListener('submit', function(e) {
    e.preventDefault();
    var errEl = document.getElementById('fileopening-error');
    errEl.classList.add('hidden');
    var suspectCid = document.getElementById('fileopening-suspect').value.trim();
    if (!suspectCid) { errEl.textContent = 'Suspect citizen ID is required.'; errEl.classList.remove('hidden'); return; }
    var selectedCodes = [];
    document.querySelectorAll('#fileopening-charges input[type="checkbox"]:checked').forEach(function(cb) {
        selectedCodes.push({ code: cb.value });
    });
    if (selectedCodes.length === 0) { errEl.textContent = 'Select at least one charge.'; errEl.classList.remove('hidden'); return; }
    var narrative = document.getElementById('fileopening-narrative').value.trim();
    if (narrative.length < 10) { errEl.textContent = 'Grounds must be at least 10 characters.'; errEl.classList.remove('hidden'); return; }
    var notes = document.getElementById('fileopening-notes').value.trim();
    var submitBtn = document.getElementById('fileopening-submit');
    submitBtn.disabled = true; submitBtn.textContent = 'Submitting…';
    fetch('https://mclaw/fileopening:openFile', {
        method: 'POST',
        body: JSON.stringify({ suspectCid: suspectCid, charges: selectedCodes, narrative: narrative, notes: notes }),
    }).then(function(res) { return res.json(); }).then(function(result) {
        submitBtn.disabled = false; submitBtn.textContent = 'Create File';
        if (result && result.ok) {
            document.getElementById('fileopening-form').reset();
            document.getElementById('fileopening-narrative-count').textContent = '0';
            document.querySelectorAll('#fileopening-charges .charge-item').forEach(function(i) { i.classList.remove('checked'); });
        } else {
            errEl.textContent = result && result.error ? result.error : 'Submission failed.';
            errEl.classList.remove('hidden');
        }
    }).catch(function() {
        submitBtn.disabled = false; submitBtn.textContent = 'Create File';
    });
});

// -- Pending approvals (judge)

function renderPendingApprovals() {
    var listEl  = document.getElementById('approvals-list');
    var emptyEl = document.getElementById('approvals-empty');
    listEl.innerHTML = '';
    if (pendingApprovals.length === 0) { emptyEl.style.display = ''; return; }
    emptyEl.style.display = 'none';
    pendingApprovals.forEach(function(file) {
        var chargeRows = (file.charges || []).map(function(c) {
            return '<div class="file-meta" style="padding-left:8px;">' +
                '<span class="file-meta-key" style="min-width:0;flex:1;">[' + (c.category || '?') + '] ' + c.label + '</span>' +
                '<span style="font-size:11px;color:#4a5268;white-space:nowrap;">' + (c.jailTime || 0) + ' dk / $' + (c.fine || 0) + '</span>' +
            '</div>';
        }).join('');
        var narrativeRow = file.narrative
            ? '<div class="file-meta" style="flex-direction:column;gap:4px;margin-top:6px;padding-top:6px;border-top:1px solid #2e3650;">' +
                  '<span class="file-meta-key">Opening Grounds</span>' +
                  '<span style="font-size:12px;color:#c0c8de;line-height:1.5;white-space:pre-wrap;">' + file.narrative + '</span>' +
              '</div>'
            : '';
        var internalNoteRow = file.notes
            ? '<div class="file-meta" style="flex-direction:column;gap:4px;margin-top:4px;">' +
                  '<span class="file-meta-key">Internal Note</span>' +
                  '<span style="font-size:12px;color:#8a93a8;white-space:pre-wrap;">' + file.notes + '</span>' +
              '</div>'
            : '';
        var JOB_LABELS = { prosecutor: 'Prosecutor', lawyer: 'Lawyer', judge: 'Judge' };
        var card = document.createElement('div');
        card.className = 'file-card';
        card.innerHTML =
            '<div class="file-card-header">' +
                '<span class="file-number">' + file.fileNumber + '</span>' +
                '<span class="file-status status-yellow">Pending Approval</span>' +
            '</div>' +
            '<div class="file-card-body">' +
                '<div class="file-meta"><span class="file-meta-key">Suspect</span><span>' + displayName(file.suspectName, file.suspectCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Opened By</span><span>' + (JOB_LABELS[file.openedByJob] || file.openedByJob || '?') + ' — ' + displayName(file.openedByName, file.openedBy) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Opened</span><span>' + (file.createdAt || '-') + '</span></div>' +
                '<div class="file-meta" style="flex-direction:column;gap:4px;margin-top:6px;padding-top:6px;border-top:1px solid #2e3650;">' +
                    '<span class="file-meta-key">Charges</span>' +
                    chargeRows +
                '</div>' +
                narrativeRow +
                internalNoteRow +
            '</div>' +
            '<div class="approval-actions" id="approval-actions-' + file.id + '">' +
                '<button class="btn-primary approval-approve-btn" data-id="' + file.id + '">Approve</button>' +
                '<button class="btn-danger approval-reject-btn" data-id="' + file.id + '">Reject</button>' +
                '<button class="btn-secondary approval-view-btn" data-id="' + file.id + '" style="margin-left:auto;">View →</button>' +
            '</div>' +
            '<div class="approval-reject-panel hidden" id="reject-panel-' + file.id + '">' +
                '<textarea class="reject-reason-input" id="reject-reason-' + file.id + '" rows="2" maxlength="300" placeholder="Rejection reason (optional)…"></textarea>' +
                '<div class="form-actions" style="margin-top:8px;">' +
                    '<button class="btn-danger approval-reject-confirm-btn" data-id="' + file.id + '">Confirm Rejection</button>' +
                    '<button class="btn-secondary approval-reject-cancel-btn" data-id="' + file.id + '">Cancel</button>' +
                '</div>' +
            '</div>';
        listEl.appendChild(card);
    });

    // View detail from approvals
    listEl.querySelectorAll('.approval-view-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            openFileDetail(parseInt(btn.getAttribute('data-id'), 10), 'approvals');
        });
    });

    // Approve buttons
    listEl.querySelectorAll('.approval-approve-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var fid = parseInt(btn.getAttribute('data-id'), 10);
            btn.disabled = true; btn.textContent = 'Approving…';
            fetch('https://mclaw/judge:approveFile', {
                method: 'POST',
                body: JSON.stringify({ fileId: fid, notes: '' }),
            }).then(function(res) { return res.json(); }).then(function(result) {
                if (result && result.ok) {
                    var card = btn.closest('.file-card');
                    if (card) { card.remove(); }
                    pendingApprovals = pendingApprovals.filter(function(f) { return f.id !== fid; });
                    if (pendingApprovals.length === 0) { document.getElementById('approvals-empty').style.display = ''; }
                } else {
                    btn.disabled = false; btn.textContent = 'Approve';
                }
            }).catch(function() { btn.disabled = false; btn.textContent = 'Approve'; });
        });
    });

    // Reject buttons — show panel
    listEl.querySelectorAll('.approval-reject-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var fid = btn.getAttribute('data-id');
            document.getElementById('approval-actions-' + fid).classList.add('hidden');
            document.getElementById('reject-panel-' + fid).classList.remove('hidden');
        });
    });

    // Reject cancel
    listEl.querySelectorAll('.approval-reject-cancel-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var fid = btn.getAttribute('data-id');
            document.getElementById('reject-panel-' + fid).classList.add('hidden');
            document.getElementById('approval-actions-' + fid).classList.remove('hidden');
        });
    });

    // Reject confirm
    listEl.querySelectorAll('.approval-reject-confirm-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var fid = parseInt(btn.getAttribute('data-id'), 10);
            var reason = document.getElementById('reject-reason-' + fid).value.trim();
            btn.disabled = true; btn.textContent = 'Rejecting…';
            fetch('https://mclaw/judge:rejectFile', {
                method: 'POST',
                body: JSON.stringify({ fileId: fid, reason: reason }),
            }).then(function(res) { return res.json(); }).then(function(result) {
                if (result && result.ok) {
                    var card = btn.closest('.file-card');
                    if (card) { card.remove(); }
                    pendingApprovals = pendingApprovals.filter(function(f) { return f.id !== fid; });
                    if (pendingApprovals.length === 0) { document.getElementById('approvals-empty').style.display = ''; }
                } else {
                    btn.disabled = false; btn.textContent = 'Confirm Rejection';
                }
            }).catch(function() { btn.disabled = false; btn.textContent = 'Confirm Rejection'; });
        });
    });
}

// -- File detail

var previousTab        = 'files';
var currentFileDetail  = null;

// DOC_TYPE_LABELS and DOC_TYPES_BY_JOB are built dynamically from docTypeList (Config.DocTypes).
function getDocTypeLabel(value) {
    for (var i = 0; i < docTypeList.length; i++) {
        if (docTypeList[i].value === value) return docTypeList[i].label;
    }
    return value;
}

function getDocTypesForJob(job) {
    var result = [];
    for (var i = 0; i < docTypeList.length; i++) {
        var dt = docTypeList[i];
        if (dt.jobs && dt.jobs.indexOf(job) !== -1) result.push(dt);
    }
    return result;
}

var JOB_TR = { prosecutor: 'Prosecutor', judge: 'Judge', lawyer: 'Lawyer', police: 'Police' };

function displayName(name, cid) {
    if (name && cid) return name + ' <span style="color:#4a5268;font-size:11px;">(' + escHtml(cid) + ')</span>';
    return escHtml(name || cid || '—');
}

function openFileDetail(fileId, fromTab) {
    previousTab = fromTab || 'files';
    fetch('https://mclaw/file:getDetail', {
        method: 'POST',
        body: JSON.stringify({ fileId: fileId }),
    }).then(function(res) { return res.json(); }).then(function(result) {
        if (result && result.ok && result.data) {
            currentFileDetail = result.data;
            renderFileDetail(result.data);
            activateTab('filedetail');
        }
    });
}

function renderFileDetail(file) {
    // Topbar
    document.getElementById('filedetail-number').textContent = file.fileNumber;
    var badge = document.getElementById('filedetail-status');
    badge.className = 'file-status ' + (STATUS_COLORS[file.status] || 'status-gray');
    badge.textContent = STATUS_LABELS[file.status] || file.status;

    var closeBtn   = document.getElementById('filedetail-close-btn');
    var closePanel = document.getElementById('filedetail-close-panel');
    var canClose   = currentJob === 'judge' && file.status !== 'closed' && file.status !== 'archived' && file.status !== 'verdict_issued';
    if (canClose) { closeBtn.classList.remove('hidden'); } else { closeBtn.classList.add('hidden'); }
    closePanel.classList.add('hidden');
    closeBtn.setAttribute('data-id', file.id);
    document.getElementById('filedetail-close-reason').value = '';

    // Body
    var body = document.getElementById('filedetail-body');
    body.innerHTML = '';

    // ── Parties
    var parties = mkSection('Parties');
    var pb = parties.querySelector('.detail-section-body');
    pb.innerHTML =
        mkRow('Plaintiff',    '<span style="color:#c9a84c;font-weight:600;">State (Prosecution)</span>') +
        mkRow('Defendant',    displayName(file.suspectName,    file.suspectCid)) +
        mkRow('Prosecutor',   displayName(file.prosecutorName, file.prosecutorCid)) +
        mkRow('Judge',        displayName(file.judgeName,      file.judgeCid)) +
        mkRow('Opened',       file.createdAt || '—') +
        (file.closedAt ? mkRow('Closed', '<span style="color:#ea4335;">' + file.closedAt + '</span>') : '') +
        (file.openedBy ? mkRow('Opened By', (JOB_TR[file.openedByJob] || file.openedByJob || '?') + ' — ' + displayName(file.openedByName, file.openedBy)) : '');
    body.appendChild(parties);

    // ── Charges
    var chargesSection = mkSection('Charges');
    var cb2 = chargesSection.querySelector('.detail-section-body');
    cb2.style.padding = '0';
    cb2.style.gap = '0';
    (file.charges || []).forEach(function(c) {
        var row = document.createElement('div');
        row.className = 'charge-row';
        row.innerHTML =
            '<span class="charge-cat">' + (c.category || '?').toUpperCase() + '</span>' +
            '<span class="charge-name">' + c.label + '</span>' +
            '<span class="charge-penalty">' + (c.jailTime || 0) + ' dk / $' + (c.fine || 0) + '</span>';
        if (c.note) {
            var noteEl = document.createElement('div');
            noteEl.style.cssText = 'padding:2px 16px 6px 30px;font-size:11px;color:#4a5268;';
            noteEl.textContent = c.note;
            cb2.appendChild(row);
            cb2.appendChild(noteEl);
        } else {
            cb2.appendChild(row);
        }
    });
    body.appendChild(chargesSection);

    // ── Source petition (for investigations opened from lawyer petitions)
    if (file.sourcePetition) {
        var sp = file.sourcePetition;
        var PETITION_TR = { criminal: 'Criminal Case', civil: 'Civil Case' };
        var spSection = mkSection('Source Petition');
        var spb = spSection.querySelector('.detail-section-body');

        var spChargeRows = (sp.charges || []).map(function(c) {
            return '<div class="charge-row">' +
                '<span class="charge-cat">' + (c.category || '?').toUpperCase() + '</span>' +
                '<span class="charge-name">' + c.label + '</span>' +
                '<span class="charge-penalty">' + c.jailTime + ' min / $' + c.fine + '</span>' +
            '</div>';
        }).join('');

        spb.innerHTML =
            mkRow('Type',     PETITION_TR[sp.petitionType] || sp.petitionType) +
            mkRow('Lawyer',   displayName(sp.attorneyName,  sp.attorneyCid)) +
            mkRow('Client',   displayName(sp.plaintiffName, sp.plaintiffCid)) +
            mkRow('Subject',  escHtml(sp.subject)) +
            mkRow('Date',     sp.createdAt || '—');

        if (sp.description) {
            var descEl = document.createElement('div');
            descEl.className = 'detail-narrative';
            descEl.style.margin = '0 0 0 0';
            descEl.innerHTML = '<div style="padding:8px 16px 2px;font-size:11px;color:#5a6480;text-transform:uppercase;letter-spacing:.4px;">Petition Content</div>' +
                '<div style="padding:0 16px 12px;font-size:13px;color:#c0c8de;white-space:pre-wrap;">' + escHtml(sp.description) + '</div>';
            spb.appendChild(descEl);
        }

        if (spChargeRows) {
            var chEl = document.createElement('div');
            chEl.innerHTML = '<div style="padding:8px 16px 4px;font-size:11px;color:#5a6480;text-transform:uppercase;letter-spacing:.4px;">Charges</div>' + spChargeRows;
            spb.appendChild(chEl);
        }

        if (sp.attachments && sp.attachments.length > 0) {
            var attEl = document.createElement('div');
            attEl.innerHTML = '<div style="padding:8px 16px 4px;font-size:11px;color:#5a6480;text-transform:uppercase;letter-spacing:.4px;">Attachments</div>' +
                buildAttachmentsHtml(sp.attachments).replace('<div class="file-meta"', '<div class="file-meta" style="margin:0;padding:0 16px 10px;border-top:none;"');
            spb.appendChild(attEl);
            bindAttachmentCopyBtns(spb);
        }

        body.appendChild(spSection);
    }

    // ── Opening grounds
    if (file.narrative) {
        var narSection = mkSection('Opening Grounds');
        var nb = narSection.querySelector('.detail-section-body');
        nb.style.padding = '0';
        var narEl = document.createElement('div');
        narEl.className = 'detail-narrative';
        narEl.textContent = file.narrative;
        nb.appendChild(narEl);
        if (file.narrativeBy) {
            var narMeta = document.createElement('div');
            narMeta.style.cssText = 'padding:0 16px 10px;font-size:11px;color:#4a5268;';
            narMeta.innerHTML = (JOB_TR[file.narrativeJob] || file.narrativeJob || '?') + ' — ' + displayName(file.narrativeByName, file.narrativeBy) + '  ·  ' + (file.narrativeAt || '');
            nb.appendChild(narMeta);
        }
        body.appendChild(narSection);
    }

    // ── Hearing
    if (file.hearing) {
        var h = file.hearing;
        var hearSection = mkSection('Hearing');
        var hb = hearSection.querySelector('.detail-section-body');
        hb.innerHTML =
            mkRow('Type',   h.hearingType === 'written' ? 'Written Trial' : 'Physical Hearing') +
            mkRow('Date',   '<span style="color:#c9a84c;font-weight:600;">' + (h.scheduledAt || '—') + '</span>') +
            mkRow('Status', HEARING_STATUS_LABELS[h.status] || h.status) +
            (h.notes ? mkRow('Note', h.notes) : '');
        body.appendChild(hearSection);
    }

    // ── Internal note
    if (file.notes) {
        var noteSection = mkSection('Internal Note');
        var noteSB = noteSection.querySelector('.detail-section-body');
        noteSB.style.padding = '0';
        var noteEl2 = document.createElement('div');
        noteEl2.className = 'detail-narrative';
        noteEl2.textContent = file.notes;
        noteSB.appendChild(noteEl2);
        body.appendChild(noteSection);
    }

    // ── Schedule hearing (judge, when file is indictment_ready)
    if (currentJob === 'judge' && file.status === 'indictment_ready') {
        var hearingSection = mkSection('Schedule Hearing');
        var hb2 = hearingSection.querySelector('.detail-section-body');
        hb2.style.padding = '0';
        var hForm = document.createElement('div');
        hForm.className = 'add-doc-form';
        hForm.id = 'detail-hearing-form-' + file.id;
        hForm.innerHTML =
            '<div style="display:flex;gap:10px;">' +
                '<div style="flex:1;">' +
                    '<label style="font-size:11px;color:#a8b0c8;text-transform:uppercase;letter-spacing:.4px;display:block;margin-bottom:5px;">Date & Time</label>' +
                    '<input type="datetime-local" id="dh-dt-' + file.id + '" style="width:100%;padding:8px 10px;">' +
                '</div>' +
                '<div style="flex:1;">' +
                    '<label style="font-size:11px;color:#a8b0c8;text-transform:uppercase;letter-spacing:.4px;display:block;margin-bottom:5px;">Type</label>' +
                    '<select id="dh-type-' + file.id + '" style="width:100%;padding:8px 10px;">' +
                        '<option value="physical">Physical Hearing</option>' +
                        '<option value="written">Written Trial</option>' +
                    '</select>' +
                '</div>' +
            '</div>' +
            '<textarea id="dh-notes-' + file.id + '" rows="2" maxlength="300" placeholder="Note (optional)…"></textarea>' +
            '<div id="dh-error-' + file.id + '" class="form-error hidden"></div>' +
            '<div><button class="btn-primary dh-submit" data-id="' + file.id + '" style="font-size:12px;padding:8px 20px;">Save Hearing</button></div>';
        hb2.appendChild(hForm);
        body.appendChild(hearingSection);

        hForm.querySelector('.dh-submit').addEventListener('click', function() {
            var fid    = parseInt(file.id, 10);
            var dtVal  = document.getElementById('dh-dt-' + fid).value;
            var type   = document.getElementById('dh-type-' + fid).value;
            var notes  = document.getElementById('dh-notes-' + fid).value.trim();
            var errEl  = document.getElementById('dh-error-' + fid);
            errEl.classList.add('hidden');
            if (!dtVal) { errEl.textContent = 'Please select a date.'; errEl.classList.remove('hidden'); return; }
            var btn = hForm.querySelector('.dh-submit');
            btn.disabled = true; btn.textContent = 'Saving…';
            fetch('https://mclaw/judge:acceptCase', {
                method: 'POST',
                body: JSON.stringify({ fileId: fid, scheduledAt: dtVal, hearingType: type, notes: notes }),
            }).then(function(r) { return r.json(); }).then(function(result) {
                if (result && result.ok) {
                    // Update: status badge + remove form
                    var badge = document.getElementById('filedetail-status');
                    if (badge) { badge.className = 'file-status status-green'; badge.textContent = 'Hearing Scheduled'; }
                    hearingSection.remove();
                    var typeLabel2 = type === 'written' ? 'Written Trial' : 'Physical Hearing';
                    var dtFormatted = dtVal.replace('T', ' ');
                    var newHearSec = mkSection('Hearing');
                    var nhb = newHearSec.querySelector('.detail-section-body');
                    nhb.innerHTML =
                        mkRow('Type', typeLabel2) +
                        mkRow('Date', '<span style="color:#c9a84c;font-weight:600;">' + dtFormatted + '</span>') +
                        mkRow('Status', 'Scheduled') +
                        (notes ? mkRow('Note', notes) : '');
                    // Insert after the charges section
                    var chargesSec = body.querySelector('.detail-section:nth-child(2)');
                    if (chargesSec && chargesSec.nextSibling) {
                        body.insertBefore(newHearSec, chargesSec.nextSibling);
                    } else {
                        body.appendChild(newHearSec);
                    }
                } else {
                    btn.disabled = false; btn.textContent = 'Save Hearing';
                    errEl.textContent = 'Save failed.'; errEl.classList.remove('hidden');
                }
            }).catch(function() { btn.disabled = false; btn.textContent = 'Save Hearing'; });
        });
    }

    // ── Documents
    var docsSection = mkSection('Documents');
    var docsBody = docsSection.querySelector('.detail-section-body');
    docsBody.style.padding = '0';
    docsBody.style.gap = '0';
    docsBody.id = 'filedetail-docs-body-' + file.id;
    if ((file.documents || []).length === 0) {
        var noDoc = document.createElement('div');
        noDoc.style.cssText = 'padding:16px;font-size:13px;color:#3a4258;text-align:center;';
        noDoc.id = 'filedetail-no-doc-' + file.id;
        noDoc.textContent = 'No documents added yet.';
        docsBody.appendChild(noDoc);
    }
    (file.documents || []).forEach(function(d) {
        docsBody.appendChild(buildDocCard(d, file));
    });

    // Add document form (closed/archived → no form)
    var docTypes = getDocTypesForJob(currentJob);
    var canAdd = docTypes.length > 0 && file.status !== 'closed' && file.status !== 'archived';
    if (canAdd) {
        var formDivider = document.createElement('div');
        formDivider.style.cssText = 'border-top:1px solid #2e3650;padding:10px 16px 4px;font-size:11px;color:#5a6480;text-transform:uppercase;letter-spacing:.5px;';
        formDivider.textContent = 'Add Document';
        docsBody.appendChild(formDivider);

        var formEl = document.createElement('div');
        formEl.className = 'add-doc-form';

        var typeOpts = docTypes.map(function(t) { return '<option value="' + t.value + '">' + t.label + '</option>'; }).join('');
        formEl.innerHTML =
            '<select id="adoc-type-' + file.id + '">' + typeOpts + '</select>' +
            '<input type="text" id="adoc-title-' + file.id + '" maxlength="128" placeholder="Title…">' +
            '<textarea id="adoc-content-' + file.id + '" rows="5" maxlength="3000" placeholder="Content…"></textarea>' +
            '<div id="adoc-error-' + file.id + '" class="form-error hidden"></div>' +
            '<div><button class="btn-primary adoc-submit" data-id="' + file.id + '" style="font-size:12px;padding:8px 20px;">Add</button></div>';
        docsBody.appendChild(formEl);
    }

    body.appendChild(docsSection);

    // ── History
    if (file.history && file.history.length > 0) {
        body.appendChild(renderHistory(file.history));
    }

    // Submit new document
    body.querySelectorAll('.adoc-submit').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var fid    = parseInt(btn.getAttribute('data-id'), 10);
            var errEl  = document.getElementById('adoc-error-' + fid);
            var dtype  = document.getElementById('adoc-type-' + fid).value;
            var title  = document.getElementById('adoc-title-' + fid).value.trim();
            var cont   = document.getElementById('adoc-content-' + fid).value.trim();
            errEl.classList.add('hidden');
            if (title.length < 2) { errEl.textContent = 'Title is too short.'; errEl.classList.remove('hidden'); return; }
            if (cont.length < 5)  { errEl.textContent = 'Content is too short.'; errEl.classList.remove('hidden'); return; }
            btn.disabled = true; btn.textContent = 'Adding…';
            fetch('https://mclaw/file:addDocument', {
                method: 'POST',
                body: JSON.stringify({ fileId: fid, docType: dtype, title: title, content: cont }),
            }).then(function(res) { return res.json(); }).then(function(result) {
                btn.disabled = false; btn.textContent = 'Add';
                if (result && result.ok) {
                    // Append new doc card optimistically
                    var noDoc2 = document.getElementById('filedetail-no-doc-' + fid);
                    if (noDoc2) { noDoc2.remove(); }
                    var now = new Date();
                    var padZ = function(n) { return n < 10 ? '0' + n : '' + n; };
                    var nowStr = padZ(now.getDate()) + '.' + padZ(now.getMonth()+1) + '.' + now.getFullYear() + ' ' + padZ(now.getHours()) + ':' + padZ(now.getMinutes());
                    var newDoc = { id: 0, authorCid: '—', authorJob: currentJob, docType: dtype, title: title, content: cont, createdAt: nowStr };
                    var docsBodyEl = document.getElementById('filedetail-docs-body-' + fid);
                    var formDivEl = docsBodyEl.querySelector('.add-doc-form').previousSibling;
                    docsBodyEl.insertBefore(buildDocCard(newDoc, currentFileDetail), formDivEl);
                    document.getElementById('adoc-title-' + fid).value = '';
                    document.getElementById('adoc-content-' + fid).value = '';
                } else {
                    errEl.textContent = 'Could not add document.';
                    errEl.classList.remove('hidden');
                }
            }).catch(function() { btn.disabled = false; btn.textContent = 'Add'; });
        });
    });
}

// ── File history
function renderHistory(histItems) {
    var HIST_ICONS = {
        'opened':          '📂',
        'approved':        '✅',
        'rejected':        '❌',
        'document':        '📄',
        'hearing_created': '📅',
    };
    var HIST_LABELS = {
        'opened':          'File Opened',
        'approved':        'File Approved',
        'rejected':        'File Rejected',
        'document':        'Document Added',
        'hearing_created': 'Hearing Scheduled',
    };
    var sec = mkSection('File History');
    var sb = sec.querySelector('.detail-section-body');
    sb.style.padding = '0';
    sb.style.gap = '0';
    if (!histItems || histItems.length === 0) {
        sb.innerHTML = '<div style="padding:16px;font-size:13px;color:#3a4258;text-align:center;">No history records.</div>';
        return sec;
    }
    histItems.forEach(function(item) {
        var row = document.createElement('div');
        row.style.cssText = 'display:flex;gap:10px;padding:9px 16px;border-bottom:1px solid #1e2435;align-items:flex-start;';
        var icon = HIST_ICONS[item.eventType] || '•';
        var label = HIST_LABELS[item.eventType] || item.eventType;
        var detail = '';
        if (item.eventType === 'document') {
            detail = getDocTypeLabel(item.docType) + ' — ' + escHtml(item.title || '');
        } else if (item.eventType === 'hearing_created') {
            var htLabel = item.hearingType === 'written' ? 'Written Trial' : 'Physical Hearing';
            detail = htLabel + ' → ' + (item.scheduledAt || '—');
        } else if (item.note) {
            detail = escHtml(item.note.length > 80 ? item.note.substring(0, 80) + '…' : item.note);
        }
        row.innerHTML =
            '<span style="font-size:14px;flex-shrink:0;margin-top:1px;">' + icon + '</span>' +
            '<div style="flex:1;">' +
                '<div style="font-size:12px;font-weight:600;color:#c0c8de;">' + label + '</div>' +
                (detail ? '<div style="font-size:12px;color:#5a6480;margin-top:2px;">' + detail + '</div>' : '') +
            '</div>' +
            '<div style="font-size:11px;color:#3a4258;white-space:nowrap;text-align:right;">' +
                (JOB_TR[item.actorJob] || item.actorJob || '') + '<br>' +
                displayName(item.actorName, item.actor) + '<br>' +
                (item.createdAt || '') +
            '</div>';
        sb.appendChild(row);
    });
    return sec;
}

// ── Document view modal
function openDocModal(doc, file) {
    var typeLabel = getDocTypeLabel(doc.docType);
    document.getElementById('doc-modal-fileno').textContent   = file ? file.fileNumber : '—';
    document.getElementById('doc-modal-type').textContent     = typeLabel;
    document.getElementById('doc-modal-title').textContent    = doc.title;
    document.getElementById('doc-modal-date').textContent     = doc.createdAt || '—';
    document.getElementById('doc-modal-author').innerHTML = (JOB_TR[doc.authorJob] || doc.authorJob) + ' — ' + displayName(doc.authorName, doc.authorCid);
    document.getElementById('doc-modal-content').textContent  = doc.content;
    document.getElementById('doc-view-modal').classList.remove('hidden');
}

document.getElementById('doc-modal-close').addEventListener('click', function() {
    document.getElementById('doc-view-modal').classList.add('hidden');
});

document.getElementById('doc-modal-print').addEventListener('click', function() {
    var lines = [
        '════════════════════════════════════════',
        '     mcLaw Legal System',
        '     File No: ' + (document.getElementById('doc-modal-fileno').textContent || ''),
        '════════════════════════════════════════',
        'Doc Type : ' + (document.getElementById('doc-modal-type').textContent   || ''),
        'Title    : ' + (document.getElementById('doc-modal-title').textContent  || ''),
        'Date     : ' + (document.getElementById('doc-modal-date').textContent   || ''),
        'Author   : ' + (document.getElementById('doc-modal-author').textContent || ''),
        '────────────────────────────────────────',
        '',
        (document.getElementById('doc-modal-content').textContent || ''),
        '',
        '════════════════════════════════════════',
    ];
    var text = lines.join('\n');
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.style.cssText = 'position:fixed;top:0;left:0;opacity:0;pointer-events:none;';
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    try {
        document.execCommand('copy');
        document.getElementById('doc-modal-print').textContent = '✓ Copied to Clipboard';
        setTimeout(function() {
            document.getElementById('doc-modal-print').textContent = '📋 Copy to Clipboard';
        }, 2000);
    } catch (e) {}
    document.body.removeChild(ta);
});

function buildDocCard(d, file) {
    var el = document.createElement('div');
    el.className = 'doc-card';
    var typeLabel = getDocTypeLabel(d.docType);
    el.innerHTML =
        '<div class="doc-card-header">' +
            '<span class="doc-type-badge doc-badge-generic">' + typeLabel + '</span>' +
            '<span class="doc-title">' + escHtml(d.title) + '</span>' +
            '<span class="doc-meta">' + (JOB_TR[d.authorJob] || d.authorJob) + ' · ' + displayName(d.authorName, d.authorCid) + '  ·  ' + (d.createdAt || '') + '</span>' +
            '<button class="btn-secondary doc-view-btn" style="font-size:11px;padding:4px 10px;margin-left:8px;flex-shrink:0;">View</button>' +
        '</div>' +
        '<div class="doc-content">' + escHtml(d.content) + '</div>';
    var viewBtn = el.querySelector('.doc-view-btn');
    viewBtn.addEventListener('click', function() { openDocModal(d, file); });
    return el;
}

function mkSection(title) {
    var sec = document.createElement('div');
    sec.className = 'detail-section';
    sec.innerHTML = '<div class="detail-section-title">' + title + '</div><div class="detail-section-body"></div>';
    return sec;
}

function mkRow(key, val) {
    return '<div class="detail-row"><span class="detail-key">' + key + '</span><span>' + val + '</span></div>';
}

function escHtml(str) {
    return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

// Back button
document.getElementById('filedetail-back').addEventListener('click', function() {
    activateTab(previousTab);
});

// Close file — show panel
document.getElementById('filedetail-close-btn').addEventListener('click', function() {
    document.getElementById('filedetail-close-panel').classList.remove('hidden');
    document.getElementById('filedetail-close-btn').classList.add('hidden');
});

document.getElementById('filedetail-close-cancel').addEventListener('click', function() {
    document.getElementById('filedetail-close-panel').classList.add('hidden');
    document.getElementById('filedetail-close-btn').classList.remove('hidden');
});

document.getElementById('filedetail-close-confirm').addEventListener('click', function() {
    var btn    = document.getElementById('filedetail-close-confirm');
    var reason = document.getElementById('filedetail-close-reason').value.trim();
    var fid    = parseInt(document.getElementById('filedetail-close-btn').getAttribute('data-id'), 10);
    btn.disabled = true; btn.textContent = 'Closing…';
    fetch('https://mclaw/judge:closeFile', {
        method: 'POST',
        body: JSON.stringify({ fileId: fid, reason: reason }),
    }).then(function(res) { return res.json(); }).then(function(result) {
        btn.disabled = false; btn.textContent = 'Close File';
        if (result && result.ok) {
            document.getElementById('filedetail-close-panel').classList.add('hidden');
            var badge = document.getElementById('filedetail-status');
            badge.className = 'file-status status-gray';
            badge.textContent = 'Closed';
        }
    }).catch(function() { btn.disabled = false; btn.textContent = 'Close File'; });
});

// -- Investigation open (prosecutor)

function populateInvOpenCharges() {
    var container = document.getElementById('invopen-charges');
    if (!container) return;
    container.innerHTML = '';
    fileOpenChargeList.forEach(function(charge) {
        var item = document.createElement('label');
        item.className = 'charge-item';
        var cb = document.createElement('input');
        cb.type = 'checkbox';
        cb.value = charge.code;
        cb.addEventListener('change', function() { item.classList.toggle('checked', cb.checked); });
        var lbl = document.createElement('span'); lbl.className = 'charge-label';
        lbl.textContent = '[' + (charge.category || '?') + '] ' + charge.label;
        var meta = document.createElement('span'); meta.className = 'charge-meta';
        meta.textContent = (charge.jailTime || 0) + ' dk / $' + (charge.fine || 0);
        item.appendChild(cb); item.appendChild(lbl); item.appendChild(meta);
        container.appendChild(item);
    });
}

document.getElementById('invopen-narrative').addEventListener('input', function() {
    document.getElementById('invopen-narrative-count').textContent = this.value.length;
});

document.getElementById('invopen-reset').addEventListener('click', function() {
    document.getElementById('invopen-form').reset();
    document.getElementById('invopen-narrative-count').textContent = '0';
    document.querySelectorAll('#invopen-charges .charge-item').forEach(function(i) { i.classList.remove('checked'); });
    document.getElementById('invopen-error').classList.add('hidden');
});

document.getElementById('invopen-form').addEventListener('submit', function(e) {
    e.preventDefault();
    var errEl = document.getElementById('invopen-error');
    errEl.classList.add('hidden');
    var suspectCid = document.getElementById('invopen-suspect').value.trim();
    if (!suspectCid) { errEl.textContent = 'Suspect citizen ID is required.'; errEl.classList.remove('hidden'); return; }
    var charges = [];
    document.querySelectorAll('#invopen-charges input[type="checkbox"]:checked').forEach(function(cb) {
        charges.push({ code: cb.value });
    });
    if (charges.length === 0) { errEl.textContent = 'Select at least one charge.'; errEl.classList.remove('hidden'); return; }
    var narrative = document.getElementById('invopen-narrative').value.trim();
    if (narrative.length < 10) { errEl.textContent = 'Grounds must be at least 10 characters.'; errEl.classList.remove('hidden'); return; }
    var notes = document.getElementById('invopen-notes').value.trim();
    var submitBtn = document.getElementById('invopen-submit');
    submitBtn.disabled = true; submitBtn.textContent = 'Opening…';
    fetch('https://mclaw/prosecutor:openInvestigation', {
        method: 'POST',
        body: JSON.stringify({ suspectCid: suspectCid, charges: charges, narrative: narrative, notes: notes }),
    }).then(function(r) { return r.json(); }).then(function(result) {
        submitBtn.disabled = false; submitBtn.textContent = 'Start Investigation';
        if (result && result.ok) {
            document.getElementById('invopen-form').reset();
            document.getElementById('invopen-narrative-count').textContent = '0';
            document.querySelectorAll('#invopen-charges .charge-item').forEach(function(i) { i.classList.remove('checked'); });
        } else {
            errEl.textContent = result && result.error ? result.error : 'Submission failed.';
            errEl.classList.remove('hidden');
        }
    }).catch(function() { submitBtn.disabled = false; submitBtn.textContent = 'Start Investigation'; });
});

// -- Petition system

var PETITION_TYPE_LABELS   = { criminal: 'Criminal Case', civil: 'Civil Case' };
var PETITION_STATUS_LABELS = { pending: 'Pending', accepted: 'Accepted', rejected: 'Rejected' };
var PETITION_STATUS_COLORS = { pending: 'status-yellow', accepted: 'status-green', rejected: 'status-red' };

function buildAttachmentsHtml(attachments) {
    if (!attachments || attachments.length === 0) return '';
    var rows = attachments.map(function(att) {
        return '<div style="display:flex;align-items:center;gap:8px;padding:4px 0;">' +
            '<span style="font-size:12px;color:#c0c8de;flex:1;">' + escHtml(att.label || 'Attachment') + '</span>' +
            '<button class="btn-secondary att-copy-btn" data-url="' + escHtml(att.url) + '" style="font-size:11px;padding:3px 10px;flex-shrink:0;">Copy Link</button>' +
        '</div>';
    }).join('');
    return '<div class="file-meta" style="flex-direction:column;gap:2px;margin-top:6px;padding-top:6px;border-top:1px solid #2e3650;">' +
        '<span class="file-meta-key">Attachments</span>' +
        '<div id="att-rows-' + Math.random().toString(36).slice(2) + '">' + rows + '</div>' +
    '</div>';
}

function bindAttachmentCopyBtns(container) {
    container.querySelectorAll('.att-copy-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var url = btn.getAttribute('data-url');
            var ta  = document.createElement('textarea');
            ta.value = url;
            ta.style.cssText = 'position:fixed;top:0;left:0;opacity:0;pointer-events:none;';
            document.body.appendChild(ta);
            ta.focus(); ta.select();
            try {
                document.execCommand('copy');
                btn.textContent = '✓ Copied';
                setTimeout(function() { btn.textContent = 'Copy Link'; }, 2000);
            } catch(e) {}
            document.body.removeChild(ta);
        });
    });
}

function populatePetitionCharges() {
    var container = document.getElementById('petition-charges');
    if (!container) return;
    container.innerHTML = '';
    fileOpenChargeList.forEach(function(charge) {
        var item = document.createElement('label');
        item.className = 'charge-item';
        var cb = document.createElement('input');
        cb.type = 'checkbox';
        cb.value = charge.code;
        cb.addEventListener('change', function() { item.classList.toggle('checked', cb.checked); });
        var labelSpan = document.createElement('span');
        labelSpan.className = 'charge-label';
        labelSpan.textContent = '[' + (charge.category || '?') + '] ' + charge.label;
        var meta = document.createElement('span');
        meta.className = 'charge-meta';
        meta.textContent = (charge.jailTime || 0) + ' dk / $' + (charge.fine || 0);
        item.appendChild(cb); item.appendChild(labelSpan); item.appendChild(meta);
        container.appendChild(item);
    });
}

// Criminal/civil radio → show/hide charge list
document.querySelectorAll('input[name="petition-type"]').forEach(function(radio) {
    radio.addEventListener('change', function() {
        var grp = document.getElementById('petition-charges-group');
        if (grp) grp.style.display = radio.value === 'criminal' ? '' : 'none';
    });
});

// Add attachment
document.getElementById('petition-add-attachment').addEventListener('click', function() {
    var container = document.getElementById('petition-attachments');
    var row = document.createElement('div');
    row.className = 'attachment-row';
    row.style.cssText = 'display:flex;gap:8px;margin-bottom:6px;align-items:center;';
    row.innerHTML =
        '<input type="text" class="att-label" maxlength="64" placeholder="Label (e.g. Photo 1)" style="flex:1;padding:7px 10px;">' +
        '<input type="url" class="att-url" maxlength="512" placeholder="https://..." style="flex:2;padding:7px 10px;">' +
        '<button type="button" class="att-remove btn-danger" style="padding:6px 10px;font-size:12px;flex-shrink:0;">✕</button>';
    row.querySelector('.att-remove').addEventListener('click', function() { row.remove(); });
    container.appendChild(row);
});

document.getElementById('petition-description').addEventListener('input', function() {
    document.getElementById('petition-desc-count').textContent = this.value.length;
});

document.getElementById('petition-reset').addEventListener('click', function() {
    document.getElementById('petition-form').reset();
    document.getElementById('petition-desc-count').textContent = '0';
    document.querySelectorAll('#petition-charges .charge-item').forEach(function(i) { i.classList.remove('checked'); });
    document.getElementById('petition-error').classList.add('hidden');
    document.getElementById('petition-attachments').innerHTML = '';
    var grp = document.getElementById('petition-charges-group');
    if (grp) grp.style.display = '';
});

document.getElementById('petition-form').addEventListener('submit', function(e) {
    e.preventDefault();
    var errEl = document.getElementById('petition-error');
    errEl.classList.add('hidden');

    var petType    = document.querySelector('input[name="petition-type"]:checked').value;
    var plaintiff  = document.getElementById('petition-plaintiff').value.trim();
    var subject    = document.getElementById('petition-subject').value.trim();
    var desc       = document.getElementById('petition-description').value.trim();

    if (!plaintiff) { errEl.textContent = 'Client citizen ID is required.'; errEl.classList.remove('hidden'); return; }
    if (!subject)   { errEl.textContent = 'Subject cannot be empty.'; errEl.classList.remove('hidden'); return; }
    if (desc.length < 10) { errEl.textContent = 'Petition content must be at least 10 characters.'; errEl.classList.remove('hidden'); return; }

    var charges = [];
    if (petType === 'criminal') {
        document.querySelectorAll('#petition-charges input[type="checkbox"]:checked').forEach(function(cb) {
            charges.push({ code: cb.value });
        });
        if (charges.length === 0) { errEl.textContent = 'Select at least one charge for a criminal case.'; errEl.classList.remove('hidden'); return; }
    }

    var attachments = [];
    document.querySelectorAll('#petition-attachments .attachment-row').forEach(function(row) {
        var label = row.querySelector('.att-label').value.trim();
        var url   = row.querySelector('.att-url').value.trim();
        if (url) attachments.push({ label: label || 'Attachment', url: url });
    });

    var submitBtn = document.getElementById('petition-submit');
    submitBtn.disabled = true; submitBtn.textContent = 'Submitting…';
    fetch('https://mclaw/lawyer:sendPetition', {
        method: 'POST',
        body: JSON.stringify({ petitionType: petType, plaintiffCid: plaintiff, charges: charges, subject: subject, description: desc, attachments: attachments }),
    }).then(function(r) { return r.json(); }).then(function(result) {
        submitBtn.disabled = false; submitBtn.textContent = 'Submit Petition';
        if (result && result.ok) {
            document.getElementById('petition-form').reset();
            document.getElementById('petition-desc-count').textContent = '0';
            document.getElementById('petition-attachments').innerHTML = '';
            document.querySelectorAll('#petition-charges .charge-item').forEach(function(i) { i.classList.remove('checked'); });
        } else {
            errEl.textContent = result && result.error ? result.error : 'Submission failed.';
            errEl.classList.remove('hidden');
        }
    }).catch(function() { submitBtn.disabled = false; submitBtn.textContent = 'Submit Petition'; });
});

function renderMyPetitions() {
    var listEl  = document.getElementById('mypetitions-list');
    var emptyEl = document.getElementById('mypetitions-empty');
    if (!listEl) return;
    listEl.innerHTML = '';
    if (myPetitions.length === 0) { if (emptyEl) emptyEl.style.display = ''; return; }
    if (emptyEl) emptyEl.style.display = 'none';
    myPetitions.forEach(function(p) {
        var card = document.createElement('div');
        card.className = 'file-card';
        var typeLabel   = PETITION_TYPE_LABELS[p.petitionType]   || p.petitionType;
        var statusLabel = PETITION_STATUS_LABELS[p.status]       || p.status;
        var statusClass = PETITION_STATUS_COLORS[p.status]       || 'status-gray';
        var rejectRow   = (p.status === 'rejected' && p.rejectReason)
            ? '<div class="file-meta" style="flex-direction:column;gap:2px;margin-top:4px;">' +
                  '<span class="file-meta-key" style="color:#ea4335;">Rejection Reason</span>' +
                  '<span style="font-size:12px;color:#c0c8de;">' + escHtml(p.rejectReason) + '</span>' +
              '</div>'
            : '';
        card.innerHTML =
            '<div class="file-card-header">' +
                '<span class="file-number">' + typeLabel + '</span>' +
                '<span class="file-status ' + statusClass + '">' + statusLabel + '</span>' +
            '</div>' +
            '<div class="file-card-body">' +
                '<div class="file-meta"><span class="file-meta-key">Client</span><span>' + displayName(p.plaintiffName, p.plaintiffCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Subject</span><span>' + escHtml(p.subject) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Submitted</span><span>' + (p.createdAt || '—') + '</span></div>' +
                rejectRow +
                buildAttachmentsHtml(p.attachments) +
            '</div>';
        bindAttachmentCopyBtns(card);
        listEl.appendChild(card);
    });
}

function renderIncomingPetitions() {
    var listEl  = document.getElementById('inpetitions-list');
    var emptyEl = document.getElementById('inpetitions-empty');
    if (!listEl) return;
    listEl.innerHTML = '';
    if (incomingPetitions.length === 0) { if (emptyEl) emptyEl.style.display = ''; return; }
    if (emptyEl) emptyEl.style.display = 'none';

    incomingPetitions.forEach(function(p) {
        var card = document.createElement('div');
        card.className = 'file-card';
        var typeLabel = PETITION_TYPE_LABELS[p.petitionType] || p.petitionType;
        var chargeRows = (p.charges || []).map(function(c) {
            return '<div class="file-meta" style="padding-left:8px;">' +
                '<span class="file-meta-key" style="flex:1;">[' + (c.category || '?') + '] ' + c.label + '</span>' +
                '<span style="font-size:11px;color:#4a5268;">' + c.jailTime + ' dk / $' + c.fine + '</span>' +
            '</div>';
        }).join('');
        var chargesSection = chargeRows
            ? '<div class="file-meta" style="flex-direction:column;gap:4px;margin-top:6px;padding-top:6px;border-top:1px solid #2e3650;">' +
                  '<span class="file-meta-key">Charges</span>' + chargeRows +
              '</div>'
            : '';
        card.innerHTML =
            '<div class="file-card-header">' +
                '<span class="file-number">' + typeLabel + '</span>' +
                '<span class="file-status status-yellow">Pending</span>' +
            '</div>' +
            '<div class="file-card-body">' +
                '<div class="file-meta"><span class="file-meta-key">Lawyer</span><span>' + displayName(p.attorneyName, p.attorneyCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Client</span><span>' + displayName(p.plaintiffName, p.plaintiffCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Subject</span><span>' + escHtml(p.subject) + '</span></div>' +
                '<div class="file-meta" style="flex-direction:column;gap:4px;margin-top:4px;">' +
                    '<span class="file-meta-key">Petition</span>' +
                    '<span style="font-size:12px;color:#c0c8de;white-space:pre-wrap;">' + escHtml(p.description) + '</span>' +
                '</div>' +
                chargesSection +
                '<div class="file-meta"><span class="file-meta-key">Date</span><span>' + (p.createdAt || '—') + '</span></div>' +
                buildAttachmentsHtml(p.attachments) +
            '</div>' +
            '<div class="approval-actions" id="inpet-actions-' + p.id + '">' +
                '<button class="btn-primary inpet-accept-btn" data-id="' + p.id + '">Accept</button>' +
                '<button class="btn-danger inpet-reject-btn" data-id="' + p.id + '">Reject</button>' +
            '</div>' +
            '<div class="approval-reject-panel hidden" id="inpet-reject-panel-' + p.id + '">' +
                '<textarea class="reject-reason-input" id="inpet-reason-' + p.id + '" rows="2" maxlength="300" placeholder="Rejection reason (optional)…"></textarea>' +
                '<div class="form-actions" style="margin-top:8px;">' +
                    '<button class="btn-danger inpet-reject-confirm-btn" data-id="' + p.id + '" data-type="' + p.petitionType + '">Confirm Rejection</button>' +
                    '<button class="btn-secondary inpet-reject-cancel-btn" data-id="' + p.id + '">Cancel</button>' +
                '</div>' +
            '</div>';
        bindAttachmentCopyBtns(card);
        listEl.appendChild(card);
    });

    var inpetEmptyEl = emptyEl;

    // Accept
    listEl.querySelectorAll('.inpet-accept-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var pid = parseInt(btn.getAttribute('data-id'), 10);
            btn.disabled = true; btn.textContent = 'Processing…';
            var endpoint = currentJob === 'prosecutor' ? 'prosecutor:acceptPetition' : 'judge:acceptCivilPetition';
            fetch('https://mclaw/' + endpoint, {
                method: 'POST',
                body: JSON.stringify({ petitionId: pid }),
            }).then(function(r) { return r.json(); }).then(function(result) {
                if (result && result.ok) {
                    var card = btn.closest('.file-card');
                    if (card) { card.remove(); }
                    incomingPetitions = incomingPetitions.filter(function(p) { return p.id !== pid; });
                    if (incomingPetitions.length === 0 && inpetEmptyEl) inpetEmptyEl.style.display = '';
                } else {
                    btn.disabled = false; btn.textContent = 'Accept';
                }
            }).catch(function() { btn.disabled = false; btn.textContent = 'Accept'; });
        });
    });

    // Reject show panel
    listEl.querySelectorAll('.inpet-reject-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var pid = btn.getAttribute('data-id');
            document.getElementById('inpet-actions-' + pid).classList.add('hidden');
            document.getElementById('inpet-reject-panel-' + pid).classList.remove('hidden');
        });
    });

    // Reject cancel
    listEl.querySelectorAll('.inpet-reject-cancel-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var pid = btn.getAttribute('data-id');
            document.getElementById('inpet-reject-panel-' + pid).classList.add('hidden');
            document.getElementById('inpet-actions-' + pid).classList.remove('hidden');
        });
    });

    // Reject confirm
    listEl.querySelectorAll('.inpet-reject-confirm-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var pid    = parseInt(btn.getAttribute('data-id'), 10);
            var reason = document.getElementById('inpet-reason-' + pid).value.trim();
            btn.disabled = true; btn.textContent = 'Rejecting…';
            var endpoint = currentJob === 'prosecutor' ? 'prosecutor:rejectPetition' : 'judge:rejectCivilPetition';
            fetch('https://mclaw/' + endpoint, {
                method: 'POST',
                body: JSON.stringify({ petitionId: pid, reason: reason }),
            }).then(function(r) { return r.json(); }).then(function(result) {
                if (result && result.ok) {
                    var card = btn.closest('.file-card');
                    if (card) { card.remove(); }
                    incomingPetitions = incomingPetitions.filter(function(p) { return p.id !== pid; });
                    if (incomingPetitions.length === 0 && inpetEmptyEl) inpetEmptyEl.style.display = '';
                } else {
                    btn.disabled = false; btn.textContent = 'Confirm Rejection';
                }
            }).catch(function() { btn.disabled = false; btn.textContent = 'Confirm Rejection'; });
        });
    });
}

// -- Hearings tab

var HEARING_TYPE_LABELS = { 'physical': 'Physical Hearing', 'written': 'Written Trial' };
var HEARING_STATUS_LABELS = { 'scheduled': 'Scheduled', 'active': 'Active', 'completed': 'Completed', 'cancelled': 'Cancelled' };
var HEARING_STATUS_COLORS = { 'scheduled': 'status-blue', 'active': 'status-green', 'completed': 'status-gray', 'cancelled': 'status-red' };

function renderHearingList() {
    var listEl  = document.getElementById('hearings-list');
    var emptyEl = document.getElementById('hearings-empty');
    if (!listEl) return;
    listEl.innerHTML = '';
    if (hearingList.length === 0) { if (emptyEl) emptyEl.style.display = ''; return; }
    if (emptyEl) emptyEl.style.display = 'none';
    hearingList.forEach(function(h) {
        var card = document.createElement('div');
        card.className = 'file-card';
        var typeLabel   = HEARING_TYPE_LABELS[h.hearingType]   || h.hearingType;
        var statusLabel = HEARING_STATUS_LABELS[h.status]      || h.status;
        var statusClass = HEARING_STATUS_COLORS[h.status]      || 'status-gray';
        var notesRow = h.notes ? '<div class="file-meta"><span class="file-meta-key">Note</span><span class="file-charges-text">' + h.notes + '</span></div>' : '';
        card.innerHTML =
            '<div class="file-card-header">' +
                '<span class="file-number">' + h.fileNumber + '</span>' +
                '<span class="file-status ' + statusClass + '">' + statusLabel + '</span>' +
            '</div>' +
            '<div class="file-card-body">' +
                '<div class="file-meta"><span class="file-meta-key">Suspect</span><span>' + displayName(h.suspectName, h.suspectCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Prosecutor</span><span>' + displayName(h.prosecutorName, h.prosecutorCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Type</span><span>' + typeLabel + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Date</span><span style="color:#c9a84c;font-weight:600;">' + (h.scheduledAt || '—') + '</span></div>' +
                notesRow +
            '</div>';
        var hViewBtn = document.createElement('button');
        hViewBtn.type = 'button';
        hViewBtn.className = 'btn-secondary file-indictment-btn';
        hViewBtn.textContent = 'View File →';
        (function(fid) {
            hViewBtn.addEventListener('click', function() { openFileDetail(fid, 'hearings'); });
        }(h.fileId));
        card.appendChild(hViewBtn);
        listEl.appendChild(card);
    });
}

// -- Verdict tab (judge)

// -- My Reports (police)

var REPORT_STATUS_LABELS = { pending: 'Pending', processed: 'Processed', rejected: 'Withdrawn' };
var REPORT_STATUS_COLORS = { pending: 'status-yellow', processed: 'status-green', rejected: 'status-red' };

function renderMyReports() {
    var listEl  = document.getElementById('myreports-list');
    var emptyEl = document.getElementById('myreports-empty');
    listEl.innerHTML = '';
    if (!myReports || myReports.length === 0) {
        emptyEl.style.display = '';
        return;
    }
    emptyEl.style.display = 'none';
    myReports.forEach(function(r) {
        var card = document.createElement('div');
        card.className = 'file-card';
        card.style.cursor = 'default';
        var statusLabel = REPORT_STATUS_LABELS[r.status] || r.status;
        var statusClass = REPORT_STATUS_COLORS[r.status] || '';
        card.innerHTML =
            '<div class="file-card-header">' +
                '<span class="file-number">' + escHtml(r.file_number || '—') + '</span>' +
                '<span class="file-status ' + statusClass + '">' + escHtml(statusLabel) + '</span>' +
            '</div>' +
            '<div class="file-card-body">' +
                '<div><strong>Suspect:</strong> ' + escHtml(r.suspect_citizenid) + '</div>' +
                '<div><strong>Submitted:</strong> ' + Mclaw_FormatDate(r.created_at) + '</div>' +
                (r.narrative ? '<div style="margin-top:4px;color:#aaa;font-size:12px;">' + escHtml(r.narrative.substring(0, 120)) + (r.narrative.length > 120 ? '…' : '') + '</div>' : '') +
            '</div>';
        listEl.appendChild(card);
    });
}

var VERDICT_RESULT_LABELS = { guilty: 'Guilty', acquitted: 'Acquitted', dismissed: 'Dismissed' };
var VERDICT_RESULT_COLORS = { guilty: 'status-red', acquitted: 'status-green', dismissed: 'status-gray' };

function renderVerdictList() {
    var listEl  = document.getElementById('verdict-list');
    var emptyEl = document.getElementById('verdict-empty');
    if (!listEl) return;
    listEl.innerHTML = '';
    if (verdictFiles.length === 0) { if (emptyEl) emptyEl.style.display = ''; return; }
    if (emptyEl) emptyEl.style.display = 'none';

    verdictFiles.forEach(function(file) {
        var card = document.createElement('div');
        card.className = 'file-card';

        var chargeRows = (file.charges || []).map(function(c) {
            return '<div class="file-meta" style="padding-left:8px;">' +
                '<span class="file-meta-key" style="flex:1;">[' + (c.category || '?') + '] ' + c.label + '</span>' +
                '<span style="font-size:11px;color:#4a5268;white-space:nowrap;">' + (c.jailTime || 0) + ' min / $' + (c.fine || 0) + '</span>' +
            '</div>';
        }).join('');

        card.innerHTML =
            '<div class="file-card-header">' +
                '<span class="file-number">' + file.fileNumber + '</span>' +
                '<span class="file-status status-green">Hearing Scheduled</span>' +
            '</div>' +
            '<div class="file-card-body">' +
                '<div class="file-meta"><span class="file-meta-key">Suspect</span><span>' + displayName(file.suspectName, file.suspectCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Hearing</span><span style="color:#c9a84c;font-weight:600;">' + escHtml(file.scheduledAt || '—') + '</span></div>' +
                (file.hearingType ? '<div class="file-meta"><span class="file-meta-key">Type</span><span>' + (HEARING_TYPE_LABELS[file.hearingType] || file.hearingType) + '</span></div>' : '') +
                '<div class="file-meta" style="flex-direction:column;gap:4px;margin-top:6px;padding-top:6px;border-top:1px solid #2e3650;">' +
                    '<span class="file-meta-key">Charges</span>' + chargeRows +
                '</div>' +
            '</div>' +
            '<div class="verdict-trigger" id="verdict-trigger-' + file.id + '">' +
                '<button class="btn-primary verdict-open-btn" data-id="' + file.id + '" style="font-size:12px;">Issue Verdict</button>' +
                '<button class="btn-secondary" data-id="' + file.id + '" onclick="(function(){openFileDetail(' + file.id + ',\'verdict\');})()" style="font-size:12px;margin-left:8px;">View File</button>' +
            '</div>' +
            '<div class="approval-reject-panel hidden" id="verdict-form-' + file.id + '"></div>';

        listEl.appendChild(card);
    });

    // Build inline verdict form on "Issue Verdict" click
    listEl.querySelectorAll('.verdict-open-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var fid   = parseInt(btn.getAttribute('data-id'), 10);
            var file  = verdictFiles.filter(function(f) { return f.id === fid; })[0];
            var panel = document.getElementById('verdict-form-' + fid);
            var trigger = document.getElementById('verdict-trigger-' + fid);
            if (!file || !panel) return;
            if (!panel.classList.contains('hidden')) return;

            // Build charge override rows
            var chargeOverrideHtml = (file.charges || []).map(function(c, i) {
                return '<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px;">' +
                    '<span style="flex:2;font-size:12px;color:#c0c8de;">' + escHtml(c.label) + '</span>' +
                    '<div style="flex:1;">' +
                        '<label style="font-size:10px;color:#5a6480;display:block;margin-bottom:2px;">Jail (min)</label>' +
                        '<input type="number" min="0" class="reject-reason-input vrd-jail-' + fid + '" data-code="' + escHtml(c.code) + '" value="' + (c.jailTime || 0) + '" style="width:100%;padding:5px 8px;">' +
                    '</div>' +
                    '<div style="flex:1;">' +
                        '<label style="font-size:10px;color:#5a6480;display:block;margin-bottom:2px;">Fine ($)</label>' +
                        '<input type="number" min="0" class="reject-reason-input vrd-fine-' + fid + '" data-code="' + escHtml(c.code) + '" value="' + (c.fine || 0) + '" style="width:100%;padding:5px 8px;">' +
                    '</div>' +
                '</div>';
            }).join('');

            panel.innerHTML =
                '<div style="padding:12px 0 0;">' +
                    '<div style="font-size:11px;color:#5a6480;text-transform:uppercase;letter-spacing:.4px;margin-bottom:10px;">Verdict</div>' +
                    '<div class="radio-group" style="margin-bottom:12px;">' +
                        '<label class="radio-item"><input type="radio" name="vrd-result-' + fid + '" value="guilty" checked><span class="radio-label"><strong style="color:#ea4335;">Guilty</strong></span></label>' +
                        '<label class="radio-item"><input type="radio" name="vrd-result-' + fid + '" value="acquitted"><span class="radio-label"><strong style="color:#34a853;">Acquitted</strong></span></label>' +
                        '<label class="radio-item"><input type="radio" name="vrd-result-' + fid + '" value="dismissed"><span class="radio-label"><strong style="color:#9aa0b4;">Dismissed</strong></span></label>' +
                    '</div>' +
                    (chargeOverrideHtml ? '<div style="font-size:11px;color:#5a6480;text-transform:uppercase;letter-spacing:.4px;margin-bottom:8px;">Sentence Override (per charge)</div>' + chargeOverrideHtml : '') +
                    '<div style="display:flex;gap:10px;margin-bottom:8px;">' +
                        '<div style="flex:1;"><label style="font-size:11px;color:#a8b0c8;display:block;margin-bottom:4px;">Total Jail (min)</label><input type="number" min="0" id="vrd-total-jail-' + fid + '" class="reject-reason-input" value="0" style="width:100%;padding:7px 10px;"></div>' +
                        '<div style="flex:1;"><label style="font-size:11px;color:#a8b0c8;display:block;margin-bottom:4px;">Total Fine ($)</label><input type="number" min="0" id="vrd-total-fine-' + fid + '" class="reject-reason-input" value="0" style="width:100%;padding:7px 10px;"></div>' +
                    '</div>' +
                    '<textarea id="vrd-reasoning-' + fid + '" class="reject-reason-input" rows="3" maxlength="500" placeholder="Reasoning (optional)…" style="width:100%;margin-bottom:8px;"></textarea>' +
                    '<div id="vrd-error-' + fid + '" class="form-error hidden"></div>' +
                    '<div class="form-actions" style="margin-top:6px;">' +
                        '<button class="btn-primary vrd-submit-btn" data-id="' + fid + '">Confirm Verdict</button>' +
                        '<button class="btn-secondary vrd-cancel-btn" data-id="' + fid + '">Cancel</button>' +
                    '</div>' +
                '</div>';

            panel.classList.remove('hidden');
            trigger.classList.add('hidden');

            // Auto-sum jail/fine from charge overrides
            function recalcTotals() {
                var jailInputs = panel.querySelectorAll('.vrd-jail-' + fid);
                var fineInputs = panel.querySelectorAll('.vrd-fine-' + fid);
                var totalJ = 0, totalF = 0;
                jailInputs.forEach(function(el) { totalJ += parseInt(el.value) || 0; });
                fineInputs.forEach(function(el) { totalF += parseInt(el.value) || 0; });
                document.getElementById('vrd-total-jail-' + fid).value = totalJ;
                document.getElementById('vrd-total-fine-' + fid).value = totalF;
            }
            panel.querySelectorAll('.vrd-jail-' + fid + ', .vrd-fine-' + fid).forEach(function(el) {
                el.addEventListener('input', recalcTotals);
            });
            recalcTotals();

            // Submit
            panel.querySelector('.vrd-submit-btn').addEventListener('click', function() {
                var submitBtn = panel.querySelector('.vrd-submit-btn');
                var errEl = document.getElementById('vrd-error-' + fid);
                errEl.classList.add('hidden');

                var resultEl = panel.querySelector('input[name="vrd-result-' + fid + '"]:checked');
                if (!resultEl) { errEl.textContent = 'Select a verdict result.'; errEl.classList.remove('hidden'); return; }

                var charges = [];
                (file.charges || []).forEach(function(c) {
                    var jailEl = panel.querySelector('.vrd-jail-' + fid + '[data-code="' + c.code + '"]');
                    var fineEl = panel.querySelector('.vrd-fine-' + fid + '[data-code="' + c.code + '"]');
                    charges.push({
                        code:         c.code,
                        jailOverride: jailEl ? parseInt(jailEl.value) || 0 : c.jailTime,
                        fineOverride: fineEl ? parseInt(fineEl.value) || 0 : c.fine,
                    });
                });

                submitBtn.disabled = true; submitBtn.textContent = 'Submitting…';
                fetch('https://mclaw/verdict:issue', {
                    method: 'POST',
                    body: JSON.stringify({
                        fileId:    fid,
                        result:    resultEl.value,
                        charges:   charges,
                        totalJail: parseInt(document.getElementById('vrd-total-jail-' + fid).value) || 0,
                        totalFine: parseInt(document.getElementById('vrd-total-fine-' + fid).value) || 0,
                        reasoning: document.getElementById('vrd-reasoning-' + fid).value.trim(),
                    }),
                }).then(function(r) { return r.json(); }).then(function(result) {
                    if (result && result.ok) {
                        var cardEl = submitBtn.closest('.file-card');
                        if (cardEl) { cardEl.remove(); }
                        verdictFiles = verdictFiles.filter(function(f) { return f.id !== fid; });
                        if (verdictFiles.length === 0 && emptyEl) emptyEl.style.display = '';
                    } else {
                        submitBtn.disabled = false; submitBtn.textContent = 'Confirm Verdict';
                        errEl.textContent = (result && result.error) ? result.error : 'Submission failed.';
                        errEl.classList.remove('hidden');
                    }
                }).catch(function() { submitBtn.disabled = false; submitBtn.textContent = 'Confirm Verdict'; });
            });

            // Cancel
            panel.querySelector('.vrd-cancel-btn').addEventListener('click', function() {
                panel.classList.add('hidden');
                trigger.classList.remove('hidden');
            });
        });
    });
}

// -- NUI message handler

window.addEventListener('message', function(event) {
    var data = event.data;
    if (data.action === 'show') {
        currentJob          = data.job || 'civilian';
        chargeList          = data.chargeList          || [];
        prosecutorFiles     = data.prosecutorFiles     || [];
        fileOpenChargeList  = data.fileOpenChargeList  || [];
        pendingApprovals    = data.pendingApprovals    || [];
        hearingList         = data.hearingList         || [];
        docTypeList         = data.docTypeList         || [];
        myPetitions         = data.myPetitions         || [];
        incomingPetitions   = data.incomingPetitions   || [];
        investigationList   = data.investigationList   || [];
        verdictFiles        = data.verdictFiles        || [];
        myReports           = data.myReports           || [];
        filterTabsForJob(currentJob);
        document.getElementById('user-job').textContent = currentJob;
        if (data.dashStats) {
            var af = document.getElementById('stat-active-files');
            var pn = document.getElementById('stat-pending');
            if (af) af.textContent = data.dashStats.activeFiles != null ? data.dashStats.activeFiles : '—';
            if (pn) pn.textContent = data.dashStats.pendingCount != null ? data.dashStats.pendingCount : '—';
        }
        if (currentJob === 'police') { populateReferralForm(); renderMyReports(); }
        if (currentJob === 'prosecutor' || currentJob === 'judge') { renderFilesList(); }
        if (currentJob === 'prosecutor') { populateInvOpenCharges(); }
        if (currentJob === 'prosecutor') { populateIndictmentFileSelect(); }
        if (fileOpenChargeList.length > 0) { populateFileOpenCharges(); showFileOpeningNote(currentJob); populateInvOpenCharges(); }
        if (currentJob === 'judge') { renderPendingApprovals(); }
        if (currentJob === 'judge' || currentJob === 'lawyer') { renderHearingList(); }
        if (currentJob === 'lawyer') { populatePetitionCharges(); renderMyPetitions(); }
        if (currentJob === 'prosecutor' || currentJob === 'judge') { renderIncomingPetitions(); }
        if (currentJob === 'prosecutor') { renderInvestigationList(); }
        if (currentJob === 'judge') { renderVerdictList(); }
        activateTab(data.activeTab || 'dashboard');
        document.getElementById('app').classList.remove('hidden');
    }
    if (data.action === 'tabUpdate') {
        if (data.dashStats !== undefined) {
            var af = document.getElementById('stat-active-files');
            var pn = document.getElementById('stat-pending');
            if (af) af.textContent = data.dashStats.activeFiles != null ? data.dashStats.activeFiles : '—';
            if (pn) pn.textContent = data.dashStats.pendingCount != null ? data.dashStats.pendingCount : '—';
        }
        if (data.prosecutorFiles !== undefined) {
            prosecutorFiles = data.prosecutorFiles;
            renderFilesList();
            if (currentJob === 'prosecutor') { populateIndictmentFileSelect(); }
        }
        if (data.pendingApprovals !== undefined) {
            pendingApprovals = data.pendingApprovals;
            renderPendingApprovals();
        }
        if (data.hearingList !== undefined) {
            hearingList = data.hearingList;
            renderHearingList();
        }
        if (data.investigationList !== undefined) {
            investigationList = data.investigationList;
            renderInvestigationList();
        }
        if (data.myPetitions !== undefined) {
            myPetitions = data.myPetitions;
            renderMyPetitions();
        }
        if (data.incomingPetitions !== undefined) {
            incomingPetitions = data.incomingPetitions;
            renderIncomingPetitions();
        }
        if (data.chargeList !== undefined) {
            chargeList = data.chargeList;
            populateReferralForm();
        }
        if (data.myReports !== undefined) {
            myReports = data.myReports;
            renderMyReports();
        }
        if (data.verdictFiles !== undefined) {
            verdictFiles = data.verdictFiles;
            renderVerdictList();
        }
    }
    if (data.action === 'hide') {
        document.getElementById('app').classList.add('hidden');
    }
});

// -- Citizens search

function renderCitizensResults(results) {
    var listEl  = document.getElementById('citizens-results');
    var statusEl = document.getElementById('citizens-status');
    listEl.innerHTML = '';
    if (!results || results.length === 0) {
        statusEl.textContent = 'No results found.';
        return;
    }
    statusEl.textContent = results.length + ' result(s) found.';
    results.forEach(function(r) {
        var card = document.createElement('div');
        card.className = 'file-card';
        card.style.cursor = 'default';
        card.innerHTML =
            '<div class="file-card-body" style="display:flex;align-items:center;justify-content:space-between;gap:12px;">' +
                '<div>' +
                    '<div style="font-size:14px;font-weight:600;color:#c0c8de;">' + escHtml(r.name || '—') + '</div>' +
                    '<div style="font-size:12px;color:#5a6480;margin-top:2px;">Citizen ID: <span style="font-family:monospace;color:#a8b0c8;">' + escHtml(r.citizenid) + '</span></div>' +
                '</div>' +
                '<button class="btn-secondary citizens-copy-btn" data-cid="' + escHtml(r.citizenid) + '" style="font-size:11px;padding:5px 12px;flex-shrink:0;">Copy ID</button>' +
            '</div>';
        card.querySelector('.citizens-copy-btn').addEventListener('click', function() {
            var btn = card.querySelector('.citizens-copy-btn');
            var cid = btn.getAttribute('data-cid');
            var ta  = document.createElement('textarea');
            ta.value = cid;
            ta.style.cssText = 'position:fixed;top:0;left:0;opacity:0;pointer-events:none;';
            document.body.appendChild(ta);
            ta.focus(); ta.select();
            try {
                document.execCommand('copy');
                btn.textContent = '✓ Copied';
                setTimeout(function() { btn.textContent = 'Copy ID'; }, 2000);
            } catch(e) {}
            document.body.removeChild(ta);
        });
        listEl.appendChild(card);
    });
}

function doSearchCitizens() {
    var query    = document.getElementById('citizens-query').value.trim();
    var statusEl = document.getElementById('citizens-status');
    var btn      = document.getElementById('citizens-search-btn');
    if (query.length < 2) { statusEl.textContent = 'Enter at least 2 characters.'; return; }
    btn.disabled = true;
    statusEl.textContent = 'Searching…';
    fetch('https://mclaw/citizens:search', {
        method: 'POST',
        body: JSON.stringify({ query: query }),
    }).then(function(r) { return r.json(); }).then(function(results) {
        btn.disabled = false;
        renderCitizensResults(results);
    }).catch(function() {
        btn.disabled = false;
        statusEl.textContent = 'Search failed.';
    });
}

document.getElementById('citizens-search-btn').addEventListener('click', doSearchCitizens);
document.getElementById('citizens-query').addEventListener('keydown', function(e) {
    if (e.key === 'Enter') { e.preventDefault(); doSearchCitizens(); }
});

// -- Close on ESC

document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        var modal = document.getElementById('doc-view-modal');
        if (!modal.classList.contains('hidden')) {
            modal.classList.add('hidden');
            return;
        }
        document.getElementById('app').classList.add('hidden');
        fetch('https://mclaw/close', { method: 'POST', body: JSON.stringify({}) });
    }
});

document.getElementById('btn-exit-app').addEventListener('click', function() {
    document.getElementById('app').classList.add('hidden');
    fetch('https://mclaw/close', { method: 'POST', body: JSON.stringify({}) });
});
