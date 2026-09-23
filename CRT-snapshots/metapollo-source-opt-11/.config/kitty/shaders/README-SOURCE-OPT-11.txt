METAPOLLO CRT — SOURCE OPTIMIZATION 11
======================================

Stacks on top of passed Source Optimization 10.

PHOSPHOR + GRID
---------------
- Very dark pixels now return before pixel-coordinate/modulo work.
- If phosphor did not activate, grid reuses the already-known original
  brightness instead of calculating max(r,g,b) again.
- Pixels that are on neither a vertical nor horizontal grid line return
  before grid smoothstep/multiplier math. Their old grid darkening was
  exactly zero.

BLOOM
-----
- Each bloom sample already calculated max(r,g,b) as brightness.
  Saturation now reuses that exact value instead of calculating max(r,g,b)
  a second time.
- Normal brightness-bloom division is skipped below BLOOM_THRESHOLD,
  where the old brightness mask was exactly zero.

HALATION
--------
- If luma/chroma are already above the upper edge of their smoothstep,
  the mask uses the exact endpoint value 1.0 directly.

No colors, strengths, radii, thresholds, pixel patterns, event timing,
NO SIGNAL/wake behavior, HUM, glare, tear, interference or sync geometry
were changed.
