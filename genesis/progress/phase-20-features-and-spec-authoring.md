# Progress — Phase 20: Features & Spec Authoring

> **Status (2026-08-11):** ✅ **SHIPPED — PHASE 20 COMPLETE (20-01..20-06).** Released **genesis v0.45.0** (single-repo;
> genesis-core/genesis-workflows unchanged), CI green; **ADR-042/043 Accepted**. m0010 (schema v10). Live-accepted (feature →
> spec chat authors `spec.html` → annotate in the embedded review → comment flows into the chat). Spec:
> `specs/phase-20-features-and-spec-authoring.md` (+ `20-01..20-06`).

## 20-01 — Embedded annotation spike ✅ (PASS + user-confirmed)
Proved Path B (embed the Lavish annotation SDK) before building. Findings: `spike/2026-08-11-lavish-embed.md`.
- Pinned `kunchenguid/lavish-axi` @ **`899747a`** (npm 0.1.50, MIT). The injected browser SDK (`artifact-sdk.js` +
  `mermaid-node.js`) is plain ESM, makes **0** network calls, and talks only via `parent.postMessage`.
- A 2-line browser entry (`import {createArtifactSdk, deriveLavishQueueKey}` → call it) bundled through **our esbuild 0.21.5
  (Node 20.20)** into a **~70.5 kb** self-contained IIFE — esbuild resolves `mermaid-node.js` automatically (cleaner than
  Lavish's own `.toString()` `createSdkJs` assembly). **No `lavish-axi` npm dep, no server/CLI/poll, no Node ≥22.**
- Captured the bridge schema: `lavish:queuePrompt {prompt:{uid,selector,tag,text,prompt,target?:{type:"text-range",text,
  start/end anchors},_lavishQueueKey}}` + `lavish:sendQueuedPrompts`.
- **User confirmed** the in-browser round-trip (element + text-range annotations arrive with anchors + comment).
- **Theming (ADR-027):** the SDK builds its palette on the shadow `:host`; seam = make it consume `--lavish-*` overrides
  (fallbacks preserved) + inject Genesis tokens (`--primary #6d8bff` etc.) via `injectLavishSdk` — applied in the harness,
  var→token map recorded for 20-05 (do it theme-aware; log the vendored-SDK patch in `THIRD-PARTY-NOTICES.md`).

## 20-02 — Data model + `FeatureStore` ✅ (code-complete, uncommitted)
**Migration `m0010_features`** (`genesis/db/migrations/m0010_features.py`, schema **v10**) — three tables mirroring the
`kb_*` idiom (`CREATE TABLE IF NOT EXISTS`, additive/forward-only):
- `kb_features` (`app_uuid` FK → `kb_applications ON DELETE CASCADE`, name, description) + `ix_kb_feature_app`.
- `kb_feature_specs` (`feature_id` FK → `kb_features ON DELETE CASCADE`, title, status DEFAULT 'draft', `chat_session_id`
  [no FK — independent chat lifecycle], `html_path`, `content_hash`, `md_export_path`) + `ix_kb_spec_feature`.
- `kb_feature_spec_revisions` (`spec_id` FK CASCADE, `revision_no`, `html_path`, `note`, `UNIQUE(spec_id, revision_no)`) +
  `ix_kb_specrev_spec`.
Registered in `db/migrations/__init__.py` (`MIGRATIONS += features`).

**`FeatureStore`** (`genesis/kb/features.py`) — same style as `DocumentStore` (injected `Database`, `tx()`/`connect()`,
never creates tables): feature CRUD (`create/list/get/update/delete_feature`; `list_features` LEFT-JOINs the spec's
id+status); spec lifecycle (`create_spec` [draft], `get_spec`, `get_spec_for_feature`, `set_spec_html`, `set_status`
[validated against `VALID_SPEC_STATUSES = draft|in-progress|in-review|completed`], `set_md_export`, `delete_spec`); milestone
`add_revision` (auto-increment `revision_no`) / `list_revisions` / `get_revision`. `delete_feature` returns the deleted spec
ids so the caller can remove `feature_specs_dir/<spec_id>/`. Exported from `genesis/kb/__init__.py`.

**Wiring:** `settings.feature_specs_dir` (`~/.genesis/feature-specs`, parallel to `kb_documents_dir`) for the on-disk bulk
`spec.html` + `revisions/<n>.html`. `KbStore.untrack_application` gains an explicit `DELETE FROM kb_features WHERE app_uuid=?`
(cascades specs+revisions via FK) — the **ADR-042 intrinsic-to-app** rule, contrasting Phase-19 documents (which only unlink).

**Tests:** `tests/test_feature_store.py` (9) — version=10, feature CRUD + list-with-spec-status, FK requires a real app,
spec create/lookup, validated status transitions (reject unknown), html/md pointer round-trip, revision auto-increment +
`UNIQUE`, `delete_feature` cascade + returned spec ids, **untrack-app cascades features/specs/revisions**. `tests/test_db.py`
bumped to v10 (applied list, `schema_migrations` rows incl. `features`, current_version/pending; the synthetic
next-migration test moved 10→11 since m0010 is now real). Version assertions in `test_document_store`/`test_chat_store`/
`test_kb_store` bumped 9→10. **Full suite: genesis 384 pytest green; `ruff check genesis` clean.**

## 20-03 — Features surface + feature page shell ✅ (code-complete, uncommitted)
**Backend** `genesis/api/features.py` (`register_features_routes(api, settings, kb_store)`, wired in `create_app` after the
documents routes): `GET/POST /applications/{uuid}/features` (create validates the app via `KbStore` + a non-blank name),
`GET/PATCH/DELETE /features/{id}` (delete also `shutil.rmtree`s each cascaded spec's `feature_specs_dir/<spec_id>/`), and
`POST/GET /features/{id}/spec` (v1 **one-spec-per-feature** guard → 409; default title `Spec: <feature>`; the spec's
`chat_session_id` is bound in 20-04). Unknown app/feature → 404.

**Web** `web/src/features/features/`: `types/features.ts` + `lib/api/features.ts` (`featuresApi`) + `qk.features` +
`hooks.ts` (TanStack: `useFeatures`/`useFeature`/`useCreateFeature`/`useUpdateFeature`/`useDeleteFeature`/`useCreateSpec`) +
`status.ts` (spec-status label/tone) + `CreateFeatureDialog.tsx` (name + description) + `FeaturesTab.tsx` (feature cards +
Create → navigate to the feature page) + `FeaturePage.tsx` (full page: header + back-to-app + the **Create spec** empty state,
and a spec-workspace **shell** that 20-04/20-05 fill in). Wired the **Features** tab into `ApplicationDetail` (6th tab) and the
route `applications/:appUuid/features/:featureId` into `router.tsx`.

**Tests:** `tests/test_features_api.py` (6 — CRUD, name/app validation, create-spec + one-per-feature guard, default title,
404s) → **genesis 390 pytest green, ruff clean**. `web/src/features/features/features.test.tsx` (4 — lists cards, create +
navigate, jest-axe, feature-page create-spec) → **web 142 Vitest (18 files) green**; tsc + eslint (0 errors) + `npm run build`
clean (`web/static/` rebuilt, uncommitted with the rest until 20-06).

## 20-04 — Spec chat backend ✅ (code-complete, uncommitted)
Makes the spec's authoring a real **Chat** (reuse of Phase 10), no new orchestration (ADR-001 intact).

**Chat core (additive):** a new **`feature_spec`** session mode — `ChatStore.set_mode` accepts it;
`ChatManager` adds `_STEERING_SPEC` (selected on a fresh client for that mode) and a `create_session(title,
mode=...)` param. `feature_spec` reuses the **read-only client path** (so `genesis-kb` + introspection are
wired and the Phase-14 `fs_write_root` sandbox lets the agent write `spec.html`); only the steering differs.
`read_only`/`copilot` paths are untouched.

**`api/features.py` (rewritten):** `register_features_routes(api, settings, kb_store, chat)`. `create_spec`
now opens a `feature_spec` session, **seeds** the app/feature identity + KB-scoping via
`chat.enqueue_system_turn` (the existing deterministic transcript seam), and stores `chat_session_id` on the
spec. New endpoints: `GET /features/{id}/spec/context` (the app's linked business artifacts = the picker
source) + `POST …/spec/context` (validate each doc is linked to this app → inject its parsed Markdown,
capped at 8000 chars, as a system message); `POST …/spec/milestone` (copy `skill_output_dir/<session>/spec.html`
→ `feature_specs_dir/<spec_id>/spec.html` + `revisions/<n>.html`, set the pointer + sha256 hash + a revision;
friendly **409** when nothing authored yet); `PATCH …/spec/status` (validated transition). Wired `chat` into
`create_app`'s features registration.

**Decisions / deviations from the draft:** (a) context injection is **conversational** — GET-available +
POST-inject only (dropped the draft's tracked injected-set + DELETE; removing content from an LLM's context
once sent isn't meaningful). (b) Identity is seeded into the transcript + carried by the static
`_STEERING_SPEC`; the cold-start replay preamble is **bounded** (last ~10 msgs / 4000 chars), so in a very
long conversation the seeded identity could age out on a client cold-start — a durable per-session preamble
is a noted future refinement (not load-bearing for v1; live behaviour is validated at 20-06).

**Tests:** `tests/test_features_api.py` (9 — CRUD + seeded `feature_spec` session + add-context inject &
app-linkage rejection + milestone 409→snapshot→increment + status validation + 404s), asserting chat state
via `app.state.chat`. **genesis 393 pytest green, ruff clean.** No web changes (the chat UI + review surface
are 20-05).

## 20-05 — Embedded review surface + annotation→chat bridge ✅ (code-complete, uncommitted)
The visible heart: annotate the spec HTML in-app and have it flow into the chat (ADR-043).

**Vendored SDK (ADR-043):** the themed Lavish SDK source (`artifact-sdk.js` + `mermaid-node.js`, MIT @ `899747a`, with the
20-01 `--lavish-*` theming patch) + an `entry.js` live in `genesis/genesis/api/assets/lavish/`; `sdk.js` is the esbuild-built
IIFE (72.5 kb, browser). **No `lavish-axi` npm dep, no server/CLI/poll.** (Rebuild: `esbuild entry.js --bundle --format=iife
--platform=browser --outfile=sdk.js`.)

**Backend (`api/features.py`):** `GET /features/{id}/spec/sdk.js` (serves the bundle), `GET …/spec/artifact?theme=` (serves
the freshest spec HTML — session sandbox else the last milestone — with the Genesis theme `<style>` [dark/light token map] +
the SDK `<script>` injected before `</body>`; themed placeholder when nothing authored), `GET …/spec/export.md` (HTML→Markdown
via **`markdownify==1.2.3`**, pinned; persists `export.md` + `md_export_path`; 409 when empty).

**Web (`features/features/SpecWorkspace.tsx`):** a split view — the **reused `ChatThread`** (bound to the spec's session) beside
the **sandboxed review iframe** (`sandbox="allow-scripts"`, src = the artifact route, theme from the active `.theme-*` class, a
`bust` cache-buster). The **annotation→chat bridge**: a `window` `message` listener collects `lavish:queuePrompt` items and, on
`lavish:sendQueuedPrompts`, composes ONE chat turn (`> "<selected text>"` + comment per annotation) and pushes it via a new
optional **`registerSend`** prop on `ChatThread` (exposes its `useChatTurn` `send`; read-only/copilot unaffected). The iframe
**reloads** whenever a new assistant message appears (shared `useSession`). Toolbar: **status** `<select>` (draft→…→completed),
**Save milestone**, **Export .md** (anchor to the export route), **Add context** (a dialog listing the app's linked business
artifacts → `POST …/spec/context`). `featuresApi` + hooks extended accordingly; `qk.features.detail` invalidated on
status/milestone.

**Tests:** backend `tests/test_features_api.py` (+3 — artifact placeholder→injected+themed, sdk.js served, export→Markdown +
`md_export_path`) → **genesis 396 pytest green, ruff clean**. Web `features.test.tsx` (+3 — iframe src + sandbox, export link,
status change PATCH) → **web 145 Vitest (18 files) green**; tsc + eslint (0 errors) + `npm run build` clean (`web/static/`
rebuilt, uncommitted with the rest until 20-06). Live annotate→revise→reload loop is validated at 20-06 (needs a real browser +
agent).

### Live fix (20-05 testing) — spec.html write was denied (cwd/fs_write_root mismatch)
During live testing the spec-authoring agent's write to `spec.html` was **denied**. Root cause: the
`feature_spec` session reused the read-only client setup with `cwd=state_dir` but `fs_write_root=
skill-output/<session_id>`, so the agent's relative `spec.html` resolved to `~/.genesis/spec.html`
(outside the sandbox → SDK refuses it), and milestone-save reads from the sandbox anyway. **Fix:** for
`feature_spec` sessions set **`cwd = skill_out`** (the sandbox) in `ChatManager._ensure_started`, so a
relative `spec.html` lands inside `fs_write_root` and where milestone reads it (read_only chat keeps
`cwd=state_dir` for skill discovery). Regression test: `test_feature_spec_cwd_is_the_writable_sandbox`
(asserts `cwd == fs_write_root` for a feature_spec session). Requires a `genesis serve` **restart** to
take effect (in-process server code). genesis 397 pytest green (was 396; +1 regression test).

### Live refinements (20-05) — context UX + efficient injection
Two more fixes from live testing: (1) **"Add context" moved into the chat column** (a chat action, not a
review-pane one) — a header bar above the reused `ChatThread`; removed from the review toolbar. (2) **File-based
context instead of transcript dumps:** `inject_context` now writes each selected document's Markdown as a
**file under the session's `./context/<id>-slug.md`** (the agent's cwd, now the sandbox) and appends only a
short system note listing the filenames — so the full content no longer clutters the chat AND it's
token-efficient (the Kiro agent reads the files on demand with its file tools rather than carrying all
content in every turn's context). `_STEERING_SPEC` now tells the agent its reference documents live under
`./context/`. Test updated to assert the context file is written (with content) while the transcript note
carries only the filename. genesis 397 pytest green, ruff clean; web tsc/eslint/build clean.

### Live fix #2 (20-05) — spec.html write STILL denied after the cwd fix: trust the fs tools
After the cwd fix the target was correct (`skill-output/<sid>/spec.html`) but the write was still
denied. Ground truth from the SDK (`kiro-agent-sdk` `client.py` + `test_permission_policy.py`): the
`fs/write_text_file` capability is gated ONLY by `allow_fs_write`+`fs_write_root` (NOT `permission_mode`),
while `session/request_permission` (untrusted **tools**) is what `auto_deny` rejects. So kiro-cli was
requesting permission for its built-in **`fs_write` tool** — untrusted in the read-only-derived
feature_spec session → `auto_deny` rejected it before the sandbox-enforcing capability ran. **Fix:** for
`feature_spec` sessions, add `fs_read`/`fs_write` to `trust_tools` (so no permission is requested); the
write is still confined to `fs_write_root`, and all other tools (shell, MCP mutations) stay untrusted →
denied. Regression test extended to assert `fs_write`/`fs_read` trusted + `auto_deny` retained. Needs a
`genesis serve` restart. (Note: `fs_write`/`fs_read` are kiro-cli's built-in tool names; if a future
kiro-cli renames them, re-confirm via `KIRO_ACP_DEBUG=1`.)
