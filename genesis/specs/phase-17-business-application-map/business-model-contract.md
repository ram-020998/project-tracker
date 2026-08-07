# Phase 17 — Business Model contract (`BusinessModel v1`)

> **Status:** DRAFT · **Author:** Genesis agent · **Date:** 2026-08-07 · **Part of:** Phase 17 (see the umbrella spec).
> **Purpose.** This is the **implementation source of truth** for Phase 17's derived artifact: the exact JSON shape the
> `generate-business-map` workflow produces, the **evidence-grounding + validation** rules that make it trustworthy, the
> **KB → business** derivation guidance the agent nodes follow, how the two web views (A value stream + B capability
> constellation) render from it, and the **coverage** metric. The workflow (17-03), persistence (17-01), API (17-04),
> validators (17-06), and web (17-05) all conform to this document. It is **versioned** (`schema_version`), starting at **1**.

---

## 1. Design rules

- **Business language only.** Every human-facing string (`summary`, `domain`, names, descriptions, stage/branch labels) is in
  business terms. Technical vocabulary is **banned** (see §4.3).
- **Evidence-grounded.** Every business element carries an `evidence` block listing the **real KB object UUIDs** it was
  inferred from. This is *hidden metadata* (for validation + traceability + the optional "see underlying objects" affordance),
  **never** rendered as primary content.
- **Stable IDs.** Every element has a model-local `id` (`ent-*`, `cap-*`, `act-*`, `vs-*`, `st-*`). Cross-references use these
  ids. IDs are assigned by the composing program node (deterministic), not the agent.
- **Code-free.** No SAIL, no code, no file paths (ADR-037).
- **Compact.** The model is a summary abstraction (target: a few hundred KB of JSON at most), not a re-encoding of the KB.

---

## 2. `BusinessModel v1` — JSON schema (informal)

```jsonc
{
  "schema_version": 1,
  "app_uuid": "…",                 // the tracked application
  "app_name": "…",
  "source_sync_id": 42,            // point-in-time grounding (a kb_syncs.sync_id)
  "generated_at": "2026-08-07T…Z",

  "summary": "One short paragraph, plain business language: what this application does and for whom.",
  "domain": "e.g. Document Management · Lending · Case Management",   // inferred business domain

  "entities": [                    // (B) the business nouns
    {
      "id": "ent-1",
      "name": "Document",          // business name, NOT the record-type object name if that is technical
      "description": "A submitted item that moves through classification and review.",
      "lifecycle": ["Submitted", "In review", "Approved", "Archived"],  // optional; only if inferable
      "evidence": { "object_uuids": ["…"], "object_types": ["Record Type"] }
    }
  ],

  "actors": [                      // who performs the work
    { "id": "act-1", "name": "Reviewer",
      "evidence": { "object_uuids": ["…"], "object_types": ["Group"] } }
  ],

  "capabilities": [                // (B) functional areas (target 4–10)
    {
      "id": "cap-1",
      "name": "Document Intake",
      "description": "How documents enter the system and are captured.",
      "entities": ["ent-1"],       // entity ids this capability works with
      "actors": ["act-1"],         // actor ids
      "evidence": { "object_uuids": ["…"], "bundle_ids": ["…"] }
    }
  ],

  "capability_relations": [        // (B) how capabilities hand off / relate
    { "from": "cap-1", "to": "cap-2", "label": "hands off to" }
  ],

  "value_streams": [               // (A) end-to-end business journeys (usually 1–3)
    {
      "id": "vs-1",
      "name": "Document Approval Journey",
      "description": "From submission to archival.",
      "stages": [
        { "id": "st-1", "name": "Intake",            "kind": "start",
          "description": "A user submits a document.",
          "actor": "act-1", "entities": ["ent-1"], "capability": "cap-1",
          "next": [ { "to": "st-2" } ],
          "evidence": { "object_uuids": ["…"], "object_types": ["Process Model"] } },

        { "id": "st-2", "name": "AI Classification", "kind": "activity",
          "actor": null, "entities": ["ent-1"], "capability": "cap-2",
          "next": [ { "to": "st-3" } ],
          "evidence": { "object_uuids": ["…"], "object_types": ["AI Skill"] } },

        { "id": "st-3", "name": "Review",            "kind": "decision",
          "actor": "act-1", "entities": ["ent-1"], "capability": "cap-3",
          "next": [ { "to": "st-4", "condition": "Approved" },
                    { "to": "st-5", "condition": "Rejected" } ],
          "evidence": { "object_uuids": ["…"] } },

        { "id": "st-4", "name": "Archive", "kind": "end",  "capability": "cap-4",
          "entities": ["ent-1"], "next": [], "evidence": { "object_uuids": ["…"] } },
        { "id": "st-5", "name": "Return to submitter", "kind": "end",
          "capability": "cap-1", "next": [], "evidence": { "object_uuids": ["…"] } }
      ]
    }
  ],

  "coverage": {                    // computed by compose_model (§5), NOT by the agent
    "significant_total": 120,      // entry points + record types + key processes in the KB
    "significant_referenced": 98,  // of those, how many appear in the model's evidence
    "ratio": 0.82,
    "objects_referenced": 240      // distinct evidence UUIDs overall
  }
}
```

**Field rules.** `kind ∈ {start, activity, decision, end}`. A `decision` stage MUST have ≥2 `next` entries each with a
business-worded `condition`; non-decision stages have `condition: null` (or omit). `next[].to` MUST reference a stage `id`
within the same value stream. `capability`/`entities`/`actor` MUST reference ids defined in the model. `evidence.object_uuids`
MUST be non-empty for every element (the one exception: a purely synthetic `end` like "Return to submitter" may reuse an
upstream stage's evidence). All `evidence` fields are optional to *render* but **required to validate**.

---

## 3. KB → business derivation (guidance the agent nodes follow)

The agent is instructed to derive business concepts from KB signals (it may call `genesis-kb` read tools to drill in):

- **Entities ← Record types.** Each significant record type ≈ a business entity. Prefer a business name (a technical/opaque
  record-type name is rewritten to its business meaning). `lifecycle` may be inferred from status/phase fields or from the
  stage names of the processes that write it.
- **Activities/stages ← entry-point processes + record actions.** The `flow_json` **stage names**, **gateway conditions**
  (→ decision branches), and **write targets** (→ which entity a stage acts on) drive the value stream. Multiple technical
  process nodes collapse into one business stage where appropriate (e.g. several script tasks = one "Classify" stage).
- **Capabilities ← cohesive clusters** of activities/entities (guided by bundles, hub objects, and the dependency graph),
  plus **AI skills / integrations / connected systems** as automation/external capabilities. Target 4–10 capabilities;
  fewer, clearer areas beat many thin ones.
- **Actors ← Groups** referenced by user tasks / security.
- **Hand-offs ← dependencies/bundles** that cross capability boundaries.
- **Surfaces (sites/dashboards)** inform *where* work happens but are **not** rendered as pages.

The output must read as a business narrative — never enumerate objects.

---

## 4. Validation rules (enforced by the `v_*` nodes; hardened in 17-06)

### 4.1 Evidence integrity (anti-hallucination) — HARD
Every `evidence.object_uuids` entry MUST resolve to an object that exists in the KB for this app+sync (checked via
`KbStore.get_object` / a batch existence query). Any unknown UUID ⇒ the node **fails** (→ retry with the offending ids in the
feedback → escalate to `review`). The agent cannot introduce objects that aren't in the KB.

### 4.2 Coverage gate — SOFT (lenient floor, default ratio ≥ 0.3 → routes to human review)
`coverage.ratio = significant_referenced / significant_total` (see §5). Coverage is a **lenient "is the map
non-trivial" signal, not a quality score**: a good business map abstracts/consolidates heavily (dozens of record types →
a handful of business entities; many process objects → a few stages), so it legitimately references only a *fraction* of
the app's significant objects. Below the floor the run **routes to the human `review` gate** (the real quality backstop),
it does **not** hard-fail. Default **0.3** (recalibrated from 0.6 after the first live run scored 0.355 for a genuinely
good map — 17-06 §0). Coverage is surfaced in the UI regardless.

### 4.3 Business-language guard — HARD
Human-facing fields (`summary`, `domain`, `*.name`, `*.description`, stage/branch labels) MUST NOT contain banned technical
tokens (case-insensitive, whole-word): `object`, `bundle`, `interface`, `expression rule`, `record type`, `process model`,
`constant`, `integration`, `web api`, `site`, `uuid`, `sail`, or a raw UUID pattern. Violations fail the node.

### 4.4 Structural well-formedness — HARD
JSON-schema valid; unique ids; every cross-reference (`capability`/`entities`/`actor`/`next.to`/`capability_relations.*`)
resolves within the model; each `value_stream` is a well-formed DAG (exactly one logical `start` reachable path to at least
one `end`, no dangling `next`, no cycles unless explicitly modeled as a labeled loop); every `decision` has ≥2 labeled
branches.

### 4.5 Sanity bounds — SOFT (warn, don't fail)
Capabilities 3–12; value streams 1–4; stages per stream ≤ ~25 (keep it readable). Warnings surface to the review gate.

---

## 5. Coverage metric (computed deterministically by `compose_model`)

- **`significant_total`** = count of *significant* current KB objects = entry points (`is_entry_point=1`) + record types +
  processes referenced by any bundle. (Excludes low-signal leaf objects like constants/translations so coverage measures the
  business surface, not noise.)
- **`significant_referenced`** = of those, how many appear in any element's `evidence.object_uuids`.
- **`ratio`** = referenced / total (0..1). **`objects_referenced`** = distinct evidence UUIDs across the whole model.
Coverage is computed by the program node (not the agent) so it can't be gamed, and it gates §4.2 + is shown in the UI.

---

## 6. Diagram mapping (how 17-05 renders the model)

**(A) Value stream** — one React Flow canvas per `value_stream` (or a switcher): `stages` → nodes laid out left-to-right by
dagre following `next`; `kind` picks the node shape/anchor (start ▶, activity ▭, decision ◇, end ⏹); `next[].condition` →
edge labels; each node shows `name`, `actor`, and an `entities` chip. Sub-journey stages are expandable.

**(B) Capability constellation** — one canvas: `domain` at the center; `capabilities` as clustered nodes around it;
`entities` as linked satellite nodes; `capability_relations` as labeled edges.

**Linking/brushing** — one shared selection across A+B (keyed by `capability` id): selecting a capability highlights its
stages in A and dims the rest (focus+context); selecting a stage highlights its capability in B. Business-styled node
components (new; not the technical `NodeCard`), design tokens per ADR-027.

---

## 7. Versioning

`schema_version` starts at **1**. Additive fields keep v1; a breaking change bumps the version and the persisted
`kb_business_maps.schema_version`, and the web renders known versions (unknown → "regenerate"). The contract mirrors the
Phase-16 discipline of a stable, documented shape that producers (workflow), storage (KbStore), and consumers (API/web) all
agree on.
