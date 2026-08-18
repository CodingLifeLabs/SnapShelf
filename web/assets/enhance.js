// SnapShelf landing enhancement — scroll-triggered reveals with a tiny
// IntersectionObserver, plus latest-release link resolution. Progressive
// only: the page is complete without JS.
(function () {
  "use strict";

  var REPO = "CodingLifeLabs/SnapShelf";

  // Latest release DMG: point download CTAs at GitHub Releases (latest).
  // Falls back silently to the anchor's existing href on any failure.
  fetch("https://api.github.com/repos/" + REPO + "/releases/latest")
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (release) {
      if (!release || !release.assets) return;
      var dmg = release.assets.find(function (a) { return /\.dmg$/i.test(a.name); });
      if (!dmg) return;
      // Hero/header CTAs link to #download; the final button already targets
      // releases/latest — rewrite every download-intent anchor to the DMG asset.
      document.querySelectorAll('a[href="#download"], a.btn-lg[href*="releases"]').forEach(function (a) {
        a.setAttribute("href", dmg.browser_download_url);
        a.removeAttribute("download");
      });
      var note = document.querySelector(".download-note");
      if (note) { note.textContent = release.tag_name + " · " + new Date(release.published_at).toLocaleDateString("en-US", { month: "long", year: "numeric" }); }
    })
    .catch(function () { /* keep fallback href */ });

  var prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (prefersReduced || !("IntersectionObserver" in window)) return;

  var style = document.createElement("style");
  style.textContent =
    ".reveal { opacity: 0; transform: translateY(18px); }" +
    ".reveal.is-in { opacity: 1; transform: none; transition: opacity .6s cubic-bezier(.16,1,.3,1), transform .6s cubic-bezier(.16,1,.3,1); }";
  document.head.appendChild(style);

  var targets = document.querySelectorAll(
    ".section-head, .loop-step, .bento-card, .price-card, .privacy-inner, .faq-list details, .problem-facts li"
  );
  targets.forEach(function (el) { el.classList.add("reveal"); });

  var observer = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-in");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.15, rootMargin: "0px 0px -5% 0px" }
  );
  targets.forEach(function (el) { observer.observe(el); });
})();
