# Flappy Race tuning

Select a rules Resource in `Tuning/Active Presets.tres`, under Flappy Race. `Default.tres`
selects `Flight.tres`, `Course.tres` and `View.tres`, and holds the race values below. Changes apply when
the host next starts.

The values are starting points taken from the Flappy Bird reference in
[the design](../../../docs/game-design-documents/Minigames/006/006%20-%20Flappy%20Race.md).
The owner chooses them in play.

## Race

`Default.tres` itself, a `FlappyRaceTuning`, holds the race around the flights.

| Field | Default | Effect |
| --- | --- | --- |
| Countdown | 3 s | 3, 2, 1, GO before forward motion and gravity start. |
| Race time | 360 s | The race ends when it runs out, if not everyone has finished. |
| Last seconds | 10 s | The large countdown at the end of the race timer. |
| Tap window | 0.25 s | How far behind its clock the host settles every flight, so a late tap still counts at its tick. |
| State rate | 20 Hz | How often each phone receives its own settled flight. |

## Flight

`Flight.tres` is a `FlappyFlightTuning`. The phone receives the same values, with durations
turned into whole 60 Hz ticks.

| Field | Default | Effect |
| --- | --- | --- |
| Forward speed | 10 m/s | Constant speed along the course. |
| Flap velocity | 22.5 m/s | Upward speed a tap sets, replacing the current one. |
| Gravity | 75 m/s² | Downward acceleration between taps. |
| Max fall speed | 25 m/s | Fastest fall. |
| Hit box inset | 0.2 m | How far the hit box sits inside the 2 m body cube on every side. |
| Heart count | 3 | Hearts in the row, each a spare respawn. |
| Heart recovery | 10 s | Time to refill one heart; one refills at a time. |
| Respawn cooldown | 2 s | Time from a hit before the floating heart can be tapped. |
| Invulnerable | 1 s | After a respawn, obstacles and the ground cost no heart. |
| Boost share | 0.25 | Extra forward speed from a pickup. |
| Boost time | 3 s | Boost length; another pickup restarts it. |

## Course

`Course.tres` is a `FlappyRaceCourseTuning`. Difficulty follows course progress, from 0 at the
start line to 1 at the finish line.

| Field | Default | Effect |
| --- | --- | --- |
| Perfect run | 120 s | Sets the course length with the forward speed: 1200 m. |
| Start and finish clear | 3 s each | Clear travel before the first and after the last obstacle. |
| View height | 34 m | Ground to the top of the view the course is made for. |
| Start height | 17 m | Body centre at GO. |
| Obstacle width | 6 m | Width of every obstacle pair. |
| Gap lowest and highest share | 0.2 and 0.8 | Gaps stay inside this part of the view height. |
| Respawn distance | 2 m | From a respawn spot to its obstacle's front face. |
| Obstacle spacing | 14 m to 11 m | Curve: front face to front face, which gives about 90 obstacles. |
| Gap height | 8.4 m to 7 m | Curve. |
| Largest gap change | 4 m to 9 m | Curve: most the gap centre moves from one obstacle to the next. |
| Pickup chance | 0.1 to 0.25 | Curve: chance that an obstacle's gap holds a pickup. |
| Pickup size | 1.6 m | Side of a pickup's square trigger. |
| Pickup edge distance | 0.4 m | From a pickup to the top or bottom edge of its gap. |
| Look weights | 0.6, 0.25, 0.15 | Relative chances of a stalagmite, rock stack or crystal cluster. |

The generator also keeps each gap within what a Cubio can still fall or climb to across the
clear space at boosted speed, so every course can be flown; the flyability tests prove it at
the defaults. Validation refuses values that leave no room for a respawn spot, gaps smaller
than the hit box, and pickups that do not fit their gap.

## View

`View.tres` is a `FlappyRaceViewTuning`: how the race looks and feels on the phone and the
shared screen. No value changes a flight; the phone receives them in its snapshot.

| Field | Default | Effect |
| --- | --- | --- |
| Tilt up and down | 25° and 70° | Nose-up tilt at the flap velocity, nose-down at the fastest fall. |
| Tilt response | 0.08 s | How quickly the tilt follows the vertical speed. |
| Hit tumble | 0.6 s | The dizzy tumble at the hit spot before the Cubio leaves play. |
| Pickup face | 0.6 s | How long the beaming face lasts after a pickup. |
| Phone Cubio position | 0.3 | Share of the phone's width from the left edge to its Cubio. |
| Correction | 0.12 s | Time a host correction takes to blend out of the phone's drawing. |
| Heart flight | 0.6 s | Time the spent heart takes to fly from the row to the respawn spot. |
