import type { Frame, Message, Snapshot, Visual } from "./types.js";

export function isSnapshot(value: unknown): value is Snapshot {
  if (!value || typeof value !== "object") return false;

  const type = (value as { type?: string }).type;
  return type === "bubbles_3d_snapshot" || type === "bubbles_3d_feedback";
}

export class BubbleState {
  snapshot?: Snapshot;
  private snapshotAt = 0;
  private visual?: Visual;
  private visualAt = 0;

  receive(message: Message, now: number): boolean {
    if (isSnapshot(message)) {
      if (this.snapshot && message.host_time_msec < this.snapshot.host_time_msec) return false;

      this.snapshot = message;
      this.snapshotAt = now;
      if (this.visual && this.visual.host_time_msec <= message.host_time_msec)
        this.visual = undefined;
      return true;
    }
    if (message.type === "bubbles_3d_visual" && this.snapshot) {
      const minimum = this.visual?.host_time_msec ?? this.snapshot.host_time_msec;
      if (message.visual.host_time_msec < minimum) return false;

      this.visual = message.visual;
      this.visualAt = now;
      return true;
    }
    return false;
  }

  frame(now: number): Frame | undefined {
    const snapshot = this.snapshot;
    if (!snapshot) return;

    const elapsed = Math.max(0, now - this.snapshotAt);
    const running = snapshot.phase === "active" || snapshot.phase === "countdown";
    const age = running ? elapsed : 0;
    const reform = snapshot.visual_tuning.bubble_reform_seconds * 1000;
    const remaining = Math.max(0, snapshot.reform_remaining_msec - age);
    const popAge =
      snapshot.reform_remaining_msec > 0
        ? reform - snapshot.reform_remaining_msec + age
        : snapshot.event === "pop"
          ? age
          : -1;
    const visual = this.visual;
    if (visual) {
      const visualAge = running ? Math.max(0, now - this.visualAt) : 0;
      return {
        snapshot,
        visual: {
          ...visual,
          host_time_msec: visual.host_time_msec + visualAge,
          pop_age_msec: visual.pop_age_msec < 0 ? -1 : visual.pop_age_msec + visualAge,
        },
      };
    }
    return {
      snapshot,
      visual: {
        host_time_msec: snapshot.host_time_msec + age,
        radius: snapshot.bubble_radius * Math.max(0.08, 1 - remaining / Math.max(1, reform)),
        stretch: [0, 0],
        velocity: [0, 0],
        white: snapshot.invulnerable_remaining_msec > age,
        pop_age_msec: popAge,
        caught: snapshot.visual_jellyfish,
      },
    };
  }
}

export async function choosePresentation<T>(
  create: () => Promise<T>,
  fallback: () => T,
): Promise<T> {
  try {
    return await create();
  } catch {
    return fallback();
  }
}
