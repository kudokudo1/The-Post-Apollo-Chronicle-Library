#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO CRT SYNC FAULT
//
// Rare vertical-hold / sync wobble effect.
//
// What it does:
// - very occasionally triggers
// - a portion of the screen slips vertically
// - slight horizontal wobble
// - soft sync seam / split line
// - then snaps back
//
// This should feel like display timing drift, not static.
// ============================================================

static const float EVENT_WINDOW      = 14.0;
static const float EVENT_CHANCE      = 0.16;

static const float MIN_DURATION      = 0.10;
static const float MAX_DURATION      = 0.22;

static const float SHIFT_PIXELS      = 14.0;
static const float WOBBLE_PIXELS     = 1.6;

static const float LINE_SOFTNESS     = 0.012;
static const float LINE_STRENGTH     = 0.18;

static const float BRIGHTNESS_PULSE  = 0.05;


// ------------------------------------------------------------
// HASH
// ------------------------------------------------------------

float hash11(float p) {
    return frac(
        sin(p * 127.1) *
        43758.5453123
    );
}


// ------------------------------------------------------------
// MAIN
// ------------------------------------------------------------

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float time = d.timestamp;


    // --------------------------------------------------------
    // EVENT SCHEDULING
    // --------------------------------------------------------

    float event_slot =
        floor(time / EVENT_WINDOW);

    float local_time =
        fmod(time, EVENT_WINDOW);

    float event_roll =
        hash11(event_slot + 111.3);

    bool event_exists =
        event_roll > (1.0 - EVENT_CHANCE);

    // 84% of sync windows are intentionally empty. Skip all the
    // duration/start/split math in those windows.
    if (!event_exists) {
        return color;
    }

    float event_start =
        0.45 +
        hash11(event_slot + 42.7) *
        (EVENT_WINDOW - 0.9);

    float event_duration =
        MIN_DURATION +
        hash11(event_slot + 89.1) *
        (MAX_DURATION - MIN_DURATION);

    bool event_active =
        event_exists &&
        local_time >= event_start &&
        local_time <= event_start + event_duration;

    if (!event_active) {
        return color;
    }


    // --------------------------------------------------------
    // NORMALIZED EVENT PROGRESS
    // --------------------------------------------------------

    float progress =
        saturate(
            (local_time - event_start) /
            max(event_duration, 0.0001)
        );

    // Ease in/out so it feels like a quick slip and recovery.
    float envelope =
        sin(progress * 3.14159265);


    // --------------------------------------------------------
    // RANDOMIZED SYNC SPLIT LOCATION
    // --------------------------------------------------------

    float split_y =
        0.18 +
        hash11(event_slot + 19.4) *
        0.64;

    float direction =
        hash11(event_slot + 73.8) > 0.5
            ? 1.0
            : -1.0;


    // --------------------------------------------------------
    // REGION SELECTION
    //
    // Everything below the split line slips.
    // The split itself is feathered a little.
    // --------------------------------------------------------

    float slipped_region =
        smoothstep(
            split_y - LINE_SOFTNESS,
            split_y + LINE_SOFTNESS,
            t.pos.y
        );


    // Below the feathered split, slipped_region is exactly zero.
    // In the old path uv == t.pos, seam == 0, and source == color;
    // only the global brightness pulse remains.
    if (slipped_region <= 0.0) {
        float pulse =
            1.0 +
            BRIGHTNESS_PULSE *
            envelope *
            0.5;

        return float4(
            saturate(
                color.rgb *
                pulse
            ),
            color.a
        );
    }


    // --------------------------------------------------------
    // VERTICAL SLIP + HORIZONTAL WOBBLE
    // --------------------------------------------------------

    float2 pixel =
        1.0 / float2(d.viewport_size_pixels);

    float vertical_shift =
        pixel.y *
        SHIFT_PIXELS *
        direction *
        envelope *
        slipped_region;

    float horizontal_wobble =
        pixel.x *
        WOBBLE_PIXELS *
        envelope *
        slipped_region *
        sin(t.pos.y * 120.0 + time * 44.0);


    float2 uv =
        float2(
            saturate(t.pos.x + horizontal_wobble),
            frac(t.pos.y + vertical_shift)
        );

    float4 source =
        t.backbuffer.Sample(uv);


    // --------------------------------------------------------
    // SYNC SEAM LINE
    // --------------------------------------------------------

    float3 seam_glow =
        float3(0.0);


    // slipped_region reaches exactly 1 above the feathered seam,
    // where the old seam value is exactly zero.
    if (slipped_region < 1.0) {
        float seam =
            1.0 -
            smoothstep(
                0.0,
                LINE_SOFTNESS,
                abs(t.pos.y - split_y)
            );

        seam_glow =
            float3(0.18, 0.24, 0.32) *
            seam *
            LINE_STRENGTH *
            envelope;
    }


    // --------------------------------------------------------
    // VERY SLIGHT GLOBAL BRIGHTNESS PULSE
    // --------------------------------------------------------

    float3 final_rgb =
        source.rgb *
        (1.0 + BRIGHTNESS_PULSE * envelope * 0.5);

    final_rgb += seam_glow;


    return float4(
        saturate(final_rgb),
        source.a
    );
}
