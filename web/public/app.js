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

// build/004_3d_bubbles/input.js
function canTouch(snapshot, connected) {
  return connected && snapshot?.phase === "active" && snapshot.connected && !snapshot.left;
}
function displacement(start, end, size2) {
  return end.map((value, index) => {
    const share = (value - start[index]) / Math.max(1, size2[index]);
    return Math.max(-1, Math.min(1, share));
  });
}
function quantize(value) {
  return value.map((axis) => Math.max(-4, Math.min(4, Math.round(axis * 10))) || 0);
}
var TouchInput = class {
  available;
  nextSequence;
  send;
  touch;
  constructor(available, nextSequence, send) {
    this.available = available;
    this.nextSequence = nextSequence;
    this.send = send;
  }
  start(point, size2, now) {
    if (!this.available() || this.touch)
      return false;
    const seq = this.nextSequence();
    this.touch = { seq, start: point, size: size2, current: [0, 0], sent: [0, 0], last: now, count: 0 };
    this.send({ type: "bubbles_3d_touch", input_seq: seq, stage: "start" });
    return true;
  }
  move(point, now) {
    if (!this.touch)
      return;
    this.touch.current = quantize(displacement(this.touch.start, point, this.touch.size));
    this.tick(now);
  }
  tick(now) {
    const touch = this.touch;
    if (!touch || !this.available())
      return;
    const changed = touch.current.some((axis, index) => axis !== touch.sent[index]);
    const elapsed = now - touch.last;
    if (touch.count >= 48 || elapsed < 70 || !changed && elapsed < 600)
      return;
    this.send({
      type: "bubbles_3d_touch",
      input_seq: touch.seq,
      stage: "drag",
      drag: [...touch.current]
    });
    touch.sent = [...touch.current];
    touch.last = now;
    touch.count++;
  }
  release(point) {
    const touch = this.touch;
    this.touch = void 0;
    if (!touch || !this.available())
      return;
    this.send({
      type: "bubbles_3d_release",
      input_seq: touch.seq,
      displacement: displacement(touch.start, point, touch.size)
    });
  }
  cancel() {
    const touch = this.touch;
    this.touch = void 0;
    if (touch && this.available())
      this.send({ type: "bubbles_3d_touch", input_seq: touch.seq, stage: "cancel" });
  }
};

// build/004_3d_bubbles/state.js
function isSnapshot(value) {
  if (!value || typeof value !== "object")
    return false;
  const type = value.type;
  return type === "bubbles_3d_snapshot" || type === "bubbles_3d_feedback";
}
var BubbleState = class {
  snapshot;
  snapshotAt = 0;
  visual;
  visualAt = 0;
  receive(message, now) {
    if (isSnapshot(message)) {
      if (this.snapshot && message.host_time_msec < this.snapshot.host_time_msec)
        return false;
      this.snapshot = message;
      this.snapshotAt = now;
      if (this.visual && this.visual.host_time_msec <= message.host_time_msec)
        this.visual = void 0;
      return true;
    }
    if (message.type === "bubbles_3d_visual" && this.snapshot) {
      const minimum = this.visual?.host_time_msec ?? this.snapshot.host_time_msec;
      if (message.visual.host_time_msec < minimum)
        return false;
      this.visual = message.visual;
      this.visualAt = now;
      return true;
    }
    return false;
  }
  frame(now) {
    const snapshot = this.snapshot;
    if (!snapshot)
      return;
    const elapsed = Math.max(0, now - this.snapshotAt);
    const running = snapshot.phase === "active" || snapshot.phase === "countdown";
    const age = running ? elapsed : 0;
    const reform = snapshot.visual_tuning.bubble_reform_seconds * 1e3;
    const remaining = Math.max(0, snapshot.reform_remaining_msec - age);
    const popAge = snapshot.reform_remaining_msec > 0 ? reform - snapshot.reform_remaining_msec + age : snapshot.event === "pop" ? age : -1;
    const visual = this.visual;
    if (visual) {
      const visualAge = running ? Math.max(0, now - this.visualAt) : 0;
      return {
        snapshot,
        visual: {
          ...visual,
          host_time_msec: visual.host_time_msec + visualAge,
          pop_age_msec: visual.pop_age_msec < 0 ? -1 : visual.pop_age_msec + visualAge
        }
      };
    }
    return {
      snapshot,
      visual: {
        host_time_msec: snapshot.host_time_msec + age,
        radius: snapshot.bubble_radius * Math.max(0.08, 1 - remaining / Math.max(1, reform)),
        stretch: [0, 0],
        velocity: [0, 0],
        white: snapshot.invulnerable_remaining_msec > age,
        pop_age_msec: popAge,
        caught: snapshot.visual_jellyfish
      }
    };
  }
};
async function choosePresentation(create, fallback) {
  try {
    return await create();
  } catch {
    return fallback();
  }
}

// build/004_3d_bubbles/phone.js
var BubblePhone = class {
  surface;
  canvas;
  score;
  circle;
  load;
  state = new BubbleState();
  presentation;
  pointer;
  timer;
  unbind;
  generation = 0;
  feedback = "";
  input;
  constructor(surface, canvas, score, circle, connected, nextSequence, send, load) {
    this.surface = surface;
    this.canvas = canvas;
    this.score = score;
    this.circle = circle;
    this.load = load;
    this.input = new TouchInput(() => !surface.hidden && canTouch(this.state.snapshot, connected()), nextSequence, send);
    surface.addEventListener("pointerdown", (event) => {
      if (this.pointer !== void 0 || event.pointerType === "mouse" && event.button !== 0)
        return;
      const rect = surface.getBoundingClientRect();
      if (!this.input.start([event.clientX, event.clientY], [rect.width, rect.height], performance.now()))
        return;
      event.preventDefault();
      this.pointer = event.pointerId;
      try {
        surface.setPointerCapture(event.pointerId);
      } catch {
        this.cancel();
      }
    });
    surface.addEventListener("pointermove", (event) => {
      if (event.pointerId !== this.pointer)
        return;
      event.preventDefault();
      this.input.move([event.clientX, event.clientY], performance.now());
    });
    surface.addEventListener("pointerup", (event) => {
      if (event.pointerId !== this.pointer)
        return;
      event.preventDefault();
      this.input.release([event.clientX, event.clientY]);
      this.cancel();
    });
    for (const name of ["pointercancel", "lostpointercapture"])
      surface.addEventListener(name, (event) => {
        if (event.pointerId === this.pointer)
          this.cancel();
      });
  }
  receive(message) {
    const previous = this.state.snapshot;
    if (isSnapshot(message) && message.phase === "lobby_return") {
      this.hide();
      return;
    }
    if (isSnapshot(message) && !canTouch(message, true))
      this.cancel();
    if (!this.state.receive(message, performance.now()))
      return;
    if (isSnapshot(message)) {
      this.surface.hidden = false;
      this.score.textContent = String(Math.max(0, Math.floor(message.score)));
      const key = `${message.host_time_msec}:${message.event}`;
      if (message.type === "bubbles_3d_feedback" && this.feedback !== key) {
        this.feedback = key;
        try {
          if (message.event === "captured")
            navigator.vibrate?.(18);
          else if (message.event === "pop")
            navigator.vibrate?.([35, 45, 35]);
        } catch {
        }
      }
      if (!previous)
        this.mount();
    }
    this.paint();
  }
  mount() {
    const generation = ++this.generation;
    this.presentation = this.fallback();
    this.unbind = bindControllerLifecycle(() => this.cancel());
    this.timer = setInterval(() => {
      this.input.tick(performance.now());
      this.paint();
    }, 30);
    void choosePresentation(async () => (await this.load()).createBubbleView(this.canvas), () => this.fallback()).then((presentation) => {
      if (generation !== this.generation) {
        presentation.dispose();
        return;
      }
      this.presentation?.dispose();
      this.presentation = presentation;
      this.canvas.hidden = false;
      this.circle.hidden = true;
      this.paint();
    });
  }
  fallback() {
    return {
      update: ({ snapshot, visual }) => {
        this.canvas.hidden = true;
        this.circle.hidden = false;
        this.circle.style.backgroundColor = snapshot.character_color;
        const maximum = Math.max(snapshot.visual_tuning.max_radius, visual.radius, 0.01);
        const size2 = 24 + 60 * visual.radius / maximum;
        this.circle.style.setProperty("--bubble-size", `${size2}%`);
      },
      dispose: () => {
      }
    };
  }
  paint() {
    if (document.hidden)
      return;
    const frame = this.state.frame(performance.now());
    if (frame)
      this.presentation?.update(frame);
  }
  cancel() {
    this.input.cancel();
    const pointer = this.pointer;
    this.pointer = void 0;
    if (pointer !== void 0 && this.surface.hasPointerCapture(pointer))
      this.surface.releasePointerCapture(pointer);
  }
  hide() {
    this.cancel();
    this.generation++;
    clearInterval(this.timer);
    this.timer = void 0;
    this.unbind?.();
    this.unbind = void 0;
    this.presentation?.dispose();
    this.presentation = void 0;
    this.state = new BubbleState();
    this.feedback = "";
    this.surface.hidden = true;
  }
};

// build/shape_paddle/face.js
var FACE_BASE = "/shape_faces/";
var BLINK_EYE = "facial_part_eye_closed_down";
var UNBLINKING_EYES = [
  "facial_part_eye_closed_down",
  "facial_part_eye_closed_up",
  "facial_part_eye_x",
  "facial_part_eye_squeezed",
  "facial_part_eye_spiral",
  "facial_part_eye_heart",
  "facial_part_eye_star",
  "facial_part_eye_money"
];
var EYE_PREFIX = "facial_part_eye_";
function validManifest(value) {
  if (!value || typeof value !== "object")
    return false;
  const manifest = value;
  return !!manifest.parts && typeof manifest.parts === "object" && !!manifest.faces && typeof manifest.faces === "object" && Object.values(manifest.faces).every((face2) => Number.isFinite(face2.box_aspect) && Array.isArray(face2.layers) && face2.layers.every((layer) => typeof layer.part === "string" && layer.part in manifest.parts));
}
async function loadManifest(base = FACE_BASE) {
  const response = await fetch(base + "face_presets.json");
  if (!response.ok)
    throw new Error("The face presets could not load");
  const manifest = await response.json();
  if (!validManifest(manifest))
    throw new Error("The face presets are not a face manifest");
  return manifest;
}
function canClose(part) {
  return part.startsWith(EYE_PREFIX) && !UNBLINKING_EYES.includes(part);
}
function faceLayers(manifest, name, blinking) {
  const face2 = manifest.faces[name];
  if (!face2)
    return [];
  if (!blinking)
    return face2.layers;
  const closed = manifest.parts[BLINK_EYE].size;
  const height = face2.source_size[1];
  return face2.layers.map((layer) => canClose(layer.part) ? {
    ...layer,
    part: BLINK_EYE,
    size: [closed[0] / height, closed[1] / height],
    rotation_degrees: 0
  } : layer);
}
var Blinker = class {
  gaps;
  closedSeconds;
  random;
  next = -1;
  constructor(gaps = [2.4, 5.6], closedSeconds = 0.12, random = Math.random) {
    this.gaps = gaps;
    this.closedSeconds = closedSeconds;
    this.random = random;
  }
  /** True while a blink closes the eyes at [seconds]; calls must move forward in time. */
  closed(seconds) {
    if (this.next < 0)
      this.next = seconds + this.gap();
    while (seconds >= this.next + this.closedSeconds)
      this.next += this.closedSeconds + this.gap();
    return seconds >= this.next;
  }
  gap() {
    const [shortest, longest] = this.gaps;
    return shortest + (Math.max(shortest, longest) - shortest) * this.random();
  }
};
var FaceImages = class {
  manifest;
  base;
  loaded;
  images = /* @__PURE__ */ new Map();
  constructor(manifest, base = FACE_BASE, loaded = () => {
  }) {
    this.manifest = manifest;
    this.base = base;
    this.loaded = loaded;
  }
  image(part) {
    const entry = this.manifest.parts[part];
    if (!entry)
      return void 0;
    let image = this.images.get(part);
    if (!image) {
      image = new Image();
      image.addEventListener("load", this.loaded);
      image.src = this.base + entry.file;
      this.images.set(part, image);
    }
    return image;
  }
};
function drawFace(context, images, layers, height) {
  for (const layer of layers) {
    const image = images.image(layer.part);
    if (!image?.complete || !image.naturalWidth)
      continue;
    const width = layer.size[0] * height;
    const tall = layer.size[1] * height;
    context.save();
    context.translate(layer.center[0] * height, layer.center[1] * height);
    context.rotate(layer.rotation_degrees * Math.PI / 180);
    if (layer.mirror)
      context.scale(-1, 1);
    context.drawImage(image, -width / 2, -tall / 2, width, tall);
    context.restore();
  }
}

// build/shape_paddle/rounded_bar.js
var CORNER_SEGMENTS = 5;
function roundedOutline(length, thickness, radius, segments = CORNER_SEGMENTS) {
  const halfX = Math.max(length, 1e-4) / 2;
  const halfY = Math.max(thickness, 1e-4) / 2;
  const corner = Math.min(Math.max(radius, 0), halfX, halfY);
  const innerX = halfX - corner;
  const innerY = halfY - corner;
  const centres = [
    [innerX, innerY],
    [-innerX, innerY],
    [-innerX, -innerY],
    [innerX, -innerY]
  ];
  const count = Math.max(1, Math.floor(segments));
  const points = [];
  centres.forEach(([x2, y2], index) => {
    for (let step = 0; step <= count; step++) {
      const angle = index * Math.PI / 2 + Math.PI / 2 * step / count;
      points.push([x2 + Math.cos(angle) * corner, y2 + Math.sin(angle) * corner]);
    }
  });
  return points;
}
function tracePath(context, outline) {
  context.beginPath();
  outline.forEach(([x2, y2], index) => {
    if (index === 0)
      context.moveTo(x2, -y2);
    else
      context.lineTo(x2, -y2);
  });
  context.closePath();
}

// build/shape_paddle/paddle.js
function validLook(value) {
  if (!value || typeof value !== "object")
    return false;
  const look = value;
  const colour2 = (text) => typeof text === "string" && /^[0-9a-f]{6}$/i.test(text);
  return [
    look.corner_ratio,
    look.depth_ratio,
    look.gap_ratio,
    look.outline_ratio,
    look.face_ratio
  ].every((ratio) => Number.isFinite(ratio) && ratio >= 0 && ratio <= 3) && colour2(look.gap_color) && Array.isArray(look.outline_colors) && look.outline_colors.length === 3 && look.outline_colors.every(colour2) && Array.isArray(look.wall_colors) && look.wall_colors.length === 2 && look.wall_colors.every(colour2);
}
function paddleOutlines(shape) {
  const { length, thickness, look } = shape;
  const radius = thickness * look.corner_ratio;
  const gap = thickness * look.gap_ratio;
  const outline = gap + thickness * look.outline_ratio;
  return [
    roundedOutline(length + outline * 2, thickness + outline * 2, radius + outline),
    roundedOutline(length + gap * 2, thickness + gap * 2, radius + gap),
    roundedOutline(length, thickness, radius)
  ];
}
function drawPaddle(context, shape, angle, images, layers) {
  context.save();
  context.rotate(angle);
  const colours = [shape.outline, shape.look.gap_color, shape.body];
  paddleOutlines(shape).forEach((outline, index) => {
    tracePath(context, outline);
    context.fillStyle = `#${colours[index].replace(/^#/, "")}`;
    context.fill();
  });
  if (images)
    drawFace(context, images, layers, shape.thickness * shape.look.face_ratio);
  context.restore();
}

// build/005_3d_tilt_shift/fallback.js
var FlatPaddleView = class {
  canvas;
  manifest;
  frame;
  context;
  blinker = new Blinker();
  images;
  request = 0;
  disposed = false;
  constructor(canvas, manifest) {
    this.canvas = canvas;
    this.manifest = manifest;
    this.context = canvas.getContext("2d");
    this.images = manifest ? new FaceImages(manifest, void 0, () => this.draw()) : void 0;
    this.request = requestAnimationFrame(this.tick);
  }
  update(frame) {
    this.frame = frame;
  }
  dispose() {
    this.disposed = true;
    cancelAnimationFrame(this.request);
  }
  tick = () => {
    if (this.disposed)
      return;
    this.draw();
    this.request = requestAnimationFrame(this.tick);
  };
  draw() {
    const context = this.context;
    if (!context || !this.frame)
      return;
    const width = this.canvas.clientWidth;
    const height = this.canvas.clientHeight;
    const ratio = Math.min(devicePixelRatio || 1, 2);
    if (this.canvas.width !== Math.round(width * ratio))
      this.canvas.width = Math.round(width * ratio);
    if (this.canvas.height !== Math.round(height * ratio))
      this.canvas.height = Math.round(height * ratio);
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
    context.clearRect(0, 0, width, height);
    const { shape, angle, face: face2, resting } = this.frame;
    const scale = Math.min(width, height) * (resting ? 0.6 : 0.82) / shape.length;
    context.translate(width / 2, height / 2);
    context.scale(scale, scale);
    const layers = this.manifest ? faceLayers(this.manifest, face2, this.blinker.closed(performance.now() / 1e3)) : [];
    drawPaddle(context, shape, angle, this.images, layers);
  }
};

// build/005_3d_tilt_shift/types.js
var WORLD_UNITS = 19.2;
var PHASES = ["preparing", "countdown", "start", "active", "between_rounds", "finished"];
var colour = (value) => typeof value === "string" && /^[0-9a-f]{6}$/i.test(value);
var face = (value) => typeof value === "string" && value.length <= 64 && /^face_[a-z]+(?:_[a-z]+)*$/.test(value);
var size = (value) => Array.isArray(value) && value.length === 2 && value.every((part) => Number.isFinite(part) && part > 0 && part <= 2);
function validSnapshot(value) {
  if (!value || typeof value !== "object")
    return false;
  const v2 = value;
  return v2.type === "tilt_shift_3d_snapshot" && typeof v2.generation === "string" && v2.generation.length > 0 && v2.generation.length <= 64 && Number.isSafeInteger(v2.sequence) && v2.sequence >= 0 && PHASES.includes(v2.phase) && Number.isInteger(v2.round) && v2.round >= 1 && v2.round <= 24 && (v2.team === 0 || v2.team === 1) && Number.isFinite(v2.angle_radians) && Array.isArray(v2.paddle_ids) && (v2.paddle_ids.length >= 1 || v2.selected === false) && v2.paddle_ids.length <= 5 && new Set(v2.paddle_ids).size === v2.paddle_ids.length && v2.paddle_ids.every((id) => typeof id === "string" && id.length > 0 && id.length <= 96) && (v2.selected === void 0 || typeof v2.selected === "boolean") && (v2.round_token === void 0 || typeof v2.round_token === "string" && v2.round_token.length > 0 && v2.round_token.length <= 64) && [
    v2.ready,
    v2.ready_available,
    v2.calibration_available,
    v2.calibrated,
    v2.usable,
    v2.landscape
  ].every((flag) => flag === void 0 || typeof flag === "boolean") && size(v2.paddle_size) && colour(v2.color) && face(v2.face) && validLook(v2.look);
}
function validPreparation(value) {
  if (!value || typeof value !== "object")
    return false;
  const v2 = value;
  return typeof v2.generation === "string" && Number.isFinite(v2.angle_radians) && typeof v2.usable === "boolean" && typeof v2.calibrated === "boolean" && size(v2.paddle_size) && colour(v2.color) && face(v2.face) && validLook(v2.look);
}
function paddleShape(sizeInWidths, color, team, look) {
  return {
    length: sizeInWidths[0] * WORLD_UNITS,
    thickness: sizeInWidths[1] * WORLD_UNITS,
    body: color,
    outline: look.outline_colors[Math.min(2, Math.max(0, team))],
    look
  };
}

// build/005_3d_tilt_shift/phone.js
var NO_TEAM = 2;
var RETRY_MSEC = 1e3;
var STAGGER_MSEC = 1500;
var TiltShift3DPhone = class {
  surface;
  stream;
  sendReady;
  load;
  isLandscape;
  canvas;
  flat;
  actions;
  permission;
  calibration;
  ready;
  state;
  orientation;
  presentation;
  manifest;
  mounting = 0;
  mounted = false;
  frame;
  team = NO_TEAM;
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
  constructor(surface, stream, sendReady, load, isLandscape = () => window.matchMedia("(orientation: landscape)").matches) {
    this.surface = surface;
    this.stream = stream;
    this.sendReady = sendReady;
    this.load = load;
    this.isLandscape = isLandscape;
    this.canvas = surface.querySelector("#tilt3d-paddle");
    this.flat = surface.querySelector("#tilt3d-flat");
    this.actions = surface.querySelector("#tilt3d-actions");
    this.permission = surface.querySelector("#tilt3d-permission");
    this.calibration = surface.querySelector("#tilt3d-calibrate");
    this.ready = surface.querySelector("#tilt3d-ready");
    this.state = surface.querySelector("#tilt3d-state");
    this.orientation = surface.querySelector("#tilt3d-orientation");
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
  }
  preparation(value, ready) {
    if (!validPreparation(value))
      return false;
    this.generation = value.generation;
    this.sequence = -1;
    this.preparing = this.readyAvailable = this.selected = this.connected = true;
    this.roundToken = void 0;
    this.usable = value.usable;
    this.calibrated = value.calibrated;
    this.landscape = value.landscape === true;
    this.capture = value.capture_state;
    this.isReady = ready;
    this.team = NO_TEAM;
    this.show(value, value.angle_radians);
    return true;
  }
  snapshot(value) {
    if (!validSnapshot(value))
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
    this.show(value, this.selected ? value.angle_radians : 0);
    this.surface.hidden = value.phase === "finished";
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
    this.mounting++;
    this.mounted = false;
    this.presentation?.dispose();
    this.presentation = void 0;
    this.frame = void 0;
  }
  /** The frame the phone draws now, for tests. */
  currentFrame() {
    return this.frame;
  }
  show(value, angle) {
    this.frame = {
      shape: paddleShape(value.paddle_size, value.color, this.team, value.look),
      angle,
      face: value.face,
      resting: !this.selected
    };
    const [top, bottom] = value.look.wall_colors;
    this.surface.style.setProperty("--tilt3d-wall", `linear-gradient(#${top}, #${bottom})`);
    this.surface.hidden = false;
    this.surface.setAttribute("data-waiting", String(!this.selected));
    this.surface.setAttribute("data-team", String(this.team));
    this.buttons();
    if (!this.mounted) {
      this.mounted = true;
      this.mount();
    }
    this.presentation?.update(this.frame);
  }
  /**
   * Draws in 3D once three.js and the faces load; without WebGL, or if either fails, the flat
   * drawing takes over on its own canvas, since a canvas keeps the first kind of context it gets.
   */
  mount() {
    const mounting = ++this.mounting;
    this.canvas.hidden = this.flat.hidden = true;
    void (async () => {
      let next;
      let flat = false;
      try {
        next = await this.createView(mounting).catch(async () => {
          await new Promise((done) => setTimeout(done, RETRY_MSEC));
          return this.createView(mounting);
        });
      } catch {
        if (mounting !== this.mounting)
          return;
        next = new FlatPaddleView(this.flat, this.manifest);
        flat = true;
      }
      if (mounting !== this.mounting) {
        next.dispose();
        return;
      }
      this.presentation = next;
      this.canvas.hidden = flat;
      this.flat.hidden = !flat;
      this.surface.setAttribute("data-view", flat ? "flat" : "3d");
      if (this.frame)
        next.update(this.frame);
    })();
  }
  async createView(mounting) {
    if (!this.manifest) {
      await new Promise((done) => setTimeout(done, Math.random() * STAGGER_MSEC));
      if (mounting !== this.mounting)
        throw new Error("The phone left this screen");
    }
    this.manifest ??= await loadManifest();
    if (mounting !== this.mounting)
      throw new Error("The phone left this screen");
    return (await this.load()).createTiltPaddleView(this.canvas, this.manifest);
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
};

// build/flappy_flight/heart_row.js
var HeartRow = class {
  count;
  full;
  /** Ticks of progress on the leftmost empty heart. */
  refillTicks = 0;
  owed = false;
  recoveryTicks;
  constructor(heartCount, heartRecoveryTicks) {
    this.count = heartCount;
    this.full = heartCount;
    this.recoveryTicks = heartRecoveryTicks;
  }
  /** Advances the refill by one tick. Returns true when a heart finished refilling. */
  tick() {
    if (this.full >= this.count)
      return false;
    this.refillTicks += 1;
    if (this.refillTicks < this.recoveryTicks)
      return false;
    this.refillTicks = 0;
    if (this.owed)
      this.owed = false;
    else
      this.full += 1;
    return true;
  }
  hit() {
    if (this.full > 0)
      this.full -= 1;
    else
      this.owed = true;
  }
  /** How far the leftmost empty heart has refilled, 0 to 1. */
  refillShare() {
    return this.refillTicks / this.recoveryTicks;
  }
  copyFrom(other) {
    this.count = other.count;
    this.full = other.full;
    this.refillTicks = other.refillTicks;
    this.owed = other.owed;
    this.recoveryTicks = other.recoveryTicks;
  }
};

// build/flappy_flight/tuning.js
var TICK_RATE = 60;
var TICK = 1 / TICK_RATE;
var BODY_SIZE = 2;
function hitHalf(tuning) {
  return BODY_SIZE * 0.5 - tuning.hit_box_inset;
}
function boostedSpeed(tuning) {
  return tuning.forward_speed * (1 + tuning.boost_share);
}

// build/flappy_flight/flight.js
var EVENT_FLAP = 1;
var EVENT_HIT = 2;
var EVENT_PICKUP = 4;
var EVENT_HEART_REFILLED = 8;
var EVENT_READY = 16;
var EVENT_RESPAWN = 32;
var FlappyFlightState = class _FlappyFlightState {
  /** Body centre, metres along the course and above the ground. While waiting, the respawn spot. */
  x = 0;
  y = 0;
  verticalSpeed = 0;
  /** False from a hit until the respawn tap. */
  flying = true;
  /** Waiting and allowed to respawn: the cooldown is over and no heart is owed. */
  ready = false;
  cooldownTicks = 0;
  invulnerableTicks = 0;
  boostTicks = 0;
  /** The first obstacle the hit box has not yet passed. */
  obstacleIndex = 0;
  hearts;
  /** One entry per course pickup, 1 once this player has taken it. */
  taken;
  constructor(hearts, pickupCount) {
    this.hearts = hearts;
    this.taken = new Uint8Array(pickupCount);
  }
  copyFrom(other) {
    this.x = other.x;
    this.y = other.y;
    this.verticalSpeed = other.verticalSpeed;
    this.flying = other.flying;
    this.ready = other.ready;
    this.cooldownTicks = other.cooldownTicks;
    this.invulnerableTicks = other.invulnerableTicks;
    this.boostTicks = other.boostTicks;
    this.obstacleIndex = other.obstacleIndex;
    this.hearts.copyFrom(other.hearts);
    this.taken = other.taken.slice();
  }
  copy() {
    const state = new _FlappyFlightState(new HeartRow(0, 1), 0);
    state.copyFrom(this);
    return state;
  }
};
var FlappyFlight = class {
  course;
  forwardSpeed;
  boostedSpeed;
  flapVelocity;
  gravity;
  maxFallSpeed;
  hitHalf;
  heartCount;
  heartRecoveryTicks;
  cooldownTicks;
  invulnerableTicks;
  boostTicks;
  constructor(tuning, course) {
    this.course = course;
    this.forwardSpeed = tuning.forward_speed;
    this.boostedSpeed = boostedSpeed(tuning);
    this.flapVelocity = tuning.flap_velocity;
    this.gravity = tuning.gravity;
    this.maxFallSpeed = tuning.max_fall_speed;
    this.hitHalf = hitHalf(tuning);
    this.heartCount = tuning.heart_count;
    this.heartRecoveryTicks = tuning.heart_recovery_ticks;
    this.cooldownTicks = tuning.respawn_cooldown_ticks;
    this.invulnerableTicks = tuning.invulnerable_ticks;
    this.boostTicks = tuning.boost_ticks;
  }
  /** A player at the start line at GO, flying with every heart full. */
  newState() {
    const hearts = new HeartRow(this.heartCount, this.heartRecoveryTicks);
    const state = new FlappyFlightState(hearts, this.course.pickups.length);
    state.x = this.course.start_x;
    state.y = this.course.start_y;
    return state;
  }
  /**
   * Advances `state` by one tick. `tap` is a touch-down during this tick: a flap while flying,
   * the respawn while waiting and ready, and nothing otherwise. Returns the EVENT_ bits.
   */
  step(state, tap) {
    let events = 0;
    if (state.hearts.tick())
      events |= EVENT_HEART_REFILLED;
    if (!state.flying) {
      if (state.cooldownTicks > 0)
        state.cooldownTicks -= 1;
      if (!state.ready && state.cooldownTicks === 0 && !state.hearts.owed) {
        state.ready = true;
        events |= EVENT_READY;
      }
      if (!state.ready || !tap)
        return events;
      state.flying = true;
      state.ready = false;
      state.invulnerableTicks = this.invulnerableTicks;
      state.obstacleIndex = 0;
      events |= EVENT_RESPAWN;
    }
    if (tap) {
      state.verticalSpeed = this.flapVelocity;
      events |= EVENT_FLAP;
    } else {
      state.verticalSpeed = Math.max(state.verticalSpeed - this.gravity * TICK, -this.maxFallSpeed);
    }
    const speed = state.boostTicks > 0 ? this.boostedSpeed : this.forwardSpeed;
    state.x += speed * TICK;
    state.y += state.verticalSpeed * TICK;
    if (state.boostTicks > 0)
      state.boostTicks -= 1;
    events |= this.takePickups(state);
    events |= this.collide(state);
    if (state.invulnerableTicks > 0)
      state.invulnerableTicks -= 1;
    return events;
  }
  takePickups(state) {
    let events = 0;
    const pickups = this.course.pickups;
    for (let index = 0; index < pickups.length; index += 1) {
      if (state.taken[index] !== 0)
        continue;
      const pickup = pickups[index];
      const reach = this.hitHalf + pickup.half_size;
      if (Math.abs(state.x - pickup.x) < reach && Math.abs(state.y - pickup.y) < reach) {
        state.taken[index] = 1;
        state.boostTicks = this.boostTicks;
        events |= EVENT_PICKUP;
      }
    }
    return events;
  }
  collide(state) {
    const obstacles = this.course.obstacles;
    const back = state.x - this.hitHalf;
    const front = state.x + this.hitHalf;
    while (state.obstacleIndex < obstacles.length && obstacles[state.obstacleIndex].x_end <= back)
      state.obstacleIndex += 1;
    if (state.invulnerableTicks > 0) {
      if (state.y - this.hitHalf < 0) {
        state.y = this.hitHalf;
        if (state.verticalSpeed < 0)
          state.verticalSpeed = 0;
      }
      return 0;
    }
    if (state.obstacleIndex < obstacles.length) {
      const obstacle = obstacles[state.obstacleIndex];
      const inside = front > obstacle.x_start && back < obstacle.x_end;
      const outsideGap = state.y - this.hitHalf < obstacle.gap_bottom || state.y + this.hitHalf > obstacle.gap_top;
      if (inside && outsideGap)
        return this.hit(state, obstacle.respawn_x, obstacle.respawn_y);
    }
    if (state.y - this.hitHalf <= 0) {
      if (obstacles.length === 0)
        return this.hit(state, state.x, this.course.start_y);
      const index = Math.min(state.obstacleIndex, obstacles.length - 1);
      return this.hit(state, obstacles[index].respawn_x, obstacles[index].respawn_y);
    }
    return 0;
  }
  hit(state, respawnX, respawnY) {
    state.flying = false;
    state.ready = false;
    state.x = respawnX;
    state.y = respawnY;
    state.verticalSpeed = 0;
    state.boostTicks = 0;
    state.invulnerableTicks = 0;
    state.cooldownTicks = this.cooldownTicks;
    state.hearts.hit();
    return EVENT_HIT;
  }
};

// build/006_flappy_race/framing.js
function courseWindow(viewHeight, aspect, focusX, share) {
  const width = viewHeight * aspect;
  return { left: focusX - share * width, width, height: viewHeight };
}
function toCanvas(window2, size2, x2, y2) {
  return [(x2 - window2.left) / window2.width * size2[0], (1 - y2 / window2.height) * size2[1]];
}

// build/006_flappy_race/fallback.js
function createFallbackView(canvas, setup) {
  const { course } = setup;
  const context = canvas.getContext("2d");
  let focus = course.flight.start_x;
  let shown = courseWindow(course.view_height, 1, focus, setup.focusShare);
  let size2 = [1, 1];
  return {
    draw(frame) {
      if (!context)
        return;
      const rect = canvas.getBoundingClientRect();
      const ratio = Math.min(2, window.devicePixelRatio || 1);
      const width = Math.max(1, Math.round(rect.width * ratio));
      const height = Math.max(1, Math.round(rect.height * ratio));
      if (canvas.width !== width || canvas.height !== height) {
        canvas.width = width;
        canvas.height = height;
      }
      size2 = [Math.max(1, rect.width), Math.max(1, rect.height)];
      focus = frame.focusX;
      shown = courseWindow(course.view_height, size2[0] / size2[1], focus, setup.focusShare);
      const at = (x3, y3) => toCanvas(shown, size2, x3, y3);
      const metre = size2[1] / course.view_height;
      const box = (color, x0, x1, y0, y1) => {
        const [left, top] = at(x0, y1);
        const [right2, bottom] = at(x1, y0);
        context.fillStyle = color;
        context.fillRect(left, top, right2 - left, bottom - top);
      };
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
      context.clearRect(0, 0, size2[0], size2[1]);
      const flight = course.flight;
      const right = shown.left + shown.width;
      box("#fff3cb", flight.finish_x - 0.25, flight.finish_x + 0.25, 0, course.view_height);
      for (const obstacle of flight.obstacles) {
        if (obstacle.x_end < shown.left || obstacle.x_start > right)
          continue;
        box("#d6a86c", obstacle.x_start, obstacle.x_end, 0, obstacle.gap_bottom);
        box("#d6a86c", obstacle.x_start, obstacle.x_end, obstacle.gap_top, course.view_height * 2);
      }
      box("#b98a55", shown.left, right, -course.view_height, 0);
      context.fillStyle = "#f2c230";
      flight.pickups.forEach((pickup, index) => {
        if (frame.taken[index] !== 0 || pickup.x < shown.left - 2 || pickup.x > right + 2)
          return;
        const [x3, y3] = at(pickup.x, pickup.y);
        context.beginPath();
        context.arc(x3, y3, pickup.half_size * metre, 0, Math.PI * 2);
        context.fill();
      });
      if (!frame.cubioVisible)
        return;
      const [x2, y2] = at(frame.cubioX, frame.cubioY);
      context.translate(x2, y2);
      context.rotate(-frame.tilt);
      context.fillStyle = setup.color;
      context.fillRect(-metre, -metre, metre * 2, metre * 2);
      context.fillStyle = "#1f2a33";
      for (const eye of [-0.4, 0.4]) {
        context.beginPath();
        context.arc(eye * metre, -0.2 * metre, 0.16 * metre, 0, Math.PI * 2);
        context.fill();
      }
    },
    project(x2, y2) {
      return toCanvas(shown, size2, x2, y2);
    },
    dispose() {
      context?.setTransform(1, 0, 0, 1, 0, 0);
      context?.clearRect(0, 0, canvas.width, canvas.height);
    }
  };
}

// build/006_flappy_race/hud.js
function ordinal(place) {
  const tens = place % 100;
  const ones = place % 10;
  const suffix = tens >= 11 && tens <= 13 ? "th" : ones === 1 ? "st" : ones === 2 ? "nd" : ones === 3 ? "rd" : "th";
  return `${place}${suffix}`;
}
function clockText(seconds) {
  const whole = Math.max(0, Math.ceil(seconds));
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`;
}
var FlappyRaceHud = class {
  root;
  hearts;
  progress;
  timer;
  cue;
  floating;
  layer;
  shownCount = -1;
  constructor(root) {
    this.root = root;
    const find = (selector) => root.querySelector(selector);
    this.hearts = find(".flappy-hearts");
    this.progress = find(".flappy-progress-fill");
    this.timer = find(".flappy-timer");
    this.cue = find(".flappy-cue");
    this.floating = find(".flappy-floating-heart");
    this.layer = find(".flappy-hud");
  }
  update(frame) {
    const { count, full, refillShare } = frame.hearts;
    if (this.shownCount !== count) {
      this.shownCount = count;
      this.hearts.replaceChildren(...Array.from({ length: count }, () => {
        const heart = document.createElement("span");
        heart.className = "flappy-heart";
        heart.textContent = "♥";
        return heart;
      }));
    }
    Array.from(this.hearts.children).forEach((child, index) => {
      const heart = child;
      heart.dataset.fill = index < full ? "full" : index === full ? "refill" : "empty";
      heart.style.setProperty("--refill", index === full ? String(refillShare) : "0");
    });
    const progress = Math.min(1, Math.max(0, frame.progress));
    this.progress.style.inlineSize = `${Math.round(progress * 1e3) / 10}%`;
    this.timer.textContent = clockText(frame.secondsLeft);
    this.timer.dataset.last = String(frame.lastSeconds);
    if (this.cue.textContent !== frame.cue)
      this.cue.textContent = frame.cue;
    this.cue.hidden = frame.cue === "";
    const floating = frame.floating;
    this.floating.hidden = !floating;
    if (floating) {
      this.floating.dataset.state = floating.state;
      this.floating.style.setProperty("--refill", String(floating.refillShare));
      this.floating.style.transform = `translate(${floating.at[0]}px, ${floating.at[1]}px)`;
    }
  }
  /** Flies a copy of heart `index` from the row to `to`, in canvas CSS pixels. */
  flyHeart(index, to, seconds) {
    const source = this.hearts.children[index];
    if (!source)
      return;
    const layer = this.layer.getBoundingClientRect();
    const start = source.getBoundingClientRect();
    const flying = document.createElement("span");
    flying.className = "flappy-heart flappy-heart-flight";
    flying.textContent = "♥";
    flying.dataset.fill = "full";
    this.root.append(flying);
    const from = [
      start.left + start.width / 2 - layer.left,
      start.top + start.height / 2 - layer.top
    ];
    const keyframes = [
      { transform: `translate(${from[0]}px, ${from[1]}px) scale(1)` },
      { transform: `translate(${to[0]}px, ${to[1]}px) scale(1.6)` }
    ];
    const animation = flying.animate?.(keyframes, {
      duration: seconds * 1e3,
      easing: "ease-in-out"
    });
    if (!animation) {
      flying.remove();
      return;
    }
    animation.onfinish = animation.oncancel = () => flying.remove();
  }
  /** Removes any heart still in flight. */
  clear() {
    for (const flying of Array.from(this.root.querySelectorAll(".flappy-heart-flight")))
      flying.remove();
  }
};

// build/006_flappy_race/messages.js
function typed(value, type) {
  return !!value && typeof value === "object" && value.type === type;
}
function isSnapshot2(value) {
  return typed(value, "flappy_race_snapshot");
}
function isState(value) {
  return typed(value, "flappy_race_state") && Number.isInteger(value.tick);
}
function isEvent(value) {
  return typed(value, "flappy_race_event") && typeof value.event === "string";
}
function flightState(flight, tuning, pickupCount) {
  const hearts = new HeartRow(tuning.heart_count, tuning.heart_recovery_ticks);
  hearts.full = flight.hearts.full;
  hearts.refillTicks = flight.hearts.refill_ticks;
  hearts.owed = flight.hearts.owed;
  const state = new FlappyFlightState(hearts, pickupCount);
  state.x = flight.x;
  state.y = flight.y;
  state.verticalSpeed = flight.vertical_speed;
  state.flying = flight.flying;
  state.ready = flight.ready;
  state.cooldownTicks = flight.cooldown_ticks;
  state.invulnerableTicks = flight.invulnerable_ticks;
  state.boostTicks = flight.boost_ticks;
  state.obstacleIndex = flight.obstacle_index;
  for (const index of flight.taken)
    if (index >= 0 && index < pickupCount)
      state.taken[index] = 1;
  return state;
}

// build/006_flappy_race/prediction.js
var MOST_TICKS = 600;
function sameFlight(a2, b2) {
  if (a2.x !== b2.x || a2.y !== b2.y || a2.verticalSpeed !== b2.verticalSpeed || a2.flying !== b2.flying || a2.ready !== b2.ready || a2.cooldownTicks !== b2.cooldownTicks || a2.invulnerableTicks !== b2.invulnerableTicks || a2.boostTicks !== b2.boostTicks || a2.obstacleIndex !== b2.obstacleIndex || a2.hearts.full !== b2.hearts.full || a2.hearts.refillTicks !== b2.hearts.refillTicks || a2.hearts.owed !== b2.hearts.owed || a2.taken.length !== b2.taken.length)
    return false;
  return a2.taken.every((taken, index) => taken === b2.taken[index]);
}
var FlappyPrediction = class {
  flight;
  /** The tick `state` has been stepped to. */
  tick;
  state;
  /** Host corrections so far, for tests and diagnostics. */
  corrections = 0;
  /** Drawn minus predicted position, metres; it decays to zero. */
  offsetX = 0;
  offsetY = 0;
  history = /* @__PURE__ */ new Map();
  taps = /* @__PURE__ */ new Set();
  constructor(flight, state, tick) {
    this.flight = flight;
    this.state = state;
    this.tick = tick;
  }
  get finished() {
    return this.state.x >= this.flight.course.finish_x;
  }
  /** Applies a touch-down at the next tick and returns that tick, for flappy_tap. */
  tap() {
    const tick = this.tick + 1;
    this.taps.add(tick);
    return tick;
  }
  /**
   * Steps toward `target`, at most MOST_TICKS at a time so a page back from the background
   * catches up over a few frames, and stopping at the finish line. Returns the event bits.
   */
  advanceTo(target) {
    let events = 0;
    const last = Math.min(target, this.tick + MOST_TICKS);
    while (this.tick < last && !this.finished) {
      this.tick += 1;
      events |= this.flight.step(this.state, this.taps.has(this.tick));
      this.history.set(this.tick, this.state.copy());
    }
    return events;
  }
  /**
   * The host's settled `host` flight at `tick`. Returns true when it differed and the prediction
   * was corrected.
   */
  confirm(tick, host) {
    if (tick > this.tick)
      this.advanceTo(tick);
    const ours = tick === this.tick ? this.state : this.history.get(tick);
    if (ours && sameFlight(ours, host)) {
      this.forget(tick);
      return false;
    }
    const before = this.state;
    const replayed = host.copy();
    this.history.clear();
    this.history.set(tick, replayed.copy());
    const last = Math.min(this.tick, tick + MOST_TICKS);
    for (let next = tick + 1; next <= last; next += 1) {
      if (replayed.x >= this.flight.course.finish_x)
        break;
      this.flight.step(replayed, this.taps.has(next));
      this.history.set(next, replayed.copy());
    }
    this.state = replayed;
    this.tick = Math.max(this.tick, tick);
    this.corrections += 1;
    if (before.flying === replayed.flying) {
      this.offsetX += before.x - replayed.x;
      this.offsetY += before.y - replayed.y;
    } else {
      this.offsetX = this.offsetY = 0;
    }
    this.forget(tick);
    return true;
  }
  /** Blends the drawn position toward the prediction over about `seconds`. */
  blend(delta, seconds) {
    const keep = seconds > 0 ? Math.exp(-delta / seconds) : 0;
    this.offsetX *= keep;
    this.offsetY *= keep;
    if (Math.abs(this.offsetX) < 1e-4)
      this.offsetX = 0;
    if (Math.abs(this.offsetY) < 1e-4)
      this.offsetY = 0;
  }
  get drawnX() {
    return this.state.x + this.offsetX;
  }
  get drawnY() {
    return this.state.y + this.offsetY;
  }
  /** The host has settled everything up to `tick`, so nothing before it is replayed again. */
  forget(tick) {
    for (const key of this.history.keys())
      if (key < tick)
        this.history.delete(key);
    for (const key of this.taps)
      if (key <= tick)
        this.taps.delete(key);
  }
};

// build/006_flappy_race/race_clock.js
var RaceClock = class {
  go;
  /** A host message reading `clockTick` arrived at local time `now`, in milliseconds. */
  observe(clockTick, now) {
    const go = now - clockTick * 1e3 / TICK_RATE;
    if (this.go === void 0 || go < this.go)
      this.go = go;
  }
  get started() {
    return this.go !== void 0;
  }
  /** Whole ticks since GO at local time `now`. */
  tick(now) {
    if (this.go === void 0)
      return Number.NEGATIVE_INFINITY;
    return Math.floor((now - this.go) * TICK_RATE / 1e3);
  }
  /** Milliseconds from `now` to GO; zero once the race runs. */
  untilGo(now) {
    return this.go === void 0 ? 0 : Math.max(0, this.go - now);
  }
};

// build/006_flappy_race/phone.js
var GO_SECONDS = 0.6;
var FOCUS_SECONDS = 0.25;
var TUMBLE_TURNS = 1.5;
function faceFor(moment, place = 0, players = 1) {
  switch (moment) {
    case "countdown":
      return "face_scheming";
    case "pickup":
      return "face_beaming";
    case "hit":
      return "face_dizzy";
    case "waiting":
      return "face_worried";
    case "results":
      if (players === 1)
        return place === 1 ? "face_slightly_smiling" : "face_disappointed";
      return place >= 1 && place <= 3 ? "face_mischievous" : "face_disappointed";
    default:
      return "face_slightly_smiling";
  }
}
function resultText(result) {
  if (!result)
    return ["Race over", ""];
  if (result.dnf)
    return ["Did not finish", ""];
  const place = `${ordinal(result.place)} place`;
  if (!result.finished)
    return [place, `Reached ${Math.floor(result.distance)} m`];
  const seconds = result.finish_msec / 1e3;
  const hundredths = String(Math.floor(result.finish_msec % 1e3 / 10)).padStart(2, "0");
  return [place, `Time ${clockText(Math.floor(seconds))}.${hundredths}`];
}
var FlappyRacePhone = class {
  surface;
  send;
  loadView;
  race;
  presentation;
  courseKey = "";
  generation = 0;
  request = 0;
  previous = 0;
  hud;
  viewCanvas;
  fallbackCanvas;
  results;
  constructor(surface, send, loadView) {
    this.surface = surface;
    this.send = send;
    this.loadView = loadView;
    this.hud = new FlappyRaceHud(surface);
    this.viewCanvas = surface.querySelector(".flappy-view");
    this.fallbackCanvas = surface.querySelector(".flappy-fallback");
    this.results = surface.querySelector(".flappy-results");
    surface.addEventListener("pointerdown", (event) => {
      if (event.pointerType === "mouse" && event.button !== 0)
        return;
      if (this.tap(performance.now()))
        event.preventDefault();
    });
  }
  show() {
    this.surface.hidden = false;
    if (!this.request)
      this.request = requestAnimationFrame(this.frame);
  }
  hide() {
    this.generation++;
    if (this.request)
      cancelAnimationFrame(this.request);
    this.request = 0;
    this.previous = 0;
    this.presentation?.dispose();
    this.presentation = void 0;
    this.courseKey = "";
    this.race = void 0;
    this.hud.clear();
    this.surface.hidden = true;
  }
  receive(message) {
    const now = performance.now();
    if (isSnapshot2(message)) {
      this.start(message, now);
      return;
    }
    const race = this.race;
    if (!race)
      return;
    if (isState(message))
      race.clock.observe(message.clock_tick, now);
    const own = message.own;
    if (own) {
      race.prediction.confirm(message.tick, this.settledFrom(race.snapshot, own.flight));
      race.place = own.place;
    }
    if (isEvent(message) && message.event === "finish" && message.place)
      race.place = message.place;
  }
  /** A touch-down: one flap at the next tick, sent to the host with that tick. */
  tap(now) {
    const race = this.race;
    if (!race || this.surface.hidden || race.snapshot.phase === "results")
      return false;
    if (race.clock.tick(now) < 0 || race.prediction.finished || !race.snapshot.own.connected)
      return false;
    const tick = race.prediction.tap();
    race.seq += 1;
    this.send({ type: "flappy_tap", seq: race.seq, tick });
    return true;
  }
  start(snapshot, now) {
    const flight = new FlappyFlight(snapshot.flight, snapshot.course.flight);
    const clock = new RaceClock();
    clock.observe(snapshot.clock_tick, now);
    const state = this.settledFrom(snapshot, snapshot.own.flight);
    const previous = this.race;
    this.race = {
      snapshot,
      clock,
      prediction: new FlappyPrediction(flight, state, snapshot.tick),
      seq: Math.max(snapshot.own.last_seq, previous?.seq ?? -1),
      place: snapshot.own.place,
      ownResult: snapshot.own_result,
      wasFlying: state.flying,
      hitAt: Number.NEGATIVE_INFINITY,
      hitX: state.x,
      hitY: state.y,
      heartSpent: false,
      takenCount: state.taken.reduce((sum, taken) => sum + taken, 0),
      pickupAt: Number.NEGATIVE_INFINITY,
      tilt: 0,
      focusX: state.x
    };
    const results = snapshot.phase === "results";
    this.results.hidden = !results;
    if (results) {
      const [title, detail] = resultText(snapshot.own_result);
      this.results.querySelector(".flappy-result-place").textContent = title;
      this.results.querySelector(".flappy-result-detail").textContent = detail;
    }
    const flightCourse = snapshot.course.flight;
    const key = JSON.stringify([
      flightCourse.finish_x,
      flightCourse.obstacles,
      snapshot.character_color
    ]);
    if (key !== this.courseKey)
      this.mount(key, snapshot);
    this.show();
  }
  mount(key, snapshot) {
    const generation = ++this.generation;
    this.courseKey = key;
    this.presentation?.dispose();
    const setup = {
      course: snapshot.course,
      color: `#${snapshot.character_color.replace(/^#/, "")}`,
      focusShare: snapshot.view.phone_cubio_screen_share
    };
    this.viewCanvas.hidden = true;
    this.fallbackCanvas.hidden = false;
    this.presentation = createFallbackView(this.fallbackCanvas, setup);
    void this.loadView().then((module) => module.createFlappyRaceView(this.viewCanvas, setup)).then((presentation) => {
      if (generation !== this.generation) {
        presentation.dispose();
        return;
      }
      this.presentation?.dispose();
      this.presentation = presentation;
      this.fallbackCanvas.hidden = true;
      this.viewCanvas.hidden = false;
    }, () => {
    });
  }
  settledFrom(snapshot, flight) {
    return flightState(flight, snapshot.flight, snapshot.course.flight.pickups.length);
  }
  frame = (now) => {
    this.request = requestAnimationFrame(this.frame);
    const race = this.race;
    const presentation = this.presentation;
    const delta = this.previous ? Math.min(0.1, (now - this.previous) / 1e3) : 0;
    this.previous = now;
    if (!race || !presentation || document.hidden)
      return;
    const { snapshot, prediction } = race;
    const view = snapshot.view;
    const clockTick = race.clock.tick(now);
    const events = snapshot.phase !== "results" ? prediction.advanceTo(clockTick) : 0;
    prediction.blend(delta, view.correction_seconds);
    const state = prediction.state;
    let gesture;
    if (events & EVENT_FLAP)
      gesture = "flap";
    if (events & EVENT_RESPAWN || !race.wasFlying && state.flying)
      gesture = "respawn";
    if (race.wasFlying && !state.flying) {
      gesture = "hit";
      race.hitAt = now;
      race.heartSpent = !state.hearts.owed;
      if (race.heartSpent) {
        const to = presentation.project(state.x, state.y);
        this.hud.flyHeart(state.hearts.full, to, view.heart_flight_seconds);
      }
    }
    if (state.flying) {
      race.hitX = prediction.drawnX;
      race.hitY = prediction.drawnY;
    }
    race.wasFlying = state.flying;
    const taken = state.taken.reduce((sum, value) => sum + value, 0);
    if (taken > race.takenCount)
      race.pickupAt = now;
    race.takenCount = taken;
    const sinceHit = (now - race.hitAt) / 1e3;
    const tumbling = !state.flying && sinceHit < view.hit_tumble_seconds;
    const results = snapshot.phase === "results";
    let face2 = faceFor("flying");
    if (results)
      face2 = faceFor("results", snapshot.own_result?.place ?? 0, snapshot.player_count);
    else if (clockTick < 0)
      face2 = faceFor("countdown");
    else if (tumbling)
      face2 = faceFor("hit");
    else if (!state.flying)
      face2 = faceFor("waiting");
    else if ((now - race.pickupAt) / 1e3 < view.pickup_face_seconds)
      face2 = faceFor("pickup");
    const tuning = snapshot.flight;
    const speed = state.verticalSpeed;
    const target = speed >= 0 ? Math.min(1, speed / tuning.flap_velocity) * view.tilt_up_degrees * Math.PI / 180 : -Math.min(1, -speed / tuning.max_fall_speed) * view.tilt_down_degrees * Math.PI / 180;
    const follow = view.tilt_response_seconds > 0 ? 1 - Math.exp(-delta / view.tilt_response_seconds) : 1;
    race.tilt += (target - race.tilt) * follow;
    const focusTarget = state.flying ? prediction.drawnX : tumbling ? race.hitX : state.x;
    race.focusX = state.flying ? focusTarget : race.focusX + (focusTarget - race.focusX) * (1 - Math.exp(-delta / FOCUS_SECONDS));
    presentation.draw({
      delta,
      focusX: race.focusX,
      cubioX: tumbling ? race.hitX : prediction.drawnX,
      cubioY: tumbling ? race.hitY : prediction.drawnY,
      tilt: tumbling ? -sinceHit * TUMBLE_TURNS * Math.PI * 2 : race.tilt,
      cubioVisible: state.flying || tumbling || state.ready,
      face: face2,
      gesture,
      hitSeconds: view.hit_tumble_seconds,
      tumbling,
      idle: !state.flying && !tumbling || results || clockTick < 0,
      taken: state.taken
    });
    const heartLanded = !race.heartSpent || sinceHit >= view.heart_flight_seconds;
    let floating;
    if (!state.flying && heartLanded && !results)
      floating = {
        at: presentation.project(state.x, state.y),
        state: state.hearts.owed ? "owed" : state.ready ? "ready" : "cooling",
        refillShare: state.hearts.refillShare()
      };
    let cue = "";
    if (clockTick < 0)
      cue = String(Math.max(1, Math.ceil(race.clock.untilGo(now) / 1e3)));
    else if (clockTick < GO_SECONDS * snapshot.tick_rate)
      cue = "GO!";
    if (prediction.finished && !results)
      cue = race.place > 0 ? `You finished ${ordinal(race.place)}!` : "Finished!";
    const ticksLeft = snapshot.race_ticks - Math.max(0, clockTick);
    this.hud.update({
      hearts: {
        count: tuning.heart_count,
        full: state.hearts.full,
        refillShare: state.hearts.refillShare()
      },
      progress: prediction.drawnX / snapshot.course.flight.finish_x,
      secondsLeft: ticksLeft / snapshot.tick_rate,
      lastSeconds: clockTick >= snapshot.last_seconds_tick,
      cue: results ? "" : cue,
      floating
    });
    const data = this.surface.dataset;
    data.phase = results ? "results" : clockTick < 0 ? "countdown" : "racing";
    data.tick = String(prediction.tick);
    data.flying = String(state.flying);
    data.ready = String(state.ready);
    data.rising = String(state.verticalSpeed > 0);
    data.corrections = String(prediction.corrections);
  };
};

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
    return this.send({ type: "motion_calibrate", ...context }, false);
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
  // Streamed messages yield to queued bytes because the next one replaces them. A click is sent
  // once, so queued bytes must not swallow it.
  send(payload, streamed = true) {
    const socket2 = this.connection();
    if (!this.subscription || socket2?.readyState !== WebSocket.OPEN || streamed && socket2.bufferedAmount > this.maximumBufferedBytes)
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

// build/character_preview.js
var JoinCharacterPreview = class {
  canvases;
  load;
  canvas;
  view;
  generation = 0;
  color = "#1E88E5";
  loading;
  constructor(canvases, load) {
    this.canvases = canvases;
    this.load = load;
    const observer = new MutationObserver(() => this.refresh(this.color));
    for (const canvas of canvases) {
      const section = canvas.closest("section");
      if (section)
        observer.observe(section, { attributes: true, attributeFilter: ["hidden"] });
    }
    document.addEventListener("visibilitychange", () => this.refresh(this.color));
    window.addEventListener("pagehide", () => this.clear());
    window.addEventListener("pageshow", () => this.refresh(this.color));
  }
  refresh(color) {
    this.color = color;
    const canvas = document.hidden ? void 0 : this.canvases.find((candidate) => !candidate.closest("section")?.hidden);
    if (canvas === this.canvas) {
      this.view?.setColor(color);
      return;
    }
    this.clear();
    if (!canvas)
      return;
    this.canvas = canvas;
    this.loading = new AbortController();
    canvas.dataset.preview = "loading";
    void this.activate(canvas, this.generation);
  }
  clear() {
    this.generation++;
    this.loading?.abort();
    this.loading = void 0;
    this.view?.dispose();
    this.view = void 0;
    if (this.canvas)
      this.canvas.dataset.preview = "idle";
    this.canvas = void 0;
  }
  async activate(canvas, generation) {
    try {
      const module = await this.load();
      if (generation !== this.generation)
        return;
      const view = await module.createCharacterPreview(canvas, this.loading?.signal);
      if (generation !== this.generation) {
        view.dispose();
        return;
      }
      this.view = view;
      view.setColor(this.color);
      canvas.dataset.preview = "ready";
    } catch {
      if (generation === this.generation)
        canvas.dataset.preview = "unavailable";
    }
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
var CHARACTER_SHAPE = "cubio";
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
var lobbyControls = new LobbyControls(lobbyController, lobbyStickZone, lobbyJumpButton, (action) => {
  if (!joined || !socket || socket.readyState !== WebSocket.OPEN || activeGame !== null)
    return;
  inputSeq += 1;
  store(STORAGE.inputSeq, String(inputSeq));
  socket.send(JSON.stringify({ ...action, input_seq: inputSeq }));
});
var gameplayMotion = new MotionStream(() => socket);
window.addEventListener("pageshow", (event) => {
  if (event.persisted && activeGame === "tilt_shift_3d")
    socket?.close();
});
var tilt3DSurface = document.querySelector("#tilt-shift-3d");
var tilt3DPhone = new TiltShift3DPhone(tilt3DSurface, gameplayMotion, (ready, context) => {
  if (socket?.readyState === WebSocket.OPEN)
    socket.send(JSON.stringify(context ? { type: "tilt_shift_3d_ready", ready, ...context } : { type: "pre_minigame_ready", ready }));
}, () => loadThreeView());
gameplayMotion.onControlState = () => {
  tilt3DPhone.feedback();
};
var motionLab = new MotionLabController(motionPanel, motionButton, motionReadings, () => socket);
var pwa = new PwaOnboarding(document.querySelector("#app-screen"), document.querySelector("#install-button"), document.querySelector("#install-guidance"), document.querySelector("#browser-button"), () => {
  selectionScreen.hidden = false;
  nextButton.focus();
  void requestImmersiveMode();
});
var bubble3DCard = document.querySelector("#bubbles-3d-card");
var flappyRaceSurface = document.querySelector("#flappy-race");
var flappyRacePhone = new FlappyRacePhone(flappyRaceSurface, (message) => {
  if (socket?.readyState === WebSocket.OPEN)
    socket.send(JSON.stringify(message));
}, () => loadThreeView());
var threeView;
function loadThreeView() {
  const url = "/three_view.js";
  threeView ??= import(url).catch((error) => {
    threeView = void 0;
    throw error;
  });
  return threeView;
}
var joinPreview = new JoinCharacterPreview([selectionPreview, namePreview], loadThreeView);
var bubble3DPhone = new BubblePhone(bubble3DCard, document.querySelector("#bubbles-3d-visual"), document.querySelector("#bubbles-3d-score"), document.querySelector("#bubbles-3d-fallback"), () => socket?.readyState === WebSocket.OPEN, () => {
  inputSeq += 1;
  store(STORAGE.inputSeq, String(inputSeq));
  return inputSeq;
}, (message) => {
  if (socket?.readyState === WebSocket.OPEN)
    socket.send(JSON.stringify(message));
}, () => loadThreeView());
protectControllerSurface(bubble3DCard);
function showBubble3D(message) {
  if (!isSnapshot(message)) {
    bubble3DPhone.receive(message);
    return;
  }
  gameplayMotion.stop();
  motionLab.stop();
  lobbyControls.deactivate();
  const visible = message.phase !== "lobby_return";
  setGameplaySurface(visible, "bubbles_3d");
  selectionScreen.hidden = nameScreen.hidden = joinForm.hidden = playerCard.hidden = true;
  readyCard.hidden = true;
  document.documentElement.classList.remove("ready-active");
  status.hidden = true;
  bubble3DPhone.receive(message);
}
for (const surface of [lobbyController, readyCard, tilt3DSurface, flappyRaceSurface])
  protectControllerSurface(surface);
bindControllerLifecycle(() => {
});
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
  return `${color} Cubio`;
}
function refreshSelectionUi() {
  const label = selectedCharacterName();
  selectedCharacterLabel.textContent = label;
  selectionPreview.setAttribute("aria-label", `${label} Shape Character`);
  namePreview.setAttribute("aria-label", `${label} character preview`);
  for (const button of Array.from(colorGrid.querySelectorAll(".color-button"))) {
    button.setAttribute("aria-pressed", String(button.dataset.color === joinFlow.color));
  }
  joinPreview.refresh(joinFlow.color);
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
function setGameplaySurface(active, game) {
  const next = active ? game ?? null : null;
  if (next !== "tilt_shift_3d")
    tilt3DPhone.hide();
  if (next !== "bubbles_3d")
    bubble3DPhone.hide();
  if (next !== "flappy_race")
    flappyRacePhone.hide();
  if (activeGame !== next) {
    if (next === null) {
      try {
        screen.orientation?.unlock?.();
      } catch {
      }
    } else if (document.fullscreenElement) {
      try {
        const orientation = screen.orientation;
        const direction = next === "tilt_shift_3d" ? "landscape" : "portrait";
        void Promise.resolve(orientation?.lock?.(direction)).catch(() => {
        });
      } catch {
      }
    }
    activeGame = next;
  }
  document.documentElement.classList.toggle("gameplay-active", next !== null);
  document.documentElement.classList.toggle("bubbles-3d-active", next === "bubbles_3d");
  document.documentElement.classList.toggle("tilt-3d-active", next === "tilt_shift_3d");
  document.documentElement.classList.toggle("flappy-race-active", next === "flappy_race");
}
function showJoin(message, focus = false) {
  gameplayMotion.stop();
  motionLab.stop();
  lobbyControls.deactivate();
  readyCard.hidden = true;
  document.documentElement.classList.remove("ready-active");
  joinFlow = returnToCharacterSelection(joinFlow);
  joined = false;
  setGameplaySurface(false);
  playerCard.hidden = true;
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
  setGameplaySurface(false);
  selectionScreen.hidden = true;
  nameScreen.hidden = true;
  joinForm.hidden = true;
  playerCard.hidden = true;
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
  if (message.minigame_id === "tilt_shift_3d" && message.preparation) {
    showTiltSurface();
    tilt3DPhone.preparation(message.preparation, message.ready === true);
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
  setGameplaySurface(true, "tilt_shift_3d");
  selectionScreen.hidden = nameScreen.hidden = joinForm.hidden = playerCard.hidden = true;
  readyCard.hidden = true;
  document.documentElement.classList.remove("ready-active");
  status.hidden = true;
}
function showFlappyRace(message) {
  if (!isSnapshot2(message))
    return;
  gameplayMotion.stop();
  motionLab.stop();
  lobbyControls.deactivate();
  setGameplaySurface(true, "flappy_race");
  selectionScreen.hidden = nameScreen.hidden = joinForm.hidden = playerCard.hidden = true;
  readyCard.hidden = true;
  document.documentElement.classList.remove("ready-active");
  status.hidden = true;
  flappyRacePhone.receive(message);
}
function showTilt3D(message) {
  if (tilt3DPhone.snapshot(message))
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
      if (message.type === "lobby" || message.type?.endsWith("_snapshot") && !isSnapshot(message)) {
        if (activeGame === "bubbles_3d")
          setGameplaySurface(false);
      }
      if (message.type === "welcome" && message.protocol === 1 && Number.isInteger(message.connection_id)) {
        stage = "Connected WebSocket";
        connectionError.hidden = true;
        connectionError.textContent = "";
        clearTimeout(deadline);
        if (message.resume_status === "resumed" && rememberIdentity(message)) {
          if (isSnapshot(message.gameplay))
            showBubble3D(message.gameplay);
          else if (message.gameplay?.type === "tilt_shift_3d_snapshot")
            showTilt3D(message.gameplay);
          else if (isSnapshot2(message.gameplay))
            showFlappyRace(message.gameplay);
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
      } else if (isSnapshot(message) || message.type === "bubbles_3d_visual" || message.type === "bubbles_3d_release_result")
        showBubble3D(message);
      else if (message.type === "pre_minigame_snapshot")
        showReady(message);
      else if (message.type === "tilt_shift_3d_snapshot")
        showTilt3D(message);
      else if (isSnapshot2(message))
        showFlappyRace(message);
      else if (isState(message) || isEvent(message))
        flappyRacePhone.receive(message);
      else if (message.type === "motion_lab" && joined && typeof message.subscription_id === "string" && typeof message.send_hz === "number") {
        lobbyControls.deactivate();
        setGameplaySurface(false);
        document.documentElement.classList.remove("ready-active");
        selectionScreen.hidden = nameScreen.hidden = joinForm.hidden = playerCard.hidden = readyCard.hidden = true;
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
        tilt3DPhone.feedback();
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
      if (activeGame === "tilt_shift_3d")
        tilt3DPhone.disconnect();
      else
        setGameplaySurface(false);
      if (socket === peer)
        socket = void 0;
      if (event.code === 4e3) {
        stopped = true;
        leaveButton.disabled = true;
        readyCard.hidden = true;
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
