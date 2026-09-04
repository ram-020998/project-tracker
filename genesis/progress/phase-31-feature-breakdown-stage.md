# Phase 31 — Feature Breakdown Stage — as-built

> **✅ SHIPPED (2026-09-04) — PHASE 31 COMPLETE.** genesis **v0.59.0** (`e30d5e2`) + genesis-workflows **v0.15.0** (`07e04ce`), CI green — genesis **#6735324** / workflows **#6735326**. ADR-059 **Accepted**. Specs: `specs/phase-31-feature-breakdown-stage.md` + `31-01..31-07` + `31-01-findings.md`. genesis-core / kiro-agent-sdk / genesis-appian-parser unchanged; **no migration** (m0015 reused).

## What shipped

The **fourth and final** feature stage: turn the finalized **Spec + UX Design + Technical Design** into a
developer-executable **backlog** (epics + stories/tasks) and export it straight to Jira. Once all three prior
artifacts exist, the user opens the Feature Breakdown stage, optionally types **notes** and attaches **up to 3
supporting docs** (a meeting transcript, a spike write-up), and clicks **Start** → a supervised
**`feature-breakdown-analysis`** run → a grounded backlog, refined in a **`feature_breakdown`** completion chat,
downloadable as a **Jira-importable CSV**.

## The workflow (`feature-breakdown-analysis`, genesis-workflows v0.15.0)

`resolve_inputs → load_inputs → plan_epics →[v_epics]→ start_breakdown → next_epic →(break) break_epic
→[v_stories]→ advance_epic → next_epic └─(done)→ assemble → verify →[v_verify]→ route_verify →(ok) present →
cleanup → END`; `route_verify →(revise, bounded 2) next_epic; →(exhausted) escalate → cleanup → END`.

- **plan_epics** (agent) — epics = the Technical Design's **functional workstreams**, 1:1.
- **break_epic** (agent, per-epic MAP loop, read-only `@genesis-kb`/`@appian-dev` for a light spot-check) —
  Appian rules: a **form** → one story (split by section only when complex); its **process model** → a
  separate story; split by **entry point**; **Story** = front-end-testable (**Gherkin** Given/When/Then AC) /
  **Task** = a backend/data-model/appref/process-only change a tester can't validate from the UI (AC
  optional); a one-line **`devNoteRef`** pointer into the TD (no rewrite); nice-to-haves flagged.
- **assemble** (DETERMINISTIC program, REDUCE) — builds a canonical `backlog.json` + renders a **Lavish-safe**
  `breakdown.html` (summary header + `<details>` story cards grouped by epic + a **CSS-only** card/table
  toggle + the canonical backlog embedded in `<script id="genesis-backlog">`). Self-checks `check_backlog` +
  `check_html` and raises on violation (no giant-emission agent turn — the Phase-30 timeout lesson).
- **verify** (grounded coverage critic) — every Spec scope item + every TD "What changes" item maps to ≥1
  story/task; nothing invented; the form/process split is right; Gherkin AC testable; `devNoteRef`s valid.
- Reliability trio on every agent; `MAX_EPICS` 15; `recursion_limit` 300; the revise loop resets the
  aggregate + `break_queue` + retry counters (no duplicates).

## The platform (genesis v0.59.0)

- **Backend** (`api/features.py`): `_fb_prereqs_ready` (three-way gate → 409), `_launch_breakdown` (snapshots
  the 3 artifacts + `files={"doc1..3"}` uploads), multipart `POST /features/{id}/stages/breakdown/start` +
  `/rerun` (`_read_uploads` ≤3; 409 on in-progress / already-finalized / workflow-not-installed), registered
  **before** the generic `/stages/{stage}/start` so the literal `breakdown` route wins;
  `_STAGE_ARTIFACT_FILE['breakdown']='breakdown.html'`.
- **StageFinalizer** (`chat/stage_finalizer.py`): one more `_BINDINGS` entry (`feature-breakdown-analysis` →
  stage `breakdown`, artifact `breakdown.html`, chat mode `feature_breakdown`, `_seed_fb`) — the registry now
  serves UX + TD + Breakdown.
- **Chat** (`chat/mode_profile.py` + `chat/store.py`): a `feature_breakdown` `ChatModeProfile` + `_STEERING_FB`
  (refine the backlog; keep the embedded canonical JSON in sync); mode whitelisted.
- **Jira export** (31-05): `GET /features/{id}/stages/breakdown/export.csv` — `_parse_embedded_backlog` (reads
  the embedded JSON from the current `breakdown.html`, falls back to the run's `backlog.json`) →
  `_backlog_to_jira_rows` (Issue ID → Parent ID; **create-new-epics**; no custom-field columns) →
  `_backlog_csv` (stdlib `csv` — `openpyxl` already pinned, no new dep).
- **Web** (`web/src/features/features/`): `STAGE_DEFS.breakdown` live + `requires:["spec","ux","design"]` + a
  real `deriveStatus`; a `stage-registry` entry; a `BreakdownEntry` (notes + ≤3-doc dropzone + Start; blocked
  / running states); `BreakdownCardActions` (Locked / Start / View / **Export** / Re-run) + `RerunBreakdownButton`;
  `startBreakdown` (multipart) + `exportCsvUrlFor` + `useStartBreakdown`. **No shell edits** — the ADR-056
  plug-in invariant held.

## 31-06 review + hardening

- **Lavish compatibility (the one hard requirement):** the served artifact injects only the Lavish SDK
  `<script>` + theme vars before `</body>`; our document is otherwise **JavaScript-free**, so annotation can't
  break. A deterministic test (`test_lavish_injection_preserves_breakdown_structure`) proves injection keeps
  one `</body>`, loads the SDK, and leaves the embedded backlog JSON intact (so the export is unaffected by
  annotation). **Fix found:** the artifact iframe sets only `color-scheme` (no body background), so dark text
  was unreadable on the dark-theme canvas → gave `breakdown.html` an explicit light **paper** background
  (readable both themes; cards/table already light).
- Verified: read-only allowlists, reliability trio, deterministic assemble, Gherkin-AC + Story/Task rules,
  three-way gating agrees front↔back, multipart guards, the finalizer binding, the revise-loop reset, and the
  export round-trip (Issue ID → Parent ID linkage).

## Gates (all green)

- genesis: pytest **678** + ruff; web tsc + eslint 0 + vitest **226** + build (`web/static` committed).
- genesis-workflows: `validate_library` **12** + pytest **176** + ruff.
- CI green — genesis **#6735324** / workflows **#6735326**. `genesis install` picked up the workflow.

## Local commits (then released)

genesis-workflows: `5587dc3` (31-03 workflow) + `c598b0a` (31-06 paper-bg) + `07e04ce` (v0.15.0 release).
genesis: `991829c` (31-04 backend) + `2c763a9` (31-04 web + web/static) + `85656b8` (31-05 export) +
`bd8d65e` (31-06 Lavish test) + `e30d5e2` (v0.59.0 release).

## Methodology / format authorities

The `spec-to-backlog` Kiro skill (`gitlab…/allison.olson/spec-to-backlog`) — **analysis core + `Backlog_JSON`
+ Jira-column contract ONLY** (its Lucid/Google-Sheets/Jira-REST renderers + gws/Lucid fetching dropped). The
four GSS example breakdowns at `~/Documents/GSS/breakdown-examples` (the real field set + the form/process-model
split + entry-point granularity + Story-vs-Task + Gherkin AC). See `31-01-findings.md`.

## Live acceptance (user-driven / headless-undrivable)

A real feature with Spec + UX + Technical Design finalized → open Feature Breakdown → Start with notes + a
transcript → the supervised run → the completion chat → refine → **Export** → import the CSV into Jira as
epics + stories/tasks with Gherkin acceptance criteria.

## Deferred (out of scope)

Push-to-Jira from Genesis (the CSV is the boundary); the skill's Lucid/Sheets renderers + REST importer; story
points; docx/xlsx attachments; auto-"stale" flagging when an upstream artifact changes.
