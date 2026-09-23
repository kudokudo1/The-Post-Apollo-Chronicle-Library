#language slang 2026

import kitty_custom_shader_types;

static const float MODE_ACTIVE    = 0.10;
static const float MODE_SLEEP     = 0.35;
static const float MODE_NO_SIGNAL = 0.60;
static const float MODE_WAKE      = 0.85;

static const float STATE_SIGNATURE = 0.731;
static const float2 STATE_UV = float2(0.5, 0.5);

bool mode_is(float value, float target) {
    return abs(value - target) < 0.035;
}

public float4 fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float4 s = t.persist.Sample(STATE_UV);

    // Invalid/uninitialized state = WHITE
    if (abs(s.a - STATE_SIGNATURE) >= 0.01)
        return float4(1.0, 1.0, 1.0, 1.0);

    // ACTIVE = CYAN
    if (mode_is(s.r, MODE_ACTIVE))
        return float4(0.0, 1.0, 1.0, 1.0);

    // SLEEP = RED -> ORANGE as G/progress advances
    if (mode_is(s.r, MODE_SLEEP))
        return float4(1.0, saturate(s.g), 0.0, 1.0);

    // NO SIGNAL = BLUE
    if (mode_is(s.r, MODE_NO_SIGNAL))
        return float4(0.0, 0.0, 1.0, 1.0);

    // WAKE = MAGENTA -> PINK/WHITE as G/progress advances
    if (mode_is(s.r, MODE_WAKE))
        return float4(1.0, saturate(s.g), 1.0, 1.0);

    // Valid signature but unknown mode = GREEN-ish raw marker
    return float4(saturate(s.r), 1.0, saturate(s.g), 1.0);
}
