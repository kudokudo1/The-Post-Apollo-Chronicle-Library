#language slang 2026

import kitty_custom_shader_types;


// ============================================================
// METAPOLLO SIGNAL STATE CONTROLLER
//
// CONTROL ONLY.  It does not draw any visual effect.
//
//   0 = ACTIVE
//   1 = PRE-SLEEP
//   2 = ENTER TRANSITION
//   3 = NO SIGNAL
//   4 = WAKE TRANSITION
//
// R = mode
// G = phase start timestamp
// B = stable random seed
// A = signature
//
// The crucial rule:
// once ENTER or WAKE starts, repeated user-activity does not
// replace its original phase timestamp.
// ============================================================


static const float MODE_ACTIVE    = 0.0;
static const float MODE_PRE_SLEEP = 1.0;
static const float MODE_ENTER     = 2.0;
static const float MODE_NO_SIGNAL = 3.0;
static const float MODE_WAKE      = 4.0;

static const float STATE_SIGNATURE = 0.731;
static const float2 STATE_UV = float2(0.005, 0.005);


// The state group's animation is 7 days long.  Since Kitty
// restarts animation_progress on every user-activity event,
// this converts progress back into seconds since last input.
static const float IDLE_TIMER_SECONDS = 604800.0;


// TEST VALUES
//   0-3 sec = ACTIVE
//   3-5 sec = PRE-SLEEP (currently visually unchanged)
//   5 sec   = ENTER transition
//
// Final values can become e.g. 100 / 120 seconds later.
static const float PRE_SLEEP_START_SECONDS = 3.0;
static const float NO_SIGNAL_START_SECONDS = 5.0;

static const float TRANSITION_DURATION = 0.90;


float hash11(float p) {
    return frac(
        sin(p * 127.1) *
        43758.5453123
    );
}


bool valid_state(float4 s) {
    return
        abs(
            s.a -
            STATE_SIGNATURE
        ) <
        0.002;
}


float4 make_state(
    float mode,
    float phase_start,
    float seed
) {
    return float4(
        mode,
        phase_start,
        seed,
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
        t.a.Sample(
            STATE_UV
        );


    bool valid =
        valid_state(
            previous
        );


    float previous_mode =
        valid
            ? previous.r
            : MODE_ACTIVE;


    float previous_start =
        valid
            ? previous.g
            : d.timestamp;


    float previous_seed =
        valid
            ? previous.b
            : 0.173;


    float idle_seconds =
        t.animation_progress *
        IDLE_TIMER_SECONDS;


    // ========================================================
    // WAKE
    //
    // Ignore every additional mouse/key event until the
    // original wake timestamp has completed its 0.90 sec run.
    // ========================================================

    if (
        previous_mode > 3.5 &&
        previous_mode < 4.5
    ) {
        float elapsed =
            max(
                0.0,
                d.timestamp -
                previous_start
            );


        if (
            elapsed <
            TRANSITION_DURATION
        ) {
            return make_state(
                MODE_WAKE,
                previous_start,
                previous_seed
            );
        }


        return make_state(
            MODE_ACTIVE,
            d.timestamp,
            previous_seed
        );
    }


    // ========================================================
    // ENTERING NO SIGNAL
    // ========================================================

    if (
        previous_mode > 1.5 &&
        previous_mode < 2.5
    ) {
        // If the user comes back before the drop finishes,
        // abort cleanly.  We never reached NO SIGNAL, so there
        // is no reason to fire a second wake transition.
        if (
            idle_seconds <
            NO_SIGNAL_START_SECONDS
        ) {
            return make_state(
                MODE_ACTIVE,
                d.timestamp,
                previous_seed
            );
        }


        float elapsed =
            max(
                0.0,
                d.timestamp -
                previous_start
            );


        if (
            elapsed <
            TRANSITION_DURATION
        ) {
            return make_state(
                MODE_ENTER,
                previous_start,
                previous_seed
            );
        }


        return make_state(
            MODE_NO_SIGNAL,
            previous_start,
            previous_seed
        );
    }


    // ========================================================
    // NO SIGNAL -> FIRST ACTIVITY -> WAKE
    // ========================================================

    if (
        previous_mode > 2.5 &&
        previous_mode < 3.5
    ) {
        // Genuine user activity restarts this group's Kitty
        // animation clock, so idle_seconds suddenly becomes
        // very small.  That is the only condition allowed to
        // leave MODE_NO_SIGNAL.
        if (
            idle_seconds <
            PRE_SLEEP_START_SECONDS
        ) {
            float new_seed =
                hash11(
                    d.timestamp *
                    71.37 +
                    previous_seed *
                    19.31 +
                    float(
                        d.frame_counter
                    ) *
                    0.017
                );


            return make_state(
                MODE_WAKE,
                d.timestamp,
                new_seed
            );
        }


        return make_state(
            MODE_NO_SIGNAL,
            previous_start,
            previous_seed
        );
    }


    // ========================================================
    // ACTIVE
    // ========================================================

    if (
        idle_seconds <
        PRE_SLEEP_START_SECONDS
    ) {
        return make_state(
            MODE_ACTIVE,
            d.timestamp -
            idle_seconds,
            previous_seed
        );
    }


    // ========================================================
    // PRE-SLEEP
    //
    // State exists now, but its renderer is intentionally the
    // exact old ACTIVE renderer.  We can add deterioration
    // later without risking the working colors/effects now.
    // ========================================================

    if (
        idle_seconds <
        NO_SIGNAL_START_SECONDS
    ) {
        float idle_start =
            d.timestamp -
            idle_seconds;


        float seed =
            hash11(
                idle_start *
                37.71 +
                9.13
            );


        return make_state(
            MODE_PRE_SLEEP,
            idle_start,
            seed
        );
    }


    // ========================================================
    // START DROP TO NO SIGNAL
    // ========================================================

    float idle_start =
        d.timestamp -
        idle_seconds;


    float entry_seed =
        hash11(
            idle_start *
            83.17 +
            41.73
        );


    return make_state(
        MODE_ENTER,
        d.timestamp,
        entry_seed
    );
}
