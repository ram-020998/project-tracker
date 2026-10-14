# 46-10 — Review, hardening and live acceptance

> **Status:** 🟡 DRAFTED 2026-10-14. Repos: all. Parent: `specs/phase-46-spec-change-requests.md`.

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
   "Link stories to the spec" hidden, story design launches unaffected.
7. **Collab** — strict `LocalHubProvider` rejects unknown kinds/item types; open-CR data is never published; the
   conflict merge never drops a CR change.
8. **ADR conformance** — ADR-001 (no orchestration in chat; the deterministic workflow for linking), ADR-011 (trio on
   every agent node of `spec-story-linking`), ADR-012 (no workflow import in genesis; parity test instead),
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
| 1 | Open an existing finalized feature on `main` | Spec shows **Initiate change request**, not Reopen; "Link stories to the spec" banner |
| 2 | Link stories to the spec | Run completes; badges appear; ≥ 90% of stories have a confirmed ref (user spot-check) |
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
| 13 | A feature with a completed breakdown, not finalized: CR → Apply | `breakdown.html` re-rendered with the reconciled backlog; Finalize then carries `spec_refs` |

Record evidence (run ids, revision numbers, screenshots of the document) in 46-10 §4 "As run".
