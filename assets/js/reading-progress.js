/* Reading progress bar: tracks scroll completion on article pages.
   Zero dependencies, rAF-throttled passive listener, GPU scaleX transform. */
(function () {
  var bar = document.querySelector("[data-reading-progress]");
  if (!bar) return;
  var ticking = false;

  function update() {
    ticking = false;
    var doc = document.documentElement;
    var total = doc.scrollHeight - window.innerHeight;
    if (total <= 0) {
      bar.style.transform = "scaleX(0)";
      return;
    }
    var ratio = Math.min(1, Math.max(0, window.scrollY / total));
    bar.style.transform = "scaleX(" + ratio + ")";
  }

  function requestUpdate() {
    if (!ticking) {
      window.requestAnimationFrame(update);
      ticking = true;
    }
  }

  window.addEventListener("scroll", requestUpdate, { passive: true });
  window.addEventListener("resize", requestUpdate, { passive: true });
  update();
})();
