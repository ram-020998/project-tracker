# Phase 31 — Feature Breakdown Stage (Spec + UX + Technical Design → grounded, Jira-ready backlog)

> **Status:** ✅ **SHIPPED — PHASE 31 COMPLETE (2026-09-04).** genesis v0.59.0 + genesis-workflows v0.15.0, CI green (genesis #6735324 / workflows #6735326). ADR-059 **Accepted**. As-built: `progress/phase-31-feature-breakdown-stage.md`. Umbrella + `phase-31-feature-breakdown-stage/31-01..31-07`. · **Author:** Genesis agent
> **Type:** multi-repo — **genesis** (backend + web; no migration — reuses m0015) + **genesis-workflows** (new workflow). genesis-core / kiro-agent-sdk / genesis-appian-parser **unchanged**. · **Depends on:** Phase 30 (the Technical Design stage — its object-level, code-grounded artifact is this stage's primary structural input; the generalized `StageFinalizer` workflow→stage binding registry; ADR-058 + the ADR-056 prerequisite amendment), Phase 29 (the generalized per-stage artifact model m0015, `StageArtifactWorkspace`/`AnnotatablePreviewDialog`/`StageBuilderPage`, the run→stage bridge), Phase 28 (the Feature Workspace framework; ADR-056), Phase 20/21 (Features & Specs + the annotatable chat authoring; ADR-042/043/044/045), Phase 25-01 (`LifecycleService`/`domain/`; ADR-050), Phase 19 (`openpyxl` doc-parsing dep — reused for the export; ADR-035 run-launch file attachments), Phase 16 (`genesis-kb` + the managed-native `appian-dev` MCP; ADR-036/037/038).

---

## 1. Why this phase exists

Phase 28 framed a Feature as **parallel, plug-in stage containers**; Phase 29 made **UX Design** the first
live one after Spec; Phase 30 made **Technical Design** live (the first stage that *depends on* its
predecessors). **This phase makes the fourth and final stage live: Feature Breakdown** — turning the finished
design artifacts into the **developer-executable backlog** (epics + stories/tasks) a team grooms and imports
into Jira.

In the real SDLC, once a **Spec** (what to build), a **UX Design** (how it looks/behaves), and a **Technical
Design** (the object-level, code-grounded plan) all exist, a lead breaks the feature into **epics and stories**
so the team can estimate, groom, and build. Today this is a slow, manual spreadsheet exercise (the GSS
"Feature Breakdown Sheet"). It is also **Appian-specific**: an interaction typically splits into a **form**
part and a **process-model** part; a form is single-owner so it stays one story (split by section only when
complex); and the same field/action gets a separate story per **entry point**. **We automate the analysis:**
produce a grounded, reader-friendly breakdown the lead can trust, refine by chatting with the agent, and
**export as a Jira-importable file** — the Spec/UX/TD handoff experience, one stage further down and out to Jira.

**The methodology authority is the `spec-to-backlog` Kiro skill** (`https://gitlab.appian-stratus.com/allison.olson/spec-to-backlog`) — an exhaustive, multi-team skill; we reuse **only its analysis core** (the story-breakdown best-practices + the `Backlog_JSON` contract + the Jira-import column mapping), and **drop** its Lucid/Google-Sheets/Jira-API renderers and its `gws`/Lucid input fetching. **The example authority for the output is `/Users/ramaswamy.u/Documents/GSS/breakdown-examples`** (four real GSS/GAMS "Feature Breakdown Sheet" PDFs + one CSV) — re-read as the format ground truth in 31-01.

---

## 2. Goal

Make the **Feature Breakdown stage** live: once the **Spec, UX Design, and Technical Design artifacts all
exist**, the user opens the stage, optionally types **notes** and attaches **up to 3 supporting documents**
(a meeting transcript, a spike write-up, etc.), and clicks **Start**. Genesis launches a supervised
**`feature-breakdown-analysis`** run (label **"Feature Breakdown Preparation"**) that:

1. **Ingests + plans epics** — reads the Spec + UX Analysis + **Technical Design** + notes + the uploaded
   docs, and derives **epics = the TD's functional workstreams** (1:1).
2. **Breaks each epic into stories/tasks** (map loop) — applying the Appian breakdown rules (form vs
   process-model split; split by entry point; happy/error; edge cases; state/status; integration/config/
   operational stories; nice-to-have flagging). Each item is a **Story** (front-end testable) or a **Task**
   (a backend/data-model/appref/process-only change *not* verifiable from the front end).
3. **Assembles + verifies (grounded critic) → presents** — a **deterministic** node stitches the per-epic
   stories into a canonical `backlog.json` and renders a reader-first **`breakdown.html`**; a grounded critic
   re-checks coverage against the Spec scope + every TD "What changes" item (nothing invented, nothing
   dropped; the form/process split correct; Gherkin AC testable; Dev-Note pointers valid) → bounded → escalate.
   The doc is handed to the user in a **completion chat** with the **same annotatable preview** as the earlier
   stages; the user refines by conversation.
4. **Exports to Jira** — a download endpoint produces a **Jira-importable file** (create-new-epics, linked via
   Issue ID → Parent ID) from the canonical backlog data.

**Success = a lead opens the finished breakdown, reads it as an easy epic-by-epic set of story cards, trusts
that every Spec/TD change is covered by a story (and nothing is invented), refines a few via chat, and exports
a file that imports straight into Jira as epics + stories/tasks with Gherkin acceptance criteria.**

---

## 3. Constraints & decisions (locked with the user, 2026-09-04)

Firm inputs, not open questions.

1. **Prerequisite gating (all three).** Feature Breakdown can start **only when the Spec, UX Design, AND
   Technical Design artifacts all exist at `in-review` or `completed`** (artifact present; full "Mark
   complete" NOT required). Until then the stage is a first-class but **locked** card. Enforced in the UI
   (locked card) and backend (409 on start) — defense in depth. (Extends the ADR-056 prerequisite amendment
   from Phase 30 — `requires: ["spec","ux","technical_design"]`.)
2. **Entry = notes + up to 3 files + Start (multipart).** Unlike TD (comment-only JSON start) and UX (single
   PDF), Breakdown takes **both** an optional **notes** textarea **and** up to **3 optional attachments**
   (supporting docs). A **multipart** start endpoint provisions the files into the run blackboard (ADR-035).
   Attachments are optional — Start works with zero. **File allowlist unchanged** (pdf/txt/md/html/csv/images
   — no docx/xlsx).
3. **Epics = functional workstreams.** Epics map **1:1 to the Technical Design's workstreams** — the whole
   pipeline stays coherent (the TD already decomposed the feature that way).
4. **Story vs Task = front-end testability.** A **Story** is a user-facing, front-end-testable item (carries
   Gherkin AC). A **Task** is a technical/backend change a tester **cannot validate from the front end**
   (data-model changes, APPREF/entry-point config, process-only backend logic) — a Task may legitimately carry
   **no** Gherkin AC.
5. **Acceptance criteria = Gherkin.** `Given / When / Then` (`AC1`, `AC2`, …), matching the newest GSS sheet
   (2.7). A validator checks each criterion parses as Given/When/Then. (Not the skill's "* Verify…" form.)
6. **No story points.** Estimation is left to team grooming — no points/size field is generated.
7. **Minimal, TD-anchored Dev Notes.** A story does **not** repeat the technical detail — its implementation
   note is a **one-line pointer into the Technical Design** (e.g. *"See Technical Design → 'Vendor Data Model'
   workstream"*). The TD workstream sections carry anchor ids so the pointer can deep-link. Grounding is
   therefore **light** (the TD is already object-grounded); a read-only live spot-check is available to the
   verify critic only.
8. **Reader-first, Lavish-safe output.** `breakdown.html` optimizes for a human reviewer: a summary header +
   **expandable story cards grouped by epic** (native `<details>/<summary>`) with a **CSS-only card↔table
   toggle** (a dense Excel-like table view), **zero JavaScript** so it cannot break the Lavish annotation
   layer (validated against Lavish's golden postMessage fixture in 31-06). The canonical backlog JSON is
   **embedded** in the HTML (`<script type="application/json" id="genesis-backlog">`) so the export is lossless
   even after chat edits.
9. **Jira-importable export.** A download endpoint produces a **Jira-importable file** from the embedded
   canonical JSON, using the skill's proven column contract (`Issue ID · Issue Type · Summary · Description ·
   Parent ID · Acceptance Criteria · Labels`), hierarchy via **Issue ID → Parent ID**, **always creating new
   epics** (no existing-epic-key attach), **no custom-field columns** (the team maps org-specific fields at
   import time). Built with **`openpyxl`/`csv`** (already a pinned genesis dep — no new dependency).
10. **Read-only against Appian (ADR-036/037).** The workflow + completion chat only **read** the live env; the
    breakdown describes work, it never creates/edits/deploys objects.
11. **Maximum reuse.** Reuse the generalized stage surface wholesale (StageStore/m0015,
    `StageArtifactWorkspace`, `AnnotatablePreviewDialog`, `StageBuilderPage`, the annotation→chat bridge, the
    in-progress screen, the reliability-trio + escalation-gate pattern, the generalized `StageFinalizer`
    binding registry). **The only new agent prompt is the completion-chat steering** (`_STEERING_FB`).
12. **Naming:** workflow id **`feature-breakdown-analysis`**; run label **"Feature Breakdown Preparation"**;
    chat mode **`feature_breakdown`**; artifact **`breakdown.html`**; canonical data **`backlog.json`**; stage
    key **`breakdown`** / artifactKind **`feature_breakdown`** (already reserved in `stages.ts`).

---

## 4. Current state (what we build on) — code-grounded

- **Generalized stage model (Phase 29, m0015).** `kb_feature_stages`/`kb_feature_stage_revisions` +
  `genesis/kb/stages.py::StageStore` are per-`(feature, stage)`. A `feature_breakdown` stage is
  `StageStore.get_or_create(feature_id, "feature_breakdown", …)` — **no migration** (`current_version` stays 15).
- **Stage framework (`web/src/features/features/`).** `stages.ts` already declares the `breakdown` stage
  (`artifactKind:"feature_breakdown"`, `available:false`). Making it live = flip `available:true` + a real
  `deriveStatus` + a `breakdown` registry entry + `requires:["spec","ux","technical_design"]` — **no shell
  edits** (the ADR-056 invariant). `deriveAvailability` (Phase 30) already supports prerequisites.
- **The TD workflow (`genesis-workflows/workflows/technical-design-analysis/graph.py`, v0.2.0).** The exact
  skeleton to clone: program nodes plan/loop/persist; narrow Kiro agent nodes wrapped by `attach_reliability`;
  a per-item **map loop** with per-iteration retry-counter reset; a **deterministic assemble** program node
  (agents emit small structured pieces, the program builds the artifact — the timeout lesson); a **grounded
  `verify` critic** (bounded → escalate); a `cleanup` node; read-only namespaced `@genesis-kb/…` +
  `@appian-dev/…` allowlists; fail-fast `resolve_inputs`.
- **StageFinalizer (`genesis/chat/stage_finalizer.py`).** Already a **workflow→stage `_BINDINGS` registry**
  (Phase 30) serving `ux-design-analysis` + `technical-design-analysis`. Adding Feature Breakdown = one more
  `_Binding` (`feature_breakdown`, `breakdown.html`, `feature_breakdown`, `_seed_fb`) — no structural change.
- **Chat modes (`genesis/chat/mode_profile.py`).** `technical_design`/`ux_design` are `ChatModeProfile`s
  (read-only KB/live tools + sandboxed fs-write + steering). A `feature_breakdown` profile is a near-clone with
  `_STEERING_FB`.
- **Stage API (`genesis/api/features.py`).** The generalized `/features/{id}/stages/{stage}` surface exists;
  TD added a JSON start-with-comment (`_launch_td`), UX a multipart upload (`_launch_analysis`), plus
  `_STAGE_ARTIFACT_FILE`, `_current_stage_html`, `export.md`, prerequisite gate `_td_prereqs_ready`. Feature
  Breakdown needs a **multipart start-with-notes-and-≤3-files** path + a **`_fb_prereqs_ready`** (three
  prerequisites) + an **`export.csv`/`.xlsx`** download route.
- **`openpyxl` is already pinned** in genesis (Phase 19 doc-parsing) — the export needs **no new dependency**.

**Takeaway:** this phase = one new genesis-workflows workflow + a thin genesis backend layer (multipart start,
three-way prerequisite gate, one StageFinalizer binding, the `feature_breakdown` chat mode, the export
endpoint) + a web layer (flip `breakdown` live + gating + a registry entry + the notes-and-dropzone entry
state + an export button). **No genesis-core / SDK / migration change.**

---

## 5. The `feature-breakdown-analysis` workflow (working design; finalized in 31-02/31-03)

Deterministic LangGraph (ADR-001). Program nodes plan/loop/persist/assemble; narrow Kiro agent nodes
(reliability trio each) do judgment. **Per-epic decomposition** and a **grounded verification pass** are
first-class (§6). Because a backlog is naturally structured, **agents emit per-epic story JSON and a program
renders the HTML** — sidestepping the giant-HTML-emission timeout entirely.

1. **`resolve_inputs`** (program) — resolve feature + `spec_path` + `uxdesign_path` + `techdesign_path` (all
   three required — the prerequisite is also enforced here) + optional `notes` + the ≤3 uploaded doc paths;
   require a dev-tagged env + the app synced in the KB. Fail-fast otherwise.
2. **`load_inputs`** (program) — materialize `spec.txt` + `ux.txt` + `technical-design.txt` (HTML→text) +
   `notes.txt` + each uploaded doc as `attachments/<name>.txt` into the blackboard. Mark the TD the
   **structural source**.
3. **`plan_epics`** (agent) — derive **epics = the TD's functional workstreams** (reconciled with Spec scope +
   UX screens): a JSON array `[{id, title, workstreamRef, summary}]`. Validator: non-empty; titles set.
4. **`break_epic`** (agent, **looped per epic**) — produce the epic's **stories/tasks as JSON** applying the
   Appian rules (§ below). Each item: `{id, title, storyType(Story|Task), category(core|nice-to-have),
   appianPart, description(As-a/I-want/So-that), acceptanceCriteria(Gherkin | [] for Tasks), devNoteRef(TD
   pointer), questions, labels}`. Loop node resets its retry counter per epic. Validator: Stories carry ≥1
   Gherkin AC; titles action-oriented; Dev-Note pointer references a real TD workstream.
5. **`assemble`** (program, **deterministic**) — stitch the per-epic story JSON into a canonical, de-duplicated,
   ordered **`backlog.json`**, then render **`breakdown.html`** (summary header + `<details>` cards grouped by
   epic + CSS-only table view + the embedded canonical JSON). Self-check the structural invariants; fail loudly
   on violation (the TD `check_doc` lesson).
6. **`verify`** (agent, **grounded critic**, read-only KB/live spot-check) — re-check coverage: every Spec
   scope item + every TD "What changes" item maps to ≥1 story/task; nothing invented; form/process-model split
   correct; Gherkin AC testable + implementation-free; Dev-Note pointers valid; nice-to-haves flagged; uploaded
   docs incorporated; open questions surfaced. Emits pass or a targeted fix list → bounded loop back to
   `break_epic` (the flagged epics) / `assemble`; on exhaustion → **escalation gate**.
7. **`present` → `cleanup` → END** — register `breakdown.html` (+ `backlog.json`) as the `feature_breakdown`
   stage artifact (→ `in-review`); the `StageFinalizer` opens the completion chat. `cleanup` deletes the
   tool-output scratch, preserves artifacts (both terminal paths, like TD).

**Appian breakdown rules encoded in `break_epic`** (from the skill + the GSS examples + the user's heads-up):
form → one story (split by section only when complex); process model → a **separate** story; split by **entry
point** (same action from Home vs Search = separate stories); separate happy-path vs error; explicit
edge-case, state/status stories; integration/config/operational (queuing/guardrails/tracking) stories; group
notifications; flag nice-to-haves (future/phase-2). **Clarity over volume** — don't split just to split;
prefer fewer, meatier stories a dev can deliver end-to-end.

---

## 6. Improvements over a single-pass agent (baked in — research-backed)

- **Per-epic decomposition (map) + deterministic assemble (reduce)** instead of one giant turn — the same
  hierarchical/map-reduce topology that beat a monolithic run in Phase 30, and here the reduce is a *program*
  (structured backlog → HTML), so there is **zero** giant-HTML-emission risk.
- **Context-isolated iterations.** Each `break_epic` turn gets only that epic's TD workstream + the relevant
  Spec/UX slice — countering the "erodes after the first unit" failure of long single-agent runs.
- **A grounded verification (critic) pass**, not self-grading — coverage re-checked against the Spec + the TD
  (external truth), not the agent's own impression.
- **Reuse of the already-grounded TD.** Because the Technical Design is object-level and code-grounded, the
  breakdown inherits accurate scope + object references and only needs a light live spot-check — cheaper +
  more reliable than re-grounding from scratch.
- **Reliability trio + escalation gate** on every agent node (ADR-011); bounded revise loop.

---

## 7. The Feature Breakdown chat (completion), the artifact & the HTML output

Identical experience to Spec/UX/TD — **only the initial steering changes** (`_STEERING_FB`). A bound
**`feature_breakdown`** chat mode (read-only genesis-kb + appian-dev + sandboxed fs-write) is seeded with the
feature identity + the drafted `breakdown.html`. The steering tells the agent its job is to **refine the
backlog with the user** — add/split/merge/re-word stories, adjust AC, re-classify Story/Task — and, crucially,
that `breakdown.html` **contains an embedded canonical JSON block that must be kept in sync** with the visible
cards/table on every edit (so the export stays lossless). The doc is reviewed in the **same annotatable
preview**; annotations flow back into the chat. When done, the stage → `completed`.

**`breakdown.html` structure** (deterministically rendered from `backlog.json`; Lavish-safe, no JS):
- **Summary header** — feature name; epic count; story/task counts; core vs nice-to-have split.
- **Primary view — expandable story cards grouped by epic.** Each epic is a section; each story is a
  `<details>` card (title + Story/Task + core/nice + appian-part chips + one-line summary in the `<summary>`);
  expanding shows the full As-a/I-want/So-that, the Gherkin AC, the one-line Dev-Note TD pointer, and open
  questions. A "⚠ open questions" marker where present.
- **Alternate view — dense table** (one row per story: Epic · Title · Type · Description · AC · Dev Note ·
  Questions · Category), the Excel-like layout the team already reads and the shape the export mirrors.
- **CSS-only card↔table toggle** (a hidden radio/checkbox + sibling selectors — no JavaScript).
- **Embedded canonical JSON** in `<script type="application/json" id="genesis-backlog">…</script>` — the
  export's lossless source.

---

## 8. Start screen + prerequisite gating (three prerequisites)

Feature Breakdown requires **Spec + UX Design + Technical Design artifacts present** (`in-review`/`completed`).
Realized as:
- **Frontend:** `breakdown` declares `requires: ["spec","ux","technical_design"]`; the Phase-30
  `deriveAvailability` renders a **locked** card ("Complete Spec, UX Design & Technical Design first") + a
  blocked workspace until all three are ready.
- **Backend:** a `_fb_prereqs_ready(feature_id)` helper (the three-way analog of `_td_prereqs_ready`) → the
  start endpoint returns **409** if any prerequisite artifact is missing/too-early, and `resolve_inputs` fails
  fast if any of the three paths is absent.
- **Start screen** — reuses the stage entry surface with **both** a **notes textarea** and a **file dropzone
  (≤3 files)**; submits **multipart** to a new `POST /features/{id}/stages/feature_breakdown/start`
  (`notes` + `files[]`). A `/rerun` mirrors it (reset → relaunch). Friendly 409 when the workflow isn't
  installed (§7 lesson).

---

## 9. The Jira-importable export

The workflow's canonical `backlog.json` (embedded in `breakdown.html`) drives a deterministic export at
**`GET /features/{id}/stages/feature_breakdown/export.csv`** (mirroring the `export.md` route). Built with
`csv`/`openpyxl` (already pinned). Jira's classic External-System importer consumes **CSV** and links a
hierarchy via **Issue ID → Parent ID**; the columns follow the skill's proven Sheets/Jira contract:

| Issue ID | Issue Type | Summary | Description | Parent ID | Acceptance Criteria | Labels |
|---|---|---|---|---|---|---|

- Sequential integer **Issue ID** across all epics + stories; a story/task's **Parent ID** = its epic's Issue ID.
- **Issue Type** ∈ Epic / Story / Task; **always create new epics** (epics are rows — no existing-epic-key attach).
- **Description** = As-a/I-want/So-that + the one-line TD pointer + Questions; **Acceptance Criteria** = the
  Gherkin block (newline-separated); **Labels** = category (`nice-to-have`) + inferred labels.
- **No custom-field columns** — the team maps org-specific fields (Component/Fix Version/Team/…) during Jira's
  column-mapping step. (The skill's `backlog-to-jira.py` REST importer with custom-field IDs is explicitly out
  of scope — Genesis produces the importable file, the human imports it.)

The export reads the **embedded canonical JSON from the current `breakdown.html`** (the chat-edited sandbox
copy), so a refined breakdown exports its refinements; a missing/garbled JSON block falls back to the run's
`backlog.json`.

---

## 10. ADR

- **ADR-059 (PROPOSED — this phase): The Feature Breakdown stage — grounded, workstream-decomposed, Jira-ready
  backlog.** A Feature's Feature Breakdown stage consumes the finalized **Spec + UX Implementation Analysis +
  Technical Design** (+ optional notes + up to 3 uploaded supporting docs) and produces a reader-first
  **breakdown** HTML artifact (+ a canonical `backlog.json`) via a deterministic `feature-breakdown-analysis`
  workflow: `plan_epics` (epics = the TD's functional workstreams) → per-epic **story/task breakdown** (map) →
  **deterministic assemble** (backlog.json + breakdown.html, reduce) → **grounded verification** critic
  (coverage vs Spec + TD; bounded → escalate) → present; then a bound **`feature_breakdown` completion chat**
  refines it via the same annotatable review. Appian-native rules (form vs process-model split; entry-point
  splitting; Story = front-end-testable / Task = not FE-verifiable; **Gherkin** AC; **no** story points;
  one-line TD-anchored Dev Notes). A **Jira-importable CSV export** (create-new-epics via Issue ID → Parent ID;
  the skill's column contract; `openpyxl`/`csv`, no new dep). Reuses the Phase-29/30 generalized surface (m0015
  StageStore, the stage components, the StageFinalizer binding registry). Extends the ADR-056 prerequisite
  amendment (`requires: ["spec","ux","technical_design"]`). No migration; genesis + genesis-workflows only.
  Read-only against Appian (ADR-036/037). Reuses the `spec-to-backlog` skill's **analysis methodology + JSON +
  Jira-column contract only** (its Lucid/Sheets/Jira-API renderers + gws/Lucid fetching are dropped).

Mirror in `reference/decision-log.md` + `bible/04`.

---

## 11. Sub-phase ledger

| # | Sub-phase | Deliverable | Gate |
|---|---|---|---|
| **31-01** | Research & format study | Cited study of the `spec-to-backlog` skill (analysis core + `Backlog_JSON` + Jira-column contract) + the four GSS example breakdowns (real fields, form/process split, entry-point granularity, Story vs Task) → the locked backlog schema + HTML output construction; a current-code audit of the reuse surface. **Docs only.** | ⭐ user review |
| **31-02** | ADR & finalize | Lock the workflow node graph + validators + the backlog JSON schema + the HTML template + the three-way prerequisite gating + the multipart start (notes + ≤3 files) + re-run + the export contract; **draft ADR-059.** | ⭐ user sign-off → build |
| **31-03** | Workflow (genesis-workflows) | The `feature-breakdown-analysis` graph (plan_epics → per-epic break_epic loop → deterministic assemble [backlog.json + breakdown.html] → grounded verify → present → cleanup), prompts, validators, workflow.yaml, tests, registry entry (read-only allowlists; reuse the managed `genesis-kb`). | independent review = SHIP |
| **31-04** | Platform build (genesis) | Three-way prerequisite gating (frontend + backend 409); the multipart start-with-notes-and-≤3-files + re-run endpoints; the `feature_breakdown` StageFinalizer binding; the `feature_breakdown` chat mode + `_STEERING_FB`; web: flip `STAGE_DEFS.breakdown` live + gating + a `breakdown` registry entry + the notes-and-dropzone entry-state (reusing the in-progress screen). Gates green; `web/static` committed. | independent review = SHIP |
| **31-05** | Jira-importable export | `GET …/stages/feature_breakdown/export.csv` (deterministic, from the embedded canonical JSON; the skill's column contract; create-new-epics via Issue ID → Parent ID; `openpyxl`/`csv`) + an **Export** button in the stage workspace/Overview; the completion-chat steering keeps the embedded JSON in sync. Round-trip test: export → parse → schema-valid + Jira-column-complete. | independent review = SHIP |
| **31-06** | Code review & hardening | Independent review (coverage-grounding correctness, reliability trio, read-only posture, three-way gating, **Lavish-annotation compatibility of the interactive HTML**, export Jira-importability, reuse cleanliness, a11y/dark-parity/no-hardcoded-hex/contract fixtures); apply SHOULD-FIX; live-acceptance notes. | review clean |
| **31-07** | Release | Coordinated chain **genesis → genesis-workflows**; tags; CI green; docs (bible/tracker/progress/ADR) updated; report. | CI green |

**Suggested order:** 31-01 → 31-02 → 31-03 → 31-04 → 31-05 → 31-06 → 31-07 (linear; each gated on the prior).

---

## 12. Release plan

**Two-repo** (no core/SDK/migration). Order per ADR-019: **genesis** (multipart start + gating + StageFinalizer
binding + `feature_breakdown` mode + export + web) → **genesis-workflows** (the `feature-breakdown-analysis`
workflow + registry, re-pinning the genesis dev-pin). genesis-core / kiro-agent-sdk / genesis-appian-parser
**unchanged**. Per-sub-phase: build → gates → local commit → independent review → docs; **no tag/push until
31-07 on the user's go-ahead**. Keep the pin chain consistent (§7 ResolutionImpossible lesson); a web change →
`npm run build` + commit `web/static` (stale-bundle guard).

---

## 13. Scope

**In scope:** the `feature-breakdown-analysis` workflow; three-way prerequisite gating; the multipart
start-with-notes-and-≤3-files + re-run; the `feature_breakdown` StageFinalizer binding + chat mode; the web
Feature Breakdown stage (live + gating + entry state, reusing the workspace + in-progress screen); the
reader-first Lavish-safe HTML output (cards + table); the **Jira-importable CSV export**.

**Out of scope (future):** the `spec-to-backlog` skill's Lucid/Google-Sheets renderers + its Jira **REST API**
importer (`backlog-to-jira.py`) + `gws`/Lucid input fetching; direct push-to-Jira from Genesis; story-point
estimation; docx/xlsx attachments; auto-"stale" flagging when an upstream artifact changes; any Appian
write/deploy; multi-user/assignment/roles; team style-reference learning (`collect-backlog-examples`).

---

## 14. Open questions

None blocking — all resolved with the user (2026-09-04): Gherkin AC; no points; Story vs Task = front-end
testability; keep the current attachment allowlist; minimal TD-anchored Dev Notes; epics = functional
workstreams; Lavish-safe interactive HTML (must not break annotation); a Jira-importable CSV export that
**always creates new epics** with no custom-field columns.
