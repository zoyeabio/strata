/* Site search: fetches the home JSON index on first open and scores it
   in the page. Every query token must occur somewhere; title hits weigh 3,
   summary 2, body 1. English tokenization (lowercase alphanumeric split);
   CJK queries still match as whole-string substrings. Results render as
   text links (no innerHTML anywhere), at most ten, with a polite live
   status line. Escape closes with focus back on the button — the same
   disclosure contract as assets/js/menu.js, which this script also closes
   so the two dropdowns never stack (menu.js returns the courtesy).
   Loaded deferred from the search partial when enableSearch is on. */
(function () {
  var btn = document.querySelector("[data-search-toggle]");
  var panel = document.querySelector("[data-search-panel]");
  if (!btn || !panel) return;
  var input = panel.querySelector("[data-search-input]");
  var list = panel.querySelector("[data-search-results]");
  var status = panel.querySelector("[data-search-status]");
  var indexURL = panel.getAttribute("data-search-index");
  var entries = null;
  var failed = false;
  var timer = null;

  function set(open) {
    btn.setAttribute("aria-expanded", open ? "true" : "false");
    panel.classList.toggle("is-open", open);
    if (open) {
      var navBtn = document.querySelector("[data-nav-toggle]");
      var navPanel = document.querySelector("[data-nav-panel]");
      if (navBtn && navPanel) {
        navBtn.setAttribute("aria-expanded", "false");
        navPanel.classList.remove("is-open");
      }
      load();
      if (input) input.focus();
    }
  }

  function load() {
    if (entries || failed || !indexURL) return;
    if (status) status.textContent = status.getAttribute("data-search-loading");
    fetch(indexURL).then(function (res) {
      if (!res.ok) throw new Error(res.status);
      return res.json();
    }).then(function (data) {
      entries = Array.isArray(data) ? data : [];
      if (status) status.textContent = "";
      if (input && input.value) render(input.value);
    }).catch(function () {
      failed = true;
      if (status) status.textContent = status.getAttribute("data-search-unavailable");
    });
  }

  function tokens(query) {
    return query.toLowerCase().split(/[^a-z0-9']+/).filter(function (t) { return t; });
  }

  function count(haystack, token) {
    var n = 0;
    var i = haystack.indexOf(token);
    while (i !== -1) {
      n++;
      i = haystack.indexOf(token, i + token.length);
    }
    return n;
  }

  function search(query) {
    var toks = tokens(query);
    if (!toks.length || !entries) return [];
    var hits = [];
    entries.forEach(function (entry) {
      var title = (entry.title || "").toLowerCase();
      var summary = (entry.summary || "").toLowerCase();
      var content = (entry.content || "").toLowerCase();
      var score = 0;
      var matched = true;
      toks.forEach(function (tok) {
        var inTitle = count(title, tok);
        var inSummary = count(summary, tok);
        var inContent = count(content, tok);
        if (!inTitle && !inSummary && !inContent) {
          matched = false;
          return;
        }
        score += 3 * inTitle + 2 * inSummary + inContent;
      });
      if (matched) hits.push({ entry: entry, score: score });
    });
    hits.sort(function (a, b) { return b.score - a.score; });
    return hits.slice(0, 10);
  }

  function render(query) {
    while (list.firstChild) list.removeChild(list.firstChild);
    if (!tokens(query).length) {
      if (status && (failed || entries)) status.textContent = "";
      return;
    }
    if (failed) {
      if (status) status.textContent = status.getAttribute("data-search-unavailable");
      return;
    }
    if (!entries) return;
    var hits = search(query);
    if (!hits.length) {
      if (status) status.textContent = status.getAttribute("data-search-empty");
      return;
    }
    hits.forEach(function (hit) {
      var item = document.createElement("li");
      var link = document.createElement("a");
      link.className = "site-search__link";
      link.href = hit.entry.url;
      link.textContent = hit.entry.title;
      item.appendChild(link);
      if (hit.entry.date) {
        var meta = document.createElement("span");
        meta.className = "site-search__meta";
        meta.textContent = hit.entry.date;
        item.appendChild(meta);
      }
      list.appendChild(item);
    });
    if (status) status.textContent = hits.length + " " + status.getAttribute("data-search-count");
  }

  btn.addEventListener("click", function () {
    set(btn.getAttribute("aria-expanded") !== "true");
  });

  if (input) {
    input.addEventListener("input", function () {
      if (timer) clearTimeout(timer);
      timer = setTimeout(function () { render(input.value); }, 150);
    });
  }

  list.addEventListener("click", function () { set(false); });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape" && btn.getAttribute("aria-expanded") === "true") {
      set(false);
      btn.focus();
    }
  });
})();
