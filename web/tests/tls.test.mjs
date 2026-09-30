import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { request } from 'node:https';
import { createSecureContext } from 'node:tls';
import { createConnection } from 'node:net';
import { randomBytes, createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

const root = fileURLToPath(new URL('../../', import.meta.url));
const binary = process.env.GODOT_BIN || 'godot';
let host, ca, log = '';
before(async () => {
  for (let attempt = 0; attempt < 5; attempt++) {
  await new Promise((resolve, reject) => {
    const process = spawn(binary, ['--headless', '--path', root, '--script', 'tests/controller_tls_test.gd'], { windowsHide: true });
    let output = '';
    process.stdout.on('data', data => output += data); process.stderr.on('data', data => output += data);
    process.on('error', reject); process.on('exit', code => code === 0 && output.includes('Controller TLS credential checks passed') ? resolve() : reject(new Error(output)));
  });
  ca = readFileSync(root + 'test-results/tls/certificate.pem');
  // Godot test-only self-signed serial generation can produce ASN.1 padding
  // rejected by OpenSSL. Validate before hosting; production tooling uses mkcert.
  try { createSecureContext({ cert: ca, key: readFileSync(root + 'test-results/tls/key.pem') }); break; }
  catch (error) { if (attempt === 4) throw error; }
  }
  host = spawn(binary, ['--headless', '--path', root], { windowsHide: true, env: { ...process.env, PLAY_SHAPES_NETWORK_CONFIG: root + 'test-results/tls/network.json' } });
  host.stdout.on('data', data => log += data); host.stderr.on('data', data => log += data);
  for (let index = 0; index < 100; index++) { if (log.includes('Play Shapes ready: https')) return; await delay(100); }
  throw new Error(log);
});
after(() => { host?.kill(); assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/); });

function get(path, trust = ca, hostname = 'localhost') {
  return new Promise((resolve, reject) => {
    const req = request({ hostname, port: 18443, path, ca: trust, timeout: 5000 }, response => {
      const chunks = []; response.on('data', data => chunks.push(data));
      response.on('end', () => resolve({ status: response.statusCode, body: Buffer.concat(chunks) }));
    }); req.on('error', reject); req.on('timeout', () => req.destroy(new Error('TLS request timeout'))); req.end();
  });
}

function connectSocket() {
  return new Promise((resolve, reject) => {
    const key = randomBytes(16).toString('base64');
    const req = request({ hostname: 'localhost', port: 18444, path: '/', ca, headers: { Upgrade: 'websocket', Connection: 'Upgrade', 'Sec-WebSocket-Key': key, 'Sec-WebSocket-Version': '13' } });
    req.on('error', reject);
    req.on('upgrade', (response, socket, head) => {
      assert.equal(response.headers['sec-websocket-accept'], createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64'));
      let input = head; const messages = [], waiters = [];
      socket.on('error', reject);
      socket.on('data', chunk => {
        input = Buffer.concat([input, chunk]);
        while (input.length >= 2) {
          let size = input[1] & 127, offset = 2;
          if (size === 126) { if (input.length < 4) return; size = input.readUInt16BE(2); offset = 4; }
          if (input.length < offset + size) return;
          const opcode = input[0] & 15, payload = input.subarray(offset, offset + size); input = input.subarray(offset + size);
          if (opcode === 1) { const message = JSON.parse(payload.toString()); const waiter = waiters.shift(); if (waiter) waiter(message); else messages.push(message); }
        }
      });
      resolve({ close: () => socket.destroy(), send: value => {
        const payload = Buffer.from(JSON.stringify(value)), mask = randomBytes(4);
        const header = Buffer.alloc(payload.length < 126 ? 2 : 4); header[0] = 0x81;
        header[1] = 0x80 | (payload.length < 126 ? payload.length : 126); if (payload.length >= 126) header.writeUInt16BE(payload.length, 2);
        socket.write(Buffer.concat([header, mask, Buffer.from(payload.map((value, index) => value ^ mask[index % 4]))]));
      }, next: () => messages.length ? Promise.resolve(messages.shift()) : new Promise((resolve, reject) => {
        const timeout = setTimeout(() => reject(new Error('WSS reply timeout')), 5000);
        waiters.push(value => { clearTimeout(timeout); resolve(value); });
      }) });
    }); req.end();
  });
}

test('verified HTTPS serves assets and WSS joins then resumes a registered player', async () => {
  for (const path of ['/', '/app.js', '/network_config.js', '/squircle-v1/idle-front-colorable.png']) {
    const response = await get(path); assert.equal(response.status, 200); assert.ok(response.body.length > 0);
  }
  const config = JSON.parse((await get('/session.json')).body); assert.equal(config.websocket_scheme, 'wss');
  const first = await connectSocket(); first.send({ type: 'hello', protocol: 1 }); assert.equal((await first.next()).type, 'welcome');
  first.send({ type: 'join', name: 'TLS tester' }); const joined = await first.next(); assert.equal(joined.type, 'join_accepted'); first.close();
  await delay(100);
  const resumed = await connectSocket(); resumed.send({ type: 'hello', protocol: 1, session_id: joined.session_id, reconnect_token: joined.reconnect_token });
  const welcome = await resumed.next(); assert.equal(welcome.resume_status, 'resumed'); assert.equal(welcome.player.player_id, joined.player.player_id); resumed.close();
});
test('unknown trust and wrong hostname are rejected; stalled TLS does not stop serving', async () => {
  await assert.rejects(get('/', null), /certificate|self.signed/i);
  await assert.rejects(get('/', ca, '127.0.0.1'), /altname|Hostname|IP/i);
  const stalled = createConnection({ host: '127.0.0.1', port: 18443 });
  await delay(100); assert.equal((await get('/session.json')).status, 200); stalled.destroy();
});
