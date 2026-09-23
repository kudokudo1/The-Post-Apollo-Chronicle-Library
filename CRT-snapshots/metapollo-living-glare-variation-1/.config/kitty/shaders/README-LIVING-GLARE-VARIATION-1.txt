METAPOLLO CRT — LIVING GLARE VARIATION 1
=========================================

Built on the passed Source Optimization 14 shader.

THIS IS A VISUAL-BEHAVIOR CHANGE, NOT AN OPTIMIZATION PASS.

Fixed every event:
- glare/specular travel direction is ALWAYS left -> right
- reflection tint stays unchanged
- event chance stays unchanged
- existing 6–15 second random event duration stays unchanged
- tiny permanent glass/base sheen stays unchanged

Stable random values chosen once per event:
- vertical placement: +/- 0.08
- diagonal slope: +/- 0.035 around the existing angle
- broad glare width: 0.18–0.28
- core width: 0.045–0.075
- event brightness multiplier: 0.80–1.12
- travel distance multiplier: 0.90–1.12
- vertical drift: +/- 0.025
- brightness breathing: 0.03–0.10
- width breathing: 0.01–0.035
- upper sheen X offset: +/- 0.035
- upper sheen Y offset: +/- 0.020
- upper sheen strength: 0.90–1.10
- small horizontal event offset: +/- 0.025

During the event:
- the broad body drifts gently left -> right
- the bright core always sweeps left -> right
- brightness breathes slowly
- width breathes slightly
- vertical movement is smooth and restrained

No frame-to-frame random jitter is used. Each event gets one stable family
of values so it feels like one physical lighting condition passing across
the glass, rather than procedural noise.

Shimmer and angle-drift are intentionally NOT added yet.
