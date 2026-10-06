import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { setTimeout as delay } from "node:timers/promises";

const root = fileURLToPath(new URL("../../", import.meta.url));
async function peer(identity = {}) {
  const socket = new WebSocket("ws://127.0.0.1:18341");
  const queue = [];
  socket.addEventListener("message", (event) => queue.push(JSON.parse(event.data)));
  await new Promise((resolve, reject) => {
    socket.onopen = resolve;
    socket.onerror = reject;
  });
  socket.send(JSON.stringify({ type: "hello", protocol: 1, ...identity }));
  return {
    socket,
    send: (value) => socket.send(JSON.stringify(value)),
    until: async (predicate) => {
      for (let index = 0; index < 300; index++) {
        const found = queue.findIndex(predicate);
        if (found >= 0) return queue.splice(found, 1)[0];
        await delay(10);
      }
      throw new Error("Multiplayer motion reply timed out");
    },
  };
}
const diagnostics = {
  secure_context: true,
  motion_support: true,
  orientation_support: true,
  motion_permission: "unknown",
  orientation_permission: "unknown",
  state: "live",
  page_protocol: "https:",
  hostname: "127.0.0.1",
  websocket_protocol: "wss:",
  websocket_status: "open",
};
const sample = (index) => ({
  orientation: [index, 0, 80],
  absolute: false,
  rotation_rate: [0, 0, 0],
  acceleration: [0, 0, 0],
  acceleration_gravity: [0, 0, 9.8],
  interval_msec: 16.667,
  screen_angle: 90,
  orientation_age_msec: 0,
  motion_age_msec: 0,
  orientation_hz: 60,
  motion_hz: 60,
});
test("ten live sockets isolate samples/calibration, reject obsolete generations and coalesce bursts", async () => {
  const process = spawn(
    globalThis.process.env.GODOT_BIN || "godot",
    ["--headless", "--path", root, "--script", "tests/multiplayer_motion_server.gd"],
    {
      windowsHide: true,
      env: { ...globalThis.process.env, PLAY_SHAPES_NETWORK_CONFIG: "off" },
    },
  );
  let output = "";
  const clients = [],
    identities = [],
    subscriptions = [];
  process.stdout.on("data", (data) => (output += data));
  process.stderr.on("data", (data) => (output += data));
  try {
    for (
      let index = 0;
      index < 100 && !output.includes("Multiplayer motion fixture ready");
      index++
    )
      await delay(50);
    assert.ok(output.includes("Multiplayer motion fixture ready"), output);
    for (let index = 0; index < 10; index++) {
      const client = await peer();
      clients.push(client);
      await client.until((value) => value.type === "welcome");
      client.send({ type: "join", name: `Phone ${index}` });
      identities.push(await client.until((value) => value.type === "join_accepted"));
    }
    for (const client of clients)
      subscriptions.push(await client.until((value) => value.type === "motion_subscribe"));
    assert.equal(new Set(subscriptions.map((value) => value.subscription_id)).size, 10);
    for (let index = 0; index < 10; index++) {
      const client = clients[index],
        subscription_id = subscriptions[index].subscription_id;
      client.send({ type: "motion_status", subscription_id, diagnostics });
      client.send({ type: "motion_sample", subscription_id, sequence: 1, sample: sample(index) });
      client.send({ type: "motion_calibrate", subscription_id });
    }
    for (let index = 0; index < 10; index++) {
      const observed = await clients[index].until(
        (value) =>
          value.type === "motion_observed" && value.samples === 1 && value.state.calibrated,
      );
      assert.equal(observed.latest.orientation[0], index);
      assert.equal(observed.state.usable, true);
    }
    await delay(60);
    clients[1].send({
      type: "motion_sample",
      subscription_id: subscriptions[0].subscription_id,
      sequence: 2,
      sample: sample(999),
    });
    clients[0].send({
      type: "motion_sample",
      subscription_id: subscriptions[0].subscription_id,
      sequence: 2,
      player_id: identities[1].player.player_id,
      sample: sample(999),
    });
    await delay(60);
    clients[0].send({
      type: "motion_sample",
      subscription_id: subscriptions[0].subscription_id,
      sequence: 2,
      sample: sample(222),
    });
    clients[0].send({
      type: "motion_sample",
      subscription_id: subscriptions[0].subscription_id,
      sequence: 3,
      sample: sample(333),
    });
    const newest = await clients[0].until(
      (value) => value.type === "motion_observed" && value.latest.orientation?.[0] === 333,
    );
    assert.ok(newest.samples <= 3);
    assert.equal(
      (await clients[1].until((value) => value.type === "motion_observed" && value.samples === 1))
        .latest.orientation[0],
      1,
    );
    const resumed = await peer({
      session_id: identities[0].session_id,
      reconnect_token: identities[0].reconnect_token,
    });
    clients.push(resumed);
    assert.equal(
      (await resumed.until((value) => value.type === "welcome")).resume_status,
      "resumed",
    );
    const subscription = await resumed.until((value) => value.type === "motion_subscribe");
    assert.notEqual(subscription.subscription_id, subscriptions[0].subscription_id);
    resumed.send({
      type: "motion_sample",
      subscription_id: subscriptions[0].subscription_id,
      sequence: 4,
      sample: sample(999),
    });
    await delay(60);
    const retired = await resumed.until(
      (value) => value.type === "motion_observed" && value.samples === 0,
    );
    assert.equal(retired.state.calibrated, true);
    assert.deepEqual(retired.latest, {});
    resumed.send({
      type: "motion_status",
      subscription_id: subscription.subscription_id,
      diagnostics,
    });
    resumed.send({
      type: "motion_sample",
      subscription_id: subscription.subscription_id,
      sequence: 1,
      sample: sample(42),
    });
    const accepted = await resumed.until(
      (value) => value.type === "motion_observed" && value.samples === 1,
    );
    assert.equal(accepted.latest.orientation[0], 42);
  } finally {
    for (const client of clients) client.socket.close();
    process.kill();
  }
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
});
