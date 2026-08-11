# 20-04 — Spec chat backend (feature-bound session, context injection, milestones)

> **Status:** ✅ **CODE-COMPLETE — UNCOMMITTED** (commit at 20-06). Create-spec now opens a bound
> **`feature_spec`** chat session (new additive mode + `_STEERING_SPEC`; `genesis-kb` auto-wired, 16-05)
> seeded with the app/feature identity; **Add context** injects the app's linked business artifacts;
> **milestone** snapshots the agent-authored `spec.html` from the session sandbox; **status** transitions
> validated. genesis **393** pytest green, ruff clean. See `progress/phase-20-features-and-spec-authoring.md`.
> **As-built note:** context is a **conversational** act — shipped `GET …/spec/context` (the app's linked
> docs = the picker source) + `POST …/spec/context` (inject selected docs' bounded Markdown as a system
> message); the draft's "list currently-injected / DELETE one" was dropped (removing content from an
> LLM's context isn't meaningful once sent). The app/feature seed rides the transcript (`enqueue_system_turn`)
> + the static `_STEERING_SPEC`; note the cold-start preamble is bounded (identity may age out of a very
> long conversation — a durable-preamble refinement is deferred).
> **Repo:** genesis. **Depends on:** 20-02 (`FeatureStore`), 20-03 (spec create). **Reuses:** Chat
> (Phase 10, ADR-031), the fs-write sandbox (Phase 14, ADR-034), `genesis-kb` MCP (16-05), `DocumentStore` +
> `build_evidence_pack` docs (Phase 19). **No new orchestration (ADR-001).**

## Goal
Make a spec's conversation a real, feature-bound **chat session** that (a) knows which application/feature it is, (b) can be
handed the app's **business artifacts** as context, (c) authors the spec **HTML** into the session sandbox, and (d) persists
**milestone** snapshots + status.

## The spec chat session (reuse `ChatManager`/`ChatStore`)
- **Binding.** `create_spec` (20-03) creates a `chat_sessions` row and stores its id on `kb_feature_specs.chat_session_id`.
  The session is **typed for a feature-spec** (a `mode`/tag value, e.g. `mode="feature_spec"`, additive to the Phase-13
  `chat_sessions.mode`) so the UI + seeding differ from generic chat.
- **Seeding (app/feature identity).** The first turn's system/seed context includes the **application** (uuid, name — so the
  agent can call `genesis-kb` for its KB) and the **feature** (name, description). `genesis-kb` is **already wired into every
  chat** (16-05), so no MCP change — the agent can `search_objects`/`get_app_overview`/etc. for *this* app.
- **Authoring seam.** The agent writes/overwrites **`spec.html`** in its per-session `fs_write_root` sandbox
  (`~/.genesis/skill-output/<session_id>/spec.html` — the Phase-14 sandbox, no new write authority). A **system instruction**
  (seed/steering) teaches it: *produce a single rich, self-contained HTML spec at `spec.html`; treat HTML as the source of
  truth; revise the exact passages the user annotates; periodically remind the user to save a milestone.*

## "Add context" — inject the app's business artifacts
- **API:** `POST /features/{id}/spec/context` `{document_ids:[…]}` — resolve each via `DocumentStore.get_document` (must be a
  document **linked to this feature's app** — validate against `kb_document_links`), and inject its **parsed Markdown** into
  the session context for subsequent turns (reuse the `build_evidence_pack` document-excerpt mechanism — bounded, code-free).
  `GET /features/{id}/spec/context` lists currently-injected docs; `DELETE …/context/{document_id}` removes one.
- **Source of the picker:** the app's linked documents (`DocumentStore.list_documents(app_uuid=...)`), i.e. the Business
  Artifacts tab's list — so "add context" = "pull in these business artifacts."
- **Mechanism:** injected content rides with the session's turn context (the same way KB evidence is provided), so the agent
  designs the spec grounded in the selected documents. (Whether injection is a pinned system block or per-turn is finalized in
  implementation; either way it is **bounded** and code-free.)

## Milestones + status
- **Milestone save** — `POST /features/{id}/spec/milestone` `{note?}`: copy the current sandbox `spec.html` into the
  feature-spec store as `spec.html` + a new `kb_feature_spec_revisions` row (auto `revision_no`), update `content_hash`.
  Triggered by the **user** ("save"/"draft") and **prompted by the agent** (the seed instruction reminds the user; the agent
  does not silently snapshot — a milestone is an explicit save). Best-effort autosave-on-significant-change may be added, but
  the explicit milestone is the contract.
- **Status** — `PATCH /features/{id}/spec/status` `{status}` validated against `draft|in-progress|in-review|completed`
  (`FeatureStore.set_status`). User-set; the agent may **suggest** a transition in chat but does not set it.

## Tests
- `tests/test_features_api.py` (extended) + a spec-chat test: session bound + typed; context inject validates app-linkage
  (reject a document not linked to the app → 400/404) and injects Markdown; milestone copies sandbox HTML → a revision +
  bumps hash; status transition validation; **hermetic** (fake/no live ACP — assert the seeding/injection/persistence, not a
  real Kiro turn, matching the 19-05 hermetic-API-test posture).

## Exit criteria
A feature's spec has a bound, app-aware chat session; selected business-artifact documents inject as context; the agent's
`spec.html` can be milestone-saved into a revision; status transitions are validated. Live agent authoring is exercised in
20-06 acceptance (can't be driven headlessly). Tests + `ruff` green.
