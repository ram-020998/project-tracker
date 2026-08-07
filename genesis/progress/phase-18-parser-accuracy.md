# Phase 18 — Appian Parser Accuracy Overhaul — as-built progress

> As-built record for Phase 18 (see `specs/phase-18-parser-accuracy.md`). Newest first.

## Summary

`genesis-appian-parser` was catastrophically **under-linking** dependencies — on a real 2,620-object package it
reported **804 orphans (30.7% of all objects), 803 of them provably false** (objects genuinely referenced by other
objects). Root cause: dependency extraction was **field-path-scoped** (no entries for Constants, AI Skills, Decisions,
Translation Strings, Documents) and "orphan" meant *"not in an entry-point bundle"* rather than *"unreferenced"*. This
phase reverified extraction against real XML + the original **Atlas** parser and the **Jarvis** plugin (best-of-both),
and drove accuracy **>95%**, verified by a committed raw-XML reference oracle.

## Result (2,620-object fixture; live-validated on the user's real app 2026-08-07)

| Metric | Baseline | Final | Target |
|---|---|---|---|
| Edge recall (relationships found) | 0.324 | **0.978** | ≥0.95 ✅ |
| Edge precision | ~artifact | **0.999** | ≥0.95 ✅ |
| Referenced-object recall | 0.869 | **1.000** | ≥0.95 ✅ |
| Orphans | 804 (803 false) | **0** | — |
| False-orphan rate | 0.311 | **0.000** | ≤0.05 ✅ |
| Dependency edges | 5,084 | **10,617** | — |
| Integration points classified | 0 | **12** | — |

Parser test suite 13 → **25** green; ruff clean; code-free (ADR-037) no-SAIL guards intact.

## Sub-phases (all on `genesis-appian-parser` main; **release/tag = 18-06, pending**)

| Sub-phase | What | Commit |
|---|---|---|
| 18-01 | Accuracy harness + raw-XML reference **oracle** + baseline lock (measurement backbone) | `afcb66d` |
| 18-02 | **Edge recall**: analyze on RAW data + universal known-UUID scan over every string; record-action + translation-string URNs; `USES_TRANSLATION`/`USES_DOCUMENT`/`USES_AI_SKILL`; `rulereferencebyname` by-name; `_v<N>` normalization | `31567fa` |
| 18-03 | **Orphan semantics**: Atlas inbound/outbound + `is_hub` graph model; `is_orphan` = disconnected (no incoming AND no outgoing), not "unbundled" | `a357db6` |
| 18-04 | **APPREF/ENTRYPOINT integration points**: Jarvis regexes + 10-category taxonomy + behavioral detection; Atlas app-level cross-app map (entry_points/app_references/shared_library_usage); orphan-exempt; `integration_*` metadata | `c86b20c` |
| 18-05 | CDT **QName** refs (`{urn:…}Type`); **raw-XML reference scan** (transient, code-free) → recall >95%; oracle hardening (filename-stem attribution, specific-id resolution, base only when unique); **≥95% CI gate** | `44472c4` |

## Best of both worlds (Atlas ⋈ Jarvis)

Discovered our front-half port **dropped three Atlas layers** (`app_cross_app_builder.py`, `graph_builder.py`, the
`enrichment/` package). Adopted: **Jarvis** for object-level integration classification (by-name `RULENAME_PATTERN` +
category taxonomy) + system-rule set; **Atlas** for the app-level cross-app map + shared-library aggregation + the
inbound/outbound graph model; **ours** for the universal known-UUID scan (neither reference did this) + the corrected
orphan definition. Full decision matrix in the spec §9.

## Key lessons (also in AGENT_ONBOARDING §7)
- Field-path-scoped reference extraction silently misses whole object types → **scan every string + the raw XML** for
  known-UUID / URN / QName / by-name references (known-UUID-gated to protect precision).
- **Orphan = disconnected (no edges)**, not "not reachable from an entry-point bundle" — the latter mislabels
  used-but-unbundled objects.
- A prefixed Appian id `_a-<base>_<suffix>` shares its **base** with folder-siblings → **base is a group id, not an
  object id**; never resolve a reference by base alone (over-links to an arbitrary sibling).
- APPREF/ENTRYPOINT is a **by-name** cross-app mechanism (`rulereferencebyname(ruleName:"…")`), invisible to UUID scans;
  classify + exempt from orphans.
- You cannot claim "N% accurate" without a **parser-independent oracle**; attribute each file to its object by
  **filename stem** (universal), not the in-XML `<uuid>` (which varies by type).

## Remaining
- **18-06** (pending): release `genesis-appian-parser` v0.2.0 → repin `genesis` + `sync-application` → docs finalize.
- Deferred (need a package containing those types to build/validate): a **Tempo Report** parser + a **generic-haul
  fallback** (Jarvis has both); richer per-type golden fixtures; Jarvis `orphanCluster` + `TagDetector` behavioral tags
  (a Business-Map capability signal).
