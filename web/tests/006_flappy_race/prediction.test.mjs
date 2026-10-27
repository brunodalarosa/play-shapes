import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { FlappyFlight } from "../../build/flappy_flight/flight.js";
import { flightState } from "../../build/006_flappy_race/messages.js";
import { FlappyPrediction } from "../../build/006_flappy_race/prediction.js";
import { RaceClock } from "../../build/006_flappy_race/race_clock.js";

// The phone predicts against a scripted host that follows the host's rule (decision 0048):
// every flight settles one tap window behind the host's clock, and a tap applies at its own
// tick when that lies in the window. The real host is proven against the same flight by the
// shared fixture.
const fixture = JSON.parse(
  readFileSync(new URL("../../../tests/fixtures/flappy_flight_runs.json", import.meta.url), "utf8"),
);
const TICK_MSEC = 1000 / 60;
const WINDOW = 15;
const STATE_EVERY = 3;

/** A seeded generator, so the jitter is the same on every run. */
function random(seed) {
  let value = seed;
  return () => {
    value = (value * 1103515245 + 12345) % 2147483648;
    return value / 2147483648;
  };
}

function hostFlight(state) {
  const taken = [];
  state.taken.forEach((value, index) => value && taken.push(index));
  return {
    x: state.x,
    y: state.y,
    vertical_speed: state.verticalSpeed,
    flying: state.flying,
    ready: state.ready,
    cooldown_ticks: state.cooldownTicks,
    invulnerable_ticks: state.invulnerableTicks,
    boost_ticks: state.boostTicks,
    obstacle_index: state.obstacleIndex,
    hearts: {
      full: state.hearts.full,
      refill_ticks: state.hearts.refillTicks,
      owed: state.hearts.owed,
    },
    taken,
  };
}

/** The host's side: its clock reads tick 0 at GO, local time 0 on the host. */
class ScriptedHost {
  constructor(course) {
    this.flight = new FlappyFlight(fixture.tuning, course);
    this.state = this.flight.newState();
    this.settled = 0;
    this.taps = new Set();
    this.sent = [];
  }

  clock(now) {
    return Math.floor(now / TICK_MSEC);
  }

  tap(tick, now) {
    const earliest = this.settled + 1;
    this.taps.add(Math.min(Math.max(tick, earliest), Math.max(this.clock(now), earliest)));
  }

  advance(now) {
    const target = this.clock(now) - WINDOW;
    while (this.settled < target && this.state.x < this.flight.course.finish_x) {
      this.settled += 1;
      this.flight.step(this.state, this.taps.delete(this.settled));
      if (this.settled % STATE_EVERY === 0)
        this.sent.push({
          at: now,
          tick: this.settled,
          clock: this.clock(now),
          flight: hostFlight(this.state),
        });
    }
  }
}

/** Messages arrive in order, each 80 ms ± 20 ms after it left. */
class Link {
  constructor(seed) {
    this.random = random(seed);
    this.queue = [];
    this.last = Number.NEGATIVE_INFINITY;
  }

  send(message, now, extra = 0) {
    this.last = Math.max(this.last, now + 60 + this.random() * 40 + extra);
    this.queue.push({ ...message, arrives: this.last });
  }

  receive(now) {
    const arrived = this.queue.filter((message) => message.arrives <= now);
    this.queue = this.queue.filter((message) => message.arrives > now);
    return arrived;
  }
}

/**
 * Plays `tapTicks` (the ticks whose step has a tap) on the phone for `ticks` ticks or to the
 * finish line. A tap at
 * `lateTick` reaches the host `lateMsec` later than the others. Returns what the phone drew.
 */
function play(course, tapTicks, ticks, { lateTick = -1, lateMsec = 0 } = {}) {
  const host = new ScriptedHost(course);
  const down = new Link(7);
  const up = new Link(11);
  const jitter = random(3);
  const clock = new RaceClock();
  const flight = new FlappyFlight(fixture.tuning, course);
  const prediction = new FlappyPrediction(flight, flight.newState(), 0);
  const taps = new Set(tapTicks);
  const frames = [];
  // The snapshot leaves the host 3 s before GO, as the countdown starts.
  down.send({ clock: -180, tick: 0 }, -3000);
  let sentUpTo = 0;
  const done = () => host.settled >= ticks || host.state.x >= course.finish_x;
  for (let now = -3000; !done(); now += TICK_MSEC + jitter() * 4) {
    for (const tap of up.receive(now)) host.tap(tap.tick, now);
    host.advance(now);
    for (const message of host.sent.slice(sentUpTo)) down.send(message, now);
    sentUpTo = host.sent.length;

    const corrections = prediction.corrections;
    for (const message of down.receive(now)) {
      clock.observe(message.clock, now);
      if (!message.flight) continue;
      const settled = flightState(message.flight, fixture.tuning, course.pickups.length);
      prediction.confirm(message.tick, settled);
    }
    const target = Math.min(clock.tick(now), ticks);
    while (prediction.tick < target && !prediction.finished) {
      if (taps.has(prediction.tick)) {
        const tick = prediction.tap();
        up.send({ tick }, now, tick === lateTick ? lateMsec : 0);
      }
      prediction.advanceTo(prediction.tick + 1);
    }
    prediction.blend(TICK_MSEC / 1000, 0.12);
    frames.push({
      now,
      corrected: prediction.corrections > corrections,
      flying: prediction.state.flying,
      offset: Math.hypot(prediction.offsetX, prediction.offsetY),
      ahead: clock.tick(now) - host.clock(now),
    });
  }
  return { frames, prediction, host };
}

test("a clean run with 80 ms latency and jitter shows no correction", () => {
  const run = fixture.runs.find((entry) => entry.name === "autopilot_generated");
  const { frames, prediction, host } = play(fixture.courses[run.course], run.taps, run.ticks);
  assert.ok(prediction.state.hearts.full === 3, "the autopilot run has no hit");
  assert.equal(prediction.corrections, 0);
  assert.ok(
    frames.every((frame) => frame.offset < 0.01),
    "the drawn Cubio never moves off",
  );
  assert.ok(
    frames.every((frame) => frame.ahead <= 0),
    "the phone's clock is never ahead",
  );
  assert.ok(prediction.finished && host.settled === prediction.tick, "both cross the finish line");
});

test("a tap the host judged too late corrects in the frame the host's state arrives", () => {
  // Never tapping hits the ground at tick 49; one tap at tick 40 saves it on the phone, but it
  // reaches the host half a second late and is applied after the hit. The first host state
  // without that flap replays the phone into the host's hit.
  const course = fixture.courses.gaps;
  const { frames, prediction } = play(course, [39], 200, { lateTick: 40, lateMsec: 500 });
  const arrival = frames.findIndex((frame) => frame.corrected);
  assert.ok(arrival > 0, "the host's state reaches the phone");
  assert.equal(frames[arrival - 1].flying, true, "the phone predicted no hit");
  assert.equal(frames[arrival].flying, false, "the hit shows in the frame the state arrives");
  assert.equal(frames[arrival].offset, 0, "a hit is not blended");
  assert.equal(prediction.corrections, 1, "after one correction the phone agrees again");
});

test("the race clock follows the fastest message and never runs ahead", () => {
  const clock = new RaceClock();
  assert.equal(clock.started, false);
  clock.observe(-180, 100);
  assert.equal(clock.tick(100), -180);
  assert.equal(clock.untilGo(100), 3000);
  // A slower message changes nothing; a faster one moves GO earlier.
  clock.observe(-170, 300);
  assert.equal(clock.tick(300), -168);
  clock.observe(-147, 600);
  assert.equal(clock.tick(600), -147);
  assert.equal(clock.untilGo(3000), 50);
  assert.equal(clock.untilGo(3050), 0);
});
