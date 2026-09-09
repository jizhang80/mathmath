// Prototype-only behaviour: URL-hash variant switching for state variants on one page.
// Usage: <div class="proto-bar" data-variants="default:Normal,bad:First failure">…</div>
//        <section data-variant="bad">…</section>   (sections with no data-variant always show)
// Also: [data-show-dialog="#id"] toggles a dialog; [data-goto] navigates on click.
(function () {
  function activate(name) {
    var all = document.querySelectorAll('[data-variant]');
    for (var i = 0; i < all.length; i++) {
      var names = all[i].getAttribute('data-variant').split(/\s+/);
      all[i].classList.toggle('is-active', names.indexOf(name) >= 0);
    }
    var btns = document.querySelectorAll('.proto-bar .variants button');
    for (var j = 0; j < btns.length; j++) btns[j].setAttribute('aria-pressed', btns[j].dataset.name === name ? 'true' : 'false');
  }
  function init() {
    var bar = document.querySelector('.proto-bar');
    var variants = bar && bar.getAttribute('data-variants');
    if (variants) {
      var host = document.createElement('span'); host.className = 'variants';
      var list = variants.split(',').map(function (s) { var p = s.split(':'); return { name: p[0].trim(), label: (p[1] || p[0]).trim() }; });
      list.forEach(function (v) {
        var b = document.createElement('button'); b.textContent = v.label; b.dataset.name = v.name;
        b.onclick = function () { location.hash = v.name; };
        host.appendChild(b);
      });
      bar.appendChild(host);
      var pick = function () { var h = location.hash.replace('#', ''); activate(list.some(function (v) { return v.name === h; }) ? h : list[0].name); };
      window.addEventListener('hashchange', pick); pick();
    }
    document.addEventListener('click', function (e) {
      var t = e.target.closest('[data-show-dialog]');
      if (t) { e.preventDefault(); var d = document.querySelector(t.getAttribute('data-show-dialog')); if (d) d.hidden = !d.hidden; }
      var c = e.target.closest('[data-close-dialog]');
      if (c) { e.preventDefault(); c.closest('.dialog-backdrop').hidden = true; }
      var ch = e.target.closest('.choice');
      if (ch) { var group = ch.closest('.choices'); if (group) { group.querySelectorAll('.choice').forEach(function (x) { x.classList.remove('is-selected'); }); ch.classList.add('is-selected'); var r = ch.querySelector('input'); if (r) r.checked = true; } }
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
