import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../assets/js/ads.js', import.meta.url), 'utf8');

function style() {
  return {
    display: '',
    removeProperty(name) {
      if (name === 'display') this.display = '';
    },
  };
}

function unit(name, { internal = false } = {}) {
  const attributes = new Map([
    ['data-ad-client', 'ca-pub-0000000000000000'],
    ['data-ad-slot', name],
  ]);
  const slot = { style: style() };
  return {
    name,
    internal,
    attributes,
    style: style(),
    closest(selector) { return selector === '.ad-slot' ? slot : null; },
    getAttribute(key) { return attributes.get(key) ?? null; },
    removeAttribute(key) { attributes.delete(key); },
    setAttribute(key, value) { attributes.set(key, value); },
    hasAttribute(key) { return attributes.has(key); },
    slot,
  };
}

function harness(savedAnswer) {
  const documentListeners = new Map();
  const windowListeners = new Map();
  const stored = new Map();
  if (savedAnswer) stored.set('strata-cookie-consent', savedAnswer);
  const document = {
    currentScript: null,
    units: [],
    loaders: [],
    addEventListener(name, listener) {
      const entries = documentListeners.get(name) || [];
      entries.push(listener);
      documentListeners.set(name, entries);
    },
    dispatchEvent(event) {
      for (const listener of documentListeners.get(event.type) || []) listener(event);
    },
    querySelectorAll(selector) {
      assert.equal(selector, 'ins.adsbygoogle[data-strata-ad-unit]');
      return this.units.filter((entry) => !entry.internal);
    },
    querySelector(selector) {
      assert.equal(selector, 'ins.adsbygoogle[data-strata-ad-unit][data-ad-client]');
      return this.units.find((entry) => !entry.internal && entry.getAttribute('data-ad-client')) || null;
    },
    createElement(name) {
      assert.equal(name, 'script');
      return {};
    },
    head: {
      appendChild(loader) { document.loaders.push(loader); },
    },
  };
  const location = { reloads: 0, reload() { this.reloads += 1; } };
  const sandbox = {
    console,
    document,
    encodeURIComponent,
    localStorage: { getItem: (key) => stored.get(key) ?? null },
    location,
    addEventListener(name, listener) {
      const entries = windowListeners.get(name) || [];
      entries.push(listener);
      windowListeners.set(name, entries);
    },
    dispatchEvent(event) {
      for (const listener of windowListeners.get(event.type) || []) listener(event);
    },
  };
  // A browser's global object is window. Keeping that identity is important:
  // adsbygoogle's legacy unqualified assignment must land on window too.
  sandbox.window = sandbox;
  const context = vm.createContext(sandbox);

  function runCopy() {
    document.currentScript = {
      getAttribute(name) { return name === 'data-ads-consent' ? 'gated' : null; },
    };
    vm.runInContext(source, context);
  }

  return {
    context,
    document,
    location,
    runCopy,
    setAnswer(answer) {
      if (answer == null) stored.delete('strata-cookie-consent');
      else stored.set('strata-cookie-consent', answer);
    },
  };
}

{
  const page = parseTwoUnits('granted');
  page.setAnswer('denied');
  page.context.window.dispatchEvent({ type: 'pageshow', persisted: true });
  assert.equal(page.first.style.display, 'none');
  assert.equal(page.second.style.display, 'none');
  assert.equal(page.location.reloads, 1, 'a bfcache restore must tear down ads withdrawn on another page');
}

function parseTwoUnits(savedAnswer) {
  const page = harness(savedAnswer);
  const first = unit('first');
  const internal = unit('google-internal', { internal: true });
  internal.setAttribute('data-ads-pending', 'owned-by-google');
  page.document.units.push(first, internal);
  page.runCopy();
  const second = unit('second');
  page.document.units.push(second);
  page.runCopy();
  return { ...page, first, second, internal };
}

{
  const page = parseTwoUnits('granted');
  assert.equal(page.context.adsbygoogle.length, 2, 'both stored-grant units must be queued');
  assert.equal(page.context.window.__strataAdsDrained, '2');
  assert.equal(page.document.loaders.length, 1, 'the loader must be injected once');
  assert.equal(page.first.hasAttribute('data-ads-pending'), false);
  assert.equal(page.second.hasAttribute('data-ads-pending'), false);
  assert.equal(page.internal.getAttribute('data-ads-pending'), 'owned-by-google', 'unmarked Google internal units are not theme units');
  page.document.dispatchEvent({ type: 'strata:cookie-consent', detail: 'denied' });
  assert.equal(page.first.style.display, 'none');
  assert.equal(page.second.style.display, 'none');
  assert.equal(page.location.reloads, 1, 'withdrawal after a stored grant must reload exactly once');
}

{
  const page = parseTwoUnits(null);
  assert.equal(page.first.hasAttribute('data-ads-pending'), true);
  assert.equal(page.second.hasAttribute('data-ads-pending'), true);
  assert.equal(page.context.adsbygoogle, undefined);
  page.document.dispatchEvent({ type: 'strata:cookie-consent', detail: 'granted' });
  assert.equal(page.context.adsbygoogle.length, 2);
  assert.equal(page.first.hasAttribute('data-ads-pending'), false);
  assert.equal(page.second.hasAttribute('data-ads-pending'), false);
}

{
  const page = parseTwoUnits('denied');
  assert.equal(page.context.adsbygoogle, undefined);
  assert.equal(page.first.style.display, 'none');
  assert.equal(page.second.style.display, 'none');
  assert.equal(page.first.slot.style.display, 'none');
  assert.equal(page.second.slot.style.display, 'none');
  assert.equal(page.document.loaders.length, 0);
}

console.log('ads-runtime: all checks passed');
