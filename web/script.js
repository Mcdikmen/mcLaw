'use strict';

// -- State

var currentJob          = null;
var chargeList          = [];
var nearbyPlayers       = [];
var prosecutorFiles     = [];
var fileOpenChargeList  = [];
var pendingApprovals    = [];
var hearingList         = [];
var docTypeList         = [];
var myPetitions         = [];
var incomingPetitions   = [];

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

var REFRESHABLE_TABS = { dashboard: 1, files: 1, approvals: 1, hearings: 1, referral: 1, mypetitions: 1, inpetitions: 1 };

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

// -- Referral form

function populateReferralForm() {
    var suspectSelect = document.getElementById('referral-suspect');
    suspectSelect.innerHTML = '<option value="">-- Yakindaki oyuncu secin --</option>';
    var noNearby = document.getElementById('referral-no-nearby');
    if (nearbyPlayers.length === 0) {
        noNearby.style.display = '';
    } else {
        noNearby.style.display = 'none';
        nearbyPlayers.forEach(function(p) {
            var opt = document.createElement('option');
            opt.value = p.value;
            opt.textContent = p.label;
            suspectSelect.appendChild(opt);
        });
    }
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
    hideReferralError();
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
    var suspectSource = document.getElementById('referral-suspect').value;
    if (!suspectSource) { showReferralError('Lutfen bir suphe secin.'); return; }
    var selectedCodes = [];
    document.querySelectorAll('#referral-charges input[type="checkbox"]:checked').forEach(function(cb) {
        selectedCodes.push({ code: cb.value });
    });
    if (selectedCodes.length === 0) { showReferralError('En az bir suc secin.'); return; }
    var narrative = document.getElementById('referral-narrative').value.trim();
    if (narrative.length < 10) { showReferralError('Olay anlatis en az 10 karakter olmali.'); return; }
    var submitBtn = document.querySelector('#referral-form .btn-primary');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Gonderiliyor...';
    fetch('https://mclaw/referral:submit', {
        method: 'POST',
        body: JSON.stringify({ suspectSource: parseInt(suspectSource, 10), charges: selectedCodes, narrative: narrative }),
    }).then(function(res) { return res.json(); }).then(function(result) {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Raporu Gonder';
        if (result && result.ok) {
            document.getElementById('referral-form').reset();
            document.getElementById('narrative-count').textContent = '0';
            document.querySelectorAll('.charge-item').forEach(function(item) { item.classList.remove('checked'); });
        } else {
            showReferralError(result && result.error ? result.error : 'Gonderme basarisiz.');
        }
    }).catch(function() {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Raporu Gonder';
    });
});

// -- Files tab (prosecutor / judge)

var STATUS_LABELS = {
    'opened':               'Acildi',
    'awaiting_prosecutor':  'Savci Bekleniyor',
    'prosecutor_review':    'Savci Incelemesinde',
    'indictment_ready':     'Iddianame Hazir',
    'hearing_scheduled':    'Durusma Planlandi',
    'written_trial_active': 'Yazili Yargilama',
    'verdict_issued':       'Karar Verildi',
    'enforcement_active':   'Icra Aktif',
    'closed':               'Kapatıldı',
    'archived':             'Arşivlendi',
    'pending_approval':     'Onay Bekliyor',
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
        var notesRow = file.notes ? '<div class="file-meta"><span class="file-meta-key">Not</span><span class="file-charges-text">' + file.notes + '</span></div>' : '';
        var pendingRow = (file.status === 'pending_approval')
            ? '<div class="file-meta" style="margin-top:6px;padding-top:6px;border-top:1px solid #2e3650;">' +
                  '<span class="file-meta-key" style="color:#fbbc04;">Onay</span>' +
                  '<span style="color:#fbbc04;font-size:12px;">Hakim onayı bekleniyor</span>' +
              '</div>'
            : '';
        card.innerHTML =
            '<div class="file-card-header">' +
                '<span class="file-number">' + file.fileNumber + '</span>' +
                '<span class="file-status ' + statusClass + '">' + statusLabel + '</span>' +
            '</div>' +
            '<div class="file-card-body">' +
                '<div class="file-meta"><span class="file-meta-key">Şüpheli</span><span>' + displayName(file.suspectName, file.suspectCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Suçlar</span><span class="file-charges-text">' + chargeNames + '</span></div>' +
                notesRow +
                '<div class="file-meta"><span class="file-meta-key">Açılış</span><span>' + (file.createdAt || '-') + '</span></div>' +
                pendingRow +
            '</div>';
        // View detail button — all cards
        var viewBtn = document.createElement('button');
        viewBtn.type = 'button';
        viewBtn.className = 'btn-secondary file-indictment-btn';
        viewBtn.textContent = 'Dosyayı İncele →';
        (function(fid) {
            viewBtn.addEventListener('click', function() { openFileDetail(fid, 'files'); });
        }(file.id));
        card.appendChild(viewBtn);

        var eligibleIndictment = ['opened', 'awaiting_prosecutor', 'prosecutor_review'];
        if (currentJob === 'prosecutor' && eligibleIndictment.indexOf(file.status) !== -1) {
            var btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'btn-secondary file-indictment-btn';
            btn.textContent = 'İddianame Hazırla →';
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
            acceptTrigger.innerHTML = '<button class="btn-primary accept-case-open-btn" data-id="' + file.id + '">Duruşma Planla →</button>';
            card.appendChild(acceptTrigger);
            // Inline scheduling form (hidden)
            var acceptPanel = document.createElement('div');
            acceptPanel.className = 'approval-reject-panel hidden';
            acceptPanel.id = 'accept-panel-' + file.id;
            acceptPanel.innerHTML =
                '<div class="form-group" style="margin-bottom:10px;">' +
                    '<label style="font-size:12px;color:#a8b0c8;text-transform:uppercase;letter-spacing:.4px;display:block;margin-bottom:6px;">Duruşma Tarihi & Saati</label>' +
                    '<input type="datetime-local" class="reject-reason-input accept-datetime" id="accept-dt-' + file.id + '" style="width:100%;padding:8px 10px;">' +
                '</div>' +
                '<div class="form-group" style="margin-bottom:10px;">' +
                    '<label style="font-size:12px;color:#a8b0c8;text-transform:uppercase;letter-spacing:.4px;display:block;margin-bottom:6px;">Tür</label>' +
                    '<select class="reject-reason-input accept-type" id="accept-type-' + file.id + '" style="width:100%;padding:8px 10px;">' +
                        '<option value="physical">Fiziksel Duruşma</option>' +
                        '<option value="written">Yazılı Yargılama</option>' +
                    '</select>' +
                '</div>' +
                '<div class="form-group" style="margin-bottom:10px;">' +
                    '<textarea class="reject-reason-input accept-notes" id="accept-notes-' + file.id + '" rows="2" maxlength="300" placeholder="Hakim notu (isteğe bağlı)…"></textarea>' +
                '</div>' +
                '<div class="form-actions" style="margin-top:8px;">' +
                    '<button class="btn-primary accept-case-confirm-btn" data-id="' + file.id + '">Duruşmayı Kaydet</button>' +
                    '<button class="btn-secondary accept-case-cancel-btn" data-id="' + file.id + '">İptal</button>' +
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
            if (!dtVal) { alert('Lütfen duruşma tarihini seçin.'); return; }
            btn.disabled = true; btn.textContent = 'Kaydediliyor...';
            fetch('https://mclaw/judge:acceptCase', {
                method: 'POST',
                body: JSON.stringify({ fileId: fid, scheduledAt: dtVal, hearingType: typeVal, notes: notes }),
            }).then(function(res) { return res.json(); }).then(function(result) {
                if (result && result.ok) {
                    var card = btn.closest('.file-card');
                    var badge = card && card.querySelector('.file-status');
                    if (badge) { badge.className = 'file-status status-green'; badge.textContent = 'Duruşma Planlandı'; }
                    var panel = document.getElementById('accept-panel-' + fid);
                    if (panel) { panel.remove(); }
                    var trigger = document.getElementById('accept-trigger-' + fid);
                    if (trigger) { trigger.remove(); }
                } else {
                    btn.disabled = false; btn.textContent = 'Duruşmayı Kaydet';
                }
            }).catch(function() { btn.disabled = false; btn.textContent = 'Duruşmayı Kaydet'; });
        });
    });
}

// -- Indictment form

function populateIndictmentFileSelect() {
    var sel = document.getElementById('indictment-file');
    sel.innerHTML = '<option value="">-- Dosya secin --</option>';
    var eligible = ['opened', 'awaiting_prosecutor', 'prosecutor_review'];
    prosecutorFiles.forEach(function(file) {
        if (eligible.indexOf(file.status) !== -1) {
            var opt = document.createElement('option');
            opt.value = file.id;
            opt.textContent = file.fileNumber + ' -- ' + file.suspectCid;
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
    if (!fileId) { showIndictmentError('Lutfen bir dosya secin.'); return; }
    var hearingTypeEl = document.querySelector('input[name="hearing-type"]:checked');
    if (!hearingTypeEl) { showIndictmentError('Yargilama turu secin.'); return; }
    var notes = document.getElementById('indictment-notes').value.trim();
    var submitBtn = document.querySelector('#indictment-form .btn-primary');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Gonderiliyor...';
    fetch('https://mclaw/prosecutor:submitIndictment', {
        method: 'POST',
        body: JSON.stringify({ fileId: parseInt(fileId, 10), hearingType: hearingTypeEl.value, notes: notes }),
    }).then(function(res) { return res.json(); }).then(function(result) {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Iddianameyi Gonder';
        if (result && result.ok) {
            document.getElementById('indictment-form').reset();
            hideIndictmentError();
        } else {
            showIndictmentError(result && result.error ? result.error : 'Gonderme basarisiz.');
        }
    }).catch(function() {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Iddianameyi Gonder';
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
    if (!suspectCid) { errEl.textContent = 'Şüpheli kimlik numarası girilmedi.'; errEl.classList.remove('hidden'); return; }
    var selectedCodes = [];
    document.querySelectorAll('#fileopening-charges input[type="checkbox"]:checked').forEach(function(cb) {
        selectedCodes.push({ code: cb.value });
    });
    if (selectedCodes.length === 0) { errEl.textContent = 'En az bir suç seçin.'; errEl.classList.remove('hidden'); return; }
    var narrative = document.getElementById('fileopening-narrative').value.trim();
    if (narrative.length < 10) { errEl.textContent = 'Gerekçe en az 10 karakter olmalıdır.'; errEl.classList.remove('hidden'); return; }
    var notes = document.getElementById('fileopening-notes').value.trim();
    var submitBtn = document.getElementById('fileopening-submit');
    submitBtn.disabled = true; submitBtn.textContent = 'Gönderiliyor...';
    fetch('https://mclaw/fileopening:openFile', {
        method: 'POST',
        body: JSON.stringify({ suspectCid: suspectCid, charges: selectedCodes, narrative: narrative, notes: notes }),
    }).then(function(res) { return res.json(); }).then(function(result) {
        submitBtn.disabled = false; submitBtn.textContent = 'Dosyayı Oluştur';
        if (result && result.ok) {
            document.getElementById('fileopening-form').reset();
            document.getElementById('fileopening-narrative-count').textContent = '0';
            document.querySelectorAll('#fileopening-charges .charge-item').forEach(function(i) { i.classList.remove('checked'); });
        } else {
            errEl.textContent = result && result.error ? result.error : 'Gönderme başarısız.';
            errEl.classList.remove('hidden');
        }
    }).catch(function() {
        submitBtn.disabled = false; submitBtn.textContent = 'Dosyayı Oluştur';
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
                  '<span class="file-meta-key">Açılış Gerekçesi</span>' +
                  '<span style="font-size:12px;color:#c0c8de;line-height:1.5;white-space:pre-wrap;">' + file.narrative + '</span>' +
              '</div>'
            : '';
        var internalNoteRow = file.notes
            ? '<div class="file-meta" style="flex-direction:column;gap:4px;margin-top:4px;">' +
                  '<span class="file-meta-key">Dahili Not</span>' +
                  '<span style="font-size:12px;color:#8a93a8;white-space:pre-wrap;">' + file.notes + '</span>' +
              '</div>'
            : '';
        var JOB_LABELS = { prosecutor: 'Savcı', lawyer: 'Avukat', judge: 'Hakim' };
        var card = document.createElement('div');
        card.className = 'file-card';
        card.innerHTML =
            '<div class="file-card-header">' +
                '<span class="file-number">' + file.fileNumber + '</span>' +
                '<span class="file-status status-yellow">Onay Bekliyor</span>' +
            '</div>' +
            '<div class="file-card-body">' +
                '<div class="file-meta"><span class="file-meta-key">Şüpheli</span><span>' + displayName(file.suspectName, file.suspectCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Açan</span><span>' + (JOB_LABELS[file.openedByJob] || file.openedByJob || '?') + ' — ' + displayName(file.openedByName, file.openedBy) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Açılış</span><span>' + (file.createdAt || '-') + '</span></div>' +
                '<div class="file-meta" style="flex-direction:column;gap:4px;margin-top:6px;padding-top:6px;border-top:1px solid #2e3650;">' +
                    '<span class="file-meta-key">Suçlar</span>' +
                    chargeRows +
                '</div>' +
                narrativeRow +
                internalNoteRow +
            '</div>' +
            '<div class="approval-actions" id="approval-actions-' + file.id + '">' +
                '<button class="btn-primary approval-approve-btn" data-id="' + file.id + '">Onayla</button>' +
                '<button class="btn-danger approval-reject-btn" data-id="' + file.id + '">Reddet</button>' +
                '<button class="btn-secondary approval-view-btn" data-id="' + file.id + '" style="margin-left:auto;">İncele →</button>' +
            '</div>' +
            '<div class="approval-reject-panel hidden" id="reject-panel-' + file.id + '">' +
                '<textarea class="reject-reason-input" id="reject-reason-' + file.id + '" rows="2" maxlength="300" placeholder="Ret gerekçesi (isteğe bağlı)…"></textarea>' +
                '<div class="form-actions" style="margin-top:8px;">' +
                    '<button class="btn-danger approval-reject-confirm-btn" data-id="' + file.id + '">Reddi Onayla</button>' +
                    '<button class="btn-secondary approval-reject-cancel-btn" data-id="' + file.id + '">İptal</button>' +
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
            btn.disabled = true; btn.textContent = 'Onaylanıyor...';
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
                    btn.disabled = false; btn.textContent = 'Onayla';
                }
            }).catch(function() { btn.disabled = false; btn.textContent = 'Onayla'; });
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
            btn.disabled = true; btn.textContent = 'Reddediliyor...';
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
                    btn.disabled = false; btn.textContent = 'Reddi Onayla';
                }
            }).catch(function() { btn.disabled = false; btn.textContent = 'Reddi Onayla'; });
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

var JOB_TR = { prosecutor: 'Savcı', judge: 'Hakim', lawyer: 'Avukat', police: 'Polis' };

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

    // ── Taraflar
    var parties = mkSection('Taraflar');
    var pb = parties.querySelector('.detail-section-body');
    pb.innerHTML =
        mkRow('Davacı',   '<span style="color:#c9a84c;font-weight:600;">Devlet (Savcılık)</span>') +
        mkRow('Davalı',   displayName(file.suspectName,    file.suspectCid)) +
        mkRow('Savcı',    displayName(file.prosecutorName, file.prosecutorCid)) +
        mkRow('Hakim',    displayName(file.judgeName,      file.judgeCid)) +
        mkRow('Açılış',   file.createdAt || '—') +
        (file.closedAt ? mkRow('Kapanış', '<span style="color:#ea4335;">' + file.closedAt + '</span>') : '') +
        (file.openedBy ? mkRow('Açan', (JOB_TR[file.openedByJob] || file.openedByJob || '?') + ' — ' + displayName(file.openedByName, file.openedBy)) : '');
    body.appendChild(parties);

    // ── Suçlar
    var chargesSection = mkSection('Suçlar');
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

    // ── Açılış gerekçesi
    if (file.narrative) {
        var narSection = mkSection('Açılış Gerekçesi');
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

    // ── Duruşma
    if (file.hearing) {
        var h = file.hearing;
        var hearSection = mkSection('Duruşma');
        var hb = hearSection.querySelector('.detail-section-body');
        hb.innerHTML =
            mkRow('Tür',    h.hearingType === 'written' ? 'Yazılı Yargılama' : 'Fiziksel Duruşma') +
            mkRow('Tarih',  '<span style="color:#c9a84c;font-weight:600;">' + (h.scheduledAt || '—') + '</span>') +
            mkRow('Durum',  HEARING_STATUS_LABELS[h.status] || h.status) +
            (h.notes ? mkRow('Not', h.notes) : '');
        body.appendChild(hearSection);
    }

    // ── Dahili not
    if (file.notes) {
        var noteSection = mkSection('Dahili Not');
        var noteSB = noteSection.querySelector('.detail-section-body');
        noteSB.style.padding = '0';
        var noteEl2 = document.createElement('div');
        noteEl2.className = 'detail-narrative';
        noteEl2.textContent = file.notes;
        noteSB.appendChild(noteEl2);
        body.appendChild(noteSection);
    }

    // ── Duruşma Planla (hakim, indictment_ready veya hearing_scheduled yeni tur için)
    if (currentJob === 'judge' && file.status === 'indictment_ready') {
        var hearingSection = mkSection('Duruşma Planla');
        var hb2 = hearingSection.querySelector('.detail-section-body');
        hb2.style.padding = '0';
        var hForm = document.createElement('div');
        hForm.className = 'add-doc-form';
        hForm.id = 'detail-hearing-form-' + file.id;
        hForm.innerHTML =
            '<div style="display:flex;gap:10px;">' +
                '<div style="flex:1;">' +
                    '<label style="font-size:11px;color:#a8b0c8;text-transform:uppercase;letter-spacing:.4px;display:block;margin-bottom:5px;">Tarih & Saat</label>' +
                    '<input type="datetime-local" id="dh-dt-' + file.id + '" style="width:100%;padding:8px 10px;">' +
                '</div>' +
                '<div style="flex:1;">' +
                    '<label style="font-size:11px;color:#a8b0c8;text-transform:uppercase;letter-spacing:.4px;display:block;margin-bottom:5px;">Tür</label>' +
                    '<select id="dh-type-' + file.id + '" style="width:100%;padding:8px 10px;">' +
                        '<option value="physical">Fiziksel Duruşma</option>' +
                        '<option value="written">Yazılı Yargılama</option>' +
                    '</select>' +
                '</div>' +
            '</div>' +
            '<textarea id="dh-notes-' + file.id + '" rows="2" maxlength="300" placeholder="Not (isteğe bağlı)…"></textarea>' +
            '<div id="dh-error-' + file.id + '" class="form-error hidden"></div>' +
            '<div><button class="btn-primary dh-submit" data-id="' + file.id + '" style="font-size:12px;padding:8px 20px;">Duruşmayı Kaydet</button></div>';
        hb2.appendChild(hForm);
        body.appendChild(hearingSection);

        hForm.querySelector('.dh-submit').addEventListener('click', function() {
            var fid    = parseInt(file.id, 10);
            var dtVal  = document.getElementById('dh-dt-' + fid).value;
            var type   = document.getElementById('dh-type-' + fid).value;
            var notes  = document.getElementById('dh-notes-' + fid).value.trim();
            var errEl  = document.getElementById('dh-error-' + fid);
            errEl.classList.add('hidden');
            if (!dtVal) { errEl.textContent = 'Lütfen tarih seçin.'; errEl.classList.remove('hidden'); return; }
            var btn = hForm.querySelector('.dh-submit');
            btn.disabled = true; btn.textContent = 'Kaydediliyor...';
            fetch('https://mclaw/judge:acceptCase', {
                method: 'POST',
                body: JSON.stringify({ fileId: fid, scheduledAt: dtVal, hearingType: type, notes: notes }),
            }).then(function(r) { return r.json(); }).then(function(result) {
                if (result && result.ok) {
                    // Güncelle: status rozeti + formu kaldır
                    var badge = document.getElementById('filedetail-status');
                    if (badge) { badge.className = 'file-status status-green'; badge.textContent = 'Duruşma Planlandı'; }
                    hearingSection.remove();
                    // Duruşma bölümünü ekle
                    var typeLabel2 = type === 'written' ? 'Yazılı Yargılama' : 'Fiziksel Duruşma';
                    var dtFormatted = dtVal.replace('T', ' ');
                    var newHearSec = mkSection('Duruşma');
                    var nhb = newHearSec.querySelector('.detail-section-body');
                    nhb.innerHTML =
                        mkRow('Tür', typeLabel2) +
                        mkRow('Tarih', '<span style="color:#c9a84c;font-weight:600;">' + dtFormatted + '</span>') +
                        mkRow('Durum', 'Planlandı') +
                        (notes ? mkRow('Not', notes) : '');
                    // Suçlar bölümünden sonraya ekle
                    var chargesSec = body.querySelector('.detail-section:nth-child(2)');
                    if (chargesSec && chargesSec.nextSibling) {
                        body.insertBefore(newHearSec, chargesSec.nextSibling);
                    } else {
                        body.appendChild(newHearSec);
                    }
                } else {
                    btn.disabled = false; btn.textContent = 'Duruşmayı Kaydet';
                    errEl.textContent = 'Kaydetme başarısız.'; errEl.classList.remove('hidden');
                }
            }).catch(function() { btn.disabled = false; btn.textContent = 'Duruşmayı Kaydet'; });
        });
    }

    // ── Evraklar
    var docsSection = mkSection('Evraklar');
    var docsBody = docsSection.querySelector('.detail-section-body');
    docsBody.style.padding = '0';
    docsBody.style.gap = '0';
    docsBody.id = 'filedetail-docs-body-' + file.id;
    if ((file.documents || []).length === 0) {
        var noDoc = document.createElement('div');
        noDoc.style.cssText = 'padding:16px;font-size:13px;color:#3a4258;text-align:center;';
        noDoc.id = 'filedetail-no-doc-' + file.id;
        noDoc.textContent = 'Henüz evrak eklenmemiş.';
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
        formDivider.textContent = 'Evrak Ekle';
        docsBody.appendChild(formDivider);

        var formEl = document.createElement('div');
        formEl.className = 'add-doc-form';

        var typeOpts = docTypes.map(function(t) { return '<option value="' + t.value + '">' + t.label + '</option>'; }).join('');
        formEl.innerHTML =
            '<select id="adoc-type-' + file.id + '">' + typeOpts + '</select>' +
            '<input type="text" id="adoc-title-' + file.id + '" maxlength="128" placeholder="Başlık…">' +
            '<textarea id="adoc-content-' + file.id + '" rows="5" maxlength="3000" placeholder="İçerik…"></textarea>' +
            '<div id="adoc-error-' + file.id + '" class="form-error hidden"></div>' +
            '<div><button class="btn-primary adoc-submit" data-id="' + file.id + '" style="font-size:12px;padding:8px 20px;">Ekle</button></div>';
        docsBody.appendChild(formEl);
    }

    body.appendChild(docsSection);

    // ── Geçmiş
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
            if (title.length < 2) { errEl.textContent = 'Başlık çok kısa.'; errEl.classList.remove('hidden'); return; }
            if (cont.length < 5)  { errEl.textContent = 'İçerik çok kısa.'; errEl.classList.remove('hidden'); return; }
            btn.disabled = true; btn.textContent = 'Ekleniyor...';
            fetch('https://mclaw/file:addDocument', {
                method: 'POST',
                body: JSON.stringify({ fileId: fid, docType: dtype, title: title, content: cont }),
            }).then(function(res) { return res.json(); }).then(function(result) {
                btn.disabled = false; btn.textContent = 'Ekle';
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
                    errEl.textContent = 'Eklenemedi.';
                    errEl.classList.remove('hidden');
                }
            }).catch(function() { btn.disabled = false; btn.textContent = 'Ekle'; });
        });
    });
}

// ── Dosya geçmişi (sahafat)
function renderHistory(histItems) {
    var HIST_ICONS = {
        'opened':          '📂',
        'approved':        '✅',
        'rejected':        '❌',
        'document':        '📄',
        'hearing_created': '📅',
    };
    var HIST_LABELS = {
        'opened':          'Dosya Açıldı',
        'approved':        'Dosya Onaylandı',
        'rejected':        'Dosya Reddedildi',
        'document':        'Evrak Eklendi',
        'hearing_created': 'Duruşma Planlandı',
    };
    var sec = mkSection('Dosya Geçmişi');
    var sb = sec.querySelector('.detail-section-body');
    sb.style.padding = '0';
    sb.style.gap = '0';
    if (!histItems || histItems.length === 0) {
        sb.innerHTML = '<div style="padding:16px;font-size:13px;color:#3a4258;text-align:center;">Geçmiş kaydı yok.</div>';
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
            var htLabel = item.hearingType === 'written' ? 'Yazılı Yargılama' : 'Fiziksel Duruşma';
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

// ── Evrak görüntüleme modali
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
        '     T.C. mcLaw Yargı Sistemi',
        '     Dosya No: ' + (document.getElementById('doc-modal-fileno').textContent || ''),
        '════════════════════════════════════════',
        'Belge Türü : ' + (document.getElementById('doc-modal-type').textContent   || ''),
        'Başlık     : ' + (document.getElementById('doc-modal-title').textContent  || ''),
        'Tarih      : ' + (document.getElementById('doc-modal-date').textContent   || ''),
        'Yazar      : ' + (document.getElementById('doc-modal-author').textContent || ''),
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
        document.getElementById('doc-modal-print').textContent = '✓ Panoya Kopyalandı';
        setTimeout(function() {
            document.getElementById('doc-modal-print').textContent = '📋 Panoya Kopyala';
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
            '<button class="btn-secondary doc-view-btn" style="font-size:11px;padding:4px 10px;margin-left:8px;flex-shrink:0;">Görüntüle</button>' +
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
    btn.disabled = true; btn.textContent = 'Kapatılıyor...';
    fetch('https://mclaw/judge:closeFile', {
        method: 'POST',
        body: JSON.stringify({ fileId: fid, reason: reason }),
    }).then(function(res) { return res.json(); }).then(function(result) {
        btn.disabled = false; btn.textContent = 'Dosyayı Kapat';
        if (result && result.ok) {
            document.getElementById('filedetail-close-panel').classList.add('hidden');
            var badge = document.getElementById('filedetail-status');
            badge.className = 'file-status status-gray';
            badge.textContent = 'Kapatıldı';
        }
    }).catch(function() { btn.disabled = false; btn.textContent = 'Dosyayı Kapat'; });
});

// -- Petition system

var PETITION_TYPE_LABELS   = { criminal: 'Ceza Davası', civil: 'Hukuk Davası' };
var PETITION_STATUS_LABELS = { pending: 'Bekliyor', accepted: 'Kabul Edildi', rejected: 'Reddedildi' };
var PETITION_STATUS_COLORS = { pending: 'status-yellow', accepted: 'status-green', rejected: 'status-red' };

function buildAttachmentsHtml(attachments) {
    if (!attachments || attachments.length === 0) return '';
    var rows = attachments.map(function(att) {
        return '<div style="display:flex;align-items:center;gap:8px;padding:4px 0;">' +
            '<span style="font-size:12px;color:#c0c8de;flex:1;">' + escHtml(att.label || 'Ek') + '</span>' +
            '<button class="btn-secondary att-copy-btn" data-url="' + escHtml(att.url) + '" style="font-size:11px;padding:3px 10px;flex-shrink:0;">Linki Kopyala</button>' +
        '</div>';
    }).join('');
    return '<div class="file-meta" style="flex-direction:column;gap:2px;margin-top:6px;padding-top:6px;border-top:1px solid #2e3650;">' +
        '<span class="file-meta-key">Ekler</span>' +
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
                btn.textContent = '✓ Kopyalandı';
                setTimeout(function() { btn.textContent = 'Linki Kopyala'; }, 2000);
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

// Ceza/hukuk radio → suç listesini göster/gizle
document.querySelectorAll('input[name="petition-type"]').forEach(function(radio) {
    radio.addEventListener('change', function() {
        var grp = document.getElementById('petition-charges-group');
        if (grp) grp.style.display = radio.value === 'criminal' ? '' : 'none';
    });
});

// Ek ekleme
document.getElementById('petition-add-attachment').addEventListener('click', function() {
    var container = document.getElementById('petition-attachments');
    var row = document.createElement('div');
    row.className = 'attachment-row';
    row.style.cssText = 'display:flex;gap:8px;margin-bottom:6px;align-items:center;';
    row.innerHTML =
        '<input type="text" class="att-label" maxlength="64" placeholder="Etiket (ör: Fotoğraf 1)" style="flex:1;padding:7px 10px;">' +
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

    if (!plaintiff) { errEl.textContent = 'Müvekkil kimlik numarası girilmedi.'; errEl.classList.remove('hidden'); return; }
    if (!subject)   { errEl.textContent = 'Konu boş olamaz.'; errEl.classList.remove('hidden'); return; }
    if (desc.length < 10) { errEl.textContent = 'Dilekçe içeriği en az 10 karakter olmalıdır.'; errEl.classList.remove('hidden'); return; }

    var charges = [];
    if (petType === 'criminal') {
        document.querySelectorAll('#petition-charges input[type="checkbox"]:checked').forEach(function(cb) {
            charges.push({ code: cb.value });
        });
        if (charges.length === 0) { errEl.textContent = 'Ceza davası için en az bir suç seçin.'; errEl.classList.remove('hidden'); return; }
    }

    var attachments = [];
    document.querySelectorAll('#petition-attachments .attachment-row').forEach(function(row) {
        var label = row.querySelector('.att-label').value.trim();
        var url   = row.querySelector('.att-url').value.trim();
        if (url) attachments.push({ label: label || 'Ek', url: url });
    });

    var submitBtn = document.getElementById('petition-submit');
    submitBtn.disabled = true; submitBtn.textContent = 'Gönderiliyor...';
    fetch('https://mclaw/lawyer:sendPetition', {
        method: 'POST',
        body: JSON.stringify({ petitionType: petType, plaintiffCid: plaintiff, charges: charges, subject: subject, description: desc, attachments: attachments }),
    }).then(function(r) { return r.json(); }).then(function(result) {
        submitBtn.disabled = false; submitBtn.textContent = 'Dilekçeyi Gönder';
        if (result && result.ok) {
            document.getElementById('petition-form').reset();
            document.getElementById('petition-desc-count').textContent = '0';
            document.getElementById('petition-attachments').innerHTML = '';
            document.querySelectorAll('#petition-charges .charge-item').forEach(function(i) { i.classList.remove('checked'); });
        } else {
            errEl.textContent = result && result.error ? result.error : 'Gönderme başarısız.';
            errEl.classList.remove('hidden');
        }
    }).catch(function() { submitBtn.disabled = false; submitBtn.textContent = 'Dilekçeyi Gönder'; });
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
                  '<span class="file-meta-key" style="color:#ea4335;">Ret Gerekçesi</span>' +
                  '<span style="font-size:12px;color:#c0c8de;">' + escHtml(p.rejectReason) + '</span>' +
              '</div>'
            : '';
        card.innerHTML =
            '<div class="file-card-header">' +
                '<span class="file-number">' + typeLabel + '</span>' +
                '<span class="file-status ' + statusClass + '">' + statusLabel + '</span>' +
            '</div>' +
            '<div class="file-card-body">' +
                '<div class="file-meta"><span class="file-meta-key">Müvekkil</span><span>' + displayName(p.plaintiffName, p.plaintiffCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Konu</span><span>' + escHtml(p.subject) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Gönderildi</span><span>' + (p.createdAt || '—') + '</span></div>' +
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
                  '<span class="file-meta-key">Suçlar</span>' + chargeRows +
              '</div>'
            : '';
        card.innerHTML =
            '<div class="file-card-header">' +
                '<span class="file-number">' + typeLabel + '</span>' +
                '<span class="file-status status-yellow">Bekliyor</span>' +
            '</div>' +
            '<div class="file-card-body">' +
                '<div class="file-meta"><span class="file-meta-key">Avukat</span><span>' + displayName(p.attorneyName, p.attorneyCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Müvekkil</span><span>' + displayName(p.plaintiffName, p.plaintiffCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Konu</span><span>' + escHtml(p.subject) + '</span></div>' +
                '<div class="file-meta" style="flex-direction:column;gap:4px;margin-top:4px;">' +
                    '<span class="file-meta-key">Dilekçe</span>' +
                    '<span style="font-size:12px;color:#c0c8de;white-space:pre-wrap;">' + escHtml(p.description) + '</span>' +
                '</div>' +
                chargesSection +
                '<div class="file-meta"><span class="file-meta-key">Tarih</span><span>' + (p.createdAt || '—') + '</span></div>' +
                buildAttachmentsHtml(p.attachments) +
            '</div>' +
            '<div class="approval-actions" id="inpet-actions-' + p.id + '">' +
                '<button class="btn-primary inpet-accept-btn" data-id="' + p.id + '">Kabul Et</button>' +
                '<button class="btn-danger inpet-reject-btn" data-id="' + p.id + '">Reddet</button>' +
            '</div>' +
            '<div class="approval-reject-panel hidden" id="inpet-reject-panel-' + p.id + '">' +
                '<textarea class="reject-reason-input" id="inpet-reason-' + p.id + '" rows="2" maxlength="300" placeholder="Ret gerekçesi (isteğe bağlı)…"></textarea>' +
                '<div class="form-actions" style="margin-top:8px;">' +
                    '<button class="btn-danger inpet-reject-confirm-btn" data-id="' + p.id + '" data-type="' + p.petitionType + '">Reddi Onayla</button>' +
                    '<button class="btn-secondary inpet-reject-cancel-btn" data-id="' + p.id + '">İptal</button>' +
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
            btn.disabled = true; btn.textContent = 'İşleniyor...';
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
                    btn.disabled = false; btn.textContent = 'Kabul Et';
                }
            }).catch(function() { btn.disabled = false; btn.textContent = 'Kabul Et'; });
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
            btn.disabled = true; btn.textContent = 'Reddediliyor...';
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
                    btn.disabled = false; btn.textContent = 'Reddi Onayla';
                }
            }).catch(function() { btn.disabled = false; btn.textContent = 'Reddi Onayla'; });
        });
    });
}

// -- Hearings tab

var HEARING_TYPE_LABELS = { 'physical': 'Fiziksel Duruşma', 'written': 'Yazılı Yargılama' };
var HEARING_STATUS_LABELS = { 'scheduled': 'Planlandı', 'active': 'Aktif', 'completed': 'Tamamlandı', 'cancelled': 'İptal' };
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
        var notesRow = h.notes ? '<div class="file-meta"><span class="file-meta-key">Not</span><span class="file-charges-text">' + h.notes + '</span></div>' : '';
        card.innerHTML =
            '<div class="file-card-header">' +
                '<span class="file-number">' + h.fileNumber + '</span>' +
                '<span class="file-status ' + statusClass + '">' + statusLabel + '</span>' +
            '</div>' +
            '<div class="file-card-body">' +
                '<div class="file-meta"><span class="file-meta-key">Şüpheli</span><span>' + displayName(h.suspectName, h.suspectCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Savcı</span><span>' + displayName(h.prosecutorName, h.prosecutorCid) + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Tür</span><span>' + typeLabel + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Tarih</span><span style="color:#c9a84c;font-weight:600;">' + (h.scheduledAt || '—') + '</span></div>' +
                notesRow +
            '</div>';
        var hViewBtn = document.createElement('button');
        hViewBtn.type = 'button';
        hViewBtn.className = 'btn-secondary file-indictment-btn';
        hViewBtn.textContent = 'Dosyayı İncele →';
        (function(fid) {
            hViewBtn.addEventListener('click', function() { openFileDetail(fid, 'hearings'); });
        }(h.fileId));
        card.appendChild(hViewBtn);
        listEl.appendChild(card);
    });
}

// -- NUI message handler

window.addEventListener('message', function(event) {
    var data = event.data;
    if (data.action === 'show') {
        currentJob          = data.job || 'civilian';
        nearbyPlayers       = data.nearbyPlayers       || [];
        chargeList          = data.chargeList          || [];
        prosecutorFiles     = data.prosecutorFiles     || [];
        fileOpenChargeList  = data.fileOpenChargeList  || [];
        pendingApprovals    = data.pendingApprovals    || [];
        hearingList         = data.hearingList         || [];
        docTypeList         = data.docTypeList         || [];
        myPetitions         = data.myPetitions         || [];
        incomingPetitions   = data.incomingPetitions   || [];
        filterTabsForJob(currentJob);
        document.getElementById('user-job').textContent = currentJob;
        if (data.dashStats) {
            var af = document.getElementById('stat-active-files');
            var pn = document.getElementById('stat-pending');
            if (af) af.textContent = data.dashStats.activeFiles != null ? data.dashStats.activeFiles : '—';
            if (pn) pn.textContent = data.dashStats.pendingCount != null ? data.dashStats.pendingCount : '—';
        }
        if (currentJob === 'police') { populateReferralForm(); }
        if (currentJob === 'prosecutor' || currentJob === 'judge') { renderFilesList(); }
        if (currentJob === 'prosecutor') { populateIndictmentFileSelect(); }
        if (fileOpenChargeList.length > 0) { populateFileOpenCharges(); showFileOpeningNote(currentJob); }
        if (currentJob === 'judge') { renderPendingApprovals(); }
        if (currentJob === 'judge' || currentJob === 'lawyer') { renderHearingList(); }
        if (currentJob === 'lawyer') { populatePetitionCharges(); renderMyPetitions(); }
        if (currentJob === 'prosecutor' || currentJob === 'judge') { renderIncomingPetitions(); }
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
        if (data.myPetitions !== undefined) {
            myPetitions = data.myPetitions;
            renderMyPetitions();
        }
        if (data.incomingPetitions !== undefined) {
            incomingPetitions = data.incomingPetitions;
            renderIncomingPetitions();
        }
        if (data.nearbyPlayers !== undefined) {
            nearbyPlayers = data.nearbyPlayers;
            chargeList = data.chargeList || chargeList;
            populateReferralForm();
        }
    }
    if (data.action === 'hide') {
        document.getElementById('app').classList.add('hidden');
    }
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
