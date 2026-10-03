import { MotionInput } from "./motion_input.js";
export class MotionLabController {
    panel;
    button;
    readings;
    connection;
    timer;
    subscription;
    sequence = 0;
    statusAt = -Infinity;
    sent = 0;
    started = 0;
    input = new MotionInput();
    constructor(panel, button, readings, connection) {
        this.panel = panel;
        this.button = button;
        this.readings = readings;
        this.connection = connection;
        // This is the sole sensor activation action; never await fullscreen first.
        button.addEventListener("click", () => {
            button.disabled = true;
            const request = this.input.requestPermission();
            this.tick();
            void request.finally(() => {
                button.disabled = false;
                this.tick();
            });
        });
        document.addEventListener("visibilitychange", () => {
            if (!this.subscription)
                return;
            if (document.hidden)
                this.input.suspend();
            else
                this.input.resume();
            this.tick();
        });
        window.addEventListener("pagehide", () => this.stop());
    }
    get active() {
        return !!this.subscription;
    }
    begin(subscription) {
        this.stop();
        this.subscription = subscription;
        this.sequence = this.sent = 0;
        this.started = performance.now();
        this.statusAt = -Infinity;
        this.panel.hidden = false;
        this.button.disabled = false;
        this.timer = setInterval(() => this.tick(), Math.ceil(1000 / Math.max(1, Math.min(30, subscription.send_hz))));
        this.tick();
    }
    stop() {
        clearInterval(this.timer);
        this.timer = undefined;
        this.subscription = undefined;
        this.input.stop();
        this.panel.hidden = true;
    }
    disconnect() {
        this.stop();
    }
    diagnostics(socket) {
        return {
            ...this.input.capabilities(),
            page_protocol: location.protocol,
            hostname: location.hostname,
            websocket_protocol: socket
                ? new URL(socket.url).protocol
                : location.protocol === "https:"
                    ? "wss:"
                    : "ws:",
            websocket_status: socket?.readyState === WebSocket.OPEN ? "open" : "closed",
        };
    }
    tick() {
        if (!this.subscription)
            return;
        const socket = this.connection(), diagnostics = this.diagnostics(socket), sample = this.input.sample();
        const send = (payload) => {
            if (socket?.readyState !== WebSocket.OPEN || socket.bufferedAmount >= 8192)
                return false;
            socket.send(JSON.stringify({ ...payload, subscription_id: this.subscription.subscription_id }));
            return true;
        };
        // Periodic status recovers states coalesced by the host's rate limit.
        const transmittedHz = this.sent / Math.max((performance.now() - this.started) / 1000, 0.001);
        if (performance.now() - this.statusAt >= 250 &&
            send({ type: "motion_status", diagnostics, transmitted_hz: transmittedHz }))
            this.statusAt = performance.now();
        if (this.input.active &&
            !document.hidden &&
            diagnostics.state === "live" &&
            send({ type: "motion_sample", sequence: ++this.sequence, sample }))
            this.sent++;
        this.readings.textContent = `${JSON.stringify(diagnostics, null, 2)}\nSent: ${(this.sent / Math.max((performance.now() - this.started) / 1000, 0.001)).toFixed(1)} Hz\n${formatSample(sample)}`;
    }
}
function formatSample(sample) {
    return `Orientation [alpha, beta, gamma] degrees\n${JSON.stringify(sample.orientation)} (${sample.absolute ? "absolute" : "relative"})\nRotation [alpha, beta, gamma] degrees/s\n${JSON.stringify(sample.rotation_rate)}\nAcceleration [x,y,z] m/s²\n${JSON.stringify(sample.acceleration)}\nIncluding gravity [x,y,z] m/s²\n${JSON.stringify(sample.acceleration_gravity)}\nEvent interval: ${sample.interval_msec ?? "unavailable"} ms\nMotion: ${sample.motion_hz.toFixed(1)} Hz, age ${sample.motion_age_msec ?? "unavailable"} ms\nOrientation: ${sample.orientation_hz.toFixed(1)} Hz, age ${sample.orientation_age_msec ?? "unavailable"} ms\nScreen angle: ${sample.screen_angle}°\nnull = unavailable`;
}
