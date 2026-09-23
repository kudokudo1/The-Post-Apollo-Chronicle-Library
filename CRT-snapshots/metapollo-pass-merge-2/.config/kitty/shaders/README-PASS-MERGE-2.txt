METAPOLLO CRT — PASS MERGE 2
=============================

This test build merges:
    metapollo-phosphor -> metapollo-grid

into one Kitty shader group.

No effect parameters were changed.

Expected result:
- same phosphor stripes
- same grid/crosshatch
- same brightness
- same interference/sync
- same living glare
- same NO SIGNAL / wake behavior
- one fewer full-screen group

This is intentionally a test merge because the original phosphor/grid source
files are not being rewritten here. If either shader internally relies on
t.backbuffer rather than only the incoming `color`, the appearance can differ.
That is why the GOLDEN backup was made first.

If the image looks identical, this merge is safe in practice for the current
shader pair and we can keep it.
