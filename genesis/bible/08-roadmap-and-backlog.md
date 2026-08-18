<!-- GENESIS BIBLE — CHUNK 08. DO NOT summarize or drop content when editing; keep it verbatim-faithful. -->
> **This file is one chunk of the Genesis bible.** The bible is split across `bible/` and indexed by
> [`../AGENT_ONBOARDING.md`](../AGENT_ONBOARDING.md). **When asked to "read the bible", read the index AND every
> chunk it lists, then follow all of it religiously.** This chunk holds: **§9 Roadmap & backlog — shipped-phase as-builts + what is next.**
> Section numbers (§0–§10) are the ORIGINAL bible sections and are preserved here; the §→chunk map lives in the index.

---

## 9. Roadmap & backlog (what's next — context, not an assignment)

### 📝 PLANNED (SPECS DRAFTED — awaiting approval to build) — Phase 24: UX revamp + environment-scoped credentials

> **Specs:** `specs/phase-24-ux-revamp-and-environment-credentials.md` (umbrella) + `phase-24-…/24-01` (credentials) + `24-02`
> (nav/IA). **ADR-048 + ADR-049** (PROPOSED). Two user-feedback changes: **(24-01)** the two core Appian MCPs
> (`appian-dev`/`appian-devops`) take their creds from the **environment** — entered on the env form, stored per-env in the
> SecretProvider `env:<label>` scope, resolved ONLY from the dev env; `LCP_API_PATH` → public env field;
> `LCP_URL`/`APPIAN_DOMAIN` auto-derived + hidden; one-time non-destructive migration of legacy server-scoped creds; other MCPs
> unchanged. **(24-02)** Applications-first IA — primary nav = Applications · Chat · Runs · Documents; Overview + Catalog move
> into Settings tabs (default Overview). Delivery order: 24-01 (backend: genesis-workflows `mcp-registry.json` + genesis) then
> 24-02 (frontend). **Not yet implemented.**

### ✅ SHIPPED (COMPLETE) — Phase 23: Scheduled & Full-Package Syncs (genesis v0.48.0)

> **As-built: `progress/phase-23-scheduled-and-full-package-syncs.md`.** Keep the local Appian KB + Document Library fresh
> automatically. **ADR-047.** genesis-only + **m0012**. CI green (pipeline **#6588951**: genesis + frontend + clean-install).
>
> - **23-01 full-package refresh** — the app sync is re-runnable: `api/applications.py` unblocks `sync-application`
>   **`mode=delta`** (a **full re-export → parse → diff the DB → write only the changes**, 16-07 Option A — **not** an env
>   delta-patch), with `_resolve_mode` (auto-pick baseline↔delta, `refresh` alias) + a per-app **already-running 409** guard;
>   the web app-detail action is relabeled **Refresh** (mode-less auto-pick, disabled while running).
> - **23-02 scheduler foundation** — **m0012 `scheduled_jobs`** + `ScheduleStore` + `runtime/scheduler.py` (pure `due_slot` +
>   a 60s asyncio tick; jobs run as **background tasks**; **mark-before-work**; **restart-safe** within-day via `last_fired_slot`;
>   handler-gated). Started/stopped in the app lifespan; `DEFAULT_JOBS` seeded on boot.
> - **23-03 jobs + endpoint** — `application-sync` (all tracked apps, **07:00 IST weekdays**, **serialized** — Appian export is
>   one-at-a-time/409; per-app mode-pick; skip-if-running; skip if no dev env / workflow uninstalled) + `document-library-sync`
>   (`scope=library`, **08/12/16/20 IST weekdays**; skip if `gws` down / workflow uninstalled); read-only
>   `GET /api/system/schedules` (`api/schedules.py`). Released **genesis v0.48.0**.
>
> **Gate:** backend **464** pytest + ruff; web **161** Vitest + eslint + tsc + build; CI green. genesis-core / kiro-agent-sdk /
> genesis-appian-parser / genesis-workflows **unchanged** (the `sync-application` delta mode + `sync-documents` library scope
> already existed). **Live acceptance** is user-observed (leave `genesis serve` up across a slot, or seed a near-future time —
> the app-sync job fires once, runs apps serially, records `last_run_*`; the doc job fires on 4-hour slots, none overnight/
> weekends). **PHASE 23 COMPLETE.** (Deferred: true incremental delta [Appian changed-objects API]; a user-facing schedule
> config UI [the read-only endpoint + table are the seam]; a `scheduled_job_runs` history table.)

### ✅ SHIPPED (COMPLETE) — Phase 22: Distribution & Browser-Based Shipping (clone + git-tag) (genesis v0.47.0)

> **As-built: `progress/phase-22-distribution-and-shipping.md`.** A **standard, working way to ship Genesis to internal
> users** as a **local, browser-based** app — modeled on `appian/prod/friday`'s clone + venv + git-tag self-update installer,
> but browser-based (no Mac `.app`), leveraging Genesis's single-port `genesis serve`. **ADR-046** (clone+tag distribution;
> wheel+index deferred; Docker/native-app out). **genesis-only, no schema.**
>
> **Shipped (22-01..22-07), all CI green (pipeline #6558223: genesis + frontend + the new clean-install):**
> - **22-01 installer** — `scripts/install.sh`: prereq + **SSH-access preflight** (per-repo `git ls-remote`) → clone (one
>   clone; deps via git+ssh tag pins) → venv → `pip install .` → `genesis db upgrade` → scaffold + writes `~/.genesis/dist.json`.
> - **22-02 launcher** — `runtime/launcher.py` = single source of truth for **`genesis up/down/status/logs`** (background serve
>   + health-wait + open browser); `scripts/genesisctl.sh` rewritten as a thin wrapper.
> - **22-03 updates** — `runtime/updater.py` + `api/system` `GET/POST /system/update` + **`genesis update`** + an **UpdateBanner**
>   in `AppShell` (one-click: highest `vX.Y.Z` tag vs deployed → on-branch guard → checkout → `pip install .` → `db upgrade` →
>   detached restart). Tracked branch = **`master`**; dist config `~/.genesis/dist.json`.
> - **22-04 Kiro auth** — `runtime/kiro_auth.py` (`whoami` status / pty device-flow login / logout) + `api/system/kiro*` +
>   **Settings → General "Kiro sign-in"**. (Real-CLI whoami parse: first JSON line + identity claims.)
> - **22-05 preflight** — `runtime/preflight.py` + `GET /system/preflight` + a dismissible **PreflightChecklist** modal
>   (required: kiro/db/health; optional: dev-env/uv/gws) with Fix→ links.
> - **22-06 CI + release** — a **`clean-install`** CI job (fresh non-editable install boots+migrates+serves via `genesis up`;
>   shellcheck); released **genesis v0.47.0**.
> - **22-07 docs** — README quickstart + **`docs/INSTALL.md`** (shipped in v0.47.0) + this bible refresh.
>
> **Gate:** backend **437** pytest + ruff; web **160** Vitest + eslint + tsc + build; shellcheck — all green. genesis-core /
> kiro-agent-sdk / genesis-appian-parser / genesis-workflows **unchanged**. **Live acceptance** is user-driven (a clean-machine
> `install.sh` → `genesis up` → in-app Kiro sign-in → tag a release → the banner → `genesis update`; the device-flow login +
> detached restart are headless-undrivable). **PHASE 22 COMPLETE.** (Deferred: wheel+package-index transport; Windows-native
> beyond WSL; auto-apply updates.)
>
> **▸ Follow-up patch — genesis v0.48.1 (CI green, #6589165): updater dev-guard.** The 22-03 updater's `repo_dir()` fallback
> also matches a developer's **editable checkout**, so it showed a spurious "update available" (the editable metadata version
> lags the git tags) and wired a one-click Update that runs **`pip install .`** — which **clobbers the editable sibling
> installs** (genesis + core + sdk + parser → non-editable). Fix: a real clone+tag **deployment** is marked by
> `~/.genesis/dist.json` (`updater.is_managed_install`); when it's absent (dev/editable), `check()` returns
> **`managed=False` + `update_available=False`** (banner hidden) and `apply()` **refuses** with a clear message. Shipped
> clone-installs (dist.json present) are unaffected. `UpdateStatus` gains a `managed` field. +2 updater tests → **466**.
> (Discovered live: the button had been clicked in the dev tree; recovery = `git checkout master` + re-`pip install -e`
> the four repos `--no-deps`.) See §7's Phase-23 lesson + §6's "do not `pip install .` in the dev venv" note.
>
> **▸ Follow-up patches — genesis v0.48.2 + v0.48.3 & genesis-workflows v0.9.4 (CI green): real-install Dev-MCP + packaging
> fixes.** Found deploying to fresh machines. **(a) SPA packaging (v0.48.2):** the wheel didn't ship `web/static` (it's a repo
> sibling, not in `packages=["genesis"]`) → `/` 404'd on a real install while `/api` worked. Fix: `force-include web/static →
> genesis/web_static` + `api/app._resolve_web_static()` (packaged-first, repo fallback); clean-install CI now asserts `/` serves
> the SPA. **(b) Dev-MCP app enumeration (v0.48.2 + genesis-workflows v0.9.4):** `kb/dev_mcp` now surfaces `isError` (HTTP 401)
> as a real reason (was a silent empty list → misleading "No untracked apps found") + **paginates** `listApplications` (was
> capped at 50 → now all apps); `LCP_API_PATH` is a per-dev-env **persisted** field (defaulted) not a hardcoded literal; and the
> `appian-dev` registry **injects `USERNAME`/`PASSWORD` from the same `LCP_*` secrets** because current lcp-mcp-server builds
> read the bare names (the real 401 root cause — see §7). **(c) Scheduler (v0.48.3):** the `application-sync` job ships
> **disabled by default** (on-demand refresh unaffected; re-enable later). Backend **473** pytest + ruff green. Also surfaced:
> the baseline sync's **DevOps export** needs a valid `APPIAN_API_KEY` + "External Deployments" enabled (a separate 403, not a
> genesis bug). See §7's two v0.48.2 lessons.
>
> **▸ Follow-up patch — genesis v0.48.4: one-click Update upgrades the WHOLE stack.** `updater.apply()` now also runs
> `genesis install` to refresh the **genesis-workflows** library — the only related repo that isn't a pip dependency (the
> pinned **genesis-core / kiro-agent-sdk / genesis-appian-parser** are already re-pulled by `pip install .`, since they're
> git+ssh tag pins in genesis's pyproject). So clicking **Update** now updates genesis + core + sdk + parser + workflows in one
> go, to the version set the genesis release pins (ADR-019 compat contract). Library refresh is non-fatal (warns on failure).
> Note: the update *banner* still fires on a new **genesis** tag — the release protocol bumps genesis's pins alongside any
> core/sdk change, so a new genesis tag accompanies dep changes. (A future enhancement: an independent multi-repo version check
> so a workflows-only tag also surfaces a banner.)

### ✅ SHIPPED (COMPLETE) — Phase 21: Feature Workspace, Spec-Builder UX & Chat Parity (genesis v0.46.0 + genesis-core v0.9.3 + kiro-agent-sdk v0.7.0)

> **As-built: `progress/phase-21-feature-workspace-and-chat-parity.md`.** A **Phase-20 live-feedback pass** — after the user
> used Features + the Spec builder, three themes: **(A)** the feature page becomes a proper **workspace**, **(B)** the spec
> builder becomes **chat-first**, and **(C)** the reused chat reaches **Kiro CLI/ACP parity**. **ADR-044** (a feature = a
> pipeline of artifact stages, each with its own status) + **ADR-045** (chat mirrors the CLI/ACP surface; **refines ADR-031** —
> introspection free, write-actions human-confirmed via the Phase-13 bridge). Release chain: **kiro-agent-sdk v0.7.0** →
> **genesis-core v0.9.3** (SDK pin) → **genesis v0.46.0**; all CI green.
>
> **Shipped (21-01..21-07):**
> - **21-01 ACP parity spike** — `spike/2026-08-12-acp-parity.md`; verified the surface vs **kiro-cli 2.16.2** (models+agents on
>   `session/new`; commands as a notification; autocomplete client-side; `execute` streams; `contextUsagePercentage` + image cap).
> - **21-02 feature workspace** — `web/features/features/ArtifactPipeline` (Spec **Edit**→builder / **View**→read-only preview
>   via `artifact?annotate=0`; Design/Breakdown disabled placeholders); builder split to `…/features/:id/spec`; feature card
>   drops the spec status. **ADR-044.**
> - **21-03 spec-builder UX** — full-width `ChatThread` (`chrome="spec"` — no copilot banner) + a full-screen annotatable
>   **Preview** popup (the doc + **our own comment-queue rail** + one **Send-all**); **`feature_spec` sessions excluded** from the
>   main Chat list (`ChatStore.list(exclude_modes=…)`).
> - **21-04 SDK ACP extensions** — kiro-agent-sdk **v0.7.0**: `SystemInit` models/modes/commands; `set_model`/`set_mode`;
>   `execute_command`; `prompt(images)`; `on_commands`/`on_session_status`.
> - **21-05 chat parity** — **m0011 `chat_sessions.model`**; `ChatManager` model-at-creation + `ensure_agent_catalog` +
>   slash-`execute_command` routing + clear/compact + images; `api/chat` `/chat/{models,commands}` + `…/{model,clear,compact}` +
>   `SendMessage.images`; `Composer` parity toolbar (model select + context meter + Clear/Compact) + **Commands** palette
>   autocomplete + image attach — **both** the main chat and the spec builder. **ADR-045.**
> - **21-06 chat transcript export** — `chat/export.py` + `GET …/export.md` (Markdown, includes tools + thinking); an Export
>   link in the shared chat toolbar. (PDF deferred → browser print only.)
> - **21-07 release** — the chain above; ADR-044/045 Accepted; docs + this bible refreshed.
>
> **Gate:** genesis **409** pytest + **150** Vitest; genesis-core **65**; kiro-agent-sdk **93**; ruff/eslint/tsc clean; CI green.
> **Live acceptance** is user-driven (restart `genesis serve` to load the new server code + the v0.7.0 SDK). **PHASE 21
> COMPLETE.** (Optional future polish: mid-conversation model switch; slash-command argument entry; the sequential card-unlock
> once Design/Breakdown exist; a spreadsheet-grid preview.)
>
> **▸ Follow-up patch — genesis v0.46.1 (CI green, #6556691):** post-release live-feedback bug fixes to the chat parity
> surface (all backend, `genesis/chat/`). (1) **Slash commands hung** — they were dispatched via `_kiro.dev/commands/execute`,
> which times out headlessly for every command (verified vs kiro-cli 2.17.0); rerouted through the normal `prompt()` path
> (`stream_turn` + the Clear/Compact `run_slash_command`), so `/effort`, `/model`, `/clear`, `/compact`, etc. return instantly.
> (2) **`export.md` 500** — `session_to_markdown` now accepts the float that `session_usage_total` actually returns (was
> assuming a dict). (3) **export thinking formatting** — coalesce streaming `agent.thought` deltas into one blockquote (raw, not
> per-chunk stripped). Tests 409→**411**. See §7's two v0.46.1 lessons.

### ✅ SHIPPED (COMPLETE) — Phase 20: Features & Spec Authoring (genesis v0.45.0)

> **As-built: `progress/phase-20-features-and-spec-authoring.md`.** An Appian application gains first-class **Features** (the
> unit of work an engineer develops), and inside a feature a conversationally-authored, annotatable **Spec** — the first of
> what will grow into design docs / user stories on the **feature page**. **ADR-042** (Features & Specs as first-class app
> sub-entities; Chat-authored — ADR-001 intact; HTML-authoritative; draft→in-progress→in-review→completed) + **ADR-043** (embed
> the vendored MIT **Lavish** annotation SDK). **genesis-only release; genesis-core/genesis-workflows unchanged.**
>
> **Shipped (all CI green; ADR-042/043 Accepted):**
> - **20-01 embed spike** — `spike/2026-08-11-lavish-embed.md`; proved the Lavish SDK embeds (postMessage-only, esbuild-bundled,
>   user-confirmed round-trip) + captured the theming seam.
> - **20-02 data model** — **m0010** (`kb_features`/`kb_feature_specs`/`kb_feature_spec_revisions`, schema v10) + `FeatureStore`
>   (untrack cascades features — intrinsic-to-app).
> - **20-03 features surface** — `api/features.py` (feature CRUD + spec create) + **Features** tab + **feature page**
>   (`/applications/:uuid/features/:featureId`) + Create-spec empty state.
> - **20-04 spec chat** — a bound **`feature_spec`** Chat session (additive mode; `genesis-kb` auto-wired) seeded with the
>   app/feature identity; **Add context** (the app's linked business artifacts); milestone snapshots + status.
> - **20-05 embedded review** — vendored Lavish SDK (`api/assets/lavish/`, Genesis-themed) served same-origin; `SpecWorkspace` =
>   reused `ChatThread` + sandboxed review iframe + the postMessage **annotation→chat bridge** + Export-`.md` (`markdownify`).
> - **20-06 release** — genesis **v0.45.0**, CI green; ADR-042/043 Accepted.
>
> **Live-accepted** (create feature → the spec chat authors `spec.html` → annotate a passage in the embedded review → the
> comment flows into the chat → the agent revises). **Two live fixes** folded in (see §7): the `feature_spec` **cwd = the fs
> sandbox**, and **trusting `fs_read`/`fs_write`** (kiro-cli's built-in `fs_write` tool was being auto-denied). Context is
> delivered as **`./context/` files** the agent reads on demand (not dumped into the transcript). **PHASE 20 COMPLETE.**
> (Optional future polish: multiple specs per feature + templates; design-docs / user-stories tabs; the Mermaid-as-Excalidraw
> whiteboard; a durable per-session identity preamble so it survives long-conversation cold-starts.)

### ✅ SHIPPED (COMPLETE) — Phase 19: Genesis Document Library (genesis-core v0.9.2 + genesis v0.44.0 + genesis-workflows v0.9.3)

> **Handoff — as-built: `progress/phase-19-document-library.md`.** Attach the business documents that
> describe an application (the PDFs/Word/Excel/Google Docs in Google Drive) to Genesis, parse them to LLM-consumable Markdown
> (+ JSON for tabular), and use them **alongside the Appian KB** for spec generation / design discussion. Documents are a
> **global first-class store** (`kb_documents`, one row per unique doc, dedup by Drive file-id / upload hash) **linked into apps**
> (`kb_document_links`); **untrack unlinks, never deletes** (**ADR-041**). Google Drive is reached via the **Google Workspace CLI
> (`gws`)** integrated as a **managed-native CLI connector** (**ADR-040**, the CLI analog of the native Appian MCP — single
> static binary, no `uv`): Genesis owns an **isolated** config dir (`~/.genesis/cli-tools/gws/config`, file keyring, its own
> `gws auth login`) and **reads the OAuth client** from the dotfiles-provisioned `~/.config/gws/client_secret.json` — **ships no
> token**; the dotfiles setup is a documented prerequisite. Read-only Drive/Docs/Sheets/Slides scopes only.
>
> **Shipped (all CI green; ADR-040/041 Accepted):**
> - **19-01 spike** — `spike/2026-08-11-gws-oauth-and-export.md` (live-verified).
> - **19-02 managed-native `gws` connector** (genesis-core v0.9.2 `CliRegistry` resolution + genesis `NativeCliInstaller`/`gws`
>   seam/login/`api/native_cli.py`/`genesis cli` + genesis-workflows `cli-registry.json`); live isolated-login smoke test passed.
> - **19-03 data model** — m0009 (`kb_documents`/`_links`/`_sections`, schema v9) + `DocumentStore` (untrack unlinks-not-deletes).
> - **19-04 parsing** — `kb/doc_parsing.py` (PDF/DOCX/XLSX/CSV/MD/TXT → Markdown + per-tab JSON + sections); deps pinned
>   `pypdf==6.15.0`/`python-docx==1.2.0`/`openpyxl==3.1.5`; Google-native export→binary/text convergence.
> - **19-05 sync** — `DocumentSyncEngine` (`ctx.extras['document_sync']`) + the deterministic **`sync-documents`** workflow
>   (async `to_thread` write) + `api/documents.py` (upload/gdrive add [auto-syncs Drive docs], link/unlink, sync single|app|
>   library with friendly 409, list/search/get/delete).
> - **19-06 consumption** — `genesis-kb` MCP `list/get/search_documents` (auto-trusted in chat) + `build_evidence_pack` includes
>   linked docs as bounded excerpts (document-aware `design-doc`/`generate-business-map`).
> - **19-07 web** — Document Library page + **full-screen document viewer** (`/documents/:id`, full-width + overflow scroll) +
>   per-app **Business Artifacts** tab (add upload/drive/**multi-pick**, unlink/sync) + Settings→CLI **gws connector card**.
> - **19-08 release** — genesis-core **v0.9.2** → genesis **v0.44.0** → genesis-workflows **v0.9.3**, all CI green; ADR-040/041
>   flipped to **Accepted**. **Tests:** genesis 375 pytest + 138 Vitest · genesis-core 65 · genesis-workflows 75 + validate_library.
>
> **Live-accepted:** a real Google Drive doc (incl. an .xlsx) added → auto-synced via `gws` export → parsed → viewed in the
> full-screen viewer. **PHASE 19 COMPLETE.** (Optional future polish: a spreadsheet-grid view from `tables.json`; a scheduler
> for periodic document sync; semantic/pgvector document search — an ADR-030 trigger.)


### ✅ SHIPPED (COMPLETE) — Phase 18: Appian Parser Accuracy Overhaul (genesis-appian-parser v0.2.0 + genesis v0.40.0 + genesis-workflows v0.9.2)

> **Fixed a catastrophic dependency under-linking bug in `genesis-appian-parser`.** A real 2,620-object app reported
> **804 orphans (30.7%), 803 provably false** — objects genuinely referenced by expression rules / interfaces /
> constants. Root cause (inherited from the Atlas port): field-path-scoped reference extraction (no Constants / AI Skills
> / Decisions / Translation Strings / Documents) + `is_orphan` = "not bundled" rather than "unreferenced". Reverified
> against real XML + the original **Atlas** parser + the **Jarvis** plugin (best-of-both; §9 decision matrix in the spec)
> and drove accuracy **>95%**, verified by a committed **raw-XML reference oracle** + a **≥95% CI gate**: edge recall
> **0.324 → 0.978**, precision **0.999**, referenced-object recall **0.869 → 1.0**, **orphans 804 → 0**, false-orphan
> rate **0.311 → 0.0**, edges 5,084 → 10,617, **12 cross-app integration points**. Also delivered the user's
> **APPREF/ENTRYPOINT** cross-app integration-point model (by-name `rulereferencebyname`, ENTRYPOINT/APPREF naming +
> 10-category taxonomy, orphan-exempt, `integration_*` metadata + `stats.cross_app`). **Live-validated on the user's real
> app** (delete + re-add baseline sync; the venv's editable parser install picks up main without a `genesis serve`
> restart — parsing runs in a fresh subprocess worker). Delivered **18-01..18-05** on `genesis-appian-parser` main
> (afcb66d/31567fa/a357db6/c86b20c/44472c4); suite 13 → **25** green, ruff clean. **18-06 SHIPPED:**
> `genesis-appian-parser` **v0.2.0** (05d0fea) → repin `genesis` **v0.40.0** (8477945) → `genesis-workflows` **v0.9.2**
> (79edb75), all CI green (a fresh `sync-application` baseline/delta recomputes the accurate graph into the KB).
> **Deferred:** a **Tempo Report** parser + **generic-haul fallback** (need a package containing those types), richer
> per-type golden fixtures, Jarvis `orphanCluster` + `TagDetector` behavioral tags (a future Business-Map capability
> signal). Specs: `specs/phase-18-parser-accuracy.md`; as-built: `progress/phase-18-parser-accuracy.md`. **PHASE 18
> COMPLETE.**

### ✅ SHIPPED (COMPLETE) — Phase 17: Business Application Map (17-01..17-06; genesis v0.39.0 + genesis-workflows v0.9.1)

> **Agent-synthesized, business-language map of what an application does end-to-end** — **(A)** value stream(s) + **(B)**
> capability constellation — explicitly **NOT** a technical/object/bundle view (the user's hard steer: no objects, bundles,
> pages, or properties; those terms are **banned** from the output). Business meaning is *derived*, not parsed, so it is
> produced by a new **deterministic `generate-business-map` LangGraph workflow** with narrow **agent** nodes (ADR-001)
> wrapped by the reliability trio (ADR-011); **evidence-grounding + coverage + business-language** validators make it
> un-hallucinated (every business element cites real KB object UUIDs) + a HITL review gate. Reads the **code-free KB only**
> (via `genesis-kb`/`KbStore` — no env round-trip), emits a versioned **`BusinessModel v1`** persisted in **m0008
> `kb_business_maps`** (code-free, point-in-time, stale-on-sync); the web renders A+B on the existing **@xyflow/react +
> dagre** stack with focus+context linking. **Specs:** `specs/phase-17-business-application-map.md` (umbrella) +
> `phase-17-business-application-map/business-model-contract.md` + `17-01..17-06`; **ADR-039** (Proposed). **Release chain
> when built:** genesis (m0008 + KbStore + evidence extractor + API + web) → genesis-workflows (workflow + catalog);
> genesis-core likely unchanged. **Backend (17-01 persistence/m0008 + 17-02 evidence pack + 17-04 API) SHIPPED in
> genesis v0.35.0; the deterministic `generate-business-map` workflow (17-03) SHIPPED in genesis-workflows v0.9.0
> (2 Kiro agent nodes + reliability trio + evidence-grounding/coverage/business-language validators + escalate/review
> gates). The web **Business Map view** (17-05 — React Flow **A** value stream + **B** capability constellation,
> first tab, click-for-detail popups, focus+context linking) SHIPPED and was **exercised live**: the first real
> generation against the 2,763-object "AS GSS Full Application" produced a rich, high-quality model (10 capabilities /
> 10 entities / 14-stage value stream, 2 decision branches) — readability iterations followed in **genesis v0.37.0**
> (readable zoom + MiniMap + radial constellation) and **v0.38.0** (detail popups + smoothstep edge routing). NEXT =
> **17-06** shipped the hardening: (a) a **friendly 409 "workflow not installed"** on generate instead of a 500 (a
> newly-released library workflow must be `genesis install`-ed first — genesis v0.39.0); (b) **recalibrated the coverage
> floor 0.6 → 0.3** — coverage is a lenient "is the map non-trivial" signal (a good map abstracts heavily), the human
> **review gate** is the real backstop (genesis-workflows v0.9.1). **Live-acceptance PASSED** — the first real map read
> as a coherent business story with no technical vocabulary. **PHASE 17 COMPLETE.** (Optional future polish: richer
> golden-fixture harness; per-value-stream layout tuning.)**

### ⭐ ACTIVE (IN PROGRESS — planning complete + pushed; 16-01/16-02/16-03/16-04/16-08 + **16-05 (server + chat)** shipped, **16-05b (workflow cutover) + 16-07 next**) — Phase 16: Appian Knowledge Base ("Atlas-into-Genesis")

> **Handoff for the next session:** planning is complete AND implementation is under way. Read
> `specs/phase-16-appian-knowledge-base.md` (umbrella) + `phase-16-appian-knowledge-base/16-01..16-08` +
> `genesis-kb-tool-contracts.md`, ADR-036/037/038, and `progress/phase-16-04-applications-surface.md` +
> `progress/phase-16-08-native-mcp.md`. **Shipped so far:**
> **16-01** = `genesis-appian-parser` **v0.1.0** (`parse(zip|bytes) -> KbParseResult`, code-free); **16-02** = genesis
> **v0.28.0** (m0007 `kb_*` + `KbStore`); **16-03** = the **`sync-application`** workflow (genesis **v0.29.1** +
> genesis-workflows **v0.8.2**); **16-08** = the dev-env `is_dev` toggle (§2.0, genesis **v0.30.0**) + the
> **managed-native Dev/DevOps MCP installer** (Stage B: genesis-core **v0.9.1** + genesis **v0.31.1** +
> genesis-workflows **v0.8.4**); **16-04** = the **Applications surface** (genesis **v0.32.0**); **16-05** = the
> **`genesis-kb` MCP server + CHAT cutover** (genesis **v0.33.0**); **16-07 Option A** = the **`sync-application` delta
> path** (re-export + SCD-2 delta-merge, genesis-workflows **v0.8.5**) — all CI green.
> **Next: 16-05b** (cut `erd-generation` + `design-doc` off `appian-atlas` → `genesis-kb`; blocked on Section-C schema +
> 16-06 versioning + Jarvis→Dev-MCP — `appian-atlas` RETAINED for them meanwhile) **+ the 16-07 remainder** (true
> incremental delta via a new Appian changed-objects API [the Dev MCP can't back it], scheduler, per-release changelog).
> **📋 See `specs/backlog/phase-16-deferred.md` for the full deferred register.** Keep extending `tracker.md` §6 as you go.

**Goal.** Move the Appian knowledge base *inside* Genesis and make Genesis an agentic Appian-development environment.
Stop calling external **Atlas** (GitLab-served pre-parsed KB) / **Jarvis** (in-Appian KB) as services; reproduce their
*knowledge* surface locally and route every *environment* call through the native **Dev MCP / DevOps MCP**.

**Architecture (decided):**
- **`genesis-appian-parser`** — a NEW pinned repo: port the Atlas parser's front-half (unzip → type-detect → 15 object
  parsers → UUID/URN resolution → dep-graph → entry-point **bundles** → diff-hash) into a Genesis-owned, stdlib-only
  package that emits an **in-memory `KbParseResult`** — **no source code persisted**, no file output. (Atlas parser repo
  `appian/prod/solutions-atlas-parser`; KB repo `appian/prod/solutions-atlas-kb` with `sync_packages.py`; Atlas MCP
  `appian/prod/solutions-atlas-mcp-server` — all read via `glab`.)
- **KB in `genesis.db`** — migration **m0007**, `kb_*` tables, a **temporal SCD-2** model (objects/edges validity-ranged
  by sync) + `kb_bundles`(+`flow_json`) + `kb_releases`; **cross-app queryable**; **NO code**.
- **`sync-application` LangGraph workflow** — deterministic **REST export** (Appian Deployment API in a program node — no
  agent, no credits) → parse → SCD-2 merge → recompute bundles → record sync.
- **Applications page** (`kb_applications`, `/api/applications*`) — tag one env as **dev** (`is_dev` toggle, single-select,
  in the existing Environments registry — supplies URL + creds for all Phase-16 auth; 16-08 §2.0) → list its apps via Dev
  MCP → **Add** an app → baseline sync → status/releases.
- **`genesis-kb` MCP** — Genesis-owned read-only stdio server (like `introspection_server`), serving the KB; **cuts
  chat / erd-generation / design-doc off the external `appian-atlas`** onto it (the "KB swapped, functionality
  preserved" milestone). `get_object_code` fetches SAIL **live via the Dev MCP**.
- **Native MCP integration (16-08)** — the Dev MCP (`lcp-mcp-server`) + DevOps MCP (`appian-deployment-mcp`) installed as
  **managed, versioned, updatable** local servers (bundles the user placed at `artifacts/mcp-servers/`); **updatable
  without forking** (manual drop-in — the operator installs a new bundle; Genesis versions it + keeps the prior for
  rollback; no auto-fetch source — 2026-08-05).
  **Connectivity foundation (16-08 §2.0, build FIRST):** a single-select **`is_dev` toggle** on the Environments
  registry — the registry may hold many envs, exactly one is tagged **dev**, and that env's URL + credentials feed all
  Phase-16 auth (REST export, Dev MCP, DevOps MCP, changed-objects API); no dev env ⇒ fail fast + a "Test connection".

**Scope decisions (2026-08-04, from a full Atlas(34-tool)+Jarvis(50-tool) audit — see `genesis-kb-tool-contracts.md`):**
- **Iteration 1 = 16 read-only KB tools** (Section A / Tier-1): `list_applications`, `get_app_overview`,
  `search_objects`, `get_dependencies`, `get_object_detail`, `get_entry_points_for_object`,
  `get_dependents_batch`/`get_precedents_batch`, `get_shared_objects`, `search_bundles`, `get_bundle`, `list_orphans`,
  `get_orphan`, `get_dependency_path`, `get_transitive_dependencies`, `get_hub_objects`, `get_object_code` (live).
  Return shapes **mirror the Atlas MCP** for a lossless cutover.
- **Versioning (6 Version tools + release tagging + point-in-time) = BACKLOG (16-06)** — gated on Dev MCP **AP-62096**
  ("Object version viewing/comparison", Code Review, **26.8 GA / 2026-08-28**; underlying version-UUID plumbing AP-51279
  is Done). Schema kept version-ready (additive) so it lands code-only later.
- **Schema/DDL/data-gen (7+2 tools) = DEFERRED (Section C).** **Write/deploy (Section E) = OUT.** **Documents/git-content/
  pipeline-refresh (Section F) = OUT.** **Live-env reads (Section D) = via Dev/DevOps MCP only.**
- **Governing principle:** *knowledge fetch → internal `genesis-kb`; any environment call → Dev/DevOps MCP.* Read-only
  against Appian throughout (Dev MCP read-only allowlist; DevOps export/status/download only).

**Sub-phases (all in `phase-16-appian-knowledge-base/`; iteration-1 unless noted):** 16-01 parser (new repo) **✅ v0.1.0** ·
16-02 schema+`KbStore` (m0007) **✅ genesis v0.28.0** · 16-03 sync workflow (baseline) **✅ genesis v0.29.1 + genesis-workflows v0.8.2** · 16-08 native MCP integration (§2.0 dev-env toggle **✅ genesis v0.30.0**; **Stage B installer ✅ genesis-core v0.9.1 + genesis v0.31.1 + genesis-workflows v0.8.4** — 16-08 COMPLETE) · 16-04 Applications surface **✅ genesis v0.32.0** · **16-05 `genesis-kb` MCP server + CHAT cutover ✅ genesis v0.33.0**
(workflow cutover split to **16-05b ◀ NEXT** — `appian-atlas` retained for erd/design-doc until Section-C schema + 16-06)
· 16-07 delta refresh **✅ Option A (re-export + delta-merge) genesis-workflows v0.8.5** (true incremental delta via a
new Appian "changed-in-[start,end]" API + scheduler + per-release changelog = deferred, backlog §1.3–§1.5) · **16-06 versioning —
BACKLOG**. Suggested build order: 16-01 → 16-02 → 16-03 → 16-08 → 16-04 → 16-05 → 16-05b/16-07; 16-06 later. **Release chain:**
`genesis-appian-parser` (new) → `genesis` (m0007 + KbStore + kb_server + native-MCP installer + applications api/web) →
`genesis-workflows` (sync-application + managed-native registry entries). genesis-core likely unchanged.

**✅ 16-03 — DONE (`sync-application` workflow).** genesis **v0.29.1** + genesis-workflows **v0.8.2**, CI green. As built
(see `progress/phase-16-03-sync-workflow.md`): a program-only graph `resolve_inputs → export_package → v_export →
parse_package → v_parse → write_kb → v_kb → present`; **export = deterministic Appian Deployment REST** in a program
node, all network/env/secret access isolated in the `_fetch_package_zip` seam (401/403/404 fail-fast; 409/timeout/5xx →
retry); **parse → code-free `result.json`**; **write_kb → `KbStore` baseline**, store injected via
`ctx.extras['kb_store']` (wiring resolved to ctx.extras — `build_context` provides it; `graph.py` never imports the
platform); re-baseline rejected. genesis pins `genesis-appian-parser@v0.1.0`, adds `EnvironmentRegistry.active()`, and
hardened the checkpointer connection (WAL + busy_timeout). **`write_kb` is a raw async node that runs the blocking
`KbStore` write via `asyncio.to_thread`** — the deterministic fix for a flaky CI `database is locked` (a sync write on
the event loop deadlocks the aiosqlite checkpointer; see §7). `appian-dev`/`appian-devops` registered as managed-native
refs (resolved the old `lcp` placeholder).

**✅ 16-08 §2.0 — DONE (dev-environment toggle).** genesis **v0.30.0**, CI green (#6502611). The Environments registry
has an **`is_dev`** flag (single-select — tagging one env clears the others); `EnvironmentRegistry.dev_environment()`/
`dev_environment_label()`/`set_dev_environment()`; `ConfigService.dev_connection_check()` readiness; API `is_dev` on
upsert + `POST /config/environments/{label}/dev` + `GET /config/environments/dev/check`; web dev toggle + **dev** badge +
per-row **Set as dev** + **Test connection**. See `progress/phase-16-08-native-mcp.md`.

**✅ 16-08 Stage B — DONE (managed-native Dev/DevOps MCP installer).** genesis-core **v0.9.1** + genesis **v0.31.1** +
genesis-workflows **v0.8.4**, CI green (see the progress doc for the one `frontend`-guard caveat). As built:
`NativeMcpInstaller` (`genesis/mcp/native/`) installs a drop-in bundle → `uv sync` under
`~/.genesis/mcp-servers/<id>/versions/<v>/` → verify entry → sha256 + lockfile → set `current`; `rollback(id)` to the
prior version; `active_launch_spec(id)` launches from the **per-server venv, NOT `uv`** (Dev `python -m lcp_mcp_server`,
DevOps `.venv/bin/appian-deployment`); **no network `update`** (manual drop-in). `NativeMcpLockfile` = own atomic JSON
store (not `genesis.db`). genesis-core `McpRegistry` resolves a `"managed":"<id>"` entry via an injected `launch_provider`
(env `${VAR}` stays on the entry, resolved as usual; additive, `CORE_MAJOR`=1) + an 8 MiB introspect stream limit.
`mcp-registry.json` `appian-dev`/`appian-devops` are managed refs with read-only allowlists **set from the real installed
`tools/list`** (Dev 67/145, DevOps 13/26). Wiring: `ConfigService` + `worker` inject `native.launch_spec_for`;
`environments.resolve_var` maps `LCP_URL`/`APPIAN_DOMAIN` from the dev env. Surface: `api/native_mcp.py` (GET status +
POST install|rollback), `genesis mcp install-native|status|rollback-native` CLI, Settings→MCP "Appian MCP servers" panel.
See `progress/phase-16-08-native-mcp.md`.

**✅ 16-04 — DONE (Applications surface).** genesis **v0.32.0**, CI green (#6504611: `genesis` + `frontend`). As built
(see `progress/phase-16-04-applications-surface.md`): `api/applications.py` over `KbStore` + `RunManager` (list /
available [Dev-MCP `listApplications` via `kb/dev_mcp.py`, best-effort + manual-UUID fallback] / add→baseline sync /
detail / sync-status / objects / bundles / table-scoped untrack); `KbStore.list_syncs`+`latest_sync`;
`web/features/applications` (page + Add dialog + detail tabs **Business Map | Overview | Syncs | Releases** [Objects + Bundles tabs removed v0.41.0] + live SyncStatus **shown only while a sync is running**)
+ a Sidebar entry. First consumer of the managed-native Dev MCP. (The `frontend` stale-bundle guard ran green here —
also closing the 16-08 Stage-B gap where it hadn't executed.)

**✅ 16-05 — DONE (`genesis-kb` MCP server + CHAT cutover).** genesis **v0.33.0**, CI green (pipeline 6513536; `frontend`
skipped — no web change). As built (see `progress/phase-16-05-kb-mcp-and-cutover.md`): **`genesis/mcp/kb_server.py`** —
a read-only stdio JSON-RPC MCP modeled on `introspection_server.py` (`mode=ro` genesis.db, 32 KB cap, `-m
genesis.mcp.kb_server --db <db>`) exposing the **17 Tier-1 tools** over `KbStore` with **Atlas-mirrored shapes**;
`get_object_code`/`get_orphan` fetch live SAIL via the Dev MCP (`genesis/kb/dev_mcp.py` `object_code`, type→getter map +
defensive parse; graceful `code_status:"unavailable"`, never fabricated). `KbStore` gained the 7 remaining reads
(entry-points, dependents/precedents batch, shared, hub, dependency-path BFS, transitive-deps BFS; current-state only).
**Chat cut over** (`chat/mcp.py`): `genesis-kb` always wired (+ best-effort `@appian-dev` for live code); **`appian-atlas`
dropped from chat**. 288 pytest green, ruff clean.

**⚠️ Phased-cutover decision (2026-08-06) — `appian-atlas` RETAINED for the workflows.** A lossless `erd-generation` +
`design-doc` cutover is **not** possible in iteration 1: `genesis-kb` deliberately omits the **schema/DDL tools
(Section C, deferred)** and the **release/version tools (16-06 backlog, AP-62096)** — exactly what those workflows use
(`get_app_schema`/`get_schema_relationships`; `list_releases`/`get_object_at_release`/`get_changelog`/`compare_releases`/
`get_release_impact`), and `design-doc` also still uses **Jarvis**. **Per the user's decision, both workflows STAY on
`appian-atlas`** (their `required_mcp` unchanged; genesis-workflows not re-released) until parity lands. Only **chat**
cut over (it used Atlas *structural* reads that `genesis-kb` mirrors). Documented in the phase-16 umbrella spec.

**▶ NEXT — 16-05b (workflow cutover) + 16-07 remainder.** **16-05b** = cut `erd-generation` + `design-doc` off
`appian-atlas` → `genesis-kb` (+ Dev MCP for live/schema), unblocked by (a) a Section-C schema decision (build the
schema tools OR repoint their schema/data-model research to live Dev-MCP record-type tools) and (b) **16-06 versioning**
(AP-62096) for `design-doc`'s release-history, plus retiring Jarvis→Dev MCP there. **16-07 remainder** = the true
incremental delta (Appian changed-objects API — the Dev MCP can't back it), the scheduler, and the per-release
changelog. **16-06** (versioning) stays BACKLOG (gated on Dev-MCP AP-62096, 26.8 GA). **📋 The full deferred register
(every postponed Phase-16 item + why + what unblocks it) is `specs/backlog/phase-16-deferred.md` — read it before
picking up any Phase-16 follow-up.**

**✅ 16-07 — Option A DONE (delta refresh via re-export + SCD-2 delta-merge).** genesis-workflows **v0.8.5**, CI green
(pipeline 6513690). `sync-application` v0.2.0 `mode=delta`: full re-export + `KbStore.apply(mode='delta')` (diffs by
`diff_hash`; opens new/modified, closes removed [inferred], recomputes bundles, records the window). `resolve_inputs`
requires an existing baseline for delta; `check_kb` mode-aware. **The true incremental delta (Appian changed-objects
API) is deferred — the Dev MCP cannot fetch objects by modified date/time (confirmed 2026-08-06: no modified-since tool;
objects carry no modified timestamp).** Scheduler + per-release changelog also deferred. See
`progress/phase-16-07-delta-refresh.md` + backlog §1.3–§1.5.

**Key facts for any Phase-16 work:** the sample package the user provided is
`/Users/ramaswamy.u/Documents/test/packages/AiDocumentCenterv4.3.1.zip` (also vendored in the parser repo's
`tests/fixtures/`); the env **accepts Basic auth** (Dev MCP headless, no playwright/SSO); `KbStore` reads/writes are
**current-state only** in iteration 1 (`valid_to_sync IS NULL`); `KbBundle.flow` / `flow_json` is the **structured dict**
(Atlas standard), returned verbatim.

**Open items to confirm with the human:** (1) the Appian **changed-objects** API contract (content vs ids; deletes;
pagination) for 16-07. *(Resolved: env accepts Basic auth; export is deterministic REST not the DevOps MCP; the
KbStore→worker wiring is `ctx.extras['kb_store']` via `build_context`; native-MCP updates = **manual drop-in, no
auto-fetch source** (2026-08-05); commit/push approved — 16-01/16-02/16-03 + 16-08 §2.0 are pushed + CI-green.)*

---

- **Shipped:** Phases 1–6, the web revamp (7.1), the code-review fix program (01–06), Phase 8 (settings
  revamp), **Phase 9 (agent artifact I/O), Phase 10 (chat assistant), Phase 11 (credit tracking),
  Phase 12 (Appian code-review workflow), Phase 13 (Chat Copilot & Run Orchestrator — 13-01..13-06),
  Phase 14 (Skills in Chat — 14-01..14-05), Phase 15 (Design-Document Workflow — 15-01..15-05:
  dual-source Jarvis+Atlas research → Markdown design doc + run-launch file attachments, ADR-035)**.
  See `tracker.md` §3/§6 and `reference/roadmap-and-sequencing.md`.
- **Phase 13: Chat Copilot & Run Orchestrator — COMPLETE (13-01..13-06 shipped; ADR-033 Accepted).**
  Read `specs/phase-13-copilot-orchestrator.md` (umbrella) + `phase-13-copilot-orchestrator/13-01..13-06`
  + **ADR-033** + `progress/phase-13-copilot-orchestrator.md` if you touch the copilot. **Delivered:** type `/`
  in chat → pick a workflow → schema-driven inputs → the Kiro agent **starts the run** and **supervises**
  it (senses HITL gates, presents options, relays the user's decision, reports outcomes) without staying
  alive. **Architecture (decided, code-grounded):**
  - **Genesis Control MCP server** (`genesis/mcp/control_server.py`) — a write-capable sibling of the
    read-only `introspection_server`, but a **thin MCP→HTTP facade over `/api`** (`POST /api/runs`, `GET
    /api/runs/{id}`(+`.gate`), `/respond`, `/cancel`, `/api/catalog`, `GET /api/workflows/{id}`) so
    `RunManager` stays the single source of truth. Tools: `list_launchable_workflows`,
    `get_workflow_inputs_schema`, `check_launch_readiness`, `start_run`, `get_run_status`, `get_run_steps`,
    `get_pending_gate`, `respond_to_gate`, `cancel_run`, `list_session_runs`. NO config/secret/registry/deploy tools.
  - **Human-confirmed mutations via ACP's native permission mechanism** — the SDK permission model is binary
    (`auto_approve`/`auto_deny`) and *trusted tools skip the prompt*. So keep **read tools trusted (silent)**
    and leave **mutating tools UNTRUSTED** → kiro-cli fires `session/request_permission` per call → a new SDK
    **`permission_mode="ask"`** + async `on_permission` callback (13-01) routes it to a **chat confirm card**
    (fail-closed on timeout). **Load-bearing spike (13-01, do FIRST):** prove kiro-cli actually fires
    `request_permission` for untrusted MCP tools; if not, use the ADR-033 fallback (UI-mediated pending-action confirm).
  - **Event-driven supervision** — a `ChatRunSupervisor` (app process) subscribes to `RunManager`'s EventBus
    for **session-linked runs** (`m0004 chat_run_links`); on `gate.awaiting`/`run.final` it emits a notification
    + a proactive **nudge turn** so the copilot surfaces the gate + options; **level-triggered reconcile** from
    durable state (`pending_gate` + `EventLog`) on restart (don't rely on the live subscription). Nudges queue
    behind the session lock + de-dup by `(run_id, gate_node, raised_at)`.
  - **Slash UX** — Composer `/` palette from the catalog; **reuse the 07-05 launch form** for schema inputs;
    on submit the UI hands the agent the `start_run` action (agent is the actor) → confirm card → run linked +
    supervised. In-chat cards: permission-confirm, gate, terminal; a supervised-runs strip.
  - **ADR-033 reconciliation:** ADR-001 preserved (LangGraph still owns each workflow's control flow; copilot
    = operator at the run-management layer = what a human does in the Runs UI); ADR-031 refined (read-write at
    that layer, every mutation human-confirmed, no config/secret/deploy, read-only default + kill-switch).
  - **Sub-phase order + release chain:** **13-01 SDK permission bridge — SHIPPED (kiro-agent-sdk v0.5.0;
    spike confirmed; genesis/core pin bump deferred to 13-03)** → **13-02 control server + ADR-033 —
    BUILT (genesis/mcp/control_server.py on master `b6edf7c`; requests not httpx; token gating deferred to
    13-06)** → **13-03 copilot chat mode + run↔session link (`m0004`) + coordinated sdk-v0.5.0 pin bump —
    SHIPPED (genesis v0.21.0 + genesis-core v0.8.1; the 13-02 control server ships here, now live)** → **13-04
    run-supervision bridge — SHIPPED (genesis v0.22.0: ChatRunSupervisor observes gate/terminal for linked
    runs → durable notifications [m0005] + per-session SSE + deterministic system nudge; level-triggered
    reconcile + SLA)** → **13-05 slash launch + in-chat HITL/confirm UI — SHIPPED (genesis v0.23.0: Composer
    `/` palette → LaunchDialog → start_run intent turn → PermissionCard/GateCard/TerminalCard + SupervisedRunsStrip;
    frontend-only release)** → **13-06 safety/audit/advanced-gate + release — SHIPPED (genesis v0.24.0:
    persisted kill-switch + per-session concurrency/rate/allow-deny enforced app-side on POST /api/runs
    gated on the control token; `copilot_actions` audit trail [m0006]; pre_mutation never auto-approved;
    Settings→Copilot section + activity; ADR-033 → Accepted)**. **PHASE 13 COMPLETE.** `genesis-core`
    unchanged. After any `web/src` change: `npm run build` + commit `web/static`. Remaining: manual
    live-acceptance vs. real kiro-cli (headless-undrivable).
- **Phase 14: Skills in Chat — COMPLETE (14-01..14-05 shipped; ADR-034 Accepted).** Read
  `specs/phase-14-skills-in-chat.md` (umbrella) + `phase-14-skills-in-chat/14-01..14-05` + **ADR-034** + the proving
  spike `spike/2026-07-16-kiro-skills-in-acp-and-chat.md` before touching code. **Goal:** add **Skills** — Kiro's
  portable `SKILL.md` instruction packages — as a **second first-class capability beside Workflows**, usable from
  **Chat** (priority 1). **Concept boundary:** a *Skill* = standalone activity (draft a doc, build a checklist, apply
  a body of knowledge like GAM), no stages/run, owned by the Kiro agent; a *Workflow* = staged/orchestrated, owned by
  LangGraph. **Architecture (spike-proven, code-grounded):** skills are **filesystem-discovered** (`.kiro/skills/`),
  NOT an ACP wire param like MCP — Genesis writes them into a managed workspace **`~/.genesis/.kiro/skills/`** (= the
  chat `cwd`); kiro-cli auto-discovers them (auto-activation by `description` + explicit `/skill-name`, both proven).
  Two acquisition paths: **install from a `genesis-workflows` `skills/` library** (parallel of the workflow install +
  a separate `skills-registry.json`) or **author in-flight** (SKILL.md + scripts/references/assets uploads). **Catalog**
  → Workflows | Skills sub-tabs; **Chat** `/` palette → unified workflows+skills menu (skills also in read-only chat).
  **Safety:** skills may write documents **only** into a per-session **skill-output sandbox**
  `~/.genesis/skill-output/<session_id>/` via a small additive SDK **`fs_write_root`** option (writes elsewhere
  rejected); executing bundled scripts stays deferred. **Sub-phases:** 14-01 foundation + chat discovery → 14-02
  skills library + install-from-repo → 14-03 Catalog Skills tab + in-flight authoring → 14-04 chat skills invocation →
  14-05 safety (skill-output sandbox) / lifecycle / release. **Release chain (shipped):** kiro-agent-sdk **v0.6.0**
  (`fs_write_root`) → genesis-workflows **v0.6.0** (skills library) → genesis **v0.26.1**; genesis-core **v0.8.2** (sdk-pin bump only).
  Remaining: manual live-acceptance vs. real kiro-cli (auto-activation + `/gam`, headless-undrivable).
- **Backlog (`specs/backlog/`):** the **skill → workflow migration program** (the 45 solutions-copilot
  skills, waves A–D) — deferred; the methodology is intact and resumes when scheduled.
- **Open follow-ups (may be assigned):** the Phase-12 **live run** against a real GAMS ticket/package
  (needs a `genesis serve` restart on ≥ v0.20.2 + the connected jarvis/jira secrets) to confirm per-object
  findings, checklist coverage, SQL checks, the diff baseline rule, and metered credits; restart the
  running `genesis serve` to load v0.20.x; harden the other JSON stores' writes to be atomic (like
  secrets); **rotate the shared `GITLAB_PUSH_TOKEN`** + refresh the expired Artifactory npm token; the
  `lcp` MCP image placeholder (`<lcp-image>`) in `mcp-registry.json`.

**Do not start backlog or a *new* phase unless explicitly asked.** (Phase 16 is **actively being implemented** with the
human's go-ahead — specs are pushed and 16-01/16-02 are shipped + CI-green; continue in the build order per §9's Phase-16
block. This does not authorize starting any phase *beyond* 16 or any `specs/backlog/` work.)

---

