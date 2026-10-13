/* Contact form: live byte counter, honeypot, and a fetch-based submit that
   reports the outcome inline. The byte limit comes from data-max-bytes
   (1000 default); the field ids derive from the form's own id, so two forms
   on one page do not collide.

   SECURITY: the endpoint must validate, sanitise and rate-limit on the
   server, and must reject hp_name whenever it is filled.

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
      if (Number(byteEl.textContent) > maxBytes) {
        show("error", "Message is too long. Maximum " + maxBytes + " bytes allowed.");
        message.focus();
        return;
      }
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
