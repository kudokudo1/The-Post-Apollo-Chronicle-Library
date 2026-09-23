#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// BINARY PERSIST TEST
//
// Write unmistakable MAGENTA:
//
//     R = 1
//     G = 0
//     B = 1
//     A = 1
//
// No fractional signatures.
// No timestamps.
// ============================================================

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    return float4(
        1.0,
        0.0,
        1.0,
        1.0
    );
}
