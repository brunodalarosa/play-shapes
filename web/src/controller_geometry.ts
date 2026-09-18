export type Direction = "left" | "right" | "down" | "up";

export function heldDirectionAfterUpdate(held: Direction | undefined, available: readonly Direction[]): Direction | undefined {
  return held !== undefined && available.includes(held) ? held : undefined;
}

export function directionAtPoint(count: number, x: number, y: number, width: number, height: number): Direction {
  const nx = width > 0 ? Math.min(1, Math.max(0, x / width)) : 0.5;
  const ny = height > 0 ? Math.min(1, Math.max(0, y / height)) : 0.5;
  if (count <= 2) return nx < 0.5 ? "left" : "right";
  if (count === 3) {
    const lowerBoundary = Math.max(nx, 1 - nx);
    if (ny >= lowerBoundary) return "down";
    return nx < 0.5 ? "left" : "right";
  }
  if (ny <= nx && ny < 1 - nx) return "up";
  if (ny < nx && ny >= 1 - nx) return "right";
  if (ny >= nx && ny > 1 - nx) return "down";
  return "left";
}

export function chargedColor(hex: string, minimum: number, maximum: number, charge: number): string {
  const clean = /^#[0-9a-f]{6}$/i.test(hex) ? hex.slice(1) : "ffffff";
  const level = Math.min(1, Math.max(0, charge));
  const brightness = Math.min(1, Math.max(0, minimum + (maximum - minimum) * level));
  const channels = [0, 2, 4].map(index => Math.round(Number.parseInt(clean.slice(index, index + 2), 16) * brightness));
  return `rgb(${channels[0]} ${channels[1]} ${channels[2]})`;
}

export async function attemptImmersive(
  requestFullscreen: (() => Promise<void> | void) | undefined,
  requestOrientationLock: (() => Promise<void>) | undefined,
): Promise<void> {
  try { await requestFullscreen?.(); } catch { /* Permission denial is a supported fallback. */ }
  try { await requestOrientationLock?.(); } catch { /* Orientation lock is optional. */ }
}
