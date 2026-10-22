# Understanding — Synapse Solutions Plugin (the methodology reference)

> **Role in Upgrade Assist:** Synapse is **not** our application. It is the **reference architecture** — the
> proven pattern we are copying to give Upgrade Assist a modern React UI while keeping all data and logic in Appian.
> Read this to understand *how* a React front-end is deployed into Appian and talks to an Appian backend.

- **Repo:** `https://gitlab.appian-stratus.com/appian/prod/synapse-solutions-plugin` (private GitLab; clone over SSH).
- **What it is:** a full-stack Appian **plugin suite** powering "Synapse", an AI document-processing / verification /
  knowledge-management product built on top of Appian.
- **Captured:** 2026-10-22 (from README + component-plugin/README + suite-plugin/README).

---

## 1. The big idea

Synapse delivers a **modern React UI that renders *inside* Appian** and uses **Appian as its entire backend** (data,
security, business logic, AI agents). The React app has **no database of its own** — it reaches into Appian through a
connected system. This is exactly the model Upgrade Assist wants to adopt.

It is built from **two cooperating plugins**:

```
┌────────────────────────── Appian Platform ──────────────────────────┐
│  SAIL interface                                                      │
│    synapseMain(state, connectedSystem, brandingMap, translationMap)  │
└───────────────┬─────────────────────────────────┬────────────────────┘
                │ Component SDK                    │ Client APIs
                │ (onNewValue / saveValue)         │ (invokeClientApi)
                ▼                                  ▼
   ┌────────────────────────┐        ┌──────────────────────────────┐
   │  Component Plugin       │        │      Suite Plugin             │
   │  React / TypeScript     │───────▶│      Java 17 / Gradle         │
   │  (Vite build → .zip)    │        │  Connected System +           │
   │                         │        │  client APIs + expr functions │
   └────────────────────────┘        └──────────────────────────────┘
                │                                  │
        component-plugin/dist/*.zip        suite-plugin/build/libs/*.jar
                └──────────────┬───────────────────┘
                               ▼
                     playwright-deploy/  (automated upload to Appian sites)
```

## 2. component-plugin/ — the React front-end (Appian **Component Plugin**)

- React + TypeScript, built with **Vite**; output is a zipped Appian component plugin
  (`dist/synapse-component-plugin-<version>.zip`).
- A component is exposed to SAIL as a function, e.g. `synapseMain(...)`. SAIL passes it **four inputs**, which are the
  entire contract between Appian and React:

  | Param | Direction | Purpose |
  |---|---|---|
  | `state` | input-output | A URL-style routing string (`t:…/e:…/u:…/p:…`). The React app parses it to decide what to show, and writes it back via `saveValue` so navigation persists in SAIL. |
  | `connectedSystem` | input | The connected system handle used to call server-side client APIs / query data. |
  | `brandingMap` | input | Appian theme colors → applied as CSS variables so the React UI matches the environment theme. |
  | `translationMap` | input | Translated UI strings → all user-facing text goes through `t(key, default)`; **no hardcoded strings**. |

- **Two channels back into Appian:**
  1. **SDK glue** — `onNewValue` / `saveValue` (persist `state` and other outputs into SAIL). Lives in the `*Main.tsx`
     wrapper files.
  2. **Client APIs** — `Appian.Component.invokeClientApi()` and query calls, which run the suite plugin's server-side
     Java against Appian data/design objects.
- **Shared infra worth copying:** `i18n.ts` (translation provider), `brandingColors.ts` (branding → CSS vars),
  `componentHeight.ts` (publishes platform height as `--syn-component-height`), a `styles/` design-token system, and a
  `shared/` primitive library (Icon, search box, menus, markdown editor, cross-origin-safe clipboard).
- **A known iframe constraint (important for our diff viewer):** the component iframe is **auto-height and cannot read
  its SAIL pane**, so a definite **pixel height** must be set (`--syn-component-height`, e.g. 900px for the workspace).
  A percentage height renders blank. Any large scrolling surface (like a diff view) must bound its own height.
- **Quality gates baked in:** Jest + 80% per-file coverage, ESLint/Prettier, and **automated accessibility scans**
  (`jest-axe`) that run inside the normal test job — any WCAG violation fails CI.

### Multiple components in one plugin
Synapse ships several components in one plugin (`synapseMain`, `synapseWorkspace`). Adding one touches four places
(registry entry, `<name>.html` root, `public/<name>.svg` + `_en_US.properties`, and a `<component>` block in
`appian-component-plugin.xml`). The three-pane workspace is built as a JS component (nav + content) placed beside a
**separate SAIL chat component** inside an `a!paneLayout` — i.e. React and SAIL panes can coexist in one screen.

## 3. suite-plugin/ — the Java backend bridge (Appian **Connected System**)

- Java 17 / Gradle. Registers a **connected-system template** that hosts **client APIs** (called from React) and
  **expression functions** (callable from SAIL). This is the privileged bridge that lets the browser run server-side
  Appian operations.
- Representative client APIs (the surface React calls):
  - `invokeFunction` — safely evaluate **whitelisted** Appian expression functions server-side.
  - `queryProcessModels` — list/validate process models (runs as the logged-in user, so it respects permissions).
  - `getDocumentMetadata`, `uploadDocument` — document plumbing.
  - `lcpApi` — proxy to the Appian Objects (design-time) REST API (`/suite/api/v2/`) using the connected system's
    configured basic-auth creds, so React can create/patch design objects without a bespoke process model per op.
  - `deployKnowledgeBase`, `updateKnowledgeBaseAgentTools`, `updateSharePoint`, `updateGoogleDrive` — higher-level
    deploy/update operations that generate Appian object XML and import it via the Deployment API.
- **Design patterns worth copying:** thin SDK-glue classes delegate to **pure, unit-tested** helper classes
  (search/validate/resolve/generate split out). JUnit 5 + JaCoCo with **80% instruction coverage per class**
  (SDK-glue classes exempted). This keeps the hard logic testable off-platform.

## 4. Build / deploy / dev loop (shape we can mirror)

- Root scripts orchestrate both plugins: `setup.sh`, `build.sh` (build + deploy to dev/test), `dev.sh` (Vite dev server
  with hot reload, proxying API calls to a **real** Appian site via `dev/dev-config.json`), `test-unit.sh`, `lint.sh`,
  `sync.sh`.
- A single root **`VERSION`** is injected into both the component XML and the Java plugin XML at build time.
- **`playwright-deploy/`** automates uploading the built artifacts to Appian sites.
- GitLab CI: lint (ESLint/Checkstyle) → test (Jest/JUnit, both with coverage) → build (Vite zip / Gradle jar) →
  security scan (Semgrep/Checkov/Mend/Gitleaks) → release on `main`.

## 5. Takeaways we carry into Upgrade Assist

1. **React is only a renderer.** No client-side DB; Appian owns data/security/logic. Our Merge Assist backend stays.
2. **The SAIL↔React contract is tiny and known**: `state` + `connectedSystem` + `brandingMap` + `translationMap`, plus
   `invokeClientApi` for everything dynamic. Branding + i18n are injected from Appian.
3. **A suite (Java) plugin is required** to expose server-side operations (query diff data, resolve dependents/
   precedents, run session/review writes) to the React component. This is where we surface Merge Assist's expression
   rules / internal-function logic to the browser.
4. **Mind the iframe height constraint** — critical for a scrolling diff viewer.
5. **Accessibility + i18n + branding are first-class from day one** (enforced in CI), not afterthoughts.
