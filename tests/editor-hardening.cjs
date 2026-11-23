const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const test = require('node:test');
const editor = fs.readFileSync('three.js/editor/index.html', 'utf8');

test('solver stays disconnected until a valid operator selection', () => {
  let click;
  let opens = 0;
  let entered = null;
  const socket = { readyState: 3, open() { opens++; } };
  const WebSocket = { CONNECTING: 0, OPEN: 1 };
  const context = {
    document: { getElementById: () => ({ addEventListener: (_, cb) => { click = cb; } }) },
    window: { prompt: () => entered, alert() {} }, editor: { client: { socket } },
    URL, WebSocket,
  };
  vm.runInNewContext(editor.slice(editor.indexOf('const connect ='), editor.indexOf('window.editor =')), context);
  assert.equal(opens, 0);
  click();
  assert.equal(opens, 0);
  entered = 'ws://solver.example:7100';
  click();
  assert.equal(opens, 0);
  entered = 'ws://localhost:7100';
  click();
  assert.equal(opens, 1);
  assert.equal(socket.url, 'ws://localhost:7100/');
  socket.readyState = WebSocket.CONNECTING;
  click();
  assert.equal(opens, 1);
  socket.readyState = 3;
  entered = 'wss://solver.example:7100';
  click();
  assert.equal(opens, 2);
});

test('startup does not import scenes or pick a solver from page URLs', () => {
  assert.doesNotMatch(editor, /location\.(?:hash|search)|FileLoader/);
  assert.equal((editor.match(/socket\.open\(/g) || []).length, 1);
});

test('both history lists render names as plain text', () => {
  const sidebar = fs.readFileSync('three.js/editor/js/Sidebar.History.js', 'utf8');
  assert.equal((sidebar.match(/option\.textContent .* object\.name/g) || []).length, 2);
  assert.doesNotMatch(sidebar, /innerHTML .* object\.name/);
});

test('manual WebSocket wrapper starts closed and does not retry automatically', () => {
  const wrapper = fs.readFileSync('three.js/editor/js/libs/reconnecting-websocket.js', 'utf8');
  let opened = 0;
  let raw;
  class FakeSocket {
    static CLOSED = 3;
    static CONNECTING = 0;
    constructor() { opened++; raw = this; }
  }
  const document = {
    createElement: () => new EventTarget(),
    createEvent: () => ({ initCustomEvent(type) { this.type = type; } }),
  };
  document.createElement = () => ({
    addEventListener() {}, removeEventListener() {}, dispatchEvent() {},
  });
  let timers = 0;
  const context = {
    document, WebSocket: FakeSocket,
    setTimeout() { timers++; }, clearTimeout() {},
  };
  const Client = vm.runInNewContext(wrapper.replace(/export\s*\{[^}]+\};?/s, '') + '\nReconnectingWebSocket;', context);
  const client = new Client('ws://localhost:7100', null, { automaticOpen: false, maxReconnectAttempts: 0 });
  assert.equal(opened, 0);
  assert.equal(client.readyState, FakeSocket.CLOSED);
  client.open();
  assert.equal(opened, 1);
  assert.equal(client.readyState, FakeSocket.CONNECTING);
  raw.onclose({});
  assert.equal(client.readyState, FakeSocket.CLOSED);
  assert.equal(timers, 1); // Connect timeout only; no retry scheduled.
});
