/* Reading progress bar: tracks scroll completion on article pages.
   Zero dependencies, passive scroll listener, respects reduced-motion. */
(function () {
  var bar = document.querySelector("[data-reading-progress]");
  if (!bar) return;

  function update() {
    var doc = document.documentElement;
    var total = doc.scrollHeight - window.innerHeight;
    if (total <= 0) {
      bar.style.width = "0%";
      return;
    }
    var progress = Math.min(100, Math.max(0, (window.scrollY / total) * 100));
    bar.style.width = progress + "%";
  }

  window.addEventListener("scroll", update, { passive: true });
  window.addEventListener("resize", update, { passive: true });
  update();
})();
