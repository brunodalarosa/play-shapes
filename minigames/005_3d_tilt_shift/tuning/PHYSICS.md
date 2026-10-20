# Tilt Shift 3D physics and delivery

The selected rules profile references `Physics.tres`. These values drive the same arena for
runtime and the workshop preview. Duplicate the profile for experiments, select it through the
rules Resource, and restart the shift to apply edits.

## Units

All lengths use the layout's arena width, measured from the arena's top-left with Y down, as
the workshop shows them. The arena multiplies them by 19.2: one world unit is 100 pixels of a
1920 × 1080 frame, and the 1 × 0.5625 arena is 19.2 × 10.8 world units on the Jolt plane.

## Provisional values

| Field | Default | Valid range | Effect |
| --- | --- | --- | --- |
| Ball count | 60 | 0–1,000 per round | White balls, independent of curve shape. |
| Negative ball count | 20 | 0–1,000 per round | Dark blue balls; zero disables them. |
| Negative ball color | `#176dd1` | Opaque RGB | The dark blue balls' colour. |
| Delivery curve | `(0, 1), (1, 1)` | 2–64 linear points | Progress from zero to one; relative intensity. |
| Negative delivery curve | Zero through 20%, peak at 70%, zero from 90% | 2–64 smooth points | Full-round progress; relative intensity. |
| Use position seed / seed | Off / 1 | Boolean / integer | Repeat the entry positions when enabled. |
| Spawn half width | 0.40 | 0–0.49 widths | Centred entry interval; balls must clear both walls. |
| Spawn height | 0.03 | 0–0.5 widths | Gap above the whole ball, beyond the visible top. |
| Delivery cutoff | 6 | 0–300 seconds | Lead time before scoring closes. |
| Ball radius | 0.01587 | 0.003–0.02 widths | Sphere collider and drawn sphere of both ball types. |
| Paddle length / thickness | 0.10 / 0.04 | 0.02–0.20 / 0.006–0.1 widths | Only for layouts that set no size of their own. |
| Corner radius ratio | 0.35 | 0–0.5 of the thickness | Rounds the paddle's ends; never stretches with the length. |
| Depth ratio | 1.0 | 0.5–3 of the thickness | Front-to-back depth; must exceed the ball's diameter. |
| Bin band | 0.07 | 0–0.2 widths | Raises the floor and the bin mouths above the frame's bottom. |
| Gravity | 0.18 | 0–2 widths/s² | Downward acceleration of balls only. |
| Entry speed | 0.05 | 0–1 widths/s | Initial downward speed. |
| Rotation speed | 180 | 1–180 degrees/s | Maximum turning rate toward the target angle. |
| Ball / paddle friction | 0.2 / 0.4 | 0–1 each | Lower slides more; the larger contacting value wins. |
| Ball / paddle restitution | 0 / 0 | 0–1 each | Contact rebound includes both materials. |

Layouts A and B set their own paddle sizes: A `0.20 × 0.04` and B `0.18 × 0.04` widths, with an
automatic paddle of `0.20 × 0.04`. Thicker paddles leave less room between rows; re-space the
layouts in the workshop when the thickness changes.

## Delivery, catches and cleanup

Delivery and scoring follow the 2D Tilt Shift exactly: the curves are integrated into midpoint
quantiles, the positive curve spans the round minus the cutoff, the negative curve the whole
round, and both share spawn bounds, gravity, contacts and positions. A seed repeats only the
entry positions.

The floor sits the bin band above the arena's bottom. A ball that crosses it inside an opening
is caught once, for that opening's team or the trash. The default five openings touch, so every
crossing is caught. Custom gapped presets have floor segments and need the whole ball to fit an
opening.

The deadline, the next round, stop and scene exit remove old balls; rule tokens block late
catches. Each mapped round rebuilds its paddles, walls and floor during preparation.

## Bodies on the plane

Balls are `RigidBody3D` spheres with continuous collision detection, locked to depth zero, that
roll only about the depth axis and fall with their own acceleration. Paddles are
`AnimatableBody3D` bodies turned by code about the depth axis; their convex collider is the
rounded outline the player sees, built by `RoundedBar` from the same measurements.

Turning is bounded so a paddle's tip moves at most half a ball radius per physics step.
Positive angles turn clockwise on screen, as in the rules. Each new paddle contact reports the
speed it closed in at, which the faces use; it never changes a score.

## Measurement

`tests/tilt_shift_3d_rotation_contact_test.gd` turns a paddle through full turns against a
resting ball and requires less than half a ball radius of transient penetration.
`tests/tilt_shift_3d_physics_cost_check.gd` and `tests/tilt_shift_3d_performance_check.gd`
measure the arena and the shared screen; [verification](../../../docs/verification.md) names
the commands.
