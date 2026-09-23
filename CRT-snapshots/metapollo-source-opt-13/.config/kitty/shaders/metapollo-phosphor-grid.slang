#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO — FUSED PHOSPHOR + GRID
//
// Exact order preserved:
//     phosphor -> grid
//
// This replaces two sequential shader stages with one source shader.
// All pipeline-tunable variable names remain identical.
// ============================================================


// ------------------------------------------------------------
// PHOSPHOR — same controls
// ------------------------------------------------------------

static const float PHOSPHOR_STRENGTH       = 0.50;
static const float PHOSPHOR_STRIPE_WIDTH   = 1.0;

static const float PHOSPHOR_ROW_HEIGHT     = 3.0;
static const float PHOSPHOR_ROW_OFFSET     = 1.5;

static const float PHOSPHOR_BRIDGE_DARKEN  = 0.28;

static const float PHOSPHOR_START          = 0.03;
static const float PHOSPHOR_FULL           = 0.40;


// ------------------------------------------------------------
// GRID — same controls
// ------------------------------------------------------------

static const float VERTICAL_SPACING        = 3.0;
static const float VERTICAL_WIDTH          = 1.0;
static const float VERTICAL_DARKEN         = 0.26;

static const float HORIZONTAL_SPACING      = 3.0;
static const float HORIZONTAL_WIDTH        = 1.0;
static const float HORIZONTAL_DARKEN       = 0.18;

static const float GRID_START              = 0.025;
static const float GRID_FULL               = 0.35;


float brightness_of(float3 c) {
    return max(c.r, max(c.g, c.b));
}


public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    // The darkest pixels are untouched by both phosphor and grid.
    // Check that before any pixel-coordinate/modulo work.
    float phosphor_brightness =
        brightness_of(color.rgb);

    if (phosphor_brightness <= GRID_START) {
        return color;
    }


    // Cache pixel coordinates once. Both stages use them.
    float pixel_x =
        floor(t.pos.x * float(d.viewport_size_pixels.x));

    float pixel_y =
        floor(t.pos.y * float(d.viewport_size_pixels.y));


    // ========================================================
    // STAGE 1 — PHOSPHOR
    // ========================================================

    float4 phosphor_out =
        color;

    bool phosphor_applied =
        phosphor_brightness > PHOSPHOR_START;

    if (phosphor_applied) {
        float row_group =
            floor(pixel_y / PHOSPHOR_ROW_HEIGHT);

        float row_offset =
            fmod(row_group, 2.0) *
            PHOSPHOR_ROW_OFFSET;

        float stripe =
            floor(
                (pixel_x + row_offset) /
                PHOSPHOR_STRIPE_WIDTH
            );

        float phase =
            fmod(stripe, 3.0);

        float3 triad;

        if (phase < 1.0) {
            triad =
                float3(1.0, 0.58, 0.58);
        }
        else if (phase < 2.0) {
            triad =
                float3(0.58, 1.0, 0.58);
        }
        else {
            triad =
                float3(0.58, 0.58, 1.0);
        }

        float within_row =
            fmod(
                pixel_y,
                PHOSPHOR_ROW_HEIGHT
            );

        float bridge_zone =
            smoothstep(
                PHOSPHOR_ROW_HEIGHT - 1.0,
                PHOSPHOR_ROW_HEIGHT - 0.1,
                within_row
            );

        float row_mask =
            1.0 -
            bridge_zone *
            PHOSPHOR_BRIDGE_DARKEN;

        float lit_amount =
            phosphor_brightness >= PHOSPHOR_FULL
                ? 1.0
                : smoothstep(
                    PHOSPHOR_START,
                    PHOSPHOR_FULL,
                    phosphor_brightness
                );

        float strength =
            PHOSPHOR_STRENGTH *
            lit_amount;

        float3 phosphor_mask =
            triad *
            row_mask;

        phosphor_out.rgb =
            phosphor_out.rgb *
            lerp(
                float3(1.0),
                phosphor_mask,
                strength
            );
    }


    // ========================================================
    // STAGE 2 — GRID
    //
    // Important: brightness is measured AFTER phosphor, exactly
    // like the old second shader stage.
    // ========================================================

    float grid_brightness =
        phosphor_applied
            ? brightness_of(phosphor_out.rgb)
            : phosphor_brightness;

    if (grid_brightness <= GRID_START) {
        return phosphor_out;
    }

    float vertical_position =
        fmod(
            pixel_x,
            VERTICAL_SPACING
        );

    float vertical_line =
        vertical_position < VERTICAL_WIDTH
        ? 1.0
        : 0.0;

    float horizontal_position =
        fmod(
            pixel_y,
            HORIZONTAL_SPACING
        );

    float horizontal_line =
        horizontal_position < HORIZONTAL_WIDTH
        ? 1.0
        : 0.0;


    // If this pixel is between both grille lines, grid darkening is
    // exactly zero and the old result is phosphor_out unchanged.
    if (
        vertical_line <= 0.0 &&
        horizontal_line <= 0.0
    ) {
        return phosphor_out;
    }


    float grid_lit_amount =
        grid_brightness >= GRID_FULL
            ? 1.0
            : smoothstep(
                GRID_START,
                GRID_FULL,
                grid_brightness
            );

    float darkening =
        vertical_line *
        VERTICAL_DARKEN +
        horizontal_line *
        HORIZONTAL_DARKEN;

    darkening =
        min(
            darkening,
            0.75
        );

    float final_multiplier =
        1.0 -
        darkening *
        grid_lit_amount;

    phosphor_out.rgb *=
        final_multiplier;

    return phosphor_out;
}
