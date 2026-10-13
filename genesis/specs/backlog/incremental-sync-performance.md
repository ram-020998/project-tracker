# Backlog — Faster incremental sync: stop re-adding every bundle root to each delta package

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-10-13 (Phase 45-09 live-acceptance finding **F4**). ·
> Depends on Phase 45 (ADR-073/074, `genesis-appian-parser` ≥ 0.3.0, sync-application ≥ 0.3.0).

## The problem

An incremental sync should be much cheaper than a full one. In the 45-09 live acceptance it was **slower**:

| Run (AS GSS, 2,782 objects) | Build/export step | Total |
|---|---|---|
| Full sync `r-92dec4e88b48` | `export_package` **103 s** | 120 s |
| Incremental, 1 changed object `r-ec32f9f56f1e` | `build_delta_package` **182 s** | 200 s |

Measured inside `build_delta_package` (temporary package, 220 objects):

| Step | Time |
|---|---|
| `createPackage` | 2.6 s |
| `addPackageObjects`, 5 batches (50, 50, 50, 50, 20) | **31 + 55 + 31 + 21 + 16 = 154 s** (≈ 0.3–1.1 s per object) |
| Deployment REST export of the package (1.2 MB) | 29 s |

The cost is the **~220 `delta_roots`** (every process model, site, web API, record type with actions/views,
label-bundle document, entry point) that the package always contains — not the changed objects. `addPackageObjects`
is slow per object on the Appian side, so the cost grows with the number of roots, not with how much changed.

Why the roots are there (45-03 §6): an incremental parse rebuilds **every** bundle from its root. A bundle's root
and flow (process-model nodes, record actions/views, label documents) need content that the code-free KB stub does
not hold, so the root's XML must be in the package.

## Proposed fix — only the roots of affected bundles

1. **Affected roots only.** For the changed set `C`, add only the roots of bundles that contain a changed object
   (the KB already stores bundle membership — `kb_bundles` + `kb_bundle_members`), plus any changed object that is itself a root,
   plus the label documents those roots use. Typical change sets touch a handful of bundles, not 220.
2. **Let the parser keep the rest.** The incremental parser already reports bundles it could not rebuild in
   `stats.incremental.skipped_entry_points`, and `KbStore._apply_incremental(keep_unrebuilt=True)` keeps their
   existing rows. Bundles with no changed member are unchanged by definition — keeping them is correct.
3. **Derived fields stay whole-app.** `inbound_count` / `outbound_count` / `is_hub` / `is_bundled` / `is_orphan` are
   computed from the known edges + the package objects' new edges (45-03); unaffected by which roots are present.
4. **New bundles.** A changed object that newly becomes reachable from a root it wasn't in before is the edge case:
   its new parent appears as a changed object (the parent's code changed to reference it) → the parent's bundle is
   affected → its root is included. A brand-new root is a changed object → included.
5. **Fallback.** If the affected-root set exceeds a threshold (e.g. 100), keep today's behaviour (all roots) or fall
   back to a full sync — whichever measures faster.

## Verification (required before shipping)

- Extend the 45-03 **equivalence oracle**: for random change sets on the vendored fixture AND the real AS GSS export,
  "affected roots only" must produce bundles / edges / derived fields identical to a full parse (today's oracle uses
  all roots).
- Add a parser API helper, e.g. `affected_roots(known_objects, known_bundles, changed_uuids)`, next to
  `delta_roots`, so the rule lives in one tested place.
- Live: re-run the 45-09 step 5 (one edited constant) and record `build_delta_package` time — target well under the
  full export (≈ 10–30 s for a handful of roots).

## Alternatives considered

- **A long-lived "roots" package** that is kept between runs (add roots once, export it + a small changed-objects
  package). Rejected for now: it leaves a permanent Genesis-owned package in the customer's app and complicates the
  ADR-073 "temporary, always deleted" guarantee.
- **Bigger `addPackageObjects` batches.** The server caps request size and the cost appears to be per object, so this
  would not change the total much (to confirm when implementing).
- **Exporting the changed objects by UUID list directly** (no package). The Deployment REST export accepts
  application or package UUIDs only (16-07 / 45-01), so a package is required.
