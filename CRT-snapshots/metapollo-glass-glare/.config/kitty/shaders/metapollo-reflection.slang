#language slang 2026

import kitty_custom_shader_types;

// ============================================================
// METAPOLLO — FRONT GLASS REFLECTION
//
// Physical-glass pass:
//   • broad curved diagonal glare across the CRT face
//   • softer upper specular sheen
//   • thin highlight core so the surface has a little "shine"
//   • reflection remains stronger over dark content and quieter
//     over bright glyphs
//
// This pass does not alter the signal/state system.
// ============================================================

static const float3 REFLECTION_TINT =
    float3(0.72, 0.68, 0.77);

// Broad diagonal glare.
static const float PRIMARY_STRENGTH = 0.075;
static const float GLARE_WIDTH = 0.22;
static const float GLARE_CORE_WIDTH = 0.055;
static const float GLARE_CORE_STRENGTH = 0.025;
static const float GLARE_CURVE = 0.10;
static const float GLARE_OFFSET = 0.02;

// Upper glass sheen.
static const float SECONDARY_STRENGTH = 0.035;
static const float SHEEN_WIDTH = 0.48;
static const float SHEEN_HEIGHT = 0.30;
static const float SHEEN_X = 0.36;
static const float SHEEN_Y = 0.79;

// Visibility over underlying terminal brightness.
static const float DARK_VISIBILITY = 0.90;
static const float BRIGHT_VISIBILITY = 0.22;


float
soft_band(
    float distance_from_center,
    float width
) {
    float inner =
        width * 0.18;

    return
        1.0 -
        smoothstep(
            inner,
            width,
            abs(distance_from_center)
        );
}


float
soft_ellipse(
    float2 uv,
    float2 center,
    float2 radius
) {
    float2 q =
        (uv - center) /
        max(
            radius,
            float2(0.001, 0.001)
        );

    float d =
        length(q);

    return
        1.0 -
        smoothstep(
            0.0,
            1.0,
            d
        );
}


public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float2 uv =
        t.pos;

    float2 p =
        uv -
        float2(0.5, 0.5);

    // --------------------------------------------------------
    // BROAD DIAGONAL GLARE
    //
    // Bottom-left UV coordinates mean x + y = constant runs
    // from upper-left toward lower-right.
    //
    // A slight quadratic bend keeps it from looking like a flat
    // Photoshop stripe and makes it follow the CRT face better.
    // --------------------------------------------------------

    float curved_diagonal =
        (uv.x + uv.y - 1.0) +
        GLARE_OFFSET +
        GLARE_CURVE *
        (
            p.x * p.x -
            0.25 * p.y * p.y
        );

    float broad_glare =
        soft_band(
            curved_diagonal,
            GLARE_WIDTH
        );

    // Keep the glare broadest through the middle of the glass and
    // feather it near the extreme corners.
    float across_face =
        1.0 -
        smoothstep(
            0.52,
            0.78,
            length(
                p *
                float2(0.84, 1.0)
            )
        );

    broad_glare *=
        0.58 +
        0.42 * across_face;

    // A narrower core inside the broad reflection gives the face
    // a little polished-glass shine without becoming a white stripe.
    float glare_core =
        soft_band(
            curved_diagonal + 0.018,
            GLARE_CORE_WIDTH
        );

    glare_core *=
        across_face;

    // --------------------------------------------------------
    // SOFT UPPER SHEEN
    //
    // This is intentionally large and low contrast. It should read
    // as room light sitting on the convex glass, not as an overlay.
    // --------------------------------------------------------

    float upper_sheen =
        soft_ellipse(
            uv,
            float2(
                SHEEN_X,
                SHEEN_Y
            ),
            float2(
                SHEEN_WIDTH,
                SHEEN_HEIGHT
            )
        );

    // Pull some of the sheen toward the top-left edge so it feels
    // like a reflection entering from outside the monitor.
    float entry_fade =
        smoothstep(
            0.98,
            0.18,
            uv.x
        ) *
        smoothstep(
            0.20,
            0.92,
            uv.y
        );

    upper_sheen *=
        0.55 +
        0.45 * entry_fade;

    // --------------------------------------------------------
    // CONTENT-AWARE VISIBILITY
    //
    // Glass reflections are easiest to see over black/dark terminal
    // areas and should become much quieter over bright glyphs.
    // --------------------------------------------------------

    float luma =
        dot(
            color.rgb,
            float3(
                0.299,
                0.587,
                0.114
            )
        );

    float bright_mix =
        smoothstep(
            0.08,
            0.72,
            luma
        );

    float visibility =
        lerp(
            DARK_VISIBILITY,
            BRIGHT_VISIBILITY,
            bright_mix
        );

    float reflection =
        broad_glare *
        PRIMARY_STRENGTH;

    reflection +=
        glare_core *
        GLARE_CORE_STRENGTH;

    reflection +=
        upper_sheen *
        SECONDARY_STRENGTH;

    reflection *=
        visibility;

    // Slightly preserve saturation/contrast underneath instead of
    // laying a flat white veil across the terminal.
    float3 reflected =
        REFLECTION_TINT *
        reflection *
        (
            1.0 -
            color.rgb * 0.28
        );

    float3 final_rgb =
        saturate(
            color.rgb +
            reflected
        );

    return
        float4(
            final_rgb,
            color.a
        );
}
