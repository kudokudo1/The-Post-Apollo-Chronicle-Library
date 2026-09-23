#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO PHOSPHOR HALATION / OVERDRIVE
//
// Makes bright colored pixels feel like they are pushing
// light beyond the normal screen surface.
//
// This is NOT normal bloom.
// It is a tighter, denser, more color-faithful glow.
// ============================================================


// ------------------------------------------------------------
// SETTINGS
// ------------------------------------------------------------

static const float HALATION_THRESHOLD = 0.34;
static const float HALATION_SOFTNESS  = 0.22;

static const float COLOR_START = 0.06;
static const float COLOR_FULL  = 0.30;

static const float HOT_CORE_BOOST = 0.14;

static const float INNER_RADIUS_PX = 1.6;
static const float OUTER_RADIUS_PX = 4.5;

static const float INNER_STRENGTH = 0.20;
static const float OUTER_STRENGTH = 0.10;

static const float RESIDUAL_STRENGTH = 0.045;


// ------------------------------------------------------------
// HELPERS
// ------------------------------------------------------------

float luma(float3 c) {
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float chroma_amount(float3 c) {
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    return mx - mn;
}

float bright_color_mask(float3 c) {
    float lum =
        luma(c);

    // Below the lower bright edge, smoothstep() is exactly zero.
    // Returning here also avoids calculating chroma for dark samples.
    if (lum <= HALATION_THRESHOLD) {
        return 0.0;
    }

    float chroma =
        chroma_amount(c);

    // Likewise, colorless samples contribute exactly zero halation.
    if (chroma <= COLOR_START) {
        return 0.0;
    }

    float bright =
        lum >=
        (
            HALATION_THRESHOLD +
            HALATION_SOFTNESS
        )
            ? 1.0
            : smoothstep(
                HALATION_THRESHOLD,
                HALATION_THRESHOLD + HALATION_SOFTNESS,
                lum
            );

    float colorful =
        chroma >= COLOR_FULL
            ? 1.0
            : smoothstep(
                COLOR_START,
                COLOR_FULL,
                chroma
            );

    return
        bright *
        colorful;
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
    float2 pixel =
        1.0 / float2(d.viewport_size_pixels);

    float2 inner_r =
        pixel * INNER_RADIUS_PX;

    float2 outer_r =
        pixel * OUTER_RADIUS_PX;

    // `color` is already the center pixel from this group's input.
    // Reusing it avoids one redundant texture fetch per fragment.
    float4 src4 =
        color;

    float3 src =
        src4.rgb;

    float source_mask =
        bright_color_mask(src);


    // --------------------------------------------------------
    // INNER HALATION
    // --------------------------------------------------------

    float3 i1 = t.backbuffer.Sample(t.pos + float2( inner_r.x, 0.0)).rgb;
    float3 i2 = t.backbuffer.Sample(t.pos + float2(-inner_r.x, 0.0)).rgb;
    float3 i3 = t.backbuffer.Sample(t.pos + float2(0.0,  inner_r.y)).rgb;
    float3 i4 = t.backbuffer.Sample(t.pos + float2(0.0, -inner_r.y)).rgb;

    float3 i5 = t.backbuffer.Sample(t.pos + float2( inner_r.x,  inner_r.y)).rgb;
    float3 i6 = t.backbuffer.Sample(t.pos + float2(-inner_r.x,  inner_r.y)).rgb;
    float3 i7 = t.backbuffer.Sample(t.pos + float2( inner_r.x, -inner_r.y)).rgb;
    float3 i8 = t.backbuffer.Sample(t.pos + float2(-inner_r.x, -inner_r.y)).rgb;

    float3 inner_sum =
        i1 * bright_color_mask(i1) +
        i2 * bright_color_mask(i2) +
        i3 * bright_color_mask(i3) +
        i4 * bright_color_mask(i4) +
        i5 * bright_color_mask(i5) +
        i6 * bright_color_mask(i6) +
        i7 * bright_color_mask(i7) +
        i8 * bright_color_mask(i8);

    float3 inner_glow =
        (inner_sum / 8.0) * INNER_STRENGTH;


    // --------------------------------------------------------
    // OUTER HALATION
    // --------------------------------------------------------

    float3 o1 = t.backbuffer.Sample(t.pos + float2( outer_r.x, 0.0)).rgb;
    float3 o2 = t.backbuffer.Sample(t.pos + float2(-outer_r.x, 0.0)).rgb;
    float3 o3 = t.backbuffer.Sample(t.pos + float2(0.0,  outer_r.y)).rgb;
    float3 o4 = t.backbuffer.Sample(t.pos + float2(0.0, -outer_r.y)).rgb;

    float3 o5 = t.backbuffer.Sample(t.pos + float2( outer_r.x,  outer_r.y)).rgb;
    float3 o6 = t.backbuffer.Sample(t.pos + float2(-outer_r.x,  outer_r.y)).rgb;
    float3 o7 = t.backbuffer.Sample(t.pos + float2( outer_r.x, -outer_r.y)).rgb;
    float3 o8 = t.backbuffer.Sample(t.pos + float2(-outer_r.x, -outer_r.y)).rgb;

    float3 outer_sum =
        o1 * bright_color_mask(o1) +
        o2 * bright_color_mask(o2) +
        o3 * bright_color_mask(o3) +
        o4 * bright_color_mask(o4) +
        o5 * bright_color_mask(o5) +
        o6 * bright_color_mask(o6) +
        o7 * bright_color_mask(o7) +
        o8 * bright_color_mask(o8);

    float3 outer_glow =
        (outer_sum / 8.0) * OUTER_STRENGTH;


    // --------------------------------------------------------
    // HOT CORE + RESIDUAL COLOR
    // --------------------------------------------------------

    float3 hot_core =
        src * source_mask * HOT_CORE_BOOST;

    float3 residual =
        (inner_glow + outer_glow) *
        RESIDUAL_STRENGTH;


    float3 final_rgb =
        src +
        hot_core +
        inner_glow +
        outer_glow +
        residual;


    return float4(
        saturate(final_rgb),
        src4.a
    );
}
