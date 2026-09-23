#language slang 2026

import kitty_custom_shader_types;


public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float4 state =
        t.persist.Sample(t.pos);


    bool good =
        state.r > 0.8 &&
        state.g < 0.2 &&
        state.b > 0.8 &&
        state.a > 0.8;


    // GREEN:
    // persist definitely survived.
    if (good) {
        return float4(
            0.0,
            1.0,
            0.0,
            1.0
        );
    }


    // RED:
    // persist handoff itself is not behaving.
    return float4(
        1.0,
        0.0,
        0.0,
        1.0
    );
}
