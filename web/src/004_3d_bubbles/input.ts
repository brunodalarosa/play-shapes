import type { Pair, Snapshot } from "./types.js";

export type InputMessage =
  | { type: "bubbles_3d_touch"; input_seq: number; stage: "start" | "cancel" }
  | { type: "bubbles_3d_touch"; input_seq: number; stage: "drag"; drag: Pair }
  | { type: "bubbles_3d_release"; input_seq: number; displacement: Pair };

export function canTouch(snapshot: Snapshot | undefined, connected: boolean): boolean {
  return connected && snapshot?.phase === "active" && snapshot.connected && !snapshot.left;
}

export function displacement(start: Pair, end: Pair, size: Pair): Pair {
  return end.map((value, index) => {
    const share = (value - start[index]) / Math.max(1, size[index]);
    return Math.max(-1, Math.min(1, share));
  }) as Pair;
}

export function quantize(value: Pair): Pair {
  return value.map((axis) => Math.max(-4, Math.min(4, Math.round(axis * 10))) || 0) as Pair;
}

export class TouchInput {
  private touch?: {
    seq: number;
    start: Pair;
    size: Pair;
    current: Pair;
    sent: Pair;
    last: number;
    count: number;
  };

  constructor(
    private readonly available: () => boolean,
    private readonly nextSequence: () => number,
    private readonly send: (message: InputMessage) => void,
  ) {}

  start(point: Pair, size: Pair, now: number): boolean {
    if (!this.available() || this.touch) return false;

    const seq = this.nextSequence();
    this.touch = { seq, start: point, size, current: [0, 0], sent: [0, 0], last: now, count: 0 };
    this.send({ type: "bubbles_3d_touch", input_seq: seq, stage: "start" });
    return true;
  }

  move(point: Pair, now: number): void {
    if (!this.touch) return;

    this.touch.current = quantize(displacement(this.touch.start, point, this.touch.size));
    this.tick(now);
  }

  tick(now: number): void {
    const touch = this.touch;
    if (!touch || !this.available()) return;

    const changed = touch.current.some((axis, index) => axis !== touch.sent[index]);
    const elapsed = now - touch.last;
    if (touch.count >= 48 || elapsed < 70 || (!changed && elapsed < 600)) return;

    this.send({
      type: "bubbles_3d_touch",
      input_seq: touch.seq,
      stage: "drag",
      drag: [...touch.current],
    });
    touch.sent = [...touch.current];
    touch.last = now;
    touch.count++;
  }

  release(point: Pair): void {
    const touch = this.touch;
    this.touch = undefined;
    if (!touch || !this.available()) return;

    this.send({
      type: "bubbles_3d_release",
      input_seq: touch.seq,
      displacement: displacement(touch.start, point, touch.size),
    });
  }

  cancel(): void {
    const touch = this.touch;
    this.touch = undefined;
    if (touch && this.available())
      this.send({ type: "bubbles_3d_touch", input_seq: touch.seq, stage: "cancel" });
  }
}
