/* Accessibility panel: three switches persisted to localStorage
   ("strataA11y") and applied as classes on <html> — a11y-underline-links,
   a11y-reduce-motion, a11y-strong-focus (see base/a11y.css). The classes
   are applied in the head, before the first paint, so a stored preference
   never flashes the other way; the panel wiring waits for DOMContentLoaded
   because this head copy runs before the body exists. Carousel and
   scroll-to-top read the motion class alongside the OS setting. When the
   OS already prefers reduced motion the motion switch is disabled and its
   note shown: both rules only ever turn motion off, so the switch could
   never re-enable it and leaving it live would mislead.
   Loaded synchronously from head/head.html when enableA11y is on; the
   panel is frame/a11y.html, which shares its contract with assets/js/dropdowns.js. */
(function () {
  var KEY = "strataA11y";
  var CLASSES = { links: "a11y-underline-links", motion: "a11y-reduce-motion", focus: "a11y-strong-focus" };
  var root = document.documentElement;

  function read() {
    var saved = {};
    try {
      saved = JSON.parse(localStorage.getItem(KEY) || "{}");
    } catch (e) {
      saved = {};
    }
    return saved;
  }

  function applyClasses() {
    var saved = read();
    Object.keys(CLASSES).forEach(function (name) {
      root.classList.toggle(CLASSES[name], !!saved[name]);
    });
    return saved;
  }

  applyClasses();

  document.addEventListener("DOMContentLoaded", function () {
    var btn = document.querySelector("[data-a11y-toggle]");
    var panel = document.querySelector("[data-a11y-panel]");
    if (!btn || !panel) return;

    var saved = applyClasses();
    panel.querySelectorAll("[data-a11y-setting]").forEach(function (box) {
      box.checked = !!saved[box.getAttribute("data-a11y-setting")];
    });

    var osMotion = false;
    try {
      osMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    } catch (e) {
      osMotion = false;
    }
    var motionBox = panel.querySelector('[data-a11y-setting="motion"]');
    var note = panel.querySelector("[data-a11y-os-note]");
    if (osMotion && motionBox) {
      motionBox.checked = true;
      motionBox.disabled = true;
      if (note) note.hidden = false;
    }

    var set = strataRegisterDropdown(btn, panel);

    btn.addEventListener("click", function () {
      set(btn.getAttribute("aria-expanded") !== "true");
    });

    panel.addEventListener("change", function (event) {
      var box = event.target;
      if (!box || !box.getAttribute) return;
      var name = box.getAttribute("data-a11y-setting");
      if (!name || !CLASSES[name] || box.disabled) return;
      var current = read();
      current[name] = box.checked;
      try {
        localStorage.setItem(KEY, JSON.stringify(current));
      } catch (e) {
        /* private mode: the session still applies, it just won't persist */
      }
      root.classList.toggle(CLASSES[name], box.checked);
    });
  });
})();
