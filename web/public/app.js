import { attemptImmersive, chargedColor, directionAtPoint, heldDirectionAfterUpdate } from "./controller_geometry.js";
import { GestureTrace } from "./bubbles_gesture.js";
const status = document.querySelector("#status");
const joinForm = document.querySelector("#join-form");
const nameInput = document.querySelector("#player-name");
const joinButton = document.querySelector("#join-button");
const playerCard = document.querySelector("#player-card");
const playerName = document.querySelector("#player-name-heading");
const playerState = document.querySelector("#player-state");
const leaveButton = document.querySelector("#leave-button");
const gameCard = document.querySelector("#game-card");
const gameHeading = document.querySelector("#game-heading");
const gameMessage = document.querySelector("#game-message");
const lives = document.querySelector("#lives");
const poseGrid = document.querySelector("#pose-grid");
const rotateState = document.querySelector("#rotate-state");
const bubblesCard = document.querySelector("#bubbles-card");
const bubblesPad = document.querySelector("#bubbles-pad");
const bubblesRotate = document.querySelector("#bubbles-rotate");
const bubblesStatus = document.querySelector("#bubbles-status");
const bubblesScore = document.querySelector("#bubbles-score");
const bubblesState = document.querySelector("#bubbles-state");
const bubblesReplica = document.querySelector("#bubbles-replica");
const bubblesCharacter = document.querySelector("#bubbles-character");
const bubblesCaptured = document.querySelector("#bubbles-captured");
const bubblesMeter = document.querySelector("#bubbles-meter-fill");
const bubblesHelp = document.querySelector("#bubbles-help");
const STORAGE = { session: "play-shapes.session-id", token: "play-shapes.reconnect-token", name: "play-shapes.last-name", inputSeq: "play-shapes.input-seq" };
const POSES = [
    { direction: "left", icon: "←", label: "Pose left" }, { direction: "right", icon: "→", label: "Pose right" },
    { direction: "down", icon: "↓", label: "Pose down" }, { direction: "up", icon: "↑", label: "Pose up" },
];
const DEFAULT_COLORS = { left: "#48d16f", right: "#f04f55", down: "#f4c542", up: "#3489eb" };
let socket;
let retry;
let stopped = false;
let joined = false;
let inputSeq = Number.parseInt(stored(STORAGE.inputSeq), 10) || 0;
let held;
let directions = [];
let presentation = { colors: DEFAULT_COLORS, minimum_brightness: 0.42, maximum_brightness: 1, charge_fill_seconds: 1, charge_decay_seconds: 0.28 };
let visualCharge = { left: 0, right: 0, down: 0, up: 0 };
let authoritativeDirection;
let authoritativeCharge = 0;
let authoritativeHeld = false;
let lastAnimationTime = performance.now();
let fullscreenAttempted = { flash: false, bubbles: false };
let activeGame = null;
let bubblesPointer;
let bubblesSnapshot;
let bubblesSnapshotTime = 0;
let bubblesLocalCharge = 0;
let bubblesFeedbackUntil = 0;
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
function setGameplaySurface(active, mode = "flash") {
    const next = active ? mode : null;
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
                void Promise.resolve(orientation?.lock?.(next === "flash" ? "landscape" : "portrait")).catch(() => { });
            }
            catch { /* Lock denied. */ }
        }
        activeGame = next;
    }
    document.documentElement.classList.toggle("gameplay-active", active);
    document.documentElement.classList.toggle("bubbles-active", next === "bubbles");
    updateOrientation();
}
function updateOrientation() {
    const portrait = matchMedia("(orientation: portrait)").matches;
    rotateState.hidden = !(activeGame === "flash" && portrait);
    poseGrid.hidden = activeGame !== "flash" || portrait;
    bubblesRotate.hidden = !(activeGame === "bubbles" && !portrait);
}
function showJoin(message, focus = false) {
    joined = false;
    setGameplaySurface(false);
    playerCard.hidden = true;
    gameCard.hidden = true;
    bubblesCard.hidden = true;
    joinForm.hidden = false;
    joinButton.disabled = false;
    leaveButton.disabled = false;
    status.textContent = message;
    nameInput.value = stored(STORAGE.name);
    if (focus)
        queueMicrotask(() => nameInput.focus());
}
function showJoined(player, state = "Connected") {
    joined = true;
    setGameplaySurface(false);
    joinForm.hidden = true;
    playerCard.hidden = false;
    gameCard.hidden = true;
    bubblesCard.hidden = true;
    playerName.textContent = player.name;
    playerState.textContent = state;
    leaveButton.disabled = false;
    status.textContent = state === "Connected" ? "Joined. Keep this page open while you play." : state;
}
function sendPose(type, direction) { if (!socket || socket.readyState !== WebSocket.OPEN)
    return; inputSeq += 1; store(STORAGE.inputSeq, String(inputSeq)); socket.send(JSON.stringify({ type, direction, input_seq: inputSeq })); }
function releaseHeld(send = true) {
    if (!held)
        return;
    const current = held;
    held = undefined;
    current.button.classList.remove("is-held");
    current.button.setAttribute("aria-pressed", "false");
    if (current.pointerId !== undefined && poseGrid.hasPointerCapture(current.pointerId))
        poseGrid.releasePointerCapture(current.pointerId);
    if (send)
        sendPose("pose_up", current.direction);
}
function beginHold(direction, button, pointerId) {
    if (held?.direction === direction)
        return;
    releaseHeld();
    held = { direction, button, ...(pointerId === undefined ? {} : { pointerId }) };
    if (pointerId !== undefined)
        poseGrid.setPointerCapture(pointerId);
    button.classList.add("is-held");
    button.setAttribute("aria-pressed", "true");
    visualCharge[direction] = 0;
    authoritativeDirection = direction;
    authoritativeCharge = 0;
    authoritativeHeld = true;
    sendPose("pose_down", direction);
    void requestImmersiveMode("flash");
}
function readPresentation(value) {
    if (!value)
        return;
    presentation = { colors: { ...DEFAULT_COLORS, ...(value.colors ?? {}) }, minimum_brightness: Number(value.minimum_brightness ?? presentation.minimum_brightness), maximum_brightness: Number(value.maximum_brightness ?? presentation.maximum_brightness), charge_fill_seconds: Math.max(0.1, Number(value.charge_fill_seconds ?? presentation.charge_fill_seconds)), charge_decay_seconds: Math.max(0.05, Number(value.charge_decay_seconds ?? presentation.charge_decay_seconds)) };
}
function renderControls(available) {
    const desired = POSES.filter(item => available.includes(item.direction)).map(item => item.direction);
    if (held && heldDirectionAfterUpdate(held.direction, desired) === undefined)
        releaseHeld();
    directions = desired;
    const existing = Array.from(poseGrid.querySelectorAll(".pose-button"), button => button.dataset.direction);
    if (existing.length === desired.length && existing.every((value, index) => value === desired[index]))
        return;
    poseGrid.replaceChildren();
    poseGrid.dataset.count = String(desired.length);
    for (const pose of POSES.filter(item => desired.includes(item.direction))) {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "pose-button";
        button.dataset.direction = pose.direction;
        button.setAttribute("aria-label", pose.label);
        button.setAttribute("aria-pressed", held?.direction === pose.direction ? "true" : "false");
        button.innerHTML = `<span class="icon" aria-hidden="true">${pose.icon}</span>`;
        if (held?.direction === pose.direction) {
            held.button = button;
            button.classList.add("is-held");
        }
        button.addEventListener("keydown", event => { if ((event.key !== " " && event.key !== "Enter") || event.repeat || held)
            return; event.preventDefault(); beginHold(pose.direction, button); });
        button.addEventListener("keyup", event => { if ((event.key === " " || event.key === "Enter") && held?.button === button) {
            event.preventDefault();
            releaseHeld();
        } });
        button.addEventListener("blur", () => { if (held?.button === button && held.pointerId === undefined)
            releaseHeld(); });
        poseGrid.append(button);
    }
}
poseGrid.addEventListener("pointerdown", event => {
    event.preventDefault();
    if (event.button !== 0 && event.pointerType === "mouse")
        return;
    const rect = poseGrid.getBoundingClientRect();
    const direction = directionAtPoint(directions.length, event.clientX - rect.left, event.clientY - rect.top, rect.width, rect.height);
    const button = poseGrid.querySelector(`[data-direction="${direction}"]`);
    if (button)
        beginHold(direction, button, event.pointerId);
});
poseGrid.addEventListener("pointerup", event => { event.preventDefault(); if (held?.pointerId === event.pointerId)
    releaseHeld(); });
poseGrid.addEventListener("pointercancel", event => { if (held?.pointerId === event.pointerId)
    releaseHeld(); });
poseGrid.addEventListener("lostpointercapture", event => { if (held?.pointerId === event.pointerId)
    releaseHeld(); });
poseGrid.addEventListener("contextmenu", event => event.preventDefault());
poseGrid.addEventListener("selectstart", event => event.preventDefault());
async function requestImmersiveMode(mode) {
    if (fullscreenAttempted[mode])
        return;
    fullscreenAttempted[mode] = true;
    const root = document.documentElement;
    const orientation = screen.orientation;
    const fullscreen = root.requestFullscreen ? () => root.requestFullscreen({ navigationUI: "hide" }) : root.webkitRequestFullscreen?.bind(root);
    await attemptImmersive(fullscreen, orientation?.lock ? () => orientation.lock(mode === "flash" ? "landscape" : "portrait") : undefined);
}
function updateCharge(message) {
    authoritativeDirection = POSES.some(item => item.direction === message.direction) ? message.direction : undefined;
    authoritativeCharge = Math.min(1, Math.max(0, Number(message.charge ?? 0)));
    authoritativeHeld = message.held === true;
}
function animate(now) {
    const delta = Math.min(0.1, Math.max(0, (now - lastAnimationTime) / 1000));
    lastAnimationTime = now;
    for (const direction of directions) {
        const locallyHeld = held?.direction === direction;
        const hostDirection = authoritativeDirection === direction;
        let target = hostDirection ? authoritativeCharge : 0;
        if (locallyHeld && authoritativeHeld)
            target = Math.max(target, visualCharge[direction] + delta / presentation.charge_fill_seconds);
        const rate = (locallyHeld || (hostDirection && authoritativeHeld)) ? 1 / presentation.charge_fill_seconds : 1 / presentation.charge_decay_seconds;
        const step = rate * delta;
        visualCharge[direction] += Math.max(-step, Math.min(step, target - visualCharge[direction]));
        const button = poseGrid.querySelector(`[data-direction="${direction}"]`);
        if (button)
            button.style.backgroundColor = chargedColor(presentation.colors[direction] ?? DEFAULT_COLORS[direction], presentation.minimum_brightness, presentation.maximum_brightness, visualCharge[direction]);
    }
    requestAnimationFrame(animate);
}
requestAnimationFrame(animate);
function cancelBubblesPointer() {
    if (!bubblesPointer)
        return;
    const id = bubblesPointer.id;
    bubblesPointer = undefined;
    bubblesLocalCharge = 0;
    if (bubblesPad.hasPointerCapture(id))
        bubblesPad.releasePointerCapture(id);
}
function sendBubblesTrace(trace) {
    if (activeGame !== "bubbles" || bubblesSnapshot?.phase !== "active" || trace.length < 2 || !socket || socket.readyState !== WebSocket.OPEN)
        return;
    inputSeq += 1;
    store(STORAGE.inputSeq, String(inputSeq));
    socket.send(JSON.stringify({ type: "bubbles_trace", input_seq: inputSeq, trace }));
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
    bubblesPointer = { id: event.pointerId, trace };
    try {
        bubblesPad.setPointerCapture(event.pointerId);
    }
    catch {
        cancelBubblesPointer();
        return;
    }
    void requestImmersiveMode("bubbles");
});
bubblesPad.addEventListener("pointermove", event => {
    if (bubblesPointer?.id !== event.pointerId)
        return;
    event.preventDefault();
    for (const sample of event.getCoalescedEvents?.() ?? [event])
        bubblesPointer.trace.add(sample.clientX, sample.clientY);
    bubblesLocalCharge = bubblesPointer.trace.preview(bubblesSnapshot?.circles_to_charge ?? 1);
});
bubblesPad.addEventListener("pointerup", event => {
    if (bubblesPointer?.id !== event.pointerId)
        return;
    event.preventDefault();
    bubblesPointer.trace.add(event.clientX, event.clientY);
    const trace = bubblesPointer.trace.completed();
    cancelBubblesPointer();
    sendBubblesTrace(trace);
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
        void requestImmersiveMode("bubbles");
    }
    else if (event.key === " " || event.key === "Enter") {
        event.preventDefault();
        const circles = Math.max(1, Math.min(3, bubblesSnapshot?.circles_to_charge ?? 1));
        const trace = Array.from({ length: 97 }, (_, index) => [0.5 + 0.22 * Math.cos(index / 96 * Math.PI * 2 * circles), 0.5 + 0.22 * Math.sin(index / 96 * Math.PI * 2 * circles)]);
        sendBubblesTrace(trace);
        void requestImmersiveMode("bubbles");
    }
});
function showBubbles(message) {
    releaseHeld(false);
    bubblesSnapshot = message;
    bubblesSnapshotTime = performance.now();
    gameCard.hidden = true;
    playerCard.hidden = true;
    bubblesCard.hidden = false;
    const phase = message.phase ?? "waiting";
    const active = phase === "results" || (["instructions", "countdown", "active"].includes(phase) && message.left !== true);
    setGameplaySurface(active, "bubbles");
    bubblesHelp.textContent = phase === "results" ? "Check the shared screen for the final ranking" : phase === "active" ? "Swipe to move · Draw circles and release to spin" : "Watch the shared screen for GO";
    const score = Math.max(0, Math.floor(message.score ?? 0));
    bubblesScore.textContent = `${score} jellyfish`;
    const count = Math.min(Math.max(0, Math.floor(message.visual_jellyfish ?? 0)), Math.max(0, Math.floor(message.visual_cap ?? 0)), 64);
    bubblesCaptured.replaceChildren();
    for (let index = 0; index < count; index++) {
        const img = document.createElement("img");
        img.src = "/bubbles-jellyfish.png";
        img.alt = "";
        const angle = index * 2.39996323;
        const distance = Math.sqrt((index + 0.5) / Math.max(count, 1)) * 32;
        img.style.left = `${50 + Math.cos(angle) * distance}%`;
        img.style.top = `${50 + Math.sin(angle) * distance}%`;
        bubblesCaptured.append(img);
    }
    const colors = ["#5b8df2", "#4ecb8d", "#f6c453", "#9c72e8", "#ef7f45", "#55c7d9", "#e867b5", "#89b34c", "#7f91a8", "#d76464"];
    const seat = Math.max(1, Math.floor(message.seat ?? 1));
    bubblesCharacter.style.setProperty("--shape-color", colors[(seat - 1) % colors.length]);
    bubblesCharacter.className = `bubbles-character ${["", "triangle", "square"][(seat - 1) % 3]}`;
    bubblesReplica.style.setProperty("--bubble-scale", String(Math.min(1.48, Math.max(0.8, (message.bubble_radius ?? 48) / 48))));
    if (message.type === "bubbles_feedback") {
        bubblesFeedbackUntil = performance.now() + 1800;
        if (message.event === "captured") {
            bubblesStatus.textContent = `Jellyfish collected. ${score} held.`;
            vibrate(18);
        }
        else if (message.event === "spin") {
            bubblesStatus.textContent = "Spin active! Swipe to keep moving.";
            vibrate([20, 30, 20]);
        }
        else if (message.event === "pop") {
            bubblesStatus.textContent = `Bubble popped. ${message.lost ?? 0} jellyfish lost. Re-forming.`;
            vibrate([35, 45, 35]);
        }
    }
    else if (phase === "results")
        bubblesStatus.textContent = message.rank ? `Round complete. You placed #${message.rank} with ${score} jellyfish.` : `Round complete with ${score} jellyfish.`;
    else if (performance.now() >= bubblesFeedbackUntil) {
        if (phase === "active")
            bubblesStatus.textContent = "Swipe to move. Draw circles and release to spin.";
        else if (phase === "countdown")
            bubblesStatus.textContent = "Get ready. Watch the shared screen for GO.";
        else if (phase === "instructions")
            bubblesStatus.textContent = "Watch the shared screen for instructions.";
        else
            bubblesStatus.textContent = "Waiting for the next game.";
    }
}
function animateBubbles(now) {
    if (activeGame === "bubbles" && bubblesSnapshot) {
        if (bubblesSnapshot.phase === "active" && bubblesFeedbackUntil > 0 && now >= bubblesFeedbackUntil) {
            bubblesFeedbackUntil = 0;
            bubblesStatus.textContent = "Swipe to move. Draw circles and release to spin.";
        }
        const elapsed = Math.max(0, now - bubblesSnapshotTime);
        const spin = Math.max(0, (bubblesSnapshot.spin_remaining_msec ?? 0) - elapsed);
        const cooldown = Math.max(0, (bubblesSnapshot.cooldown_remaining_msec ?? 0) - elapsed);
        const invulnerable = Math.max(0, (bubblesSnapshot.invulnerable_remaining_msec ?? 0) - elapsed);
        const reform = Math.max(0, (bubblesSnapshot.reform_remaining_msec ?? 0) - elapsed);
        const fraction = bubblesSnapshot.phase !== "active" ? 0 : spin > 0 ? spin / Math.max(1, bubblesSnapshot.spin_duration_msec ?? 1) : cooldown > 0 ? 1 - cooldown / Math.max(1, bubblesSnapshot.cooldown_duration_msec ?? 1) : bubblesLocalCharge;
        bubblesMeter.style.setProperty("--meter-offset", String(635 * (1 - Math.max(0, Math.min(1, fraction)))));
        bubblesState.textContent = bubblesSnapshot.phase === "results" ? (bubblesSnapshot.rank ? `Rank #${bubblesSnapshot.rank}` : "Round complete") : bubblesSnapshot.phase !== "active" ? "Get ready" : reform > 0 ? "Re-forming" : invulnerable > 0 ? "Protected" : spin > 0 ? "Spinning" : cooldown > 0 ? `Cooldown ${Math.ceil(cooldown / 1000)}s` : bubblesPointer ? "Charging spin" : "Spin ready";
        bubblesReplica.classList.toggle("is-reforming", reform > 0);
    }
    requestAnimationFrame(animateBubbles);
}
requestAnimationFrame(animateBubbles);
function showGame(message) {
    bubblesCard.hidden = true;
    playerCard.hidden = true;
    gameCard.hidden = false;
    const phase = message.phase ?? "waiting";
    gameHeading.textContent = phase === "countdown" ? "Get ready!" : phase === "genuine_stop_grace" ? "Hold a pose!" : "Watch the big screen";
    gameMessage.textContent = message.message ?? (phase === "genuine_stop_grace" ? "Music stopped! Hold your pose." : "Keep watching the shared screen.");
    const player = message.player;
    const lifeCount = message.lives ?? player?.lives;
    if (message.debug_mode === true)
        lives.textContent = "Lives: DEBUG";
    else if (Number.isInteger(lifeCount))
        lives.textContent = `Lives: ${"♥".repeat(Math.max(0, lifeCount))}${"♡".repeat(Math.max(0, 2 - lifeCount))}`;
    const eliminated = message.eliminated === true || player?.eliminated === true;
    readPresentation(message.presentation);
    if (player)
        updateCharge(player);
    if (eliminated) {
        releaseHeld();
        setGameplaySurface(false);
        gameHeading.textContent = "You've been eliminated :(";
        gameMessage.textContent = "Keep watching the big screen for the results.";
        poseGrid.replaceChildren();
    }
    else if (message.type === "flash_pose_result")
        gameHeading.textContent = message.success ? "Pose locked!" : "Keep dancing!";
    else if (["countdown", "dance", "genuine_stop_grace", "resolve", "flash_wait"].includes(phase) || message.type === "flash_pose_challenge") {
        renderControls(message.available_directions ?? directions);
        setGameplaySurface(true);
    }
    else if (message.type === "flash_pose_results") {
        releaseHeld();
        setGameplaySurface(false);
        gameHeading.textContent = message.placement ? `You placed #${message.placement}` : "Round complete";
        gameMessage.textContent = "Check the big screen for the final results.";
        poseGrid.replaceChildren();
    }
    else {
        releaseHeld();
        setGameplaySurface(false);
        poseGrid.replaceChildren();
    }
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
    if (stopped || retry !== undefined)
        return;
    setGameplaySurface(false);
    if (joined) {
        playerState.textContent = "Reconnecting";
        leaveButton.disabled = true;
    }
    else
        joinForm.hidden = true;
    status.textContent = "Host disconnected. Reconnecting…";
    retry = setTimeout(() => { retry = undefined; void connect(); }, 2000);
}
async function connect() {
    status.textContent = joined ? "Reconnecting to the host…" : "Connecting to the host…";
    try {
        const response = await fetch("/session.json", { cache: "no-store", signal: AbortSignal.timeout(5000) });
        if (!response.ok)
            throw new Error("Session unavailable");
        const config = await response.json();
        if (!config || typeof config !== "object" || !("protocol" in config) || config.protocol !== 1 || !("websocket_port" in config) || !Number.isInteger(config.websocket_port) || Number(config.websocket_port) < 1024 || Number(config.websocket_port) > 65535 || !("session_id" in config) || typeof config.session_id !== "string")
            throw new Error("Unsupported session");
        if (stopped)
            return;
        const peer = new WebSocket(`ws://${location.hostname}:${config.websocket_port}`);
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
                    releaseHeld(false);
                    if (message.gameplay)
                        showGame(message.gameplay);
                    return;
                }
                if (message.resume_status === "session_restarted") {
                    forgetIdentity();
                    showJoin("The host started a new session. Join again with your name.", true);
                }
                else if (message.resume_status === "expired") {
                    forgetIdentity();
                    showJoin("Your previous player expired. Join again with your name.", true);
                }
                else
                    showJoin("Connected. Enter your name to join.", true);
            }
            else if (message.type === "join_accepted") {
                if (!rememberIdentity(message))
                    peer.close();
            }
            else if (message.type === "join_rejected" || message.type === "error") {
                joinButton.disabled = false;
                status.textContent = message.message ?? "The host could not complete that action.";
                if (activeGame === "bubbles")
                    bubblesStatus.textContent = message.message ?? "Gesture rejected by the host.";
                if (!joined)
                    nameInput.focus();
            }
            else if (message.type === "left") {
                forgetIdentity();
                showJoin("You left the lobby. Enter a name to join again.", true);
            }
            else if (message.type === "flash_pose_charge")
                updateCharge(message);
            else if (["flash_pose_snapshot", "flash_pose_challenge", "flash_pose_result", "flash_pose_results"].includes(message.type ?? ""))
                showGame(message);
            else if (message.type === "bubbles_trace_result") {
                bubblesLocalCharge = 0;
                if (message.action === "none") {
                    bubblesStatus.textContent = message.reason === "spin_cooldown" ? "Spin is cooling down. Swipes still move you." : "Keep drawing a complete circle to spin.";
                    bubblesFeedbackUntil = performance.now() + 1800;
                }
            }
            else if (message.type === "bubbles_snapshot" || message.type === "bubbles_feedback")
                showBubbles(message);
            else if (message.type === "lobby") {
                releaseHeld(false);
                setGameplaySurface(false);
                bubblesCard.hidden = true;
                bubblesSnapshot = undefined;
                if (message.player)
                    rememberIdentity(message);
                else if (joined) {
                    gameCard.hidden = true;
                    playerCard.hidden = false;
                    playerState.textContent = "Waiting for the next game";
                    status.textContent = message.message ?? "Waiting for the next game";
                }
            }
        };
        peer.onclose = event => { clearTimeout(deadline); releaseHeld(false); if (socket === peer)
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
    return;
} joinButton.disabled = true; status.textContent = "Joining…"; socket.send(JSON.stringify({ type: "join", name })); });
leaveButton.addEventListener("click", () => { if (!socket || socket.readyState !== WebSocket.OPEN)
    return; leaveButton.disabled = true; status.textContent = "Leaving…"; socket.send(JSON.stringify({ type: "leave" })); });
addEventListener("orientationchange", updateOrientation);
addEventListener("resize", updateOrientation);
window.addEventListener("pagehide", () => { stopped = true; releaseHeld(false); clearTimeout(retry); retry = undefined; socket?.close(); });
window.addEventListener("pageshow", event => { if (event.persisted) {
    stopped = false;
    void connect();
} });
void connect();
