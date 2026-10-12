# 45-09 — Review, hardening & live acceptance

> **Status:** 🟡 DRAFTED. Repos: all. Parent: `specs/phase-45-incremental-delta-sync.md`.

## 1. Independent review (sub-agent)

Focus areas: the **environment-write boundary** (no agent/chat can reach package tools; delete guard; leftover sweep;
`finally` cleanup), **KB integrity** (incremental merge never removes; edges only for package sources; derived
fields; snapshot determinism), scheduler correctness (slot expansion, `user_modified`), collaboration (no
self-re-pull, no hydrate during a local sync), error mapping (version mismatch / auth), and the §7 lessons
(off-event-loop writes, stubs mirroring real shapes, every file staged).

## 2. Gates

genesis-appian-parser pytest + the equivalence oracle; genesis pytest + ruff + fresh DB → v23; web tsc + eslint (0) +
vitest + build (`web/static` committed); genesis-workflows `validate_library` + pytest.

## 3. Live acceptance (merge-assist-dev, AS GSS + RU Sandbox)

1. 26.6.110 installed on the host; both fleet instances report matching shas.
2. Manual **Refresh** on AS GSS → `incremental`; report shows changed objects, `genesis-delta-*` package deleted
   (`listPackages` → 0).
3. KB check: current objects/edges not reduced; changed objects at their new version; bundles count stable.
4. **Full sync** action → `full`; deletions applied; next scheduled run is `incremental`.
5. Make a small edit in the env (e.g. a test constant), Refresh → exactly that object changes.
6. Schedule: set an `every_hours` window that includes now, enable on `main`, observe one run per app;
   `userb` skips; `userb` KB hydrates via auto-pull within ~10 s of `main`'s publish.
7. Kill the worker mid-run (between create and delete) → next run's sweep deletes the leftover package.
8. Manually corrupt the bundle path (rename the MCP version dir) → clear error; restore.

## 4. Exit

All gates green, review = SHIP, acceptance steps evidenced (run ids, counts, `listPackages`).
