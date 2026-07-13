# Phase 8 — Settings & Integrations Revamp

**Status:** 📋 Planned (spec drafted 2026-07-13) · **Layer:** `web` (frontend-only; backend/API
already provide everything needed — see §2). · **Depends on:** 07-04 (settings), spec 03
(Integrations Studio two-tier registry), spec 04 (retention). · **Supersedes** the ad-hoc settings
layout shipped across 07-04 + spec 03.

> **Goal:** turn the settings area from one long stacked-`Section` scroll (with three inconsistent
> add/edit dialogs and several data-fidelity bugs) into a single **tabbed Settings workspace** —
> **MCP · CLI · GitLab · Environments · General** — with ONE standardized, polished, reusable
> master-detail + form pattern used across every integration type. Enterprise-grade polish, still
> local single-user (ADR-026 unchanged).

---

## 1. Motivation — what's wrong today (code-grounded)

Verified by reading `web/src/features/settings/**`, `web/src/shared/layout/Sidebar.tsx`,
`web/src/app/router.tsx` on 2026-07-13.

1. **Three entry points, one page.** Sidebar "Configure" group has `Integrations`→`/settings` and
   `Environments`→`/settings/environments`, plus a redundant bottom `Settings`→`/settings`.
2. **One long scroll.** `SettingsPage` stacks 5 `<Section>`s (MCP master-detail, CLI grid, GitLab,
   Environments, Storage). `/settings/:server` selects an MCP server; `/settings/environments`
   `scrollIntoView`s. No tabs; poor information scent; everything mounts/fetches at once.
3. **Inconsistent add/edit UX (three patterns).**
   - `AddMcpDialog` (McpSection): raw `fixed inset-0 bg-black/50` overlay, JSON-only, emoji warning.
   - `AddCliDialog` (CliSection): another raw overlay, one shared `nameError` string for all fields.
   - `EnvDialog` (EnvironmentsSection): the **good** one — shared `Dialog` + react-hook-form + zod +
     inline field errors + server-error surface + a proper confirm-delete `Dialog`.
   - `McpServerDetail` delete uses browser `confirm()`.
4. **Data-fidelity bugs in `McpServerDetail`** (renders off `mcp-cards` only):
   - Configuration JSON is **fabricated** (`JSON.stringify({ mode: card.mode })`) — never loads the
     real custom `spec` (command/args/env/tool_allowlist) from `GET /config/mcp-servers`.
   - `allowedTools` initializes to `[]` on mount — never seeds from `spec.tool_allowlist`, so a
     server with an allowlist always renders "no tools restricted".
   - `isCustom` reads `card.source`, but `mcp-cards` has no `source` (it lives on `McpServerEntry`).
     Net effect: **Delete never shows, config is always read-only → custom MCP servers can't be
     edited or deleted from the UI**, and `updateMcpServer` is never called anywhere.
5. **CLI CRUD unwired.** `useClis()`, `updateCli`, `useDeleteCli` exist; `CliSection` renders
   read-only `cli-cards` with no edit/delete.
6. **Design-token drift.** `McpServerDetail` uses raw palette (`text-emerald-400`, `bg-red-400`,
   `border-amber-500/30`) instead of semantic tokens (`text-success/-danger/-warning`, `HealthDot`),
   violating 07-03a/ADR-027.

**Non-goals (unchanged posture):** no auth/multi-tenancy (ADR-026); no new backend endpoints (the
API from spec 03/04 is sufficient — §2); no secret values ever returned by any API; curated-tier
integrations stay MR-governed (read-only in the app, ADR-005/029).

---

## 2. Backend/API is already sufficient (no server changes)

The two-tier registry (spec 03) + retention (spec 04) already expose everything the revamp needs.
This is a **frontend-only** phase.

| Concern | Existing endpoint(s) | Notes |
|---|---|---|
| MCP merged view + status + secret fields | `GET /config/mcp-cards` | status `configured\|missing_secret`, `fields`, `missing_secrets` |
| MCP custom entries (raw spec + allowlist + source) | `GET /config/mcp-servers` | `McpServerEntry{name,source,overrides_curated,spec}` |
| MCP CRUD | `POST/PUT/DELETE /config/mcp-servers[/{name}]` | custom tier only |
| MCP tools introspection | `POST /config/mcp-servers/{name}/tools` | direct stdio |
| MCP allowlist | `PUT /config/mcp-servers/{name}/allowlist` | |
| MCP connection test | `POST /config/mcp-servers/{name}/test` (or `mcp-cards/{server}/test`) | real handshake |
| CLI cards (availability) | `GET /config/cli-cards` | `available` + `install_hint` |
| CLI custom entries | `GET /config/clis` | `CliEntry{name,source,overrides_curated,spec}` |
| CLI CRUD | `POST/PUT/DELETE /config/clis[/{name}]` | |
| GitLab token | `GET/POST /config/gitlab-token` | write-only |
| Environments | `GET/POST /config/environments`, `DELETE /config/environments/{label}` | credential-free |
| Storage + retention | `GET /artifacts/usage`, `GET/POST /config/retention/{plan,apply}` | spec 04 |

**One small FE data-layer addition** (not a backend change): a merged selector that joins
`mcp-cards` (status + secret fields) with `mcp-servers` (source + raw spec + allowlist) by name, so
the detail pane has the *real* spec + allowlist + a correct `source`. Same join for CLI
(`cli-cards` ⋈ `clis`).

---

## 3. Target architecture

### 3.1 Routing (React Router)
Replace the current `/settings`, `/settings/environments`, `/settings/:server` with a single
tab-parameterized route:

```
/settings                      → redirect/default to /settings/mcp
/settings/:tab                 → tab ∈ { mcp, cli, gitlab, environments, general }
/settings/:tab/:id             → deep-link a selected resource (mcp server / cli name)
```

- `SettingsPage` reads `:tab` (default `mcp`) and `:id`. Tab switch = `navigate` (URL is the source
  of truth so deep links + back/forward work; ADR-028 client routing).
- Keep legacy redirects so existing links don't 404: `/settings/environments` → `/settings/environments`
  (now a real tab); old `/settings/:server` (a bare server id) → `/settings/mcp/:server` (handled by
  a small compatibility resolver, or just accept the reshuffle since it's a local app).

### 3.2 Sidebar (`shared/layout/Sidebar.tsx`)
- **Remove** the `Configure` group's two items (`Integrations`, `Environments`).
- The **bottom-left `Settings`** link (already present) becomes the single entry → `/settings`.
  Mark it active for any `/settings*` path (`NavLink` with a `className` isActive on prefix).
- `RootLayout` `LABELS`: map `settings`→"Settings"; add tab labels for breadcrumbs
  (`mcp`→"MCP", `cli`→"CLI", `gitlab`→"GitLab", `environments`→"Environments", `general`→"General").

### 3.3 Settings shell (`SettingsPage.tsx`, rewritten)
```
<Page title="Settings" subtitle="Integrations, access, environments, and storage.">
  <Tabs value={tab} onValueChange={(t)=>navigate(`/settings/${t}`)}>
    <TabsList> MCP · CLI · GitLab · Environments · General </TabsList>
    <TabsContent value="mcp">          <McpTab selected={id}/> </TabsContent>
    <TabsContent value="cli">          <CliTab selected={id}/> </TabsContent>
    <TabsContent value="gitlab">       <GitlabSection/>        </TabsContent>
    <TabsContent value="environments"> <EnvironmentsTab/>      </TabsContent>
    <TabsContent value="general">      <GeneralTab/>           </TabsContent>
  </Tabs>
</Page>
```
Each `TabsContent` lazy-mounts (Radix unmounts inactive content by default) → only the active tab
fetches. Tab count badges (e.g. "MCP 4", CLI "3", a warning dot when a required secret is missing).

### 3.4 The standardized master-detail pattern (the heart of this phase)
A reusable, generic **`ResourceManager`** used by both the MCP and CLI tabs (and available for
future integration types). It encodes the "standard screen + layout" the user asked for.

```tsx
// features/settings/components/manager/ResourceManager.tsx
interface ResourceManagerProps<T> {
  items: ResourceListItem[];        // {id, title, subtitle?, status, tier: "curated"|"custom", badges?}
  selectedId?: string;
  onSelect: (id: string) => void;
  search: { placeholder: string; };
  emptyState: { icon; title; description; };
  addLabel: string;                 // e.g. "Add MCP Server"
  onAdd: () => void;                 // opens the standard ResourceFormDialog
  detail: React.ReactNode;          // the selected item's detail pane
  isLoading; isError; error; onRetry;
}
```
Layout (matches the current MCP master-detail, generalized + polished):
```
┌───────────────────────────────┬───────────────────────────────────────┐
│ [search]                [+Add] │  Detail header: title · HealthDot ·     │
│ ─────────────────────────────  │    tier badge · actions (Test/Save/Del) │
│ ○ appian-atlas   curated       │  ───────────────────────────────────── │
│ ● jarvis         custom        │  <detail sections>                      │
│ ○ my-tool        custom  ⚠     │                                         │
└───────────────────────────────┴───────────────────────────────────────┘
```
- Left list: `HealthDot` (status) + title + a small **tier chip** (`curated`/`custom`) + a
  warning dot if a required secret is missing. Attention-first sort (missing → configured → alpha).
  Keyboard: `role="listbox"`/`option`, arrow-key nav, `aria-selected`.
- Responsive: at `<md`, the list collapses to a top `<select>`/segmented picker + full-width detail.
- Uses `SplitPane` (existing) or a CSS grid `[minmax(240px,300px)_1fr]`.

### 3.5 The standardized detail pane (`ResourceDetail`)
A consistent, section-based detail with a fixed header + vertically-scrolled sections. Curated
resources render **read-only** with a top banner: *"Curated integration — installed from the
workflow library. Edit via a merge request (ADR-005)."* Custom resources are fully editable.

**Header (all types):** title, `HealthDot` + status label (semantic tokens, not raw colors),
tier chip, and a right-aligned action cluster: `Test connection` (MCP), `Save`, `Delete` (custom
only, opens the shared confirm dialog — **no more `confirm()`**).

**MCP detail sections** (driven by the *merged* `McpServerEntry.spec` ⋈ `McpCard`):
1. **Overview** — mode, source, `note`; the merged status + last test result banner (semantic tokens).
2. **Configuration** — a **guided form** (command, args list, env rows) with an **"Advanced (JSON)"**
   `Switch`/`SegmentedControl` toggle backed by `JsonEditor` (the two stay in sync; JSON is the
   escape hatch). On save → `updateMcpServer(name, spec)` (custom only). **Fixes the fabricated-JSON
   bug** by loading the real `spec`.
3. **Allowed tools** — seeds from `spec.tool_allowlist` (**fixes the reset-to-`[]` bug**); add/remove
   chips + `Discover` (introspect) → `PUT allowlist`. Empty = "all tools allowed" with a clear note.
4. **Secrets & fields** — the existing write-only per-field form (react-hook-form), unchanged in
   behavior, restyled to the standard section.

**CLI detail sections:** Overview (binary, availability via `HealthDot`, `install_hint`),
Configuration (binary, note, install_hint, version_check — guided form; JSON advanced toggle),
delete (custom only). **Wires the currently-dead CLI edit/delete.**

### 3.6 The ONE standard add/edit form (`ResourceFormDialog`)
Retire both raw overlays. A single dialog built on the shared `Dialog` + react-hook-form + zod
(the `EnvDialog` pattern, generalized):

```tsx
// features/settings/components/manager/ResourceFormDialog.tsx
<Dialog open onOpenChange={...}>
  <DialogContent>
    <DialogTitle>{isEdit ? `Edit ${kind}` : `Add ${kind}`}</DialogTitle>
    <DialogDescription>…</DialogDescription>   // fixes the a11y "Missing Description" warning
    <form> {fields via a schema-driven renderer} </form>
    {securityCallout /* custom command runs with your privileges */}
    {serverError}
    <footer> Cancel · Save </footer>
  </DialogContent>
</Dialog>
```
- **Field renderer**: a small `FormField[]` schema per type (name, command, args, env, mode,
  secretKeys, note for MCP; name, binary, note, install_hint for CLI) → renders `Field` + `Input`/
  `Textarea`/`Switch` with per-field zod errors. An **"Advanced (JSON)"** toggle swaps the guided
  form for `JsonEditor` on the whole spec (round-trips both ways).
- **Name validation**: reuse the existing `^[a-z0-9][a-z0-9_-]*$` rule, surfaced as a *per-field*
  error (not the shared string). Block name collisions with an existing custom entry.
- **Security callout**: replace the emoji line with a tokenized `TriangleAlert` warning banner
  (custom MCP/CLI runs a local command with the user's privileges).

### 3.7 GitLab / Environments / General tabs
- **GitLab**: `GitlabSection` reused as-is (already clean); just re-homed into the tab.
- **Environments**: `EnvironmentsSection` reused (already the canonical Dialog/RHF/zod pattern);
  its `EnvDialog` becomes the reference the `ResourceFormDialog` generalizes. Remove the
  `scrollIntoView` hack (now a tab).
- **General**: `StorageSection` (usage + retention "Reclaim space" from spec 04). Room to add
  future app-level prefs (theme, default environment) here later — this is why it's "General", not
  just "Storage".

---

## 4. Files (frontend only)

| File | Change |
|------|--------|
| `shared/layout/Sidebar.tsx` | remove `Configure` group items; single bottom `Settings` entry active on `/settings*` |
| `app/router.tsx` | `/settings/:tab?/:id?`; legacy redirects |
| `app/RootLayout.tsx` | breadcrumb labels for tabs |
| `features/settings/SettingsPage.tsx` | rewrite → `Tabs` shell |
| `features/settings/components/manager/ResourceManager.tsx` | **new** — generic master-detail scaffold |
| `features/settings/components/manager/ResourceDetail.tsx` | **new** — generic section-based detail + header/actions |
| `features/settings/components/manager/ResourceFormDialog.tsx` | **new** — the one standard add/edit dialog |
| `features/settings/components/manager/SpecForm.tsx` | **new** — guided form ⇄ JSON (Advanced) editor |
| `features/settings/components/manager/ConfirmDialog.tsx` | **new** — shared confirm (replaces `confirm()`; reuse env pattern) |
| `features/settings/components/mcp/McpTab.tsx` | **new** — wires ResourceManager to merged MCP data |
| `features/settings/components/mcp/McpDetail.tsx` | **new** — MCP sections (fixes spec/allowlist/source bugs) |
| `features/settings/components/cli/CliTab.tsx` | **new** — wires ResourceManager to merged CLI data (adds edit/delete) |
| `features/settings/components/cli/CliDetail.tsx` | **new** |
| `features/settings/components/EnvironmentsSection.tsx` | keep; drop scroll hack; reuse in tab |
| `features/settings/components/GitlabSection.tsx` | keep; reuse in tab |
| `features/settings/components/StorageSection.tsx` | keep; render under General tab |
| `features/settings/components/{McpSection,McpServerDetail,CliSection,AddMcp/AddCli dialogs}.tsx` | **remove** (replaced by manager/* + mcp/* + cli/*) |
| `features/settings/hooks.ts` | add `useUpdateMcpServer`, `useUpdateCli`; add merged selectors `useMcpResources()`, `useCliResources()` (join cards ⋈ entries) |
| `lib/query/keys.ts` | ensure keys for `mcp-servers`, `clis`, `mcp-cards`, `cli-cards` coexist for the join |
| `features/settings/settings.test.tsx` | update to tabbed structure + add coverage (§6) |
| `types/config.ts` / `types/integrations.ts` | add a `McpResource`/`CliResource` merged view type |

No backend, no `genesis-core`, no new dependency (Tabs/Dialog/Switch/Segmented/JsonEditor all exist).

---

## 5. UX / visual standards (enforce)

- **Design tokens only** — replace every raw `emerald/red/amber` in `McpServerDetail` with
  `success/danger/warning` tokens + `HealthDot`/`Badge`/`Chip` (07-03a, ADR-027).
- **One dialog primitive** — everything on shared `Dialog`/`DialogContent` with `DialogTitle` +
  `DialogDescription` (fixes the RTL "Missing Description" a11y warning seen in tests).
- **Consistent density & spacing** — reuse `Card`/`CardBody`, `Field`, `Section` spacing; detail
  sections use the same header rhythm as the run-detail inspector.
- **Loading/empty/error** — every tab uses `LoadingState`/`EmptyState`/`ErrorState` (already used).
- **A11y** — list is a `listbox`; tabs are Radix (roving tabindex, `aria-selected`); dialogs trap
  focus; all icon-only buttons have `aria-label`; jest-axe on the shell + a dialog.
- **Keyboard & deep-link** — arrow-key list nav; the URL always reflects tab + selection.
- **Responsive** — master-detail collapses to stacked (picker + detail) under `md`.

---

## 6. Testing / DoD

**Unit / component (Vitest + RTL + MSW):**
- Tab switching updates the URL and lazy-mounts only the active tab's queries.
- MCP: merged selector joins card+entry → detail shows the **real** `command`/`args` and seeds the
  allowlist from `spec.tool_allowlist` (regression tests for the two data-fidelity bugs).
- MCP custom: Save calls `PUT /config/mcp-servers/{name}` with the edited spec; Delete opens the
  shared confirm then `DELETE`s (no `confirm()`).
- Curated MCP/CLI: detail is read-only + shows the "edit via MR" banner; no Save/Delete.
- CLI: edit + delete are now wired (regression: they were dead).
- `ResourceFormDialog`: per-field zod errors; name-collision + pattern validation; Advanced-JSON
  toggle round-trips to the guided form.
- Environments + GitLab + General render under their tabs; retention reclaim flow still works.
- **jest-axe** on the settings shell and on `ResourceFormDialog`.
- Keep the existing 6 settings tests green (updated to the tabbed structure).

**DoD:** `tsc` + `eslint` (0 errors) + `vitest` green; `npm run build` + **commit `web/static/`**
(stale-bundle guard); a genesis release (frontend ships via committed `static/`); a manual
`genesis serve` browser pass (tab nav, add/edit/delete MCP + CLI, curated read-only, deep links,
responsive). Update tracker §6 + a `progress/phase-08-...` doc.

---

## 7. Delivery plan (incremental, each independently green)

1. **Shell + routing + sidebar** — Tabs skeleton, `/settings/:tab?/:id?`, remove Configure items,
   re-home GitLab/Environments/General verbatim (no behavior change). Ship.
2. **`ResourceManager` + `ResourceDetail` + `ConfirmDialog` + `ResourceFormDialog` + `SpecForm`** —
   the generic framework, with a Storybook-less `/dev` KitchenSink entry for visual QA.
3. **MCP tab** on the framework — merged selector, real spec/allowlist, wire `updateMcpServer`,
   guided+JSON form, curated read-only. Fixes §1.4.
4. **CLI tab** on the framework — merged selector, wire edit/delete. Fixes §1.5.
5. **Polish + a11y + responsive + tests**; rebuild `static/`; release; progress doc.

Estimate: ~2–3 focused sessions. Steps 1–2 are the foundation; 3–4 reuse it; 5 hardens.

---

## 8. Risks / decisions

- **Route reshuffle** may break bookmarked `/settings/<server>` links — mitigated by a compat
  redirect; acceptable for a local app.
- **Guided-form ⇄ JSON sync** is the trickiest piece; the JSON editor stays the source of truth on
  the Advanced tab, the guided form on Basic; switching re-parses. Invalid JSON disables Save.
- **Merged selector** must treat `mcp-cards` (status/secrets) and `mcp-servers` (spec/source) as
  independent queries joined by name; a custom-only server with no card still lists (status derived
  from missing secrets), and a curated server with no custom entry is read-only.
- **Scope guard:** no new backend, no auth, no new deps; curated tier stays MR-governed.
