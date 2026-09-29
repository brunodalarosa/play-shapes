import { attemptImmersive } from "./immersive.js";
import { controllerSocketUrl } from "./network_config.js";
import { SquircleV1Canvas } from "./squircle_v1.js";
import { GestureTrace } from "./bubbles_gesture.js";
import { LobbyControls } from "./lobby_controls.js";
import { advanceJoinFlow, CHARACTER_COLORS, chooseJoinColor, colorOption, createJoinMessage, defaultJoinFlow, FALLBACK_CHARACTER, returnToCharacterSelection, } from "./character_selection.js";
const status = document.querySelector("#status");
const selectionScreen = document.querySelector("#selection-screen");
const selectionPreview = document.querySelector("#selection-preview");
const namePreview = document.querySelector("#name-preview");
const selectedCharacterLabel = document.querySelector("#selected-character-label");
const colorGrid = document.querySelector("#color-grid");
const nextButton = document.querySelector("#next-button");
const backButton = document.querySelector("#back-button");
const nameScreen = document.querySelector("#name-screen");
const joinForm = document.querySelector("#join-form");
const nameInput = document.querySelector("#player-name");
const joinButton = document.querySelector("#join-button");
const playerCard = document.querySelector("#player-card");
const readyCard = document.querySelector("#ready-card");
const readyState = document.querySelector("#ready-state");
const readyButton = document.querySelector("#ready-button");
const playerName = document.querySelector("#player-name-heading");
const playerState = document.querySelector("#player-state");
const leaveButton = document.querySelector("#leave-button");
const lobbyController = document.querySelector("#lobby-controller");
const lobbyStickZone = document.querySelector("#lobby-stick-zone");
const lobbyJumpButton = document.querySelector("#lobby-jump-button");
const lobbyLeaveButton = document.querySelector("#lobby-leave-button");
const bubblesCard = document.querySelector("#bubbles-card");
const bubblesPad = document.querySelector("#bubbles-pad");
const bubblesScore = document.querySelector("#bubbles-score");
const bubblesCanvas = document.querySelector("#bubbles-visual");
const bubblesContext = bubblesCanvas.getContext("2d", { alpha: true });
const STORAGE = { session: "play-shapes.session-id", token: "play-shapes.reconnect-token", name: "play-shapes.last-name", inputSeq: "play-shapes.input-seq" };
let socket;
let retry;
let stopped = false;
let joined = false;
let isReady = false;
let joinFlow = defaultJoinFlow();
let inputSeq = Number.parseInt(stored(STORAGE.inputSeq), 10) || 0;
let fullscreenAttempted = false;
let activeGame = null;
let bubblesPointer;
let bubblesSnapshot;
let bubblesSnapshotTime = 0;
let bubblesLocalCharge = 0;
let bubblesVisualSnapshot;
let bubblesVisualReceivedAt = 0;
let bubblesPhoneDragDisplay = [0, 0];
let bubblesPreviousFrame = performance.now();
const squircleCanvas = new SquircleV1Canvas();
const bubblesArt = { jellyfish: new Image() };
bubblesArt.jellyfish.src = "/bubbles-jellyfish.png";
const lobbyControls = new LobbyControls(lobbyController, lobbyStickZone, lobbyJumpButton, (action) => {
    if (!joined || !socket || socket.readyState !== WebSocket.OPEN || activeGame !== null)
        return;
    inputSeq += 1;
    store(STORAGE.inputSeq, String(inputSeq));
    socket.send(JSON.stringify({ ...action, input_seq: inputSeq }));
});
function stored(key) { try {
    return localStorage.getItem(key) ?? "";
}
catch {
    return "";
} }
function store(key, value) { try {
    localStorage.setItem(key, value);
}
catch { /* Page remains usable. */ } }
function forgetIdentity() { try {
    localStorage.removeItem(STORAGE.session);
    localStorage.removeItem(STORAGE.token);
    localStorage.removeItem(STORAGE.inputSeq);
}
catch { /* Restricted storage. */ } inputSeq = 0; }
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
    button.addEventListener("click", () => { joinFlow = chooseJoinColor(joinFlow, option.hex); refreshSelectionUi(); });
    colorGrid.append(button);
}
refreshSelectionUi();
function setGameplaySurface(active) {
    const next = active ? "bubbles" : null;
    if (activeGame !== next) {
        cancelBubblesPointer();
        if (next === null) {
            try {
                screen.orientation?.unlock?.();
            }
            catch { /* Unsupported orientation API. */ }
        }
        else if (document.fullscreenElement) {
            try {
                const orientation = screen.orientation;
                void Promise.resolve(orientation?.lock?.("portrait")).catch(() => { });
            }
            catch { /* Lock denied. */ }
        }
        activeGame = next;
    }
    document.documentElement.classList.toggle("gameplay-active", active);
    document.documentElement.classList.toggle("bubbles-active", next === "bubbles");
}
function showJoin(message, focus = false) {
    lobbyControls.deactivate();
    readyCard.hidden = true;
    document.documentElement.classList.remove("ready-active");
    joinFlow = returnToCharacterSelection(joinFlow);
    joined = false;
    bubblesSnapshot = undefined;
    bubblesVisualSnapshot = undefined;
    setGameplaySurface(false);
    playerCard.hidden = true;
    bubblesCard.hidden = true;
    selectionScreen.hidden = false;
    nameScreen.hidden = true;
    joinForm.hidden = true;
    joinButton.disabled = false;
    leaveButton.disabled = false;
    status.textContent = message;
    status.hidden = !message;
    nameInput.value = stored(STORAGE.name);
    refreshSelectionUi();
    if (focus)
        queueMicrotask(() => nextButton.focus());
}
function showJoined(player, state = "Connected") {
    readyCard.hidden = true;
    document.documentElement.classList.remove("ready-active");
    joined = true;
    bubblesSnapshot = undefined;
    bubblesVisualSnapshot = undefined;
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
readyButton.addEventListener("click", () => {
    if (!socket || socket.readyState !== WebSocket.OPEN)
        return;
    readyButton.disabled = true;
    socket.send(JSON.stringify({ type: "pre_minigame_ready", ready: !isReady }));
});
nextButton.addEventListener("click", () => {
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
    if (fullscreenAttempted)
        return;
    fullscreenAttempted = true;
    const root = document.documentElement;
    const orientation = screen.orientation;
    const fullscreen = root.requestFullscreen ? () => root.requestFullscreen({ navigationUI: "hide" }) : root.webkitRequestFullscreen?.bind(root);
    await attemptImmersive(fullscreen, orientation?.lock ? () => orientation.lock("portrait") : undefined);
}
function sendBubblesCharge(seq, stage, step = 0) {
    if (socket?.readyState === WebSocket.OPEN)
        socket.send(JSON.stringify({ type: "bubbles_charge", input_seq: seq, stage, step }));
}
function sendBubblesMotion(pointer, now) {
    if (pointer.motionCount >= 48 || socket?.readyState !== WebSocket.OPEN)
        return;
    socket.send(JSON.stringify({ type: "bubbles_charge", input_seq: pointer.seq, stage: "motion", drag: pointer.drag }));
    pointer.sentDrag = [...pointer.drag];
    pointer.lastMotionAt = now;
    pointer.motionCount += 1;
}
function cancelBubblesPointer(sendCancel = true) {
    if (!bubblesPointer)
        return;
    const { id, seq } = bubblesPointer;
    bubblesPointer = undefined;
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
    if (gestureSeq === undefined) {
        inputSeq += 1;
        store(STORAGE.inputSeq, String(inputSeq));
    }
    socket.send(JSON.stringify({ type: "bubbles_trace", input_seq: gestureSeq ?? inputSeq, trace }));
}
function vibrate(pattern) { try {
    navigator.vibrate?.(pattern);
}
catch { /* Best effort only. */ } }
bubblesPad.addEventListener("pointerdown", event => {
    if (activeGame !== "bubbles" || bubblesSnapshot?.phase !== "active" || bubblesPointer || (event.pointerType === "mouse" && event.button !== 0))
        return;
    event.preventDefault();
    const trace = new GestureTrace(bubblesPad.getBoundingClientRect());
    trace.add(event.clientX, event.clientY);
    inputSeq += 1;
    store(STORAGE.inputSeq, String(inputSeq));
    bubblesPhoneDragDisplay = [0, 0];
    bubblesPointer = { id: event.pointerId, trace, seq: inputSeq, step: 0, drag: [0, 0], sentDrag: [0, 0], lastMotionAt: performance.now(), motionCount: 0 };
    try {
        bubblesPad.setPointerCapture(event.pointerId);
    }
    catch {
        cancelBubblesPointer();
        return;
    }
    sendBubblesCharge(inputSeq, "start");
    void requestImmersiveMode();
});
bubblesPad.addEventListener("pointermove", event => {
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
    const drag = [Math.max(-4, Math.min(4, Math.round(dx * 10))), Math.max(-4, Math.min(4, Math.round(dy * 10)))];
    const now = performance.now();
    bubblesPointer.drag = drag;
    if ((drag[0] !== bubblesPointer.sentDrag[0] || drag[1] !== bubblesPointer.sentDrag[1]) && now - bubblesPointer.lastMotionAt >= 70)
        sendBubblesMotion(bubblesPointer, now);
});
bubblesPad.addEventListener("pointerup", event => {
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
bubblesPad.addEventListener("pointercancel", event => { if (bubblesPointer?.id === event.pointerId)
    cancelBubblesPointer(); });
bubblesPad.addEventListener("lostpointercapture", event => { if (bubblesPointer?.id === event.pointerId)
    cancelBubblesPointer(); });
bubblesPad.addEventListener("contextmenu", event => event.preventDefault());
bubblesPad.addEventListener("keydown", event => {
    if (event.repeat || activeGame !== "bubbles" || bubblesSnapshot?.phase !== "active")
        return;
    const directions = { ArrowLeft: [0.1, 0.5], ArrowRight: [0.9, 0.5], ArrowUp: [0.5, 0.1], ArrowDown: [0.5, 0.9] };
    if (directions[event.key]) {
        event.preventDefault();
        sendBubblesTrace([[0.5, 0.5], directions[event.key]]);
        void requestImmersiveMode();
    }
    else if (event.key === " " || event.key === "Enter") {
        event.preventDefault();
        const circles = Math.max(1, Math.min(3, bubblesSnapshot?.circles_to_charge ?? 1));
        const trace = Array.from({ length: 97 }, (_, index) => [0.5 + 0.22 * Math.cos(index / 96 * Math.PI * 2 * circles), 0.5 + 0.22 * Math.sin(index / 96 * Math.PI * 2 * circles)]);
        sendBubblesTrace(trace);
        void requestImmersiveMode();
    }
});
function showBubbles(message) {
    lobbyControls.deactivate();
    readyCard.hidden = true;
    document.documentElement.classList.remove("ready-active");
    bubblesSnapshot = message;
    bubblesSnapshotTime = performance.now();
    playerCard.hidden = true;
    bubblesCard.hidden = false;
    const phase = message.phase ?? "waiting";
    const active = phase === "results" || (["instructions", "countdown", "active"].includes(phase) && message.left !== true);
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
const BUBBLE_RIM_COLORS = ["#6eeaff", "#a785ff", "#ff8bce", "#ffdf9d", "#8af8c7"];
function clamp(value, minimum, maximum) { return Math.min(maximum, Math.max(minimum, value)); }
function tuningValue(key, fallback) {
    const value = bubblesSnapshot?.visual_tuning?.[key];
    return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}
function imageReady(image) { return image.complete && image.naturalWidth > 0; }
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
function drawBubblePath(context, radius, pull, surfaceAngle) {
    const length = Math.hypot(pull[0], pull[1]);
    const stretch = clamp(length, 0, 0.22);
    const along = stretch > 0.001 ? [pull[0] / length, pull[1] / length] : [1, 0];
    const center = [along[0] * radius * stretch * 0.22, along[1] * radius * stretch * 0.22];
    const at = (theta) => {
        const forward = Math.cos(theta);
        const longitudinal = 1 + stretch * (1.25 * Math.max(forward, 0) - 0.25 * Math.max(-forward, 0));
        const normalX = -along[1];
        const normalY = along[0];
        return [center[0] + along[0] * forward * radius * longitudinal + normalX * Math.sin(theta) * radius * (1 - stretch * 0.3),
            center[1] + along[1] * forward * radius * longitudinal + normalY * Math.sin(theta) * radius * (1 - stretch * 0.3)];
    };
    const points = [];
    for (let index = 0; index < 65; index++)
        points.push(at(index * Math.PI * 2 / 64));
    context.beginPath();
    points.forEach(([x, y], index) => index === 0 ? context.moveTo(x, y) : context.lineTo(x, y));
    context.closePath();
    return { points, center, along, stretch };
}
function traceBubblePoint(theta, radius, center, along, stretch) {
    const forward = Math.cos(theta);
    const longitudinal = 1 + stretch * (1.25 * Math.max(forward, 0) - 0.25 * Math.max(-forward, 0));
    return [center[0] + along[0] * forward * radius * longitudinal - along[1] * Math.sin(theta) * radius * (1 - stretch * 0.3),
        center[1] + along[1] * forward * radius * longitudinal + along[0] * Math.sin(theta) * radius * (1 - stretch * 0.3)];
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
function drawArc(context, x, y, radius, start, end, color, width) {
    context.beginPath();
    context.arc(x, y, Math.max(0, radius), start, end, false);
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
        const x = Math.cos(phase) * radius * (0.25 + age * 1.14);
        const y = Math.sin(phase) * radius * (0.25 + age * 1.14);
        const color = BUBBLE_RIM_COLORS[index % BUBBLE_RIM_COLORS.length];
        drawArc(context, x, y, radius * (0.3 - age * 0.17), phase + 1, phase + 2.7, `${color}${Math.round(0.83 * fade * 255).toString(16).padStart(2, "0")}`, Math.max(2, radius * 0.055));
        drawArc(context, x, y, radius * (0.27 - age * 0.16), phase + 1.05, phase + 2.5, `rgba(255,255,255,${0.38 * fade})`, Math.max(1, radius * 0.016));
    }
    for (let index = 0; index < density; index++) {
        const phase = index * 2.39996;
        const distance = radius * (0.35 + age * (0.75 + (index % 4) * 0.13));
        const x = Math.cos(phase) * distance;
        const y = Math.sin(phase) * distance;
        if (index % 4 === 0) {
            const star = 2 + index % 3;
            context.strokeStyle = `rgba(255,255,222,${fade})`;
            context.lineWidth = 1.2;
            context.beginPath();
            context.moveTo(x - star, y);
            context.lineTo(x + star, y);
            context.moveTo(x, y - star);
            context.lineTo(x, y + star);
            context.stroke();
        }
        else
            drawArc(context, x, y, 2 + index % 3, 0, Math.PI * 2, `rgba(204,248,255,${0.75 * fade})`, 1.3);
    }
}
function drawPhoneCharacter(context, visual, hostTime, selectedColor) {
    const fallbackScale = Math.min(0.44, (bubblesSnapshot?.bubble_radius ?? tuningValue("starting_radius", 48)) * 0.82 / 100);
    const position = visual?.character_position ?? [0, 40 + Math.sin(hostTime / 1000 * 2.2) * 4];
    squircleCanvas.draw(context, visual?.recovery_white ? "#ffffff" : selectedColor, position[0], position[1], visual?.character_scale ?? fallbackScale, hostTime, visual?.face_blink ?? false, visual?.body_rotation ?? Math.sin(hostTime / 1000 * 1.7) * 0.05);
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
    let pull = visual?.pull ?? [0, 0];
    let localDragPull = [0, 0];
    if (bubblesPointer && message.phase === "active") {
        const dragX = bubblesPointer.drag[0] / 4;
        const dragY = bubblesPointer.drag[1] / 4;
        const dragLength = Math.hypot(dragX, dragY);
        const dragScale = dragLength > 1 ? 1 / dragLength : 1;
        const strength = tuningValue("live_drag_pull_strength", 0.2);
        const target = [dragX * dragScale * strength, dragY * dragScale * strength];
        const delta = clamp((now - bubblesPreviousFrame) / 1000, 0, 0.1);
        const response = Math.max(0.001, tuningValue("live_drag_response_seconds", 0.08));
        const amount = 1 - Math.exp(-delta / response);
        bubblesPhoneDragDisplay = [bubblesPhoneDragDisplay[0] + (target[0] - bubblesPhoneDragDisplay[0]) * amount,
            bubblesPhoneDragDisplay[1] + (target[1] - bubblesPhoneDragDisplay[1]) * amount];
        localDragPull = bubblesPhoneDragDisplay;
        const localCharge = bubblesPointer.step / 4;
        const seconds = tuneTime / 1000;
        const wobble = tuningValue("charge_wobble_strength", 0.07) * localCharge;
        const localChargePull = [Math.sin(seconds * 13) * wobble, Math.cos(seconds * 17) * wobble];
        const hostDrag = visual?.drag_pull ?? [0, 0];
        const hostCharge = visual?.charge_pull ?? [0, 0];
        pull = [pull[0] - hostDrag[0] - hostCharge[0] + localDragPull[0] + localChargePull[0],
            pull[1] - hostDrag[1] - hostCharge[1] + localDragPull[1] + localChargePull[1]];
    }
    else {
        const amount = 1 - Math.exp(-clamp((now - bubblesPreviousFrame) / 1000, 0, 0.1) / Math.max(0.001, tuningValue("live_drag_response_seconds", 0.08)));
        bubblesPhoneDragDisplay = [bubblesPhoneDragDisplay[0] * (1 - amount), bubblesPhoneDragDisplay[1] * (1 - amount)];
    }
    context.save();
    context.translate(rect.width / 2, rect.height / 2);
    context.scale(worldScale, worldScale);
    if (burstProgress >= 0 && burstProgress < 1) {
        drawBubbleBurst(context, renderedRadius, burstProgress + (visual ? visualElapsed / burstDuration : 0), visual?.particle_density ?? 10);
    }
    else {
        const shape = drawBubblePath(context, renderedRadius, pull, surfaceAngle);
        context.fillStyle = "rgba(69,191,255,.10)";
        context.fill();
        const chargeGlow = bubblesPointer ? Math.max(0, bubblesPointer.step / 4) * tuningValue("charge_glow_strength", 0.12) : (visual?.charge_glow ?? 0);
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
            drawPolyline(context, arc, `${visual?.recovery_white ? "rgba(255,255,255," : "rgba("}${visual?.recovery_white ? "0.5" : `${["110,234,255", "167,133,255", "255,139,206", "255,223,157", "138,248,199"][index % 5]},0.5`})`, Math.max(2, renderedRadius * 0.055));
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
                const phase = index * 2.39996 + surfaceAngle * (0.55 + (index % 3) * 0.2);
                const x = Math.cos(phase) * renderedRadius * (1.12 + (index % 4) * 0.075);
                const y = Math.sin(phase) * renderedRadius * (1.12 + (index % 4) * 0.075);
                const size = 2.2 + (index % 3) * 1.2;
                drawArc(context, x, y, size, 0, Math.PI * 2, "rgba(204,250,255,.52)", 1.2);
                context.beginPath();
                context.arc(x - size * 0.28, y - size * 0.3, 0.7, 0, Math.PI * 2);
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
    if (stopped || retry !== undefined)
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
    retry = setTimeout(() => { retry = undefined; void connect(); }, 2000);
}
async function connect() {
    status.textContent = joined ? "Reconnecting to the host…" : "Connecting to the host…";
    status.hidden = false;
    try {
        const response = await fetch("/session.json", { cache: "no-store", signal: AbortSignal.timeout(5000) });
        if (!response.ok)
            throw new Error("Session unavailable");
        const config = await response.json();
        const socketUrl = controllerSocketUrl(config, location.href);
        if (stopped)
            return;
        const peer = new WebSocket(socketUrl);
        socket = peer;
        const deadline = setTimeout(() => peer.close(), 7000);
        peer.onopen = () => peer.send(JSON.stringify({ type: "hello", protocol: 1, ...(stored(STORAGE.token) ? { reconnect_token: stored(STORAGE.token), session_id: stored(STORAGE.session) } : {}) }));
        peer.onmessage = (event) => {
            let message;
            try {
                message = JSON.parse(event.data);
            }
            catch {
                peer.close();
                return;
            }
            if (message.type === "welcome" && message.protocol === 1 && Number.isInteger(message.connection_id)) {
                clearTimeout(deadline);
                if (message.resume_status === "resumed" && rememberIdentity(message)) {
                    if (message.gameplay?.type === "bubbles_snapshot")
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
                }
                else if (message.resume_status === "expired") {
                    forgetIdentity();
                    showJoin("Your previous player expired. Choose your character and name to join again.", true);
                }
                else
                    showJoin("Connected. Choose your character to join.", true);
            }
            else if (message.type === "join_accepted") {
                if (!rememberIdentity(message))
                    peer.close();
            }
            else if (message.type === "join_rejected" || message.type === "error") {
                joinButton.disabled = false;
                readyButton.disabled = false;
                status.textContent = message.message ?? "The host could not complete that action.";
                status.hidden = false;
                if (!readyCard.hidden)
                    readyState.textContent = status.textContent;
                if (!joined)
                    nameInput.focus();
            }
            else if (message.type === "left") {
                forgetIdentity();
                showJoin("You left the lobby. Choose your character and name to join again.", true);
            }
            else if (message.type === "bubbles_trace_result")
                bubblesLocalCharge = 0;
            else if (message.type === "bubbles_visual" && message.visual && bubblesSnapshot) {
                bubblesVisualSnapshot = message.visual;
                bubblesVisualReceivedAt = performance.now();
            }
            else if (message.type === "bubbles_snapshot" || message.type === "bubbles_feedback")
                showBubbles(message);
            else if (message.type === "pre_minigame_snapshot")
                showReady(message);
            else if (message.type === "lobby") {
                setGameplaySurface(false);
                readyCard.hidden = true;
                document.documentElement.classList.remove("ready-active");
                bubblesCard.hidden = true;
                bubblesSnapshot = undefined;
                bubblesVisualSnapshot = undefined;
                if (message.player)
                    rememberIdentity(message);
                else if (joined) {
                    playerCard.hidden = true;
                    lobbyControls.activate();
                    status.hidden = true;
                }
            }
        };
        peer.onclose = event => { clearTimeout(deadline); lobbyControls.deactivate(); if (socket === peer)
            socket = undefined; if (event.code === 4000) {
            stopped = true;
            leaveButton.disabled = true;
            status.textContent = "This player continued in another tab.";
            playerState.textContent = "Open in another tab";
            return;
        } reconnect(); };
        peer.onerror = () => peer.close();
    }
    catch {
        reconnect();
    }
}
joinForm.addEventListener("submit", event => { event.preventDefault(); const name = nameInput.value.trim(); store(STORAGE.name, name); if (!socket || socket.readyState !== WebSocket.OPEN) {
    status.textContent = "Still connecting. Try again in a moment.";
    status.hidden = false;
    return;
} joinButton.disabled = true; status.textContent = "Joining…"; status.hidden = false; socket.send(JSON.stringify(createJoinMessage(name, joinFlow))); });
function leaveLobby() { if (!socket || socket.readyState !== WebSocket.OPEN)
    return; lobbyControls.deactivate(); leaveButton.disabled = true; lobbyLeaveButton.disabled = true; status.textContent = "Leaving…"; socket.send(JSON.stringify({ type: "leave" })); }
leaveButton.addEventListener("click", leaveLobby);
lobbyLeaveButton.addEventListener("click", leaveLobby);
window.addEventListener("pagehide", () => { stopped = true; lobbyControls.deactivate(); clearTimeout(retry); retry = undefined; socket?.close(); });
window.addEventListener("pageshow", event => { if (event.persisted) {
    stopped = false;
    void connect();
} });
void connect();
