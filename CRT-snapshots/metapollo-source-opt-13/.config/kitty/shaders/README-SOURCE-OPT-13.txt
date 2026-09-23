METAPOLLO CRT — SOURCE OPTIMIZATION 13
======================================

Stacks on top of passed Source Optimization 12.

TEAR + INTERFERENCE MASKS
-------------------------
- region_mask() no longer repeats zone_gate() because every call already
  happens inside the exact same successful zone check.
- smoothstep is skipped at its exact 1.0 / 0.0 endpoints.
- tear core smoothstep is skipped for pixels outside the core radius.
- tear edge work immediately returns zero through the central 65% where
  the old outer and inner masks were both exactly 1.
- interference core smoothstep is skipped outside its tiny 0.007 core.

PHOSPHOR + GRID
---------------
- pixels already at/above PHOSPHOR_FULL and GRID_FULL use the exact
  smoothstep endpoint 1.0 directly.

BLOOM
-----
- color brightness and saturation masks use the exact endpoint 1.0
  directly once already above COLOR_FULL / SATURATION_FULL.

No strengths, colors, thresholds, event rolls, random seeds, timing,
band positions, NO SIGNAL/wake behavior, HUM, glare, sync, radii, or
visual geometry were changed.
