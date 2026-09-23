#language slang 2026

import kitty_custom_shader_types;

static const int EVENT_KIND = 0;
static const float TRANSITION_STEP = 0.018;

// Alpha-only encoding.
// ACTIVE is a single value.
// SLEEP and WAKE are ranges carrying progress.
// NO SIGNAL is a single value.
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

bool is_sleep(float a) {
    return a >= 0.175 && a < 0.425;
}

bool is_wake(float a) {
    return a >= 0.575 && a < 0.825;
}

float sleep_progress(float a) {
    return saturate((a - A_SLEEP_START) / A_SLEEP_SPAN);
}

float wake_progress(float a) {
    return saturate((a - A_WAKE_START) / A_WAKE_SPAN);
}

float4 pack_alpha(float a) {
    // RGB deliberately carries no state.
    return float4(0.0, 0.0, 0.0, saturate(a));
}

public float4 fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float a = t.persist.Sample(STATE_UV).a;

    // Uninitialized/unknown state behaves as ACTIVE.
    bool active = near_value(a, A_ACTIVE);
    bool sleep = is_sleep(a);
    bool no_signal = near_value(a, A_NO_SIGNAL);
    bool wake = is_wake(a);

    if (!active && !sleep && !no_signal && !wake) {
        a = A_ACTIVE;
        active = true;
    }

    if (EVENT_KIND == 1) {
        if (active) {
            return pack_alpha(A_SLEEP_START);
        }

        if (sleep) {
            float p = sleep_progress(a) + TRANSITION_STEP;
            if (p >= 1.0) {
                return pack_alpha(A_NO_SIGNAL);
            }
            return pack_alpha(A_SLEEP_START + p * A_SLEEP_SPAN);
        }

        // Already NO SIGNAL or a newer WAKE state exists.
        return pack_alpha(a);
    }

    if (EVENT_KIND == 2) {
        if (sleep || no_signal) {
            return pack_alpha(A_WAKE_START);
        }

        if (wake) {
            float p = wake_progress(a) + TRANSITION_STEP;
            if (p >= 1.0) {
                return pack_alpha(A_ACTIVE);
            }
            return pack_alpha(A_WAKE_START + p * A_WAKE_SPAN);
        }

        return pack_alpha(A_ACTIVE);
    }

    return pack_alpha(a);
}
