# Play Shapes

Play Shapes is a local-network multiplayer party game. The Godot application
runs the authoritative host on a PC, while players use their phones as web
controllers.

The lobby can start **001 — Flash? Pose!** (the Dancer Simon Says prototype)
or **002 — Bubbles and Jellyfishes**. The shared PC display shows the round;
phones switch to the selected minigame's controls.

## Requirements

To run the project locally, install:

- Git
- Godot 4.7.2 or newer, with the GL Compatibility renderer available
- A desktop PC and phones that can reach the PC on the same local network

Node.js is optional for normal gameplay. It is needed only when rebuilding or
testing the TypeScript browser client. The repository includes the compiled
browser files, so Godot can serve a cloned checkout without an internet
connection or a separate web server.

The Godot MCP/OpenCode integration in this repository is optional developer
tooling; it is not required to launch or play the game.

## First-time setup

1. Clone the repository.
2. Open the `play-shapes` folder in Godot. This folder is the Godot project
   root and contains `project.godot`.
3. Confirm that Godot is using the **GL Compatibility** renderer.
4. If you want to rebuild or test the web client, install the dependencies:

   ```powershell
   cd web
   npm install
   cd ..
   ```

   The browser client is served by Godot from `web/public/`; do not start a
   second web server for normal play.

## Start a local session

1. Open the project in Godot and press **F5** to run the project.
2. Wait for the lobby to appear on the PC.
3. Choose the host's reachable LAN address if more than one address is shown.
4. On each phone, scan the QR code or open the displayed URL. Phones must be
   on the same reachable network as the host; guest Wi-Fi, VPNs, and client
   isolation can prevent connections.
5. Enter a player name and choose **Join game**.

The host uses HTTP port `8080` and WebSocket port `8081` by default. If those
ports are already in use, stop the other host or change the values in
`Tuning/Shared/Networking/Default.tres` before restarting Godot.

## Test the minigames with the debug flow

The debug flow is for testing either minigame with one real registered player.
It does not create simulated players.

1. Start the project and connect exactly one phone to the lobby.
2. Enter a player name and choose **Join game**.
3. On the PC, press **F12** to open the non-pausing debug launcher.
4. Choose **One-player Flash? Pose!** or **One-player Bubbles and Jellyfishes**.
5. Play from the phone while watching the shared PC display. The PC labels the
   selected debug scenario; Bubbles also shows a one-player debug badge on the
   phone and shared screen.
6. Use **Restart current debug scenario** in the F12 launcher to restart with
   a fresh snapshot.
7. Use **Return to lobby** when finished. This keeps the host services alive
   and reopens the lobby for new joins.

Each one-player entry is available only when exactly one real player is
registered. A browser connection by itself does not count as a player.

## Play with 2 or more players

1. Start the project and have each player scan the lobby QR code or open the
   displayed URL.
2. Each player enters a name and chooses **Join game**.
3. On the shared PC display, wait until at least two players appear in the
   roster.
4. Choose **Flash? Pose!** or **Bubbles and Jellyfishes** from the minigame
   dropdown, then choose **Start selected minigame**. New-player admission
   closes for the round.
5. For Flash? Pose!, players respond to the pose prompts when the music stops.
   For Bubbles, swipe to move and draw a circle, then release to spin; the
   phone controller uses portrait orientation.
6. At the results screen, use **Return to lobby** on the shared PC display to
   switch games or start another round. Existing players and LAN services stay
   connected.

Both minigames support **2–10 registered players** in normal play. The wider
lobby can hold more players, but players beyond ten cannot currently be
included in a round.

The minigame works in Safari, but it currently plays best in Chrome. Chrome is
recommended for the most consistent phone controls and fullscreen/orientation
behavior.

## Browser client development

After changing TypeScript in `web/src/`, rebuild the committed browser files:

```powershell
cd web
npm run check
npm run build
npm test
cd ..
```

The generated files in `web/public/` are the files Godot serves to phones.

## Known limitations

- This is an early local-network prototype, not an internet-hosted service.
  The host PC and phones must be able to reach one another on the same LAN.
- Flash? Pose! and Bubbles are currently limited to 2–10 players in normal
  play and one real player in their explicit debug flows. There is no
  matchmaking, queue, or remote multiplayer service.
- Reconnecting players keep their registered seat during the configured
  reconnect grace period, but a disconnected phone's held pose is cleared and
  the player must press again after reconnecting.
- Safari is supported, but Chrome is the preferred browser. Phone-specific
  layout, orientation, and touch behavior still need broader device coverage.
- The recorded iPhone/Android and human-play check covers Flash? Pose!. Bubbles
  still needs its owner-led two-phone and game-feel review. No validation here
  guarantees every phone, browser, Wi-Fi configuration, or accessibility
  setup. See `DEVELOPMENT.md` for evidence and troubleshooting notes.

## Project notes

`DEVELOPMENT.md` contains architecture details, focused test commands,
networking defaults, validation evidence, and implementation caveats. It is
the technical reference for contributors; this README is the current run and
play guide.
