/* Carousel: prev and next buttons, dot indicators, autoplay, keyboard arrows,
   pause on hover and focus. Autoplay is skipped when prefers-reduced-motion
   matches or when the a11y panel has stored a reduce-motion choice. The
   interval is read from data-interval (2000ms default); wrapping past the
   last slide animates off-screen and snaps back, so the loop is continuous.

   One instance per [data-carousel] element. Loaded by the carousel shortcode,
   so a page without one ships no script and keeps the strict CSP intact. */
(function () {
  var roots = document.querySelectorAll("[data-carousel]");
  if (!roots.length) return;

  Array.prototype.forEach.call(roots, function (root) {
    if (root.getAttribute("data-carousel-ready")) return;
    root.setAttribute("data-carousel-ready", "");

    var track = root.querySelector("[data-carousel-track]");
    var slides = track.children;
    var dots = root.querySelectorAll("[data-slide-to]");
    var count = dots.length;
    var index = 0;
    var timer = null;
    var snap = null;
    var interval = parseInt(root.getAttribute("data-interval"), 10) || 2000;

    function calm() {
      return document.documentElement.classList.contains("a11y-reduce-motion") ||
        (typeof window.matchMedia === "function" &&
          window.matchMedia("(prefers-reduced-motion: reduce)").matches);
    }

    function paint(n) {
      for (var i = 0; i < dots.length; i++) {
        if (i === n) {
          dots[i].setAttribute("data-carousel-active", "");
          dots[i].setAttribute("aria-current", "true");
        } else {
          dots[i].removeAttribute("data-carousel-active");
          dots[i].removeAttribute("aria-current");
        }
      }
      for (var j = 0; j < slides.length; j++) {
        if (j === n) {
          slides[j].setAttribute("data-carousel-active", "");
        } else {
          slides[j].removeAttribute("data-carousel-active");
        }
      }
    }

    function go(next) {
      if (next === count) {
        index = count;
        track.style.transform = "translateX(-" + index * 100 + "%)";
        paint(0);
        clearTimeout(snap);
        snap = setTimeout(function () {
          track.style.transition = "none";
          index = 0;
          track.style.transform = "translateX(0)";
          void track.offsetWidth;
          track.style.transition = "transform 0.6s ease";
        }, 650);
      } else {
        clearTimeout(snap);
        index = (next + count) % count;
        track.style.transform = "translateX(-" + index * 100 + "%)";
        paint(index);
      }
    }

    function start() {
      stop();
      if (!calm() && count > 1) {
        timer = setInterval(function () {
          if (calm()) { stop(); return; }
          go(index + 1);
        }, interval);
      }
    }

    function stop() {
      if (timer) { clearInterval(timer); timer = null; }
    }

    root.querySelector("[data-carousel-prev]").addEventListener("click", function () { go(index - 1); });
    root.querySelector("[data-carousel-next]").addEventListener("click", function () { go(index + 1); });
    root.addEventListener("keydown", function (event) {
      if (event.key === "ArrowLeft") {
        event.preventDefault();
        go(index - 1);
      } else if (event.key === "ArrowRight") {
        event.preventDefault();
        go(index + 1);
      }
    });
    for (var k = 0; k < dots.length; k++) {
      (function (n) { dots[k].addEventListener("click", function () { go(n); }); })(k);
    }
    root.addEventListener("pointerenter", stop);
    root.addEventListener("pointerleave", start);
    root.addEventListener("focusin", stop);
    root.addEventListener("focusout", start);
    start();
  });
})();
