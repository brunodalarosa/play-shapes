export function isStandalone(target, browser) {
    return target.matchMedia("(display-mode: standalone)").matches
        || target.matchMedia("(display-mode: fullscreen)").matches
        || browser.standalone === true;
}
export function installGuidance(browser) {
    const ios = /iPhone|iPad|iPod/.test(browser.userAgent)
        || (browser.platform === "MacIntel" && browser.maxTouchPoints > 1);
    return ios
        ? "In Safari, tap Share → Add to Home Screen. Keep Open as Web App on if shown, then tap Add. Open the new icon before joining."
        : "Open your browser menu and choose Install app or Add to Home Screen if offered. Then launch Play Shapes from its icon. Otherwise, continue in your browser.";
}
/** Offered before registration: installation never creates a player in the old tab. */
export class PwaOnboarding {
    panel;
    action;
    guidance;
    onContinue;
    target;
    browser;
    pending;
    dismissed = false;
    busy = false;
    constructor(panel, action, guidance, continueButton, onContinue, target = window, browser = navigator) {
        this.panel = panel;
        this.action = action;
        this.guidance = guidance;
        this.onContinue = onContinue;
        this.target = target;
        this.browser = browser;
        try {
            this.dismissed = target.sessionStorage.getItem("play-shapes.app-offer-dismissed") === "yes";
        }
        catch { /* Memory-only fallback. */ }
        target.addEventListener("beforeinstallprompt", event => {
            event.preventDefault();
            this.pending = event;
            if (!this.busy)
                this.action.textContent = "INSTALL APP";
        });
        target.addEventListener("appinstalled", () => {
            this.pending = undefined;
            this.rememberDismissal();
            this.guidance.hidden = false;
            this.guidance.textContent = "Open Play Shapes from its new icon before joining, or continue here in your browser.";
        });
        action.addEventListener("click", () => { void this.install(); });
        continueButton.addEventListener("click", () => {
            if (this.busy)
                return;
            this.rememberDismissal();
            this.hide();
            this.onContinue();
        });
    }
    get visible() { return !this.panel.hidden; }
    show() {
        if (this.dismissed || isStandalone(this.target, this.browser))
            return false;
        this.panel.hidden = false;
        this.action.focus();
        return true;
    }
    hide() { this.panel.hidden = true; }
    rememberDismissal() {
        this.dismissed = true;
        try {
            this.target.sessionStorage.setItem("play-shapes.app-offer-dismissed", "yes");
        }
        catch { /* Memory-only fallback. */ }
    }
    async install() {
        if (this.busy)
            return;
        this.guidance.hidden = false;
        this.guidance.textContent = installGuidance(this.browser);
        const event = this.pending;
        if (!event)
            return;
        this.pending = undefined;
        this.busy = true;
        this.action.disabled = true;
        try {
            // Invoke synchronously in the click handler, before any await.
            await event.prompt();
            const choice = await event.userChoice;
            if (choice.outcome === "accepted") {
                this.rememberDismissal();
                this.guidance.textContent = "Open Play Shapes from its new icon before joining, or continue here in your browser.";
            }
        }
        catch { /* Keep honest menu guidance and the browser continuation. */ }
        finally {
            this.busy = false;
            this.action.disabled = false;
            this.action.textContent = this.pending ? "INSTALL APP" : "HOW TO ADD THE APP";
        }
    }
}
