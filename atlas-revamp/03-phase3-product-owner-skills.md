# Phase 3 — Product Owner Skills

**Goal (one session):** Create the ten read-only PO skills from `atlas-product-owner`. Each
source `action-*` / `guide-*` steering file becomes one skill. All use the Atlas MCP only.

**Depends on:** Phase 1 (agent + seeding doc that carries the business-language table).
**Independent of** Phases 2 and 4.

> **Shared context, not duplicated:** the "Atlas says → you say" business-language
> translation table and the "everything comes from Atlas" rule live in the agent seeding
> document (Phase 1 §E). Each PO skill assumes them and focuses on its own procedure. If a
> skill needs a reminder, it points back with one line rather than restating the whole table.

> **Retention note:** `action-technical-debt`, `action-impact-analysis`, and `action-explore`
> also exist in the out-of-scope `atlas-developer` power. We take the **PO** versions
> (business-language framing). The developer power is untouched.

Each skill = `.kiro/skills/<name>/SKILL.md` (add a `references/` only if a source action file
carries a large template that would push the body over ~500 lines).

---

## 3.1 — `atlas-app-onboarding`  ← `action-onboarding`
```yaml
description: "Walk a Product Owner through an unfamiliar Appian application in business language — what users can do, the main workflows, and how it's structured. Use for 'what does this app do', 'walk me through the app', or first contact with an app. Starts with get_app_overview (once) and summarizes bundles as features. Not for deep single-feature dives (atlas-explore-feature) or release analysis (atlas-release-review)."
```
Body: `list_applications` → `get_app_overview` (once) → group bundles by type → present a
plain-language capability map + suggested next questions.

## 3.2 — `atlas-explore-feature`  ← `action-explore`
```yaml
description: "Deep-dive one feature or workflow of an Appian app in business terms — user journey, entry points, forms, and outcomes. Use for 'how does X work', 'show me the Y feature', 'find Z'. Uses search_bundles/get_bundle and only surfaces code when explicitly asked. Default PO action when the request is unclear. Not for whole-app onboarding (atlas-app-onboarding)."
```
Body: `search_bundles` → `get_bundle` (filtered members) → narrate the flow; `get_object_code`
only on explicit technical request.

## 3.3 — `atlas-release-review`  ← `action-release-review`
```yaml
description: "Analyze what changed in an Appian application release and explain it for stakeholders. Use for 'what changed', 'release notes', 'what's new in this version', 'summarize the release'. Uses list_releases/get_changelog/compare_releases/get_release_impact and translates object deltas into feature-level narrative. Not for assessing a proposed change's risk (atlas-impact-analysis)."
```
Body: `list_releases` → `get_changelog`/`compare_releases`/`get_release_impact` → business
summary (new features / updated / removed), counting bundles not objects.

## 3.4 — `atlas-impact-analysis`  ← `action-impact-analysis`
```yaml
description: "Assess the blast radius of a proposed change to an Appian app — what would break if X changes. Use for 'what would break', 'impact of changing X', 'risk assessment', 'dependencies of X'. Uses get_transitive_dependencies (inbound), get_dependency_path, and get_hub_objects. Analyzes existing state; does not review a shipped release (atlas-release-review)."
```
Body: locate the object → `get_transitive_dependencies(direction=inbound)` → `get_hub_objects`
for shared-component risk → present impacted features + risk rating.

## 3.5 — `atlas-feature-spec`  ← `action-feature-spec`
```yaml
description: "Write a feature specification or user story grounded in real Atlas data for an Appian app. Use for 'write a spec', 'document this feature', 'create a story'. Pulls the current implementation via bundles/dependencies so the spec reflects reality, then produces a structured spec document. Not open-ended investigation (atlas-research)."
```
Body: gather current behavior (`get_bundle`, `get_dependencies`) → emit a spec template
(overview, current behavior, proposed change, acceptance criteria, affected components).

## 3.6 — `atlas-research`  ← `action-research`
```yaml
description: "Investigate a topic, idea, or problem space across an Appian application using Atlas. Use for 'research X', 'investigate this idea', 'what are the options', 'explore the problem space'. Combines search + dependency + history tools to assemble findings and options. Broader than a single feature dive (atlas-explore-feature) and not a formal spec (atlas-feature-spec)."
```
Body: multi-tool sweep (`search_bundles`/`search_objects`/`get_object_history`) → synthesize
options + findings with citations to features.

## 3.7 — `atlas-feature-inventory`  ← `action-feature-inventory`
```yaml
description: "Produce feature counts, complexity, and breakdowns for Appian release/backlog planning. Use for 'how many features', 'most complex features', 'feature breakdown', 'inventory the app'. Counts bundles by type and ranks by dependency/size. Planning-oriented; not a narrative walkthrough (atlas-app-onboarding)."
```
Body: `get_app_overview` → tabulate bundles by type + complexity (member counts, inbound
counts) → ranked inventory table.

## 3.8 — `atlas-technical-debt`  ← `action-technical-debt` (PO version)
```yaml
description: "Identify cleanup opportunities in an Appian app — unused/orphaned components and unreferenced features. Use for 'unused features', 'technical debt', 'cleanup candidates', 'what's not used'. Uses list_orphans/get_orphan and inbound-dependency counts, framed as business cleanup candidates. Read-only analysis."
```
Body: `list_orphans` (by type) → `get_orphan` detail → business-framed cleanup list with
caveats ("appears unused — confirm before removing").

## 3.9 — `atlas-cross-app-analysis`  ← `action-cross-app-analysis`
```yaml
description: "Compare features across multiple Appian applications in the Atlas KB. Use for 'do other apps have X', 'compare apps', 'which apps share this feature'. Iterates list_applications + per-app search_bundles to find similar features and highlight differences. Cross-application scope (not a single app)."
```
Body: `list_applications` → per-app `search_bundles`/`search_objects` → comparison matrix.

## 3.10 — `atlas-appian-docs`  ← `guide-appian-docs`
```yaml
description: "Look up how a native Appian platform feature works (not app-specific), via Atlas Git-content tools over Appian documentation. Use for 'how does Appian handle X', 'Appian docs for X', 'what does the platform support'. Distinct from app feature exploration (atlas-explore-feature) — this is about Appian the product, not the customer app."
```
Body: use `get_git_content`/`search_git_content` against Appian docs repos → concise answer
with source links. (Retains the guide's behavior; if the source relied on a docs source not
in Atlas, note it and fall back to the Git-content tools only — Atlas-only rule.)

---

## Step 3.11 — Validate
```bash
for s in atlas-app-onboarding atlas-explore-feature atlas-release-review atlas-impact-analysis \
         atlas-feature-spec atlas-research atlas-feature-inventory atlas-technical-debt \
         atlas-cross-app-analysis atlas-appian-docs; do
  python3 .kiro/skills/skill-creator/scripts/quick_validate.py .kiro/skills/$s
done
```

## Optional split (if one session is too large)
- **3a:** onboarding, explore-feature, release-review, impact-analysis, cross-app-analysis
- **3b:** feature-spec, research, feature-inventory, technical-debt, appian-docs

## Phase 3 exit criteria
- [ ] 10 PO skill folders with valid SKILL.md.
- [ ] Descriptions clearly separate onboarding vs explore vs release vs impact vs research vs
      spec vs inventory vs debt vs cross-app vs appian-docs.
- [ ] No business-language table duplicated into skills (it lives in the seeding doc).
- [ ] All pass `quick_validate.py`.
