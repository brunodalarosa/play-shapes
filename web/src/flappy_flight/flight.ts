import type { FlappyFlightCourse } from "./course.js";
import { HeartRow } from "./heart_row.js";
import { boostedSpeed, hitHalf, TICK, type FlappyFlightTuning } from "./tuning.js";

/** Bits of what `step` reports. */
export const EVENT_FLAP = 1;
export const EVENT_HIT = 2;
export const EVENT_PICKUP = 4;
export const EVENT_HEART_REFILLED = 8;
export const EVENT_READY = 16;
export const EVENT_RESPAWN = 32;

/** One player's flight, changed only by `FlappyFlight.step`. */
export class FlappyFlightState {
  /** Body centre, metres along the course and above the ground. While waiting, the respawn spot. */
  x = 0.0;
  y = 0.0;
  verticalSpeed = 0.0;
  /** False from a hit until the respawn tap. */
  flying = true;
  /** Waiting and allowed to respawn: the cooldown is over and no heart is owed. */
  ready = false;
  cooldownTicks = 0;
  invulnerableTicks = 0;
  boostTicks = 0;
  /** The first obstacle the hit box has not yet passed. */
  obstacleIndex = 0;
  hearts: HeartRow;
  /** One entry per course pickup, 1 once this player has taken it. */
  taken: Uint8Array;

  constructor(hearts: HeartRow, pickupCount: number) {
    this.hearts = hearts;
    this.taken = new Uint8Array(pickupCount);
  }

  copyFrom(other: FlappyFlightState): void {
    this.x = other.x;
    this.y = other.y;
    this.verticalSpeed = other.verticalSpeed;
    this.flying = other.flying;
    this.ready = other.ready;
    this.cooldownTicks = other.cooldownTicks;
    this.invulnerableTicks = other.invulnerableTicks;
    this.boostTicks = other.boostTicks;
    this.obstacleIndex = other.obstacleIndex;
    this.hearts.copyFrom(other.hearts);
    this.taken = other.taken.slice();
  }

  copy(): FlappyFlightState {
    const state = new FlappyFlightState(new HeartRow(0, 1), 0);
    state.copyFrom(this);
    return state;
  }
}

/**
 * The flappy shape gameplay: one fixed 60 Hz step of a player's flight over a course.
 *
 * components/flappy_flight/flappy_flight.gd is the same step in GDScript, line for line, so the
 * phone predicts exactly what the host computes (decision 0047). Change both together and
 * regenerate tests/fixtures/flappy_flight_runs.json. Only addition, subtraction,
 * multiplication, division, min and max are used, in the same order on both sides.
 */
export class FlappyFlight {
  readonly course: FlappyFlightCourse;
  private readonly forwardSpeed: number;
  private readonly boostedSpeed: number;
  private readonly flapVelocity: number;
  private readonly gravity: number;
  private readonly maxFallSpeed: number;
  private readonly hitHalf: number;
  private readonly heartCount: number;
  private readonly heartRecoveryTicks: number;
  private readonly cooldownTicks: number;
  private readonly invulnerableTicks: number;
  private readonly boostTicks: number;

  constructor(tuning: FlappyFlightTuning, course: FlappyFlightCourse) {
    this.course = course;
    this.forwardSpeed = tuning.forward_speed;
    this.boostedSpeed = boostedSpeed(tuning);
    this.flapVelocity = tuning.flap_velocity;
    this.gravity = tuning.gravity;
    this.maxFallSpeed = tuning.max_fall_speed;
    this.hitHalf = hitHalf(tuning);
    this.heartCount = tuning.heart_count;
    this.heartRecoveryTicks = tuning.heart_recovery_ticks;
    this.cooldownTicks = tuning.respawn_cooldown_ticks;
    this.invulnerableTicks = tuning.invulnerable_ticks;
    this.boostTicks = tuning.boost_ticks;
  }

  /** A player at the start line at GO, flying with every heart full. */
  newState(): FlappyFlightState {
    const hearts = new HeartRow(this.heartCount, this.heartRecoveryTicks);
    const state = new FlappyFlightState(hearts, this.course.pickups.length);
    state.x = this.course.start_x;
    state.y = this.course.start_y;
    return state;
  }

  /**
   * Advances `state` by one tick. `tap` is a touch-down during this tick: a flap while flying,
   * the respawn while waiting and ready, and nothing otherwise. Returns the EVENT_ bits.
   */
  step(state: FlappyFlightState, tap: boolean): number {
    let events = 0;
    if (state.hearts.tick()) events |= EVENT_HEART_REFILLED;

    if (!state.flying) {
      if (state.cooldownTicks > 0) state.cooldownTicks -= 1;
      if (!state.ready && state.cooldownTicks === 0 && !state.hearts.owed) {
        state.ready = true;
        events |= EVENT_READY;
      }
      if (!state.ready || !tap) return events;

      // The respawn tap is also the first flap.
      state.flying = true;
      state.ready = false;
      state.invulnerableTicks = this.invulnerableTicks;
      state.obstacleIndex = 0;
      events |= EVENT_RESPAWN;
    }

    if (tap) {
      state.verticalSpeed = this.flapVelocity;
      events |= EVENT_FLAP;
    } else {
      state.verticalSpeed = Math.max(state.verticalSpeed - this.gravity * TICK, -this.maxFallSpeed);
    }

    const speed = state.boostTicks > 0 ? this.boostedSpeed : this.forwardSpeed;
    state.x += speed * TICK;
    state.y += state.verticalSpeed * TICK;
    if (state.boostTicks > 0) state.boostTicks -= 1;

    events |= this.takePickups(state);
    events |= this.collide(state);
    if (state.invulnerableTicks > 0) state.invulnerableTicks -= 1;
    return events;
  }

  private takePickups(state: FlappyFlightState): number {
    let events = 0;
    const pickups = this.course.pickups;
    for (let index = 0; index < pickups.length; index += 1) {
      if (state.taken[index] !== 0) continue;

      const pickup = pickups[index];
      const reach = this.hitHalf + pickup.half_size;
      if (Math.abs(state.x - pickup.x) < reach && Math.abs(state.y - pickup.y) < reach) {
        state.taken[index] = 1;
        state.boostTicks = this.boostTicks;
        events |= EVENT_PICKUP;
      }
    }
    return events;
  }

  private collide(state: FlappyFlightState): number {
    const obstacles = this.course.obstacles;
    const back = state.x - this.hitHalf;
    const front = state.x + this.hitHalf;
    while (state.obstacleIndex < obstacles.length && obstacles[state.obstacleIndex].x_end <= back)
      state.obstacleIndex += 1;

    if (state.invulnerableTicks > 0) {
      // Invulnerable: through obstacles, and resting on the ground at no cost.
      if (state.y - this.hitHalf < 0.0) {
        state.y = this.hitHalf;
        if (state.verticalSpeed < 0.0) state.verticalSpeed = 0.0;
      }
      return 0;
    }

    if (state.obstacleIndex < obstacles.length) {
      const obstacle = obstacles[state.obstacleIndex];
      const inside = front > obstacle.x_start && back < obstacle.x_end;
      const outsideGap =
        state.y - this.hitHalf < obstacle.gap_bottom || state.y + this.hitHalf > obstacle.gap_top;
      if (inside && outsideGap) return this.hit(state, obstacle.respawn_x, obstacle.respawn_y);
    }

    if (state.y - this.hitHalf <= 0.0) {
      // Out in the open, the next obstacle ahead sets the spot; past the last one, the last.
      if (obstacles.length === 0) return this.hit(state, state.x, this.course.start_y);
      const index = Math.min(state.obstacleIndex, obstacles.length - 1);
      return this.hit(state, obstacles[index].respawn_x, obstacles[index].respawn_y);
    }

    return 0;
  }

  private hit(state: FlappyFlightState, respawnX: number, respawnY: number): number {
    state.flying = false;
    state.ready = false;
    state.x = respawnX;
    state.y = respawnY;
    state.verticalSpeed = 0.0;
    state.boostTicks = 0;
    state.invulnerableTicks = 0;
    state.cooldownTicks = this.cooldownTicks;
    state.hearts.hit();
    return EVENT_HIT;
  }
}
