/* Main navigation disclosure: toggles the mobile panel, closes on
   Escape with focus back on the button, and resets when crossing to the
   desktop layout. Submenu chevron buttons toggle their sibling block
   in the same script. Loaded deferred from the menu partial whenever
   a main menu exists. */
(function () {
  var btn = document.querySelector("[data-nav-toggle]");
  var panel = document.querySelector("[data-nav-panel]");
  if (!btn || !panel) return;

  function set(open) {
    btn.setAttribute("aria-expanded", open ? "true" : "false");
    panel.classList.toggle("is-open", open);
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
