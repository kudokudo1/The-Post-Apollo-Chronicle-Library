#language slang 2026

import kitty_custom_shader_types;

// ============================================================
// METAPOLLO ALPHA-ONLY EVENT -> NEXT STATE
//
// CONFIRMED STATE TRANSPORT:
//
//   Kitty event
//      -> scratch A
//      -> attached A -> persist copy
//      -> persist alpha channel
//
// RGB is intentionally NOT used for persistent control state.
// The alpha-only state machine was tested independently before
// being installed into the full CRT renderer.
//
// EVENT_KIND:
//   1 = Kitty user-idle
//   2 = Kitty user-activity / focus-in
// ============================================================

static const int EVENT_KIND = 0;

// Alpha-only encoding.
//
// ACTIVE        = 0.10
//
// SLEEP range:
//   0.20 -> 0.40
//   progress = (alpha - 0.20) / 0.20
//
// NO SIGNAL     = 0.50
//
// WAKE range:
//   0.60 -> 0.80
//   progress = (alpha - 0.60) / 0.20
//
static const float A_ACTIVE = 0.10;

static const float A_SLEEP_START = 0.20;
static const float A_SLEEP_SPAN  = 0.20;

static const float A_NO_SIGNAL = 0.50;

static const float A_WAKE_START = 0.60;
static const float A_WAKE_SPAN  = 0.20;

static const float2 STATE_UV = float2(0.5, 0.5);

// 0.018 * roughly 50-56 scheduled frames ~= old 0.9 s transition.
static const float TRANSITION_STEP = 0.018;

bool near_value(float a, float b) {
    return abs(a - b) < 0.025;
}

bool is_sleep(float a) {
    return a >= 0.175 && a < 0.425;
}

bool is_wake(float a) {
    return a >= 0.575 && a < 0.825;
}

float sleep_progress(float a) {
    return saturate(
        (a - A_SLEEP_START) /
        A_SLEEP_SPAN
    );
}

float wake_progress(float a) {
    return saturate(
        (a - A_WAKE_START) /
        A_WAKE_SPAN
    );
}

float4 pack_state(float a) {
    // RGB deliberately carries no state.
    return float4(
        0.0,
        0.0,
        0.0,
        saturate(a)
    );
}

public float4 fragment_main(
    float4 color,
    KittyTextures t,
    KittyCustomShaderData d
) {
    float a =
        t.persist.Sample(
            STATE_UV
        ).a;

    bool active =
        near_value(
            a,
            A_ACTIVE
        );

    bool sleep =
        is_sleep(a);

    bool no_signal =
        near_value(
            a,
            A_NO_SIGNAL
        );

    bool wake =
        is_wake(a);

    // Uninitialized or unknown persistent state begins as ACTIVE.
    if (!active && !sleep && !no_signal && !wake) {
        a = A_ACTIVE;
        active = true;
    }

    // --------------------------------------------------------
    // KITTY USER-IDLE
    //
    // ACTIVE -> SLEEP transition -> NO SIGNAL
    //
    // If activity has already moved us into WAKE, this older idle
    // animation cannot drag the state backwards.
    // --------------------------------------------------------
    if (EVENT_KIND == 1) {
        if (active) {
            return pack_state(
                A_SLEEP_START
            );
        }

        if (sleep) {
            float p =
                sleep_progress(a) +
                TRANSITION_STEP;

            if (p >= 1.0) {
                return pack_state(
                    A_NO_SIGNAL
                );
            }

            return pack_state(
                A_SLEEP_START +
                p * A_SLEEP_SPAN
            );
        }

        return pack_state(a);
    }

    // --------------------------------------------------------
    // KITTY USER-ACTIVITY / FOCUS-IN
    //
    // SLEEP / NO SIGNAL -> WAKE transition -> ACTIVE
    //
    // Repeated activity does not reset wake progress. Progress is
    // encoded in persist alpha and continues from the stored value.
    // --------------------------------------------------------
    if (EVENT_KIND == 2) {
        if (sleep || no_signal) {
            return pack_state(
                A_WAKE_START
            );
        }

        if (wake) {
            float p =
                wake_progress(a) +
                TRANSITION_STEP;

            if (p >= 1.0) {
                return pack_state(
                    A_ACTIVE
                );
            }

            return pack_state(
                A_WAKE_START +
                p * A_WAKE_SPAN
            );
        }

        return pack_state(
            A_ACTIVE
        );
    }

    return pack_state(a);
}
