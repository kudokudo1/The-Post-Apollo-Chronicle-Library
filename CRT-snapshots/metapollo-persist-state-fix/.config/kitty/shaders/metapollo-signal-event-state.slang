#language slang 2026

import kitty_custom_shader_types;

// ============================================================
// METAPOLLO EVENT -> NEXT STATE
//
// This group writes to scratch texture A, so it is allowed to
// sample the previous persistent state from t.persist.
// The attached copy group then copies A -> persist in the SAME draw.
//
// EVENT_KIND:
//   1 = Kitty user-idle
//   2 = Kitty user-activity / focus-in
// ============================================================

static const int EVENT_KIND = 0;

static const float MODE_ACTIVE    = 0.10;
static const float MODE_SLEEP     = 0.35;
static const float MODE_NO_SIGNAL = 0.60;
static const float MODE_WAKE      = 0.85;

static const float STATE_SIGNATURE = 0.731;
static const float2 STATE_UV = float2(0.5, 0.5);

// 0.018 * ~50-56 scheduled frames is about the old 0.9 s transition.
static const float TRANSITION_STEP = 0.018;

bool state_valid(float4 state) {
    return abs(state.a - STATE_SIGNATURE) < 0.01;
}

bool mode_is(float value, float target) {
    return abs(value - target) < 0.035;
}

float4 make_state(float mode, float progress, float seed) {
    return float4(
        mode,
        saturate(progress),
        saturate(seed),
        STATE_SIGNATURE
    );
}

public float4 fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    // Read one canonical state sample. Every state write is full-screen,
    // so the state is identical at every UV after initialization.
    float4 previous = t.persist.Sample(STATE_UV);

    if (!state_valid(previous)) {
        previous = make_state(MODE_ACTIVE, 0.0, 0.173);
    }

    float mode = previous.r;
    float progress = previous.g;
    float seed = previous.b;

    // --------------------------------------------------------
    // KITTY USER-IDLE
    // ACTIVE -> SLEEP -> NO SIGNAL
    //
    // If activity has already moved us into WAKE, this older idle
    // animation is not allowed to pull the state backwards.
    // --------------------------------------------------------
    if (EVENT_KIND == 1) {
        if (mode_is(mode, MODE_ACTIVE)) {
            return make_state(MODE_SLEEP, 0.0, seed);
        }

        if (mode_is(mode, MODE_SLEEP)) {
            float next_progress = progress + TRANSITION_STEP;

            if (next_progress >= 1.0) {
                return make_state(MODE_NO_SIGNAL, 1.0, seed);
            }

            return make_state(MODE_SLEEP, next_progress, seed);
        }

        // Already NO SIGNAL, or activity has moved us into WAKE.
        // Preserve the newer state instead of fighting it.
        return previous;
    }

    // --------------------------------------------------------
    // KITTY USER-ACTIVITY / FOCUS-IN
    // NO SIGNAL/SLEEP -> WAKE -> ACTIVE
    //
    // Crucially, repeated user-activity does NOT reset progress.
    // It simply causes this same group to remain scheduled while
    // the progress stored in persist keeps advancing.
    // --------------------------------------------------------
    if (EVENT_KIND == 2) {
        if (mode_is(mode, MODE_SLEEP) || mode_is(mode, MODE_NO_SIGNAL)) {
            return make_state(MODE_WAKE, 0.0, seed);
        }

        if (mode_is(mode, MODE_WAKE)) {
            float next_progress = progress + TRANSITION_STEP;

            if (next_progress >= 1.0) {
                return make_state(MODE_ACTIVE, 0.0, seed);
            }

            return make_state(MODE_WAKE, next_progress, seed);
        }

        // Startup invalid state lands here as ACTIVE, and ordinary
        // user activity while ACTIVE stays ACTIVE with no wake glitch.
        return make_state(MODE_ACTIVE, 0.0, seed);
    }

    return previous;
}
