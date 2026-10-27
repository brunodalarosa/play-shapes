/** The fixed simulation rate shared by the host and the phone (decision 0047). */
export const TICK_RATE = 60;
export const TICK = 1.0 / TICK_RATE;
/** Cubio's body cube, metres. Hands, feet and the face never collide. */
export const BODY_SIZE = 2.0;

/** The flappy shape gameplay values, as FlappyFlightTuning.to_dictionary sends them. */
export interface FlappyFlightTuning {
  forward_speed: number;
  flap_velocity: number;
  gravity: number;
  max_fall_speed: number;
  hit_box_inset: number;
  heart_count: number;
  heart_recovery_ticks: number;
  respawn_cooldown_ticks: number;
  invulnerable_ticks: number;
  boost_share: number;
  boost_ticks: number;
}

/** Half the hit box's side, metres. */
export function hitHalf(tuning: FlappyFlightTuning): number {
  return BODY_SIZE * 0.5 - tuning.hit_box_inset;
}

export function boostedSpeed(tuning: FlappyFlightTuning): number {
  return tuning.forward_speed * (1.0 + tuning.boost_share);
}
