import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

const root = fileURLToPath(new URL('../../', import.meta.url));
async function peer(identity = {}) {
  const socket = new WebSocket('ws://127.0.0.1:18091');
  const queue = [];
  socket.addEventListener('message', event => queue.push(JSON.parse(event.data)));
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
  socket.send(JSON.stringify({ type: 'hello', protocol: 1, ...identity }));
  return { socket, send: value => socket.send(JSON.stringify(value)), until: async predicate => {
    for (let index = 0; index < 200; index++) { const found = queue.findIndex(predicate); if (found >= 0) return queue.splice(found, 1)[0]; await delay(10); }
    throw new Error('Motion lab reply timed out');
  } };
}
test('live lab pins Player 1, rejects another phone, rotates subscription on resume and serves its modules', async () => {
  const process = spawn(globalThis.process.env.GODOT_BIN || 'godot', ['--headless', '--path', root, '--script', 'tests/motion_lab_server.gd'], { windowsHide: true, env: { ...globalThis.process.env, PLAY_SHAPES_NETWORK_CONFIG: 'off' } });
  let output = ''; const clients = [];
  process.stdout.on('data', data => output += data); process.stderr.on('data', data => output += data);
  try {
    for (let index = 0; index < 100 && !output.includes('Motion lab fixture ready'); index++) await delay(50);
    assert.ok(output.includes('Motion lab fixture ready'), output);
    for (const name of ['motion_input', 'motion_lab', 'network_config']) assert.equal((await fetch(`http://127.0.0.1:18090/${name}.js`)).status, 200);
    const one = await peer(); clients.push(one); await one.until(value => value.type === 'welcome'); one.send({ type: 'join', name: 'First phone' });
    const joined = await one.until(value => value.type === 'join_accepted'), subscription = await one.until(value => value.type === 'motion_lab');
    const two = await peer(); clients.push(two); await two.until(value => value.type === 'welcome'); two.send({ type: 'join', name: 'Second phone' }); await two.until(value => value.type === 'join_accepted');
    const diagnostics = { secure_context: true, motion_support: true, orientation_support: true, motion_permission: 'granted', orientation_permission: 'granted', state: 'live', page_protocol: 'http:', hostname: '127.0.0.1', websocket_protocol: 'ws:', websocket_status: 'open' };
    const sample = { orientation: [0,90,0], absolute: false, rotation_rate: [1,null,0], acceleration: [0,1,null], acceleration_gravity: [0,9.8,0], interval_msec: 16, screen_angle: 0, orientation_age_msec: 0, motion_age_msec: 0, orientation_hz: 60, motion_hz: 60 };
    two.send({ type: 'motion_sample', subscription_id: subscription.subscription_id, sequence: 1, sample });
    const rejected = await two.until(value => value.type === 'motion_observed'); assert.equal(rejected.samples, 0);
    one.send({ type: 'motion_status', subscription_id: subscription.subscription_id, diagnostics }); one.send({ type: 'motion_sample', subscription_id: subscription.subscription_id, sequence: 1, sample });
    const accepted = await one.until(value => value.type === 'motion_observed' && value.samples === 1); assert.equal(accepted.target, joined.player.player_id); assert.deepEqual(accepted.latest.acceleration, [0,1,null]);
    one.socket.close(); await delay(100);
    const resumed = await peer({ session_id: joined.session_id, reconnect_token: joined.reconnect_token }); clients.push(resumed);
    assert.equal((await resumed.until(value => value.type === 'welcome')).resume_status, 'resumed');
    const current = await resumed.until(value => value.type === 'motion_lab'); assert.notEqual(current.subscription_id, subscription.subscription_id);
    resumed.send({ type: 'motion_sample', subscription_id: subscription.subscription_id, sequence: 2, sample });
    assert.equal((await resumed.until(value => value.type === 'motion_observed')).samples, 0);
  } finally { for (const client of clients) client.socket.close(); process.kill(); }
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
});
