import { FlappyFlight, FlappyFlightState } from "../flappy_flight/flight.js";

/** Furthest a single advance or replay steps; anything older takes the host's state as it is. */
export const MOST_TICKS = 600;

/** True when two flights are exactly the same, field by field. */
export function sameFlight(a: FlappyFlightState, b: FlappyFlightState): boolean {
  if (
    a.x !== b.x ||
    a.y !== b.y ||
    a.verticalSpeed !== b.verticalSpeed ||
    a.flying !== b.flying ||
    a.ready !== b.ready ||
    a.cooldownTicks !== b.cooldownTicks ||
    a.invulnerableTicks !== b.invulnerableTicks ||
    a.boostTicks !== b.boostTicks ||
    a.obstacleIndex !== b.obstacleIndex ||
    a.hearts.full !== b.hearts.full ||
    a.hearts.refillTicks !== b.hearts.refillTicks ||
    a.hearts.owed !== b.hearts.owed ||
    a.taken.length !== b.taken.length
  )
    return false;

  return a.taken.every((taken, index) => taken === b.taken[index]);
}

/**
 * The phone's own flight, predicted from its own taps on the shared step (decision 0047) and
 * corrected by the host's settled state (decision 0048).
 *
 * It keeps the state after every tick the host has not settled yet, and the taps it applied.
 * A host state that matches its own tick changes nothing. One that differs replaces that tick
 * and the taps after it are played again, and the drawn position blends the difference out,
 * unless the flight changed between flying and waiting, which shows at once.
 */
export class FlappyPrediction {
  /** The tick `state` has been stepped to. */
  tick: number;
  state: FlappyFlightState;
  /** Host corrections so far, for tests and diagnostics. */
  corrections = 0;
  /** Drawn minus predicted position, metres; it decays to zero. */
  offsetX = 0;
  offsetY = 0;
  private history = new Map<number, FlappyFlightState>();
  private taps = new Set<number>();

  constructor(
    readonly flight: FlappyFlight,
    state: FlappyFlightState,
    tick: number,
  ) {
    this.state = state;
    this.tick = tick;
  }

  get finished(): boolean {
    return this.state.x >= this.flight.course.finish_x;
  }

  /** Applies a touch-down at the next tick and returns that tick, for flappy_tap. */
  tap(): number {
    const tick = this.tick + 1;
    this.taps.add(tick);
    return tick;
  }

  /**
   * Steps toward `target`, at most MOST_TICKS at a time so a page back from the background
   * catches up over a few frames, and stopping at the finish line. Returns the event bits.
   */
  advanceTo(target: number): number {
    let events = 0;
    const last = Math.min(target, this.tick + MOST_TICKS);
    while (this.tick < last && !this.finished) {
      this.tick += 1;
      events |= this.flight.step(this.state, this.taps.has(this.tick));
      this.history.set(this.tick, this.state.copy());
    }
    return events;
  }

  /**
   * The host's settled `host` flight at `tick`. Returns true when it differed and the prediction
   * was corrected.
   */
  confirm(tick: number, host: FlappyFlightState): boolean {
    if (tick > this.tick) this.advanceTo(tick);
    const ours = tick === this.tick ? this.state : this.history.get(tick);
    if (ours && sameFlight(ours, host)) {
      this.forget(tick);
      return false;
    }

    const before = this.state;
    const replayed = host.copy();
    this.history.clear();
    this.history.set(tick, replayed.copy());
    const last = Math.min(this.tick, tick + MOST_TICKS);
    for (let next = tick + 1; next <= last; next += 1) {
      if (replayed.x >= this.flight.course.finish_x) break;
      this.flight.step(replayed, this.taps.has(next));
      this.history.set(next, replayed.copy());
    }
    this.state = replayed;
    this.tick = Math.max(this.tick, tick);
    this.corrections += 1;
    if (before.flying === replayed.flying) {
      this.offsetX += before.x - replayed.x;
      this.offsetY += before.y - replayed.y;
    } else {
      this.offsetX = this.offsetY = 0;
    }
    this.forget(tick);
    return true;
  }

  /** Blends the drawn position toward the prediction over about `seconds`. */
  blend(delta: number, seconds: number): void {
    const keep = seconds > 0 ? Math.exp(-delta / seconds) : 0;
    this.offsetX *= keep;
    this.offsetY *= keep;
    if (Math.abs(this.offsetX) < 1e-4) this.offsetX = 0;
    if (Math.abs(this.offsetY) < 1e-4) this.offsetY = 0;
  }

  get drawnX(): number {
    return this.state.x + this.offsetX;
  }

  get drawnY(): number {
    return this.state.y + this.offsetY;
  }

  /** The host has settled everything up to `tick`, so nothing before it is replayed again. */
  private forget(tick: number): void {
    for (const key of this.history.keys()) if (key < tick) this.history.delete(key);
    for (const key of this.taps) if (key <= tick) this.taps.delete(key);
  }
}
