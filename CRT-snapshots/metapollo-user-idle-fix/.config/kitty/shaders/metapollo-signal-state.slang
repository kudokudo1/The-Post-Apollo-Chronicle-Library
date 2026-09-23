#language slang 2026

import kitty_custom_shader_types;

// ============================================================
// METAPOLLO SIGNAL EVENT STATE
//
// Native Kitty events drive this tiny state writer.
//
// EVENT_KIND = 1 -> Kitty user-idle event
// EVENT_KIND = 2 -> Kitty user-activity event
//
// State:
//   R = 0 ACTIVE
//   R = 1 SLEEP CYCLE
//   R = 2 WAKE CYCLE
//   G = cycle start timestamp
//   B = stable random seed
//   A = signature
//
// Important: repeated user-activity while WAKE is already active
// preserves the original wake timestamp, so mouse movement cannot
// restart the big wake animation.
// ============================================================

static const int EVENT_KIND = 0;

static const float MODE_ACTIVE = 0.0;
static const float MODE_SLEEP  = 1.0;
static const float MODE_WAKE   = 2.0;

static const float STATE_SIGNATURE = 0.731;
static const float2 STATE_UV = float2(0.005, 0.005);

float hash11(float p) {
    return frac(sin(p * 127.1) * 43758.5453123);
}

bool valid_state(float4 s) {
    return abs(s.a - STATE_SIGNATURE) < 0.002;
}

float4 make_state(float mode, float started, float seed) {
    return float4(mode, started, seed, STATE_SIGNATURE);
}

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float4 previous = t.a.Sample(STATE_UV);
    bool valid = valid_state(previous);

    float previous_mode = valid ? previous.r : MODE_ACTIVE;
    float previous_start = valid ? previous.g : d.timestamp;
    float previous_seed = valid ? previous.b : 0.173;

    // --------------------------------------------------------
    // Native Kitty user-idle event.
    // Start a brand new sleep cycle exactly once.
    // --------------------------------------------------------
    if (EVENT_KIND == 1) {
        float seed = hash11(
            d.timestamp * 83.17 +
            float(d.frame_counter) * 0.019 +
            41.73
        );

        return make_state(
            MODE_SLEEP,
            d.timestamp,
            seed
        );
    }

    // --------------------------------------------------------
    // Native Kitty user-activity event.
    // --------------------------------------------------------
    if (EVENT_KIND == 2) {
        // First activity after sleep/no-signal starts wake.
        if (
            valid &&
            previous_mode > 0.5 &&
            previous_mode < 1.5
        ) {
            float seed = hash11(
                d.timestamp * 71.37 +
                previous_seed * 19.31 +
                float(d.frame_counter) * 0.017
            );

            return make_state(
                MODE_WAKE,
                d.timestamp,
                seed
            );
        }

        // Repeated mouse/key events during or after wake must NOT
        // replace the original wake timestamp.
        if (
            valid &&
            previous_mode > 1.5 &&
            previous_mode < 2.5
        ) {
            return make_state(
                MODE_WAKE,
                previous_start,
                previous_seed
            );
        }

        // Normal activity while already active just keeps ACTIVE.
        return make_state(
            MODE_ACTIVE,
            d.timestamp,
            previous_seed
        );
    }

    // Should only matter if this shader is accidentally run without
    // an EVENT_KIND override.
    if (valid)
        return previous;

    return make_state(
        MODE_ACTIVE,
        d.timestamp,
        previous_seed
    );
}
