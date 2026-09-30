export const SENSOR_STALE_MSEC = 1000;
const numberOrNull = (value) => typeof value === "number" && Number.isFinite(value) ? value : null;
const vector = (value) => [numberOrNull(value?.x), numberOrNull(value?.y), numberOrNull(value?.z)];
export function browserSensors() {
    const host = window;
    return { target: window, secure: window.isSecureContext, motion: host.DeviceMotionEvent, orientation: host.DeviceOrientationEvent,
        now: () => performance.now(), screenAngle: () => screen.orientation?.angle ?? host.orientation ?? 0 };
}
export class MotionInput {
    environment;
    motionPermission = "unknown";
    orientationPermission = "unknown";
    active = false;
    suspended = false;
    desired = false;
    generation = 0;
    pending = false;
    motionAt = null;
    orientationAt = null;
    started = 0;
    motionCount = 0;
    orientationCount = 0;
    raw = this.emptyRaw();
    constructor(environment = browserSensors()) {
        this.environment = environment;
        if (!environment.motion)
            this.motionPermission = "unavailable";
        if (!environment.orientation)
            this.orientationPermission = "unavailable";
    }
    emptyRaw() {
        return { orientation: [null, null, null], absolute: false, rotation_rate: [null, null, null],
            acceleration: [null, null, null], acceleration_gravity: [null, null, null], interval_msec: null };
    }
    motion = (event) => {
        const value = event;
        this.raw.rotation_rate = [numberOrNull(value.rotationRate?.alpha), numberOrNull(value.rotationRate?.beta), numberOrNull(value.rotationRate?.gamma)];
        this.raw.acceleration = vector(value.acceleration);
        this.raw.acceleration_gravity = vector(value.accelerationIncludingGravity);
        this.raw.interval_msec = numberOrNull(value.interval);
        this.motionAt = this.environment.now();
        this.motionCount++;
    };
    orientation = (event) => {
        const value = event;
        this.raw.orientation = [numberOrNull(value.alpha), numberOrNull(value.beta), numberOrNull(value.gamma)];
        this.raw.absolute = value.absolute === true;
        this.orientationAt = this.environment.now();
        this.orientationCount++;
    };
    // Invoke BOTH permission APIs synchronously in the gesture before awaiting either.
    async requestPermission() {
        if (!this.environment.secure || this.pending)
            return;
        this.stop();
        this.desired = true;
        this.suspended = false;
        this.pending = true;
        const generation = this.generation;
        const request = (api) => {
            if (!api)
                return Promise.resolve("unavailable");
            if (!api.requestPermission)
                return Promise.resolve("unknown");
            try {
                return Promise.resolve(api.requestPermission()).then(value => value === "granted" ? "granted" : "denied", () => "error");
            }
            catch {
                return Promise.resolve("error");
            }
        };
        const motion = request(this.environment.motion), orientation = request(this.environment.orientation);
        const permissions = await Promise.all([motion, orientation]);
        if (generation !== this.generation)
            return;
        [this.motionPermission, this.orientationPermission] = permissions;
        this.pending = false;
        this.startListeners();
    }
    startListeners() {
        if (!this.desired || this.active || this.suspended || !this.environment.secure)
            return;
        this.raw = this.emptyRaw();
        this.motionAt = this.orientationAt = null;
        this.motionCount = this.orientationCount = 0;
        this.started = this.environment.now();
        if (["unknown", "granted"].includes(this.motionPermission) && this.environment.motion)
            this.environment.target.addEventListener("devicemotion", this.motion);
        if (["unknown", "granted"].includes(this.orientationPermission) && this.environment.orientation)
            this.environment.target.addEventListener("deviceorientation", this.orientation);
        this.active = !!((this.environment.motion && ["unknown", "granted"].includes(this.motionPermission)) || (this.environment.orientation && ["unknown", "granted"].includes(this.orientationPermission)));
    }
    suspend() { this.removeListeners(); this.suspended = true; this.raw = this.emptyRaw(); this.motionAt = this.orientationAt = null; }
    resume() { this.suspended = false; this.startListeners(); }
    stop() { this.generation++; this.pending = false; this.desired = false; this.removeListeners(); this.raw = this.emptyRaw(); this.motionAt = this.orientationAt = null; }
    removeListeners() { this.environment.target.removeEventListener("devicemotion", this.motion); this.environment.target.removeEventListener("deviceorientation", this.orientation); this.active = false; }
    sample() {
        const now = this.environment.now(), seconds = Math.max((now - this.started) / 1000, 0.001);
        return { ...this.raw, orientation: [...this.raw.orientation], rotation_rate: [...this.raw.rotation_rate], acceleration: [...this.raw.acceleration], acceleration_gravity: [...this.raw.acceleration_gravity],
            screen_angle: this.environment.screenAngle(), orientation_age_msec: this.orientationAt === null ? null : now - this.orientationAt,
            motion_age_msec: this.motionAt === null ? null : now - this.motionAt, orientation_hz: this.active ? this.orientationCount / seconds : 0, motion_hz: this.active ? this.motionCount / seconds : 0 };
    }
    status() {
        if (!this.environment.secure)
            return "insecure";
        if (!this.environment.motion && !this.environment.orientation)
            return "unsupported";
        if (this.pending)
            return "requesting";
        if (this.suspended)
            return "suspended";
        if (!this.active)
            return this.motionPermission === "denied" || this.orientationPermission === "denied" ? "denied" : this.motionPermission === "error" || this.orientationPermission === "error" ? "error" : "idle";
        const sample = this.sample();
        const ages = [sample.orientation_age_msec, sample.motion_age_msec];
        return ages.some(age => age !== null && age <= SENSOR_STALE_MSEC) ? "live" : ages.some(age => age !== null) ? "stale" : "waiting";
    }
    capabilities() {
        return { secure_context: this.environment.secure, motion_support: !!this.environment.motion, orientation_support: !!this.environment.orientation,
            motion_permission: this.motionPermission, orientation_permission: this.orientationPermission, state: this.status() };
    }
}
