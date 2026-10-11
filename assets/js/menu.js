/* Main navigation disclosure: toggles the mobile panel, closes on
   Escape with focus back on the button, and resets when crossing to the
   desktop layout. On open the panel cap is measured from the live header
   bottom, so a wrapped (multi-line) header never pushes it past the
   viewport. Submenu chevron buttons toggle their sibling block
   in the same script. Opening the nav closes the search and a11y panels
   so the dropdowns never stack (both return the courtesy).
   Loaded deferred from the menu partial whenever
   a main menu exists. */
(function () {
  var btn = document.querySelector("[data-nav-toggle]");
  var panel = document.querySelector("[data-nav-panel]");
  if (!btn || !panel) return;

  function set(open) {
    btn.setAttribute("aria-expanded", open ? "true" : "false");
    panel.classList.toggle("is-open", open);
    if (open) {
      panel.style.maxHeight =
        Math.max(0, window.innerHeight - panel.getBoundingClientRect().top) + "px";
      var searchBtn = document.querySelector("[data-search-toggle]");
      var searchPanel = document.querySelector("[data-search-panel]");
      if (searchBtn && searchPanel) {
        searchBtn.setAttribute("aria-expanded", "false");
        searchPanel.classList.remove("is-open");
      }
      var a11yBtn = document.querySelector("[data-a11y-toggle]");
      var a11yPanel = document.querySelector("[data-a11y-panel]");
      if (a11yBtn && a11yPanel) {
        a11yBtn.setAttribute("aria-expanded", "false");
        a11yPanel.classList.remove("is-open");
      }
    } else {
      panel.style.maxHeight = "";
    }
  }

  btn.addEventListener("click", function () {
    set(btn.getAttribute("aria-expanded") !== "true");
  });

  document.querySelectorAll("[data-nav-subtoggle]").forEach(function (sub) {
    sub.addEventListener("click", function () {
      var open = sub.getAttribute("aria-expanded") !== "true";
      sub.setAttribute("aria-expanded", open ? "true" : "false");
      var body = document.getElementById(sub.getAttribute("aria-controls"));
      if (body) body.hidden = !open;
    });
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape" && btn.getAttribute("aria-expanded") === "true") {
      set(false);
      btn.focus();
    }
  });

  var wide = window.matchMedia("(min-width: 853px)");
  function sync() {
    if (wide.matches) set(false);
  }
  if (wide.addEventListener) {
    wide.addEventListener("change", sync);
  }
})();
