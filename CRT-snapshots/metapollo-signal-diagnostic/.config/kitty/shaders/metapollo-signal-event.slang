#language slang 2026

import kitty_custom_shader_types;

// ============================================================
// METAPOLLO SIGNAL EVENT PULSE
//
// This shader never owns persistent state.
// It only writes a short-lived event code into scratch texture A.
//
// EVENT_KIND:
//   0 = clear / no event
//   1 = Kitty user-idle
//   2 = Kitty user-activity
// ============================================================

static const int EVENT_KIND = 0;

static const float PULSE_NONE     = 0.00;
static const float PULSE_IDLE     = 0.25;
static const float PULSE_ACTIVITY = 0.75;

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    if (EVENT_KIND == 1)
        return float4(PULSE_IDLE, 0.0, 0.0, 1.0);

    if (EVENT_KIND == 2)
        return float4(PULSE_ACTIVITY, 0.0, 0.0, 1.0);

    return float4(PULSE_NONE, 0.0, 0.0, 1.0);
}
