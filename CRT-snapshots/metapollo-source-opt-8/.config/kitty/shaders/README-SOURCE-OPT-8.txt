METAPOLLO CRT — SOURCE OPTIMIZATION 8
=====================================

Stacks on top of passed Source Optimization 7.

This targets active glitch events without changing their shapes.

NORMAL TEAR
-----------
The tear regions are split into non-overlapping vertical zones. For any one
pixel, only ONE of region 1/2/3 can be active.

Old active-event path still calculated:
- direction hashes for all 3 regions
- two wave sine calls for all 3 regions
- bend sine for all 3 regions
- core/edge work for every enabled region

New path:
- identify the one region whose mask is non-zero
- calculate direction/wave/bend/core/edge only for that region

The same per-region formulas, seeds, frequencies, masks and strengths are used.

INTERFERENCE
------------
Same non-overlapping-zone optimization:
- only the active region's direction hash and sine wave are calculated
- interference core is calculated only for the active region

No colors, strengths, random rolls, durations, band placement, tear geometry,
NO SIGNAL behavior, wake behavior, HUM, glare, bloom, halation, phosphor or
grid values were changed.
