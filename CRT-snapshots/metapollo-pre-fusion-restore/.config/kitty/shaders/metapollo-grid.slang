#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO CRT GRID
//
// Adds visible vertical + horizontal screen structure.
//
// Horizontal:
//   supplements Kitty's existing CRT scanlines.
//
// Vertical:
//   creates the grille / mesh structure you're looking for.
//
// This is intentionally separate from the RGB phosphor mask.
// ============================================================

static const float VERTICAL_SPACING   = 3.0;
static const float VERTICAL_WIDTH     = 1.0;
static const float VERTICAL_DARKEN    = 0.26;

static const float HORIZONTAL_SPACING = 3.0;
static const float HORIZONTAL_WIDTH   = 1.0;
static const float HORIZONTAL_DARKEN  = 0.18;

static const float GRID_START         = 0.025;
static const float GRID_FULL          = 0.35;


float brightness_of(float3 c) {
    return max(c.r, max(c.g, c.b));
}


public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float brightness =
        brightness_of(color.rgb);

    // Below GRID_START, lit_amount is exactly zero and the grid
    // multiplier is exactly 1.0.
    if (brightness <= GRID_START) {
        return color;
    }


    float pixel_x =
        floor(t.pos.x * float(d.viewport_size_pixels.x));

    float pixel_y =
        floor(t.pos.y * float(d.viewport_size_pixels.y));


    // --------------------------------------------------------
    // VERTICAL GRILLE
    // --------------------------------------------------------

    float vertical_position =
        fmod(pixel_x, VERTICAL_SPACING);

    float vertical_line =
        vertical_position < VERTICAL_WIDTH
        ? 1.0
        : 0.0;


    // --------------------------------------------------------
    // HORIZONTAL STRUCTURE
    // --------------------------------------------------------

    float horizontal_position =
        fmod(pixel_y, HORIZONTAL_SPACING);

    float horizontal_line =
        horizontal_position < HORIZONTAL_WIDTH
        ? 1.0
        : 0.0;


    // --------------------------------------------------------
    // KEEP THE DARKEST BACKGROUND MOSTLY CLEAN
    // --------------------------------------------------------

    float lit_amount =
        smoothstep(
            GRID_START,
            GRID_FULL,
            brightness
        );


    // --------------------------------------------------------
    // COMBINE BOTH DIRECTIONS
    // --------------------------------------------------------

    float darkening =
        vertical_line * VERTICAL_DARKEN +
        horizontal_line * HORIZONTAL_DARKEN;

    darkening =
        min(darkening, 0.75);

    float final_multiplier =
        1.0 - darkening * lit_amount;


    return float4(
        color.rgb * final_multiplier,
        color.a
    );
}
