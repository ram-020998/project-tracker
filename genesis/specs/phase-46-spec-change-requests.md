# Phase 46 — Spec Change Requests & Story Traceability

> **Status:** ✅ **SHIPPED 2026-10-15 — genesis v0.77.0 → genesis-workflows v0.22.0 (+ the Genesis Hub contract addition, live-validated 41/41); CI green — genesis #7087827 (master) + #7087831 (v0.77.0 tag), genesis-workflows #7087975 + #7087976 (v0.22.0); ADR-075/076 Accepted; m0024 → DB v24** (spec-drafted 2026-10-14; as-built: `progress/phase-46-spec-change-requests.md`). · **Author:** Genesis agent.
> Sub-specs: `phase-46-spec-change-requests/46-01..46-11`. Findings (research + every decision):
> `46-01-findings.md`. New ADRs (**Proposed**): **ADR-075** (spec clause model + story↔spec trace links) and
> **ADR-076** (spec change requests). Repos: **genesis**, **genesis-workflows**, and the **Genesis Hub** Appian app
> (additive fields, built by the separate write-capable agent).

## 1. Why this phase exists

A feature's **Spec** is not final when the stories are created. In daily stand-ups developers ask the PO the open
questions on their stories, and the answers regularly change the spec. Today Genesis cannot tell which of a
feature's (often 100+) stories a spec change affects, has no controlled way to change a spec after the stories
exist, and keeps no record of what was decided. A completed spec can simply be **reopened** and edited; the
stories, the breakdown, the UX Design and the Technical Design silently drift from it. Worse, every downstream run
(story design, implementation) reads the spec's **working copy**, so half-finished PO edits leak into developer runs.

## 2. Goal

1. **Traceability** (for features whose breakdown runs after this release — existing stories are left as they are,
   D19). Every section and requirement clause of a spec has a stable hidden ID. Every story records the
   clauses it implements (captured when the breakdown creates it). The spec preview shows how many stories cover
   each clause and which clauses no story covers.
2. **Change requests (CRs).** After the breakdown is done, the spec is changed only through a numbered change request
   (**CR-01, CR-02, …**) that the PO drives entirely from the spec's **existing chat**:
   **Initiate change request → edit the spec in the chat → Analyze impact → refine in the chat → Apply changes**
   (or **Discard change request**).
3. **Impact analysis document.** **Analyze impact** produces a **"CR-0n Impact Analysis"** document: changed
   clauses (before/after), every affected story with a proposed decision and its reason, drafted story changes,
   drafted new stories, stories that are not touched because they are past Design, and uncovered requirements.
4. **Apply exactly what was agreed.** **Apply changes** executes the agreed plan in one transaction: stories updated,
   follow-up/new stories created, story change histories written, the document frozen as *Applied*, the spec back to
   *Completed* with a new revision, UX/TD flagged "spec changed".
5. **A record everywhere.** The spec lists all its CRs; every story shows the clauses it comes from and the CRs that
   changed it; story questions can be answered (by a person or by an applied CR).

## 3. Decisions (locked with the user, 2026-10-14 — detail and rationale in `46-01-findings.md` §5)

| # | Decision |
|---|---|
| D1 | **Option B:** hidden clause IDs repaired by program code, links captured at breakdown time, content fingerprints for change detection, AI-assisted per-story decisions. |
| D2 | Before the Feature Breakdown is **completed** (or stories finalized) the spec lifecycle is unchanged (Draft → In progress → In review → Completed, Reopen). |
| D3 | Once the breakdown is completed or stories are finalized, a Completed spec offers **Initiate change request** instead of **Reopen**. |
| D4 | Initiating opens **CR-n** (numbered per feature) and moves the spec to the new status **Under change**. One open CR per spec. |
| D5 | The PO edits the spec in the **same chat** as today. **One chat per spec** — no separate CR chats; each CR starts with a visible divider and fresh context files. |
| D6 | **Analyze impact** → the agent proposes a decision per affected story; the discussion happens in the chat. |
| D7 | **Apply changes** is the only step that changes stories/backlog. Nothing is changed before it. Afterwards the spec goes **straight to Completed** (no second review). |
| D8 | The agent maintains a **structured plan**; it never writes stories. Program code validates the plan and applies exactly it. |
| D9 | Facts (changed clauses, linked stories, lanes) are computed by **program code** and given to the agent as files; the agent judges. |
| D10 | A plan is **out of date** if the spec changed after the analysis; Apply is disabled until Analyze impact runs again. |
| D11 | While a CR is open, every downstream consumer reads the **last completed revision**, never the working copy. |
| D12 | **Discard change request** reverts the spec to the last completed revision and changes no stories. |
| D13 | **Backlog mode:** if the breakdown is completed but the stories are not finalized, the CR updates the **breakdown's backlog** instead of story records. |
| D14 | **Lane rule:** stories in **To Do** or **Design** may be updated by the plan. Stories in **Design Review or later** are listed as affected but are **not touched unless the user explicitly asks** in the chat. |
| D15 | Analyze impact creates a **"CR-0n Impact Analysis" document** per CR, shown next to the spec in the preview (tabs). It is rendered by program code from the plan; frozen as *Applied* or *Discarded*. The spec page lists all CRs. |
| D16 | **UX Design and Technical Design** show "Spec changed since this was produced (CR-n)" after an applied CR. |
| D17 | **Additive Hub fields** are allowed; **story questions get answers**. |
| D18 | No "raise change request from a story" button. |
| D19 | **Existing stories are left as they are.** No backfill/linking of stories created before Phase 46; traceability and change requests apply only to breakdowns produced after this release (a *traceable* feature). Legacy features keep today's behaviour (Reopen). |

## 4. Current state (code-grounded — full detail in `46-01-findings.md` §2)

| Area | Today | File(s) |
|---|---|---|
| Spec storage | `kb_feature_stages` (stage `spec`) + milestone `kb_feature_stage_revisions`; working copy in the chat sandbox; `html_path` set only on milestone | `genesis/kb/stages.py`, `genesis/api/features.py:420-442, 602-612` |
| Spec lifecycle | `SPEC_TRANSITIONS` shared by all stages; `completed –reopen→ in-progress`; `allowed()` ignores preconditions | `genesis/domain/transitions.py:22-49`, `genesis/domain/lifecycle.py:79-86, 181-201` |
| Spec structure | Free HTML; steering has no ID/numbering rule | `genesis/chat/mode_profile.py:75-90` |
| Downstream reads | Every launcher snapshots `_current_stage_html` (sandbox first) | `genesis/api/features.py`, `genesis/api/workbench.py:69-85, 218, 325` |
| Breakdown | Reads flattened text; backlog stories carry no spec reference | `genesis-workflows/workflows/feature-breakdown-analysis/graph.py:166-189, 272-296, 632-679` |
| Stories | `kb_stories` (m0016/19/20/22); `questions` is `string[]`, no answers; finalize drops `workstreamRef` (bug) | `genesis/kb/stories.py:85-131, 155-178` |
| Staleness | `upstream_versions_json` never written; "spec changed" badge never mounted | `genesis/db/migrations/m0019_collab.py`, `specs/phase-38-collaborative-sdlc/38-04-deferred-ui-notes.md` |
| Chat notes | `enqueue_system_turn` never reaches a live agent | `genesis/chat/manager.py:236-243, 576-583` |
| Collab | `story` json_cols → `GH Story Item` (`item_type ac|question|label`) | `genesis/collab/service.py:86-107`, contract `genesis-hub-api.md` §2.2 |

## 5. The user experience (summary — full detail in `46-07-web-experience.md`)

```
Spec: Completed ─[Initiate change request]─▶ Under change · CR-03
  chat:  ─── CR-03 started by ram · 14 Oct 14:50 ───            (divider; agent gets context files)
         PO: "Corporate applicants may also give an LEI instead of a registration number."
         agent edits spec.html (preview shows the working copy)
  header: [Analyze impact]  [Discard change request]
         ─▶ "CR-03 Impact Analysis" document opens (Preview → tab "CR-03 Impact Analysis")
         PO: "Make GNS_000057 a follow-up story instead"  → agent updates the plan → document refreshes
  header: [Apply changes]   (confirm dialog: "Update 2 · Create 1 · Leave 2 unchanged (past Design)")
         ─▶ stories updated/created · CR-03 frozen "Applied" · spec Completed (revision 7)
```

The **spec preview** gains clause numbers in the margin (`§3.2-1`), a story-count badge per clause, a hollow
"no story" badge for uncovered clauses, and a popover listing the stories behind a badge.

## 6. Design overview

```
                  ┌──────────── program code ─────────────┐     ┌──── agent (spec chat) ────┐
spec.html ──(post-turn normalizer: assign/repair data-cid)──▶ clause map (IDs, labels, fingerprints)
                                                              │
Breakdown run ◀── clause-tagged spec text ────────────────────┘
   └─ stories carry clauseRefs ──finalize──▶ kb_stories.spec_refs (clause_id + fingerprint)

CR-03:  Analyze impact ─▶ diff(base revision, working copy) ─▶ impact-input.json ─▶ agent writes plan.json
        plan.json ─(validate + render)─▶ "CR-03 Impact Analysis" document (live, Lavish-annotatable)
        Apply changes ─▶ one transaction: stories/backlog + spec_refs + change_log + spec revision + CR status
                       ─▶ publish (collab) ─▶ UX/TD "spec changed" badges
```

| Building block | Sub-spec |
|---|---|
| Clause model: `data-cid` IDs, post-turn normalizer + ID repair, fingerprints, labels, clause map, preview overlay | 46-02 |
| Story↔clause links: breakdown `clauseRefs`, finalize → `spec_refs`, coverage API, workstream bug fix, traceable vs legacy features | 46-03 |
| CR lifecycle: `under-change` status + transitions, CR table, open/discard/list endpoints, consumer isolation, agent-visible chat notes, CR context files | 46-04 |
| Impact analysis: deterministic diff, `impact-input.json`, the plan schema + validator, the CR document renderer, staleness | 46-05 |
| Apply and discard: the transactional apply, backlog mode (re-render `breakdown.html`), freezing, publishing | 46-06 |
| Web experience: spec workspace controls, CR banner, preview tabs, CR list, coverage overlay, apply/discard dialogs | 46-07 |
| Story answers, story change history + spec references, design-out-of-date flags, UX/TD "spec changed" badges | 46-08 |
| Collaboration & Hub contract additions | 46-09 |
| Review, hardening, live acceptance | 46-10 |
| Release | 46-11 |

## 7. Data model — migration m0024 (`current_version` 23 → 24)

Additive + idempotent (guarded `ADD COLUMN`, `CREATE TABLE/INDEX IF NOT EXISTS`). Full DDL in 46-04 §3.

| Change | Purpose |
|---|---|
| `kb_stories.spec_refs TEXT` (JSON array) | the clauses a story implements: `{clause_id, fingerprint, origin, linked_at}` |
| `kb_stories.answers TEXT` (JSON array) | answered questions: `{question, answer, answered_by, answered_at, source, cr_no}` |
| `kb_stories.change_log TEXT` (JSON array) | the CRs that affected the story: `{cr_no, cr_sync_uuid, decision, summary, clause_ids, at, by, …}` |
| `kb_spec_change_requests` (new table) | one row per CR: number, status (`open`/`applied`/`discarded`), base/result revision, analysis state, file paths, counts, `sync_uuid`, `row_version` |
| partial unique index `WHERE status='open'` on `(stage_id)` | at most one open CR per spec |
| `kb_feature_stages.status` value `under-change` | new spec status (no schema change; `StageStore.VALID_STATUSES` += `under-change`) |
| `kb_feature_stages.upstream_versions_json` | now **written** at UX/TD/breakdown launch: `{"spec": {"revision_no", "content_hash"}}` (no schema change) |

Files: CR working files live in the spec chat sandbox under `./cr/CR-03/`; frozen copies under
`~/.genesis/feature-stage-artifacts/<spec_stage_id>/change-requests/CR-03/` (46-04 §4).

## 8. Lifecycle (full table in 46-04 §2)

| From | Action | To | Precondition |
|---|---|---|---|
| `completed` | `reopen` | `in-progress` | **not** `downstream_locked` (unchanged behaviour before breakdown) |
| `completed` | `initiate-change` | `under-change` | stage is `spec` **and** `downstream_locked` |
| `under-change` | `apply-change` | `completed` | called by the CR apply service only |
| `under-change` | `discard-change` | `completed` | called by the CR discard service only |

`downstream_locked` = the feature is traceable **and** (its breakdown stage is `completed` **or** `kb_features.stories_finalized_at` is set).
`downstream_locked` applies only to **traceable** features (46-03 §7); a legacy feature keeps Reopen.
`LifecycleService.allowed()` becomes precondition-aware so the UI never shows an action that would fail.

## 9. API surface (detail in the sub-specs)

| Method + path | Purpose | Sub-spec |
|---|---|---|
| `GET /features/{id}/spec/clauses?revision=` | clause map (IDs, labels, kinds, fingerprints, text) | 46-02 |
| `GET /features/{id}/spec/coverage` | per clause: linked stories / backlog items; uncovered clauses | 46-03 |
| `GET /features/{id}/change-requests` | list CRs | 46-04 |
| `POST /features/{id}/change-requests` | initiate a CR (`{title?}`) | 46-04 |
| `GET /features/{id}/change-requests/{cr_no}` | CR detail (status, staleness, plan validation, counts) | 46-04/05 |
| `POST /features/{id}/change-requests/{cr_no}/analyze` | deterministic impact input (then the web sends the chat turn) | 46-05 |
| `GET /features/{id}/change-requests/{cr_no}/document` | the CR document HTML (live or frozen; Lavish-injected) | 46-05 |
| `GET /features/{id}/change-requests/{cr_no}/plan` | plan JSON + validation result | 46-05 |
| `GET /features/{id}/change-requests/{cr_no}/export.md` | Markdown export of the document | 46-05 |
| `POST /features/{id}/change-requests/{cr_no}/apply` | apply (`{confirm_locked_story_ids: []}`) | 46-06 |
| `POST /features/{id}/change-requests/{cr_no}/discard` | discard | 46-06 |
| `POST /features/{id}/stories/{sid}/answers` · `PATCH`/`DELETE …/answers/{index}` | answer / edit / reopen a question | 46-08 |
| `POST /features/{id}/stages/{stage}/spec-reviewed` | dismiss the "spec changed" badge on UX/TD | 46-08 |

## 10. Sub-phase ledger

| Sub-phase | Repo(s) | Content |
|---|---|---|
| **46-01** | docs | Findings + decisions + ADR-075/076 drafted (this set) |
| **46-02** | genesis | Clause model: steering rules, `kb/spec_clauses.py` (extract, normalize, repair, fingerprint, label), post-turn normalizer hook, clause-map API, preview overlay data |
| **46-03** | genesis-workflows, genesis | `feature-breakdown-analysis` v0.3.0 (`spec_clauses_path` input, clause-tagged spec text, `clauseRefs`, validator + coverage critic); finalize → `spec_refs`; `workstreamRef` fix; coverage API; `is_traceable` (legacy features unchanged) |
| **46-04** | genesis | m0024; `under-change` + transitions + precondition-aware `allowed`; `SpecChangeStore`; open/list/get/discard endpoints; consumer isolation; agent-visible chat notes; CR context files + divider |
| **46-05** | genesis | `kb/spec_diff.py`; analyze endpoint → `impact-input.json`; plan schema + validator; CR document renderer + endpoints; staleness |
| **46-06** | genesis (+ genesis-workflows parity test) | `SpecChangeService.apply/discard`; backlog mode with `kb/backlog_doc.py` (renderer port) + parity test; freezing; publish hooks |
| **46-07** | genesis (web) | Spec workspace CR controls + banner; preview tabs; CR list; coverage overlay + popover; apply/discard dialogs |
| **46-08** | genesis (+ genesis-workflows prompts) | Story answers API + UI; story spec references + change history UI; design-out-of-date flag + re-run; UX/TD "spec changed" badges; answers passed to story design/implementation |
| **46-09** | genesis + Hub | `spec_change_request` record kind + document blob; `GH Story Item` `item_type` += `spec_ref`, `answer`, `change`; bindings; advisory marker; contract addition + fixtures |
| **46-10** | all | Independent review + hardening + live acceptance |
| **46-11** | all | Release (genesis → genesis-workflows), ADR-075/076 → Accepted, docs, fleet redeploy |

Suggested build order: 46-02 → 46-03 → 46-04 → 46-05 → 46-06 → 46-08 → 46-07 → 46-09 → 46-10 → 46-11 (46-09's Hub
build can run in parallel once 46-04/46-08 freeze the field shapes).

## 11. Release plan

ADR-019 order: **genesis v0.77.0** (m0024 → DB **v24**) → **genesis-workflows v0.22.0** (re-pins genesis v0.77.0;
`feature-breakdown-analysis` 0.3.0, `story-design-analysis` / `story-implementation` prompt additions). genesis-core, kiro-agent-sdk and the parser are unchanged. The Hub additions (46-09) are built and
live-validated **before** the genesis release. genesis tolerates an older installed workflow library: it passes
`spec_clauses_path` only when the installed `feature-breakdown-analysis` declares it (an older library produces
legacy, untraced breakdowns).

## 12. Scope

**In:** everything in §3 and §10. **Out:** linking or backfilling stories created before Phase 46 (D19). **Deferred:** CRs on UX Design / Technical Design / the breakdown document
itself; automatic re-run of story designs; partial apply (apply some decisions, keep the CR open); multiple
concurrent CRs on one spec; Jira push of CR changes; per-clause comments/threads; clause-level links from UX/TD
artifacts; enforcing the lane rule on manual story edits outside a CR.

## 13. Defaults — ✅ confirmed by the user 2026-10-14 (all five as written; asked one by one)

*(Heading was "Defaults to confirm at build sign-off (chosen by the assistant — `46-01-findings.md` §6)".)*

| # | Default |
|---|---|
| Q1 | The spec is locked for CRs when the breakdown is **completed** or stories are **finalized** (a breakdown *in review* keeps normal Reopen). |
| Q2 | Clause numbers are **computed** at render and shown in the preview margin (`§3.2-1`); never stored in the HTML. |
| Q3 | New stories: epic = the followed-up story's epic (or the agent's proposal); status **To Do**; on the board if the followed-up story is (or, for a brand-new story, if any story of the feature is). |
| Q4 | Removed clauses: affected stories flagged, default **no change**; the user may ask to update or **remove** a To Do / Design story. |
| Q5 | A CR title ("What's changing?") is optional. |

*(Former default "link existing stories with a one-time AI action" was dropped: existing stories are left as they are, D19.)*

## 14. Risks

| Risk | Mitigation |
|---|---|
| The agent drops or duplicates `data-cid` attributes | The program normalizer repairs IDs after every turn (exact → fuzzy match), never trusts the agent; unmatched old IDs are reported as removed clauses (46-02) |
| A noisy diff (formatting) flags many stories | Formatting-only changes are auto-cleared deterministically; moves are not changes (46-05) |
| The agent forgets an affected story | Validator requires exactly one decision for every affected item; Apply is disabled until complete (46-05) |
| Apply races with teammates / running designs | Per-story `row_version` + run-state checks at Apply; 409 lists the stale rows (46-06) |
| Long chat loses context after compaction | Context is in files (spec, impact input, plan, prior CR documents); each CR re-seeds them (46-04) |
| Half-edited spec leaks into developer runs | Consumer isolation: base revision while Under change; milestone saves disabled during a CR (46-04 §6) |
| Hub contract drift | Additive item types + one new kind, live-validated round-trip before release (46-09) |
| Deleting a story by mistake | Remove allowed only for To Do / Design (or explicit request); the frozen plan keeps a full snapshot of removed stories (46-06) |

## 15. ADR summaries (full text in `reference/decision-log.md`)

- **ADR-075 (Proposed) — Spec clause model and story↔spec traceability.** Spec sections/clauses carry stable hidden
  `data-cid` IDs assigned and repaired by program code; stories record the clauses they implement (`spec_refs` with
  content fingerprints), captured at breakdown time; coverage is shown in the spec preview. Amends ADR-042 (spec
  structure), ADR-059 (breakdown output), ADR-060 (finalize carries references).
- **ADR-076 (Proposed) — Spec change requests.** After the breakdown, a spec changes only through a numbered CR
  driven from the spec's chat; a program-computed impact input, an agent-maintained plan, a program-rendered CR
  document, and a program-executed atomic Apply (the human confirmation). Adds the `under-change` status (amends
  ADR-050's spec machine), isolates downstream consumers, records history on stories and CRs, and extends the Hub
  contract additively (ADR-063/064). Refines ADR-031/045: the chat proposes, the Apply button commits.
