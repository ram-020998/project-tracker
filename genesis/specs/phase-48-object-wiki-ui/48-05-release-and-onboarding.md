# 48-05 — Release and onboarding

> **Status:** 🟡 §1–§2 DONE 2026-10-21 — genesis **v0.78.0** released (`df9011d`, CI 7140928 / 7141042 green) and
> deployed to main + userb; §3 docs write-back pending (genesis-docs). Repos: genesis, project-tracker. Parent: `specs/phase-48-object-wiki-ui.md`.
> After 48-04 = SHIP. **genesis-release** asks before every tag and push; then **genesis-docs** does the write-back.

## 1. Release — genesis v0.78.0 only

1. Bump `pyproject.toml` `[project].version`, the FastAPI `create_app` version and `web/src/version.ts` to **0.78.0**;
   `npm run build` and commit `web/static/`.
2. Pins unchanged: genesis-core **v0.9.8**, kiro-agent-sdk **v0.7.1**, genesis-appian-parser **v0.3.0**. No migration
   (DB **v24**). genesis-workflows is not released (its genesis dev pin may stay at v0.77.0).
3. Verify the release commit contains every changed file (L-056); tag `v0.78.0`; push (on the user's go-ahead); CI green
   on master + tag (genesis, frontend, clean-install).

## 2. Deploy

Never restart while a run is active (`GET /api/runs?status=running` on each instance first). Then the usual fleet
update (`gsm provision --all --no-mcp --no-env --force`, `gsm restart --all`); verify each instance reports 0.78.0 and
`GET /api/applications/<app>/wiki` answers.

## 3. Docs write-back (genesis-docs)

`context/state/current.md` (genesis v0.78.0, test counts, "what works" + the Object Wiki tab); code map (new
`kb/object_types.py`, `api/object_wiki.py`, `ObjectWikiStore.list_objects/get_object`, `web/src/features/object-wiki/`,
`shared/ui/appian-object-types.ts`, URL-addressable app tabs); `progress/phase-48-object-wiki-ui.md`; `changelog.md`;
README row 48 → SHIPPED; tracker §6; `bible/08` §9 pointer to `specs/backlog/wiki-story-cross-link.md`; lessons from
the build via `genesis-ctx add lesson`; note on the agent-system pilot (Phase 48 was its first real phase) in the
operator guide if anything changed. `genesis-ctx index && lint` green.

## 4. As run

### Release and deploy (2026-10-21, genesis-release) — §1–§2 ✅ DONE

- **Versions:** genesis **v0.78.0**. Unchanged: genesis-core v0.9.8 (`CORE_MAJOR=1`), kiro-agent-sdk v0.7.1,
  genesis-appian-parser v0.3.0, genesis-workflows v0.22.0 (not released; its genesis dev pin stays v0.77.0). No
  migration: DB **v24**, memory.db v1.
- **Commit:** genesis `df9011d` "release: genesis v0.78.0 - Phase 48 Object Wiki UI (no migration, DB v24; pins
  unchanged)", on top of `777e619` (the 48-04 SHIP). 65 files:
  - `pyproject.toml` `[project].version`;
  - `genesis/api/app.py` `create_app` version;
  - `web/src/version.ts`;
  - `README.md` status line (see deviation 1);
  - `web/static/` (`index.html` + 60 renamed/added/deleted assets; main chunk `index-C0g9J8MV.js`).
- **Tag:** genesis `v0.78.0` (annotated) → `df9011d`, asked and confirmed. **Push:** master `d6ee6cd..df9011d`
  (fast-forward, 13 commits: 48-02, 48-03, 48-04 and the release commit) and the tag, asked and confirmed.
- **Gates before commit** (run in sequence on the bumped tree):
  - pytest **1187 passed**; `ruff check genesis` (the CI command) clean;
  - web lint 0 errors / 20 warnings (unchanged); typecheck clean; vitest 46 files, **380 passed**;
  - `npm run build` → committed `web/static` in the release commit; after the commit, a fresh `npm run build` left
    `git status --short --untracked-files=all` empty (stale-bundle check).
- **L-056:** before committing, `git status` showed only the four sources plus `web/static`, all staged; empty after.
  `git grep 0.78.0 HEAD` hits all four sources and the bundle.
- **L-057:** `git diff d6ee6cd df9011d -- pyproject.toml genesis/db/migrations` = the version line only.
- **CI** (both on `df9011d`, all three jobs green — `genesis` (ruff + pytest), `frontend` (incl. the L-030
  stale-bundle guard), `clean-install`):

  | Pipeline | Ref | genesis | frontend | clean-install |
  |---|---|---|---|---|
  | **7140928** (#280) | master | success | success | success |
  | **7141042** (#281) | v0.78.0 | success | success | success |

- **Deploy.** Both fleet instances run from the editable dev venv (`genesis/.venv/bin/genesis`), so the code on disk
  was already `df9011d`; the restart is what loads it.
  - Before: `GET /api/runs?status=running` → `total: 0` on both (checked twice, the second time right before the
    update). main (:8760) reported 0.77.0 with the wiki API live (it ran `777e619`); userb (:8761) reported 0.77.0
    and answered the wiki route with the generic `/api` 404 (pre-Phase-48 server code).
  - `gsm restart --all` (main pid 60492 → 45597, userb 38150 → 45769) and
    `gsm provision --all --no-mcp --no-env --force` (13 workflows @ `local` into each state dir, unchanged versions).
    `gsm` is not on the agent shell's PATH; called as `genesis-fleet/bin/gsm`. gsm restarts each instance with its
    registry env (`~/.genesis-fleet/config.json`: collab on, provider `appian`, the Hub app); `gsm status` shows
    both healthy, collab on.
  - After (read-only probe `/tmp/genesis-release-48/verify.py`, not committed):

    | Instance | Version (`/openapi.json`) | `GET …/<GSS app>/wiki` | Untracked uuid | Running runs | DB | SPA |
    |---|---|---|---|---|---|---|
    | main :8760 (`~/.genesis`) | **0.78.0** | 200, 21 objects | 404 `Application '…' not tracked` | 0 | v24, memory v1 | `index-C0g9J8MV.js`, `no-cache, must-revalidate` (L-068) |
    | userb :8761 | **0.78.0** | 200, 21 objects | 404 `Application '…' not tracked` | 0 | v24, memory v1 | `index-C0g9J8MV.js` |

    GSS app = `_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416` (AS GSS Full Application, tracked on both).
- **Deviations:**
  1. **README status line bumped** to "v0.78.0 (Phase 48 Object Wiki UI, 2026-10-21) / Phases 1–48 are complete",
     beyond the three listed places — the v0.77.0 release commit did the same and the release skill says to catch
     every occurrence of the version string. `docs/INSTALL.md` untouched (no upgrade step to describe).
  2. **No DB backup before the fleet update** — skipped on the user's instruction (no migration in this release).
  3. **`gsm provision` and `gsm restart` were issued in one tool batch, and the restart ran first.** No effect: the
     reinstalled library is identical (genesis-workflows unchanged at v0.22.0) and a running server loads the library
     at run start. Web lint and typecheck were likewise run in one batch (both read-only). Edit → build → commit were
     strictly sequential.
  4. **`ruff check .`** (whole repo) reports 28 pre-existing findings in `tests/` and `scripts/` (E702, F401, F811,
     E401). CI runs `ruff check genesis`, which is clean; nothing changed there in Phase 48.
- **Deferred / follow-ups:** none from the release. Docs write-back (§3) is genesis-docs'.

## Context manifest

```toml
areas    = ["release-ci"]
adrs     = ["ADR-019"]
lessons  = ["L-030", "L-056", "L-057", "L-068"]
docs     = ["tracker:specs/phase-48-object-wiki-ui.md",
            "tracker:specs/phase-48-object-wiki-ui/48-04-review-and-acceptance.md"]
code     = ["genesis/pyproject.toml", "genesis/genesis/api/app.py", "genesis/web/src/version.ts",
            "genesis/web/static/**"]
upstream = ["48-04"]
```
