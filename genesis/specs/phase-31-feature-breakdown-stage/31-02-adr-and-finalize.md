# 31-02 — ADR & finalize (lock the design; draft ADR-059)

> **Status:** ✅ DONE (2026-09-04) — design locked with the user; ADR-059 drafted (Proposed) in `reference/decision-log.md` + `bible/04`. · Part of Phase 31. **Docs only.** Gate: ⭐ user sign-off → build (given 2026-09-04).

## Purpose

Turn the 31-01 findings into a locked, buildable design and record **ADR-059**. Everything below is a firm
input to 31-03/31-04/31-05.

## Locked design (finalized with the user)

### A. Workflow node graph (`feature-breakdown-analysis`)

`resolve_inputs → load_inputs → plan_epics →[v_epics]→ start_breakdown → next_epic
  →(break) break_epic →[v_stories]→ advance_epic → next_epic
  └─(all done)→ assemble →[v_backlog]→ verify →[v_verify]→ route_verify
route_verify →(ok) present → cleanup → END
route_verify →(revise, bounded MAX_VERIFY_ROUNDS=2) break_epic (flagged epics) ; →(exhausted) escalate → cleanup → END`

- Program: `resolve_inputs` (3 required artifact paths + optional notes + ≤3 doc paths; dev-env + KB-sync
  fail-fast), `load_inputs` (spec.txt/ux.txt/technical-design.txt/notes.txt + attachments/*), `start_breakdown`
  (seed the epic queue from `epics.json`), `next_epic`/`advance_epic` (map cursor, retry-reset per epic),
  `assemble` (**deterministic**: build `backlog.json` + render `breakdown.html`), `route_verify` (verdict +
  retry-reset + round bump), `present` (register artifact → in-review), `cleanup` (delete tool-output scratch,
  keep artifacts — both terminal paths).
- Agents (reliability trio each): `plan_epics` (mcp=[]), `break_epic` (read-only `@genesis-kb`+`@appian-dev`
  for a **light** spot-check only — the TD is already grounded), `verify` (grounded critic, `@genesis-kb`+
  `@appian-dev`). **`assemble` is a PROGRAM node** (structured JSON → HTML is mechanical — no giant-emission
  agent turn; the Phase-30 timeout lesson made even cleaner here).
- `MAX_EPICS ≈ 15`; `recursion_limit 300`; `required_mcp: ["genesis-kb","appian-dev"]` (read-only).

### B. Backlog JSON schema (canonical artifact — Appian-extended Full-Breakdown)

```jsonc
{ "metadata": { "featureName", "generatedAt", "sources": ["spec","ux","technical_design","<uploads…>"] },
  "epics": [ { "id":"epic-1", "title", "workstreamRef", "description",
    "stories": [ {
      "id":"story-1-1", "title",                       // action-oriented, Appian-termed
      "storyType": "Story | Task",                     // Story = FE-testable; Task = not FE-verifiable
      "category": "core | nice-to-have",
      "appianPart": "form | process-model | data-model | integration | config | ui | none",
      "description": "As a …\nI want …\nSo that …",
      "acceptanceCriteria": ["Given …\nWhen …\nThen …"],   // GHERKIN; [] allowed for Tasks
      "devNoteRef": "See Technical Design → '<workstream>'",  // ONE-LINE TD pointer, not a rewrite
      "questions": ["open question"],
      "labels": ["nice-to-have","ux-mockup-needed","AutomationCandidate"] } ] } ] }
```

### C. Validators (deterministic)

- `check_epics` — non-empty array; each `{id,title}` set; `workstreamRef` present.
- `check_stories` — per epic: non-empty; each story has a title + `storyType∈{Story,Task}` + a description;
  **every Story has ≥1 acceptanceCriterion** and each AC parses as **Given/When/Then**; a Task's AC may be
  empty; `devNoteRef` references a known epic workstream.
- `check_backlog` — the assembled `backlog.json` is schema-valid, epic/story ids unique + sequential; every TD
  workstream is represented by ≥1 epic.
- `check_html` — `breakdown.html` is one well-formed document, contains the summary header + a card section
  per epic + the embedded `<script id="genesis-backlog">` JSON that round-trips to `backlog.json`.
- `check_verify` — critic verdict shape `{ok:bool, fixes:[…]}`.

### D. HTML template (`breakdown.html`) — reader-first, Lavish-safe

Summary header (counts + core/nice + story/task split) → **expandable story cards grouped by epic**
(`<details>/<summary>`) → a **CSS-only card↔table toggle** (hidden checkbox + sibling selectors; **no JS**) →
the embedded canonical JSON. Deterministically rendered by `assemble`. Validated against Lavish's golden
postMessage fixture in 31-06.

### E. Prerequisite gating (three-way)

`requires: ["spec","ux","technical_design"]` — frontend `deriveAvailability` (locked card + blocked
workspace) AND backend `_fb_prereqs_ready` (start 409) + `resolve_inputs` fail-fast. Extends the ADR-056
prerequisite amendment (Phase 30).

### F. Entry (multipart start) + re-run

`POST /features/{id}/stages/feature_breakdown/start` — multipart `notes` (optional) + `files[]` (≤3, optional,
current allowlist). `/rerun` = reset → relaunch. Uploaded docs provisioned into the blackboard (ADR-035,
`files={"doc1":…,"doc2":…,"doc3":…}`).

### G. Export contract

`GET /features/{id}/stages/feature_breakdown/export.csv` (31-05) — from the embedded canonical JSON, columns
`Issue ID · Issue Type · Summary · Description · Parent ID · Acceptance Criteria · Labels`; create-new-epics
via Issue ID → Parent ID; no custom-field columns; `openpyxl`/`csv`.

## ADR-059 (drafted, Proposed)

The full ADR-059 statement is in the umbrella §10 and mirrored into `reference/decision-log.md` + `bible/04`.
Status **Proposed** until 31-07 release.

## Gate

⭐ User sign-off on this locked design → 31-03 build. (Given 2026-09-04.)
