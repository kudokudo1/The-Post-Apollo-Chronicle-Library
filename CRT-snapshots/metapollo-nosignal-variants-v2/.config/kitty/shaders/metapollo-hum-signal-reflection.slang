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

static const float3 NS_STATIC_LOW  = float3(0.110, 0.067, 0.133); // #1C1122
static const float3 NS_STATIC_MID  = float3(0.165, 0.098, 0.200); // #2A1933
static const float3 NS_STATIC_HIGH = float3(0.224, 0.141, 0.275); // #392446
static const float3 NS_STATIC_PEAK = float3(0.286, 0.188, 0.353); // #49305A

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
// NO SIGNAL — LONG-LIVED VARIANT SELECTOR
//
// No extra persistent state is used.
//
// Every 30 seconds the shader independently rolls:
//     0 = line / rolling-band mode
//     1 = dense static mode
//
// If the roll chooses the same mode again, nothing changes, so the
// actual visible hold time can naturally become 60, 90, 120... seconds.
// This keeps the implementation stateless while making swaps infrequent.
// ------------------------------------------------------------

static const float NS_VARIANT_REROLL_SECONDS = 30.0;
static const float NS_STATIC_VARIANT_STRENGTH = 0.96;


// ------------------------------------------------------------
// NO SIGNAL — ELECTRICAL FAULTS
//
// These are independent of the selected line/static variant.
// They occasionally tear/warp and blast static through the entire
// NO SIGNAL image, including the plaque.
// ------------------------------------------------------------

static const float NS_FAULT_WINDOW = 7.0;
static const float NS_FAULT_CHANCE = 0.42;

static const float NS_FAULT_DURATION_MIN = 0.10;
static const float NS_FAULT_DURATION_MAX = 0.55;

static const float NS_FAULT_BAND_MIN = 0.035;
static const float NS_FAULT_BAND_MAX = 0.14;

static const float NS_FAULT_SHIFT_PIXELS = 20.0;
static const float NS_FAULT_Y_PIXELS = 1.8;

static const float NS_FAULT_STATIC_STRENGTH = 0.68;
static const float NS_FAULT_CATASTROPHIC_CHANCE = 0.10;


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


    // Every call site is already inside this region's zone.
    // At/below the lower smoothstep edge the old mask was exactly 1;
    // at/above the upper edge it was exactly 0.
    if (distance <= half_height) {
        return 1.0;
    }

    if (
        distance >=
        half_height + 0.03
    ) {
        return 0.0;
    }


    return
        1.0 -
        smoothstep(
            half_height,
            half_height + 0.03,
            distance
        );
}


float region_core(
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

    float core_radius =
        half_height *
        0.65;


    // At/after the upper smoothstep edge the old core is exactly zero.
    if (distance >= core_radius) {
        return 0.0;
    }


    return
        1.0 -
        smoothstep(
            0.0,
            core_radius,
            distance
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


    // In the inner 65% both old masks were exactly 1, so
    // outer - inner was exactly zero.
    if (
        distance <=
        half_height * 0.65
    ) {
        return 0.0;
    }


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


    // Every call site is already inside the active region's zone.
    return
        saturate(
            outer -
            inner
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


    // Most tear windows are intentionally empty. If this window
    // failed its event roll, the exact result is the incoming color.
    if (!event_exists) {
        return color;
    }


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
    //
    // Only calculate this region if this pixel is inside zone 1.
    // region_mask() used this exact zone gate already.
    // --------------------------------------------------------

    float h1 = 0.0;
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


        h1 =
            choose_half_height(
                event_slot + 101.7,
                z1_min,
                z1_max,
                region1_min,
                region1_max
            );


        c1 =
            choose_center(
                event_slot + 141.3,
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

    float h2 = 0.0;
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
    }


    // --------------------------------------------------------
    // REGION 3
    // --------------------------------------------------------

    float m3 = 0.0;

    float h3 = 0.0;
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
    }


    float combined_mask =
        m1 +
        m2 +
        m3;


    // Outside every active tear band, core/edge/mask are all zero.
    // The old path therefore resolves exactly to `color`, so skip
    // six texture reads plus the warp/noise work for those pixels.
    if (combined_mask <= 0.0) {
        return color;
    }


    // --------------------------------------------------------
    // ACTIVE REGION
    //
    // The zones are non-overlapping, so for this pixel only one
    // of m1/m2/m3 can be non-zero. Compute the expensive core,
    // edge, direction, wave and bend only for that one region.
    // --------------------------------------------------------

    float active_mask = 0.0;
    float active_core = 0.0;
    float active_edge = 0.0;
    float active_dir = 1.0;
    float active_wave = 0.0;
    float active_bend = 0.0;


    if (m1 > 0.0) {
        active_mask = m1;

        active_core =
            region_core(
                t.pos.y,
                c1,
                h1,
                z1_min,
                z1_max
            );

        active_edge =
            region_edge(
                t.pos.y,
                c1,
                h1,
                z1_min,
                z1_max
            );

        active_dir =
            hash11(
                event_slot +
                212.4
            ) > 0.5
                ? 1.0
                : -1.0;

        active_wave =
            sin(
                t.pos.y * 90.0 +
                time * 37.0
            ) * 0.55 +
            sin(
                t.pos.y * 170.0 -
                time * 21.0
            ) * 0.45;

        active_bend =
            sin(
                (
                    t.pos.y -
                    c1
                ) *
                26.0
            );
    }
    else if (m2 > 0.0) {
        active_mask = m2;

        active_core =
            region_core(
                t.pos.y,
                c2,
                h2,
                z2_min,
                z2_max
            );

        active_edge =
            region_edge(
                t.pos.y,
                c2,
                h2,
                z2_min,
                z2_max
            );

        active_dir =
            hash11(
                event_slot +
                313.6
            ) > 0.5
                ? 1.0
                : -1.0;

        active_wave =
            sin(
                t.pos.y * 116.0 -
                time * 29.0
            ) * 0.55 +
            sin(
                t.pos.y * 153.0 +
                time * 19.0
            ) * 0.45;

        active_bend =
            sin(
                (
                    t.pos.y -
                    c2
                ) *
                23.0
            );
    }
    else {
        // combined_mask > 0 guarantees region 3 is active here.
        active_mask = m3;

        active_core =
            region_core(
                t.pos.y,
                c3,
                h3,
                z3_min,
                z3_max
            );

        active_edge =
            region_edge(
                t.pos.y,
                c3,
                h3,
                z3_min,
                z3_max
            );

        active_dir =
            hash11(
                event_slot +
                414.8
            ) > 0.5
                ? 1.0
                : -1.0;

        active_wave =
            sin(
                t.pos.y * 77.0 +
                time * 31.0
            ) * 0.55 +
            sin(
                t.pos.y * 188.0 -
                time * 17.0
            ) * 0.45;

        active_bend =
            sin(
                (
                    t.pos.y -
                    c3
                ) *
                29.0
            );
    }


    // --------------------------------------------------------
    // PIXEL SIZE
    // --------------------------------------------------------

    float2 viewport_size =
        float2(
            d.viewport_size_pixels
        );

    float2 pixel =
        1.0 /
        viewport_size;


    float horizontal_profile =
        active_mask *
        active_dir *
        (
            0.75 +
            active_wave *
            0.25
        );


    float vertical_profile =
        active_mask *
        active_bend;


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
        active_core *
        active_dir;


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


    float4 s1;
    float4 s2;
    float4 s3;


    // When the core mask is zero, smear_offset is exactly zero.
    // The old path sampled the exact same UV four times. Reuse the
    // first sample, but keep the identical weighted arithmetic.
    if (smear_offset.x == 0.0) {
        s1 = s0;
        s2 = s0;
        s3 = s0;
    }
    else {
        s1 =
            t.backbuffer.Sample(
                uv -
                smear_offset *
                0.35
            );

        s2 =
            t.backbuffer.Sample(
                uv -
                smear_offset *
                0.70
            );

        s3 =
            t.backbuffer.Sample(
                uv -
                smear_offset
            );
    }


    float4 smeared =
        s0 * 0.42 +
        s1 * 0.26 +
        s2 * 0.19 +
        s3 * 0.13;


    // --------------------------------------------------------
    // RGB SPLIT
    // --------------------------------------------------------

    float signed_mask =
        active_mask *
        active_dir;


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
            viewport_size
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


    // THEME_BLACK * 2.8 remains below 1.0 in every channel.
    float3 high_noise =
        THEME_BLACK *
        2.8;


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
            TEAR_NOISE_STRENGTH *
            combined_mask
        );


    // --------------------------------------------------------
    // EDGE GLOW
    // --------------------------------------------------------

    // active_edge is already produced in the [0, 1] range.
    float combined_edge =
        active_edge;


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
    float time =
        d.timestamp;


    float2 viewport =
        float2(
            d.viewport_size_pixels
        );


    float2 pixel =
        1.0 /
        viewport;


    // ========================================================
    // LONG-LIVED VARIANT SELECTOR
    //
    // This intentionally does NOT care when NO SIGNAL started.
    // It is simply a slow global random selector.
    //
    // Every 30 seconds it rolls line-mode vs static-mode.
    // Repeating the same roll naturally extends the hold time.
    // ========================================================

    float variant_slot =
        floor(
            time /
            NS_VARIANT_REROLL_SECONDS
        );


    bool static_variant =
        hash11(
            variant_slot +
            817.31
        ) >= 0.5;


    // ========================================================
    // RANDOM NO-SIGNAL ELECTRICAL FAULT
    //
    // Independent from the selected variant.
    // Produces occasional horizontal displacement + vertical wobble
    // + static bursts. Rare events hit the whole screen.
    // ========================================================

    float fault_slot =
        floor(
            time /
            NS_FAULT_WINDOW
        );


    float fault_roll =
        hash11(
            fault_slot +
            431.17
        );


    bool fault_exists =
        fault_roll >
        (
            1.0 -
            NS_FAULT_CHANCE
        );


    float fault_envelope =
        0.0;


    float fault_mask =
        0.0;


    float2 ns_uv =
        t.pos;


    if (fault_exists) {
        float fault_duration =
            lerp(
                NS_FAULT_DURATION_MIN,
                NS_FAULT_DURATION_MAX,
                hash11(
                    fault_slot +
                    449.73
                )
            );


        float fault_start =
            hash11(
                fault_slot +
                463.91
            ) *
            max(
                0.0,
                NS_FAULT_WINDOW -
                fault_duration
            );


        float local_time =
            time -
            fault_slot *
            NS_FAULT_WINDOW;


        float fault_age =
            (
                local_time -
                fault_start
            ) /
            max(
                fault_duration,
                0.001
            );


        if (
            fault_age >= 0.0 &&
            fault_age <= 1.0
        ) {
            float fade_in =
                smoothstep(
                    0.0,
                    0.10,
                    fault_age
                );


            float fade_out =
                1.0 -
                smoothstep(
                    0.78,
                    1.0,
                    fault_age
                );


            fault_envelope =
                fade_in *
                fade_out;


            bool catastrophic =
                hash11(
                    fault_slot +
                    487.13
                ) >
                (
                    1.0 -
                    NS_FAULT_CATASTROPHIC_CHANCE
                );


            if (catastrophic) {
                fault_mask =
                    1.0;
            }
            else {
                float fault_center =
                    hash11(
                        fault_slot +
                        503.57
                    );


                float fault_half_height =
                    lerp(
                        NS_FAULT_BAND_MIN,
                        NS_FAULT_BAND_MAX,
                        hash11(
                            fault_slot +
                            521.29
                        )
                    );


                float fault_distance =
                    abs(
                        t.pos.y -
                        fault_center
                    );


                if (
                    fault_distance <=
                    fault_half_height
                ) {
                    fault_mask =
                        1.0;
                }
                else if (
                    fault_distance <
                    fault_half_height + 0.020
                ) {
                    fault_mask =
                        1.0 -
                        smoothstep(
                            fault_half_height,
                            fault_half_height + 0.020,
                            fault_distance
                        );
                }
            }


            float direction =
                hash11(
                    fault_slot +
                    547.83
                ) > 0.5
                    ? 1.0
                    : -1.0;


            float fault_wave =
                0.72 +
                0.28 *
                sin(
                    t.pos.y *
                    121.0 +
                    time *
                    47.0
                );


            float fault_scale =
                catastrophic
                    ? 1.70
                    : 1.0;


            float x_shift =
                pixel.x *
                NS_FAULT_SHIFT_PIXELS *
                fault_scale *
                direction *
                fault_wave *
                fault_mask *
                fault_envelope;


            float y_shift =
                pixel.y *
                NS_FAULT_Y_PIXELS *
                sin(
                    t.pos.x *
                    87.0 -
                    time *
                    33.0
                ) *
                fault_mask *
                fault_envelope;


            ns_uv =
                clamp(
                    t.pos +
                    float2(
                        x_shift,
                        y_shift
                    ),
                    float2(0.0),
                    float2(1.0)
                );
        }
    }


    float2 screen_pixel =
        floor(
            ns_uv *
            viewport
        );


    // ========================================================
    // SCREEN BASE
    // ========================================================

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


    // One animated noise source is shared by both variants.
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


    float3 static_rgb =
        base;


    // ========================================================
    // VARIANT A — ORIGINAL LINE / ROLLING-BAND MODE
    // ========================================================

    if (!static_variant) {
        // ----------------------------------------------------
        // SPARSE PURPLE-GREY STATIC
        // ----------------------------------------------------

        float noise_mask =
            step(
                1.0 -
                NS_NOISE_DENSITY,
                n
            );


        if (noise_mask > 0.0) {
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

            static_rgb =
                lerp(
                    base,
                    noise_color,
                    NS_NOISE_STRENGTH
                );
        }


        // ----------------------------------------------------
        // FINE HORIZONTAL NOISE
        // ----------------------------------------------------

        float line_wave =
            sin(
                ns_uv.y *
                NS_LINE_DENSITY +
                time *
                NS_LINE_SPEED *
                40.0
            );


        float line_mask =
            0.0;


        if (line_wave > 0.65) {
            line_mask =
                smoothstep(
                    0.65,
                    1.0,
                    line_wave
                );
        }


        static_rgb +=
            NS_STATIC_MID *
            line_mask *
            NS_LINE_STRENGTH;


        // ----------------------------------------------------
        // SLOW ROLLING BAND
        // ----------------------------------------------------

        float band_center =
            frac(
                time *
                NS_BAND_SPEED
            );


        float band_dist =
            abs(
                ns_uv.y -
                band_center
            );


        float band;


        if (
            band_dist <=
            NS_BAND_HEIGHT
        ) {
            band =
                1.0;
        }
        else if (
            band_dist >=
            NS_BAND_HEIGHT + 0.015
        ) {
            band =
                0.0;
        }
        else {
            band =
                1.0 -
                smoothstep(
                    NS_BAND_HEIGHT,
                    NS_BAND_HEIGHT + 0.015,
                    band_dist
                );
        }


        static_rgb +=
            NS_STATIC_MID *
            band *
            NS_BAND_STRENGTH;
    }


    // ========================================================
    // VARIANT B — DENSE ANALOG STATIC MODE
    //
    // No fine-line or rolling-band layer here.
    // This is a true snowy/static alternate NO SIGNAL state.
    // ========================================================

    else {
        // Two-pixel "snow" cells make the analog grain readable instead
        // of averaging into a flat grey field at normal viewing distance.
        float2 static_cell =
            floor(
                screen_pixel /
                2.0
            );


        float coarse_noise =
            hash21(
                static_cell +
                float2(
                    noise_frame * 43.0,
                    noise_frame * 11.0
                )
            );


        // Fine one-pixel component keeps the field electrically alive.
        float fine_noise =
            hash21(
                screen_pixel +
                float2(
                    noise_frame * 19.0,
                    noise_frame * 53.0
                )
            );


        float3 dense_static;


        // Keep a broad tonal spread instead of averaging two hashes
        // together, which was washing the result into a near-flat grey.
        if (coarse_noise < 0.24) {
            dense_static =
                lerp(
                    NS_STATIC_LOW,
                    NS_STATIC_MID,
                    coarse_noise /
                    0.24
                );
        }
        else if (coarse_noise < 0.72) {
            dense_static =
                lerp(
                    NS_STATIC_MID,
                    NS_STATIC_HIGH,
                    (
                        coarse_noise -
                        0.24
                    ) /
                    0.48
                );
        }
        else {
            dense_static =
                lerp(
                    NS_STATIC_HIGH,
                    NS_STATIC_PEAK,
                    (
                        coarse_noise -
                        0.72
                    ) /
                    0.28
                );
        }


        // Small bright/dark fine-grain interruptions stop the 2x2 cells
        // from looking blocky while preserving the purple-grey palette.
        if (fine_noise > 0.965) {
            dense_static =
                lerp(
                    dense_static,
                    NS_STATIC_PEAK,
                    0.72
                );
        }
        else if (fine_noise < 0.035) {
            dense_static =
                lerp(
                    dense_static,
                    THEME_BLACK,
                    0.58
                );
        }


        static_rgb =
            lerp(
                base,
                dense_static,
                NS_STATIC_VARIANT_STRENGTH
            );
    }


    // ========================================================
    // RARE LIGHT STREAK
    //
    // Shared by both variants.
    // ========================================================

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


    if (streak_exists > 0.0) {
        float streak_y =
            hash11(
                streak_slot +
                33.1
            );


        float streak_dist =
            abs(
                ns_uv.y -
                streak_y
            );


        float streak =
            1.0 -
            smoothstep(
                0.0,
                0.0035,
                streak_dist
            );


        static_rgb +=
            NS_STATIC_PEAK *
            streak *
            NS_STREAK_STRENGTH;
    }


    // ========================================================
    // NO SIGNAL PLAQUE
    //
    // Uses the warped UV too, so a fault can physically tear the
    // plaque/text along with the rest of the dead channel.
    // ========================================================

    float2 sign_half =
        float2(
            NS_SIGN_WIDTH,
            NS_SIGN_HEIGHT
        ) *
        0.5;


    float2 sign_delta =
        abs(
            ns_uv -
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
            ns_uv.x,
            1.0 - ns_uv.y
        );


    float text_mask =
        0.0;


    if (sign_mask > 0.0) {
        text_mask =
            no_signal_text_mask(
                text_uv
            );
    }


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


    // ========================================================
    // FAULT STATIC BLAST
    //
    // Applied after the plaque so a live fault can briefly cut
    // through EVERYTHING on the NO SIGNAL screen.
    // ========================================================

    if (
        fault_envelope > 0.0 &&
        fault_mask > 0.0
    ) {
        float fault_frame =
            floor(
                time *
                61.0
            );


        float fault_noise =
            hash21(
                screen_pixel +
                float2(
                    fault_frame * 29.0,
                    fault_frame * 47.0
                )
            );


        float3 fault_color;


        if (fault_noise < 0.50) {
            fault_color =
                lerp(
                    NS_STATIC_LOW,
                    NS_STATIC_HIGH,
                    fault_noise * 2.0
                );
        }
        else {
            fault_color =
                lerp(
                    NS_STATIC_MID,
                    NS_STATIC_PEAK,
                    (
                        fault_noise -
                        0.50
                    ) *
                    2.0
                );
        }


        with_sign =
            lerp(
                with_sign,
                fault_color,
                saturate(
                    fault_mask *
                    fault_envelope *
                    NS_FAULT_STATIC_STRENGTH
                )
            );
    }


    return float4(
        saturate(
            with_sign
        ),
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


    float4 source =
        color;


    // When tear is exactly zero, every warp offset is also exactly
    // zero and the old texture read sampled t.pos. Reuse `color`.
    if (tear > 0.0) {
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


        // ----------------------------------------------------
        // WHOLE SCREEN WARP
        // ----------------------------------------------------

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


        source =
            t.backbuffer.Sample(
                uv
            );
    }


    // --------------------------------------------------------
    // PURPLE-GREY STATIC
    // --------------------------------------------------------

    float3 final_rgb =
        source.rgb;


    // After progress 0.32 the static blend weight is exactly zero.
    // Skip the per-pixel hash/noise palette work for the rest of
    // the wake/sleep transition.
    if (static_amount > 0.0) {
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


        final_rgb =
            lerp(
                source.rgb,
                noise,
                static_amount * 0.96
            );
    }


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

float4
render_signal_main(
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


// ============================================================
// FUSED HUM STAGE
//
// This reproduces the old:
//     metapollo-hum -> metapollo-signal
//
// The signal renderer receives the hum-shifted center color, while
// any t.backbuffer samples inside the signal renderer still address
// the original input texture exactly as they did in the old group.
// ============================================================

static const float HUM_X_PIXELS = 0.34;
static const float HUM_Y_PIXELS = 0.16;

static const float HUM_X_SPEED = 17.3;
static const float HUM_Y_SPEED = 13.7;

static const float HUM_SECONDARY = 0.30;


float4
render_hum_signal_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float time =
        d.timestamp;


    float2 pixel =
        1.0 /
        float2(
            d.viewport_size_pixels
        );


    float x1 =
        sin(
            time *
            HUM_X_SPEED *
            6.2831853
        );


    float y1 =
        sin(
            time *
            HUM_Y_SPEED *
            6.2831853
        );


    float x2 =
        sin(
            time *
            (
                HUM_X_SPEED *
                0.371
            ) *
            6.2831853 +
            1.7
        );


    float y2 =
        sin(
            time *
            (
                HUM_Y_SPEED *
                0.417
            ) *
            6.2831853 +
            3.1
        );


    float x_motion =
        (
            x1 +
            x2 *
            HUM_SECONDARY
        ) *
        HUM_X_PIXELS;


    float y_motion =
        (
            y1 +
            y2 *
            HUM_SECONDARY
        ) *
        HUM_Y_PIXELS;


    float2 uv =
        t.pos +
        float2(
            pixel.x *
            x_motion,
            pixel.y *
            y_motion
        );


    uv =
        clamp(
            uv,
            float2(0.0),
            float2(1.0)
        );


    float4 hum_color =
        t.backbuffer.Sample(
            uv
        );


    return
        render_signal_main(
            hum_color,
            t,
            d
        );
}


// ============================================================
// FUSED LIVING REFLECTION STAGE
// ============================================================

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


float reflection_hash11(float p) {
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

    float distance =
        abs(distance_from_center);


    // Exact smoothstep endpoint shortcuts.
    if (distance <= inner) {
        return 1.0;
    }

    if (distance >= width) {
        return 0.0;
    }


    return
        1.0 -
        smoothstep(
            inner,
            width,
            distance
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

    float distance_sq =
        dot(q, q);


    // Outside the ellipse the old smoothstep result is exactly 1,
    // so the returned sheen is exactly zero.
    if (distance_sq >= 1.0) {
        return 0.0;
    }

    if (distance_sq <= 0.0) {
        return 1.0;
    }


    return
        1.0 -
        smoothstep(
            0.0,
            1.0,
            sqrt(distance_sq)
        );
}


float4 render_reflection_main(
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
        reflection_hash11(
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
            reflection_hash11(
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
            reflection_hash11(
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

    float clamped_age =
        saturate(age);

    // Slow physical fade rather than popping on/off.
    // Outside an enabled event, the old envelope was exactly zero,
    // so skip both smoothsteps during the long inactive stretches.
    float envelope =
        0.0;

    if (
        event_enabled > 0.0 &&
        inside_event > 0.0
    ) {
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

        envelope =
            fade_in *
            fade_out;
    }

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

    float2 face_q =
        p *
        float2(
            0.84,
            1.0
        );

    float face_distance_sq =
        dot(
            face_q,
            face_q
        );

    float across_face;

    if (
        face_distance_sq <=
        0.52 * 0.52
    ) {
        across_face = 1.0;
    }
    else if (
        face_distance_sq >=
        0.78 * 0.78
    ) {
        across_face = 0.0;
    }
    else {
        across_face =
            1.0 -
            smoothstep(
                0.52,
                0.78,
                sqrt(
                    face_distance_sq
                )
            );
    }

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
            clamped_age
        );

    // Active glare travel is built inside the event block below.
    // The direction is deliberately fixed LEFT -> RIGHT every time.

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
                    clamped_age *
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

    float bright_mix;

    if (luma <= 0.08) {
        bright_mix = 0.0;
    }
    else if (luma >= 0.72) {
        bright_mix = 1.0;
    }
    else {
        bright_mix =
            smoothstep(
                0.08,
                0.72,
                luma
            );
    }

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
        0.0;

    if (envelope > 0.0) {
        // ====================================================
        // LIVING EVENT VARIATION
        //
        // One stable seed family is derived from window_id.
        // Values stay fixed for the whole event; only smooth
        // travel / drift / breathing evolves with age.
        //
        // Direction is NEVER randomized:
        // every shine still moves LEFT -> RIGHT.
        // ====================================================

        float event_y_center =
            lerp(
                -0.08,
                0.08,
                reflection_hash11(
                    window_id * 31.17 +
                    1.13
                )
            );

        float event_slope =
            1.0 +
            lerp(
                -0.035,
                0.035,
                reflection_hash11(
                    window_id * 37.41 +
                    5.71
                )
            );

        float event_glare_width =
            lerp(
                0.18,
                0.28,
                reflection_hash11(
                    window_id * 41.83 +
                    7.29
                )
            );

        float event_core_width =
            lerp(
                0.045,
                0.075,
                reflection_hash11(
                    window_id * 43.97 +
                    9.47
                )
            );

        float event_intensity =
            lerp(
                0.80,
                1.12,
                reflection_hash11(
                    window_id * 47.23 +
                    11.19
                )
            );

        float event_travel =
            SHINE_TRAVEL *
            lerp(
                0.90,
                1.12,
                reflection_hash11(
                    window_id * 53.11 +
                    13.73
                )
            );

        float event_y_drift =
            lerp(
                -0.025,
                0.025,
                reflection_hash11(
                    window_id * 59.03 +
                    15.31
                )
            );

        float brightness_breathe =
            lerp(
                0.03,
                0.10,
                reflection_hash11(
                    window_id * 61.79 +
                    17.87
                )
            );

        float width_breathe =
            lerp(
                0.01,
                0.035,
                reflection_hash11(
                    window_id * 67.13 +
                    19.43
                )
            );

        float breathe_phase =
            reflection_hash11(
                window_id * 71.41 +
                21.97
            ) *
            6.2831853;

        float event_sheen_x =
            lerp(
                -0.035,
                0.035,
                reflection_hash11(
                    window_id * 73.67 +
                    23.51
                )
            );

        float event_sheen_y =
            lerp(
                -0.020,
                0.020,
                reflection_hash11(
                    window_id * 79.19 +
                    25.37
                )
            );

        float event_sheen_strength =
            lerp(
                0.90,
                1.10,
                reflection_hash11(
                    window_id * 83.53 +
                    27.11
                )
            );

        float event_horizontal_offset =
            lerp(
                -0.025,
                0.025,
                reflection_hash11(
                    window_id * 89.17 +
                    29.83
                )
            );


        // ----------------------------------------------------
        // SLOW CLOUD / WINDOW-LIGHT MOTION
        // ----------------------------------------------------

        float vertical_motion =
            event_y_drift *
            sin(
                clamped_age *
                3.14159265
            );

        float brightness_motion =
            1.0 +
            brightness_breathe *
            sin(
                clamped_age *
                6.2831853 +
                breathe_phase
            );

        float width_motion =
            1.0 +
            width_breathe *
            sin(
                clamped_age *
                6.2831853 +
                breathe_phase +
                1.731
            );


        float2 event_p =
            p;

        event_p.y -=
            event_y_center +
            vertical_motion;


        // The broad body itself drifts slightly left -> right too.
        float body_sweep =
            lerp(
                0.025,
                -0.025,
                shine_phase
            );


        float event_curved_diagonal =
            event_p.x +
            event_slope *
            event_p.y +
            GLARE_OFFSET +
            event_horizontal_offset +
            body_sweep +
            GLARE_CURVE *
            (
                event_p.x * event_p.x -
                0.25 *
                event_p.y * event_p.y
            );


        float event_broad_glare =
            soft_band(
                event_curved_diagonal,
                event_glare_width *
                width_motion
            );

        event_broad_glare *=
            0.58 +
            0.42 *
            across_face;


        // Positive diagonal shift places the core on the LEFT.
        // Moving toward negative shift therefore guarantees a
        // LEFT -> RIGHT sweep on screen every single event.
        float event_shine_shift =
            lerp(
                event_travel,
                -event_travel,
                shine_phase
            );


        float glare_core =
            soft_band(
                event_curved_diagonal +
                event_shine_shift,
                event_core_width *
                (
                    1.0 +
                    width_breathe *
                    0.45 *
                    sin(
                        clamped_age *
                        6.2831853 +
                        breathe_phase +
                        0.913
                    )
                )
            );

        glare_core *=
            across_face;


        float pulse =
            1.0 +
            SHINE_PULSE *
            sin(
                clamped_age *
                6.2831853 *
                2.0
            );


        // Event-only upper sheen variation. The permanent base
        // sheen above remains the original stable glass layer.
        float event_upper_sheen =
            soft_ellipse(
                uv,
                float2(
                    SHEEN_X +
                    sheen_drift +
                    event_sheen_x,
                    SHEEN_Y +
                    event_sheen_y +
                    vertical_motion * 0.40 +
                    0.018 *
                    sin(
                        clamped_age *
                        6.2831853
                    )
                ),
                float2(
                    SHEEN_WIDTH,
                    SHEEN_HEIGHT
                )
            );

        event_upper_sheen *=
            0.55 +
            0.45 *
            entry_fade;


        active_reflection =
            event_broad_glare *
            PRIMARY_STRENGTH *
            event_intensity;

        active_reflection +=
            glare_core *
            GLARE_CORE_STRENGTH *
            pulse *
            event_intensity;

        active_reflection +=
            event_upper_sheen *
            SECONDARY_STRENGTH *
            event_sheen_strength;

        active_reflection *=
            envelope *
            brightness_motion;
    }

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


// ============================================================
// FINAL FUSED WRAPPER
//
// Exact previous order:
//     HUM -> SIGNAL -> LIVING REFLECTION
// ============================================================

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float4 signal_color =
        render_hum_signal_main(
            color,
            t,
            d
        );

    return
        render_reflection_main(
            signal_color,
            t,
            d
        );
}
