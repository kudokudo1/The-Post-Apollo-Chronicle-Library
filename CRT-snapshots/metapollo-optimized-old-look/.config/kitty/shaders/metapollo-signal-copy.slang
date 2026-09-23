#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO SIGNAL STATE SNAPSHOT
//
// Copy previous-frame persistent state into scratch texture A.
// The next tiny state pass reads A and writes the next state to
// persist.  This avoids sampling persist while also writing it.
// ============================================================

static const float2 STATE_UV = float2(0.005, 0.005);


public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    return t.persist.Sample(
        STATE_UV
    );
}
