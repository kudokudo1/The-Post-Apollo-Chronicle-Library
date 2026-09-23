#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO BLOOM
//
// White / grayscale:
//   uses normal brightness-based bloom.
//
// Colored pixels:
//   can bloom at a lower brightness level.
//
// Dark background:
//   remains below the colored-pixel activation threshold.
// ============================================================

static const float BLOOM_THRESHOLD       = 0.42;
static const float BLOOM_STRENGTH        = 0.98;
static const float BLOOM_RADIUS          = 2.2;

static const float COLOR_BLOOM_BOOST     = 0.32;

static const float COLOR_START           = 0.18;
static const float COLOR_FULL            = 0.34;

static const float SATURATION_START      = 0.12;
static const float SATURATION_FULL       = 0.55;

static const float COLOR_MIN_BLOOM       = 0.72;


float brightness_of(float3 c) {
    return max(c.r, max(c.g, c.b));
}


float saturation_from_brightness(
    float3 c,
    float maxc
) {
    float minc =
        min(c.r, min(c.g, c.b));

    if (maxc <= 0.0001)
        return 0.0;

    return
        (maxc - minc) /
        maxc;
}


float3 bloom_sample(
    KittyTexture tex,
    float2 uv
) {
    float3 c = tex.Sample(uv).rgb;

    float brightness = brightness_of(c);

    // At/below COLOR_START the color bloom mask is exactly zero,
    // and COLOR_START is below BLOOM_THRESHOLD, so the normal
    // brightness mask is zero too. The sample contributes nothing.
    if (brightness <= COLOR_START) {
        return float3(0.0);
    }

    // brightness is already max(r,g,b), so reuse it as maxc rather
    // than calculating the same max-channel expression again.
    float saturation =
        saturation_from_brightness(
            c,
            brightness
        );

    // In this region both possible bloom masks are exactly zero:
    // normal brightness bloom has not started, and colored bloom
    // has no qualifying saturation.
    if (
        brightness <= BLOOM_THRESHOLD &&
        saturation <= SATURATION_START
    ) {
        return float3(0.0);
    }


    // --------------------------------------------------------
    // NORMAL BRIGHTNESS BLOOM
    //
    // Keeps white behaving like it already did.
    // --------------------------------------------------------

    float brightness_mask =
        0.0;

    if (brightness > BLOOM_THRESHOLD) {
        brightness_mask =
            saturate(
                (brightness - BLOOM_THRESHOLD)
                / (1.0 - BLOOM_THRESHOLD)
            );
    }


    // --------------------------------------------------------
    // COLORED PIXEL BLOOM
    //
    // Allows saturated colors to activate before they reach
    // the white/brightness threshold.
    // --------------------------------------------------------

    float color_brightness =
        brightness >= COLOR_FULL
            ? 1.0
            : smoothstep(
                COLOR_START,
                COLOR_FULL,
                brightness
            );

    float color_saturation =
        saturation >= SATURATION_FULL
            ? 1.0
            : smoothstep(
                SATURATION_START,
                SATURATION_FULL,
                saturation
            );

    float color_mask =
        color_brightness *
        color_saturation *
        COLOR_MIN_BLOOM;


    // Whichever rule qualifies more strongly wins.
    float mask =
        max(
            brightness_mask,
            color_mask
        );


    // Saturated colors get a little extra energy.
    float color_boost =
        1.0 +
        saturation * COLOR_BLOOM_BOOST;


    return c * mask * color_boost;
}


public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float2 pixel =
        1.0 / float2(d.viewport_size_pixels);

    float2 r =
        pixel * BLOOM_RADIUS;


    // --------------------------------------------------------
    // CLOSE HALO
    // --------------------------------------------------------

    float3 glow = float3(0.0);

    glow += bloom_sample(t.backbuffer, t.pos + float2( r.x,  0.0));
    glow += bloom_sample(t.backbuffer, t.pos + float2(-r.x,  0.0));
    glow += bloom_sample(t.backbuffer, t.pos + float2( 0.0,  r.y));
    glow += bloom_sample(t.backbuffer, t.pos + float2( 0.0, -r.y));


    // --------------------------------------------------------
    // DIAGONAL HALO
    // --------------------------------------------------------

    glow += bloom_sample(t.backbuffer, t.pos + float2( r.x,  r.y)) * 0.70;
    glow += bloom_sample(t.backbuffer, t.pos + float2(-r.x,  r.y)) * 0.70;
    glow += bloom_sample(t.backbuffer, t.pos + float2( r.x, -r.y)) * 0.70;
    glow += bloom_sample(t.backbuffer, t.pos + float2(-r.x, -r.y)) * 0.70;


    // --------------------------------------------------------
    // WIDER HALO
    // --------------------------------------------------------

    float2 far_r =
        r * 2.4;

    glow += bloom_sample(t.backbuffer, t.pos + float2( far_r.x, 0.0)) * 0.35;
    glow += bloom_sample(t.backbuffer, t.pos + float2(-far_r.x, 0.0)) * 0.35;
    glow += bloom_sample(t.backbuffer, t.pos + float2(0.0,  far_r.y)) * 0.35;
    glow += bloom_sample(t.backbuffer, t.pos + float2(0.0, -far_r.y)) * 0.35;


    glow /= 7.4;


    float3 final_rgb =
        color.rgb +
        glow * BLOOM_STRENGTH;


    return float4(
        saturate(final_rgb),
        color.a
    );
}
