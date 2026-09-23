METAPOLLO CRT — SOURCE OPTIMIZATION 3
=====================================

Stacks on top of Source Optimization 1 + 2.

1. INTERFERENCE
   - If the current 6-second event window rolled "no event", return
     immediately before duration/start/region calculations.
   - EVENT_CHANCE is 0.38, so most windows now take this cheap path.

2. NORMAL SIGNAL TEAR
   - Same whole-window shortcut.
   - EVENT_CHANCE is 0.22, so most active-mode tear windows skip almost
     all tear scheduling math.

3. SYNC FAULT
   - Same shortcut after the initial event roll.
   - EVENT_CHANCE is 0.16, so 84% of sync windows exit immediately.

4. HALATION
   - bright_color_mask() now returns immediately for samples whose luma
     or chroma is below the exact smoothstep activation edge.
   - This applies to the center plus all 16 neighbor samples.

5. BLOOM
   - Adds another exact zero-contribution shortcut when a sample is both
     below the normal bloom threshold and below the saturation threshold.

6. LIVING GLASS
   - The moving specular-core and pulse math now runs only while the glare
     envelope is actually active.
   - Permanent base glass and sheen behavior remain unchanged.

No strengths, colors, event probabilities, durations, geometry, state logic,
NO SIGNAL/wake behavior, or glare timing were changed.
