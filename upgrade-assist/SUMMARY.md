# Upgrade Assist — Program Summary

- **Status:** 🟡 Pre-spec / discovery. Understanding captured 2026-10-22; no code written for Upgrade Assist yet.
- **This folder is self-contained** and lives at `project-tracker/upgrade-assist/` — a **separate project** from the
  sibling `genesis/` folder. Upgrade Assist is **not** part of the Genesis build program.

---

## What Upgrade Assist is

**Upgrade Assist is the next generation of the "Merge Assist" Appian application** — same product, renamed because
customers reacted poorly to the name "Merge Assist." The product helps customers manage **Appian solution upgrades**:
when a customer has customized a vendor solution and the vendor ships a new version, Upgrade Assist analyzes and shows
the differences so the customer can review conflicts and merge safely.

**The goal of this effort:** give the product a **modern, React-based UI** while **keeping the entire existing Appian
backend** (data model, workflow process models, and the hard-won XML→diff converter logic). We achieve this by adopting
the **Synapse plugin methodology**: a React **component plugin** rendered inside Appian + a Java **suite plugin**
(connected system) that exposes server-side operations to the browser, with Appian remaining the sole backend.

## The product journey (why we are here)

1. **3WM (desktop):** the idea started as a **Flask/Python desktop app** (`pywebview`) doing a classic **three-way
   merge** of three uploaded Appian packages (Base / Customer / New-Vendor). Customers liked the capability but did
   **not** want a locally-installed app.
2. **Merge Assist (Appian, SAIL):** we rebuilt the whole thing **natively in Appian** — record types, process models,
   and ~107 expression rules (notably the `MA_convert_*` converters) — with a **SAIL** front-end. The capability landed,
   but customers found the **SAIL UI not as good** as the desktop app's UI.
3. **Upgrade Assist (Appian + React) — this program:** keep the Appian backend, **replace the SAIL UI with React** using
   the Synapse component-plugin + suite-plugin pattern. Modern UX, Appian-native data and logic.

## The three reference projects (each has its own understanding doc)

| # | Project | What it gives us | Doc |
|---|---|---|---|
| 1 | **Synapse Solutions Plugin** | The **methodology/reference architecture** — how a React component plugin + Java suite plugin run inside Appian with Appian as the backend. | [`understanding/synapse-solutions-plugin.md`](understanding/synapse-solutions-plugin.md) |
| 2 | **Three-Way Merge (3WM)** | The **origin + domain algorithm** — set-theory conflict classification, diff-hash comparison, ~12 object parsers, per-change review. (Flask/Python desktop app — **not** React.) | [`understanding/three-way-merge.md`](understanding/three-way-merge.md) |
| 3 | **Merge Assist (Appian)** | The **backend we keep** — record types, process models, the `MA_convert_*` converter logic, and the SAIL UI we replace. Includes the internal-platform-function dependencies. | [`understanding/merge-assist-appian.md`](understanding/merge-assist-appian.md) |

## The architecture we are building toward

```
┌────────────────────────── Appian (customer's customized env) ──────────────────────────┐
│  SAIL interface  ─────────────────────────────────────────────────────────────────────┐ │
│    upgradeAssistMain(state, connectedSystem, brandingMap, translationMap)               │ │
│                                                                                         │ │
│   React Component Plugin  ──invokeClientApi──▶  Java Suite Plugin (Connected System)    │ │
│   (dashboard, session create,                   • fetch diff-map JSON (from converters) │ │
│    review flow, DIFF VIEWER)                    • dependents / precedents               │ │
│                                                 • session / review writes               │ │
│                                                 • AI-summary fetch                      │ │
│                        ▲                                   │                            │ │
│                        │                                   ▼                            │ │
│                  (keep as-is) ◀── Record types · Process models · MA_convert_* rules ───┘ │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

## The key design decisions / risks (the short list)

1. **Diff rendering is the crux.** The current diff relies on an **internal Appian diff-view framework** that is both the
   data contract *and* the renderer. React cannot embed the renderer → **we must rebuild the diff visualization in
   React**, fed by the converter output as JSON. (Possible upside: we define our own canonical diff schema, which may
   simplify the still-incomplete XML converters.)
2. **Internal-function dependencies.** Converters, the diff framework, and dependents/precedents use **undocumented
   internal Appian functions**. Consequence: the **Dev MCP often cannot read objects that reference them** — agents must
   treat such objects as "uses internal functions," not broken, and must not fabricate their contents.
3. **Three-way, normalized.** The customer leg = the **live environment** (not an upload). Up to **three comparison
   pairings** (Latest-vs-Env ✅, Base-vs-Latest ✅, Base-vs-Env 🔜). The React diff viewer must treat **pairing as a
   first-class selectable dimension** from day one.
4. **A Java suite plugin is required** to surface server-side logic (diff-map, dependents/precedents, writes) to React —
   evaluate how much of Synapse's suite plugin we can reuse.
5. **Mind the component iframe height constraint** (Synapse: fixed pixel height; percentage renders blank) — matters for
   a tall scrolling diff view.

## Next step

Author a proper spec for the port (screens, client-API surface, diff schema, build/deploy pipeline). The open questions
are enumerated in [`understanding/merge-assist-appian.md`](understanding/merge-assist-appian.md) §8.
