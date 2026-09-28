export async function attemptImmersive(requestFullscreen, requestOrientationLock) {
    try {
        await requestFullscreen?.();
    }
    catch { /* Permission denial is a supported fallback. */ }
    try {
        await requestOrientationLock?.();
    }
    catch { /* Orientation lock is optional. */ }
}
