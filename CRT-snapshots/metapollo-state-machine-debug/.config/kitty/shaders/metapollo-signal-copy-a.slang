#language slang 2026

import kitty_custom_shader_types;

// Attached pass: copy the full-screen next-state texture A into persist.
// This mirrors kitty's own persistent multi-pass shader pattern.
public float4 fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    return t.a.Sample(t.pos);
}
