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
- **Rendering a large parsed document to HTML on the main thread freezes the tab — show source for big docs (v0.50.2 live fix).** The full-screen document viewer (`web/features/library/DocumentDetailPage.tsx`, route `/documents/:id`) rendered the entire parsed Markdown (`content_md`) through `MarkdownView` (react-markdown + remark-gfm) **unconditionally, with no size guard or virtualization**. A real spreadsheet-derived doc (doc #4: `content_md` **~858 KB / 3,240 lines**, wide GFM tables, longest line 8,344 chars; its `tables.json` was 1.5 MB) **hung the tab for a long time** — remark parses the whole blob into an AST (GFM table parsing is expensive) and React commits **thousands of `<tr>`/`<td>`** nodes to the DOM, all synchronously on the main thread. It was NOT a backend/network/`crash` — the API sends `content_md` inline over localhost in ~ms; the cost is client render. It surfaced now because it was the first genuinely large doc opened (the earlier §7 note only fixed table *width* via `overflow-x-auto`, not render *cost*). **Fix:** a **Rendered | Source** toggle — Source renders the raw Markdown in the existing `CodeBlock` (a plain `<pre>` = one text node, instant regardless of size), and docs over `LARGE_DOC_CHARS` (200k) **default to Source** so they open immediately (user can flip to Rendered; small docs still default Rendered). Pure default logic isolated in `documentView.ts` + unit-tested. **Lesson: a document/preview surface must bound its render cost — cap/virtualize/offer a cheap source view for large content; `react-markdown` over hundreds of KB (especially GFM tables) is a main-thread hazard. The structured `tables.json` → a paged/virtualized grid remains the richer future option for spreadsheets.** _(Done in v0.51.1: a **Sheets** view mode + `SpreadsheetView` renders `tables.json` as a sheet-tab strip + paged grid — multi-tab Excel shows tab-by-tab, defaulting on for docs with a `tables_path`.)_
- **Verify the release commit contains EVERY changed file before tagging — a forgotten `git add` ships a test without its implementation and reds CI (v0.51.0 → v0.51.1).** The spreadsheet-viewer release committed the new `test_document_tables_endpoint` + the entire frontend + version bump, but the commit's explicit `git add` list omitted **`genesis/api/documents.py`** (the file holding the new `GET /documents/{id}/tables` endpoint). Locally everything passed (the endpoint was in the working tree); the tag `v0.51.0` checked out a tree with the **test but not the endpoint**, so `test_document_tables_endpoint` hit **404** and the `genesis` CI job went red (the `frontend` + `clean-install` jobs passed, which is a tell: only the Python job saw the gap). Fixed forward by committing the missing file + shipping **v0.51.1** (non-destructive — no tag force-move). **Lesson: when committing with an explicit path list, run `git status` first and confirm it's clean AFTER the commit (nothing modified left behind); prefer staging by reviewing `git status` over typing paths from memory. Tests and their implementation must ship in the same commit. A green frontend/clean-install with a red Python job on a release that touched the API is the fingerprint of an unstaged backend file.**
- **When you bump a repo's tag, update EVERY transitive pin that must move with it — a downstream repo pinning an older shared dep reds CI with `ResolutionImpossible` (Phase 26 release, genesis-workflows v0.10.0).** genesis-workflows pins **both** `genesis-core` (runtime dep) and `genesis` (dev dep). For the Phase-26 release I bumped the `genesis` pin `v0.44.0 → v0.52.0` but left the `genesis-core` pin at **v0.9.2** — while genesis v0.52.0 itself depends on **genesis-core v0.9.5**. pip can't satisfy `genesis-core==0.9.2` AND `genesis-core==0.9.5` → `ERROR: ResolutionImpossible` in the `library-validate` CI job (the local editable venv never re-resolved, so it passed locally — the failure only appears in CI's clean `pip install .[dev]`). Fixed by aligning the transitive pin to v0.9.5, re-pointing the just-created (broken) `v0.10.0` tag to the fix commit (a brand-new tag, safe to move; master got a normal fast-forward commit — no branch history rewritten), CI then green. **Lesson: a repo that pins a chain (genesis-workflows → genesis → genesis-core) must keep the WHOLE chain consistent — when you move the middle pin, move the shared-base pin to match what that tag depends on. Locally-editable installs mask the conflict; the clean-install CI job is the source of truth. A `ResolutionImpossible` naming two versions of a shared dep = a stale transitive pin.**

- **An app-process run→artifact bridge (StageFinalizer, ChatRunSupervisor) can miss a live terminal event — give it a level-triggered recovery AND make its failures loud (Phase 29 v0.55.2).** The first real live `ux-design-analysis` run (`r-72c0d9e55c6e`) finished **fully green** (14-page PDF, all nodes ok, grounded `verify` ok) but its UX stage was left **stranded** — `in-progress`, no completion chat, `analysis.html` not served. Root cause was NOT a bug in the finalizer's logic (wiring, method signatures, and the `run.final{status:"done"}` guard were all correct): the app-process `StageFinalizer` observes the worker's `run.final` **live**, but that event is only delivered to the process that **spawned** the worker — if the server bounced around run-launch (ADR-012 orphaned worker) the current process never saw it, and the safety-net `reconcile()` **only runs at startup**, which had already run *before* the run completed. Worse, every finalize error was `except: pass`, so nothing surfaced in the log. **Two fixes:** (1) **log** finalize failures (`log.warning(..., exc_info=True)`) — a swallowed finalization bug must not be invisible (the §7 honest-failures rule); (2) **in-flight recovery** — `StageFinalizer.reconcile_stage(stage_id)` finalizes one stranded stage from durable state (bound run + `done` + artifact, no completion chat), and the **feature/stage GET calls it best-effort on read**, so simply opening the stage self-heals it with no restart. A recovery-only finalizer is constructed in `register_features_routes` (NOT `attach()`-ed → no duplicate observer). **Lesson: any observer that bridges a subprocess/worker terminal into app state needs a recovery path that runs on demand (a read, a tick), not only at startup — startup reconcile races the run — and it must never swallow errors silently. The recovery must be idempotent (guard on "already finalized").** (The sibling `ChatRunSupervisor` shares the same startup-only-reconcile shape — a candidate for the same treatment.)
- **A cursor jumping BACKWARDS in the live run graph is usually the bounded verify→revise loop, not corruption (Phase 29).** On the same run the user saw the "last-but-one" node in progress and then "3 nodes suddenly in progress". That was real: the run's `decisions.verify_rounds == 1` — the grounded `verify` critic returned **"revise"** on its first pass, so `route_verify` routed back to **`synthesize`** (resetting the per-node retry counters, by design) and `synthesize → v_doc → verify` ran a **second** time before passing (`verdict: ok`). This is the ADR-057 grounded-critic loop doing its job (it is not a rubber stamp), not a state regression. Minor display note: the run-detail node-state fold (`deriveNodeStates`) flips a node to "running" only `if (d.status === "pending")`, so a node that already completed (`ok`) and then **re-runs in a loop** does not cleanly return to "running" — cyclic graphs (this + `code-review`'s per-item loop) render the re-run imperfectly. A future fold improvement: reset a node to "running" on a fresh `agent.*`/re-entry even if it was `ok`.

- **A completed run showed a mid-graph node stuck "Running" because the client `/events` fetch is capped and node status was event-derived (Phase 29 v0.56.0).** The run-detail graph derived per-node status purely from `GET /runs/{id}/events`, which defaults to **limit=1000**. A large/agent-heavy run (the first live `ux-design-analysis`: **6,627 events**, 5,397 `agent.thought` deltas) never loaded the later `node.completed` events (e.g. `live_grounding`'s at seq 21203, past the 18894 cutoff), so the fold left that node "running" and everything after it "skipped" — on a **done** run. `/steps` (server-side `fold_steps`) had the correct states all along. **Fixes:** (1) `deriveNodeStates` takes `/steps` as **authoritative** for per-node status + counts, overlaid on the event fold; (2) `useRunEvents` **pages** `/events` to completion so the conversation/inspector get every round's turns. Also: `fold_steps` now reports **`executions`** (count of `node.completed`) so loop rounds are visible (a graph loop like `route_verify→synthesize` re-completes a node — `attempts` only counted reliability retries), and the conversation groups turns under "Round k of N". **Lesson: never derive authoritative status from a capped/paginated event stream — reconcile against the server-side aggregate (`/steps`), and page the log when the UI needs the whole thing. A node that "runs again" in a graph loop is a real re-execution (count `node.completed`), distinct from a reliability retry.**

- **A run→artifact finalizer that sweeps "all done runs" must scope to the stage's CURRENTLY-BOUND run, and never restart `serve` while a run is active (Phase 29 v0.56.2).** Two coupled live findings on a re-upload. (1) **Orphaned worker:** restarting `genesis serve` (to ship the re-upload button) while a run was mid-`live_grounding` **killed its worker subprocess** (ADR-012: the worker is a child of serve; `genesis down` terminates it) — the run stuck "running" with no `run.final` (dead 8 s after its last event). **Never restart serve while a run is active** — check for active runs first; recover an orphan by cancelling it (there is no `run.final` to reconcile). (2) **Stale-run finalize:** a re-upload's `reset_for_reupload` clears the stage's chat/run/source and rebinds it to the NEW run, but `StageFinalizer.reconcile()` iterates **every done run**, so it finalized the stage from the **OLD, superseded** done run — resurrecting the previous analysis and then blocking the new run's finalize via the `chat_session_id` idempotency guard (leaving `run_id`=new but chat/html=old — a mismatched state). **Fix:** `_finalize` no-ops unless the stage's current `run_id` == the run being finalized (`reconcile_stage`, the on-read path, was already stage-run-scoped and correct). **Lesson: a sweep-style reconciler keyed by "done run" must verify the target still points back at that run before mutating it; and treat a serve restart as `pause=kill` for every in-flight run (ADR-012).**

- **Generalize a run→artifact finalizer with a workflow→stage BINDING REGISTRY, and gate `start` on the run lifecycle — not just "in progress" (Phase 30 / ADR-058).** Making the Technical Design stage live meant a SECOND workflow (`technical-design-analysis`) had to finalize into a SECOND stage (`technical_design`), reusing the Phase-29 `StageFinalizer`. The clean generalization was a module-level `_BINDINGS: {workflow_id → {stage, artifact_filename, chat_mode, seed}}`; `_finalize` resolves the binding by `rec.workflow_id` and **skips unknown workflows**, so one attached observer serves both UX + TD with the v0.55.2 recovery + v0.56.2 bound-run guard intact. Add a **defensive stage-match guard** (`row["stage"] == binding.stage`) so a run can never cross-finalize a different stage. **The subtle bug the review caught:** the JSON `start` endpoint guarded only against an *in-flight* run (`run_id` set, no chat) — but a second `start` on an *already-finalized* stage (`chat_session_id` set) would launch a run the finalizer then **skips** (its idempotency guard) → a stranded run. Gate `start` on BOTH: reject when finalized (→ "use re-run") AND when in progress. Lesson: when you turn a single-instance bridge into a multi-tenant one, key it by a registry (not a constant), keep every existing guard, and make the *entry* endpoint's precondition cover the whole lifecycle (unstarted / in-flight / finalized), not just the middle state.
- **A prerequisite (gated) stage is an amendment to the parallel model — enforce it on BOTH sides + expect it to pull into the roll-up (Phase 30).** ADR-056 said "no stage gates another"; Technical Design needed Spec + UX first. Modeled as `StageDescriptor.requires: StageKey[]` + a pure `deriveAvailability(detail, def)`; enforced **frontend** (locked card + blocked workspace, not navigable) AND **backend** (start 409 + `resolve_inputs` fail-fast) so the two can't drift. Flipping a reserved stage to `available:true` also **pulls it into `deriveFeatureStatus`** (the rolled-up "Completed" now needs Spec + UX + Technical Design) — a real, correct behavior change that broke the existing `stages.test.ts`/landing assertions; update them with the migration rather than special-casing.

- **A single agent turn that must emit a large multi-part artifact will hit `turn_timeout` and TRUNCATE — decompose + assemble deterministically (Phase 30 post-ship, genesis-workflows v0.14.0).** The `technical-design-analysis` `assemble` node asked one Kiro turn to stitch ~12 workstream blocks (~195 KB in → ~55 KB out) into one HTML doc. On the first real run it hit `turn_timeout` (~428 s) → the output was **truncated** (dropped a workstream, duplicated others, multiple `</body></html>`), AND because a timed-out turn never sends the final `_kiro.dev/metadata`, its **credits came back `unavailable`** (the "239 vs ~400" gap — ADR-032, don't fabricate). BOTH symptoms had ONE root cause: an oversized agent emission. **Fix:** program owns structure, agent owns only small prose — a bounded `synthesize` agent (cross-cutting Overview + Complex Designs) + a **deterministic program `assemble`** that concatenates the already-validated per-workstream blocks (each exactly once, in build order) + a programmatically-consolidated Open Questions. Lesson: never ask one agent turn to reproduce a large structured document; generate the parts under the reliability trio, then assemble mechanically. A turn whose `duration_ms ≈ turn_timeout` with `provenance:unavailable` is the fingerprint.
- **A gate→END terminal path must set a terminal status, or the worker's snapshot leaks the resumed 'running' (Phase 30 post-ship).** `runs/worker._snapshot` did `status = status or "done"` on graph completion; the happy path works because the `present` node sets `status="done"`, but the `escalate` (hitl_gate) → END path leaves the state's status at the post-resume `"running"` (truthy) → the completed run is reported **`running` forever**, so the StageFinalizer (fires on `run.final{status:"done"}`) never finalizes the stage. **Fix:** on a completed graph (no next node, no interrupt) `_snapshot` returns a terminal status (`done` unless the graph explicitly set `failed`/`cancelled`). Lesson: any `gate → END` (or any terminal node that isn't the one that sets the done status) needs the worker to treat "graph complete" as terminal — don't rely on a leftover state field.
- **Never derive the run-graph's node status OR its full conversation from the whole event log on every tick — it's O(events²) and stalls large runs (Phase 30 post-ship perf).** The run-detail page fetched ALL events (60 k+ on a big agent run — mostly `agent.thought` deltas) and re-folded them for the graph (`deriveNodeStates`) on every SSE tick, and the Inspector filtered the growing array per node. That made the graph lag/stall to load + go unresponsive as iterations grew. **Fix:** the graph derives per-node status from **`/steps`** (authoritative, small) + `run.cursor`; the Inspector fetches only the **selected node's** events (`/events?node=` server filter); SSE streams **only while active** and just invalidates `/steps` on node transitions (no per-delta client accumulation). Lesson: `/steps` is the authoritative small aggregate — page/scope the raw event log, never fold all of it per render.
- **For a cyclic layered graph (workflow with retry/revise loops), pre-reverse back-edges before handing it to the layout engine — ELK/dagre's own cycle-breaking scatters the validators; and route edges AROUND nodes (Phase 30 post-ship run-graph revamp).** dagre stacked the graph vertically; ELK's `layered` algorithm laid it left→right but its greedy cycle-breaking **reversed the `agent→validator` edges** to break the retry 2-cycles, mis-layering `v_plan` into column 1 (next to `load_inputs`) instead of after `plan_sections` — a scattered, "stacked"-looking mess. **Fix:** detect back-edges by DFS ourselves and hand ELK the graph with those edges **reversed** (so it sees a DAG → correct monotonic layering) — ELK then also **routes every edge orthogonally around nodes** (dummy-node routing for long "skip" edges like `validator→escalate`), which handle-anchored `smoothstep` does NOT (it cuts straight through intermediate nodes). Draw ELK's routed poly-line via a custom edge (reversed edges' routes flipped back), filter out `END`-sentinel edges (no node → ELK errors / undefined points). **Verified via headless Chrome (CDP):** monotonic pipeline, 0 node overlaps, 0 edges through a non-endpoint node. Lesson: control cycle-removal yourself for correct layering; use the engine's orthogonal router (not straight handle edges) so lines avoid nodes; and when you can't see the browser, drive it with CDP to read the real rendered DOM instead of guessing.
- **Serve the SPA `index.html` with `Cache-Control: no-cache` (Phase 30 post-ship).** `FileResponse` sent no cache-control on `index.html`, so a browser could keep an already-open tab on a stale shell that referenced the previous build's hashed JS — a fix "didn't reflect" on a page until a hard-refresh. Fix: `index.html` (and the SPA fallback) send `no-cache, must-revalidate`; the content-hashed `/assets/*` stay immutably cacheable. Lesson: the SPA shell must always revalidate so a normal reload picks up the latest build.
- **`<Button asChild>` is broken in this codebase — never use it (Phase 31 live fix, v0.59.1).** The shared `Button` renders `<Slot>{loading && <Loader2/>}{children}</Slot>` when `asChild`, so the falsy `{loading && …}` is always a SECOND child and Radix `Slot`'s `React.Children.only` throws `expected to receive a single React element child` — crashing the whole route on render. Unnoticed because NO prior code used `<Button asChild>` (only Tooltip/Dialog/DrawerTrigger asChild); the Feature-Breakdown **Export** button was the first, and it only rendered once the stage went in-review (so tests of the locked/landing state missed it). Fix: don't use `<Button asChild>` — style an `<a>` with `buttonVariants(...)` or use a plain `<Button onClick>` (Export now downloads via a temporary `<a download>`); + a regression test rendering the in-review card actions. Lesson: a UI primitive that injects its own sibling children can't be a Slot host; render-time crashes hide behind conditional states — test the state that actually renders the new control.
