export type Pair = [number, number];
export type Phase = "instructions" | "countdown" | "active" | "results" | "lobby_return";

export interface VisualTuning {
  starting_radius: number;
  max_radius: number;
  visual_cap: number;
  caught_width: number;
  character_height_per_radius: number;
  character_max_height: number;
  character_bob: number;
  character_lean_degrees: number;
  live_drag_pull_strength: number;
  live_drag_response_seconds: number;
  swipe_max_hold_seconds: number;
  bubble_reform_seconds: number;
  burst_seconds: number;
}

export interface Snapshot {
  type: "bubbles_3d_snapshot" | "bubbles_3d_feedback";
  phase: Phase;
  debug_mode: boolean;
  character_shape: string;
  character_color: string;
  score: number;
  bubble_radius: number;
  visual_jellyfish: number;
  seat: number;
  connected: boolean;
  left: boolean;
  host_time_msec: number;
  invulnerable_remaining_msec: number;
  reform_remaining_msec: number;
  rank: number;
  visual_tuning: VisualTuning;
  event?: "captured" | "pop";
  lost?: number;
}

export interface Visual {
  host_time_msec: number;
  radius: number;
  stretch: Pair;
  velocity: Pair;
  white: boolean;
  pop_age_msec: number;
  caught: number;
}

export type Message =
  | Snapshot
  | { type: "bubbles_3d_visual"; visual: Visual }
  | { type: "bubbles_3d_release_result"; action: "swipe" | "none"; reason: string };

export interface Frame {
  snapshot: Snapshot;
  visual: Visual;
}

export interface Presentation {
  update(frame: Frame): void;
  dispose(): void;
}

export interface ViewModule {
  createBubbleView(canvas: HTMLCanvasElement): Promise<Presentation>;
}
