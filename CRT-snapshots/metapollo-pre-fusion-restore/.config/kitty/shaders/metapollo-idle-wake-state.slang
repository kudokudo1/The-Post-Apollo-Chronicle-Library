#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO IDLE / WAKE STATE
//
// SINGLE OWNER OF persist.
//
// State:
//
//   R
//     0.0 = NORMAL
//     0.5 = WAKE
//     1.0 = NO SIGNAL
//
//   G
//     wake start timestamp
//
//   B
//     stable wake random seed
//
//   A
//     signature
//
// Previous state is read from scratch texture A.
// New state is written to persist.
//
// This shader uses the SAME idle timer as NO SIGNAL.
// ============================================================


// ------------------------------------------------------------
// TEST
//
// ~5 sec
// ------------------------------------------------------------

static const float IDLE_PROGRESS_START =
    0.000008267;


// FINAL ~2 min:
//
// static const float IDLE_PROGRESS_START =
//     0.000198413;


// ------------------------------------------------------------
// WAKE
// ------------------------------------------------------------

static const float WAKE_DURATION_MIN =
    0.52;

static const float WAKE_DURATION_MAX =
    0.90;


static const float STATE_SIGNATURE =
    0.731;


static const float2 STATE_UV =
    float2(
        0.005,
        0.005
    );


// ============================================================
// RANDOM
// ============================================================

float hash11(float p) {
    return frac(
        sin(
            p *
            127.1
        ) *
        43758.5453123
    );
}


// ============================================================
// MAIN
// ============================================================

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


    bool valid =
        abs(
            previous.a -
            STATE_SIGNATURE
        ) <
        0.002;


    float previous_mode =
        valid
            ? previous.r
            : 0.0;


    float wake_start =
        valid
            ? previous.g
            : 0.0;


    float wake_seed =
        valid
            ? previous.b
            : 0.173;


    // ========================================================
    // CURRENTLY IDLE
    //
    // Once animation_progress passes the same threshold used
    // by NO SIGNAL, remember that the terminal is genuinely
    // in the idle state.
    // ========================================================

    bool currently_idle =
        t.animation_progress >=
        IDLE_PROGRESS_START;


    if (currently_idle) {
        return float4(
            1.0,
            0.0,
            wake_seed,
            STATE_SIGNATURE
        );
    }


    // ========================================================
    // IDLE -> ACTIVE
    //
    // animation_progress reset because activity/focus occurred,
    // while PREVIOUS state still says NO SIGNAL.
    //
    // This is the wake transition.
    // ========================================================

    if (
        previous_mode >
        0.75
    ) {
        float new_seed =
            hash11(
                d.timestamp *
                71.37 +
                float(
                    d.frame_counter
                ) *
                0.017 +
                wake_seed *
                13.9
            );


        return float4(
            0.5,
            d.timestamp,
            new_seed,
            STATE_SIGNATURE
        );
    }


    // ========================================================
    // WAKE CURRENTLY ACTIVE
    // ========================================================

    if (
        previous_mode >
            0.25 &&
        previous_mode <
            0.75
    ) {
        float duration =
            lerp(
                WAKE_DURATION_MIN,
                WAKE_DURATION_MAX,
                hash11(
                    wake_seed *
                    91.7 +
                    4.3
                )
            );


        float elapsed =
            max(
                0.0,
                d.timestamp -
                wake_start
            );


        if (
            elapsed <
            duration
        ) {
            return float4(
                0.5,
                wake_start,
                wake_seed,
                STATE_SIGNATURE
            );
        }


        // Wake finished.
        return float4(
            0.0,
            0.0,
            wake_seed,
            STATE_SIGNATURE
        );
    }


    // ========================================================
    // NORMAL
    // ========================================================

    return float4(
        0.0,
        0.0,
        wake_seed,
        STATE_SIGNATURE
    );
}
