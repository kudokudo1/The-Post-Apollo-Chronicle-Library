#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO SIGNAL REACQUISITION
//
// Uses the EXACT visual structure proven by:
//
//     metapollo-wake-test
//
// Difference:
//
// It only runs visibly when previous persistent state says:
//
//     WAKE
//
// Its progress is:
//
//     current timestamp - latched wake timestamp
//
// NOT animation_progress.
//
// Therefore mouse movement cannot restart the visual.
// ============================================================


static const float STATE_SIGNATURE =
    0.731;


static const float WAKE_DURATION =
    0.90;


// ============================================================
// PURPLE-GREY STATIC
// ============================================================

static const float3 STATIC_LOW =
    float3(
        0.110,
        0.067,
        0.133
    );


static const float3 STATIC_MID =
    float3(
        0.165,
        0.098,
        0.200
    );


static const float3 STATIC_HIGH =
    float3(
        0.224,
        0.141,
        0.275
    );


// ============================================================
// RANDOM
// ============================================================

float hash21(float2 p) {
    return frac(
        sin(
            dot(
                p,
                float2(
                    127.1,
                    311.7
                )
            )
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
    // IMPORTANT:
    //
    // Read A, not persist.
    //
    // A is our guaranteed snapshot of persistent state from
    // the previous render.
    float4 state =
        t.a.Sample(
            t.pos
        );


    bool valid =
        abs(
            state.a -
            STATE_SIGNATURE
        ) <
        0.002;


    // --------------------------------------------------------
    // NOT WAKING
    // --------------------------------------------------------

    if (
        !valid ||
        state.r <
            0.25 ||
        state.r >
            0.75
    ) {
        return color;
    }


    float wake_start =
        state.g;


    float seed =
        state.b;


    float elapsed =
        max(
            0.0,
            d.timestamp -
            wake_start
        );


    float progress =
        saturate(
            elapsed /
            WAKE_DURATION
        );


    if (
        progress >=
        1.0
    ) {
        return color;
    }


    float2 pixel =
        1.0 /
        float2(
            d.viewport_size_pixels
        );


    // ========================================================
    // DIRECTION
    // ========================================================

    float direction =
        seed >
        0.5
            ? 1.0
            : -1.0;


    // ========================================================
    // 01 — STATIC BLAST
    //
    // Same basic timing as the successful standalone test.
    // ========================================================

    float static_amount =
        1.0 -
        smoothstep(
            0.00,
            0.32,
            progress
        );


    // ========================================================
    // 02 — HUGE TEAR
    // ========================================================

    float tear_in =
        smoothstep(
            0.05,
            0.14,
            progress
        );


    float tear_out =
        1.0 -
        smoothstep(
            0.70,
            0.95,
            progress
        );


    float tear =
        tear_in *
        tear_out;


    float band_center =
        0.52;


    float band_half =
        0.30;


    float band =
        1.0 -
        smoothstep(
            band_half,
            band_half +
            0.03,
            abs(
                t.pos.y -
                band_center
            )
        );


    // ========================================================
    // 03 — HORIZONTAL RIP
    // ========================================================

    float wave =
        sin(
            t.pos.y *
            105.0 +
            d.timestamp *
            48.0
        );


    float x_shift =
        pixel.x *
        150.0 *
        tear *
        band *
        direction *
        (
            0.75 +
            wave *
            0.25
        );


    // ========================================================
    // 04 — WHOLE-SCREEN WOBBLE
    // ========================================================

    float global_shift =
        pixel.x *
        38.0 *
        tear *
        sin(
            t.pos.y *
            13.0 +
            d.timestamp *
            15.0
        );


    // ========================================================
    // 05 — VERTICAL BEND
    // ========================================================

    float y_shift =
        pixel.y *
        14.0 *
        tear *
        band *
        sin(
            (
                t.pos.y -
                band_center
            ) *
            24.0
        );


    // ========================================================
    // SAMPLE DISTORTED SCREEN
    // ========================================================

    float2 uv =
        t.pos +
        float2(
            x_shift +
            global_shift,
            y_shift
        );


    float4 source =
        t.backbuffer.Sample(
            uv
        );


    // ========================================================
    // PURPLE-GREY STATIC
    // ========================================================

    float2 screen_pixel =
        floor(
            t.pos *
            float2(
                d.viewport_size_pixels
            )
        );


    float noise_frame =
        floor(
            d.timestamp *
            60.0
        );


    float n =
        hash21(
            screen_pixel +
            float2(
                noise_frame *
                17.0 +
                seed *
                731.0,

                noise_frame *
                31.0 +
                seed *
                991.0
            )
        );


    float3 noise_color;


    if (
        n <
        0.5
    ) {
        noise_color =
            lerp(
                STATIC_LOW,
                STATIC_MID,
                n *
                2.0
            );
    }
    else {
        noise_color =
            lerp(
                STATIC_MID,
                STATIC_HIGH,
                (
                    n -
                    0.5
                ) *
                2.0
            );
    }


    float3 final_rgb =
        lerp(
            source.rgb,
            noise_color,
            static_amount *
            0.96
        );


    // ========================================================
    // SIGNAL-CATCH BRIGHT LINE
    // ========================================================

    float catch_line =
        1.0 -
        smoothstep(
            0.0,
            0.008,
            abs(
                t.pos.y -
                band_center
            )
        );


    final_rgb +=
        STATIC_HIGH *
        catch_line *
        tear *
        0.40;


    // ========================================================
    // FINAL SNAP CLEAN
    // ========================================================

    float snap =
        smoothstep(
            0.88,
            1.0,
            progress
        );


    final_rgb =
        lerp(
            final_rgb,
            color.rgb,
            snap
        );


    return float4(
        saturate(
            final_rgb
        ),
        color.a
    );
}
