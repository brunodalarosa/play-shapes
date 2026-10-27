/**
 * A row of hearts, each a spare respawn, counted in simulation ticks. The same rules as
 * components/flappy_flight/heart_row.gd.
 *
 * Full hearts are always the leftmost ones, so the leftmost empty heart is the one at index
 * `full`, and only it refills. A hit spends the rightmost full heart; the refill progress stays
 * and now belongs to the new leftmost empty heart. A hit with no full heart leaves a heart
 * `owed`, spent as soon as the next refill completes.
 */
export class HeartRow {
  count: number;
  full: number;
  /** Ticks of progress on the leftmost empty heart. */
  refillTicks = 0;
  owed = false;
  recoveryTicks: number;

  constructor(heartCount: number, heartRecoveryTicks: number) {
    this.count = heartCount;
    this.full = heartCount;
    this.recoveryTicks = heartRecoveryTicks;
  }

  /** Advances the refill by one tick. Returns true when a heart finished refilling. */
  tick(): boolean {
    if (this.full >= this.count) return false;

    this.refillTicks += 1;
    if (this.refillTicks < this.recoveryTicks) return false;

    this.refillTicks = 0;
    if (this.owed) this.owed = false;
    else this.full += 1;
    return true;
  }

  hit(): void {
    if (this.full > 0) this.full -= 1;
    else this.owed = true;
  }

  /** How far the leftmost empty heart has refilled, 0 to 1. */
  refillShare(): number {
    return this.refillTicks / this.recoveryTicks;
  }

  copyFrom(other: HeartRow): void {
    this.count = other.count;
    this.full = other.full;
    this.refillTicks = other.refillTicks;
    this.owed = other.owed;
    this.recoveryTicks = other.recoveryTicks;
  }
}
