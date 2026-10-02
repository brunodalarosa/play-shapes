/** Build also serializes these defaults for the host to read without duplicating tuning. */
export const DEFAULT_PLATFORM_SETTINGS = Object.freeze({
    deadZone: 0.16,
    deadZoneHysteresis: 0.04,
    verticalEnterDegrees: 20,
    verticalExitDegrees: 28,
    moveIntervalMsec: 45,
    refreshIntervalMsec: 100,
});
export function validatePlatformSettings(settings) {
    if (![settings.deadZone, settings.deadZoneHysteresis, settings.verticalEnterDegrees,
        settings.verticalExitDegrees, settings.moveIntervalMsec, settings.refreshIntervalMsec].every(Number.isFinite)
        || settings.deadZone < 0 || settings.deadZoneHysteresis < 0
        || settings.deadZone + settings.deadZoneHysteresis >= 1
        || settings.verticalEnterDegrees < 0
        || settings.verticalExitDegrees < settings.verticalEnterDegrees
        || settings.verticalExitDegrees >= 45
        || settings.moveIntervalMsec < 1 || settings.refreshIntervalMsec < settings.moveIntervalMsec
        || settings.refreshIntervalMsec >= 350)
        throw new RangeError("Invalid platform input settings");
}
const neutral = () => ({ axes: { x: 0, y: 0 }, stance: "neutral" });
/** X is right-positive, Y is up-positive (NippleJS convention). Magnitude is at most one.
 * Retain neutral/vertical sectors through small radial/angular changes. The host handoff
 * documents the same ordered comparisons; client stance is never a physics decision.
 */
export function classifyPlatformInput(x, y, previous, settings = DEFAULT_PLATFORM_SETTINGS) {
    if (!Number.isFinite(x) || !Number.isFinite(y))
        return neutral();
    // Clamp before hypot so even extreme finite input cannot overflow the normalization.
    x = Math.max(-1, Math.min(1, x));
    y = Math.max(-1, Math.min(1, y));
    const length = Math.hypot(x, y);
    if (length > 1) {
        x /= length;
        y /= length;
    }
    const magnitude = Math.hypot(x, y);
    if (magnitude <= settings.deadZone
        || (previous.stance === "neutral" && magnitude < settings.deadZone + settings.deadZoneHysteresis))
        return neutral();
    const vertical = y > 0 ? "look_up" : "crouch";
    const angle = Math.atan2(Math.abs(x), Math.abs(y)) * 180 / Math.PI;
    const sector = previous.stance === vertical ? settings.verticalExitDegrees : settings.verticalEnterDegrees;
    return { axes: { x, y }, stance: angle <= sector ? vertical : "move" };
}
/** Shared gesture state; transport, identity, layout and gameplay live in context adapters. */
export class PlatformInputState {
    emit;
    active = false;
    stickHeld = false;
    current = neutral();
    owner;
    settings;
    constructor(emit, settings = DEFAULT_PLATFORM_SETTINGS) {
        this.emit = emit;
        this.settings = Object.freeze({ ...settings });
        validatePlatformSettings(this.settings);
    }
    get actionPointer() { return this.owner && "pointer" in this.owner ? this.owner.pointer : undefined; }
    get actionHeld() { return this.owner !== undefined; }
    get action() { return this.current.stance === "crouch" ? "fall" : "jump"; }
    snapshot() { return { axes: { ...this.current.axes }, stance: this.current.stance }; }
    activate() { if (!this.active) {
        this.cancel();
        this.active = true;
    } }
    deactivate() { this.cancel(); this.active = false; }
    /** Every device move updates local state, even when its network send is throttled. */
    updateAxes(x, y) {
        if (!this.active || !Number.isFinite(x) || !Number.isFinite(y))
            return false;
        this.stickHeld = true;
        this.current = classifyPlatformInput(x, y, this.current, this.settings);
        return true;
    }
    refresh() {
        if (this.active && this.stickHeld)
            this.emit({ kind: "move", input: this.snapshot() });
    }
    endStick() {
        const sendNeutral = this.active && this.stickHeld;
        this.stickHeld = false;
        this.current = neutral();
        if (sendNeutral)
            this.emit({ kind: "move", input: this.snapshot() });
    }
    cancelAction() { this.owner = undefined; }
    cancel() { this.cancelAction(); this.endStick(); }
    pressAction(pointer) {
        if (!this.active || this.owner !== undefined)
            return false;
        this.owner = { pointer };
        return true;
    }
    releaseAction(pointer, cancelled = false) {
        if (this.actionPointer !== pointer)
            return;
        this.owner = undefined;
        if (!cancelled)
            this.activateAction();
    }
    pressKey(key) {
        if (this.active && this.owner === undefined)
            this.owner = { key };
    }
    releaseKey(key) {
        if (!this.owner || !("key" in this.owner) || this.owner.key !== key)
            return;
        this.owner = undefined;
        this.activateAction();
    }
    /** Native assistive activation and owned pointer/key releases use the same current snapshot. */
    activateAction() {
        if (this.active && !this.actionHeld)
            this.emit({ kind: "release", action: this.action, input: this.snapshot() });
    }
}
