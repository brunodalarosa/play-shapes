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
/** Safari gesture events predate touch-action. Block defaults only on play surfaces. */
export function protectControllerSurface(surface) {
    const prevent = (event) => {
        if (!surface.hidden && event.cancelable)
            event.preventDefault();
    };
    surface.addEventListener("touchstart", event => { if (event.touches.length > 1)
        prevent(event); }, { passive: false });
    for (const name of ["touchmove", "gesturestart", "gesturechange", "gestureend", "contextmenu", "selectstart"]) {
        surface.addEventListener(name, prevent, { passive: false });
    }
}
export function bindControllerLifecycle(cancel, target = window, page = document) {
    const resize = () => {
        page.documentElement.style.setProperty("--controller-height", `${target.visualViewport?.height ?? target.innerHeight}px`);
        cancel();
    };
    target.addEventListener("blur", cancel);
    target.addEventListener("pagehide", cancel);
    page.addEventListener("visibilitychange", () => { if (page.hidden)
        cancel(); });
    target.addEventListener("resize", resize);
    target.addEventListener("orientationchange", resize);
    target.visualViewport?.addEventListener("resize", resize);
    page.addEventListener("fullscreenchange", resize);
    resize();
}
