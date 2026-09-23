#language slang 2026

import kitty_custom_shader_types;

// ============================================================
// METAPOLLO SIGNAL EVENT STATE
//
// Native Kitty events drive this tiny state writer.
//
// IMPORTANT:
// State is stored in a color texture, so every stored channel is
// deliberately kept inside 0..1.
//
// R = mode byte
// G/B/A = packed 24-bit cycle start clock
//
// Modes:
//   ACTIVE = 17/255
//   SLEEP  = 85/255
//   WAKE   = 153/255
//
// The clock wraps once per week. With 24 packed bits that still
// gives ~36 ms timestamp resolution, easily enough for the 0.90 s
// sleep/wake transition.
//
// Repeated user-activity while WAKE is already active preserves
// the original packed wake clock, so mouse movement cannot restart
// the big wake animation.
// ============================================================

static const int EVENT_KIND = 0;

static const float MODE_ACTIVE = 17.0 / 255.0;
static const float MODE_SLEEP  = 85.0 / 255.0;
static const float MODE_WAKE   = 153.0 / 255.0;

static const float CLOCK_PERIOD = 604800.0;
static const float CLOCK_MAX = 16777215.0;
static const float2 STATE_UV = float2(0.005, 0.005);

bool mode_is(float value, float target) {
    return abs(value - target) < (1.5 / 255.0);
}

float3 encode_clock(float timestamp) {
    float phase = frac(timestamp / CLOCK_PERIOD);
    float packed = floor(phase * CLOCK_MAX + 0.5);

    float hi = floor(packed / 65536.0);
    packed -= hi * 65536.0;

    float mid = floor(packed / 256.0);
    float lo = packed - mid * 256.0;

    return float3(hi, mid, lo) / 255.0;
}

float4 make_state(float mode, float started) {
    float3 clock = encode_clock(started);
    return float4(mode, clock.x, clock.y, clock.z);
}

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float4 previous = t.a.Sample(STATE_UV);

    bool was_sleep = mode_is(previous.r, MODE_SLEEP);
    bool was_wake  = mode_is(previous.r, MODE_WAKE);

    // --------------------------------------------------------
    // Native Kitty user-idle event.
    // Start a brand new sleep cycle exactly once.
    // --------------------------------------------------------
    if (EVENT_KIND == 1) {
        return make_state(
            MODE_SLEEP,
            d.timestamp
        );
    }

    // --------------------------------------------------------
    // Native Kitty user-activity event.
    // --------------------------------------------------------
    if (EVENT_KIND == 2) {
        // First activity after sleep / NO SIGNAL starts wake.
        if (was_sleep) {
            return make_state(
                MODE_WAKE,
                d.timestamp
            );
        }

        // Repeated activity during WAKE preserves the original
        // packed start clock byte-for-byte.
        if (was_wake) {
            return previous;
        }

        // Normal activity while already active.
        return make_state(
            MODE_ACTIVE,
            d.timestamp
        );
    }

    return previous;
}
