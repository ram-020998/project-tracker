# 46-10 — Review, hardening and live acceptance

> **Status:** ✅ BUILT + SHIPPED (genesis v0.77.0 / genesis-workflows v0.22.0, 2026-10-15; as-built in `progress/phase-46-spec-change-requests.md`) — drafted 2026-10-14. Repos: all. Parent: `specs/phase-46-spec-change-requests.md`.

## 1. Independent review (sub-agent, read-only)

A reviewer that did not build the phase checks, with file:line evidence:

1. **Nothing changes stories before Apply** — no code path writes `kb_stories`/the backlog from the chat, the analyze
   endpoint or the document endpoint; the agent's only writes are `spec.html` and `./cr/CR-n/plan.json`.
2. **Apply is atomic** — stories, revision, CR row, spec status and the m0013 audit row commit in one transaction
   (failure injection test exists and passes).
3. **Lane rule** — no path updates/removes a locked story without `user_requested` **and** the confirm list (V4 + A7).
4. **Consumer isolation** — every downstream launcher uses `_consumer_stage_html`; a grep for `_current_stage_html`
   outside the spec chat preview / milestone / normalizer paths is empty.
5. **ID stability** — the normalizer never edits text or non-`data-cid` attributes (golden test), is idempotent, and
   never reuses an ID.
6. **Old libraries** — genesis with the v0.21.0 workflow library: breakdown launches without `spec_clauses_path`,
   the feature stays legacy (Reopen, no badges), story design launches unaffected.
7. **Collab** — strict `LocalHubProvider` rejects unknown kinds/item types; open-CR data is never published; the
   conflict merge never drops a CR change.
8. **ADR conformance** — ADR-001 (no orchestration in chat; the deterministic workflow for linking), ADR-011 (trio on
   every breakdown agent node, unchanged), ADR-012 (no workflow import in genesis; parity test instead),
   ADR-031/045 (the chat proposes, Apply commits), ADR-050 (all status changes through `LifecycleService`),
   ADR-063/064 (additive contract), ADR-037 (no code stored).
9. **UX** — every disabled control explains why; every dialog says what will happen; jest-axe clean.

Findings are fixed before release; each fix gets a regression test.

## 2. Gates

genesis: pytest + ruff; web: eslint, `tsc`, vitest (incl. jest-axe), build + committed `web/static`;
genesis-workflows: `validate_library` + pytest (incl. the backlog-renderer parity test); fresh DB migrates to **v24**.

## 3. Live acceptance (merge-assist-dev, fleet `main` + `userb`)

| # | Step | Expected |
|---|---|---|
| 1 | Open an existing (legacy) finalized feature on `main` | Exactly today's behaviour: Reopen, no CR controls, no badges |
| 2 | New feature: spec → UX → TD → breakdown → finalize | Breakdown cards show "Spec: §…"; every story has spec refs; spec preview shows coverage badges and **Initiate change request** |
| 3 | Initiate CR-01 ("Accept LEI") | Status *Under change · CR-01*; chat divider; Save milestone hidden |
| 4 | Start a story design on `main` for a story of this feature | The run's `spec_path` snapshot equals revision N (not the working copy) |
| 5 | Edit 2 clauses, add 1, reword 1 cosmetically, move 1 | Normalizer keeps IDs (check `GET …/spec/clauses`) |
| 6 | Analyze impact | Document lists exactly the stories linked to the 2 edited clauses + a new-story proposal for the added clause; cosmetic + move changes listed as ignored; locked stories shown *Locked — no change* |
| 7 | In chat: "make GNS_x a follow-up instead" and "update GNS_y anyway" (a locked story) | Plan + document update; Apply dialog asks to confirm GNS_y |
| 8 | Edit the spec again | Banner: analysis out of date; Apply disabled |
| 9 | Analyze again, Apply | Stories updated/created as shown; document frozen *Applied* with real keys; spec revision N+1; UX/TD show "spec changed (CR-01)" |
| 10 | On `userb` | Updated/created stories pulled; CR-01 in the list with its document; stories show change history |
| 11 | Answer a question on `userb` | Appears on `main` after auto-pull; next design run prompt contains it |
| 12 | Initiate CR-02, edit, Discard | Spec restored byte-for-byte; no story changed; CR-02 *Discarded* in the list on both machines |
| 13 | ⏭️ skipped (user decision, 2026-10-15) | A backlog-mode CR (breakdown completed, not finalized) was not run live; covered by `tests/test_cr_apply.py::test_backlog_mode_apply` and the genesis-workflows renderer parity test (byte-identical `breakdown.html`). |
| 13 | A feature with a completed breakdown, not finalized: CR → Apply | `breakdown.html` re-rendered with the reconciled backlog; Finalize then carries `spec_refs` |

Record evidence (run ids, revision numbers, screenshots of the document) in 46-10 §4 "As run".

## 4. As run

### 4.1 Gates + whole-phase review (2026-10-15, no fleet change)
- genesis pytest **1104** + ruff clean; web tsc clean, eslint 0 errors (19 pre-existing warnings), vitest **332**,
  `npm run build` byte-identical to the committed `web/static`; genesis-workflows `validate_library` **13** + pytest
  **256** (the backlog-renderer parity test ran — not skipped — against the local genesis); a fresh DB migrates to
  **v24**.
- Hardening: the strict `LocalHubProvider` now also clears an ABSENT original story array (`acceptance_criteria` /
  `questions` / `labels`) like the live Hub (46-09 Hub report); a test asserts Genesis always sends all six arrays
  (genesis `9aa01b0`).
- Independent whole-phase review = **SHIP**, all 9 invariants of §1 **PASS** with file:line evidence (targeted suite
  205 passed); cross-sub-phase checks clear (a pulled spec can't offer CR actions; the fragment / overlay scripts accept
  only `c-` + 8 hex; CR dirs and blob keys are built from integers + uuids; CR numbering after a pull). Two NITs, both
  already-recorded deviations (best-effort "latest" file after Apply; the emulator tweak).

### 4.2 Fleet update (2026-10-15, on the user's go-ahead)
- No active runs on either instance (the memory-maintenance gate was resolved by the user first).
- Backups (SQLite online backup, sources opened read-only, both v23 + `integrity_check ok`):
  `~/Genesis/backups/phase46-pre-v24-20261015-171825/{main,userb}-genesis.db`.
- `gsm stop` both → `gsm provision --all --no-mcp --no-env --force` (genesis-workflows `e20d66e`:
  feature-breakdown-analysis 0.3.0, story-design-analysis 0.3.1, story-implementation 0.1.1) → `gsm start` both. The
  fleet runs the editable genesis checkout, i.e. genesis `9aa01b0`; startup migrated both DBs to **v24**
  (`kb_spec_change_requests` present). Both healthy; `/api/catalog` lists the new versions; collaboration enabled +
  available against the dev-env Hub; no errors in either log since startup.

### 4.3 Live acceptance (§3)
| # | Result | Evidence |
|---|---|---|
| 1 | ✅ (API) — UI look to be confirmed by the user | `main` feature 3 "Multi Round Evaluations" (finalized 2026-09-04, 72 stories, 0 linked = legacy): `/spec/allowed` → `allowed: ["reopen"]`, `downstream_locked: false`, 0 CRs; `/spec/coverage` → `traceable: false, mode: none`; served spec has 172 labels and 0 coverage badges; no stage carries `spec_changed`; `POST …/change-requests` → 409, no row written. Note: the coverage GET normalized the working copy (170 `data-cid` added — the documented 46-02 §9 side effect; text unchanged). |
| 2 | ✅ (Playwright + API) | Feature 6 "Evaluation Instructions" (`main`): spec submitted + approved, milestone rev 1; UX run `r-d945d439d221` (escalated after a self-heal, approved from another browser session), TD `r-d5ed99071d49`, breakdown `r-f9a818a124cb` (feature-breakdown-analysis 0.3.0 with `spec_clauses_path`, 49 clauses, rev 1) — all three recorded `upstream_versions.spec = rev 1`; 8 epics / 18 stories, 18/18 with `clauseRefs`, 18 cards "Spec: §…"; Finalize → 18/18 `spec_refs` (origin breakdown); spec toolbar **Initiate change request** + "Change requests (0)", no Reopen / Save milestone; preview shows labels + coverage badges (25 covered, 14 of 39 requirement clauses "no story"). Finding F1: Finalize doesn't publish the backlog (`usePublishBacklog` has no caller — pre-existing since 38-04); published by hand via `/collab/publish/*` and `userb` pulled the feature, 4 stages, 8 epics, 18 stories with `spec_refs`. |
| 3 | ✅ | CR-01 "Raise the instructions limit to 4000 characters": dialog text per §14; "Under change · CR-01", banner "CR-01 open — …", divider "CR-01 started by admin.user …", "Change requests (1)"; CR row open / stories mode / base rev 1; the Hub marker `stage_artifact` / spec sync_uuid visible from `userb` (24 h). |
| 5 | ✅ (done before 4) | One chat turn (34 s): 2 clauses edited (§4-3, §5-4 2000 → 4000), 1 added (c-de59ef23 "Show more"), 1 cosmetic (§7-2 comma → em dash), 1 moved (§8-1 → §8-3): 49/49 IDs kept, 1 new, 0 lost. |
| 4 | ❌ → fixed (F2) | Story design `r-0bdd08eb2777` for GNS_000001 snapshotted the **working copy** (4000 / "Show more"), not rev 1. Root cause: the spec stage's status had flipped `under-change` → `completed` without a transition — `main`'s auto-pull re-applied its OWN published `stage_artifact` record (published during step 2) over the local row. The pull re-delivers it because the per-kind `stage_artifact` cursor has been pinned at 459 since 2026-09-24 by a leftover Hub validation row (`bafef139…`, the `stage_artifact.json` fixture, parent feature not local → skipped forever). Fix genesis `0e371de`: a pull never re-applies a version this machine already has (published or pulled); regression test fails on the old code. |
| 4 (re-run) | ✅ | After the fix: run `r-d945…` cancelled (reports `failed` — worker exit after cancel, F3), `main` restarted, spec stage 9 repaired to `under-change` (one guarded row update, user-approved; consistent with audit row 164 + open CR-01); a forced pull + an auto-pull tick left it `under-change`. Story design `r-0aa082031405` (GNS_000001): `spec_snapshot.html` sha `243b576f…` = rev 1 = CR-01 `base.html` (no 4000 / "Show more"); `story.spec_clauses` from the base map. Its escalation gate approved by the user's decision → GNS_000001 in Design Review (locked). |
| 6 | ✅ | Analyze (103 s): affected = exactly GNS_000001 (§4-3), GNS_000007 + GNS_000008 (§5-4); new clause §7-5 with 3 candidates; §7-2 formatting + §8-3 moved listed as "Formatting-only or moved (no impact)"; the plan kept GNS_000001 `no_change` while its design ran (A6). Re-analysis after the design finished showed it **locked** ("1 unchanged (past Design)"), decisions carried forward. The agent attached §7-5 to candidate GNS_000014 instead of proposing a new story (allowed by 46-05 Q1; judgment for the user). |
| 7 | ✅ | Chat: "follow-up of GNS_000014 instead" + "update GNS_000001 anyway" → plan: new story N1 `follow_up_of` GNS_000014 for §7-5, GNS_000001 `update` with `user_requested: true`; validation ok; `locked_confirmations` = [GNS_000001]; Apply dialog lists "Change GNS_000001 (design-review) as you asked", Apply disabled until ticked. |
| 8 | ✅ | A further chat edit (§1-2) → banner "You changed the spec after the analysis.", no Apply button; `POST …/apply` → 409 ("The spec changed after the analysis — Analyze impact again"). |
| 9 | ✅ | Analyze again (4 changes) → Apply via the dialog (GNS_000001 ticked): 3 updated (GNS_000001 locked by request, `needs_design_rerun: true`; GNS_000007; GNS_000008 incl. an answer), 1 created (GNS_000019, follow-up of GNS_000014, whose log records the follow-up); spec rev 2 (note "CR-01: …"), audit `apply-change`; frozen `document.html` *Applied* with the real key GNS_000019, `result.html`, `plan.json`, `apply-report.json` (no warnings); UX + TD `spec_changed: CR-01`; published spec + 5 stories + CR-01 (0 pending, 0 errors); marker cleared. |
| 10 | ✅ (Playwright on `userb`) | Pulled: 19 stories (GNS_000001/7 updated with 4000, GNS_000019 created, change logs), CR-01 `applied` rev 2 with its document on `userb`'s disk; the pulled spec view shows "Change requests (1)" → drawer "rev 1 → 2 · 3 updated · 1 created" → the frozen document; the Story Workspace shows the Change history card. |
| 11 | ✅ | On `userb`, answered GNS_000013's question in the Story Workspace → `publish: published`; on `main` the answer arrived by auto-pull (≤ 2 min; `published_version` 1); a design run for GNS_000013 (`r-6545274053db`, cancelled after the prompt was checked) has `answered_questions:` with it + `spec_clauses_this_story_implements:` in the ticket block. |
| 12 | ✅ | CR-02 initiated, one chat edit (4000 → 6000), Discard via the dialog ("The spec goes back to revision 2. No stories change.") → working copy sha identical to before CR-02, no story row_version changed, spec `completed`, revisions [1, 2]; `userb` shows CR-02 `discarded`; marker cleared. |

**Findings so far:** F1 Finalize doesn't publish the backlog (pre-existing, `usePublishBacklog` unused); F2 own-record pull echo (fixed, genesis `0e371de`); F3 a cancelled run is reported `failed` ("worker exited abnormally", pre-existing); F4 the Hub's leftover validation rows (`bafef139…`, GH Story 120) pin the `stage_artifact` / `story` pull cursors at 459 since 2026-09-24 — harmless after F2 but every pull re-fetches them (Appian agent to delete, with the user's OK); F5 the pull's `applied` lists include already-known versions (cosmetic); F6 the sidebar still says v0.76.0 on the unreleased build (cosmetic, fixed by the 46-11 bump).

### 4.4 Outcome
Phase 46 accepted for release by the user on 2026-10-15 (steps 1–12 ✅, step 13 skipped). Fix found during acceptance:
genesis `0e371de`. Open findings → `specs/backlog/phase-46-follow-ups.md`.
