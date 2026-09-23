#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO WAKE LATCH
//
// Triggered by user activity / focus.
//
// IMPORTANT:
//
// It reads t.a.
//
// t.a contains persist from the PREVIOUS render.
//
// Therefore:
//
//     previous frame = IDLE
//     current event  = ACTIVITY
//
// can be detected even though the NO SIGNAL timer has already
// reset.
//
// Once wake begins, its ORIGINAL timestamp is preserved.
//
// Mouse movement may restart the Kitty animation group 500
// times, but it DOES NOT restart our timestamp.
// ============================================================


static const float STATE_SIGNATURE =
    0.731;


static const float WAKE_DURATION =
    0.90;


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
            t.pos
        );


    bool valid =
        abs(
            previous.a -
            STATE_SIGNATURE
        ) <
        0.002;


    // --------------------------------------------------------
    // NO VALID STATE YET
    // --------------------------------------------------------

    if (!valid) {
        return float4(
            0.0,
            0.0,
            0.173,
            STATE_SIGNATURE
        );
    }


    float previous_mode =
        previous.r;


    float wake_start =
        previous.g;


    float wake_seed =
        previous.b;


    // ========================================================
    // IDLE -> ACTIVITY
    //
    // THIS STARTS THE WAKE.
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
                13.91
            );


        return float4(
            0.5,
            d.timestamp,
            new_seed,
            STATE_SIGNATURE
        );
    }


    // ========================================================
    // WAKE ALREADY RUNNING
    //
    // Preserve original timestamp.
    // ========================================================

    if (
        previous_mode >
            0.25 &&
        previous_mode <
            0.75
    ) {
        float elapsed =
            max(
                0.0,
                d.timestamp -
                wake_start
            );


        if (
            elapsed <
            WAKE_DURATION
        ) {
            return float4(
                0.5,
                wake_start,
                wake_seed,
                STATE_SIGNATURE
            );
        }
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
