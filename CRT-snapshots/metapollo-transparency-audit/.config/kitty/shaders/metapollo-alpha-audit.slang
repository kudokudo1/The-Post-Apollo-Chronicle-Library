#language slang 2026

import kitty_custom_shader_types;

// ============================================================
// METAPOLLO — ALPHA AUDIT
//
// TEMPORARY DIAGNOSTIC.
//
// Rightmost strip shows the incoming alpha after every previous
// CRT pass:
//
//   0.0 alpha -> black
//   0.5 alpha -> middle gray
//   0.8 alpha -> light gray
//   1.0 alpha -> white
//
// The diagnostic strip itself uses alpha 1.0 so the grayscale
// reading is not altered by compositor transparency.
// ============================================================

static const float AUDIT_STRIP_START = 0.88;

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    if (t.pos.x < AUDIT_STRIP_START) {
        return color;
    }

    float a = saturate(color.a);

    return float4(
        a,
        a,
        a,
        1.0
    );
}
