/* Fixture consent controller: the site owns its consent answer and the
   theme obeys it. This implements the contract js/ads.js reads in the
   [ads] consent "gated" mode:

     localStorage "strata-cookie-consent" = "granted" | "denied"
     CustomEvent "strata:cookie-consent" with that value as detail

   The banner asks once per browser; "Change" reopens the question.
   Shipped through extend-head.html as a fingerprinted file, because
   static/_headers keeps script-src 'self' with no unsafe-inline. */
(function () {
  var KEY = 'strata-cookie-consent';
  var EVENT = 'strata:cookie-consent';

  function answer() {
    try { return localStorage.getItem(KEY); } catch (err) { return null; }
  }

  function paint(value) {
    var region = document.querySelector('[data-cookie-consent]');
    if (!region) return;
    var controls = region.querySelector('[data-consent-controls]');
    var asked = region.querySelector('[data-consent-state]');
    var shown = region.querySelector('[data-consent-value]');
    if (!value) {
      if (controls) controls.hidden = false;
      if (asked) asked.hidden = true;
      return;
    }
    if (controls) controls.hidden = true;
    if (asked) {
      asked.hidden = false;
      if (shown) shown.textContent = value;
    }
  }

  function record(value) {
    try { localStorage.setItem(KEY, value); } catch (err) { /* private mode */ }
    paint(value);
    // js/ads.js listens for exactly this event in gated mode.
    document.dispatchEvent(new CustomEvent(EVENT, { detail: value }));
  }

  document.addEventListener('DOMContentLoaded', function () {
    var region = document.querySelector('[data-cookie-consent]');
    if (!region) return;
    var accept = region.querySelector('[data-consent-accept]');
    var decline = region.querySelector('[data-consent-decline]');
    var reopen = region.querySelector('[data-consent-reopen]');
    if (accept) {
      accept.addEventListener('click', function () { record('granted'); });
    }
    if (decline) {
      decline.addEventListener('click', function () { record('denied'); });
    }
    if (reopen) {
      reopen.addEventListener('click', function () {
        try { localStorage.removeItem(KEY); } catch (err) { /* private mode */ }
        paint(null);
      });
    }
    paint(answer());
  });
})();
