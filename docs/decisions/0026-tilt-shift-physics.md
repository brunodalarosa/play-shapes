# 0026. Tilt Shift shares native physics and integrates a delivery budget

## Situation

Gameplay and workshop preview require identical contacts, seeded entry positions and
exclusive deadlines. Bubbles uses manual kinematics that do not supply this rigid-body
falling/rotating-surface behavior. Independent preview physics would drift from gameplay.

## Decision

An ordinary arena scene owns native rigid balls, fixed-anchor animatable paddles and
floor geometry. Its ordinary rules-controller child remains authoritative for time and
scores. Physical poses approach unwrapped targets with bounded tip travel; presentation
reads the confirmed transform. No global physics setting or phone protocol changes.

Use typed linear intensity points, exact trapezoid integration and midpoint quantiles to
distribute a bounded round budget. This keeps zero spans empty without approximation
from a sampled smooth curve. Position randomness belongs to a separate shift generator.

## What follows

- The workshop can instantiate the gameplay arena, inject content/control and stop it.
- Deadline checks independently protect registration and catches; deferred node cleanup
  never extends scoring. A stalled host may miss pending delivery before the cutoff.
- Both materials participate in friction and restitution; zero paddle bounce alone
  cannot promise a zero-rebound contact. Moving surfaces still transfer momentum.
- Swept-clearance diagnostics expose geometry without moving drafts or changing the
  assignment neighbor relation. Stability claims apply to measured contact envelopes.
- Budget bounds handle/body counts; profiling precedes pooling or a custom pair solver.
