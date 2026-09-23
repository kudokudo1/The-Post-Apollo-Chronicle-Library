#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO SLOT-MASK PHOSPHOR
//
// Simulates a late CRT monitor style phosphor texture:
// - RGB vertical phosphor structure
// - horizontal slot / bridge structure
// - alternating row offset for a mesh-like look
//
// This is meant to work together with the CRT scanlines,
// not replace them.
// ============================================================

static const float PHOSPHOR_STRENGTH      = 0.50;
static const float PHOSPHOR_STRIPE_WIDTH  = 1.0;
static const float PHOSPHOR_ROW_HEIGHT    = 3.0;
static const float PHOSPHOR_ROW_OFFSET    = 1.5;
static const float PHOSPHOR_BRIDGE_DARKEN = 0.28;

static const float PHOSPHOR_START         = 0.03;
static const float PHOSPHOR_FULL          = 0.40;


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
    float brightness =
        brightness_of(color.rgb);

    // smoothstep(PHOSPHOR_START, ...) is exactly zero here,
    // so the phosphor mask would not affect the pixel.
    if (brightness <= PHOSPHOR_START) {
        return color;
    }


    float pixel_x =
        floor(t.pos.x * float(d.viewport_size_pixels.x));

    float pixel_y =
        floor(t.pos.y * float(d.viewport_size_pixels.y));


    // --------------------------------------------------------
    // SLOT-MASK ROW GROUPING
    //
    // Alternate the phosphor columns slightly every few rows
    // so it feels more like a mesh / slot-mask screen and less
    // like perfect modern RGB stripes.
    // --------------------------------------------------------

    float row_group =
        floor(pixel_y / PHOSPHOR_ROW_HEIGHT);

    float row_offset =
        fmod(row_group, 2.0) * PHOSPHOR_ROW_OFFSET;

    float stripe =
        floor((pixel_x + row_offset) / PHOSPHOR_STRIPE_WIDTH);

    float phase =
        fmod(stripe, 3.0);


    // --------------------------------------------------------
    // RGB TRIAD
    // --------------------------------------------------------

    float3 triad;

    if (phase < 1.0) {
        triad = float3(1.0, 0.58, 0.58);
    }
    else if (phase < 2.0) {
        triad = float3(0.58, 1.0, 0.58);
    }
    else {
        triad = float3(0.58, 0.58, 1.0);
    }


    // --------------------------------------------------------
    // HORIZONTAL SLOT / BRIDGE STRUCTURE
    //
    // A thin darker bridge appears at the bottom of each row
    // group, which helps create the little rectangular / mesh
    // feeling you see in close CRT monitor photos.
    // --------------------------------------------------------

    float within_row =
        fmod(pixel_y, PHOSPHOR_ROW_HEIGHT);

    float bridge_zone =
        smoothstep(
            PHOSPHOR_ROW_HEIGHT - 1.0,
            PHOSPHOR_ROW_HEIGHT - 0.1,
            within_row
        );

    float row_mask =
        1.0 - bridge_zone * PHOSPHOR_BRIDGE_DARKEN;


    // --------------------------------------------------------
    // APPLY MOSTLY TO LIT PIXELS
    // --------------------------------------------------------

    float lit_amount =
        smoothstep(
            PHOSPHOR_START,
            PHOSPHOR_FULL,
            brightness
        );

    float strength =
        PHOSPHOR_STRENGTH * lit_amount;


    // Combine vertical RGB structure with horizontal slot mask.
    float3 phosphor_mask =
        triad * row_mask;

    float3 final_rgb =
        color.rgb *
        lerp(float3(1.0), phosphor_mask, strength);


    return float4(
        final_rgb,
        color.a
    );
}
