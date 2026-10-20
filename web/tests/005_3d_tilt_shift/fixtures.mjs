export const look = {
  corner_ratio: 0.35,
  depth_ratio: 1,
  gap_ratio: 0.06,
  outline_ratio: 0.09,
  face_ratio: 0.72,
  gap_color: "fff3dc",
  outline_colors: ["fd8702", "0144f2", "707070"],
  wall_colors: ["fbf3e2", "efdfc2"],
};

export function snapshot(overrides = {}) {
  return {
    type: "tilt_shift_3d_snapshot",
    generation: "generation",
    sequence: 3,
    phase: "active",
    round: 1,
    round_token: "token",
    selected: true,
    ready: false,
    ready_available: false,
    calibration_available: false,
    calibrated: true,
    usable: true,
    landscape: true,
    team: 1,
    angle_radians: 0.4,
    paddle_ids: ["a_0"],
    paddle_size: [0.2, 0.04],
    color: "e53935",
    face: "face_a",
    look,
    ...overrides,
  };
}

export function preparation(overrides = {}) {
  return {
    paddle_size: [0.2, 0.04],
    generation: "generation",
    calibrated: false,
    usable: false,
    landscape: false,
    capture_state: "waiting",
    angle_radians: 0,
    color: "43a047",
    face: "face_a",
    look,
    ...overrides,
  };
}
