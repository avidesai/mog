// `<mog-capture>` on the web, where there is no TrueDepth camera: it reports every check passing
// and hands over "sample", which the app answers with a sample face's readings. iOS runs the
// ARKit capture in modules/apple. Events: 8 is `message`.
export const abi = 1;
export const roster = { 'mog-capture': { snapshot: false } };

const MESSAGE = 8;

class Sample {
  constructor(element, event) {
    this.root = element.shadowRoot ?? element.attachShadow({ mode: 'open' });
    this.root.innerHTML = '<style>:host{display:block;background:#000}</style>';
    queueMicrotask(() => {
      event(MESSAGE, 'gates 111111 capture.hint_ready');
      event(MESSAGE, 'sample');
    });
  }
  setProps() {}
  destroy() {}
}

export function create(tag, element, json, event) { return new Sample(element, event); }
export function setProps(view, json) { view.setProps(JSON.parse(json)); }
export function destroy(view) { view.destroy(); }
