/**
 * One obstacle pair: a ground box from the ground to the gap and a hanging box from the gap up
 * without end. Metres along the course and above the ground.
 */
export interface FlappyFlightObstacle {
  x_start: number;
  x_end: number;
  gap_bottom: number;
  gap_top: number;
  /** Where a Cubio waits after this obstacle hits it, before its front face. */
  respawn_x: number;
  respawn_y: number;
}

/** A speed pickup: a square trigger centred at x, y. */
export interface FlappyFlightPickup {
  x: number;
  y: number;
  half_size: number;
}

/** What the flight collides with, as FlappyFlightCourse.to_dictionary sends it. */
export interface FlappyFlightCourse {
  start_x: number;
  start_y: number;
  finish_x: number;
  /** Sorted along the course. */
  obstacles: FlappyFlightObstacle[];
  pickups: FlappyFlightPickup[];
}
