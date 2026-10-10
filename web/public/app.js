// build/immersive.js
async function attemptImmersive(requestFullscreen, requestOrientationLock) {
  try {
    await requestFullscreen?.();
  } catch {
  }
  try {
    await requestOrientationLock?.();
  } catch {
  }
}
function protectControllerSurface(surface) {
  const prevent = (event) => {
    if (!surface.hidden && event.cancelable)
      event.preventDefault();
  };
  surface.addEventListener("touchstart", (event) => {
    if (event.touches.length > 1)
      prevent(event);
  }, { passive: false });
  for (const name of [
    "touchmove",
    "gesturestart",
    "gesturechange",
    "gestureend",
    "contextmenu",
    "selectstart"
  ]) {
    surface.addEventListener(name, prevent, { passive: false });
  }
}
function bindControllerLifecycle(cancel, target = window, page = document) {
  const bindings = [];
  const listen = (surface, name, handler) => {
    surface.addEventListener(name, handler);
    bindings.push(() => surface.removeEventListener(name, handler));
  };
  const resize = (event) => {
    page.documentElement.style.setProperty("--controller-height", `${target.visualViewport?.height ?? target.innerHeight}px`);
    cancel(event);
  };
  listen(target, "blur", cancel);
  listen(target, "pagehide", cancel);
  listen(page, "visibilitychange", (event) => {
    if (page.hidden)
      cancel(event);
  });
  listen(target, "resize", resize);
  listen(target, "orientationchange", resize);
  if (target.visualViewport)
    listen(target.visualViewport, "resize", resize);
  listen(page, "fullscreenchange", resize);
  resize();
  return () => {
    for (const unbind of bindings)
      unbind();
  };
}

// build/pwa.js
function isStandalone(target, browser) {
  return target.matchMedia("(display-mode: standalone)").matches || target.matchMedia("(display-mode: fullscreen)").matches || browser.standalone === true;
}
function installGuidance(browser) {
  const ios = /iPhone|iPad|iPod/.test(browser.userAgent) || browser.platform === "MacIntel" && browser.maxTouchPoints > 1;
  return ios ? "In Safari, tap Share → Add to Home Screen. Keep Open as Web App on if shown, then tap Add. Open the new icon before joining." : "Open your browser menu and choose Install app or Add to Home Screen if offered. Then launch Play Shapes from its icon. Otherwise, continue in your browser.";
}
var PwaOnboarding = class {
  panel;
  action;
  guidance;
  onContinue;
  target;
  browser;
  pending;
  dismissed = false;
  busy = false;
  constructor(panel, action, guidance, continueButton, onContinue, target = window, browser = navigator) {
    this.panel = panel;
    this.action = action;
    this.guidance = guidance;
    this.onContinue = onContinue;
    this.target = target;
    this.browser = browser;
    try {
      this.dismissed = target.sessionStorage.getItem("play-shapes.app-offer-dismissed") === "yes";
    } catch {
    }
    target.addEventListener("beforeinstallprompt", (event) => {
      event.preventDefault();
      this.pending = event;
      if (!this.busy)
        this.action.textContent = "INSTALL APP";
    });
    target.addEventListener("appinstalled", () => {
      this.pending = void 0;
      this.rememberDismissal();
      this.guidance.hidden = false;
      this.guidance.textContent = "Open Play Shapes from its new icon before joining, or continue here in your browser.";
    });
    action.addEventListener("click", () => {
      void this.install();
    });
    continueButton.addEventListener("click", () => {
      if (this.busy)
        return;
      this.rememberDismissal();
      this.hide();
      this.onContinue();
    });
  }
  get visible() {
    return !this.panel.hidden;
  }
  show() {
    if (this.dismissed || isStandalone(this.target, this.browser))
      return false;
    this.panel.hidden = false;
    this.action.focus();
    return true;
  }
  hide() {
    this.panel.hidden = true;
  }
  rememberDismissal() {
    this.dismissed = true;
    try {
      this.target.sessionStorage.setItem("play-shapes.app-offer-dismissed", "yes");
    } catch {
    }
  }
  async install() {
    if (this.busy)
      return;
    this.guidance.hidden = false;
    this.guidance.textContent = installGuidance(this.browser);
    const event = this.pending;
    if (!event)
      return;
    this.pending = void 0;
    this.busy = true;
    this.action.disabled = true;
    try {
      await event.prompt();
      const choice = await event.userChoice;
      if (choice.outcome === "accepted") {
        this.rememberDismissal();
        this.guidance.textContent = "Open Play Shapes from its new icon before joining, or continue here in your browser.";
      }
    } catch {
    } finally {
      this.busy = false;
      this.action.disabled = false;
      this.action.textContent = this.pending ? "INSTALL APP" : "HOW TO ADD THE APP";
    }
  }
};

// build/screen_wake_lock.js
function bindScreenWakeLock(page = document, target = window, wakeLock = navigator.wakeLock) {
  let sentinel;
  let pending = false;
  let retry2 = false;
  let suspended = false;
  let stopped2 = false;
  let generation = 0;
  const visible = () => !stopped2 && !suspended && page.visibilityState === "visible";
  const release = (lock) => {
    if (lock && !lock.released)
      void lock.release().catch(() => {
      });
  };
  const request = async () => {
    if (!wakeLock || !visible() || sentinel)
      return;
    if (pending) {
      retry2 = true;
      return;
    }
    pending = true;
    const requestedGeneration = generation;
    try {
      const lock = await wakeLock.request("screen");
      if (!visible() || requestedGeneration !== generation) {
        release(lock);
        return;
      }
      if (lock.released)
        return;
      sentinel = lock;
      lock.addEventListener("release", () => {
        if (sentinel === lock)
          sentinel = void 0;
      });
    } catch {
    } finally {
      pending = false;
      if (retry2) {
        retry2 = false;
        void request();
      }
    }
  };
  const retire = () => {
    generation++;
    retry2 = false;
    release(sentinel);
    sentinel = void 0;
  };
  const visibility = () => {
    if (visible())
      void request();
    else
      retire();
  };
  const hide = () => {
    suspended = true;
    retire();
  };
  const show = () => {
    suspended = false;
    void request();
  };
  const interact = () => {
    void request();
  };
  page.addEventListener("visibilitychange", visibility);
  page.addEventListener("pointerdown", interact);
  page.addEventListener("keydown", interact);
  target.addEventListener("pagehide", hide);
  target.addEventListener("pageshow", show);
  void request();
  return () => {
    stopped2 = true;
    retire();
    page.removeEventListener("visibilitychange", visibility);
    page.removeEventListener("pointerdown", interact);
    page.removeEventListener("keydown", interact);
    target.removeEventListener("pagehide", hide);
    target.removeEventListener("pageshow", show);
  };
}

// build/motion_input.js
var SENSOR_STALE_MSEC = 1e3;
var numberOrNull = (value) => typeof value === "number" && Number.isFinite(value) ? value : null;
var vector = (value) => [
  numberOrNull(value?.x),
  numberOrNull(value?.y),
  numberOrNull(value?.z)
];
function browserSensors() {
  const host = window;
  return {
    target: window,
    secure: window.isSecureContext,
    motion: host.DeviceMotionEvent,
    orientation: host.DeviceOrientationEvent,
    now: () => performance.now(),
    screenAngle: () => screen.orientation?.angle ?? host.orientation ?? 0
  };
}
var MotionInput = class {
  environment;
  motionPermission = "unknown";
  orientationPermission = "unknown";
  active = false;
  suspended = false;
  desired = false;
  generation = 0;
  pending = false;
  motionAt = null;
  orientationAt = null;
  started = 0;
  motionCount = 0;
  orientationCount = 0;
  raw = this.emptyRaw();
  constructor(environment = browserSensors()) {
    this.environment = environment;
    if (!environment.motion)
      this.motionPermission = "unavailable";
    if (!environment.orientation)
      this.orientationPermission = "unavailable";
  }
  emptyRaw() {
    return {
      orientation: [null, null, null],
      absolute: false,
      rotation_rate: [null, null, null],
      acceleration: [null, null, null],
      acceleration_gravity: [null, null, null],
      interval_msec: null
    };
  }
  motion = (event) => {
    const value = event;
    this.raw.rotation_rate = [
      numberOrNull(value.rotationRate?.alpha),
      numberOrNull(value.rotationRate?.beta),
      numberOrNull(value.rotationRate?.gamma)
    ];
    this.raw.acceleration = vector(value.acceleration);
    this.raw.acceleration_gravity = vector(value.accelerationIncludingGravity);
    this.raw.interval_msec = numberOrNull(value.interval);
    this.motionAt = this.environment.now();
    this.motionCount++;
  };
  orientation = (event) => {
    const value = event;
    this.raw.orientation = [
      numberOrNull(value.alpha),
      numberOrNull(value.beta),
      numberOrNull(value.gamma)
    ];
    this.raw.absolute = value.absolute === true;
    this.orientationAt = this.environment.now();
    this.orientationCount++;
  };
  // Invoke BOTH permission APIs synchronously in the gesture before awaiting either.
  async requestPermission() {
    if (!this.environment.secure || this.pending)
      return;
    this.stop();
    this.desired = true;
    this.suspended = false;
    this.pending = true;
    const generation = this.generation;
    const request = (api) => {
      if (!api)
        return Promise.resolve("unavailable");
      if (!api.requestPermission)
        return Promise.resolve("unknown");
      try {
        return Promise.resolve(api.requestPermission()).then((value) => value === "granted" ? "granted" : "denied", () => "error");
      } catch {
        return Promise.resolve("error");
      }
    };
    const motion = request(this.environment.motion), orientation = request(this.environment.orientation);
    const permissions = await Promise.all([motion, orientation]);
    if (generation !== this.generation)
      return;
    [this.motionPermission, this.orientationPermission] = permissions;
    this.pending = false;
    this.startListeners();
  }
  startListeners() {
    if (!this.desired || this.active || this.suspended || !this.environment.secure)
      return;
    this.raw = this.emptyRaw();
    this.motionAt = this.orientationAt = null;
    this.motionCount = this.orientationCount = 0;
    this.started = this.environment.now();
    if (["unknown", "granted"].includes(this.motionPermission) && this.environment.motion)
      this.environment.target.addEventListener("devicemotion", this.motion);
    if (["unknown", "granted"].includes(this.orientationPermission) && this.environment.orientation)
      this.environment.target.addEventListener("deviceorientation", this.orientation);
    this.active = !!(this.environment.motion && ["unknown", "granted"].includes(this.motionPermission) || this.environment.orientation && ["unknown", "granted"].includes(this.orientationPermission));
  }
  suspend() {
    this.removeListeners();
    this.suspended = true;
    this.raw = this.emptyRaw();
    this.motionAt = this.orientationAt = null;
  }
  resume() {
    this.suspended = false;
    this.startListeners();
  }
  stop() {
    this.generation++;
    this.pending = false;
    this.desired = false;
    this.removeListeners();
    this.raw = this.emptyRaw();
    this.motionAt = this.orientationAt = null;
  }
  removeListeners() {
    this.environment.target.removeEventListener("devicemotion", this.motion);
    this.environment.target.removeEventListener("deviceorientation", this.orientation);
    this.active = false;
  }
  sample() {
    const now = this.environment.now(), seconds = Math.max((now - this.started) / 1e3, 1e-3);
    return {
      ...this.raw,
      orientation: [...this.raw.orientation],
      rotation_rate: [...this.raw.rotation_rate],
      acceleration: [...this.raw.acceleration],
      acceleration_gravity: [...this.raw.acceleration_gravity],
      screen_angle: this.environment.screenAngle(),
      orientation_age_msec: this.orientationAt === null ? null : now - this.orientationAt,
      motion_age_msec: this.motionAt === null ? null : now - this.motionAt,
      orientation_hz: this.active ? this.orientationCount / seconds : 0,
      motion_hz: this.active ? this.motionCount / seconds : 0
    };
  }
  status() {
    if (!this.environment.secure)
      return "insecure";
    if (!this.environment.motion && !this.environment.orientation)
      return "unsupported";
    if (this.pending)
      return "requesting";
    if (this.suspended)
      return "suspended";
    if (!this.active)
      return this.motionPermission === "denied" || this.orientationPermission === "denied" ? "denied" : this.motionPermission === "error" || this.orientationPermission === "error" ? "error" : "idle";
    const sample = this.sample();
    const ages = [sample.orientation_age_msec, sample.motion_age_msec];
    return ages.some((age) => age !== null && age <= SENSOR_STALE_MSEC) ? "live" : ages.some((age) => age !== null) ? "stale" : "waiting";
  }
  capabilities() {
    return {
      secure_context: this.environment.secure,
      motion_support: !!this.environment.motion,
      orientation_support: !!this.environment.orientation,
      motion_permission: this.motionPermission,
      orientation_permission: this.orientationPermission,
      state: this.status()
    };
  }
};

// build/motion_stream.js
var MotionStream = class {
  connection;
  reading;
  input;
  maximumBufferedBytes;
  timer;
  subscription;
  sequence = 0;
  statusAt = -Infinity;
  sampleAt = -Infinity;
  sent = 0;
  started = 0;
  interval = 34;
  statusState = "";
  controlState;
  onControlState;
  constructor(connection, reading = () => {
  }, input = new MotionInput(), maximumBufferedBytes = 0) {
    this.connection = connection;
    this.reading = reading;
    this.input = input;
    this.maximumBufferedBytes = maximumBufferedBytes;
  }
  get active() {
    return !!this.subscription;
  }
  visibility = () => {
    if (document.hidden)
      this.input.suspend();
    else
      this.input.resume();
    this.tick();
  };
  pagehide = () => {
    this.stop();
  };
  begin(subscription) {
    this.stop();
    this.subscription = subscription;
    this.sequence = this.sent = 0;
    this.started = performance.now();
    this.statusAt = this.sampleAt = -Infinity;
    this.statusState = "";
    this.interval = Math.ceil(1e3 / Math.max(1, Math.min(30, subscription.send_hz)));
    document.addEventListener("visibilitychange", this.visibility);
    window.addEventListener("pagehide", this.pagehide);
    this.timer = setInterval(() => this.tick(), this.interval);
    this.tick();
  }
  stop(subscriptionId) {
    if (subscriptionId !== void 0 && subscriptionId !== this.subscription?.subscription_id)
      return false;
    clearInterval(this.timer);
    this.timer = void 0;
    this.subscription = void 0;
    this.controlState = void 0;
    this.input.stop();
    document.removeEventListener("visibilitychange", this.visibility);
    window.removeEventListener("pagehide", this.pagehide);
    return true;
  }
  async requestPermission() {
    if (!this.active)
      return;
    const request = this.input.requestPermission();
    this.tick();
    await request;
    if (this.active && document.hidden)
      this.input.suspend();
    this.tick();
  }
  requestCalibration(context) {
    return this.send({ type: "motion_calibrate", ...context });
  }
  feedback(subscriptionId, state) {
    if (subscriptionId !== this.subscription?.subscription_id)
      return false;
    if (typeof state?.calibrated !== "boolean" || typeof state.usable !== "boolean" || state.landscape !== void 0 && typeof state.landscape !== "boolean" || typeof state.capture_state !== "string")
      return false;
    this.controlState = { ...state };
    this.onControlState?.({ ...state });
    return true;
  }
  send(payload) {
    const socket2 = this.connection();
    if (!this.subscription || socket2?.readyState !== WebSocket.OPEN || socket2.bufferedAmount > this.maximumBufferedBytes)
      return false;
    socket2.send(JSON.stringify({ ...payload, subscription_id: this.subscription.subscription_id }));
    return true;
  }
  tick() {
    if (!this.subscription)
      return;
    const socket2 = this.connection();
    const diagnostics = {
      ...this.input.capabilities(),
      page_protocol: location.protocol,
      hostname: location.hostname,
      websocket_protocol: socket2 ? new URL(socket2.url).protocol : location.protocol === "https:" ? "wss:" : "ws:",
      websocket_status: socket2?.readyState === WebSocket.OPEN ? "open" : "closed"
    };
    const now = performance.now();
    const transmittedHz = this.sent / Math.max((now - this.started) / 1e3, 1e-3);
    if ((now - this.statusAt >= 250 || diagnostics.state !== this.statusState) && this.send({ type: "motion_status", diagnostics, transmitted_hz: transmittedHz })) {
      this.statusAt = now;
      this.statusState = diagnostics.state;
    }
    const sample = this.input.sample();
    if (this.input.active && !document.hidden && diagnostics.state === "live" && now - this.sampleAt >= this.interval && this.send({ type: "motion_sample", sequence: this.sequence + 1, sample })) {
      this.sequence++;
      this.sent++;
      this.sampleAt = now;
    }
    this.reading({
      diagnostics,
      sample,
      transmittedHz: this.sent / Math.max((now - this.started) / 1e3, 1e-3)
    });
  }
};

// build/motion_lab.js
var MotionLabController = class {
  panel;
  button;
  stream;
  constructor(panel, button, readings, connection) {
    this.panel = panel;
    this.button = button;
    this.stream = new MotionStream(connection, (value) => {
      readings.textContent = [
        JSON.stringify(value.diagnostics, null, 2),
        `Sent: ${value.transmittedHz.toFixed(1)} Hz`,
        formatSample(value.sample)
      ].join("\n");
    }, new MotionInput(), 8191);
    button.addEventListener("click", () => {
      if (!this.active)
        return;
      button.disabled = true;
      void this.stream.requestPermission().finally(() => {
        button.disabled = false;
      });
    });
  }
  get active() {
    return this.stream.active;
  }
  begin(subscription) {
    this.stream.begin(subscription);
    this.panel.hidden = false;
    this.button.disabled = false;
  }
  stop(subscriptionId) {
    if (this.stream.stop(subscriptionId))
      this.panel.hidden = true;
  }
  disconnect() {
    this.stop();
  }
  tick() {
    this.stream.tick();
  }
};
function formatSample(sample) {
  const motionAge = sample.motion_age_msec ?? "unavailable";
  const orientationAge = sample.orientation_age_msec ?? "unavailable";
  return [
    "Orientation [alpha, beta, gamma] degrees",
    `${JSON.stringify(sample.orientation)} (${sample.absolute ? "absolute" : "relative"})`,
    "Rotation [alpha, beta, gamma] degrees/s",
    JSON.stringify(sample.rotation_rate),
    "Acceleration [x,y,z] m/s²",
    JSON.stringify(sample.acceleration),
    "Including gravity [x,y,z] m/s²",
    JSON.stringify(sample.acceleration_gravity),
    `Event interval: ${sample.interval_msec ?? "unavailable"} ms`,
    `Motion: ${sample.motion_hz.toFixed(1)} Hz, age ${motionAge} ms`,
    `Orientation: ${sample.orientation_hz.toFixed(1)} Hz, age ${orientationAge} ms`,
    `Screen angle: ${sample.screen_angle}°`,
    "null = unavailable"
  ].join("\n");
}

// build/003_tilt_shift/tilt_shift_phone.js
function validTiltSnapshot(value) {
  if (!value || typeof value !== "object")
    return false;
  const v2 = value;
  return v2.type === "tilt_shift_snapshot" && typeof v2.generation === "string" && v2.generation.length > 0 && v2.generation.length <= 64 && Number.isSafeInteger(v2.sequence) && v2.sequence >= 0 && ["preparing", "countdown", "start", "active", "between_rounds", "finished"].includes(v2.phase) && Number.isInteger(v2.round) && v2.round >= 1 && v2.round <= 24 && (v2.team === 0 || v2.team === 1) && Number.isFinite(v2.angle_radians) && Array.isArray(v2.paddle_ids) && (v2.paddle_ids.length >= 1 || v2.selected === false) && v2.paddle_ids.length <= 5 && new Set(v2.paddle_ids).size === v2.paddle_ids.length && (v2.selected === void 0 || typeof v2.selected === "boolean") && (v2.round_token === void 0 || typeof v2.round_token === "string" && v2.round_token.length > 0 && v2.round_token.length <= 64) && [
    v2.ready,
    v2.ready_available,
    v2.calibration_available,
    v2.calibrated,
    v2.usable,
    v2.landscape
  ].every((flag) => flag === void 0 || typeof flag === "boolean") && v2.paddle_ids.every((id) => typeof id === "string" && id.length > 0 && id.length <= 96) && Array.isArray(v2.paddle_size) && v2.paddle_size.length === 2 && v2.paddle_size.every((size) => Number.isFinite(size) && size > 0 && size <= 2);
}
var TiltShiftPhone = class {
  surface;
  stream;
  sendReady;
  isLandscape;
  canvas;
  context;
  actions;
  permission;
  calibration;
  ready;
  state;
  orientation;
  images = [];
  bounds = [];
  angle = 0;
  ratio = 6;
  team = 2;
  generation;
  sequence = -1;
  preparing = false;
  readyAvailable = false;
  selected = true;
  roundToken;
  connected = false;
  usable = false;
  calibrated = false;
  landscape = false;
  isReady = false;
  capture = "waiting";
  observer;
  constructor(surface, stream, sendReady, isLandscape = () => window.matchMedia("(orientation: landscape)").matches) {
    this.surface = surface;
    this.stream = stream;
    this.sendReady = sendReady;
    this.isLandscape = isLandscape;
    this.canvas = surface.querySelector("canvas");
    this.context = this.canvas.getContext("2d");
    this.actions = surface.querySelector("#tilt-actions");
    this.permission = surface.querySelector("#tilt-permission");
    this.calibration = surface.querySelector("#tilt-calibrate");
    this.ready = surface.querySelector("#tilt-ready");
    this.state = surface.querySelector("#tilt-state");
    this.orientation = surface.querySelector("#tilt-orientation");
    this.permission.addEventListener("click", () => {
      this.permission.disabled = true;
      void this.stream.requestPermission().finally(() => this.buttons());
    });
    this.calibration.addEventListener("click", () => {
      if (this.stream.requestCalibration(this.actionContext()))
        this.calibration.disabled = true;
    });
    this.ready.addEventListener("click", () => {
      if (this.ready.disabled)
        return;
      this.ready.disabled = true;
      this.sendReady(!this.isReady, this.actionContext());
    });
    this.observer = new ResizeObserver(() => {
      this.buttons();
      this.draw();
    });
    this.observer.observe(this.canvas);
    void this.loadArt();
  }
  async loadArt() {
    const response = await fetch("/tilt-shift/manifest.json");
    if (!response.ok)
      throw new Error("Tilt Shift artwork metadata could not load");
    const manifest = await response.json();
    for (const name of ["orange", "blue", "neutral"]) {
      const image = new Image();
      image.src = `/tilt-shift/paddle_${name}.png`;
      this.images.push(image);
      this.bounds.push(manifest.assets[`paddles/paddle_${name}.png`].visible_bounds_px);
      image.addEventListener("load", () => this.draw());
    }
  }
  preparation(value, ready) {
    if (typeof value?.generation !== "string" || !Number.isFinite(value.angle_radians))
      return false;
    if (typeof value.usable !== "boolean" || typeof value.calibrated !== "boolean")
      return false;
    this.generation = value.generation;
    this.sequence = -1;
    this.preparing = this.readyAvailable = this.selected = this.connected = true;
    this.roundToken = void 0;
    this.usable = value.usable;
    this.calibrated = value.calibrated;
    this.landscape = value.landscape === true;
    this.capture = value.capture_state;
    this.angle = value.angle_radians;
    if (Array.isArray(value.paddle_size) && value.paddle_size.length === 2 && value.paddle_size.every((size) => Number.isFinite(size) && size > 0))
      this.ratio = value.paddle_size[0] / value.paddle_size[1];
    this.isReady = ready;
    this.team = 2;
    this.surface.hidden = false;
    this.canvas.hidden = false;
    this.surface.setAttribute("data-waiting", "false");
    this.surface.setAttribute("data-team", String(this.team));
    this.actions.hidden = false;
    this.buttons();
    this.draw();
    return true;
  }
  snapshot(value) {
    if (!validTiltSnapshot(value))
      return false;
    if (this.generation !== void 0 && value.generation !== this.generation)
      return false;
    if (value.sequence < this.sequence)
      return false;
    this.generation = value.generation;
    this.sequence = value.sequence;
    this.preparing = value.calibration_available === true;
    this.readyAvailable = value.ready_available === true;
    this.selected = value.selected !== false;
    this.roundToken = value.round_token;
    this.isReady = value.ready === true;
    if (value.usable !== void 0)
      this.usable = value.usable;
    if (value.calibrated !== void 0)
      this.calibrated = value.calibrated;
    this.landscape = value.landscape === true;
    this.connected = true;
    this.team = value.team;
    this.angle = value.angle_radians;
    this.ratio = value.paddle_size[0] / value.paddle_size[1];
    this.surface.hidden = value.phase === "finished";
    this.canvas.hidden = !this.selected;
    this.surface.setAttribute("data-waiting", String(!this.selected));
    this.surface.setAttribute("data-team", String(this.team));
    this.buttons();
    this.draw();
    return true;
  }
  feedback() {
    const state = this.stream.controlState;
    if (!state)
      return;
    this.capture = state.capture_state;
    this.usable = state.usable;
    this.calibrated = state.calibrated;
    this.landscape = state.landscape === true;
    this.buttons();
  }
  disconnect() {
    this.connected = this.usable = false;
    this.buttons();
  }
  hide() {
    this.surface.hidden = true;
    this.generation = void 0;
    this.sequence = -1;
    this.preparing = this.connected = this.usable = false;
  }
  actionContext() {
    return this.roundToken && this.generation ? { generation: this.generation, round_token: this.roundToken } : void 0;
  }
  buttons() {
    const landscape = this.landscape && this.isLandscape();
    this.orientation.hidden = !this.preparing;
    this.orientation.textContent = landscape ? "Hold your phone in landscape while you get ready." : "Turn your phone to landscape. If it stays upright, turn off rotation lock.";
    this.permission.hidden = this.usable;
    this.permission.disabled = !this.connected || !this.stream.active;
    this.calibration.hidden = !this.preparing;
    this.calibration.disabled = !this.connected || !this.usable;
    this.ready.hidden = !this.readyAvailable;
    this.ready.disabled = !this.connected || !this.isReady && (!this.usable || !this.calibrated || !landscape);
    this.ready.textContent = this.isReady ? "CANCEL" : "READY";
    this.ready.setAttribute("aria-pressed", String(this.isReady));
    this.actions.hidden = !this.preparing && this.usable || !this.selected && !this.preparing;
    const blocked = {
      insecure: "Motion needs a secure connection",
      unsupported: "Motion is unavailable",
      denied: "Motion access was denied",
      error: "Motion access could not start",
      unavailable: "Motion is unavailable",
      degenerate_orientation: "Hold the screen toward you"
    };
    this.state.textContent = this.preparing && !this.usable ? blocked[this.capture] ?? "" : "";
    this.state.hidden = !this.state.textContent;
  }
  draw() {
    if (this.surface.hidden || !this.selected)
      return;
    const width = this.canvas.clientWidth, height = this.canvas.clientHeight;
    const dpr = Math.min(devicePixelRatio || 1, 2);
    this.canvas.width = Math.round(width * dpr);
    this.canvas.height = Math.round(height * dpr);
    const ctx = this.context;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, width, height);
    const image = this.images[this.team], bounds = this.bounds[this.team];
    if (!image?.complete || !image.naturalWidth || !bounds)
      return;
    const length = Math.min(width, height) * 0.82, thickness = length / this.ratio;
    const [sx, sy, right, bottom] = bounds;
    const sw = right - sx, sh = bottom - sy;
    const capPx = Math.min(96, sw * 0.25), cap = Math.min(capPx * thickness / sh, length * 0.25);
    ctx.translate(width / 2, height / 2);
    ctx.rotate(this.angle);
    ctx.drawImage(image, sx, sy, capPx, sh, -length / 2, -thickness / 2, cap, thickness);
    ctx.drawImage(image, sx + capPx, sy, sw - 2 * capPx, sh, -length / 2 + cap, -thickness / 2, length - 2 * cap, thickness);
    ctx.drawImage(image, right - capPx, sy, capPx, sh, length / 2 - cap, -thickness / 2, cap, thickness);
  }
};

// build/network_config.js
function controllerSocketUrl(config, pageUrl) {
  const page = new URL(pageUrl);
  if (!config || typeof config !== "object")
    throw new Error("Unsupported session");
  const values = config;
  const secure = page.protocol === "https:";
  if (page.protocol !== "http:" && !secure)
    throw new Error("Unsupported page protocol");
  if (values.protocol !== 1 || typeof values.session_id !== "string" || values.http_scheme !== (secure ? "https" : "http") || values.websocket_scheme !== (secure ? "wss" : "ws") || !Number.isInteger(values.websocket_port) || Number(values.websocket_port) < 1024 || Number(values.websocket_port) > 65535) {
    throw new Error("Invalid or mixed-content controller configuration");
  }
  const endpoint = new URL(page.origin);
  endpoint.protocol = secure ? "wss:" : "ws:";
  endpoint.port = String(values.websocket_port);
  return endpoint.href;
}

// build/squircle_v1.js
var ROOT = "/squircle-v1/";
var BLUE = [30, 136, 229];
var SquircleV1Canvas = class {
  clip;
  tile = [256, 256];
  colorable = new Image();
  neutral = new Image();
  blink = new Image();
  tinted = /* @__PURE__ */ new Map();
  constructor() {
    void this.load();
  }
  async load() {
    try {
      const response = await fetch(`${ROOT}manifest.json`);
      if (!response.ok)
        return;
      const manifest = await response.json();
      this.tile = manifest.resolution;
      this.clip = manifest.clips.find((clip) => clip.name === "idle" && clip.view === "front");
      this.colorable.src = `${ROOT}idle-front-colorable.png`;
      this.neutral.src = `${ROOT}idle-front-neutral.png`;
      this.blink.src = `${ROOT}idle-front-blink.png`;
    } catch {
    }
  }
  draw(context, color, x2, y2, scale, timeMsec, blinking = false, rotation = 0) {
    const clip = this.clip;
    const face = blinking ? this.blink : this.neutral;
    if (!clip || !this.colorable.complete || !face.complete || !this.colorable.naturalWidth || !face.naturalWidth)
      return false;
    const sheet = this.tint(color);
    if (!sheet)
      return false;
    const frame = Math.floor(Math.max(0, timeMsec) * clip.fps / 1e3) % clip.frames;
    const sx = frame % clip.sheet_columns * this.tile[0];
    const sy = Math.floor(frame / clip.sheet_columns) * this.tile[1];
    context.save();
    context.translate(x2, y2);
    context.rotate(rotation);
    for (const layer of [sheet, face])
      context.drawImage(layer, sx, sy, this.tile[0], this.tile[1], -clip.anchor_px[0] * scale, -clip.anchor_px[1] * scale, this.tile[0] * scale, this.tile[1] * scale);
    context.restore();
    return true;
  }
  tint(color) {
    const key = /^#[0-9a-f]{6}$/i.test(color) ? color.toUpperCase() : "#1E88E5";
    const cached = this.tinted.get(key);
    if (cached)
      return cached;
    const canvas = document.createElement("canvas");
    canvas.width = this.colorable.naturalWidth;
    canvas.height = this.colorable.naturalHeight;
    const context = canvas.getContext("2d", { willReadFrequently: true });
    if (!context)
      return void 0;
    context.drawImage(this.colorable, 0, 0);
    const image = context.getImageData(0, 0, canvas.width, canvas.height);
    const rgb = [1, 3, 5].map((index) => Number.parseInt(key.slice(index, index + 2), 16));
    for (let offset = 0; offset < image.data.length; offset += 4) {
      if (image.data[offset + 3] === 0)
        continue;
      const diffuse = Math.min(1.4, Math.max(0, (image.data[offset + 2] - image.data[offset]) / 199));
      for (let channel = 0; channel < 3; channel++)
        image.data[offset + channel] = Math.min(255, Math.max(0, image.data[offset + channel] + diffuse * (rgb[channel] - BLUE[channel])));
    }
    context.putImageData(image, 0, 0);
    this.tinted.set(key, canvas);
    return canvas;
  }
};

// build/002_bubbles_and_jellyfishes/bubbles_gesture.js
var MAX_TRACE_POINTS = 128;
var GestureTrace = class {
  bounds;
  points = [];
  constructor(bounds) {
    this.bounds = bounds;
  }
  add(clientX, clientY) {
    if (!Number.isFinite(clientX) || !Number.isFinite(clientY) || this.bounds.width <= 0 || this.bounds.height <= 0)
      return;
    const point = [
      Math.max(0, Math.min(1, (clientX - this.bounds.left) / this.bounds.width)),
      Math.max(0, Math.min(1, (clientY - this.bounds.top) / this.bounds.height))
    ];
    const last = this.points.at(-1);
    if (last && Math.hypot(point[0] - last[0], point[1] - last[1]) < 4e-3)
      return;
    this.points.push(point);
    if (this.points.length > MAX_TRACE_POINTS) {
      this.points = this.points.filter((_2, index) => index === 0 || index === this.points.length - 1 || index % 2 === 0);
    }
  }
  completed() {
    return this.points.length >= 2 ? this.points.map((point) => [...point]) : [];
  }
  displacement() {
    if (this.points.length < 2)
      return [0, 0];
    const first = this.points[0];
    const last = this.points.at(-1);
    return [last[0] - first[0], last[1] - first[1]];
  }
  preview(circlesToCharge) {
    if (this.points.length < 6)
      return 0;
    const center = this.points.reduce(([x2, y2], point) => [x2 + point[0], y2 + point[1]], [0, 0]).map((value) => value / this.points.length);
    let signed = 0;
    let absolute = 0;
    for (let index = 1; index < this.points.length; index++) {
      const before = Math.atan2(this.points[index - 1][1] - center[1], this.points[index - 1][0] - center[0]);
      const after = Math.atan2(this.points[index][1] - center[1], this.points[index][0] - center[0]);
      const step = Math.atan2(Math.sin(after - before), Math.cos(after - before));
      signed += step;
      absolute += Math.abs(step);
    }
    if (absolute < Math.PI * 0.75 || Math.abs(signed) / absolute < 0.65)
      return 0;
    return Math.min(1, Math.abs(signed) / (Math.PI * 2 * Math.max(1, circlesToCharge)));
  }
};

// build/vendor/nipplejs.mjs
var t = "dynamic";
var i = "semi";
var e = "static";
var s = "undefined" != typeof window && "ontouchstart" in window;
var o = { start: "mousedown", move: "mousemove", end: "mouseup, mouseleave", pressure: "webkitmouseforcechanged" };
var n;
var r;
"undefined" != typeof window && !!window.PointerEvent ? n = { start: "pointerdown", move: "pointermove", end: "pointerup, pointercancel, pointerleave", pressure: "webkitmouseforcechanged" } : s ? (n = { start: "touchstart", move: "touchmove", end: "touchend, touchcancel", pressure: "webkitmouseforcechanged" }, r = o) : n = o;
var d = n;
var h = r;
var a = Math.PI / 4;
var l = Math.PI / 2;
var c = (t2, i3) => {
  const e2 = i3.x - t2.x, s3 = i3.y - t2.y;
  return Math.sqrt(e2 * e2 + s3 * s3);
};
var p = (t2) => t2 * (Math.PI / 180);
var u = (t2) => t2 * (180 / Math.PI);
var y = /* @__PURE__ */ new Map();
var f = (t2) => {
  y.has(t2) && clearTimeout(y.get(t2)), y.set(t2, setTimeout(t2, 100));
};
var m = (t2, i3, e2) => {
  const s3 = i3.split(/[ ,]+/g);
  for (let i4 = 0; i4 < s3.length; i4 += 1) t2.addEventListener(s3[i4], e2, false);
};
var g = (t2, i3, e2) => {
  const s3 = i3.split(/[ ,]+/g);
  for (let i4 = 0; i4 < s3.length; i4 += 1) t2.removeEventListener(s3[i4], e2);
};
var v = (t2) => "force" in t2 ? t2.force : "pressure" in t2 ? t2.pressure : "webkitForce" in t2 ? t2.webkitForce / 3 : "buttons" in t2 && 0 !== t2.buttons ? 1 : 0;
var x = (t2, i3) => ({ identifier: "identifier" in i3 ? i3.identifier : "pointerId" in i3 ? i3.pointerId : 1, isTouch: "touches" in t2 || "changedTouches" in t2, position: { x: i3.pageX, y: i3.pageY }, pressure: v(i3), type: t2.type, initial: t2, raw: i3 });
var k = () => ({ x: window.scrollX, y: window.scrollY });
var b = (t2, i3) => {
  const { left: e2, top: s3, right: o2, bottom: n2, x: r2, y: d2 } = i3;
  s3 || o2 || n2 || e2 ? T(t2.style, { top: s3, right: o2, bottom: n2, left: e2 }) : ($(r2) || $(d2)) && T(t2.style, { left: $(r2) ? `${r2}px` : void 0, top: $(d2) ? `${d2}px` : void 0 });
};
var w = (t2, i3 = "") => ({ [t2]: i3 });
var T = (t2, i3) => {
  for (const e2 in i3) Object.hasOwn(i3, e2) && (t2[e2] = i3[e2]);
  return t2;
};
var $ = (t2) => "number" == typeof t2 && !isNaN(t2);
var z = { debug: 0, info: 1, warning: 2, error: 3, none: 4 };
var O = "warning";
var I = class {
  constructor(t2) {
    this.uid = 0, this.index = 0, this.name = "super", this._domHandlers_ = /* @__PURE__ */ new Map(), this._handlers_ = {}, this.name = t2, this.log("construct", this.name, this.index);
  }
  mapOnEvents(t2, i3) {
    const e2 = t2.split(/[ ,]+/g);
    for (let t3 = 0; t3 < e2.length; t3 += 1) i3(e2[t3]);
  }
  on(t2, i3) {
    this.mapOnEvents(t2, ((t3) => {
      this._handlers_[t3] = this._handlers_[t3] || /* @__PURE__ */ new Set(), this._handlers_[t3].add(i3);
    }));
  }
  off(t2, i3) {
    void 0 === t2 ? this._handlers_ = {} : this.mapOnEvents(t2, ((t3) => {
      void 0 === i3 ? this._handlers_[t3] = /* @__PURE__ */ new Set() : this._handlers_[t3] && this._handlers_[t3].delete(i3);
    }));
  }
  trigger(t2, i3) {
    this.mapOnEvents(t2, ((t3) => {
      this.log(`- "${t3}" [trigger]`);
      const e2 = this._handlers_[t3];
      if (e2 && e2.size) {
        const s3 = [...e2];
        for (const e3 of s3) e3.call(this, { type: t3, target: this, data: i3 });
      }
    }));
  }
  bindEvt(t2, i3, e2) {
    const s3 = (t3) => {
      for (const s4 of ((t4) => {
        t4.type.toLowerCase().includes("move") && t4.preventDefault();
        const i4 = [];
        if ("changedTouches" in t4) for (const e3 of Array.from(t4.changedTouches)) e3 && i4.push(e3);
        else i4.push(t4);
        return i4.map(((i5) => x(t4, i5)));
      })(t3)) this.log(`- "${i3}" [dom:trigger:${s4.identifier}]`), e2.call(this, s4);
    };
    this._domHandlers_.set(e2, s3), m(t2, d[i3], s3), h?.[i3] && m(t2, h[i3], s3);
  }
  unbindEvt(t2, i3, e2) {
    const s3 = this._domHandlers_.get(e2);
    s3 ? (g(t2, d[i3], s3), h?.[i3] && g(t2, h[i3], s3), this._domHandlers_.delete(e2)) : this.error(`Internal handler not found for event ${i3}.`, e2);
  }
  logPrefix() {
    return { super: "", joystick: "  ", collection: "    ", factory: "      " }[this.name];
  }
  logSuffix() {
    return `[${this.name}|${this.uid}]`;
  }
  static get logLevel() {
    return O;
  }
  static set logLevel(t2) {
    O = t2;
  }
  log(...t2) {
    z[O] <= z.debug && console.log(this.logPrefix(), ...t2, this.logSuffix());
  }
  info(...t2) {
    z[O] <= z.info && console.info(this.logPrefix(), ...t2, this.logSuffix());
  }
  warn(...t2) {
    z[O] <= z.warning && console.warn(this.logPrefix(), ...t2, this.logSuffix());
  }
  error(...t2) {
    z[O] <= z.error && console.error(this.logPrefix(), ...t2, this.logSuffix());
  }
};
var E = class i2 extends I {
  constructor(t2, e2) {
    super("joystick"), this.direction = {}, this.defaults = { size: 100, threshold: 0.1, color: "white", fadeTime: 250, dataOnly: false, restJoystick: true, restOpacity: 0.5, mode: "dynamic", zone: document.body, lockX: false, lockY: false, shape: "circle" }, this.position = e2.position, this.frontPosition = e2.frontPosition, this.collection = t2, this.options = { ...this.defaults, ...e2 }, "dynamic" === this.options.mode && (this.options.restOpacity = 0), this.uid = i2.index++, this.ui = { el: document.createElement("div"), back: document.createElement("div"), front: document.createElement("div") };
  }
  init() {
    this.options.dataOnly || this.buildEl(), this.trigger("added", this), this.trigger("joystickCreated", this);
  }
  get identifier() {
    return this._identifier;
  }
  set identifier(t2) {
    $(t2) ? (this._identifier = t2, this.trigger("attached", { collection: this.collection, joystick: this, identifier: t2 })) : (this.trigger("detached", { collection: this.collection, joystick: this, identifier: this._identifier }), this._identifier = void 0);
  }
  resolveColors() {
    const t2 = this.options.color;
    return "object" == typeof t2 && null !== t2 ? t2 : { front: t2, back: t2 };
  }
  buildEl() {
    this.ui.el.className = `joystick collection_${this.collection.uid}`, this.ui.back.className = "back", this.ui.front.className = "front", this.ui.el.setAttribute("id", `joystick_${this.collection.uid}_${this.uid}`), this.ui.el.appendChild(this.ui.back), this.ui.el.appendChild(this.ui.front);
    const t2 = `${this.options.fadeTime}ms`, i3 = w("borderRadius", "50%"), e2 = w("transition", `opacity ${t2}`), s3 = this.resolveColors();
    T(this.ui.el.style, { position: "absolute", opacity: this.options.restOpacity.toString(), display: "block", zIndex: "999", touchAction: "none", userSelect: "none", ...e2 }), T(this.ui.back.style, { position: "absolute", display: "block", width: `${this.options.size}px`, height: `${this.options.size}px`, left: "0", marginLeft: -this.options.size / 2 + "px", marginTop: -this.options.size / 2 + "px", background: s3.back, ..."circle" === this.options.shape ? i3 : {} }), T(this.ui.front.style, { width: this.options.size / 2 + "px", height: this.options.size / 2 + "px", position: "absolute", display: "block", left: "0", marginLeft: -this.options.size / 4 + "px", marginTop: -this.options.size / 4 + "px", background: s3.front, opacity: ".5", transform: "translate(0px, 0px)", ...i3 });
  }
  get pressure() {
    return this._pressure ?? 0;
  }
  set pressure(t2) {
    t2 !== this._pressure && (this._pressure = t2, this.trigger("pressure", t2));
  }
  startPressureInterval(t2) {
    this.pressureInterval || (this.pressureInterval = window.setInterval((() => {
      this.pressure = v(t2);
    }), 100));
  }
  stopPressureInterval() {
    clearInterval(this.pressureInterval), this.pressureInterval = void 0;
  }
  addToDom() {
    this.options.dataOnly || this.options.zone.contains(this.ui.el) || this.options.zone.appendChild(this.ui.el);
  }
  removeFromDom() {
    !this.options.dataOnly && this.options.zone.contains(this.ui.el) && this.options.zone.removeChild(this.ui.el);
  }
  clearTimeouts() {
    clearTimeout(this.removeTimeout), clearTimeout(this.showTimeout), clearTimeout(this.restTimeout), clearTimeout(this.activeTimeout), this.removeTimeout = void 0, this.showTimeout = void 0, this.restTimeout = void 0, this.activeTimeout = void 0;
  }
  start(t2, i3) {
    this.trigger("start", this), this.clearTimeouts(), this.options.dataOnly ? "function" == typeof i3 && i3.call(this) : (this.addToDom(), this.startPressureInterval(t2), requestAnimationFrame((() => {
      this.ui.el.style.opacity = "1";
    })), this.showTimeout = window.setTimeout((() => {
      this.showTimeout = void 0, this.trigger("shown", this), "function" == typeof i3 && i3.call(this);
    }), this.options.fadeTime));
  }
  end(i3) {
    if (this.resetDirection(), this.clearTimeouts(), this.stopPressureInterval(), this.pressure = 0, this.trigger("end", this), this.options.dataOnly) "function" == typeof i3 && i3.call(this);
    else {
      if (this.ui.el.style.opacity = this.options.restOpacity.toString(), this.options.restJoystick) {
        const t2 = this.options.restJoystick, e2 = { x: true === t2 || false !== t2.x ? 0 : this.frontPosition.x, y: true === t2 || false !== t2.y ? 0 : this.frontPosition.y };
        this.setPosition(i3, e2);
      }
      clearTimeout(this.removeTimeout), this.removeTimeout = window.setTimeout((() => {
        this.removeTimeout = void 0, this.ui.el.style.display = this.options.mode === t ? "none" : "block", this.trigger("hidden", this), this.options.mode === t && (this.trigger("removed", this), this.destroy()), "function" == typeof i3 && i3.call(this);
      }), this.options.fadeTime);
    }
  }
  setTransition(t2 = false, i3) {
    if (t2) {
      const t3 = 100, e2 = T(w("transition", `transform ${`${t3}ms`}`), w("transform", `translate(${this.frontPosition.x}px, ${this.frontPosition.y}px)`));
      T(this.ui.front.style, e2), clearTimeout(this.activeTimeout), this.activeTimeout = window.setTimeout((() => {
        this.activeTimeout = void 0, "function" == typeof i3 && i3.call(this);
      }), t3);
    } else T(this.ui.front.style, w("transition", "none"));
  }
  setPosition(t2, i3) {
    this.frontPosition = { x: i3.x, y: i3.y }, this.setTransition(true), clearTimeout(this.restTimeout), this.restTimeout = window.setTimeout((() => {
      this.restTimeout = void 0, "function" == typeof t2 && t2.call(this), this.setTransition(false), this.trigger("rested", this);
    }), this.options.fadeTime);
  }
  resetDirection() {
    this.direction = {};
  }
  computeDirectionAndTriggerEvents(t2) {
    const i3 = t2.angle.radian, e2 = {};
    return i3 > a && i3 < 3 * a && !t2.lockX ? e2.angle = "up" : i3 > -a && i3 <= a && !t2.lockY ? e2.angle = "left" : i3 > 3 * -a && i3 <= -a && !t2.lockX ? e2.angle = "down" : t2.lockY || (e2.angle = "right"), t2.lockY || (e2.x = i3 > -l && i3 < l ? "left" : "right"), t2.lockX || (e2.y = i3 > 0 ? "up" : "down"), t2.angle = { radian: p(180 - t2.angle.degree), degree: 180 - t2.angle.degree }, this.triggerDirectionEvents(t2, e2), t2;
  }
  triggerDirectionEvents(t2, i3) {
    if (t2.force > this.options.threshold) {
      const e2 = { x: this.direction.x, y: this.direction.y, angle: this.direction.angle };
      this.direction = i3, t2.direction = i3, e2.x !== i3.x && this.trigger(`plain plain:${i3.x}`, t2), e2.y !== i3.y && this.trigger(`plain plain:${i3.y}`, t2), e2.angle !== i3.angle && this.trigger(`dir dir:${i3.angle}`, t2);
    } else this.resetDirection();
    this.trigger("move", t2);
  }
  destroy() {
    this.clearTimeouts(), this.identifier = void 0, this.removeFromDom(), this.trigger("joystickDestroyed", this), this.off();
  }
};
E.index = 0;
var j = E;
var C = class s2 extends I {
  constructor(o2, n2) {
    super("collection"), this.all = /* @__PURE__ */ new Map(), this.idles = /* @__PURE__ */ new Set(), this.actives = /* @__PURE__ */ new Map(), this.resting = /* @__PURE__ */ new Map(), this.parentIsFlex = false, this.defaults = { catchDistance: 200, color: "white", dataOnly: false, dynamicPage: false, fadeTime: 250, follow: false, lockX: false, lockY: false, maxNumberOfJoysticks: 10, mode: t, multitouch: false, position: { top: "0px", left: "0px" }, restJoystick: true, restOpacity: 0.5, shape: "circle", size: 100, threshold: 0.1, zone: document.body }, this.factory = o2, this.uid = s2.index++, this.options = { ...this.defaults, ...n2 }, this.options.mode !== e && this.options.mode !== i || (this.options.multitouch = false), this.options.multitouch || (this.options.maxNumberOfJoysticks = 1);
    const r2 = this.options.zone.parentElement && getComputedStyle(this.options.zone.parentElement);
    "flex" === r2?.display && (this.parentIsFlex = true);
    "static" === getComputedStyle(this.options.zone).position && this.warn('The zone element has no CSS "position" set (it is "static").', "Joysticks may not be positioned correctly.", 'Set "position: relative" (or absolute/fixed) on the zone element.'), this.box = this.options.zone.getBoundingClientRect(), this.bindEvt(this.options.zone, "start", this.processOnStart), T(this.options.zone.style, { touchAction: "none", userSelect: "none", webkitUserSelect: "none" }), "undefined" != typeof ResizeObserver && (this.resizeObserver = new ResizeObserver((() => {
      this.reposition();
    })), this.resizeObserver.observe(this.options.zone));
  }
  init() {
    if (this.trigger("collectionCreated", this), this.options.mode === e) {
      this.createJoystick(this.options.position).addToDom();
    }
  }
  getJoystickByUid(t2) {
    return void 0 === t2 ? this.all.values().next().value : this.all.get(t2);
  }
  bindJoystick(t2) {
    t2.on("joystickDestroyed", (() => {
      this.deleteJoystickFromLists(t2);
    })), t2.on("attached", ((i3) => {
      this.idles.delete(i3.data.joystick.uid), this.actives.set(i3.data.identifier, t2);
    })), t2.on("detached", ((t3) => {
      this.idles.add(t3.data.joystick.uid), this.deleteIdentifierFromLists(t3.data.identifier);
    })), t2.on("end", ((i3) => {
      $(i3.data.identifier) && (this.actives.delete(i3.data.identifier), this.resting.set(i3.data.identifier, t2)), this.idles.add(i3.data.uid);
    })), t2.on("start", ((t3) => {
      $(t3.data.identifier) && this.resting.delete(t3.data.identifier);
    })), t2.on("hidden", ((t3) => {
      $(t3.data.identifier) && this.resting.delete(t3.data.identifier);
    })), t2.on("pressure", ((i3) => {
      this.trigger(`pressure ${t2.uid}:pressure`, i3.data);
    })), t2.on("attached detached", ((t3) => {
      const i3 = `${t3.type} ${t3.data.joystick.uid}:${t3.type}`;
      this.trigger(i3, t3.data);
    })), t2.on("added start shown hidden rested removed end joystickCreated joystickDestroyed", ((t3) => {
      const i3 = `${t3.type} ${t3.data.uid}:${t3.type}`;
      this.trigger(i3, t3.data);
    })), t2.on("move", ((t3) => {
      this.trigger(`move ${t3.data.instance.uid}:move`, t3.data);
    })), t2.on("dir dir:up dir:right dir:down dir:left", ((t3) => {
      const i3 = `${t3.type} ${t3.data.instance.uid}:${t3.type}`;
      this.trigger(i3, t3.data);
    })), t2.on("plain plain:up plain:right plain:down plain:left", ((t3) => {
      const i3 = `${t3.type} ${t3.data.instance.uid}:${t3.type}`;
      this.trigger(i3, t3.data);
    }));
  }
  deleteJoystickFromLists(t2) {
    this.deleteUidFromLists(t2.uid), $(t2.identifier) && this.deleteIdentifierFromLists(t2.identifier);
  }
  deleteUidFromLists(t2) {
    this.all.delete(t2), this.idles.delete(t2);
  }
  deleteIdentifierFromLists(t2) {
    this.actives.delete(t2), this.resting.delete(t2);
  }
  getOrCreate(t2) {
    if (this.options.mode === i || this.options.mode === e) {
      const e2 = this.idles.values().next().value;
      if ($(e2)) {
        const t3 = this.all.get(e2);
        if (t3) return t3;
        this.error(`Couldn't find the joystick ${e2}. Creating a new one.`), this.deleteUidFromLists(e2);
      }
      if (this.options.mode === i) return this.createJoystick(t2);
      this.warn("Couldn't find the expected joystick. Creating a new one.");
    }
    return this.createJoystick(t2);
  }
  createJoystick(t2) {
    const i3 = this.factory.scroll, e2 = this.parentIsFlex ? i3.x : i3.x + this.box.left, s3 = this.parentIsFlex ? i3.y : i3.y + this.box.top;
    let o2, n2;
    if ($(t2.x) && $(t2.y)) o2 = { x: t2.x - e2, y: t2.y - s3 }, n2 = { x: t2.x, y: t2.y };
    else {
      if (!(t2.top || t2.right || t2.bottom || t2.left)) return void this.error("Invalid or missing position.", t2);
      {
        const e3 = document.createElement("DIV");
        T(e3.style, { visibility: "hidden", position: "absolute", top: t2.top, right: t2.right, bottom: t2.bottom, left: t2.left }), this.options.zone.appendChild(e3);
        const s4 = e3.getBoundingClientRect();
        this.options.zone.removeChild(e3), o2 = t2, n2 = { x: s4.left + i3.x, y: s4.top + i3.y };
      }
    }
    const r2 = new j(this, { color: this.options.color, size: this.options.size, threshold: this.options.threshold, fadeTime: this.options.fadeTime, dataOnly: this.options.dataOnly, restJoystick: this.options.restJoystick, restOpacity: this.options.restOpacity, mode: this.options.mode, position: n2, zone: this.options.zone, frontPosition: { x: 0, y: 0 }, shape: this.options.shape });
    return this.all.has(r2.uid) && this.error(`Joystick with uid ${r2.uid} already exists.`), this.options.dataOnly || (b(r2.ui.el, o2), b(r2.ui.front, r2.frontPosition)), this.all.set(r2.uid, r2), this.idles.add(r2.uid), this.bindJoystick(r2), r2.init(), r2;
  }
  processOnStart(t2, e2 = 0) {
    if (this.box = this.options.zone.getBoundingClientRect(), !this.actives.has(t2.identifier) && this.actives.size >= this.options.maxNumberOfJoysticks) return void this.warn("No more joysticks allowed.");
    const s3 = this.actives.get(t2.identifier) || this.resting.get(t2.identifier) || this.getOrCreate(t2.position), o2 = () => {
      s3.start(t2.raw), s3.identifier = t2.identifier, this.processOnMove(t2, true);
    };
    if (this.options.mode === i) {
      c(t2.position, s3.position) <= this.options.catchDistance ? o2() : e2 < 3 ? (s3.destroy(), this.processOnStart(t2, e2 + 1)) : this.error("Max semi-mode recursion depth reached.");
    } else o2();
  }
  processOnMove(t2, i3 = false) {
    const e2 = this.actives.get(t2.identifier), s3 = this.factory.scroll;
    if (!e2) return this.error(`Found zombie joystick onMove with identifier ${t2.identifier}`), void this.deleteIdentifierFromLists(t2.identifier);
    this.options.dynamicPage && this.reposition();
    const o2 = e2.options.size / 2;
    let n2 = { x: t2.position.x, y: t2.position.y };
    this.options.lockX && (n2.y = e2.position.y), this.options.lockY && (n2.x = e2.position.x);
    let r2 = c(n2, e2.position);
    const d2 = ((t3, i4) => {
      const e3 = i4.x - t3.x, s4 = i4.y - t3.y;
      return u(Math.atan2(s4, e3));
    })(n2, e2.position), h2 = p(d2), a2 = r2 / o2, l2 = { distance: r2, position: n2 };
    let y2, f2;
    "circle" === e2.options.shape ? (y2 = Math.min(r2, o2), f2 = ((t3, i4, e3) => {
      const s4 = p(e3);
      return { x: t3.x - i4 * Math.cos(s4), y: t3.y - i4 * Math.sin(s4) };
    })(e2.position, y2, d2)) : (f2 = ((t3, i4, e3) => ({ x: Math.min(Math.max(t3.x, i4.x - e3), i4.x + e3), y: Math.min(Math.max(t3.y, i4.y - e3), i4.y + e3) }))(n2, e2.position, o2), y2 = c(f2, e2.position));
    let m2 = { x: 0, y: 0 };
    if (this.options.follow) {
      if (r2 > o2) {
        const t3 = n2.x - f2.x, i4 = n2.y - f2.y;
        m2 = { x: t3, y: -i4 }, e2.position.x += t3, e2.position.y += i4, T(e2.ui.el.style, { top: e2.position.y - (this.box.top + s3.y) + "px", left: e2.position.x - (this.box.left + s3.x) + "px" }), r2 = c(n2, e2.position);
      }
    } else n2 = f2, r2 = y2;
    const g2 = n2.x - e2.position.x, v2 = n2.y - e2.position.y;
    e2.frontPosition = { x: g2, y: v2 }, this.options.dataOnly || (i3 && e2.setTransition(true, (() => {
      e2.setTransition(false);
    })), e2.ui.front.style.transform = `translate(${g2}px,${v2}px)`);
    const x2 = { position: n2, force: a2, pressure: t2.pressure, distance: r2, angle: { radian: h2, degree: d2 }, vector: { x: g2 / o2, y: -v2 / o2 }, raw: l2, instance: e2, lockX: this.options.lockX, lockY: this.options.lockY, baseDelta: m2 };
    e2.computeDirectionAndTriggerEvents(x2);
  }
  processOnEnd(t2) {
    const i3 = this.actives.get(t2.identifier);
    if (!i3) return this.error(`Found zombie joystick onEnd with identifier ${t2.identifier}`), void this.deleteIdentifierFromLists(t2.identifier);
    i3.end();
  }
  reposition() {
    this.factory.scroll = k(), this.box = this.options.zone.getBoundingClientRect();
    const t2 = this.factory.scroll;
    this.all.forEach(((i3) => {
      if (i3.options.dataOnly) return;
      const e2 = i3.ui.el.getBoundingClientRect();
      i3.position = { x: t2.x + e2.left, y: t2.y + e2.top };
    }));
  }
  destroy() {
    this.resizeObserver && (this.resizeObserver.disconnect(), this.resizeObserver = void 0), this.unbindEvt(this.options.zone, "start", this.processOnStart), this.all.forEach(((t2) => {
      t2.destroy();
    })), this.all.clear(), this.idles.clear(), this.actives.clear(), this.resting.clear(), this.trigger("collectionDestroyed", this), this.off();
  }
};
C.index = 0;
var _ = C;
var D = new class extends I {
  constructor() {
    super("factory"), this.scroll = k(), this.binded = false, this.joysticksByUid = /* @__PURE__ */ new Map(), this.joysticksByIdentifier = /* @__PURE__ */ new Map(), this.collections = /* @__PURE__ */ new Set(), this.resizeHandler = null, this.scrollHandler = null, this.repositionAll = () => {
      this.collections.forEach(((t2) => {
        t2.reposition();
      }));
    }, this.refreshScroll = () => {
      this.scroll = k();
    }, this.bindResize(), this.bindScroll(), this.trigger("factoryCreated", this);
  }
  bindResize() {
    this.resizeHandler = () => f(this.repositionAll), m(window, "resize", this.resizeHandler);
  }
  bindScroll() {
    this.scrollHandler = () => f(this.refreshScroll), m(window, "scroll", this.scrollHandler);
  }
  getJoystickByUid(t2) {
    return this.joysticksByUid.get(t2);
  }
  getJoystickByIdentifier(t2) {
    return this.joysticksByIdentifier.get(t2);
  }
  create(t2) {
    const i3 = new _(this, t2);
    return this.bindCollection(i3), this.collections.add(i3), i3.init(), i3;
  }
  removeJoystickFromLists(t2) {
    this.joysticksByUid.delete(t2.uid), $(t2.identifier) && this.joysticksByIdentifier.delete(t2.identifier);
  }
  bindCollection(t2) {
    t2.on("collectionDestroyed", ((t3) => {
      this.collections.delete(t3.data), t3.data.all.forEach(((t4) => {
        this.removeJoystickFromLists(t4);
      })), this.unbindDocument();
    })), t2.on("joystickDestroyed", ((t3) => {
      this.removeJoystickFromLists(t3.data), this.unbindDocument();
    })), t2.on("end", ((t3) => {
      $(t3.data.identifier) && this.joysticksByIdentifier.delete(t3.data.identifier), this.unbindDocument();
    })), t2.on("added", ((t3) => {
      this.joysticksByUid.set(t3.data.uid, t3.data), this.bindDocument();
    })), t2.on("attached", ((t3) => {
      this.joysticksByIdentifier.set(t3.data.identifier, t3.data.joystick);
    })), t2.on("pressure", ((t3) => {
      this.trigger(`pressure ${t3.target.uid}:pressure`, t3.data);
    })), t2.on("collectionCreated collectionDestroyed", ((t3) => {
      const i3 = `${t3.type} ${t3.data.uid}:${t3.type}`;
      this.trigger(i3, t3.data);
    })), t2.on("attached detached", ((t3) => {
      const i3 = `${t3.type} ${t3.data.joystick.uid}:${t3.type}`;
      this.trigger(i3, t3.data);
    })), t2.on("added start shown hidden rested removed end joystickCreated joystickDestroyed", ((t3) => {
      const i3 = `${t3.type} ${t3.data.uid}:${t3.type}`;
      this.trigger(i3, t3.data);
    })), t2.on("move", ((t3) => {
      this.trigger(`move ${t3.data.instance.uid}:move`, t3.data);
    })), t2.on("dir dir:up dir:right dir:down dir:left", ((t3) => {
      const i3 = `${t3.type} ${t3.data.instance.uid}:${t3.type}`;
      this.trigger(i3, t3.data);
    })), t2.on("plain plain:up plain:right plain:down plain:left", ((t3) => {
      const i3 = `${t3.type} ${t3.data.instance.uid}:${t3.type}`;
      this.trigger(i3, t3.data);
    }));
  }
  cleanInactiveTouches(i3) {
    if (!("touches" in i3.initial)) return;
    const e2 = Array.from(i3.initial.touches).map(((t2) => t2.identifier));
    this.log("Cleaning inactive", e2, Array.from(this.joysticksByIdentifier.keys()));
    const s3 = Array.from(this.joysticksByIdentifier.entries());
    for (const [o2, n2] of s3) if (n2.collection.options.mode === t && !e2.includes(o2)) {
      if (!n2) return void this.error(`No collection found for cleaning identifier ${o2}`);
      this.log("💣 Cleaning", o2);
      const t2 = i3.raw;
      n2.collection.processOnEnd(x(i3.initial, { identifier: o2, pageX: t2.pageX, pageY: t2.pageY, clientX: t2.clientX, clientY: t2.clientY }));
    }
  }
  bindDocument() {
    this.binded || (this.log("bind dom"), this.bindEvt(document, "start", this.onstart), this.bindEvt(document, "move", this.onmove), this.bindEvt(document, "end", this.onend), this.bindEvt(document, "pressure", this.onpressure), this.binded = true);
  }
  unbindDocument(t2 = false) {
    !this.binded || this.joysticksByUid.size && true !== t2 || (this.log((t2 ? "force " : "") + "unbind dom"), this.unbindEvt(document, "start", this.onstart), this.unbindEvt(document, "move", this.onmove), this.unbindEvt(document, "end", this.onend), this.unbindEvt(document, "pressure", this.onpressure), this.binded = false);
  }
  onstart(t2) {
    this.cleanInactiveTouches(t2);
  }
  onmove(t2) {
    this.handleEventInCollection(t2, ((i3) => {
      i3.processOnMove(t2);
    }));
  }
  onend(t2) {
    this.cleanInactiveTouches(t2), this.handleEventInCollection(t2, ((i3) => {
      i3.processOnEnd(t2);
    }));
  }
  onpressure(t2) {
    t2.initial.preventDefault();
    const i3 = this.joysticksByIdentifier.get(t2.identifier);
    i3 ? i3.pressure = t2.pressure : this.error(`No joystick found for pressure event ${t2.identifier}`);
  }
  handleEventInCollection(t2, i3) {
    const e2 = this.joysticksByIdentifier.get(t2.identifier);
    e2 && i3(e2.collection);
  }
  destroy() {
    this.unbindDocument(true), this.collections.forEach(((t2) => {
      t2.destroy();
    })), this.resizeHandler && (g(window, "resize", this.resizeHandler), this.resizeHandler = null), this.scrollHandler && (g(window, "scroll", this.scrollHandler), this.scrollHandler = null), this.trigger("factoryDestroyed", this), this.off();
  }
}();
var P = (t2) => D.create(t2);
var S = (t2) => {
  I.logLevel = t2;
};
var L = () => I.logLevel;
var J = { create: P, factory: D, setLogLevel: S, getLogLevel: L };

// build/platform_input.js
var DEFAULT_PLATFORM_SETTINGS = Object.freeze({
  deadZone: 0.16,
  deadZoneHysteresis: 0.04,
  verticalEnterDegrees: 20,
  verticalExitDegrees: 28,
  moveIntervalMsec: 45,
  refreshIntervalMsec: 100
});
function validatePlatformSettings(settings) {
  if (![
    settings.deadZone,
    settings.deadZoneHysteresis,
    settings.verticalEnterDegrees,
    settings.verticalExitDegrees,
    settings.moveIntervalMsec,
    settings.refreshIntervalMsec
  ].every(Number.isFinite) || settings.deadZone < 0 || settings.deadZoneHysteresis < 0 || settings.deadZone + settings.deadZoneHysteresis >= 1 || settings.verticalEnterDegrees < 0 || settings.verticalExitDegrees < settings.verticalEnterDegrees || settings.verticalExitDegrees >= 45 || settings.moveIntervalMsec < 1 || settings.refreshIntervalMsec < settings.moveIntervalMsec || settings.refreshIntervalMsec >= 350)
    throw new RangeError("Invalid platform input settings");
}
var neutral = () => ({ axes: { x: 0, y: 0 }, stance: "neutral" });
function classifyPlatformInput(x2, y2, previous, settings = DEFAULT_PLATFORM_SETTINGS) {
  if (!Number.isFinite(x2) || !Number.isFinite(y2))
    return neutral();
  x2 = Math.max(-1, Math.min(1, x2));
  y2 = Math.max(-1, Math.min(1, y2));
  const length = Math.hypot(x2, y2);
  if (length > 1) {
    x2 /= length;
    y2 /= length;
  }
  const magnitude = Math.hypot(x2, y2);
  if (magnitude <= settings.deadZone || previous.stance === "neutral" && magnitude < settings.deadZone + settings.deadZoneHysteresis)
    return neutral();
  const vertical = y2 > 0 ? "look_up" : "crouch";
  const angle = Math.atan2(Math.abs(x2), Math.abs(y2)) * 180 / Math.PI;
  const sector = previous.stance === vertical ? settings.verticalExitDegrees : settings.verticalEnterDegrees;
  return { axes: { x: x2, y: y2 }, stance: angle <= sector ? vertical : "move" };
}
var PlatformInputState = class {
  emit;
  active = false;
  stickHeld = false;
  current = neutral();
  owner;
  settings;
  constructor(emit, settings = DEFAULT_PLATFORM_SETTINGS) {
    this.emit = emit;
    this.settings = Object.freeze({ ...settings });
    validatePlatformSettings(this.settings);
  }
  get actionPointer() {
    return this.owner && "pointer" in this.owner ? this.owner.pointer : void 0;
  }
  get actionHeld() {
    return this.owner !== void 0;
  }
  get action() {
    return this.current.stance === "crouch" ? "fall" : "jump";
  }
  snapshot() {
    return { axes: { ...this.current.axes }, stance: this.current.stance };
  }
  activate() {
    if (!this.active) {
      this.cancel();
      this.active = true;
    }
  }
  deactivate() {
    this.cancel();
    this.active = false;
  }
  /** Every device move updates local state, even when its network send is throttled. */
  updateAxes(x2, y2) {
    if (!this.active || !Number.isFinite(x2) || !Number.isFinite(y2))
      return false;
    this.stickHeld = true;
    this.current = classifyPlatformInput(x2, y2, this.current, this.settings);
    return true;
  }
  refresh() {
    if (this.active && this.stickHeld)
      this.emit({ kind: "move", input: this.snapshot() });
  }
  endStick() {
    const sendNeutral = this.active && this.stickHeld;
    this.stickHeld = false;
    this.current = neutral();
    if (sendNeutral)
      this.emit({ kind: "move", input: this.snapshot() });
  }
  cancelAction() {
    this.owner = void 0;
  }
  cancel() {
    this.cancelAction();
    this.endStick();
  }
  pressAction(pointer) {
    if (!this.active || this.owner !== void 0)
      return false;
    this.owner = { pointer };
    return true;
  }
  releaseAction(pointer, cancelled = false) {
    if (this.actionPointer !== pointer)
      return;
    this.owner = void 0;
    if (!cancelled)
      this.activateAction();
  }
  pressKey(key) {
    if (this.active && this.owner === void 0)
      this.owner = { key };
  }
  releaseKey(key) {
    if (!this.owner || !("key" in this.owner) || this.owner.key !== key)
      return;
    this.owner = void 0;
    this.activateAction();
  }
  /** Native assistive activation and owned pointer/key releases use the same current snapshot. */
  activateAction() {
    if (this.active && !this.actionHeld)
      this.emit({ kind: "release", action: this.action, input: this.snapshot() });
  }
};

// build/platform_controls.js
var PlatformControls = class {
  screen;
  stickZone;
  actionButton;
  context;
  input;
  manager;
  repeat;
  listeners = new AbortController();
  unbindLifecycle;
  lastMoveAt = -Infinity;
  constructor(screen2, stickZone, actionButton, context, settings = DEFAULT_PLATFORM_SETTINGS) {
    this.screen = screen2;
    this.stickZone = stickZone;
    this.actionButton = actionButton;
    this.context = context;
    this.input = new PlatformInputState((intent) => this.context.send(intent), settings);
    this.repeat = setInterval(() => this.input.refresh(), this.input.settings.refreshIntervalMsec);
    const options = { signal: this.listeners.signal };
    actionButton.addEventListener("pointerdown", (event) => {
      if (event.pointerType === "mouse" && event.button !== 0 || !this.input.pressAction(event.pointerId))
        return;
      event.preventDefault();
      try {
        actionButton.setPointerCapture(event.pointerId);
      } catch {
        this.input.releaseAction(event.pointerId, true);
      }
      this.renderAction();
    }, options);
    actionButton.addEventListener("pointerup", (event) => {
      if (event.pointerId !== this.input.actionPointer)
        return;
      event.preventDefault();
      this.input.releaseAction(event.pointerId);
      this.releaseCapture(event.pointerId);
      this.renderAction();
    }, options);
    for (const name of ["pointercancel", "lostpointercapture"]) {
      actionButton.addEventListener(name, (event) => {
        if (event.pointerId !== this.input.actionPointer)
          return;
        this.input.releaseAction(event.pointerId, true);
        this.releaseCapture(event.pointerId);
        this.renderAction();
      }, options);
      stickZone.addEventListener(name, () => {
        this.input.endStick();
        this.renderAction();
        this.destroyJoystick();
        if (this.input.active && !document.hidden && document.hasFocus())
          this.createJoystick();
      }, options);
    }
    actionButton.addEventListener("keydown", (event) => {
      if (event.key !== " " && event.key !== "Enter")
        return;
      event.preventDefault();
      if (!event.repeat)
        this.input.pressKey(event.key);
      this.renderAction();
    }, options);
    actionButton.addEventListener("keyup", (event) => {
      if (event.key !== " " && event.key !== "Enter")
        return;
      event.preventDefault();
      this.input.releaseKey(event.key);
      this.renderAction();
    }, options);
    actionButton.addEventListener("blur", () => {
      const pointer = this.input.actionPointer;
      this.input.cancelAction();
      this.releaseCapture(pointer);
      this.renderAction();
    }, options);
    actionButton.addEventListener("click", (event) => {
      if (event.detail === 0)
        this.input.activateAction();
    }, options);
    this.unbindLifecycle = bindControllerLifecycle((event) => {
      this.cancelTouches();
      if (event?.type !== "blur" && event?.type !== "pagehide" && this.input.active && !document.hidden && document.hasFocus())
        this.createJoystick();
    });
    window.addEventListener("focus", () => {
      if (this.input.active)
        this.createJoystick();
    }, options);
    document.addEventListener("visibilitychange", () => {
      if (!document.hidden && this.input.active)
        this.createJoystick();
    }, options);
    this.renderAction();
  }
  activate() {
    if (this.input.active)
      return;
    this.screen.hidden = false;
    document.documentElement.classList.add(this.context.activeClass);
    this.input.activate();
    this.lastMoveAt = -Infinity;
    this.renderAction();
    this.createJoystick();
  }
  createJoystick() {
    if (this.manager)
      return;
    const manager = J.create({
      zone: this.stickZone,
      mode: "static",
      position: { left: "50%", top: "50%" },
      size: 116,
      color: { back: "#168573", front: "#ffd879" },
      restJoystick: true,
      restOpacity: 0.9,
      fadeTime: 0
    });
    this.manager = manager;
    manager.on("move", (event) => {
      if (this.manager !== manager)
        return;
      const firstMove = !this.input.stickHeld;
      if (!this.input.updateAxes(event.data.vector.x, event.data.vector.y))
        return;
      this.renderAction();
      const now = performance.now();
      if (firstMove || now - this.lastMoveAt >= this.input.settings.moveIntervalMsec) {
        this.input.refresh();
        this.lastMoveAt = now;
      }
    });
    manager.on("end", () => {
      if (this.manager !== manager)
        return;
      this.input.endStick();
      this.renderAction();
    });
  }
  renderAction() {
    const label = this.input.action === "fall" ? "FALL" : "JUMP";
    this.actionButton.textContent = label;
    this.actionButton.setAttribute("aria-label", label === "FALL" ? "Fall" : "Jump");
    this.actionButton.classList.toggle("is-held", this.input.actionHeld);
  }
  releaseCapture(pointer) {
    if (pointer === void 0)
      return;
    try {
      if (this.actionButton.hasPointerCapture(pointer))
        this.actionButton.releasePointerCapture(pointer);
    } catch {
    }
  }
  destroyJoystick() {
    const manager = this.manager;
    this.manager = void 0;
    manager?.destroy();
  }
  cancelTouches() {
    const pointer = this.input.actionPointer;
    this.input.cancel();
    this.releaseCapture(pointer);
    this.renderAction();
    this.destroyJoystick();
    this.lastMoveAt = -Infinity;
  }
  deactivate() {
    this.cancelTouches();
    this.input.deactivate();
    this.screen.hidden = true;
    document.documentElement.classList.remove(this.context.activeClass);
  }
  /** Cancel against the old transport before replacing it; never carry touches across contexts. */
  setContext(context) {
    const wasActive = this.input.active;
    this.deactivate();
    this.context = context;
    if (wasActive)
      this.activate();
  }
  destroy() {
    this.deactivate();
    clearInterval(this.repeat);
    this.listeners.abort();
    this.unbindLifecycle();
  }
};

// build/lobby_input.js
function lobbyAction(intent) {
  const axes = {
    horizontal: intent.input.axes.x,
    vertical: intent.input.axes.y,
    stance: intent.input.stance
  };
  if (intent.kind === "move")
    return { type: "lobby_move", ...axes };
  return intent.action === "fall" ? { type: "lobby_fall_release", action: "fall", ...axes } : { type: "lobby_jump_release", action: "jump", ...axes };
}
function createLobbyContext(send) {
  return { activeClass: "lobby-active", send: (intent) => send(lobbyAction(intent)) };
}

// build/lobby_controls.js
var LobbyControls = class extends PlatformControls {
  constructor(screen2, stickZone, actionButton, send) {
    super(screen2, stickZone, actionButton, createLobbyContext(send));
  }
};

// build/character_selection.js
var CHARACTER_SHAPE = "squircle";
var CHARACTER_COLORS = [
  { id: "red", name: "Red", hex: "#E53935" },
  { id: "orange", name: "Orange", hex: "#F57C00" },
  { id: "golden_yellow", name: "Golden Yellow", hex: "#FBC02D" },
  { id: "green", name: "Green", hex: "#43A047" },
  { id: "cyan", name: "Cyan", hex: "#00ACC1" },
  { id: "blue", name: "Blue", hex: "#1E88E5" },
  { id: "indigo", name: "Indigo", hex: "#3949AB" },
  { id: "purple", name: "Purple", hex: "#8E24AA" },
  { id: "pink", name: "Pink", hex: "#EC407A" },
  { id: "brown", name: "Brown", hex: "#8D6E63" }
];
var FALLBACK_CHARACTER = { shape: CHARACTER_SHAPE, color: "#598DF2" };
function defaultJoinFlow() {
  return {
    screen: "selection",
    color: CHARACTER_COLORS.find((option) => option.id === "blue").hex
  };
}
function chooseJoinColor(state, color) {
  return { ...state, color };
}
function advanceJoinFlow(state) {
  return { ...state, screen: "name" };
}
function returnToCharacterSelection(state) {
  return { ...state, screen: "selection" };
}
function createJoinMessage(name, state) {
  return {
    type: "join",
    name: name.trim(),
    character_shape: CHARACTER_SHAPE,
    character_color: state.color
  };
}
function colorOption(hex) {
  if (typeof hex !== "string")
    return void 0;
  return CHARACTER_COLORS.find((option) => option.hex.toUpperCase() === hex.toUpperCase());
}

// build/app.js
var status = document.querySelector("#status");
bindScreenWakeLock();
var connectionError = document.querySelector("#connection-error");
var connectionErrors = [];
function reportConnectionFailure(stage, endpoint, error) {
  const detail = error instanceof Error ? `${error.name}: ${error.message}` : String(error);
  const text = `Step: ${stage}
Endpoint: ${endpoint}
${detail}`;
  const last = connectionErrors.at(-1);
  if (last?.text === text)
    last.repeats++;
  else {
    connectionErrors.push({ text, at: (/* @__PURE__ */ new Date()).toISOString(), repeats: 1 });
    if (connectionErrors.length > 6)
      connectionErrors.shift();
  }
  connectionError.textContent = `CONTROLLER ERROR LOG (development)
Browser: ${navigator.userAgent}
Connection failures retry every 2 seconds.

` + connectionErrors.map((entry) => {
    const repeats = entry.repeats > 1 ? ` (repeated ${entry.repeats} times)` : "";
    return `[${entry.at}]${repeats}
${entry.text}`;
  }).join("\n\n");
  connectionError.hidden = false;
}
window.addEventListener("error", (event) => {
  const cause = event.error instanceof Error ? `${event.error.name}: ${event.error.message}` : event.message;
  reportConnectionFailure("Browser JavaScript error", new URL(location.href).origin, `${cause}
Source: ${event.filename}:${event.lineno}:${event.colno}`);
});
window.addEventListener("unhandledrejection", (event) => {
  reportConnectionFailure("Unhandled browser promise rejection", new URL(location.href).origin, event.reason);
});
var selectionScreen = document.querySelector("#selection-screen");
var selectionPreview = document.querySelector("#selection-preview");
var namePreview = document.querySelector("#name-preview");
var selectedCharacterLabel = document.querySelector("#selected-character-label");
var colorGrid = document.querySelector("#color-grid");
var nextButton = document.querySelector("#next-button");
var backButton = document.querySelector("#back-button");
var nameScreen = document.querySelector("#name-screen");
var joinForm = document.querySelector("#join-form");
var nameInput = document.querySelector("#player-name");
var joinButton = document.querySelector("#join-button");
var playerCard = document.querySelector("#player-card");
var readyCard = document.querySelector("#ready-card");
var readyState = document.querySelector("#ready-state");
var readyButton = document.querySelector("#ready-button");
var playerName = document.querySelector("#player-name-heading");
var playerState = document.querySelector("#player-state");
var leaveButton = document.querySelector("#leave-button");
var lobbyController = document.querySelector("#lobby-controller");
var lobbyStickZone = document.querySelector("#lobby-stick-zone");
var lobbyJumpButton = document.querySelector("#lobby-jump-button");
var lobbyLeaveButton = document.querySelector("#lobby-leave-button");
var bubblesCard = document.querySelector("#bubbles-card");
var bubblesPad = document.querySelector("#bubbles-pad");
var bubblesScore = document.querySelector("#bubbles-score");
var bubblesCanvas = document.querySelector("#bubbles-visual");
var bubblesContext = bubblesCanvas.getContext("2d", { alpha: true });
var motionPanel = document.querySelector("#motion-lab");
var motionButton = document.querySelector("#motion-permission");
var motionReadings = document.querySelector("#motion-readings");
var STORAGE = {
  session: "play-shapes.session-id",
  token: "play-shapes.reconnect-token",
  name: "play-shapes.last-name",
  inputSeq: "play-shapes.input-seq"
};
var socket;
var retry;
var stopped = false;
var joined = false;
var isReady = false;
var joinFlow = defaultJoinFlow();
var inputSeq = Number.parseInt(stored(STORAGE.inputSeq), 10) || 0;
var activeGame = null;
var bubblesPointer;
var bubblesSnapshot;
var bubblesSnapshotTime = 0;
var bubblesLocalCharge = 0;
var bubblesVisualSnapshot;
var bubblesVisualReceivedAt = 0;
var bubblesPhoneDragDisplay = [0, 0];
var bubblesPreviousFrame = performance.now();
var squircleCanvas = new SquircleV1Canvas();
var bubblesArt = { jellyfish: new Image() };
bubblesArt.jellyfish.src = "/bubbles-jellyfish.png";
var lobbyControls = new LobbyControls(lobbyController, lobbyStickZone, lobbyJumpButton, (action) => {
  if (!joined || !socket || socket.readyState !== WebSocket.OPEN || activeGame !== null)
    return;
  inputSeq += 1;
  store(STORAGE.inputSeq, String(inputSeq));
  socket.send(JSON.stringify({ ...action, input_seq: inputSeq }));
});
var gameplayMotion = new MotionStream(() => socket);
window.addEventListener("pageshow", (event) => {
  if (event.persisted && activeGame === "tilt_shift")
    socket?.close();
});
var tiltSurface = document.querySelector("#tilt-shift");
var tiltPhone = new TiltShiftPhone(tiltSurface, gameplayMotion, (ready, context) => {
  if (socket?.readyState === WebSocket.OPEN)
    socket.send(JSON.stringify(context ? { type: "tilt_shift_ready", ready, ...context } : { type: "pre_minigame_ready", ready }));
});
gameplayMotion.onControlState = () => tiltPhone.feedback();
var motionLab = new MotionLabController(motionPanel, motionButton, motionReadings, () => socket);
var pwa = new PwaOnboarding(document.querySelector("#app-screen"), document.querySelector("#install-button"), document.querySelector("#install-guidance"), document.querySelector("#browser-button"), () => {
  selectionScreen.hidden = false;
  nextButton.focus();
  void requestImmersiveMode();
});
for (const surface of [lobbyController, bubblesPad, readyCard, tiltSurface])
  protectControllerSurface(surface);
bindControllerLifecycle(() => cancelBubblesPointer());
function stored(key) {
  try {
    return localStorage.getItem(key) ?? "";
  } catch {
    return "";
  }
}
function store(key, value) {
  try {
    localStorage.setItem(key, value);
  } catch {
  }
}
function forgetIdentity() {
  try {
    localStorage.removeItem(STORAGE.session);
    localStorage.removeItem(STORAGE.token);
    localStorage.removeItem(STORAGE.inputSeq);
  } catch {
  }
  inputSeq = 0;
}
function selectedCharacterName() {
  const color = colorOption(joinFlow.color)?.name ?? "Blue";
  return `${color} Squircle`;
}
function refreshSelectionUi() {
  const label = selectedCharacterName();
  selectedCharacterLabel.textContent = label;
  selectionPreview.setAttribute("aria-label", `${label} Shape Character`);
  namePreview.setAttribute("aria-label", `${label} character preview`);
  for (const button of Array.from(colorGrid.querySelectorAll(".color-button"))) {
    button.setAttribute("aria-pressed", String(button.dataset.color === joinFlow.color));
  }
  renderJoinPreviews(performance.now());
}
for (const option of CHARACTER_COLORS) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "color-button";
  button.dataset.color = option.hex;
  button.style.backgroundColor = option.hex;
  button.setAttribute("aria-label", `Choose ${option.name}`);
  button.setAttribute("aria-pressed", "false");
  button.addEventListener("click", () => {
    joinFlow = chooseJoinColor(joinFlow, option.hex);
    refreshSelectionUi();
  });
  colorGrid.append(button);
}
refreshSelectionUi();
function setGameplaySurface(active, game = "bubbles") {
  const next = active ? game : null;
  if (next !== "tilt_shift")
    tiltPhone.hide();
  if (activeGame !== next) {
    cancelBubblesPointer();
    if (next === null) {
      try {
        screen.orientation?.unlock?.();
      } catch {
      }
    } else if (document.fullscreenElement) {
      try {
        const orientation = screen.orientation;
        const direction = next === "tilt_shift" ? "landscape" : "portrait";
        void Promise.resolve(orientation?.lock?.(direction)).catch(() => {
        });
      } catch {
      }
    }
    activeGame = next;
  }
  document.documentElement.classList.toggle("gameplay-active", active);
  document.documentElement.classList.toggle("bubbles-active", next === "bubbles");
  document.documentElement.classList.toggle("tilt-active", next === "tilt_shift");
}
function showJoin(message, focus = false) {
  gameplayMotion.stop();
  motionLab.stop();
  lobbyControls.deactivate();
  readyCard.hidden = true;
  document.documentElement.classList.remove("ready-active");
  joinFlow = returnToCharacterSelection(joinFlow);
  joined = false;
  bubblesSnapshot = void 0;
  bubblesVisualSnapshot = void 0;
  setGameplaySurface(false);
  playerCard.hidden = true;
  bubblesCard.hidden = true;
  selectionScreen.hidden = pwa.visible || pwa.show();
  nameScreen.hidden = true;
  joinForm.hidden = true;
  joinButton.disabled = false;
  leaveButton.disabled = false;
  status.textContent = message;
  status.hidden = !message;
  nameInput.value = stored(STORAGE.name);
  refreshSelectionUi();
  if (focus && !pwa.visible)
    queueMicrotask(() => nextButton.focus());
}
function showJoined(player, state = "Connected") {
  pwa.hide();
  gameplayMotion.stop();
  motionLab.stop();
  readyCard.hidden = true;
  document.documentElement.classList.remove("ready-active");
  joined = true;
  bubblesSnapshot = void 0;
  bubblesVisualSnapshot = void 0;
  setGameplaySurface(false);
  selectionScreen.hidden = true;
  nameScreen.hidden = true;
  joinForm.hidden = true;
  playerCard.hidden = true;
  bubblesCard.hidden = true;
  playerName.textContent = player.name;
  playerState.textContent = state;
  leaveButton.disabled = false;
  lobbyLeaveButton.disabled = false;
  lobbyControls.activate();
  const serverColor = colorOption(player.character_color)?.hex;
  if (serverColor)
    joinFlow = chooseJoinColor(joinFlow, serverColor);
  status.textContent = state === "Connected" ? "Joined. Keep this page open while you play." : state;
  status.hidden = true;
}
function showReady(message) {
  if (message.minigame_id === "tilt_shift" && message.preparation) {
    showTiltSurface();
    tiltPhone.preparation(message.preparation, message.ready === true);
    return;
  }
  gameplayMotion.stop();
  motionLab.stop();
  lobbyControls.deactivate();
  setGameplaySurface(false);
  selectionScreen.hidden = true;
  nameScreen.hidden = true;
  joinForm.hidden = true;
  playerCard.hidden = true;
  bubblesCard.hidden = true;
  readyCard.hidden = false;
  document.documentElement.classList.add("ready-active");
  isReady = message.ready === true;
  readyState.textContent = isReady ? "Ready!" : "Not ready";
  readyButton.textContent = isReady ? "CANCEL" : "READY";
  readyButton.setAttribute("aria-pressed", String(isReady));
  readyButton.setAttribute("aria-label", isReady ? "Cancel ready status" : "Ready up");
  readyButton.disabled = false;
  status.hidden = true;
}
function showTiltSurface() {
  motionLab.stop();
  lobbyControls.deactivate();
  setGameplaySurface(true, "tilt_shift");
  selectionScreen.hidden = nameScreen.hidden = joinForm.hidden = playerCard.hidden = true;
  bubblesCard.hidden = readyCard.hidden = true;
  document.documentElement.classList.remove("ready-active");
  status.hidden = true;
}
function showTilt(message) {
  if (tiltPhone.snapshot(message))
    showTiltSurface();
}
readyButton.addEventListener("click", () => {
  if (!socket || socket.readyState !== WebSocket.OPEN)
    return;
  readyButton.disabled = true;
  socket.send(JSON.stringify({ type: "pre_minigame_ready", ready: !isReady }));
});
nextButton.addEventListener("click", () => {
  if (pwa.visible)
    return;
  joinFlow = advanceJoinFlow(joinFlow);
  selectionScreen.hidden = true;
  nameScreen.hidden = false;
  joinForm.hidden = false;
  if (!nameInput.value)
    nameInput.value = stored(STORAGE.name);
  status.hidden = true;
  status.textContent = "";
  refreshSelectionUi();
  queueMicrotask(() => nameInput.focus());
});
backButton.addEventListener("click", () => {
  joinFlow = returnToCharacterSelection(joinFlow);
  nameScreen.hidden = true;
  joinForm.hidden = true;
  selectionScreen.hidden = false;
  status.hidden = true;
  status.textContent = "";
  refreshSelectionUi();
  queueMicrotask(() => nextButton.focus());
});
async function requestImmersiveMode() {
  if (isStandalone(window, navigator) || document.fullscreenElement)
    return;
  const root = document.documentElement;
  const orientation = screen.orientation;
  const fullscreen = root.requestFullscreen ? () => root.requestFullscreen({ navigationUI: "hide" }) : root.webkitRequestFullscreen?.bind(root);
  await attemptImmersive(fullscreen, orientation?.lock ? () => orientation.lock("portrait") : void 0);
}
function sendBubblesCharge(seq, stage, step = 0) {
  if (socket?.readyState === WebSocket.OPEN)
    socket.send(JSON.stringify({ type: "bubbles_charge", input_seq: seq, stage, step }));
}
function sendBubblesMotion(pointer, now) {
  if (pointer.motionCount >= 48 || socket?.readyState !== WebSocket.OPEN)
    return;
  socket.send(JSON.stringify({
    type: "bubbles_charge",
    input_seq: pointer.seq,
    stage: "motion",
    drag: pointer.drag
  }));
  pointer.sentDrag = [...pointer.drag];
  pointer.lastMotionAt = now;
  pointer.motionCount += 1;
}
function cancelBubblesPointer(sendCancel = true) {
  if (!bubblesPointer)
    return;
  const { id, seq } = bubblesPointer;
  bubblesPointer = void 0;
  bubblesLocalCharge = 0;
  bubblesPhoneDragDisplay = [0, 0];
  if (sendCancel)
    sendBubblesCharge(seq, "cancel");
  if (bubblesPad.hasPointerCapture(id))
    bubblesPad.releasePointerCapture(id);
}
function sendBubblesTrace(trace, gestureSeq) {
  if (activeGame !== "bubbles" || bubblesSnapshot?.phase !== "active" || trace.length < 2 || !socket || socket.readyState !== WebSocket.OPEN)
    return;
  if (gestureSeq === void 0) {
    inputSeq += 1;
    store(STORAGE.inputSeq, String(inputSeq));
  }
  socket.send(JSON.stringify({ type: "bubbles_trace", input_seq: gestureSeq ?? inputSeq, trace }));
}
function vibrate(pattern) {
  try {
    navigator.vibrate?.(pattern);
  } catch {
  }
}
bubblesPad.addEventListener("pointerdown", (event) => {
  if (activeGame !== "bubbles" || bubblesSnapshot?.phase !== "active" || bubblesPointer || event.pointerType === "mouse" && event.button !== 0)
    return;
  event.preventDefault();
  const trace = new GestureTrace(bubblesPad.getBoundingClientRect());
  trace.add(event.clientX, event.clientY);
  inputSeq += 1;
  store(STORAGE.inputSeq, String(inputSeq));
  bubblesPhoneDragDisplay = [0, 0];
  bubblesPointer = {
    id: event.pointerId,
    trace,
    seq: inputSeq,
    step: 0,
    drag: [0, 0],
    sentDrag: [0, 0],
    lastMotionAt: performance.now(),
    motionCount: 0
  };
  try {
    bubblesPad.setPointerCapture(event.pointerId);
  } catch {
    cancelBubblesPointer();
    return;
  }
  sendBubblesCharge(inputSeq, "start");
});
bubblesPad.addEventListener("pointermove", (event) => {
  if (bubblesPointer?.id !== event.pointerId)
    return;
  event.preventDefault();
  for (const sample of event.getCoalescedEvents?.() ?? [event])
    bubblesPointer.trace.add(sample.clientX, sample.clientY);
  bubblesLocalCharge = bubblesPointer.trace.preview(bubblesSnapshot?.circles_to_charge ?? 1);
  const step = Math.min(4, Math.floor(bubblesLocalCharge * 4));
  if (step > bubblesPointer.step) {
    bubblesPointer.step = step;
    sendBubblesCharge(bubblesPointer.seq, "progress", step);
  }
  const [dx, dy] = bubblesPointer.trace.displacement();
  const drag = [
    Math.max(-4, Math.min(4, Math.round(dx * 10))),
    Math.max(-4, Math.min(4, Math.round(dy * 10)))
  ];
  const now = performance.now();
  bubblesPointer.drag = drag;
  if ((drag[0] !== bubblesPointer.sentDrag[0] || drag[1] !== bubblesPointer.sentDrag[1]) && now - bubblesPointer.lastMotionAt >= 70)
    sendBubblesMotion(bubblesPointer, now);
});
bubblesPad.addEventListener("pointerup", (event) => {
  if (bubblesPointer?.id !== event.pointerId)
    return;
  event.preventDefault();
  bubblesPointer.trace.add(event.clientX, event.clientY);
  const { seq } = bubblesPointer;
  const trace = bubblesPointer.trace.completed();
  cancelBubblesPointer(false);
  if (trace.length < 2)
    sendBubblesCharge(seq, "cancel");
  else
    sendBubblesTrace(trace, seq);
});
bubblesPad.addEventListener("pointercancel", (event) => {
  if (bubblesPointer?.id === event.pointerId)
    cancelBubblesPointer();
});
bubblesPad.addEventListener("lostpointercapture", (event) => {
  if (bubblesPointer?.id === event.pointerId)
    cancelBubblesPointer();
});
bubblesPad.addEventListener("contextmenu", (event) => event.preventDefault());
bubblesPad.addEventListener("keydown", (event) => {
  if (event.repeat || activeGame !== "bubbles" || bubblesSnapshot?.phase !== "active")
    return;
  const directions = {
    ArrowLeft: [0.1, 0.5],
    ArrowRight: [0.9, 0.5],
    ArrowUp: [0.5, 0.1],
    ArrowDown: [0.5, 0.9]
  };
  if (directions[event.key]) {
    event.preventDefault();
    sendBubblesTrace([[0.5, 0.5], directions[event.key]]);
  } else if (event.key === " " || event.key === "Enter") {
    event.preventDefault();
    const circles = Math.max(1, Math.min(3, bubblesSnapshot?.circles_to_charge ?? 1));
    const trace = Array.from({ length: 97 }, (_2, index) => [
      0.5 + 0.22 * Math.cos(index / 96 * Math.PI * 2 * circles),
      0.5 + 0.22 * Math.sin(index / 96 * Math.PI * 2 * circles)
    ]);
    sendBubblesTrace(trace);
  }
});
function showBubbles(message) {
  gameplayMotion.stop();
  motionLab.stop();
  lobbyControls.deactivate();
  readyCard.hidden = true;
  document.documentElement.classList.remove("ready-active");
  bubblesSnapshot = message;
  bubblesSnapshotTime = performance.now();
  playerCard.hidden = true;
  bubblesCard.hidden = false;
  const phase = message.phase ?? "waiting";
  const active = phase === "results" || ["instructions", "countdown", "active"].includes(phase) && message.left !== true;
  setGameplaySurface(active);
  bubblesScore.textContent = String(Math.max(0, Math.floor(message.score ?? 0)));
  if (message.type === "bubbles_feedback") {
    if (message.event === "captured")
      vibrate(18);
    else if (message.event === "spin")
      vibrate([20, 30, 20]);
    else if (message.event === "pop")
      vibrate([35, 45, 35]);
  }
}
var BUBBLE_RIM_COLORS = ["#6eeaff", "#a785ff", "#ff8bce", "#ffdf9d", "#8af8c7"];
function clamp(value, minimum, maximum) {
  return Math.min(maximum, Math.max(minimum, value));
}
function tuningValue(key, fallback) {
  const value = bubblesSnapshot?.visual_tuning?.[key];
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}
function imageReady(image) {
  return image.complete && image.naturalWidth > 0;
}
function renderJoinPreviews(now) {
  for (const canvas of [selectionPreview, namePreview]) {
    if (canvas.closest("section")?.hidden)
      continue;
    const rect = canvas.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0)
      continue;
    const pixelRatio = Math.max(1, Math.min(3, window.devicePixelRatio || 1));
    const width = Math.max(1, Math.round(rect.width * pixelRatio));
    const height = Math.max(1, Math.round(rect.height * pixelRatio));
    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width;
      canvas.height = height;
    }
    const context = canvas.getContext("2d");
    if (!context)
      continue;
    context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
    context.clearRect(0, 0, rect.width, rect.height);
    const scale = Math.min(rect.width / 256, rect.height / 220) * 0.95;
    squircleCanvas.draw(context, joinFlow.color, rect.width / 2, rect.height * 0.89, scale, now);
  }
}
function drawBubblePath(context, radius, pull) {
  const length = Math.hypot(pull[0], pull[1]);
  const stretch = clamp(length, 0, 0.22);
  const along = stretch > 1e-3 ? [pull[0] / length, pull[1] / length] : [1, 0];
  const center = [along[0] * radius * stretch * 0.22, along[1] * radius * stretch * 0.22];
  const at = (theta) => {
    const forward = Math.cos(theta);
    const longitudinal = 1 + stretch * (1.25 * Math.max(forward, 0) - 0.25 * Math.max(-forward, 0));
    const normalX = -along[1];
    const normalY = along[0];
    return [
      center[0] + along[0] * forward * radius * longitudinal + normalX * Math.sin(theta) * radius * (1 - stretch * 0.3),
      center[1] + along[1] * forward * radius * longitudinal + normalY * Math.sin(theta) * radius * (1 - stretch * 0.3)
    ];
  };
  const points = [];
  for (let index = 0; index < 65; index++)
    points.push(at(index * Math.PI * 2 / 64));
  context.beginPath();
  points.forEach(([x2, y2], index) => index === 0 ? context.moveTo(x2, y2) : context.lineTo(x2, y2));
  context.closePath();
  return { points, center, along, stretch };
}
function traceBubblePoint(theta, radius, center, along, stretch) {
  const forward = Math.cos(theta);
  const longitudinal = 1 + stretch * (1.25 * Math.max(forward, 0) - 0.25 * Math.max(-forward, 0));
  return [
    center[0] + along[0] * forward * radius * longitudinal - along[1] * Math.sin(theta) * radius * (1 - stretch * 0.3),
    center[1] + along[1] * forward * radius * longitudinal + along[0] * Math.sin(theta) * radius * (1 - stretch * 0.3)
  ];
}
function drawPolyline(context, points, color, width) {
  if (points.length < 2)
    return;
  context.beginPath();
  context.moveTo(points[0][0], points[0][1]);
  for (let index = 1; index < points.length; index++)
    context.lineTo(points[index][0], points[index][1]);
  context.strokeStyle = color;
  context.lineWidth = width;
  context.lineJoin = "round";
  context.lineCap = "round";
  context.stroke();
}
function drawArc(context, x2, y2, radius, start, end, color, width) {
  context.beginPath();
  context.arc(x2, y2, Math.max(0, radius), start, end, false);
  context.strokeStyle = color;
  context.lineWidth = width;
  context.lineCap = "round";
  context.stroke();
}
function drawBubbleBurst(context, radius, progress, density) {
  const age = clamp(progress, 0, 1);
  const fade = 1 - clamp((age - 0.45) / 0.55, 0, 1);
  const fragmentCount = Math.max(4, Math.floor(density / 2));
  for (let index = 0; index < fragmentCount; index++) {
    const phase = index * Math.PI * 2 / fragmentCount + 0.14;
    const x2 = Math.cos(phase) * radius * (0.25 + age * 1.14);
    const y2 = Math.sin(phase) * radius * (0.25 + age * 1.14);
    const color = BUBBLE_RIM_COLORS[index % BUBBLE_RIM_COLORS.length];
    drawArc(context, x2, y2, radius * (0.3 - age * 0.17), phase + 1, phase + 2.7, `${color}${Math.round(0.83 * fade * 255).toString(16).padStart(2, "0")}`, Math.max(2, radius * 0.055));
    drawArc(context, x2, y2, radius * (0.27 - age * 0.16), phase + 1.05, phase + 2.5, `rgba(255,255,255,${0.38 * fade})`, Math.max(1, radius * 0.016));
  }
  for (let index = 0; index < density; index++) {
    const phase = index * 2.39996;
    const distance = radius * (0.35 + age * (0.75 + index % 4 * 0.13));
    const x2 = Math.cos(phase) * distance;
    const y2 = Math.sin(phase) * distance;
    if (index % 4 === 0) {
      const star = 2 + index % 3;
      context.strokeStyle = `rgba(255,255,222,${fade})`;
      context.lineWidth = 1.2;
      context.beginPath();
      context.moveTo(x2 - star, y2);
      context.lineTo(x2 + star, y2);
      context.moveTo(x2, y2 - star);
      context.lineTo(x2, y2 + star);
      context.stroke();
    } else
      drawArc(context, x2, y2, 2 + index % 3, 0, Math.PI * 2, `rgba(204,248,255,${0.75 * fade})`, 1.3);
  }
}
function drawPhoneCharacter(context, visual, hostTime, selectedColor) {
  const fallbackScale = Math.min(0.44, (bubblesSnapshot?.bubble_radius ?? tuningValue("starting_radius", 48)) * 0.82 / 100);
  const position = visual?.character_position ?? [0, 40 + Math.sin(hostTime / 1e3 * 2.2) * 4];
  squircleCanvas.draw(context, visual?.recovery_white ? "#ffffff" : selectedColor, position[0], position[1], visual?.character_scale ?? fallbackScale, hostTime, visual?.face_blink ?? false, visual?.body_rotation ?? Math.sin(hostTime / 1e3 * 1.7) * 0.05);
}
function renderBubbles(now) {
  if (bubblesCard.hidden || !bubblesSnapshot)
    return;
  const rect = bubblesCanvas.getBoundingClientRect();
  const pixelRatio = Math.max(1, Math.min(3, window.devicePixelRatio || 1));
  const backingWidth = Math.max(1, Math.round(rect.width * pixelRatio));
  const backingHeight = Math.max(1, Math.round(rect.height * pixelRatio));
  if (bubblesCanvas.width !== backingWidth || bubblesCanvas.height !== backingHeight) {
    bubblesCanvas.width = backingWidth;
    bubblesCanvas.height = backingHeight;
  }
  const context = bubblesContext;
  context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
  context.clearRect(0, 0, rect.width, rect.height);
  const message = bubblesSnapshot;
  const visual = bubblesVisualSnapshot;
  const snapshotElapsed = Math.max(0, now - bubblesSnapshotTime);
  const visualElapsed = visual ? Math.max(0, now - bubblesVisualReceivedAt) : 0;
  const tuneTime = Number.isFinite(visual?.host_time_msec) ? visual.host_time_msec + visualElapsed : (message.host_time_msec ?? 0) + snapshotElapsed;
  const startRadius = Math.max(1, tuningValue("starting_radius", 48));
  const baseRadius = Math.min(rect.width, rect.height) * 0.23;
  const worldScale = baseRadius / startRadius;
  const reformDuration = Math.max(1, tuningValue("bubble_reform_seconds", 0.35) * 1e3);
  const reformRemaining = Math.max(0, (message.reform_remaining_msec ?? 0) - snapshotElapsed);
  const reformScale = reformRemaining > 0 ? clamp((reformDuration - reformRemaining) / reformDuration, 0.08, 1) : 1;
  const burstDuration = Math.max(1, tuningValue("burst_seconds", 0.26) * 1e3);
  const burstProgress = visual?.burst_progress ?? (reformRemaining > 0 && reformDuration - reformRemaining < burstDuration ? (reformDuration - reformRemaining) / burstDuration : -1);
  const radius = Math.max(1, visual?.radius ?? (message.bubble_radius ?? startRadius) * reformScale);
  const burstRadius = message.burst_radius ?? message.bubble_radius ?? startRadius;
  const renderedRadius = burstProgress >= 0 && burstProgress < 1 ? visual?.radius ?? burstRadius : radius;
  const selectedColor = colorOption(message.character_color)?.hex ?? FALLBACK_CHARACTER.color;
  const spinTurns = tuningValue("spin_surface_turns_per_second", 1.8);
  const spinning = visual?.spinning ?? (message.phase === "active" && (message.spin_remaining_msec ?? 0) - snapshotElapsed > 0);
  const surfaceAngle = visual ? visual.surface_angle + (spinning ? visualElapsed / 1e3 * Math.PI * 2 * spinTurns : 0) : 0;
  let pull = visual?.pull ?? [0, 0];
  let localDragPull = [0, 0];
  if (bubblesPointer && message.phase === "active") {
    const dragX = bubblesPointer.drag[0] / 4;
    const dragY = bubblesPointer.drag[1] / 4;
    const dragLength = Math.hypot(dragX, dragY);
    const dragScale = dragLength > 1 ? 1 / dragLength : 1;
    const strength = tuningValue("live_drag_pull_strength", 0.2);
    const target = [dragX * dragScale * strength, dragY * dragScale * strength];
    const delta = clamp((now - bubblesPreviousFrame) / 1e3, 0, 0.1);
    const response = Math.max(1e-3, tuningValue("live_drag_response_seconds", 0.08));
    const amount = 1 - Math.exp(-delta / response);
    bubblesPhoneDragDisplay = [
      bubblesPhoneDragDisplay[0] + (target[0] - bubblesPhoneDragDisplay[0]) * amount,
      bubblesPhoneDragDisplay[1] + (target[1] - bubblesPhoneDragDisplay[1]) * amount
    ];
    localDragPull = bubblesPhoneDragDisplay;
    const localCharge = bubblesPointer.step / 4;
    const seconds = tuneTime / 1e3;
    const wobble = tuningValue("charge_wobble_strength", 0.07) * localCharge;
    const localChargePull = [
      Math.sin(seconds * 13) * wobble,
      Math.cos(seconds * 17) * wobble
    ];
    const hostDrag = visual?.drag_pull ?? [0, 0];
    const hostCharge = visual?.charge_pull ?? [0, 0];
    pull = [
      pull[0] - hostDrag[0] - hostCharge[0] + localDragPull[0] + localChargePull[0],
      pull[1] - hostDrag[1] - hostCharge[1] + localDragPull[1] + localChargePull[1]
    ];
  } else {
    const amount = 1 - Math.exp(-clamp((now - bubblesPreviousFrame) / 1e3, 0, 0.1) / Math.max(1e-3, tuningValue("live_drag_response_seconds", 0.08)));
    bubblesPhoneDragDisplay = [
      bubblesPhoneDragDisplay[0] * (1 - amount),
      bubblesPhoneDragDisplay[1] * (1 - amount)
    ];
  }
  context.save();
  context.translate(rect.width / 2, rect.height / 2);
  context.scale(worldScale, worldScale);
  if (burstProgress >= 0 && burstProgress < 1) {
    drawBubbleBurst(context, renderedRadius, burstProgress + (visual ? visualElapsed / burstDuration : 0), visual?.particle_density ?? 10);
  } else {
    const shape = drawBubblePath(context, renderedRadius, pull);
    context.fillStyle = "rgba(69,191,255,.10)";
    context.fill();
    const chargeGlow = bubblesPointer ? Math.max(0, bubblesPointer.step / 4) * tuningValue("charge_glow_strength", 0.12) : visual?.charge_glow ?? 0;
    if (chargeGlow > 0) {
      context.beginPath();
      context.arc(shape.center[0], shape.center[1], renderedRadius * 0.84, 0, Math.PI * 2);
      context.fillStyle = `rgba(125,209,255,${chargeGlow * 0.48})`;
      context.fill();
      drawArc(context, shape.center[0], shape.center[1], renderedRadius * 0.78, 0, Math.PI * 2, `rgba(191,240,255,${chargeGlow * 0.85})`, Math.max(3, renderedRadius * 0.16));
    }
    drawArc(context, shape.center[0] + renderedRadius * 0.04, shape.center[1] + renderedRadius * 0.04, renderedRadius * 0.79, 0.15 + surfaceAngle, 1.35 + surfaceAngle, "rgba(110,212,255,.13)", Math.max(3, renderedRadius * 0.12));
    drawArc(context, shape.center[0], shape.center[1], renderedRadius * 0.87, 2.2 + surfaceAngle, 3.9 + surfaceAngle, "rgba(189,161,255,.10)", Math.max(3, renderedRadius * 0.09));
    drawPolyline(context, [...shape.points, shape.points[0]], `rgba(186,247,255,${0.65 * (visual?.recovery_white ? 1 : 0.88)})`, Math.max(2, renderedRadius * 0.045));
    drawPolyline(context, [...shape.points, shape.points[0]], `rgba(255,255,255,${0.56 * (visual?.recovery_white ? 1 : 0.88)})`, Math.max(1, renderedRadius * 0.016));
    for (let index = 0; index < 12; index++) {
      const start = index * Math.PI * 2 / 12 + surfaceAngle;
      const arc = [];
      for (let sample = 0; sample < 10; sample++)
        arc.push(traceBubblePoint(start + sample * (Math.PI * 2 / 12 + 0.04) / 9, renderedRadius, shape.center, shape.along, shape.stretch));
      const hues = ["110,234,255", "167,133,255", "255,139,206", "255,223,157", "138,248,199"];
      const hue = visual?.recovery_white ? "255,255,255" : hues[index % 5];
      drawPolyline(context, arc, `rgba(${hue},0.5)`, Math.max(2, renderedRadius * 0.055));
    }
    drawArc(context, shape.center[0] - renderedRadius * 0.08, shape.center[1] - renderedRadius * 0.08, renderedRadius * 0.74, -2.55 + surfaceAngle, -1.65 + surfaceAngle, "rgba(255,255,255,.76)", Math.max(2, renderedRadius * 0.055));
    drawArc(context, shape.center[0], shape.center[1], renderedRadius * 0.91, 0.38 + surfaceAngle, 1.15 + surfaceAngle, "rgba(222,255,255,.34)", Math.max(1.5, renderedRadius * 0.03));
    const count = Math.min(Math.max(0, Math.floor(message.visual_jellyfish ?? 0)), Math.max(0, Math.floor(message.visual_cap ?? 0)), 64);
    if (imageReady(bubblesArt.jellyfish))
      for (let index = 0; index < count; index++) {
        const turn = index * 2.39996323;
        const distance = Math.sqrt((index + 0.5) / Math.max(count, 1)) * renderedRadius * 0.67;
        const width = renderedRadius * 0.11;
        const height = width * bubblesArt.jellyfish.naturalHeight / bubblesArt.jellyfish.naturalWidth;
        context.save();
        context.globalAlpha = 0.82;
        context.drawImage(bubblesArt.jellyfish, Math.cos(turn) * distance - width / 2, Math.sin(turn) * distance - height / 2, width, height);
        context.restore();
      }
    if (spinning) {
      const density = visual?.particle_density ?? 10;
      for (let index = 0; index < density; index++) {
        const phase = index * 2.39996 + surfaceAngle * (0.55 + index % 3 * 0.2);
        const x2 = Math.cos(phase) * renderedRadius * (1.12 + index % 4 * 0.075);
        const y2 = Math.sin(phase) * renderedRadius * (1.12 + index % 4 * 0.075);
        const size = 2.2 + index % 3 * 1.2;
        drawArc(context, x2, y2, size, 0, Math.PI * 2, "rgba(204,250,255,.52)", 1.2);
        context.beginPath();
        context.arc(x2 - size * 0.28, y2 - size * 0.3, 0.7, 0, Math.PI * 2);
        context.fillStyle = "rgba(255,255,255,.7)";
        context.fill();
      }
    }
  }
  const characterVisible = visual?.character_visible ?? !(burstProgress >= 0 && burstProgress < 1);
  if (characterVisible)
    drawPhoneCharacter(context, visual, tuneTime, selectedColor);
  context.restore();
  bubblesPreviousFrame = now;
}
function animateBubbles(now) {
  renderBubbles(now);
  renderJoinPreviews(now);
  requestAnimationFrame(animateBubbles);
}
requestAnimationFrame(animateBubbles);
function rememberIdentity(message) {
  const player = message.player;
  if (!player || typeof player.name !== "string" || typeof message.session_id !== "string" || typeof message.reconnect_token !== "string")
    return false;
  store(STORAGE.name, player.name);
  store(STORAGE.session, message.session_id);
  store(STORAGE.token, message.reconnect_token);
  showJoined(player);
  return true;
}
function reconnect() {
  gameplayMotion.stop();
  motionLab.disconnect();
  if (stopped || retry !== void 0)
    return;
  lobbyControls.deactivate();
  setGameplaySurface(false);
  if (!readyCard.hidden) {
    readyButton.disabled = true;
    readyState.textContent = "Reconnecting…";
  }
  if (joined) {
    playerState.textContent = "Reconnecting";
    leaveButton.disabled = true;
  }
  status.textContent = "Host disconnected. Reconnecting…";
  status.hidden = false;
  retry = setTimeout(() => {
    retry = void 0;
    void connect();
  }, 2e3);
}
async function connect() {
  status.textContent = joined ? "Reconnecting to the host…" : "Connecting to the host…";
  status.hidden = false;
  let stage = "Fetch session configuration";
  let endpoint = new URL("/session.json", location.href).href;
  try {
    const response = await fetch("/session.json", {
      cache: "no-store",
      signal: AbortSignal.timeout(5e3)
    });
    if (!response.ok)
      throw new Error(`HTTP ${response.status} ${response.statusText}`);
    stage = "Parse session configuration JSON";
    const config = await response.json();
    stage = "Validate session transport configuration";
    const socketUrl = controllerSocketUrl(config, location.href);
    stage = "Open WebSocket";
    endpoint = socketUrl;
    if (stopped)
      return;
    const peer = new WebSocket(socketUrl);
    socket = peer;
    let socketFailure = "";
    const deadline = setTimeout(() => {
      socketFailure = "No host welcome received within 7000 ms.";
      reportConnectionFailure(stage, endpoint, socketFailure);
      peer.close();
    }, 7e3);
    peer.onopen = () => {
      stage = "Wait for host welcome";
      peer.send(JSON.stringify({
        type: "hello",
        protocol: 1,
        ...stored(STORAGE.token) ? { reconnect_token: stored(STORAGE.token), session_id: stored(STORAGE.session) } : {}
      }));
    };
    peer.onmessage = (event) => {
      let message;
      try {
        message = JSON.parse(event.data);
      } catch (error) {
        const cause = error instanceof Error ? error.name : "parse error";
        socketFailure = `Invalid JSON received from host (${cause}).`;
        reportConnectionFailure("Parse host message JSON", endpoint, socketFailure);
        peer.close();
        return;
      }
      if (message.type === "welcome" && message.protocol === 1 && Number.isInteger(message.connection_id)) {
        stage = "Connected WebSocket";
        connectionError.hidden = true;
        connectionError.textContent = "";
        clearTimeout(deadline);
        if (message.resume_status === "resumed" && rememberIdentity(message)) {
          if (message.gameplay?.type === "tilt_shift_snapshot")
            showTilt(message.gameplay);
          else if (message.gameplay?.type === "bubbles_snapshot")
            showBubbles(message.gameplay);
          else if (message.gameplay?.type === "pre_minigame_snapshot")
            showReady(message.gameplay);
          else if (message.gameplay?.type === "lobby" && message.player && "player_id" in message.player && "name" in message.player)
            showJoined(message.player, message.gameplay.message ?? "Waiting for the next game");
          return;
        }
        if (message.resume_status === "session_restarted") {
          forgetIdentity();
          showJoin("The host started a new session. Choose your character and name to join again.", true);
        } else if (message.resume_status === "expired") {
          forgetIdentity();
          showJoin("Your previous player expired. Choose your character and name to join again.", true);
        } else
          showJoin(isStandalone(window, navigator) && !stored(STORAGE.token) ? "Choose your character to join. If already playing in a browser, leave that controller first." : "Connected. Choose your character to join.", true);
      } else if (message.type === "join_accepted") {
        if (!rememberIdentity(message))
          peer.close();
      } else if (message.type === "join_rejected" || message.type === "error") {
        joinButton.disabled = false;
        readyButton.disabled = false;
        status.textContent = message.message ?? "The host could not complete that action.";
        status.hidden = false;
        if (message.type === "error")
          reportConnectionFailure("Host protocol error", endpoint, `${message.code ?? "unknown"}: ${status.textContent}`);
        if (!readyCard.hidden)
          readyState.textContent = status.textContent;
        if (!joined)
          nameInput.focus();
      } else if (message.type === "left") {
        forgetIdentity();
        showJoin("You left the lobby. Choose your character and name to join again.", true);
      } else if (message.type === "bubbles_trace_result")
        bubblesLocalCharge = 0;
      else if (message.type === "bubbles_visual" && message.visual && bubblesSnapshot) {
        bubblesVisualSnapshot = message.visual;
        bubblesVisualReceivedAt = performance.now();
      } else if (message.type === "bubbles_snapshot" || message.type === "bubbles_feedback")
        showBubbles(message);
      else if (message.type === "pre_minigame_snapshot")
        showReady(message);
      else if (message.type === "tilt_shift_snapshot")
        showTilt(message);
      else if (message.type === "motion_lab" && joined && typeof message.subscription_id === "string" && typeof message.send_hz === "number") {
        lobbyControls.deactivate();
        setGameplaySurface(false);
        document.documentElement.classList.remove("ready-active");
        selectionScreen.hidden = nameScreen.hidden = joinForm.hidden = playerCard.hidden = readyCard.hidden = bubblesCard.hidden = true;
        status.hidden = true;
        gameplayMotion.stop();
        motionLab.begin({
          subscription_id: message.subscription_id,
          send_hz: message.send_hz,
          stale_msec: message.stale_msec ?? 1e3
        });
      } else if (message.type === "motion_subscribe" && joined && typeof message.subscription_id === "string" && typeof message.send_hz === "number") {
        motionLab.stop();
        lobbyControls.deactivate();
        gameplayMotion.begin({
          subscription_id: message.subscription_id,
          send_hz: message.send_hz,
          stale_msec: message.stale_msec ?? 1e3
        });
        tiltPhone.feedback();
      } else if (message.type === "motion_control_state") {
        if (typeof message.subscription_id === "string") {
          if (message.control_state)
            gameplayMotion.feedback(message.subscription_id, message.control_state);
        }
      } else if (message.type === "motion_stop") {
        if (typeof message.subscription_id === "string")
          gameplayMotion.stop(message.subscription_id);
        motionLab.stop(message.subscription_id);
        if (joined && activeGame === null && readyCard.hidden && !gameplayMotion.active && !motionLab.active)
          lobbyControls.activate();
      } else if (message.type === "lobby") {
        gameplayMotion.stop();
        motionLab.stop();
        setGameplaySurface(false);
        readyCard.hidden = true;
        document.documentElement.classList.remove("ready-active");
        bubblesCard.hidden = true;
        bubblesSnapshot = void 0;
        bubblesVisualSnapshot = void 0;
        if (message.player)
          rememberIdentity(message);
        else if (joined) {
          playerCard.hidden = true;
          lobbyControls.activate();
          status.hidden = true;
        }
      }
    };
    peer.onclose = (event) => {
      clearTimeout(deadline);
      lobbyControls.deactivate();
      gameplayMotion.stop();
      motionLab.disconnect();
      if (activeGame === "tilt_shift")
        tiltPhone.disconnect();
      else
        setGameplaySurface(false);
      if (socket === peer)
        socket = void 0;
      if (event.code === 4e3) {
        stopped = true;
        leaveButton.disabled = true;
        readyCard.hidden = bubblesCard.hidden = true;
        document.documentElement.classList.remove("ready-active");
        status.textContent = "This player continued in another window. Reload to switch back.";
        status.hidden = false;
        playerState.textContent = "Open in another window";
        return;
      }
      if (!stopped)
        reportConnectionFailure(stage, endpoint, `${socketFailure ? socketFailure + "\n" : ""}WebSocket closed: code=${event.code}, reason=${event.reason || "(not provided)"}, wasClean=${event.wasClean}.`);
      reconnect();
    };
    peer.onerror = (event) => {
      socketFailure = `WebSocket ${event.type || "error"} event. Browser did not expose the underlying network/TLS reason.`;
      reportConnectionFailure(stage, endpoint, socketFailure);
      peer.close();
    };
  } catch (error) {
    if (!stopped)
      reportConnectionFailure(stage, endpoint, error);
    reconnect();
  }
}
joinForm.addEventListener("submit", (event) => {
  event.preventDefault();
  if (pwa.visible)
    return;
  const name = nameInput.value.trim();
  store(STORAGE.name, name);
  if (!socket || socket.readyState !== WebSocket.OPEN) {
    status.textContent = "Still connecting. Try again in a moment.";
    status.hidden = false;
    return;
  }
  joinButton.disabled = true;
  status.textContent = "Joining…";
  status.hidden = false;
  socket.send(JSON.stringify(createJoinMessage(name, joinFlow)));
});
function leaveLobby() {
  if (!socket || socket.readyState !== WebSocket.OPEN)
    return;
  lobbyControls.deactivate();
  leaveButton.disabled = true;
  lobbyLeaveButton.disabled = true;
  status.textContent = "Leaving…";
  socket.send(JSON.stringify({ type: "leave" }));
}
leaveButton.addEventListener("click", leaveLobby);
lobbyLeaveButton.addEventListener("click", leaveLobby);
window.addEventListener("pagehide", () => {
  stopped = true;
  lobbyControls.deactivate();
  clearTimeout(retry);
  retry = void 0;
  socket?.close();
});
window.addEventListener("pageshow", (event) => {
  if (event.persisted) {
    stopped = false;
    void connect();
  }
});
void connect();
