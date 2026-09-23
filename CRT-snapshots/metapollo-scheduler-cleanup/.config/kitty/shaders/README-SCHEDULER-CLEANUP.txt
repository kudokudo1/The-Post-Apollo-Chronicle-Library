METAPOLLO CRT — scheduler cleanup
=================================

This build is intentionally conservative.

Changed:
- CRT group: explicit animation_step 0 instead of Kitty's default periodic step.
- Random interference: animation_step 33 -> 0.
- Sync fault: animation_step 33 -> 0.

Why this is safe in the current architecture:
- Group 14 (HUM + SIGNAL) remains animation_step 16 and continuously redraws
  the full pipeline.
- Kitty runs unconditional groups on rendered frames, so interference/sync
  still evaluate against d.timestamp on those 16 ms frames.
- Their own 33 ms timers were redundant scheduling sources.

NOT changed:
- Alpha-only persistent state engine.
- Idle/activity event writers.
- A -> persist commit passes.
- Any visual strengths, colors, probabilities, durations, geometry, or timing.
- 1-minute Kitty user-idle setting.
- Living glare behavior.

This is a scheduling cleanup, not yet a shader-pass merge. The next larger
optimization would be reducing full-screen passes, which should be profiled
before rewriting because bloom/chroma/halation sample the backbuffer.
