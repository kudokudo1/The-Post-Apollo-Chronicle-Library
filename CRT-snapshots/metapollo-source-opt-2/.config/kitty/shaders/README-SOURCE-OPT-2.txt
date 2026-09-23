METAPOLLO CRT — SOURCE OPTIMIZATION 2
=====================================

This patch stacks on top of Source Optimization 1.

Exact-identity shortcuts added:

1. CHROMA
   Very dark pixels now return before the two left/right texture reads.
   At that brightness the original chroma strength was exactly zero.

2. BLOOM
   Neighbor samples still happen (they are required for bloom), but sampled
   pixels below COLOR_START return zero before saturation and mask math.
   Their original bloom contribution was exactly zero.

3. PHOSPHOR
   Pixels below PHOSPHOR_START return before slot-mask/triad calculations.

4. GRID
   Pixels below GRID_START return before grid coordinate/mask calculations.

5. SYNC
   During the rare sync fault, pixels above the slipped region reuse incoming
   `color` rather than fetching t.backbuffer at the exact same UV. The global
   brightness pulse and seam math are still applied exactly as before.

No effect strengths, colors, probabilities, durations, geometry, state logic,
NO SIGNAL behavior, wake behavior, or living glare values were changed.
