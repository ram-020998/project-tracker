# archive — verbatim history, never mandatory

This directory holds Genesis history **moved here verbatim** during the Phase 47 migration
(47-04): the `tracker.md` §6 status log, the shipped-phase blocks of `bible/08`, old
`AGENT_ONBOARDING.md` banners, and the superseded onboarding/current-state bibles.

**Nothing here is part of the mandatory read set.** It exists so no paragraph is lost
(the move is proven lossless by `genesis-ctx verify-lossless`, recorded in `LOSSLESS.json`).

**Search, don't read whole.** These files are large. Look things up with
`genesis-ctx search <regex> --archive` (or a ranged read of a specific hit), never a
whole-file read. The `PreToolUse` bulk-read guard blocks whole-file reads of `archive/**`.

Files appear here only in 47-04; at the end of 47-02 this directory contains just this README.
