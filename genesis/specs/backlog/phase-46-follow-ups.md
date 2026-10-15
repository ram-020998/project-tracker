# Backlog — Phase 46 follow-ups (recorded 2026-10-15 at the v0.77.0 release)

Not scheduled; do not start without the user's go-ahead. Evidence: `specs/phase-46-spec-change-requests/46-10-review-and-acceptance.md` §4.

1. **Finalize Stories doesn't publish the backlog (F1, pre-existing since 38-04).** `usePublishBacklog` has no caller;
   wire Finalize → `POST /collab/publish/backlog/{id}` (or publish server-side in the finalize route, like Apply), with a test
   on the trigger.
2. **A cancelled run is reported `failed` (F3, pre-existing).** Cancelling writes `run.final cancelled`, then the worker's
   abnormal exit appends `error` + `run.final failed`; the supervisor should keep the user's `cancelled`.
3. **Leftover Hub validation rows pin the `stage_artifact` / `story` pull cursors (F4).** `bafef139…` (GH Stage Artifact
   id 5, the old `stage_artifact.json` fixture) and GH Story id 120 have parents no instance has, so every pull replays
   every change since cursor 459. Harmless since genesis `0e371de`, but wasteful: delete them via the Appian agent (with
   the user's OK), and consider advancing a cursor past a record that has been unresolvable for N pulls.
4. **Hub-wide date-looking text conversion.** `a!fromJson` converts any text whose whole value looks like a date or
   date-time on every kind except the CR's title / `opened_at` / `closed_at` (e.g. a story titled `2026-10-14` reads back
   `10/14/2026`). Fix recorded in `progress/phase-36-genesis-hub-appian-app.md` (route every text field through
   `GH_payloadText` with `rawBody`); touches every kind → its own approval + regression run.
5. **Security: `GH_isServiceCaller` returns `true()`** — any authenticated Appian user can call the Hub write APIs.
   Restore the group check after adding the account Genesis uses to `GH Service Accounts` (the user's call).
6. **Hub writes no blob change rows** (known, ADR-074) — the KB auto-pull polls instead; contract §3.6 still says it should.
7. **Live acceptance step 13 not run** — a backlog-mode CR (breakdown completed, not finalized) on a live feature.
8. Cosmetic: the pull's `applied` lists include already-held versions (F5).
