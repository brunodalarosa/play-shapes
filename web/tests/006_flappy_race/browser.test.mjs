/* global window, document */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { chromium } from "@playwright/test";

const WAITING = {
  type: "flappy_race_snapshot",
  phase: "countdown",
  player_count: 1,
  tick_rate: 60,
  tick: 0,
  clock_tick: -180,
  countdown_remaining_msec: 3000,
  window_ticks: 15,
  race_ticks: 21600,
  last_seconds_tick: 21000,
  flight: {},
  course: { flight: { obstacles: [], pickups: [] } },
  own: {},
};
const PLAYER = { player_id: "one", name: "Tester", seat: 1, state: "connected" };

async function phone(verify) {
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
      const source = `../../public${path === "/" ? "/index.html" : path}`;
      const types = { js: "text/javascript", css: "text/css", html: "text/html" };
      try {
        const body = await readFile(new URL(source, import.meta.url));
        await route.fulfill({ body, contentType: types[path.split(".").at(-1)] ?? "text/html" });
      } catch {
        await route.fulfill({ status: 404, body: "" });
      }
    });
    await page.addInitScript(() => {
      window.WebSocket = class {
        static OPEN = 1;
        readyState = 1;
        bufferedAmount = 0;
        constructor() {
          window.receiveHost = (message) => this.onmessage({ data: JSON.stringify(message) });
          setTimeout(() => this.onopen?.(), 0);
        }
        send() {}
        close() {
          this.readyState = 3;
        }
      };
    });
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

test("the race start replaces READY with the Flappy Race waiting screen", async () => {
  await phone(async (page) => {
    await resume(page, { type: "pre_minigame_snapshot", minigame_id: "flappy_race", ready: true });
    assert.equal(await page.locator("#ready-card").isVisible(), true);

    await page.evaluate((message) => window.receiveHost(message), WAITING);
    assert.equal(await page.locator("#flappy-race").isVisible(), true);
    assert.equal(await page.locator("#ready-card").isVisible(), false);
    assert.equal(await page.locator("#flappy-race-title").textContent(), "Flappy Race");
    assert.equal(
      await page.evaluate(() => document.documentElement.classList.contains("flappy-race-active")),
      true,
    );
  });
});

test("race state and events leave the waiting screen as it is", async () => {
  await phone(async (page) => {
    await resume(page, WAITING);
    await page.evaluate(() => {
      window.receiveHost({ type: "flappy_race_event", event: "go", tick: 0 });
      window.receiveHost({ type: "flappy_race_state", tick: 3, clock_tick: 18, own: {} });
    });
    assert.equal(await page.locator("#flappy-race").isVisible(), true);
  });
});

test("a reconnect during the race returns to the waiting screen", async () => {
  await phone(async (page) => {
    await resume(page, WAITING);
    assert.equal(await page.locator("#flappy-race").isVisible(), true);
  });
});

test("returning to the lobby hides the race screen", async () => {
  await phone(async (page) => {
    await resume(page, WAITING);
    await resume(page, { type: "lobby", state: "waiting", message: "Waiting for the next game" });
    assert.equal(await page.locator("#flappy-race").isVisible(), false);
    assert.equal(
      await page.evaluate(() => document.documentElement.classList.contains("flappy-race-active")),
      false,
    );
  });
});
