# Backlog: findings from the architecture documentation pass (2026-11-11)

> **Status:** UNVERIFIED. Found by reading the v0.81.0 code while writing `architecture/` (one writer per module).
> Nothing here was reproduced or tested. Each item needs a failing test or a repro before it is treated as a bug.
> The architecture documents describe the code as it is and do not state these as facts.

## Runs and workers
1. `RunManager.patch_state` on a **paused** run spawns `update_state`; the worker's `final` snapshot reports the
   state's `status` (`running`), and `_claim_status` stores `running` with a `run.final{running}`, leaving a
   `running` run with no worker (it would be failed as orphaned at the next restart).
2. `artifact.saved` (and other non-canonical `ctx.emit` types) are stored as kind `custom` with no node, so
   `fold_iterations`' per-turn `artifacts` list never fills.
3. `genesis/runs/worker.py` `_load_registries` loads only the curated registries (no custom tier, ADR-029) and
   builds `CliRegistry` without a launch provider (managed CLIs unresolvable via `ctx.clis`).
4. `genesis/runs/supervisor.py`: worker stderr is not written to `genesis.log`; only the last 2000 characters reach
   the run on a non-zero exit.

## API, launcher, distribution
5. `genesis/runtime/launcher.py` `up()` does not forward `--i-understand-no-auth` to `genesis serve`, so
   `genesis up --host 0.0.0.0 --i-understand-no-auth` fails in the child; the updater's restart has the same gap.
6. `genesis/api/app.py` startup: the `supervisor`, `stage_finalizer` and `story_design_finalizer` reconciles swallow
   exceptions with no log line (L-058 "make failures loud").
7. `genesis/api/run_routes.py` `POST /runs` does not map `FileNotFoundError` for an uninstalled workflow (L-033).
8. `genesis/dist/gitlab.py` `latest_tag()` returns the API's first tag; the updater uses the highest semver.
9. `genesis/runtime/updater.py` `apply`: `scope` is computed but unused; step 6 runs `genesis install` with no ids,
   which installs every workflow in the catalog.
10. `scripts/install.sh` usage text is stale (`--branch main`, "once Phase 22-02 lands").
11. `genesis/api/config_routes.py` comments say models live in `app.py` (now `_shared.py`); `test_server` docstring
    says "NOT a live handshake" but it does one.

## Configuration and settings
12. `genesis/runtime/settings.py`: unreachable code after `return` in `collab_hub_dir` (a lost method header).
13. `Settings.load()` never reads `GENESIS_COLLAB_HUB_APP_UUID` although comments and `collab/service.py` expect it.
14. L-070's legacy `appian-dev/LCP_URL` secret is not removed by the migration.

## Chat
15. `ChatManager.reap_idle` has no caller, so `GENESIS_CHAT_IDLE_MINUTES` has no effect.
16. `ChatRunSupervisor` nudges use `enqueue_system_turn` (transcript only), not `enqueue_agent_note`.
17. Copilot kill-switch, caps and rate limit apply to `POST /runs` only; `respond`/`cancel` ignore the token;
    `PUT /config/copilot` does not close live copilot clients.
18. `ensure_agent_catalog` caches an empty catalog until restart.

## Workflow library and lints
19. `registry.json` `erd-generation` is 1.0.0 while its `workflow.yaml` is 1.1.0; summaries differ for
    `memory-maintenance` and `story-design-analysis`; gate 5 compares ids only.
20. `genesis/lint/contract.py` `check_hitl_posture`: the gate loop does nothing, `SANCTIONED_GATE_KINDS` is unused,
    and no gate or CLI calls it (ADR-021 says CI enforces it).
21. `genesis-workflows/schemas/*.json` are used by nothing; `mcp-registry.schema.json` requires `command`, which
    managed entries lack.
22. `story-implementation` declares the `appian` skill, which is not in the library and resolves only through the
    global `~/.kiro/skills` fallback (ADR-069).
23. The memory workflows' `graph.py` import `genesis.memory` inside functions (graph.py should import only
    `genesis_core`).

## Knowledge base, parser, documents
24. Parser: bundle `entry_point.expressions` and flow `gateway_conditions` text do not pass `_strip_sail`
    (`output/bundle_structure_builder.py:107,251`; ADR-037).
25. Parser `api.py`: when `source` is bytes and `reader.read` fails, the temporary zip is not removed.
26. `dev_mcp.object_code` fetches current code only; ADR-037 describes historical fetches by version.
27. `KbStore.archive_application` and `tag_release` have no production callers.
28. `kb_server.search_documents` promises a snippet the store does not return; `kb_documents.raw_path` is never
    written; status `stale` is never set by the backend.

## Features, stories, Workbench
29. `api/features.py` stage-start routes set `in-progress` with the raw store (no LifecycleService, no audit; ADR-050);
    `PATCH /spec/status` bypasses the table; `stage_breakdown_rerun` does not check finalized stories.
30. `api/app.py` never calls `StoryImplementationFinalizer.reconcile()` at startup.
31. `api/workbench.py` `start_design`/`start_implementation` move the card before `run_manager.start`; a failed start
    leaves the card moved. `start_verification` does not check the card is in Deployment.

## Testing
32. `testexec/workspace.py` `export()`: `node_modules` is a symlink to the workspace's, and the drift check omits it,
    so an agent edit there reaches the shared workspace.
33. `integrations/apwt/client.py` `_scrub` replaces only the raw password (the runner covers escaped forms).

## Collaboration, memory, scheduler, observability
34. `collab/service.py` `autopull_tick` saves the cursor before `pull_all()`; a failed pull is not retried until the
    next Hub change. No escape hatch for a record that can never resolve (L-082).
35. `web/src/features/collab/hooks.ts` `usePublishBacklog` has no caller (the L-085 pattern).
36. `memory_server`: `get_entity_memories`/`get_related_entities` do not filter by owner; the "read-only" server can
    create `memory_vectors`. `update_memory` drops `pinned`/`protected` on the new row.
37. The installer may not install the `embeddings` extra, so a default install may run with `NullEmbedder`.
38. `runtime/scheduler.py` `_fire`: a cancel at shutdown leaves `last_run_status="running"`; sync handlers would run
    on the loop. `kb_hub_pull` reports `ok` on partial failure; `document_library_sync` reports `ok` at start.
39. `runtime/logging.py`: `session_id` and `tool_call_id` are never bound; redaction covers `extra` keys only.
40. `api/metrics.py` returns credits `0.0` with no metering where `api/home.py` returns `None`.

## Web
41. `/dev` gallery routes are in the production bundle; `useRunEvents` is unused; the stale-bundle CI guard
    (`git diff --quiet -- static`) misses new untracked files.
