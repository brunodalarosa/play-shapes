import { MotionInput, type MotionSample } from "./motion_input.js";
import { MotionStream, type MotionSubscription } from "./motion_stream.js";

export type { MotionSubscription } from "./motion_stream.js";
export class MotionLabController {
  private stream: MotionStream;
  constructor(
    private panel: HTMLElement,
    private button: HTMLButtonElement,
    readings: HTMLElement,
    connection: () => WebSocket | undefined,
  ) {
    this.stream = new MotionStream(
      connection,
      (value) => {
        readings.textContent = [
          JSON.stringify(value.diagnostics, null, 2),
          `Sent: ${value.transmittedHz.toFixed(1)} Hz`,
          formatSample(value.sample),
        ].join("\n");
      },
      new MotionInput(),
      8191,
    );
    // Both permission calls happen synchronously in this gesture.
    button.addEventListener("click", () => {
      if (!this.active) return;
      button.disabled = true;
      void this.stream.requestPermission().finally(() => {
        button.disabled = false;
      });
    });
  }
  get active(): boolean {
    return this.stream.active;
  }
  begin(subscription: MotionSubscription): void {
    this.stream.begin(subscription);
    this.panel.hidden = false;
    this.button.disabled = false;
  }
  stop(subscriptionId?: string): void {
    if (this.stream.stop(subscriptionId)) this.panel.hidden = true;
  }
  disconnect(): void {
    this.stop();
  }
  private tick(): void {
    this.stream.tick();
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
