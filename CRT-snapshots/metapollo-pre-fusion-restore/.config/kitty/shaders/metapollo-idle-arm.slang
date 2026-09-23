#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO IDLE ARM
//
// Runs ONLY while Kitty considers the user idle.
//
// Every idle frame it writes:
//
//   R = signature 1
//   G = current timestamp
//   B = random seed
//   A = signature 2
//
// Because the timestamp is refreshed continuously while idle,
// the last value left in persist is effectively:
//
//     "the exact moment immediately before wake-up"
// ============================================================


static const float SIGNATURE_R =
    0.731;


static const float SIGNATURE_A =
    0.219;


// ============================================================
// RANDOM
// ============================================================

float hash11(float p) {
    return frac(
        sin(
            p *
            127.1
        ) *
        43758.5453123
    );
}


// ============================================================
// MAIN
// ============================================================

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float seed =
        hash11(
            d.timestamp *
            73.19 +
            float(
                d.frame_counter
            ) *
            0.013
        );


    return float4(
        SIGNATURE_R,
        d.timestamp,
        seed,
        SIGNATURE_A
    );
}
