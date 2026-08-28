# 29-03 — Final Design (LOCKED) — UX Design Stage

> **Status:** ✅ **FINAL — FOR BUILD SIGN-OFF (2026-08-28).** · **Type:** design finalization / docs (no release) · **Phase:** 29 (UX Design Stage) · **Gate:** ⭐ user sign-off → 29-04 build.
> Locks every 29-04 decision. **ADR-057** wording finalized (stays *Proposed* until built at 29-04). Builds on 29-01 findings + the 29-02 mockup (`/dev/ux-design`) approved by the user (chat-first review + Preview popup).

---

## D0. Headline constraint — REUSE the Spec-page experience (user directive, 2026-08-28)

> *"During implementation reuse components from the spec page rather than building newly. I want a very
> similar experience."*

The UX Design stage MUST render through **the same components as the Spec stage**, generalized — not
new-built look-alikes. Concretely (29-04):

| Spec today | 29-04 action | UX + Spec both use |
|---|---|---|
| `SpecWorkspace.tsx` (full-width `ChatThread` + top action bar + Preview) | **Generalize → `StageArtifactWorkspace`** (props: `featureId`, `stage`, `artifactKind`, title, artifact/export URLs, lifecycle actions) | ✅ same workspace |
| `PreviewDialog` (iframe + comment-queue rail + Send-all + Lavish `postMessage` bridge + `composeFeedback`) | **Extract → shared `AnnotatablePreviewDialog`** (props: title + `artifactUrl(stage,theme,bust)`) | ✅ same annotatable preview |
| `SpecBuilderPage.tsx` (immersive/Escape + `StageWorkspaceHeader` + empty state) | **Generalize → `StageBuilderPage`**; Spec's empty state = "Create spec", UX's = "Upload mockup PDF" (launches the run) | ✅ same builder scaffold |
| `AddContextDialog` | **Reuse as-is** (stage-scoped) | ✅ |
| `ChatThread` (`@/features/chat/ChatThread`, `chrome="spec"`, `registerSend`) | **Reuse directly** (accept `chrome="ux"` or keep `"spec"` chrome) | ✅ same chat |
| hooks `useSpecAllowed`/`useApplySpecAction`/`useSaveMilestone`/`useInjectContext`/`useSpecContextCandidates` | **Generalize to stage-scoped** (`useStageAllowed(stage)`, …) | ✅ same behavior |

**Rule for 29-04:** if a UX surface differs from Spec only by data (endpoint, title, artifact kind),
**parameterize the existing Spec component**; do not fork it. The Spec stage must keep working (regression
tests green) after the generalization. This reuse is enabled by the `m0015` model (D5) that makes Spec and
UX **the same shape**.

---

## D1. The `ux-design-analysis` workflow (LOCKED node graph)

Deterministic LangGraph (ADR-001); program nodes render/route/persist, narrow Kiro agent nodes judge; every
agent node wears the reliability trio (`attach_reliability` → retry + `escalate` gate). Modeled on
`design-doc/graph.py`.

`START → resolve_inputs → render_pages →[v_pages]→ load_spec → screen_inventory →[v_screens]→
spec_reconcile →[v_reconcile]→ live_grounding →[v_grounding]→ synthesize →[v_doc]→ verify →(pass)→ present → END`
`verify →(fail, bounded)→ synthesize`; `verify →(exhausted)→ escalate(HITL) → END`; any agent exhaustion → `escalate`.

| Node | Kind | MCP / tools | Output |
|---|---|---|---|
| `resolve_inputs` | program | — | validate PDF; resolve feature+spec; require dev env + synced app |
| `render_pages` | program | PyMuPDF (off-loop) | `pages/NNN.png` (DPI 150, ≤40 pages) |
| `load_spec` | program | — | `spec.txt` (the feature's spec, HTML→text) |
| `screen_inventory` | agent · **images** | blackboard | `screens.json` (per-page record) |
| `spec_reconcile` | agent | — | `reconcile.json` (screen→spec: agree/conflict/gap) |
| `live_grounding` | agent | **@genesis-kb + @appian-dev** (read) | `grounding.json` (affected objects; add/modify; blast-radius) |
| `synthesize` | agent | — | `analysis.html` (the UX Implementation Analysis) |
| `verify` | agent · **grounded critic** | @genesis-kb + @appian-dev | pass / fix-list (re-checks vs images+spec+grounding) |
| `present` | program | — | register artifact; stage → `in-review` |

## D2. Validators (LOCKED)
- `v_pages`: ≥1 non-empty `pages/*.png`; count ≤ 40.
- `v_screens`: exactly one record per rendered page; each has `{screen_name, components[], states[], ux_comments}`.
- `v_reconcile`: every screen maps to ≥1 spec ref **or** is flagged `gap`.
- `v_grounding`: every change entry cites `{name,type,add|modify,source:kb|appian-dev}` with a real ref, **or** `is_new:true`.
- `v_doc`: the HTML has the locked section skeleton (D4); one screen block per rendered page; an Open-Questions section (may be "none").
- `verify` is an **agent** critic (not a plain validator): re-reads `analysis.html` against `pages/*` + `spec.txt` + `grounding.json`; emits `{ok, fixes[]}`; bounded loop (retry_max 2) → `escalate`.

## D3. Grounding contract (LOCKED)
- **genesis-kb = structure/impact ONLY**: `search_objects`/`get_object_detail` (exists?), and **blast-radius**
  via `get_dependents_batch` + `get_transitive_dependencies` + `get_dependency_path` + `get_hub_objects` on
  affected objects → the **Blind spots** section.
- **appian-dev = the actual code** (heavy reliance): read the SAIL of the *specific* affected interfaces to
  judge add-vs-modify + describe the change at intent level.
- **Citation:** each change = `{name, uuid?, type, add|modify, source}`; unresolved → `is_new:true`.
  Node allowlists are **read-only** `@server/tool` lists (mirror `design-doc`'s pattern).

## D4. The "UX Implementation Analysis" doc template (LOCKED; HTML; intent-level)
`<h1>` Feature + "UX Implementation Analysis" → **Overview** → **Per screen** (one block/page: *Mockup intent*
· *Spec basis* [agree/conflict/gap] · *Live delta* [affected objects] · **What to change (intent level)**) →
**Blind spots / ripple effects** (KB-impact-derived) → **Open Questions** (numbered, tagged
`[Gap]`/`[Assumption]`/`[Cross-Feature]`/`[Scope]`). **No SAIL / no object-level design** (Technical Design's
job) — enforced by the template + steering.

## D5. `m0015` — generalized per-`(feature, stage)` artifact model (LOCKED: option A)
Add **`kb_feature_stages`**: `{id, feature_id FK→kb_features ON DELETE CASCADE, stage TEXT CHECK in
(spec,ux_design,technical_design,breakdown), status TEXT, chat_session_id TEXT, html_path TEXT,
content_hash TEXT, md_export_path TEXT, row_version INT, created_at, updated_at}` + `UNIQUE(feature_id, stage)`;
and **`kb_feature_stage_revisions`** (mirrors `kb_feature_spec_revisions`). On-disk artifacts →
`settings.feature_stage_artifacts_dir/<stage_row_id>/`. **Migrate Spec onto it** (option A): copy each
`kb_feature_specs` row → a `kb_feature_stages` row with `stage='spec'` (+ its revisions); repoint
`FeatureStore`/API/lifecycle at `kb_feature_stages`; keep `kb_feature_specs` briefly as a read-through or drop
after the data move (29-04 decides drop-vs-view — additive migration either way). `current_version` **14 → 15**;
bump the `current_version==N` tests. `StageStore` reuses the `_cas_update` CAS pattern verbatim.

## D6. The `ux_design` lifecycle machine (LOCKED)
Reuse **`SPEC_TRANSITIONS`** verbatim (`draft→start→in-progress→submit→in-review→approve→completed`;
`request-changes`; `reopen`) bound to the ux stage row + `ArtifactKind.UX_DESIGN` via a
`build_stage_lifecycle(stage)` (generalize `build_spec_lifecycle`); audited in **m0013**. `present` drives
`draft→…→in-review`; **Mark complete** = `approve` → `completed` (D8). Re-upload resets to `in-progress`.

## D7. The `ux_design` chat mode (LOCKED)
A `ChatModeProfile` cloning `feature_spec`: `mcp_mode="read_only"` (already wires genesis-kb + appian-dev +
introspection), `permission_mode="auto_deny"`, `cwd_sandbox=True`, `extra_trust=("fs_read","fs_write")`, new
`_STEERING_UX`: *"You are refining a UX Implementation Analysis (HTML) for a feature. Walk the Open Questions
one at a time; as the user answers, revise exactly that part and rewrite the HTML. Re-check the live app
(genesis-kb structure + appian-dev code) when asked. Keep it intent-level (no SAIL/object design). The HTML is
the source of truth."* The chat renders in the **reused** `ChatThread` (D0).

## D8. Completion (LOCKED)
Explicit **"Mark complete"** (mirrors Spec's allowed-action buttons; `approve` → `completed`). Not
auto-on-all-answered.

## D9. `kiro_node` image seam (LOCKED; additive genesis-core)
Add `image_docs: list[str] | None` (blackboard PNG filenames) + optional `images_fn(state, ctx)` to
`kiro_node`; in `_run`, read+base64-encode those files and pass via the `AgentProvider` to
`client.prompt(..., images=[{data, mimeType}])`. Extend `AgentProvider.collect`/`collect_streaming` +
`KiroAcpProvider` to accept `images` (SDK already gates on `promptCapabilities.image`, drops gracefully).
Additive; `CORE_MAJOR` unchanged. Unit test: passed-when-capable / dropped-when-not.

## D10. Render defaults (LOCKED)
PyMuPDF; **DPI 150**; **≤40 pages** (friendly error above); PNG; off the event loop (`asyncio.to_thread`).
Pin `PyMuPDF` in genesis `pyproject.toml`. PDF-only (PPTX deferred).

## D11. Handoff & re-upload (LOCKED)
Upload PDF (ADR-035 multipart) → launch the **supervised `ux-design-analysis` run** (Runs-visible; `verify`→
`escalate` surfaces there) → on completion the stage shows the **draft** analysis (`in-review`) + the
completion chat (`StageArtifactWorkspace`). **Re-upload**: delete `pages/*` + supersede the artifact (new
stage-artifact row/revision; remove the prior on-disk dir) + reset the stage + re-run.

## D12. Backend API surface (LOCKED; generalize the spec endpoints to stage-scoped)
`POST /features/{id}/stages/{stage}/upload` (PDF → launch run) · `GET …/stages/{stage}` (row+status) ·
`GET …/stages/{stage}/artifact?annotate=&theme=&bust=` (the HTML, Lavish-hosted like the spec artifact) ·
`GET …/stages/{stage}/export.md` · `…/stages/{stage}/allowed` + `POST …/stages/{stage}/actions/{action}`
(LifecycleService) · `…/stages/{stage}/milestone` · context endpoints. The existing spec routes become
thin `stage='spec'` aliases (back-comp) or redirect to the generalized routes.

## D13. 29-04 build inventory (order: core → genesis → genesis-workflows)
1. **genesis-core:** `kiro_node` images + `AgentProvider` images (D9) + tests. Release core.
2. **genesis backend:** PyMuPDF render util (D10); `m0015` + `StageStore` + migrate Spec (D5);
   `build_stage_lifecycle` + `ux_design` audit (D6); `ux_design` `ChatModeProfile` (D7); generalized
   stage API (D12); re-upload/replace (D11).
3. **genesis web:** generalize `SpecWorkspace`→`StageArtifactWorkspace`, `PreviewDialog`→
   `AnnotatablePreviewDialog`, `SpecBuilderPage`→`StageBuilderPage`, stage-scoped hooks (D0); flip
   `STAGE_DEFS.ux` `available:true` + a real `deriveStatus`; add the `ux` `stage-registry` entry
   ({Workspace: the generalized builder, CardActions: upload/review}); the UX empty state = upload.
4. **genesis-workflows:** `workflows/ux-design-analysis/` (D1/D2) + registry (read-only allowlists).

## Acceptance / DoD (this sub-phase)
- Every 29-04 decision locked; no blocking TBD. The **component-reuse map (D0)** is explicit. ADR-057
  finalized. Progress + tracker updated. **No code changed.**

## Gate
⭐ **User signs off on this locked design → 29-04 build begins. Do NOT build before this gate.**
