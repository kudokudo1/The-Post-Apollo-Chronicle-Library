METAPOLLO CRT — SOURCE OPTIMIZATION 15
======================================

Built on the passed Opt 14 + Living Glare Variation 1 state.
The glare design itself is frozen and unchanged.

NORMAL TEAR
-----------
- viewport size is converted once and reused by pixel offsets/static coordinates
- removes three clamps that are mathematically redundant with the current
  bounded masks/constants

NO SIGNAL
---------
- fine horizontal line smoothstep runs only when its sine is above the exact
  activation edge
- rolling-band smoothstep runs only inside its narrow feather transition

INTERFERENCE
------------
- viewport size is converted once and reused
- only the X reciprocal needed for horizontal tear displacement is calculated
- removes a redundant clamp from the static blend factor

No strengths, colors, timings, random seeds, geometry, NO SIGNAL design, wake
behavior, HUM, living glare behavior, bloom, halation, phosphor/grid, chroma,
or sync settings changed.
