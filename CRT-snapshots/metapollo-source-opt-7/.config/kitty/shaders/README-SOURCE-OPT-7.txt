METAPOLLO CRT — SOURCE OPTIMIZATION 7
=====================================

This fuses the final living-reflection stage into the already-passed
HUM+SIGNAL source shader.

Before:
    shaders metapollo-hum-signal metapollo-reflection

Now:
    shaders metapollo-hum-signal-reflection

Exact order is preserved:
    HUM -> SIGNAL -> LIVING REFLECTION

Why this should be visually equivalent:
- HUM still samples the exact same shifted UV first.
- SIGNAL receives that HUM output exactly as in Opt 6.
- SIGNAL's own t.backbuffer accesses still refer to the same original
  group input texture.
- REFLECTION receives the completed SIGNAL color exactly as before.
- REFLECTION itself uses the incoming color plus UV/time; it does not
  need a separate backbuffer snapshot.

The reflection hash helper was namespaced only to avoid a source-level
name collision with SIGNAL's hash helper. Its math is unchanged.

No strengths, colors, event timing, probabilities, state logic,
NO SIGNAL/wake behavior, or glare timing changed.

This removes the last extra shader stage from the continuously-running
final visual group.
