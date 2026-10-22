# Phase 48 — The Object Wiki in the application page — as built

> **Status:** ✅ SHIPPED 2026-10-21 · genesis **v0.78.0** (`df9011d`) · no migration (DB v24, memory.db v1) · no new ADR
> (applies ADR-027/028/037/055/070/071). Other repos unchanged: genesis-core v0.9.8 (`CORE_MAJOR=1`), kiro-agent-sdk
> v0.7.1, genesis-appian-parser v0.3.0, genesis-workflows v0.22.0 (its `genesis` dev pin stays v0.77.0 on purpose — not
> released, needs nothing from v0.78.0).
> Spec: `specs/phase-48-object-wiki-ui.md` + `48-01..48-05` (each has its As built / As run). Reviews:
> `specs/phase-48-object-wiki-ui/reviews/48-0{2,3,4}-review.md`. Follow-ups: `specs/backlog/phase-48-follow-ups.md`,
> `specs/backlog/wiki-story-cross-link.md`.

## What changed for the user

- The application page has a new **Object Wiki** tab after Overview: every documented object (name, type, summary,
  change count, latest change + when, last author), with search, Type and Change filters and sortable headers.
- Clicking an object opens its page `/applications/:appUuid/wiki/:objectUuid`: metadata, the current summary and the
  newest-first change history, switchable Business / Technical / Both; every entry shows its change reason ("Why: …");
  story keys link to the canonical story page (ADR-071) when the story exists locally.
- Application tabs are URL-addressable (`?tab=`), so Back and deep links land on the right tab.

## Delivered (by sub-spec)

| Sub-spec | Result | Commits (genesis) |
|---|---|---|
| 48-01 | Findings + decisions D1–D8 (D8, the reason on every entry, added after the 48-03 review) | — |
| 48-02 | `kb/object_types.py` (`normalize_object_type`), `ObjectWikiStore.list_objects`/`get_object`, `api/object_wiki.py` (two GETs); 11 API + table-driven type tests; review SHIP ×2 | `940deef`, `148c064` |
| 48-03 | URL tabs, `features/object-wiki/` (tab, table, page, timeline, logic, hooks), `shared/ui/appian-object-types.ts`, types/client/keys; 34 tests; review SHIP + delta SHIP | `01288c9`, `5789f88`, `0b2ecec` |
| 48-04 | H1 (reason on every entry) + narrow-width hardening; 47 wiki tests; live acceptance 1–11 PASS (reviewer + human) | `fdc47ab` … `777e619` (7) |
| 48-05 | Release v0.78.0, CI green on master (7140928) + tag (7141042), fleet main + userb on 0.78.0; this write-back | `df9011d` |

Tests at release: genesis pytest **1187** (1105 at v0.77.0), web vitest **380** in 46 files (332).

## Review history

- **48-02:** SHIP on `940deef`; m2 (ORDER BY vs displayed `last_changed_at` diverged on `""`), m3, n1–n3 fixed in
  `148c064` (delta SHIP); m1 (Hub timestamp form) verified live in 48-04 — `julianday(created_at)` non-NULL for all 26 entries.
- **48-03:** SHIP on `01288c9`; m2 (three untested design choices) + n1–n4 fixed in `5789f88`, n5 in `0b2ecec`; m1 became
  decision D8 (show the reason on every entry), built as 48-04 H1.
- **48-04:** full review NEEDS_CHANGES (M1 narrow-window overflow), then five delta reviews: `c86ed3e` SHIP (m2) →
  `809ac29` SHIP (m3) → `64b311a` NEEDS_CHANGES (**B1 stale `web/static`**, m4) → `9d926fd` NEEDS_CHANGES (M2, caused by
  the m4 fix) → `4d2ea41` SHIP (m5) → `777e619` **SHIP (final)**. The loop ended once a real-browser geometry probe drove
  the column widths (L-090).

## Decisions and deviations (all recorded in the sub-specs; no ADR deviation)

- Ordering by `julianday(created_at)`, not string order; unparseable values last; `id` tie-break (48-02 §1).
- Story resolution: `sync_uuid` wins, else a key only when unique within the app (ambiguous legacy keys → null).
- Unlisted parser types → `type_key: "other"` with `type_raw` kept as the label.
- Wiki hooks refetch on focus explicitly (the app default is off); a 404 is not retried.
- The table scrolls inside its card below a 600 px table width rather than squeezing columns.
- 48-04 restarted :8760 on unreleased code for live acceptance (DB backed up first, no run active).
- Release: the genesis README status line was bumped too; no DB backup before the fleet update (user's call, no
  migration); `gsm provision` + `gsm restart` were issued in one batch (no effect — library unchanged).

## Lessons (write-back decisions)

| Candidate (source) | Decision |
|---|---|
| Run edit → build → commit in sequence, never in one parallel batch; prove the bundle with a fresh build + empty status (48-04) | **Added L-089** — the root cause (parallel tool batches) is new and recurred in the release (`gsm`); L-030/L-056 don't cover a bundle built from the wrong tree. L-056 gets a one-line pointer (a clean status ≠ a fresh bundle). |
| Size table columns from measured content, not percentages chosen by eye (48-04) | **Added L-090**, merged with the next row (one rule) |
| jsdom can't catch layout bugs; budget a real-browser width probe (48-04) | Merged into **L-090** |
| Sort Hub-crossing timestamps by parsed value, unparseable last, `id` tie-break (48-02) | **Extended L-084** (the Hub-timestamp lesson) with the consumer rule |
| A list's ORDER BY and its derived field from one expression (48-02) | **Extended L-039** (it is the in-query form of the same rule) |
| Shared `Select` silently drops `aria-label` (48-03) | **Deferred** — `phase-48-follow-ups.md` item 1 owns it and records the lesson when the bug is fixed |
| A hook's own `retry` shadows the test client's `retry:false`; set `retryDelay: 0` (48-03) | **Rejected** — a narrow test-harness detail, fixed in code (`0b2ecec`) and covered by this note; not a do-not-regress rule |

L-030, L-069 and L-083 were checked and held: the bundle was rebuilt and committed with every web change except
`64b311a` (B1, fixed in `9d926fd`); no `<Button asChild>`; fixtures are the 48-02 samples verbatim.

## Agent-system pilot (first real phase on the five agents)

Observations from the 48-0x As built / As run / review files and the release session:

1. Parallel tool batches broke ordering twice (48-04 B1; the release's `gsm` pair) → L-089; dev, release and review
   skills now spell out the sequencing.
2. A delta-review brief named a non-existent sha (`9e3e2b0`); the reviewer resolved HEAD (`64b311a`) and said so →
   review skill: resolve the brief's sha first.
3. The reviewer's in-tree stale-bundle build dirtied `web/static` and `git clean` is denied to it; it restored with
   `git stash push/drop` → review skill: build to `--outDir /tmp/…` and `diff -r` (the 48-03 review's method).
4. `gsm` is not on the agent shell's PATH (called as `genesis-fleet/bin/gsm`); there is no `/api/system/version`, and
   `/api/system/update`'s `current` is stale on the editable venv → the absolute path and the `/openapi.json`
   `info.version` check are in the release skill and `bible/05`. No backlog item: the existing endpoint is enough.
5. The reviewer could not drive the collaboration pull (row 10) or judge the visual half of row 11; the human did.
6. Each sub-agent review flagged "As built not yet written" (48-02 m4, 48-04 m1) because the dev writes it after the
   verdict — expected; noted in the operator guide.
7. Narrow-width UI fixes looped through five delta reviews until a geometry probe → L-090; the spec-authoring skill
   now asks for a width probe in the acceptance sub-spec for table/list UI.

Changed in `agent-system/`: skills `genesis-release`, `genesis-web-dev`, `genesis-code-review`,
`genesis-spec-authoring`; `OPERATOR_GUIDE.md` (status + §10 pilot notes). Installed copies need `agent-system/update.sh`.
