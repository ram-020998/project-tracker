# Phase 46 — Spec Change Requests & Story Traceability — progress (as-built)

> Spec: `specs/phase-46-spec-change-requests.md` (+ `46-01..46-11`). ADR-075/076 **Proposed** (Accepted at the 46-11 release).
> Build started 2026-10-14 on the user's go-ahead. Code commits are **local only** (no push/tag until the 46-11 release
> go-ahead). The umbrella §13 defaults (Q1–Q5) are still to be confirmed; nothing built so far depends on them.

## Ledger

| Sub-phase | Status | Commits (local) | Review |
|---|---|---|---|
| 46-01 findings | ✅ done (2026-10-14) | docs only | — |
| 46-02 clause model | ✅ built (2026-10-14) | genesis `196e78d` | SHIP |
| 46-03 story↔spec links | ⏳ next | — | — |
| 46-04 CR lifecycle | — | — | — |
| 46-05 impact analysis | — | — | — |
| 46-06 apply / discard | — | — | — |
| 46-08 story answers / history / badges | — | — | — |
| 46-07 web | — | — | — |
| 46-09 collaboration / Hub | — | — | — |
| 46-10 review + acceptance | — | — | — |
| 46-11 release | — | — | — |

## 46-02 — the spec clause model (genesis `196e78d`)

**What was built**
- `genesis/kb/spec_clauses.py` (new, pure): block extraction per 46-02 §3 (sections `h2`–`h4`; clauses `p` not inside
  another block, `li` with its own text only, body `tr` [not `thead`/`tfoot`, not a leading all-`th` row], `dt`/`dd`,
  `blockquote`, `pre`; excludes `head`/`header`/`nav`/`footer`/`script`/`style`/`h1`/`data-gn-ignore` and empty blocks),
  `normalize_text` / `fingerprint` / `formatting_key` (§5), computed labels with the virtual section 0 and skipped-level
  rule (§6), `normalize_spec(html, previous, registry)` (§7: keep → duplicate resolution → exact re-anchor → fuzzy
  re-anchor 0.85 in-section / 0.92 document-wide, sections first → mint, never reusing a registry/previous/foreign ID) with
  a `RepairReport`, `clause_map(html)`, and `overlay_labels(html, coverage=None)` for the served copy (§11).
- `genesis/services/spec_clauses.py` (new): `SpecClauseService` — normalizes the agent's sandbox `spec.html` in place
  (atomic, only when changed) against `<stage_id>/working/last-normalized.html` (fallback: latest revision, then
  `html_path`), keeps `working/clause-registry.json` (every ID ever issued, removed ones flagged), all under a per-spec
  `path_lock`.
- `ChatModeProfile.post_turn` + `ChatManager.register_post_turn_hook`: `feature_spec` runs the `spec_clauses` hook
  after every non-command turn, via `asyncio.to_thread`, after the assistant message is persisted and while the session
  lock is held; a failure is logged with the traceback and never breaks the turn.
- `_STEERING_SPEC` gains the **Structure** paragraph (one requirement per element; never touch `data-cid`).
- `StageStore.get_by_chat_session`.
- API: both milestone routes for the spec normalize first (every revision carries IDs); `GET /features/{id}/spec/clauses
  ?revision=working|<n>` (409 no content, 400 bad revision, 404 unknown revision); the spec artifact routes
  (`/spec/artifact`, `/stages/spec/artifact`) add render-only `data-gn-label` + a margin stylesheet (`labels=0` turns it
  off). Coverage badges are supported by `overlay_labels(coverage=…)` and get wired when the coverage API lands (46-03).
- `beautifulsoup4==4.15.0` pinned directly.

**Deviations from the spec (deliberate)**
- The normalizer edits only the start tags of the blocks it touches instead of re-serializing with BeautifulSoup, so all
  other markup stays byte-identical (re-serialization remains as a fallback if a source position can't be verified).
- `data-gn-ignore` is not stripped (it is the author's exclusion marker); every other `data-gn-*` is.
- A table row's overlay label goes on its first cell (a `tr` can't render the margin pseudo-element).
- `tfoot` rows are not clauses (totals/footers), in addition to `thead` rows.
- `GET …/spec/clauses` defaults to `working`; the "consumer version" default arrives with change requests (46-04 §6).
- The real-spec fixture is not committed (business content). Instead: a synthetic spec + 8 awkward-markup cases are
  committed, and the two live specs in `~/.genesis` were checked read-only (169 and 100 blocks: byte-identical apart from
  the IDs, rendered text identical, idempotent).

**Evidence**
- genesis pytest **959** passed (was 923; +36: `tests/test_spec_clauses.py` 28, `tests/test_spec_clauses_api.py` 8) +
  ruff clean. No web change (the preview UI is 46-07), so web gates were not affected.
- Independent review = **SHIP**; its findings folded in (tfoot rows, duplicate `data-cid` on one tag, awkward-markup
  regression tests, a comment on the GET side effect). Reviewer timing: a 500-block spec with every ID dropped and 30%
  reworded re-anchors 500/500 IDs in ~95 ms.
- Not verified: a live agent turn in a running `genesis serve` (the server needs a restart to load the hook; no restart
  done — the fleet is not updated mid-phase).
