#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO SCREEN TEAR / WARP
//
// 75% = one warped region
// 20% = two warped regions
//  5% = three warped regions
//
// Rare triple events can span essentially the entire terminal.
//
// Durations:
// ~76% short
// ~19% medium
//  ~5% long
//
// Noise uses the Metapollo palette rather than grayscale.
// ============================================================


// ------------------------------------------------------------
// PALETTE
// ------------------------------------------------------------

static const float3 THEME_BLACK =
    float3(0.106, 0.024, 0.137);

static const float3 THEME_DARK =
    float3(0.086, 0.020, 0.122);

static const float3 THEME_CYAN =
    float3(0.333, 0.812, 0.792);


// ------------------------------------------------------------
// EVENT FREQUENCY
// ------------------------------------------------------------

static const float EVENT_WINDOW = 11.0;
static const float EVENT_CHANCE = 0.22;


// ------------------------------------------------------------
// REGION COUNT
// ------------------------------------------------------------

static const float TWO_REGION_CHANCE   = 0.20;
static const float THREE_REGION_CHANCE = 0.05;

static const float CATASTROPHIC_THREE_CHANCE = 0.20;


// ------------------------------------------------------------
// RANDOM DURATION
// ------------------------------------------------------------

static const float SHORT_DURATION_MIN = 0.09;
static const float SHORT_DURATION_MAX = 0.38;

static const float MEDIUM_DURATION_MIN = 0.45;
static const float MEDIUM_DURATION_MAX = 1.20;

static const float LONG_DURATION_MIN = 1.30;
static const float LONG_DURATION_MAX = 3.00;

static const float MEDIUM_DURATION_CHANCE = 0.19;
static const float LONG_DURATION_CHANCE   = 0.05;


// ------------------------------------------------------------
// APPEARANCE
// ------------------------------------------------------------

static const float MIN_BAND_HEIGHT = 0.10;
static const float MAX_BAND_HEIGHT = 0.34;

static const float SHIFT_PIXELS        = 44.0;
static const float BEND_PIXELS         = 6.0;
static const float SMEAR_PIXELS        = 18.0;
static const float CHROMA_SPLIT_PIXELS = 1.4;

static const float NOISE_STRENGTH = 0.09;
static const float EDGE_GLOW      = 0.12;


// ------------------------------------------------------------
// RANDOM
// ------------------------------------------------------------

float hash11(float p) {
    return frac(
        sin(p * 127.1) *
        43758.5453123
    );
}


float hash21(float2 p) {
    return frac(
        sin(
            dot(
                p,
                float2(127.1, 311.7)
            )
        ) *
        43758.5453123
    );
}


// ------------------------------------------------------------
// REGION HELPERS
// ------------------------------------------------------------

float zone_gate(
    float y,
    float zone_min,
    float zone_max
) {
    return
        step(zone_min, y) *
        (
            1.0 -
            step(zone_max, y)
        );
}


float choose_half_height(
    float seed,
    float zone_min,
    float zone_max,
    float min_half,
    float max_half
) {
    float zone_half =
        (
            zone_max -
            zone_min
        ) *
        0.5;


    float hi =
        min(
            max_half,
            zone_half
        );


    float lo =
        min(
            min_half,
            hi
        );


    return
        lo +
        hash11(seed) *
        (
            hi -
            lo
        );
}


float choose_center(
    float seed,
    float zone_min,
    float zone_max,
    float half_height
) {
    float lo =
        zone_min +
        half_height;


    float hi =
        zone_max -
        half_height;


    return
        lo +
        hash11(
            seed +
            29.71
        ) *
        max(
            0.0,
            hi - lo
        );
}


float region_mask(
    float y,
    float center,
    float half_height,
    float zone_min,
    float zone_max
) {
    float distance =
        abs(
            y -
            center
        );


    float mask =
        1.0 -
        smoothstep(
            half_height,
            half_height + 0.03,
            distance
        );


    return
        mask *
        zone_gate(
            y,
            zone_min,
            zone_max
        );
}


float region_core(
    float y,
    float center,
    float half_height,
    float zone_min,
    float zone_max
) {
    float core =
        1.0 -
        smoothstep(
            0.0,
            half_height * 0.65,
            abs(
                y -
                center
            )
        );


    return
        core *
        zone_gate(
            y,
            zone_min,
            zone_max
        );
}


float region_edge(
    float y,
    float center,
    float half_height,
    float zone_min,
    float zone_max
) {
    float distance =
        abs(
            y -
            center
        );


    float outer =
        1.0 -
        smoothstep(
            half_height,
            half_height + 0.03,
            distance
        );


    float inner =
        1.0 -
        smoothstep(
            half_height * 0.65,
            half_height,
            distance
        );


    return
        saturate(
            outer -
            inner
        ) *
        zone_gate(
            y,
            zone_min,
            zone_max
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
    float time =
        d.timestamp;


    // --------------------------------------------------------
    // EVENT SLOT
    // --------------------------------------------------------

    float event_slot =
        floor(
            time /
            EVENT_WINDOW
        );


    float local_time =
        fmod(
            time,
            EVENT_WINDOW
        );


    bool event_exists =
        hash11(
            event_slot +
            301.7
        ) >
        (
            1.0 -
            EVENT_CHANCE
        );


    // --------------------------------------------------------
    // RANDOM DURATION
    // --------------------------------------------------------

    float duration_roll =
        hash11(
            event_slot +
            99.1
        );


    float duration_value =
        hash11(
            event_slot +
            199.7
        );


    float event_duration;


    if (
        duration_roll <
        LONG_DURATION_CHANCE
    ) {
        event_duration =
            LONG_DURATION_MIN +
            duration_value *
            (
                LONG_DURATION_MAX -
                LONG_DURATION_MIN
            );
    }
    else if (
        duration_roll <
        LONG_DURATION_CHANCE +
        MEDIUM_DURATION_CHANCE
    ) {
        event_duration =
            MEDIUM_DURATION_MIN +
            duration_value *
            (
                MEDIUM_DURATION_MAX -
                MEDIUM_DURATION_MIN
            );
    }
    else {
        event_duration =
            SHORT_DURATION_MIN +
            duration_value *
            (
                SHORT_DURATION_MAX -
                SHORT_DURATION_MIN
            );
    }


    float available_start_time =
        max(
            0.10,
            EVENT_WINDOW -
            event_duration -
            0.35
        );


    float event_start =
        0.15 +
        hash11(
            event_slot +
            14.3
        ) *
        available_start_time;


    bool event_active =
        event_exists &&
        local_time >=
            event_start &&
        local_time <=
            event_start +
            event_duration;


    if (!event_active) {
        return color;
    }


    float progress =
        saturate(
            (
                local_time -
                event_start
            ) /
            max(
                event_duration,
                0.0001
            )
        );


    float envelope =
        sin(
            progress *
            3.14159265
        );


    // --------------------------------------------------------
    // REGION COUNT
    // --------------------------------------------------------

    float region_roll =
        hash11(
            event_slot +
            412.6
        );


    bool three_regions =
        region_roll <
        THREE_REGION_CHANCE;


    bool two_regions =
        !three_regions &&
        region_roll <
        (
            THREE_REGION_CHANCE +
            TWO_REGION_CHANCE
        );


    bool use_region_2 =
        two_regions ||
        three_regions;


    bool use_region_3 =
        three_regions;


    bool catastrophic_three =
        three_regions &&
        hash11(
            event_slot +
            711.4
        ) <
        CATASTROPHIC_THREE_CHANCE;


    // --------------------------------------------------------
    // ZONES
    // --------------------------------------------------------

    float z1_min = 0.0;
    float z1_max = 1.0;

    float z2_min = 0.0;
    float z2_max = 0.0;

    float z3_min = 0.0;
    float z3_max = 0.0;


    if (three_regions) {
        z1_min = 0.0;
        z1_max = 1.0 / 3.0;

        z2_min = 1.0 / 3.0;
        z2_max = 2.0 / 3.0;

        z3_min = 2.0 / 3.0;
        z3_max = 1.0;
    }
    else if (two_regions) {
        z1_min = 0.0;
        z1_max = 0.5;

        z2_min = 0.5;
        z2_max = 1.0;
    }


    // --------------------------------------------------------
    // REGION 1
    // --------------------------------------------------------

    float region1_max =
        catastrophic_three
            ? (
                z1_max -
                z1_min
            ) * 0.5
            : MAX_BAND_HEIGHT;


    float region1_min =
        catastrophic_three
            ? region1_max
            : MIN_BAND_HEIGHT;


    float h1 =
        choose_half_height(
            event_slot + 101.7,
            z1_min,
            z1_max,
            region1_min,
            region1_max
        );


    float c1 =
        choose_center(
            event_slot + 141.3,
            z1_min,
            z1_max,
            h1
        );


    float m1 =
        region_mask(
            t.pos.y,
            c1,
            h1,
            z1_min,
            z1_max
        );


    float core1 =
        region_core(
            t.pos.y,
            c1,
            h1,
            z1_min,
            z1_max
        );


    float edge1 =
        region_edge(
            t.pos.y,
            c1,
            h1,
            z1_min,
            z1_max
        );


    // --------------------------------------------------------
    // REGION 2
    // --------------------------------------------------------

    float m2 = 0.0;
    float core2 = 0.0;
    float edge2 = 0.0;

    float h2 = 0.0;
    float c2 = 0.0;


    if (use_region_2) {
        float region2_max =
            catastrophic_three
                ? (
                    z2_max -
                    z2_min
                ) * 0.5
                : MAX_BAND_HEIGHT;


        float region2_min =
            catastrophic_three
                ? region2_max
                : MIN_BAND_HEIGHT;


        h2 =
            choose_half_height(
                event_slot + 202.7,
                z2_min,
                z2_max,
                region2_min,
                region2_max
            );


        c2 =
            choose_center(
                event_slot + 242.3,
                z2_min,
                z2_max,
                h2
            );


        m2 =
            region_mask(
                t.pos.y,
                c2,
                h2,
                z2_min,
                z2_max
            );


        core2 =
            region_core(
                t.pos.y,
                c2,
                h2,
                z2_min,
                z2_max
            );


        edge2 =
            region_edge(
                t.pos.y,
                c2,
                h2,
                z2_min,
                z2_max
            );
    }


    // --------------------------------------------------------
    // REGION 3
    // --------------------------------------------------------

    float m3 = 0.0;
    float core3 = 0.0;
    float edge3 = 0.0;

    float h3 = 0.0;
    float c3 = 0.0;


    if (use_region_3) {
        float region3_max =
            catastrophic_three
                ? (
                    z3_max -
                    z3_min
                ) * 0.5
                : MAX_BAND_HEIGHT;


        float region3_min =
            catastrophic_three
                ? region3_max
                : MIN_BAND_HEIGHT;


        h3 =
            choose_half_height(
                event_slot + 303.7,
                z3_min,
                z3_max,
                region3_min,
                region3_max
            );


        c3 =
            choose_center(
                event_slot + 343.3,
                z3_min,
                z3_max,
                h3
            );


        m3 =
            region_mask(
                t.pos.y,
                c3,
                h3,
                z3_min,
                z3_max
            );


        core3 =
            region_core(
                t.pos.y,
                c3,
                h3,
                z3_min,
                z3_max
            );


        edge3 =
            region_edge(
                t.pos.y,
                c3,
                h3,
                z3_min,
                z3_max
            );
    }


    float combined_mask =
        saturate(
            m1 +
            m2 +
            m3
        );


    // --------------------------------------------------------
    // PIXEL SIZE
    // --------------------------------------------------------

    float2 pixel =
        1.0 /
        float2(
            d.viewport_size_pixels
        );


    // --------------------------------------------------------
    // PER-REGION DIRECTION / WARP
    // --------------------------------------------------------

    float dir1 =
        hash11(
            event_slot +
            212.4
        ) > 0.5
            ? 1.0
            : -1.0;


    float dir2 =
        hash11(
            event_slot +
            313.6
        ) > 0.5
            ? 1.0
            : -1.0;


    float dir3 =
        hash11(
            event_slot +
            414.8
        ) > 0.5
            ? 1.0
            : -1.0;


    float wave1 =
        sin(
            t.pos.y * 90.0 +
            time * 37.0
        ) * 0.55 +
        sin(
            t.pos.y * 170.0 -
            time * 21.0
        ) * 0.45;


    float wave2 =
        sin(
            t.pos.y * 116.0 -
            time * 29.0
        ) * 0.55 +
        sin(
            t.pos.y * 153.0 +
            time * 19.0
        ) * 0.45;


    float wave3 =
        sin(
            t.pos.y * 77.0 +
            time * 31.0
        ) * 0.55 +
        sin(
            t.pos.y * 188.0 -
            time * 17.0
        ) * 0.45;


    float bend1 =
        sin(
            (
                t.pos.y -
                c1
            ) *
            26.0
        );


    float bend2 =
        sin(
            (
                t.pos.y -
                c2
            ) *
            23.0
        );


    float bend3 =
        sin(
            (
                t.pos.y -
                c3
            ) *
            29.0
        );


    float horizontal_profile =
        m1 *
        dir1 *
        (
            0.75 +
            wave1 *
            0.25
        )
        +
        m2 *
        dir2 *
        (
            0.75 +
            wave2 *
            0.25
        )
        +
        m3 *
        dir3 *
        (
            0.75 +
            wave3 *
            0.25
        );


    float vertical_profile =
        m1 * bend1 +
        m2 * bend2 +
        m3 * bend3;


    float x_shift =
        pixel.x *
        SHIFT_PIXELS *
        envelope *
        horizontal_profile;


    float y_shift =
        pixel.y *
        BEND_PIXELS *
        envelope *
        vertical_profile *
        0.35;


    float2 uv =
        t.pos +
        float2(
            x_shift,
            y_shift
        );


    // --------------------------------------------------------
    // SMEAR
    // --------------------------------------------------------

    float signed_core =
        core1 * dir1 +
        core2 * dir2 +
        core3 * dir3;


    float2 smear_offset =
        float2(
            pixel.x *
            SMEAR_PIXELS *
            envelope *
            signed_core,
            0.0
        );


    float4 s0 =
        t.backbuffer.Sample(
            uv
        );


    float4 s1 =
        t.backbuffer.Sample(
            uv -
            smear_offset *
            0.35
        );


    float4 s2 =
        t.backbuffer.Sample(
            uv -
            smear_offset *
            0.70
        );


    float4 s3 =
        t.backbuffer.Sample(
            uv -
            smear_offset
        );


    float4 smeared =
        s0 * 0.42 +
        s1 * 0.26 +
        s2 * 0.19 +
        s3 * 0.13;


    // --------------------------------------------------------
    // RGB SPLIT
    // --------------------------------------------------------

    float signed_mask =
        m1 * dir1 +
        m2 * dir2 +
        m3 * dir3;


    float2 chroma_offset =
        float2(
            pixel.x *
            CHROMA_SPLIT_PIXELS *
            envelope *
            signed_mask,
            0.0
        );


    float4 left =
        t.backbuffer.Sample(
            uv -
            chroma_offset
        );


    float4 right =
        t.backbuffer.Sample(
            uv +
            chroma_offset
        );


    float3 split_rgb =
        float3(
            left.r,
            smeared.g,
            right.b
        );


    // --------------------------------------------------------
    // THEMED STATIC INSIDE DAMAGED REGIONS
    // --------------------------------------------------------

    float2 screen_pixel =
        floor(
            t.pos *
            float2(
                d.viewport_size_pixels
            )
        );


    float noise_frame =
        floor(
            time *
            36.0
        );


    float n =
        hash21(
            screen_pixel +
            float2(
                noise_frame * 19.0,
                noise_frame * 13.0
            )
        );


    float3 low_noise =
        THEME_DARK *
        0.55;


    float3 high_noise =
        saturate(
            THEME_BLACK *
            2.8
        );


    float3 themed_noise =
        lerp(
            low_noise,
            high_noise,
            n
        );


    themed_noise =
        lerp(
            themed_noise,
            THEME_CYAN,
            n * 0.08
        );


    float3 distorted_rgb =
        lerp(
            split_rgb,
            themed_noise,
            saturate(
                NOISE_STRENGTH *
                combined_mask
            )
        );


    // --------------------------------------------------------
    // EDGE GLOW
    // --------------------------------------------------------

    float combined_edge =
        saturate(
            edge1 +
            edge2 +
            edge3
        );


    float3 edge_color =
        lerp(
            THEME_BLACK,
            THEME_CYAN,
            0.18
        );


    float3 edge_glow =
        edge_color *
        EDGE_GLOW *
        combined_edge *
        envelope;


    float3 final_rgb =
        distorted_rgb +
        edge_glow;


    return float4(
        saturate(final_rgb),
        smeared.a
    );
}
