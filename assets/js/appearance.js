/* Appearance: apply stored or system colour scheme before first paint,
   then wire the header [data-appearance-toggle] button if present. The
   button cycles auto -> dark -> light; auto follows the OS preference
   (or the site default) and stores nothing, so the manual choice never
   locks out the system setting for good. The label is the accessible
   name and carries the current mode, so the button stays aria-pressed
   free: it cycles three states, and aria-pressed would announce
   "dark active" while the label says "Auto".
   Loaded in head on every page. */
(function () {
  var root = document.documentElement;
  var KEY = "strata:appearance";
  var ORDER = ["auto", "dark", "light"];

  function stored() {
    try {
      return window.localStorage.getItem(KEY);
    } catch (e) {
      return null;
    }
  }

  function mode() {
    var s = stored();
    return s === "dark" || s === "light" ? s : "auto";
  }

  function effective() {
    var m = mode();
    if (m !== "auto") return m;
    var fallback = root.getAttribute("data-default-appearance") || "light";
    var auto =
      root.getAttribute("data-auto-appearance") !== "false" &&
      typeof window.matchMedia === "function" &&
      window.matchMedia("(prefers-color-scheme: dark)").matches;
    return auto ? "dark" : fallback;
  }

  function apply() {
    var m = mode();
    var e = effective();
    root.classList.toggle("dark", e === "dark");
    var btn = document.querySelector("[data-appearance-toggle]");
    if (btn) {
      btn.textContent = m.charAt(0).toUpperCase() + m.slice(1);
    }
  }

  apply();

  document.addEventListener("DOMContentLoaded", function () {
    var btn = document.querySelector("[data-appearance-toggle]");
    if (!btn) return;
    apply();
    btn.addEventListener("click", function () {
      var next = ORDER[(ORDER.indexOf(mode()) + 1) % ORDER.length];
      try {
        if (next === "auto") {
          window.localStorage.removeItem(KEY);
        } else {
          window.localStorage.setItem(KEY, next);
        }
      } catch (e) {}
      apply();
    });
  });
})();
