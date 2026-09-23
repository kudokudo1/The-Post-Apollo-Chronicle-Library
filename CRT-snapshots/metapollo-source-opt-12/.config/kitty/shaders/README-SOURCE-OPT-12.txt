METAPOLLO CRT — SOURCE OPTIMIZATION 12
======================================

Stacks on top of passed Source Optimization 11.

NORMAL TEAR
-----------
When the smear core is zero, smear_offset is exactly zero. The old shader
then sampled the exact same UV four times. Opt 12 samples it once and reuses
that sample for s1/s2/s3 while preserving the exact same weighted math.

LIVING REFLECTION
-----------------
- The two glare fade smoothsteps now run only while a glare event is both
  enabled and currently active. Outside that condition the old envelope was
  exactly zero.
- Content visibility uses exact 0/1 endpoint shortcuts when luma is already
  outside the smoothstep range.

CHROMA
------
- Only the X pixel reciprocal is calculated because Y was never used.
- Bright pixels at/above CHROMA_FULL use the exact smoothstep endpoint 1.0
  directly.

No strengths, colors, timing, probabilities, random seeds, geometry,
NO SIGNAL/wake behavior, HUM, bloom, halation, phosphor/grid, interference,
or sync values were changed.
