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
const binary = process.env.GODOT_BIN || 'godot';
const base = 'http://127.0.0.1:8080';
let host;
let output = '';

before(async () => {
  // Refuse to test a different running session by accident.
  await assert.rejects(fetch(base, { signal: AbortSignal.timeout(500) }));
  await new Promise((resolve, reject) => {
    const check = spawn(binary, ['--headless', '--path', root, '--script', 'tests/foundation.gd'], { windowsHide: true, env: { ...process.env, PLAY_SHAPES_NETWORK_CONFIG: "off" } });
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
  host = spawn(binary, ['--headless', '--path', root], { windowsHide: true, env: { ...process.env, PLAY_SHAPES_NETWORK_CONFIG: "off" } });
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
    ['/', 'text/html', 'PLAY SHAPES'], ['/app.js', 'text/javascript', 'localStorage'],
    ['/immersive.js', 'text/javascript', 'attemptImmersive'],
    ['/pwa.js', 'text/javascript', 'PwaOnboarding'],
    ['/manifest.webmanifest', 'application/manifest+json', 'standalone'],
    ...[180, 192, 512].map(size => [`/app-icon-${size}.png`, 'image/png', null]),
    ['/bubbles_gesture.js', 'text/javascript', 'GestureTrace'],
    ['/lobby_controls.js', 'text/javascript', 'lockX'],
    ['/lobby_input.js', 'text/javascript', 'LobbyInputState'],
    ['/squircle_v1.js', 'text/javascript', 'SquircleV1Canvas'],
    ['/vendor/nipplejs.mjs', 'text/javascript', 'create'],
    ['/bubbles-jellyfish.png', 'image/png', null],
    ['/style.css', 'text/css', 'focus-visible'], ['/session.json', 'application/json', 'session_id']
  ]) {
    try {
      const response = await fetch(base + path);
      assert.equal(response.status, 200);
      assert.equal(response.headers.get('cache-control'), 'no-store');
      assert.ok(response.headers.get('content-type').startsWith(mime));
      if (text) assert.ok((await response.text()).includes(text));
      else await response.arrayBuffer();
    } catch (error) { throw new Error(`Failed to serve ${path}`, { cause: error }); }
  }
});

test('manifest has stable origin-local identity and correctly sized bundled icons', async () => {
  const manifest = await (await fetch(base + '/manifest.webmanifest')).json();
  assert.equal(manifest.id, '/'); assert.equal(manifest.start_url, '/'); assert.equal(manifest.scope, '/');
  assert.equal(manifest.display, 'standalone'); assert.equal(manifest.orientation, 'portrait');
  for (const size of [180, 192, 512]) {
    const response = await fetch(`${base}/app-icon-${size}.png`);
    const image = PNG.sync.read(Buffer.from(await response.arrayBuffer()));
    assert.equal(image.width, size); assert.equal(image.height, size);
    if (size !== 180) assert.ok(manifest.icons.some(icon => icon.src === `/app-icon-${size}.png` && icon.sizes === `${size}x${size}`));
  }
  const html = await (await fetch(base)).text();
  assert.match(html, /rel="manifest" href="\/manifest.webmanifest"/);
  assert.match(html, /rel="apple-touch-icon" href="\/app-icon-180.png"/);
  assert.doesNotMatch(html, /user-scalable=no|maximum-scale=1/);
});

test('phone join form has labels, live feedback, and explicit change-player action', async () => {
  const html = await (await fetch(base)).text();
  assert.match(html, /<label for="player-name">Your name<\/label>/);
  assert.match(html, /id="status"[^>]*role="status"[^>]*aria-live="polite"/);
  assert.match(html, />Leave \/ Change player<\/button>/);
  assert.match(html, /maxlength="16"/);
});

test('Bubbles controller keeps a clean portrait screen and accessible touch controls', async () => {
  const html = await (await fetch(base)).text();
  const css = await (await fetch(base + '/style.css')).text();
  const js = await (await fetch(base + '/app.js')).text();
  assert.match(html, /id="bubbles-pad"[^>]*role="button"[^>]*tabindex="0"[^>]*aria-label=/);
  assert.match(html, /id="bubbles-help" class="visually-hidden"/);
  assert.match(html, /id="bubbles-score" aria-live="polite">0<\/span>/);
  assert.match(html, /id="bubbles-visual"[^>]*aria-hidden="true"/);
  assert.doesNotMatch(html, /bubbles-status|bubbles-debug|bubbles-meter|bubbles-state/);
  assert.match(css, /inset-block-start: 15%/);
  assert.match(css, /env\(safe-area-inset-top\)/);
  assert.match(css, /bubbles-phone-background\.png/);
  assert.doesNotMatch(css, /#bubbles-status|#bubbles-debug|\.debug-badge/);
  assert.match(css, /html\.bubbles-active/);
  for (const expected of ['bubbles_trace', 'pointercancel', 'lostpointercapture', 'bubbles_trace_result', 'bubbles_snapshot', 'bubbles_visual', 'portrait', 'navigator.vibrate']) {
    assert.ok(js.includes(expected), `compiled controller should include ${expected}`);
  }
});

test('Playground controller is locally bundled, portrait safe, and touch-accessible', async () => {
  const html = await (await fetch(base)).text();
  const css = await (await fetch(base + '/style.css')).text();
  const controls = await (await fetch(base + '/lobby_controls.js')).text();
  assert.match(html, /id="lobby-stick-zone"[^>]*aria-label="Move left or right"/);
  assert.match(html, /id="lobby-jump-button"[^>]*aria-label="Jump"/);
  assert.match(css, /#lobby-stick-zone, #lobby-jump-button[^}]*safe-area-inset-bottom/);
  assert.match(controls, /vendor\/nipplejs\.mjs/);
  assert.match(controls, /lockX: true/);
  assert.match(controls, /pointercancel/);
  assert.match(controls, /lostpointercapture/);
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
  assert.match(await rawRequest(['GET / HTTP/1.1\r\nHost:', ' localhost\r\n\r\n']), /200 OK[\s\S]*PLAY SHAPES/);
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

function request(peer, message) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('WebSocket response timed out')), 7000);
    peer.addEventListener('message', event => {
      clearTimeout(timeout);
      resolve(JSON.parse(event.data));
    }, { once: true });
    peer.send(JSON.stringify(message));
  });
}

test('host assigns unique connection IDs to simultaneous browser clients', async () => {
  const clients = await Promise.all(Array.from({ length: 4 }, () => connect(JSON.stringify({ type: 'hello', protocol: 1 }))));
  try {
    for (const client of clients) {
      assert.equal(client.welcome.type, 'welcome');
      assert.equal(client.welcome.resume_status, 'join_required');
      assert.equal(client.welcome.protocol, 1);
      assert.equal(typeof client.welcome.session_id, 'string');
    }
    assert.equal(new Set(clients.map(client => client.welcome.connection_id)).size, 4);
  } finally { clients.forEach(client => client.peer?.close()); }
});

test('supports ten simultaneous protocol-1 browser clients', async () => {
  // Connect sequentially so this checks ten live peers rather than the OS TCP
  // accept backlog, which is deliberately outside the gameplay player limit.
  const clients = [];
  for (let index = 0; index < 10; index++) {
    clients.push(await connect(JSON.stringify({ type: 'hello', protocol: 1 })));
  }
  try {
    assert.equal(new Set(clients.map(client => client.welcome.connection_id)).size, 10);
    assert.ok(clients.every(client => client.welcome.protocol === 1));
  } finally { clients.forEach(client => client.peer?.close()); }
});

test('rejects malformed messages and client-authored state', async () => {
  for (const message of ['garbage', '{}', '{"type":"hello","protocol":99}', '{"type":"set_state","score":99}']) {
    assert.equal((await connect(message)).code, 1008);
  }
});

test('joins, rejects duplicate names, resumes, leaves, and invalidates identity', async () => {
  const first = await connect(JSON.stringify({ type: 'hello', protocol: 1 }));
  const second = await connect(JSON.stringify({ type: 'hello', protocol: 1 }));
  let resumed;
  let afterLeave;
  try {
    const joined = await request(first.peer, { type: 'join', name: '  Player One  ', player_id: 'client-choice' });
    assert.equal(joined.type, 'join_accepted');
    assert.equal(joined.player.name, 'Player One');
    assert.notEqual(joined.player.player_id, 'client-choice');
    assert.notEqual(joined.player.player_id, String(first.welcome.connection_id));
    assert.notEqual(joined.reconnect_token, joined.player.player_id);

    const duplicate = await request(second.peer, { type: 'join', name: 'PLAYER ONE' });
    assert.equal(duplicate.type, 'join_rejected');
    assert.equal(duplicate.code, 'duplicate_name');
    assert.equal(duplicate.message, 'Name already in use');

    first.peer.close();
    await delay(100);
    resumed = await connect(JSON.stringify({
      type: 'hello', protocol: 1,
      session_id: joined.session_id, reconnect_token: joined.reconnect_token
    }));
    assert.equal(resumed.welcome.resume_status, 'resumed');
    assert.equal(resumed.welcome.player.player_id, joined.player.player_id);
    assert.equal(resumed.welcome.player.seat, joined.player.seat);

    assert.equal((await request(resumed.peer, { type: 'leave' })).type, 'left');
    afterLeave = await connect(JSON.stringify({
      type: 'hello', protocol: 1,
      session_id: joined.session_id, reconnect_token: joined.reconnect_token
    }));
    assert.equal(afterLeave.welcome.resume_status, 'expired');
    const reused = await request(afterLeave.peer, { type: 'join', name: 'player one' });
    assert.equal(reused.type, 'join_accepted');
    await request(afterLeave.peer, { type: 'leave' });
  } finally {
    first.peer?.close();
    second.peer?.close();
    resumed?.peer?.close();
    afterLeave?.peer?.close();
  }
});

test('host accepts sequenced lobby intent only from its registered connection', async () => {
  const player = await connect(JSON.stringify({ type: 'hello', protocol: 1 }));
  const stranger = await connect(JSON.stringify({ type: 'hello', protocol: 1 }));
  let resumed;
  try {
    assert.equal((await request(stranger.peer, { type: 'lobby_move', input_seq: 1, horizontal: 1 })).code, 'not_joined');
    const joined = await request(player.peer, {
      type: 'join', name: 'Lobby Input Test', character_shape: 'square', character_color: '#EC407A'
    });
    assert.equal(joined.type, 'join_accepted');
    assert.equal(joined.player.character_shape, 'squircle');
    player.peer.send(JSON.stringify({ type: 'lobby_move', input_seq: 1, horizontal: 0.65 }));
    assert.equal((await request(player.peer, { type: 'lobby_move', input_seq: 1, horizontal: -1 })).code, 'stale_sequence');
    assert.equal((await request(player.peer, { type: 'lobby_move', input_seq: 2, horizontal: 1.5 })).code, 'invalid_movement');
    player.peer.send(JSON.stringify({ type: 'lobby_jump_release', input_seq: 2 }));
    assert.equal((await request(player.peer, { type: 'lobby_jump_release', input_seq: 2 })).code, 'stale_sequence');
    resumed = await connect(JSON.stringify({
      type: 'hello', protocol: 1, session_id: joined.session_id, reconnect_token: joined.reconnect_token
    }));
    assert.equal(resumed.welcome.player.player_id, joined.player.player_id);
    resumed.peer.send(JSON.stringify({ type: 'lobby_move', input_seq: 1, horizontal: -0.3 }));
    assert.equal((await request(resumed.peer, { type: 'lobby_move', input_seq: 1, horizontal: 1 })).code, 'stale_sequence');
    await request(resumed.peer, { type: 'leave' });
    assert.equal((await request(resumed.peer, { type: 'lobby_move', input_seq: 3, horizontal: 1 })).code, 'not_joined');
  } finally { player.peer.close(); stranger.peer.close(); resumed?.peer.close(); }
});

test('returns actionable protocol errors after the handshake', async () => {
  const client = await connect(JSON.stringify({ type: 'hello', protocol: 1 }));
  try {
    const invalidName = await request(client.peer, { type: 'join', name: 'Line\nBreak' });
    assert.deepEqual(
      { type: invalidName.type, code: invalidName.code, message: invalidName.message },
      { type: 'join_rejected', code: 'invalid_name', message: 'Name cannot contain control characters' }
    );
    const unsupported = await request(client.peer, { type: 'set_state', score: 99 });
    assert.equal(unsupported.type, 'error');
    assert.equal(unsupported.code, 'unsupported_message');
  } finally { client.peer.close(); }
});

test('distinguishes a token from a different host session', async () => {
  const client = await connect(JSON.stringify({
    type: 'hello', protocol: 1, session_id: 'old-session', reconnect_token: 'old-token'
  }));
  try {
    assert.equal(client.welcome.resume_status, 'session_restarted');
    assert.match(client.welcome.message, /new session/i);
  } finally { client.peer.close(); }
});
