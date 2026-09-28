export async function attemptImmersive(
  requestFullscreen: (() => Promise<void> | void) | undefined,
  requestOrientationLock: (() => Promise<void>) | undefined,
): Promise<void> {
  try { await requestFullscreen?.(); } catch { /* Permission denial is a supported fallback. */ }
  try { await requestOrientationLock?.(); } catch { /* Orientation lock is optional. */ }
}
