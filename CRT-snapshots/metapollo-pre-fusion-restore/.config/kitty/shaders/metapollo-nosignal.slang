#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO IDLE / NO SIGNAL
//
// Dark purple-grey analog static.
//
// Screen base:
//     #1B0623
//
// Sign:
//     #16051F
//
// Noise:
//     desaturated purple-grey
//
// "NO SIGNAL":
//     transparent cut-out showing static underneath.
// ============================================================


// ------------------------------------------------------------
// METAPOLLO SCREEN COLORS
// ------------------------------------------------------------

static const float3 THEME_BLACK =
    float3(0.106, 0.024, 0.137);   // #1B0623

static const float3 THEME_DARK =
    float3(0.086, 0.020, 0.122);   // #16051F


// ------------------------------------------------------------
// DESATURATED STATIC PALETTE
// ------------------------------------------------------------

static const float3 STATIC_LOW =
    float3(0.090, 0.080, 0.100);

static const float3 STATIC_MID =
    float3(0.175, 0.155, 0.190);

static const float3 STATIC_HIGH =
    float3(0.300, 0.275, 0.320);

static const float3 STATIC_PEAK =
    float3(0.420, 0.390, 0.440);


// ------------------------------------------------------------
// IDLE TIMER
// ------------------------------------------------------------

static const float IDLE_PROGRESS_START = 0.000198413;
static const float IDLE_FADE_WIDTH     = 0.0000010;


// ------------------------------------------------------------
// STATIC SETTINGS
// ------------------------------------------------------------

static const float SOURCE_VISIBILITY = 0.06;
static const float DARK_FLOOR        = 0.018;

static const float NOISE_DENSITY  = 0.060;
static const float NOISE_STRENGTH = 0.54;

static const float LINE_SPEED    = 0.22;
static const float LINE_DENSITY  = 190.0;
static const float LINE_STRENGTH = 0.10;

static const float BAND_SPEED    = 0.10;
static const float BAND_HEIGHT   = 0.035;
static const float BAND_STRENGTH = 0.14;

static const float STREAK_DENSITY  = 0.0025;
static const float STREAK_STRENGTH = 0.32;


// ------------------------------------------------------------
// NO SIGNAL SIGN
// ------------------------------------------------------------

static const float SIGN_WIDTH   = 0.38;
static const float SIGN_HEIGHT  = 0.115;
static const float SIGN_OPACITY = 0.78;

static const float TEXT_WIDTH   = 0.285;
static const float TEXT_HEIGHT  = 0.052;


// ------------------------------------------------------------
// RANDOM HELPERS
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
            0.5 - TEXT_WIDTH * 0.5,
            0.5 - TEXT_HEIGHT * 0.5
        );


    float2 local =
        (
            uv -
            origin
        ) /
        float2(
            TEXT_WIDTH,
            TEXT_HEIGHT
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


// ------------------------------------------------------------
// MAIN
// ------------------------------------------------------------

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float idle_mix =
        smoothstep(
            IDLE_PROGRESS_START,
            IDLE_PROGRESS_START +
            IDLE_FADE_WIDTH,
            t.animation_progress
        );


    if (idle_mix <= 0.0) {
        return color;
    }


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
            SOURCE_VISIBILITY
        );


    base +=
        THEME_DARK *
        DARK_FLOOR;


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
            NOISE_DENSITY,
            n
        );


    float3 noise_color;


    if (n < 0.55) {
        noise_color =
            lerp(
                STATIC_LOW,
                STATIC_MID,
                n / 0.55
            );
    }
    else {
        noise_color =
            lerp(
                STATIC_MID,
                STATIC_HIGH,
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
            NOISE_STRENGTH
        );


    // --------------------------------------------------------
    // FINE HORIZONTAL NOISE
    // --------------------------------------------------------

    float line_wave =
        sin(
            t.pos.y *
            LINE_DENSITY +
            time *
            LINE_SPEED *
            40.0
        );


    float line_mask =
        smoothstep(
            0.65,
            1.0,
            line_wave
        );


    static_rgb +=
        STATIC_MID *
        line_mask *
        LINE_STRENGTH;


    // --------------------------------------------------------
    // SLOW ROLLING BAND
    // --------------------------------------------------------

    float band_center =
        frac(
            time *
            BAND_SPEED
        );


    float band_dist =
        abs(
            t.pos.y -
            band_center
        );


    float band =
        1.0 -
        smoothstep(
            BAND_HEIGHT,
            BAND_HEIGHT + 0.015,
            band_dist
        );


    static_rgb +=
        STATIC_MID *
        band *
        BAND_STRENGTH;


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
            STREAK_DENSITY,
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
        STATIC_PEAK *
        streak *
        STREAK_STRENGTH;


    // --------------------------------------------------------
    // NO SIGNAL PLAQUE
    // --------------------------------------------------------

    float2 sign_half =
        float2(
            SIGN_WIDTH,
            SIGN_HEIGHT
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
        SIGN_OPACITY;


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
