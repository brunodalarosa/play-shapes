import { MotionInput, type MotionSample } from "./motion_input.js";

export type MotionSubscription = { subscription_id: string; send_hz: number; stale_msec: number };
export class MotionLabController {
  private timer: ReturnType<typeof setInterval> | undefined;
  private subscription: MotionSubscription | undefined;
  private sequence = 0;
  private statusAt = -Infinity;
  private sent = 0;
  private started = 0;
  private input = new MotionInput();
  constructor(
    private panel: HTMLElement,
    private button: HTMLButtonElement,
    private readings: HTMLElement,
    private connection: () => WebSocket | undefined,
  ) {
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
      if (!this.subscription) return;
      if (document.hidden) this.input.suspend();
      else this.input.resume();
      this.tick();
    });
    window.addEventListener("pagehide", () => this.stop());
  }
  get active(): boolean {
    return !!this.subscription;
  }
  begin(subscription: MotionSubscription): void {
    this.stop();
    this.subscription = subscription;
    this.sequence = this.sent = 0;
    this.started = performance.now();
    this.statusAt = -Infinity;
    this.panel.hidden = false;
    this.button.disabled = false;
    this.timer = setInterval(
      () => this.tick(),
      Math.ceil(1000 / Math.max(1, Math.min(30, subscription.send_hz))),
    );
    this.tick();
  }
  stop(): void {
    clearInterval(this.timer);
    this.timer = undefined;
    this.subscription = undefined;
    this.input.stop();
    this.panel.hidden = true;
  }
  disconnect(): void {
    this.stop();
  }
  private diagnostics(socket: WebSocket | undefined) {
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
  private tick(): void {
    if (!this.subscription) return;
    const socket = this.connection(),
      diagnostics = this.diagnostics(socket),
      sample = this.input.sample();
    const send = (payload: Record<string, unknown>): boolean => {
      if (socket?.readyState !== WebSocket.OPEN || socket.bufferedAmount >= 8192) return false;
      socket.send(
        JSON.stringify({ ...payload, subscription_id: this.subscription!.subscription_id }),
      );
      return true;
    };
    // Periodic status recovers states coalesced by the host's rate limit.
    const transmittedHz = this.sent / Math.max((performance.now() - this.started) / 1000, 0.001);
    if (
      performance.now() - this.statusAt >= 250 &&
      send({ type: "motion_status", diagnostics, transmitted_hz: transmittedHz })
    )
      this.statusAt = performance.now();
    if (
      this.input.active &&
      !document.hidden &&
      diagnostics.state === "live" &&
      send({ type: "motion_sample", sequence: ++this.sequence, sample })
    )
      this.sent++;
    const elapsedSeconds = Math.max((performance.now() - this.started) / 1000, 0.001);
    this.readings.textContent = [
      JSON.stringify(diagnostics, null, 2),
      `Sent: ${(this.sent / elapsedSeconds).toFixed(1)} Hz`,
      formatSample(sample),
    ].join("\n");
  }
}
function formatSample(sample: MotionSample): string {
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
    "null = unavailable",
  ].join("\n");
}
