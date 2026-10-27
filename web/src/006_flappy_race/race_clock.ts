import { TICK_RATE } from "../flappy_flight/tuning.js";

/**
 * The phone's reading of the host's race clock, in ticks since GO; negative in the countdown.
 *
 * Every host message says what the host's clock read when it was sent. Arriving later by its
 * travel time, it puts GO at least that much later than it really was, so the earliest GO any
 * message implies is the closest, and never ahead of the host. The reading only moves forward.
 */
export class RaceClock {
  private go?: number;

  /** A host message reading `clockTick` arrived at local time `now`, in milliseconds. */
  observe(clockTick: number, now: number): void {
    const go = now - (clockTick * 1000) / TICK_RATE;
    if (this.go === undefined || go < this.go) this.go = go;
  }

  get started(): boolean {
    return this.go !== undefined;
  }

  /** Whole ticks since GO at local time `now`. */
  tick(now: number): number {
    if (this.go === undefined) return Number.NEGATIVE_INFINITY;

    return Math.floor(((now - this.go) * TICK_RATE) / 1000);
  }

  /** Milliseconds from `now` to GO; zero once the race runs. */
  untilGo(now: number): number {
    return this.go === undefined ? 0 : Math.max(0, this.go - now);
  }
}
