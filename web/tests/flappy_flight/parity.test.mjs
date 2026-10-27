import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { EVENT_FLAP, FlappyFlight } from "../../build/flappy_flight/flight.js";

// tests/flappy_flight_parity_test.gd writes this fixture from the GDScript flight; the phone's
// flight must reproduce every run bit for bit (decision 0047).
const fixture = JSON.parse(
  readFileSync(new URL("../../../tests/fixtures/flappy_flight_runs.json", import.meta.url), "utf8"),
);
const traces = new URL("../../../test-results/flappy_flight/", import.meta.url);

/** The hex of a float's 64-bit little-endian bytes, as GDScript's PackedFloat64Array gives it. */
function floatBits(values) {
  const view = new DataView(new ArrayBuffer(8 * values.length));
  values.forEach((value, index) => view.setFloat64(index * 8, value, true));
  return Buffer.from(view.buffer).toString("hex");
}

function traceLine(state, events) {
  const counters = [
    Number(state.flying),
    Number(state.ready),
    state.cooldownTicks,
    state.invulnerableTicks,
    state.boostTicks,
    state.obstacleIndex,
    state.hearts.full,
    state.hearts.refillTicks,
    Number(state.hearts.owed),
    events,
  ];
  const bits = floatBits([state.x, state.y, state.verticalSpeed]);
  return `${bits} ${counters.join(" ")} ${Buffer.from(state.taken).toString("hex")}`;
}

function play(run) {
  const flight = new FlappyFlight(fixture.tuning, fixture.courses[run.course]);
  const state = flight.newState();
  const taps = new Set(run.taps);
  const events = [];
  const lines = [];
  for (let tick = 0; tick < run.ticks; tick += 1) {
    const happened = flight.step(state, taps.has(tick));
    if ((happened & ~EVENT_FLAP) !== 0) events.push([tick, happened]);
    lines.push(traceLine(state, happened));
  }
  const text = lines.join("\n") + "\n";
  return { events, text, digest: createHash("sha256").update(text, "utf8").digest("hex") };
}

test("the fixture covers every flight rule", () => {
  const seen = fixture.runs.flatMap((run) => run.events.map(([, bits]) => bits));
  for (const bit of [2, 4, 8, 16, 32]) {
    assert.ok(
      seen.some((bits) => (bits & bit) !== 0),
      `event ${bit} happens in some run`,
    );
  }
});

for (const run of fixture.runs) {
  test(`the phone's flight matches the host's on every tick: ${run.name}`, () => {
    const result = play(run);
    if (result.digest !== run.digest) {
      mkdirSync(traces, { recursive: true });
      writeFileSync(new URL(`${run.name}.ts.txt`, traces), result.text);
    }
    assert.deepEqual(result.events, run.events);
    assert.equal(result.digest, run.digest);
  });
}
