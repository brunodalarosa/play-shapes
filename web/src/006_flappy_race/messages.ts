import type { FlappyFlightCourse } from "../flappy_flight/course.js";
import { FlappyFlightState } from "../flappy_flight/flight.js";
import { HeartRow } from "../flappy_flight/heart_row.js";
import type { FlappyFlightTuning } from "../flappy_flight/tuning.js";

/** A settled flight as FlappyFlightState.to_dictionary sends it. */
export interface HostFlight {
  x: number;
  y: number;
  vertical_speed: number;
  flying: boolean;
  ready: boolean;
  cooldown_ticks: number;
  invulnerable_ticks: number;
  boost_ticks: number;
  obstacle_index: number;
  hearts: { full: number; refill_ticks: number; owed: boolean };
  /** Indices of the pickups taken. */
  taken: number[];
}

/** The player's own race state, settled by the host. */
export interface Own {
  flight: HostFlight;
  last_seq: number;
  connected: boolean;
  /** Finish order, 0 before finishing. */
  place: number;
  finish_tick: number;
  dnf: boolean;
}

/** FlappyRaceViewTuning.to_dictionary: presentation only. */
export interface ViewTuning {
  tilt_up_degrees: number;
  tilt_down_degrees: number;
  tilt_response_seconds: number;
  hit_tumble_seconds: number;
  pickup_face_seconds: number;
  phone_cubio_screen_share: number;
  correction_seconds: number;
  heart_flight_seconds: number;
}

export interface Course {
  length: number;
  view_height: number;
  flight: FlappyFlightCourse;
  ground_kinds: string[];
}

export interface ResultEntry {
  player_id: string;
  name: string;
  character_color: string;
  place: number;
  finished: boolean;
  finish_msec: number;
  distance: number;
  dnf: boolean;
}

export type Phase = "countdown" | "racing" | "results";

/** The host's Flappy Race snapshot for one phone, sent on launch and on every resume. */
export interface Snapshot {
  type: "flappy_race_snapshot";
  character_color: string;
  phase: Phase;
  player_count: number;
  tick_rate: number;
  /** The settled tick, one tap window behind the host's clock. */
  tick: number;
  clock_tick: number;
  countdown_remaining_msec: number;
  window_ticks: number;
  race_ticks: number;
  last_seconds_tick: number;
  flight: FlappyFlightTuning;
  view: ViewTuning;
  course: Course;
  own: Own;
  results?: ResultEntry[];
  own_result?: ResultEntry;
}

/** The player's own settled flight, a few times a second. */
export interface StateMessage {
  type: "flappy_race_state";
  tick: number;
  clock_tick: number;
  own: Own;
}

export interface EventMessage {
  type: "flappy_race_event";
  event: string;
  tick: number;
  own?: Own;
  place?: number;
  pickup?: number;
}

export type Message = Snapshot | StateMessage | EventMessage;

function typed(value: unknown, type: string): boolean {
  return !!value && typeof value === "object" && (value as { type?: string }).type === type;
}

export function isSnapshot(value: unknown): value is Snapshot {
  return typed(value, "flappy_race_snapshot");
}

export function isState(value: unknown): value is StateMessage {
  return typed(value, "flappy_race_state") && Number.isInteger((value as StateMessage).tick);
}

export function isEvent(value: unknown): value is EventMessage {
  return typed(value, "flappy_race_event") && typeof (value as EventMessage).event === "string";
}

/** The host's settled flight as the shared flight's state. */
export function flightState(
  flight: HostFlight,
  tuning: FlappyFlightTuning,
  pickupCount: number,
): FlappyFlightState {
  const hearts = new HeartRow(tuning.heart_count, tuning.heart_recovery_ticks);
  hearts.full = flight.hearts.full;
  hearts.refillTicks = flight.hearts.refill_ticks;
  hearts.owed = flight.hearts.owed;
  const state = new FlappyFlightState(hearts, pickupCount);
  state.x = flight.x;
  state.y = flight.y;
  state.verticalSpeed = flight.vertical_speed;
  state.flying = flight.flying;
  state.ready = flight.ready;
  state.cooldownTicks = flight.cooldown_ticks;
  state.invulnerableTicks = flight.invulnerable_ticks;
  state.boostTicks = flight.boost_ticks;
  state.obstacleIndex = flight.obstacle_index;
  for (const index of flight.taken) if (index >= 0 && index < pickupCount) state.taken[index] = 1;
  return state;
}
