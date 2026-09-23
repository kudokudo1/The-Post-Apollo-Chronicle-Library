#language slang 2026

import kitty_custom_shader_types;

// Pipeline group var overrides this static const before compilation.
static const int EVENT_KIND = 0;

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    // Idle event: vivid green.
    if (EVENT_KIND == 1) {
        return float4(0.03, 1.0, 0.08, color.a);
    }

    // Activity event: vivid yellow.
    if (EVENT_KIND == 2) {
        return float4(1.0, 0.90, 0.03, color.a);
    }

    // Should never be visible in this test.
    return color;
}
