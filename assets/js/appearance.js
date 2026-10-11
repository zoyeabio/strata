/* Appearance: apply stored or system colour scheme before first paint,
   then wire the footer [data-appearance-toggle] button if present.
   Loaded in head on every page. */
(function () {
  var root = document.documentElement;
  var KEY = "strata:appearance";

  function stored() {
    try {
      return window.localStorage.getItem(KEY);
    } catch (e) {
      return null;
    }
  }

  function apply(name) {
    root.classList.toggle("dark", name === "dark");
    var btn = document.querySelector("[data-appearance-toggle]");
    if (btn) {
      btn.setAttribute("aria-pressed", name === "dark" ? "true" : "false");
      btn.textContent = name === "dark" ? "Light" : "Dark";
    }
  }

  function current() {
    var fallback = root.getAttribute("data-default-appearance") || "light";
    var auto =
      root.getAttribute("data-auto-appearance") !== "false" &&
      typeof window.matchMedia === "function" &&
      window.matchMedia("(prefers-color-scheme: dark)").matches;
    return stored() || (auto ? "dark" : fallback);
  }

  apply(current());

  document.addEventListener("DOMContentLoaded", function () {
    var btn = document.querySelector("[data-appearance-toggle]");
    if (!btn) return;
    apply(current());
    btn.addEventListener("click", function () {
      var next = root.classList.contains("dark") ? "light" : "dark";
      try {
        window.localStorage.setItem(KEY, next);
      } catch (e) {}
      apply(next);
    });
  });
})();
