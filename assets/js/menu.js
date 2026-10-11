/* Main navigation disclosure: toggles the mobile panel and resets when
   crossing to the desktop layout. On open the panel cap is measured from
   the live header bottom, so a wrapped (multi-line) header never pushes it
   past the viewport. Submenu chevron buttons toggle their sibling block in
   the same script. Mutual exclusion, aria-expanded and Escape are shared
   with the search and a11y panels through assets/js/dropdowns.js.
   Loaded deferred from the menu partial whenever a main menu exists. */
(function () {
  var btn = document.querySelector("[data-nav-toggle]");
  var panel = document.querySelector("[data-nav-panel]");
  if (!btn || !panel) return;

  var set = strataRegisterDropdown(btn, panel, {
    onOpen: function () {
      panel.style.maxHeight =
        Math.max(0, window.innerHeight - panel.getBoundingClientRect().top) + "px";
    },
    onClose: function () {
      panel.style.maxHeight = "";
    }
  });

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

  var wide = window.matchMedia("(min-width: 853px)");
  function sync() {
    if (wide.matches) set(false);
  }
  if (wide.addEventListener) {
    wide.addEventListener("change", sync);
  }
})();
