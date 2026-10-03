export type PermissionState = "unknown" | "granted" | "denied" | "unavailable" | "error";
type SensorAPI = { requestPermission?: () => Promise<string> };
export type SensorEnvironment = {
  target: EventTarget;
  secure: boolean;
  motion?: SensorAPI;
  orientation?: SensorAPI;
  now: () => number;
  screenAngle: () => number;
};
export type Axis3 = [number | null, number | null, number | null];
export type MotionSample = {
  orientation: Axis3;
  absolute: boolean;
  rotation_rate: Axis3;
  acceleration: Axis3;
  acceleration_gravity: Axis3;
  interval_msec: number | null;
  screen_angle: number;
  orientation_age_msec: number | null;
  motion_age_msec: number | null;
  orientation_hz: number;
  motion_hz: number;
};
export const SENSOR_STALE_MSEC = 1000;
const numberOrNull = (value: unknown): number | null =>
  typeof value === "number" && Number.isFinite(value) ? value : null;
const vector = (value: DeviceMotionEventAcceleration | null | undefined): Axis3 => [
  numberOrNull(value?.x),
  numberOrNull(value?.y),
  numberOrNull(value?.z),
];
export function browserSensors(): SensorEnvironment {
  const host = window as Window & {
    DeviceMotionEvent?: SensorAPI;
    DeviceOrientationEvent?: SensorAPI;
    orientation?: number;
  };
  return {
    target: window,
    secure: window.isSecureContext,
    motion: host.DeviceMotionEvent,
    orientation: host.DeviceOrientationEvent,
    now: () => performance.now(),
    screenAngle: () => screen.orientation?.angle ?? host.orientation ?? 0,
  };
}

export class MotionInput {
  motionPermission: PermissionState = "unknown";
  orientationPermission: PermissionState = "unknown";
  active = false;
  suspended = false;
  private desired = false;
  private generation = 0;
  private pending = false;
  private motionAt: number | null = null;
  private orientationAt: number | null = null;
  private started = 0;
  private motionCount = 0;
  private orientationCount = 0;
  private raw: Omit<
    MotionSample,
    "screen_angle" | "orientation_age_msec" | "motion_age_msec" | "orientation_hz" | "motion_hz"
  > = this.emptyRaw();
  constructor(private environment: SensorEnvironment = browserSensors()) {
    if (!environment.motion) this.motionPermission = "unavailable";
    if (!environment.orientation) this.orientationPermission = "unavailable";
  }
  private emptyRaw() {
    return {
      orientation: [null, null, null] as Axis3,
      absolute: false,
      rotation_rate: [null, null, null] as Axis3,
      acceleration: [null, null, null] as Axis3,
      acceleration_gravity: [null, null, null] as Axis3,
      interval_msec: null as number | null,
    };
  }
  private motion = (event: Event): void => {
    const value = event as DeviceMotionEvent;
    this.raw.rotation_rate = [
      numberOrNull(value.rotationRate?.alpha),
      numberOrNull(value.rotationRate?.beta),
      numberOrNull(value.rotationRate?.gamma),
    ];
    this.raw.acceleration = vector(value.acceleration);
    this.raw.acceleration_gravity = vector(value.accelerationIncludingGravity);
    this.raw.interval_msec = numberOrNull(value.interval);
    this.motionAt = this.environment.now();
    this.motionCount++;
  };
  private orientation = (event: Event): void => {
    const value = event as DeviceOrientationEvent;
    this.raw.orientation = [
      numberOrNull(value.alpha),
      numberOrNull(value.beta),
      numberOrNull(value.gamma),
    ];
    this.raw.absolute = value.absolute === true;
    this.orientationAt = this.environment.now();
    this.orientationCount++;
  };
  // Invoke BOTH permission APIs synchronously in the gesture before awaiting either.
  async requestPermission(): Promise<void> {
    if (!this.environment.secure || this.pending) return;
    this.stop();
    this.desired = true;
    this.suspended = false;
    this.pending = true;
    const generation = this.generation;
    const request = (api: SensorAPI | undefined): Promise<PermissionState> => {
      if (!api) return Promise.resolve("unavailable");
      if (!api.requestPermission) return Promise.resolve("unknown");
      try {
        return Promise.resolve(api.requestPermission()).then(
          (value) => (value === "granted" ? "granted" : "denied"),
          () => "error",
        );
      } catch {
        return Promise.resolve("error");
      }
    };
    const motion = request(this.environment.motion),
      orientation = request(this.environment.orientation);
    const permissions = await Promise.all([motion, orientation]);
    if (generation !== this.generation) return;
    [this.motionPermission, this.orientationPermission] = permissions;
    this.pending = false;
    this.startListeners();
  }
  private startListeners(): void {
    if (!this.desired || this.active || this.suspended || !this.environment.secure) return;
    this.raw = this.emptyRaw();
    this.motionAt = this.orientationAt = null;
    this.motionCount = this.orientationCount = 0;
    this.started = this.environment.now();
    if (["unknown", "granted"].includes(this.motionPermission) && this.environment.motion)
      this.environment.target.addEventListener("devicemotion", this.motion);
    if (["unknown", "granted"].includes(this.orientationPermission) && this.environment.orientation)
      this.environment.target.addEventListener("deviceorientation", this.orientation);
    this.active = !!(
      (this.environment.motion && ["unknown", "granted"].includes(this.motionPermission)) ||
      (this.environment.orientation && ["unknown", "granted"].includes(this.orientationPermission))
    );
  }
  suspend(): void {
    this.removeListeners();
    this.suspended = true;
    this.raw = this.emptyRaw();
    this.motionAt = this.orientationAt = null;
  }
  resume(): void {
    this.suspended = false;
    this.startListeners();
  }
  stop(): void {
    this.generation++;
    this.pending = false;
    this.desired = false;
    this.removeListeners();
    this.raw = this.emptyRaw();
    this.motionAt = this.orientationAt = null;
  }
  private removeListeners(): void {
    this.environment.target.removeEventListener("devicemotion", this.motion);
    this.environment.target.removeEventListener("deviceorientation", this.orientation);
    this.active = false;
  }
  sample(): MotionSample {
    const now = this.environment.now(),
      seconds = Math.max((now - this.started) / 1000, 0.001);
    return {
      ...this.raw,
      orientation: [...this.raw.orientation],
      rotation_rate: [...this.raw.rotation_rate],
      acceleration: [...this.raw.acceleration],
      acceleration_gravity: [...this.raw.acceleration_gravity],
      screen_angle: this.environment.screenAngle(),
      orientation_age_msec: this.orientationAt === null ? null : now - this.orientationAt,
      motion_age_msec: this.motionAt === null ? null : now - this.motionAt,
      orientation_hz: this.active ? this.orientationCount / seconds : 0,
      motion_hz: this.active ? this.motionCount / seconds : 0,
    };
  }
  status(): string {
    if (!this.environment.secure) return "insecure";
    if (!this.environment.motion && !this.environment.orientation) return "unsupported";
    if (this.pending) return "requesting";
    if (this.suspended) return "suspended";
    if (!this.active)
      return this.motionPermission === "denied" || this.orientationPermission === "denied"
        ? "denied"
        : this.motionPermission === "error" || this.orientationPermission === "error"
          ? "error"
          : "idle";
    const sample = this.sample();
    const ages = [sample.orientation_age_msec, sample.motion_age_msec];
    return ages.some((age) => age !== null && age <= SENSOR_STALE_MSEC)
      ? "live"
      : ages.some((age) => age !== null)
        ? "stale"
        : "waiting";
  }
  capabilities() {
    return {
      secure_context: this.environment.secure,
      motion_support: !!this.environment.motion,
      orientation_support: !!this.environment.orientation,
      motion_permission: this.motionPermission,
      orientation_permission: this.orientationPermission,
      state: this.status(),
    };
  }
}
