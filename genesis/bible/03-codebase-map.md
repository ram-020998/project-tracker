<!-- GENESIS BIBLE — CHUNK 03. DO NOT summarize or drop content when editing; keep it verbatim-faithful. -->
> **This file is one chunk of the Genesis bible.** The bible is split across `bible/` and indexed by
> [`../AGENT_ONBOARDING.md`](../AGENT_ONBOARDING.md). **When asked to "read the bible", read the index AND every
> chunk it lists, then follow all of it religiously.** This chunk holds: **§4 Codebase map — where every module lives across the five repos.**
> Section numbers (§0–§10) are the ORIGINAL bible sections and are preserved here; the §→chunk map lives in the index.

---

## 4. Codebase map (where things live)

```
genesis-core/genesis_core/
  types.py        PlatformContext (run_id, workspace, mcp, clis, settings, emit, secrets,
                  environments, checkpointer, extras); ValidationResult; Node(name,fn,kind);
                  CORE_MAJOR=1; CompatError; check_compat; CTX_KEY="genesis_ctx"; ctx_from_config.
  state.py        PlatformState TypedDict + reducers; new_state, record_artifact, record_decision.
  workspace.py    RunWorkspace (per-run blackboard) + Doc + default_artifacts_root.
  validators.py   toolkit: non_empty, parses_json, json_schema, required_keys, values_in_set,
                  count_between, first_field_is, excludes, referential_integrity, all_items_present,
                  matches_predicate, all_of, any_of (`_dig` dotted paths w/ []).
  mcp/registry.py   McpRegistry.acp_servers(names) -> ACP entries {name,command,args,env:[{name,value}]}
                    (env is a LIST — see §7). from_layers(curated,custom) merges the two tiers (ADR-029);
                    allowlist()/servers(). Resolve: SecretProvider → EnvironmentRegistry → os.environ.
  mcp/custom_store.py  CustomMcpStore: JSON-file CRUD + tool allowlist + validation (custom tier).
  mcp/introspect.py    direct MCP stdio client (JSON-RPC 2.0 initialize + tools/list) — agent-independent.
  clis/registry.py     CliRegistry.ensure/run + from_layers/clis; CliError.
  clis/custom_store.py CustomCliStore: JSON-file CRUD + validation.
  nodes/  program.py; agent.py (kiro_node: prompt_fn(state,ctx,out_path), output_doc, mcp=[],
          tools→trust_tools, _compute_effective_trust = node.tools ∩ server.allowlist, turn_timeout=420,
          startup_timeout=120; emits agent.message|thought|tool_call|tool_update|result; the result
          carries Phase-11 credits/context_pct/provenance from turn.usage); cli.py;
          validator.py; gate.py (hitl_gate via interrupt(); kinds approval|escalation|pre_mutation|review);
          subgraph.py; reliability.py (attach_reliability = the trio); tool_store.py + mcp/blackboard_server.py
          (Phase 9: per-run ToolOutputStore + save_tool_output/list_tool_outputs — save-by-reference).
  state.py `_telemetry_merge` sums `credits` (None never clobbers an accumulated total; Phase 11).

genesis/genesis/
  db/       database.py (Database: connection factory + PRAGMA WAL/busy_timeout/foreign_keys/row_factory
            + tx()); runner.py (Migration + migrate() + current_version/pending + contiguity guard);
            migrations/ (m0001_baseline adopts runs+run_events; m0002_chat adds chat_sessions+chat_messages;
            m0003_chat_usage adds chat_messages.usage; m0004_copilot adds chat_sessions.mode +
            chat_run_links + chat_permissions; m0005_supervision adds chat_notifications; m0006_copilot_actions adds the copilot audit trail; **m0007_kb adds the code-free temporal `kb_*` Appian KB tables (Phase 16-02); m0008_business_map adds `kb_business_maps` (17-01); m0009_documents adds `kb_documents`/`kb_document_links`/`kb_document_sections` (Phase 19); m0010_features adds `kb_features`/`kb_feature_specs`/`kb_feature_spec_revisions` (Phase 20); m0011_chat_model adds `chat_sessions.model` (Phase 21); m0012_scheduled_jobs adds `scheduled_jobs` (the backend scheduler's cadence + last-run, Phase 23)** — current_version=12). Schema is owned HERE (spec 01).
  kb/       (Phase 16-02) store.py (KbStore over `kb_*`: app lifecycle incl. table-scoped untrack; begin/apply
            [baseline+delta SCD-2]/finish syncs; recompute-on-sync bundles [flow_json verbatim]; tag_release/
            list_releases + point-in-time helper; contract-shaped reads; **+ list_syncs/latest_sync (16-04)**). **dev_mcp.py — Dev-MCP `listApplications` via a direct-stdio `tools/call` (16-04).** No source code stored (ADR-037);
            duck-types genesis-appian-parser's KbParseResult (pin lands in 16-03).
            **Phase 19 (Document Library): documents.py (DocumentStore over `kb_documents`/`kb_document_links`/
            `kb_document_sections` — global dedup store; list populates `linked_apps`; untrack unlinks-not-deletes);
            doc_parsing.py (ParsedDocument + parse_document/parse_bytes: PDF/DOCX/XLSX/CSV/MD/TXT → Markdown + per-tab JSON +
            heading sections + content_hash; google_export_target convergence; store_parsed); doc_sync.py (DocumentSyncEngine
            — injected via ctx.extras['document_sync']: resolve/fetch[gws]/parse/write + add_upload/add_gdrive + remove);
            build_evidence_pack extended with a `documents` key (bounded excerpts).**
            **Phase 20 (Features & Specs): features.py (FeatureStore over `kb_features`/`kb_feature_specs`/
            `kb_feature_spec_revisions` — feature CRUD; single spec per feature with a validated status
            draft→in-progress→in-review→completed; milestone revisions; untrack cascades features [ADR-042
            intrinsic-to-app]). `KbStore.untrack_application` also deletes `kb_features` (cascades specs+revisions).**
  integrations/gws/ (Phase 19, ADR-040) client.py (GwsClient — read-only Drive/Docs/Sheets/Slides allowlist, exit-code map,
            reuse vs isolated mode, list/get/export/download_file); login.py (GwsLogin — spawn `gws auth login`, capture the
            sign-in URL from stderr, track idle/pending/connected/failed); factory.py (build_gws_client/build_gws_login,
            isolated mode). Genesis owns an isolated config dir; reads the OAuth client from the dotfiles client_secret.json.
  cli_tools/native/ (Phase 19, ADR-040) installer.py (NativeCliInstaller — drop-in single-binary install/version/rollback/
            active_launch_spec/status) + lockfile.py (NativeCliLockfile — own atomic JSON store). The CLI analog of mcp/native/.
  runtime/  settings.py (Settings: state_dir ~/.genesis, artifacts_dir ~/Genesis/runs, db_path,
            library_dir, lockfile_path, secrets_path, environments_path, custom_mcp_path,
            custom_cli_path, **skills_dir=~/.genesis/.kiro/skills + skill_output_dir=~/.genesis/skill-output [Phase 14]**,
            **mcp_servers_dir=~/.genesis/mcp-servers [16-08]; cli_tools_dir=~/.genesis/cli-tools + isolated gws_config_dir + gws_client_secret_path (dotfiles ~/.config/gws/client_secret.json) + kb_documents_dir=~/.genesis/kb-documents [Phase 19]; feature_specs_dir=~/.genesis/feature-specs [Phase 20 — spec.html + revisions/<n>.html]**,
            retention_keep_last/max_age_days, retention_on_start); checkpoint.py
            (AsyncSqliteSaver); context.py (build_context); engine.py (async run/resume/get_state/stream).
            **Distribution (Phase 22): launcher.py (`genesis up/down/status/logs` — background serve + health-wait + open
            browser; PID/log under ~/.genesis/run); updater.py (dist config ~/.genesis/dist.json + semver tag compare +
            `apply` = checkout tag → pip install . → db upgrade → detached restart); kiro_auth.py (kiro-cli whoami status /
            pty device-flow login / logout); preflight.py (first-run `{items, ready}` readiness).**
            **Scheduling (Phase 23): scheduler.py (pure `due_slot` + a 60s asyncio tick engine — jobs as
            background tasks, handler-gated, mark-before-work, restart-safe within-day; started/stopped in the app
            lifespan); schedule_store.py (ScheduleStore over m0012 `scheduled_jobs`); sync_jobs.py (DEFAULT_JOBS +
            register_sync_jobs → `application-sync` [all apps, 07:00 IST wkdays, serialized] + `document-library-sync`
            [scope=library, 08/12/16/20 IST wkdays], preflight-skips).**
  dist/     gitlab.py, local.py, catalog.py, lockfile.py (**+InstalledSkill / Lockfile.skills — Phase 14, additive/back-compat**),
            install.py, loader.py (check_compat gate, meta_of [yaml, no import], graph_of, installed, load_build);
            **skill_catalog.py (reads skills-registry.json) + skill_install.py (SkillInstaller: pull skills/<id>/** at a
            ref into settings.skills_dir + record Lockfile.skills; update/remove) — Phase 14-02**.
  config/   secrets.py (SecretProvider/PlaintextProvider 0600; **atomic writes: temp+os.replace, and
            set/delete serialize read-modify-write under a per-path lock** — v0.20.1 crash fix), fields.py (mcp_cards/cli_cards/
            secret_fields/missing_secrets; GLOBAL_KEYS={GITLAB_TOKEN}), environments.py, retention.py
            (disk_usage, plan_prune/apply_prune [artifacts], prunable_runs + RetentionService [events +
            blackboard, spec 04]), health.py, service.py (ConfigService facade: merged registries, MCP/CLI
            CRUD, introspect, allowlist, test_server, secrets, environments, health).
  runs/     store.py (RunStore/RunRecord; statuses pending|running|awaiting_input:gate|
            awaiting_input:paused|done|failed|cancelled; TERMINAL set), eventlog.py (EventLog — durable
            run_events; append/list/last_seq/latest/purge/count/aggregate_tool_calls; **aggregate_credits/
            run_credits/credits_provenance via json_extract over agent.result — Phase 11**), steps.py
            (fold_steps → per-node summary incl. credits/context_pct), events.py (Event +
            single canonical EventBus — legacy dual bus removed in spec 04), validation.py, worker.py
            (SUBPROCESS entry; ops run|resume|get_state|update_state|fork; emits JSONL; sets the
            LangGraph `recursion_limit` from `META.execution.recursion_limit`, default 150 — 12-01), supervisor.py,
            manager.py (RunManager: start/pause/resume/cancel/respond/patch_state/fork/list/wait; writes
            canonical events to EventLog + fans out on cbus; `_CANONICAL_CUSTOM` persists agent.result &c
            with node+full payload; pending_gate [durable + checkpoint cold path]; log_events; steps).
  chat/     (Phase 10) manager.py (ChatManager/ChatSession: persistent read-only ACP client per live
            session, in-process — NOT a subprocess; stream_turn persists per-message usage + emits credits),
            store.py (ChatStore/ChatMessageStore on genesis.db: sessions + messages + usage; session_usage_total),
            events.py (map_message_to_events → canonical agent.* shapes), mcp.py (Atlas + introspection wiring
            + read-tool trust set). Read-only enforcement (ADR-031): trust_tools allowlist + permission_mode
            auto_deny. Phase 14: allow_fs_write=True but **sandboxed** via SDK fs_write_root to the per-session
            skill-output dir only (skill_output_dir/<session_id>); reload_skills/reload_all_skill_clients close
            live clients so a workspace change is picked up next turn.
  mcp/      introspection_server.py (read-only Genesis-introspection MCP server: list_runs/get_run/steps/
            events/list_failures/list_workflows/get_workflow/integration_health/platform_stats over a
            read-only genesis.db connection — Phase 10-02);
            **kb_server.py (Phase 16-05) — read-only genesis-kb MCP: the 17 Tier-1 KB tools over a `mode=ro`
            KbStore with Atlas-mirrored shapes; get_object_code/get_orphan fetch live SAIL via the Dev MCP
            (kb/dev_mcp.object_code), graceful code_status:unavailable. Launched `-m genesis.mcp.kb_server --db <db>`;
            wired into chat (chat/mcp.py) in place of appian-atlas**;
            **native/ (Phase 16-08, ADR-038) — installer.py (NativeMcpInstaller: install(id,bundle_path)→uv sync under
            settings.mcp_servers_dir/<id>/versions/<v>/ → verify entry → sha+lockfile → set current; rollback;
            active_launch_spec [launch from the per-server venv, not uv]; status; NO network update) + lockfile.py
            (NativeMcpLockfile — atomic own JSON store, not genesis.db)**.
  skills/   (Phase 14, ADR-034) model.py (parse_skill_md/validate SKILL.md frontmatter + SkillInfo +
            shadows_personal), store.py (SkillStore: filesystem repo over settings.skills_dir =
            ~/.genesis/.kiro/skills; path-traversal-safe create/list/get/remove + .genesis-source.json marker),
            service.py (facade + reload hook). dist/skill_catalog.py + dist/skill_install.py pull a library
            skill into the workspace + record Lockfile.skills. Chat auto-discovers the workspace (cwd/.kiro/skills)
            + writes documents to the per-session skill-output sandbox (SDK fs_write_root).
  api/      app.py (create_app FastAPI; version 0.48.4; **`_resolve_web_static` serves the SPA from packaged `genesis/web_static` [installed wheel] with a repo `web/static` fallback [dev]**; instantiates ChatManager + ChatRunSupervisor + SkillService + **Scheduler (Phase 23)**; registers chat/copilot/skills + **native-mcp** + **applications** + **documents** + **features** + **system** + **schedules** routes + per-session skill-output endpoints).
            ALL routes on an APIRouter at prefix="/api" (ADR-028) + a catch-all SPA fallback. Routes:
            catalog(+available), library install|update|DELETE; workflows/{id}(+/graph); config/health,
            gitlab-token, mcp-cards, cli-cards, mcp-cards/{server}/test, secrets, environments;
            config/mcp-servers CRUD(+tools+allowlist+test), config/clis CRUD; **config/environments(+/{label}/dev + /dev/check, 16-08 §2.0); config/native-mcp (GET status) + config/native-mcp/{id}/install|rollback (POST, 16-08 Stage B)**; **applications(+/available) + applications/{uuid}(+/sync +/sync-status +/objects(+/{uuid}) +/bundles(+/{id})) + DELETE (16-04)**; **config/native-cli (GET status) + config/native-cli/{id}/install|rollback + config/gws/auth (GET) + config/gws/auth/login(+/state) + config/gws/auth/logout (Phase 19); documents/upload + documents/gdrive + documents/{id}/link (POST/DELETE) + documents/{id}/sync + documents/sync + applications/{uuid}/documents/sync + GET documents(+?app_uuid) + documents/search + documents/{id} + DELETE documents/{id} (Phase 19)**; **applications/{uuid}/features + features/{id}(+PATCH/DELETE) + features/{id}/spec (POST create-opens-a-feature_spec-chat / GET) + features/{id}/spec/context (GET candidates / POST inject-as-./context/-files) + features/{id}/spec/milestone + features/{id}/spec/status + features/{id}/spec/{artifact,sdk.js,export.md} (Phase 20)**; config/retention/{plan,apply};
            artifacts/usage; home (metrics incl. **total_credits + credits_provenance**); runs (POST/GET),
            runs/{id}(+gate), runs/{id}/state (GET/PATCH), pause|resume|cancel|respond|fork,
            runs/{id}/artifacts(+/{name}(?mode)+/download), runs/{id}/events(?after,kinds,node)+/steps,
            runs/{id}/events/stream (canonical SSE); **chat/sessions CRUD + chat/sessions/{id}/messages
            (SSE turn) + /cancel (Phase 10); chat/sessions/{id}/mode + /notifications + GET/PUT config/copilot
            + chat/actions + resolve-permission (Phase 13 copilot); skills (GET/POST author/DELETE) +
            skills/available + skills/install + skills/update + chat/sessions/{id}/reload +
            chat/sessions/{id}/outputs(+/{name}(?mode)+/download) (Phase 14 skills)**. studio.py.
  cli/      main.py (genesis serve|install|list|create-workflow|test-workflow|db upgrade|db status|**mcp install-native|mcp status|mcp rollback-native**|**up|down|status|logs|update [Phase 22]** …).
  (scripts/  **install.sh — Phase-22 bootstrap; genesisctl.sh — thin wrapper over `genesis up/down/…`**.)
  lint/     contract.py (workflow.yaml↔META parity; YAML_ONLY_KEYS exempts UI-only keys like `graph:`),
            reliability.py (trio enforcement).
  web/      React + TS + Vite (ADR-026/027): Tailwind + Radix/shadcn-style + Zustand + React Router +
            TanStack Query + React Flow + Recharts + react-markdown/remark-gfm + mermaid (lazy) +
            CodeMirror (JSON editor) + lucide + sonner. Structure:
            src/styles/{tokens.css,index.css}; src/lib/{cn.ts, api/** [typed client PREPENDS /api +
            ApiError; resource modules], query/** [keys + client]}; src/stores/**; src/shared/ui/**
            (primitives: Button/Card/Badge/Chip/Dialog+Drawer/Tabs/SegmentedControl/Switch/Input+Field+
            Textarea/HealthDot/MetricCard/TrendChart/format/icons); src/shared/layout/** (AppShell/
            Sidebar/SplitPane/Page — **no top bar (removed v0.43.0); no breadcrumbs (removed v0.42.0); the theme
            toggle lives in Settings → General (`AppearanceSection`)**); src/shared/feedback/** (Empty/Error/Loading); src/app/**
            (providers, router, RootLayout, routes); src/features/{overview,settings,catalog,runs,
            run-detail,documents,chat,applications,library,features}/**; src/test/fixtures (golden contract fixtures); src/dev/KitchenSink.
            **features/features (Phase 20): FeaturesTab + CreateFeatureDialog + FeaturePage + SpecWorkspace (reused ChatThread
            + a sandboxed review `<iframe sandbox="allow-scripts">` served by the API + a postMessage annotation→chat bridge via
            an optional `registerSend` prop on ChatThread + status/milestone/Export-.md/Add-context). api/assets/lavish/ holds
            the vendored MIT Lavish SDK (artifact-sdk.js + mermaid-node.js, Genesis-themed) + the esbuild-built `sdk.js`.**
            **static/ = the COMMITTED, built app** served by `genesis serve`.
            Settings (Phase 8): SettingsPage = Tabs shell (/settings/:tab?/:id?); components/manager/**
            (ResourceManager, ResourceFormDialog, SpecForm, ConfirmDialog — the standardized pattern);
            components/mcp/** + cli/** (tabs+detail on that framework); EnvironmentsSection/GitlabSection/
            StorageSection reused; hooks.useMcpResources/useCliResources merge cards ⋈ custom entries.
            Run-detail conversation (spec 06): conversation.ts buildTranscript + groupTurns; inspector/
            TurnView + ThinkingTimeline + AssistantAnswer + conversationParts.
            Chat (Phase 10): features/chat/** — ChatThread REUSES the run-detail Conversation via a
            `hideResultChip` prop; Composer; SessionList; lib/api/chat.ts `readSse` (CRLF SSE framing).
            Skills (Phase 14): features/catalog/CatalogPage = Tabs shell (Workflows | Skills; static
            `catalog/skills` route ahead of `catalog/:workflowId` to dodge the dynamic-route collision);
            features/catalog/skills/** (SkillsTab + SkillCard + SkillAuthorDialog + hooks); shared/ui/file-drop
            (FileDropList); lib/api/skills.ts (+ client.postForm multipart). Chat `/` palette (Composer) is a
            unified Workflows(copilot-only)+Skills(both modes) menu → skill pick sends `/<name>`; features/chat/
            SessionOutputs renders the per-session skill-output sandbox via the shared DocumentPreview.
            Credits (Phase 11): shared/ui `formatCredits` + `CreditBadge` + `Coins`; Overview "Credits
            Used" KPI (replaced Tool-Calls); run-detail TelemetryStrip Credits stat + per-node + header
            run-total; chat per-message credit footer (in the ResultChip's old position).

genesis-workflows/
  registry.json (catalog + genesis_core_major=1), mcp-registry.json (REAL internal images:
  appian-atlas [read-only], jarvis [read-write-deploy], appian-data-generator, **appian-dev [read-only] + appian-devops [export-only] — managed-native, ADR-038, resolved the old `lcp` placeholder**, jira),
  cli-registry.json, bundles.json, schemas/, steering/01-07, ci/validate_library.py (7-gate publish
  runner), workflows/{_template, hello-appian, erd-generation, code-review, design-doc, sync-application, _fixtures/noncompliant}, MIGRATION.md.
  skills/{gam/SKILL.md + references/, _fixtures/noncompliant} + skills-registry.json + ci/validate_skills.py
  (self-contained pyyaml validator: registry+manifest+parity+fixture gate; a `skills-validate` CI job) — Phase 14-02.

# ── Phase 25 — Architectural Foundation Hardening (genesis v0.49.0 + genesis-core v0.9.4) ──
genesis-core/genesis_core/
  util/atomic_json.py   (25-03) path_lock / atomic_write_json (temp+os.replace) / read_modify_write_json —
                        the shared atomic-write primitive the custom MCP/CLI stores + genesis config use.
  agents/               (25-05, ADR-051) AgentProvider Protocol + KiroAcpProvider (wraps nodes/agent._load_real)
                        + get/set_agent_provider; nodes/agent._run drives turns through the provider.
genesis/genesis/
  domain/               (25-01, ADR-050) enums.py (EntityKind/LifecycleState/ArtifactKind), entities.py
                        (Feature/Spec/Story/Stage), transitions.py (declarative SPEC/STORY_STAGE tables +
                        preconditions + allowed_actions), lifecycle.py (LifecycleService — the single
                        transition authority; EntityLifecycle; build_spec_lifecycle/build_default_lifecycle;
                        state-CAS write, 25-08), events.py (LifecycleEvent), errors.py (Domain/Illegal/
                        Precondition/UnknownEntity/UnknownEntityKind/**StaleWriteError**). Import-clean, no FastAPI.
  services/             (25-06, C-5) ApplicationSyncService — the one add-app→baseline / refresh orchestration
                        used by BOTH api/applications.py + runtime/sync_jobs.py (SyncBusyError).
  runtime/logging.py    (25-02) zero-dep structured logging + contextvars correlation IDs + JSON/console
                        formatters + secret redaction; configure_logging wired into create_app (request_id
                        middleware) + worker (run_id) + CLI.
  kb/_{graph_reads,relationship_reads,evidence,object_reads}_mixin.py  (25-06, C-3) KbStore split into four
                        behavior-preserving read mixins via MRO (KbStore 1373→652); the SCD-2 write/sync path
                        stays in store.py (the to_thread deadlock lesson, §7). features.py adds row_version CAS
                        (_cas_update) + StaleWriteError (25-08, m0014).
  api/{config_routes,run_routes,catalog_routes}.py + api/_shared.py  (25-06, C-3) the core routes extracted
                        from create_app into register_config/run/catalog_routes(...); _shared.py holds the
                        request models + formatters (kills the create_app↔route-module import cycle). app.py is
                        now a 189-LOC composition root. run_routes threads StartRun.idempotency_key (25-08).
  chat/mode_profile.py  (25-07, C-4) ChatModeProfile + PROFILES{read_only,copilot,feature_spec} + resolve_profile;
                        ChatSession resolves ONE profile per session (no `self.mode ==` branching).
  db/migrations/        m0013_lifecycle (lifecycle_transitions audit, 25-01) + m0014_row_version (optimistic-lock
                        CAS column on kb_features/kb_feature_specs, 25-08); current_version=14.
  runs/manager.py       RunManager.start(idempotency_key=…) — in-memory dedupe of a double-submit (25-08, §17).
```

---

