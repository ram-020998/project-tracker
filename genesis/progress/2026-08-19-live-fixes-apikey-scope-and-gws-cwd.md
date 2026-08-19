# Live fixes (2026-08-19) — sync-application APPIAN_API_KEY scope + gws --output cwd

Two runtime failures found on a real deployment (app ahead of the installed workflow / gws newly connected),
diagnosed by the user and verified against the code. Two independent patches, both CI-green.

| Fix | Repo | Release | Root cause |
|---|---|---|---|
| #1 APPIAN_API_KEY scope | genesis-workflows | **v0.9.6** (workflow **v0.2.3**) | ADR-048 version skew: app stores the key in the per-env scope; workflow read `appian-devops`/`global` only |
| #2 gws `--output` confinement | genesis | **v0.50.1** | `GwsClient` spawned gws with no `cwd`; absolute `-o` under `~/Genesis/runs/…` is outside cwd → gws 0.22.5 rejects |
| #3 document viewer hang | genesis | **v0.50.2** | `/documents/:id` rendered ~858 KB Markdown via react-markdown on the main thread → tab froze; large docs now default to a raw-source view |

## #1 — `sync-application` can't read APPIAN_API_KEY (run `r-0860e9961b20`)
**Symptom:** baseline export of "AS GSS Full Application" failed —
`APPIAN_API_KEY secret is not set (scope 'appian-devops' or 'global')`.
**Root cause (verified):** since genesis **v0.48.5** (Phase 24-01 / **ADR-048**) the core Appian creds are stored
per-environment (`env-<sha1(label)[:16]>/APPIAN_API_KEY`) and resolved **only** from the dev-tagged env via
`EnvironmentRegistry.resolve_var`; the app's startup migration relocates keys out of `appian-devops/` into the env
scope. But `sync-application` **v0.2.2** (`graph.py` `_fetch_package_zip`) called
`ctx.secrets.resolve("APPIAN_API_KEY", server="appian-devops")`, and `PlaintextProvider.resolve(var, server)`
(`genesis/config/secrets.py`) checks only `server/VAR` then `global/VAR` — never the env scope. The user verified
`env_scope("Appian Dev") == env-cca1fa2581e2d882` (where the key was stored). Pure app↔workflow version skew.
**Fix (workflow v0.2.3):** resolve the key via `ctx.environments.resolve_var("APPIAN_API_KEY")` **first** (the ADR-048
dev-env seam — `build_context` wires `EnvironmentRegistry(..., secrets=…)`, so it works in the worker), then fall back
to `ctx.secrets.resolve(...)` for pre-ADR-048 installs. Error message repointed at Settings → Environments. Bumped
`META`/`workflow.yaml`/`registry.json` 0.2.2 → 0.2.3. **+2 regression tests** (env-scope resolve with empty secrets;
missing-key message names the environment). Commit `a15efb9`, tag **v0.9.6**.

## #2 — `sync-documents` gws export fails on `--output` (document_id 1)
**Symptom:** the fetch step failed exporting the doc to `.xlsx` —
`--output '…/Genesis/runs/…/fetched/doc-1.xlsx' … is outside the current directory (validationError, code 400)`.
**Root cause (verified):** **gws 0.22.5** confines `--output` to the process cwd. `GwsClient._run`
(`genesis/integrations/gws/client.py`) spawned gws via `subprocess.run(...)` with **no `cwd=`**, so it inherited the
server's cwd (the genesis checkout where `genesis up` ran); `export_file`/`download_file` passed an **absolute** `-o`
under `~/Genesis/runs/…` → outside cwd → rejected. Surfaced only now because gws had never been connected before.
Reproduced directly: gws from the repo with `-o /tmp/…` → the 400; gws with cwd=the output's parent → passes.
**Fix (genesis v0.50.1):** `_run` takes an optional `cwd` (None = inherit — unchanged for `list`/`get`/`auth`);
`export_file`/`download_file` run gws with **`cwd=out_path.parent` + a relative `-o` (basename)** so the run-artifacts
path is always inside cwd. The isolated config dir is an absolute env var (`GOOGLE_WORKSPACE_CLI_CONFIG_DIR`), so
changing cwd is safe. **+3 regression tests** (a confining fake gws mirroring 0.22.5 for export + download; a direct
`cwd`/relative-`-o` spawn-contract assertion). Commit `276be73`, tag **v0.50.1**.

## #3 — document viewer hangs on a large doc (`/documents/4`)
**Symptom:** opening `http://127.0.0.1:8760/documents/4` hangs the tab for a long time.
**Root cause (verified):** the full-screen viewer `web/features/library/DocumentDetailPage.tsx` rendered the
entire parsed Markdown (`content_md`) via `MarkdownView` (react-markdown + remark-gfm) **unconditionally, no
size guard/virtualization**. Doc #4 is spreadsheet-derived: `content_md` **~858 KB / 3,240 lines** (longest line
8,344 chars; `tables.json` 1.5 MB). remark parses the whole blob (GFM tables are expensive) and React commits
**thousands of `<tr>`/`<td>`** to the DOM on the main thread → freeze. Not backend/network (content is sent inline
over localhost in ~ms) and not a crash — smaller docs open fine.
**Fix (genesis v0.50.2, frontend-only):** a **Rendered | Source** `SegmentedControl`. Source renders the raw
Markdown in the existing `CodeBlock` (plain `<pre>` = one text node, instant at any size); docs over
`LARGE_DOC_CHARS` (200k chars) **default to Source** so they open immediately (flip to Rendered on demand; small
docs still default Rendered). Pure default logic in `web/features/library/documentView.ts` (**+2 vitest**).
web 166 → 168 vitest, lint(0 err)/tsc/build green; `web/static` rebuilt + committed. Commit `be8a6e6`, tag **v0.50.2**.
(Future richer option: render `tables.json` as a paged/virtualized grid for spreadsheets.)

## Gates
- genesis-workflows: 14 sync-application pytest + `validate_library` (7 workflows) green. CI = validate/test only (no ruff).
- genesis: **574** backend pytest + ruff clean (571 → 574, +3 gws tests). genesis-core unchanged (v0.9.5).

## Bible updates
bible/01 (versions v0.50.1 / v0.9.6 + counts 574 / 77 [14 sync-application] + both fix notes on the repo rows),
bible/06 (two hard-won lessons: the ADR-048 credential-seam skew; the gws `--output` cwd confinement),
index + bible/00 Last-refreshed banners.

## Notes / not-done
- The user's "Appian Dev" env must be the **dev-tagged** one for `resolve_var` to find the key (ADR-048 requires that anyway).
- Deployment picks up workflow v0.2.3 via `genesis install` (or one-click Update, which runs `genesis install` — v0.48.4).
- **Related coupling (flagged, not changed):** the export node's base URL comes from the **active** env
  (`resolve_var("APPIAN_BASE_URL")`) while the key now comes from the **dev** env — consistent only when active == dev
  (which the app-detail Refresh + the scheduler both ensure by launching against the dev env). Left as-is (out of the
  reported failure's scope); revisit if a non-dev active env is ever used for this workflow.
