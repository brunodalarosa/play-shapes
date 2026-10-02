# Optional controller app and touch review

The controller offers **Run Play Shapes as an app** before the host registers a new player. **Continue in browser** dismisses it for that tab's session, including reloads and leave/rejoin. Restricted storage falls back to dismissal in memory. Resumed players and already-standalone windows skip the offer. Instructions never appear over gameplay.

## Installing and switching windows

- On iPhone/iPad, open the host URL in Safari, tap Share, then **Add to Home Screen**. If shown, keep **Open as Web App** enabled, tap Add, and launch the resulting icon before joining. Older versions use the manifest's standalone mode and Apple metadata. Menu wording/placement varies by OS version. Safari has no automatic install dialog available to this site.
- On Android Chrome, **INSTALL APP** appears only when a real `beforeinstallprompt` event is available. Its native prompt runs directly from the button gesture; dismissal or denial keeps browser continuation available. Without that event, use Install app/Add to Home Screen in the browser menu if offered. Trusted HTTPS and Chrome's engagement criteria affect promotion; the site cannot force it.
- Install before joining: the original tab has no registered player to orphan. The installed app fetches fresh `/session.json` and connects to that origin's current host. If the browser genuinely shares the stored session/token, the existing host resume path takes ownership of the same player and closes the older connection with code 4000. The older window stops reconnecting.
- Safari tabs and installed apps may have separate localStorage. No credentials are placed in the manifest, start URL, fragments or cookies to try to bypass that separation. With no token, the app starts ordinary onboarding and never automatically submits a new join. **If you already joined in a browser, leave that controller first**, then join from the app. Its onboarding states this. Names already in use remain rejected by the host. Closing a joined tab alone retains its player for the existing 60-second reconnect grace; use Leave to switch immediately. Physical cross-window storage behavior remains unverified.
- The manifest `id`, `start_url` and `scope` are all `/`, without session identifiers. App identity is stable for an origin, including scheme, address and port. Restarting that host invalidates previous session tokens and requires a fresh join. Changing the LAN IP, hostname, scheme or port changes the origin; the old icon still opens the old address. Open the new host QR/address and add a new icon. The app does not discover or redirect to other hosts.

## Immersion, input and offline behavior

Browser continuation attempts fullscreen and portrait lock once per onboarding gesture; failures resolve as playable fallbacks. There are no fullscreen requests inside Bubbles pointer/key handlers or before sensor permissions. A standalone launch uses manifest/Apple metadata. A website cannot force a Safari tab into installed mode, remove all browser chrome, or suppress OS-reserved edge gestures.

The active lobby, Bubbles and READY surfaces scope touch-action, Safari gesture/touch-move prevention, selection/callout suppression and overscroll protection. Single taps remain available for READY/Leave. Onboarding remains scrollable and zoomable; name entry, keyboard and focus are outside those guards. The shared platform controller keeps separate stick/action touches and release-triggered actions. Its unlocked NippleJS stick supplies both axes; near-down changes JUMP to FALL, with the displayed mode and latest axes included at release. Cancellation emits no action, and keyboard/assistive activation remains supported. Current host drop/stance integration is pending; unsupported FALL never becomes a jump. See [platform intent and host handoff](platform-phone-controller.md).

`immersive.ts` shares viewport/lifecycle handling and returns a cleanup function for temporary controller mounts. `--controller-height` tracks `visualViewport.height`, falling back to `innerHeight`; CSS retains safe-area insets and dynamic-height fallback. Rotation, viewport/fullscreen change, blur, visibility loss and pagehide cancel pending gestures; the stick is recreated when focused/visible. Platform reset neutralizes both axes, stance and action ownership and restores JUMP; context replacement sends neutral through the old adapter first. Bubbles sends cancel instead of completing a backgrounded trace. Inspect `platform_controls.ts`/`platform_input.ts` (45 ms movement throttle, 100 ms two-axis held refresh) and `app.ts` (70 ms Bubbles motion throttle, 600 ms heartbeat, 48-motion-packet cap). Platform action release and Bubbles action start/release send synchronously.

No service worker or Cache Storage is added. Current Chrome install-promotion criteria do not require a service worker, and LAN-serving already provides all assets without Internet. Every route sends `Cache-Control: no-store`; session discovery also fetches with `cache: no-store`. Session metadata, identities, reconnect tokens and live state are never service-worker cached. There is no cache version or invalidation procedure: rebuild committed `web/public/`, restart the host, and reload/relaunch controllers after updates. The host must still be reachable on the LAN. Installation neither provides hostless play nor solves first-join certificate trust.

Icons reuse the approved Squircle v1 front idle frame and Playground logo. Regenerate with `node web/scripts/generate_pwa_icons.mjs`, then import in Godot. The HTTP allowlist, export presets and pack policy include the manifest, 180/192/512px PNGs and `pwa.js`.

## Evidence and remaining device review

### Development error reporting

Connection failures now show a selectable red diagnostic panel even when normal gameplay status is hidden. Its bounded six-entry log records UTC timestamps, the failing step (fetch, JSON parsing, configuration validation, WebSocket opening/welcome), endpoint, browser error text and user agent. Consecutive identical failures are grouped with a repeat count. WebSocket closures include code, reason and clean/unclean state; a browser error event that conceals the TLS cause says so explicitly. Host protocol errors also surface their code/message. Errors persist across retries; the panel hides after a successful host welcome and retained in-memory history appears if another failure occurs. No reconnect tokens or complete protocol payloads are displayed. HTTP failures include their status code; invalid host JSON reports its parser error type without quoting credential-bearing payloads.

Uncaught JavaScript errors also include source filename/line/column; unhandled promise rejections show the original error text. [AUTO] Diagnostics follow-up: TypeScript check/build and 17 focused controller/install/immersion tests passed. [DESKTOP-BROWSER] A deliberately failing HTTP 503 session fixture verified the readable log at 390×844; ignored screenshot `test-results/controller-app-and-touch/error-log-390x844.png`. This fixture used loopback port 18090 and was stopped afterward; it did not replace or restart the owner's host.

After rebuilding, restart the host to reload its startup-cached browser assets, then reload the controller. If the exported host is in use, rebuild that package first. The owner reported the development CA was not enabled for Safari and chose to defer Safari/PWA certificate setup until the Trusted Online Controller layer; current physical testing uses Chrome. No certificate/trust settings were changed. For later Safari investigation, opening `/session.json` directly separates HTTPS/session discovery from WebSocket failure. The public development CA profile must be installed **and** explicitly enabled for SSL/TLS under iPhone Certificate Trust Settings; accepting a page warning does not establish full root trust. See [Apple's full-trust instructions](https://support.apple.com/en-ie/102390). Safari/PWA device acceptance remains pending.

[AUTO] TypeScript check/build; 46/46 browser/host checks, including compiled-app install gating, standalone storage cases, immediate send, duplicate releases and lifecycle cancellation; verified HTTPS asset routes; standalone policy and actual exported PCK inspection. Synthetic compiled-app pointerdown-to-fake-send measurement (100 samples): median 0.002 ms, p95 0.012 ms, max 0.137 ms in the focused run. These numbers exclude device event delivery, browser rendering, networking and Godot receipt; they cannot establish Safari latency.

[DESKTOP-BROWSER] Codex in-app browser, 390×844 viewport: prompt/menu guidance, continuation, color/name input, joining, jump, Leave, reload without a repeated prompt; no error/warning console entries in the checked join journey. Screenshot: ignored `test-results/controller-app-and-touch/app-prompt-390x844.png`. This is desktop browser evidence, not an iPhone simulation or native-install test.

[EXPORTED-BUILD] Windows release export and PCK content verification passed. The exported executable started headlessly and served HTML, pwa.js, manifest and all three icons with HTTP 200; the owned smoke process was stopped. Physical phones, installed browser windows and exported-executable phone/controller interaction remain pending. Human approval remains pending.

Record exact OS/browser versions and results for each device below before acceptance:

| Device/browser | Required journey | Version/result |
| --- | --- | --- |
| iPhone Safari | Tab prompt; Share/Add to Home Screen/Open as Web App; icon launch to current host; standalone layout; separate/shared storage switch; lobby stick + jump together; READY/CANCEL; Bubbles swipe/spin/cancel; keyboard; pinch/double tap; bars/rotation; background/lock/unlock; lab permission | Pending physical device access |
| Android Chrome | Real native install event when eligible; accepted/dismissed/unsupported fallback; icon launch; same play/lifecycle/keyboard/permission journey | Pending physical device access |
| Both | Host restart, grace expiry, LAN-origin change, certificate trust, current-host reconnect and absence of duplicate active players after the documented switch | Pending |
| Both | Measured event-to-host-send/receipt timing and subjective responsiveness; identify measurement method, sample count and versions | Pending; synthetic timing above is separate |

Primary references checked for this implementation:

- [Apple iOS 26: turn a website into an app](https://support.apple.com/en-az/guide/iphone/iphea86e5236/26/ios/26)
- [WebKit Safari 26 Home Screen changes](https://webkit.org/blog/17333/webkit-features-in-safari-26-0/#every-site-can-be-a-web-app-on-ios-and-ipados)
- [WebKit Safari 17.2 storage separation](https://webkit.org/blog/14787/webkit-features-in-safari-17-2/)
- [Chrome install-promotion criteria](https://web.dev/articles/install-criteria)
