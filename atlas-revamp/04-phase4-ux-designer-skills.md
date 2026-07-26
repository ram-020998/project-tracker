# Phase 4 — UX Designer Skills

**Goal:** Create the nine UX skills from `atlas-ux-designer`. Each source `action-*` steering
file becomes one skill. All use the Atlas MCP (KB + **Git-content tools** for Aurora/Sailwind
docs). No second MCP server, no local installs beyond Node.js for the React prototype skill.

**Depends on:** Phase 1. **Independent of** Phases 2 and 3.

Because the UX action files are large (~9–15KB each), this phase is split into two
sub-sessions. Complete 4a, checkpoint, then 4b.

> **Retention note:** `atlas-ux-designer/.kiro/steering.md` mentions an `action-publish-prototype`
> (Vercel publish, Action 4). **No such file exists** in `steering/` — the actual files are the
> nine below. Do not fabricate a publish skill; if publish is wanted later, file it separately.
> All nine existing action files are retained.

> **Atlas-only:** Aurora/Sailwind/Sailwind-Lite content is fetched at runtime via the Atlas
> MCP Git-content tools (`list_git_directory`, `get_git_content`, `search_git_content`) — the
> same design decision the power made (it replaced the Aurora MCP with these generic tools).
> `atlas-aurora-compliance` does **not** depend on the repo's `appian-a11y-rules` skill.

Each skill = `.kiro/skills/<name>/`; move large embedded templates/checklists from the source
action file into `references/` to keep SKILL.md under ~500 lines.

---

## Phase 4a — Build skills (3)

### 4a.1 — `atlas-html-prototype`  ← `action-create-html-prototype`
```yaml
description: "Create a standalone HTML prototype of an Appian interface using Sailwind-Lite (Pico CSS + Aurora theme) — no setup needed. Use for 'HTML prototype', 'quick mockup', 'mock up this interface', 'generate HTML'. Fetches sailwind-lite gem.md + template from GitHub via Atlas Git-content tools, traces the interface's parent site for chrome, and writes a .html file. Not React (atlas-sailwind-prototype) or production SAIL (atlas-generate-sail-interface)."
```
Body: fetch `pglevy/sailwind-lite` `gem.md`+`template.html`; resolve site context via
`get_dependencies`; generate standalone `.html`. Retain the mandatory site-context step.

### 4a.2 — `atlas-sailwind-prototype`  ← `action-create-sailwind-prototype`
```yaml
description: "Create a high-fidelity React prototype using the Sailwind component library. Use for 'React prototype', 'Sailwind prototype', 'high-fidelity prototype'. Scaffolds a minimal Vite+React+Tailwind app under prototypes/sailwind-app/ on first use, fetches component knowledge from pglevy/sailwind + sailwind-starter via Atlas Git-content tools, writes .tsx pages, and runs the build to verify. Requires Node.js. Not standalone HTML (atlas-html-prototype)."
```
Body: scaffold/locate the React app; fetch `AGENTS.md` + components; create `.tsx` page +
routes; `pnpm run build` to verify. Retain component list + import patterns as
`references/sailwind-components.md`.

### 4a.3 — `atlas-generate-sail-interface`  ← `action-generate-sail`
```yaml
description: "Generate production-ready Appian SAIL interface code using the Aurora Design System. Use for 'generate SAIL', 'create a SAIL interface', 'build a form/dashboard/record view', 'write SAIL code' for a new interface. Fetches Aurora SAIL_CODING_GUIDE + component/layout/pattern docs from appian-design/aurora via Atlas Git-content tools and emits a .sail file. Named to avoid confusion with atlas-generate-sql (bulk DATA SQL) — this produces UI code, not data."
```
Body: fetch Aurora `docs/SAIL_CODING_GUIDE.md` + relevant `components/`/`layouts/`/`patterns/`;
generate `.sail`. Keep the Aurora doc-path map in `references/aurora-docs-map.md`.

**Validate 4a**, then checkpoint before 4b.

---

## Phase 4b — Analyze / review skills (6)

### 4b.1 — `atlas-edge-case-analysis`  ← `action-edge-case-analysis`
```yaml
description: "Surface unhandled states, missing scenarios, and developer questions from a UX mockup or SAIL. Use for 'edge cases', 'what's missing', 'dev questions', 'unhandled states', 'what happens when'. Analyzes the provided mockup/spec against common Appian interaction states and writes a gap list as .md. Analysis only — not prototype creation."
```

### 4b.2 — `atlas-feasibility-check`  ← `action-platform-feasibility-check`
```yaml
description: "Assess what a proposed design can and cannot do in Appian SAIL, with alternatives. Use for 'is this possible', 'feasibility', 'can SAIL do this', 'platform limitations'. Checks the design against Aurora/SAIL capabilities (via Atlas Git-content tools) and returns feasible / not-feasible / workaround. Not a design-system compliance check (atlas-aurora-compliance)."
```

### 4b.3 — `atlas-design-consistency-review`  ← `action-design-consistency-review`
```yaml
description: "Compare a proposed design against existing interface patterns in an Appian app for consistency. Use for 'consistency', 'match existing', 'compare with app', 'does this fit'. Pulls comparable interfaces via Atlas search_objects/get_object_code and flags divergences from established patterns. App-relative comparison (not against Aurora — that's atlas-aurora-compliance)."
```

### 4b.4 — `atlas-component-decomposition`  ← `action-component-decomposition`
```yaml
description: "Plan how to structure a complex interface into reusable SAIL rules. Use for 'decompose', 'break down', 'structure', 'how to split', 'reusable rules'. Produces a component/rule breakdown with inputs and responsibilities. Structural planning — not code generation (atlas-generate-sail-interface) or dev handoff (atlas-design-handoff)."
```

### 4b.5 — `atlas-design-handoff`  ← `action-design-to-dev-handoff`
```yaml
description: "Produce a complete design-to-development implementation brief for an Appian interface. Use for 'handoff', 'for developers', 'implementation brief', 'what devs need'. Assembles the mockup, component breakdown, data needs, and acceptance criteria into a handoff doc. Broader than decomposition (atlas-component-decomposition), which it can include."
```

### 4b.6 — `atlas-aurora-compliance`  ← `action-aurora-compliance-check`
```yaml
description: "Validate an Appian interface/design against Aurora Design System standards. Use for 'Aurora check', 'compliance', 'design system check', 'standards', 'validate against Aurora'. Fetches Aurora docs via Atlas Git-content tools and checks components/layouts/branding adherence. Self-contained (Aurora docs only) — does not use the repo's a11y skills; that keeps the agent Atlas-only."
```

---

## Step 4.7 — Validate every skill
```bash
for s in atlas-html-prototype atlas-sailwind-prototype atlas-generate-sail-interface \
         atlas-edge-case-analysis atlas-feasibility-check atlas-design-consistency-review \
         atlas-component-decomposition atlas-design-handoff atlas-aurora-compliance; do
  python3 .kiro/skills/skill-creator/scripts/quick_validate.py .kiro/skills/$s
done
```

## Phase 4 exit criteria
- [ ] 9 UX skill folders with valid SKILL.md; large templates moved to `references/`.
- [ ] Build skills fetch external docs via Atlas Git-content tools only (no extra MCP/installs
      except Node.js for React).
- [ ] `atlas-generate-sail-interface` and `atlas-generate-sql` descriptions cross-disambiguate.
- [ ] `atlas-aurora-compliance` has no dependency on `appian-a11y-rules` or any non-Atlas asset.
- [ ] No `atlas-publish-prototype` invented; all 9 real action files retained.
- [ ] All pass `quick_validate.py`.
