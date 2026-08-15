// SnapShelf landing enhancement — scroll-triggered reveals with a tiny
// IntersectionObserver. Progressive only: the page is complete without JS.
(function () {
  "use strict";

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
