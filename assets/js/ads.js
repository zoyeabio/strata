/* AdSense unit push, externalised so static/_headers keeps no unsafe-inline.
   Each <ins class="adsbygoogle"> is followed by a fingerprinted copy of this
   tag carrying data-ads-consent from the site's [ads] config.

   consent "none": the loader ships from head.html on unit pages and every
   copy simply queues one unit into the array the loader drains — the shape
   that has shipped since 0.1, for sites behind a certified CMP.

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
   copy. Ingress and egress still go through static/_headers only: the
   injected tag is an external script, and 'script-src' 'self' pagead2…
   heads it off at build time (head.html keeps that check in both modes). */

var KEY = 'strata-cookie-consent';
var EVENT = 'strata:cookie-consent';
var LOADER = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js';

function consentValue() {
  try { return localStorage.getItem(KEY); } catch (err) { return null; }
}

function units() {
  return document.querySelectorAll('ins.adsbygoogle');
}

function collapseUnits() {
  units().forEach(function (unit) { unit.style.display = 'none'; });
}

function revealUnits() {
  units().forEach(function (unit) { unit.style.removeProperty('display'); });
}

function injectLoader() {
  if (window.__strataAdsLoader) return;
  window.__strataAdsLoader = true;
  var unit = document.querySelector('ins.adsbygoogle[data-ad-client]');
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

(function () {
  var consent = document.currentScript && document.currentScript.getAttribute('data-ads-consent');
  if (consent !== 'gated') {
    (adsbygoogle = window.adsbygoogle || []).push({});
    return;
  }
  units().forEach(function (unit) {
    unit.setAttribute('data-ads-pending', '');
  });
  var answer = consentValue();
  if (answer === 'denied') collapseUnits();
  if (answer === 'granted') { run(); return; }
  document.addEventListener(EVENT, function (event) {
    if (event.detail === 'granted') { revealUnits(); run(); }
    else if (event.detail === 'denied') collapseUnits();
  });
})();
