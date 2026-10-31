/* AdSense unit push, externalised so static/_headers keeps no unsafe-inline.
   Each <ins class="adsbygoogle"> is followed by a fingerprinted copy of this
   tag carrying data-ads-consent from the site's [ads] config.

   consent "none": the loader ships from head.html on unit pages and every
   copy simply queues one unit into the array the loader drains — the shape
   that has shipped since 0.1. The theme performs no consent gating in this
   mode; the site or its CMP owns that decision.

   consent "gated": the site owns the consent answer; this file obeys it.
   Contract (documented in docs/configuration.md):
     - localStorage key "strata-cookie-consent" holds "granted" or "denied"
     - the site's banner dispatches CustomEvent("strata:cookie-consent")
       with those values as detail when the answer changes
   Until "granted", every unit stays hidden (data-ads-pending) and the
   external loader is never downloaded; a denied answer removes the units
   from the flow entirely, so a site the reader will not monetize keeps no
   blank slabs where ads would have been; a granted answer — present in the
   store when this script runs, or arriving on the event — reveals them,
   injects the loader once, and drains the units in DOM order, one push per
   copy.

   Withdrawal is immediate, not just for later pages: a denied answer that
   arrives AFTER the loader was injected reloads the page once, so the
   already-running Google runtime — loader, iframes, cookies in flight —
   is out of the document with no way for this file to half-disarm it.
   First-denial visits need the reload never (nothing injected yet), and
   the reload cannot loop: the fresh document reads the persisted answer
   and has nothing to tear down. Ingress and egress still go through
   static/_headers only: the injected tag is an external script, and
   'script-src' 'self' pagead2… heads it off at build time (head.html
   keeps that check in both modes). */

var KEY = 'strata-cookie-consent';
var EVENT = 'strata:cookie-consent';
var LOADER = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js';

function consentValue() {
  try { return localStorage.getItem(KEY); } catch (err) { return null; }
}

function units() {
  // Select only markup emitted by Strata. Google may append its own
  // adsbygoogle nodes or mutate their private class names at runtime.
  return document.querySelectorAll('ins.adsbygoogle[data-strata-ad-unit]');
}

function collapseUnits() {
  units().forEach(function (unit) {
    unit.style.display = 'none';
    var slot = unit.closest('.ad-slot');
    if (slot) slot.style.display = 'none';
  });
}

function revealUnits() {
  units().forEach(function (unit) {
    unit.removeAttribute('data-ads-pending');
    unit.style.removeProperty('display');
    var slot = unit.closest('.ad-slot');
    if (slot) slot.style.removeProperty('display');
  });
}

function injectLoader() {
  if (window.__strataAdsLoader) return;
  window.__strataAdsLoader = true;
  var unit = document.querySelector('ins.adsbygoogle[data-strata-ad-unit][data-ad-client]');
  var client = unit && unit.getAttribute('data-ad-client');
  if (!client) return;
  var loader = document.createElement('script');
  loader.async = true;
  loader.crossOrigin = 'anonymous';
  loader.src = LOADER + '?client=' + encodeURIComponent(client);
  document.head.appendChild(loader);
}

function drain() {
  var next = Number(window.__strataAdsDrained || 0);
  if (next >= units().length) return false;
  window.__strataAdsDrained = String(next + 1);
  units()[next].removeAttribute('data-ads-pending');
  (adsbygoogle = window.adsbygoogle || []).push({});
  return true;
}

function run() {
  injectLoader();   // fills in only once, the first time
  while (drain());  // each copy had better be one unit apart
}

function handleConsent(event) {
  if (event.detail === 'granted') {
    revealUnits();
    run();
  } else if (event.detail === 'denied') {
    collapseUnits();
    if (window.__strataAdsLoader) window.location.reload();
  }
}

function handlePageShow(event) {
  // A document restored from the back-forward cache does not rerun this
  // script. Consent may have changed on the page visited in between, so the
  // restored document must reconcile its live Google runtime with storage.
  if (!event.persisted) return;
  var answer = consentValue();
  if (answer === 'granted') {
    revealUnits();
    run();
  } else if (window.__strataAdsLoader) {
    // Google code cannot be safely dismantled in place. Hide it first, then
    // reload into a document whose normal startup path withholds the loader.
    collapseUnits();
    window.location.reload();
  } else if (answer === 'denied') {
    collapseUnits();
  } else {
    // The banner was reopened on another page. Restore the undecided layout
    // without downloading or queuing ads.
    revealUnits();
    units().forEach(function (unit) {
      unit.setAttribute('data-ads-pending', '');
    });
  }
}

(function () {
  var consent = document.currentScript && document.currentScript.getAttribute('data-ads-consent');
  if (consent !== 'gated') {
    (adsbygoogle = window.adsbygoogle || []).push({});
    return;
  }
  // Every ad unit carries this file, but one document-level listener is
  // enough. Register it even when consent was already granted: otherwise a
  // returning visitor could reopen the banner and deny ads without the
  // running Google code being torn out by the documented page reload.
  if (!window.__strataAdsConsentListener) {
    window.__strataAdsConsentListener = true;
    document.addEventListener(EVENT, handleConsent);
    window.addEventListener('pageshow', handlePageShow);
  }
  var answer = consentValue();
  if (answer === 'denied') {
    collapseUnits();
  } else if (answer === 'granted') {
    revealUnits();
    run();
  } else {
    units().forEach(function (unit) {
      unit.setAttribute('data-ads-pending', '');
    });
  }
})();
