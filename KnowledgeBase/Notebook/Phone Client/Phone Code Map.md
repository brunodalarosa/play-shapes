---
area: Phone Client
tags: [system, stub]
code: [web/public/app.js, web/src/005_3d_tilt_shift, web/src/shape_paddle, web/src/three_view/shape_paddle.ts, web/src/006_flappy_race, web/src/flappy_flight, web/src/character_preview.ts]
verified:
branch:
---

# Phone Code Map

Hub: [[Phone Client]].

Where the phone client's behavior lives in web/src.


- `web/src/` is the TypeScript source. The build bundles it into one script,
  `web/public/app.js`, which is committed and served by Godot with the page, the styles and
  the icons beside it. Normal play needs neither Node nor Internet. See
  [[Browser Build]].
- The phone onboarding keeps the socket available while players choose a Cubio color and
  enter a name. The host creates the player record only on the final join submission.
- Ordinary ready-up shows one host-confirmed READY/CANCEL toggle. Preview and instructions
  remain on the shared screen.
- Tilt Shift 3D additionally exposes permission and neutral calibration, and shows the player's
  own paddle in 3D through `web/src/005_3d_tilt_shift/`, with a flat drawing without WebGL.
  `web/src/shape_paddle/` holds the rounded outline and the face composition;
  `web/src/three_view/shape_paddle.ts` draws them with three.js.
- Flappy Race flies the player's own Cubio through `web/src/006_flappy_race/`. `race_clock.ts`
  reads the host's clock, `prediction.ts` predicts the flight on `web/src/flappy_flight/` and
  corrects it from host state, `view.ts` draws it with three.js and `fallback.ts` flat,
  `hud.ts` shows the hearts and text, and `phone.ts` ties them to the surface.
- `web/src/character_preview.ts` mounts a live 3D Cubio only in the visible setup canvas.
  Its renderer is in `web/src/three_view/character_preview.ts`; model and face downloads are
  cached with gameplay's assets. Hidden setup screens release their renderer.
- `web/src/screen_wake_lock.ts` owns one visible-page wake lock across every phone screen,
  independent of the active minigame or socket. It adds no host state or messages.
- What the phone screens do is in [[Phone Web App]].
