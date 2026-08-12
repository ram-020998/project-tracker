# 21-05 — Chat parity (model, slash commands, context/compaction, clear, images)

> **Status:** ✅ CODE-COMPLETE (2026-08-12) — genesis working tree (uncommitted; ships in the Phase-21 end-of-phase release,
> incl. the genesis-core SDK pin bump). Backend **405** pytest + ruff clean; web typecheck + eslint clean, **150** Vitest / 18
> files, build OK. Develops against the editable 21-04 SDK. · **Phase:** 21 · **Repo:** genesis (+ genesis-core SDK pin) ·
> **ADR:** ADR-045 (revises ADR-031) · **Depends on:** 21-04 (SDK) · Applies to **both** the main chat and the spec builder

## Goal

Bring the reused chat to parity with the native Kiro CLI/ACP surface: **model selection at creation**, **slash commands with
autocomplete**, a **context-usage + compaction** indicator, **clear/compact**, and **image attachments** — in both places.

## ADR-045 (revises ADR-031) — the guardrail

Chat is **no longer categorically read-only**. Stance (approved 2026-08-12): **safe introspection** commands (`/context`,
`/usage`, `/tools`, `/help`, …) run freely; **write-capable actions** a command/tool may trigger stay **human-confirmed** via
the existing `permission_mode="ask"` + `on_permission` bridge (Phase 13), **not** blanket-denied. Default trust set stays
read-only; the permission card is the backstop. Bounded by local single-user (ADR-026). Applies to both chrome variants.

## Backend (genesis `chat/manager.py` + `api/chat.py`, consuming 21-04)

- **Model @ creation** — session-create accepts an optional `model`; `ChatManager` passes it to `KiroAgentOptions.model` when
  it spawns the session client. **Available models** come from the SDK (`available_models()`); expose `GET /api/chat/models`
  (with the Settings-configured fallback list if the CLI doesn't advertise). **Persist the choice** on the session — candidate
  migration **`m0011` `chat_sessions.model`** (nullable; only if we must re-read it after reload; else skip per 21-04/spike).
- **Slash commands** — passthrough endpoints over the live session client:
  - `GET /api/chat/sessions/{id}/commands` → `list_commands` (the `commands/available` set).
  - `GET /api/chat/sessions/{id}/commands/options?q=` → `command_options` (autocomplete).
  - command **execution** flows through the **existing** `POST …/messages` turn path: a message beginning with `/` is sent via
    `execute_command` and streams back as normal `agent.*` events (no separate render path). Permission bridge unchanged.
- **Context/compaction** — we already capture `contextUsagePercentage` per turn; surface **compaction status**
  (`_kiro.dev/compaction/status`) on the SSE stream as a lightweight event the UI can show. `POST …/clear` and `POST …/compact`
  trigger the corresponding commands and report status.
- **Images** — `POST …/messages` accepts an optional **image attachment** (multipart, reuse the 07-05 `postForm` idiom + the
  Phase-15 upload guards: size cap, mime allowlist, sanitized), forwarded as an SDK image content part; gated on the advertised
  image capability.

## Frontend (`Composer` + `ChatThread`, both chrome variants)

- **Model selector** — on **new chat** (and the spec's create), a compact model dropdown from `GET /api/chat/models`; the
  chosen model is sent at creation. (No mid-conversation switch — deferred.)
- **`/` palette + autocomplete** — extend the existing Composer `/` palette: as the user types `/…`, query `commands/options`
  and render suggestions (name + description); Enter/Tab completes; submitting a `/command` sends it through the turn path.
  Keep the existing copilot workflow/skills entries in `chrome="full"`; in `chrome="spec"` show only the command set.
- **Context meter** — a slim bar (existing tokens) showing `contextUsagePercentage`, with a **compaction** hint when a
  compaction status arrives, and **Clear** / **Compact** actions (Clear behind a confirm).
- **Attach image** — an attach control (reuse `FileDropList`/`postForm`); render a thumbnail chip in the composer; on send,
  include the image part. Hidden if the capability isn't advertised.

## Testing

- **Backend (pytest):** `/models` returns the SDK list (or fallback); commands list/options passthrough; a `/`-prefixed message
  routes through `execute_command`; write-capable tool still raises a permission request (ADR-045 backstop); image attach
  respects the guards; (if added) `m0011` migration asserted in `test_db.py`.
- **Web (Vitest):** model selector populates + submits at creation; typing `/` shows autocomplete from mocked options; context
  meter renders a percentage; Clear/Compact call their endpoints; image chip appears + is sent. Both chrome variants covered.

## Definition of done

- Model-at-creation, slash palette + autocomplete, context/compaction meter, clear/compact, and image attach all work in the
  main chat **and** the spec builder.
- ADR-045 stance enforced (introspection free; writes human-confirmed) with a regression test.
- genesis-core SDK **pin bumped** to the 21-04 tag; backend + web gates green; `web/static/` rebuilt + committed.
