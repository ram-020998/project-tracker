# Phase 17-02 — Business Evidence Pack extractor

> **Status:** DRAFT · **Repos:** genesis · **Depends on:** 16-02 (`KbStore` reads)
> **Goal:** Build the deterministic, pure, **capped** function that turns the (potentially multi-thousand-object) KB into a
> compact **Business Evidence Pack** — the *only* input the agent nodes (17-03) see. This is what keeps generation grounded,
> cheap, and inside the context window. No agent here — pure data shaping + tests against the real synced app.

---

## 1. Current state (grounded)
- `KbStore` exposes `get_app_overview` (object_counts, coverage, dependency_summary incl. `most_depended_on` = hubs, bundles),
  `search_objects`/`get_object` (type, description, entry-point flags, calls/called_by, bundles),
  `get_bundle` (returns `entry_point` + verbatim **`flow`** = process graph with stage `name`/`type`/`next`/gateway
  conditions/writes/subprocess/interface), `get_hub_objects`, `get_entry_points_for_object`, `get_dependencies`.
- A real synced app (`AiDocumentCenter`, ~2,516 objects) is available to test against; the full object set must **not** be
  dumped into the pack (context blow-up + noise).

## 2. Design
A new pure module `genesis/kb/business.py` (or `KbStore.build_evidence_pack(app, *, sync_id=None) -> dict`) assembles:
- **entities** ← record types: `{uuid, name, description}` (+ candidate lifecycle/state field names if cheaply detectable).
- **activities** ← entry-point process models + record actions: `{uuid, name, entry_point_kind, stages:[flow stage names],
  branches:[gateway condition labels], writes:[entity/target names], calls_out:[key targets]}` — pulled from each entry
  point's `get_bundle().flow` (process_model + subprocesses), **summarized** (stage names + branch labels + write targets
  only — not the full node payload).
- **surfaces** ← sites/dashboards/control panels: `{uuid, name, kind}` (context; not rendered as pages).
- **capability_signals** ← AI skills, integrations, connected systems: `{uuid, name, type}`.
- **actors** ← groups: `{uuid, name}`.
- **structure** ← hub objects (top `most_depended_on`), bundles-by-type counts, object-type counts, `significant_total`
  (entry points + record types + bundle-referenced processes — the coverage denominator, computed here for reuse).
- **meta** ← `{app_uuid, app_name, source_sync_id, generated_from: "kb"}`.

**Capping/summarization rules (deterministic):** cap each list to a configurable max (e.g. entities ≤ 60, activities ≤ 80,
signals ≤ 40) ranked by significance (entry points first, then by inbound-dependency count / bundle membership); always
include every entry point + record type up to the cap; drop low-signal leaf types (constants, translations, folders) from the
pack entirely. Emit `truncated: {…}` counts so the agent (and coverage) know what was omitted. Target pack size: comfortably
within the agent context budget for a 5-6k-object app.

**Purity:** no network, no agent, no code — reads `kb_*` only; returns a plain dict; deterministic for a given sync.

## 3. Definition of Done
- `build_evidence_pack` runs against the real synced `AiDocumentCenter` and returns a pack with ≥1 entity + ≥1 activity,
  within the size cap, with `significant_total` populated and `truncated` counts correct.
- Unit tests over a fixture KB assert: correct entity/activity/actor extraction; flow **stage names + branch labels** are
  captured (not raw node payloads); caps + ranking applied; low-signal types excluded; determinism (same sync → same pack).
- Pure/offline (no MCP, no env). `ruff` clean; genesis pytest green. Consumed by 17-03's `extract_evidence` program node.
