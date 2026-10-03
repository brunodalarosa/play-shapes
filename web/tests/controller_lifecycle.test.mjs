import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

// Exercise the compiled app's real DOM handlers. Only joystick rendering is replaced;
// its independent input semantics have their own tests. This measures dispatch-to-send,
// with fake transport, not browser latency, Wi-Fi, Godot receipt or physical feel.
class Element extends EventTarget {
  hidden = true;
  disabled = false;
  textContent = "";
  value = "";
  dataset = {};
  children = [];
  style = { setProperty() {} };
  classList = { add() {}, remove() {}, toggle() {} };
  captures = new Set();
  focus() {}
  setAttribute() {}
  append(value) {
    this.children.push(value);
  }
  querySelectorAll() {
    return [];
  }
  closest() {
    return { hidden: true };
  }
  getContext() {
    return {};
  }
  getBoundingClientRect() {
    return { left: 0, top: 0, width: 390, height: 844 };
  }
  setPointerCapture(id) {
    this.captures.add(id);
  }
  hasPointerCapture(id) {
    return this.captures.has(id);
  }
  releasePointerCapture(id) {
    this.captures.delete(id);
  }
}
let run = 0;
async function withController(
  { standalone = false, identity = false, failure = null } = {},
  verify,
) {
  const elements = new Map();
  const el = (selector) => {
    if (!elements.has(selector)) elements.set(selector, new Element());
    return elements.get(selector);
  };
  const root = new Element();
  let fullscreen = 0;
  root.requestFullscreen = () => {
    fullscreen++;
    return Promise.reject(Error("denied"));
  };
  const document = Object.assign(new EventTarget(), {
    documentElement: root,
    hidden: false,
    fullscreenElement: null,
    querySelector: el,
    createElement: () => new Element(),
    hasFocus: () => true,
  });
  const storage = new Map(
    identity
      ? [
          ["play-shapes.session-id", "session"],
          ["play-shapes.reconnect-token", "token"],
        ]
      : [],
  );
  const memory = {
    getItem: (key) => storage.get(key),
    setItem: (key, value) => storage.set(key, value),
    removeItem: (key) => storage.delete(key),
  };
  const window = Object.assign(new EventTarget(), {
    innerHeight: 844,
    sessionStorage: memory,
    devicePixelRatio: 1,
    matchMedia: (query) => ({ matches: standalone && query.includes("standalone") }),
  });
  const sockets = [],
    messages = [];
  class Socket {
    static OPEN = 1;
    readyState = 1;
    bufferedAmount = 0;
    constructor(url) {
      this.url = url;
      sockets.push(this);
    }
    send(data) {
      messages.push({ ...JSON.parse(data), sentAt: performance.now() });
    }
    close() {
      this.readyState = 3;
      this.onclose?.({ code: 1000, reason: "", wasClean: true });
    }
  }
  const globals = {
    document,
    window,
    navigator: { userAgent: "Android", platform: "Linux", maxTouchPoints: 1 },
    screen: { orientation: { unlock() {} } },
    location: { href: "http://localhost:8080/", protocol: "http:", hostname: "localhost" },
    localStorage: memory,
    WebSocket: Socket,
    Image: class {
      complete = false;
      naturalWidth = 0;
    },
    requestAnimationFrame() {},
    addEventListener: window.addEventListener.bind(window),
    fetch: async (path) => {
      if (path === "/session.json" && failure === "fetch") throw new TypeError("Load failed");
      return {
        ok: !(path === "/session.json" && failure === "http"),
        status: 503,
        statusText: "Service Unavailable",
        json: async () => {
          if (path !== "/session.json") return { resolution: [256, 256], clips: [] };
          if (failure === "json") throw new SyntaxError("Unexpected token < in JSON");
          return {
            protocol: 1,
            session_id: "session",
            http_scheme: "http",
            websocket_scheme: failure === "config" ? "wss" : "ws",
            websocket_port: 8081,
          };
        },
      };
    },
  };
  const saved = new Map(
    Object.keys(globals).map((key) => [key, Object.getOwnPropertyDescriptor(globalThis, key)]),
  );
  for (const [key, value] of Object.entries(globals))
    Object.defineProperty(globalThis, key, { configurable: true, writable: true, value });
  try {
    let source = readFileSync(new URL("../public/app.js", import.meta.url), "utf8");
    const stub =
      "data:text/javascript," +
      encodeURIComponent("export class LobbyControls { activate(){} deactivate(){} }");
    source = source.replace(
      /from "(\.\/[^\"]+)"/g,
      (match, path) =>
        `from "${path === "./lobby_controls.js" ? stub : new URL("../public/" + path.slice(2), import.meta.url).href}"`,
    );
    await import(
      "data:text/javascript;base64," +
        Buffer.from(source + `\n// fixture ${++run}`).toString("base64")
    );
    await new Promise((resolve) => setImmediate(resolve));
    const peer = sockets[0];
    if (!failure) assert.ok(peer);
    peer?.onopen();
    const receive = (message) => peer.onmessage({ data: JSON.stringify(message) });
    const player = { player_id: "one", name: "Tester", seat: 1, state: "connected" };
    await verify({
      el,
      document,
      window,
      receive,
      player,
      messages,
      error: () => peer.onerror(new Event("error")),
      close: (code, reason = "", wasClean = false) => {
        peer.readyState = 3;
        peer.onclose({ code, reason, wasClean });
      },
      fullscreen: () => fullscreen,
    });
  } finally {
    window.dispatchEvent(new Event("pagehide"));
    for (const [key, descriptor] of saved)
      descriptor ? Object.defineProperty(globalThis, key, descriptor) : delete globalThis[key];
  }
}

test("actual app offers installation before registration and dismisses without reoffering", async () => {
  await withController({}, async ({ el, receive, messages, fullscreen }) => {
    receive({ type: "welcome", protocol: 1, connection_id: 1, resume_status: "join_required" });
    assert.equal(el("#app-screen").hidden, false);
    assert.equal(el("#selection-screen").hidden, true);
    el("#join-form").dispatchEvent(new Event("submit", { cancelable: true }));
    assert.equal(messages.filter((m) => m.type === "join").length, 0);
    el("#browser-button").dispatchEvent(new Event("click"));
    await new Promise((resolve) => setImmediate(resolve));
    assert.equal(fullscreen(), 1);
    assert.equal(el("#selection-screen").hidden, false);
    el("#next-button").dispatchEvent(new Event("click"));
    el("#player-name").value = "Tester";
    el("#join-form").dispatchEvent(new Event("submit", { cancelable: true }));
    assert.equal(messages.filter((m) => m.type === "join").length, 1);
    receive({ type: "left" });
    assert.equal(el("#app-screen").hidden, true);
  });
});

test("session failures retain exact step, endpoint and browser error through reconnect status", async () => {
  for (const [failure, step, detail] of [
    ["fetch", "Fetch session configuration", "TypeError: Load failed"],
    ["http", "Fetch session configuration", "HTTP 503 Service Unavailable"],
    ["json", "Parse session configuration JSON", "SyntaxError: Unexpected token < in JSON"],
    [
      "config",
      "Validate session transport configuration",
      "Invalid or mixed-content controller configuration",
    ],
  ])
    await withController({ failure, identity: true }, async ({ el }) => {
      const panel = el("#connection-error");
      assert.equal(panel.hidden, false);
      assert.ok(panel.textContent.includes(step));
      assert.ok(panel.textContent.includes(detail));
      assert.match(panel.textContent, /Endpoint: http:\/\/localhost:8080\/session.json/);
      assert.match(panel.textContent, /Browser: Android/);
      assert.match(el("#status").textContent, /Reconnecting/);
      assert.doesNotMatch(panel.textContent, /reconnect-token|session-id|"token"/);
    });
});

test("WebSocket failures show close details and clear only after a successful welcome", async () => {
  await withController({}, async ({ el, error, close, receive }) => {
    error();
    assert.equal(el("#connection-error").hidden, false);
    assert.match(el("#connection-error").textContent, /Open WebSocket|Wait for host welcome/);
    assert.match(el("#connection-error").textContent, /underlying network\/TLS reason/);
    close(1006, "", false);
    assert.match(
      el("#connection-error").textContent,
      /code=1006, reason=\(not provided\), wasClean=false/,
    );
    assert.match(el("#connection-error").textContent, /ws:\/\/localhost:8081/);
    receive({ type: "welcome", protocol: 1, connection_id: 1, resume_status: "join_required" });
    assert.equal(el("#connection-error").hidden, true);
    assert.equal(el("#connection-error").textContent, "");
  });
});

test("host protocol errors stay visible independently of hidden gameplay status", async () => {
  await withController({ standalone: true, identity: true }, async ({ el, receive, player }) => {
    receive({
      type: "welcome",
      protocol: 1,
      connection_id: 1,
      resume_status: "resumed",
      player,
      session_id: "session",
      reconnect_token: "token",
    });
    receive({ type: "bubbles_snapshot", phase: "active" });
    receive({ type: "error", code: "invalid_input", message: "Input sequence must increase" });
    assert.equal(el("#connection-error").hidden, false);
    assert.match(el("#connection-error").textContent, /Host protocol error/);
    assert.match(
      el("#connection-error").textContent,
      /invalid_input: Input sequence must increase/,
    );
  });
});

test("phone log groups repeats, stays bounded, and surfaces uncaught browser failures", async () => {
  await withController({}, async ({ el, receive, window }) => {
    receive({ type: "welcome", protocol: 1, connection_id: 1, resume_status: "join_required" });
    for (let i = 0; i < 2; i++)
      receive({ type: "error", code: "example", message: "Same failure" });
    assert.match(el("#connection-error").textContent, /repeated 2 times/);
    for (let i = 0; i < 8; i++)
      receive({ type: "error", code: "example", message: `Different failure ${i}` });
    assert.equal((el("#connection-error").textContent.match(/Step:/g) ?? []).length, 6);
    assert.doesNotMatch(
      el("#connection-error").textContent,
      /Different failure 0|Different failure 1|Same failure/,
    );
    window.dispatchEvent(
      Object.assign(new Event("error"), {
        error: new TypeError("Example runtime failure"),
        filename: "app.js",
        lineno: 23,
        colno: 7,
      }),
    );
    assert.match(el("#connection-error").textContent, /Browser JavaScript error/);
    assert.match(el("#connection-error").textContent, /TypeError: Example runtime failure/);
    assert.match(el("#connection-error").textContent, /Source: app.js:23:7/);
    window.dispatchEvent(
      Object.assign(new Event("unhandledrejection"), {
        reason: new Error("Example asynchronous failure"),
      }),
    );
    assert.match(el("#connection-error").textContent, /Unhandled browser promise rejection/);
    assert.match(el("#connection-error").textContent, /Error: Example asynchronous failure/);
  });
});

test("installed/shared-token ownership handoff stops the older controller without rejoining", async () => {
  await withController(
    { standalone: true, identity: true },
    async ({ el, receive, player, close, messages }) => {
      receive({
        type: "welcome",
        protocol: 1,
        connection_id: 1,
        resume_status: "resumed",
        player,
        session_id: "session",
        reconnect_token: "token",
      });
      receive({ type: "pre_minigame_snapshot", ready: true });
      close(4000);
      assert.equal(el("#ready-card").hidden, true);
      assert.equal(el("#bubbles-card").hidden, true);
      assert.equal(el("#status").hidden, false);
      assert.match(el("#status").textContent, /another window/);
      assert.equal(el("#app-screen").hidden, true);
      assert.equal(messages.filter((m) => m.type === "join").length, 0);
    },
  );
});

test("standalone with shared identity resumes; separate storage starts unregistered", async () => {
  for (const identity of [false, true])
    await withController(
      { standalone: true, identity },
      async ({ el, receive, player, messages }) => {
        assert.equal(messages[0].reconnect_token, identity ? "token" : undefined);
        receive({
          type: "welcome",
          protocol: 1,
          connection_id: 1,
          resume_status: identity ? "resumed" : "join_required",
          ...(identity
            ? {
                player,
                session_id: "session",
                reconnect_token: "token",
                gameplay: { type: "lobby", player },
              }
            : {}),
        });
        assert.equal(el("#app-screen").hidden, true);
        assert.equal(el("#selection-screen").hidden, identity);
        assert.equal(messages.filter((m) => m.type === "join").length, 0);
        if (!identity) assert.match(el("#status").textContent, /leave that controller first/);
      },
    );
});

test("actual Bubbles handlers send once immediately, cancel on lifecycle, and never request fullscreen", async (t) => {
  await withController(
    { standalone: true, identity: true },
    async ({ el, receive, player, document, window, messages, fullscreen }) => {
      receive({
        type: "welcome",
        protocol: 1,
        connection_id: 1,
        resume_status: "resumed",
        player,
        session_id: "session",
        reconnect_token: "token",
      });
      receive({ type: "bubbles_snapshot", phase: "active" });
      const pad = el("#bubbles-pad");
      const pointer = (type, id, x = 90) =>
        Object.assign(new Event(type, { cancelable: true }), {
          pointerId: id,
          clientX: x,
          clientY: 200,
          pointerType: "touch",
        });
      const timing = [];
      for (let id = 0; id < 100; id++) {
        const start = performance.now();
        pad.dispatchEvent(pointer("pointerdown", id));
        const sent = messages.at(-1);
        assert.equal(sent.stage, "start");
        timing.push(sent.sentAt - start);
        pad.dispatchEvent(pointer("pointerup", id, 300));
        pad.dispatchEvent(pointer("pointerup", id, 300)); // A duplicate release produces no second trace.
      }
      assert.equal(messages.filter((m) => m.type === "bubbles_trace").length, 100);
      for (const [target, name] of [
        [pad, "pointercancel"],
        [pad, "lostpointercapture"],
        [window, "blur"],
        [window, "resize"],
        [window, "orientationchange"],
        [document, "visibilitychange"],
      ]) {
        pad.dispatchEvent(pointer("pointerdown", 200));
        document.hidden = name === "visibilitychange";
        target.dispatchEvent(pointer(name, 200));
        assert.equal(messages.at(-1).stage, "cancel");
        const count = messages.length;
        pad.dispatchEvent(pointer("pointerup", 200, 300));
        assert.equal(messages.length, count);
      }
      assert.equal(fullscreen(), 0);
      timing.sort((a, b) => a - b);
      t.diagnostic(
        `Synthetic pointerdown-to-send, fake transport, n=100: median=${timing[50].toFixed(3)}ms p95=${timing[95].toFixed(3)}ms max=${timing.at(-1).toFixed(3)}ms. Physical responsiveness unmeasured.`,
      );
    },
  );
});
