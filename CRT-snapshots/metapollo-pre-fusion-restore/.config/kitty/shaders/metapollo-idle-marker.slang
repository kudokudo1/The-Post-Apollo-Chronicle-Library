#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO IDLE MARKER
//
// This runs from the SAME timer as NO SIGNAL.
//
// It does not draw anything visibly.
//
// State format:
//
//   R
//     0.0 = NORMAL
//     0.5 = WAKE
//     1.0 = NO SIGNAL / ARMED
//
//   G
//     wake start timestamp
//
//   B
//     wake random seed
//
//   A
//     signature
//
// This pass owns the basic NORMAL / IDLE state.
//
// The wake-state pass comes AFTER this one and can overwrite
// persist with WAKE.
// ============================================================


// TEST ~5 seconds
static const float IDLE_PROGRESS_START =
    0.000008267;


// FINAL ~2 minutes:
//
// static const float IDLE_PROGRESS_START =
//     0.000198413;


static const float STATE_SIGNATURE =
    0.731;


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


    float previous_seed =
        valid
            ? previous.b
            : 0.173;


    // --------------------------------------------------------
    // NO SIGNAL THRESHOLD REACHED
    // --------------------------------------------------------

    if (
        t.animation_progress >=
        IDLE_PROGRESS_START
    ) {
        return float4(
            1.0,
            0.0,
            previous_seed,
            STATE_SIGNATURE
        );
    }


    // --------------------------------------------------------
    // CURRENTLY ACTIVE
    //
    // Wake-state, which runs AFTER this pass, will replace
    // this NORMAL state if the previous frame was IDLE.
    // --------------------------------------------------------

    return float4(
        0.0,
        0.0,
        previous_seed,
        STATE_SIGNATURE
    );
}
