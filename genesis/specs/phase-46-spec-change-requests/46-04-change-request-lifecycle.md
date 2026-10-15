# 46-04 — Change-request lifecycle, data model, chat behaviour and consumer isolation

> **Status:** ✅ BUILT + SHIPPED (genesis v0.77.0 / genesis-workflows v0.22.0, 2026-10-15; as-built in `progress/phase-46-spec-change-requests.md`) — drafted 2026-10-14. Repo: **genesis**. Implements the lifecycle half of **ADR-076**.
> Parent: `specs/phase-46-spec-change-requests.md`. Decisions D2–D5 and D11 (umbrella §3).

## 1. Goal

Introduce the **change request (CR)**: a numbered, recorded unit of change to a spec whose stories already exist,
driven from the spec's existing chat, during which the spec is **Under change** and nothing downstream sees the
unfinished edits.

## 2. Lifecycle

### 2.1 States and transitions

`LifecycleState` (`genesis/domain/enums.py`) gains `UNDER_CHANGE = "under-change"`; `StageStore.VALID_STATUSES`
gains `"under-change"`. `SPEC_TRANSITIONS` (`genesis/domain/transitions.py`) becomes:

| From | Action | To | Precondition (ctx key) | Reason shown on failure |
|---|---|---|---|---|
| `draft` | `start` | `in-progress` | — | — |
| `in-progress` | `submit` | `in-review` | `has_html` | "the spec has no authored HTML artifact yet" |
| `in-review` | `approve` | `completed` | — | — |
| `in-review` | `request-changes` | `in-progress` | — | — |
| `completed` | `reopen` | `in-progress` | `not downstream_locked` | "the breakdown is complete — use Initiate change request" |
| `completed` | `initiate-change` | `under-change` | `is_spec and downstream_locked and via_change_request` | "change requests apply to a spec whose breakdown is complete" |
| `under-change` | `apply-change` | `completed` | `via_change_request` | "use Apply changes on the change request" |
| `under-change` | `discard-change` | `completed` | `via_change_request` | "use Discard change request" |

- The table is still shared by every stage (`build_stage_lifecycle`). The new rows are unreachable for non-spec
  stages because `is_spec` is false and `downstream_locked` defaults to false.
- **ctx computation** — one helper `_stage_ctx(row)` used by **both** `/spec/actions/{a}` and
  `/stages/{stage}/actions/{a}` (and their `allowed` endpoints):
  `has_html`, `is_spec = row.stage == "spec"`, `downstream_locked = is_spec and is_traceable(feature) and
  (breakdown.status == "completed" or feature.stories_finalized_at is not null)` (`is_traceable`: 46-03 §7 — a legacy
  feature is never locked and keeps Reopen), `via_change_request = False`. Only the CR service (§5, 46-06) calls
  `transition(..., ctx={…, "via_change_request": True})`.
- **Precondition-aware `allowed`.** `LifecycleService.allowed(kind, id, ctx=None)` (additive): when `ctx` is given,
  actions whose precondition fails are left out. The `allowed` endpoints pass ctx, so a locked spec offers no
  `reopen`, and `initiate-change` / `apply-change` / `discard-change` never appear as generic action buttons (the UI
  renders dedicated CR controls, 46-07).
- The deprecated `PATCH /features/{id}/spec/status` returns **409** when the spec is `under-change` or when the
  target status would leave `completed` while `downstream_locked`.
- Audit: every transition is recorded by the existing m0013 lifecycle audit (actor = `canonical_username`) and so
  appears in the feature Activity feed ("Spec: initiate-change → under-change by ram").

### 2.2 How `under-change` is treated elsewhere

| Consumer | Behaviour |
|---|---|
| Downstream prerequisites (the Technical Design and breakdown start checks in `genesis/api/features.py`, e.g. `_fb_prereqs_ready`; web `deriveAvailability`) | `under-change` counts as **present** (the last completed revision exists). |
| Feature roll-up (`deriveFeatureStatus`) | `under-change` counts as **completed** (the feature does not regress); the spec card shows "Under change · CR-03". |
| Publish to team (`PublishToTeamButton`, `publish_feature_stage`) | Not offered / refused while `under-change` (publishing happens at Apply, 46-06 §7). |
| Save milestone | **Disabled** (UI) and **409** (API) while `under-change` — Apply creates the revision. |
| Export .md | Exports the working copy (labelled "working copy of CR-03" in the filename). |
| **Finalize Stories** (`POST …/stages/breakdown/finalize`) | **409** while the spec is `under-change` ("Apply or discard CR-03 first") — a backlog-mode CR's plan refers to backlog ids that finalize would replace; the UI disables the button with that tooltip. |
| Breakdown stage during a **backlog-mode** CR | Its milestone save returns **409** and its workspace shows a notice "CR-03 is open on the spec — changes to the backlog will come from the change request"; the breakdown chat stays usable for questions (Apply re-checks the breakdown hash, 46-06 A8). |
| Re-running UX / TD / breakdown | Allowed; they read the last completed revision (§6). |

## 3. Migration m0024 (`current_version` 23 → 24)

Additive + idempotent. Bump every `current_version == 23` assertion to 24 (and the synthetic next-migration test).

```sql
-- story traceability + history + answers (JSON arrays; NULL = empty)
ALTER TABLE kb_stories ADD COLUMN spec_refs  TEXT;   -- 46-03 §2
ALTER TABLE kb_stories ADD COLUMN answers    TEXT;   -- 46-08 §2
ALTER TABLE kb_stories ADD COLUMN change_log TEXT;   -- 46-08 §4

-- chat message metadata (divider + agent-only detail; §7)
ALTER TABLE chat_messages ADD COLUMN meta_json TEXT;

CREATE TABLE IF NOT EXISTS kb_spec_change_requests (
  id                  INTEGER PRIMARY KEY,
  feature_id          INTEGER NOT NULL REFERENCES kb_features(id) ON DELETE CASCADE,
  stage_id            INTEGER NOT NULL REFERENCES kb_feature_stages(id) ON DELETE CASCADE,  -- the spec row
  cr_no               INTEGER NOT NULL,              -- 1, 2, 3 … per feature; label = 'CR-' + cr_no zero-padded to at least 2 digits (CR-01 … CR-99, CR-100)
  title               TEXT,                          -- optional "What's changing?"
  status              TEXT NOT NULL DEFAULT 'open',  -- open | applied | discarded
  mode                TEXT,                          -- stories | backlog (set at open)
  opened_by           TEXT NOT NULL,
  opened_at           TEXT NOT NULL,
  closed_by           TEXT,
  closed_at           TEXT,
  base_revision_no    INTEGER NOT NULL,              -- the completed revision the CR started from
  base_content_hash   TEXT NOT NULL,
  result_revision_no  INTEGER,                       -- set on apply
  analysis_id         TEXT,                          -- uuid of the latest Analyze impact
  analyzed_at         TEXT,
  analyzed_spec_hash  TEXT,                          -- normalized working-copy hash at analysis (staleness)
  dir_path            TEXT NOT NULL,                 -- frozen-files directory (§4)
  summary_json        TEXT,                          -- counts + one-line summary (for lists + the Hub)
  sync_uuid           TEXT UNIQUE,
  row_version         INTEGER NOT NULL DEFAULT 0,
  created_at          TEXT NOT NULL,
  updated_at          TEXT NOT NULL,
  UNIQUE (feature_id, cr_no)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_spec_cr_one_open
  ON kb_spec_change_requests(stage_id) WHERE status = 'open';
```

Store: `genesis/kb/spec_changes.py::SpecChangeStore` (`create`, `get`, `get_open`, `list_for_feature`,
`set_analysis`, `close(status, result_revision_no, closed_by)`, `set_summary`; every write `row_version`-CAS'd →
`StaleWriteError`). `KbStore.untrack_application` already cascades through `kb_features`.

## 4. Files

| File | Location | Written by | Purpose |
|---|---|---|---|
| `instructions.md` | sandbox `./cr/CR-03/` | genesis at open | the CR rules for the agent (§8) |
| `base-spec.html` | sandbox `./cr/CR-03/` | genesis at open | the spec as it was when the CR opened (read-only reference) |
| `context/ux-design.html`, `context/technical-design.html` | sandbox `./cr/CR-03/` | genesis at open | current UX/TD text for reasoning (read on demand) |
| `impact-input.json` | sandbox `./cr/CR-03/` | genesis at Analyze (46-05 §3) | the computed facts |
| `plan.json` | sandbox `./cr/CR-03/` | **the agent** (46-05 §4) | the proposed decisions |
| `base.html`, `result.html`, `impact-input.json`, `plan.json`, `document.html`, `apply-report.json` | `feature-stage-artifacts/<spec_stage_id>/change-requests/CR-03/` (`dir_path`) | genesis at open / apply / discard | the frozen record |
| `working/last-normalized.html`, `working/clause-registry.json` | `feature-stage-artifacts/<spec_stage_id>/` | normalizer (46-02 §8) | ID repair state |

Prior CR documents are copied into the sandbox as `./cr/CR-0n/document.html` so the agent can read earlier
decisions on demand.

## 5. Endpoints

All under the features router (`genesis/api/features.py`, or a new `genesis/api/change_requests.py` registered from
it). 409 bodies follow the existing `{error, …}` shape.

### 5.1 `POST /features/{id}/change-requests` — Initiate change request

Body `{title?: string}`. Steps (in order; any failure leaves the spec `completed`):
1. Guards: spec exists, `status == completed`, `downstream_locked`, the spec has a chat session (owner machine — a
   pulled mirror has none → 409 "only the machine that owns the spec chat can change it"), no chat turn is
   streaming in that session (409 "wait for the current chat turn to finish"), no open CR.
2. Normalize the sandbox `spec.html` (46-02). If its hash differs from the latest revision (or there is no
   revision), save a milestone revision first (note "Baseline for CR-03") so `html_path` = the base.
3. `cr_no = max(cr_no) + 1`; `mode = "stories"` if stories are finalized else `"backlog"`.
4. Create the CR row + `dir_path`; copy the base HTML to `base.html`.
5. `transition(STAGE, spec_id, "initiate-change", ctx={…, via_change_request: True})`.
6. Write the sandbox CR files (§4).
7. Post the CR divider + agent note into the chat (§7.2).
8. Collab (when enabled): set the advisory marker (46-09 §5).
Response `{change_request, spec, allowed}`.

### 5.2 `GET /features/{id}/change-requests` · `GET …/{cr_no}`

List (newest first): `{cr_no, label "CR-03", title, status, mode, opened_by, opened_at, closed_by, closed_at,
base_revision_no, result_revision_no, summary}`. Detail adds `analysis` (46-05 §6: `{state: none|awaiting_plan|current|stale,
analysis_id, analyzed_at, validation: {ok, errors[], warnings[]}, counts}`) and `can_apply` + `apply_blockers[]`.

### 5.3 `POST …/{cr_no}/discard` and `POST …/{cr_no}/apply`

Specified in 46-06.

## 6. Consumer isolation (D11)

New helper in `genesis/api/features.py` (and the mirror in `genesis/api/workbench.py`):
`_consumer_stage_html(row)` — for the **spec** stage with `status == under-change`, return the HTML at `html_path`
(the base revision saved in §5.1 step 2); otherwise behave exactly like `_current_stage_html`.

Every downstream read switches to it: `_launch_analysis`, `_launch_td`, `_launch_breakdown`, the Workbench
story-design and story-implementation launches, `_parse_embedded_backlog` consumers, the clause/coverage APIs
(default version), the Story Workspace spec references. The spec **chat preview** keeps using the working copy
(`_current_stage_html`) — that is what the PO is editing.

Regression test: with a CR open and the sandbox edited, a story-design launch snapshots the base revision text.

## 7. Chat behaviour (single chat, D5)

### 7.1 Agent-visible notes (fixes the 46-01 §2.4 defect)

`ChatManager.enqueue_agent_note(session_id, visible: str, agent_text: str | None = None, kind: str = "note",
meta: dict | None = None) -> int`:
- appends a `system` message whose `content` = `visible` and `meta_json` = `{kind, agent_text, …meta}`;
- if the session is live, queues `agent_text or visible` on the session (`ChatSession._pending_notes: list[str]`);
  `stream_turn` prepends queued notes (after the steering/replay preamble, before `User:`) on the next non-slash
  turn and clears them;
- on a cold start, `_build_preamble` renders `system` messages as `Genesis:` lines (not `Assistant:`) and uses
  `meta_json.agent_text` when present, so nothing is lost across a restart.
- `inject_context` (Add context) switches to `enqueue_agent_note` (the existing defect is fixed for every stage).

### 7.2 The CR divider and seed

At CR open:
- **Visible** (rendered by `ChatThread` as a full-width divider when `meta_json.kind == "cr-divider"`):
  "**CR-03 started** by ram · 14 Oct 2026 14:50 — <title>". Similar dividers for `cr-analyzed`
  ("Impact analysis ready — 7 stories affected"), `cr-applied` and `cr-discarded`.
- **Agent text** (hidden): "Change request CR-03 is open for this spec. Read ./cr/CR-03/instructions.md now and
  follow it for the rest of this change request. The spec as it was before this change is ./cr/CR-03/base-spec.html.
  Edit spec.html as the user asks. Do not change any story yourself."

### 7.3 Context size

One chat holds every CR (D5). The durable memory is in files (the spec, `base-spec.html`, `impact-input.json`,
`plan.json`, previous CR documents), so a compaction or a cold-start replay (bounded to the last messages) cannot
lose a decision. The existing context meter and **Compact** button are unchanged; `instructions.md` tells the agent
to re-read the CR files rather than rely on chat memory.

## 8. `instructions.md` (content, written by genesis)

1. What a CR is; the CR number and title; base revision.
2. **Editing:** edit `spec.html` as asked; keep `data-cid` attributes (the structure rules from 46-02 §4).
3. **Analysis:** when Genesis says "Analyze impact", read `impact-input.json` and write `plan.json` exactly in the
   schema it describes (46-05 §4); every item in `affected` needs exactly one decision.
4. **Lane rule (D14):** for stories whose `lane_group` is `locked` (Design Review or later) the decision must be
   `no_change` **unless the user explicitly asked** to change that story; then set `"user_requested": true` and
   quote the request in `rationale`. Recording an answer to a locked story's question also counts as changing it.
5. **Defaults:** clarification/rewording on editable stories → `update` only if acceptance criteria or description
   become wrong, else `no_change`; new scope → a new story (follow-up of the most related story) unless the user
   prefers updating an editable one; removal → `no_change` and say what the user should consider.
6. **Discussion:** after writing `plan.json`, summarize the decisions in the chat in ≤ 10 lines, point the user to
   the CR document, and update `plan.json` whenever the user changes a decision. Never claim a change is applied —
   only the user's **Apply changes** does that.
7. **Never** edit stories, the breakdown or any file outside `./cr/CR-03/` and `spec.html`.

## 9. Tests

Transitions table (each row + preconditions + precondition-aware `allowed`); the deprecated PATCH guard; m0024
idempotency + one-open-CR index; open endpoint guards (each 409) + baseline milestone + mode; consumer isolation for
every launcher; `enqueue_agent_note` (live delivery, cold-start replay with `Genesis:` lines, Add-context fix);
divider metadata.
