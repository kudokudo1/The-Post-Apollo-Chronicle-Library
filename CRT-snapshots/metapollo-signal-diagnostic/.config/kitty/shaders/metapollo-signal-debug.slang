#language slang 2026

import kitty_custom_shader_types;

// ============================================================
// METAPOLLO SIGNAL DIAGNOSTIC OVERLAY
//
// TEMPORARY DEBUG ONLY.
//
// Full-screen pulse flashes:
//   GREEN  = idle pulse reached scratch A
//   YELLOW = activity pulse reached scratch A
//
// Top-left state box (what the final renderer can read from persist):
//   CYAN    = ACTIVE
//   RED     = SLEEP GLITCH
//   BLUE    = NO SIGNAL
//   MAGENTA = WAKE GLITCH
//   WHITE   = invalid / unrecognized persist state
//
// Top progress bar:
//   visible during SLEEP or WAKE and grows with persist.g
// ============================================================

static const float2 STATE_UV = float2(0.005, 0.005);

static const float MODE_ACTIVE    = 0.10;
static const float MODE_SLEEP     = 0.35;
static const float MODE_NO_SIGNAL = 0.60;
static const float MODE_WAKE      = 0.85;

static const float PULSE_IDLE     = 0.25;
static const float PULSE_ACTIVITY = 0.75;

static const float STATE_SIGNATURE = 0.731;

bool near_value(float value, float target, float tolerance) {
    return abs(value - target) < tolerance;
}

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float4 out_color = color;

    float4 pulse = t.a.Sample(STATE_UV);
    float4 state = t.persist.Sample(STATE_UV);

    bool idle_pulse = near_value(pulse.r, PULSE_IDLE, 0.10);
    bool activity_pulse = near_value(pulse.r, PULSE_ACTIVITY, 0.10);

    // --------------------------------------------------------
    // EVENT PULSE: huge unmistakable full-screen flash.
    // --------------------------------------------------------
    if (idle_pulse) {
        out_color.rgb = lerp(out_color.rgb, float3(0.05, 1.00, 0.10), 0.82);
    }

    if (activity_pulse) {
        out_color.rgb = lerp(out_color.rgb, float3(1.00, 0.90, 0.05), 0.82);
    }

    // --------------------------------------------------------
    // STATE BOX: top-left ~14% x 10%.
    // --------------------------------------------------------
    bool state_box =
        t.pos.x >= 0.015 &&
        t.pos.x <= 0.155 &&
        t.pos.y >= 0.015 &&
        t.pos.y <= 0.115;

    bool valid_state = near_value(state.a, STATE_SIGNATURE, 0.02);

    float3 state_color = float3(1.0, 1.0, 1.0); // invalid = white

    if (valid_state) {
        if (near_value(state.r, MODE_ACTIVE, 0.04)) {
            state_color = float3(0.05, 0.95, 1.00); // cyan
        }
        else if (near_value(state.r, MODE_SLEEP, 0.04)) {
            state_color = float3(1.00, 0.05, 0.05); // red
        }
        else if (near_value(state.r, MODE_NO_SIGNAL, 0.04)) {
            state_color = float3(0.08, 0.18, 1.00); // blue
        }
        else if (near_value(state.r, MODE_WAKE, 0.04)) {
            state_color = float3(1.00, 0.05, 0.85); // magenta
        }
    }

    if (state_box) {
        out_color.rgb = state_color;
    }

    // --------------------------------------------------------
    // TRANSITION PROGRESS BAR.
    // Red-state or magenta-state should grow this from left to right.
    // --------------------------------------------------------
    bool transition_state =
        valid_state &&
        (
            near_value(state.r, MODE_SLEEP, 0.04) ||
            near_value(state.r, MODE_WAKE, 0.04)
        );

    if (transition_state) {
        float p = saturate(state.g);

        bool bar_bg =
            t.pos.x >= 0.20 &&
            t.pos.x <= 0.80 &&
            t.pos.y >= 0.025 &&
            t.pos.y <= 0.055;

        bool bar_fill =
            t.pos.x >= 0.20 &&
            t.pos.x <= (0.20 + 0.60 * p) &&
            t.pos.y >= 0.025 &&
            t.pos.y <= 0.055;

        if (bar_bg) {
            out_color.rgb = float3(0.05, 0.05, 0.05);
        }

        if (bar_fill) {
            out_color.rgb = float3(1.00, 1.00, 1.00);
        }
    }

    return float4(out_color.rgb, color.a);
}
