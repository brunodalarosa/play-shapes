/** The host's Flappy Race state for one phone. The race is not built yet, so it only waits. */
export type Snapshot = {
  type: "flappy_race_snapshot";
  state: "waiting";
  player_count: number;
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
