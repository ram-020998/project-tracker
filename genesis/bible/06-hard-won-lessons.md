<!-- GENESIS BIBLE — CHUNK 06. DO NOT summarize or drop content when editing; keep it verbatim-faithful. -->
> **This file is one chunk of the Genesis bible.** The bible is split across `bible/` and indexed by
> [`../AGENT_ONBOARDING.md`](../AGENT_ONBOARDING.md). **When asked to "read the bible", read the index AND every
> chunk it lists, then follow all of it religiously.** This chunk holds: **§7 Hard-won lessons — do not regress these.**
> Section numbers (§0–§10) are the ORIGINAL bible sections and are preserved here; the §→chunk map lives in the index.

---

## 7. Hard-won lessons (do not regress these)

- **ACP MCP env MUST be a list of `{name,value}`** (`McpRegistry.acp_servers`). A dict silently drops env in kiro-cli acp → the MCP container runs without secrets and hangs to timeout. This broke erd-generation. When stubbing an external contract, mirror its REAL schema (a permissive stub hid this).
- **`kiro_node` builds the real `KiroAgentOptions`** (cwd, trust_all_tools, trust_tools, agent, model, agent_engine, kiro_cli_path, extra_args, mcp_servers, startup_timeout, turn_timeout, stream_limit_bytes, debug). There is NO `tools` field (map an allowlist to `trust_tools`). turn_timeout=420, startup_timeout=120 for heavy MCP.
- **SSE streaming:** the per-run bus stays open until the run is TERMINAL (so gate pause/resume keeps streaming); the client dedupes replayed history and CLOSES the EventSource on terminal final/error (else it auto-reconnects and re-replays forever — the "repeated activity" bug). The server sends NAMED SSE events (`event: <kind>`); the client registers a handler per kind.
- **Data plane is SQLite, not JSON** (`~/.genesis/genesis.db`, WAL): runs + full conversation + checkpoints. Only bulk artifacts are files. Schema is owned by `genesis/db/` migrations (spec 01) — never hand-write DDL in the repositories; add a migration. Gate/approval controls MUST derive from durable state (`GET /runs/{id}.gate` via `manager.pending_gate`), NEVER from a transient event.
- **Canonical event kinds:** `run.started` / `node.completed` / `agent.message|thought|tool_call|tool_update|result` / `validator.result` / `retry.scheduled` / `gate.awaiting|resolved` / `run.final` / `error`. There is NO `node.started`/`node.failed` — "running" = `run.cursor`; failure is attributed to the cursor on a failed run. The single live `EventBus` + durable `EventLog` are the whole event model (the legacy dual bus was removed in spec 04).
- **Run Detail resilience:** if a workflow declares no `graph:` topology, the UI derives a fallback from `/steps` (or events) so the graph is never blank. Workflows SHOULD still declare `graph:` (the catalog preview needs it; node ids must match LangGraph node names).
- **Conversation (spec 06):** `buildTranscript` folds `agent.*` events → items; `groupTurns` groups them into turns (validator/retry notes attach to the just-closed turn). The Thinking panel auto-expands while live and collapses on the turn's `result`. Markdown answers reuse the 07-09 renderers (no new deps).
- **Worker error reporting:** a generic `worker_exit` must NOT clobber a specific `error` event; empty-message exceptions report their type + a hint. For MCP-server logs, run the container standalone (Genesis hides them in the ACP subprocess).
- **LangGraph specifics:** sync `invoke` can't run async nodes; sync `SqliteSaver` fails under async (use `AsyncSqliteSaver`). `Command(resume=...)` needs a checkpointer-compiled graph. Fork seeds a NEW thread.
- **API namespacing (ADR-028):** browser routes (`/runs`, `/catalog`, `/settings`) are real client paths; ALL backend endpoints live under `/api`; the client prepends `/api` centrally and REJECTS non-JSON (throws `ApiError` → `ErrorState`). Uniform 500s on `/api/*` in the browser usually means the BACKEND ISN'T RUNNING (the Vite proxy 500s on connection-refused) — `curl http://127.0.0.1:8760/api/config/mcp-cards` first.
- **Frontend contract fixtures:** mirror the 07-02 event/GateDescriptor/topology/steps shapes in `web/src/types` + the golden fixtures in `web/src/test/fixtures`; a drift must fail a test (`contract.test.ts` feeds the golden log through the real folds). The "stub hid the contract" lesson applies.
- **Settings data (Phase 8):** MCP/CLI detail needs BOTH the merged card view (`mcp-cards`/`cli-cards`: status + secret fields) AND the custom entry (`mcp-servers`/`clis`: raw spec + allowlist + source) — joined by name in `useMcpResources`/`useCliResources`. Curated tier is read-only; custom is editable/deletable through the standardized `ResourceFormDialog`/`ConfirmDialog`. Use `HealthDot` + tokens, not raw colors.
- **`workflow.yaml`** may carry UI-only keys (e.g. `graph:` topology) — the parity lint exempts them via `YAML_ONLY_KEYS`.
- **jest-axe (v9)** ships no types: ambient `declare module` + the vitest matcher augmentation live in `web/src/types/jest-axe.d.ts` + `web/src/vitest-axe.d.ts` (keep them pure ambient / module-aug); the matcher is extended globally in `web/src/test-setup.ts`.
- **mermaid + Recharts are heavy;** mermaid is dynamic-imported (lazy chunk). Keep new heavy libs lazy.
- **Credits are REAL, not estimated (Phase 11 / ADR-032).** Kiro reports per-turn credits via the
  `_kiro.dev/metadata` notification: the final one of a turn carries `meteringUsage:[{value,unit:"credit"}]`
  + `contextUsagePercentage` + `turnDurationMs`. Verified **per-turn, not cumulative** (spike: 0.184 then
  0.113 in one session). The SDK captures it into `ResultMessage.usage`/`TurnResult.usage`; agent.py puts
  it on the `agent.result` event; `manager._CANONICAL_CUSTOM` persists that payload verbatim into
  `run_events`, so `aggregate_credits` (json_extract) + `fold_steps` + SSE all get it for free. The
  `_telemetry_merge` reducer must NOT let a None (unavailable) credits value clobber an accumulated sum.
- **Chat read-only (Phase 10 / ADR-031):** trust is fail-CLOSED — never trust-all; build the allowlist
  with the namespaced `@server/tool` form (kiro-cli matches that way). A curated server with NO registry
  `tool_allowlist` (e.g. `jarvis`, which is read-write-deploy) means the ONLY cap is the node's `tools=`
  list — a read-only workflow MUST set an explicit read-only `tools=` allowlist on every agent node
  (effective trust = node.tools ∩ server.allowlist).
- **SSE framing is CRLF:** sse-starlette frames events with `\r\n\r\n`. A client reader that splits on
  `\n\n` never parses a frame (the "stuck on Thinking…" chat bug, fixed v0.19.1). `readSse` splits on
  `/\r?\n\r?\n/`. Don't let a LF-only test fixture hide it.
- **Secret writes must be atomic + serialized (v0.20.1 crash fix).** FastAPI runs sync route handlers in
  a threadpool, so two secret-set requests (e.g. two fields of one MCP server) run concurrently. A plain
  `write_text` isn't atomic → concurrent writers corrupt `secrets.json` (a valid object + leftover tail =
  "Extra data"), which 500s `/api/config/mcp-cards` and crashes the UI. Fix: temp-file + `os.replace`
  (atomic) + a per-path lock around read-modify-write. The other JSON stores (mcp-custom/cli-custom/
  environments) share the old non-atomic pattern — harden them the same way if touched.
- **Looping workflows (Phase 12 note):** LangGraph's default `recursion_limit` is **25 supersteps** and
  the worker doesn't raise it, so a per-item loop dies after ~6 items — a looping workflow needs the
  worker to set a higher limit (from META). Also, `attach_reliability` keys retries by agent NODE NAME, so
  a re-entered loop node must RESET `retries[node]=0` each iteration or later items get no retry budget.
- **Phase 9 save-by-reference:** a huge MCP result (e.g. a 3000-line process model) must not re-enter the
  context window — the agent calls `save_tool_output(ref, document=...)` to persist it to the blackboard
  by reference (the per-run ToolOutputStore records every tool result). Prompts instruct "never paste
  tool output into your reply — save it BY REFERENCE".
- **Workflow graph.py with custom reducer state keys must NOT use `from __future__ import annotations`.**
  The loader imports graph.py standalone (`spec_from_file_location` → not registered in `sys.modules`),
  so LangGraph's `get_type_hints()` can't re-resolve stringized annotations — a `class MyState(PlatformState):
  reviewed: Annotated[list, add]` dies with `NameError: Annotated`. Eager (non-`__future__`) evaluation
  stores real `Annotated` objects and works. (erd-generation's state has no reducer keys, so it never hit
  this; the code-review workflow did.) Also: quote YAML flow-scalars containing `?`/`:` (e.g. `label: "Stale?"`).
- **Parse saved MCP tool outputs DEFENSIVELY — real shapes vary per tool (Phase 12 live-run lesson).**
  `save_tool_output` persists a tool's result verbatim, and jarvis tools are inconsistent: some wrap
  JSON in a human-readable preamble (`get_package_contents_from_url` → `Package Contents from URL:\n\n[…]`;
  `get_application_info` → `Application Info:\n{…}`), others return clean JSON (`get_jira_issue`,
  `get_review_checklist`). Shapes also differ from the obvious guess: object `type` is a QName
  (`{http://…/types/2009}Interface`) with a separate `typeId`; `get_review_checklist` is **3-level
  nested** (`parentCategory→categories→checkListItems`) with `applicableObjectTypes` as display names
  ("Expression Rule", not "ExpressionRule"); `jarvis_config` nests `appUuid`/`kbFolderId` under
  `applications[].appConfig` with `globalSettings` a list. The code-review workflow added `_coerce_json`
  (strip preamble), `flatten_checklist`, and normalized type matching. **Systemic gotcha:** a
  `validator_node`'s `check_fn(data,…)` receives `data` from a plain `json.loads` that falls back to
  raw text on failure — so any JSON-consuming validator must coerce `data` itself (don't assume it's a
  dict). Stubbed tests won't catch these; validate against real captured artifacts under
  `~/Genesis/runs/<wf>/<run>/`.
- **Kiro Skills load over ACP from the filesystem, NOT the wire (Phase 14 spike, 2026-07-16).** kiro-cli
  auto-discovers **skills** from `<cwd>/.kiro/skills/` (workspace) + `~/.kiro/skills/` (global) — there is **no
  `skills` param on `session/new`** the way there is `mcpServers`. A real-ACP spike proved a `SKILL.md` in the chat
  session's `cwd` (`~/.genesis`) both **auto-activates** (by `description` match) and is **explicitly invocable**
  via `/skill-name` in the prompt text. So to give the agent a skill you **write files** into a Kiro workspace, you
  don't inject it over the wire. `--help` doesn't list skills (they're a convention, not a flag) — the binary's
  changelog strings + the spike are the evidence. Do NOT set `KIRO_HOME` to relocate skills (it also relocates the
  user's agents/sessions/settings/auth). See `spike/2026-07-16-kiro-skills-in-acp-and-chat.md` + ADR-034.
- **Pin the linter — unpinned `ruff` drifts and breaks CI on pre-existing code (Phase 16-02).** genesis CI does
  `pip install -e ".[dev]"` then `ruff check genesis`. With `ruff>=0.6` (floating), a newer ruff released a **changed
  default rule set** (added `UP*`) that flagged ~170 pre-existing `Optional[...]` usages repo-wide — a green release
  (v0.27.2) went red 18 days later with **zero code change**. Local `ruff check genesis` (older pinned venv ruff) still
  passed, hiding it. Fix: **`ruff==0.15.20`** in dev deps so CI reproduces local exactly. When adopting a newer ruff,
  do it deliberately with a repo-wide fix (`ruff check --fix` the `Optional`→`X|None` churn) + bump the pin. (Tests
  aren't ruff-gated in CI — only the `genesis` package is — so test-file lint drift won't fail CI.)
- **A blocking DB write inside an async node deadlocks the LangGraph checkpointer — do blocking `genesis.db`
  writes OFF the event loop (Phase 16-03).** `genesis.db` is shared: the async `AsyncSqliteSaver` (aiosqlite) and
  any sync `genesis.db.Database` writer coexist. When a program node does a **synchronous, blocking** KB write
  (`KbStore`) *inside the async worker*, that call holds the single-threaded event loop while it waits on the
  sqlite write lock — but the checkpointer's own `aput`/`aput_writes` do `execute` then `await commit()`, so if a
  checkpoint write is in-flight (lock held, commit pending) the commit can never run to release the lock →
  **deadlock** until busy_timeout expires → flaky `sqlite3.OperationalError: database is locked` (green locally,
  red under CI timing; it can pass on one pipeline and fail on the tag pipeline for the *same commit*). **Root
  cause = sync-blocking-write-in-async-node, NOT a PRAGMA.** **Deterministic fix:** run the blocking write via
  `await asyncio.to_thread(...)` so the loop stays free for the checkpointer to commit/release (the `sync-application`
  `write_kb` is a raw async node for exactly this; `program_node` is sync-only). Reproduced in isolation: a sync
  write on the loop FAILS in ~5s, `to_thread` SUCCEEDS in ~0.25s. **Complementary (necessary, not sufficient):**
  WAL + a `busy_timeout` on *both* the checkpointer connection (`runtime/checkpoint.py`) and every `Database`
  connection so writers serialize with bounded waiting rather than erroring. WAL/busy_timeout alone did NOT fix it
  (only reduced the flake) — the loop-starvation deadlock is the real issue. Reads (WAL) don't take the write lock,
  so validator/read nodes can stay sync.
- **Pin ruff in EVERY repo that runs `ruff check` in CI (16-08 recurrence of the 16-02 lesson).** The pin was applied to
  genesis but NOT genesis-core; the first time genesis-core's CI re-ran (its first release since ruff drifted), the
  unpinned `ruff>=0.6` flagged **44 pre-existing `UP037`** ("remove quotes from type annotation") findings and failed an
  otherwise code-clean release. Local `ruff check genesis_core` (pinned venv ruff) passed, hiding it. Fixed by pinning
  `ruff==0.15.20` in genesis-core too. Rule: any repo with `ruff check` in `.gitlab-ci.yml` pins ruff to the
  locally-verified version.
- **MCP introspection must allow a large `tools/list` line (16-08).** `genesis_core.mcp.introspect` reads
  newline-delimited JSON-RPC via `asyncio` stream readers whose default line limit is **64 KiB**. The Appian **Dev MCP
  returns 145 tools in one `tools/list` line** (well past 64 KiB) → `ValueError: Separator is not found, and chunk exceed
  the limit`. Fixed by spawning with `limit=8 MiB`. Any server with a big tool surface hits this — Settings "Test
  connection" / allowlist introspection would fail on the Dev MCP without the bump.
- **Managed-native launch vs. env-resolution boundary (16-08, ADR-038).** `NativeMcpInstaller.active_launch_spec` returns
  the **binary location only** (command/args from the installed per-server venv); the `${VAR}` env template stays on the
  `mcp-registry.json` entry and is resolved by `McpRegistry` (SecretProvider→Env→os.environ) exactly like every other
  server — so the installer never touches secrets and updating the binary needs no registry edit. The Dev/DevOps **URL**
  vars (`LCP_URL`, `APPIAN_DOMAIN`) resolve from the **dev-tagged** env via `EnvironmentRegistry.resolve_var` (not the
  per-run active env), so Chat and workflows both reach the single Phase-16 target.
- **The genesis `frontend` CI job only runs on `changes: [web/**/*]` (16-08).** A release that lands web changes in one
  tag but ships a follow-up tag touching no web (e.g. a pin/version bump) will NOT re-run the stale-bundle guard. If a
  **transient CI infra failure** (e.g. a Gitaly `HTTP 500` at the git-fetch step, seen on the v0.31.0 pipeline) kills the
  frontend job on the web-changing tag, re-trigger it with a real `web/**` touch (`glab` can't retry — read-only token) —
  don't assume a later green pipeline covered the guard.
- **Match the real Appian Deployment REST contract for the export — read the vendor's own client, don't guess (16-07 live fix).**
  `sync-application`'s export was hand-rolled to a guessed endpoint (`POST …/deployments/export`, JSON body) and **405'd**
  against the live env. The authoritative reference is the **installed DevOps MCP** (`appian-deployment-mcp`): export is a
  **multipart `POST /suite/deployment-management/v2/deployments`** with an **`Action-Type: export`** header + a `json` part
  `{uuids, exportType, name}`; poll `GET /deployments/{uuid}` to `COMPLETED`; download the poll response's **`packageZip`**
  URL; auth header **`appian-api-key`**. Lesson: when hand-rolling a vendor REST call, read the vendor's client rather than
  guessing, and add a request-shape regression test (a permissive stub hides a 405).
- **De-dupe KB objects by UUID — real exports repeat UUIDs (16-07 live fix).** A real Appian export can list the **same
  `object_uuid` more than once**, so a baseline `KbStore.apply` hit `UNIQUE(app_uuid,object_uuid,valid_from_sync)`. Fix:
  `apply` de-dupes objects by UUID (edges by their `(source,target,dep_type)` triple), keeping the first; and the
  workflow's baseline `check_kb` reconciliation is **`0 < written ≤ parsed`** (distinct ≤ raw), not `==`. Synthetic
  fixtures had unique UUIDs and hid this — validate against a real package (verified on a live 2516-object app).
- **A newly-released library workflow must be `genesis install`-ed before it can run — and a missing workflow must not
  500 (Phase 17-05 live).** `run_manager.start(workflow_id, …)` raises if the workflow isn't in the local library
  (`~/.genesis/library`); the `business-map/generate` endpoint surfaced that as a bare **500 "Internal Server Error"**.
  After releasing a workflow in genesis-workflows, run `genesis install --from ../genesis-workflows` (the running
  `genesis serve` picks up the new workflow at run-start — no restart needed; only a *server-code* change needs a
  restart). The endpoint should catch the load failure and return a friendly 409/400 ("install the workflow library")
  — tracked in 17-06.
- **Rendering a real graph needs level-of-detail, not `fitView`-to-fit (Phase 17-05 live).** `fitView` crammed a
  14-node value stream into a short pane → unreadably tiny nodes with most off-screen and no cue to pan ("the data
  looks minimal"). What made it usable: a **readable zoom floor** (`fitViewOptions.minZoom ≈ 0.4–0.55`) + a **MiniMap**
  + pan + wider dagre spacing; **click-for-detail popups** so node cards stay compact instead of truncating text; a
  **manual radial** layout (not dagre) for a domain→capabilities *constellation* to avoid a shared-entity crisscross,
  with entities shown as **chips inside** the capability card rather than separate crisscrossing nodes; and
  **`smoothstep`** edges + arrowheads so branch/loop paths don't overlap. Note: React Flow renders a custom node only
  when `node.type` matches a `nodeTypes` key — a default node renders `data.label` (which business nodes don't set →
  blank), so a `nodeTypes` mismatch looks like "empty nodes".
- **Parser dependency extraction must scan EVERYTHING, and "orphan" ≠ "unbundled" (Phase 18).** `genesis-appian-parser`
  (ported faithfully from Atlas) reported **804 orphans / 30.7%** on a real app, **803 provably false**. Two root causes,
  both inherited: (1) reference extraction was **field-path-scoped** (`SAIL_CODE_FIELDS`/`STRUCTURAL_FIELDS` had **no
  entries** for Constant/AI-Skill/Decision/Translation-String/Document → those types emitted **zero** edges); (2)
  `is_orphan` meant *"not reachable from an entry-point bundle"*, which mislabels used-but-unbundled objects. Fixes that
  took edge recall 0.32→**0.98** / orphans 804→**0**: run dep analysis on **RAW** data (before the resolver rewrites
  `#"_a-uuid"`→`rule!Name`); a **universal known-UUID scan over every string + the raw XML** (transient, still code-free
  per ADR-037) so no reference form/field/type is missed; add record-action + translation-string URNs, CDT **QName**
  (`{urn:…}Type`) refs, and `rulereferencebyname("X")` by-name refs; and **redefine `is_orphan` = disconnected (no
  incoming AND no outgoing edges)**. Keep the scan **known-UUID-gated** for precision (0.999).
- **An Appian prefixed id `_a-<base>_<suffix>` shares its base with folder-siblings — base is a GROUP id, not an object
  id (Phase 18).** Resolving a reference by base UUID alone over-links to an arbitrary sibling (precision cratered
  0.999→0.80 when tried). Match on the **full or canonical (`_a-<base>_<numericSuffix>`)** id; only use base when it is
  **unique** across the package. The accuracy **oracle** has the same trap — and must attribute each file to its object
  by **filename stem** (universal: every object file is `<uuid>.xml`), NOT the in-XML `<uuid>` (a child for content
  objects, a root `uuid="…"` attribute for the rest — 1,386 files were mis-mapped, which falsely showed precision 0.41).
- **APPREF/ENTRYPOINT is a by-name cross-app integration mechanism (Phase 18, user-taught).** Apps soft-integrate across
  environments via `rulereferencebyname(ruleName:"AS_GSS_ENTRYPOINT_…")` — a **name string**, not a UUID, with the peer
  usually in a *different* package (so the object has no in-package incoming edge and looks orphaned). Classify these via
  the ENTRYPOINT/APPREF naming convention (+ the 10-value category taxonomy GETDATA/DISPLAY/STARTPROCESS/RECORDACTION/
  LOGIC/URL/SAVE/APPVERSION/REF/AI, adopted from Jarvis) + behavioral (`rulereferencebyname` caller); **exempt them from
  orphan reporting** and surface them as cross-app integration points (`integration_role`/`integration_peer`/
  `integration_category` in `KbObject.metadata`, + a `stats.cross_app` app-level map ported from Atlas
  `app_cross_app_builder`).
- **When porting a parser front-half, you may silently drop whole layers — diff against the source (Phase 18).** Our port
  dropped Atlas's `output/app_cross_app_builder.py` (cross-app), `output/graph_builder.py` (inbound/outbound + is_hub),
  and the entire `enrichment/` package. A concept-by-concept inventory of BOTH reference implementations (Atlas on disk +
  indexed; the Jarvis plugin decompiled with `javap` — macOS `strings` misreads Java `0xCAFEBABE` as a Mach-O fat
  binary, so use `javap`/a constant-pool reader) is the way to get "best of both". Matrix in `specs/phase-18-*.md` §9.
- **A repository list method must populate the SAME derived fields its single-get promises (Phase 19 live fix).**
  `DocumentStore.get_document` attached `linked_apps`, but `list_documents` returned raw rows without it — the web table read
  `d.linked_apps.length` and crashed (`Cannot read properties of undefined (reading 'length')`) the moment a real (non-mocked)
  list was rendered. The unit test's fixture happened to include `linked_apps`, so it hid the gap ("the stub hid the contract"
  again). Fix: `list_documents` populates `linked_apps` for every row in ONE grouped query; the frontend also reads
  `(d.linked_apps ?? [])` defensively; the API test asserts the field is present. Lesson: derived/joined fields belong in the
  list method, and API tests must assert the shape the UI depends on — don't let the mock be more generous than the backend.
- **Google-native export → converge on the binary parser; auto-sync on add (Phase 19).** A Google Sheet is exported to **.xlsx**
  (not CSV) so `openpyxl` gives per-tab structure, and Docs→`text/markdown`, Slides→`text/plain` — every Google-native doc then
  flows through the *same* `parse_document` used for uploads (no separate Google parser). Uploads parse **synchronously at add**;
  a Drive add only registers the file, so the add endpoint **auto-starts a single-doc `sync-documents` run** (best-effort — the
  content otherwise wouldn't appear until a manual sync). The document viewer must be **full-width with `overflow-x-auto`** (a
  wide spreadsheet's Markdown table overflows a fixed-width card).
- **An agent that must AUTHOR files needs BOTH cwd=sandbox AND the fs tool trusted — and know that fs writes vs tool
  permissions are separate gates (Phase 20, two live fixes).** Reusing the read-only chat setup for the spec-authoring
  `feature_spec` session broke agent file writes twice. (1) **cwd mismatch:** cwd was `state_dir` but `fs_write_root` was the
  per-session sandbox, so the agent's relative `spec.html` resolved outside the sandbox → the SDK's `fs/write_text_file`
  handler refused it. Fix: set **cwd = the sandbox** for `feature_spec` (so a relative write lands in-sandbox, where the
  milestone save also reads it). (2) **permission vs capability:** in the SDK, `fs/write_text_file` is gated ONLY by
  `allow_fs_write`+`fs_write_root` (NOT `permission_mode`), while `session/request_permission` (untrusted **tools**) is what
  `auto_deny` rejects. kiro-cli asks permission for its built-in **`fs_write` tool** before writing, so `auto_deny` denied it
  upstream of the sandbox. Fix: **trust `fs_read`/`fs_write`** for `feature_spec` (the write is still confined by
  `fs_write_root`; every other tool — shell, MCP mutations — stays untrusted → denied). Ground truth came from the SDK's
  `client.py` + `test_permission_policy.py`, not the agent's self-diagnosis (it mislabeled a sandbox refusal as "prompt
  declined"). Lesson: read the SDK's actual permission model; the two gates are independent.
- **Give a CLI agent bulk context as FILES in its workspace, not as chat content (Phase 20).** "Add context" first dumped each
  document's full Markdown into the transcript (as a system message) — token-heavy every turn and it cluttered the chat. Better:
  write the docs as files under the session's `./context/<id>-slug.md` (the agent's cwd/sandbox) and post only a short note
  naming them; the Kiro agent reads them **on demand with its file tools**. There is no ACP "attach documents" wire param for a
  chat session (unlike `mcpServers`), so files-in-cwd is the idiomatic, efficient mechanism — and it composes with the
  cwd=sandbox fix above.
- **Embedding a 3rd-party browser SDK: prefer `postMessage`-host reuse over running its server (Phase 20, ADR-043).** Lavish's
  injected `artifact-sdk.js` talks only via `parent.postMessage` (no server calls), so we vendor two source files, bundle them
  with our own esbuild, serve the artifact + SDK **same-origin** from the API, host it in a **sandboxed iframe** (`allow-scripts`,
  no `allow-same-origin`), and let our React chrome be the host — no second window, no `:4387` server, no Node-≥22. Theme it via
  the vars it already exposes on its shadow `:host` (a one-line patch → `var(--lavish-*, fallback)`), fed from Genesis tokens.
  Keep a golden `postMessage`-schema fixture so an upstream bump can't silently change the contract.
- **The Kiro ACP extension surface is richer than the public docs — spike the *installed* CLI, and prefer typed methods over
  `execute` (Phase 21).** Against **kiro-cli 2.16.2** (the 21-01 spike): the **model list + agents come free on `session/new`**
  (`result.models` = `{currentModelId, availableModels[]}`, `result.modes` = agent personas) — no separate call, no Settings
  fallback; **`session/set_model`/`session/set_mode`** are plain requests. The **slash-command catalog** arrives as the
  `_kiro.dev/commands/available` **notification** (calling it as a request → -32601), carrying `commands` + `prompts` + `tools`.
  The advertised per-command `optionsMethod` (e.g. `_kiro.dev/commands/model/options`) is **NOT wired** in 2.16.2 (-32601) →
  do **autocomplete client-side** off the catalog. **`_kiro.dev/commands/execute` streams** its output and a `panel` command may
  not return a terminal result headlessly (it times out) → treat it as a streaming turn (bound it with a `command_timeout`) and
  keep **sending the slash text through the normal prompt path as the fallback**. `contextUsagePercentage` (already captured for
  metering) + `promptCapabilities.image` are present. Lesson: these `_kiro.dev/*` extensions are experimental — pin the verified
  CLI version in the findings, keep the SDK methods additive/no-op when the peer doesn't advertise, and don't trust the docs'
  version over what the installed binary actually answers.
- **Exposing the CLI surface in a "read-only" chat = refine the ADR, keep the human-confirm backstop (Phase 21, ADR-045).**
  Broadening chat to the full command/model surface makes it no longer categorically read-only (ADR-031). The safe move was
  **not** to trust-all, but to keep the default trust set read-only + `permission_mode="ask"` so any write-capable tool a
  command triggers still raises the Phase-13 confirm card; introspection commands run freely. Consciously recorded as ADR-045
  (refines ADR-031) rather than silently widened.
- **Route Kiro slash commands through the normal `prompt()` path, NOT `_kiro.dev/commands/execute` (v0.46.1 hotfix).**
  21-05 dispatched chat slash commands via the `execute` extension. Verified vs **kiro-cli 2.17.0**: that method
  **times out for EVERY command headlessly** (not just `panel`/`selection` ones — `/context`, `/tools` too, even with a
  subcommand) and streams nothing, so the turn blocked the full `command_timeout` (120s) and the chat "hung", then stored an
  empty assistant message (`provenance:unavailable`). kiro-cli instead **intercepts a leading-slash `session/prompt`** and
  returns/streams the result immediately (`/effort` → "Available effort levels: low, medium, high, xhigh, max"; `/effort high`
  → "Effort set to high"; `/clear`,`/compact`,`/model`,`/usage` all return in ~0s). Fix: `ChatManager.stream_turn` +
  `run_slash_command` (the Clear/Compact buttons) send the raw slash text through `prompt()` (no steering/preamble wrapper).
  The per-command `optionsMethod` (`_kiro.dev/commands/*/options`) is STILL unwired (-32601) in 2.17.0, and the catalog's
  `subcommands` are only the static management subcommands (e.g. `/effort` → `set-current-as-default`) — the dynamic option
  lists (effort levels, model ids) are NOT enumerable over ACP, so client-side option autocomplete for them isn't possible;
  bare `/effort` returning the levels as a reply is the honest UX. `execute_command` is left in the SDK (released API) but unused.
- **The chat MD export must match the REAL return shapes (v0.46.1 hotfix).** Two 21-06 export bugs, both hidden by a stub:
  (1) `ChatMessageStore.session_usage_total()` returns a **float** (or None), but `session_to_markdown` treated it as a
  `{"credits": …}` dict → `AttributeError: 'float' object has no attribute 'get'` (the test only exercised the None case). Now
  it accepts a float OR a dict. (2) `agent.thought` events are streaming **deltas** (≈one token each); rendering each as its own
  `> 💭` line — and `.strip()`ping each — shattered the thinking into one-word lines and destroyed boundary spaces ("gr"+
  "ounded"). Fix: concatenate consecutive thought deltas **raw** into a single blockquote. Lesson: when consuming events/store
  values in a NEW renderer, assert against the real shapes (float total, delta thoughts), not a convenient stub.
- **The built SPA must ship as PACKAGE DATA, and Dev-MCP enumeration must surface errors + paginate (v0.48.2).**
  Three real-install bugs found deploying to a fresh machine: (1) **`/` 404'd** while `/api` worked — the wheel only packaged
  `packages=["genesis"]`, but `web/static` lives at the repo root (a sibling), so the SPA never shipped; the runtime resolved
  `parents[2]/web/static` = `site-packages/web/static` (absent). Fix: **`force-include web/static → genesis/web_static`** in
  pyproject + `_resolve_web_static()` prefers the packaged path with a repo fallback. The clean-install CI job only checked
  `/api/config/health` (200), not `/`, so it missed it — it now asserts `/` serves the SPA shell. Lesson: anything outside the
  package dir isn't in the wheel unless force-included; test the *installed* artifact, not just the editable tree. (2) A Dev-MCP
  **HTTP 401** was swallowed as an empty list → the UI said "No untracked apps found" instead of "auth failed": MCP tool results
  signal failure via **`isError: true`** in the result envelope (not an exception) — check it and surface the reason. (3) The
  Add-application list was **capped at 50** — `listApplications` defaults `limit=50`; **paginate by `offset`**, advancing by the
  actual returned count (correct whether the server honors `limit` or caps it), stopping on an empty/no-new page.
- **A managed-MCP bundle can silently disagree with the registry on env-var names (v0.48.2 / genesis-workflows v0.9.4).** The
  Dev-MCP app list came back **401 even with correct creds + path** — same creds worked from the user's clone. Root cause: the
  installed lcp-mcp-server build reads **bare `USERNAME`/`PASSWORD`** for basic auth, while genesis injected only
  `LCP_USERNAME`/`LCP_PASSWORD` → no password found → no auth header → 401 (proven by giving it `USERNAME`/`PASSWORD` → 50 apps).
  It was NOT our install step, NOT credentials, NOT `LCP_AUTH_METHOD`, NOT the path — all ruled out by diffing the installed
  bundle vs the clone. Fix: the `appian-dev` registry injects **`USERNAME`/`PASSWORD` from the same stored `LCP_*` secrets** (no
  new UI fields — field rendering is driven by `secretKeys`/`publicKeys`, not the env map), supporting both builds. Lesson: when
  a "healthy" managed MCP misbehaves, diff the *installed* bundle's source against a known-good one and confirm the env-var
  contract; note macOS sets `USER`, not `USERNAME`, so such vars MUST be injected by the launcher.
- **"delta" sync = full re-export + LOCAL diff, not an environment patch; and a scheduled Appian export must be serialized
  (Phase 23).** The `sync-application` `mode=delta` (16-07) was mistaken for "needs a delta package from the environment" — it
  actually re-exports the WHOLE app and diffs against the KB by `diff_hash` locally (open new / close+reopen modified / close
  removed / recompute bundles). It just wasn't reachable: `api/applications.py._start_sync` hard-rejected any non-baseline mode.
  So a "full-package refresh" was an API unblock, not a new engine. The load-bearing constraint for scheduling it: the Appian
  **Deployment REST export is one-at-a-time** — the workflow treats HTTP 409 "a deployment is already in progress" as
  transient, so the daily all-apps job MUST run apps **serially** (start → poll `run_manager.get(...).status ∈ TERMINAL` →
  next), never fan out N subprocess exports (409-storm + resource spike). A backend scheduler (`runtime/scheduler.py`) is a
  60s asyncio tick that fires jobs as **background tasks** (never block the loop), marks the slot **before** the work (no
  double-fire), and is **restart-safe** via a persisted `last_fired_slot` embedding the local date (within-day catch-up, no
  cross-day re-fire) — TZ/weekday/daytime windows come from a DB table (m0012) so it's user-configurable later. Auto-firing
  runs are safe under ADR-001/026/033 (read-only Appian export + local writes, `auto_approve`, same `RunManager.start` a human
  clicks) but a **schema bump breaks every hardcoded `current_version==N` test** — bump them with the migration.
- **Shipping = clone + git-tag self-update, browser-based — reuse Friday's model, verify against the real CLI (Phase 22).**
  Genesis ships as a git clone + `pip install .` (one clone; internal deps via their git+ssh tag pins) launched by `genesis up`
  (opens the browser) and updated by checking out release tags — modeled on `appian/prod/friday`, minus the native `.app`
  (ADR-046). Two real-CLI findings the spec's assumptions got wrong until tested against the installed binary: (1) **the genesis
  repo's default branch is `master`, not `main`** — the updater's tracked-branch default + `install.sh --branch` had to be
  `master` (else `git clone --branch main` fails and update-checks falsely report "wrong branch"); (2) **`kiro-cli whoami
  --format json`** on THIS CLI prints a logged-in object with **no `account` key** (`accountType`/`email`/`startUrl`) plus
  trailing non-JSON `Profile:` lines — a naive `{"account": null}` check (Friday's shape) + `json.loads(full_stdout)` both
  falsely reported logged-out, so parse the **first JSON line** and detect identity claims. Lesson: for distribution/auth
  plumbing, probe the *installed* tools (branch names, `whoami` shape, that `kiro-cli login` needs a TTY → drive it over a
  stdlib `pty`, no `expect` dep) rather than trusting the docs or a peer project's older assumptions.
- **A launcher/process-control belongs in ONE place (Phase 22).** `genesis up/down/status/logs` live in `runtime/launcher.py`
  (health-wait + PID/log under `~/.genesis/run` + browser-open, loopback-mapped for 0.0.0.0/::); the CLI subcommands and
  `scripts/genesisctl.sh` (now a thin wrapper) both call it — no duplicated bash. The one-click updater's restart is a
  **detached** `down; up` (`start_new_session`) so the request-serving process can exit and the SPA polls health + reloads.

---

- **A workflow that reads a core Appian credential must resolve it via the ADR-048 env seam, not `ctx.secrets` (v0.9.6 live fix, app↔workflow version skew).** Since genesis **v0.48.5** (Phase 24-01/ADR-048) the two core Appian creds (`LCP_USERNAME`/`LCP_PASSWORD`/`APPIAN_API_KEY`) live in the SecretProvider under a **per-environment** scope (`env-<sha1(label)[:16]>/VAR`) and are resolved **only** from the dev-tagged env via `EnvironmentRegistry.resolve_var` — the app's startup migration even moves keys **out of** `appian-devops/` into the env scope. But `sync-application` **v0.2.2** still called `ctx.secrets.resolve("APPIAN_API_KEY", server="appian-devops")`, and `PlaintextProvider.resolve(var, server)` checks only `server/VAR` then `global/VAR` — never the env scope. So the key the app stored where ADR-048 says it belongs was invisible to the workflow → baseline export failed with "APPIAN_API_KEY secret is not set (scope 'appian-devops' or 'global')" (run `r-0860e996…`). It surfaced now because the deployed app (v0.48.7) was ahead of the installed workflow (v0.2.2). Fix (workflow v0.2.3): resolve the key via `ctx.environments.resolve_var("APPIAN_API_KEY")` **first** (the one seam the app injects secrets into — `build_context` wires `EnvironmentRegistry(..., secrets=…)` so it works in the worker), then fall back to `ctx.secrets.resolve(...)` for pre-ADR-048 installs. **Lesson: when the app changes *where* a credential lives (a new scope/seam), every consumer — including installed library workflows pulled at runtime — must move to the new seam; a workflow shipped on an older tag is a live version-skew hazard. Both `ctx.environments` and `ctx.secrets` are on `ctx`, so a standalone-loaded `graph.py` can use the seam without importing the platform.**
- **A managed-native CLI's `--output` may be confined to the process cwd — set `cwd`, pass a relative `-o` (gws 0.22.5, Phase 19 live fix).** `gws` **0.22.5** rejects an `--output` outside the process's current directory (`… is outside the current directory`, validationError code 400). `GwsClient._run` spawned `gws` via `subprocess.run(...)` with **no `cwd=`**, so it inherited the server's cwd (the genesis checkout, where `genesis up` was launched), while `export_file`/`download_file` passed an **absolute** `-o` under `~/Genesis/runs/…` → rejected. It surfaced only now because `gws` had never been connected before, so the binary's path-confinement had never been exercised. Fix: `_run` takes an optional `cwd` (None = inherit — unchanged for `list`/`get`/`auth`, which write no files), and `export_file`/`download_file` run gws with **`cwd=out_path.parent` + a relative `-o` (basename)** so the run-artifacts path is always inside cwd. The isolated config dir is set via `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` (absolute env var), so changing cwd is safe. Reproduced directly: running gws from the repo with `-o /tmp/…` → the 400; running it with cwd=the output's parent → validation passes. **Lesson: a single-binary CLI connector may confine file outputs to cwd; don't assume an absolute `-o` works — run the tool from the output directory and reproduce the confinement with a fake binary in the regression test.**
