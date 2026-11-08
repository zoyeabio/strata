import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../assets/js/youtube.js', import.meta.url), 'utf8');

assert.doesNotMatch(source, /ytimg|preconnect/i,
  'the runtime must not contact a thumbnail CDN or preconnect before activation');

let componentClass;
const customElements = {
  get() { return componentClass; },
  define(name, value) {
    assert.equal(name, 'lite-youtube');
    componentClass = value;
  },
};

class HTMLElement {
  constructor() {
    this.attributes = new Map();
    this.children = [];
    this.triggerListeners = new Map();
    this.classList = {
      values: new Set(),
      add: (value) => this.classList.values.add(value),
      contains: (value) => this.classList.values.has(value),
    };
    this.trigger = {
      addEventListener: (name, listener) => this.triggerListeners.set(name, listener),
    };
  }

  getAttribute(name) { return this.attributes.get(name) ?? null; }
  querySelector(selector) {
    assert.equal(selector, '.lite-youtube__btn');
    return this.trigger;
  }
  appendChild(child) { this.children.push(child); }
}

const created = [];
const document = {
  createElement(name) {
    assert.equal(name, 'iframe');
    const frame = { focusCalls: 0, focus() { this.focusCalls += 1; } };
    created.push(frame);
    return frame;
  },
};

const context = vm.createContext({ customElements, document, encodeURIComponent, HTMLElement });
vm.runInContext(source, context);
assert.ok(componentClass, 'the component registers');

const embed = new componentClass();
embed.attributes.set('videoid', 'dQw4w9WgXcQ');
embed.attributes.set('data-title', 'Fixture video');
embed.attributes.set('data-start', '30');
embed.connectedCallback();

assert.equal(created.length, 0, 'connecting the component makes no iframe or third-party request');
assert.ok(embed.triggerListeners.has('click'), 'the progressively enhanced link gets a click handler');

let prevented = 0;
embed.triggerListeners.get('click')({ preventDefault() { prevented += 1; } });
assert.equal(prevented, 1);
assert.equal(created.length, 1, 'activation creates exactly one iframe');
assert.equal(created[0].src,
  'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?autoplay=1&rel=0&start=30');
assert.equal(created[0].title, 'Fixture video');
assert.equal(created[0].referrerPolicy, 'strict-origin-when-cross-origin');
assert.equal(created[0].focusCalls, 1, 'focus follows activation into the player');

embed.triggerListeners.get('click')({ preventDefault() { prevented += 1; } });
assert.equal(created.length, 1, 'repeat activation never duplicates the iframe');

console.log('youtube-runtime: all checks passed');
