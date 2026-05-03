'use strict';

// -- State

var currentJob      = null;
var chargeList      = [];
var nearbyPlayers   = [];
var prosecutorFiles = [];

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

navButtons.forEach(function(btn) {
    btn.addEventListener('click', function() { activateTab(btn.getAttribute('data-page')); });
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
    'closed':               'Kapatildi',
    'archived':             'Arsivlendi',
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
        card.innerHTML =
            '<div class="file-card-header">' +
                '<span class="file-number">' + file.fileNumber + '</span>' +
                '<span class="file-status ' + statusClass + '">' + statusLabel + '</span>' +
            '</div>' +
            '<div class="file-card-body">' +
                '<div class="file-meta"><span class="file-meta-key">Supheli</span><span>' + file.suspectCid + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Suclar</span><span class="file-charges-text">' + chargeNames + '</span></div>' +
                '<div class="file-meta"><span class="file-meta-key">Acilis</span><span>' + (file.createdAt || '-') + '</span></div>' +
            '</div>';
        var eligible = ['opened', 'awaiting_prosecutor', 'prosecutor_review'];
        if (currentJob === 'prosecutor' && eligible.indexOf(file.status) !== -1) {
            var btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'btn-secondary file-indictment-btn';
            btn.textContent = 'Iddianame Hazirla ->';
            (function(fid) {
                btn.addEventListener('click', function() {
                    prefillIndictmentForm(fid);
                    activateTab('indictment');
                });
            }(file.id));
            card.appendChild(btn);
        }
        listEl.appendChild(card);
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

// -- NUI message handler

window.addEventListener('message', function(event) {
    var data = event.data;
    if (data.action === 'show') {
        currentJob      = data.job || 'civilian';
        nearbyPlayers   = data.nearbyPlayers   || [];
        chargeList      = data.chargeList      || [];
        prosecutorFiles = data.prosecutorFiles || [];
        filterTabsForJob(currentJob);
        document.getElementById('user-job').textContent = currentJob;
        if (currentJob === 'police') { populateReferralForm(); }
        if (currentJob === 'prosecutor' || currentJob === 'judge') { renderFilesList(); }
        if (currentJob === 'prosecutor') { populateIndictmentFileSelect(); }
        activateTab(data.activeTab || 'dashboard');
        document.getElementById('app').classList.remove('hidden');
    }
    if (data.action === 'hide') {
        document.getElementById('app').classList.add('hidden');
    }
});

// -- Close on ESC

document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        document.getElementById('app').classList.add('hidden');
        fetch('https://mclaw/close', { method: 'POST', body: JSON.stringify({}) });
    }
});
