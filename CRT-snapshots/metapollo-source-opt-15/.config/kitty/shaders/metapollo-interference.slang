#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO CRT INTERFERENCE
//
// Purple-grey electrical corruption.
// No cyan.
// No neutral white static.
// ============================================================


// ------------------------------------------------------------
// STATIC PALETTE
// ------------------------------------------------------------
static const float3 STATIC_LOW =
    float3(0.110, 0.067, 0.133);   // #1C1122

static const float3 STATIC_MID =
    float3(0.165, 0.098, 0.200);   // #2A1933

static const float3 STATIC_HIGH =
    float3(0.224, 0.141, 0.275);   // #392446

static const float3 STATIC_PEAK =
    float3(0.286, 0.188, 0.353);   // #49305A

// ------------------------------------------------------------
// EVENT SETTINGS
// ------------------------------------------------------------

static const float EVENT_WINDOW = 6.0;
static const float EVENT_CHANCE = 0.38;

static const float TWO_REGION_CHANCE   = 0.20;
static const float THREE_REGION_CHANCE = 0.05;

static const float CATASTROPHIC_THREE_CHANCE = 0.20;


// ------------------------------------------------------------
// DURATION
// ------------------------------------------------------------

static const float SHORT_DURATION_MIN = 0.08;
static const float SHORT_DURATION_MAX = 0.35;

static const float MEDIUM_DURATION_MIN = 0.40;
static const float MEDIUM_DURATION_MAX = 1.10;

static const float LONG_DURATION_MIN = 1.20;
static const float LONG_DURATION_MAX = 3.00;

static const float MEDIUM_DURATION_CHANCE = 0.22;
static const float LONG_DURATION_CHANCE   = 0.06;


// ------------------------------------------------------------
// APPEARANCE
// ------------------------------------------------------------

static const float MIN_BAND_HEIGHT = 0.025;
static const float MAX_BAND_HEIGHT = 0.10;

static const float TEAR_PIXELS = 12.0;

static const float STATIC_STRENGTH = 0.60;
static const float LINE_STRENGTH   = 0.32;


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
            19.73
        ) *
        max(
            0.0,
            hi -
            lo
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


    // The caller already passed this exact region's zone_gate.
    if (distance <= half_height) {
        return 1.0;
    }

    if (
        distance >=
        half_height + 0.012
    ) {
        return 0.0;
    }


    return
        1.0 -
        smoothstep(
            half_height,
            half_height + 0.012,
            distance
        );
}


float core_mask(
    float y,
    float center,
    float zone_min,
    float zone_max
) {
    float distance =
        abs(
            y -
            center
        );


    // Outside the tiny core the old smoothstep result was exactly zero.
    if (distance >= 0.007) {
        return 0.0;
    }


    return
        1.0 -
        smoothstep(
            0.0,
            0.007,
            distance
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
            13.37
        ) >
        (
            1.0 -
            EVENT_CHANCE
        );


    // A failed event roll means this entire EVENT_WINDOW is clean.
    // The old path eventually returned `color` too, but only after
    // calculating duration/start values for every pixel.
    if (!event_exists) {
        return color;
    }


    // --------------------------------------------------------
    // RANDOM DURATION
    // --------------------------------------------------------

    float duration_roll =
        hash11(
            event_slot +
            92.71
        );


    float duration_value =
        hash11(
            event_slot +
            193.42
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
            41.91
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


    // --------------------------------------------------------
    // REGION COUNT
    // --------------------------------------------------------

    float region_roll =
        hash11(
            event_slot +
            517.31
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
            811.72
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
    //
    // Only generate this region for pixels that are actually in
    // zone 1. This uses the exact same zone_gate as region_mask().
    // --------------------------------------------------------

    float c1 = 0.0;
    float m1 = 0.0;


    if (
        zone_gate(
            t.pos.y,
            z1_min,
            z1_max
        ) > 0.0
    ) {
        float region1_max =
            MAX_BAND_HEIGHT;


        if (!use_region_2) {
            region1_max =
                MAX_BAND_HEIGHT *
                2.2;
        }
        else if (two_regions) {
            region1_max =
                MAX_BAND_HEIGHT *
                1.35;
        }


        if (catastrophic_three) {
            region1_max =
                (
                    z1_max -
                    z1_min
                ) *
                0.5;
        }


        float region1_min =
            catastrophic_three
                ? region1_max
                : MIN_BAND_HEIGHT;


        float h1 =
            choose_half_height(
                event_slot + 101.2,
                z1_min,
                z1_max,
                region1_min,
                region1_max
            );


        c1 =
            choose_center(
                event_slot + 141.8,
                z1_min,
                z1_max,
                h1
            );


        m1 =
            region_mask(
                t.pos.y,
                c1,
                h1,
                z1_min,
                z1_max
            );
    }


    // --------------------------------------------------------
    // REGION 2
    // --------------------------------------------------------

    float m2 = 0.0;
    float c2 = 0.0;


    if (
        use_region_2 &&
        zone_gate(
            t.pos.y,
            z2_min,
            z2_max
        ) > 0.0
    ) {
        float region2_max =
            two_regions
                ? MAX_BAND_HEIGHT * 1.35
                : MAX_BAND_HEIGHT;


        if (catastrophic_three) {
            region2_max =
                (
                    z2_max -
                    z2_min
                ) *
                0.5;
        }


        float region2_min =
            catastrophic_three
                ? region2_max
                : MIN_BAND_HEIGHT;


        float h2 =
            choose_half_height(
                event_slot + 202.4,
                z2_min,
                z2_max,
                region2_min,
                region2_max
            );


        c2 =
            choose_center(
                event_slot + 242.9,
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
    }


    // --------------------------------------------------------
    // REGION 3
    // --------------------------------------------------------

    float m3 = 0.0;
    float c3 = 0.0;


    if (
        use_region_3 &&
        zone_gate(
            t.pos.y,
            z3_min,
            z3_max
        ) > 0.0
    ) {
        float region3_max =
            MAX_BAND_HEIGHT;


        if (catastrophic_three) {
            region3_max =
                (
                    z3_max -
                    z3_min
                ) *
                0.5;
        }


        float region3_min =
            catastrophic_three
                ? region3_max
                : MIN_BAND_HEIGHT;


        float h3 =
            choose_half_height(
                event_slot + 303.6,
                z3_min,
                z3_max,
                region3_min,
                region3_max
            );


        c3 =
            choose_center(
                event_slot + 343.1,
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
    }


    float combined_mask =
        m1 +
        m2 +
        m3;


    // Outside every active interference band the old path resolves
    // exactly to the incoming color. Skip displacement/noise/sample work.
    if (combined_mask <= 0.0) {
        return color;
    }


    // --------------------------------------------------------
    // ACTIVE REGION DISPLACEMENT
    //
    // The zones do not overlap, so only one mask can affect this
    // pixel. Avoid direction hashes and sine waves for inactive zones.
    // --------------------------------------------------------

    float active_mask = 0.0;
    float active_center = 0.0;
    float active_z_min = 0.0;
    float active_z_max = 1.0;
    float active_dir = 1.0;
    float active_wave = 0.0;


    if (m1 > 0.0) {
        active_mask = m1;
        active_center = c1;
        active_z_min = z1_min;
        active_z_max = z1_max;

        active_dir =
            hash11(
                event_slot +
                81.1
            ) > 0.5
                ? 1.0
                : -1.0;

        active_wave =
            0.72 +
            sin(
                t.pos.y * 140.0 +
                time * 53.0
            ) *
            0.28;
    }
    else if (m2 > 0.0) {
        active_mask = m2;
        active_center = c2;
        active_z_min = z2_min;
        active_z_max = z2_max;

        active_dir =
            hash11(
                event_slot +
                182.3
            ) > 0.5
                ? 1.0
                : -1.0;

        active_wave =
            0.72 +
            sin(
                t.pos.y * 117.0 -
                time * 47.0
            ) *
            0.28;
    }
    else {
        active_mask = m3;
        active_center = c3;
        active_z_min = z3_min;
        active_z_max = z3_max;

        active_dir =
            hash11(
                event_slot +
                283.5
            ) > 0.5
                ? 1.0
                : -1.0;

        active_wave =
            0.72 +
            sin(
                t.pos.y * 163.0 +
                time * 39.0
            ) *
            0.28;
    }


    float2 viewport_size =
        float2(
            d.viewport_size_pixels
        );

    float pixel_x =
        1.0 /
        viewport_size.x;


    float tear_profile =
        active_mask *
        active_dir *
        active_wave;


    float tear =
        pixel_x *
        TEAR_PIXELS *
        tear_profile;


    float2 distorted_uv =
        t.pos +
        float2(
            tear,
            0.0
        );


    float4 source =
        t.backbuffer.Sample(
            distorted_uv
        );


    // --------------------------------------------------------
    // PURPLE-GREY STATIC
    // --------------------------------------------------------

    float2 screen_pixel =
        floor(
            t.pos *
            viewport_size
        );


    float noise_frame =
        floor(
            time *
            48.0
        );


    float n =
        hash21(
            screen_pixel +
            float2(
                noise_frame * 17.0,
                noise_frame * 31.0
            )
        );


    float3 noise_color;


    if (n < 0.5) {
        noise_color =
            lerp(
                STATIC_LOW,
                STATIC_MID,
                n * 2.0
            );
    }
    else {
        noise_color =
            lerp(
                STATIC_MID,
                STATIC_HIGH,
                (
                    n -
                    0.5
                ) *
                2.0
            );
    }


    float3 final_rgb =
        lerp(
            source.rgb,
            noise_color,
            STATIC_STRENGTH *
            combined_mask
        );


    // --------------------------------------------------------
    // INTERFERENCE CORE
    // --------------------------------------------------------

    float core =
        core_mask(
            t.pos.y,
            active_center,
            active_z_min,
            active_z_max
        );


    final_rgb +=
        STATIC_PEAK *
        core *
        LINE_STRENGTH;


    return float4(
        saturate(
            final_rgb
        ),
        source.a
    );
}
