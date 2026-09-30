import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

const root = fileURLToPath(new URL('../../', import.meta.url));
const binary = process.env.GODOT_BIN || 'godot';
const url = 'ws://127.0.0.1:18101';

function phone() {
  const peer = new WebSocket(url);
  const messages = [];
  const listeners = new Set();
  peer.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    messages.push(message);
    for (const listener of listeners) listener();
  });
  function next(predicate, timeoutMs = 7000) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => { listeners.delete(check); reject(new Error('Timed out waiting for phone message')); }, timeoutMs);
      function check() {
        const index = messages.findIndex(predicate);
        if (index < 0) return;
        clearTimeout(timer); listeners.delete(check); resolve(messages.splice(index, 1)[0]);
      }
      listeners.add(check); check();
    });
  }
  const opened = new Promise((resolve, reject) => {
    peer.addEventListener('open', resolve, { once: true });
    peer.addEventListener('error', reject, { once: true });
  });
  return { peer, opened, next, send: message => peer.send(JSON.stringify(message)) };
}

async function hello(client, identity = {}) {
  await client.opened;
  client.send({ type: 'hello', protocol: 1, ...identity });
  return client.next(message => message.type === 'welcome');
}

test('host ready-up accepts prior onboarding, resets reconnect, and launches Bubbles once', { timeout: 30000 }, async () => {
  const server = spawn(binary, ['--headless', '--path', root, '--script', 'tests/pre_minigame_server.gd'], { windowsHide: true, env: { ...process.env, PLAY_SHAPES_NETWORK_CONFIG: "off" } });
  let output = '';
  server.stdout.on('data', data => { output += data; });
  server.stderr.on('data', data => { output += data; });
  const clients = [];
  try {
    for (let attempt = 0; attempt < 100 && !output.includes('Ready fixture listening'); attempt++) await delay(100);
    assert.match(output, /Ready fixture listening/);
    const html = await (await fetch('http://127.0.0.1:18100')).text();
    const css = await (await fetch('http://127.0.0.1:18100/style.css')).text();
    const app = await (await fetch('http://127.0.0.1:18100/app.js')).text();
    assert.match(html, /id="ready-button"[^>]*aria-pressed="false"[^>]*aria-label="Ready up"/);
    assert.doesNotMatch(html.match(/<section id="ready-card"[\s\S]*?<\/section>/)?.[0] ?? '', /preview|instructions|booklet/i);
    assert.match(css, /html\.ready-active/);
    assert.match(app, /pre_minigame_ready/);
    const first = phone(); const pending = phone(); const second = phone();
    clients.push(first, pending, second);
    await hello(first); await hello(pending); await hello(second);
    first.send({ type: 'join', name: 'First' });
    const firstJoin = await first.next(message => message.type === 'join_accepted');
    second.send({ type: 'join', name: 'Second' });
    const secondJoin = await second.next(message => message.type === 'join_accepted');
    await first.next(message => message.type === 'pre_minigame_snapshot');
    await second.next(message => message.type === 'pre_minigame_snapshot');

    pending.send({ type: 'pre_minigame_ready', ready: true, player_id: firstJoin.player.player_id });
    assert.equal((await pending.next(message => message.type === 'error')).code, 'ready_unavailable');
    const late = phone(); clients.push(late);
    await late.opened;
    const rejected = new Promise(resolve => late.peer.addEventListener('close', event => resolve(event.code), { once: true }));
    late.send({ type: 'hello', protocol: 1 });
    assert.equal(await rejected, 1008);

    first.send({ type: 'pre_minigame_ready', ready: true });
    await first.next(message => message.type === 'pre_minigame_snapshot' && message.ready === true);
    first.send({ type: 'pre_minigame_ready', ready: false });
    await first.next(message => message.type === 'pre_minigame_snapshot' && message.ready === false);
    second.send({ type: 'pre_minigame_ready', ready: true });
    await second.next(message => message.type === 'pre_minigame_snapshot' && message.ready === true);

    pending.send({ type: 'join', name: 'Late' });
    const lateJoin = await pending.next(message => message.type === 'join_accepted');
    const lateReady = await pending.next(message => message.type === 'pre_minigame_snapshot' && message.players.length === 3);
    assert.equal(lateReady.ready, false);
    assert.deepEqual(lateReady.players.map(player => player.name), ['First', 'Second', 'Late']);
    first.send({ type: 'pre_minigame_ready', ready: true });
    await first.next(message => message.type === 'pre_minigame_snapshot' && message.ready === true);
    first.peer.close();
    await second.next(message => message.type === 'pre_minigame_snapshot'
      && message.players.find(player => player.player_id === firstJoin.player.player_id)?.state === 'reconnecting');

    const resumed = phone(); clients.push(resumed);
    const welcome = await hello(resumed, { session_id: firstJoin.session_id, reconnect_token: firstJoin.reconnect_token });
    assert.equal(welcome.resume_status, 'resumed');
    assert.equal(welcome.player.player_id, firstJoin.player.player_id);
    assert.equal(welcome.gameplay.type, 'pre_minigame_snapshot');
    assert.equal(welcome.gameplay.ready, false);
    pending.send({ type: 'pre_minigame_ready', ready: true });
    await pending.next(message => message.type === 'pre_minigame_snapshot' && message.ready === true);
    resumed.send({ type: 'pre_minigame_ready', ready: true });
    const gameplay = await resumed.next(message => message.type === 'bubbles_snapshot', 10000);
    assert.equal(gameplay.phase, 'instructions');
    assert.equal(gameplay.player_id, undefined);
    assert.equal(secondJoin.player.seat, 2);
    assert.equal(lateJoin.player.seat, 3);
  } finally {
    clients.forEach(client => client.peer.close());
    server.kill();
  }
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
});
