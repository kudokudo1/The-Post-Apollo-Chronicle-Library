#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO CRT HUM / MICRO-JITTER
//
// Tiny continuous analog vibration.
//
// This should be felt more than consciously noticed.
// ============================================================

static const float HUM_X_PIXELS = 0.34;
static const float HUM_Y_PIXELS = 0.16;

static const float HUM_X_SPEED = 17.3;
static const float HUM_Y_SPEED = 13.7;

static const float HUM_SECONDARY = 0.30;


public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float time =
        d.timestamp;


    float2 pixel =
        1.0 /
        float2(
            d.viewport_size_pixels
        );


    float x1 =
        sin(
            time *
            HUM_X_SPEED *
            6.2831853
        );


    float y1 =
        sin(
            time *
            HUM_Y_SPEED *
            6.2831853
        );


    float x2 =
        sin(
            time *
            (
                HUM_X_SPEED *
                0.371
            ) *
            6.2831853 +
            1.7
        );


    float y2 =
        sin(
            time *
            (
                HUM_Y_SPEED *
                0.417
            ) *
            6.2831853 +
            3.1
        );


    float x_motion =
        (
            x1 +
            x2 *
            HUM_SECONDARY
        ) *
        HUM_X_PIXELS;


    float y_motion =
        (
            y1 +
            y2 *
            HUM_SECONDARY
        ) *
        HUM_Y_PIXELS;


    float2 uv =
        t.pos +
        float2(
            pixel.x *
            x_motion,
            pixel.y *
            y_motion
        );


    uv =
        clamp(
            uv,
            float2(0.0),
            float2(1.0)
        );


    return
        t.backbuffer.Sample(
            uv
        );
}
