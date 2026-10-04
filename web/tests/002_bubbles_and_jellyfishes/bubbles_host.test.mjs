import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { setTimeout as delay } from "node:timers/promises";
import { PNG } from "pngjs";

const root = fileURLToPath(new URL("../../../", import.meta.url));
const binary = process.env.GODOT_BIN || "godot";
const port = 8090;
let host;
let output = "";

async function startPreview() {
  await assert.rejects(fetch(`http://127.0.0.1:${port}`, { signal: AbortSignal.timeout(500) }));
  host = spawn(
    binary,
    [
      "--headless",
      "--path",
      root,
      "--script",
      "minigames/002_bubbles_and_jellyfishes/tests/bubbles_phone_preview.gd",
    ],
    {
      windowsHide: true,
      env: {
        ...process.env,
        BUBBLES_PREVIEW_PORT: String(port),
        PLAY_SHAPES_NETWORK_CONFIG: "off",
      },
    },
  );
  host.stdout.on("data", (data) => {
    output += data;
  });
  host.stderr.on("data", (data) => {
    output += data;
  });
  host.on("error", (error) => {
    output += error.message;
  });
  for (let attempt = 0; attempt < 100; attempt++) {
    if (output.includes(`Bubbles phone preview ready: join at http://127.0.0.1:${port}`)) {
      try {
        const response = await fetch(`http://127.0.0.1:${port}/session.json`, {
          signal: AbortSignal.timeout(500),
        });
        if (response.ok) return;
      } catch {
        /* Wait for the HTTP listener as well as the startup message. */
      }
    }
    if (host.exitCode !== null || output.includes("SCRIPT ERROR")) break;
    await delay(100);
  }
  throw new Error(`Bubbles preview did not boot: ${output}`);
}

async function stopPreview() {
  const currentHost = host;
  host = undefined;
  if (currentHost && currentHost.exitCode === null) {
    const exited = new Promise((resolve) => currentHost.once("exit", resolve));
    currentHost.kill();
    await exited;
  }
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
}

function connect() {
  return new Promise((resolve, reject) => {
    const peer = new WebSocket(`ws://127.0.0.1:${port + 1}`);
    const messages = [];
    const waiters = [];
    peer.onmessage = (event) => {
      const message = JSON.parse(event.data);
      const index = waiters.findIndex((waiter) => waiter.predicate(message));
      if (index < 0) messages.push(message);
      else waiters.splice(index, 1)[0].resolve(message);
    };
    peer.onerror = reject;
    peer.onopen = () =>
      resolve({
        peer,
        send: (value) => peer.send(JSON.stringify(value)),
        next: (predicate) =>
          new Promise((done, fail) => {
            const index = messages.findIndex(predicate);
            if (index >= 0) return done(messages.splice(index, 1)[0]);
            const waiter = {
              predicate,
              resolve: (message) => {
                clearTimeout(timeout);
                done(message);
              },
            };
            waiters.push(waiter);
            const timeout = setTimeout(() => {
              const position = waiters.indexOf(waiter);
              if (position >= 0) {
                waiters.splice(position, 1);
                fail(
                  new Error(`Timed out waiting for message; queued ${JSON.stringify(messages)}`),
                );
              }
            }, 7000);
          }),
      });
  });
}

test("active Bubbles routes authenticated traces, rejects forged input, and restores reconnect state", async () => {
  try {
    await startPreview();
    await verifyPhoneJoinAndAssets();
    const client = await connect();
    let resumed;
    try {
      client.send({ type: "hello", protocol: 1 });
      const welcome = await client.next((message) => message.type === "welcome");
      assert.equal(welcome.resume_status, "join_required");
      client.send({
        type: "join",
        name: "Protocol Tester",
        character_shape: "triangle",
        character_color: "#E53935",
      });
      const rejectedSelection = await client.next((message) => message.type === "join_rejected");
      assert.equal(rejectedSelection.code, "invalid_character_selection");
      client.send({
        type: "join",
        name: "Protocol Tester",
        character_shape: "rhombus",
        character_color: "#EC407A",
      });
      const joined = await client.next((message) => message.type === "join_accepted");
      assert.equal(joined.player.character_shape, "squircle");
      assert.equal(joined.player.character_color, "#EC407A");
      const snapshot = await client.next(
        (message) => message.type === "bubbles_snapshot" && message.score === 8,
      );
      assert.equal(snapshot.visual_jellyfish, 8);
      assert.equal(snapshot.phase, "active");
      assert.equal(snapshot.debug_mode, true);
      assert.equal(snapshot.seat, joined.player.seat);
      assert.equal(snapshot.character_shape, joined.player.character_shape);
      assert.equal(snapshot.character_color, joined.player.character_color);
      const trace = [
        [0.1, 0.5],
        [0.9, 0.5],
      ];
      client.send({
        type: "bubbles_charge",
        input_seq: 1,
        stage: "start",
        step: 0,
        player_id: "forged",
      });
      assert.equal(
        (await client.next((message) => message.type === "error")).code,
        "unauthorized_field",
      );
      client.send({ type: "bubbles_charge", input_seq: 1, stage: "start", step: 0 });
      client.send({ type: "bubbles_charge", input_seq: 1, stage: "progress", step: 2 });
      client.send({ type: "bubbles_charge", input_seq: 1, stage: "motion", drag: [-3, 0] });
      client.send({ type: "bubbles_charge", input_seq: 1, stage: "motion", drag: [5, 0] });
      assert.equal((await client.next((message) => message.type === "error")).code, "invalid_drag");
      client.send({ type: "bubbles_charge", input_seq: 1, stage: "progress", step: 1 });
      assert.equal((await client.next((message) => message.type === "error")).code, "stale_charge");
      client.send({ type: "bubbles_trace", input_seq: 1, trace, player_id: "forged" });
      assert.equal(
        (await client.next((message) => message.type === "error")).code,
        "unauthorized_field",
      );
      client.send({ type: "bubbles_trace", input_seq: 1, trace });
      const result = await client.next((message) => message.type === "bubbles_trace_result");
      assert.equal(result.action, "swipe");
      assert.equal(result.charge, 0);
      client.send({ type: "bubbles_trace", input_seq: 1, trace });
      assert.equal(
        (await client.next((message) => message.type === "error")).code,
        "stale_or_invalid_sequence",
      );
      const fullTrace = Array.from({ length: 128 }, (_, index) => [0.1 + (index * 0.8) / 127, 0.5]);
      client.send({ type: "bubbles_trace", input_seq: 2, trace: fullTrace });
      assert.equal(
        (await client.next((message) => message.type === "bubbles_trace_result")).action,
        "swipe",
      );
      client.send({ type: "pose_down", direction: "left", input_seq: 2 });
      assert.equal(
        (await client.next((message) => message.type === "error")).code,
        "unsupported_message",
      );
      client.peer.close();
      resumed = await connect();
      resumed.send({
        type: "hello",
        protocol: 1,
        session_id: joined.session_id,
        reconnect_token: joined.reconnect_token,
      });
      const restored = await resumed.next((message) => message.type === "welcome");
      assert.equal(restored.resume_status, "resumed");
      assert.equal(restored.gameplay.type, "bubbles_snapshot");
      assert.equal(restored.gameplay.score, 8);
      assert.equal(restored.player.character_shape, "squircle");
      assert.equal(restored.gameplay.character_shape, "squircle");
      assert.equal(restored.gameplay.character_color, "#EC407A");
    } finally {
      client.peer.close();
      resumed?.peer.close();
    }
  } finally {
    await stopPreview();
  }
});

async function verifyPhoneJoinAndAssets() {
  const request = async (path) => {
    try {
      return await fetch(`http://127.0.0.1:${port}${path}`);
    } catch (error) {
      throw new Error(`Could not request ${path}; host exit=${host?.exitCode}; output=${output}`, {
        cause: error,
      });
    }
  };
  const paths = [
    "/",
    "/style.css",
    "/bubbles-phone-background.png",
    "/app.js",
    "/squircle-v1/manifest.json",
    "/squircle-v1/idle-front-colorable.png",
    "/squircle-v1/idle-front-neutral.png",
    "/squircle-v1/idle-front-blink.png",
  ];
  const responses = [];
  for (const path of paths) responses.push(await request(path));
  for (const response of responses) assert.equal(response.status, 200);
  const [
    htmlResponse,
    cssResponse,
    backgroundResponse,
    clientResponse,
    manifestResponse,
    ...sheets
  ] = responses;
  const html = await htmlResponse.text();
  const css = await cssResponse.text();
  assert.match(html, /id="bubbles-visual"/);
  assert.match(html, /id="bubbles-score"/);
  assert.match(html, /id="selection-screen"/);
  assert.match(html, /id="name-screen"/);
  assert.doesNotMatch(html, /previous-shape|next-shape|shape-cycle/);
  assert.match(html, /Blue Squircle/);
  assert.match(html, /placeholder="Enter your name"/);
  assert.match(html, /ENTER LOBBY/);
  assert.doesNotMatch(html, /bubbles-debug|bubbles-status|bubbles-meter|bubbles-state/);
  assert.match(css, /bubbles-phone-background\.png/);
  assert.match(css, /inset-block-start: 15%/);
  assert.match(css, /grid-template-columns: repeat\(5, minmax\(0, 1fr\)\)/);
  assert.match(css, /env\(safe-area-inset-top\)/);
  const client = await clientResponse.text();
  assert.match(client, /character_shape: CHARACTER_SHAPE/);
  assert.match(client, /manifest\.json/);
  const manifest = await manifestResponse.json();
  assert.equal(manifest.shape_id, "squircle");
  assert.equal(
    manifest.clips.find((clip) => clip.name === "idle" && clip.view === "front").frames,
    48,
  );
  const background = PNG.sync.read(Buffer.from(await backgroundResponse.arrayBuffer()));
  assert.equal(background.width, 1080);
  assert.equal(background.height, 1920);
  for (const response of sheets) {
    const sheet = PNG.sync.read(Buffer.from(await response.arrayBuffer()));
    assert.equal(sheet.width, 2048);
    assert.equal(sheet.height, 1536);
  }
}
