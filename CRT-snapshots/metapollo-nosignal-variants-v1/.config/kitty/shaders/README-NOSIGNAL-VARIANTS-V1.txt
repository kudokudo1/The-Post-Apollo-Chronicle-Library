METAPOLLO CRT — NO SIGNAL VARIANTS V1
======================================

Built directly on the passed Source Optimization 15 shader.
Living Glare Variation 1 is untouched.

NO EXTRA PERSISTENT STATE
-------------------------
This deliberately uses no new state-machine storage.

Every 30 seconds, globally, the NO SIGNAL renderer rolls one of two modes:
    A — line / rolling-band mode
    B — dense analog static mode

The selection is deterministic for that 30-second slot.
If the next slot rolls the same mode, the screen simply stays there.

That means visible mode changes happen infrequently:
- minimum possible hold: 30 seconds
- common hold: around 30–60+ seconds
- 90/120+ second holds naturally happen when the same mode repeats

It does not care when NO SIGNAL starts or ends.

MODE A
------
Keeps the existing sparse purple-grey static, fine horizontal noise,
slow rolling band, rare light streak, and NO SIGNAL plaque.

MODE B
------
Dense animated purple-grey analog snow replaces the fine line + rolling
band layers. The same NO SIGNAL plaque remains.

NO SIGNAL ELECTRICAL FAULTS
---------------------------
Independent of whichever mode is currently selected.

Every 7-second window has a 42% chance to contain a short fault:
- 0.10–0.55 second duration
- horizontal tear/warp
- tiny vertical wobble
- purple-grey static burst
- usually a random horizontal region
- 10% of faults become a whole-screen failure

The fault UV is used for the procedural screen AND the NO SIGNAL plaque,
so the plaque/text can physically tear with the rest of the image.

The static blast is applied after the plaque, so a fault can briefly cut
through the entire dead-channel image.

UNCHANGED
---------
- active terminal visuals
- 1-minute idle timing
- sleep transition
- wake transition
- alpha state engine
- living glare
- HUM
- bloom/halation/chroma/phosphor/grid
- existing interference/sync pipeline behavior
