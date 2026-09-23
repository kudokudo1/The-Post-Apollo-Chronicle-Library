METAPOLLO CRT — SOURCE OPTIMIZATION 10
======================================

Stacks on top of passed Source Optimization 9.

NORMAL TEAR + INTERFERENCE
--------------------------
The active core/edge helpers used to re-check zone_gate() even though they
are only called after that region's mask is already proven non-zero.

Now:
- redundant active-region zone_gate checks are removed
- saturate(m1 + m2 + m3) becomes m1 + m2 + m3 because the vertical
  zones are non-overlapping and each mask is already in [0,1]

SYNC FAULT
----------
During an active sync fault, the unslipped side of the screen previously
still calculated pixel size, wobble sine, UVs, and related work before
discovering it could reuse the center color.

Now:
- slipped_region == 0 immediately applies only the same global brightness
  pulse and returns
- the texture sample / wobble path runs only on the slipped side
- seam math runs only inside the feathered seam itself

No effect strengths, event rolls, positions, timing, colors, geometry,
NO SIGNAL/wake logic, HUM, glare, bloom, halation, phosphor or grid values
were changed.
