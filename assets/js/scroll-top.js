/* Scroll-to-top: reveals the floating [data-scroll-top] button past 400px
   and smooth-scrolls on click. Loaded from the footer partial only when
   enabled in site config. Runs synchronously: this script follows the
   button in DOM order, so no readyState or DOMContentLoaded dance. */
(function () {
  var btn = document.querySelector("[data-scroll-top]");
  if (!btn) return;
  function update() {
    btn.hidden = window.scrollY < 400;
  }
    update();
    window.addEventListener("scroll", update, { passive: true });
    btn.addEventListener("click", function () {
      var calm = typeof window.matchMedia === "function" &&
        window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      window.scrollTo({ top: 0, behavior: calm ? "auto" : "smooth" });
    });
})();
