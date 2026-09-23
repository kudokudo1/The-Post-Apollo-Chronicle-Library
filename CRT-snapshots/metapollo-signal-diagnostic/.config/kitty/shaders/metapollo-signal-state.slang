#language slang 2026

import kitty_custom_shader_types;

// ============================================================
// METAPOLLO SIGNAL CONTROLLER
//
// This is the ONLY shader allowed to write persistent signal state.
//
// Inputs:
//   t.a = current frame event pulse
//   t.b = previous frame persistent state snapshot
//
// Output (to persist):
//   R = mode
//   G = transition progress 0..1
//   B = stable cycle seed
//   A = signature
//
// No timestamps are stored. No event group writes persist.
// ============================================================

static const float2 STATE_UV = float2(0.005, 0.005);

static const float MODE_ACTIVE    = 0.10;
static const float MODE_SLEEP     = 0.35;
static const float MODE_NO_SIGNAL = 0.60;
static const float MODE_WAKE      = 0.85;

static const float PULSE_IDLE     = 0.25;
static const float PULSE_ACTIVITY = 0.75;

static const float STATE_SIGNATURE = 0.731;

// animation_step is 16 ms in the pipeline.
// 0.0178 * ~56 frames ~= 0.90 seconds.
static const float TRANSITION_STEP = 0.0178;

bool state_valid(float4 state) {
    return abs(state.a - STATE_SIGNATURE) < 0.01;
}

bool mode_is(float value, float target) {
    return abs(value - target) < 0.035;
}

bool pulse_is(float value, float target) {
    return abs(value - target) < 0.10;
}

float hash11(float p) {
    return frac(sin(p * 127.1) * 43758.5453123);
}

float4 make_state(
    float mode,
    float progress,
    float seed
) {
    return float4(
        mode,
        saturate(progress),
        saturate(seed),
        STATE_SIGNATURE
    );
}

public float4
fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float4 previous =
        t.b.Sample(
            STATE_UV
        );

    float4 pulse =
        t.a.Sample(
            STATE_UV
        );

    if (!state_valid(previous)) {
        previous = make_state(
            MODE_ACTIVE,
            0.0,
            0.173
        );
    }

    bool idle_event =
        pulse_is(
            pulse.r,
            PULSE_IDLE
        );

    bool activity_event =
        pulse_is(
            pulse.r,
            PULSE_ACTIVITY
        );

    float mode = previous.r;
    float progress = previous.g;
    float seed = previous.b;

    // --------------------------------------------------------
    // ACTIVE
    // --------------------------------------------------------
    if (mode_is(mode, MODE_ACTIVE)) {
        if (idle_event) {
            float next_seed =
                hash11(
                    float(d.frame_counter) *
                    0.019 +
                    d.timestamp *
                    0.071
                );

            return make_state(
                MODE_SLEEP,
                0.0,
                next_seed
            );
        }

        return make_state(
            MODE_ACTIVE,
            0.0,
            seed
        );
    }

    // --------------------------------------------------------
    // SLEEP GLITCH
    //
    // An activity event during the sleep glitch reverses into the
    // wake glitch. Repeated idle pulses are ignored.
    // --------------------------------------------------------
    if (mode_is(mode, MODE_SLEEP)) {
        if (activity_event) {
            return make_state(
                MODE_WAKE,
                0.0,
                seed
            );
        }

        float next_progress =
            progress +
            TRANSITION_STEP;

        if (next_progress >= 1.0) {
            return make_state(
                MODE_NO_SIGNAL,
                1.0,
                seed
            );
        }

        return make_state(
            MODE_SLEEP,
            next_progress,
            seed
        );
    }

    // --------------------------------------------------------
    // NO SIGNAL
    // --------------------------------------------------------
    if (mode_is(mode, MODE_NO_SIGNAL)) {
        if (activity_event) {
            float next_seed =
                hash11(
                    float(d.frame_counter) *
                    0.017 +
                    seed *
                    19.31
                );

            return make_state(
                MODE_WAKE,
                0.0,
                next_seed
            );
        }

        return make_state(
            MODE_NO_SIGNAL,
            1.0,
            seed
        );
    }

    // --------------------------------------------------------
    // WAKE GLITCH
    //
    // ALL user activity is deliberately ignored here.
    // The progress counter can never be restarted by mouse motion.
    // --------------------------------------------------------
    if (mode_is(mode, MODE_WAKE)) {
        float next_progress =
            progress +
            TRANSITION_STEP;

        if (next_progress >= 1.0) {
            return make_state(
                MODE_ACTIVE,
                0.0,
                seed
            );
        }

        return make_state(
            MODE_WAKE,
            next_progress,
            seed
        );
    }

    // Unknown mode -> recover safely to ACTIVE.
    return make_state(
        MODE_ACTIVE,
        0.0,
        seed
    );
}
