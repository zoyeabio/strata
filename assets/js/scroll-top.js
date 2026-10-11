/* Scroll-to-top: smooth-scrolls the footer [data-scroll-top] button.
   Loaded from the footer partial only when enabled in site config. */
(function () {
  document.addEventListener("DOMContentLoaded", function () {
    var btn = document.querySelector("[data-scroll-top]");
    if (!btn) return;
    btn.addEventListener("click", function () {
      window.scrollTo({ top: 0, behavior: "smooth" });
    });
  });
})();
