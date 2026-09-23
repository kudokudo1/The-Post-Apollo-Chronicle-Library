METAPOLLO CRT — SOURCE OPTIMIZATION 6
=====================================

This is a true source fusion of:

    metapollo-hum
        ->
    metapollo-signal

Before:
    shaders metapollo-hum metapollo-signal metapollo-reflection

Now:
    shaders metapollo-hum-signal metapollo-reflection

The old ordering is preserved:
1. Calculate the exact HUM UV offset.
2. Sample the hum-shifted center color.
3. Feed that color into the exact current signal renderer.
4. Signal renderer's own t.backbuffer samples still use the original
   group input, matching the previous same-group behavior.
5. Living reflection remains the final shader stage unchanged.

All HUM pipeline variables keep the same names, so the current values
(0.12 px X, 0.05 px Y, speeds 17.3/13.7, secondary 0.24) still override
the shader defaults exactly as before.

This removes one full shader stage from the continuously-running final group.

No effect values, random timing, NO SIGNAL logic, wake logic, tear geometry,
or reflection behavior are changed.
