# 46-01 — Findings: spec ↔ story traceability and spec change requests

> **Status:** 🟡 DRAFTED 2026-10-14 (research + decisions locked with the user; no code changed).
> Parent: `specs/phase-46-spec-change-requests.md`. Proposed ADRs: **ADR-075** (spec clause model + story↔spec
> trace links) and **ADR-076** (spec change requests).
>
> This document records **everything** that was researched and decided before the spec was written: the problem
> as the user stated it, how Genesis works today (code-grounded), how other products solve the problem, the
> technical building blocks, the three options considered, and every decision taken in the four rounds of
> discussion (2026-10-14). The sub-specs (46-02 … 46-11) implement what is decided here.

---

## 1. The problem (as stated by the user, 2026-10-14)

Genesis takes a feature from a **Spec** (chat-authored HTML) and a mockup through UX Design and Technical Design to a
**Feature Breakdown**, whose stories are **finalized** into Genesis story records and imported into Workbench boards.

The spec is **not a final document**. During daily stand-ups developers go through the open questions on the
stories assigned to them and ask the Product Owner (PO); the answers often make the PO change part of the spec.
For every such change the team has to decide whether the change is implemented **as part of the existing story** or
as a **separate, new story**.

So Genesis needs:

1. **A practical relationship between each part of the spec and the stories** derived from it. If a spec has
   120–130 stories and one line changes, Genesis must know which stories are affected.
2. **Impact detection on change.** When the spec is updated after stories exist, find the impacted stories and ask
   the user to decide, per story, whether to **update the existing story** or **create an incremental story**.
3. **A record of those decisions against the spec** ("these stories were created/updated for this change").
4. **A simple user experience.** It must not be complicated for the PO.

---

## 2. How Genesis works today (verified in the code)

Paths: `genesis/` = `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis`, `workflows/` =
`/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis-workflows/workflows`.

### 2.1 The spec

- **Storage.** A spec is the `stage='spec'` row of `kb_feature_stages` (m0015): `status`, `chat_session_id`,
  `html_path`, `content_hash`, `row_version`, … Milestones are rows in `kb_feature_stage_revisions`
  (`revision_no`, `html_path`, `note`). Store: `genesis/kb/stages.py` (`StageStore`; `VALID_STATUSES =
  draft|in-progress|in-review|completed`).
- **Working copy vs saved copy.** The chat agent writes `spec.html` into its sandbox
  (`~/.genesis/skill-output/<chat_session_id>/spec.html`). `html_path` is set only when the user saves a milestone
  (`POST /features/{id}/spec/milestone`, `genesis/api/features.py:420-442`). `_current_stage_html(row)`
  (`features.py:602-612`) returns the **sandbox file first**, then `html_path`.
- **Every downstream consumer reads the sandbox first.** `_launch_analysis` (UX), `_launch_td`, `_launch_breakdown`
  (`features.py`) and the Workbench story-design / implementation launches (`genesis/api/workbench.py:69-85,
  218, 325`) all snapshot `_current_stage_html`. **Consequence:** while the PO is editing the spec, a story-design
  run started by a developer would read the PO's half-finished edits. Phase 46 must fix this (46-04 §6).
- **Lifecycle.** `SPEC_TRANSITIONS` (`genesis/domain/transitions.py:22-28`): `draft –start→ in-progress –submit→
  in-review –approve→ completed`, `in-review –request-changes→ in-progress`, `completed –reopen→ in-progress`.
  The same table governs **every** feature stage (`build_stage_lifecycle`, `genesis/domain/lifecycle.py:181-201`).
  `LifecycleService.allowed()` lists actions **without evaluating preconditions** (`lifecycle.py:79-86`) — the UI
  shows every action in the table for the current state.
- **No structure Genesis can point at.** `_STEERING_SPEC` (`genesis/chat/mode_profile.py:75-90`) asks for "a
  SINGLE, self-contained, well-structured HTML document … clear sections, lists, and tables". There are **no
  section/clause IDs and no numbering rule**.
- **Spec workspace UI.** `web/src/features/features/StageArtifactWorkspace.tsx`: a toolbar (Add context, status
  badge, one button per allowed action — labels in `status.ts` `SPEC_ACTION_LABEL` — Export .md, Save milestone,
  Publish to team, Preview) above the `ChatThread`. **Preview** opens the full-screen `AnnotatablePreviewDialog`
  (sandboxed iframe + the vendored Lavish SDK + a comment queue whose "Send all" posts into the chat).

### 2.2 The breakdown and the stories

- **Breakdown input.** `feature-breakdown-analysis` reads the spec/UX/TD HTML and **flattens it to plain text**
  (`_read_html_file` / `_strip_html`, `workflows/feature-breakdown-analysis/graph.py:166-189, 422-444`). Any IDs in
  the HTML would be lost before the agent sees them.
- **Backlog JSON** (embedded in `breakdown.html` as `<script id="genesis-backlog">`): epic `{id:"epic-N", title,
  workstreamRef, description, stories[]}`; story `{id:"story-N-M", title, storyType, category, appianPart,
  description, acceptanceCriteria[], devNoteRef, questions[], labels[]}` (`graph.py:272-296`). **No reference to a
  spec section, UX screen or TD object** — `workstreamRef` is a TD workstream *name*, `devNoteRef` is free text.
- **Finalize** (`genesis/kb/stories.py:85-131`, ADR-060) inserts `kb_epics` + `kb_stories` once. Two existing
  provenance losses:
  - the backlog story id `story-N-M` is replaced by the `GNS_` key (by design, ADR-072);
  - **bug:** finalize reads `epic.get("workstream")` but the backlog emits `workstreamRef`, so
    **`kb_epics.workstream` is always NULL** (`stories.py:110` vs `graph.py:292`).
- **Stories after finalize.** `StoryStore.create_story` can add stories at any time (status `to-do`);
  `update_story` is row_version-CAS'd; `delete_story` exists.
- **Story questions** are a flat `string[]` (`kb_stories.questions`), shown read-only in the Story Workspace
  Overview (`web/src/features/workbench/StoryWorkspacePage.tsx`). **There is no answer field.**
- **Downstream re-flow.** `story-design-analysis` and `story-implementation` read the story fields + freshly
  snapshotted spec/UX/TD HTML at launch, so an updated story re-flows into the next design run.
- **Lanes.** To Do → Design → Design Review → Implementation → Code Review → Verification → Deployment → Done
  (`STORY_LANES`); audited send-back edges exist (`implementation –send-back→ design-review`, …).

### 2.3 Staleness and collaboration

- `upstream_versions_json` exists on `kb_feature_stages` + `kb_story_stages` (m0019) but is **never written** —
  only renamed on Hub publish/pull (`genesis/collab/service.py:78, 92, 518`). The "Spec changed since this stage
  was built" badge was designed in Phase 38 but **never mounted** (`specs/phase-38-collaborative-sdlc/
  38-04-deferred-ui-notes.md:60-83`).
- `isStale` / `StalenessBadge` compare **Hub publish versions** only, not upstream artifact versions.
- **Publishing.** `CollaborationService._BINDINGS` (`collab/service.py:86-107`): `stage_artifact` (HTML as an
  `artifact` blob), `epic`, `story` (`json_cols = acceptance_criteria, questions, labels` → arrays on the wire →
  exploded into `GH Story Item` rows with `item_type ∈ ac|question|label` on the Hub — contract
  `specs/phase-36-genesis-hub-appian-app/contract/genesis-hub-api.md` §2.2). Any new shared column rides the
  payload automatically unless listed in `_LOCAL_ONLY`; the Hub needs a matching **additive** change (precedents:
  the v0.69.0 `on_board` field, the Phase-42 `object-wiki-contract-addition.md`).
- A **pulled** stage is a read-only mirror with no local chat — only the machine that owns the spec chat can edit
  the spec.

### 2.4 A latent chat defect found while grounding

`ChatManager.enqueue_system_turn` (`genesis/chat/manager.py:576-583`) only **appends a `system` message to the
transcript**. A live Kiro session never receives it: `stream_turn` prepends only the steering (fresh client) and the
cold-start replay preamble (`manager.py:236-243`). So, for example, the "Added 2 reference documents to ./context/"
note from **Add context** reaches the agent only after the client restarts. `_build_preamble` also labels `system`
messages as `Assistant:` (`manager.py:355-362`). Phase 46 depends on reliable agent-visible notes, so it fixes
both (46-04 §7).

### 2.5 Reusable seams

Milestone revisions + content hashes; the canonical backlog JSON; `create_story`/`update_story` CAS; audited
lifecycle transitions (m0013) + the activity feed; the Lavish annotation round-trip; the `./context/` files
pattern; the `stage_artifact`/`story` collab bindings; `upstream_versions_json`; the deterministic-render lesson
(Phases 30/31: agents produce structured data, program code renders documents).

---

## 3. How other products solve it (research summary)

Three families. Sources: IBM DOORS / DOORS Next docs (suspect links, link validity), Jama Connect (suspect links,
Live Trace Explorer, Impact Analysis, Relationship Discovery, Advisor), Siemens Polarion (LiveDoc work items,
Auto-Suspect, red dashed suspect links), PTC Codebeamer (suspect flag + "mass process suspected changes"), Visure,
Helix ALM, ReqView, Modern Requirements4DevOps, Doorstop (YAML items + content fingerprints), StrictDoc,
sphinx-needs, Jira + Confluence, Jira Product Discovery, R4J, Xray, Azure DevOps, Productboard, Aha!, Linear,
Notion, AWS Kiro specs (requirements.md / design.md / tasks.md, EARS, "Sync Files"), GitHub Spec Kit (`/clarify`,
`/analyze`), Tessl, plus academic work on LLM trace-link recovery and change-impact analysis (TVR, R2Code,
ProReFiCIA, NARCIA, ChangeSumm). Full research notes with URLs were produced on 2026-10-14; the key ones are in §8.

| Family | Products | Mechanism | Weakness |
|---|---|---|---|
| **Suspect links** | DOORS, Jama, Polarion, Codebeamer, ReqView, Doorstop | Every requirement has a permanent ID; work items link to it; when the requirement changes the link turns "suspect" until someone reviews and clears it. | Flags on every edit (typos too) → users click "clear all". Heavy setup (Jama's traceability model, Polarion configuration). |
| **Regenerate** | Kiro specs ("Sync Files"), GitHub Spec Kit (`/analyze`) | Tasks reference requirement IDs; on change, downstream tasks are re-derived and a cross-artifact consistency check runs. | Churn (unrelated tasks reshuffled, manual edits lost); no record of *why* something changed. |
| **Manual links** | Jira + Confluence, Linear, Notion, ADO | Links exist but carry no change signal; Confluence shows a page diff. | Spec and stories silently drift — today's Genesis problem. |

### 3.1 Lessons that shaped the design

1. **Clause-level links, not page or section level.** Nearly every tool settles on "one requirement = one stable
   ID", with acceptance criteria addressable underneath. Page-level links fire constantly; paragraph-level
   (Polarion) is precise but heavy.
2. **Capture links when stories are generated.** Post-hoc AI link recovery tops out around 80–85% correct
   (TVR 85.5% recovery; documentation-to-code ~79–80% F1), and embedding similarity alone can rate opposites
   ("must encrypt" / "must not encrypt") as near-identical. The breakdown agent *knows* which clauses it used —
   that is the trustworthy link; AI recovery only *suggests* extra links, with a confidence shown.
3. **Detect real change with content fingerprints, not edit events** (Doorstop: the link stores the parent's hash;
   it is suspect only when the hash differs). A deterministic "formatting-only" check plus an AI classification
   (clarification / new scope / removal / rewording / correction) removes the typo noise.
4. **Small, pre-filled, explainable triage.** Linear Triage Intelligence proposes a decision with a "why" and
   one-click accept; GitHub "changed since last viewed" shows only new deltas; ProReFiCIA had engineers review only
   ~3% of requirements. Show a tiny high-recall candidate set with defaults filled in.
5. **New story vs update in place — consistent agile practice.** Clarifications and changes to not-started stories
   are edited in place; new scope, or any change to work already in progress/done, becomes a **new linked story**;
   never silently rewrite a story a developer is working on.
6. **Decision records are append-only** (ADR practice: supersede, never edit). Each change becomes a dated record
   with the affected items and the decisions.
7. **Keep agent output structured; render documents deterministically** (Genesis Phase 30/31 lessons) — the same
   reason Kiro/Spec-Kit keep requirement IDs in structured files.

### 3.2 Technical building blocks (research)

- **Anchors.** Assigned hidden block IDs are the strongest anchor (Notion block UUIDs, TipTap `UniqueID` with
  server-side `generateUniqueIds`), but split/paste/LLM rewrites duplicate or drop IDs → a **repair pass** is
  mandatory. Repair uses the W3C Web Annotation / Hypothesis strategy: exact content match first, then a fuzzy
  quote match (Bitap / diff ratio) above a threshold; anything that cannot be re-anchored is reported, never
  silently dropped (Hypothesis "silent orphan" pitfall). Heading slugs break on rewording → display only.
- **Diff.** Hash gate (unchanged blocks skipped) → structural block diff with move detection (diff-dom style;
  moves ≠ changes) → AI change summary + classification only for changed blocks that have linked stories
  (ChangeSumm: give the model the diff, decompose per edit).
- **Concurrency.** Optimistic locking (Google Docs `requiredRevisionId`) — commit only if nothing changed since the
  analysis; never auto-overwrite in-progress work; record every automated action reversibly.

---

## 4. Options considered (presented 2026-10-14)

| | **A — section links + AI impact** | **B — clause IDs + generation-time links + fingerprints + AI-assisted review** | **C — regenerate & reconcile (Kiro style)** |
|---|---|---|---|
| How | Stories link to spec headings; on publish an agent reads the diff and proposes decisions | Numbered hidden clause IDs repaired by program code; the breakdown records clause refs per story; fingerprints detect real change; an agent proposes per-story decisions; decisions recorded | Re-run the whole breakdown with existing stories as context; show backlog changes for approval |
| Precision | Low–medium | **High** | Medium |
| Credits per change | Medium | **Low** | High |
| Audit trail | Weak | **Strong** | Weak |
| Build effort | Small | Large (phased) | Medium |
| Survives manual story edits | Yes | Yes | Risky |

**The user chose Option B** for its technical model (clause IDs, links, detection) — "more usable and more
realistic" — and then redesigned the user experience around a chat-driven change request (§5.2).

---

## 5. Decisions (locked with the user, 2026-10-14)

### 5.1 Round 1 — option

- **D1.** Option **B**: clause IDs, generation-time links, fingerprint detection. Accepted as proposed.

### 5.2 Round 2 — the user's change-request flow (replaces the separate review screen)

The user's words, condensed: *the spec can only move on when it is Completed; today a Completed spec can be
Reopened. Once the breakdown is done, replace Reopen with "Initiate change request"; the spec goes to a new status
("under change"). The PO edits the spec in the same chat. When all edits are done, a button starts the
reconciliation: in the same chat the agent analyses everything and lists every affected story and the decision
needed for each. The user reviews and settles everything in the chat (update a story, create a new story, …). Only
when the user clicks the final Reconcile button do the discussed changes take effect. Before breakdown, the normal
lifecycle is unchanged.*

Agreed design points (assistant's restatement, accepted):

- **D2.** Before the breakdown is complete nothing changes (Draft → In progress → In review → Completed; Reopen).
- **D3.** Once the Feature Breakdown is **completed** or the stories are **finalized**, a Completed spec offers
  **"Initiate change request"** instead of **Reopen**.
- **D4.** Initiating opens **CR-n** (numbered per feature: CR-01, CR-02, …) and moves the spec to a new status
  **Under change**.
- **D5.** The PO edits the spec **in the chat**, exactly as today.
- **D6.** **Analyze impact** (step 1): the agent analyses the change and proposes a decision for every affected
  story + new stories for uncovered requirements. **Discussion happens in the chat.**
- **D7.** **Apply changes** (step 2): only now are stories updated/created, the change recorded and the spec
  returned to Completed with a new revision. **Nothing changes before this click.**
- **D8.** The agent maintains a **structured reconciliation plan** (it never writes stories itself); program code
  validates and applies exactly that plan in one transaction — the button is the human confirmation (ADR-031/045).
- **D9.** The facts (changed clauses, linked stories, lanes) are **computed by program code** and handed to the
  agent as files; the agent judges. AI cost is limited to changed clauses.
- **D10.** If the spec is edited again after an analysis, the plan is marked **out of date** and Apply is disabled
  until Analyze impact runs again.
- **D11.** While a CR is open, **downstream runs read the last completed revision**, never the working copy.
- **D12.** **One open CR per spec**; teammates see "Spec under change by <name> (CR-n)".

### 5.3 Round 3 — answers to the open points (verbatim decisions)

| # | Question | Decision |
|---|---|---|
| 1 | Button names | **"Analyze impact"** (step 1) and **"Apply changes"** (step 2) — agreed. |
| 2 | Review inside a CR? | **Straight to Completed** after Apply (the PO is the one making the change). |
| 3 | Abandon a CR | **Yes** — "Discard change request" reverts the spec to the last completed revision; no story changes. |
| 4 | Breakdown completed but stories not finalized | **The CR updates the breakdown's backlog** (backlog mode). |
| 5 | Which chat | **One chat per spec** (no separate CR chats). Context is preserved by compaction plus the durable records (§5.4). Assistant agreed. |
| 6 | Stories beyond Design | **Any story beyond Design is not touched unless the user specifically asks.** The user decides. |
| 7 | "Raise change request" from a story | **Not needed.** |
| 8 | Mark UX Design / Technical Design stale | **Yes.** |
| 9 | Hub fields + answers on story questions | **Agreed** — additive Hub fields; story questions get answers. |
| — | New: CR document | **Yes** — "Analyze impact" creates a **"CR-0n Impact Analysis" document** (like the spec), one per CR, instead of putting the analysis only in the chat. |

### 5.4 Consequences of the round-3 answers (assistant's refinements, accepted)

- **Single chat (Q5).** Each CR starts with a visible divider in the chat ("CR-03 started by <name>"). At that
  point the agent receives fresh context **as files** (current spec, clause map, CR instructions, earlier CR
  documents), so a compaction can never lose what matters: the spec, the CR documents and the story records are the
  memory, not the chat. The existing context meter and Compact button keep working.
- **Lane rule (Q6).** **To Do** and **Design** stories: the agent may propose updates. **Design Review onward**:
  listed as affected with the reason, default **no change**; changed or followed-up only if the user explicitly
  asks in the chat. A Design-lane story whose design already ran is flagged "re-run design" when updated.
- **CR document.** Shown in the same full-screen preview as the spec (tabs **Spec | CR-03 Impact Analysis**), with
  the same highlight-and-comment review. The agent edits only the structured plan; program code renders the
  document from it, so the document and what Apply executes can never diverge. On Apply the document is frozen as
  **Applied** with the resulting story keys; a discarded CR keeps its document marked **Discarded**. The spec page
  lists **CR-01 … CR-n** with status, author, dates and a link to each document — this list **replaces** the
  separate change-history tab proposed in round 1.

### 5.5 Round 4 — existing stories (2026-10-14, after the spec set was drafted)

- **D19.** *"We don't have to take care of existing stories. We can leave them as they are. We will only start fresh
  after this implementation."* → No backfill or AI linking of stories created before Phase 46; the planned
  `spec-story-linking` workflow, the "Link stories to the spec" action and suggested (confidence-scored) links are
  **dropped**. Traceability and change requests apply to **traceable** features — breakdowns produced after the
  release. Legacy features keep today's behaviour (Reopen after the breakdown, no coverage badges). A legacy feature
  whose breakdown is not finalized becomes traceable by re-running the breakdown. (46-03 §7.)

### 5.6 Settled flow

```
Completed ──Initiate change request──▶ Under change (CR-03; chat divider; context files)
   edit spec in chat → Analyze impact → "CR-03 Impact Analysis" document
   refine in chat / annotate the document (plan + document update together)
   ├─ Apply changes ──▶ stories / backlog updated · document frozen "Applied" · spec Completed (new revision)
   └─ Discard change request ──▶ spec reverted · document "Discarded" · stories untouched
```

Other confirmed points: no "raise CR from story" button; UX/TD get a "spec changed" badge; Hub fields allowed;
story questions get answers.

---

### 5.7 Round 5 — the defaults (2026-10-14, after 46-02 was built)

Asked one question at a time; the user chose the default (option A) for each:
- **Q1** — CRs replace Reopen once the breakdown is *completed* or the stories are *finalized* (in review keeps Reopen). Rejected: finalized-only; any breakdown state.
- **Q2** — clause numbers computed and shown only in the preview margin, never stored. Rejected: an added "copy reference" action; numbers written into the text.
- **Q3** — a new story goes into the followed-up story's epic (else the agent's proposed epic), status To Do, on the board if the followed-up story is (a brand-new story: if any story of the feature is), positioned after the followed-up story. Rejected: never auto-board; a per-story board checkbox in Apply.
- **Q4** — removed clauses: affected stories flagged, default no change; update or (To Do / Design only) remove when the user asks. Rejected: default update; mark obsolete instead of deleting.
- **Q5** — the CR title is optional (blank shows as CR-n; Analyze impact may suggest one). Rejected: required; required before Apply.

### 5.8 Round 6 — 46-05 build decisions (2026-10-15)

Asked one question at a time before building 46-05; the user chose option A for both and accepted the assistant's
14 other refinements. Full text: `46-05-impact-analysis.md` §11.
- **Q1 — attach a new clause to an existing story → A:** each new clause lists *candidate* stories (linked to
  other clauses of its section); the plan may `update` a candidate only to attach the new clause; lane/run/CAS rules
  apply. Rejected: section-linked stories auto-affected; new stories only.
- **Q2 — formatting/moved-only CRs → A:** `no_changes` only when nothing differs at all; such a CR is analyzed with
  an empty `affected` list, an agent-written decision-less plan, and Apply saves the revision without story changes.
  Rejected: treat as no change (Discard only); Genesis writes the empty plan itself.

### 5.9 Round 7 — 46-06 build decisions (2026-10-15)

Asked one question at a time before building 46-06; the user chose option A for both and accepted the assistant's
12 other proposals. Full text: `46-06-apply-and-discard.md` §10.
- **Q1 — publishing before 46-09 → A:** Apply publishes what the existing bindings support (spec stage, updated/created
  stories, deletion tombstones, the breakdown stage in backlog mode); a `HubConflict` → "publish pending", no
  pull-then-republish. The CR record/blob, advisory marker and conflict merge stay in 46-09. Rejected: publish nothing;
  everything now incl. pull-and-republish.
- **Q2 — answers on locked stories → A:** the Apply confirmation (A7) also covers locked stories that keep
  `no_change` but get answers (matches V4). Rejected: A7 as written (update/remove only).

### 5.10 Round 8 — 46-08 build decisions (2026-10-15)

Asked one question at a time before building 46-08; the user chose option A for all three and accepted the
assistant's 11 other proposals. Full text: `46-08-story-answers-history-and-badges.md` §9.
- **Q1 — "re-run design" scope → A:** every CR-updated story whose design is done, in Design **or Design Review**
  (amends the built 46-06 rule, which only covered the Design lane). Rejected: Design lane only; any lane.
- **Q2 — a "From the spec" chip → A:** opens the read-only spec in a new tab scrolled to + highlighting the clause.
  Rejected: open the spec workspace preview (depends on 46-07); a popover only.
- **Q3 — story workflow inputs → A:** pass answers, spec clauses **and the open questions** (marked unresolved).
  Rejected: answers + spec clauses only.

### 5.11 Round 9 — 46-07 build decisions (2026-10-15)

Asked one question at a time before building 46-07; the user chose option A for all three. Full text:
`46-07-web-experience.md` §14.
- **Q1 — small additive backend reads → A:** add them in 46-07 (lock/open-CR state on `/spec/allowed`; locked
  confirmations, next revision and chat busy on the CR detail; the activity CR label; `coverage=0` on the preview) so
  the UI renders from durable state; recorded as a deviation from "web-only". Rejected: client-side inference.
- **Q2 — a closed CR from the list → A:** `/spec/artifact?revision=<n>`; an applied CR opens its frozen document +
  the spec revision it produced (read-only tabs); a discarded CR its document only. Rejected: the document only.
- **Q3 — proposals 1–14 → A:** all accepted as written (toolbar per state, Initiate wording, banner from the detail
  with 5 s polling while busy, Analyze/ask texts, Apply/Discard dialogs, preview tabs with tagged comments, coverage
  switch + popover from `revision=working`, CR drawer, Overview chip from the latest applied CR, Activity text, chat
  dividers, pulled mirrors → 46-09, the backend additions).

## 6. Defaults chosen by the assistant — ✅ confirmed by the user 2026-10-14 (umbrella §13 Q1–Q5, each answered "A" = the default as written)

*(Heading was "not yet explicitly confirmed"; the confirmation round is recorded in §5.7.)*

| Topic | Default in this spec |
|---|---|
| Which breakdown state locks the spec | Breakdown stage **completed** OR stories **finalized** (a breakdown still *in review* keeps normal Reopen; the breakdown then shows the "spec changed" badge). |
| Clause numbers | Shown by Genesis in the preview margin, **computed** from document order at render time; never stored in the HTML (IDs stay hidden). |
| New stories | Same epic as the story they follow up (or the epic the agent proposes); status **To Do**; on the board if the followed-up story is on the board (or, for a brand-new story, if any story of the feature is on the board). |
| Removed requirements | Affected stories are flagged; default **no change**; the user may ask to update or remove a To Do / Design story. |
| ~~Existing features~~ | ~~One-time "Link stories to the spec" action~~ — **dropped by D19** (existing stories left as they are). |
| CR title | Optional one-line "What's changing?" when initiating. |

---

## 7. What Phase 46 changes vs today (for traceable features — 46-03 §7)

| Today | Phase 46 |
|---|---|
| Spec HTML has no structure Genesis can reference | Every section/clause carries a hidden `data-cid`, repaired by program code after every agent turn |
| Breakdown sees flattened text; stories have no spec link | Breakdown sees clause-tagged text and records `clauseRefs`; finalize stores `spec_refs` on each story |
| Reopen a completed spec freely; downstream silently drifts | After breakdown: Initiate change request → Under change → Analyze impact → Apply / Discard |
| Downstream runs read the spec's working copy | Downstream runs read the last completed revision while a CR is open |
| No record of spec changes vs stories | CR documents (one per CR) + a change history on every story |
| `kb_epics.workstream` always NULL (bug) | Fixed at finalize |
| Story questions have no answers | Questions can be answered (by people or by an applied CR) |
| "Spec changed" badge designed, never built | UX/TD show "Spec changed since this was produced (CR-n)" |
| System notes never reach a live chat agent | Agent-visible notes (also fixes Add context) |

---

## 8. Key sources

- IBM DOORS suspect links — https://www.ibm.com/docs/kk/SSYQBZ_9.7.0/com.ibm.doors.requirements.doc/topics/c_aboutsuspectlinks.html ; suspicion profiles — https://www.ibm.com/docs/en/elm/6.0.2?topic=traceability-creating-suspicion-profiles
- Jama Connect change management / Live Trace Explorer — https://www.jamasoftware.com/blog/jama-connect-features-in-five-change-management/ , https://www.jamasoftware.com/blog/jama-connect-features-in-five-live-trace-explorer/
- Polarion impact analysis / suspect links — https://polarion.code.blog/2020/06/28/use-case-a-customer-requirement-changes-impact-analysis-and-staying-consistent/
- Codebeamer mass-process suspected changes — https://support.ptc.com/help/codebeamer/r2.2/ja/codebeamer/user_guide/ug_mass_process_suspected_changes.html
- Doorstop (fingerprinted links) — https://github.com/doorstop-dev/doorstop/blob/develop/README.md
- Kiro specs and iteration ("Sync Files") — https://kiro.dev/docs/specs/ , https://kiro.dev/docs/specs/best-practices/
- GitHub Spec Kit — https://github.com/github/spec-kit/blob/main/spec-driven.md
- Linear triage / Triage Intelligence — https://linear.app/docs/triage , https://linear.app/docs/triage-intelligence
- GitHub "changed since last view" — https://github.blog/news-insights/product-news/mark-files-as-viewed/
- Hypothesis fuzzy anchoring — https://web.hypothes.is/blog/fuzzy-anchoring/ ; W3C Web Annotation — https://www.w3.org/TR/annotation-model/
- TipTap UniqueID — https://tiptap.dev/docs/editor/extensions/functionality/uniqueid
- TVR (RAG + LLM traceability) — https://arxiv.org/html/2504.15427v4 ; ProReFiCIA — https://arxiv.org/html/2511.00262v6 ; LLM doc-to-code traceability — https://arxiv.org/html/2506.16440v1 ; embeddings vs opposites — https://arxiv.org/html/2509.09714v1 ; ChangeSumm — https://aclweb.org/anthology/2024.findings-acl.190.pdf
- Agile change handling — https://pm.stackexchange.com/a/10829/4271 , https://softwareengineering.stackexchange.com/questions/253274/
- ADR append-only — https://learn.microsoft.com/en-us/azure/well-architected/architect-role/architecture-decision-record
