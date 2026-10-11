/* Accessibility panel: three switches persisted to localStorage and
   applied as classes on <html> — a11y-underline-links, a11y-reduce-motion,
   a11y-strong-focus (see base/a11y.css). Classes go on at load so the
   preference holds from the first paint; carousel and scroll-to-top read
   the motion class alongside the OS setting. The panel is the same
   disclosure contract as menu.js/search.js: aria-expanded sync, Escape
   closes with focus back, opening closes the other two dropdowns.
   Loaded deferred from the a11y partial when enableA11y is on. */
(function () {
  var btn = document.querySelector("[data-a11y-toggle]");
  var panel = document.querySelector("[data-a11y-panel]");
  if (!btn || !panel) return;

  var KEY = "strataA11y";
  var CLASSES = { links: "a11y-underline-links", motion: "a11y-reduce-motion", focus: "a11y-strong-focus" };

  function read() {
    var saved = {};
    try {
      saved = JSON.parse(localStorage.getItem(KEY) || "{}");
    } catch (e) {
      saved = {};
    }
    return saved;
  }

  function applyAll() {
    var saved = read();
    Object.keys(CLASSES).forEach(function (name) {
      document.documentElement.classList.toggle(CLASSES[name], !!saved[name]);
    });
    panel.querySelectorAll("[data-a11y-setting]").forEach(function (box) {
      box.checked = !!saved[box.getAttribute("data-a11y-setting")];
    });
  }

  function set(open) {
    btn.setAttribute("aria-expanded", open ? "true" : "false");
    panel.classList.toggle("is-open", open);
    if (open) {
      [["[data-nav-toggle]", "[data-nav-panel]"], ["[data-search-toggle]", "[data-search-panel]"]].forEach(function (pair) {
        var otherBtn = document.querySelector(pair[0]);
        var otherPanel = document.querySelector(pair[1]);
        if (otherBtn && otherPanel) {
          otherBtn.setAttribute("aria-expanded", "false");
          otherPanel.classList.remove("is-open");
        }
      });
    }
  }

  btn.addEventListener("click", function () {
    set(btn.getAttribute("aria-expanded") !== "true");
  });

  panel.addEventListener("change", function (event) {
    var box = event.target;
    if (!box || !box.getAttribute) return;
    var name = box.getAttribute("data-a11y-setting");
    if (!name || !CLASSES[name]) return;
    var saved = read();
    saved[name] = box.checked;
    try {
      localStorage.setItem(KEY, JSON.stringify(saved));
    } catch (e) {
      /* private mode: the session still applies, it just won't persist */
    }
    document.documentElement.classList.toggle(CLASSES[name], box.checked);
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape" && btn.getAttribute("aria-expanded") === "true") {
      set(false);
      btn.focus();
    }
  });

  applyAll();
})();
