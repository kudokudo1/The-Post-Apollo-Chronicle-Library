#language slang 2026

import kitty_custom_shader_types;

static const float A_ACTIVE = 0.10;

static const float A_SLEEP_START = 0.20;
static const float A_SLEEP_SPAN  = 0.20;

static const float A_NO_SIGNAL = 0.50;

static const float A_WAKE_START = 0.60;
static const float A_WAKE_SPAN  = 0.20;

static const float2 STATE_UV = float2(0.5, 0.5);

bool near_value(float a, float b) {
    return abs(a - b) < 0.025;
}

public float4 fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float a = t.persist.Sample(STATE_UV).a;

    // ACTIVE or uninitialized = CYAN
    if (a < 0.05 || near_value(a, A_ACTIVE))
        return float4(0.0, 1.0, 1.0, 1.0);

    // SLEEP = RED -> ORANGE
    if (a >= 0.175 && a < 0.425) {
        float p = saturate((a - A_SLEEP_START) / A_SLEEP_SPAN);
        return float4(1.0, p, 0.0, 1.0);
    }

    // NO SIGNAL = BLUE
    if (near_value(a, A_NO_SIGNAL))
        return float4(0.0, 0.0, 1.0, 1.0);

    // WAKE = MAGENTA -> PINK/WHITE
    if (a >= 0.575 && a < 0.825) {
        float p = saturate((a - A_WAKE_START) / A_WAKE_SPAN);
        return float4(1.0, p, 1.0, 1.0);
    }

    // Unknown alpha = GREEN
    return float4(0.0, 1.0, 0.0, 1.0);
}
