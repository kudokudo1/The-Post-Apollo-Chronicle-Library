METAPOLLO CRT — SOURCE OPTIMIZATION 4
=====================================

Stacks on top of Source Optimizations 1–3.

Only metapollo-signal.slang changes.

NORMAL TEAR
- Core/edge masks are no longer calculated for pixels outside all active
  tear bands.
- The visual equations inside the bands are unchanged.

NO SIGNAL
- Sparse static palette math now runs only on the ~6% of pixels whose
  noise mask is actually on.
- Rare streak position/distance math now runs only when a streak exists.
- The 5x7 NO SIGNAL font routine now runs only inside the plaque region.

BIG SLEEP/WAKE TRANSITION
- When tear amount is exactly zero, reuse incoming color instead of doing
  a center backbuffer fetch and all warp trigonometry.
- Once static_amount reaches exactly zero, skip static hash/palette math.

No strengths, colors, event probabilities, durations, transition timing,
state values, NO SIGNAL appearance, wake geometry, or tear geometry changed.
