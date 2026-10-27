/**
 * The host's Flappy Race snapshot for one phone, sent on launch and on every resume. The phone
 * does not fly the race yet, so it only waits; flappy_race_state and flappy_race_event messages
 * are not read.
 */
export type Snapshot = {
  type: "flappy_race_snapshot";
  phase: "countdown" | "racing" | "results";
  player_count: number;
  tick_rate: number;
  /** The settled tick, one tap window behind the host's clock. */
  tick: number;
  clock_tick: number;
  countdown_remaining_msec: number;
  window_ticks: number;
  race_ticks: number;
  last_seconds_tick: number;
  flight: Record<string, number>;
  course: unknown;
  own: unknown;
  results?: unknown[];
};

export function isSnapshot(value: unknown): value is Snapshot {
  if (!value || typeof value !== "object") return false;

  return (value as { type?: string }).type === "flappy_race_snapshot";
}

/** The Flappy Race phone: portrait, pointing the player at the shared screen. */
export class FlappyRacePhone {
  constructor(private surface: HTMLElement) {}

  show(): void {
    this.surface.hidden = false;
  }

  hide(): void {
    this.surface.hidden = true;
  }
}
