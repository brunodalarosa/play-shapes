import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

const root = fileURLToPath(new URL('../../', import.meta.url));
const binary = process.env.GODOT_BIN ?? 'C:/Users/backup pc/Documents/Godot/Godot_v4.7.2-stable_win64_console.exe';
const port = 8090;
let host;
let output = '';

before(async () => {
  await assert.rejects(fetch(`http://127.0.0.1:${port}`, { signal: AbortSignal.timeout(500) }));
  host = spawn(binary, ['--headless', '--path', root, '--script', 'tests/bubbles_phone_preview.gd'], {
    windowsHide: true, env: { ...process.env, BUBBLES_PREVIEW_PORT: String(port) }
  });
  host.stdout.on('data', data => { output += data; });
  host.stderr.on('data', data => { output += data; });
  host.on('error', error => { output += error.message; });
  for (let attempt = 0; attempt < 100; attempt++) {
    if (output.includes(`Bubbles phone preview ready: join at http://127.0.0.1:${port}`)) return;
    if (host.exitCode !== null || output.includes('SCRIPT ERROR')) break;
    await delay(100);
  }
  throw new Error(`Bubbles preview did not boot: ${output}`);
});

after(() => {
  host?.kill();
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
});

function connect() {
  return new Promise((resolve, reject) => {
    const peer = new WebSocket(`ws://127.0.0.1:${port + 1}`);
    const messages = [];
    const waiters = [];
    peer.onmessage = event => {
      const message = JSON.parse(event.data);
      const index = waiters.findIndex(waiter => waiter.predicate(message));
      if (index < 0) messages.push(message);
      else waiters.splice(index, 1)[0].resolve(message);
    };
    peer.onerror = reject;
    peer.onopen = () => resolve({
      peer,
      send: value => peer.send(JSON.stringify(value)),
      next: predicate => new Promise((done, fail) => {
        const index = messages.findIndex(predicate);
        if (index >= 0) return done(messages.splice(index, 1)[0]);
        const waiter = { predicate, resolve: message => { clearTimeout(timeout); done(message); } }; waiters.push(waiter);
        const timeout = setTimeout(() => { const position = waiters.indexOf(waiter); if (position >= 0) { waiters.splice(position, 1); fail(new Error(`Timed out waiting for message; queued ${JSON.stringify(messages)}`)); } }, 7000);
      })
    });
  });
}

test('active Bubbles routes authenticated traces, rejects forged input, and restores reconnect state', async () => {
  const client = await connect();
  let resumed;
  try {
    client.send({ type: 'hello', protocol: 1 });
    const welcome = await client.next(message => message.type === 'welcome');
    assert.equal(welcome.resume_status, 'join_required');
    client.send({ type: 'join', name: 'Protocol Tester' });
    const joined = await client.next(message => message.type === 'join_accepted');
    const snapshot = await client.next(message => message.type === 'bubbles_snapshot' && message.score === 8);
    assert.equal(snapshot.visual_jellyfish, 8);
    assert.equal(snapshot.phase, 'active');
    assert.equal(snapshot.debug_mode, true);
    assert.equal(snapshot.seat, joined.player.seat);
    const trace = [[0.1, 0.5], [0.9, 0.5]];
    client.send({ type: 'bubbles_charge', input_seq: 1, stage: 'start', step: 0, player_id: 'forged' });
    assert.equal((await client.next(message => message.type === 'error')).code, 'unauthorized_field');
    client.send({ type: 'bubbles_charge', input_seq: 1, stage: 'start', step: 0 });
    client.send({ type: 'bubbles_charge', input_seq: 1, stage: 'progress', step: 2 });
    client.send({ type: 'bubbles_charge', input_seq: 1, stage: 'progress', step: 1 });
    assert.equal((await client.next(message => message.type === 'error')).code, 'stale_charge');
    client.send({ type: 'bubbles_trace', input_seq: 1, trace, player_id: 'forged' });
    assert.equal((await client.next(message => message.type === 'error')).code, 'unauthorized_field');
    client.send({ type: 'bubbles_trace', input_seq: 1, trace });
    const result = await client.next(message => message.type === 'bubbles_trace_result');
    assert.equal(result.action, 'swipe');
    assert.equal(result.charge, 0);
    client.send({ type: 'bubbles_trace', input_seq: 1, trace });
    assert.equal((await client.next(message => message.type === 'error')).code, 'stale_or_invalid_sequence');
    const fullTrace = Array.from({ length: 128 }, (_, index) => [0.1 + index * 0.8 / 127, 0.5]);
    client.send({ type: 'bubbles_trace', input_seq: 2, trace: fullTrace });
    assert.equal((await client.next(message => message.type === 'bubbles_trace_result')).action, 'swipe');
    client.send({ type: 'pose_down', direction: 'left', input_seq: 2 });
    assert.equal((await client.next(message => message.type === 'error')).code, 'game_unavailable');
    client.peer.close();
    resumed = await connect();
    resumed.send({ type: 'hello', protocol: 1, session_id: joined.session_id, reconnect_token: joined.reconnect_token });
    const restored = await resumed.next(message => message.type === 'welcome');
    assert.equal(restored.resume_status, 'resumed');
    assert.equal(restored.gameplay.type, 'bubbles_snapshot');
    assert.equal(restored.gameplay.score, 8);
  } finally { client.peer.close(); resumed?.peer.close(); }
});
