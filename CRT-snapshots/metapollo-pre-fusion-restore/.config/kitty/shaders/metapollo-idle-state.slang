#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO IDLE / WAKE STATE
//
// persist.r = previous/current idle animation progress
// persist.g = wake animation remaining, 1 -> 0
// persist.b = wake-event random seed
// persist.a = signature
//
// Detects:
//
//     NO SIGNAL
//          ↓
//     activity/focus
//          ↓
//     idle progress suddenly resets
//          ↓
//     force wake/reacquisition animation
// ============================================================


static const float STATE_SIGNATURE =
    0.731;


// Pipeline overrides this.
//
// 5 second TEST:
//     0.000008267
//
// 2 minute NORMAL:
//     0.000198413
//
static const float IDLE_PROGRESS_START =
    0.000008267;


static const float WAKE_DURATION_MIN =
    0.52;

static const float WAKE_DURATION_MAX =
    0.90;


static const float2 STATE_UV =
    float2(0.005, 0.005);


// ------------------------------------------------------------
// RANDOM
// ------------------------------------------------------------

float hash11(float p) {
    return frac(
        sin(
            p * 127.1
        ) *
        43758.5453123
    );
}


// ------------------------------------------------------------
// MAIN
// ------------------------------------------------------------

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float4 previous =
        t.a.Sample(
            STATE_UV
        );


    bool valid_state =
        abs(
            previous.a -
            STATE_SIGNATURE
        ) <
        0.002;


    float previous_progress =
        valid_state
            ? previous.r
            : 0.0;


    float previous_wake =
        valid_state
            ? previous.g
            : 0.0;


    float wake_seed =
        valid_state
            ? previous.b
            : 0.173;


    float current_progress =
        t.animation_progress;


    // --------------------------------------------------------
    // DETECT ACTUAL WAKE FROM NO SIGNAL
    //
    // Previous frame had crossed idle threshold.
    // Current frame suddenly reset near zero.
    // --------------------------------------------------------

    bool waking_from_idle =
        previous_progress >=
            IDLE_PROGRESS_START
        &&
        current_progress <
            IDLE_PROGRESS_START *
            0.20;


    if (waking_from_idle) {
        wake_seed =
            hash11(
                d.timestamp *
                37.17 +
                float(
                    d.frame_counter
                ) *
                0.013
            );
    }


    // --------------------------------------------------------
    // RANDOM WAKE DURATION
    // --------------------------------------------------------

    float duration_random =
        hash11(
            wake_seed *
            91.73 +
            7.19
        );


    float wake_duration =
        lerp(
            WAKE_DURATION_MIN,
            WAKE_DURATION_MAX,
            duration_random
        );


    // --------------------------------------------------------
    // COUNTDOWN
    // --------------------------------------------------------

    float wake_remaining =
        previous_wake;


    if (waking_from_idle) {
        wake_remaining =
            1.0;
    }
    else if (
        valid_state &&
        previous_wake >
        0.0
    ) {
        float delta =
            clamp(
                d.timestamp -
                d.last_rendered_at,
                0.0,
                0.100
            );


        wake_remaining =
            max(
                0.0,
                previous_wake -
                delta /
                wake_duration
            );
    }


    return float4(
        current_progress,
        wake_remaining,
        wake_seed,
        STATE_SIGNATURE
    );
}
