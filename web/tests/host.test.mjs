import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import jsQR from 'jsqr';
import { PNG } from 'pngjs';
import { createConnection } from 'node:net';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

const root = fileURLToPath(new URL('../../', import.meta.url));
const binary = process.env.GODOT_BIN ?? 'C:/Users/backup pc/Documents/Godot/Godot_v4.7.2-stable_win64_console.exe';
const base = 'http://127.0.0.1:8080';
let host;
let output = '';

before(async () => {
  // Refuse to test a different running session by accident.
  await assert.rejects(fetch(base, { signal: AbortSignal.timeout(500) }));
  await new Promise((resolve, reject) => {
    const check = spawn(binary, ['--headless', '--path', root, '--script', 'tests/foundation.gd'], { windowsHide: true });
    let log = '';
    const timeout = setTimeout(() => { check.kill(); reject(new Error('Foundation check timed out')); }, 15000);
    check.stdout.on('data', data => { log += data; });
    check.stderr.on('data', data => { log += data; });
    check.on('error', reject);
    check.on('exit', code => {
      clearTimeout(timeout);
      if (code !== 0 || /ERROR:/.test(log) || !log.includes('Foundation checks passed')) reject(new Error(log));
      else resolve();
    });
  });
  host = spawn(binary, ['--headless', '--path', root], { windowsHide: true });
  host.stdout.on('data', data => { output += data; });
  host.stderr.on('data', data => { output += data; });
  host.on('error', error => { output += error.message; });
  for (let attempt = 0; attempt < 100; attempt++) {
    if (output.includes('Play Shapes ready:')) return;
    if (host.exitCode !== null || output.includes('SCRIPT ERROR')) break;
    await delay(100);
  }
  throw new Error(`Host did not boot: ${output}`);
});

after(async () => {
  host?.kill();
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
});

test('serves bundled HTML, JS, CSS and session configuration', async () => {
  for (const [path, mime, text] of [
    ['/', 'text/html', 'Hello world'], ['/app.js', 'text/javascript', 'WebSocket'],
    ['/style.css', 'text/css', 'color-scheme'], ['/session.json', 'application/json', 'websocket_port']
  ]) {
    const response = await fetch(base + path);
    assert.equal(response.status, 200);
    assert.ok(response.headers.get('content-type').startsWith(mime));
    assert.ok((await response.text()).includes(text));
  }
});

test('lobby QR texture decodes to the exact join URL', () => {
  const png = PNG.sync.read(readFileSync(new URL('../../test-results/join-qr.png', import.meta.url)));
  const decoded = jsQR(new Uint8ClampedArray(png.data), png.width, png.height);
  assert.equal(decoded?.data, 'http://192.168.1.50:8080');
});

test('rejects unknown paths and unsupported methods', async () => {
  for (const path of ['/missing', '/host/session_host.gd', '/%2e%2e/project.godot']) {
    assert.equal((await fetch(base + path)).status, 404);
  }
  assert.equal((await fetch(base, { method: 'POST', body: '{}' })).status, 405);
});

function rawRequest(chunks) {
  return new Promise((resolve, reject) => {
    const peer = createConnection(8080, '127.0.0.1');
    let result = '';
    peer.setTimeout(7000, () => peer.destroy(new Error('HTTP timeout')));
    peer.on('error', error => {
      // Closing an oversized request with unread bytes can reset TCP on Windows.
      if (error.code === 'ECONNRESET' && chunks.join('').length > 8192) resolve(result || 'RESET');
      else reject(error);
    });
    peer.on('data', data => { result += data; });
    peer.on('end', () => resolve(result));
    peer.on('connect', async () => {
      for (const chunk of chunks) { peer.write(chunk); await delay(30); }
    });
  });
}

test('handles fragmented requests and rejects oversized headers', async () => {
  assert.match(await rawRequest(['GET / HTTP/1.1\r\nHost:', ' localhost\r\n\r\n']), /200 OK[\s\S]*Hello world/);
  assert.match(await rawRequest(['GET / HTTP/1.1\r\nX: ' + 'a'.repeat(9000)]), /431 Request|^RESET$/);
});

function connect(message) {
  return new Promise((resolve, reject) => {
    const peer = new WebSocket('ws://127.0.0.1:8081');
    const timeout = setTimeout(() => { peer.close(); reject(new Error('WebSocket timeout')); }, 7000);
    peer.onopen = () => peer.send(message);
    peer.onmessage = event => { clearTimeout(timeout); resolve({ peer, welcome: JSON.parse(event.data) }); };
    peer.onclose = event => { clearTimeout(timeout); resolve({ code: event.code }); };
    peer.onerror = () => { clearTimeout(timeout); reject(new Error('WebSocket failed')); };
  });
}

test('host assigns unique connection IDs to simultaneous browser clients', async () => {
  const clients = await Promise.all(Array.from({ length: 4 }, () => connect(JSON.stringify({ type: 'hello', protocol: 1 }))));
  try {
    for (const client of clients) {
      assert.equal(client.welcome.type, 'welcome');
      assert.equal(client.welcome.message, 'Hello world');
      assert.equal(client.welcome.protocol, 1);
    }
    assert.equal(new Set(clients.map(client => client.welcome.connection_id)).size, 4);
  } finally { clients.forEach(client => client.peer?.close()); }
});

test('rejects malformed messages and client-authored state', async () => {
  for (const message of ['garbage', '{}', '{"type":"hello","protocol":99}', '{"type":"set_state","score":99}']) {
    assert.equal((await connect(message)).code, 1008);
  }
});
