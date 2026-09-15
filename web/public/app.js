const status = document.querySelector("#status");
const joinForm = document.querySelector("#join-form");
const nameInput = document.querySelector("#player-name");
const joinButton = document.querySelector("#join-button");
const playerCard = document.querySelector("#player-card");
const playerName = document.querySelector("#player-name-heading");
const playerState = document.querySelector("#player-state");
const leaveButton = document.querySelector("#leave-button");
const STORAGE = {
    session: "play-shapes.session-id",
    token: "play-shapes.reconnect-token",
    name: "play-shapes.last-name",
};
let socket;
let retry;
let stopped = false;
let joined = false;
function stored(key) {
    try {
        return localStorage.getItem(key) ?? "";
    }
    catch {
        return "";
    }
}
function store(key, value) {
    try {
        localStorage.setItem(key, value);
    }
    catch { /* Joining still works for this page. */ }
}
function forgetIdentity() {
    try {
        localStorage.removeItem(STORAGE.session);
        localStorage.removeItem(STORAGE.token);
    }
    catch { /* Nothing else can be cleared in restricted storage. */ }
}
function showJoin(message, focus = false) {
    joined = false;
    playerCard.hidden = true;
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
    joinForm.hidden = true;
    playerCard.hidden = false;
    playerName.textContent = player.name;
    playerState.textContent = state;
    leaveButton.disabled = false;
    status.textContent = state === "Connected" ? "Joined. Keep this page open while you play." : state;
}
function rememberIdentity(message) {
    if (!message.player || typeof message.player.name !== "string" ||
        typeof message.session_id !== "string" || typeof message.reconnect_token !== "string")
        return false;
    store(STORAGE.name, message.player.name);
    store(STORAGE.session, message.session_id);
    store(STORAGE.token, message.reconnect_token);
    showJoined(message.player);
    return true;
}
function reconnect() {
    if (stopped || retry !== undefined)
        return;
    if (joined) {
        playerState.textContent = "Reconnecting";
        leaveButton.disabled = true;
    }
    else {
        joinForm.hidden = true;
    }
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
        if (!config || typeof config !== "object" || !("protocol" in config) || config.protocol !== 1 ||
            !("websocket_port" in config) || !Number.isInteger(config.websocket_port) ||
            Number(config.websocket_port) < 1024 || Number(config.websocket_port) > 65535 ||
            !("session_id" in config) || typeof config.session_id !== "string") {
            throw new Error("Unsupported session");
        }
        if (stopped)
            return;
        const peer = new WebSocket(`ws://${location.hostname}:${config.websocket_port}`);
        socket = peer;
        const deadline = setTimeout(() => peer.close(), 7000);
        peer.onopen = () => {
            const reconnectToken = stored(STORAGE.token);
            const priorSession = stored(STORAGE.session);
            peer.send(JSON.stringify({
                type: "hello",
                protocol: 1,
                ...(reconnectToken ? { reconnect_token: reconnectToken, session_id: priorSession } : {}),
            }));
        };
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
                if (message.resume_status === "resumed" && rememberIdentity(message))
                    return;
                if (message.resume_status === "session_restarted") {
                    forgetIdentity();
                    showJoin("The host started a new session. Join again with your name.", true);
                }
                else if (message.resume_status === "expired") {
                    forgetIdentity();
                    showJoin("Your previous player expired. Join again with your name.", true);
                }
                else {
                    showJoin("Connected. Enter your name to join.", true);
                }
            }
            else if (message.type === "join_accepted") {
                if (!rememberIdentity(message))
                    peer.close();
            }
            else if (message.type === "join_rejected" || message.type === "error") {
                joinButton.disabled = false;
                status.textContent = message.message ?? "The host could not complete that action.";
                if (!joined)
                    nameInput.focus();
            }
            else if (message.type === "left") {
                forgetIdentity();
                showJoin("You left the lobby. Enter a name to join again.", true);
            }
        };
        peer.onclose = event => {
            clearTimeout(deadline);
            if (socket === peer)
                socket = undefined;
            if (event.code === 4000) {
                stopped = true;
                leaveButton.disabled = true;
                status.textContent = "This player continued in another tab.";
                playerState.textContent = "Open in another tab";
                return;
            }
            reconnect();
        };
        peer.onerror = () => peer.close();
    }
    catch {
        reconnect();
    }
}
joinForm.addEventListener("submit", event => {
    event.preventDefault();
    const name = nameInput.value.trim();
    store(STORAGE.name, name);
    if (!socket || socket.readyState !== WebSocket.OPEN) {
        status.textContent = "Still connecting. Try again in a moment.";
        return;
    }
    joinButton.disabled = true;
    status.textContent = "Joining…";
    socket.send(JSON.stringify({ type: "join", name }));
});
leaveButton.addEventListener("click", () => {
    if (!socket || socket.readyState !== WebSocket.OPEN)
        return;
    leaveButton.disabled = true;
    status.textContent = "Leaving…";
    socket.send(JSON.stringify({ type: "leave" }));
});
window.addEventListener("pagehide", () => {
    stopped = true;
    clearTimeout(retry);
    retry = undefined;
    socket?.close();
});
window.addEventListener("pageshow", event => {
    if (event.persisted) {
        stopped = false;
        void connect();
    }
});
void connect();
export {};
