---
tags: [architecture]
level: macro
parent: "[[Architecture]]"
status: draft
code: [minigames/006_flappy_race/workshop/flappy_race_workshop.tscn]
verified:
branch:
---

# Overview and running

What the project does today and how to run it. Read this first if you are new to the
repository.

## What exists today

- Godot 4.7.2 is the authoritative host. Phone controllers are bundled HTML, CSS and
  JavaScript clients over local HTTP and WebSockets.
- **Bubbles and jellyfishes 3D** (minigame 004) opens a shared ready screen with 2–10 registered
  players and starts after every current participant is ready. Players push their bubbles in a
  3D underwater scene on Jolt physics, with a real-time three.js view of each player's own
  bubble on the phone.
- **Tilt Shift 3D** (minigame 005) supports 2/4/6/8/10 players. Each phone enables motion, sets
  a comfortable landscape neutral and confirms READY on the shared Pre-minigame screen before
  launch. Players guide balls in a 3D toy factory on Jolt physics, where each player is a
  paddle in their own colour with a face that reacts. Each phone shows the player's own paddle
  in real-time 3D.
- **Flappy Race** (minigame 006) starts with 1–10 players, the only minigame that can start
  with one. Each phone flies its own Cubio with hearts and a timer; the shared screen follows
  the leader with everyone, on a placeholder course until the cave art lands.
- Registered players appear as 3D Cubios in the Playground lobby, a café plaza viewed from
  the side. Each steers their character from a portrait phone stick and a release-action
  button. The billboard shows the join QR; the lobby controls are in the top-right panel. Near-vertical input
  reaches or crouches, and FALL descends Open supports.
- The live 3D Cubio is the character in phone setup and the Ready screen. Minigame 004
  uses the same model on the shared screen and on the phone.
- F12 opens the debug menu: the Flappy Race workshop, the one-real-player scenario for Bubbles
  and jellyfishes 3D, the Shape Characters lab, the Gyroscope and Accelerometer Lab, and the Tilt Shift 3D factory with
  explicitly simulated controls. The factory review creates ten synthetic players without
  registering phones.
  Bubbles and jellyfishes 3D labels its debug round on the host and the phone.
- The Flappy Race workshop, `minigames/006_flappy_race/workshop/flappy_race_workshop.tscn`,
  runs on its own with F6. Fly through its phone view beside autopilots, edit the Tunables,
  press R to restart with them, then save the preset and use it in the game. See
  [[Minigame Workshops|Minigame workshops]].
- The host defaults to a responsive 1920×1080 GL Compatibility presentation.
- **Project > Tools > Build Standalone Host** creates a portable Windows x86_64 release ZIP.
  There is no Linux build.

What still needs a person's review is listed in [[Pending Reviews]].

## Where things are

The repository contains the Godot project, the browser client, the bundled runtime assets,
the tests and the tooling.

- [README.md](../../README.md): what to install and how to play.
- [AGENTS.md](../../AGENTS.md): how to work on the project.
- [DEVELOPMENT.md](../../DEVELOPMENT.md): the table of development documents.
- [Tuning/README.md](../../Tuning/README.md): tuning values.
