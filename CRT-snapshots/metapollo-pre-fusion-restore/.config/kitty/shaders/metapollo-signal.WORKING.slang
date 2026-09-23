#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO UNIFIED SIGNAL RENDERER
//
// VISUALS ARE COPIED FROM THE USER'S WORKING SHADERS:
//
//   ACTIVE / PRE-SLEEP -> original metapollo-tear
//   ENTER / WAKE       -> original metapollo-wake-test
//   NO SIGNAL          -> original metapollo-nosignal
//
// The state machine chooses WHICH old renderer runs.
// It does not recolor or redesign them.
// ============================================================


// ------------------------------------------------------------
// STATE — ALPHA ONLY
// ------------------------------------------------------------

static const float2 STATE_UV = float2(0.5, 0.5);

// Persistent control state lives only in alpha.
//
// ACTIVE        = 0.10
// SLEEP         = 0.20 -> 0.40
// NO SIGNAL     = 0.50
// WAKE          = 0.60 -> 0.80
//
// RGB is not used for control state. This avoids color-space
// conversion from corrupting exact state/progress values.
static const float A_ACTIVE = 0.10;

static const float A_SLEEP_START = 0.20;
static const float A_SLEEP_SPAN  = 0.20;

static const float A_NO_SIGNAL = 0.50;

static const float A_WAKE_START = 0.60;
static const float A_WAKE_SPAN  = 0.20;

bool alpha_near(float a, float target) {
    return abs(a - target) < 0.025;
}

bool alpha_is_sleep(float a) {
    return a >= 0.175 && a < 0.425;
}

bool alpha_is_wake(float a) {
    return a >= 0.575 && a < 0.825;
}

float alpha_sleep_progress(float a) {
    return saturate(
        (a - A_SLEEP_START) /
        A_SLEEP_SPAN
    );
}

float alpha_wake_progress(float a) {
    return saturate(
        (a - A_WAKE_START) /
        A_WAKE_SPAN
    );
}


// ------------------------------------------------------------
// ORIGINAL TEAR PALETTE / SETTINGS
// ------------------------------------------------------------

static const float3 THEME_BLACK = float3(0.106, 0.024, 0.137);
static const float3 THEME_DARK  = float3(0.086, 0.020, 0.122);
static const float3 THEME_CYAN  = float3(0.333, 0.812, 0.792);

static const float EVENT_WINDOW = 11.0;
static const float EVENT_CHANCE = 0.22;

static const float TWO_REGION_CHANCE   = 0.20;
static const float THREE_REGION_CHANCE = 0.05;
static const float CATASTROPHIC_THREE_CHANCE = 0.20;

static const float SHORT_DURATION_MIN = 0.09;
static const float SHORT_DURATION_MAX = 0.38;
static const float MEDIUM_DURATION_MIN = 0.45;
static const float MEDIUM_DURATION_MAX = 1.20;
static const float LONG_DURATION_MIN = 1.30;
static const float LONG_DURATION_MAX = 3.00;
static const float MEDIUM_DURATION_CHANCE = 0.19;
static const float LONG_DURATION_CHANCE   = 0.05;

static const float MIN_BAND_HEIGHT = 0.10;
static const float MAX_BAND_HEIGHT = 0.34;
static const float SHIFT_PIXELS = 44.0;
static const float BEND_PIXELS = 6.0;
static const float SMEAR_PIXELS = 18.0;
static const float CHROMA_SPLIT_PIXELS = 1.4;
static const float TEAR_NOISE_STRENGTH = 0.09;
static const float TEAR_EDGE_GLOW = 0.12;


// ------------------------------------------------------------
// ORIGINAL NO-SIGNAL PALETTE / SETTINGS
// ------------------------------------------------------------

static const float3 NS_STATIC_LOW  = float3(0.090, 0.080, 0.100);
static const float3 NS_STATIC_MID  = float3(0.175, 0.155, 0.190);
static const float3 NS_STATIC_HIGH = float3(0.300, 0.275, 0.320);
static const float3 NS_STATIC_PEAK = float3(0.420, 0.390, 0.440);

static const float NS_SOURCE_VISIBILITY = 0.06;
static const float NS_DARK_FLOOR = 0.018;
static const float NS_NOISE_DENSITY = 0.060;
static const float NS_NOISE_STRENGTH = 0.54;
static const float NS_LINE_SPEED = 0.22;
static const float NS_LINE_DENSITY = 190.0;
static const float NS_LINE_STRENGTH = 0.10;
static const float NS_BAND_SPEED = 0.10;
static const float NS_BAND_HEIGHT = 0.035;
static const float NS_BAND_STRENGTH = 0.14;
static const float NS_STREAK_DENSITY = 0.0025;
static const float NS_STREAK_STRENGTH = 0.32;
static const float NS_SIGN_WIDTH = 0.38;
static const float NS_SIGN_HEIGHT = 0.115;
static const float NS_SIGN_OPACITY = 0.78;
static const float NS_TEXT_WIDTH = 0.285;
static const float NS_TEXT_HEIGHT = 0.052;


// ------------------------------------------------------------
// ORIGINAL BIG WAKE / TRANSITION PALETTE
// ------------------------------------------------------------

static const float3 TR_STATIC_LOW  = float3(0.110, 0.067, 0.133);
static const float3 TR_STATIC_MID  = float3(0.165, 0.098, 0.200);
static const float3 TR_STATIC_HIGH = float3(0.224, 0.141, 0.275);


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
// 5x7 PIXEL FONT
//
// Glyph IDs:
//
// 0 = N
// 1 = O
// 2 = S
// 3 = I
// 4 = G
// 5 = A
// 6 = L
// ------------------------------------------------------------

uint glyph_row(
    int glyph,
    int row
) {
    // N
    if (glyph == 0) {
        if (row == 0) return 17u;
        if (row == 1) return 25u;
        if (row == 2) return 21u;
        if (row == 3) return 19u;
        if (row == 4) return 17u;
        if (row == 5) return 17u;
        return 17u;
    }

    // O
    if (glyph == 1) {
        if (row == 0) return 14u;
        if (row == 1) return 17u;
        if (row == 2) return 17u;
        if (row == 3) return 17u;
        if (row == 4) return 17u;
        if (row == 5) return 17u;
        return 14u;
    }

    // S
    if (glyph == 2) {
        if (row == 0) return 15u;
        if (row == 1) return 16u;
        if (row == 2) return 16u;
        if (row == 3) return 14u;
        if (row == 4) return 1u;
        if (row == 5) return 1u;
        return 30u;
    }

    // I
    if (glyph == 3) {
        if (row == 0) return 31u;
        if (row == 1) return 4u;
        if (row == 2) return 4u;
        if (row == 3) return 4u;
        if (row == 4) return 4u;
        if (row == 5) return 4u;
        return 31u;
    }

    // G
    if (glyph == 4) {
        if (row == 0) return 14u;
        if (row == 1) return 17u;
        if (row == 2) return 16u;
        if (row == 3) return 23u;
        if (row == 4) return 17u;
        if (row == 5) return 17u;
        return 14u;
    }

    // A
    if (glyph == 5) {
        if (row == 0) return 14u;
        if (row == 1) return 17u;
        if (row == 2) return 17u;
        if (row == 3) return 31u;
        if (row == 4) return 17u;
        if (row == 5) return 17u;
        return 17u;
    }

    // L
    if (glyph == 6) {
        if (row == 0) return 16u;
        if (row == 1) return 16u;
        if (row == 2) return 16u;
        if (row == 3) return 16u;
        if (row == 4) return 16u;
        if (row == 5) return 16u;
        return 31u;
    }

    return 0u;
}


// ------------------------------------------------------------
// "NO SIGNAL" MASK
// ------------------------------------------------------------

float no_signal_text_mask(
    float2 uv
) {
    float2 origin =
        float2(
            0.5 - NS_TEXT_WIDTH * 0.5,
            0.5 - NS_TEXT_HEIGHT * 0.5
        );


    float2 local =
        (
            uv -
            origin
        ) /
        float2(
            NS_TEXT_WIDTH,
            NS_TEXT_HEIGHT
        );


    if (
        local.x < 0.0 ||
        local.x >= 1.0 ||
        local.y < 0.0 ||
        local.y >= 1.0
    ) {
        return 0.0;
    }


    // 9 character slots:
    //
    // N O _ S I G N A L
    //
    // Each slot is 6 columns wide.
    // Glyph itself uses first 5 columns.
    const int TOTAL_COLUMNS = 53;


    int cell_x =
        int(
            floor(
                local.x *
                float(TOTAL_COLUMNS)
            )
        );


    int cell_y =
        int(
            floor(
                local.y *
                7.0
            )
        );


    if (
        cell_y < 0 ||
        cell_y > 6
    ) {
        return 0.0;
    }


    int slot =
        cell_x / 6;


    int glyph_x =
        cell_x -
        slot * 6;


    if (glyph_x >= 5) {
        return 0.0;
    }


    int glyph = -1;


    if (slot == 0) glyph = 0; // N
    if (slot == 1) glyph = 1; // O

    // slot 2 intentionally blank

    if (slot == 3) glyph = 2; // S
    if (slot == 4) glyph = 3; // I
    if (slot == 5) glyph = 4; // G
    if (slot == 6) glyph = 0; // N
    if (slot == 7) glyph = 5; // A
    if (slot == 8) glyph = 6; // L


    if (glyph < 0) {
        return 0.0;
    }


    uint row_bits =
        glyph_row(
            glyph,
            cell_y
        );


    int bit_index =
        4 -
        glyph_x;


    uint bit =
        (
            row_bits >>
            uint(bit_index)
        ) &
        1u;


    return
        bit == 1u
            ? 1.0
            : 0.0;
}



float4
render_normal_tear(
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
                TEAR_NOISE_STRENGTH *
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
        TEAR_EDGE_GLOW *
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


float4
render_no_signal(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float idle_mix = 1.0;


    float time =
        d.timestamp;


    float2 viewport =
        float2(
            d.viewport_size_pixels
        );


    float2 screen_pixel =
        floor(
            t.pos *
            viewport
        );


    // --------------------------------------------------------
    // SCREEN BASE
    // --------------------------------------------------------

    float3 base =
        THEME_BLACK;


    base =
        lerp(
            base,
            color.rgb,
            NS_SOURCE_VISIBILITY
        );


    base +=
        THEME_DARK *
        NS_DARK_FLOOR;


    // --------------------------------------------------------
    // PURPLE-GREY STATIC
    // --------------------------------------------------------

    float noise_frame =
        floor(
            time *
            28.0
        );


    float n =
        hash21(
            screen_pixel +
            float2(
                noise_frame * 17.0,
                noise_frame * 31.0
            )
        );


    float noise_mask =
        step(
            1.0 -
            NS_NOISE_DENSITY,
            n
        );


    float3 noise_color;


    if (n < 0.55) {
        noise_color =
            lerp(
                NS_STATIC_LOW,
                NS_STATIC_MID,
                n / 0.55
            );
    }
    else {
        noise_color =
            lerp(
                NS_STATIC_MID,
                NS_STATIC_HIGH,
                (
                    n -
                    0.55
                ) /
                0.45
            );
    }


    float3 static_rgb =
        lerp(
            base,
            noise_color,
            noise_mask *
            NS_NOISE_STRENGTH
        );


    // --------------------------------------------------------
    // FINE HORIZONTAL NOISE
    // --------------------------------------------------------

    float line_wave =
        sin(
            t.pos.y *
            NS_LINE_DENSITY +
            time *
            NS_LINE_SPEED *
            40.0
        );


    float line_mask =
        smoothstep(
            0.65,
            1.0,
            line_wave
        );


    static_rgb +=
        NS_STATIC_MID *
        line_mask *
        NS_LINE_STRENGTH;


    // --------------------------------------------------------
    // SLOW ROLLING BAND
    // --------------------------------------------------------

    float band_center =
        frac(
            time *
            NS_BAND_SPEED
        );


    float band_dist =
        abs(
            t.pos.y -
            band_center
        );


    float band =
        1.0 -
        smoothstep(
            NS_BAND_HEIGHT,
            NS_BAND_HEIGHT + 0.015,
            band_dist
        );


    static_rgb +=
        NS_STATIC_MID *
        band *
        NS_BAND_STRENGTH;


    // --------------------------------------------------------
    // RARE LIGHT STREAK
    // --------------------------------------------------------

    float streak_slot =
        floor(
            time *
            0.8
        );


    float streak_roll =
        hash11(
            streak_slot +
            9.7
        );


    float streak_exists =
        step(
            1.0 -
            NS_STREAK_DENSITY,
            streak_roll
        );


    float streak_y =
        hash11(
            streak_slot +
            33.1
        );


    float streak_dist =
        abs(
            t.pos.y -
            streak_y
        );


    float streak =
        (
            1.0 -
            smoothstep(
                0.0,
                0.0035,
                streak_dist
            )
        ) *
        streak_exists;


    static_rgb +=
        NS_STATIC_PEAK *
        streak *
        NS_STREAK_STRENGTH;


    // --------------------------------------------------------
    // NO SIGNAL PLAQUE
    // --------------------------------------------------------

    float2 sign_half =
        float2(
            NS_SIGN_WIDTH,
            NS_SIGN_HEIGHT
        ) *
        0.5;


    float2 sign_delta =
        abs(
            t.pos -
            float2(
                0.5,
                0.5
            )
        );


    float sign_mask =
        step(
            sign_delta.x,
            sign_half.x
        ) *
        step(
            sign_delta.y,
            sign_half.y
        );


    float2 text_uv =
    float2(
        t.pos.x,
        1.0 - t.pos.y
    );


float text_mask =
    no_signal_text_mask(
        text_uv
    );


    // Dark plaque.
    // Text itself is punched through the plaque,
    // exposing the moving static underneath.
    float plaque_amount =
        sign_mask *
        (
            1.0 -
            text_mask
        ) *
        NS_SIGN_OPACITY;


    float3 with_sign =
        lerp(
            static_rgb,
            THEME_DARK,
            plaque_amount
        );


    // --------------------------------------------------------
    // IDLE TRANSITION
    // --------------------------------------------------------

    float3 final_rgb =
        lerp(
            color.rgb,
            saturate(
                with_sign
            ),
            idle_mix
        );


    return float4(
        final_rgb,
        color.a
    );
}


float4
render_transition(
    float4 color,
    float4 state,
    KittyTextures t,
    KittyCustomShaderData d
) {
    // Transition progress is advanced by the single persistent
    // state controller. The visual renderer only consumes it.
    float progress =
        saturate(
            state.g
        );


    float2 pixel =
        1.0 /
        float2(
            d.viewport_size_pixels
        );


    // --------------------------------------------------------
    // STATIC BLAST
    // --------------------------------------------------------

    float static_amount =
        1.0 -
        smoothstep(
            0.00,
            0.32,
            progress
        );


    // --------------------------------------------------------
    // MASSIVE TEAR
    // --------------------------------------------------------

    float tear_in =
        smoothstep(
            0.05,
            0.14,
            progress
        );


    float tear_out =
        1.0 -
        smoothstep(
            0.70,
            0.95,
            progress
        );


    float tear =
        tear_in *
        tear_out;


    float band_center =
        0.52;


    float band_half =
        0.30;


    float band =
        1.0 -
        smoothstep(
            band_half,
            band_half + 0.03,
            abs(
                t.pos.y -
                band_center
            )
        );


    float wave =
        sin(
            t.pos.y * 105.0 +
            d.timestamp * 48.0
        );


    float x_shift =
        pixel.x *
        150.0 *
        tear *
        band *
        (
            0.75 +
            wave * 0.25
        );


    // --------------------------------------------------------
    // WHOLE SCREEN WARP
    // --------------------------------------------------------

    float global_shift =
        pixel.x *
        38.0 *
        tear *
        sin(
            t.pos.y * 13.0 +
            d.timestamp * 15.0
        );


    float y_shift =
        pixel.y *
        14.0 *
        tear *
        band *
        sin(
            (
                t.pos.y -
                band_center
            ) *
            24.0
        );


    float2 uv =
        t.pos +
        float2(
            x_shift + global_shift,
            y_shift
        );


    float4 source =
        t.backbuffer.Sample(
            uv
        );


    // --------------------------------------------------------
    // PURPLE-GREY STATIC
    // --------------------------------------------------------

    float2 screen_pixel =
        floor(
            t.pos *
            float2(
                d.viewport_size_pixels
            )
        );


    float frame =
        floor(
            d.timestamp *
            60.0
        );


    float n =
        hash21(
            screen_pixel +
            float2(
                frame * 17.0,
                frame * 31.0
            )
        );


    float3 noise;


    if (n < 0.5) {
        noise =
            lerp(
                TR_STATIC_LOW,
                TR_STATIC_MID,
                n * 2.0
            );
    }
    else {
        noise =
            lerp(
                TR_STATIC_MID,
                TR_STATIC_HIGH,
                (n - 0.5) * 2.0
            );
    }


    float3 final_rgb =
        lerp(
            source.rgb,
            noise,
            static_amount * 0.96
        );


    // --------------------------------------------------------
    // SNAP CLEAN
    // --------------------------------------------------------

    float snap =
        smoothstep(
            0.88,
            1.0,
            progress
        );


    final_rgb =
        lerp(
            final_rgb,
            color.rgb,
            snap
        );


    return float4(
        saturate(final_rgb),
        color.a
    );
}


// ============================================================
// STATE DISPATCH — ALPHA ONLY
//
// ACTIVE:
//     original normal random tear renderer
//
// SLEEP:
//     original purple static + huge wobble
//
// NO SIGNAL:
//     original NO SIGNAL renderer
//
// WAKE:
//     original purple static + huge wobble
//
// Only the state decoding changed. The visual functions above are
// unchanged from the previous full renderer.
// ============================================================

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float state_alpha =
        t.persist.Sample(
            STATE_UV
        ).a;

    // Uninitialized/unknown state behaves as ACTIVE.
    bool active =
        alpha_near(
            state_alpha,
            A_ACTIVE
        );

    bool sleeping =
        alpha_is_sleep(
            state_alpha
        );

    bool no_signal =
        alpha_near(
            state_alpha,
            A_NO_SIGNAL
        );

    bool waking =
        alpha_is_wake(
            state_alpha
        );

    if (!active && !sleeping && !no_signal && !waking) {
        return render_normal_tear(
            color,
            t,
            d
        );
    }

    if (sleeping) {
        float progress =
            alpha_sleep_progress(
                state_alpha
            );

        // render_transition() consumes state.g as 0..1 progress.
        // Construct a temporary local state only for that function;
        // nothing is written back into persistent RGB.
        float4 transition_state =
            float4(
                0.0,
                progress,
                0.0,
                1.0
            );

        return render_transition(
            color,
            transition_state,
            t,
            d
        );
    }

    if (no_signal) {
        return render_no_signal(
            color,
            t,
            d
        );
    }

    if (waking) {
        float progress =
            alpha_wake_progress(
                state_alpha
            );

        float4 transition_state =
            float4(
                0.0,
                progress,
                0.0,
                1.0
            );

        return render_transition(
            color,
            transition_state,
            t,
            d
        );
    }

    return render_normal_tear(
        color,
        t,
        d
    );
}
