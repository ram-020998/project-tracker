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

## 5. As run (2026-10-13) — live acceptance on merge-assist-dev (fleet main :8760 + userb :8761)

| Step | Result |
|---|---|
| 1 | `gsm provision --all --no-mcp --no-env --force` + `gsm restart --all` → both instances: sync-application **0.3.0**, devmcp match `e84174719e61709c`, healthy |
| 2–3 | Refresh `r-3b44a846e006` → **full** ("kb built by an older parser") 140 s: 2,763/18,044/222 → **2,782/18,161/226**, Hub KB **v1**. Refresh `r-342427ca023f` → **empty** incremental in 10 s. `listPackages` → **0** |
| 4 | Full sync `r-92dec4e88b48` → full, 120 s, 0 removed, Hub **v2**; userb hydrated (diff: +0 ~1) |
| 5 | After the user edited `AS_GSS_API_RESPONSE_STATUS_CODE_400` (description): Refresh `r-ec32f9f56f1e` → **incremental**, changed_count **1**, package `genesis-delta-20261013T082654Z` (1 changed + 220 roots) **deleted**, KB +0 ~1 −0 (exactly that constant: closed + reopened with the new description), counts unchanged 2,782/18,161/226, Hub **v3**; userb hydrated it within ~25 s |
| 6 | Hourly window on main (designated) → ran once per app: AS GSS empty incremental; RU Sandbox **failed** (see F3). userb → "skipped: … not designated". main reset to every 4 h, designated |
| 7 | Refresh `r-2d9d1ef21011`; worker killed (pause) at t+14 s while `genesis-delta-20261013T082607Z` existed → run cancelled → leftover present → `sweep_leftovers` (60 min default) left it (too young, by design) → `sweep_leftovers(older_than_minutes=0)` deleted it → `listPackages` **0**. The covered_until watermark did not advance (step 5 then saw the change) |
| 8 | Active Dev MCP version dir renamed → `/config/devmcp/version`, `dev/check?live=true` and the package client all report "No such file or directory: …/.venv/bin/python"; restored → match again |

**Findings**
- **F1 (fixed, genesis `0867f49`):** the live Genesis Hub appends **no `blob` change rows** on a KB publish (contract §3.6
  says it should; the corrected LocalHubProvider emits them). The change-gated auto-pull therefore never saw main's
  publish. Fix: the auto-pull also polls every tracked app's latest KB blob version once per `KB_POLL_SECONDS` (60 s).
  After the fix userb hydrated each of v1/v2/v3 within ~20–25 s.
- **F2 (parser, follow-up):** a Decision (`AS_GSS_DecideActionBasedOnVendorProposalUpdate`) gets a new `diff_hash`
  on every export: Appian embeds a fresh `versionKey` in its generated `a!decisiondesigner_cache(...)` definition.
  Harmless (one extra SCD-2 version per full sync / whenever it is in a package); fix = exclude/normalize the
  `versionKey` in the parser's Decision hash.
- **F3 (data):** tracked app **RU Sandbox** (`d3b81e2e…`) no longer exists in the env (export 404; absent from
  `listApplications`) → the scheduled job reports `partial`. Untracking (deletes its local KB) awaits the user.
- **F4 (performance — design follow-up):** the incremental build took **182 s** vs **103 s** for a full export.
  Measured: `addPackageObjects` is slow — **~0.3–1.1 s per object** (five batches: 31, 55, 31, 21, 16 s for 220
  objects); the package export itself is 29 s. The cost is dominated by the ~220 `delta_roots` re-added every run
  (D-design from 45-03), not by the changes. Options: only add the roots of bundles that contain a changed object
  (the parser already keeps un-rebuilt bundles via `skipped_entry_points`, so this needs an oracle check), or cache
  a long-lived roots package. Correctness is unaffected.
