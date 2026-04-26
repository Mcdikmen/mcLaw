const navButtons = document.querySelectorAll('.nav-btn');
const pages = document.querySelectorAll('.page');

navButtons.forEach(function(btn) {
    btn.addEventListener('click', function() {
        navButtons.forEach(function(b) { b.classList.remove('active'); });
        pages.forEach(function(p) { p.classList.remove('active'); });

        btn.classList.add('active');

        var pageName = btn.getAttribute('data-page');
        document.getElementById('page-' + pageName).classList.add('active');
    });
});

window.addEventListener('message', function(event) {
    var data = event.data;

    if (data.action === 'show') {
        document.getElementById('app').classList.remove('hidden');
    }

    if (data.action === 'hide') {
        document.getElementById('app').classList.add('hidden');
    }
});

document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        document.getElementById('app').classList.add('hidden');
        fetch('https://mclaw/close', {
            method: 'POST',
            body: JSON.stringify({})
        });
    }
});
