import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { BubbleState, choosePresentation } from "../../build/004_3d_bubbles/state.js";
import { snapshot } from "./fixtures.mjs";

test("snapshots retain exact scores and reconstruct recovery on reconnect", () => {
  const state = new BubbleState();
  state.receive(
    snapshot({ score: 127, reform_remaining_msec: 500, invulnerable_remaining_msec: 1200 }),
    10,
  );
  assert.equal(state.frame(10).snapshot.score, 127);
  assert.equal(state.frame(10).visual.radius, 0.6 * 0.08);
  assert.equal(state.frame(260).visual.radius, 0.3);
  assert.equal(state.frame(1010).visual.radius, 0.6);
  assert.equal(state.frame(1010).visual.white, true);
  assert.equal(state.frame(1210).visual.white, false);
});

test("visuals use plane axes and host time while ignoring stale packets and release results", () => {
  const state = new BubbleState();
  const visual = {
    host_time_msec: 1050,
    radius: 0.7,
    stretch: [0.2, -0.1],
    velocity: [0.8, 0.2],
    white: true,
    pop_age_msec: 20,
    caught: 6,
  };
  assert.equal(state.receive({ type: "bubbles_3d_visual", visual }, 1), false);
  state.receive(snapshot(), 0);
  state.receive({ type: "bubbles_3d_visual", visual }, 50);
  const frame = state.frame(100);
  assert.deepEqual(frame.visual.stretch, [0.2, -0.1]);
  assert.equal(frame.visual.radius, 0.7);
  assert.equal(frame.visual.pop_age_msec, 70);
  assert.equal(frame.visual.host_time_msec, 1100);
  assert.equal(state.receive(snapshot({ host_time_msec: 900 }), 100), false);
  assert.equal(
    state.receive({ type: "bubbles_3d_visual", visual: { ...visual, host_time_msec: 1000 } }, 100),
    false,
  );
  assert.equal(
    state.receive(
      { type: "bubbles_3d_release_result", action: "none", reason: "held_too_long" },
      100,
    ),
    false,
  );
  state.receive(snapshot({ phase: "results", score: 6, host_time_msec: 1100 }), 100);
  assert.equal(state.frame(200).snapshot.phase, "results");
  assert.deepEqual(state.frame(200).visual.stretch, [0, 0]);
});

test("fallback is selected for renderer creation or asset loading failure", async () => {
  const flat = { kind: "flat" };
  const webgl = { kind: "webgl" };
  assert.equal(
    await choosePresentation(
      async () => webgl,
      () => flat,
    ),
    webgl,
  );
  assert.equal(
    await choosePresentation(
      async () => {
        throw Error("no WebGL");
      },
      () => flat,
    ),
    flat,
  );
  assert.equal(
    await choosePresentation(
      () => {
        throw Error("context denied");
      },
      () => flat,
    ),
    flat,
  );
});

test("the screen and reusable view contain no spin mechanic", () => {
  const forbidden = /\bspin/i;
  for (const directory of ["004_3d_bubbles", "three_view"]) {
    const base = new URL(`../../src/${directory}/`, import.meta.url);
    for (const file of readdirSync(base, { recursive: true })) {
      if (!String(file).endsWith(".ts")) continue;

      const source = readFileSync(new URL(String(file).replaceAll("\\", "/"), base), "utf8");
      assert.doesNotMatch(source, forbidden, `${directory}/${file}`);
    }
  }
});
