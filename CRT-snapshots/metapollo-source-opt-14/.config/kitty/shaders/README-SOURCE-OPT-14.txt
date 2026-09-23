METAPOLLO CRT — SOURCE OPTIMIZATION 14
======================================

Stacks on top of passed Source Optimization 13.

This pass only optimizes the living-glass/reflection geometry.

SOFT GLARE BAND
---------------
- smoothstep is skipped when the pixel is already fully inside (1.0)
  or fully outside (0.0) the glare band.

UPPER SHEEN ELLIPSE
-------------------
- pixels outside the ellipse are rejected using squared distance before
  sqrt/length + smoothstep.
- the exact center uses the exact endpoint 1.0 directly.

SCREEN-FACE FALLOFF
-------------------
- uses squared distance to detect the exact fully-on / fully-off regions.
- sqrt + smoothstep only run in the transition annulus.

GLARE TIMING
------------
- saturate(age) is calculated once and reused by sheen drift, vertical
  sheen motion, and the active specular pulse.

No glare geometry, strengths, timing, probabilities, colors, visibility,
NO SIGNAL/wake behavior, HUM, tears, bloom, halation, phosphor/grid,
interference, sync, or pipeline settings were changed.
