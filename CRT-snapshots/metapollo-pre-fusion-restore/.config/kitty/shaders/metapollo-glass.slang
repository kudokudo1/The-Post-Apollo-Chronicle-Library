#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO GLASS
//
// Static screen-glass pass.
// - Mild center brightness
// - Soft edge darkening
// - Keeps text sharp
// - No color tint
// ============================================================

static const float VIGNETTE_STRENGTH = 0.12;
static const float VIGNETTE_POWER    = 1.65;
static const float CENTER_LIFT       = 0.025;


public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    // Convert UV coordinates from 0..1 to -1..1.
    float2 p = t.pos * 2.0 - 1.0;

    // Distance from the center of the screen.
    float radius = length(p);

    // Smooth radial vignette.
    float vignette =
        1.0 -
        VIGNETTE_STRENGTH *
        pow(saturate(radius), VIGNETTE_POWER);

    // Very slight brightness lift toward the center.
    float center =
        1.0 -
        smoothstep(0.0, 1.0, radius);

    float brightness =
        vignette +
        center * CENTER_LIFT;

    float3 rgb =
        saturate(color.rgb * brightness);

    return float4(rgb, color.a);
}
