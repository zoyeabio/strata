/* Contact form: live byte counter, honeypot rejection, a minimum dwell
   time, and a fetch-based submit that reports the outcome inline. The byte
   limit comes from data-max-bytes (1000 default), the dwell time from
   data-min-fill (3 default); the field ids derive from the form's own id,
   so two forms on one page do not collide.

   SECURITY: this file only keeps the browser honest — the endpoint must
   validate, sanitise and rate-limit on the server, reject hp_name whenever
   it is filled, and, when form_ts is non-empty, bound it to
   minFill <= now - ts <= 2h so a stale request cannot be replayed.

   One instance per form[data-contact-form]. Loaded by the contact shortcode,
   so a page without one ships no script and keeps the strict CSP intact. */
(function () {
  var forms = document.querySelectorAll("form[data-contact-form]");
  if (!forms.length) return;

  Array.prototype.forEach.call(forms, function (form) {
    if (form.getAttribute("data-contact-ready")) return;
    form.setAttribute("data-contact-ready", "");

    var id = form.id;
    var message = document.getElementById(id + "-message");
    var byteEl = document.getElementById(id + "-bytes");
    var charEl = document.getElementById(id + "-chars");
    var status = document.getElementById(id + "-status");
    var maxBytes = parseInt(form.getAttribute("data-max-bytes"), 10) || 1000;
    /* Client-side cooldown: an attempt counts the moment it is made, failed
       ones too, so scripted floods burn their own interval. The endpoint
       still owns rate-limiting — this only shapes the browser. */
    var cooldown = parseInt(form.getAttribute("data-cooldown"), 10) || 0;
    /* Minimum dwell: the page must have been open for data-min-fill seconds
       before a submit counts, so a load-and-POST script never reaches the
       network. The same instant travels as form_ts for the server's window
       check (non-empty form_ts only — a native no-JS post sends ""). */
    var minFill = parseInt(form.getAttribute("data-min-fill"), 10) || 0;
    var openedAt = Date.now();
    var lastSent = 0;
    var hp = form.querySelector('input[name="hp_name"]');
    var ts = form.querySelector('input[name="form_ts"]');

    function recount() {
      var text = message.value;
      byteEl.textContent = new TextEncoder().encode(text).length;
      charEl.textContent = text.length;
      var over = Number(byteEl.textContent) > maxBytes;
      message.closest(".contact-form__field").classList.toggle(
        "contact-form__field--over", over);
      message.setAttribute("aria-invalid", over ? "true" : "false");
    }

    function show(kind, text) {
      status.textContent = text;
      status.className = "contact-form__status contact-form__status--" + kind;
    }

    message.addEventListener("input", recount);

    form.addEventListener("submit", function (event) {
      event.preventDefault();
      var now = Date.now();
      if (cooldown > 0 && now - lastSent < cooldown * 1000) {
        show("error", "Please wait a moment before sending again.");
        return;
      }
      if (hp && hp.value) {
        /* A filled honeypot is a bot, not a reader: no request, and no
           message that names the field which gave it away. */
        show("error", "Submission failed. Please try again.");
        return;
      }
      if (minFill > 0 && now - openedAt < minFill * 1000) {
        show("error", "Please wait a moment before sending.");
        return;
      }
      if (Number(byteEl.textContent) > maxBytes) {
        show("error", "Message is too long. Maximum " + maxBytes + " bytes allowed.");
        message.focus();
        return;
      }
      lastSent = now;
      if (ts) ts.value = Math.floor(openedAt / 1000);
      show("neutral", "Sending...");
      var button = form.querySelector('button[type="submit"]');
      button.disabled = true;
      form.setAttribute("aria-busy", "true");
      fetch(form.action, { method: "POST", body: new FormData(form) })
        .then(function (response) { return response.json().then(function (data) { return { ok: response.ok, data: data }; }); })
        .then(function (result) {
          if (result.ok && result.data.success) {
            show("ok", "Thank you! Your message has been sent successfully.");
            form.reset();
            recount();
          } else {
            show("error", result.data.error || "Submission failed. Please try again.");
          }
        })
        .catch(function () {
          show("error", "Oops! Something went wrong. Please try again later.");
        })
        .then(function () { button.disabled = false; form.removeAttribute("aria-busy"); button.focus(); });
    });
  });
})();
