METAPOLLO CRT — NO SIGNAL VARIANTS V2
======================================

Fixes the dense-static variant from V1.

Problem observed:
- mode switching worked
- static mode looked like a mostly flat grey/lavender screen

Cause:
- the old NO SIGNAL palette was nearly neutral grey
- the dense mode averaged two noise fields together, compressing contrast

V2:
- restores the intended purple-grey static palette:
    LOW  #1C1122
    MID  #2A1933
    HIGH #392446
    PEAK #49305A
- raises dense-static blend strength from 0.86 to 0.96
- uses readable 2x2 analog snow cells rather than averaging the noise away
- overlays a small amount of fine 1-pixel bright/dark grain
- keeps the same 30-second stateless line/static selector
- keeps the random NO SIGNAL warp/static faults from V1

The line-mode, selector behavior, plaque, fault timing, wake/sleep state,
living glare, and all other CRT effects are otherwise unchanged.
