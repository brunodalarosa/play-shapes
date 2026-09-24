# Bubbles tuning

Open `Tuning/Active Presets.tres`, then the Bubbles resource. `Default.tres` contains provisional values, not approved game feel. Copy it to a named preset for experiments, select that copy, save, and relaunch. The rules, arenas, and shared-screen scene consume these values. World pixels are Godot 2D coordinates. Normalized gesture distances are fractions of the phone input area's width/height.

Every Inspector tooltip gives the field's purpose, default, safe range, and higher/lower effect. The map below makes the complete contract searchable without opening code. Individual fields clamp to their listed safe ranges; related invalid combinations fail preset validation.

| Field | Default; safe range | Higher value does this |
| --- | --- | --- |
| Character float (pixels) | 4; 0–12 | Makes idle buoyancy more visible |
| Blink interval (seconds) | 3.4; 1.5–7 | Spaces natural blinks farther apart |
| Swipe reaction (seconds) | 0.34; 0.12–0.9 | Holds the push and bubble pull longer |
| Swipe pull (fraction) | 0.17; 0–0.22 | Stretches the drawn bubble farther, without changing collision |
| Character swipe push (pixels) | 13; 0–24 | Moves the character farther within the bubble |
| Maximum swipe hold (seconds) | 0.65; 0.2–2 | Allows a longer touch before its swipe impulse is canceled; completed spins are unaffected |
| Live drag pull (fraction) | 0.20; 0–0.22 | Stretches the bubble farther toward the held drag without changing collision |
| Live drag response (seconds) | 0.08; 0.02–0.4 | Makes deformation follow and settle more slowly |
| Charge glow (opacity) | 0.12; 0–0.25 | Brightens the faint inner glow as circular charge grows |
| Charge wobble (fraction) | 0.07; 0–0.15 | Increases the bubble's continuous wobble while charging |
| Spin surface speed (revolutions/second) | 1.8; 0.2–5 | Rotates the bubble rim faster during authoritative spin |
| Burst (seconds) | 0.26; 0.1–0.6 | Lets curved fragments and motes remain visible longer |
| Decorative particles (count) | 10; 0–32 | Adds spin bubbles and burst motes per player |
| Instruction time (seconds) | 3; 0–15 | Allows more reading and entrance time |
| Countdown (seconds) | 3; 0–10 | Gives more preparation |
| Round duration (seconds) | 90; 10–300 | Allows more collecting |
| Starting bubble radius (world pixels) | 48; 16–160 | Begins with more reach and risk |
| Maximum bubble radius (world pixels) | 110; 32–240 | Allows more reach and risk |
| Radius per jellyfish (world pixels) | 2; 0.1–10 | Grows the bubble faster |
| Captured sprite cap (count) | 12; 0–40 | Shows more creatures without capping score |
| Mass gain per jellyfish (base-mass fraction) | 0.025; 0–0.2 | Makes large bubbles harder to shove |
| Speed loss per jellyfish (fraction) | 0.01; 0–0.1 | Slows large bubbles more |
| Swipe impulse (world pixels/second) | 280; 20–1000 | Gives each accepted swipe more force |
| Swipe recognition distance (normalized) | 0.07; 0.02–0.3 | Requires a longer swipe |
| Maximum bubble speed (world pixels/second) | 460; 50–1200 | Allows faster travel |
| Water drag (per second) | 1.8; 0–8 | Slows a drifting bubble sooner |
| Wall bounciness (multiplier) | 0.65; 0–1 | Increases wall rebound |
| Circles to charge (count) | 2; 1–4 | Requires more drawing in one touch |
| Circle tolerance (radius fraction) | 0.4; 0.2–0.7 | Accepts rougher circles |
| Spin duration (seconds) | 1.5; 0.2–5 | Extends the shove advantage |
| Spin cooldown (seconds) | 5; 0–20 | Spaces out spin activations |
| Spin shove impulse (world pixels/second) | 250; 0–1000 | Pushes opponents farther |
| Jellyfish collider radius (world pixels) | 14; 4–60 | Makes collection easier |
| Starting jellyfish (count) | 20; 0–100 | Gives more early catches |
| Free jellyfish cap (count) | 70; 1–200 | Permits a busier arena |
| Low wave spawn rate (jellyfish/second) | 0.5; 0–10 | Makes quiet periods busier |
| High wave spawn rate (jellyfish/second) | 2; 0–15 | Makes bursts denser |
| Minimum wave duration (seconds) | 4; 1–30 | Stretches every wave |
| Maximum wave duration (seconds) | 9; 1–45 | Allows longer bursts |
| Jellyfish speed (world pixels/second) | 45; 0–200 | Makes catches harder |
| Safe spawn clearance (world pixels) | 90; 0–300 | Reduces immediate spawn collisions |
| Jellyfish entrance (seconds) | 0.6; 0–3 | Delays collection after spawn |
| Released jellyfish lockout (seconds) | 0.5; 0–3 | Delays collection after a pop |
| Pufferfish collider radius (world pixels) | 30; 8–100 | Increases hazard reach |
| Early pufferfish rate (per second) | 0.08; 0–2 | Raises early risk |
| Late pufferfish rate (per second) | 0.3; 0–3 | Raises endgame risk |
| Pufferfish speed (world pixels/second) | 120; 20–400 | Reduces reaction time |
| Disappear on pop (fraction) | 0.5; 0–1 | Leaves fewer to recollect |
| Pop invulnerability (seconds) | 2; 0–8 | Gives safer recovery, without collection |
| Bubble re-form time (seconds) | 0.35; 0.1–1.5 | Makes recovery more visible |
| Pufferfish warning (on/off) | On; boolean | Enables edge notice |
| Pufferfish warning time (seconds) | 0.8; 0–3 | Gives more visual notice |
| Final timer emphasis threshold (whole seconds) | 10; 1–30 | Starts countdown pulses earlier |
| Parallax strength (multiplier) | 1; 0–2 | Moves the environment layers farther |
| Timer pulse strength (multiplier) | 1; 0–2 | Enlarges final countdown beats more |
| Music gain (dB) | -12; -30–0 | Raises Bubbles background music |
| Effect gain (dB) | -6; -30–0 | Raises semantic sound effects |

The maximum radius must exceed the starting radius. Starting jellyfish cannot exceed the free cap. High jellyfish spawn rate must be at least low rate; maximum wave duration must be at least minimum; late pufferfish rate must be at least early rate. Inspector setters clamp out-of-range values; the preset validator rejects any non-finite value that remains. Passing checks establishes safe configuration only; phone feel, accessibility, and balance still need human review.
