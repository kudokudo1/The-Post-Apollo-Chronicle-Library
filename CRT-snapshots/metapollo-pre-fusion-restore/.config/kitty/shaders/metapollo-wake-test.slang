#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO WAKE VISUAL TEST
//
// NO STATE.
// NO PERSIST.
// NO IDLE DETECTION.
//
// Press one key and this MUST visibly glitch.
//
// If this works, the wake renderer is good and only the
// idle -> wake trigger needs fixing.
// ============================================================


static const float3 STATIC_LOW =
    float3(0.110, 0.067, 0.133);

static const float3 STATIC_MID =
    float3(0.165, 0.098, 0.200);

static const float3 STATIC_HIGH =
    float3(0.224, 0.141, 0.275);


float hash21(float2 p) {
    return frac(
        sin(
            dot(
                p,
                float2(127.1, 311.7)
            )
        ) *
        43758.5453123
    );
}


public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float progress =
        t.animation_progress;


    float2 pixel =
        1.0 /
        float2(
            d.viewport_size_pixels
        );


    // --------------------------------------------------------
    // STATIC BLAST
    // --------------------------------------------------------

    float static_amount =
        1.0 -
        smoothstep(
            0.00,
            0.32,
            progress
        );


    // --------------------------------------------------------
    // MASSIVE TEAR
    // --------------------------------------------------------

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
            band_half + 0.03,
            abs(
                t.pos.y -
                band_center
            )
        );


    float wave =
        sin(
            t.pos.y * 105.0 +
            d.timestamp * 48.0
        );


    float x_shift =
        pixel.x *
        150.0 *
        tear *
        band *
        (
            0.75 +
            wave * 0.25
        );


    // --------------------------------------------------------
    // WHOLE SCREEN WARP
    // --------------------------------------------------------

    float global_shift =
        pixel.x *
        38.0 *
        tear *
        sin(
            t.pos.y * 13.0 +
            d.timestamp * 15.0
        );


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


    float2 uv =
        t.pos +
        float2(
            x_shift + global_shift,
            y_shift
        );


    float4 source =
        t.backbuffer.Sample(
            uv
        );


    // --------------------------------------------------------
    // PURPLE-GREY STATIC
    // --------------------------------------------------------

    float2 screen_pixel =
        floor(
            t.pos *
            float2(
                d.viewport_size_pixels
            )
        );


    float frame =
        floor(
            d.timestamp *
            60.0
        );


    float n =
        hash21(
            screen_pixel +
            float2(
                frame * 17.0,
                frame * 31.0
            )
        );


    float3 noise;


    if (n < 0.5) {
        noise =
            lerp(
                STATIC_LOW,
                STATIC_MID,
                n * 2.0
            );
    }
    else {
        noise =
            lerp(
                STATIC_MID,
                STATIC_HIGH,
                (n - 0.5) * 2.0
            );
    }


    float3 final_rgb =
        lerp(
            source.rgb,
            noise,
            static_amount * 0.96
        );


    // --------------------------------------------------------
    // SNAP CLEAN
    // --------------------------------------------------------

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
        saturate(final_rgb),
        color.a
    );
}
