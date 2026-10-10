(function () {
  var root = document.documentElement;
  var stored = null;

  try {
    stored = window.localStorage.getItem("strata:appearance");
  } catch (e) {}

  var fallback = root.getAttribute("data-default-appearance") || "light";
  var auto =
    root.getAttribute("data-auto-appearance") !== "false" &&
    typeof window.matchMedia === "function" &&
    window.matchMedia("(prefers-color-scheme: dark)").matches;

  var appearance = stored || (auto ? "dark" : fallback);
  root.classList.toggle("dark", appearance === "dark");
})();
