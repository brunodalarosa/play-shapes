import { MotionInput, type MotionSample } from "./motion_input.js";

export type MotionSubscription = { subscription_id: string; send_hz: number; stale_msec: number };
export type MotionControlState = {
  calibrated: boolean;
  usable: boolean;
  capture_state: string;
  accepted?: boolean;
  reason?: string;
};
export type MotionStreamReading = {
  diagnostics: Record<string, unknown>;
  sample: MotionSample;
  transmittedHz: number;
};

export class MotionStream {
  private timer: ReturnType<typeof setInterval> | undefined;
  private subscription: MotionSubscription | undefined;
  private sequence = 0;
  private statusAt = -Infinity;
  private sampleAt = -Infinity;
  private sent = 0;
  private started = 0;
  private interval = 34;
  private statusState = "";
  controlState: MotionControlState | undefined;
  onControlState: ((state: MotionControlState) => void) | undefined;

  constructor(
    private connection: () => WebSocket | undefined,
    private reading: (value: MotionStreamReading) => void = () => {},
    private input = new MotionInput(),
    private maximumBufferedBytes = 0,
  ) {}

  get active(): boolean {
    return !!this.subscription;
  }

  private visibility = (): void => {
    if (document.hidden) this.input.suspend();
    else this.input.resume();
    this.tick();
  };

  private pagehide = (): void => {
    this.stop();
  };

  begin(subscription: MotionSubscription): void {
    this.stop();
    this.subscription = subscription;
    this.sequence = this.sent = 0;
    this.started = performance.now();
    this.statusAt = this.sampleAt = -Infinity;
    this.statusState = "";
    this.interval = Math.ceil(1000 / Math.max(1, Math.min(30, subscription.send_hz)));
    document.addEventListener("visibilitychange", this.visibility);
    window.addEventListener("pagehide", this.pagehide);
    this.timer = setInterval(() => this.tick(), this.interval);
    this.tick();
  }

  stop(subscriptionId?: string): boolean {
    if (subscriptionId !== undefined && subscriptionId !== this.subscription?.subscription_id)
      return false;
    clearInterval(this.timer);
    this.timer = undefined;
    this.subscription = undefined;
    this.controlState = undefined;
    this.input.stop();
    document.removeEventListener("visibilitychange", this.visibility);
    window.removeEventListener("pagehide", this.pagehide);
    return true;
  }

  async requestPermission(): Promise<void> {
    if (!this.active) return;
    const request = this.input.requestPermission();
    this.tick();
    await request;
    if (this.active && document.hidden) this.input.suspend();
    this.tick();
  }

  requestCalibration(context?: { generation: string; round_token: string }): boolean {
    return this.send({ type: "motion_calibrate", ...context });
  }

  feedback(subscriptionId: string, state: MotionControlState): boolean {
    if (subscriptionId !== this.subscription?.subscription_id) return false;
    if (
      typeof state?.calibrated !== "boolean" ||
      typeof state.usable !== "boolean" ||
      typeof state.capture_state !== "string"
    )
      return false;
    this.controlState = { ...state };
    this.onControlState?.({ ...state });
    return true;
  }

  private send(payload: Record<string, unknown>): boolean {
    const socket = this.connection();
    if (
      !this.subscription ||
      socket?.readyState !== WebSocket.OPEN ||
      socket.bufferedAmount > this.maximumBufferedBytes
    )
      return false;
    socket.send(JSON.stringify({ ...payload, subscription_id: this.subscription.subscription_id }));
    return true;
  }

  tick(): void {
    if (!this.subscription) return;
    const socket = this.connection();
    const diagnostics = {
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
    const now = performance.now();
    const transmittedHz = this.sent / Math.max((now - this.started) / 1000, 0.001);
    // Transitions are attempted immediately; periodic status recovers host coalescing.
    if (
      (now - this.statusAt >= 250 || diagnostics.state !== this.statusState) &&
      this.send({ type: "motion_status", diagnostics, transmitted_hz: transmittedHz })
    ) {
      this.statusAt = now;
      this.statusState = diagnostics.state;
    }
    const sample = this.input.sample();
    if (
      this.input.active &&
      !document.hidden &&
      diagnostics.state === "live" &&
      now - this.sampleAt >= this.interval &&
      this.send({ type: "motion_sample", sequence: this.sequence + 1, sample })
    ) {
      this.sequence++;
      this.sent++;
      this.sampleAt = now;
    }
    this.reading({
      diagnostics,
      sample,
      transmittedHz: this.sent / Math.max((now - this.started) / 1000, 0.001),
    });
  }
}
