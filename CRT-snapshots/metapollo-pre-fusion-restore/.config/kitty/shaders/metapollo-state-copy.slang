#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO STATE COPY
//
// Previous persistent state:
//
//     persist
//
// becomes:
//
//     a
//
// for this render.
//
// FULL SCREEN intentionally.
// No tiny state viewport anymore.
// ============================================================


public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    return t.persist.Sample(
        t.pos
    );
}
