METAPOLLO CRT — REAL STATE VIEWPORT PATCH
=========================================

The previous state-viewport test archive accidentally did not insert the
viewport directives. This archive fixes that packaging/patching mistake.

Only these four state groups changed:
- idle state writer
- idle A -> persist commit
- activity state writer
- activity A -> persist commit

Each now renders only:
    viewport_pos  0.49 0.49
    viewport_size 0.02 0.02

The working FSM reads STATE_UV = (0.5, 0.5), so the center sample remains
inside the rendered region.

No visual shader values, timings, colors, or state encodings were changed.
