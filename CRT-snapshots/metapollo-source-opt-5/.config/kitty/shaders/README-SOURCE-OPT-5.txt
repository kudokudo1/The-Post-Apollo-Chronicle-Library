METAPOLLO CRT — SOURCE OPTIMIZATION 5
=====================================

This is the first TRUE shader-source fusion.

Before:
    shaders metapollo-phosphor metapollo-grid

Now:
    shaders metapollo-phosphor-grid

The new shader performs the same operations in the same order:
    phosphor -> grid

Important details preserved:
- grid brightness is calculated AFTER phosphor output
- all original pipeline variable names are unchanged
- all current phosphor/grid strengths and thresholds are unchanged
- pixel coordinates are shared instead of calculated twice
- the dark-pixel early-outs from Source Optimization 2 are preserved

This is safer to fuse than bloom/chroma/halation because phosphor and grid
are local color/mask transforms and do not sample neighboring backbuffer pixels.

No other shader or state logic is changed.
