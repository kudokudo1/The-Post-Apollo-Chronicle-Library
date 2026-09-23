METAPOLLO CRT — STATE VIEWPORT OPTIMIZATION
===========================================

This build keeps all three confirmed pass merges and changes only the
idle/wake state-update render area.

Before:
- idle writer shaded the full terminal into A
- idle commit shaded the full terminal into persist
- activity writer shaded the full terminal into A
- activity commit shaded the full terminal into persist

Now:
- each of those four groups renders only a 2% x 2% box centered on UV (0.5, 0.5)

Why:
- the working alpha state engine stores/reads the state at STATE_UV = (0.5, 0.5)
- the rest of A/persist is never used by the signal renderer
- this cuts those state passes to about 0.04% of the previous pixel area while active

NOT changed:
- alpha state values
- transition step
- 1-minute idle timing
- wake behavior
- signal visuals
- interference/sync
- glare
- any CRT visual values

Test:
1. Let it idle into NO SIGNAL.
2. Move the mouse / press a key.
3. Confirm the full wake effect plays and returns to normal.
4. Repeat once if desired.

If that works, this optimization stays.
