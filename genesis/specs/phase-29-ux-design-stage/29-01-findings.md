# 29-01 — Findings: Research & Analysis (UX Design Stage)

> **Status:** ✅ **DELIVERED — FOR REVIEW (2026-08-28).** · **Type:** research / docs-only (no code, no release) · **Phase:** 29 (UX Design Stage) · **Gate:** ⭐ user review of the findings + finalized design before 29-02 mockups.
> **Method:** external desk research (cited) + a current-code audit of the real seams (cited file paths). No code changed.

---

## 0. Executive summary (the recommended, coherent design)

Build a deterministic **`ux-design-analysis`** LangGraph workflow that turns an uploaded **mockup PDF** into a
grounded, per-screen **"UX Implementation Analysis"** (HTML), then hand the feature's **UX Design** stage to a
bound **`ux_design` completion chat** that walks the open questions and finalizes the doc. The analysis is
**grounded per screen** in three sources — the rendered page images, the feature's **Spec** (authoritative
text), and the **live environment** (structure/impact via **genesis-kb**, actual code via **appian-dev**) —
and is kept honest by **per-screen decomposition** + a **grounded verification (critic) pass**. Output is
**intent-level**. The stage plugs into the Phase-28 framework with **no shell edits** (one `STAGE_DEFS` row +
one `stage-registry` entry + the inner workspace). It is realized across three repos: an **additive
genesis-core** change (images in `kiro_node`), a **genesis** backend+web layer (PDF render + the `m0015`
generalized per-stage artifact model + a `ux_design` lifecycle machine + a `ux_design` chat mode + API + the
UX stage), and a **genesis-workflows** workflow.

The research validates the two shape decisions we baked in: (a) **do not** one-shot the whole deck through a
vision model, and (b) **do** add a critic — but a **grounded** one.

---

## 1. External research (cited)

### 1.1 Multimodal LLMs analyzing UI mockups vs. an implementation — and their failure modes
- Multimodal LLMs can **reproduce visual layout** but consistently **fail at data-binding correctness,
  interaction implementation, and structural consistency** — *"Benchmarking MLLMs for Coordinated Multi-View
  Interface Construction (MV-Bench)"* (arXiv 2607.19910); *"Enhancing Web Interface Generation…"* (arXiv
  2510.04097).
- Fine-grained **UI reasoning from screenshots is still immature** — *"Reasoning for Mobile UX with
  Multimodal LLMs / UXBench"* (arXiv 2606.13192) and *"Do MLLMs Capture How Interfaces Guide User
  Behavior?"* (arXiv 2505.05026): models remain "fundamentally limited" at fine-grained UI diagnosis.
- LLMs in UI/UX design carry **hallucination, prompt instability, limited explainability** and benefit from
  **human-in-the-loop + multimodal input** — *"The role of large language models in UI/UX design"* (arXiv
  2507.04469).
- **Takeaway → design:** do **not** ask one turn to holistically "read the deck and compare." Instead
  **decompose per screen**, and **ground every claim** in the spec text + the live code (via MCP) rather than
  trusting the vision model's inference. This is why `screen_inventory` is per-page and `live_grounding` reads
  real code.

### 1.2 Generator → critic / reflection loops (and their trap)
- Reflection/critic loops (Reflexion; Self-RAG, arXiv 2310.11511; multi-agent reflexion, arXiv 2512.20845)
  measurably **reduce hallucination** — **but only when externally grounded**.
- The trap: *"When Do Agent Loops Mistake Stagnation for Progress? …Self-Evaluation Bias and Externally
  Grounded Verification"* (arXiv 2607.25152) names the **"progress mirage"** — a critic grounded only in its
  own judgment accepts plausible-but-wrong changes. The fix is a critic **grounded in external truth**.
- **Takeaway → design:** add a `verify` node, but it **re-checks the drafted doc against the page images +
  the spec + the live-grounding notes** (external truth), emits a targeted fix list, loops back to
  `synthesize` a **bounded** number of times, then **escalates to a HITL gate** (ADR-011). Not self-graded.

### 1.3 PDF → per-page images in Python
- **PyMuPDF (fitz)** is the standard, fast, memory-efficient renderer — a **pure wheel, no system
  dependency** (PyMuPDF docs; *artifex.com* "Converting PDFs to Images with PyMuPDF"). `pdf2image` needs a
  **poppler** system binary (StackOverflow 69643954) → rejected. **PPTX has no pure-Python renderer**: the
  reliable path is **LibreOffice headless → PDF → images** (StackOverflow 21523267), which adds a system
  prerequisite → **PPTX deferred; PDF-only v1** (locked).
- **Takeaway → design:** `render_pages` uses **PyMuPDF** at a configurable DPI, off the event loop
  (`asyncio.to_thread`, §7), writing `pages/NNN.png` into the blackboard.

---

## 2. Current-code audit (the real seams)

### 2.1 The Phase-28 stage framework — where UX goes live (no shell edits)
- `web/src/features/features/stages.ts` — `STAGE_DEFS` has the `ux` row **`available:false`,
  `deriveStatus:()=>"not-available"`**, `artifactKind:"ux_design"`. **Flip to `available:true` + a real
  `deriveStatus`** (reads the feature detail's ux-stage status).
- `stage-registry.tsx` — data-only `key → {Workspace, CardActions}`. **Add a `ux` entry**
  (`{Workspace: UxDesignWorkspace, CardActions: UxCardActions}`).
- `StageWorkspacePage.tsx` dispatches by the registry; `FeaturePage.tsx` renders the Overview + peer cards
  generically. **No edits needed** — the invariant holds.

### 2.2 Spec authoring = the exact template for UX
- `genesis/chat/mode_profile.py` — the `feature_spec` `ChatModeProfile`: `mcp_mode="read_only"`,
  `permission_mode="auto_deny"`, `cwd_sandbox=True`, `extra_trust=("fs_read","fs_write")`, a `_STEERING_SPEC`
  preamble. **The `ux_design` profile is a near-clone** with a UX-specific steering (see §3.6).
- `genesis/chat/mcp.py` — read-only chat **already wires `genesis-kb` + best-effort `@appian-dev`** (+
  introspection + memory). So the `ux_design` completion chat reusing `mcp_mode="read_only"` **already has
  both grounding MCPs** for on-demand re-checks — no new wiring.
- `genesis/kb/features.py` `FeatureStore` over **m0010** (`kb_features`/`kb_feature_specs`/
  `kb_feature_spec_revisions`): a spec row = `{feature_id, title, status, chat_session_id, html_path,
  content_hash, md_export_path, row_version}`; row_version **CAS** via `_cas_update` (m0014); HTML on disk at
  `settings.feature_specs_dir/<spec_id>/`; `add_revision` snapshots. **This is the shape the `m0015` per-stage
  model generalizes** (§3.4).
- `genesis/domain/`: **`ArtifactKind.UX_DESIGN="ux_design"` already exists** (`enums.py`). `transitions.py`
  `SPEC_TRANSITIONS` = `{(DRAFT,start)→IN_PROGRESS, (IN_PROGRESS,submit)→IN_REVIEW, (IN_REVIEW,approve)→
  COMPLETED, (IN_REVIEW,request-changes)→IN_PROGRESS, (COMPLETED,reopen)→IN_PROGRESS}`; `lifecycle.py`
  `build_spec_lifecycle` binds it. **The `ux_design` machine reuses this exact table** (same states/actions)
  with the ux entity/artifact + m0013 audit — no new transition design.

### 2.3 The workflow exemplar
- `genesis-workflows/workflows/design-doc/graph.py` — the pattern to copy: `program_node` for I/O/route,
  `kiro_node` for judgment, `attach_reliability(agent, validator, retry_max, on_exhaust_gate, nxt)` (the
  trio), a conditional **open-questions** node, a **mockup `format:"file"`** input (ADR-035),
  **save-by-reference** for bulk tool output, and per-node **read-only allowlists** (`@server/tool`).

### 2.4 The two capability gaps (both confirmed)
- **`kiro_node` has no image path.** `genesis-core/nodes/agent.py::kiro_node` builds
  `opts = Options(**opts_kwargs)` and calls `provider.collect_streaming(prompt, opts, on_message=…)` /
  `provider.collect(prompt, opts)`. The **SDK already supports images** (`kiro_agent_sdk/client.py::
  _build_content(text, images)`, gated on `promptCapabilities.image`) and the **chat** path uses
  `client.prompt(text, images=…)`. → **Add an image seam to `kiro_node` + the `AgentProvider`** (§3.7).
- **No PDF→image rendering.** `genesis/kb/doc_parsing.py` is text-only (pypdf); no PPTX. → **new PyMuPDF
  render step** (§3.3).

### 2.5 Grounding sources (confirmed tool surfaces)
- **genesis-kb** (`genesis/mcp/kb_server.py`, read-only, Atlas-mirrored) — structure + impact:
  `get_dependencies`, `get_dependents_batch`/`get_precedents_batch`, `get_transitive_dependencies`,
  `get_dependency_path`, `get_hub_objects`, `get_shared_objects`, `search_objects`, `get_object_detail`,
  `get_entry_points_for_object` (+ `get_object_code`, which itself fetches live SAIL via `@appian-dev`).
- **appian-dev** (managed-native Dev MCP, read-only allowlist) — the **actual code**; workflow agent nodes
  can inject `@appian-dev` directly (worker.py confirms the local-venv launch for a workflow node).

---

## 3. Finalized design

### 3.1 `ux-design-analysis` — node graph + validators

| # | Node | Kind | MCP / tools | Validator |
|---|------|------|-------------|-----------|
| 1 | `resolve_inputs` | program | — | mockup is a **PDF** (reject else); feature+spec resolve; **dev env tagged** + app **synced** (fail-fast) |
| 2 | `render_pages` | program | PyMuPDF (off-loop) | ≥1 non-empty `pages/NNN.png` |
| 3 | `load_spec` | program | — | spec text present (or explicit "no spec") |
| 4 | `screen_inventory` | agent (**multimodal**) | blackboard (images) | one screen record per rendered page; required fields (name/components/states/comments) |
| 5 | `spec_reconcile` | agent | — (reads blackboard) | each screen mapped to spec section(s) w/ agree·conflict·gap |
| 6 | `live_grounding` | agent | **@genesis-kb + @appian-dev** (read) | each change cites a real object ref (KB/appian-dev) **or** is explicitly "new"; blast-radius attempted |
| 7 | `synthesize` | agent | — | HTML section skeleton present (§3.3 template); one block per screen |
| 8 | `verify` | agent (**grounded critic**) | @genesis-kb + @appian-dev (spot re-check) | pass, else a targeted fix list → bounded loop to `synthesize` → `escalate` gate on exhaustion |
| 9 | `present` | program | — | artifact registered; stage → `in-review` |

Every agent node wears the **reliability trio** (`attach_reliability`; retry max + `escalate` escalation
gate). Bulk tool output uses **save-by-reference** (Phase 9). `graph.py` is self-contained (loader imports it
standalone). Blocking KB/DB writes run off the event loop (§7).

### 3.2 Grounding contract (locked split)
- **genesis-kb = structure only**: existence, `get_object_detail`/`search_objects`; **blast-radius / ripple**
  via `get_dependents_batch` + `get_transitive_dependencies` + `get_dependency_path` + `get_hub_objects` on
  each affected object → the **blind-spot** section is a real query, not a guess.
- **appian-dev = the actual code**: read the SAIL of the *specific* affected interfaces to judge add-vs-modify
  and describe the change at intent level. Heavy reliance here (the user's decision).
- **Citation format:** each per-screen change lists affected object refs as `{name, uuid?, type,
  add|modify, source: kb|appian-dev}`; unresolved → explicitly **"new object"**. The `live_grounding`
  validator enforces this.

### 3.3 The "UX Implementation Analysis" doc template (HTML; intent-level)
Fixed section skeleton (validated):
- **Title** — Feature + "UX Implementation Analysis".
- **Overview** — what the mockup set changes, in 3–5 sentences.
- **Per screen** (one block per rendered page): *Mockup intent* (what the slide shows + the UX's comments) ·
  *Spec basis* (which spec requirement it realizes; agree/conflict/gap) · *Live delta* (what exists today +
  affected objects) · **What to change (intent level)** — screen/interaction changes + the affected-objects
  list. **No SAIL / no object-level design** (that is the Technical Design stage — the boundary is enforced
  by the template + the steering).
- **Blind spots / ripple effects** — KB-impact-derived affected-but-unmentioned areas.
- **Open Questions** — numbered, tagged (`[Assumption]`/`[Gap]`/`[Cross-Feature]`/`[Scope]`), capped.

### 3.4 `m0015` — the generalized per-`(feature, stage)` artifact model
**Recommendation:** a new **`kb_feature_stages`** table keyed by `(feature_id, stage)` mirroring the spec-row
shape — `{id, feature_id, stage TEXT[spec|ux_design|technical_design|breakdown], status, chat_session_id,
html_path, content_hash, md_export_path, row_version, created_at, updated_at}` — plus
**`kb_feature_stage_revisions`** (mirrors `kb_feature_spec_revisions`). On-disk artifacts at a
`settings.feature_stage_artifacts_dir/<stage_row_id>/` analog. A `FeatureStore`-style `StageStore` (or an
extension) reuses the exact `_cas_update` CAS pattern; `LifecycleService` binds `SPEC_TRANSITIONS` per stage
(m0013 audit). **`current_version` → 15**, **additive** (ADR-030/019; bump the `current_version==N` tests).
- **Spec migration decision (29-03):** either (A) **migrate the existing spec onto `kb_feature_stages`**
  (`stage='spec'`) for full uniformity (cleanest; a one-time additive data move + repoint `FeatureStore`), or
  (B) **coexist** — `kb_feature_specs` stays for spec, `kb_feature_stages` serves ux+future — lower risk,
  mild special-casing. **Lean = (A) for uniformity; final call at 29-03** (see Q2).

### 3.5 The `ux_design` lifecycle machine
Reuse **`SPEC_TRANSITIONS`** verbatim (same states/actions) bound to the ux stage entity + `ArtifactKind.
UX_DESIGN` via `LifecycleService`; audited in m0013. Run flow: `present` sets the stage to **`in-review`**
(draft doc produced); the completion chat's **Mark complete** → `approve` → **`completed`** (candidate; see
Q3). Re-upload = a fresh run that resets the stage to `in-progress`/`in-review`.

### 3.6 The `ux_design` chat mode (completion)
A `ChatModeProfile` cloning `feature_spec`: `mcp_mode="read_only"` (→ genesis-kb + appian-dev + introspection
already wired), `permission_mode="auto_deny"`, `cwd_sandbox=True`, `extra_trust=("fs_read","fs_write")`, and a
new `_STEERING_UX` preamble: *"You are refining a UX Implementation Analysis (HTML) for a feature. Walk the
document's Open Questions one at a time; as the user answers, revise exactly that part and rewrite the HTML.
You may re-check the live app (genesis-kb structure + appian-dev code) when asked. Keep it intent-level (no
SAIL/object design). The HTML is the source of truth."* Reuses the Phase-20/21 annotatable Lavish review +
the postMessage annotation→chat bridge.

### 3.7 `kiro_node` image seam (additive genesis-core)
Add an optional **`images_fn(state, ctx) -> list[{data, mimeType}]`** (or `image_docs: list[str]` naming
blackboard files) to `kiro_node`; in `_run`, when present, read + base64-encode the blackboard PNGs and pass
them through the **`AgentProvider`** to `client.prompt(..., images=…)` (the SDK already gates on
`promptCapabilities.image` and drops them gracefully when absent). Extend `AgentProvider.collect`/
`collect_streaming` (and `KiroAcpProvider`) to accept `images`. Additive; `CORE_MAJOR` unchanged; unit-test
"passed when capable / dropped when not" (mirrors `test_acp_extensions.py`).

### 3.8 Render defaults, handoff, re-upload
- **DPI** default **~150** (legible screens, bounded size); a **page cap** (e.g. 40) with a friendly error
  above it — tuned against a real deck in 29-02/29-04 (Q1).
- **Handoff:** upload PDF → launch the **supervised `ux-design-analysis` run** (visible in Runs; the `verify`
  → `escalate` gate surfaces there) → on completion the stage shows the **draft** analysis (`in-review`) +
  opens the completion chat.
- **Re-upload replaces:** delete `pages/*` + supersede the prior artifact (new stage-artifact row/revision;
  old on-disk dir removed) + re-run from scratch. One active analysis per feature.

---

## 4. How the design mitigates the multimodal failure modes (§1.1)

| Failure mode (research) | Mitigation in this design |
|---|---|
| Weak holistic UI reasoning | **Per-screen** `screen_inventory` (one page at a time) |
| Data-binding / structural inference wrong | Don't infer — **read live code via appian-dev** + structure via genesis-kb |
| Hallucinated "what exists" | `live_grounding` validator: **every change cites a real ref or is "new"** |
| Self-graded critic "progress mirage" | `verify` re-checks **against images + spec + live notes** (external truth), bounded → escalate |
| Missed ripple effects | **KB dependency/impact query** → the blind-spot section |

---

## 5. Open questions for the user (feed the umbrella §13)

1. **Render DPI / page cap** — OK to default **DPI ~150** + a **max ~40 pages** guard (friendly error above)?
   (Tunable in 29-02/29-04.)
2. **`m0015` spec migration** — go with **(A) migrate the existing Spec onto the generalized
   `kb_feature_stages` model** (cleanest, uniform; one-time additive data move) vs **(B) coexist** (spec stays
   on `kb_feature_specs`)? (Lean A.)
3. **Completion criteria** — is **explicit "Mark complete"** (mirroring Spec) the gate to `completed`, or
   should "all open questions answered" auto-advance? (Lean explicit.)

*(None block 29-02. The finalized design above is a single coherent recommendation; these three only tune it.)*

---

## 6. ADR-057

Drafted + appended to `reference/decision-log.md` as **Proposed** and mirrored in `bible/04` (Phase-29 spec
draft). Finalized wording locked at 29-03; **Accepted** at 29-04/29-06.

## 7. DoD (this sub-phase)

- Findings cite real external sources + real Genesis code paths ✅. Multimodal failure modes acknowledged +
  mitigated ✅. A single coherent finalized design stated (workflow graph + validators + grounding contract +
  doc template + m0015 + lifecycle + chat + image-node + render defaults) ✅. ADR-057 drafted ✅. **No code
  changed** ✅. Progress + tracker updated (next).

## Gate

⭐ **User reviews these findings + the finalized design (+ resolves the §5 questions where possible) before
29-02 mockups begin.**
