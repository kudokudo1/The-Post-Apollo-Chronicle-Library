#language slang 2026

import kitty_custom_shader_types;

// ============================================================
// METAPOLLO — LIVING FRONT GLASS
//
// The glass reflection is no longer permanently "on".
//
// Behavior:
//   • every GLARE_EVENT_WINDOW seconds, roll for a reflection
//   • some windows are intentionally skipped
//   • active reflections last 6–15 seconds by default
//   • the broad glare fades in/out
//   • a tighter specular core travels through it
//   • the upper sheen subtly shifts and pulses
//   • a tiny base sheen remains so the screen still reads as glass
//
// No signal/state logic is touched here.
// ============================================================

static const float3 REFLECTION_TINT =
    float3(0.72, 0.68, 0.77);

// Main glare geometry.
static const float PRIMARY_STRENGTH = 0.075;
static const float GLARE_WIDTH = 0.22;
static const float GLARE_CORE_WIDTH = 0.055;
static const float GLARE_CORE_STRENGTH = 0.025;
static const float GLARE_CURVE = 0.10;
static const float GLARE_OFFSET = 0.02;

// Long random timing.
static const float GLARE_EVENT_WINDOW = 50.0;
static const float GLARE_EVENT_CHANCE = 0.70;
static const float GLARE_DURATION_MIN = 6.0;
static const float GLARE_DURATION_MAX = 15.0;

// Motion / shine.
static const float SHINE_TRAVEL = 0.20;
static const float SHINE_PULSE = 0.16;
static const float BASE_GLASS_STRENGTH = 0.006;

// Upper sheen.
static const float SECONDARY_STRENGTH = 0.035;
static const float SHEEN_WIDTH = 0.48;
static const float SHEEN_HEIGHT = 0.30;
static const float SHEEN_X = 0.36;
static const float SHEEN_Y = 0.79;

// Visibility over underlying content.
static const float DARK_VISIBILITY = 0.90;
static const float BRIGHT_VISIBILITY = 0.22;


float hash11(float p) {
    return frac(
        sin(
            p * 127.1
        ) *
        43758.5453123
    );
}


float soft_band(
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


float soft_ellipse(
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

    return
        1.0 -
        smoothstep(
            0.0,
            1.0,
            length(q)
        );
}


public float4 fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float2 uv = t.pos;

    float2 p =
        uv -
        float2(0.5, 0.5);

    // --------------------------------------------------------
    // LONG RANDOM EVENT
    // --------------------------------------------------------

    float safe_window =
        max(
            GLARE_EVENT_WINDOW,
            GLARE_DURATION_MAX + 4.0
        );

    float window_id =
        floor(
            d.timestamp /
            safe_window
        );

    float local_time =
        d.timestamp -
        window_id *
        safe_window;

    float enabled_roll =
        hash11(
            window_id * 17.31 +
            2.47
        );

    float event_enabled =
        enabled_roll <
        GLARE_EVENT_CHANCE
            ? 1.0
            : 0.0;

    float duration =
        lerp(
            GLARE_DURATION_MIN,
            GLARE_DURATION_MAX,
            hash11(
                window_id * 11.73 +
                8.19
            )
        );

    float latest_start =
        max(
            1.0,
            safe_window -
            duration -
            1.0
        );

    float event_start =
        lerp(
            1.0,
            latest_start,
            hash11(
                window_id * 23.17 +
                4.61
            )
        );

    float age =
        (local_time - event_start) /
        max(
            duration,
            0.001
        );

    float inside_event =
        (age >= 0.0 &&
         age <= 1.0)
            ? 1.0
            : 0.0;

    // Slow physical fade rather than popping on/off.
    float fade_in =
        smoothstep(
            0.0,
            0.18,
            age
        );

    float fade_out =
        1.0 -
        smoothstep(
            0.72,
            1.0,
            age
        );

    float envelope =
        event_enabled *
        inside_event *
        fade_in *
        fade_out;

    // --------------------------------------------------------
    // BROAD GLARE
    //
    // Mostly stationary reflection shape. Its intensity comes and
    // goes, while the specular highlight moves through it.
    // --------------------------------------------------------

    float curved_diagonal =
        (uv.x + uv.y - 1.0) +
        GLARE_OFFSET +
        GLARE_CURVE *
        (
            p.x * p.x -
            0.25 *
            p.y * p.y
        );

    float broad_glare =
        soft_band(
            curved_diagonal,
            GLARE_WIDTH
        );

    float across_face =
        1.0 -
        smoothstep(
            0.52,
            0.78,
            length(
                p *
                float2(
                    0.84,
                    1.0
                )
            )
        );

    broad_glare *=
        0.58 +
        0.42 *
        across_face;

    // --------------------------------------------------------
    // MOVING SPECULAR SHINE
    //
    // This is what makes the reflection actually "shine" instead
    // of simply fading a static image in and out.
    // --------------------------------------------------------

    float shine_phase =
        smoothstep(
            0.05,
            0.95,
            saturate(age)
        );

    float shine_shift =
        lerp(
            -SHINE_TRAVEL,
            SHINE_TRAVEL,
            shine_phase
        );

    float glare_core =
        soft_band(
            curved_diagonal +
            shine_shift,
            GLARE_CORE_WIDTH
        );

    glare_core *=
        across_face;

    float pulse =
        1.0 +
        SHINE_PULSE *
        sin(
            saturate(age) *
            6.2831853 *
            2.0
        );

    // --------------------------------------------------------
    // UPPER GLASS SHEEN
    //
    // It drifts slightly during the event so the highlight feels
    // like light moving across curved glass.
    // --------------------------------------------------------

    float sheen_drift =
        (
            shine_phase -
            0.5
        ) *
        0.08;

    float upper_sheen =
        soft_ellipse(
            uv,
            float2(
                SHEEN_X +
                sheen_drift,
                SHEEN_Y +
                0.018 *
                sin(
                    saturate(age) *
                    6.2831853
                )
            ),
            float2(
                SHEEN_WIDTH,
                SHEEN_HEIGHT
            )
        );

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
        0.45 *
        entry_fade;

    // --------------------------------------------------------
    // CONTENT-AWARE VISIBILITY
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

    // Tiny permanent sheen = glass still exists when there is no
    // strong room-light reflection.
    float base_glass =
        (
            broad_glare * 0.55 +
            upper_sheen * 0.45
        ) *
        BASE_GLASS_STRENGTH;

    float active_reflection =
        broad_glare *
        PRIMARY_STRENGTH;

    active_reflection +=
        glare_core *
        GLARE_CORE_STRENGTH *
        pulse;

    active_reflection +=
        upper_sheen *
        SECONDARY_STRENGTH;

    active_reflection *=
        envelope;

    float reflection =
        (
            base_glass +
            active_reflection
        ) *
        visibility;

    float3 reflected =
        REFLECTION_TINT *
        reflection *
        (
            1.0 -
            color.rgb *
            0.28
        );

    return float4(
        saturate(
            color.rgb +
            reflected
        ),
        color.a
    );
}
