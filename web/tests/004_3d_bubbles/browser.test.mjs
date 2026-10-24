/* global window, document, HTMLCanvasElement, getComputedStyle */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { chromium } from "@playwright/test";
import { snapshot } from "./fixtures.mjs";

async function phone(options, verify) {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({
      viewport: { width: 390, height: 844 },
      deviceScaleFactor: 3,
    });
    const requests = [];
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    await page.route("**/*", async (route) => {
      const path = new URL(route.request().url()).pathname;
      requests.push(path);
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
      const file = new URL(source, import.meta.url);
      const types = {
        js: "text/javascript",
        css: "text/css",
        html: "text/html",
        png: "image/png",
        json: "application/json",
        glb: "model/gltf-binary",
      };
      try {
        const body = await readFile(file);
        await route.fulfill({ body, contentType: types[path.split(".").at(-1)] ?? "text/html" });
      } catch {
        await route.fulfill({ status: 404, body: "" });
      }
    });
    await page.addInitScript(({ noWebGL }) => {
      window.sentInput = [];
      window.WebSocket = class {
        static OPEN = 1;
        readyState = 1;
        bufferedAmount = 0;
        constructor() {
          window.receiveHost = (message) => this.onmessage({ data: JSON.stringify(message) });
          setTimeout(() => this.onopen?.(), 0);
        }
        send(value) {
          window.sentInput.push(JSON.parse(value));
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
    }, options);
    await page.goto("http://phone.test/");
    await page.waitForFunction(() => typeof window.receiveHost === "function");
    await page.evaluate(() =>
      window.receiveHost({
        type: "welcome",
        protocol: 1,
        connection_id: 1,
        resume_status: "new",
      }),
    );
    await verify(page, requests);
    assert.deepEqual(errors, []);
  } finally {
    await browser.close();
  }
}

test("browser loads 3D lazily, renders models, sends label touches and retires on lobby", async () => {
  await phone({ noWebGL: false }, async (page, requests) => {
    assert.equal(requests.includes("/three_view.js"), false);
    await page.evaluate(
      (gameplay) =>
        window.receiveHost({
          type: "welcome",
          protocol: 1,
          connection_id: 2,
          resume_status: "resumed",
          session_id: "test-session",
          reconnect_token: "test-token",
          player: { player_id: "one", name: "Tester", seat: 1, state: "connected" },
          gameplay,
        }),
      snapshot(),
    );
    await page.waitForFunction(() => {
      const canvas = document.querySelector("#bubbles-3d-visual");
      return !canvas.hidden && canvas.width > 1;
    });
    await page.waitForTimeout(200);
    assert.equal(requests.filter((path) => path === "/three_view.js").length, 1);
    assert.ok(requests.includes("/models/cubio.glb"));
    assert.ok(requests.includes("/models/jellyfish.glb"));
    assert.equal(await page.locator("#bubbles-3d-score").textContent(), "7");
    assert.equal(await page.locator("#bubbles-3d-visual").evaluate((canvas) => canvas.width), 780);
    await page.mouse.move(195, 40);
    await page.mouse.down();
    await page.mouse.move(290, 150);
    await page.mouse.up();
    const sent = await page.evaluate(() => window.sentInput);
    const start = sent.find((message) => message.type === "bubbles_3d_touch");
    const release = sent.find((message) => message.type === "bubbles_3d_release");
    assert.equal(start.stage, "start");
    assert.equal(start.input_seq, release.input_seq);
    assert.ok(release.displacement[1] > 0);
    await page.mouse.down();
    await page.setViewportSize({ width: 412, height: 915 });
    await page.waitForFunction(() => window.sentInput.at(-1).stage === "cancel");
    await page.mouse.up();
    const cancelled = await page.evaluate(() => window.sentInput.at(-1));
    assert.equal(cancelled.stage, "cancel");
    await page.setViewportSize({ width: 390, height: 844 });
    const capture = new URL("../../build/bubbles-3d-phone.png", import.meta.url);
    await page.screenshot({ path: fileURLToPath(capture) });
    await page.evaluate(() => window.receiveHost({ type: "lobby" }));
    assert.equal(await page.locator("#bubbles-3d-card").isVisible(), false);
    await page.evaluate((gameplay) => window.receiveHost(gameplay), snapshot());
    await page.waitForFunction(() => !document.querySelector("#bubbles-3d-visual").hidden);
    assert.equal(requests.filter((path) => path === "/models/cubio.glb").length, 1);
    await page.evaluate(() =>
      window.receiveHost({
        type: "pre_minigame_snapshot",
        ready: false,
      }),
    );
    assert.equal(await page.locator("#bubbles-3d-card").isVisible(), false);
    assert.equal(await page.locator("#ready-card").isVisible(), true);
  });
});

test("setup shows live Cubio, preserves color through navigation and releases hidden previews", async () => {
  await phone({ noWebGL: false }, async (page, requests) => {
    await page.getByRole("button", { name: "CONTINUE IN BROWSER" }).click();
    const selection = page.locator("#selection-preview");
    const name = page.locator("#name-preview");
    await page.waitForFunction(
      () => document.querySelector("#selection-preview").dataset.preview === "ready",
    );
    assert.equal(await selection.getAttribute("aria-label"), "Blue Cubio Shape Character");
    await page.getByRole("button", { name: "Choose Pink", exact: true }).click();
    assert.equal(await selection.getAttribute("aria-label"), "Pink Cubio Shape Character");
    const capture = new URL("../../../test-results/cubio/phone-setup.png", import.meta.url);
    await page.screenshot({ path: fileURLToPath(capture) });
    await page.getByRole("button", { name: "NEXT", exact: true }).click();
    await page.waitForFunction(
      () => document.querySelector("#name-preview").dataset.preview === "ready",
    );
    assert.equal(await selection.getAttribute("data-preview"), "idle");
    assert.equal(await name.getAttribute("aria-label"), "Pink Cubio character preview");
    await page.getByRole("button", { name: "Back to character selection" }).click();
    await page.waitForFunction(
      () => document.querySelector("#selection-preview").dataset.preview === "ready",
    );
    assert.equal(await name.getAttribute("data-preview"), "idle");
    await page.getByRole("button", { name: "NEXT", exact: true }).click();
    await page.locator("#player-name").fill("Cubio Player");
    await page.locator("#join-button").click();
    const sent = await page.evaluate(() => window.sentInput);
    const join = sent.find((message) => message.type === "join");
    assert.equal(join.character_shape, "cubio");
    assert.equal(join.character_color, "#EC407A");
    assert.equal(requests.filter((path) => path === "/models/cubio.glb").length, 1);
    await page.evaluate(() =>
      window.receiveHost({
        type: "join_accepted",
        session_id: "test-session",
        reconnect_token: "test-token",
        player: { player_id: "one", name: "Cubio Player", seat: 1, state: "connected" },
      }),
    );
    await page.waitForFunction(
      () => document.querySelector("#name-preview").dataset.preview === "idle",
    );
    assert.equal(await page.locator("#lobby-controller").isVisible(), true);
  });
});

test("setup still joins when WebGL is unavailable", async () => {
  await phone({ noWebGL: true }, async (page) => {
    await page.getByRole("button", { name: "CONTINUE IN BROWSER" }).click();
    await page.waitForFunction(
      () => document.querySelector("#selection-preview").dataset.preview === "unavailable",
    );
    await page.getByRole("button", { name: "NEXT", exact: true }).click();
    await page.locator("#player-name").fill("No WebGL");
    await page.locator("#join-button").click();
    const sent = await page.evaluate(() => window.sentInput);
    const join = sent.find((message) => message.type === "join");
    assert.equal(join.character_shape, "cubio");
    assert.equal(join.name, "No WebGL");
  });
});

test("setup navigation while the model loads retires pending views without duplicate downloads", async () => {
  await phone({ noWebGL: false }, async (page, requests) => {
    let release;
    const blocked = new Promise((resolve) => {
      release = resolve;
    });
    await page.route("**/models/cubio.glb", async (route) => {
      await blocked;
      await route.fallback();
    });
    const loading = page.waitForRequest("**/models/cubio.glb");
    await page.getByRole("button", { name: "CONTINUE IN BROWSER" }).click();
    await loading;
    await page.getByRole("button", { name: "NEXT", exact: true }).click();
    await page.getByRole("button", { name: "Back to character selection" }).click();
    release();
    await page.waitForFunction(
      () => document.querySelector("#selection-preview").dataset.preview === "ready",
    );
    assert.equal(requests.filter((path) => path === "/models/cubio.glb").length, 1);
    assert.equal(await page.locator("#name-preview").getAttribute("data-preview"), "idle");
  });
});

test("reusable Cubio tints every limb, draws its shape face, scales and blinks", async () => {
  await phone({ noWebGL: false }, async (page) => {
    const result = await page.evaluate(async () => {
      const { createCubio } = await import("/three_view.js");
      const character = await createCubio();
      character.update(0, 1.31, "#e53935", false);
      character.root.updateMatrixWorld(true);
      const colors = [];
      const tinted = [];
      const parts = () => character.face.root.children.map((part) => part.material);
      character.root.traverse((object) => {
        if (!object.isMesh || !object.visible || parts().includes(object.material)) return;
        colors.push(object.material.color.getHexString());
        tinted.push(object);
      });
      const anchor = character.face.root.parent;
      const z = character.face.root.matrixWorld.elements[14];
      const open = parts().length;
      const scale = character.root.scale.x;
      // Blinks come 2.4 to 5.6 s apart and last 0.12 s; step through one in small frames.
      // A closed eye is shorter than the open eye it replaces.
      const eye = character.face.root.children[0].scale.y;
      let blinked = false;
      for (let frame = 0; frame < 400 && !blinked; frame++) {
        character.update(0.02, 1.31, "#e53935", true);
        blinked = character.face.root.children[0].scale.y < eye * 0.9;
      }
      const white = tinted.map((object) => object.material.color.getHexString());
      character.dispose();
      return { colors, anchor: anchor?.name, z, open, scale, white, blinked };
    });
    assert.deepEqual(result.colors, Array(5).fill("e53935"));
    assert.equal(result.anchor, "FaceAnchor");
    assert.ok(result.z > 0);
    assert.equal(result.open, 3);
    assert.equal(result.scale, 0.5);
    assert.deepEqual(result.white, Array(5).fill("ffffff"));
    assert.equal(result.blinked, true);
  });
});

test("browser without WebGL keeps score and a radius-sized colored fallback", async () => {
  await phone({ noWebGL: true }, async (page) => {
    await page.evaluate((gameplay) => window.receiveHost(gameplay), snapshot({ score: 123 }));
    const fallback = page.locator("#bubbles-3d-fallback");
    await fallback.waitFor({ state: "visible" });
    await page.waitForFunction(() => document.querySelector("#bubbles-3d-visual").hidden);
    assert.equal(await page.locator("#bubbles-3d-score").textContent(), "123");
    await page.waitForFunction(() => {
      const circle = document.querySelector("#bubbles-3d-fallback");
      return getComputedStyle(circle).backgroundColor === "rgb(30, 136, 229)";
    });
    const before = await fallback.boundingBox();
    await page.evaluate(
      (gameplay) => window.receiveHost(gameplay),
      snapshot({ score: 200, bubble_radius: 1.5, host_time_msec: 1100 }),
    );
    await page.waitForTimeout(150);
    assert.ok((await fallback.boundingBox()).width > before.width);
    await page.evaluate(() => window.receiveHost({ type: "lobby" }));
  });
});

test("reusable viewport caps resolution and suspends its loop while hidden or disposed", async () => {
  await phone({ noWebGL: false }, async (page) => {
    const result = await page.evaluate(async () => {
      const { Viewport } = await import("/three_view.js");
      const canvas = document.createElement("canvas");
      canvas.style.width = "100px";
      canvas.style.height = "200px";
      document.body.append(canvas);
      let frames = 0;
      const viewport = new Viewport(canvas, () => frames++);
      const wait = () => new Promise((resolve) => setTimeout(resolve, 80));
      await wait();
      const visible = frames;
      Object.defineProperty(document, "hidden", { configurable: true, value: true });
      document.dispatchEvent(new Event("visibilitychange"));
      await wait();
      const hidden = frames;
      delete document.hidden;
      document.dispatchEvent(new Event("visibilitychange"));
      await wait();
      const resumed = frames;
      viewport.dispose();
      await wait();
      const disposed = frames;
      const size = [canvas.width, canvas.height];
      canvas.remove();
      return { visible, hidden, resumed, disposed, size };
    });
    assert.ok(result.visible > 0);
    assert.equal(result.hidden, result.visible);
    assert.ok(result.resumed > result.hidden);
    assert.equal(result.disposed, result.resumed);
    assert.deepEqual(result.size, [200, 400]);
  });
});
