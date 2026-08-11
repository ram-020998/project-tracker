# 19-08 — Release + acceptance

> **Status:** ✅ **SHIPPED.** genesis-core **v0.9.2** → genesis **v0.44.0** → genesis-workflows **v0.9.3**, committed + tagged +
> pushed in dependency order; all three CI pipelines green (incl. the genesis `frontend` stale-bundle guard). ADR-040/041 →
> Accepted. Live acceptance passed (a real Drive `.xlsx` added → auto-synced via `gws` → parsed → viewed full-screen). See
> `progress/phase-19-document-library.md`. **Repos:** genesis-core → genesis → genesis-workflows.

## Goal
Ship Phase 19 as a coherent release, verify end-to-end against a real Drive document, and update all docs.

## Release chain (order core → genesis → genesis-workflows so tags exist)
1. **genesis-core** — `CliRegistry` managed-native resolution (additive, **`CORE_MAJOR` stays 1**). Bump + tag; pin genesis
   deps as usual. Pin `ruff==0.15.20` (the §7 lesson — this repo runs `ruff check`).
2. **genesis** — m0009 + `DocumentStore` + `NativeCliInstaller` + `gws` connector/auth + parsing (pinned new dependency) +
   `api/documents.py` + web (Document Library page, Business Artifacts tab, connector card). Repin genesis-core; bump + tag.
   `npm run build` + commit `web/static/` (stale-bundle guard; the `frontend` job runs on `web/**`).
3. **genesis-workflows** — `sync-documents` workflow + the `gws` managed-native `cli-registry.json` entry + catalog. Repin;
   bump + tag. `ci/validate_library.py` + workflow pytest green.

## Gates (all green before tagging)
- genesis pytest + `ruff check genesis`; genesis-core pytest + `ruff check genesis_core`; genesis-workflows
  `validate_library.py` + workflow pytest; web `lint` + `tsc` + `vitest` + build. CI green on all repos via `glab`
  (genesis `genesis` + `frontend` jobs).

## Live acceptance (manual — can't be driven headlessly)
1. Install the `gws` managed-native CLI; **Connect Google Workspace** via the standard OAuth (browser). Confirm connected.
2. Add a real **Google Doc link** to an application's Business Artifacts tab → parsed to Markdown, listed, linked.
3. **Upload** a real PDF + XLSX → parsed (MD + tables), linked; re-upload same file → dedup (one library row).
4. Link the same document into a **second app** → single stored copy, two links; unlink from one → still present via the other.
5. Edit the Google Doc upstream → **Sync now** → latest version pulled + re-parsed (fingerprint changed).
6. In **chat**, ask about the app → confirm `genesis-kb` `search_documents`/`get_document` surface the content; run
   `design-doc`/`generate-business-map` → confirm the evidence pack includes the linked documents.
7. Read-only proof: a write attempt via `gws` is denied by the read-only scopes.

## Docs (Definition of Done)
- `progress/phase-19-document-library.md` (as-built: commits, tags, CI ids, the parsing-dependency choice, the spike findings
  link, the gws auth recipe).
- `tracker.md` §3 row → shipped + §6 status-log entry; README phase table row → shipped.
- **AGENT_ONBOARDING.md** (the bible): §2 tag table + test counts, §4 map (new `genesis/documents/**` + `integrations/gws/**` +
  `cli_tools/native/**` + `web/features/documents`), §5 **ADR-040/041**, §9 roadmap, "Last refreshed" header.
- Mark **ADR-040/041 → Accepted**; note the **deferred scheduler** in the roadmap/backlog.

## Exit criteria
All gates green, live acceptance passed (or the headless-undrivable steps documented with a manual recipe), docs updated,
ADRs accepted. **PHASE 19 COMPLETE** on sign-off.
