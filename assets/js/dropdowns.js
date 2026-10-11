/* Header dropdowns share one contract: at most one panel is open at a
   time, aria-expanded tracks the panel, Escape closes it with focus back
   on its own button. Each opener registers its toggle+panel pair through
   strataRegisterDropdown (optional onOpen/onClose hooks) and gets a
   set(open) back; this file owns the mutual exclusion and Escape, so a
   fourth dropdown is one registration and no edits here.
   Loaded deferred from frame/header.html ahead of menu.js, search.js and
   a11y.js — deferred scripts run in document order. */
(function () {
  var open = [];

  function set(pair, on) {
    pair.toggle.setAttribute("aria-expanded", on ? "true" : "false");
    pair.panel.classList.toggle("is-open", on);
    if (on) {
      if (open.indexOf(pair) === -1) open.push(pair);
      if (pair.onOpen) pair.onOpen();
    } else {
      var i = open.indexOf(pair);
      if (i !== -1) open.splice(i, 1);
      if (pair.onClose) pair.onClose();
    }
  }

  document.addEventListener("keydown", function (event) {
    if (event.key !== "Escape" || !open.length) return;
    var pair = open[open.length - 1];
    set(pair, false);
    pair.toggle.focus();
  });

  window.strataRegisterDropdown = function (toggle, panel, hooks) {
    var pair = { toggle: toggle, panel: panel };
    hooks = hooks || {};
    for (var k in hooks) pair[k] = hooks[k];
    return function (on) {
      if (on) {
        open.slice().forEach(function (other) {
          if (other !== pair) set(other, false);
        });
      }
      set(pair, on);
    };
  };
})();
