# 31-01 — Findings (skill methodology + GSS example structure + reuse surface)

> Captured 2026-09-04 from the `spec-to-backlog` skill (cloned), the four GSS example breakdowns, and a
> code audit. This is the format/methodology ground truth for the phase.

## A. The `spec-to-backlog` skill — what we keep vs drop

**Architecture:** two-phase — **analysis** (spec → an intermediate `Backlog_JSON` at
`output/<feature>-backlog.json`) then **rendering** (`Backlog_JSON` → Lucid / Google Sheets / Jira). The JSON
decouples analysis from rendering. **We reuse ONLY the analysis methodology + the JSON contract + the Jira
column mapping; we write our own deterministic HTML + CSV renderer.**

**KEEP — the `Backlog_JSON` contract (Full-Breakdown depth):**
```jsonc
{ "metadata": { "featureName", "analysisDepth", "sourceSpec", "generatedAt", "renderedOutputs":[] },
  "epics": [ { "id":"epic-1", "title", "description",
    "stories": [ { "id":"story-1-1", "title", "category":"core|nice-to-have",
      "labels":["ux-mockup-needed","AutomationCandidate"],
      "description":"As a…/I want…/So that…", "acceptanceCriteria":[…], "notes", "questions" } ] } ] }
```
(Story-Map depth = epics + `{id,title,category,notes}` only — a lightweight starting point. We go straight to
Full-Breakdown depth, extended with Appian fields — see §D.)

**KEEP — Appian-native story-breakdown best-practices:** action-oriented titles; **split by entry
point/interface**; separate happy-path vs error; explicit **edge-case** stories; break by **state/status**;
integration points as own stories; **config/setup** stories; **operational** concerns (queuing, guardrails,
tracking); group **notifications**; flag **nice-to-haves** (future/phase-2). **Clarity over volume** — don't
split just to split; prefer fewer meatier stories a dev can deliver end-to-end.

**KEEP — story writing:** `As a [role] / I want [action] / So that [benefit]` (personas from the spec); AC
testable + user-observable (no HOW/implementation detail in AC); INVEST; epic description = combine children's
"I want to"s. Appian terminology (Record Type, Interface, Process Model, Site, Record Action, Expression Rule,
Connected System, Web API, Smart Service, …).

**KEEP — readiness categories** (fold into the verify critic, not a separate stage): Personas & Use Cases;
Scope Boundaries; Build Considerations/Components; UX & Interaction; NFRs; Open Questions & Risks. Appian-aware
(don't flag "no DB schema" — that's Record Types/Data Sync).

**KEEP — Jira column contract** (`backlog-to-sheets.md` "Full Breakdown" tab = the Jira-importable sheet):
`Issue ID · Summary · Issue Type · Description · Parent ID · Acceptance Criteria · Labels` (+ optional
Group/Team/Product-Owner/Work-Category we DROP). Hierarchy: sequential integer **Issue ID**; a story's
**Parent ID** = its epic's Issue ID. Issue Type ∈ Epic/Story (+ Task for us). This is the classic Jira
CSV/External-System import mechanism.

**DROP:** the Lucid renderer, the Google-Sheets renderer, the **Jira REST importer** (`backlog-to-jira.py` —
ADF + custom-field IDs; Genesis produces the importable *file*, the human imports it), `gws`/Lucid input
fetching, `team_profile.md`/`style_reference.md`/`collect-backlog-examples` (single-user Genesis grounds on
the 3 stage artifacts + KB, not Jira style), and the two-depth "story map first" round-trip.

## B. GSS example breakdowns — the real Appian structure

Source: `/Users/ramaswamy.u/Documents/GSS/breakdown-examples` (GSS 2.0 / 2.2 / 2.6 / 2.7 PDFs + a 2.7 CSV).
Columns converge on: **Epic/Parent · Story Title · Description · Acceptance Criteria · Questions · Dev Note ·
Points · Story/Issue Type · Label** (the rest — Group/Team/Fix Version/Sprint/Assignee/Tester/PO — is
Jira-import plumbing, dropped).

Key confirmations:
- **Form vs process-model split (user's heads-up, confirmed in GSS 2.0):** "Create Evaluation Set Up **Form**"
  is one story; "Create Evaluation **Process** Changes and Confirmation Screen" is a *separate* story. Form
  sections (Details/Personnel/Settings) are listed as scope inside the form story; split by section only when
  complex.
- **Entry-point splitting (GSS 2.7 "Instrument Type"):** one new field → Create / Update / Duplicate /
  Create-from-AM / Display-in-Summary = 5+ stories.
- **Acceptance Criteria = Gherkin** (Given/When/Then, `AC1/AC2…`) in the newest sheet (2.7) — chosen as our AC
  style. Older sheets used `#`-scope bullets; the skill used "* Verify…".
- **Dev Note** is a first-class column with Appian implementation hints ("driven by recordType not CDT",
  "insert into evaluation table", "audit entry", "backfill scripts"). **We DON'T rewrite this** — a story's
  Dev Note is a **one-line pointer into the Technical Design** (the TD already holds the object-level detail).
- **Story vs Task (per the user):** Task = a technical/backend change a tester **cannot validate from the
  front end** (data-model, APPREF/entry-point config, process-only backend logic); Story = a front-end-testable
  item. Tasks may carry no Gherkin AC. (GSS marks "Data Model Changes", "Create Appref" as Tasks.)
- **No story points** (the sheets have a Points column; the user chose to omit AI estimation).

## C. Reuse surface (code audit)

- **m0015 `StageStore`** (`genesis/kb/stages.py`) is per-`(feature,stage)`; a `feature_breakdown` stage needs
  no migration (`current_version` stays 15).
- **`web/src/features/features/stages.ts`** already reserves the `breakdown` stage
  (`artifactKind:"feature_breakdown"`, `available:false`); `deriveAvailability` (Phase 30) supports
  `requires`. Going live = flip + a `deriveStatus` + a `breakdown` registry entry + `requires:["spec","ux",
  "technical_design"]` — no shell edits.
- **`technical-design-analysis/graph.py` (v0.2.0)** = the skeleton to clone: program plan/loop/persist, agent
  reliability trio, per-item **map loop** with retry-reset, **deterministic assemble**, grounded `verify`
  critic (bounded → escalate), `cleanup`, read-only `@genesis-kb`/`@appian-dev` allowlists, fail-fast
  `resolve_inputs`, `recursion_limit 300`.
- **`genesis/chat/stage_finalizer.py`** is already a workflow→stage **`_BINDINGS` registry** (Phase 30) — add
  one `_Binding("feature-breakdown-analysis" → stage feature_breakdown, artifact breakdown.html, mode
  feature_breakdown, seed _seed_fb)`.
- **`genesis/chat/mode_profile.py`** — `feature_breakdown` = a near-clone of `technical_design` with
  `_STEERING_FB`.
- **`genesis/api/features.py`** — `_launch_td` (JSON start + comment), `_launch_analysis` (multipart file,
  `files=`), `export.md`, `_td_prereqs_ready`, `_STAGE_ARTIFACT_FILE`, `_current_stage_html` are the patterns;
  add `_launch_breakdown` (multipart notes + ≤3 files), `_fb_prereqs_ready` (three prerequisites), and the
  `export.csv` route.
- **ADR-035** (`runs/manager.py`): `MAX_UPLOAD_BYTES=25MB`, `ALLOWED_UPLOAD_EXTS={.txt,.md,.html,.htm,.csv,
  .png,.jpg,.jpeg,.pdf}`; `files={name:(filename,data)}` → provisioned into the blackboard.
- **`openpyxl` is already pinned** (Phase 19) — the export needs no new dependency.

## D. Locked backlog schema (Appian-extended) + HTML/export decisions

Backlog JSON = the skill's Full-Breakdown contract **plus** `storyType` (Story|Task), `appianPart`
(form|process-model|data-model|integration|config|ui|none), `devNoteRef` (a one-line TD-workstream pointer),
`acceptanceCriteria` in **Gherkin**; **no** points. Epics carry `workstreamRef` (the 1:1 TD workstream).

HTML (`breakdown.html`): deterministically rendered; summary header + `<details>` story cards grouped by epic +
a **CSS-only** card↔table toggle (no JS — Lavish-safe); the canonical JSON embedded in
`<script type="application/json" id="genesis-backlog">`. Export (`export.csv`): from the embedded JSON, the
skill's `Issue ID · Issue Type · Summary · Description · Parent ID · Acceptance Criteria · Labels` contract,
create-new-epics via Issue ID → Parent ID, no custom-field columns.
