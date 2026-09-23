METAPOLLO CRT — PASS MERGE 3
=============================

Test merge:
    crt -> metapollo-glass

No values changed.

Check specifically:
- CRT curvature/warp
- horizontal scanlines
- corner vignette strength
- center lift / overall brightness
- text shape near the edges

Everything after this group is unchanged from the build that already passed:
- chroma
- bloom
- halation
- phosphor + grid merge
- interference
- sync
- alpha-only idle/wake engine
- HUM + SIGNAL + living reflection merge

Expected result:
- visually identical
- one fewer full-screen group

If the vignette or warp changes at all, restore GOLDEN and this merge does not stay.
