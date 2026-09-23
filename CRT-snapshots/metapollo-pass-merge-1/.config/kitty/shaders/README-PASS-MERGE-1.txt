METAPOLLO CRT — PASS MERGE 1
=============================

What changed:
- The final standalone FRONT GLASS REFLECTION group was removed.
- metapollo-reflection is now the LAST shader in Group 14:
    metapollo-hum -> metapollo-signal -> metapollo-reflection

Why this should preserve the look:
- Kitty defines a group as a shader chain where each shader receives the
  previous shader's output color.
- The living reflection shader uses the incoming `color` plus UV/time and
  does not sample t.backbuffer.
- Therefore putting reflection last in Group 14 preserves the same ordering
  it had as a separate final group: signal output first, reflection second.

What was NOT changed:
- No reflection values or random timing.
- No CRT/glass/chroma/bloom/halation/phosphor/grid values.
- No interference/sync values.
- No alpha-only state logic.
- No idle/wake behavior.
- No scheduler cleanup values.

Expected result:
- Visually identical.
- One fewer full-screen rendering group.

If anything looks different, restore the GOLDEN files you just made.
