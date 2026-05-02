'use strict';

// ── State ──────────────────────────────────────────────────────────────────

var currentJob  = null;
var chargeList  = [];
var nearbyPlayers = [];

// ── Tab navigation ─────────────────────────────────────────────────────────

var navButtons = document.querySelectorAll('.nav-btn');
var pages      = document.querySelectorAll('.page');

function activateTab(pageName) {
    navButtons.forEach(function(b) { b.classList.remove('active'); });
    pages.forEach(function(p) { p.classList.remove('active'); });

    var btn  = document.querySelector('.nav-btn[data-page="' + pageName + '"]');
    var page = document.getElementById('page-' + pageName);

    if (btn && !btn.classList.contains('nav-hidden')) {
        btn.classList.add('active');
    }
    if (page) {
        page.classList.add('active');
    }
}

navButtons.forEach(function(btn) {
    btn.addEventListener('click', function() {
        activateTab(btn.getAttribute('data-page'));
    });
});

// ── Job-based tab filtering ────────────────────────────────────────────────

function filterTabsForJob(job) {
    navButtons.forEach(function(btn) {
        var allowed = btn.getAttribute('data-jobs');
        if (allowed === 'all') {
            btn.classList.remove('nav-hidden');
            return;
        }
        var jobs = allowed.split(',');
        if (jobs.indexOf(job) !== -1) {
            btn.classList.remove('nav-hidden');
        } else {
            btn.classList.add('nav-hidden');
            btn.classList.remove('active');
        }
    });
}

// nav-hidden: hide from sidebar but don't remove from DOM
var style = document.createElement('style');
style.textContent = '.nav-hidden { display: none !important; }';
document.head.appendChild(style);

// ── Referral form ──────────────────────────────────────────────────────────

function populateReferralForm() {
    var suspectSelect = document.getElementById('referral-suspect');
    suspectSelect.innerHTML = '<option value="">— Yakındaki oyuncu seçin —</option>';

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
        cb.addEventListener('change', function() {
            item.classList.toggle('checked', cb.checked);
        });

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

// Character counter for narrative
document.getElementById('referral-narrative').addEventListener('input', function() {
    document.getElementById('narrative-count').textContent = this.value.length;
});

// Reset button
document.getElementById('referral-reset').addEventListener('click', function() {
    document.getElementById('referral-form').reset();
    document.getElementById('narrative-count').textContent = '0';
    document.querySelectorAll('.charge-item').forEach(function(item) {
        item.classList.remove('checked');
    });
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
    if (!suspectSource) {
        showReferralError('Lütfen bir şüpheli seçin.');
        return;
    }

    var selectedCodes = [];
    document.querySelectorAll('#referral-charges input[type="checkbox"]:checked').forEach(function(cb) {
        selectedCodes.push({ code: cb.value });
    });
    if (selectedCodes.length === 0) {
        showReferralError('En az bir suç seçin.');
        return;
    }

    var narrative = document.getElementById('referral-narrative').value.trim();
    if (narrative.length < 10) {
        showReferralError('Olay anlatısı en az 10 karakter olmalı.');
        return;
    }

    var submitBtn = document.querySelector('#referral-form .btn-primary');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Gönderiliyor…';

    fetch('https://mclaw/referral:submit', {
        method: 'POST',
        body: JSON.stringify({
            suspectSource: parseInt(suspectSource, 10),
            charges:       selectedCodes,
            narrative:     narrative,
        }),
    }).then(function(res) { return res.json(); }).then(function(result) {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Raporu Gönder';
        if (result && result.ok) {
            document.getElementById('referral-form').reset();
            document.getElementById('narrative-count').textContent = '0';
            document.querySelectorAll('.charge-item').forEach(function(item) {
                item.classList.remove('checked');
            });
        } else {
            showReferralError(result && result.error ? result.error : 'Gönderme başarısız.');
        }
    }).catch(function() {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Raporu Gönder';
    });
});

// ── NUI message handler ────────────────────────────────────────────────────

window.addEventListener('message', function(event) {
    var data = event.data;

    if (data.action === 'show') {
        currentJob    = data.job || 'civilian';
        nearbyPlayers = data.nearbyPlayers || [];
        chargeList    = data.chargeList    || [];

        filterTabsForJob(currentJob);

        var jobLabel = document.getElementById('user-job');
        jobLabel.textContent = currentJob;

        // Populate referral form data now (police only needs it)
        if (currentJob === 'police') {
            populateReferralForm();
        }

        var startTab = data.activeTab || 'dashboard';
        activateTab(startTab);

        document.getElementById('app').classList.remove('hidden');
    }

    if (data.action === 'hide') {
        document.getElementById('app').classList.add('hidden');
    }
});

// ── Close on ESC ──────────────────────────────────────────────────────────

document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        document.getElementById('app').classList.add('hidden');
        fetch('https://mclaw/close', {
            method: 'POST',
            body: JSON.stringify({}),
        });
    }
});
