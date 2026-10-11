/* Smart header: hide on scroll down, reveal on scroll up, always show
   near the top. Thresholds follow the source behaviour verbatim: visible
   below 100px, then a 10px hysteresis either way. rAF-throttled, passive
   listener. Hiding uses translateY so no body compensation is needed
   (the header keeps its space, unlike a fixed overlay).
   Loaded from the header partial only when [header] layout is "smart". */
(function () {
  var lastScrollY = window.scrollY;
  var ticking = false;
  var header = document.querySelector("[data-smart-header]");

  if (!header) return;

  function updateHeader() {
    var scrollY = window.scrollY;

    if (scrollY < 100) {
      header.style.transform = "";
    } else if (scrollY > lastScrollY && scrollY > lastScrollY + 10) {
      header.style.transform = "translateY(-110%)";
    } else if (scrollY < lastScrollY && scrollY < lastScrollY - 10) {
      header.style.transform = "";
    }

    lastScrollY = scrollY;
    ticking = false;
  }

  window.addEventListener("scroll", function () {
    if (!ticking) {
      window.requestAnimationFrame(function () {
        updateHeader();
      });
      ticking = true;
    }
  }, { passive: true });
})();
