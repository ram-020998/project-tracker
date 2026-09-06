# 38-06 — Code review & hardening

> **Status:** ✅ SHIPPED (genesis v0.65.0). · Part of Phase 38. Repo: **genesis**. · **Depends on:** 38-01..38-05.

## Review checklist

- **Artifact-only publish** — a published stage carries the artifact bytes + metadata only; `chat_session_id`/
  `run_id`/local `html_path` are **never** sent; no chat/run/document data leaks to the Hub.
- **Pull materializes a correct read-only mirror** — bytes on disk, local `html_path` set, local-only columns
  null; a downstream stage can consume a pulled upstream artifact; a pulled entity isn't silently editable as if
  local-owned.
- **CAS + notify-then-apply** — a divergent local draft is never auto-overwritten; conflicts surface for review.
- **Boards** — lanes/status + membership shared; **in-lane ordering + sidebar curation local**; concurrent lane
  moves resolve via CAS/LWW.
- **Cross-stage staleness = notify-only** (from `upstream_versions`); never auto-cascades/blocks.
- **Advisory markers** are non-blocking + expire; the CAS remains the correctness backstop.
- **Adoption** is confirmed + idempotent + only completed work + never automatic.
- **Opt-in no-op** when disabled; **solo installs unchanged**.
- **Standards** — ruff/tsc/eslint; jest-axe; no hard-coded `/api`/brand-hex; DB-agnostic stores; secrets by key
  name.

## Deliverable

Review notes + applied SHOULD-FIX; the full-SDLC live-acceptance script for 38-07.

## Gate

Review clean → 38-07.
