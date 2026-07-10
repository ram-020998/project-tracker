# Phase 7.4 — Settings & Configuration Experience

> **Goal:** A polished, standard Settings area where the user manages everything the
> platform needs to run: MCP servers, CLIs, secrets/tokens, GitLab access, and
> environments — each shown as a card with **live status**, click-through to a
> configuration drawer, write-only secret handling, and a connection-test action.
> This is typically the user's first stop, so it must feel trustworthy and obvious.

Prereq: 07-02 (per-integration status/test endpoints, mcp/cli cards), 07-03 (design
system) + 07-03a (visual language). Feature dir: `features/settings/`. Routes:
`/settings`, `/settings/:server`.

> **Layout update (per `phase-07-03a`):** adopt Overcut's **master-detail** pattern
> for MCP/CLI configuration instead of a slide-over drawer — a left **list panel**
> ("N servers", "+ Add", search, rows with a **StatusDot**) beside a right **detail
> form** whose header shows the server name + a **status pill** (● Active/● Inactive)
> and **Save state / Delete**. The detail form is sectioned exactly like Overcut's
> MCP detail: **General** (name/note), **Configuration** (read-only resolved config),
> **Allowed Tools** (toggle rows), **Secrets** (write-only fields). `/settings/:server`
> selects the row (deep-linkable). Cards-grid remains an acceptable alternative for
> the top-level integrations overview; the edit surface is master-detail.

---

## 1. Objective & user story

"As a Solutions engineer, I open Settings, immediately see which integrations are
ready and which need attention, click the one that's missing a token, paste it, test
the connection, and see it turn green — without editing files or reading docs."

---

## 2. Information architecture

Settings is a single page with grouped sections (tabs or anchored sections):

1. **Integrations (MCP)** — one card per MCP server from `GET /config/mcp-cards`.
2. **CLIs** — one card per CLI from `GET /config/cli-cards`.
3. **GitLab access** — the global `GITLAB_TOKEN` (used for install + Atlas etc.).
4. **Environments** — credential-free environment registry (labels, URLs, products).
5. **Storage & retention** — artifacts location + disk usage + retention policy
   (read-only display now; purge action deferred to a later item).

---

## 3. Integration cards (MCP & CLI)

### 3.1 Card anatomy

```
┌─────────────────────────────────────────────┐
│ [icon] atlas                    ● Configured  │   ← HealthDot + status label
│ Appian Atlas knowledge base MCP               │   ← note
│ Requires: GITLAB_TOKEN ✓   ATLAS_KB_PROJECT ✓ │   ← field chips (set/unset)
│ mode: docker            [ Test ]  [ Configure ]│
└─────────────────────────────────────────────┘
```

- **Status** (from 07-02 §9): `configured` (green), `missing_secret` (amber, lists
  which), `unknown` (grey). If a `reachable` probe ran: reachable=green ring,
  unreachable=red ring with reason on hover.
- **Field chips**: each required field shows set/unset (never the value).
- **Actions**: `Test` (runs `POST /config/mcp-cards/{server}/test`, shows spinner →
  result toast + inline `checked_at`), `Configure` (opens the drawer / deep-links to
  `/settings/:server`).
- Cards use the design-system Card + HealthDot + KindBadge; grid is responsive
  (1–3 columns).

### 3.2 Sorting & filtering

- Default sort: attention-first (missing_secret → unknown → configured).
- Filter chips: All / Needs attention / Configured. Search by name.

---

## 4. Configuration drawer (`/settings/:server`)

Opening a card slides in a right **Drawer** (deep-linkable):

- Header: server name, status, mode, note.
- **Fields form** (react-hook-form + zod), generated from the card's `fields`:
  - Secret fields → password inputs, placeholder `•••• set` when
    `is_set`, empty when unset; **never pre-filled with the value**. A "Replace"
    affordance for set secrets; a "Clear" to unset.
  - Non-secret fields (e.g. project id, data prefix) → text/number inputs with the
    field's `default` shown as placeholder.
  - Scope indicator: server-scoped vs global (e.g. `GITLAB_TOKEN` is global — editing
    it here is clearly labeled as affecting all servers).
- **Save** → per-field `POST /config/secrets` (only changed fields); optimistic chip
  update; invalidates `['config','mcp-cards']` and the card status.
- **Test connection** button in the drawer footer; result shown inline.
- Validation: required-but-unset fields flagged; save allowed but status stays
  `missing_secret` until complete.
- Security: values are write-only; the response returns key **names** only; nothing
  secret is logged, cached, or placed in the URL.

---

## 5. GitLab access section

- Shows whether `GITLAB_TOKEN` is set (`GET /config/gitlab-token`).
- Input to set/replace it (`POST /config/gitlab-token`), write-only.
- Inline explanation of what it unlocks (library install, Atlas, etc.) and a link to
  Catalog. A `Test` that does a lightweight authenticated GitLab call (reuse health).
- Warning affordance if unset (since Catalog install depends on it).

---

## 6. Environments section

- Table/cards of environments from `GET /config/environments` (label, url,
  api_endpoint, products, type, notes).
- **Add / Edit** in a dialog (react-hook-form + zod); `POST /config/environments`;
  **credential-free validator** enforced server-side — surface its 400 message
  inline (no secrets allowed in an environment).
- **Delete** with ConfirmDialog (`DELETE /config/environments/{label}`).
- Active-environment selection indicator (environments feed MCP `${VAR}` resolution
  fallback).

---

## 7. Storage & retention section

- Show artifacts root + disk usage (`GET /artifacts/usage`) as a MetricTile.
- Show retention policy (keep-last / max-age) read from settings (display only in
  this phase).
- (Deferred) purge action → later work item; leave a disabled/"coming soon"
  affordance or omit.

---

## 8. States

- **Loading**: skeleton cards (match final grid).
- **Empty**: if no MCP registry installed yet → empty state pointing to Catalog
  install (integrations come from the installed library's `mcp-registry.json`).
- **Error**: inline ErrorState with retry per section (sections load independently).
- **Success**: green status + toast on save/test.

---

## 9. Data & hooks

- `useMcpCards()`, `useCliCards()`, `useHealth()`, `useEnvironments()`,
  `useGitlabTokenStatus()` — TanStack Query.
- Mutations: `useSetSecret()`, `useSetGitlabToken()`, `useTestServer()`,
  `useUpsertEnvironment()`, `useRemoveEnvironment()` — each invalidates the relevant
  keys and toasts.
- No polling here (config is user-driven); `Test` is an explicit action.

---

## 10. Definition of done

1. Settings page renders MCP + CLI cards with accurate live status and field chips.
2. Configure drawer sets secrets/fields write-only, per-field save, deep-linkable.
3. Connection Test works and reflects result on the card.
4. GitLab token + environments (add/edit/delete, credential-free enforced) + storage
   display implemented.
5. All states (loading/empty/error/success) designed; a11y (labels, focus in drawer)
   verified; no secret value ever rendered/logged.
6. Component + MSW tests for card status, drawer save, and test action.
