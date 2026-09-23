METAPOLLO CRT — PRE-FUSION RESTORE

Restores the last confirmed working state before Source Optimization 5.

Keeps:
- scheduler cleanup
- pass merges 1–3
- source optimizations 1–4

Removes:
- true phosphor+grid source fusion from Source Optimization 5

Reason:
A possible tiny weakening of fine text effects was noticed, so we are treating
that as a regression instead of accepting it.
