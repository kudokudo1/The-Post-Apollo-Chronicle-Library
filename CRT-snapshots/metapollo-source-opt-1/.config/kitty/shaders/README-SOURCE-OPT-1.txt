METAPOLLO CRT — SOURCE OPTIMIZATION 1
=====================================

This patch uses the exact shader sources from your current archive.

Changes:

1. metapollo-halation.slang
   - Reuses incoming `color` for the center pixel instead of sampling
     t.backbuffer at the exact same UV.
   - Saves one texture fetch for every pixel, every frame.
   - Neighbor samples and all halation equations are unchanged.

2. metapollo-interference.slang
   - After the active bands are calculated, pixels completely outside
     all bands return `color` immediately.
   - Previously those pixels still performed displacement, noise math,
     and a backbuffer sample even though the final result was unchanged.

3. metapollo-signal.slang
   - Same identity shortcut for the normal random tear.
   - Pixels outside the tear bands skip warp/noise math and six texture
     reads while a tear event is active.

No pipeline settings, visual values, random probabilities, durations,
colors, state logic, NO SIGNAL code, wake code, or living glare changed.

This is source-code optimization, not another pass merge.
