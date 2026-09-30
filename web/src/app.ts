import { attemptImmersive, protectControllerSurface, bindControllerLifecycle } from "./immersive.js";
import { PwaOnboarding, isStandalone } from "./pwa.js";
import { MotionLabController } from "./motion_lab.js";
import { controllerSocketUrl } from "./network_config.js";
import { SquircleV1Canvas } from "./squircle_v1.js";
import { GestureTrace, type Point } from "./bubbles_gesture.js";
import { LobbyControls } from "./lobby_controls.js";
import type { LobbyAction } from "./lobby_input.js";
import {
  advanceJoinFlow, CHARACTER_COLORS, chooseJoinColor,
  colorOption, createJoinMessage, defaultJoinFlow, FALLBACK_CHARACTER,
  returnToCharacterSelection, type JoinFlowState,
} from "./character_selection.js";

const status = document.querySelector<HTMLElement>("#status")!;
const connectionError = document.querySelector<HTMLElement>("#connection-error")!;
const connectionErrors: { text: string; at: string; repeats: number }[] = [];

// Development diagnostics stay outside gameplay's hidden status/onboarding layout.
// Report endpoints and error text only; never dump protocol messages or stored tokens.
function reportConnectionFailure(stage: string, endpoint: string, error: unknown): void {
  const detail = error instanceof Error ? `${error.name}: ${error.message}` : String(error);
  const text = `Step: ${stage}\nEndpoint: ${endpoint}\n${detail}`;
  const last = connectionErrors.at(-1);
  if (last?.text === text) last.repeats++;
  else {
    connectionErrors.push({ text, at: new Date().toISOString(), repeats: 1 });
    if (connectionErrors.length > 6) connectionErrors.shift();
  }
  connectionError.textContent = `CONTROLLER ERROR LOG (development)\nBrowser: ${navigator.userAgent}\nConnection failures retry every 2 seconds.\n\n` + connectionErrors.map(entry =>
    `[${entry.at}]${entry.repeats > 1 ? ` (repeated ${entry.repeats} times)` : ""}\n${entry.text}`).join("\n\n");
  connectionError.hidden = false;
}
window.addEventListener("error", event => {
  reportConnectionFailure("Browser JavaScript error", new URL(location.href).origin,
    `${event.error instanceof Error ? `${event.error.name}: ${event.error.message}` : event.message}\nSource: ${event.filename}:${event.lineno}:${event.colno}`);
});
window.addEventListener("unhandledrejection", event => {
  reportConnectionFailure("Unhandled browser promise rejection", new URL(location.href).origin, event.reason);
});
const selectionScreen = document.querySelector<HTMLElement>("#selection-screen")!;
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
const readyCard = document.querySelector<HTMLElement>("#ready-card")!;
const readyState = document.querySelector<HTMLElement>("#ready-state")!;
const readyButton = document.querySelector<HTMLButtonElement>("#ready-button")!;
const playerName = document.querySelector<HTMLElement>("#player-name-heading")!;
const playerState = document.querySelector<HTMLElement>("#player-state")!;
const leaveButton = document.querySelector<HTMLButtonElement>("#leave-button")!;
const lobbyController = document.querySelector<HTMLElement>("#lobby-controller")!;
const lobbyStickZone = document.querySelector<HTMLElement>("#lobby-stick-zone")!;
const lobbyJumpButton = document.querySelector<HTMLButtonElement>("#lobby-jump-button")!;
const lobbyLeaveButton = document.querySelector<HTMLButtonElement>("#lobby-leave-button")!;
const bubblesCard = document.querySelector<HTMLElement>("#bubbles-card")!;
const bubblesPad = document.querySelector<HTMLElement>("#bubbles-pad")!;
const bubblesScore = document.querySelector<HTMLElement>("#bubbles-score")!;
const bubblesCanvas = document.querySelector<HTMLCanvasElement>("#bubbles-visual")!;
const bubblesContext = bubblesCanvas.getContext("2d", { alpha: true })!;

const motionPanel = document.querySelector<HTMLElement>("#motion-lab")!;
const motionButton = document.querySelector<HTMLButtonElement>("#motion-permission")!;
const motionReadings = document.querySelector<HTMLElement>("#motion-readings")!;
const STORAGE = { session: "play-shapes.session-id", token: "play-shapes.reconnect-token", name: "play-shapes.last-name", inputSeq: "play-shapes.input-seq" } as const;
type PublicPlayer = { player_id: string; name: string; seat: number; state: string; character_shape?: string; character_color?: string };
type BubblesVisualSnapshot = { host_time_msec: number; radius: number; pull: Point; drag_pull: Point; charge_pull: Point; surface_angle: number; spinning: boolean; recovery_white: boolean; burst_progress: number; particle_density: number; charge_glow: number; character_visible: boolean; character_scale: number; character_position: Point; body_rotation: number; face_blink: boolean };
type BubblesVisualTuning = { starting_radius?: number; live_drag_pull_strength?: number; live_drag_response_seconds?: number; charge_wobble_strength?: number; charge_glow_strength?: number; swipe_reaction_seconds?: number; spin_surface_turns_per_second?: number; bubble_reform_seconds?: number; burst_seconds?: number };
type HostMessage = { subscription_id?: string; send_hz?: number; stale_msec?: number; type?: string; protocol?: number; connection_id?: number; session_id?: string; resume_status?: string; reconnect_token?: string; player?: PublicPlayer; code?: string; message?: string; phase?: string; debug_mode?: boolean; state?: string; gameplay?: HostMessage; ready?: boolean; score?: number; bubble_radius?: number; burst_radius?: number; visual_jellyfish?: number; visual_cap?: number; seat?: number; left?: boolean; character_shape?: string; character_color?: string; host_time_msec?: number; visual_tuning?: BubblesVisualTuning; visual?: BubblesVisualSnapshot; spin_remaining_msec?: number; cooldown_remaining_msec?: number; invulnerable_remaining_msec?: number; reform_remaining_msec?: number; spin_duration_msec?: number; cooldown_duration_msec?: number; circles_to_charge?: number; rank?: number; event?: string; lost?: number; action?: string; reason?: string };

let socket: WebSocket | undefined;
let retry: ReturnType<typeof setTimeout> | undefined;
let stopped = false;
let joined = false;
let isReady = false;
let joinFlow: JoinFlowState = defaultJoinFlow();
let inputSeq = Number.parseInt(stored(STORAGE.inputSeq), 10) || 0;
let activeGame: "bubbles" | null = null;
let bubblesPointer: { id: number; trace: GestureTrace; seq: number; step: number; drag: Point; sentDrag: Point; lastMotionAt: number; motionCount: number } | undefined;
let bubblesSnapshot: HostMessage | undefined;
let bubblesSnapshotTime = 0;
let bubblesLocalCharge = 0;
let bubblesVisualSnapshot: BubblesVisualSnapshot | undefined;
let bubblesVisualReceivedAt = 0;
let bubblesPhoneDragDisplay: Point = [0, 0];
let bubblesPreviousFrame = performance.now();
const squircleCanvas = new SquircleV1Canvas();
const bubblesArt = { jellyfish: new Image() };
bubblesArt.jellyfish.src = "/bubbles-jellyfish.png";
const lobbyControls = new LobbyControls(lobbyController, lobbyStickZone, lobbyJumpButton, (action: LobbyAction) => {
  if (!joined || !socket || socket.readyState !== WebSocket.OPEN || activeGame !== null) return;
  inputSeq += 1;
  store(STORAGE.inputSeq, String(inputSeq));
  socket.send(JSON.stringify({ ...action, input_seq: inputSeq }));
});

const motionLab = new MotionLabController(motionPanel, motionButton, motionReadings, () => socket);
const pwa = new PwaOnboarding(
  document.querySelector<HTMLElement>("#app-screen")!,
  document.querySelector<HTMLButtonElement>("#install-button")!,
  document.querySelector<HTMLElement>("#install-guidance")!,
  document.querySelector<HTMLButtonElement>("#browser-button")!,
  () => { selectionScreen.hidden = false; nextButton.focus(); void requestImmersiveMode(); },
);
for (const surface of [lobbyController, bubblesPad, readyCard]) protectControllerSurface(surface);
bindControllerLifecycle(() => cancelBubblesPointer());

function stored(key: string): string { try { return localStorage.getItem(key) ?? ""; } catch { return ""; } }
function store(key: string, value: string): void { try { localStorage.setItem(key, value); } catch { /* Page remains usable. */ } }
function forgetIdentity(): void { try { localStorage.removeItem(STORAGE.session); localStorage.removeItem(STORAGE.token); localStorage.removeItem(STORAGE.inputSeq); } catch { /* Restricted storage. */ } inputSeq = 0; }

function selectedCharacterName(): string {
  const color = colorOption(joinFlow.color)?.name ?? "Blue";
  return `${color} Squircle`;
}

function refreshSelectionUi(): void {
  const label = selectedCharacterName();
  selectedCharacterLabel.textContent = label;
  selectionPreview.setAttribute("aria-label", `${label} Shape Character`);
  namePreview.setAttribute("aria-label", `${label} character preview`);
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

function setGameplaySurface(active: boolean): void {
  const next = active ? "bubbles" : null;
  if (activeGame !== next) {
    cancelBubblesPointer();
    if (next === null) { try { screen.orientation?.unlock?.(); } catch { /* Unsupported orientation API. */ } }
    else if (document.fullscreenElement) { try { const orientation = screen.orientation as ScreenOrientation & { lock?: (value: string) => Promise<void> }; void Promise.resolve(orientation?.lock?.("portrait")).catch(() => {}); } catch { /* Lock denied. */ } }
    activeGame = next;
  }
  document.documentElement.classList.toggle("gameplay-active", active);
  document.documentElement.classList.toggle("bubbles-active", next === "bubbles");
}

function showJoin(message: string, focus = false): void {
  motionLab.stop();
  lobbyControls.deactivate();
  readyCard.hidden = true; document.documentElement.classList.remove("ready-active");
  joinFlow = returnToCharacterSelection(joinFlow);
  joined = false; bubblesSnapshot = undefined; bubblesVisualSnapshot = undefined; setGameplaySurface(false); playerCard.hidden = true; bubblesCard.hidden = true;
  selectionScreen.hidden = pwa.visible || pwa.show(); nameScreen.hidden = true; joinForm.hidden = true; joinButton.disabled = false; leaveButton.disabled = false;
  status.textContent = message; status.hidden = !message; nameInput.value = stored(STORAGE.name); refreshSelectionUi();
  if (focus && !pwa.visible) queueMicrotask(() => nextButton.focus());
}
function showJoined(player: PublicPlayer, state = "Connected"): void {
  pwa.hide();
  motionLab.stop();
  readyCard.hidden = true; document.documentElement.classList.remove("ready-active");
  joined = true; bubblesSnapshot = undefined; bubblesVisualSnapshot = undefined; setGameplaySurface(false); selectionScreen.hidden = true; nameScreen.hidden = true; joinForm.hidden = true; playerCard.hidden = true; bubblesCard.hidden = true; playerName.textContent = player.name; playerState.textContent = state; leaveButton.disabled = false; lobbyLeaveButton.disabled = false; lobbyControls.activate();
  const serverColor = colorOption(player.character_color)?.hex;
  if (serverColor) joinFlow = chooseJoinColor(joinFlow, serverColor);
  status.textContent = state === "Connected" ? "Joined. Keep this page open while you play." : state; status.hidden = true;
}

function showReady(message: HostMessage): void {
  motionLab.stop();
  lobbyControls.deactivate(); setGameplaySurface(false);
  selectionScreen.hidden = true; nameScreen.hidden = true; joinForm.hidden = true;
  playerCard.hidden = true; bubblesCard.hidden = true; readyCard.hidden = false;
  document.documentElement.classList.add("ready-active");
  isReady = message.ready === true;
  readyState.textContent = isReady ? "Ready!" : "Not ready";
  readyButton.textContent = isReady ? "CANCEL" : "READY";
  readyButton.setAttribute("aria-pressed", String(isReady));
  readyButton.setAttribute("aria-label", isReady ? "Cancel ready status" : "Ready up");
  readyButton.disabled = false;
  status.hidden = true;
}
readyButton.addEventListener("click", () => {
  if (!socket || socket.readyState !== WebSocket.OPEN) return;
  readyButton.disabled = true;
  socket.send(JSON.stringify({ type: "pre_minigame_ready", ready: !isReady }));
});

nextButton.addEventListener("click", () => {
  if (pwa.visible) return;
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
async function requestImmersiveMode(): Promise<void> {
  if (isStandalone(window, navigator) || document.fullscreenElement) return;
  const root = document.documentElement as HTMLElement & { webkitRequestFullscreen?: () => Promise<void> | void };
  const orientation = screen.orientation as ScreenOrientation & { lock?: (value: string) => Promise<void> };
  const fullscreen = root.requestFullscreen ? () => root.requestFullscreen({ navigationUI: "hide" }) : root.webkitRequestFullscreen?.bind(root);
  await attemptImmersive(fullscreen, orientation?.lock ? () => orientation.lock!("portrait") : undefined);
}
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
  if (directions[event.key]) { event.preventDefault(); sendBubblesTrace([[0.5, 0.5], directions[event.key]]); }
  else if (event.key === " " || event.key === "Enter") {
    event.preventDefault(); const circles = Math.max(1, Math.min(3, bubblesSnapshot?.circles_to_charge ?? 1));
    const trace: Point[] = Array.from({ length: 97 }, (_, index) => [0.5 + 0.22 * Math.cos(index / 96 * Math.PI * 2 * circles), 0.5 + 0.22 * Math.sin(index / 96 * Math.PI * 2 * circles)]);
    sendBubblesTrace(trace);
  }
});

function showBubbles(message: HostMessage): void {
  motionLab.stop();
  lobbyControls.deactivate();
  readyCard.hidden = true; document.documentElement.classList.remove("ready-active");
  bubblesSnapshot = message;
  bubblesSnapshotTime = performance.now();
  playerCard.hidden = true; bubblesCard.hidden = false;
  const phase = message.phase ?? "waiting";
  const active = phase === "results" || (["instructions", "countdown", "active"].includes(phase) && message.left !== true);
  setGameplaySurface(active);
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
function renderJoinPreviews(now: number): void {
  for (const canvas of [selectionPreview, namePreview]) {
    if (canvas.closest("section")?.hidden) continue;
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
    const scale = Math.min(rect.width / 256, rect.height / 220) * 0.95;
    squircleCanvas.draw(context, joinFlow.color, rect.width / 2, rect.height * 0.89, scale, now);
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
function drawPhoneCharacter(context: CanvasRenderingContext2D, visual: BubblesVisualSnapshot | undefined,
    hostTime: number, selectedColor: string): void {
  const fallbackScale = Math.min(0.44, (bubblesSnapshot?.bubble_radius ?? tuningValue("starting_radius", 48)) * 0.82 / 100);
  const position = visual?.character_position ?? [0, 40 + Math.sin(hostTime / 1000 * 2.2) * 4];
  squircleCanvas.draw(context, visual?.recovery_white ? "#ffffff" : selectedColor,
    position[0], position[1], visual?.character_scale ?? fallbackScale, hostTime,
    visual?.face_blink ?? false, visual?.body_rotation ?? Math.sin(hostTime / 1000 * 1.7) * 0.05);
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
  if (characterVisible) drawPhoneCharacter(context, visual, tuneTime, selectedColor);
  context.restore();
  bubblesPreviousFrame = now;
}

function animateBubbles(now: number): void {
  renderBubbles(now);
  renderJoinPreviews(now);
  requestAnimationFrame(animateBubbles);
}
requestAnimationFrame(animateBubbles);

function rememberIdentity(message: HostMessage): boolean {
  const player = message.player as PublicPlayer | undefined;
  if (!player || typeof player.name !== "string" || typeof message.session_id !== "string" || typeof message.reconnect_token !== "string") return false;
  store(STORAGE.name, player.name); store(STORAGE.session, message.session_id); store(STORAGE.token, message.reconnect_token); showJoined(player); return true;
}
function reconnect(): void {
  motionLab.disconnect();
  if (stopped || retry !== undefined) return; lobbyControls.deactivate(); setGameplaySurface(false);
  if (!readyCard.hidden) { readyButton.disabled = true; readyState.textContent = "Reconnecting…"; }
  if (joined) { playerState.textContent = "Reconnecting"; leaveButton.disabled = true; }
  status.textContent = "Host disconnected. Reconnecting…"; status.hidden = false; retry = setTimeout(() => { retry = undefined; void connect(); }, 2000);
}
async function connect(): Promise<void> {
  status.textContent = joined ? "Reconnecting to the host…" : "Connecting to the host…";
  status.hidden = false;
  let stage = "Fetch session configuration";
  let endpoint = new URL("/session.json", location.href).href;
  try {
    const response = await fetch("/session.json", { cache: "no-store", signal: AbortSignal.timeout(5000) });
    if (!response.ok) throw new Error(`HTTP ${response.status} ${response.statusText}`);
    stage = "Parse session configuration JSON";
    const config: unknown = await response.json();
    stage = "Validate session transport configuration";
    const socketUrl = controllerSocketUrl(config, location.href);
    stage = "Open WebSocket"; endpoint = socketUrl;
    if (stopped) return; const peer = new WebSocket(socketUrl); socket = peer;
    let socketFailure = "";
    const deadline = setTimeout(() => {
      socketFailure = "No host welcome received within 7000 ms.";
      reportConnectionFailure(stage, endpoint, socketFailure);
      peer.close();
    }, 7000);
    peer.onopen = () => {
      stage = "Wait for host welcome";
      peer.send(JSON.stringify({ type: "hello", protocol: 1, ...(stored(STORAGE.token) ? { reconnect_token: stored(STORAGE.token), session_id: stored(STORAGE.session) } : {}) }));
    };
    peer.onmessage = (event: MessageEvent<string>) => {
      let message: HostMessage; try { message = JSON.parse(event.data) as HostMessage; } catch (error) {
        // Parser messages can quote the payload, including a welcome's resume token.
        socketFailure = `Invalid JSON received from host (${error instanceof Error ? error.name : "parse error"}).`;
        reportConnectionFailure("Parse host message JSON", endpoint, socketFailure);
        peer.close(); return;
      }
      if (message.type === "welcome" && message.protocol === 1 && Number.isInteger(message.connection_id)) {
        stage = "Connected WebSocket";
        connectionError.hidden = true; connectionError.textContent = "";
        clearTimeout(deadline); if (message.resume_status === "resumed" && rememberIdentity(message)) { if (message.gameplay?.type === "bubbles_snapshot") showBubbles(message.gameplay); else if (message.gameplay?.type === "pre_minigame_snapshot") showReady(message.gameplay); else if (message.gameplay?.type === "lobby" && message.player && "player_id" in message.player && "name" in message.player) showJoined(message.player as PublicPlayer, message.gameplay.message ?? "Waiting for the next game"); return; }
        if (message.resume_status === "session_restarted") { forgetIdentity(); showJoin("The host started a new session. Choose your character and name to join again.", true); }
        else if (message.resume_status === "expired") { forgetIdentity(); showJoin("Your previous player expired. Choose your character and name to join again.", true); } else showJoin(isStandalone(window, navigator) && !stored(STORAGE.token) ? "Choose your character to join. If already playing in a browser, leave that controller first." : "Connected. Choose your character to join.", true);
      } else if (message.type === "join_accepted") { if (!rememberIdentity(message)) peer.close(); }
      else if (message.type === "join_rejected" || message.type === "error") { joinButton.disabled = false; readyButton.disabled = false; status.textContent = message.message ?? "The host could not complete that action."; status.hidden = false; if (message.type === "error") reportConnectionFailure("Host protocol error", endpoint, `${message.code ?? "unknown"}: ${status.textContent}`); if (!readyCard.hidden) readyState.textContent = status.textContent; if (!joined) nameInput.focus(); }
      else if (message.type === "left") { forgetIdentity(); showJoin("You left the lobby. Choose your character and name to join again.", true); }
      else if (message.type === "bubbles_trace_result") bubblesLocalCharge = 0;
      else if (message.type === "bubbles_visual" && message.visual && bubblesSnapshot) { bubblesVisualSnapshot = message.visual; bubblesVisualReceivedAt = performance.now(); }
      else if (message.type === "bubbles_snapshot" || message.type === "bubbles_feedback") showBubbles(message);
      else if (message.type === "pre_minigame_snapshot") showReady(message);
      else if (message.type === "motion_lab" && joined && typeof message.subscription_id === "string" && typeof message.send_hz === "number") {
        lobbyControls.deactivate(); setGameplaySurface(false); document.documentElement.classList.remove("ready-active");
        selectionScreen.hidden = nameScreen.hidden = joinForm.hidden = playerCard.hidden = readyCard.hidden = bubblesCard.hidden = true;
        status.hidden = true; motionLab.begin({ subscription_id: message.subscription_id, send_hz: message.send_hz, stale_msec: message.stale_msec ?? 1000 });
      }
      else if (message.type === "motion_stop") { motionLab.stop(); if (joined) lobbyControls.activate(); }
      else if (message.type === "lobby") { motionLab.stop(); setGameplaySurface(false); readyCard.hidden = true; document.documentElement.classList.remove("ready-active"); bubblesCard.hidden = true; bubblesSnapshot = undefined; bubblesVisualSnapshot = undefined; if (message.player) rememberIdentity(message); else if (joined) { playerCard.hidden = true; lobbyControls.activate(); status.hidden = true; } }
    };
    peer.onclose = event => {
      clearTimeout(deadline); lobbyControls.deactivate(); motionLab.disconnect(); setGameplaySurface(false);
      if (socket === peer) socket = undefined;
      if (event.code === 4000) {
        stopped = true; leaveButton.disabled = true;
        readyCard.hidden = bubblesCard.hidden = true;
        document.documentElement.classList.remove("ready-active");
        status.textContent = "This player continued in another window. Reload to switch back.";
        status.hidden = false;
        playerState.textContent = "Open in another window";
        return;
      }
      if (!stopped) reportConnectionFailure(stage, endpoint,
        `${socketFailure ? socketFailure + "\n" : ""}WebSocket closed: code=${event.code}, reason=${event.reason || "(not provided)"}, wasClean=${event.wasClean}.`);
      reconnect();
    };
    peer.onerror = event => {
      socketFailure = `WebSocket ${event.type || "error"} event. Browser did not expose the underlying network/TLS reason.`;
      reportConnectionFailure(stage, endpoint, socketFailure);
      peer.close();
    };
  } catch (error) { if (!stopped) reportConnectionFailure(stage, endpoint, error); reconnect(); }
}

joinForm.addEventListener("submit", event => { event.preventDefault(); if (pwa.visible) return; const name = nameInput.value.trim(); store(STORAGE.name, name); if (!socket || socket.readyState !== WebSocket.OPEN) { status.textContent = "Still connecting. Try again in a moment."; status.hidden = false; return; } joinButton.disabled = true; status.textContent = "Joining…"; status.hidden = false; socket.send(JSON.stringify(createJoinMessage(name, joinFlow))); });
function leaveLobby(): void { if (!socket || socket.readyState !== WebSocket.OPEN) return; lobbyControls.deactivate(); leaveButton.disabled = true; lobbyLeaveButton.disabled = true; status.textContent = "Leaving…"; socket.send(JSON.stringify({ type: "leave" })); }
leaveButton.addEventListener("click", leaveLobby);
lobbyLeaveButton.addEventListener("click", leaveLobby);
window.addEventListener("pagehide", () => { stopped = true; lobbyControls.deactivate(); clearTimeout(retry); retry = undefined; socket?.close(); });
window.addEventListener("pageshow", event => { if (event.persisted) { stopped = false; void connect(); } });
void connect();
