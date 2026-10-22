# Upgrade Assist — Agent Onboarding

> **Read this file first.** By the end of it (and the four docs it points to) you will understand the Upgrade Assist
> program, the three projects it is built on, the target architecture, and the known risks — and you will be in a
> **ready state** to spec or build.
>
> **Scope boundary:** This `upgrade-assist/` folder is **self-contained** and lives at `project-tracker/upgrade-assist/`
> — a **separate project** from the sibling `genesis/` folder. **Upgrade Assist is NOT part of the Genesis SDLC-platform
> program.** Do **not** read the `genesis/` bible / specs / agent-system to work on Upgrade Assist, and do not use the
> `genesis-*` role agents or `genesis-ctx` for it.

---

## 1. What Upgrade Assist is (one paragraph)

Upgrade Assist is the **React-UI successor to the "Merge Assist" Appian application** (renamed — customers disliked
"Merge Assist"). The product helps customers **upgrade customized Appian solutions**: it compares a new vendor package
against the customer's current (customized) Appian environment (and optionally the original base package) and shows the
**object-by-object differences and conflicts** so the upgrade can be reviewed and merged safely. This program **keeps
the existing Appian backend** (data model, process models, and the XML→diff converter logic) and **replaces the SAIL
front-end with a modern React UI**, using the **Synapse plugin methodology** (React component plugin + Java suite
plugin, with Appian as the sole backend).

## 2. Required reading order

1. **[`SUMMARY.md`](SUMMARY.md)** — the program in full: the product journey, the target architecture diagram, and the
   key design decisions/risks. Start here after this file.
2. **[`understanding/merge-assist-appian.md`](understanding/merge-assist-appian.md)** — **the most important doc.** The
   existing Appian app we keep: object inventory (with UUIDs), the 107-rule logic layer, the `MA_convert_*` converters,
   the normalized three-way model, the SAIL screens we replace, and the **internal-platform-function dependencies +
   risks**. Includes the **open questions** (§8) that the spec must answer.
3. **[`understanding/synapse-solutions-plugin.md`](understanding/synapse-solutions-plugin.md)** — the **reference
   architecture** we copy: how a React component plugin + Java suite plugin are wired into Appian, the SAIL↔React
   contract, client APIs, and gotchas (iframe height, i18n/branding injection, a11y).
4. **[`understanding/three-way-merge.md`](understanding/three-way-merge.md)** — the **origin + domain algorithm**: the
   set-theory conflict classification, diff-hash comparison, object parsers, and per-change review model. (Note: 3WM is
   a **Flask/Python desktop app, not React** — a common misconception.)

After these four you understand all three repos and the plan. For anything deeper, go to the live sources in §4.

## 3. The 30-second mental model

- **Three legs:** **Base** (original vendor, optional upload) · **Customized** (= the **live Appian environment**, not an
  upload) · **Latest** (new vendor, required upload).
- **Up to three diff pairings:** Latest-vs-Env ✅, Base-vs-Latest ✅, Base-vs-Env 🔜 (planned). Pairing is a
  **first-class selectable dimension** in the UI.
- **Backend stays in Appian.** `MA_REC_*` record types + 9 process models + ~107 expression rules (the `MA_convert_*`
  converters are the crown jewels). We keep all of it.
- **React replaces SAIL.** A React component plugin renders the UI; a Java suite plugin exposes diff-map JSON,
  dependents/precedents, and session/review writes via `invokeClientApi`.
- **The diff renderer is the hard part.** Today it is an **internal Appian diff-view framework** (data contract + 
  renderer). React can't embed it → **rebuild the diff viewer in React** off converter JSON.

## 4. Live sources (ground truth — go here for detail beyond the docs)

| Source | Location / handle | Use for |
|---|---|---|
| **Merge Assist (Appian app)** | Dev MCP in this workspace. App UUID `33060c62-b495-4c03-9948-206c2f976d2b` (prefix `MA`). Tester app `MAT` = `_a-0000efec-4e49-8000-9be6-011c48011c48_75004`. | Inspecting record types, process models, expression rules, interfaces, the site. **Load the `appian` skill before calling MCP tools.** |
| **Synapse plugin** | `git@gitlab.appian-stratus.com:appian/prod/synapse-solutions-plugin.git` (clone over SSH; HTTPS is auth-gated). | The React-component + suite-plugin reference implementation. |
| **3WM desktop app** | `/Users/ramaswamy.u/repo/3WM` (local). | The original algorithm + object parsers + review REST API. |

## 5. Working rules / gotchas for agents

1. **Load the `appian` skill before any Appian MCP call** (naming conventions, relationship rules, dependency order,
   UUID handling, deletion-confirmation workflow — the schemas don't convey these).
2. **Internal functions:** many `MA_*` interfaces/rules reference **undocumented internal Appian functions**. The Dev
   MCP often **cannot read** them. If an object is unreadable, treat it as **"uses internal functions," not broken** —
   flag it, never fabricate its contents.
3. **Don't confuse the programs:** Upgrade Assist ≠ Genesis. Ignore the surrounding Genesis docs/agents for this work.
4. **3WM is Python, not React** — don't propagate the "it was React" framing.
5. **Keep the backend; replace the front-end.** Default stance: reuse record types / process models / converter rules;
   rebuild only the UI (and wrap internal-function logic behind a suite-plugin client API).
6. **This is pre-spec.** No Upgrade Assist code exists yet. If asked to build, expect to author a spec first; the open
   questions in `understanding/merge-assist-appian.md` §8 are the agenda.

## 6. Folder map

```
upgrade-assist/
├── AGENT_ONBOARDING.md                      ← you are here (read first)
├── SUMMARY.md                               ← the program, architecture, decisions/risks
└── understanding/
    ├── merge-assist-appian.md               ← the backend we keep (most important) + open questions
    ├── synapse-solutions-plugin.md          ← the React+suite-plugin reference architecture
    └── three-way-merge.md                   ← the origin domain algorithm (Flask/Python desktop)
```
