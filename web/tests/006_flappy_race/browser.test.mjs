/* global window, document, requestAnimationFrame, HTMLCanvasElement, PointerEvent */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { readFileSync } from "node:fs";
import { chromium } from "@playwright/test";

const fixture = JSON.parse(
  readFileSync(new URL("../../../tests/fixtures/flappy_flight_runs.json", import.meta.url), "utf8"),
);
const PLAYER = { player_id: "one", name: "Tester", seat: 1, state: "connected" };
const COURSE = fixture.courses.generated;
const VIEW = {
  tilt_up_degrees: 25,
  tilt_down_degrees: 70,
  tilt_response_seconds: 0.08,
  hit_tumble_seconds: 0.2,
  pickup_face_seconds: 0.6,
  phone_cubio_screen_share: 0.3,
  correction_seconds: 0.12,
  heart_flight_seconds: 0.2,
};

function flight(overrides = {}) {
  return {
    x: COURSE.start_x,
    y: COURSE.start_y,
    vertical_speed: 0,
    flying: true,
    ready: false,
    cooldown_ticks: 0,
    invulnerable_ticks: 0,
    boost_ticks: 0,
    obstacle_index: 0,
    hearts: { full: 3, refill_ticks: 0, owed: false },
    taken: [],
    ...overrides,
  };
}

function own(overrides = {}) {
  return {
    flight: flight(),
    last_seq: 4,
    connected: true,
    place: 0,
    finish_tick: -1,
    dnf: false,
    ...overrides,
  };
}

function snapshot(overrides = {}) {
  return {
    type: "flappy_race_snapshot",
    character_color: "598DF2",
    phase: "racing",
    player_count: 2,
    tick_rate: 60,
    tick: 0,
    clock_tick: 15,
    countdown_remaining_msec: 0,
    window_ticks: 15,
    race_ticks: 21600,
    last_seconds_tick: 21000,
    flight: fixture.tuning,
    view: VIEW,
    course: { length: COURSE.finish_x, view_height: 34, flight: COURSE, ground_kinds: [] },
    own: own(),
    ...overrides,
  };
}

async function phone({ noWebGL = false } = {}, verify) {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    await page.route("**/*", async (route) => {
      const path = new URL(route.request().url()).pathname;
      if (path === "/session.json") {
        await route.fulfill({
          json: {
            protocol: 1,
            session_id: "test-session",
            http_scheme: "http",
            websocket_scheme: "ws",
            websocket_port: 8081,
          },
        });
        return;
      }
      // The host serves the face parts and Cubio's face placement from the runtime folders.
      const source = path.startsWith("/shape_faces/")
        ? `../../../assets/runtime${path}`
        : path === "/models/cubio-face-anchor.json"
          ? "../../../assets/runtime/animated_characters/cubio/face_anchor.json"
          : `../../public${path === "/" ? "/index.html" : path}`;
      const types = {
        js: "text/javascript",
        css: "text/css",
        html: "text/html",
        json: "application/json",
        png: "image/png",
      };
      try {
        const body = await readFile(new URL(source, import.meta.url));
        await route.fulfill({ body, contentType: types[path.split(".").at(-1)] ?? "text/html" });
      } catch {
        await route.fulfill({ status: 404, body: "" });
      }
    });
    await page.addInitScript(
      ({ noWebGL }) => {
        window.sent = [];
        window.WebSocket = class {
          static OPEN = 1;
          readyState = 1;
          bufferedAmount = 0;
          constructor() {
            window.receiveHost = (message) => this.onmessage({ data: JSON.stringify(message) });
            setTimeout(() => this.onopen?.(), 0);
          }
          send(value) {
            window.sent.push(JSON.parse(value));
          }
          close() {
            this.readyState = 3;
          }
        };
        if (noWebGL) {
          const original = HTMLCanvasElement.prototype.getContext;
          HTMLCanvasElement.prototype.getContext = function (kind, ...args) {
            return kind.startsWith("webgl") ? null : original.call(this, kind, ...args);
          };
        }
      },
      { noWebGL },
    );
    await page.goto("http://phone.test/");
    await page.waitForFunction(() => typeof window.receiveHost === "function");
    await verify(page);
    assert.deepEqual(errors, []);
  } finally {
    await browser.close();
  }
}

function resume(page, gameplay) {
  return page.evaluate(
    ([message, player]) =>
      window.receiveHost({
        type: "welcome",
        protocol: 1,
        connection_id: 2,
        resume_status: "resumed",
        session_id: "test-session",
        reconnect_token: "test-token",
        player,
        gameplay: message,
      }),
    [gameplay, PLAYER],
  );
}

function host(page, message) {
  return page.evaluate((value) => window.receiveHost(value), message);
}

/** The race surface's data after the phone has drawn its next frame. */
function nextFrame(page) {
  return page.evaluate(
    () =>
      new Promise((resolve) =>
        requestAnimationFrame(() => resolve({ ...document.querySelector("#flappy-race").dataset })),
      ),
  );
}

test("the race start replaces READY with the race and its countdown", async () => {
  await phone({}, async (page) => {
    await resume(page, { type: "pre_minigame_snapshot", minigame_id: "flappy_race", ready: true });
    assert.equal(await page.locator("#ready-card").isVisible(), true);

    await host(page, snapshot({ phase: "countdown", clock_tick: -180 }));
    assert.equal(await page.locator("#flappy-race").isVisible(), true);
    assert.equal(await page.locator("#ready-card").isVisible(), false);
    assert.equal((await nextFrame(page)).phase, "countdown");
    assert.equal(await page.locator(".flappy-cue").textContent(), "3");
    assert.equal(await page.locator(".flappy-heart").count(), 3);
    assert.equal(await page.locator(".flappy-timer").textContent(), "6:00");
  });
});

test("a tap sends its tick and the flap shows in the next frame", async () => {
  await phone({}, async (page) => {
    await resume(page, snapshot());
    await page.waitForFunction(
      () => Number(document.querySelector("#flappy-race").dataset.tick) >= 20,
    );
    assert.equal((await nextFrame(page)).rising, "false", "the Cubio falls before the tap");

    const rising = await page.evaluate(
      () =>
        new Promise((resolve) => {
          const surface = document.querySelector("#flappy-race");
          surface.dispatchEvent(
            new PointerEvent("pointerdown", { bubbles: true, pointerType: "touch", button: 0 }),
          );
          requestAnimationFrame(() => resolve(surface.dataset.rising));
        }),
    );
    assert.equal(rising, "true");
    const taps = await page.evaluate(() => window.sent.filter((m) => m.type === "flappy_tap"));
    assert.equal(taps.length, 1);
    assert.equal(taps[0].seq, 5, "the sequence continues from the host's last one");
    assert.ok(Number.isInteger(taps[0].tick) && taps[0].tick > 20);
  });
});

test("a hit flies a heart to the respawn spot, where it waits and pulses when ready", async () => {
  await phone({}, async (page) => {
    await resume(page, snapshot());
    await page.waitForFunction(
      () => Number(document.querySelector("#flappy-race").dataset.tick) >= 6,
    );
    const obstacle = COURSE.obstacles[0];
    const waiting = {
      x: obstacle.respawn_x,
      y: obstacle.respawn_y,
      flying: false,
      cooldown_ticks: 120,
      hearts: { full: 2, refill_ticks: 0, owed: false },
    };
    await host(page, {
      type: "flappy_race_state",
      tick: 3,
      clock_tick: 18,
      own: own({ flight: flight(waiting) }),
    });
    assert.equal((await nextFrame(page)).flying, "false");
    assert.equal(await page.locator(".flappy-heart-flight").count(), 1, "the spent heart flies");
    assert.deepEqual(
      await page
        .locator(".flappy-heart")
        .evaluateAll((hearts) =>
          hearts
            .filter((heart) => !heart.classList.contains("flappy-heart-flight"))
            .map((heart) => heart.dataset.fill),
        ),
      ["full", "full", "refill"],
    );

    const floating = page.locator(".flappy-floating-heart");
    await floating.waitFor({ state: "visible" });
    assert.equal(await floating.getAttribute("data-state"), "cooling");
    await page.waitForFunction(
      () => document.querySelector(".flappy-floating-heart").dataset.state === "ready",
    );
    assert.equal((await nextFrame(page)).ready, "true");
  });
});

test("with no heart left the respawn spot shows an outline that fills", async () => {
  await phone({}, async (page) => {
    const waiting = flight({
      flying: false,
      cooldown_ticks: 0,
      hearts: { full: 0, refill_ticks: 300, owed: true },
    });
    await resume(page, snapshot({ own: own({ flight: waiting }) }));
    const floating = page.locator(".flappy-floating-heart");
    await floating.waitFor({ state: "visible" });
    assert.equal(await floating.getAttribute("data-state"), "owed");
    const refill = Number(
      await floating.evaluate((node) => node.style.getPropertyValue("--refill")),
    );
    assert.ok(refill >= 0.5 && refill < 0.6, `the ring is half full: ${refill}`);
  });
});

test("finishing shows Finished, then the place, then the own result", async () => {
  await phone({}, async (page) => {
    const near = own({ flight: flight({ x: COURSE.finish_x - 0.1, y: 17 }) });
    await resume(page, snapshot({ own: near }));
    await page.locator(".flappy-cue", { hasText: "Finished!" }).waitFor();
    await host(page, { type: "flappy_race_event", event: "finish", tick: 16, place: 2 });
    await page.locator(".flappy-cue", { hasText: "You finished 2nd!" }).waitFor();

    const result = {
      player_id: "one",
      name: "Tester",
      character_color: "598DF2",
      place: 2,
      finished: true,
      finish_msec: 83450,
      distance: COURSE.finish_x,
      dnf: false,
    };
    await host(
      page,
      snapshot({ phase: "results", own: near, results: [result], own_result: result }),
    );
    assert.equal(await page.locator(".flappy-results").isVisible(), true);
    assert.equal(await page.locator(".flappy-result-place").textContent(), "2nd place");
    assert.equal(await page.locator(".flappy-result-detail").textContent(), "Time 1:23.45");
  });
});

test("a reconnect during the race restores the race screen in 3D", async () => {
  await phone({}, async (page) => {
    await resume(page, snapshot({ clock_tick: 900, tick: 885 }));
    assert.equal(await page.locator("#flappy-race").isVisible(), true);
    await page.locator(".flappy-view").waitFor({ state: "visible" });
    assert.equal(await page.locator(".flappy-fallback").isVisible(), false);
    assert.ok(Number((await nextFrame(page)).tick) >= 900);
  });
});

test("without WebGL the race is drawn flat and stays readable", async () => {
  await phone({ noWebGL: true }, async (page) => {
    await resume(page, snapshot());
    await page.locator(".flappy-fallback").waitFor({ state: "visible" });
    await nextFrame(page);
    const colours = await page.evaluate(() => {
      const canvas = document.querySelector(".flappy-fallback");
      const pixels = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height).data;
      const seen = new Set();
      for (let index = 0; index < pixels.length; index += 4 * 97)
        if (pixels[index + 3] > 0)
          seen.add(`${pixels[index]},${pixels[index + 1]},${pixels[index + 2]}`);
      return seen.size;
    });
    assert.ok(colours >= 3, `ground, stone and Cubio are drawn: ${colours} colours`);
    assert.equal(await page.locator(".flappy-view").isVisible(), false);
  });
});

test("returning to the lobby hides the race screen", async () => {
  await phone({}, async (page) => {
    await resume(page, snapshot());
    await resume(page, { type: "lobby", state: "waiting", message: "Waiting for the next game" });
    assert.equal(await page.locator("#flappy-race").isVisible(), false);
    assert.equal(
      await page.evaluate(() => document.documentElement.classList.contains("flappy-race-active")),
      false,
    );
  });
});
