METAPOLLO CRT — SOURCE OPTIMIZATION 9
=====================================

Stacks on top of passed Source Optimization 8.

This pushes the non-overlapping-region optimization one step earlier.

Before:
- during a 2-region event, every pixel still generated both regions'
  random half-height/center values before discovering one region's
  zone_gate was zero.
- during a 3-region event, every pixel generated all three.

Now:
- each pixel checks the exact same zone_gate() first
- only the region whose vertical zone contains that pixel generates
  its half-height, center and mask

The rendering rule is unchanged because region_mask() already multiplied
by this exact zone_gate().

Applied to:
- normal signal tear
- random interference

No event rolls, seeds, region sizes, centers, masks, wave equations,
colors, timings, NO SIGNAL, wake, HUM, glare, bloom, halation, phosphor,
grid, or pipeline settings were changed.
