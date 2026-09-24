import { attemptImmersive, chargedColor, directionAtPoint, heldDirectionAfterUpdate, type Direction } from "./controller_geometry.js";
import { GestureTrace, type Point } from "./bubbles_gesture.js";
import {
  advanceJoinFlow, bodyAssetPath, CHARACTER_COLORS, CHARACTER_SHAPES, chooseJoinColor,
  colorOption, createJoinMessage, cycleJoinShape, defaultJoinFlow, FALLBACK_CHARACTER,
  isCharacterShape, returnToCharacterSelection, type CharacterShape, type JoinFlowState,
} from "./character_selection.js";

const status = document.querySelector<HTMLElement>("#status")!;
const selectionScreen = document.querySelector<HTMLElement>("#selection-screen")!;
const previousShapeButton = document.querySelector<HTMLButtonElement>("#previous-shape")!;
const nextShapeButton = document.querySelector<HTMLButtonElement>("#next-shape")!;
const selectionPreview = document.querySelector<HTMLCanvasElement>("#selection-preview")!;
const namePreview = document.querySelector<HTMLCanvasElement>("#name-preview")!;
const selectedCharacterLabel = document.querySelector<HTMLElement>("#selected-character-label")!;
const colorGrid = document.querySelector<HTMLElement>("#color-grid")!;
const nextButton = document.querySelector<HTMLButtonElement>("#next-button")!;
const backButton = document.querySelector<HTMLButtonElement>("#back-button")!;
const nameScreen = document.querySelector<HTMLElement>("#name-screen")!;
const joinForm = document.querySelector<HTMLFormElement>("#join-form")!;
const nameInput = document.querySelector<HTMLInputElement>("#player-name")!;
const joinButton = document.querySelector<HTMLButtonElement>("#join-button")!;
const playerCard = document.querySelector<HTMLElement>("#player-card")!;
const playerName = document.querySelector<HTMLElement>("#player-name-heading")!;
const playerState = document.querySelector<HTMLElement>("#player-state")!;
const leaveButton = document.querySelector<HTMLButtonElement>("#leave-button")!;
const gameCard = document.querySelector<HTMLElement>("#game-card")!;
const gameHeading = document.querySelector<HTMLElement>("#game-heading")!;
const gameMessage = document.querySelector<HTMLElement>("#game-message")!;
const lives = document.querySelector<HTMLElement>("#lives")!;
const poseGrid = document.querySelector<HTMLElement>("#pose-grid")!;
const rotateState = document.querySelector<HTMLElement>("#rotate-state")!;
const bubblesCard = document.querySelector<HTMLElement>("#bubbles-card")!;
const bubblesPad = document.querySelector<HTMLElement>("#bubbles-pad")!;
const bubblesScore = document.querySelector<HTMLElement>("#bubbles-score")!;
const bubblesCanvas = document.querySelector<HTMLCanvasElement>("#bubbles-visual")!;
const bubblesContext = bubblesCanvas.getContext("2d", { alpha: true })!;

const STORAGE = { session: "play-shapes.session-id", token: "play-shapes.reconnect-token", name: "play-shapes.last-name", inputSeq: "play-shapes.input-seq" } as const;
type PublicPlayer = { player_id: string; name: string; seat: number; state: string; character_shape?: string; character_color?: string };
type GameplayPlayer = { lives?: number; eliminated?: boolean; direction?: string; charge?: number; held?: boolean; character_shape?: string; character_color?: string };
type Presentation = { colors?: Partial<Record<Direction, string>>; minimum_brightness?: number; maximum_brightness?: number; charge_fill_seconds?: number; charge_decay_seconds?: number };
type BubblesVisualSnapshot = { host_time_msec: number; radius: number; pull: Point; drag_pull: Point; charge_pull: Point; surface_angle: number; spinning: boolean; recovery_white: boolean; burst_progress: number; particle_density: number; charge_glow: number; character_visible: boolean; character_scale: number; character_position: Point; body_rotation: number; face_position: Point; face_blink: boolean; left_hand_position: Point; right_hand_position: Point; left_foot_position: Point; right_foot_position: Point };
type BubblesVisualTuning = { starting_radius?: number; live_drag_pull_strength?: number; live_drag_response_seconds?: number; charge_wobble_strength?: number; charge_glow_strength?: number; swipe_reaction_seconds?: number; spin_surface_turns_per_second?: number; bubble_reform_seconds?: number; burst_seconds?: number };
type HostMessage = { type?: string; protocol?: number; connection_id?: number; session_id?: string; resume_status?: string; reconnect_token?: string; player?: PublicPlayer | GameplayPlayer; code?: string; message?: string; phase?: string; available_directions?: string[]; success?: boolean; lives?: number; debug_mode?: boolean; eliminated?: boolean; placement?: number; state?: string; gameplay?: HostMessage; presentation?: Presentation; direction?: string; charge?: number; held?: boolean; score?: number; bubble_radius?: number; burst_radius?: number; visual_jellyfish?: number; visual_cap?: number; seat?: number; left?: boolean; character_shape?: string; character_color?: string; host_time_msec?: number; visual_tuning?: BubblesVisualTuning; visual?: BubblesVisualSnapshot; spin_remaining_msec?: number; cooldown_remaining_msec?: number; invulnerable_remaining_msec?: number; reform_remaining_msec?: number; spin_duration_msec?: number; cooldown_duration_msec?: number; circles_to_charge?: number; rank?: number; event?: string; lost?: number; action?: string; reason?: string };

const POSES: ReadonlyArray<{ direction: Direction; icon: string; label: string }> = [
  { direction: "left", icon: "←", label: "Pose left" }, { direction: "right", icon: "→", label: "Pose right" },
  { direction: "down", icon: "↓", label: "Pose down" }, { direction: "up", icon: "↑", label: "Pose up" },
];
const DEFAULT_COLORS: Record<Direction, string> = { left: "#48d16f", right: "#f04f55", down: "#f4c542", up: "#3489eb" };

let socket: WebSocket | undefined;
let retry: ReturnType<typeof setTimeout> | undefined;
let stopped = false;
let joined = false;
let joinFlow: JoinFlowState = defaultJoinFlow();
let inputSeq = Number.parseInt(stored(STORAGE.inputSeq), 10) || 0;
let held: { direction: Direction; pointerId?: number; button: HTMLButtonElement } | undefined;
let directions: Direction[] = [];
let presentation = { colors: DEFAULT_COLORS, minimum_brightness: 0.42, maximum_brightness: 1, charge_fill_seconds: 1, charge_decay_seconds: 0.28 };
let visualCharge: Record<Direction, number> = { left: 0, right: 0, down: 0, up: 0 };
let authoritativeDirection: Direction | undefined;
let authoritativeCharge = 0;
let authoritativeHeld = false;
let lastAnimationTime = performance.now();
let fullscreenAttempted = { flash: false, bubbles: false };
let activeGame: "flash" | "bubbles" | null = null;
let bubblesPointer: { id: number; trace: GestureTrace; seq: number; step: number; drag: Point; sentDrag: Point; lastMotionAt: number; motionCount: number } | undefined;
let bubblesSnapshot: HostMessage | undefined;
let bubblesSnapshotTime = 0;
let bubblesLocalCharge = 0;
let bubblesVisualSnapshot: BubblesVisualSnapshot | undefined;
let bubblesVisualReceivedAt = 0;
let bubblesPhoneDragDisplay: Point = [0, 0];
let bubblesPreviousFrame = performance.now();
const characterBodies = Object.fromEntries(CHARACTER_SHAPES.map(shape => [shape, new Image()])) as Record<CharacterShape, HTMLImageElement>;
for (const shape of CHARACTER_SHAPES) characterBodies[shape].src = bodyAssetPath(shape);
const bubblesArt = {
  hand: new Image(), foot: new Image(), face: new Image(), blink: new Image(), jellyfish: new Image(),
};
bubblesArt.hand.src = "/bubbles-player-hand.png";
bubblesArt.foot.src = "/bubbles-player-foot.png";
bubblesArt.face.src = "/bubbles-player-face-neutral.png";
bubblesArt.blink.src = "/bubbles-player-face-blink.png";
bubblesArt.jellyfish.src = "/bubbles-jellyfish.png";
const bubblesTintCache = new Map<string, HTMLCanvasElement>();

function stored(key: string): string { try { return localStorage.getItem(key) ?? ""; } catch { return ""; } }
function store(key: string, value: string): void { try { localStorage.setItem(key, value); } catch { /* Page remains usable. */ } }
function forgetIdentity(): void { try { localStorage.removeItem(STORAGE.session); localStorage.removeItem(STORAGE.token); localStorage.removeItem(STORAGE.inputSeq); } catch { /* Restricted storage. */ } inputSeq = 0; }

function selectedCharacterName(): string {
  const shape = joinFlow.shape[0].toUpperCase() + joinFlow.shape.slice(1);
  const color = colorOption(joinFlow.color)?.name ?? "Blue";
  return `${shape} · ${color}`;
}

function refreshSelectionUi(): void {
  const label = selectedCharacterName();
  selectedCharacterLabel.textContent = label;
  selectionPreview.setAttribute("aria-label", `${label} Shape Character`);
  namePreview.setAttribute("aria-label", `${label} character dancing`);
  for (const button of Array.from(colorGrid.querySelectorAll<HTMLButtonElement>(".color-button"))) {
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
  button.addEventListener("click", () => { joinFlow = chooseJoinColor(joinFlow, option.hex); refreshSelectionUi(); });
  colorGrid.append(button);
}
refreshSelectionUi();

function setGameplaySurface(active: boolean, mode: "flash" | "bubbles" = "flash"): void {
  const next = active ? mode : null;
  if (activeGame !== next) {
    cancelBubblesPointer();
    if (next === null) { try { screen.orientation?.unlock?.(); } catch { /* Unsupported orientation API. */ } }
    else if (document.fullscreenElement) { try { const orientation = screen.orientation as ScreenOrientation & { lock?: (value: string) => Promise<void> }; void Promise.resolve(orientation?.lock?.(next === "flash" ? "landscape" : "portrait")).catch(() => {}); } catch { /* Lock denied. */ } }
    activeGame = next;
  }
  document.documentElement.classList.toggle("gameplay-active", active);
  document.documentElement.classList.toggle("bubbles-active", next === "bubbles");
  updateOrientation();
}
function updateOrientation(): void {
  const portrait = matchMedia("(orientation: portrait)").matches;
  rotateState.hidden = !(activeGame === "flash" && portrait);
  poseGrid.hidden = activeGame !== "flash" || portrait;
}

function showJoin(message: string, focus = false): void {
  joinFlow = returnToCharacterSelection(joinFlow);
  joined = false; bubblesSnapshot = undefined; bubblesVisualSnapshot = undefined; setGameplaySurface(false); playerCard.hidden = true; gameCard.hidden = true; bubblesCard.hidden = true;
  selectionScreen.hidden = false; nameScreen.hidden = true; joinForm.hidden = true; joinButton.disabled = false; leaveButton.disabled = false;
  status.textContent = message; status.hidden = !message; nameInput.value = stored(STORAGE.name); refreshSelectionUi();
  if (focus) queueMicrotask(() => nextButton.focus());
}
function showJoined(player: PublicPlayer, state = "Connected"): void {
  joined = true; bubblesSnapshot = undefined; bubblesVisualSnapshot = undefined; setGameplaySurface(false); selectionScreen.hidden = true; nameScreen.hidden = true; joinForm.hidden = true; playerCard.hidden = false; gameCard.hidden = true; bubblesCard.hidden = true; playerName.textContent = player.name; playerState.textContent = state; leaveButton.disabled = false;
  if (isCharacterShape(player.character_shape)) joinFlow = { ...joinFlow, shape: player.character_shape };
  const serverColor = colorOption(player.character_color)?.hex;
  if (serverColor) joinFlow = chooseJoinColor(joinFlow, serverColor);
  status.textContent = state === "Connected" ? "Joined. Keep this page open while you play." : state; status.hidden = true;
}

previousShapeButton.addEventListener("click", () => { joinFlow = cycleJoinShape(joinFlow, -1); refreshSelectionUi(); });
nextShapeButton.addEventListener("click", () => { joinFlow = cycleJoinShape(joinFlow, 1); refreshSelectionUi(); });
nextButton.addEventListener("click", () => {
  joinFlow = advanceJoinFlow(joinFlow);
  selectionScreen.hidden = true; nameScreen.hidden = false; joinForm.hidden = false;
  if (!nameInput.value) nameInput.value = stored(STORAGE.name);
  status.hidden = true; status.textContent = ""; refreshSelectionUi();
  queueMicrotask(() => nameInput.focus());
});
backButton.addEventListener("click", () => {
  joinFlow = returnToCharacterSelection(joinFlow);
  nameScreen.hidden = true; joinForm.hidden = true; selectionScreen.hidden = false;
  status.hidden = true; status.textContent = ""; refreshSelectionUi();
  queueMicrotask(() => nextButton.focus());
});
function sendPose(type: "pose_down" | "pose_up", direction: Direction): void { if (!socket || socket.readyState !== WebSocket.OPEN) return; inputSeq += 1; store(STORAGE.inputSeq, String(inputSeq)); socket.send(JSON.stringify({ type, direction, input_seq: inputSeq })); }
function releaseHeld(send = true): void {
  if (!held) return; const current = held; held = undefined; current.button.classList.remove("is-held"); current.button.setAttribute("aria-pressed", "false");
  if (current.pointerId !== undefined && poseGrid.hasPointerCapture(current.pointerId)) poseGrid.releasePointerCapture(current.pointerId);
  if (send) sendPose("pose_up", current.direction);
}
function beginHold(direction: Direction, button: HTMLButtonElement, pointerId?: number): void {
  if (held?.direction === direction) return; releaseHeld(); held = { direction, button, ...(pointerId === undefined ? {} : { pointerId }) };
  if (pointerId !== undefined) poseGrid.setPointerCapture(pointerId); button.classList.add("is-held"); button.setAttribute("aria-pressed", "true");
  visualCharge[direction] = 0; authoritativeDirection = direction; authoritativeCharge = 0; authoritativeHeld = true; sendPose("pose_down", direction); void requestImmersiveMode("flash");
}
function readPresentation(value?: Presentation): void {
  if (!value) return;
  presentation = { colors: { ...DEFAULT_COLORS, ...(value.colors ?? {}) }, minimum_brightness: Number(value.minimum_brightness ?? presentation.minimum_brightness), maximum_brightness: Number(value.maximum_brightness ?? presentation.maximum_brightness), charge_fill_seconds: Math.max(0.1, Number(value.charge_fill_seconds ?? presentation.charge_fill_seconds)), charge_decay_seconds: Math.max(0.05, Number(value.charge_decay_seconds ?? presentation.charge_decay_seconds)) };
}

function renderControls(available: string[]): void {
  const desired = POSES.filter(item => available.includes(item.direction)).map(item => item.direction);
  if (held && heldDirectionAfterUpdate(held.direction, desired) === undefined) releaseHeld(); directions = desired;
  const existing = Array.from(poseGrid.querySelectorAll<HTMLButtonElement>(".pose-button"), button => button.dataset.direction);
  if (existing.length === desired.length && existing.every((value, index) => value === desired[index])) return;
  poseGrid.replaceChildren(); poseGrid.dataset.count = String(desired.length);
  for (const pose of POSES.filter(item => desired.includes(item.direction))) {
    const button = document.createElement("button"); button.type = "button"; button.className = "pose-button"; button.dataset.direction = pose.direction;
    button.setAttribute("aria-label", pose.label); button.setAttribute("aria-pressed", held?.direction === pose.direction ? "true" : "false"); button.innerHTML = `<span class="icon" aria-hidden="true">${pose.icon}</span>`;
    if (held?.direction === pose.direction) { held.button = button; button.classList.add("is-held"); }
    button.addEventListener("keydown", event => { if ((event.key !== " " && event.key !== "Enter") || event.repeat || held) return; event.preventDefault(); beginHold(pose.direction, button); });
    button.addEventListener("keyup", event => { if ((event.key === " " || event.key === "Enter") && held?.button === button) { event.preventDefault(); releaseHeld(); } });
    button.addEventListener("blur", () => { if (held?.button === button && held.pointerId === undefined) releaseHeld(); }); poseGrid.append(button);
  }
}

poseGrid.addEventListener("pointerdown", event => {
  event.preventDefault(); if (event.button !== 0 && event.pointerType === "mouse") return;
  const rect = poseGrid.getBoundingClientRect(); const direction = directionAtPoint(directions.length, event.clientX - rect.left, event.clientY - rect.top, rect.width, rect.height);
  const button = poseGrid.querySelector<HTMLButtonElement>(`[data-direction="${direction}"]`); if (button) beginHold(direction, button, event.pointerId);
});
poseGrid.addEventListener("pointerup", event => { event.preventDefault(); if (held?.pointerId === event.pointerId) releaseHeld(); });
poseGrid.addEventListener("pointercancel", event => { if (held?.pointerId === event.pointerId) releaseHeld(); });
poseGrid.addEventListener("lostpointercapture", event => { if (held?.pointerId === event.pointerId) releaseHeld(); });
poseGrid.addEventListener("contextmenu", event => event.preventDefault()); poseGrid.addEventListener("selectstart", event => event.preventDefault());

async function requestImmersiveMode(mode: "flash" | "bubbles"): Promise<void> {
  if (fullscreenAttempted[mode]) return; fullscreenAttempted[mode] = true;
  const root = document.documentElement as HTMLElement & { webkitRequestFullscreen?: () => Promise<void> | void };
  const orientation = screen.orientation as ScreenOrientation & { lock?: (value: string) => Promise<void> };
  const fullscreen = root.requestFullscreen ? () => root.requestFullscreen({ navigationUI: "hide" }) : root.webkitRequestFullscreen?.bind(root);
  await attemptImmersive(fullscreen, orientation?.lock ? () => orientation.lock!(mode === "flash" ? "landscape" : "portrait") : undefined);
}
function updateCharge(message: HostMessage | GameplayPlayer): void {
  authoritativeDirection = POSES.some(item => item.direction === message.direction) ? message.direction as Direction : undefined;
  authoritativeCharge = Math.min(1, Math.max(0, Number(message.charge ?? 0))); authoritativeHeld = message.held === true;
}
function animate(now: number): void {
  const delta = Math.min(0.1, Math.max(0, (now - lastAnimationTime) / 1000)); lastAnimationTime = now;
  for (const direction of directions) {
    const locallyHeld = held?.direction === direction; const hostDirection = authoritativeDirection === direction; let target = hostDirection ? authoritativeCharge : 0;
    if (locallyHeld && authoritativeHeld) target = Math.max(target, visualCharge[direction] + delta / presentation.charge_fill_seconds);
    const rate = (locallyHeld || (hostDirection && authoritativeHeld)) ? 1 / presentation.charge_fill_seconds : 1 / presentation.charge_decay_seconds;
    const step = rate * delta; visualCharge[direction] += Math.max(-step, Math.min(step, target - visualCharge[direction]));
    const button = poseGrid.querySelector<HTMLElement>(`[data-direction="${direction}"]`);
    if (button) button.style.backgroundColor = chargedColor(presentation.colors[direction] ?? DEFAULT_COLORS[direction], presentation.minimum_brightness, presentation.maximum_brightness, visualCharge[direction]);
  }
  if (bubblesPointer && bubblesPointer.motionCount < 48 && activeGame === "bubbles" && socket?.readyState === WebSocket.OPEN) {
    const changed = bubblesPointer.drag[0] !== bubblesPointer.sentDrag[0] || bubblesPointer.drag[1] !== bubblesPointer.sentDrag[1];
    if (now - bubblesPointer.lastMotionAt >= (changed ? 70 : 600)) sendBubblesMotion(bubblesPointer, now);
  }
  requestAnimationFrame(animate);
}
requestAnimationFrame(animate);

function sendBubblesCharge(seq: number, stage: "start" | "progress" | "cancel", step = 0): void {
  if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify({ type: "bubbles_charge", input_seq: seq, stage, step }));
}
function sendBubblesMotion(pointer: NonNullable<typeof bubblesPointer>, now: number): void {
  if (pointer.motionCount >= 48 || socket?.readyState !== WebSocket.OPEN) return;
  socket.send(JSON.stringify({ type: "bubbles_charge", input_seq: pointer.seq, stage: "motion", drag: pointer.drag }));
  pointer.sentDrag = [...pointer.drag]; pointer.lastMotionAt = now; pointer.motionCount += 1;
}
function cancelBubblesPointer(sendCancel = true): void {
  if (!bubblesPointer) return;
  const { id, seq } = bubblesPointer; bubblesPointer = undefined; bubblesLocalCharge = 0;
  bubblesPhoneDragDisplay = [0, 0];
  if (sendCancel) sendBubblesCharge(seq, "cancel");
  if (bubblesPad.hasPointerCapture(id)) bubblesPad.releasePointerCapture(id);
}
function sendBubblesTrace(trace: Point[], gestureSeq?: number): void {
  if (activeGame !== "bubbles" || bubblesSnapshot?.phase !== "active" || trace.length < 2 || !socket || socket.readyState !== WebSocket.OPEN) return;
  if (gestureSeq === undefined) { inputSeq += 1; store(STORAGE.inputSeq, String(inputSeq)); }
  socket.send(JSON.stringify({ type: "bubbles_trace", input_seq: gestureSeq ?? inputSeq, trace }));
}
function vibrate(pattern: number | number[]): void { try { navigator.vibrate?.(pattern); } catch { /* Best effort only. */ } }

bubblesPad.addEventListener("pointerdown", event => {
  if (activeGame !== "bubbles" || bubblesSnapshot?.phase !== "active" || bubblesPointer || (event.pointerType === "mouse" && event.button !== 0)) return;
  event.preventDefault();
  const trace = new GestureTrace(bubblesPad.getBoundingClientRect()); trace.add(event.clientX, event.clientY);
  inputSeq += 1; store(STORAGE.inputSeq, String(inputSeq));
  bubblesPhoneDragDisplay = [0, 0];
  bubblesPointer = { id: event.pointerId, trace, seq: inputSeq, step: 0, drag: [0, 0], sentDrag: [0, 0], lastMotionAt: performance.now(), motionCount: 0 };
  try { bubblesPad.setPointerCapture(event.pointerId); } catch { cancelBubblesPointer(); return; }
  sendBubblesCharge(inputSeq, "start");
  void requestImmersiveMode("bubbles");
});
bubblesPad.addEventListener("pointermove", event => {
  if (bubblesPointer?.id !== event.pointerId) return;
  event.preventDefault();
  for (const sample of event.getCoalescedEvents?.() ?? [event]) bubblesPointer.trace.add(sample.clientX, sample.clientY);
  bubblesLocalCharge = bubblesPointer.trace.preview(bubblesSnapshot?.circles_to_charge ?? 1);
  const step = Math.min(4, Math.floor(bubblesLocalCharge * 4));
  if (step > bubblesPointer.step) { bubblesPointer.step = step; sendBubblesCharge(bubblesPointer.seq, "progress", step); }
  const [dx, dy] = bubblesPointer.trace.displacement();
  const drag: Point = [Math.max(-4, Math.min(4, Math.round(dx * 10))), Math.max(-4, Math.min(4, Math.round(dy * 10)))];
  const now = performance.now();
  bubblesPointer.drag = drag;
  if ((drag[0] !== bubblesPointer.sentDrag[0] || drag[1] !== bubblesPointer.sentDrag[1]) && now - bubblesPointer.lastMotionAt >= 70) sendBubblesMotion(bubblesPointer, now);
});
bubblesPad.addEventListener("pointerup", event => {
  if (bubblesPointer?.id !== event.pointerId) return;
  event.preventDefault(); bubblesPointer.trace.add(event.clientX, event.clientY);
  const { seq } = bubblesPointer; const trace = bubblesPointer.trace.completed(); cancelBubblesPointer(false);
  if (trace.length < 2) sendBubblesCharge(seq, "cancel"); else sendBubblesTrace(trace, seq);
});
bubblesPad.addEventListener("pointercancel", event => { if (bubblesPointer?.id === event.pointerId) cancelBubblesPointer(); });
bubblesPad.addEventListener("lostpointercapture", event => { if (bubblesPointer?.id === event.pointerId) cancelBubblesPointer(); });
bubblesPad.addEventListener("contextmenu", event => event.preventDefault());
bubblesPad.addEventListener("keydown", event => {
  if (event.repeat || activeGame !== "bubbles" || bubblesSnapshot?.phase !== "active") return;
  const directions: Record<string, Point> = { ArrowLeft: [0.1, 0.5], ArrowRight: [0.9, 0.5], ArrowUp: [0.5, 0.1], ArrowDown: [0.5, 0.9] };
  if (directions[event.key]) { event.preventDefault(); sendBubblesTrace([[0.5, 0.5], directions[event.key]]); void requestImmersiveMode("bubbles"); }
  else if (event.key === " " || event.key === "Enter") {
    event.preventDefault(); const circles = Math.max(1, Math.min(3, bubblesSnapshot?.circles_to_charge ?? 1));
    const trace: Point[] = Array.from({ length: 97 }, (_, index) => [0.5 + 0.22 * Math.cos(index / 96 * Math.PI * 2 * circles), 0.5 + 0.22 * Math.sin(index / 96 * Math.PI * 2 * circles)]);
    sendBubblesTrace(trace); void requestImmersiveMode("bubbles");
  }
});

function showBubbles(message: HostMessage): void {
  releaseHeld(false);
  bubblesSnapshot = message;
  bubblesSnapshotTime = performance.now();
  gameCard.hidden = true; playerCard.hidden = true; bubblesCard.hidden = false;
  const phase = message.phase ?? "waiting";
  const active = phase === "results" || (["instructions", "countdown", "active"].includes(phase) && message.left !== true);
  setGameplaySurface(active, "bubbles");
  bubblesScore.textContent = String(Math.max(0, Math.floor(message.score ?? 0)));
  if (message.type === "bubbles_feedback") {
    if (message.event === "captured") vibrate(18);
    else if (message.event === "spin") vibrate([20, 30, 20]);
    else if (message.event === "pop") vibrate([35, 45, 35]);
  }
}

const BUBBLE_RIM_COLORS = ["#6eeaff", "#a785ff", "#ff8bce", "#ffdf9d", "#8af8c7"];

function clamp(value: number, minimum: number, maximum: number): number { return Math.min(maximum, Math.max(minimum, value)); }
function tuningValue(key: keyof BubblesVisualTuning, fallback: number): number {
  const value = bubblesSnapshot?.visual_tuning?.[key];
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}
function imageReady(image: HTMLImageElement): boolean { return image.complete && image.naturalWidth > 0; }
function tintedSprite(image: HTMLImageElement, color: string): HTMLCanvasElement | undefined {
  if (!imageReady(image)) return undefined;
  const key = `${image.src}|${color}`;
  const cached = bubblesTintCache.get(key);
  if (cached) return cached;
  const source = document.createElement("canvas");
  source.width = image.naturalWidth; source.height = image.naturalHeight;
  const sourceContext = source.getContext("2d", { willReadFrequently: true });
  if (!sourceContext) return undefined;
  sourceContext.drawImage(image, 0, 0);
  const pixels = sourceContext.getImageData(0, 0, source.width, source.height);
  const channels = color.replace("#", "").match(/.{2}/g)?.map(part => Number.parseInt(part, 16) / 255) ?? [0.35, 0.55, 0.95];
  const maximum = Math.max(...channels);
  const lift = clamp((0.4 - maximum) / 0.4, 0, 1);
  const base = channels.map(channel => channel * (1 - lift) + 0.55 * lift);
  const shadow = base.map(channel => channel * 0.78);
  const highlight = base.map(channel => channel + (1 - channel) * 0.38);
  const data = pixels.data;
  for (let offset = 0; offset < data.length; offset += 4) {
    const lightness = (data[offset] * 0.2126 + data[offset + 1] * 0.7152 + data[offset + 2] * 0.0722) / 255;
    const shade = clamp((lightness - 0.53) / 0.2, 0, 1);
    for (let channel = 0; channel < 3; channel++) data[offset + channel] = (shadow[channel] + (highlight[channel] - shadow[channel]) * shade) * 255;
  }
  sourceContext.putImageData(pixels, 0, 0);
  bubblesTintCache.set(key, source);
  return source;
}
function drawSprite(context: CanvasRenderingContext2D, image: HTMLImageElement, tint: string, x: number, y: number, width: number, height: number, flip = false, rotation = 0): void {
  const sprite = tintedSprite(image, tint);
  if (!sprite) return;
  context.save(); context.translate(x, y); context.rotate(rotation); if (flip) context.scale(-1, 1);
  context.drawImage(sprite, -width / 2, -height / 2, width, height); context.restore();
}
function drawUntintedSprite(context: CanvasRenderingContext2D, image: HTMLImageElement, x: number, y: number, width: number, height: number): void {
  if (!imageReady(image)) return;
  context.save(); context.translate(x, y); context.drawImage(image, -width / 2, -height / 2, width, height); context.restore();
}
type CharacterPose = { bodyRotation: number; facePosition: Point; faceBlink: boolean; leftHandPosition: Point; rightHandPosition: Point; leftFootPosition: Point; rightFootPosition: Point; leftHandRotation: number; rightHandRotation: number };
function drawCharacter(context: CanvasRenderingContext2D, shape: CharacterShape, tint: string, x: number, y: number, scale: number, pose: CharacterPose): void {
  context.save(); context.translate(x, y); context.scale(scale, scale);
  drawSprite(context, bubblesArt.foot, tint, pose.leftFootPosition[0], pose.leftFootPosition[1], 40, 24, true);
  drawSprite(context, bubblesArt.foot, tint, pose.rightFootPosition[0], pose.rightFootPosition[1], 40, 24);
  drawSprite(context, bubblesArt.hand, tint, pose.leftHandPosition[0], pose.leftHandPosition[1], 35, 34, true, pose.leftHandRotation);
  drawSprite(context, bubblesArt.hand, tint, pose.rightHandPosition[0], pose.rightHandPosition[1], 35, 34, false, pose.rightHandRotation);
  drawSprite(context, characterBodies[shape], tint, 0, 0, 80, 80, false, pose.bodyRotation);
  const face = pose.faceBlink ? bubblesArt.blink : bubblesArt.face;
  drawUntintedSprite(context, face, pose.facePosition[0], pose.facePosition[1], pose.faceBlink ? 53 : 50, pose.faceBlink ? 37 : 29);
  context.restore();
}
function renderJoinPreviews(now: number): void {
  const seconds = now / 1000;
  for (const canvas of [selectionPreview, namePreview]) {
    const section = canvas.closest("section");
    if (section?.hidden) continue;
    const rect = canvas.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) continue;
    const pixelRatio = Math.max(1, Math.min(3, window.devicePixelRatio || 1));
    const width = Math.max(1, Math.round(rect.width * pixelRatio));
    const height = Math.max(1, Math.round(rect.height * pixelRatio));
    if (canvas.width !== width || canvas.height !== height) { canvas.width = width; canvas.height = height; }
    const context = canvas.getContext("2d");
    if (!context) continue;
    context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
    context.clearRect(0, 0, rect.width, rect.height);
    const dancing = canvas === namePreview;
    const wave = dancing ? Math.sin(seconds * 4.2) : 0;
    const pose: CharacterPose = {
      bodyRotation: dancing ? Math.sin(seconds * 2.7) * 0.09 : 0,
      facePosition: [0, -5], faceBlink: Math.sin(seconds * 0.9) > 0.985,
      leftHandPosition: [-52, -4 - wave * 4], rightHandPosition: [52, -4 + wave * 4],
      leftFootPosition: [-35 - wave * 2, 62], rightFootPosition: [35 + wave * 2, 62],
      leftHandRotation: wave * 0.22, rightHandRotation: -wave * 0.22,
    };
    const scale = Math.min(rect.width / 145, rect.height / 125) * 0.9;
    drawCharacter(context, joinFlow.shape, joinFlow.color, rect.width / 2,
      rect.height * 0.46 + (dancing ? Math.sin(seconds * 3.4) * 4 : 0), scale, pose);
  }
}
function drawBubblePath(context: CanvasRenderingContext2D, radius: number, pull: Point, surfaceAngle: number): { points: Point[]; center: Point; along: Point; stretch: number } {
  const length = Math.hypot(pull[0], pull[1]);
  const stretch = clamp(length, 0, 0.22);
  const along: Point = stretch > 0.001 ? [pull[0] / length, pull[1] / length] : [1, 0];
  const center: Point = [along[0] * radius * stretch * 0.22, along[1] * radius * stretch * 0.22];
  const at = (theta: number): Point => {
    const forward = Math.cos(theta);
    const longitudinal = 1 + stretch * (1.25 * Math.max(forward, 0) - 0.25 * Math.max(-forward, 0));
    const normalX = -along[1]; const normalY = along[0];
    return [center[0] + along[0] * forward * radius * longitudinal + normalX * Math.sin(theta) * radius * (1 - stretch * 0.3),
      center[1] + along[1] * forward * radius * longitudinal + normalY * Math.sin(theta) * radius * (1 - stretch * 0.3)];
  };
  const points: Point[] = [];
  for (let index = 0; index < 65; index++) points.push(at(index * Math.PI * 2 / 64));
  context.beginPath(); points.forEach(([x, y], index) => index === 0 ? context.moveTo(x, y) : context.lineTo(x, y)); context.closePath();
  return { points, center, along, stretch };
}
function traceBubblePoint(theta: number, radius: number, center: Point, along: Point, stretch: number): Point {
  const forward = Math.cos(theta);
  const longitudinal = 1 + stretch * (1.25 * Math.max(forward, 0) - 0.25 * Math.max(-forward, 0));
  return [center[0] + along[0] * forward * radius * longitudinal - along[1] * Math.sin(theta) * radius * (1 - stretch * 0.3),
    center[1] + along[1] * forward * radius * longitudinal + along[0] * Math.sin(theta) * radius * (1 - stretch * 0.3)];
}
function drawPolyline(context: CanvasRenderingContext2D, points: Point[], color: string, width: number): void {
  if (points.length < 2) return;
  context.beginPath(); context.moveTo(points[0][0], points[0][1]);
  for (let index = 1; index < points.length; index++) context.lineTo(points[index][0], points[index][1]);
  context.strokeStyle = color; context.lineWidth = width; context.lineJoin = "round"; context.lineCap = "round"; context.stroke();
}
function drawArc(context: CanvasRenderingContext2D, x: number, y: number, radius: number, start: number, end: number, color: string, width: number): void {
  context.beginPath(); context.arc(x, y, Math.max(0, radius), start, end, false); context.strokeStyle = color; context.lineWidth = width; context.lineCap = "round"; context.stroke();
}
function drawBubbleBurst(context: CanvasRenderingContext2D, radius: number, progress: number, density: number): void {
  const age = clamp(progress, 0, 1); const fade = 1 - clamp((age - 0.45) / 0.55, 0, 1); const fragmentCount = Math.max(4, Math.floor(density / 2));
  for (let index = 0; index < fragmentCount; index++) {
    const phase = index * Math.PI * 2 / fragmentCount + 0.14;
    const x = Math.cos(phase) * radius * (0.25 + age * 1.14); const y = Math.sin(phase) * radius * (0.25 + age * 1.14);
    const color = BUBBLE_RIM_COLORS[index % BUBBLE_RIM_COLORS.length];
    drawArc(context, x, y, radius * (0.3 - age * 0.17), phase + 1, phase + 2.7, `${color}${Math.round(0.83 * fade * 255).toString(16).padStart(2, "0")}`, Math.max(2, radius * 0.055));
    drawArc(context, x, y, radius * (0.27 - age * 0.16), phase + 1.05, phase + 2.5, `rgba(255,255,255,${0.38 * fade})`, Math.max(1, radius * 0.016));
  }
  for (let index = 0; index < density; index++) {
    const phase = index * 2.39996; const distance = radius * (0.35 + age * (0.75 + (index % 4) * 0.13));
    const x = Math.cos(phase) * distance; const y = Math.sin(phase) * distance;
    if (index % 4 === 0) { const star = 2 + index % 3; context.strokeStyle = `rgba(255,255,222,${fade})`; context.lineWidth = 1.2; context.beginPath(); context.moveTo(x - star, y); context.lineTo(x + star, y); context.moveTo(x, y - star); context.lineTo(x, y + star); context.stroke(); }
    else drawArc(context, x, y, 2 + index % 3, 0, Math.PI * 2, `rgba(204,248,255,${0.75 * fade})`, 1.3);
  }
}
function drawPhoneCharacter(context: CanvasRenderingContext2D, visual: BubblesVisualSnapshot | undefined, hostTime: number,
		shape: CharacterShape, selectedColor: string): void {
  const fallbackScale = Math.min(0.55, (bubblesSnapshot?.bubble_radius ?? tuningValue("starting_radius", 48)) * 0.82 / 75);
  const characterScale = (visual?.character_scale ?? fallbackScale) * 0.4;
  const position = visual?.character_position ?? [0, Math.sin(hostTime / 1000 * 2.2) * 4];
  const pose: CharacterPose = {
    bodyRotation: visual?.body_rotation ?? Math.sin(hostTime / 1000 * 1.7) * 0.05,
    facePosition: visual?.face_position ?? [0, -5], faceBlink: visual?.face_blink ?? false,
    leftHandPosition: visual?.left_hand_position ?? [-52, -4], rightHandPosition: visual?.right_hand_position ?? [52, -4],
    leftFootPosition: visual?.left_foot_position ?? [-35, 62], rightFootPosition: visual?.right_foot_position ?? [35, 62],
    leftHandRotation: 0, rightHandRotation: 0,
  };
  drawCharacter(context, shape, visual?.recovery_white ? "#ffffff" : selectedColor,
    position[0], position[1], characterScale, pose);
}
function renderBubbles(now: number): void {
  if (bubblesCard.hidden || !bubblesSnapshot) return;
  const rect = bubblesCanvas.getBoundingClientRect();
  const pixelRatio = Math.max(1, Math.min(3, window.devicePixelRatio || 1));
  const backingWidth = Math.max(1, Math.round(rect.width * pixelRatio)); const backingHeight = Math.max(1, Math.round(rect.height * pixelRatio));
  if (bubblesCanvas.width !== backingWidth || bubblesCanvas.height !== backingHeight) { bubblesCanvas.width = backingWidth; bubblesCanvas.height = backingHeight; }
  const context = bubblesContext; context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0); context.clearRect(0, 0, rect.width, rect.height);
  const message = bubblesSnapshot; const visual = bubblesVisualSnapshot;
  const snapshotElapsed = Math.max(0, now - bubblesSnapshotTime); const visualElapsed = visual ? Math.max(0, now - bubblesVisualReceivedAt) : 0;
  const tuneTime = Number.isFinite(visual?.host_time_msec) ? visual!.host_time_msec + visualElapsed : (message.host_time_msec ?? 0) + snapshotElapsed;
  const startRadius = Math.max(1, tuningValue("starting_radius", 48));
  const baseRadius = Math.min(rect.width, rect.height) * 0.23;
  const worldScale = baseRadius / startRadius;
  const reformDuration = Math.max(1, tuningValue("bubble_reform_seconds", 0.35) * 1000);
  const reformRemaining = Math.max(0, (message.reform_remaining_msec ?? 0) - snapshotElapsed);
  const reformScale = reformRemaining > 0 ? clamp((reformDuration - reformRemaining) / reformDuration, 0.08, 1) : 1;
  const burstDuration = Math.max(1, tuningValue("burst_seconds", 0.26) * 1000);
  const burstProgress = visual?.burst_progress ?? (reformRemaining > 0 && reformDuration - reformRemaining < burstDuration ? (reformDuration - reformRemaining) / burstDuration : -1);
  const radius = Math.max(1, visual?.radius ?? ((message.bubble_radius ?? startRadius) * reformScale));
  const burstRadius = message.burst_radius ?? message.bubble_radius ?? startRadius;
  const renderedRadius = burstProgress >= 0 && burstProgress < 1 ? (visual?.radius ?? burstRadius) : radius;
  const bodyShape = isCharacterShape(message.character_shape) ? message.character_shape : FALLBACK_CHARACTER.shape;
  const selectedColor = colorOption(message.character_color)?.hex ?? FALLBACK_CHARACTER.color;
  const spinTurns = tuningValue("spin_surface_turns_per_second", 1.8);
  const spinning = visual?.spinning ?? (message.phase === "active" && (message.spin_remaining_msec ?? 0) - snapshotElapsed > 0);
  const surfaceAngle = visual ? visual.surface_angle + (spinning ? visualElapsed / 1000 * Math.PI * 2 * spinTurns : 0) : 0;
  let pull: Point = visual?.pull ?? [0, 0];
  let localDragPull: Point = [0, 0];
  if (bubblesPointer && message.phase === "active") {
    const dragX = bubblesPointer.drag[0] / 4; const dragY = bubblesPointer.drag[1] / 4; const dragLength = Math.hypot(dragX, dragY);
    const dragScale = dragLength > 1 ? 1 / dragLength : 1;
    const strength = tuningValue("live_drag_pull_strength", 0.2);
    const target: Point = [dragX * dragScale * strength, dragY * dragScale * strength];
    const delta = clamp((now - bubblesPreviousFrame) / 1000, 0, 0.1); const response = Math.max(0.001, tuningValue("live_drag_response_seconds", 0.08));
    const amount = 1 - Math.exp(-delta / response);
    bubblesPhoneDragDisplay = [bubblesPhoneDragDisplay[0] + (target[0] - bubblesPhoneDragDisplay[0]) * amount,
      bubblesPhoneDragDisplay[1] + (target[1] - bubblesPhoneDragDisplay[1]) * amount];
    localDragPull = bubblesPhoneDragDisplay;
    const localCharge = bubblesPointer.step / 4; const seconds = tuneTime / 1000;
    const wobble = tuningValue("charge_wobble_strength", 0.07) * localCharge;
    const localChargePull: Point = [Math.sin(seconds * 13) * wobble, Math.cos(seconds * 17) * wobble];
    const hostDrag = visual?.drag_pull ?? [0, 0]; const hostCharge = visual?.charge_pull ?? [0, 0];
    pull = [pull[0] - hostDrag[0] - hostCharge[0] + localDragPull[0] + localChargePull[0],
      pull[1] - hostDrag[1] - hostCharge[1] + localDragPull[1] + localChargePull[1]];
  } else {
    const amount = 1 - Math.exp(-clamp((now - bubblesPreviousFrame) / 1000, 0, 0.1) / Math.max(0.001, tuningValue("live_drag_response_seconds", 0.08)));
    bubblesPhoneDragDisplay = [bubblesPhoneDragDisplay[0] * (1 - amount), bubblesPhoneDragDisplay[1] * (1 - amount)];
  }
  context.save(); context.translate(rect.width / 2, rect.height / 2); context.scale(worldScale, worldScale);
  if (burstProgress >= 0 && burstProgress < 1) {
    drawBubbleBurst(context, renderedRadius, burstProgress + (visual ? visualElapsed / burstDuration : 0), visual?.particle_density ?? 10);
  } else {
    const shape = drawBubblePath(context, renderedRadius, pull, surfaceAngle);
    context.fillStyle = "rgba(69,191,255,.10)"; context.fill();
    const chargeGlow = bubblesPointer ? Math.max(0, bubblesPointer.step / 4) * tuningValue("charge_glow_strength", 0.12) : (visual?.charge_glow ?? 0);
    if (chargeGlow > 0) {
      context.beginPath(); context.arc(shape.center[0], shape.center[1], renderedRadius * 0.84, 0, Math.PI * 2); context.fillStyle = `rgba(125,209,255,${chargeGlow * 0.48})`; context.fill();
      drawArc(context, shape.center[0], shape.center[1], renderedRadius * 0.78, 0, Math.PI * 2, `rgba(191,240,255,${chargeGlow * 0.85})`, Math.max(3, renderedRadius * 0.16));
    }
    drawArc(context, shape.center[0] + renderedRadius * 0.04, shape.center[1] + renderedRadius * 0.04, renderedRadius * 0.79,
      0.15 + surfaceAngle, 1.35 + surfaceAngle, "rgba(110,212,255,.13)", Math.max(3, renderedRadius * 0.12));
    drawArc(context, shape.center[0], shape.center[1], renderedRadius * 0.87, 2.2 + surfaceAngle, 3.9 + surfaceAngle,
      "rgba(189,161,255,.10)", Math.max(3, renderedRadius * 0.09));
    drawPolyline(context, [...shape.points, shape.points[0]], `rgba(186,247,255,${0.65 * (visual?.recovery_white ? 1 : 0.88)})`, Math.max(2, renderedRadius * 0.045));
    drawPolyline(context, [...shape.points, shape.points[0]], `rgba(255,255,255,${0.56 * (visual?.recovery_white ? 1 : 0.88)})`, Math.max(1, renderedRadius * 0.016));
    for (let index = 0; index < 12; index++) {
      const start = index * Math.PI * 2 / 12 + surfaceAngle; const arc: Point[] = [];
      for (let sample = 0; sample < 10; sample++) arc.push(traceBubblePoint(start + sample * (Math.PI * 2 / 12 + 0.04) / 9, renderedRadius, shape.center, shape.along, shape.stretch));
      drawPolyline(context, arc, `${visual?.recovery_white ? "rgba(255,255,255," : "rgba("}${visual?.recovery_white ? "0.5" : `${["110,234,255", "167,133,255", "255,139,206", "255,223,157", "138,248,199"][index % 5]},0.5`})`, Math.max(2, renderedRadius * 0.055));
    }
    drawArc(context, shape.center[0] - renderedRadius * 0.08, shape.center[1] - renderedRadius * 0.08, renderedRadius * 0.74,
      -2.55 + surfaceAngle, -1.65 + surfaceAngle, "rgba(255,255,255,.76)", Math.max(2, renderedRadius * 0.055));
    drawArc(context, shape.center[0], shape.center[1], renderedRadius * 0.91, 0.38 + surfaceAngle, 1.15 + surfaceAngle,
      "rgba(222,255,255,.34)", Math.max(1.5, renderedRadius * 0.03));
    const count = Math.min(Math.max(0, Math.floor(message.visual_jellyfish ?? 0)), Math.max(0, Math.floor(message.visual_cap ?? 0)), 64);
    if (imageReady(bubblesArt.jellyfish)) for (let index = 0; index < count; index++) {
      const turn = index * 2.39996323; const distance = Math.sqrt((index + 0.5) / Math.max(count, 1)) * renderedRadius * 0.67;
      const width = renderedRadius * 0.11; const height = width * bubblesArt.jellyfish.naturalHeight / bubblesArt.jellyfish.naturalWidth;
      context.save(); context.globalAlpha = 0.82; context.drawImage(bubblesArt.jellyfish, Math.cos(turn) * distance - width / 2, Math.sin(turn) * distance - height / 2, width, height); context.restore();
    }
    if (spinning) {
      const density = visual?.particle_density ?? 10;
      for (let index = 0; index < density; index++) {
        const phase = index * 2.39996 + surfaceAngle * (0.55 + (index % 3) * 0.2);
        const x = Math.cos(phase) * renderedRadius * (1.12 + (index % 4) * 0.075); const y = Math.sin(phase) * renderedRadius * (1.12 + (index % 4) * 0.075);
        const size = 2.2 + (index % 3) * 1.2;
        drawArc(context, x, y, size, 0, Math.PI * 2, "rgba(204,250,255,.52)", 1.2);
        context.beginPath(); context.arc(x - size * 0.28, y - size * 0.3, 0.7, 0, Math.PI * 2); context.fillStyle = "rgba(255,255,255,.7)"; context.fill();
      }
    }
  }
  const characterVisible = visual?.character_visible ?? !(burstProgress >= 0 && burstProgress < 1);
  if (characterVisible) drawPhoneCharacter(context, visual, tuneTime, bodyShape, selectedColor);
  context.restore();
  bubblesPreviousFrame = now;
}

function animateBubbles(now: number): void {
  renderBubbles(now);
  renderJoinPreviews(now);
  requestAnimationFrame(animateBubbles);
}
requestAnimationFrame(animateBubbles);

function showGame(message: HostMessage): void {
  bubblesCard.hidden = true; playerCard.hidden = true; gameCard.hidden = false; const phase = message.phase ?? "waiting";
  gameHeading.textContent = phase === "countdown" ? "Get ready!" : phase === "genuine_stop_grace" ? "Hold a pose!" : "Watch the big screen";
  gameMessage.textContent = message.message ?? (phase === "genuine_stop_grace" ? "Music stopped! Hold your pose." : "Keep watching the shared screen.");
  const player = message.player as GameplayPlayer | undefined; const lifeCount = message.lives ?? player?.lives;
  if (message.debug_mode === true) lives.textContent = "Lives: DEBUG"; else if (Number.isInteger(lifeCount)) lives.textContent = `Lives: ${"♥".repeat(Math.max(0, lifeCount!))}${"♡".repeat(Math.max(0, 2 - lifeCount!))}`;
  const eliminated = message.eliminated === true || player?.eliminated === true; readPresentation(message.presentation); if (player) updateCharge(player);
  if (eliminated) { releaseHeld(); setGameplaySurface(false); gameHeading.textContent = "You've been eliminated :("; gameMessage.textContent = "Keep watching the big screen for the results."; poseGrid.replaceChildren(); }
  else if (message.type === "flash_pose_result") gameHeading.textContent = message.success ? "Pose locked!" : "Keep dancing!";
  else if (["countdown", "dance", "genuine_stop_grace", "resolve", "flash_wait"].includes(phase) || message.type === "flash_pose_challenge") { renderControls(message.available_directions ?? directions); setGameplaySurface(true); }
  else if (message.type === "flash_pose_results") { releaseHeld(); setGameplaySurface(false); gameHeading.textContent = message.placement ? `You placed #${message.placement}` : "Round complete"; gameMessage.textContent = "Check the big screen for the final results."; poseGrid.replaceChildren(); }
  else { releaseHeld(); setGameplaySurface(false); poseGrid.replaceChildren(); }
}

function rememberIdentity(message: HostMessage): boolean {
  const player = message.player as PublicPlayer | undefined;
  if (!player || typeof player.name !== "string" || typeof message.session_id !== "string" || typeof message.reconnect_token !== "string") return false;
  store(STORAGE.name, player.name); store(STORAGE.session, message.session_id); store(STORAGE.token, message.reconnect_token); showJoined(player); return true;
}
function reconnect(): void {
  if (stopped || retry !== undefined) return; setGameplaySurface(false);
  if (joined) { playerState.textContent = "Reconnecting"; leaveButton.disabled = true; }
  status.textContent = "Host disconnected. Reconnecting…"; status.hidden = false; retry = setTimeout(() => { retry = undefined; void connect(); }, 2000);
}
async function connect(): Promise<void> {
  status.textContent = joined ? "Reconnecting to the host…" : "Connecting to the host…";
  status.hidden = false;
  try {
    const response = await fetch("/session.json", { cache: "no-store", signal: AbortSignal.timeout(5000) }); if (!response.ok) throw new Error("Session unavailable"); const config: unknown = await response.json();
    if (!config || typeof config !== "object" || !("protocol" in config) || config.protocol !== 1 || !("websocket_port" in config) || !Number.isInteger(config.websocket_port) || Number(config.websocket_port) < 1024 || Number(config.websocket_port) > 65535 || !("session_id" in config) || typeof config.session_id !== "string") throw new Error("Unsupported session");
    if (stopped) return; const peer = new WebSocket(`ws://${location.hostname}:${config.websocket_port}`); socket = peer; const deadline = setTimeout(() => peer.close(), 7000);
    peer.onopen = () => peer.send(JSON.stringify({ type: "hello", protocol: 1, ...(stored(STORAGE.token) ? { reconnect_token: stored(STORAGE.token), session_id: stored(STORAGE.session) } : {}) }));
    peer.onmessage = (event: MessageEvent<string>) => {
      let message: HostMessage; try { message = JSON.parse(event.data) as HostMessage; } catch { peer.close(); return; }
      if (message.type === "welcome" && message.protocol === 1 && Number.isInteger(message.connection_id)) {
        clearTimeout(deadline); if (message.resume_status === "resumed" && rememberIdentity(message)) { releaseHeld(false); if (message.gameplay?.type === "bubbles_snapshot") showBubbles(message.gameplay); else if (message.gameplay?.type === "lobby" && message.player && "player_id" in message.player && "name" in message.player) showJoined(message.player as PublicPlayer, message.gameplay.message ?? "Waiting for the next game"); else if (message.gameplay) showGame(message.gameplay); return; }
        if (message.resume_status === "session_restarted") { forgetIdentity(); showJoin("The host started a new session. Choose your character and name to join again.", true); }
        else if (message.resume_status === "expired") { forgetIdentity(); showJoin("Your previous player expired. Choose your character and name to join again.", true); } else showJoin("Connected. Choose your character to join.", true);
      } else if (message.type === "join_accepted") { if (!rememberIdentity(message)) peer.close(); }
      else if (message.type === "join_rejected" || message.type === "error") { joinButton.disabled = false; status.textContent = message.message ?? "The host could not complete that action."; status.hidden = false; if (!joined) nameInput.focus(); }
      else if (message.type === "left") { forgetIdentity(); showJoin("You left the lobby. Choose your character and name to join again.", true); }
      else if (message.type === "flash_pose_charge") updateCharge(message);
      else if (["flash_pose_snapshot", "flash_pose_challenge", "flash_pose_result", "flash_pose_results"].includes(message.type ?? "")) showGame(message);
      else if (message.type === "bubbles_trace_result") bubblesLocalCharge = 0;
      else if (message.type === "bubbles_visual" && message.visual && bubblesSnapshot) { bubblesVisualSnapshot = message.visual; bubblesVisualReceivedAt = performance.now(); }
      else if (message.type === "bubbles_snapshot" || message.type === "bubbles_feedback") showBubbles(message);
      else if (message.type === "lobby") { releaseHeld(false); setGameplaySurface(false); bubblesCard.hidden = true; bubblesSnapshot = undefined; bubblesVisualSnapshot = undefined; if (message.player) rememberIdentity(message); else if (joined) { gameCard.hidden = true; playerCard.hidden = false; playerState.textContent = "Waiting for the next game"; status.textContent = message.message ?? "Waiting for the next game"; } }
    };
    peer.onclose = event => { clearTimeout(deadline); releaseHeld(false); if (socket === peer) socket = undefined; if (event.code === 4000) { stopped = true; leaveButton.disabled = true; status.textContent = "This player continued in another tab."; playerState.textContent = "Open in another tab"; return; } reconnect(); };
    peer.onerror = () => peer.close();
  } catch { reconnect(); }
}

joinForm.addEventListener("submit", event => { event.preventDefault(); const name = nameInput.value.trim(); store(STORAGE.name, name); if (!socket || socket.readyState !== WebSocket.OPEN) { status.textContent = "Still connecting. Try again in a moment."; status.hidden = false; return; } joinButton.disabled = true; status.textContent = "Joining…"; status.hidden = false; socket.send(JSON.stringify(createJoinMessage(name, joinFlow))); });
leaveButton.addEventListener("click", () => { if (!socket || socket.readyState !== WebSocket.OPEN) return; leaveButton.disabled = true; status.textContent = "Leaving…"; socket.send(JSON.stringify({ type: "leave" })); });
addEventListener("orientationchange", updateOrientation); addEventListener("resize", updateOrientation);
window.addEventListener("pagehide", () => { stopped = true; releaseHeld(false); clearTimeout(retry); retry = undefined; socket?.close(); });
window.addEventListener("pageshow", event => { if (event.persisted) { stopped = false; void connect(); } });
void connect();
