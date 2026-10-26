# 49-08 — Review, hardening and live acceptance

> **Status:** SPEC-DRAFTED 2026-10-26. Repos: genesis, genesis-workflows. Parent: `specs/phase-49-test-design.md`.
> Run by **genesis-review** (read-only on code) after 49-02..49-07 are BUILT; report in
> `specs/phase-49-test-design/reviews/49-08-review.md` with SHIP / NEEDS_CHANGES. Findings are fixed by genesis-dev
> before release; each fix gets a regression test.

## 1. Independent review (file:line evidence for each; plus `genesis-ctx check --since <phase base>` per repo)

1. **Stage plug-in only** — `test_design` added via `VALID_STAGES`, `ArtifactKind`, one `_Binding`, one
   `ChatModeProfile`, one `STAGE_DEFS` row + `gate`, one registry entry; no shell edits (ADR-056).
2. **Gate on both sides** — start/re-run/top-up 409 before stories are finalized; the card is locked (L-063).
3. **Finalize once** — `finalized_at` guard; ids allocated inside the tx in document order; re-run/Reopen refused after
   (R5); a garbled document → 422, never a partial suite.
4. **Ids** — `TC-`/`TS-` from `kb_sequences`, never reused/renumbered (D4).
5. **Lifecycle** — every status change through `LifecycleService` (ADR-050); retire-while-referenced refused;
   hard delete only Draft + unreferenced (D15).
6. **Links** — no FK to `wiki_object_pages`; no stub wiki pages created (D5, ADR-070); a hallucinated UUID can't become
   resolved (R3); derived states computed on read (R2).
7. **D7 linker** — deterministic, idempotent, never blocks the implementation lane move; startup reconcile (L-058).
8. **Impact** — read-only; current edges only; no 200 cap; depth clamp; retired excluded; R1 honoured.
9. **Workflow** — reliability trio on every agent node (ADR-011, `validate_library`); healing bounds; read-only
   allowlists; no giant emission (L-064); per-epic map + single scenario turn (L-076); JSON contract = 49-03 §4.
10. **Chat** — read-only + sandboxed fs only (ADR-031/045); `_STEERING_TEST` keeps JSON ↔ HTML in sync.
11. **Web** — existing primitives/tokens only (ADR-027/055), no `<Button asChild>` (L-069), `/api` central (ADR-028),
    types = contract fixtures (L-011), jest-axe clean, `aria-sort` on sortable headers.
12. **Naming** — no new `test_*.py` / `*_test.py` modules outside test folders (R6).
13. **No Hub / collab change** (D12); collab columns present.

## 2. Gates

genesis: `pytest` + `ruff`; fresh DB migrates to **v25**, a v24 DB upgrades with rows preserved. web: `lint`,
`typecheck`, `vitest` (incl. jest-axe), `npm run build` byte-identical to the committed `web/static`.
genesis-workflows: `validate_library` + `pytest workflows`.

## 3. Live acceptance (local `genesis serve` :8760, the new workflow installed with `genesis install`, a real tracked app)

| # | Step | Expected |
|---|---|---|
| 1 | Open a feature whose stories are **not** finalized | Test Design card locked "Stories must be finalized"; `POST …/test_design/start` → 409 |
| 2 | Feature with finalized stories → Start (notes + 1 doc) | Run starts ("Test Design Preparation"); graph shows the per-epic loop + scenario node |
| 3 | Run completes | Stage in-review; completion chat opens with `test-design.html`; document shows scenarios + cases + embedded JSON |
| 4 | Ask the chat to add a negative case and move it into a scenario | Visible cards **and** embedded JSON both updated |
| 5 | Mark completed → **Finalize tests** | `TC-`/`TS-` ids in document order; Tests tab shows the tree; dropped keys reported (if any) |
| 6 | Re-run / Reopen after Finalize | Both refused with the R5 message |
| 7 | Case page: edit Gherkin, change stories, add a planned object by name, retire a case used by a scenario | Edit saved; retire refused naming the scenario; remove from scenario → retire OK; Restore keeps the key |
| 8 | Edit a linked story's acceptance criteria | Its cases show **Needs review** on the case page, story page and Tests tab; Mark reviewed clears it |
| 9 | Implement a linked story through the Workbench (or replay an implementation fixture run) | Its cases gain the changed objects (origin implementation); matching unresolved links resolve |
| 10 | Run a KB sync after a manual change to a linked object in Appian | Test Impact → KB sync source lists that object as modified and its cases as direct hits; indirect hits at 2 hops; depth 1 removes them |
| 11 | Test Impact → Objects source with an interface many cases depend on | Direct-first ordering, Via paths shown, totals correct |
| 12 | Object Wiki page of an implemented object | Tests section lists its cases; "Check test impact" pre-picks it |
| 13 | Generate tests for uncovered stories (add a story manually first) | Proposals list; reject a new case → its dependent step auto-rejected; Apply creates Ready records with new ids |
| 14 | Export CSV | Opens in a spreadsheet: one row per case, multi-line Gherkin intact |
| 15 | **Real-browser width probe (L-090):** Tests tab Cases table and the Test Impact table at 1280, 1440, 1920 px, light and dark | No clipped key/title columns, no horizontal scroll at ≥ 1280; record measured column widths |
| 16 | Restart `serve` mid top-up run (no active design run) | Top-up row reconciles to ready/failed on startup (L-058) |

## Context manifest

```toml
areas    = ["features-stages", "stories-workbench"]
adrs     = ["ADR-011", "ADR-031", "ADR-045", "ADR-050", "ADR-056", "ADR-060", "ADR-067", "ADR-070", "ADR-072"]
lessons  = ["L-011", "L-058", "L-063", "L-064", "L-069", "L-076", "L-089", "L-090"]
code     = ["genesis/genesis/kb/testdesign.py", "genesis/genesis/services/testimpact.py"]
docs     = ["tracker:specs/phase-49-test-design.md"]
upstream = ["49-02", "49-03", "49-04", "49-05", "49-06", "49-07"]
```
