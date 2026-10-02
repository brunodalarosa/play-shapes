export type PlatformStance = "neutral" | "move" | "look_up" | "crouch";
export type PlatformAction = "jump" | "fall";
export type PlatformAxes = Readonly<{ x: number; y: number }>;
export type PlatformSnapshot = Readonly<{ axes: PlatformAxes; stance: PlatformStance }>;
export type PlatformIntent =
  | Readonly<{ kind: "move"; input: PlatformSnapshot }>
  | Readonly<{ kind: "release"; action: PlatformAction; input: PlatformSnapshot }>;

export type PlatformSettings = Readonly<{
  deadZone: number;
  deadZoneHysteresis: number;
  verticalEnterDegrees: number;
  verticalExitDegrees: number;
  moveIntervalMsec: number;
  refreshIntervalMsec: number;
}>;

/** Build also serializes these defaults for the host to read without duplicating tuning. */
export const DEFAULT_PLATFORM_SETTINGS: PlatformSettings = Object.freeze({
  deadZone: 0.16,
  deadZoneHysteresis: 0.04,
  verticalEnterDegrees: 20,
  verticalExitDegrees: 28,
  moveIntervalMsec: 45,
  refreshIntervalMsec: 100,
});

export function validatePlatformSettings(settings: PlatformSettings): void {
  if (![settings.deadZone, settings.deadZoneHysteresis, settings.verticalEnterDegrees,
    settings.verticalExitDegrees, settings.moveIntervalMsec, settings.refreshIntervalMsec].every(Number.isFinite)
    || settings.deadZone < 0 || settings.deadZoneHysteresis < 0
    || settings.deadZone + settings.deadZoneHysteresis >= 1
    || settings.verticalEnterDegrees < 0
    || settings.verticalExitDegrees < settings.verticalEnterDegrees
    || settings.verticalExitDegrees >= 45
    || settings.moveIntervalMsec < 1 || settings.refreshIntervalMsec < settings.moveIntervalMsec
    || settings.refreshIntervalMsec >= 350) throw new RangeError("Invalid platform input settings");
}

const neutral = (): PlatformSnapshot => ({ axes: { x: 0, y: 0 }, stance: "neutral" });

/** X is right-positive, Y is up-positive (NippleJS convention). Magnitude is at most one.
 * Retain neutral/vertical sectors through small radial/angular changes. The host handoff
 * documents the same ordered comparisons; client stance is never a physics decision.
 */
export function classifyPlatformInput(
  x: number, y: number, previous: PlatformSnapshot,
  settings: PlatformSettings = DEFAULT_PLATFORM_SETTINGS,
): PlatformSnapshot {
  if (!Number.isFinite(x) || !Number.isFinite(y)) return neutral();
  // Clamp before hypot so even extreme finite input cannot overflow the normalization.
  x = Math.max(-1, Math.min(1, x));
  y = Math.max(-1, Math.min(1, y));
  const length = Math.hypot(x, y);
  if (length > 1) { x /= length; y /= length; }
  const magnitude = Math.hypot(x, y);
  if (magnitude <= settings.deadZone
    || (previous.stance === "neutral" && magnitude < settings.deadZone + settings.deadZoneHysteresis)) return neutral();
  const vertical: PlatformStance = y > 0 ? "look_up" : "crouch";
  const angle = Math.atan2(Math.abs(x), Math.abs(y)) * 180 / Math.PI;
  const sector = previous.stance === vertical ? settings.verticalExitDegrees : settings.verticalEnterDegrees;
  return { axes: { x, y }, stance: angle <= sector ? vertical : "move" };
}

/** Shared gesture state; transport, identity, layout and gameplay live in context adapters. */
export class PlatformInputState {
  active = false;
  stickHeld = false;
  private current: PlatformSnapshot = neutral();
  private owner: { pointer: number } | { key: string } | undefined;
  readonly settings: PlatformSettings;

  constructor(private readonly emit: (intent: PlatformIntent) => void, settings = DEFAULT_PLATFORM_SETTINGS) {
    this.settings = Object.freeze({ ...settings });
    validatePlatformSettings(this.settings);
  }

  get actionPointer(): number | undefined { return this.owner && "pointer" in this.owner ? this.owner.pointer : undefined; }
  get actionHeld(): boolean { return this.owner !== undefined; }
  get action(): PlatformAction { return this.current.stance === "crouch" ? "fall" : "jump"; }
  snapshot(): PlatformSnapshot { return { axes: { ...this.current.axes }, stance: this.current.stance }; }

  activate(): void { if (!this.active) { this.cancel(); this.active = true; } }
  deactivate(): void { this.cancel(); this.active = false; }

  /** Every device move updates local state, even when its network send is throttled. */
  updateAxes(x: number, y: number): boolean {
    if (!this.active || !Number.isFinite(x) || !Number.isFinite(y)) return false;
    this.stickHeld = true;
    this.current = classifyPlatformInput(x, y, this.current, this.settings);
    return true;
  }

  refresh(): void {
    if (this.active && this.stickHeld) this.emit({ kind: "move", input: this.snapshot() });
  }

  endStick(): void {
    const sendNeutral = this.active && this.stickHeld;
    this.stickHeld = false;
    this.current = neutral();
    if (sendNeutral) this.emit({ kind: "move", input: this.snapshot() });
  }

  cancelAction(): void { this.owner = undefined; }
  cancel(): void { this.cancelAction(); this.endStick(); }

  pressAction(pointer: number): boolean {
    if (!this.active || this.owner !== undefined) return false;
    this.owner = { pointer };
    return true;
  }

  releaseAction(pointer: number, cancelled = false): void {
    if (this.actionPointer !== pointer) return;
    this.owner = undefined;
    if (!cancelled) this.activateAction();
  }

  pressKey(key: string): void {
    if (this.active && this.owner === undefined) this.owner = { key };
  }

  releaseKey(key: string): void {
    if (!this.owner || !("key" in this.owner) || this.owner.key !== key) return;
    this.owner = undefined;
    this.activateAction();
  }

  /** Native assistive activation and owned pointer/key releases use the same current snapshot. */
  activateAction(): void {
    if (this.active && !this.actionHeld) this.emit({ kind: "release", action: this.action, input: this.snapshot() });
  }
}
