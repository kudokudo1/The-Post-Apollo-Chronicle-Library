#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO CHROMATIC IMPERFECTION
//
// Slight RGB misalignment like a real CRT.
//
// - Mostly affects illuminated pixels
// - Dark background stays basically untouched
// - Horizontal separation only
// - Original image remains sharp
// ============================================================

static const float CHROMA_SHIFT_PIXELS = 0.80;
static const float CHROMA_STRENGTH     = 0.45;

static const float CHROMA_START        = 0.08;
static const float CHROMA_FULL         = 0.55;


// ------------------------------------------------------------
// Brightness helper
// ------------------------------------------------------------

float brightness_of(float3 c) {
    return max(c.r, max(c.g, c.b));
}


// ------------------------------------------------------------
// Main
// ------------------------------------------------------------

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    // Below CHROMA_START, smoothstep() is exactly zero, so the
    // old shader ultimately returned the incoming color unchanged.
    // Bail out before the two side texture reads.
    float brightness =
        brightness_of(color.rgb);

    if (brightness <= CHROMA_START) {
        return color;
    }


    float pixel_x =
        1.0 /
        float(
            d.viewport_size_pixels.x
        );

    float2 offset =
        float2(
            pixel_x * CHROMA_SHIFT_PIXELS,
            0.0
        );


    // Sample slightly to each side.
    float4 left =
        t.backbuffer.Sample(t.pos - offset);

    float4 right =
        t.backbuffer.Sample(t.pos + offset);


    // Slightly misregister red and blue.
    //
    // Red comes from the left,
    // green stays centered,
    // blue comes from the right.
    float3 split_rgb =
        float3(
            left.r,
            color.g,
            right.b
        );


    // --------------------------------------------------------
    // ONLY REALLY SHOW ON LIT AREAS
    // --------------------------------------------------------

    float lit_amount =
        brightness >= CHROMA_FULL
            ? 1.0
            : smoothstep(
                CHROMA_START,
                CHROMA_FULL,
                brightness
            );


    float strength =
        CHROMA_STRENGTH * lit_amount;


    // Preserve the original image and blend in only a small
    // amount of RGB separation.
    float3 final_rgb =
        lerp(
            color.rgb,
            split_rgb,
            strength
        );


    return float4(
        final_rgb,
        color.a
    );
}
