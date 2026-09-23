#language slang 2026
import kitty_custom_shader_types;

static const int EVENT_KIND = 0;

public float4 fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    // CYAN startup
    if (EVENT_KIND == 0)
        return float4(0.0, 1.0, 1.0, 1.0);

    // GREEN idle
    if (EVENT_KIND == 1)
        return float4(0.0, 1.0, 0.0, 1.0);

    // YELLOW activity
    if (EVENT_KIND == 2)
        return float4(1.0, 1.0, 0.0, 1.0);

    return float4(1.0, 0.0, 1.0, 1.0);
}
