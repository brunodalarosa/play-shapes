# Phone client

What the phone's web page does around the game itself: the offer to run as an app, fullscreen
and touch handling, what happens when the page is hidden or rotated, caching, and the
development error panel. The joystick and action button are in
[platform-phone-controller.md](platform-phone-controller.md); the messages are in
[protocol.md](protocol.md).

## The Bubbles screen

- A full-screen portrait touch area with the exact host score, capped decorative jellyfish,
  and the player's personalized character preview.
- The Squircle v1 body, hands and feet share the player's chosen color.

## The Tilt Shift screen

Preparation exposes Enable tilt, Set neutral and the host-confirmed READY/CANCEL action.
Current usable orientation and completed calibration are required by the host. A browser
without a permission enum may still provide valid samples; denial or absent samples block READY.
The preview and play instructions remain on the shared screen.

Gameplay shows one canonical team paddle as a movement guide, even when that player owns
several factory paddles. Its crop, center pivot, end-cap fitting and proportions match the
shared beam; its angle comes from the host. There are no touch gameplay controls or score HUD.
Landscape is preferred, with responsive portrait fallback and optional orientation lock.

Preparation reconnect clears READY and neutral. Gameplay reconnect retains neutral and
shows only a temporary permission action if capture needs reacquisition. Results, cancel
and lobby return retire capture and hide the guide. Returning from a cached page reconnects
through the authenticated subscription before capture can resume.

## The offer to run as an app

The controller offers **Run Play Shapes as an app** before the host registers a new player,
with guidance for the platform.

- **Continue in browser** dismisses it for that tab's session, including reloads and leave
  and rejoin.
- If storage is restricted, the dismissal is kept in memory.
- Resumed players and windows that are already standalone skip the offer.
- The instructions never appear over gameplay.

## Installing

On iPhone and iPad:

- Open the host URL in Safari, tap Share, then **Add to Home Screen**.
- If shown, keep **Open as Web App** enabled, tap Add, and launch the new icon before joining.
- Older versions use the manifest's standalone mode and Apple metadata. Menu wording and
  placement vary by OS version.
- Safari gives this site no automatic install dialog.

On Android Chrome:

- **INSTALL APP** appears only when a real `beforeinstallprompt` event is available. Its
  native prompt runs directly from the button gesture.
- Dismissal or denial keeps browser continuation available.
- Without that event, use Install app or Add to Home Screen in the browser menu, if offered.
- Trusted HTTPS and Chrome's engagement criteria affect the promotion. The site cannot force
  it.

## Switching between the browser and the app

Install before joining: the original tab then has no registered player to orphan.

- The installed app fetches fresh `/session.json` and connects to that origin's current host.
- If the browser really shares the stored session and token, the host's resume path gives the
  same player to the app and closes the older connection with code 4000. The older window
  stops reconnecting.
- Safari tabs and installed apps may have separate `localStorage`. With no token, the app
  starts ordinary onboarding and never submits a join by itself.
- **If you already joined in a browser, leave that controller first**, then join from the app.
  The onboarding says so. A name already in use stays rejected by the host.
- Closing a joined tab keeps its player for the 60-second reconnect grace. Use Leave to switch
  at once.
- No credentials are placed in the manifest, the start URL, fragments or cookies.

## App identity

- The manifest `id`, `start_url` and `scope` are all `/`, without session identifiers.
- App identity is stable for an origin: scheme, address and port.
- Restarting the host invalidates earlier session tokens and requires a fresh join.
- Changing the LAN IP, hostname, scheme or port changes the origin. The old icon still opens
  the old address. Open the new host's QR code or address and add a new icon.
- The app does not discover or redirect to other hosts.

## Fullscreen and orientation

- Browser continuation attempts fullscreen and portrait lock once per onboarding gesture.
  Failure leaves the game playable.
- There are no fullscreen requests inside Bubbles pointer or key handlers, or before sensor
  permissions.
- A standalone launch uses the manifest and Apple metadata.
- A website cannot force a Safari tab into installed mode, remove all browser chrome, or
  suppress edge gestures the OS reserves.

## Touch guards

- The active lobby, Bubbles and READY surfaces scope `touch-action`, Safari gesture and
  touch-move prevention, selection and callout suppression, and overscroll protection.
- Single taps remain available for READY and Leave.
- Onboarding remains scrollable and zoomable. Name entry, the keyboard and focus are outside
  those guards.

## When the page is hidden, rotated or resized

`immersive.ts` shares the viewport and lifecycle handling, and returns a cleanup function for
temporary controller mounts.

- `--controller-height` tracks `visualViewport.height`, falling back to `innerHeight`. The CSS
  keeps safe-area insets and a dynamic-height fallback.
- Rotation, a viewport or fullscreen change, blur, loss of visibility and `pagehide` cancel
  pending gestures.
- The stick is recreated when the page is focused and visible again.
- Bubbles sends a cancel instead of completing a trace that was interrupted in the
  background.

## How often the phone sends

- Lobby stick: a 45 ms movement throttle and a 100 ms two-axis held refresh, in
  `platform_controls.ts` and `platform_input.ts`.
- Bubbles: a 70 ms motion throttle, a 600 ms heartbeat and a 48-packet cap per gesture, in
  `app.ts`.
- A platform action release, and a Bubbles action start or release, send synchronously.

## No offline cache

- There is no service worker and no Cache Storage. The LAN host serves every asset without
  Internet.
- Every route sends `Cache-Control: no-store`. Session discovery also fetches with
  `cache: no-store`.
- Session metadata, identities, reconnect tokens and live state are never cached.
- To update phones: rebuild the committed `web/public/`, restart the host, and reload or
  relaunch the controllers. If the exported host is in use, rebuild that package first.
- The host must still be reachable on the LAN. Installation provides neither hostless play
  nor certificate trust.

## Icons

- The icons reuse the approved Squircle v1 front idle frame and the Playground logo.
- Regenerate them with `node web/scripts/generate_pwa_icons.mjs`, then import in Godot.
- The HTTP allowlist, the export presets and the pack policy include the manifest, the 180,
  192 and 512 px PNGs, and `pwa.js`.

## Development error panel

During this early development phase, connection and protocol failures show in a selectable
red panel, even when the normal gameplay status is hidden.

- Its log holds six entries. Each records a UTC timestamp, the failing step, the endpoint, the
  browser's error text and the user agent.
- The steps are: fetch, JSON parsing, configuration validation, WebSocket opening and welcome.
- Consecutive identical failures are grouped with a repeat count.
- A WebSocket closure includes its code, its reason and whether it was clean. When the
  browser's error event hides the TLS cause, the panel says so.
- Host protocol errors show their code and message. HTTP failures include their status code.
- Invalid host JSON reports the parser's error type without quoting the payload, which may
  carry credentials. No reconnect tokens or complete protocol payloads are displayed.
- Uncaught JavaScript errors include the source file name, line and column. Unhandled promise
  rejections show the original error text.
- Errors persist across retries. The panel hides after a successful host welcome, and the
  history kept in memory reappears if another failure occurs.

## References

- [Apple iOS 26: turn a website into an app](https://support.apple.com/en-az/guide/iphone/iphea86e5236/26/ios/26)
- [WebKit Safari 26 Home Screen changes](https://webkit.org/blog/17333/webkit-features-in-safari-26-0/#every-site-can-be-a-web-app-on-ios-and-ipados)
- [WebKit Safari 17.2 storage separation](https://webkit.org/blog/14787/webkit-features-in-safari-17-2/)
- [Chrome install-promotion criteria](https://web.dev/articles/install-criteria)
